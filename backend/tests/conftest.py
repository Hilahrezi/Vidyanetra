import os

os.environ["DATABASE_URL"] = "sqlite:///./test_autograding.db"
os.environ["GEMINI_MOCK_MODE"] = "true"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["JWT_EXPIRE_MINUTES"] = "60"

import pytest
from fastapi.testclient import TestClient

from app.auth import create_access_token, decode_token, hash_password
from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import User

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


def _register(client: TestClient, email: str, password: str) -> str:
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


@pytest.fixture()
def admin_user(client):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "admin_test@sekolah.id").first()
        if not user:
            user = User(
                name="Admin Test",
                email="admin_test@sekolah.id",
                role="admin",
                password_hash=hash_password("admin123"),
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        return create_access_token(user.id, user.role)
    finally:
        db.close()


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def get_token_user_id(token: str) -> int:
    payload = decode_token(token)
    return int(payload["sub"])


def create_test_class(
    client: TestClient,
    admin_token: str,
    teacher_token: str,
    name: str = "Kelas 8A",
    grade: str = "8",
    subject: str = "Matematika",
) -> int:
    teacher_id = get_token_user_id(teacher_token)
    resp = client.post(
        "/classes",
        json={"name": name, "grade_level": grade, "subject": subject, "teacher_id": teacher_id},
        headers=auth_headers(admin_token),
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def create_test_student(
    client: TestClient,
    admin_token: str,
    class_id: int,
    name: str = "Ani",
    number: str = "01",
) -> int:
    resp = client.post(
        f"/classes/{class_id}/students",
        json={"name": name, "student_number": number},
        headers=auth_headers(admin_token),
    )
    assert resp.status_code == 201
    return resp.json()["id"]
