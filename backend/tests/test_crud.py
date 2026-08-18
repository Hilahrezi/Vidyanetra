from tests.conftest import auth_headers


def _create_class(client, token, name="Kelas 8A", grade="8"):
    resp = client.post("/classes", json={"name": name, "grade_level": grade}, headers=auth_headers(token))
    assert resp.status_code == 201
    return resp.json()


def _create_exam(client, token, class_id):
    resp = client.post("/exams", json={"class_id": class_id, "title": "UTS", "total_score": 100}, headers=auth_headers(token))
    assert resp.status_code == 201
    return resp.json()


def _create_question(client, token, exam_id, number=1, qtype="mcq", key="A", weight=2):
    resp = client.post(
        f"/exams/{exam_id}/questions",
        json={"question_number": number, "type": qtype, "answer_key": key, "weight": weight},
        headers=auth_headers(token),
    )
    assert resp.status_code == 201
    return resp.json()


# ---- Classes ----
def test_class_crud(client, teacher_a):
    headers = auth_headers(teacher_a)
    class_ = _create_class(client, teacher_a)
    class_id = class_["id"]

    listed = client.get("/classes", headers=headers)
    assert listed.status_code == 200
    assert any(c["id"] == class_id for c in listed.json())

    updated = client.put(f"/classes/{class_id}", json={"name": "Kelas 8B"}, headers=headers)
    assert updated.status_code == 200
    assert updated.json()["name"] == "Kelas 8B"

    deleted = client.delete(f"/classes/{class_id}", headers=headers)
    assert deleted.status_code == 204


def test_class_ownership(client, teacher_a, teacher_b):
    class_ = _create_class(client, teacher_a)
    resp = client.get(f"/classes/{class_['id']}", headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.put(f"/classes/{class_['id']}", json={"name": "Hack"}, headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.delete(f"/classes/{class_['id']}", headers=auth_headers(teacher_b))
    assert resp.status_code == 404


def test_class_not_found(client, teacher_a):
    resp = client.get("/classes/9999", headers=auth_headers(teacher_a))
    assert resp.status_code == 404


# ---- Students ----
def test_student_flow(client, teacher_a):
    class_ = _create_class(client, teacher_a)
    headers = auth_headers(teacher_a)

    resp = client.post(f"/classes/{class_['id']}/students", json={"name": "Ani", "student_number": "01"}, headers=headers)
    assert resp.status_code == 201

    bulk = client.post(
        f"/classes/{class_['id']}/students/bulk",
        json=[{"name": "Budi", "student_number": "02"}, {"name": "Citra", "student_number": "03"}],
        headers=headers,
    )
    assert bulk.status_code == 201
    assert len(bulk.json()) == 2

    listed = client.get(f"/classes/{class_['id']}/students", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()) == 3

    sid = listed.json()[0]["id"]
    updated = client.put(f"/students/{sid}", json={"name": "Ani Updated", "student_number": "01"}, headers=headers)
    assert updated.status_code == 200
    assert updated.json()["name"] == "Ani Updated"


def test_student_ownership(client, teacher_a, teacher_b):
    class_ = _create_class(client, teacher_a)
    resp = client.post(
        f"/classes/{class_['id']}/students", json={"name": "Ani", "student_number": "01"}, headers=auth_headers(teacher_a)
    )
    sid = resp.json()["id"]

    resp2 = client.get(f"/students/{sid}", headers=auth_headers(teacher_b))
    assert resp2.status_code == 405  # endpoint GET tidak ada; teacher B tidak boleh akses kelas A
    resp3 = client.delete(f"/students/{sid}", headers=auth_headers(teacher_b))
    assert resp3.status_code == 404


# ---- Exams & Questions ----
def test_exam_question_flow(client, teacher_a):
    class_ = _create_class(client, teacher_a)
    exam = _create_exam(client, teacher_a, class_["id"])
    headers = auth_headers(teacher_a)

    for n in (1, 2):
        _create_question(client, teacher_a, exam["id"], number=n)

    q3 = client.post(
        f"/exams/{exam['id']}/questions",
        json={"question_number": 3, "type": "essay", "answer_key": "jelaskan...", "weight": 10},
        headers=headers,
    )
    assert q3.status_code == 201

    listed = client.get(f"/exams/{exam['id']}/questions", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()) == 3
    assert [q["question_number"] for q in listed.json()] == [1, 2, 3]

    qid = q3.json()["id"]
    updated = client.put(
        f"/questions/{qid}",
        json={"question_number": 3, "type": "essay", "answer_key": "kunci baru", "weight": 15},
        headers=headers,
    )
    assert updated.status_code == 200
    assert updated.json()["weight"] == 15


def test_exam_ownership(client, teacher_a, teacher_b):
    class_ = _create_class(client, teacher_a)
    exam = _create_exam(client, teacher_a, class_["id"])

    resp = client.get(f"/exams/{exam['id']}", headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.post(
        f"/exams/{exam['id']}/questions",
        json={"question_number": 1, "type": "mcq", "answer_key": "A", "weight": 2},
        headers=auth_headers(teacher_b),
    )
    assert resp.status_code == 404


def test_cross_teacher_exam_creation(client, teacher_a, teacher_b):
    class_a = _create_class(client, teacher_a)
    resp = client.post(
        "/exams", json={"class_id": class_a["id"], "title": "Hack", "total_score": 100}, headers=auth_headers(teacher_b)
    )
    assert resp.status_code == 404
