from typing import List
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from app.auth import verify_token
from app.database import get_db
from app.models import Alert, Vehicle

router = APIRouter(prefix="/alerts", tags=["alerts"])


class AlertResponse(BaseModel):
    id: int
    vehicle_id: int
    type: str
    severity: str
    message: str
    resolved_at: Optional[datetime]

    class Config:
        from_attributes = True


@router.get("/", response_model=List[AlertResponse])
def list_alerts(
    resolved: bool = False,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    """Alertas activas (o resueltas) de todos los vehículos de la empresa."""
    company_id = token["company_id"]

    # Join con vehicles para filtrar por company_id — multi-tenant en SQL
    query = (
        db.query(Alert)
        .join(Vehicle, Alert.vehicle_id == Vehicle.id)
        .filter(Vehicle.company_id == company_id)
    )

    if not resolved:
        query = query.filter(Alert.resolved_at.is_(None))

    return query.order_by(Alert.id.desc()).limit(50).all()
