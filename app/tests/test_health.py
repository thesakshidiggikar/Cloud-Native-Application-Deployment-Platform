from fastapi.testclient import TestClient
from redis.exceptions import RedisError

from devopshere_api.config import Settings
from devopshere_api.main import create_app


class FakeRedis:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}
        self.fail = False

    def _check(self) -> None:
        if self.fail:
            raise RedisError("simulated Redis outage")

    def ping(self) -> bool:
        self._check()
        return True

    def get(self, key: str) -> str | None:
        self._check()
        return self.values.get(key)

    def set(self, key: str, value: str, ex: int | None = None) -> bool:
        self._check()
        self.values[key] = value
        return True

    def scan_iter(self, match: str) -> list[str]:
        self._check()
        prefix = match.removesuffix("*")
        return [key for key in self.values if key.startswith(prefix)]

    def delete(self, *keys: str) -> int:
        self._check()
        removed = 0
        for key in keys:
            removed += self.values.pop(key, None) is not None
        return removed

    def close(self) -> None:
        return None


def make_sqlite_engine():
    from sqlalchemy import create_engine
    from sqlalchemy.pool import StaticPool

    return create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )


def make_test_app(engine, cache):
    from sqlalchemy.orm import sessionmaker

    from devopshere_api.models import Base

    Base.metadata.create_all(engine)
    app = create_app(Settings(cache_ttl_seconds=30), engine_override=engine, cache_override=cache)
    app.state.session_factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    return app


def test_liveness_does_not_require_dependencies() -> None:
    with TestClient(create_app(Settings())) as client:
        response = client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_requires_postgres() -> None:
    with TestClient(create_app(Settings())) as client:
        response = client.get("/health/ready")
    assert response.status_code == 503
    assert response.json()["dependencies"]["postgresql"] == "unavailable"


def test_task_crud_and_cache_invalidation() -> None:
    engine = make_sqlite_engine()
    cache = FakeRedis()
    app = make_test_app(engine, cache)
    try:
        with TestClient(app) as client:
            created = client.post(
                "/api/v1/tasks",
                json={"title": "  Ship API  ", "description": "first slice"},
            )
            assert created.status_code == 201
            task = created.json()
            assert task["title"] == "Ship API"
            assert task["status"] == "open"
            task_id = task["id"]

            listed = client.get("/api/v1/tasks")
            assert listed.status_code == 200
            assert len(listed.json()) == 1
            assert listed.headers["X-Request-ID"]

            updated = client.patch(f"/api/v1/tasks/{task_id}", json={"status": "done"})
            assert updated.status_code == 200
            assert updated.json()["status"] == "done"
            assert client.get(f"/api/v1/tasks/{task_id}").json()["status"] == "done"

            assert client.delete(f"/api/v1/tasks/{task_id}").status_code == 204
            assert client.get(f"/api/v1/tasks/{task_id}").status_code == 404
            assert client.get("/api/v1/tasks").json() == []
    finally:
        engine.dispose()


def test_task_validation_and_not_found() -> None:
    engine = make_sqlite_engine()
    app = make_test_app(engine, FakeRedis())
    try:
        with TestClient(app) as client:
            assert client.post("/api/v1/tasks", json={"title": "   "}).status_code == 422
            assert client.patch("/api/v1/tasks/unknown", json={}).status_code == 422
            assert client.get("/api/v1/tasks/unknown").status_code == 404
            assert client.patch(
                "/api/v1/tasks/unknown", json={"status": "blocked"}
            ).status_code == 422
    finally:
        engine.dispose()


def test_redis_outage_degrades_cache_but_not_api() -> None:
    engine = make_sqlite_engine()
    cache = FakeRedis()
    cache.fail = True
    app = make_test_app(engine, cache)
    try:
        with TestClient(app) as client:
            readiness = client.get("/health/ready")
            created = client.post("/api/v1/tasks", json={"title": "uncached task"})
            listed = client.get("/api/v1/tasks")
        assert readiness.status_code == 200
        assert readiness.json()["dependencies"]["redis"] == "degraded"
        assert created.status_code == 201
        assert len(listed.json()) == 1
    finally:
        engine.dispose()


def test_api_metadata_uses_settings() -> None:
    with TestClient(create_app(Settings(name="Test API", version="9.8.7"))) as client:
        response = client.get("/openapi.json")
    assert response.status_code == 200
    assert response.json()["info"]["title"] == "Test API"
    assert response.json()["info"]["version"] == "9.8.7"
