"""
CIRO FastAPI Backend — Main Application
=========================================
4 API endpoints for crisis detection and response orchestration.
The /api/detect endpoint invokes the full CIROPipeline (4 agents in sequence).

Endpoints:
    POST /api/ingest    — Ingest raw crisis signals
    POST /api/detect    — Run full agent pipeline, return crisis + trace
    POST /api/actions   — Get recommended actions for a crisis
    POST /api/simulate  — Run action simulation
"""

import sys
import os
import uuid
from datetime import datetime

# Add parent directory to path so we can import shared.models
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi import FastAPI
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

# ------------------------------------------------------------------ #
# FastAPI Application
# ------------------------------------------------------------------ #

app = FastAPI(
    title="CIRO — Crisis Intelligence & Response Orchestrator",
    description=(
        "Backend API for CIRO. Uses Google Antigravity as a runtime agent "
        "orchestrator to route crisis signals through 4 AI agents: "
        "Sensor → Analyst → Coordinator → Simulator."
    ),
    version="1.0.0",
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


# ------------------------------------------------------------------ #
# In-memory signal store (replaced by Firestore in Phase 2)
# ------------------------------------------------------------------ #

signal_store: list[dict] = []


# ------------------------------------------------------------------ #
# Endpoints
# ------------------------------------------------------------------ #

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
    pipeline = CIROPipeline()
    result = await pipeline.execute(request.signals)

    # Phase 2: Save agent_trace to Firestore here
    # db = get_db()
    # db.collection("agent_traces").add({
    #     "trace_id": str(uuid.uuid4()),
    #     "timestamp": datetime.now().isoformat(),
    #     "agent_trace": result["agent_trace"],
    #     "crisis": result["detected_crisis"],
    # })

    return DetectResponse(**result)


@app.post("/api/actions")
async def get_actions(request: ActionsRequest):
    """Get recommended response actions for a given crisis.
    
    In Phase 2, this will call the Coordinator Agent independently.
    For now, returns mock actions.
    """
    mock_actions = [
        ResponseAction(
            id=f"act_{uuid.uuid4().hex[:6]}",
            type="Traffic Reroute",
            description=f"Divert traffic around {request.location}",
            priority=1,
            estimated_impact="Reduces congestion by 50%",
        ).model_dump(),
        ResponseAction(
            id=f"act_{uuid.uuid4().hex[:6]}",
            type="Emergency Dispatch",
            description=f"Deploy response team to {request.location}",
            priority=2,
            estimated_impact="First responders on scene within 20 min",
        ).model_dump(),
    ]

    return {"actions": mock_actions, "crisis_location": request.location}


@app.post("/api/simulate")
async def simulate_action(request: SimulateRequest):
    """Simulate execution of a response action.
    
    In Phase 3, this will call action_simulator.py with real
    Firestore-backed before/after state.
    """
    result = SimulationResult(
        action_id=request.action_id,
        before_state={"congestion_percent": 85, "status": "critical"},
        after_state={"congestion_percent": 35, "status": "managed"},
        execution_log=[
            f"Initiated simulation for action {request.action_id}",
            f"Action type: {request.action_type}",
            "Computed before/after state delta",
            "Simulation completed successfully",
        ],
    )

    return {"simulation_result": result.model_dump()}
