"""
CIRO Backend Configuration
===========================
Uses Pydantic BaseSettings to load environment variables from .env file.
All configuration values needed by the backend are centralised here.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables / .env file."""

    # Gemini AI configuration
    GEMINI_API_KEY: str = ""

    # Google Cloud / Firestore configuration
    GCP_PROJECT_ID: str = "ciro-hackathon-2026"
    FIRESTORE_PROJECT_ID: str = "ciro-hackathon-2026"

    # Application environment
    ENVIRONMENT: str = "development"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """Cached settings instance — loaded once, reused everywhere."""
    return Settings()
