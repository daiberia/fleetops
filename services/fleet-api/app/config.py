from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Sin default — si Key Vault/CSI falla, el servicio debe fallar al arrancar,
    # no caer en un secreto de desarrollo conocido públicamente
    database_url: str
    jwt_secret: str
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