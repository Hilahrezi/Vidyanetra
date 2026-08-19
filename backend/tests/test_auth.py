from tests.conftest import auth_headers


def test_health_public(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_register_login_flow(client):
    resp = client.post("/auth/register", json={"email": "baru@sekolah.id", "password": "pass123"})
    assert resp.status_code == 201
    assert resp.json()["email"] == "baru@sekolah.id"

    wrong = client.post("/auth/login", json={"email": "baru@sekolah.id", "password": "salah"})
    assert wrong.status_code == 401

    ok = client.post("/auth/login", json={"email": "baru@sekolah.id", "password": "pass123"})
    assert ok.status_code == 200
    assert ok.json()["token_type"] == "bearer"
    assert ok.json()["user"]["role"] == "teacher"


def test_duplicate_email_rejected(client):
    resp = client.post("/auth/register", json={"email": "dupe@sekolah.id", "password": "x12345"})
    assert resp.status_code == 201
    resp2 = client.post("/auth/register", json={"email": "dupe@sekolah.id", "password": "x12345"})
    assert resp2.status_code == 409


def test_protected_endpoint_requires_token(client):
    resp = client.get("/classes")
    assert resp.status_code == 401

    bad = client.get("/classes", headers=auth_headers("token.rusak.123"))
    assert bad.status_code == 401


def test_invalid_token_rejected(client):
    resp = client.get("/classes", headers=auth_headers("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI5OTkifQ.invalid"))
    assert resp.status_code == 401


def test_get_me_success(client, teacher_a):
    resp = client.get("/auth/me", headers=auth_headers(teacher_a))
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == "guru_a@sekolah.id"
    assert data["role"] == "teacher"
