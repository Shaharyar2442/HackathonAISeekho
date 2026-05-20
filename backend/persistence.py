"""
CIRO Firestore Persistence Layer
=================================
Handles all Firestore reads and writes for crisis events.
Gracefully no-ops if Firestore is not configured (local dev without credentials).
"""

import asyncio
import uuid
from datetime import datetime


def _save_crisis_event(db, crisis_doc: dict) -> str | None:
    """Write a crisis event to Firestore. Returns the doc ID or None on failure."""
    try:
        _, ref = db.collection("crisis_events").add(crisis_doc)
        return ref.id
    except Exception as e:
        print(f"[Firestore] Write failed (non-fatal): {e}")
        return None


async def save_crisis_event(db, result: dict, signal: dict, source: str = "user_report") -> str | None:
    """Async-safe wrapper: saves a full pipeline result to crisis_events collection."""
    crisis = result.get("detected_crisis", {})
    doc = {
        "id": str(uuid.uuid4()),
        "crisis_type": crisis.get("type", "Unknown"),
        "location": crisis.get("location", "Unknown"),
        "severity": crisis.get("severity", 1),
        "confidence": crisis.get("confidence", 0.0),
        "reasoning": crisis.get("reasoning", ""),
        "lat": signal.get("lat"),
        "lng": signal.get("lng"),
        "actions": result.get("actions_recommended", []),
        "agent_trace": result.get("agent_trace", []),
        "source": source,
        "timestamp": datetime.now().isoformat(),
    }
    # Run blocking Firestore call in a thread
    doc_id = await asyncio.to_thread(_save_crisis_event, db, doc)
    return doc_id


def _load_recent_events(db, limit: int = 20) -> list[dict]:
    """Load the most recent crisis events from Firestore."""
    try:
        docs = (
            db.collection("crisis_events")
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
        return [doc.to_dict() for doc in docs]
    except Exception as e:
        print(f"[Firestore] Read failed (non-fatal): {e}")
        return []


async def load_recent_crisis_events(db, limit: int = 20) -> list[dict]:
    """Async-safe wrapper: loads recent crisis events for broadcasting to new WS clients."""
    return await asyncio.to_thread(_load_recent_events, db, limit)
