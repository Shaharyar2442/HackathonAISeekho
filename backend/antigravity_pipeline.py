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
from tenacity import retry, stop_after_attempt, wait_exponential
from action_simulator import calculate_simulation_metrics

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

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def run_sensor_agent(self, raw_signals: list[dict]) -> list[CrisisSignal]:
        prompt = f"Raw Signals: {json.dumps(raw_signals)}\n\nNormalise these crisis signals into a structured JSON list of CrisisSignal objects."
        
        sys_instruct = (
            "You are a Sensor Agent in Islamabad, Pakistan. "
            "Your task is to normalise noisy, informal crisis signals (including Roman Urdu like 'pani bhar gaya hai', 'rasta band hai') "
            "into structured JSON objects. Recognize local sectors (e.g., G-10, F-8, Blue Area). "
            "You MUST use explicit Chain-of-Thought reasoning. Break down your logic step-by-step in the reasoning_steps array "
            "BEFORE generating the final output list. Explain how you inferred the severity and translated the text."
        )
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
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

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def run_analyst_agent(self, signals: list[CrisisSignal]) -> DetectedCrisis:
        signals_json = [s.model_dump() for s in signals]
        prompt = f"Normalised Signals: {json.dumps(signals_json)}\n\nAnalyse these CrisisSignal objects and produce a DetectedCrisis assessment."
        
        sys_instruct = (
            "You are an Analyst Agent operating in Islamabad. Analyse the provided CrisisSignal objects. "
            "You MUST use explicit Chain-of-Thought reasoning. In your reasoning_steps, explicitly mention: "
            "1. Correlating signals to find clusters. 2. Translating any local context. 3. Estimating severity based on NDMA guidelines. "
            "Only after documenting your logic, return the final DetectedCrisis JSON with confidence score and summary."
        )
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
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

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def run_coordinator_agent(self, crisis: DetectedCrisis) -> list[ResponseAction]:
        prompt = f"Detected Crisis: {json.dumps(crisis.model_dump())}\n\nGiven this crisis, return JSON array of ResponseAction objects prioritised P1/P2/P3 with realistic Islamabad-specific actions."
        
        sys_instruct = (
            "You are a Coordinator Agent for Islamabad Emergency Response. "
            "You MUST use explicit Chain-of-Thought reasoning. Document your thought process in reasoning_steps: "
            "1. Evaluate resources needed for this specific sector. 2. Prioritize actions (P1/P2/P3). 3. Design realistic interventions. "
            "Then, return the JSON array of ResponseAction objects."
        )
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
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

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def run_simulator_agent(self, actions: list[ResponseAction]) -> list[SimulationResult]:
        actions_json = [a.model_dump() for a in actions]
        
        sys_instruct = (
            "You are a Simulator Agent. You MUST use the calculate_simulation_metrics tool to simulate the execution of EACH response action. "
            "Call the tool for each action type. After executing the tools, analyse the results and return them in the SimulatorAgentOutput JSON schema. "
            "Include your Chain-of-Thought in reasoning_steps explaining the tool execution results."
        )

        chat = self.client.chats.create(
            model=self.model_name,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
                temperature=0.4,
                tools=[calculate_simulation_metrics]
            )
        )
        
        # Step 1: Ask the agent to use the tools
        prompt = f"Response Actions: {json.dumps(actions_json)}\n\nPlease call the tool to simulate the execution of these actions."
        response = chat.send_message(prompt)
        
        # Step 2: If the model called tools, execute them and send results back
        if response.function_calls:
            function_responses = []
            for function_call in response.function_calls:
                if function_call.name == "calculate_simulation_metrics":
                    action_type = function_call.args.get("action_type", "")
                    location = function_call.args.get("location", "")
                    # Execute our actual Python function
                    result_dict = calculate_simulation_metrics(action_type, location)
                    
                    function_responses.append(
                        types.Part.from_function_response(
                            name="calculate_simulation_metrics",
                            response={"result": result_dict}
                        )
                    )
            
            # Send the tool output back to the model
            response = chat.send_message(types.Content(parts=function_responses))
            
        # Step 3: Now ask the model to format its findings into the final structured JSON
        final_response = chat.send_message(
            "Great. Now, based on the simulation results you received, output the final JSON matching the SimulatorAgentOutput schema.",
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=SimulatorAgentOutput,
            )
        )
        
        output: SimulatorAgentOutput = final_response.parsed
        
        # We need to map the action IDs back properly, since the model might hallucinate them
        if len(output.results) == len(actions):
            for i, res in enumerate(output.results):
                res.action_id = actions[i].id
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Simulator Agent",
                input_summary=f"Simulating {len(actions)} response actions via Tool Execution",
                output_summary=f"Completed {len(output.results)} simulations using calculate_simulation_metrics tool",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.results
