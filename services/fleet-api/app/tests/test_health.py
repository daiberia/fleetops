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
    # Verifica que el detalle de la excepción no se filtra al exterior
    assert "connection refused" not in response.text