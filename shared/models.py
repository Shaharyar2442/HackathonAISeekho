"""
CIRO Shared Models — Single Source of Truth
============================================
Created by Member 1 on Day 1 (Phase 1).
Every module across all 4 team members imports from this file.
DO NOT define local model copies anywhere else in the project.

Models:
    - CrisisSignal:     Raw or normalised crisis signal from any source
    - DetectedCrisis:   AI-analysed crisis with confidence and reasoning
    - ResponseAction:   Prioritised action recommended by the Coordinator Agent
    - SimulationResult: Before/after state from action simulation
    - AgentMessage:     Inter-agent trace log entry (critical for judging)
"""

from pydantic import BaseModel, Field
from typing import Any
from datetime import datetime


class CrisisSignal(BaseModel):
    """A single crisis signal — raw report or normalised sensor input.
    
    Used by: Sensor Agent (output), Analyst Agent (input),
             Member 3's signal_processor, Member 2's mobile app.
    """
    text: str = Field(..., description="Raw or normalised signal text, can be English or Roman Urdu")
    location: str = Field(..., description="Zone or area name, e.g. 'G-10', 'F-8', 'Blue Area'")
    crisis_type: str = Field(..., description="Crisis category: Flood, Accident, Power Outage, Fire, Traffic")
    severity: int = Field(..., ge=1, le=5, description="Severity level from 1 (minor) to 5 (critical)")
    source: str = Field(default="user_report", description="Signal source: user_report, sensor, social_media, news")
    timestamp: str = Field(
        default_factory=lambda: datetime.now().isoformat(),
        description="ISO 8601 timestamp of when the signal was generated"
    )


class DetectedCrisis(BaseModel):
    """AI-detected crisis produced by the Analyst Agent.
    
    Contains the crisis classification, severity assessment, confidence score,
    and the reasoning chain that led to the detection. This is the primary
    output displayed on the dashboard and mobile app.
    """
    type: str = Field(..., description="Crisis type: Urban Flooding, Road Accident, Power Outage, Fire, Traffic Jam")
    location: str = Field(..., description="Primary affected zone, e.g. 'G-10'")
    severity: int = Field(..., ge=1, le=5, description="Overall severity from 1 (minor) to 5 (critical)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="AI confidence score from 0.0 to 1.0")
    reasoning: str = Field(..., description="Human-readable explanation of the crisis assessment")


class ResponseAction(BaseModel):
    """A single recommended response action from the Coordinator Agent.
    
    Priority levels:
        P1 = Immediate (e.g. traffic reroute)
        P2 = Urgent (e.g. emergency dispatch)
        P3 = Standard (e.g. citizen alert)
    """
    id: str = Field(..., description="Unique action identifier, e.g. 'act_001'")
    type: str = Field(..., description="Action type: Traffic Reroute, Emergency Dispatch, Citizen Alert")
    description: str = Field(..., description="Detailed description of the action to take")
    priority: int = Field(..., ge=1, le=3, description="Priority level: 1 (P1-Immediate), 2 (P2-Urgent), 3 (P3-Standard)")
    estimated_impact: str = Field(..., description="Expected outcome, e.g. 'Reduces congestion by 50%'")


class SimulationResult(BaseModel):
    """Result of executing a simulated action.
    
    Contains before/after state snapshots and an execution log.
    Used by the Simulator Agent and displayed in the dashboard's
    before/after visualization panel.
    """
    action_id: str = Field(..., description="ID of the ResponseAction that was simulated")
    before_state: dict[str, Any] = Field(..., description="State snapshot before simulation, e.g. {'congestion': 85}")
    after_state: dict[str, Any] = Field(..., description="State snapshot after simulation, e.g. {'congestion': 35}")
    execution_log: list[str] = Field(
        default_factory=list,
        description="Step-by-step log of simulation execution"
    )


class AgentMessage(BaseModel):
    """Inter-agent trace log entry — CRITICAL for 45% of judging criteria.
    
    Every agent in the pipeline (Sensor, Analyst, Coordinator, Simulator)
    generates one AgentMessage per invocation. The full list of AgentMessages
    forms the agent_trace that is:
        1. Returned in every /api/detect response
        2. Saved to Firestore under agent_traces collection
        3. Displayed live on the dashboard and mobile app
        4. Exported as JSON for submission artifacts
    
    This is NOT a debug log — it is a core deliverable.
    """
    agent_name: str = Field(..., description="Agent identifier: 'Sensor Agent', 'Analyst Agent', 'Coordinator Agent', 'Simulator Agent'")
    input_summary: str = Field(..., description="Brief description of what was passed to this agent")
    output_summary: str = Field(..., description="Brief description of what this agent produced")
    reasoning_steps: list[str] = Field(
        default_factory=list,
        description="Ordered list of reasoning steps the agent took to reach its conclusion"
    )
    timestamp: str = Field(
        default_factory=lambda: datetime.now().isoformat(),
        description="ISO 8601 timestamp of when this agent completed execution"
    )
