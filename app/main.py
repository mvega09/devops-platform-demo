from fastapi import FastAPI
from prometheus_client import Counter, generate_latest
from starlette.responses import Response
import logging

from config import APP_NAME, APP_ENV

app = FastAPI(title=APP_NAME)

# Logging básico (producción friendly)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Métrica Prometheus
REQUEST_COUNT = Counter(
    "app_requests_total",
    "Total de peticiones a la aplicación"
)

@app.get("/health")
def health():
    logger.info("Health check ejecutado")
    return {
        "status": "ok",
        "environment": APP_ENV
    }

@app.get("/items")
def get_items():
    REQUEST_COUNT.inc()
    return {
        "items": ["item1", "item2", "item3"]
    }

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")
