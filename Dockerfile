# ─── Stage 1: Build dependencies ────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies for scipy/scikit-learn
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/deps -r requirements.txt

# ─── Stage 2: Production image ──────────────────────────
FROM python:3.11-slim

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /app/deps /app/deps
ENV PYTHONPATH="/app/deps"

# Copy application code and model files
COPY main.py .
COPY trained_model/ ./trained_model/
COPY food_dataset_fast.json .

# Cloud Run sets PORT env variable (default 8080)
ENV PORT=8080

EXPOSE ${PORT}

# Use uvicorn with the PORT env variable
CMD ["sh", "-c", "python -m uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
