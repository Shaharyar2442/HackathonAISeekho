# CIRO: Crisis Intelligence and Response Orchestrator

**AISeekho Hackathon 2026**

CIRO is a multi-agent AI system for real-time urban crisis detection, coordination, and simulation in Islamabad, Pakistan. It combines Google Vertex AI (Gemini models), a FastAPI backend, a Flutter mobile app, and a live web dashboard into a fully integrated crisis response platform.

---

## Solution Design

### The Problem

Islamabad's emergency services operate in silos. A flood in G-10 Markaz may be reported by a citizen via text, detected by a sensor, and mentioned on social media simultaneously, but there is no single system to correlate these signals, assess the crisis, and coordinate a response. Dispatchers rely on phone calls and manual judgement, losing critical minutes.

### The Approach

CIRO solves this with an **agentic pipeline**. Instead of a single large prompt, four specialised AI agents each own a distinct stage of the crisis lifecycle:

1. **Signal Ingestion** — normalise chaotic, multi-source, multilingual inputs
2. **Crisis Analysis** — correlate signals, score severity, compute confidence
3. **Response Coordination** — generate prioritised, location-specific action plans
4. **Impact Simulation** — model before/after states for each proposed action

Every decision is logged with chain-of-thought reasoning, giving dispatchers full transparency into why the AI recommended a specific action. The complete trace is exportable as JSON for audit and review.

### Design Principles

- **Agentic over monolithic:** Each agent has a distinct role, its own system prompt, its own output schema, and its own temperature setting. They are not a single large prompt chain.
- **Grounded in real infrastructure:** 28 Islamabad locations are mapped with hospitals, fire stations, roads, flood risk, and population data. The AI references real agencies (NDMA, Rescue 1122, IESCO, SNGPL) not generic templates.
- **Multi-source signal fusion:** Every user report is bundled with synthetic social media and sensor signals before hitting the pipeline, giving the AI cross-source corroboration.
- **Full transparency:** Every agent outputs numbered chain-of-thought reasoning steps, visible in both the dashboard and mobile app.

---

## Repository Structure

```
AISEEKHO_Hackathon/
├── backend/                    # FastAPI backend + agentic pipeline
│   ├── antigravity_pipeline.py # Core 4-agent pipeline (CIROPipeline)
│   ├── main.py                 # FastAPI app, all endpoints, WebSocket handler
│   ├── action_simulator.py     # Python tool used by Simulator Agent (function calling)
│   ├── config.py               # Pydantic settings (env vars)
│   ├── db.py                   # Singleton Firestore client
│   ├── persistence.py          # Firestore CRUD operations
│   └── requirements.txt        # Python dependencies
├── shared/
│   └── models.py               # Single source of truth for all Pydantic data models
├── ciro_mobile/                # Flutter mobile application
│   └── lib/
│       ├── main.dart           # All screens: Splash, Home, Map, Response, Simulation, Settings
│       ├── api_service.dart    # HTTP client + multi-source signal bundling
│       ├── metrics_screen.dart # Metrics/statistics dashboard tab
│       └── firestore_service.dart # Direct Firestore reads for historical data
├── dashboard.html              # Single-page web operations dashboard
├── signal_processor.py         # Synthetic signal generator
├── signal_aggregator.py        # Multi-source aggregation and crisis scoring
├── scenarios.json              # Pre-built crisis scenarios for demo streaming
├── demo_runner.py              # CLI demo runner for scenario presentation
└── Dockerfile                  # Container definition for Cloud Run
```

---

## Architecture Overview

The system is split into three frontends all backed by a single FastAPI service.

**Frontends**

- Flutter mobile app (Android/iOS) used by field officers and citizens
- Web dashboard (HTML/JS) used by operations centre staff
- CLI demo runner for hackathon presentation streaming

**Backend**

- FastAPI (Python 3.11) hosted on Google Cloud Run
- Exposes REST endpoints, a WebSocket feed, and SSE streaming
- Invokes the CIROPipeline on every detection request

**Persistence**

- Google Cloud Firestore stores every crisis event, its full agent trace, and all recommended actions

**AI Provider**

- Google Vertex AI (Gemini 2.5 Flash) handles all four agent calls
- Authentication is handled via Google service account attached to the Cloud Run service

**Background Loop**

- Every 90 seconds the backend auto-generates a realistic crisis signal from 8 Islamabad scenarios, runs it through the full pipeline, saves it to Firestore, and broadcasts the result to all WebSocket clients. This keeps the dashboard live without manual input.

---

## The 4-Agent Pipeline

The `CIROPipeline` class in `antigravity_pipeline.py` is the core of CIRO. Agents are chained sequentially. Each agent receives the prior agent's output, invokes Gemini with a specialised system prompt, and returns a validated Pydantic model plus chain-of-thought reasoning steps.

### Agent 1: Sensor Agent

| Property | Value |
|----------|-------|
| Input | Raw crisis signals (JSON list) |
| Output | `SensorAgentOutput` (list of `CrisisSignal`) |
| Temperature | 0.2 (high precision) |

Responsibilities:
- Parses multilingual text including Roman Urdu (e.g. "pani bhar gaya" = "water has flooded")
- Assigns severity 1-5 based on language cues and contextual keywords
- Maps each signal to one of 5 canonical crisis types
- Validates source, location, and timestamp

### Agent 2: Analyst Agent

| Property | Value |
|----------|-------|
| Input | List of `CrisisSignal` from Sensor Agent |
| Output | `AnalystAgentOutput` (single `DetectedCrisis` verdict) |
| Temperature | 0.5 |

Responsibilities:
- Cross-source correlation: signals from multiple sources (social media + sensor + user) yield higher confidence
- Applies Pakistan's NDMA (National Disaster Management Authority) severity scale
- Produces a confidence score from 0.50 to 0.99
- Writes explicit reasoning: which signals corroborated, why that severity was assigned

### Agent 3: Coordinator Agent

| Property | Value |
|----------|-------|
| Input | `DetectedCrisis` + ISLAMABAD_CONTEXT for the detected location |
| Output | `CoordinatorAgentOutput` (3-5 prioritised `ResponseAction` objects) |
| Temperature | 0.7 |

Responsibilities:
- Activates crisis-specific response protocols (flooding vs fire vs power vs accident vs traffic)
- References real Islamabad agencies: NDMA, Rescue 1122, CDA, IESCO, SNGPL, ITP, PIMS, Shifa
- Assigns P1/P2/P3 priority to each action
- Uses the 28-sector Islamabad context map to make actions location-specific

### Agent 4: Simulator Agent

| Property | Value |
|----------|-------|
| Input | List of `ResponseAction` from Coordinator Agent |
| Output | `SimulatorAgentOutput` (list of `SimulationResult` with before/after states) |
| Temperature | 0.6 |

Responsibilities:
- Uses Gemini **function calling** to invoke `calculate_simulation_metrics` — a real Python tool, not a hallucinated response
- Receives tool results and synthesises a final structured JSON output
- Produces execution logs and before/after state snapshots for each action

---

## Islamabad Location Intelligence

The `ISLAMABAD_CONTEXT` dictionary provides grounding for 28 locations:

**Core Sectors:** G-6, G-7, G-8, G-9, G-10, G-11, F-6, F-7, F-8, F-10, F-11, E-7, E-11, H-8, H-9, I-8, I-9, I-10, D-12, Blue Area

**Key Interchanges:** Faizabad

**Peri-Urban Towns:** Bhara Kahu, Rawat, Tarnol, Golra Sharif

**Housing Societies:** Soan Garden, PWD Housing Society, DHA Islamabad, Bahria Town Islamabad

Each entry includes: nearest hospitals with distances, fire station coverage radius, major road networks and intersections, flood and fire risk factors, population estimates, and critical infrastructure landmarks.

---

## APIs Used

### Real APIs

| API | Provider | Used For |
|-----|----------|----------|
| Gemini 2.5 Flash | Google Vertex AI | All 4 agent LLM calls (Sensor, Analyst, Coordinator, Simulator) |
| Cloud Firestore | Google Cloud | Persistent storage of crisis events and agent traces |
| Google Maps SDK | Google Maps Platform | Live map rendering in Flutter mobile app |
| Google Places API | Google Maps Platform | Location autocomplete when reporting an incident |
| Geocoding API | Google Maps Platform | Reverse geocoding GPS coordinates to human-readable address |

### Mock / Synthetic APIs

| Component | Purpose |
|-----------|---------|
| `signal_processor.py` | Generates synthetic sensor telemetry (water level, temperature, traffic density) bundled with user reports to simulate IoT sensor feeds |
| `signal_aggregator.py` | Simulates multi-source aggregation as if signals came from separate systems (social media scraper, citizen app, sensor network) |
| `calculate_simulation_metrics` tool | Simulates the execution of response actions. Returns realistic before/after states with randomised but bounded metrics (e.g. congestion 75-95% before, 25-45% after traffic reroute). Designed to mock a real city digital twin. |
| Background signal loop (`_agent_signal_loop`) | Every 90 seconds generates a random crisis signal from 8 realistic Islamabad scenarios (in Roman Urdu and English) to continuously populate the dashboard without manual input. |

---

## Agents Developed

| Agent | File | Role |
|-------|------|------|
| Sensor Agent | `antigravity_pipeline.py` | Signal normalisation and multilingual parsing |
| Analyst Agent | `antigravity_pipeline.py` | Crisis classification and confidence scoring |
| Coordinator Agent | `antigravity_pipeline.py` | Prioritised response action planning |
| Simulator Agent | `antigravity_pipeline.py` | Tool-augmented action impact simulation |

All agents are implemented as async methods on the `CIROPipeline` class and use tenacity-based retry with exponential backoff to handle Gemini rate limiting.

---

## Integrations Implemented

### Google Vertex AI (Gemini)
- Structured output extraction (`response_schema` with Pydantic models) for deterministic JSON
- Function calling (Simulator Agent invokes `calculate_simulation_metrics` tool)
- Async thread execution via `asyncio.to_thread` to avoid blocking the FastAPI event loop
- Retry with exponential backoff (tenacity library) for rate limit resilience

### Google Cloud Firestore
- Singleton client pattern (`db.py`) to avoid cold-start latency on Cloud Run
- Async-safe persistence via `asyncio.to_thread` wrappers (`persistence.py`)
- Stores: crisis type, location, severity, confidence, lat/lng, recommended actions, agent trace, timestamp
- Read by the dashboard via `GET /api/crisis/{id}/logs`

### Google Maps (Flutter)
- `google_maps_flutter` for interactive map rendering in the Live Map tab
- 20 predefined Islamabad crisis zone markers, colour-coded by severity (green/orange/red)
- `geolocator` + `geocoding` packages for GPS auto-detect and reverse geocoding
- Google Places Autocomplete for the location search field in the Report Incident form

### WebSocket (Real-time Feed)
- FastAPI `WebSocket` endpoint at `/ws/signals`
- Broadcasts new crisis events to all connected clients as they arrive
- Mobile app and dashboard both connect on launch to receive live updates
- New WebSocket clients receive recent historical events immediately on connection (seeded from Firestore)

### SSE Streaming (Dashboard Demo Mode)
- `POST /api/demo/run-scenario/{id}` streams live agent output step by step
- Uses FastAPI `StreamingResponse` with `text/event-stream` content type
- Dashboard renders each SSE event as an animated card appearing in real time

---

## Data Models

All models are defined once in `shared/models.py` and imported across the backend:

```
CrisisSignal        text, location, crisis_type, source, lat, lng, severity, timestamp
DetectedCrisis      type, location, severity (1-5), confidence (0-1), reasoning
ResponseAction      id, type, description, priority (1-3), estimated_impact
SimulationResult    action_id, before_state, after_state, execution_log
AgentMessage        agent_name, input_summary, output_summary, reasoning_steps, timestamp
```

---

## Backend API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/ingest` | Ingest raw crisis signals |
| POST | `/api/detect` | Run full 4-agent pipeline, returns crisis + actions + trace |
| POST | `/api/simulate` | Run action simulation via `calculate_simulation_metrics` tool |
| POST | `/api/reduce_severity` | Update severity for a location in Firestore |
| GET | `/api/health` | Health check |
| GET | `/api/aggregate/{zone}` | Multi-source signal aggregation for a zone |
| GET | `/api/crisis/{id}/logs` | Fetch stored agent trace from Firestore |
| POST | `/api/demo/run-scenario/{id}` | SSE streaming scenario demo |
| WS | `/ws/signals` | Real-time signal broadcast WebSocket |

---

## Mobile App (Flutter)

The mobile app (`ciro_mobile/`) targets Android and is built with Flutter using Material Design 3.

### Screens

| Screen | Purpose |
|--------|---------|
| Splash | Animated logo on launch |
| Report Incident | Form with description, Google Places location search, GPS auto-detect, crisis type dropdown |
| Live Map | Google Maps with 20 Islamabad crisis zone markers, tap to view details |
| Analysis Results | Crisis detection card, recommended actions (P1/P2/P3), 4-agent pipeline trace with expandable reasoning |
| Action Simulation | Stepper showing simulation execution steps, before/after metric comparison table |
| Metrics | Summary cards (total/high severity/mitigated) and pie chart by crisis type |
| Settings | Light/dark/system theme toggle |

### Key Mobile Features

**Multi-source signal bundling:** `api_service.dart` wraps the user's report with a synthetic social media signal and sensor telemetry before calling `/api/detect`, giving the AI three corroborating sources to work with.

**Optimistic UI:** The signal appears on the local map immediately on submit, before the backend responds. Once the backend returns, the signal is enriched with the full analysis.

**Agent trace visualization:** The Analysis Results screen renders the `Sensor → Analyst → Coordinator → Simulator` pipeline as a horizontal progress indicator. Each agent card is expandable to show numbered reasoning steps.

**JSON trace export:** The "Download Agent Trace (JSON)" button writes a timestamped JSON file to the device's Downloads folder containing the crisis object, all actions, and the complete agent trace.

**Before/After simulation table:** The simulation screen transforms raw JSON metrics into a readable `Metric | Before | After` table with colour-coded change indicators.

---

## Web Dashboard

`dashboard.html` is a self-contained single-page application with embedded CSS and JavaScript.

Features:
- Live WebSocket signal feed showing incoming crisis events in real time
- Expandable Agent Trace Viewer with per-agent reasoning cards
- Action Simulation Panel to trigger and view simulation results
- Islamabad Crisis Zone Map with sector markers
- SSE Streaming Demo mode to walk through pre-built scenarios step by step
- JSON trace download

---

## Deployment

The backend is containerised with Docker and deployed to Google Cloud Run.

- **Service:** `ciro-backend`
- **Region:** `asia-south1` (Mumbai, closest available to Pakistan)
- **Memory:** 1 GB
- **Timeout:** 300 seconds (to accommodate multi-step Gemini pipeline)
- **URL:** `https://ciro-backend-152360063189.asia-south1.run.app`
- **Authentication:** Google service account attached to Cloud Run (Vertex AI + Firestore)

Deploy command:
```bash
gcloud run deploy ciro-backend \
  --source . \
  --project ciro-hackathon-2026 \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars "GEMINI_API_KEY=...,GCP_PROJECT_ID=ciro-hackathon-2026,FIRESTORE_PROJECT_ID=ciro-hackathon-2026,FIRESTORE_DATABASE_ID=hackathon" \
  --memory 1Gi \
  --timeout 300
```

---

## Local Development Setup

### Backend

**Requirements:** Python 3.11+, a Google Cloud service account key with Firestore and Vertex AI permissions.

```bash
cd backend
pip install -r requirements.txt

# Create .env with:
# GEMINI_API_KEY=your_key
# GCP_PROJECT_ID=your_project
# FIRESTORE_PROJECT_ID=your_project
# FIRESTORE_DATABASE_ID=hackathon
# GOOGLE_APPLICATION_CREDENTIALS=/path/to/service_account.json

python -m uvicorn main:app --host 0.0.0.0
```

Server starts at `http://localhost:8000`.

### Dashboard

Open `dashboard.html` in any modern browser. It connects to `http://localhost:8000` by default.

### Mobile App

**Requirements:** Flutter 3.x, Android SDK, a Google Maps API key.

```bash
cd ciro_mobile

# Create lib/.env with:
# API_BASE_URL=http://YOUR_LOCAL_IP:8000/api
# MAPS_API_KEY=your_google_maps_key

flutter pub get
flutter run
```

Note: Use your machine's LAN IP address (not `localhost`) in `API_BASE_URL` so the Android device can reach your local backend.

---

## Crisis Types Supported

| Type | Trigger Examples | Primary Response Agencies |
|------|-----------------|--------------------------|
| Urban Flooding | Nullah overflow, waterlogging, monsoon | CDA pumps, WASA, NDMA, Rescue 1122 |
| Severe Accident | Vehicle crash, mass casualty | Rescue 1122, ITP, PIMS/Shifa ER |
| Power Infrastructure | Transformer blast, grid failure, blackout | IESCO, PEPCO, backup generators |
| Fire Hazard | Market fire, gas leak, cylinder blast | CDA Fire Brigade, SNGPL, Burns Centre |
| Traffic Gridlock | Road blockage, protest, signal failure | ITP, Motorway Police, Google Maps rerouting |

---

## Hackathon Judging Criteria

| Criteria | Weight | Implementation |
|----------|--------|---------------|
| Agentic AI | 45% | 4 specialised agents with distinct roles, structured output schemas, chain-of-thought reasoning, full exportable trace |
| Tool Integration | 25% | Gemini function calling with `calculate_simulation_metrics`, Google Maps API, Google Places API, Firestore |
| Innovation | 15% | 28-sector Islamabad intelligence map, Roman Urdu NLP, multi-source signal fusion, optimistic UI |
| Demo Quality | 15% | Live SSE streaming dashboard, Flutter mobile app with pipeline visualisation, JSON trace export |

---

## Team

Built for the AISeekho Hackathon 2026.
