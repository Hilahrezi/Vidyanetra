from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "AutoGrading API"
    database_url: str = "sqlite:///./autograding.db"

    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    gemini_api_key: str = ""
    gemini_model_mcq: str = "gemini-3.5-flash-lite"
    gemini_model_short: str = "gemini-3.5-flash-lite"
    gemini_model_essay: str = "gemini-3.5-flash"
    gemini_model_fallback: str = "gemini-3.5-flash-lite"
    gemini_mock_mode: bool = False

    similarity_threshold: int = 70
    upload_dir: str = "uploads"

    @property
    def upload_path(self) -> Path:
        return BASE_DIR / self.upload_dir


settings = Settings()
