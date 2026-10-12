import os
import tempfile

_DB_PRUEBAS = os.path.join(tempfile.gettempdir(), "smartcompost_test.db")
os.environ["DATABASE_URL"] = "sqlite:///" + _DB_PRUEBAS.replace("\\", "/")
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.seed import sembrar  # noqa: E402


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        sembrar(db, dias_historial=8)
    with TestClient(app) as c:
        yield c


def _login(client, correo, password):
    r = client.post("/auth/login", json={"correo": correo, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def admin(client):
    return _login(client, "admin@smartcompost.com", "Admin12345")


@pytest.fixture()
def estudiante(client):
    return _login(client, "estudiante@smartcompost.com", "Estudiante123")
