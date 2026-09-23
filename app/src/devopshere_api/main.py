from contextlib import asynccontextmanager
import logging
from time import perf_counter
from typing import AsyncIterator
from uuid import uuid4

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from redis import Redis
from redis.exceptions import RedisError
from sqlalchemy import Engine

from devopshere_api.config import Settings, get_settings
from devopshere_api.database import build_engine, build_session_factory, database_is_healthy
from devopshere_api.logging_config import configure_logging
from devopshere_api.routes import router as task_router

logger = logging.getLogger(__name__)


def create_app(
    settings: Settings | None = None,
    *,
    engine_override: Engine | None = None,
    cache_override: Redis | None = None,
) -> FastAPI:
    active_settings = settings or get_settings()
    configure_logging(active_settings.log_level)

    engine = engine_override
    if engine is None and active_settings.database_url is not None:
        engine = build_engine(active_settings.database_url.get_secret_value())

    cache = cache_override
    if cache is None and active_settings.redis_url is not None:
        cache = Redis.from_url(
            active_settings.redis_url.get_secret_value(),
            decode_responses=True,
            socket_connect_timeout=1,
            socket_timeout=1,
            health_check_interval=30,
        )

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        logger.info("application_started", extra={"environment": active_settings.environment})
        yield
        if cache is not None:
            cache.close()
        if engine is not None:
            engine.dispose()
        logger.info("application_stopped")

    application = FastAPI(
        title=active_settings.name,
        version=active_settings.version,
        lifespan=lifespan,
    )
    application.state.settings = active_settings
    application.state.engine = engine
    application.state.session_factory = build_session_factory(engine) if engine is not None else None
    application.state.cache = cache
    application.include_router(task_router)

    @application.middleware("http")
    async def request_logging(request, call_next):
        request_id = uuid4().hex
        started = perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            logger.exception(
                "http_request_failed",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                },
            )
            raise
        logger.info(
            "http_request",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round((perf_counter() - started) * 1000, 2),
            },
        )
        response.headers["X-Request-ID"] = request_id
        return response

    @application.get("/health/live", tags=["health"])
    def liveness() -> dict[str, str]:
        """Indicate that the process is running; independent of dependencies."""
        return {"status": "alive"}

    @application.get("/health/ready", tags=["health"])
    def readiness():
        """Require PostgreSQL; Redis is optional because it is a cache."""
        database_status = "ok" if database_is_healthy(engine) else "unavailable"
        redis_status = "disabled"
        if cache is not None:
            try:
                cache.ping()
                redis_status = "ok"
            except RedisError:
                redis_status = "degraded"

        if database_status != "ok":
            return JSONResponse(
                status_code=503,
                content={
                    "status": "not_ready",
                    "dependencies": {"postgresql": database_status, "redis": redis_status},
                },
            )
        return {
            "status": "ready",
            "dependencies": {"postgresql": database_status, "redis": redis_status},
        }

    return application


app = create_app()
