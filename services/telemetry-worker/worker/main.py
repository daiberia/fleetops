import time
import logging
from datetime import datetime

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from worker.config import settings
from worker.simulator import generate_telemetry_event, should_generate_alert

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

# Import de modelos — necesitamos que existan las tablas
import sys
import os
sys.path.insert(0, "/app")

from app.models import Vehicle, Telemetry, Alert, Company
from app.database import Base

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)


def seed_demo_data(db):
    """Crea datos de demo si la DB está vacía — necesario para la demo en vídeo."""
    if db.query(Company).count() > 0:
        return

    logger.info("Seeding demo data...")

    companies = [
        Company(id="acme", name="ACME Logistics", plan="pro"),
        Company(id="logitop", name="Logitop Spain", plan="starter"),
    ]
    db.add_all(companies)
    db.flush()

    vehicles = [
        Vehicle(company_id="acme", plate="1234-ABC", model="Volvo FH"),
        Vehicle(company_id="acme", plate="5678-DEF", model="Scania R450"),
        Vehicle(company_id="acme", plate="9012-GHI", model="MAN TGX"),
        Vehicle(company_id="logitop", plate="3456-JKL", model="DAF XF"),
        Vehicle(company_id="logitop", plate="7890-MNO", model="Mercedes Actros"),
    ]
    db.add_all(vehicles)
    db.commit()
    logger.info("Demo data seeded: 2 companies, 5 vehicles")


def run_simulation_cycle(db):
    """Un ciclo de simulación: genera telemetría para todos los vehículos activos."""
    vehicles = db.query(Vehicle).filter(Vehicle.status == "active").all()

    if not vehicles:
        logger.warning("No hay vehículos activos para simular")
        return

    for vehicle in vehicles:
        # Obtener último nivel de combustible
        last_telemetry = (
            db.query(Telemetry)
            .filter(Telemetry.vehicle_id == vehicle.id)
            .order_by(Telemetry.timestamp.desc())
            .first()
        )
        current_fuel = last_telemetry.fuel if last_telemetry else 100.0

        # Generar evento
        event = generate_telemetry_event(vehicle.id, current_fuel)
        telemetry = Telemetry(**event)
        db.add(telemetry)

        # Evaluar alertas
        alert_data = should_generate_alert(event["fuel"], event["speed"])
        if alert_data:
            alert = Alert(vehicle_id=vehicle.id, **alert_data)
            db.add(alert)
            logger.info(f"Alerta generada: {alert_data['type']} para vehículo {vehicle.plate}")

    db.commit()
    logger.info(f"Ciclo completado: {len(vehicles)} vehículos procesados")


def main():
    logger.info("Telemetry worker iniciando...")

    # Esperar a que la DB esté disponible
    retries = 0
    while retries < 10:
        try:
            db = SessionLocal()
            db.execute(__import__("sqlalchemy").text("SELECT 1"))
            logger.info("Conexión a DB establecida")
            break
        except Exception as e:
            retries += 1
            logger.warning(f"DB no disponible, reintento {retries}/10: {e}")
            time.sleep(5)
    else:
        logger.error("No se pudo conectar a la DB tras 10 intentos")
        sys.exit(1)

    seed_demo_data(db)

    logger.info(f"Iniciando simulación cada {settings.simulation_interval_seconds}s")
    while True:
        try:
            run_simulation_cycle(db)
        except Exception as e:
            logger.error(f"Error en ciclo de simulación: {e}")
            db.rollback()
        time.sleep(settings.simulation_interval_seconds)


if __name__ == "__main__":
    main()
