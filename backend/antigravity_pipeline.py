"""
CIRO Antigravity Pipeline — Runtime Agent Orchestrator
=======================================================
This is the core of CIRO's architecture and the primary deliverable
for the 25% "Use of Google Antigravity" judging criterion.

Antigravity orchestrates 4 named AI agents in sequence at RUNTIME:
    1. Sensor Agent     — normalises raw signals into CrisisSignal objects
    2. Analyst Agent    — analyses signals, produces DetectedCrisis with confidence
    3. Coordinator Agent — generates prioritised ResponseAction list (P1/P2/P3)
    4. Simulator Agent  — executes actions, returns SimulationResult with before/after

Each agent logs an AgentMessage to self.agent_trace. The full trace is:
    - Returned in every /api/detect response
    - Saved to Firestore under agent_traces collection
    - Displayed live on the dashboard and mobile app

SDK: google-genai (official Google Gen AI Python SDK)
Install: pip install google-genai
Model: gemini-2.5-flash (free tier via AI Studio API key)

Phase 1: All agents return MOCK data (this file).
Phase 2: Replace stubs with real Gemini calls.
"""

import sys
import os
from datetime import datetime

# Add parent directory to path so we can import shared.models
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from shared.models import (
    CrisisSignal,
    DetectedCrisis,
    ResponseAction,
    SimulationResult,
    AgentMessage,
)


class CIROPipeline:
    """Runtime agent orchestrator — the heart of CIRO.
    
    This class is instantiated fresh for each /api/detect request.
    It runs 4 agents in sequence, passing each agent's output as
    the next agent's input, and collects AgentMessage logs at every step.
    
    Phase 1: Mock data stubs (current).
    Phase 2: Real Gemini 2.5 Flash calls via google-genai SDK.
    """

    def __init__(self):
        self.agent_trace: list[AgentMessage] = []

    async def execute(self, raw_signals: list[dict]) -> dict:
        """Run the full 4-agent pipeline and return results + trace.
        
        Args:
            raw_signals: List of raw signal dicts from the /api/detect request body.
            
        Returns:
            dict with detected_crisis, actions_recommended, and agent_trace.
        """
        # Step 1: Sensor Agent — normalise raw inputs
        normalized_signals = await self.run_sensor_agent(raw_signals)

        # Step 2: Analyst Agent — analyse signals, produce crisis assessment
        detected_crisis = await self.run_analyst_agent(normalized_signals)

        # Step 3: Coordinator Agent — generate prioritised response actions
        actions = await self.run_coordinator_agent(detected_crisis)

        # Step 4: Simulator Agent — simulate action execution
        simulation_results = await self.run_simulator_agent(actions)

        return {
            "detected_crisis": detected_crisis.model_dump(),
            "actions_recommended": [a.model_dump() for a in actions],
            "simulation_results": [s.model_dump() for s in simulation_results],
            "agent_trace": [msg.model_dump() for msg in self.agent_trace],
        }

    # ------------------------------------------------------------------ #
    # Agent Methods — Phase 1: Mock stubs (replaced in Phase 2)
    # ------------------------------------------------------------------ #

    async def run_sensor_agent(self, raw_signals: list[dict]) -> list[CrisisSignal]:
        """Sensor Agent: Normalise raw signal inputs into CrisisSignal objects.
        
        Phase 1: Returns mock CrisisSignal data.
        Phase 2: Will call Gemini 2.5 Flash with system prompt:
                 "You are a Sensor Agent. Normalise these crisis signals 
                  into structured JSON list of CrisisSignal objects."
        """
        # --- MOCK DATA (Phase 1) ---
        signals = [
            CrisisSignal(
                text="G-10 mein pani bhar gaya hai, sadkein band hain",
                location="G-10",
                crisis_type="Flood",
                severity=4,
                source="social_media",
            ),
            CrisisSignal(
                text="Heavy rainfall causing waterlogging in G-10 Markaz",
                location="G-10",
                crisis_type="Flood",
                severity=4,
                source="news",
            ),
            CrisisSignal(
                text="G-10/4 mein bijli bhi chali gayi hai",
                location="G-10",
                crisis_type="Power Outage",
                severity=3,
                source="user_report",
            ),
        ]

        # Log AgentMessage
        self.agent_trace.append(
            AgentMessage(
                agent_name="Sensor Agent",
                input_summary=f"Received {len(raw_signals)} raw signal(s)",
                output_summary=f"Normalised into {len(signals)} CrisisSignal objects",
                reasoning_steps=[
                    "Parsed raw text inputs for location mentions",
                    "Identified 'G-10' as primary affected zone",
                    "Classified keywords: 'pani'/'waterlogging' → Flood, 'bijli' → Power Outage",
                    "Assigned severity based on keyword intensity and source credibility",
                    f"Generated {len(signals)} structured CrisisSignal objects",
                ],
            )
        )

        return signals

    async def run_analyst_agent(self, signals: list[CrisisSignal]) -> DetectedCrisis:
        """Analyst Agent: Analyse signals and produce a DetectedCrisis.
        
        Phase 1: Returns mock DetectedCrisis.
        Phase 2: Will call Gemini 2.5 Flash with system prompt:
                 "You are an Analyst Agent. Analyse these CrisisSignal objects.
                  Return JSON DetectedCrisis with type, location, severity, 
                  confidence, reasoning, and reasoning_steps list."
        """
        # --- MOCK DATA (Phase 1) ---
        crisis = DetectedCrisis(
            type="Urban Flooding",
            location="G-10",
            severity=4,
            confidence=0.87,
            reasoning=(
                "Multiple corroborating reports from social media and news sources "
                "indicate severe waterlogging in G-10 Markaz area. Concurrent power "
                "outage report suggests infrastructure stress. High confidence due to "
                "multi-source confirmation."
            ),
        )

        # Log AgentMessage
        self.agent_trace.append(
            AgentMessage(
                agent_name="Analyst Agent",
                input_summary=f"Analysed {len(signals)} CrisisSignal objects from Sensor Agent",
                output_summary=f"Detected '{crisis.type}' at {crisis.location} — severity {crisis.severity}/5, confidence {crisis.confidence:.0%}",
                reasoning_steps=[
                    f"Received {len(signals)} signals from Sensor Agent",
                    "Cross-referenced signal locations — all point to G-10 zone",
                    "Identified dominant crisis type: Flood (2/3 signals)",
                    "Secondary crisis: Power Outage (1/3 signals, likely correlated)",
                    "Multi-source confirmation: social_media + news = high credibility",
                    "Assigned severity 4/5 based on infrastructure impact (roads + power)",
                    "Computed confidence 0.87 from source diversity and signal consistency",
                ],
            )
        )

        return crisis

    async def run_coordinator_agent(self, crisis: DetectedCrisis) -> list[ResponseAction]:
        """Coordinator Agent: Generate prioritised response actions.
        
        Phase 1: Returns mock ResponseAction list.
        Phase 2: Will call Gemini 2.5 Flash with system prompt:
                 "You are a Coordinator Agent. Given this crisis, return JSON 
                  array of ResponseAction objects prioritised P1/P2/P3 with 
                  realistic Islamabad-specific actions."
        """
        # --- MOCK DATA (Phase 1) ---
        actions = [
            ResponseAction(
                id="act_001",
                type="Traffic Reroute",
                description="Divert traffic from G-10 Markaz via G-9/Khayaban-e-Suhrwardy alternate route",
                priority=1,
                estimated_impact="Reduces congestion from 85% to ~35%",
            ),
            ResponseAction(
                id="act_002",
                type="Emergency Dispatch",
                description="Deploy NDMA flood response team to G-10 Markaz with water pumps and rescue equipment",
                priority=2,
                estimated_impact="Begin water drainage within 45 minutes, ETA for first responders: 20 min",
            ),
            ResponseAction(
                id="act_003",
                type="Citizen Alert",
                description="Push bilingual alert (English + Roman Urdu) to all CIRO-registered users in G-10 and adjacent zones",
                priority=3,
                estimated_impact="Estimated reach: 15,000 residents in affected and buffer zones",
            ),
        ]

        # Log AgentMessage
        self.agent_trace.append(
            AgentMessage(
                agent_name="Coordinator Agent",
                input_summary=f"Planning response for '{crisis.type}' at {crisis.location} (severity {crisis.severity})",
                output_summary=f"Generated {len(actions)} response actions: P1 Traffic Reroute, P2 Emergency Dispatch, P3 Citizen Alert",
                reasoning_steps=[
                    f"Assessed crisis: {crisis.type} at {crisis.location}, severity {crisis.severity}/5",
                    "P1 (Immediate): Traffic reroute — prevents secondary accidents and enables emergency vehicle access",
                    "P2 (Urgent): NDMA dispatch — deploys flood response team with drainage equipment",
                    "P3 (Standard): Citizen alert — warns residents to avoid affected area and prepare for disruption",
                    "Prioritised by urgency: life safety > infrastructure > information",
                    f"Total actions: {len(actions)}, covering traffic, emergency, and communication response",
                ],
            )
        )

        return actions

    async def run_simulator_agent(self, actions: list[ResponseAction]) -> list[SimulationResult]:
        """Simulator Agent: Simulate execution of response actions.
        
        Phase 1: Returns mock SimulationResult data.
        Phase 3: Will integrate with action_simulator.py for real 
                 Firestore-backed simulation with before/after state.
        """
        # --- MOCK DATA (Phase 1) ---
        results = [
            SimulationResult(
                action_id="act_001",
                before_state={"congestion_percent": 85, "avg_speed_kmh": 8, "blocked_routes": 3},
                after_state={"congestion_percent": 35, "avg_speed_kmh": 42, "blocked_routes": 0},
                execution_log=[
                    "Activated alternate route via G-9/Khayaban-e-Suhrwardy",
                    "Updated traffic signal timings at 4 intersections",
                    "Notified Islamabad Traffic Police for on-ground enforcement",
                    "Congestion reduced from 85% to 35% within simulation window",
                ],
            ),
            SimulationResult(
                action_id="act_002",
                before_state={"teams_deployed": 0, "water_level_cm": 45, "evacuated": 0},
                after_state={"teams_deployed": 2, "water_level_cm": 15, "evacuated": 120},
                execution_log=[
                    "Dispatched 2 NDMA flood response teams to G-10 Markaz",
                    "ETA: 20 minutes from nearest staging area",
                    "Water pumps activated — projected drainage: 30cm/hour",
                    "Evacuation advisory issued for 120 ground-floor residents",
                ],
            ),
            SimulationResult(
                action_id="act_003",
                before_state={"alerts_sent": 0, "citizens_notified": 0},
                after_state={"alerts_sent": 1, "citizens_notified": 15000},
                execution_log=[
                    "Composed bilingual alert (English + Roman Urdu)",
                    "Broadcast via CIRO push notification channel",
                    "Coverage: G-10, G-9, G-11 (affected + buffer zones)",
                    "Estimated reach: 15,000 registered users",
                ],
            ),
        ]

        # Log AgentMessage
        self.agent_trace.append(
            AgentMessage(
                agent_name="Simulator Agent",
                input_summary=f"Simulating execution of {len(actions)} response action(s)",
                output_summary=f"Completed {len(results)} simulations — traffic congestion 85%→35%, 2 teams deployed, 15K citizens alerted",
                reasoning_steps=[
                    "Simulation 1 (Traffic Reroute): Modelled alternate route capacity, predicted congestion drop from 85% to 35%",
                    "Simulation 2 (Emergency Dispatch): Calculated ETA from nearest NDMA staging area, projected water drainage rate",
                    "Simulation 3 (Citizen Alert): Estimated notification reach based on registered user density in affected zones",
                    "All simulations completed successfully with before/after state snapshots",
                ],
            )
        )

        return results
