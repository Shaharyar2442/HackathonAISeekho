# ─────────────────────────────────────────────────────────────────────
# CIRO Backend — Docker Image for Google Cloud Run
# ─────────────────────────────────────────────────────────────────────
# Build:  docker build -t ciro-backend .
# Run:    docker run -p 8080:8080 --env-file backend/.env ciro-backend
# ─────────────────────────────────────────────────────────────────────

FROM python:3.11-slim

# Set working directory inside the container
WORKDIR /app

# Install system deps (needed for some Python packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (Docker layer caching)
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy application code
COPY shared/ ./shared/
COPY backend/ ./backend/
COPY signal_processor.py ./signal_processor.py
COPY signal_aggregator.py ./signal_aggregator.py
COPY scenarios.json ./scenarios.json
COPY crisis_data.json ./crisis_data.json

# Expose Cloud Run default port
EXPOSE 8080

# Set environment variables for Cloud Run
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

# Run from inside backend/ directory — same as local dev
# This ensures `from antigravity_pipeline import ...` resolves correctly
WORKDIR /app/backend
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
