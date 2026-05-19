# CIRO Phase 3: Scenario-Based Demo Runner

## 🚀 Overview
Phase 3 of the CIRO (Crisis Intelligence & Response Orchestrator) project focuses on the **End-to-End Simulation** of crisis detection and assessment. This phase integrates all previous work—signal normalization, multi-source aggregation, and mathematical scoring—into a single, presentation-ready demo runner.

The `demo_runner.py` script simulates a live data stream for various sectors in Islamabad, allowing evaluators to see how the AI processes signals, builds reasoning steps, and determines the current crisis status.

---

## 🛠 Key Components

1.  **`demo_runner.py`**: The main orchestration script. It loads pre-defined scenarios and simulates the sequential arrival of 10 signals per scenario.
2.  **`scenarios.json`**: A dataset containing three complete test scenarios:
    *   **Scenario A**: G-10 Urban Flooding (Escalating Trend)
    *   **Scenario B**: F-8 Road Accident (Sudden Spike)
    *   **Scenario C**: Blue Area Power Outage (Stable Situation)
3.  **Integration Layer**:
    *   **Signal Normalization**: Uses Roman Urdu keyword detection to extract crisis types.
    *   **Crisis Scoring**: Computes real-time probability and identifies the current momentum (Escalating/Stable/De-escalating).
    *   **Agent Trace Logging**: Generates `AgentMessage` objects for each step, forming a complete audit trail for the Sensor Agent.

---

## 🏃 How to Run Phase 3

To run the demo, ensure you are in the `phase1` directory and use the following command structure:

### 1. Scenario A: G-10 Flooding
Demonstrates an escalating situation where minor rain turns into a severe flood requiring rescue teams.
```bash
python3 demo_runner.py --scenario A
```
python -m uvicorn main:app --host 0.0.0.0

### 2. Scenario B: F-8 Accident
Demonstrates a sudden spike in severity following a car crash, which then stabilizes as emergency services respond.
```bash
python3 demo_runner.py --scenario B
```

### 3. Scenario C: Blue Area Power Outage
Demonstrates a persistent, mid-level severity situation with stable trend detection.
```bash
python3 demo_runner.py --scenario C
```

---

## 📊 Output Explanation

For every run, the system displays:
*   **Header Box**: Basic info about the current zone and scenario goal.
*   **Signal Rows**: Real-time processing of each message, showing:
    *   **Running Probability**: The calculated chance that a crisis is occurring.
    *   **Trend**: The direction of the crisis (getting worse or better).
    *   **Agent Reasoning**: A peak into the "brain" of the Sensor Agent.
*   **Final Assessment Box**: A summary of the dominant crisis type, final confidence score, and **Recommended Response Actions** (P1, P2, P3).

---

## 📦 Dependencies
*   Python 3.10+
*   `pydantic` (for data models)
*   Shared project models (imported from `../models.py`)
