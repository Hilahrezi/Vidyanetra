import os

os.environ["DATABASE_URL"] = "sqlite:///./test_autograding.db"
os.environ["GEMINI_MOCK_MODE"] = "true"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["JWT_EXPIRE_MINUTES"] = "60"

import pytest
from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

TEST_DB = "test_autograding.db"


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    engine.dispose()
    if os.path.exists(TEST_DB):
        os.remove(TEST_DB)


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def _register(client: TestClient, email: str, password: str) -> dict:
    resp = client.post("/auth/register", json={"email": email, "password": password})
    if resp.status_code == 409:
        login = client.post("/auth/login", json={"email": email, "password": password})
        assert login.status_code == 200
        return login.json()["access_token"]
    assert resp.status_code == 201
    login = client.post("/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200
    return login.json()["access_token"]


@pytest.fixture()
def teacher_a(client):
    return _register(client, "guru_a@sekolah.id", "rahasia123")


@pytest.fixture()
def teacher_b(client):
    return _register(client, "guru_b@sekolah.id", "rahasia123")


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
