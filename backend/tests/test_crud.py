from tests.conftest import (
    auth_headers,
    create_test_class,
    create_test_student,
)


def _create_exam(client, token, class_id):
    resp = client.post(
        "/exams",
        json={"class_id": class_id, "title": "UTS", "total_score": 100},
        headers=auth_headers(token),
    )
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
def test_class_crud(client, teacher_a, admin_user):
    headers = auth_headers(teacher_a)
    admin_headers = auth_headers(admin_user)
    class_id = create_test_class(client, admin_user, teacher_a, name="Kelas 8A")

    listed = client.get("/classes", headers=headers)
    assert listed.status_code == 200
    assert any(c["id"] == class_id for c in listed.json())

    updated = client.put(f"/classes/{class_id}", json={"name": "Kelas 8B"}, headers=admin_headers)
    assert updated.status_code == 200
    assert updated.json()["name"] == "Kelas 8B"

    deleted = client.delete(f"/classes/{class_id}", headers=admin_headers)
    assert deleted.status_code == 204


def test_class_ownership(client, teacher_a, teacher_b, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    resp = client.get(f"/classes/{class_id}", headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.put(f"/classes/{class_id}", json={"name": "Hack"}, headers=auth_headers(teacher_b))
    assert resp.status_code == 403

    resp = client.delete(f"/classes/{class_id}", headers=auth_headers(teacher_b))
    assert resp.status_code == 403


def test_class_not_found(client, teacher_a):
    resp = client.get("/classes/9999", headers=auth_headers(teacher_a))
    assert resp.status_code == 404


# ---- Students ----
def test_student_flow(client, teacher_a, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    admin_headers = auth_headers(admin_user)
    teacher_headers = auth_headers(teacher_a)

    resp = client.post(
        f"/classes/{class_id}/students",
        json={"name": "Ani", "student_number": "01"},
        headers=admin_headers,
    )
    assert resp.status_code == 201

    bulk = client.post(
        f"/classes/{class_id}/students/bulk",
        json=[{"name": "Budi", "student_number": "02"}, {"name": "Citra", "student_number": "03"}],
        headers=admin_headers,
    )
    assert bulk.status_code == 201
    assert len(bulk.json()) == 2

    listed = client.get(f"/classes/{class_id}/students", headers=teacher_headers)
    assert listed.status_code == 200
    assert len(listed.json()) == 3

    sid = listed.json()[0]["id"]
    updated = client.put(
        f"/students/{sid}",
        json={"name": "Ani Updated", "student_number": "01"},
        headers=admin_headers,
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Ani Updated"


def test_student_ownership(client, teacher_a, teacher_b, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    sid = create_test_student(client, admin_user, class_id, name="Ani", number="01")

    resp2 = client.get(f"/classes/{class_id}/students", headers=auth_headers(teacher_b))
    assert resp2.status_code == 404

    resp3 = client.delete(f"/students/{sid}", headers=auth_headers(teacher_b))
    assert resp3.status_code == 403


# ---- Exams & Questions ----
def test_exam_question_flow(client, teacher_a, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    exam = _create_exam(client, teacher_a, class_id)
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


def test_exam_ownership(client, teacher_a, teacher_b, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    exam = _create_exam(client, teacher_a, class_id)

    resp = client.get(f"/exams/{exam['id']}", headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.post(
        f"/exams/{exam['id']}/questions",
        json={"question_number": 1, "type": "mcq", "answer_key": "A", "weight": 2},
        headers=auth_headers(teacher_b),
    )
    assert resp.status_code == 404


def test_cross_teacher_exam_creation(client, teacher_a, teacher_b, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    resp = client.post(
        "/exams", json={"class_id": class_id, "title": "Hack", "total_score": 100}, headers=auth_headers(teacher_b)
    )
    assert resp.status_code == 404


def test_exam_template_pdf_generation(client, teacher_a, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a)
    exam = _create_exam(client, teacher_a, class_id)
    headers = auth_headers(teacher_a)

    # 400 if no questions
    empty_resp = client.get(f"/exams/{exam['id']}/template.pdf", headers=headers)
    assert empty_resp.status_code == 400

    # Add questions
    _create_question(client, teacher_a, exam["id"], number=1, qtype="mcq")
    _create_question(client, teacher_a, exam["id"], number=2, qtype="short", key="Jawaban")
    _create_question(client, teacher_a, exam["id"], number=3, qtype="essay", key="Gagasan")

    resp = client.get(f"/exams/{exam['id']}/template.pdf", headers=headers)
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/pdf"
    assert resp.content.startswith(b"%PDF")


def test_class_and_exam_subject_relation(client, teacher_a, admin_user):
    class_id = create_test_class(client, admin_user, teacher_a, name="Kelas 8A", grade="8", subject="Matematika")

    # Create exam in that class with custom title
    exam_resp = client.post(
        "/exams",
        json={"class_id": class_id, "title": "UTS Aljabar", "total_score": 100},
        headers=auth_headers(teacher_a),
    )
    assert exam_resp.status_code == 201
    exam = exam_resp.json()
    assert exam["subject"] == "Matematika"
    assert "Matematika — Kelas 8A" in exam["class_name"]


def test_auto_calculated_exam_score(client, teacher_a, admin_user):
    headers = auth_headers(teacher_a)
    class_id = create_test_class(client, admin_user, teacher_a)
    exam = _create_exam(client, teacher_a, class_id)
    exam_id = exam["id"]

    # 1. Add MCQ (weight 5)
    q1 = _create_question(client, teacher_a, exam_id, number=1, qtype="mcq", weight=5)
    e1 = client.get(f"/exams/{exam_id}", headers=headers).json()
    assert e1["total_score"] == 5

    # 2. Add Short Answer (weight 10)
    q2 = _create_question(client, teacher_a, exam_id, number=2, qtype="short", weight=10)
    e2 = client.get(f"/exams/{exam_id}", headers=headers).json()
    assert e2["total_score"] == 15

    # 3. Add Essay (weight 20)
    q3 = _create_question(client, teacher_a, exam_id, number=3, qtype="essay", weight=20)
    e3 = client.get(f"/exams/{exam_id}", headers=headers).json()
    assert e3["total_score"] == 35

    # 4. Delete Essay -> should be 15
    del_resp = client.delete(f"/questions/{q3['id']}", headers=headers)
    assert del_resp.status_code == 204
    e4 = client.get(f"/exams/{exam_id}", headers=headers).json()
    assert e4["total_score"] == 15

    # 5. Add questions with weights that exceed 100 -> auto rescale to 100
    q_heavy = _create_question(client, teacher_a, exam_id, number=3, qtype="essay", weight=150)
    e5 = client.get(f"/exams/{exam_id}", headers=headers).json()
    assert e5["total_score"] == 100


def test_cascade_delete_class_with_data(client, teacher_a, admin_user):
    admin_headers = auth_headers(admin_user)
    teacher_headers = auth_headers(teacher_a)
    class_id = create_test_class(client, admin_user, teacher_a, name="Kelas 9Z")
    student_id = create_test_student(client, admin_user, class_id, name="Budi", number="01")
    exam = _create_exam(client, teacher_a, class_id)
    exam_id = exam["id"]
    _create_question(client, teacher_a, exam_id, number=1, qtype="mcq", weight=10)

    # Delete class as admin
    del_res = client.delete(f"/classes/{class_id}", headers=admin_headers)
    assert del_res.status_code == 204

    # Verify class, exam, student are gone
    assert client.get(f"/classes/{class_id}", headers=teacher_headers).status_code == 404
    assert client.get(f"/exams/{exam_id}", headers=teacher_headers).status_code == 404
