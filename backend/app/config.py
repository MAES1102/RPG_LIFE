from __future__ import annotations

import os
from dataclasses import dataclass

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


@dataclass(frozen=True)
class Settings:
    """Конфигурация бэкенда RPG_LIFE."""

    app_name: str = "RPG_LIFE API"
    app_version: str = "0.1.0"
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    supabase_url: str = os.getenv("SUPABASE_URL", "")
    supabase_key: str = os.getenv("SUPABASE_KEY", "")

    @property
    def has_gemini(self) -> bool:
        return bool(self.gemini_api_key and self.gemini_api_key != "your_gemini_api_key_here")

    @property
    def has_supabase(self) -> bool:
        return bool(
            self.supabase_url
            and self.supabase_key
            and "your-project-id" not in self.supabase_url
        )


settings = Settings()
