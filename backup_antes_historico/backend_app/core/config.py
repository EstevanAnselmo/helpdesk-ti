import warnings
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    environment: str = "development"
    database_url: str = "postgresql+psycopg://helpdesk:helpdesk@localhost:5432/helpdesk"
    jwt_secret: str = "change-this-secret"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 60
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    password_min_length: int = 8

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def cors_list(self) -> list[str]:
        return [x.strip() for x in self.cors_origins.split(",") if x.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production and settings.jwt_secret == "change-this-secret":
        # Nunca deixamos o segredo padrão passar despercebido em produção.
        raise RuntimeError(
            "JWT_SECRET não pode ser o valor padrão em ambiente de produção. "
            "Defina uma variável de ambiente JWT_SECRET forte."
        )
    if not settings.is_production and settings.jwt_secret == "change-this-secret":
        warnings.warn(
            "Usando JWT_SECRET padrão (inseguro). Configure um valor próprio no .env antes de ir para produção.",
            stacklevel=2,
        )
    return settings
