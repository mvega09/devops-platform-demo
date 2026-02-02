# ---------- STAGE 1: build ----------
FROM python:3.11-slim AS builder

WORKDIR /app

# Evitar pyc y buffering
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --user -r requirements.txt

# ---------- STAGE 2: runtime ----------
FROM python:3.11-slim

WORKDIR /app

# Crear usuario no root
RUN useradd -m appuser

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Copiar dependencias del builder al directorio del usuario
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Actualizar PATH para el usuario appuser
ENV PATH=/home/appuser/.local/bin:$PATH

# Copiar código de la aplicación
COPY --chown=appuser:appuser main.py .
COPY --chown=appuser:appuser config.py .
COPY --chown=appuser:appuser requirements.txt .

# Copiar directorio test si existe
COPY --chown=appuser:appuser test/ ./test/

# Cambiar usuario ANTES de exponer el puerto
USER appuser

# Puerto app
EXPOSE 8000

# Healthcheck para Docker / K8s
HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

# Comando de arranque
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]