from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth import verify_token
from app.database import get_db
from app.models import Vehicle

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


class VehicleCreate(BaseModel):
    plate: str
    model: Optional[str] = None


class VehicleResponse(BaseModel):
    id: int
    company_id: str
    plate: str
    model: Optional[str]
    status: str

    class Config:
        from_attributes = True


@router.get("/", response_model=List[VehicleResponse])
def list_vehicles(
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    """Lista vehículos de la empresa del token — filtro multi-tenant en SQL."""
    company_id = token["company_id"]
    return db.query(Vehicle).filter(Vehicle.company_id == company_id).all()


@router.post("/", response_model=VehicleResponse, status_code=201)
def create_vehicle(
    vehicle: VehicleCreate,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    """Crea un vehículo para la empresa del token."""
    company_id = token["company_id"]
    db_vehicle = Vehicle(
        company_id=company_id,
        plate=vehicle.plate,
        model=vehicle.model,
    )
    db.add(db_vehicle)
    db.commit()
    db.refresh(db_vehicle)
    return db_vehicle


@router.get("/{vehicle_id}", response_model=VehicleResponse)
def get_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    """Obtiene un vehículo — verifica que pertenece a la empresa del token."""
    company_id = token["company_id"]
    vehicle = db.query(Vehicle).filter(
        Vehicle.id == vehicle_id,
        Vehicle.company_id == company_id,   # multi-tenant enforcement
    ).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return vehicle
