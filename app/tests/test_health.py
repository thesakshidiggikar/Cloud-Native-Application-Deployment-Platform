from fastapi.testclient import TestClient

from devopshere_api.config import Settings
from devopshere_api.main import create_app


def test_liveness_reports_running_process() -> None:
    client = TestClient(create_app(Settings()))

    response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_reports_application_ready() -> None:
    client = TestClient(create_app(Settings()))

    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_api_metadata_uses_settings() -> None:
    client = TestClient(create_app(Settings(name="Test API", version="9.8.7")))

    response = client.get("/openapi.json")

    assert response.status_code == 200
    assert response.json()["info"]["title"] == "Test API"
    assert response.json()["info"]["version"] == "9.8.7"
