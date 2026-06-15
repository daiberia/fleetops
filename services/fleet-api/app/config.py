from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Base de datos — viene del Key Vault via CSI driver
    database_url: str = "postgresql://fleetops:password@localhost:5432/fleetops"

    # JWT — viene del Key Vault via CSI driver
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    # App
    app_name: str = "FleetOps API"
    app_version: str = "0.1.0"
    debug: bool = False

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
