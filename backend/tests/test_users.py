from tests.conftest import auth_headers


def test_users_rbac_forbidden_for_teacher(client, teacher_a):
    headers = auth_headers(teacher_a)
    resp = client.get("/users", headers=headers)
    assert resp.status_code == 403
    assert "Akses khusus Administrator" in resp.json()["detail"]

    create_resp = client.post(
        "/users",
        json={"name": "Hacker", "email": "hacker@test.com", "password": "123", "role": "admin"},
        headers=headers,
    )
    assert create_resp.status_code == 403


def test_admin_user_crud(client, admin_user):
    headers = auth_headers(admin_user)

    # 1. List users
    list_resp = client.get("/users", headers=headers)
    assert list_resp.status_code == 200
    users = list_resp.json()
    assert len(users) >= 1

    # 2. Create new teacher
    create_resp = client.post(
        "/users",
        json={
            "name": "Guru Baru",
            "email": "guru_baru@sekolah.id",
            "password": "password123",
            "role": "teacher",
        },
        headers=headers,
    )
    assert create_resp.status_code == 201
    new_user = create_resp.json()
    assert new_user["name"] == "Guru Baru"
    assert new_user["email"] == "guru_baru@sekolah.id"
    assert new_user["role"] == "teacher"
    user_id = new_user["id"]

    # 3. Duplicate email check
    dup_resp = client.post(
        "/users",
        json={
            "name": "Guru Kloning",
            "email": "guru_baru@sekolah.id",
            "password": "password123",
            "role": "teacher",
        },
        headers=headers,
    )
    assert dup_resp.status_code == 400
    assert "sudah terdaftar" in dup_resp.json()["detail"]

    # 4. Get single user
    get_resp = client.get(f"/users/{user_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == user_id

    # 5. Update user
    update_resp = client.put(
        f"/users/{user_id}",
        json={"name": "Guru Terupdate", "role": "admin"},
        headers=headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Guru Terupdate"
    assert update_resp.json()["role"] == "admin"

    # 6. Delete user
    del_resp = client.delete(f"/users/{user_id}", headers=headers)
    assert del_resp.status_code == 204

    # 7. Ensure deleted
    get_del_resp = client.get(f"/users/{user_id}", headers=headers)
    assert get_del_resp.status_code == 404
