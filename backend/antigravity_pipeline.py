"""
CIRO Antigravity Pipeline — Runtime Agent Orchestrator
=======================================================
Phase 2: Real Gemini 2.5 Flash calls using google-genai SDK.
"""

import sys
import os
import json
from datetime import datetime
from pydantic import BaseModel

# Add parent directory to path so we can import shared.models
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from shared.models import (
    CrisisSignal,
    DetectedCrisis,
    ResponseAction,
    SimulationResult,
    AgentMessage,
)
from config import get_settings
from google import genai
from google.genai import types

# ------------------------------------------------------------------ #
# Wrapper Models for Gemini Structured Outputs
# These allow us to extract reasoning_steps alongside the main schema
# without modifying the shared single-source-of-truth models.
# ------------------------------------------------------------------ #

class SensorAgentOutput(BaseModel):
    signals: list[CrisisSignal]
    reasoning_steps: list[str]

class AnalystAgentOutput(BaseModel):
    crisis: DetectedCrisis
    reasoning_steps: list[str]

class CoordinatorAgentOutput(BaseModel):
    actions: list[ResponseAction]
    reasoning_steps: list[str]

class SimulatorAgentOutput(BaseModel):
    results: list[SimulationResult]
    reasoning_steps: list[str]


class CIROPipeline:
    """Runtime agent orchestrator using Gemini 2.5 Flash."""

    def __init__(self):
        self.agent_trace: list[AgentMessage] = []
        settings = get_settings()
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)
        self.model_name = "gemini-2.5-flash"

    async def execute(self, raw_signals: list[dict]) -> dict:
        """Run the full 4-agent pipeline and return results + trace."""
        # Step 1: Sensor Agent
        normalized_signals = await self.run_sensor_agent(raw_signals)

        # Step 2: Analyst Agent
        detected_crisis = await self.run_analyst_agent(normalized_signals)

        # Step 3: Coordinator Agent
        actions = await self.run_coordinator_agent(detected_crisis)

        # Step 4: Simulator Agent
        simulation_results = await self.run_simulator_agent(actions)

        return {
            "detected_crisis": detected_crisis.model_dump(),
            "actions_recommended": [a.model_dump() for a in actions],
            "simulation_results": [s.model_dump() for s in simulation_results],
            "agent_trace": [msg.model_dump() for msg in self.agent_trace],
        }

    async def run_sensor_agent(self, raw_signals: list[dict]) -> list[CrisisSignal]:
        prompt = f"Raw Signals: {json.dumps(raw_signals)}\n\nNormalise these crisis signals into a structured JSON list of CrisisSignal objects."
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction="You are a Sensor Agent. Normalise crisis signals into structured JSON list of CrisisSignal objects. Extract location, crisis_type, severity, and source. Generate reasoning_steps to explain your extraction.",
                response_mime_type="application/json",
                response_schema=SensorAgentOutput,
                temperature=0.2,
            )
        )
        
        output: SensorAgentOutput = response.parsed
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Sensor Agent",
                input_summary=f"Received {len(raw_signals)} raw signal(s)",
                output_summary=f"Normalised into {len(output.signals)} CrisisSignal objects",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.signals

    async def run_analyst_agent(self, signals: list[CrisisSignal]) -> DetectedCrisis:
        signals_json = [s.model_dump() for s in signals]
        prompt = f"Normalised Signals: {json.dumps(signals_json)}\n\nAnalyse these CrisisSignal objects and produce a DetectedCrisis assessment."
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction="You are an Analyst Agent. Analyse CrisisSignal objects. Return JSON DetectedCrisis with type, location, severity, confidence, reasoning, and reasoning_steps list explaining your analysis. Derive severity strictly from the user's raw text and crisis type using this scale: 1 = minor inconvenience reported calmly, 2 = noticeable disruption, 3 = significant incident affecting multiple people, 4 = serious emergency with immediate danger, 5 = catastrophic event requiring all available resources. You must justify your severity choice inside reasoning_steps.",
                response_mime_type="application/json",
                response_schema=AnalystAgentOutput,
                temperature=0.2,
            )
        )
        
        output: AnalystAgentOutput = response.parsed
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Analyst Agent",
                input_summary=f"Analysed {len(signals)} CrisisSignal objects",
                output_summary=f"Detected '{output.crisis.type}' at {output.crisis.location} (Confidence: {output.crisis.confidence:.0%})",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.crisis

    async def run_coordinator_agent(self, crisis: DetectedCrisis) -> list[ResponseAction]:
        prompt = f"Detected Crisis: {json.dumps(crisis.model_dump())}\n\nGiven this crisis, return JSON array of ResponseAction objects prioritised P1/P2/P3 with realistic Islamabad-specific actions."
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction="You are a Coordinator Agent. Given crisis, return JSON array of ResponseAction objects prioritised P1/P2/P3. Generate reasoning_steps explaining your prioritization. When coordinates (lat/lng) are available in the signal data, generate actions tied to the exact GPS location (e.g. 'Dispatch nearest ambulance to coordinates 33.7225, 73.0805' or 'Establish a diversion at the 500m radius around the reported location'). When no coordinates are available, fall back to zone-level actions.",
                response_mime_type="application/json",
                response_schema=CoordinatorAgentOutput,
                temperature=0.2,
            )
        )
        
        output: CoordinatorAgentOutput = response.parsed
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Coordinator Agent",
                input_summary=f"Planning response for '{crisis.type}' at {crisis.location}",
                output_summary=f"Generated {len(output.actions)} response actions",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.actions

    async def run_simulator_agent(self, actions: list[ResponseAction]) -> list[SimulationResult]:
        actions_json = [a.model_dump() for a in actions]
        prompt = f"Response Actions: {json.dumps(actions_json)}\n\nSimulate the execution of these actions and return SimulationResult objects."
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction="You are a Simulator Agent. Simulate execution of response actions. Return SimulationResult objects with realistic before_state and after_state dicts. Generate reasoning_steps explaining your simulation.",
                response_mime_type="application/json",
                response_schema=SimulatorAgentOutput,
                temperature=0.4,
            )
        )
        
        output: SimulatorAgentOutput = response.parsed
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Simulator Agent",
                input_summary=f"Simulating {len(actions)} response actions",
                output_summary=f"Completed {len(output.results)} simulations",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.results
