FROM python:3.11-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY services/telemetry-worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Worker
COPY services/telemetry-worker/worker/ ./worker/

# Modelos compartidos de fleet-api (dependencia directa — deuda técnica conocida)
COPY services/fleet-api/app/ ./app/

# M3: no correr como root
RUN useradd --no-create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app
USER appuser

CMD ["python", "-m", "worker.main"]