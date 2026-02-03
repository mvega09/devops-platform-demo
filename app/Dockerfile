# ---------- STAGE 1: build ----------
FROM python:3.11-slim-bookworm AS builder  # Especificar versión explícita

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Actualizar sistema y dependencias
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install --user -r requirements.txt

# ---------- STAGE 2: runtime ----------
FROM python:3.11-slim-bookworm  # Especificar versión explícita

WORKDIR /app

RUN useradd -m appuser

# Actualizar sistema en runtime también
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

ENV PATH=/home/appuser/.local/bin:$PATH

COPY --chown=appuser:appuser main.py .
COPY --chown=appuser:appuser config.py .
COPY --chown=appuser:appuser requirements.txt .
COPY --chown=appuser:appuser test/ ./test/

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]