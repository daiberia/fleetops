from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import text
import logging

from app.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """
    Liveness y readiness probe para Kubernetes.
    Verifica conectividad con la base de datos.
    """
    try:
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error("Health check DB failure: %s", e)
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "database": "unavailable"},
        )


@router.get("/")
def root():
    return {"service": "FleetOps API", "version": "0.1.0", "docs": "/docs"}