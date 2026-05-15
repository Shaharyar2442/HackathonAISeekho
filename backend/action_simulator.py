"""
CIRO Action Simulator
======================
Simulates the execution of response actions and computes before/after states.
In a real environment, this would integrate with external APIs (traffic, emergency dispatch).
For the hackathon, we simulate realistic changes and save the state to Firestore.
"""

import uuid
from datetime import datetime
from shared.models import SimulationResult
from db import get_db

class ActionSimulator:
    """Simulates real-world impact of response actions."""

    def __init__(self):
        # We try to get the DB, but handle failure gracefully if GCP isn't setup
        try:
            self.db = get_db()
        except Exception:
            self.db = None

    async def simulate_traffic_reroute(self, location: str, route: str) -> SimulationResult:
        """Simulate a traffic reroute, reducing congestion."""
        # Simulated initial state
        before = {"congestion_percent": 85, "avg_speed_kmh": 8, "blocked_routes": 3}
        # Simulated resulting state
        after = {"congestion_percent": 35, "avg_speed_kmh": 42, "blocked_routes": 0}
        
        log = [
            f"Activated alternate route via {route} for {location}",
            "Updated traffic signal timings at key intersections",
            "Notified Islamabad Traffic Police",
            "Congestion successfully reduced from 85% to 35%"
        ]
        
        result = SimulationResult(
            action_id=f"reroute_{uuid.uuid4().hex[:6]}",
            before_state=before,
            after_state=after,
            execution_log=log
        )
        
        # Save to Firestore
        if self.db:
            try:
                self.db.collection("simulations").add(result.model_dump())
            except Exception as e:
                print(f"Firestore save failed: {e}")
                
        return result

    async def simulate_emergency_dispatch(self, location: str) -> SimulationResult:
        """Simulate dispatching an emergency team (e.g. NDMA)."""
        before = {"teams_deployed": 0, "water_level_cm": 45}
        after = {"teams_deployed": 2, "water_level_cm": 15}
        
        log = [
            f"Dispatched 2 NDMA flood response teams to {location}",
            "ETA: 20 minutes from nearest staging area",
            "Water pumps activated — projected drainage: 30cm/hour",
            "Incident ticket created in emergency dispatch system"
        ]
        
        result = SimulationResult(
            action_id=f"dispatch_{uuid.uuid4().hex[:6]}",
            before_state=before,
            after_state=after,
            execution_log=log
        )
        
        if self.db:
            try:
                self.db.collection("simulations").add(result.model_dump())
            except Exception as e:
                print(f"Firestore save failed: {e}")
                
        return result

    async def simulate_citizen_alert(self, location: str) -> SimulationResult:
        """Simulate sending push notifications to citizens."""
        before = {"alerts_sent": 0, "citizens_notified": 0}
        after = {"alerts_sent": 1, "citizens_notified": 15000}
        
        log = [
            f"Composed bilingual alert (English + Roman Urdu) for {location}",
            "Broadcast via CIRO push notification channel",
            "Estimated reach: 15,000 registered users in affected zones"
        ]
        
        result = SimulationResult(
            action_id=f"alert_{uuid.uuid4().hex[:6]}",
            before_state=before,
            after_state=after,
            execution_log=log
        )
        
        if self.db:
            try:
                self.db.collection("simulations").add(result.model_dump())
            except Exception as e:
                print(f"Firestore save failed: {e}")
                
        return result
