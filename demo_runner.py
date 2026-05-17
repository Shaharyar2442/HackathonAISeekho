import os
import sys
import json
import argparse
from datetime import datetime

# Add parent directory to path to find models.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from models import CrisisSignal, AgentMessage
from signal_processor import SignalNormalizer, SensorAgentLogger
from signal_aggregator import CrisisScorer, CrisisAssessment

# ─────────────────────────────────────────────────────────────────────────────
# 1. ScenarioLoader
# ─────────────────────────────────────────────────────────────────────────────

class ScenarioLoader:
    """Loads scenarios from scenarios.json and converts signal dicts to CrisisSignal objects."""
    
    @staticmethod
    def load() -> dict:
        path = os.path.join(os.path.dirname(__file__), "scenarios.json")
        with open(path, "r") as f:
            data = json.load(f)
            
        scenarios = {}
        for entry in data:
            sid = entry["scenario_id"]
            # Convert signal dicts to CrisisSignal objects
            entry["signals"] = [CrisisSignal(**s) for s in entry["signals"]]
            scenarios[sid] = entry
            
        return scenarios

# ─────────────────────────────────────────────────────────────────────────────
# 2. DemoRunner
# ─────────────────────────────────────────────────────────────────────────────

class DemoRunner:
    """Runs a simulated CIRO demo for a specific scenario."""
    
    def __init__(self):
        self.scenarios = ScenarioLoader.load()
        self.normalizer = SignalNormalizer()
        self.logger = SensorAgentLogger()
        self.scorer = CrisisScorer()

    def run(self, scenario_id: str) -> list[AgentMessage]:
        scenario = self.scenarios.get(scenario_id)
        if not scenario:
            print(f"Error: Scenario {scenario_id} not found.")
            return []

        # Print Header Box
        print("\n╔" + "═" * 54 + "╗")
        header_text = f"  CIRO DEMO — Scenario {scenario_id}: {scenario['name']}"
        print(f"║{header_text:<54}║")
        meta_text = f"  Zone: {scenario['zone']}  |  Signals: {len(scenario['signals'])}  |  {scenario['description']}"
        print(f"║{meta_text:<54}║")
        print("╚" + "═" * 54 + "╝")

        all_agent_messages = []
        processed_signals = []
        
        # Iterate through signals
        for i, raw_signal in enumerate(scenario["signals"]):
            # 1. Normalize
            processed_signal, reasoning = self.normalizer.normalize(raw_signal.text, raw_signal.location)
            
            # 2. Log
            agent_msg = self.logger.log(raw_signal.text, processed_signal, reasoning)
            all_agent_messages.append(agent_msg)
            
            # 3. Score (running total)
            processed_signals.append(processed_signal)
            assessment = self.scorer.score(processed_signals)
            
            # 4. Print Row
            print("─" * 56)
            row_header = f"[Signal {i+1:02d}/10] | Severity: {processed_signal.severity} | Running Prob: {assessment.crisis_probability} | Trend: {assessment.trend}"
            print(row_header)
            print(f"Text: \"{raw_signal.text}\"")
            print(f"Agent: {agent_msg.agent_name} → {agent_msg.output_summary}")
            
            # Reasoning: Truncate to first 2 steps and join with |
            display_reasoning = " | ".join(reasoning[:2])
            print(f"Reasoning: {display_reasoning}")

        # Final Assessment Logic
        dominant_type = self._get_dominant_type(processed_signals)
        confidence = round(assessment.crisis_probability * 100)
        actions = self._get_recommended_actions(dominant_type)

        # Print Final Assessment Box
        print("\n┌" + "─" * 53 + "┐")
        print("│  FINAL CRISIS ASSESSMENT                            │")
        print(f"│  Type: {dominant_type:<15} Location: {scenario['zone']:<17} │")
        print(f"│  Severity: {assessment.severity_level}/5        Confidence: {confidence}%               │")
        print(f"│  Trend: {assessment.trend:<13} Signals processed: {len(processed_signals):<10} │")
        print("│  Actions recommended:                               │")
        for act in actions:
            print(f"│    • {act:<46} │")
        print("└" + "─" * 53 + "┘")

        return all_agent_messages

    def _get_dominant_type(self, signals: list[CrisisSignal]) -> str:
        counts = {}
        for s in signals:
            counts[s.crisis_type] = counts.get(s.crisis_type, 0) + 1
        return max(counts, key=counts.get) if counts else "Unknown"

    def _get_recommended_actions(self, crisis_type: str) -> list[str]:
        mapping = {
            "Flood": ["P1: Traffic Reroute — redirect via alt routes", 
                      "P2: Emergency Dispatch — send rescue teams", 
                      "P3: Citizen Alert — notify G-10 residents"],
            "Accident": ["P1: Emergency Dispatch — send rescue teams", 
                         "P2: Traffic Reroute — redirect via alt routes", 
                         "P3: Medical Alert — notify nearest hospitals"],
            "Power Outage": ["P1: WAPDA Notification — report grid failure", 
                             "P2: Backup Power Activation — switch to generators", 
                             "P3: Citizen Alert — provide restoration ETA"],
            "Fire": ["P1: Fire Brigade Dispatch — send trucks immediately", 
                     "P2: Evacuation Alert — clear affected buildings", 
                     "P3: Traffic Reroute — clear emergency lanes"],
            "Traffic": ["P1: Traffic Reroute — redirect via alt routes", 
                        "P2: Signal Control — adjust signal timings", 
                        "P3: Commuter Alert — broadcast traffic delay"]
        }
        return mapping.get(crisis_type, ["P1: Standard Response", "P2: Monitoring", "P3: Status Update"])

# ─────────────────────────────────────────────────────────────────────────────
# 3. Main Entry Point
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CIRO Demo Runner")
    parser.add_argument("--scenario", choices=["A", "B", "C"], required=True,
                        help="Scenario to run: A (G-10 Flood), B (F-8 Accident), C (Blue Area Outage)")
    args = parser.parse_args()

    runner = DemoRunner()
    agent_messages = runner.run(args.scenario)

    print(f"\n[DemoRunner] Completed. {len(agent_messages)} AgentMessage(s) generated.")
    print(f"[DemoRunner] Run: python demo_runner.py --scenario {args.scenario}")
