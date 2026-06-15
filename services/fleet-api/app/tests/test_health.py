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
