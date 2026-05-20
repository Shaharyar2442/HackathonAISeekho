"""
CIRO FastAPI Backend — Main Application
=========================================
Backend API for crisis detection and response orchestration.
The /api/detect endpoint invokes the full CIROPipeline (4 agents in sequence).

Endpoints:
    POST /api/ingest              — Ingest raw crisis signals
    POST /api/detect              — Run full agent pipeline, return crisis + trace
    POST /api/actions             — Get recommended actions for a crisis
    POST /api/simulate            — Run action simulation
    GET  /api/health              — Health check
    GET  /api/aggregate/{zone}    — Multi-source signal aggregation
    GET  /api/crisis/{id}/logs    — Fetch agent trace from Firestore
    POST /api/demo/run-scenario/{scenario_id} — SSE streaming demo
    WS   /ws/signals              — Live signal WebSocket
"""

import sys
import os
import json
import uuid
import random
from datetime import datetime

# Add parent directory to path so we can import shared.models
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
# Add current backend directory to path so sibling imports resolve
sys.path.insert(0, os.path.dirname(__file__))

import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from shared.models import (
    CrisisSignal,
    DetectedCrisis,
    ResponseAction,
    SimulationResult,
    AgentMessage,
)
from antigravity_pipeline import CIROPipeline
from config import get_settings
from db import get_db
from persistence import save_crisis_event, load_recent_crisis_events, update_crisis_severity

from signal_processor import MockDataGenerator
from signal_aggregator import SignalAggregator, CrisisScorer, AggregatorAgentLogger

# ------------------------------------------------------------------ #
# FastAPI Application
# ------------------------------------------------------------------ #

# ------------------------------------------------------------------ #
# Background Agent Signal Generator
# ------------------------------------------------------------------ #

from contextlib import asynccontextmanager

async def _agent_signal_loop():
    """Runs every 90 s. Picks one realistic signal, runs the full pipeline,
    and broadcasts the result to all connected WebSocket clients."""
    # Islamabad zones with coordinates for realistic spreading
    ZONE_COORDS = {
        'G-10': (33.6990, 73.0390), 'G-11': (33.6910, 73.0300),
        'F-8':  (33.7150, 73.0430), 'I-8':  (33.6840, 73.0710),
        'Blue Area': (33.7230, 73.0885), 'F-7': (33.7250, 73.0560),
        'G-9': (33.7070, 73.0480), 'F-6': (33.7310, 73.0660),
    }
    AGENT_SIGNALS = [
        {"text": "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain!", "crisis_type": "Urban Flooding", "location": "G-10", "source": "social_media"},
        {"text": "F-8 mein bari car crash, ambulance immediately chahiye!", "crisis_type": "Severe Accident", "location": "F-8", "source": "sensor"},
        {"text": "Blue Area transformer blast hua, power completely off", "crisis_type": "Power Infrastructure", "location": "Blue Area", "source": "citizen_report"},
        {"text": "G-11 mein traffic jam lag gaya, Margalla Road block hai", "crisis_type": "Traffic Gridlock", "location": "G-11", "source": "sensor"},
        {"text": "I-8 mein gas leak report hua, log area khali kar rahe hain", "crisis_type": "Fire Hazard", "location": "I-8", "source": "field_officer"},
        {"text": "F-7 mein smoke reported near market, fire brigade alert", "crisis_type": "Fire Hazard", "location": "F-7", "source": "social_media"},
        {"text": "G-9 nala overflow ho raha hai, heavy rain expected", "crisis_type": "Urban Flooding", "location": "G-9", "source": "weather_api"},
        {"text": "F-6 mein bijli nahi hai, offices band ho rahe hain", "crisis_type": "Power Infrastructure", "location": "F-6", "source": "citizen_report"},
    ]
    idx = 0
    await asyncio.sleep(15)  # initial delay so server is fully up
    while True:
        try:
            raw = AGENT_SIGNALS[idx % len(AGENT_SIGNALS)]
            idx += 1
            loc = raw['location']
            coords = ZONE_COORDS.get(loc, (33.6844, 73.0479))
            signal_with_coords = {**raw, 'lat': coords[0], 'lng': coords[1], 'timestamp': datetime.now().isoformat()}

            pipeline = CIROPipeline()
            result = await pipeline.execute([signal_with_coords])

            payload = {
                'type': 'new_crisis',
                'crisis': result['detected_crisis'],
                'actions': result['actions_recommended'],
                'agent_trace': result['agent_trace'],
                'signal': signal_with_coords,
            }
            await manager.broadcast(payload)
            # Persist to Firestore
            try:
                db = get_db()
                await save_crisis_event(db, result, signal=signal_with_coords, source="agent_generated")
            except Exception as fe:
                print(f"[BG] Firestore save failed (non-fatal): {fe}")
            print(f"[BG] Broadcast agent crisis: {result['detected_crisis'].get('type')} @ {loc}")
        except Exception as e:
            print(f"[BG] Agent signal loop error (non-fatal): {e}")
        await asyncio.sleep(90)

@asynccontextmanager
async def lifespan(app_instance):
    task = asyncio.create_task(_agent_signal_loop())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass

app = FastAPI(
    title="CIRO — Crisis Intelligence & Response Orchestrator",
    description=(
        "Backend API for CIRO. Uses Google Antigravity as a runtime agent "
        "orchestrator to route crisis signals through 4 AI agents: "
        "Sensor → Analyst → Coordinator → Simulator."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# ------------------------------------------------------------------ #
# CORS — allow dashboard, mobile, and any origin to call the API
# ------------------------------------------------------------------ #

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ------------------------------------------------------------------ #
# Request / Response Models
# ------------------------------------------------------------------ #

class IngestRequest(BaseModel):
    """Request body for POST /api/ingest."""
    signals: list[dict]


class IngestResponse(BaseModel):
    """Response for POST /api/ingest."""
    status: str
    signals_received: int
    timestamp: str


class DetectRequest(BaseModel):
    """Request body for POST /api/detect."""
    signals: list[dict]


class DetectResponse(BaseModel):
    """Response for POST /api/detect — includes full agent_trace."""
    detected_crisis: dict
    actions_recommended: list[dict]
    simulation_results: list[dict]
    agent_trace: list[dict]


class ActionsRequest(BaseModel):
    """Request body for POST /api/actions."""
    crisis_type: str
    location: str
    severity: int


class SimulateRequest(BaseModel):
    """Request body for POST /api/simulate."""
    action_id: str
    action_type: str

class ReduceSeverityRequest(BaseModel):
    """Request body for POST /api/reduce_severity."""
    location: str
    new_severity: int


# ------------------------------------------------------------------ #
# In-memory signal store (replaced by Firestore in Phase 2)
# ------------------------------------------------------------------ #

signal_store: list[dict] = []


# ------------------------------------------------------------------ #
# Endpoints
# ------------------------------------------------------------------ #

@app.get("/api/health")
async def health_check():
    """Health check endpoint for Cloud Run and monitoring."""
    return {
        "status": "healthy",
        "service": "CIRO Backend",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
    }


@app.post("/api/ingest", response_model=IngestResponse)
async def ingest_signals(request: IngestRequest):
    """Ingest raw crisis signals into the system.
    
    Accepts raw signal data and stores it for processing.
    In Phase 2, this will write to Firestore.
    """
    signal_store.extend(request.signals)

    return IngestResponse(
        status="accepted",
        signals_received=len(request.signals),
        timestamp=datetime.now().isoformat(),
    )


@app.post("/api/detect", response_model=DetectResponse)
async def detect_crisis(request: DetectRequest):
    """Run the full 4-agent Antigravity pipeline.
    
    This is the primary endpoint. It:
    1. Instantiates a fresh CIROPipeline
    2. Passes raw signals through Sensor → Analyst → Coordinator → Simulator
    3. Returns DetectedCrisis + ResponseActions + SimulationResults + agent_trace
    
    The agent_trace contains 4 AgentMessage entries (one per agent),
    each with reasoning_steps showing the agent's thought process.
    """
    try:
        pipeline = CIROPipeline()
        result = await pipeline.execute(request.signals)
    except Exception as e:
        print(f"ERROR in pipeline: {e}")
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    # Persist to Firestore (crisis_events collection)
    try:
        db = get_db()
        await save_crisis_event(
            db, result,
            signal=request.signals[0] if request.signals else {},
            source="user_report",
        )
    except Exception as e:
        print(f"WARNING: Could not save to Firestore: {e}")

    # Phase 4: Broadcast real crisis detection to all connected WebSockets
    broadcast_payload = {
        "type": "new_crisis",
        "crisis": result["detected_crisis"],
        "actions": result["actions_recommended"],
        "agent_trace": result["agent_trace"],
        "signal": request.signals[0] if request.signals else {}
    }
    await manager.broadcast(broadcast_payload)

    return DetectResponse(**result)


@app.post("/api/reduce_severity")
async def reduce_severity(request: ReduceSeverityRequest):
    """Update the severity of an incident after an action is simulated."""
    try:
        db = get_db()
        success = await update_crisis_severity(db, request.location, request.new_severity)
        return {"status": "success" if success else "not_found"}
    except Exception as e:
        print(f"Error reducing severity: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/actions")
async def get_actions(request: ActionsRequest):
    """Get recommended response actions for a given crisis.
    
    Dynamically calls the Coordinator Agent to generate actions based on the crisis.
    """
    try:
        pipeline = CIROPipeline()
        crisis = DetectedCrisis(
            type=request.crisis_type,
            location=request.location,
            severity=request.severity,
            confidence=0.95,
            reasoning="Generated from user request"
        )
        actions = await pipeline.run_coordinator_agent(crisis)
        return {"actions": [a.model_dump() for a in actions], "crisis_location": request.location}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Actions error: {str(e)}")


@app.post("/api/simulate")
async def simulate_action(request: SimulateRequest):
    """Simulate execution of a response action using the Simulator Agent and Gemini Tools."""
    try:
        pipeline = CIROPipeline()
        action = ResponseAction(
            id=request.action_id,
            type=request.action_type,
            description="Simulate this action based on context.",
            priority=1,
            estimated_impact="Pending AI simulation"
        )
        results = await pipeline.run_simulator_agent([action])
        if results:
            return {
                "simulation_result": results[0].model_dump(),
                "agent_trace": [msg.model_dump() for msg in pipeline.agent_trace]
            }
        return {"simulation_result": {"error": "Simulation failed"}, "agent_trace": []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Simulation error: {str(e)}")


# (Duplicate /api/health route removed — see line 130 for the canonical definition)


# ------------------------------------------------------------------ #
# Phase 3: WebSockets & Logs
# ------------------------------------------------------------------ #

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)

manager = ConnectionManager()

@app.websocket("/ws/signals")
async def websocket_signals(websocket: WebSocket):
    """WebSocket endpoint. Sends recent history from Firestore on connect,
    then streams real-time crises as they are detected."""
    await manager.connect(websocket)
    # Send recent history so the map is populated immediately on app open
    try:
        db = get_db()
        history = await load_recent_crisis_events(db, limit=20)
        for event in reversed(history):  # oldest first so map numbers ascend
            await websocket.send_json({
                "type": "new_crisis",
                "crisis": {
                    "type": event.get("crisis_type", "Unknown"),
                    "location": event.get("location", "Unknown"),
                    "severity": event.get("severity", 1),
                    "confidence": event.get("confidence", 0.0),
                    "reasoning": event.get("reasoning", ""),
                },
                "actions": event.get("actions", []),
                "agent_trace": event.get("agent_trace", []),
                "signal": {
                    "text": f"[History] {event.get('crisis_type')} @ {event.get('location')}",
                    "lat": event.get("lat"),
                    "lng": event.get("lng"),
                    "location": event.get("location"),
                    "source": event.get("source", "history"),
                },
            })
    except Exception as e:
        print(f"[WS] Could not send history: {e}")
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@app.get("/api/aggregate/{zone}")
async def aggregate_zone_signals(zone: str):
    """Uses Member 3's SignalAggregator to fetch multi-source signals for a zone."""
    aggregator = SignalAggregator()
    scorer = CrisisScorer()
    logger = AggregatorAgentLogger()
    
    signals = aggregator.aggregate_all(zone)
    assessment = scorer.score(signals)
    trace_log = logger.log(zone, signals, assessment)
    
    # Save trace to Firestore
    try:
        db = get_db()
        db.collection("agent_traces").add({
            "trace_id": str(uuid.uuid4()),
            "timestamp": datetime.now().isoformat(),
            "agent_trace": [trace_log.model_dump()],
            "zone": zone
        })
    except Exception as e:
        print(f"WARNING: Could not save trace to Firestore: {e}")
        
    return {
        "zone": zone,
        "signals": [s.model_dump() for s in signals],
        "assessment": {
            "crisis_probability": assessment.crisis_probability,
            "severity_level": assessment.severity_level,
            "trend": assessment.trend
        },
        "agent_trace": [trace_log.model_dump()]
    }


@app.get("/api/crisis/{id}/logs")
async def get_crisis_logs(id: str):
    """Get the AgentTrace logs for a given trace_id from Firestore."""
    try:
        db = get_db()
        # Query Firestore for agent_traces where trace_id == id
        docs = db.collection("agent_traces").where("trace_id", "==", id).get()
        if docs:
            doc_data = docs[0].to_dict()
            return {"trace_id": id, "agent_trace": doc_data.get("agent_trace", [])}
        else:
            return {"status": "error", "message": "Trace not found"}
    except Exception as e:
        print(f"Firestore read failed: {e}")
        return {"status": "error", "message": f"Could not fetch logs (GCP error: {e})"}


# ------------------------------------------------------------------ #
# Phase 4: SSE Scenario Demo Endpoint
# ------------------------------------------------------------------ #

SCENARIOS_PATH = os.path.join(os.path.dirname(__file__), "..", "scenarios.json")


@app.post("/api/demo/run-scenario/{scenario_id}")
async def run_scenario_demo(scenario_id: str):
    """Stream a scenario as Server-Sent Events (SSE).
    
    Loads the scenario from scenarios.json, iterates through each signal
    with a 1.5s delay between events to simulate real-time ingestion.
    Each event is an SSE `data:` line containing the signal JSON.
    
    Usage:
        curl -N -X POST http://localhost:8000/api/demo/run-scenario/A
    """
    # Load scenarios
    try:
        with open(SCENARIOS_PATH, "r") as f:
            scenarios = json.load(f)
    except FileNotFoundError:
        return {"status": "error", "message": "scenarios.json not found"}

    # Find requested scenario
    scenario = next((s for s in scenarios if s["scenario_id"] == scenario_id), None)
    if not scenario:
        return {"status": "error", "message": f"Scenario '{scenario_id}' not found. Available: A, B, C"}

    async def event_generator():
        signals = scenario["signals"]
        # Send scenario metadata first
        meta = {
            "event": "scenario_start",
            "scenario_id": scenario["scenario_id"],
            "name": scenario["name"],
            "zone": scenario["zone"],
            "description": scenario["description"],
            "total_signals": len(signals),
        }
        yield f"data: {json.dumps(meta)}\n\n"
        await asyncio.sleep(0.5)

        # Stream each signal with delay
        for i, signal in enumerate(signals):
            event_data = {
                "event": "signal",
                "index": i + 1,
                "total": len(signals),
                "signal": signal,
            }
            yield f"data: {json.dumps(event_data)}\n\n"
            await asyncio.sleep(1.5)

        # Send completion event
        complete = {
            "event": "scenario_complete",
            "scenario_id": scenario["scenario_id"],
            "signals_streamed": len(signals),
        }
        yield f"data: {json.dumps(complete)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )

