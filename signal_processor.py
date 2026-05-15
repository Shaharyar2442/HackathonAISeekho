import json
import random
import os
import sys
from datetime import datetime
from typing import List, Optional

# Add parent directory to path to find models.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from models import CrisisSignal, AgentMessage
# Load dataset from JSON
DATA_PATH = os.path.join(os.path.dirname(__file__), "crisis_data.json")
with open(DATA_PATH, "r") as f:
    CRISIS_DATA = json.load(f)

LOCATIONS = CRISIS_DATA["LOCATIONS"]
CRISIS_TEMPLATES = CRISIS_DATA["CRISIS_TEMPLATES"]
SEVERITY_UP = CRISIS_DATA["SEVERITY_UP"]
SEVERITY_DOWN = CRISIS_DATA["SEVERITY_DOWN"]
SCENARIO_TEXTS = CRISIS_DATA["SCENARIO_TEXTS"]
SCENARIO_META = CRISIS_DATA["SCENARIO_META"]


# ─────────────────────────────────────────────────────────────────────────────
# 1. MockDataGenerator
# ─────────────────────────────────────────────────────────────────────────────

class MockDataGenerator:
    """Generates realistic CrisisSignal objects for Islamabad."""

    def __init__(self):
        # We'll use the imported CRISIS_TEMPLATES and LOCATIONS
        pass

    def generate(self, count: int = 20) -> List[CrisisSignal]:
        """Generate count realistic CrisisSignal objects."""
        signals = []
        
        # Flatten templates for sampling
        all_templates = []
        for c_type, templates in CRISIS_TEMPLATES.items():
            for t in templates:
                # Map internal keys to properly capitalized CrisisSignal types
                display_type = c_type.capitalize()
                if display_type == "Outage": display_type = "Power Outage"
                all_templates.append((display_type, t))

        # Sample with replacement if count > templates
        if count > len(all_templates):
            samples = random.choices(all_templates, k=count)
        else:
            samples = random.sample(all_templates, k=count)

        for crisis_type, text in samples:
            # Determine source
            source = random.choice(["social_media", "sensor"])
            
            # Find location in text or pick random
            location = next((loc for loc in LOCATIONS if loc in text), random.choice(LOCATIONS))
            
            # Basic severity inference for mock data
            severity = 3
            if any(word in text.lower() for word in SEVERITY_UP): severity = 5
            if any(word in text.lower() for word in SEVERITY_DOWN): severity = 1

            signals.append(CrisisSignal(
                text=text,
                location=location,
                crisis_type=crisis_type,
                severity=severity,
                source=source
            ))
            
        return signals


# ─────────────────────────────────────────────────────────────────────────────
# 2. SignalNormalizer
# ─────────────────────────────────────────────────────────────────────────────

class SignalNormalizer:
    """Normalizes raw text into CrisisSignal objects."""

    def normalize(self, text: str, location: str) -> tuple[CrisisSignal, List[str]]:
        """Extracts fields and returns a (CrisisSignal, reasoning) tuple."""
        text_lower = text.lower()
        reasoning = []

        # 1. Crisis Type Extraction (Using JSON keywords)
        crisis_type = "Traffic"  # Default
        display_names = {
            "flood": "Flood", 
            "accident": "Accident", 
            "outage": "Power Outage", 
            "fire": "Fire", 
            "traffic": "Traffic"
        }
        
        found_type = False
        for key, keywords in CRISIS_DATA["CRISIS_KEYWORDS"].items():
            for kw in keywords:
                if kw in text_lower:
                    crisis_type = display_names.get(key, key.capitalize())
                    reasoning.append(f"Keyword '{kw}' detected → crisis_type set to {crisis_type}")
                    found_type = True
                    break
            if found_type: break
        
        if not found_type:
            reasoning.append("No specific keywords found → crisis_type defaulted to Traffic")

        # 2. Severity Scoring
        severity = 2  # Default
        reasoning.append("Initial severity set to default 2")
        
        for word in SEVERITY_UP:
            if word in text_lower:
                severity = min(5, severity + 1)
                reasoning.append(f"Urgent word '{word}' detected → severity incremented to {severity}")
        
        for word in SEVERITY_DOWN:
            if word in text_lower:
                severity = max(1, severity - 1)
                reasoning.append(f"Mild word '{word}' detected → severity decremented to {severity}")

        # 3. Create Signal
        signal = CrisisSignal(
            text=text,
            location=location,
            crisis_type=crisis_type,
            severity=severity,
            source="user_report"
        )
        
        return signal, reasoning


# ─────────────────────────────────────────────────────────────────────────────
# 3. SensorAgentLogger
# ─────────────────────────────────────────────────────────────────────────────

class SensorAgentLogger:
    """Generates trace logs for the Sensor Agent."""

    def log(self, raw_text: str, signal: CrisisSignal, reasoning: List[str]) -> AgentMessage:
        """Creates an AgentMessage describing the processing step."""
        return AgentMessage(
            agent_name="Sensor Agent",
            input_summary=f"Received raw text: '{raw_text}'",
            output_summary=f"Produced {signal.crisis_type} signal for {signal.location} (Severity: {signal.severity})",
            reasoning_steps=reasoning
        )


# ─────────────────────────────────────────────────────────────────────────────
# 4. Scenario Support
# ─────────────────────────────────────────────────────────────────────────────

def save_scenarios():
    """Generates and saves the 3 requested scenarios to scenarios.json."""
    normalizer = SignalNormalizer()
    
    scenarios = []
    
    # Mapping scenario IDs to their requirements
    configs = [
        ("A", "G-10 Flooding", "G-10", "Escalating flood emergency", [1,1,2,2,3,3,4,4,5,5]),
        ("B", "F-8 Accident", "F-8", "Sudden spike road accident", [5,5,4,4,3,3,3,2,2,1]),
        ("C", "Blue Area power outage", "Blue Area", "Stable power outage", [3,3,3,3,3,2,3,3,3,3])
    ]

    for sid, name, zone, desc, severities in configs:
        signals = []
        # Get base texts for this scenario type from crisis_data
        base_texts = SCENARIO_TEXTS.get(sid, [("Generic crisis", 3)] * 10)
        
        for i in range(10):
            text, _ = base_texts[i] if i < len(base_texts) else base_texts[-1]
            # Create signal using normalizer logic then force the requested severity
            sig, _ = normalizer.normalize(text, zone)
            sig.severity = severities[i]
            signals.append(sig.model_dump())
            
        scenarios.append({
            "scenario_id": sid,
            "name": name,
            "zone": zone,
            "description": desc,
            "signals": signals
        })

    with open("scenarios.json", "w") as f:
        json.dump(scenarios, f, indent=4)
    print("[ScenarioBuilder] Saved 3 scenarios to scenarios.json")


# ─────────────────────────────────────────────────────────────────────────────
# 5. Main Entry Point
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # 1. MockDataGenerator Test
    print("\n" + "="*50)
    print("1. MockDataGenerator Sample Signals")
    print("="*50)
    generator = MockDataGenerator()
    samples = generator.generate(count=5)
    for s in samples:
        print(f"[{s.source}] {s.location}: {s.crisis_type} (Sev: {s.severity}) | {s.text}")

    # 2. SignalNormalizer Test
    print("\n" + "="*50)
    print("2. SignalNormalizer Extraction (Roman Urdu)")
    print("="*50)
    normalizer = SignalNormalizer()
    test_texts = [
        ("G-10 mein pani bhar gaya hai", "G-10"),
        ("F-8 mein bara accident hua hai", "F-8"),
        ("Blue Area mein bijli nahi hai", "Blue Area")
    ]
    
    processed_signals = []
    reasoning_logs = []
    for txt, loc in test_texts:
        sig, reasoning = normalizer.normalize(txt, loc)
        processed_signals.append(sig)
        reasoning_logs.append(reasoning)
        print(f"Input: '{txt}' -> {sig.crisis_type}, Sev: {sig.severity}")

    # 3. SensorAgentLogger Test
    print("\n" + "="*50)
    print("3. SensorAgentLogger Trace (AgentMessage)")
    print("="*50)
    logger = SensorAgentLogger()
    msg = logger.log(test_texts[0][0], processed_signals[0], reasoning_logs[0])
    print(f"Agent: {msg.agent_name}")
    print(f"Summary: {msg.output_summary}")
    print("Reasoning Steps:")
    for step in msg.reasoning_steps:
        print(f" - {step}")

    # 4. Save Scenarios
    print("\n" + "="*50)
    save_scenarios()
    print("="*50 + "\n")
