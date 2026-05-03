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

# Environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH="/app/deps" \
    PORT=8080

# Copy installed dependencies from builder
COPY --from=builder /app/deps /app/deps

# Copy application code and model files
COPY main.py .
COPY trained_model/ ./trained_model/

# Note: raw food_dataset_fast.json is NOT needed for inference, 
# saving ~50MB in image size.

EXPOSE ${PORT}

# Use gunicorn with uvicorn workers for production stability
# -w 1: Use 1 worker (Cloud Run scales via instances, not workers)
# -k uvicorn.workers.UvicornWorker: Use the uvicorn worker class
CMD ["sh", "-c", "gunicorn main:app --workers 1 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT} --timeout 120"]
