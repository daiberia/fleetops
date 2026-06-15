from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from datetime import datetime

from app.auth import verify_token
from app.database import get_db
from app.models import Telemetry, Vehicle

router = APIRouter(prefix="/telemetry", tags=["telemetry"])


class TelemetryResponse(BaseModel):
    id: int
    vehicle_id: int
    lat: float
    lon: float
    speed: float
    fuel: float
    timestamp: datetime

    class Config:
        from_attributes = True


@router.get("/{vehicle_id}", response_model=List[TelemetryResponse])
def get_telemetry(
    vehicle_id: int,
    limit: int = 100,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    """Últimos N eventos de telemetría de un vehículo — validación multi-tenant."""
    company_id = token["company_id"]

    # Verificar que el vehículo pertenece a la empresa del token
    vehicle = db.query(Vehicle).filter(
        Vehicle.id == vehicle_id,
        Vehicle.company_id == company_id,
    ).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")

    return (
        db.query(Telemetry)
        .filter(Telemetry.vehicle_id == vehicle_id)
        .order_by(Telemetry.timestamp.desc())
        .limit(limit)
        .all()
    )
