from datetime import datetime

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Company(Base):
    """Empresa cliente — unidad de multi-tenancy."""
    __tablename__ = "companies"

    id = Column(String, primary_key=True)          # ej: "acme", "logitop"
    name = Column(String, nullable=False)
    plan = Column(String, default="starter")        # starter / pro / enterprise
    created_at = Column(DateTime, default=datetime.utcnow)

    vehicles = relationship("Vehicle", back_populates="company")


class Vehicle(Base):
    """Vehículo de la flota — pertenece a una empresa."""
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    company_id = Column(String, ForeignKey("companies.id"), nullable=False)
    plate = Column(String, nullable=False)
    model = Column(String)
    status = Column(String, default="active")       # active / maintenance / inactive

    company = relationship("Company", back_populates="vehicles")
    telemetry = relationship("Telemetry", back_populates="vehicle")
    alerts = relationship("Alert", back_populates="vehicle")


class Telemetry(Base):
    """Evento GPS/telemetría de un vehículo."""
    __tablename__ = "telemetry"

    id = Column(Integer, primary_key=True, autoincrement=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    speed = Column(Float, default=0.0)              # km/h
    fuel = Column(Float, default=100.0)             # porcentaje 0-100
    timestamp = Column(DateTime, default=datetime.utcnow)

    vehicle = relationship("Vehicle", back_populates="telemetry")


class Alert(Base):
    """Alerta generada para un vehículo."""
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    type = Column(String, nullable=False)           # fuel_low / speed / maintenance
    severity = Column(String, default="medium")     # low / medium / high / critical
    message = Column(Text, nullable=False)
    resolved_at = Column(DateTime, nullable=True)

    vehicle = relationship("Vehicle", back_populates="alerts")
