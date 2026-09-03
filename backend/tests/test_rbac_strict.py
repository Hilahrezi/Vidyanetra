from .conftest import auth_headers, get_token_user_id


def test_strict_class_rbac(client, teacher_a, admin_user):
    teacher_headers = auth_headers(teacher_a)
    admin_headers = auth_headers(admin_user)
    teacher_id = get_token_user_id(teacher_a)

    # 1. Guru dilarang membuat kelas baru (403 Forbidden)
    resp = client.post(
        "/classes",
        json={"name": "8C", "subject": "Fisika", "teacher_id": teacher_id},
        headers=teacher_headers,
    )
    assert resp.status_code == 403
    assert "Akses khusus Administrator" in resp.json()["detail"]

    # 2. Admin sukses membuat kelas dan menugaskan guru (201 Created)
    admin_resp = client.post(
        "/classes",
        json={"name": "8C", "subject": "Fisika", "teacher_id": teacher_id},
        headers=admin_headers,
    )
    assert admin_resp.status_code == 201
    class_data = admin_resp.json()
    class_id = class_data["id"]
    assert class_data["name"] == "8C"
    assert class_data["subject"] == "Fisika"
    assert class_data["grade_level"] == "8"

    # 3. Guru dapat melihat kelas yang di-assign padanya (200 OK)
    list_resp = client.get("/classes", headers=teacher_headers)
    assert list_resp.status_code == 200
    my_classes = list_resp.json()
    assert any(c["id"] == class_id for c in my_classes)

    # 4. Guru dilarang mengedit kelas (403 Forbidden)
    edit_resp = client.put(
        f"/classes/{class_id}",
        json={"subject": "Kimia"},
        headers=teacher_headers,
    )
    assert edit_resp.status_code == 403

    # 5. Admin sukses mengedit kelas (200 OK)
    admin_edit = client.put(
        f"/classes/{class_id}",
        json={"subject": "Kimia"},
        headers=admin_headers,
    )
    assert admin_edit.status_code == 200
    assert admin_edit.json()["subject"] == "Kimia"

    # 6. Guru dilarang menghapus kelas (403 Forbidden)
    del_resp = client.delete(f"/classes/{class_id}", headers=teacher_headers)
    assert del_resp.status_code == 403

    # 7. Admin sukses menghapus kelas (204 No Content)
    admin_del = client.delete(f"/classes/{class_id}", headers=admin_headers)
    assert admin_del.status_code == 204


def test_strict_student_rbac(client, teacher_a, admin_user):
    teacher_headers = auth_headers(teacher_a)
    admin_headers = auth_headers(admin_user)
    teacher_id = get_token_user_id(teacher_a)

    # Buat kelas oleh admin
    c_resp = client.post(
        "/classes",
        json={"name": "8D", "subject": "Biologi", "teacher_id": teacher_id},
        headers=admin_headers,
    )
    class_id = c_resp.json()["id"]

    # 1. Guru dilarang menambah siswa single (403 Forbidden)
    s_resp = client.post(
        f"/classes/{class_id}/students",
        json={"name": "Siswa A", "student_number": "01"},
        headers=teacher_headers,
    )
    assert s_resp.status_code == 403

    # 2. Guru dilarang bulk add siswa (403 Forbidden)
    bulk_resp = client.post(
        f"/classes/{class_id}/students/bulk",
        json=[{"name": "Siswa A", "student_number": "01"}],
        headers=teacher_headers,
    )
    assert bulk_resp.status_code == 403

    # 3. Admin sukses menambah siswa (201 Created)
    admin_s = client.post(
        f"/classes/{class_id}/students",
        json={"name": "Siswa A", "student_number": "01"},
        headers=admin_headers,
    )
    assert admin_s.status_code == 201
    student_id = admin_s.json()["id"]

    # 4. Guru boleh melihat daftar siswa (200 OK)
    list_s = client.get(f"/classes/{class_id}/students", headers=teacher_headers)
    assert list_s.status_code == 200
    assert len(list_s.json()) == 1

    # 5. Guru dilarang mengedit data siswa (403 Forbidden)
    edit_s = client.put(
        f"/students/{student_id}",
        json={"name": "Siswa A Baru", "student_number": "01"},
        headers=teacher_headers,
    )
    assert edit_s.status_code == 403

    # 6. Admin sukses mengedit data siswa (200 OK)
    admin_edit_s = client.put(
        f"/students/{student_id}",
        json={"name": "Siswa A Baru", "student_number": "01"},
        headers=admin_headers,
    )
    assert admin_edit_s.status_code == 200
    assert admin_edit_s.json()["name"] == "Siswa A Baru"

    # 7. Guru dilarang menghapus siswa (403 Forbidden)
    del_s = client.delete(f"/students/{student_id}", headers=teacher_headers)
    assert del_s.status_code == 403

    # 8. Admin sukses menghapus siswa (204 No Content)
    admin_del_s = client.delete(f"/students/{student_id}", headers=admin_headers)
    assert admin_del_s.status_code == 204
