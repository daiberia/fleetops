from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from app.config import settings
from app.database import engine, Base
from app.routers import health, vehicles, telemetry, alerts

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Crea tablas si no existen al arrancar
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="FleetOps — Fleet Management SaaS API",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# M1: CORS restringido a orígenes conocidos — wildcard eliminado
# En producción los orígenes vienen de variable de entorno
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in settings.cors_allowed_origins.split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# Prometheus — expone /metrics con métricas HTTP automáticas
Instrumentator().instrument(app).expose(app)

# Routers
app.include_router(health.router)
app.include_router(vehicles.router)
app.include_router(telemetry.router)
app.include_router(alerts.router)