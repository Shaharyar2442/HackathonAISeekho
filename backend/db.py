"""
CIRO Firestore Database Client
================================
Initialises the Firestore client at module level (not per-request)
to avoid cold-start latency on Cloud Run.

Usage:
    from db import get_db
    db = get_db()
    db.collection("agent_traces").add(data)
"""

from google.cloud import firestore
from config import get_settings

# Module-level client — initialised once on import, reused for all requests.
# This avoids Firestore cold-start delays on Cloud Run.
_db_client: firestore.Client | None = None


def get_db() -> firestore.Client:
    """Returns the singleton Firestore client.
    
    Uses the GCP_PROJECT_ID from settings. When running locally,
    ensure GOOGLE_APPLICATION_CREDENTIALS points to your service account key.
    On Cloud Run, authentication is automatic via the service account.
    """
    global _db_client
    if _db_client is None:
        settings = get_settings()
        _db_client = firestore.Client(project=settings.FIRESTORE_PROJECT_ID)
    return _db_client
