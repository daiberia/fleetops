from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch

# Mock de la DB para que el test no necesite PostgreSQL real
with patch("app.database.create_engine"):
    with patch("app.database.Base.metadata.create_all"):
        from app.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "FleetOps API"


def test_health_check_healthy():
    mock_db = MagicMock()
    with patch("app.routers.health.get_db", return_value=iter([mock_db])):
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "database": "connected"}


def test_health_check_unhealthy():
    mock_db = MagicMock()
    mock_db.execute.side_effect = Exception("connection refused")
    with patch("app.routers.health.get_db", return_value=iter([mock_db])):
        response = client.get("/health")
    assert response.status_code == 503
    assert response.json() == {"status": "unhealthy", "database": "unavailable"}
    assert "connection refused" not in response.text