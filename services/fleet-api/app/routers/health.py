from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.database import get_db

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
        return {"status": "unhealthy", "database": str(e)}, 503


@router.get("/")
def root():
    return {"service": "FleetOps API", "version": "0.1.0", "docs": "/docs"}
