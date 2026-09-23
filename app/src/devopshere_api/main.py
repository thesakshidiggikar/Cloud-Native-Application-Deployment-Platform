from contextlib import asynccontextmanager
import logging
from typing import AsyncIterator

from fastapi import FastAPI

from devopshere_api.config import Settings, get_settings
from devopshere_api.logging_config import configure_logging

logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    active_settings = settings or get_settings()
    configure_logging(active_settings.log_level)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        logger.info(
            "application_started",
            extra={"environment": active_settings.environment},
        )
        yield
        logger.info("application_stopped")

    application = FastAPI(
        title=active_settings.name,
        version=active_settings.version,
        lifespan=lifespan,
    )

    @application.get("/health/live", tags=["health"])
    async def liveness() -> dict[str, str]:
        """Indicate that the process is running."""
        return {"status": "alive"}

    @application.get("/health/ready", tags=["health"])
    async def readiness() -> dict[str, str]:
        """Report process readiness; dependency checks are added with DB/cache integration."""
        return {"status": "ready"}

    return application


app = create_app()
