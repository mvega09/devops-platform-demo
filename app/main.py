from fastapi import FastAPI
from prometheus_client import Counter, generate_latest
from starlette.responses import Response
import logging
import os

from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

# 1. Configuración de Base de Datos
# La URL la construiremos con variables de entorno que inyectaremos vía Helm
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres123@localhost:5432/devops_db")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 2. Modelo de Usuario
class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(50))
    apellido = Column(String(50))
    email = Column(String(100), unique=True, index=True)

# Crear tablas automáticamente
Base.metadata.create_all(bind=engine)

from config import APP_NAME, APP_ENV

app = FastAPI(title=APP_NAME)

# Logging básico (producción friendly)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
REQUEST_COUNT = Counter("app_requests_total", "Total de peticiones")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/health")
def health():
    logger.info("Health check ejecutado")
    return {
        "status": "ok",
        "environment": APP_ENV
    }

@app.get("/usuarios")
def obtener_usuarios(db: Session = Depends(get_db)):
    """Lista todos los usuarios en la base de datos"""
    REQUEST_COUNT.inc()
    return db.query(Usuario).all()

@app.post("/usuarios")
def crear_usuario(nombre: str, apellido: str, email: str, db: Session = Depends(get_db)):
    """Registra un nuevo usuario"""
    db_user = Usuario(nombre=nombre, apellido=apellido, email=email)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.get("/items")
def get_items():
    REQUEST_COUNT.inc()
    return {
        "items": ["item1", "item2", "item3"]
    }

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")
