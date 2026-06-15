from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://fleetops:password@localhost:5432/fleetops"
    simulation_interval_seconds: int = 15   # Genera un evento cada 15s por vehículo
    fuel_consumption_rate: float = 0.05     # % de combustible por evento

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
