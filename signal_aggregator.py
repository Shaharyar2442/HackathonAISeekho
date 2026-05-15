import os
import sys
import random
from datetime import datetime
from dataclasses import dataclass
from typing import List

# Add parent directory to path to find models.py
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from models import CrisisSignal, AgentMessage
from signal_processor import SignalNormalizer, MockDataGenerator

# ─────────────────────────────────────────────────────────────────────────────
# 1. WeatherSimulator
# ─────────────────────────────────────────────────────────────────────────────

class WeatherSimulator:
    """Simulates weather data for a specific zone."""
    
    @staticmethod
    def simulate_weather(zone: str) -> dict:
        month = datetime.now().month
        condition = "normal"
        if 7 <= month <= 8:
            condition = "heavy_rain"
        elif 5 <= month <= 6:
            condition = "heatwave"
            
        rainfall_mm = 0.0
        if condition == "heavy_rain":
            rainfall_mm = round(random.uniform(40, 80), 1)
            
        alert_level = "none"
        if rainfall_mm > 60:
            alert_level = "emergency"
        elif rainfall_mm > 30:
            alert_level = "warning"
        elif rainfall_mm > 0:
            alert_level = "watch"
            
        return {
            "condition": condition,
            "rainfall_mm": rainfall_mm,
            "alert_level": alert_level
        }

# ─────────────────────────────────────────────────────────────────────────────
# 2. TrafficSimulator
# ─────────────────────────────────────────────────────────────────────────────

class TrafficSimulator:
    """Simulates traffic data for a specific zone."""
    
    @staticmethod
    def simulate_traffic(zone: str) -> dict:
        hour = datetime.now().hour
        is_peak = hour in [8, 9, 17, 18, 19]
        is_busy_zone = zone in ["G-10", "G-11"]
        
        if is_busy_zone and (8 <= hour <= 10 or 17 <= hour <= 20):
            congestion_score = random.randint(65, 90)
        else:
            congestion_score = random.randint(20, 40)
            
        return {
            "congestion_score": congestion_score,
            "incident_count": random.randint(0, 3),
            "peak_hour": is_peak
        }

# ─────────────────────────────────────────────────────────────────────────────
# 3. SignalAggregator
# ─────────────────────────────────────────────────────────────────────────────

class SignalAggregator:
    """Aggregates signals from multiple sources."""
    
    def __init__(self):
        self.normalizer = SignalNormalizer()
        self.generator = MockDataGenerator()
        self.weather_sim = WeatherSimulator()
        self.traffic_sim = TrafficSimulator()

    def ingest_social(self, text: str, location: str) -> CrisisSignal:
        """Processes a single social media post."""
        signal, reasoning = self.normalizer.normalize(text, location)
        # reasoning is discarded as per Phase 2 requirements (already logged in Phase 1)
        return signal

    def aggregate_all(self, zone: str) -> List[CrisisSignal]:
        """Collects signals from Weather, Traffic, and Social sources."""
        all_signals = []
        
        # 1. Weather Source
        w_data = self.weather_sim.simulate_weather(zone)
        w_type = "Flood" if w_data["condition"] == "heavy_rain" else "Traffic"
        w_sev_map = {"emergency": 5, "warning": 4, "watch": 2, "none": 1}
        all_signals.append(CrisisSignal(
            text=f"Weather Sensor: {w_data['condition']} detected ({w_data['rainfall_mm']}mm)",
            location=zone,
            crisis_type=w_type,
            severity=w_sev_map.get(w_data["alert_level"], 1),
            source="sensor"
        ))
        
        # 2. Traffic Source
        t_data = self.traffic_sim.simulate_traffic(zone)
        t_sev = 1
        if t_data["congestion_score"] > 80: t_sev = 5
        elif t_data["congestion_score"] > 50: t_sev = 3
        
        all_signals.append(CrisisSignal(
            text=f"Traffic Sensor: Congestion {t_data['congestion_score']}% with {t_data['incident_count']} incidents",
            location=zone,
            crisis_type="Traffic",
            severity=t_sev,
            source="sensor"
        ))
        
        # 3. Social Media Source (2 signals)
        social_signals = self.generator.generate(count=2)
        # Ensure they match the current zone
        for s in social_signals:
            s.location = zone
            
        all_signals.extend(social_signals)
        
        return all_signals

# ─────────────────────────────────────────────────────────────────────────────
# 4. CrisisAssessment Dataclass
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class CrisisAssessment:
    """Internal assessment result."""
    crisis_probability: float
    severity_level: int
    trend: str

# ─────────────────────────────────────────────────────────────────────────────
# 5. CrisisScorer
# ─────────────────────────────────────────────────────────────────────────────

class CrisisScorer:
    """Computes probability and trends from aggregated signals."""
    
    @staticmethod
    def score(signals: List[CrisisSignal]) -> CrisisAssessment:
        if not signals:
            return CrisisAssessment(0.0, 1, "stable")
            
        avg_severity = sum(s.severity for s in signals) / len(signals)
        
        # Probability: (avg_severity / 5) * (min(count, 10) / 10)
        prob = (avg_severity / 5) * (min(len(signals), 10) / 10)
        prob = round(prob, 2)
        
        # Severity Level: round avg clamped 1-5
        sev_level = max(1, min(5, round(avg_severity)))
        
        # Trend: compare last 3 vs first 3
        trend = "stable"
        if len(signals) >= 6:
            first_3_avg = sum(s.severity for s in signals[:3]) / 3
            last_3_avg = sum(s.severity for s in signals[-3:]) / 3
            diff = last_3_avg - first_3_avg
            if diff > 0.5:
                trend = "escalating"
            elif diff < -0.5:
                trend = "de-escalating"
        
        return CrisisAssessment(prob, sev_level, trend)

# ─────────────────────────────────────────────────────────────────────────────
# 6. AggregatorAgentLogger
# ─────────────────────────────────────────────────────────────────────────────

class AggregatorAgentLogger:
    """Generates trace logs for the Aggregation step."""
    
    @staticmethod
    def log(zone: str, signals: List[CrisisSignal], assessment: CrisisAssessment) -> AgentMessage:
        steps = []
        
        # Identify source contributions
        weather_sig = next((s for s in signals if "Weather Sensor" in s.text), None)
        if weather_sig:
            steps.append(f"Weather source: {weather_sig.text.split(': ')[1]} → 1 {weather_sig.crisis_type} signal added (severity {weather_sig.severity})")
            
        traffic_sig = next((s for s in signals if "Traffic Sensor" in s.text), None)
        if traffic_sig:
            steps.append(f"Traffic source: {traffic_sig.text.split(': ')[1]} → 1 Traffic signal added (severity {traffic_sig.severity})")
            
        social_count = len([s for s in signals if s.source != "sensor"])
        if social_count > 0:
            steps.append(f"Social Media source: {social_count} signals ingested and normalized")
            
        steps.append(f"Probability computed as (avg_severity/5) × (signal_count/10) = {assessment.crisis_probability}")
        
        return AgentMessage(
            agent_name="Sensor Agent",
            input_summary=f"Aggregated {len(signals)} signals from 3 sources for zone {zone}",
            output_summary=f"Crisis probability: {assessment.crisis_probability}, Severity: {assessment.severity_level}, Trend: {assessment.trend}",
            reasoning_steps=steps
        )

# ─────────────────────────────────────────────────────────────────────────────
# 7. Main Test Block
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    zones = ["G-10", "G-11", "F-8", "I-8", "Blue Area"]
    aggregator = SignalAggregator()
    scorer = CrisisScorer()
    logger = AggregatorAgentLogger()
    
    print("\n" + "="*80)
    print("CIRO PHASE 2: MULTI-SOURCE SIGNAL AGGREGATION & ASSESSMENT")
    print("="*80)
    
    for zone in zones:
        # Aggregate signals
        signals = aggregator.aggregate_all(zone)
        
        # Perform assessment
        assessment = scorer.score(signals)
        
        # Generate log
        msg = logger.log(zone, signals, assessment)
        
        # Print results
        print(f"\nZONE: {zone}")
        print(f"Signals: {len(signals)} | Prob: {assessment.crisis_probability} | Sev: {assessment.severity_level} | Trend: {assessment.trend}")
        print("-" * 40)
        print("Reasoning Steps:")
        for step in msg.reasoning_steps:
            print(f" • {step}")
    
    print("\n" + "="*80 + "\n")
