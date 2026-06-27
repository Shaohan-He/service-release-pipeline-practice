from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def test_root_endpoint() -> None:
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "release-demo-service"
    assert "/healthz" in body["endpoints"]


def test_healthz() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readyz() -> None:
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"ready": True}


def test_version_defaults() -> None:
    response = client.get("/version")
    assert response.status_code == 200
    body = response.json()
    assert body["app"] == "release-demo-service"
    assert body["version"] == "v1.0.0"
    assert body["environment"] == "dev"


def test_order_success() -> None:
    response = client.get("/api/order")
    assert response.status_code == 200
    assert response.json() == {
        "order_id": "demo-001",
        "status": "created",
        "service": "release-demo-service",
    }


def test_order_failure() -> None:
    response = client.get("/api/order?fail=true")
    assert response.status_code == 500
    assert response.json()["detail"] == "simulated order failure"
