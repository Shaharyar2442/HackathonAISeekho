import os
import sys
import json
from datetime import datetime

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from models import AgentMessage, CrisisSignal
from demo_runner import DemoRunner, ScenarioLoader

TRACES_DIR = os.path.join(os.path.dirname(__file__), "agent_traces")
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "agent_reasoning.txt")

if __name__ == "__main__":
    trace_a_path = os.path.join(TRACES_DIR, "trace_A.json")
    if not os.path.exists(trace_a_path):
        raise FileNotFoundError(
            "trace_A.json not found. Run trace_exporter.py first."
        )

    total_reasoning_steps = 0
    scenarios_count = 0
    
    with open(OUTPUT_PATH, "w") as out_f:
        for scenario_id in ["A", "B", "C"]:
            trace_path = os.path.join(TRACES_DIR, f"trace_{scenario_id}.json")
            if not os.path.exists(trace_path):
                continue
                
            with open(trace_path, "r") as f:
                trace = json.load(f)
                
            scenarios_count += 1
            
            out_f.write("═══════════════════════════════════════════════════════════\n")
            out_f.write(f"SCENARIO {scenario_id}: {trace['scenario_name']}\n")
            out_f.write(f"Zone: {trace['zone']}  |  Signals Processed: {trace['signals_processed']}  |  Generated: {trace['generated_at']}\n")
            out_f.write("═══════════════════════════════════════════════════════════\n\n")
            
            out_f.write("AGENT REASONING STEPS:\n")
            for i, step in enumerate(trace["reasoning_steps"], 1):
                out_f.write(f" {i:>2}. {step}\n")
                total_reasoning_steps += 1
                
            out_f.write("\nRECOMMENDED ACTIONS:\n")
            for action in trace["actions_recommended"]:
                out_f.write(f"  [{action['priority']}] {action['action_type']} — {action['description']}\n")
                
            out_f.write("\nAGENT MESSAGES SUMMARY:\n")
            for i, msg in enumerate(trace["agent_messages"], 1):
                out_f.write(f"  Message {i:02d} | {msg['agent_name']} | {msg['output_summary']}\n")
                
            confidence_pct = round(trace["crisis_detected"]["confidence"] * 100)
            
            out_f.write("\n┌─────────────────────────────────────────────────────────┐\n")
            out_f.write(f"│  FINAL DECISION                                         │\n")
            out_f.write(f"│  Crisis Type : {trace['crisis_detected']['type']:<18} Location : {trace['crisis_detected']['location']:<13} │\n")
            out_f.write(f"│  Confidence  : {confidence_pct}%{(' ' * 16)} Signals  : {trace['signals_processed']:<11} │\n")
            out_f.write("└─────────────────────────────────────────────────────────┘\n")
            
            if scenario_id != "C":
                out_f.write("\n\n")

    print(f"[ReadableTrace] Saved agent_reasoning.txt — {scenarios_count} scenarios, {total_reasoning_steps} total reasoning steps")
