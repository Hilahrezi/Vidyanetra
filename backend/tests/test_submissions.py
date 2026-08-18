import base64

from tests.conftest import auth_headers


def _fake_crop(size_kb: int = 8) -> str:
    return base64.b64encode(b"x" * (size_kb * 1024)).decode()


def _setup_exam(client, token, n_mcq=2, n_short=1, n_essay=1):
    resp = client.post("/classes", json={"name": "Kelas 8A", "grade_level": "8"}, headers=auth_headers(token))
    class_id = resp.json()["id"]
    resp = client.post("/exams", json={"class_id": class_id, "title": "UTS", "total_score": 100}, headers=auth_headers(token))
    exam_id = resp.json()["id"]
    headers = auth_headers(token)

    number = 1
    for qtype, count in (("mcq", n_mcq), ("short", n_short), ("essay", n_essay)):
        for _ in range(count):
            client.post(
                f"/exams/{exam_id}/questions",
                json={"question_number": number, "type": qtype, "answer_key": "A", "weight": 2},
                headers=headers,
            )
            number += 1

    resp = client.post(f"/classes/{class_id}/students", json={"name": "Ani", "student_number": "01"}, headers=headers)
    student_id = resp.json()["id"]
    return exam_id, student_id, class_id


def _upload(client, token, exam_id, student_id, n_questions=4):
    crops = [{"question_number": n, "image_base64": _fake_crop()} for n in range(1, n_questions + 1)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(token),
    )
    return resp


def test_upload_and_grading_flow(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    resp = _upload(client, teacher_a, exam_id, student_id)
    assert resp.status_code == 202
    submission_id = resp.json()["id"]

    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a))
    assert detail.status_code == 200
    body = detail.json()
    assert body["status"] == "graded"  # background task mock selesai
    assert body["student_name"] == "Ani"
    assert len(body["details"]) == 4
    for d in body["details"]:
        assert d["status"] == "done"
        assert d["image_url"].startswith("/uploads/")
        assert d["similarity_score"] is not None

    # submission terdaftar di daftar per ujian
    listed = client.get(f"/exams/{exam_id}/submissions", headers=auth_headers(teacher_a))
    assert listed.status_code == 200
    assert any(s["id"] == submission_id for s in listed.json())


def test_upload_validations(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)

    # crop kurang
    resp = _upload(client, teacher_a, exam_id, student_id, n_questions=2)
    assert resp.status_code == 422

    # nomor soal tidak ada
    crops = [{"question_number": n, "image_base64": _fake_crop()} for n in (1, 2, 3, 99)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 422

    # nomor ganda
    crops = [{"question_number": n, "image_base64": _fake_crop()} for n in (1, 1, 3, 4)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 422

    # base64 rusak
    crops = [{"question_number": n, "image_base64": "!!!not-base64!!!"} for n in range(1, 5)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 422


def test_upload_payload_too_large(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    crops = [{"question_number": n, "image_base64": _fake_crop(size_kb=2000)} for n in range(1, 5)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 413


def test_upload_wrong_student(client, teacher_a, teacher_b):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    # siswa dari kelas guru B
    class_b = client.post("/classes", json={"name": "Kelas 7B", "grade_level": "7"}, headers=auth_headers(teacher_b)).json()
    student_b = client.post(
        f"/classes/{class_b['id']}/students", json={"name": "Budi", "student_number": "01"}, headers=auth_headers(teacher_b)
    ).json()

    resp = _upload(client, teacher_a, exam_id, student_b["id"])
    assert resp.status_code == 404


def test_review_and_finalize(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    submission_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a)).json()
    q_id = detail["details"][0]["question_id"]

    review = client.put(
        f"/submissions/{submission_id}/review",
        json={"items": [{"question_id": q_id, "overridden_score": 100}]},
        headers=auth_headers(teacher_a),
    )
    assert review.status_code == 200

    fin = client.post(f"/submissions/{submission_id}/finalize", headers=auth_headers(teacher_a))
    assert fin.status_code == 200
    assert fin.json()["status"] == "finalized"
    assert fin.json()["total_score"] is not None

    # finalize dua kali ditolak
    again = client.post(f"/submissions/{submission_id}/finalize", headers=auth_headers(teacher_a))
    assert again.status_code == 409


def test_review_ownership(client, teacher_a, teacher_b):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    submission_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    resp = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_b))
    assert resp.status_code == 404

    resp = client.post(f"/submissions/{submission_id}/finalize", headers=auth_headers(teacher_b))
    assert resp.status_code == 404


def _force_one_failed(client, token, submission_id):
    """Set 1 detail menjadi failed langsung di DB (simulasi batch gagal)."""
    from app.database import SessionLocal
    from app.models import SubmissionDetail

    db = SessionLocal()
    try:
        detail = db.query(SubmissionDetail).filter(SubmissionDetail.submission_id == submission_id).first()
        detail.status = "failed"
        detail.similarity_score = None
        detail.student_answer_text = None
        db.commit()
        return detail.question_id
    finally:
        db.close()


def test_retry_failed(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    submission_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]
    q_id = _force_one_failed(client, teacher_a, submission_id)

    resp = client.post(f"/submissions/{submission_id}/retry-failed", headers=auth_headers(teacher_a))
    assert resp.status_code == 202

    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a)).json()
    assert detail["status"] == "graded"
    retried = next(d for d in detail["details"] if d["question_id"] == q_id)
    assert retried["status"] == "done"
    assert retried["similarity_score"] is not None


def test_retry_failed_no_failed_items(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    submission_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    resp = client.post(f"/submissions/{submission_id}/retry-failed", headers=auth_headers(teacher_a))
    assert resp.status_code == 409


def test_retry_failed_after_finalize(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    submission_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]
    client.post(f"/submissions/{submission_id}/finalize", headers=auth_headers(teacher_a))

    resp = client.post(f"/submissions/{submission_id}/retry-failed", headers=auth_headers(teacher_a))
    assert resp.status_code == 409


# ---- MCQ 3-tier (Fase 4.5) ----

def _mcq_crop_bytes(key: str = "b") -> str:
    import io
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts" / "benchmark"))
    from prepare_dataset import render_mcq_option

    buffer = io.BytesIO()
    render_mcq_option(key).save(buffer, format="JPEG", quality=90)
    return base64.b64encode(buffer.getvalue()).decode()


def _mcq_exam(client, token, key="B"):
    """Ujian 1 soal MCQ key 'B' + 1 soal isian."""
    resp = client.post("/classes", json={"name": "Kelas MCQ", "grade_level": "8"}, headers=auth_headers(token))
    class_id = resp.json()["id"]
    resp = client.post("/exams", json={"class_id": class_id, "title": "UTS MCQ", "total_score": 100}, headers=auth_headers(token))
    exam_id = resp.json()["id"]
    for number, qtype, answer_key in ((1, "mcq", key), (2, "short", "Jakarta")):
        client.post(
            f"/exams/{exam_id}/questions",
            json={"question_number": number, "type": qtype, "answer_key": answer_key, "weight": 5},
            headers=auth_headers(token),
        )
    student_id = client.post(
        f"/classes/{class_id}/students", json={"name": "Ani", "student_number": "01"}, headers=auth_headers(token)
    ).json()["id"]
    return exam_id, student_id


def test_mcq_tier1_mobile_answer_dipakai(client, teacher_a):
    """Mobile kirim jawaban jelas -> langsung dipakai (tanpa Gemini), model_used=mobile-cv."""
    exam_id, student_id = _mcq_exam(client, teacher_a)
    crops = [
        {"question_number": 1, "image_base64": _mcq_crop_bytes("b"), "mcq_answer": "b", "mcq_ambiguous": False},
        {"question_number": 2, "image_base64": _fake_crop()},
    ]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 202
    submission_id = resp.json()["id"]

    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a)).json()
    mcq = next(d for d in detail["details"] if d["question_number"] == 1)
    assert mcq["model_used"] == "mobile-cv"
    assert mcq["is_correct"] is True
    assert mcq["similarity_score"] == 100.0


def test_mcq_tier2_backend_cv_saat_mobile_ambigu(client, teacher_a):
    """Mobile ambigu (tanpa mcq_answer) -> backend CV mendeteksi sendiri."""
    exam_id, student_id = _mcq_exam(client, teacher_a)
    crops = [
        {"question_number": 1, "image_base64": _mcq_crop_bytes("b"), "mcq_ambiguous": True},
        {"question_number": 2, "image_base64": _fake_crop()},
    ]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    assert resp.status_code == 202
    submission_id = resp.json()["id"]

    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a)).json()
    mcq = next(d for d in detail["details"] if d["question_number"] == 1)
    assert mcq["model_used"] == "cv-mcq"
    assert mcq["is_correct"] is True


def test_mcq_tier2_salah_tetap_salah(client, teacher_a):
    """CV mendeteksi X di 'a' tapi kunci 'B' -> is_correct False, skor 0."""
    exam_id, student_id = _mcq_exam(client, teacher_a)
    crops = [
        {"question_number": 1, "image_base64": _mcq_crop_bytes("a")},
        {"question_number": 2, "image_base64": _fake_crop()},
    ]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(teacher_a),
    )
    submission_id = resp.json()["id"]
    detail = client.get(f"/submissions/{submission_id}/details", headers=auth_headers(teacher_a)).json()
    mcq = next(d for d in detail["details"] if d["question_number"] == 1)
    assert mcq["model_used"] == "cv-mcq"
    assert mcq["is_correct"] is False
    assert mcq["similarity_score"] == 0.0
