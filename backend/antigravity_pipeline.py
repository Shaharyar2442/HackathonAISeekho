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
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from action_simulator import calculate_simulation_metrics

def async_retry(func):
    """Wraps an async function with tenacity retry using asyncio-compatible approach."""
    import functools
    @functools.wraps(func)
    async def wrapper(*args, **kwargs):
        from tenacity import AsyncRetrying
        async for attempt in AsyncRetrying(
            stop=stop_after_attempt(3),
            wait=wait_exponential(multiplier=1, min=2, max=10),
            reraise=True,
        ):
            with attempt:
                return await func(*args, **kwargs)
    return wrapper

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


# ------------------------------------------------------------------ #
# Fix #5: Islamabad Location Context Map
# Gives agents real-world knowledge about each sector so responses
# are grounded in actual geography instead of generic templates.
# ------------------------------------------------------------------ #

ISLAMABAD_CONTEXT = {
    "G-10": (
        "G-10 Markaz is a major commercial hub in Islamabad. "
        "Poly Clinic Hospital (PIMS annex) is inside G-10/3. Adjacent to Faizabad Interchange (connects to Rawalpindi). "
        "G-10 nullah (storm drain) runs through G-10/1 and frequently overflows during monsoon. "
        "CDA maintains drainage pumps at G-10/4 junction. Nearest fire station: Sector F-10 Fire Station (2.5 km). "
        "High-density residential + commercial. Population ~45,000. Schools: Islamabad Model College G-10, IMCG G-10."
    ),
    "F-8": (
        "F-8 Markaz is one of the oldest commercial areas. Located along Nazimuddin Road. "
        "F-8 Kachehri (courts complex) generates heavy daytime traffic. "
        "Nearest hospitals: Shifa International Hospital (F-8/1, 0.8 km), Quaid-e-Azam International Hospital (3 km). "
        "Jinnah Avenue runs along its southern edge — major 6-lane arterial road. "
        "Centaurus Mall is 1.5 km east. Heavy evening congestion. Population ~38,000. "
        "ITP traffic signals at F-8/Jinnah Avenue and F-8/Nazimuddin intersections."
    ),
    "Blue Area": (
        "Blue Area is Islamabad's central business district along Jinnah Avenue between sectors F-6 and G-6. "
        "Contains major banks (HBL, UBL, MCB headquarters), corporate offices, and federal government buildings. "
        "IESCO Grid-B supplies power; critical load area. Population: ~5,000 residents but 80,000+ daily workers. "
        "Nearest hospital: PIMS (Pakistan Institute of Medical Sciences, 3 km via Shakarparian). "
        "Stock Exchange building, Supreme Court nearby. Single main road (Jinnah Avenue) — "
        "any blockage causes cascading gridlock across F-6, F-7, G-6, G-7."
    ),
    "I-8": (
        "I-8 is a mixed-use sector bordering Faizabad. I-8 Markaz has heavy commercial activity. "
        "GT Road (Grand Trunk Road) traffic from Rawalpindi enters Islamabad through I-8. "
        "Heavy truck and trailer traffic. Industrial units in I-8/3 and I-8/4. "
        "Nullah runs through I-8/1 — high flood risk during monsoon. "
        "Nearest hospital: Ali Medical Centre I-8 Markaz, PIMS (5 km). "
        "CDA maintenance depot in I-8/2. Population ~40,000."
    ),
    "G-11": (
        "G-11 is adjacent to NUST University (National University of Sciences and Technology). "
        "Student population ~15,000 in surrounding hostels. G-11 Markaz is a busy commercial area. "
        "Single main entry/exit road creates bottleneck during peak hours. "
        "Nearest hospital: Quaid-e-Azam International (2 km), PIMS (6 km). "
        "Limited ambulance coverage — relies on Rescue 1122 Islamabad station in G-10. "
        "G-11/1 has several schools including Islamabad Model School. Population ~35,000."
    ),
    "F-6": (
        "F-6 (Super Market) is one of the busiest commercial hubs in Islamabad. "
        "Kohsar Market (F-6/3) is a high-end dining/shopping area. "
        "Heavy pedestrian traffic especially evenings and weekends. "
        "Nearest hospital: Kulsum International Hospital F-6/1 (0.5 km). "
        "Margalla Road runs along its northern edge — connects to Daman-e-Koh and Margalla Hills. "
        "Diplomatic enclave nearby. Population ~30,000."
    ),
    "F-7": (
        "F-7 Markaz (Jinnah Super Market) is the most popular commercial area in Islamabad. "
        "Extremely heavy foot traffic. Street food vendors and open-air market stalls. "
        "Parking congestion is chronic. Adjacent to F-7/4 residential (high density). "
        "Nearest hospital: Maroof International Hospital F-7 Markaz (0.2 km). "
        "Fire risk: high due to densely packed market stalls with gas cylinders. "
        "ITP deploys extra wardens here on weekends. Population ~32,000."
    ),
    "G-9": (
        "G-9 Markaz has Karachi Company (large commercial market). Heavy vehicular and pedestrian traffic. "
        "Nullah passes through G-9/1 — flooding during heavy rains. "
        "Nearest hospital: Federal Government Services Hospital G-9 (FGSH, 0.3 km). "
        "Adjacent to Kashmir Highway — major connector between sectors. "
        "CDA water supply tanker depot in G-9/4. Population ~42,000."
    ),
    "E-11": (
        "E-11 is a developing sector near Margalla Hills. MPCHS (Multi-Professional Cooperative Housing Society). "
        "Hilly terrain makes flood drainage problematic. Limited CDA infrastructure. "
        "Nearest hospital: Kulsoom International (4 km in F-6). "
        "Single access road from Margalla Avenue. Population ~20,000 (growing rapidly)."
    ),
    "Sector F-10": (
        "F-10 Markaz has moderate commercial activity. F-10 Fire Station serves F-8 through G-11. "
        "Faisal Mosque is 2 km north. Trail 5 hikers pass through frequently. "
        "Nearest hospital: Shifa International (2 km). Population ~28,000."
    ),
    "I-9": (
        "I-9 is a major industrial zone with factories, warehouses, and the Peshawar Mor interchange. "
        "Heavy goods vehicles (HGVs) dominate traffic. I-9 Industrial Area has chemical storage facilities — fire hazard. "
        "I-9/4 has CDA's main sewage treatment plant. Nullah from Margalla Hills passes through I-9/1. "
        "Nearest hospital: Pakistan Air Force Hospital (PAF, 3 km). Fire station: I-9 CDA Fire Station. "
        "Peshawar Mor Bus Rapid Transit (BRT) station handles 15,000+ daily commuters. Population ~30,000."
    ),
    "I-10": (
        "I-10 is a large industrial and residential sector. I-10 Markaz is a growing commercial hub. "
        "I-10/4 Industrial Area has manufacturing units and godowns (warehouses). "
        "Adjacent to Islamabad Expressway — major north-south arterial. "
        "Nearest hospital: National Institute of Rehabilitation Medicine (NIRM, 2 km). "
        "CDA water supply reservoir in I-10/1. Population ~50,000. Multiple schools in I-10/1 and I-10/2."
    ),
    "G-6": (
        "G-6 is adjacent to Blue Area CBD. Aabpara Market (G-6/1) is a historic commercial area. "
        "ISI headquarters and several federal government buildings located here. "
        "Heavy security presence. Melody Market (G-6/3) has dense commercial activity. "
        "Nearest hospital: PIMS (2 km). Jinnah Avenue southern boundary. "
        "Aabpara chowk is a major traffic intersection. Population ~25,000."
    ),
    "G-7": (
        "G-7 Markaz (Sitara Market) has moderate commercial activity. Adjacent to Jinnah Avenue. "
        "Pakistan Post headquarters and several government offices located here. "
        "G-7/2 has the CDA headquarters building. G-7/3 connects to Shakarparian hills. "
        "Nearest hospital: PIMS (1.5 km via Shakarparian Road). Population ~28,000."
    ),
    "G-8": (
        "G-8 Markaz has busy commercial activity. Located along Kashmir Highway. "
        "G-8/4 has Allama Iqbal Open University (AIOU) campus — large student population. "
        "Nearest hospital: Federal Government Polyclinic (FGPC, 1.5 km in G-10). "
        "Kashmir Highway creates high-speed traffic risk along G-8 boundary. Population ~40,000."
    ),
    "F-11": (
        "F-11 is an upscale residential sector near Margalla Hills foothills. "
        "F-11 Markaz has premium commercial outlets. Adjacent to E-11 and Margalla Avenue. "
        "Hilly terrain — landslide risk during heavy monsoon. Limited public transport access. "
        "Nearest hospital: Shifa International (3 km). Population ~22,000."
    ),
    "E-7": (
        "E-7 is a high-end residential sector housing diplomats and senior officials. "
        "Adjacent to Margalla Hills National Park — wildlife and hiking trails. "
        "Trail 3 and Trail 5 entry points nearby. Low commercial activity. "
        "Nearest hospital: Kulsum International (2 km in F-6). Limited CDA drainage. Population ~12,000."
    ),
    "H-8": (
        "H-8 contains the Quaid-e-Azam University (QAU) campus — 10,000+ students. "
        "Also houses COMSATS University Islamabad campus. Heavy student commuter traffic. "
        "H-8/4 has NUST H-12 campus access road. Adjacent to Islamabad Expressway. "
        "Nearest hospital: Quaid-e-Azam International Hospital H-8 (on-site). Population ~18,000 + students."
    ),
    "H-9": (
        "H-9 has the Centaurus Mall and Residencia complex — Islamabad's largest shopping centre. "
        "Extremely heavy vehicular traffic especially on weekends. Multi-level parking congestion. "
        "H-9 connects to Jinnah Avenue and Islamabad Expressway via service roads. "
        "Nearest hospital: Islamabad International Hospital (1 km). Population ~15,000."
    ),
    "D-12": (
        "D-12 is a developing sector in north Islamabad near Margalla Hills. "
        "D-12 connects to Murree Road via sector D-17 corridor. Hilly undulating terrain. "
        "Limited CDA infrastructure — water supply issues. New housing societies under construction. "
        "Nearest hospital: PIMS (8 km). Fire station coverage: F-10 station (6 km). Population ~10,000."
    ),
    "Rawat": (
        "Rawat is an industrial town on the eastern edge of Islamabad near GT Road. "
        "Heavy industrial activity including oil depots and factories — fire and chemical spill risk. "
        "GT Road connects to Rawalpindi and Lahore. High truck traffic volume. "
        "Nearest hospital: THQ Hospital Rawat. Rescue 1122 sub-station present. Population ~60,000."
    ),
    "Bhara Kahu": (
        "Bhara Kahu is a peri-urban town on Murree Road at the northern edge of Islamabad. "
        "Gateway to Murree hill station — extremely heavy tourist traffic on weekends and holidays. "
        "Narrow winding roads. Flash flood risk from Margalla Hills runoff during monsoon. "
        "Nearest hospital: Bhara Kahu Rural Health Centre, PIMS (12 km). Population ~45,000."
    ),
    "Tarnol": (
        "Tarnol is a western suburb along GT Road with a major railway station (Islamabad West). "
        "Industrial units and brick kilns in surrounding area. Railway crossing causes traffic bottlenecks. "
        "Low-income residential area with limited drainage infrastructure. "
        "Nearest hospital: Railway Hospital Rawalpindi (5 km). Population ~35,000."
    ),
    "Golra Sharif": (
        "Golra Sharif is a historic town in western Islamabad with the Golra Sharif shrine. "
        "Famous heritage railway station (now museum). Large religious gatherings create crowd management challenges. "
        "Adjacent to Peshawar Mor interchange. Limited modern infrastructure. "
        "Nearest hospital: HBS Hospital (2 km). Population ~30,000."
    ),
    "Faizabad": (
        "Faizabad is a critical interchange connecting Islamabad and Rawalpindi via Murree Road. "
        "One of the busiest intersections in the twin cities — handles 100,000+ vehicles daily. "
        "Faizabad Interchange connects Kashmir Highway, Murree Road, and IJP Road. "
        "Any blockage here paralyses traffic across both cities. Protest hotspot. "
        "Nearest hospital: PIMS (3 km), Benazir Bhutto Hospital Rawalpindi (4 km). "
        "ITP and Rawalpindi Traffic Police joint jurisdiction."
    ),
    "Soan Garden": (
        "Soan Garden is a residential cooperative housing society in Zone IV. "
        "Adjacent to Islamabad Expressway. Limited CDA maintenance — relies on society management. "
        "Narrow internal roads. Single main entry/exit gate creates bottleneck. "
        "Nearest hospital: Islamabad International Hospital (3 km). Population ~20,000."
    ),
    "PWD Housing Society": (
        "PWD (Pakistan Public Works Department) Housing Society is a large residential area near Rawat. "
        "High population density. Adjacent to Islamabad Expressway and Rawat industrial zone. "
        "Frequent water supply issues. Internal roads prone to waterlogging. "
        "Nearest hospital: Shifa International Satellite Clinic (2 km). Population ~55,000."
    ),
    "DHA Islamabad": (
        "Defence Housing Authority (DHA) Islamabad is a premium planned community in Zone V. "
        "Phase I and II are developed. Well-maintained roads and infrastructure. "
        "Own fire brigade and security. Adjacent to GT Road and Islamabad Expressway. "
        "DHA Medical Centre on-site. Nearest major hospital: CMH Rawalpindi (8 km). Population ~40,000."
    ),
    "Bahria Town Islamabad": (
        "Bahria Town is Pakistan's largest private housing scheme on GT Road near Rawat. "
        "Self-contained with own hospital (Bahria International Hospital), fire brigade, and security. "
        "Single main gate access creates severe congestion during peak hours. "
        "Internal road network is extensive but isolated from city grid. Population ~100,000+."
    ),
}

DEFAULT_CONTEXT = (
    "General Islamabad sector. Nearest emergency services: Rescue 1122 (dial 1122), "
    "Police (dial 15), Fire Brigade (dial 16). Nearest major hospital: PIMS or Shifa International."
)


class CIROPipeline:
    """Runtime agent orchestrator using Gemini 2.5 Flash."""

    def __init__(self):
        self.agent_trace: list[AgentMessage] = []
        settings = get_settings()
        
        vertex_project = os.environ.get("GEMINI_VERTEX_PROJECT")
        if vertex_project:
            self.client = genai.Client(
                vertexai=True,
                project=vertex_project,
                location=os.environ.get("GEMINI_VERTEX_LOCATION", "asia-south1")
            )
        else:
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

    @async_retry
    async def run_sensor_agent(self, raw_signals: list[dict]) -> list[CrisisSignal]:
        prompt = f"Raw Signals: {json.dumps(raw_signals)}\n\nNormalise these crisis signals into a structured JSON list of CrisisSignal objects."
        
        sys_instruct = (
            "You are a Sensor Agent operating in Islamabad, Pakistan — a metropolitan of 2.5 million people "
            "divided into lettered/numbered sectors (F-6, G-10, I-8, Blue Area, etc.).\n\n"
            "YOUR TASK: Normalise noisy, informal crisis signals into structured CrisisSignal JSON objects.\n\n"
            "LANGUAGE HANDLING:\n"
            "- Signals may arrive in Roman Urdu (Urdu written in English letters). Common examples:\n"
            "  'pani bhar gaya' = water has flooded, 'bijli gayi' = power gone, 'aag lag gayi' = fire broke out,\n"
            "  'sadak band' = road blocked, 'gaari ka accident' = car accident, 'rasta jam' = traffic jam,\n"
            "  'baarish' = rain, 'nala' = storm drain, 'gutter overflow' = sewage overflow\n"
            "- Translate the meaning but preserve the original text in the 'text' field.\n\n"
            "SEVERITY INFERENCE (this is critical — do NOT default to 3):\n"
            "- Level 1: Minor/routine — 'thodi baarish', 'halka jam', 'choti si problem'\n"
            "- Level 2: Noticeable — 'pani jama ho raha hai', 'traffic slow hai'\n"
            "- Level 3: Significant — 'sadak band hai', 'bijli nahi aa rahi', 'accident hua'\n"
            "- Level 4: Severe — 'log phanse hain', 'pani ghar mein aa gaya', 'bohot bura accident'\n"
            "- Level 5: Critical/Life-threatening — 'log doob rahe hain', 'aag phayl gayi', 'mayyat', 'fatalities'\n\n"
            "CRISIS TYPE MAPPING:\n"
            "- Urban Flooding: pani, baarish, nala overflow, doob, flood, sewer\n"
            "- Severe Accident: accident, crash, takkar, zakhmi, injured, collision\n"
            "- Power Infrastructure: bijli, light, WAPDA, IESCO, transformer, blackout, generator\n"
            "- Fire Hazard: aag, fire, dhuaan (smoke), jalaa, cylinder blast, short circuit\n"
            "- Traffic Gridlock: jam, rasta band, traffic, road blocked, congestion\n\n"
            "You MUST use explicit Chain-of-Thought reasoning in reasoning_steps BEFORE generating output. "
            "Explain: (1) what language the signal is in, (2) how you inferred the crisis type, "
            "(3) why you assigned that specific severity level."
        )
        
        response = await asyncio.to_thread(
            self.client.models.generate_content,
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

    @async_retry
    async def run_analyst_agent(self, signals: list[CrisisSignal]) -> DetectedCrisis:
        signals_json = [s.model_dump() for s in signals]
        prompt = f"Normalised Signals: {json.dumps(signals_json)}\n\nAnalyse these CrisisSignal objects and produce a DetectedCrisis assessment."
        
        sys_instruct = (
            "You are an Analyst Agent — a crisis intelligence specialist for Islamabad metropolitan area.\n\n"
            "YOUR TASK: Analyse normalised CrisisSignal objects and produce a single DetectedCrisis verdict.\n\n"
            "ANALYSIS FRAMEWORK:\n"
            "1. SIGNAL CORRELATION: Look at all signals together. Multiple reports from the same area = higher confidence. "
            "Mixed crisis types from same location may indicate cascading crisis (e.g., flooding → traffic → power outage).\n"
            "2. SEVERITY ASSESSMENT using Pakistan NDMA (National Disaster Management Authority) scale:\n"
            "   - Level 1-2: Localised, manageable with existing resources\n"
            "   - Level 3: District-level response needed, CDA/RDA involvement\n"
            "   - Level 4: Multi-agency coordination required (NDMA, military, hospitals)\n"
            "   - Level 5: Life-threatening emergency, full national response protocol\n"
            "3. CONFIDENCE SCORING:\n"
            "   - 0.50-0.65: Single unverified source\n"
            "   - 0.65-0.80: Multiple reports but unconfirmed\n"
            "   - 0.80-0.90: Cross-source verification (social media + sensor + user reports)\n"
            "   - 0.90-0.99: Confirmed by official sources or overwhelming signal volume\n"
            "4. CRISIS TYPE must be one of: Urban Flooding, Severe Accident, Power Infrastructure, Fire Hazard, Traffic Gridlock\n\n"
            "REASONING FIELD: Write a detailed 2-3 sentence explanation of your assessment. "
            "Mention specific signal texts that influenced your verdict. "
            "Do NOT use generic language like 'based on the signals received'.\n\n"
            "Chain-of-Thought: Document your full reasoning in reasoning_steps array. "
            "Show your analytical process — signal grouping, severity derivation, confidence calculation."
        )
        
        response = await asyncio.to_thread(
            self.client.models.generate_content,
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
                response_mime_type="application/json",
                response_schema=AnalystAgentOutput,
                temperature=0.5,
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

    @async_retry
    async def run_coordinator_agent(self, crisis: DetectedCrisis) -> list[ResponseAction]:
        # Fix #5: Inject real location context
        location_info = ISLAMABAD_CONTEXT.get(crisis.location, DEFAULT_CONTEXT)
        
        prompt = (
            f"Detected Crisis: {json.dumps(crisis.model_dump())}\n"
            f"Location Intelligence: {location_info}\n\n"
            f"Given this crisis and location context, generate a prioritised action plan "
            f"with 3-5 ResponseAction objects. Each action MUST reference specific Islamabad "
            f"agencies, hospitals, roads, or landmarks from the location intelligence."
        )
        
        sys_instruct = (
            "You are a Coordinator Agent — the emergency response planner for Islamabad Capital Territory.\n\n"
            "You MUST generate FUNDAMENTALLY DIFFERENT action plans based on the crisis type. "
            "Do NOT produce generic 'dispatch + reroute + alert' for every crisis.\n\n"
            "CRISIS-SPECIFIC RESPONSE PROTOCOLS:\n\n"
            "🌊 URBAN FLOODING:\n"
            "  P1: Deploy CDA dewatering pumps to flooded nullahs. Contact WASA (Water and Sanitation Agency) "
            "      for emergency drain clearance. If water > 2 feet, request NDMA rescue boats.\n"
            "  P2: Activate flood relief camps at nearest government schools/colleges. "
            "      Distribute clean water (bore water may be contaminated). Contact PHA (Parks dept) for tree clearance.\n"
            "  P3: Issue SMS flood warnings via PTA emergency broadcast. Post on CDA Twitter. "
            "      Alert Rescue 1122 for stranded citizens. Close underpasses (IJP Road, Faizabad, 9th Avenue).\n\n"
            "🚗 SEVERE ACCIDENT:\n"
            "  P1: Dispatch Rescue 1122 ambulances from nearest station. Notify nearest Level-1 trauma centre "
            "      (PIMS Emergency, Shifa ER, or Holy Family Hospital Rawalpindi). "
            "      If multiple casualties, activate Mass Casualty Protocol — call for blood bank mobilisation.\n"
            "  P2: Deploy ITP (Islamabad Traffic Police) for scene perimeter. "
            "      Request Motorway Police if on highway. Set up on-scene triage (red/yellow/green tagging).\n"
            "  P3: Reroute traffic via alternate corridors. Push Google Maps incident alert. "
            "      Notify NHMP (National Highway and Motorway Police) if expressway involved.\n\n"
            "⚡ POWER INFRASTRUCTURE:\n"
            "  P1: Contact IESCO (Islamabad Electric Supply Company) control room at their 24/7 helpline (118). "
            "      Identify which grid/feeder is affected. If transformer explosion, dispatch fire brigade.\n"
            "  P2: Deploy mobile generators to critical facilities — hospitals, water pumping stations, "
            "      traffic signals. Coordinate with hospital UPS battery backup teams.\n"
            "  P3: Issue estimated restoration time via IESCO social media. Alert citizens to unplug "
            "      sensitive electronics. Notify PEPCO (Pakistan Electric Power Company) if grid-wide.\n\n"
            "🔥 FIRE HAZARD:\n"
            "  P1: Dispatch fire brigade from nearest CDA fire station (F-10 station covers F-7 to G-11, "
            "      I-9 station covers I-8 to I-11). If market fire, request additional tenders. "
            "      Cut gas supply — contact SNGPL (Sui Northern Gas) emergency line.\n"
            "  P2: Evacuate 500m radius. Establish burn treatment staging area. "
            "      Alert Pakistan Burn Centre at PIMS and DHQ Rawalpindi. Close gas mains.\n"
            "  P3: Issue evacuation advisory via mosque loudspeakers and PTA broadcast. "
            "      Deploy crowd control via ITP. Notify CDA building inspection for structural assessment.\n\n"
            "🚦 TRAFFIC GRIDLOCK:\n"
            "  P1: Activate ITP signal override at congested intersections. "
            "      Deploy traffic wardens with hand signals at key junctions.\n"
            "  P2: Push real-time reroute advisory via Google Maps / Waze incident reports. "
            "      Open service roads and alternative routes (Kashmir Highway, Margalla Road, Park Road).\n"
            "  P3: Notify Metro Bus Authority if bus routes affected. "
            "      Alert university/school administrations to stagger dismissal times.\n\n"
            "IMPORTANT RULES:\n"
            "- Use REAL Islamabad agency names, hospital names, road names from the Location Intelligence.\n"
            "- Each action description must be SPECIFIC to this crisis, not copy-paste templates.\n"
            "- Generate 3-5 actions with proper P1/P2/P3 priority spread.\n"
            "- Include estimated response times in estimated_impact field.\n\n"
            "Chain-of-Thought: Document in reasoning_steps:\n"
            "1. Which crisis-specific protocol you are activating and why.\n"
            "2. Which specific agencies/hospitals you selected based on location proximity.\n"
            "3. Why you prioritised each action at its level."
        )
        
        response = await asyncio.to_thread(
            self.client.models.generate_content,
            model=self.model_name,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
                response_mime_type="application/json",
                response_schema=CoordinatorAgentOutput,
                temperature=0.7,
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

    @async_retry
    async def run_simulator_agent(self, actions: list[ResponseAction]) -> list[SimulationResult]:
        actions_json = [a.model_dump() for a in actions]
        
        sys_instruct = (
            "You are a Simulator Agent for Islamabad emergency response. "
            "You MUST use the calculate_simulation_metrics tool to simulate the execution "
            "of EACH response action. Call the tool once per action with the action_type and location.\n\n"
            "After receiving tool results, analyse them and return the final SimulatorAgentOutput. "
            "In reasoning_steps, explain:\n"
            "1. What each tool call returned (before/after states).\n"
            "2. Which actions had the highest impact and why.\n"
            "3. Any cascading effects (e.g., rerouting traffic also reduces accident risk).\n"
            "4. Overall effectiveness assessment of the response plan."
        )

        chat = await asyncio.to_thread(
            self.client.chats.create,
            model=self.model_name,
            config=types.GenerateContentConfig(
                system_instruction=sys_instruct,
                temperature=0.6,
                tools=[calculate_simulation_metrics]
            )
        )
        
        # Step 1: Ask the agent to use the tools
        prompt = f"Response Actions: {json.dumps(actions_json)}\n\nPlease call the tool to simulate the execution of these actions."
        response = await asyncio.to_thread(chat.send_message, prompt)
        
        # Step 2: If the model called tools, execute them and send results back
        actual_tool_results = []
        if response.function_calls:
            function_responses = []
            for function_call in response.function_calls:
                if function_call.name == "calculate_simulation_metrics":
                    action_type = function_call.args.get("action_type", "")
                    location = function_call.args.get("location", "")
                    # Execute our actual Python function
                    result_dict = calculate_simulation_metrics(action_type, location)
                    actual_tool_results.append(result_dict)
                    
                    function_responses.append(
                        types.Part.from_function_response(
                            name="calculate_simulation_metrics",
                            response={"result": result_dict}
                        )
                    )
            
            # Send the tool output back to the model
            response = await asyncio.to_thread(chat.send_message, types.Content(parts=function_responses))
            
        # Step 3: Now ask the model to format its findings into the final structured JSON
        final_response = await asyncio.to_thread(
            chat.send_message,
            "Great. Now, based on the simulation results you received, output the final JSON matching the SimulatorAgentOutput schema.",
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=SimulatorAgentOutput,
            )
        )
        
        output: SimulatorAgentOutput = final_response.parsed
        
        # We need to map the action IDs back properly and inject the real states
        if len(output.results) == len(actions):
            for i, res in enumerate(output.results):
                res.action_id = actions[i].id
                if i < len(actual_tool_results):
                    res.before_state = actual_tool_results[i].get("before_state", {})
                    res.after_state = actual_tool_results[i].get("after_state", {})
                    # Ensure execution_log is exactly what the tool provided
                    res.execution_log = actual_tool_results[i].get("execution_log", [])
        
        self.agent_trace.append(
            AgentMessage(
                agent_name="Simulator Agent",
                input_summary=f"Simulating {len(actions)} response actions via Tool Execution",
                output_summary=f"Completed {len(output.results)} simulations using calculate_simulation_metrics tool",
                reasoning_steps=output.reasoning_steps,
            )
        )
        return output.results
