# ─── Stage 1: Build dependencies ────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ─── Stage 2: Production image ──────────────────────────
FROM python:3.11-slim

WORKDIR /app

# Environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.11/site-packages" \
    PORT=8080

# Copy installed dependencies from builder
COPY --from=builder /install /install

# Copy all application files
COPY . .

EXPOSE 8080

# Run FastAPI with Gunicorn + Uvicorn workers
CMD ["sh", "-c", "gunicorn main:app --workers 1 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT} --timeout 120"]