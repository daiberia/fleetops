import random
import math
from datetime import datetime


# Rutas simuladas — coordenadas reales de España
ROUTES = {
    "madrid_barcelona": {
        "waypoints": [(40.4168, -3.7038), (41.3874, 2.1686)],
        "name": "Madrid-Barcelona"
    },
    "sevilla_malaga": {
        "waypoints": [(37.3891, -5.9845), (36.7213, -4.4214)],
        "name": "Sevilla-Málaga"
    },
    "bilbao_madrid": {
        "waypoints": [(43.2630, -2.9350), (40.4168, -3.7038)],
        "name": "Bilbao-Madrid"
    },
}


def generate_telemetry_event(vehicle_id: int, current_fuel: float) -> dict:
    """
    Genera un evento de telemetría realista para un vehículo.
    Simula movimiento entre dos puntos de una ruta aleatoria.
    """
    route = random.choice(list(ROUTES.values()))
    start, end = route["waypoints"]

    # Interpolar posición aleatoria entre los dos waypoints
    t = random.uniform(0, 1)
    lat = start[0] + t * (end[0] - start[0]) + random.gauss(0, 0.01)
    lon = start[1] + t * (end[1] - start[1]) + random.gauss(0, 0.01)

    # Velocidad realista para un camión: 0-120 km/h
    speed = random.gauss(80, 20)
    speed = max(0, min(120, speed))

    # Consumo de combustible
    new_fuel = max(0, current_fuel - random.uniform(0.03, 0.08))

    return {
        "vehicle_id": vehicle_id,
        "lat": round(lat, 6),
        "lon": round(lon, 6),
        "speed": round(speed, 1),
        "fuel": round(new_fuel, 2),
        "timestamp": datetime.utcnow(),
    }


def should_generate_alert(fuel: float, speed: float) -> dict | None:
    """
    Evalúa si un evento de telemetría debe generar una alerta.
    Devuelve la alerta o None.
    """
    if fuel < 15:
        return {
            "type": "fuel_low",
            "severity": "high" if fuel < 5 else "medium",
            "message": f"Combustible bajo: {fuel:.1f}%",
        }
    if speed > 110:
        return {
            "type": "speed",
            "severity": "high",
            "message": f"Velocidad excesiva: {speed:.1f} km/h",
        }
    return None
