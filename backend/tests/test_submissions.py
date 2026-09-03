import base64
import io

from tests.conftest import (
    auth_headers,
    create_test_class,
    create_test_student,
)


def _fake_crop(size_kb: int = 8) -> str:
    return base64.b64encode(b"x" * (size_kb * 1024)).decode()


def _setup_exam(client, admin_user, teacher_token, n_mcq=2, n_short=1, n_essay=1):
    class_id = create_test_class(client, admin_user, teacher_token, name="Kelas 8A", grade="8")
    resp = client.post(
        "/exams",
        json={"class_id": class_id, "title": "UTS", "total_score": 100},
        headers=auth_headers(teacher_token),
    )
    exam_id = resp.json()["id"]
    headers = auth_headers(teacher_token)

    number = 1
    for qtype, count in (("mcq", n_mcq), ("short", n_short), ("essay", n_essay)):
        for _ in range(count):
            client.post(
                f"/exams/{exam_id}/questions",
                json={"question_number": number, "type": qtype, "answer_key": "A", "weight": 2},
                headers=headers,
            )
            number += 1

    student_id = create_test_student(client, admin_user, class_id, name="Ani", number="01")
    return exam_id, student_id, class_id


def _upload(client, token, exam_id, student_id, n_questions=4):
    crops = [{"question_number": n, "image_base64": _fake_crop()} for n in range(1, n_questions + 1)]
    resp = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=auth_headers(token),
    )
    return resp


def test_upload_and_grading_flow(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
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


def test_upload_validations(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)

    # 1. Nomor soal ganda -> 422
    crops = [
        {"question_number": 1, "image_base64": _fake_crop()},
        {"question_number": 1, "image_base64": _fake_crop()},
    ]
    r = client.post("/submissions/upload-crops", json={"exam_id": exam_id, "student_id": student_id, "crops": crops}, headers=auth_headers(teacher_a))
    assert r.status_code == 422

    # 2. Nomor soal tidak ada -> 422
    crops = [{"question_number": 99, "image_base64": _fake_crop()}]
    r = client.post("/submissions/upload-crops", json={"exam_id": exam_id, "student_id": student_id, "crops": crops}, headers=auth_headers(teacher_a))
    assert r.status_code == 422

    # 3. Soal belum lengkap (hanya 2 dari 4) -> 422
    crops = [{"question_number": 1, "image_base64": _fake_crop()}, {"question_number": 2, "image_base64": _fake_crop()}]
    r = client.post("/submissions/upload-crops", json={"exam_id": exam_id, "student_id": student_id, "crops": crops}, headers=auth_headers(teacher_a))
    assert r.status_code == 422
    assert "Belum semua soal di-scan" in r.json()["detail"]

    # 4. base64 tidak valid -> 422
    crops = [{"question_number": n, "image_base64": "bukan base64!!!"} for n in range(1, 5)]
    r = client.post("/submissions/upload-crops", json={"exam_id": exam_id, "student_id": student_id, "crops": crops}, headers=auth_headers(teacher_a))
    assert r.status_code == 422


def test_upload_payload_too_large(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    # Payload > 5MB
    crops = [{"question_number": n, "image_base64": _fake_crop(size_kb=1500)} for n in range(1, 5)]
    r = client.post("/submissions/upload-crops", json={"exam_id": exam_id, "student_id": student_id, "crops": crops}, headers=auth_headers(teacher_a))
    assert r.status_code == 413


def test_upload_wrong_student(client, teacher_a, admin_user):
    exam_id, _, _ = _setup_exam(client, admin_user, teacher_a)
    r = _upload(client, teacher_a, exam_id, student_id=9999)
    assert r.status_code == 404


def test_review_and_finalize(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    resp = _upload(client, teacher_a, exam_id, student_id)
    sub_id = resp.json()["id"]

    detail = client.get(f"/submissions/{sub_id}/details", headers=auth_headers(teacher_a)).json()
    q1_id = detail["details"][0]["question_id"]

    # Override skor soal 1
    rev = client.put(
        f"/submissions/{sub_id}/review",
        json={"items": [{"question_id": q1_id, "overridden_score": 10.0}]},
        headers=auth_headers(teacher_a),
    )
    assert rev.status_code == 200

    # Finalisasi
    fin = client.post(f"/submissions/{sub_id}/finalize", headers=auth_headers(teacher_a))
    assert fin.status_code == 200
    assert fin.json()["status"] == "finalized"
    assert fin.json()["finalized_at"] is not None

    # Review ulang setelah finalisasi -> 409
    rev2 = client.put(
        f"/submissions/{sub_id}/review",
        json={"items": [{"question_id": q1_id, "overridden_score": 5.0}]},
        headers=auth_headers(teacher_a),
    )
    assert rev2.status_code == 409


def test_review_ownership(client, teacher_a, teacher_b, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    sub_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    resp = client.put(
        f"/submissions/{sub_id}/review",
        json={"items": [{"question_id": 1, "overridden_score": 5.0}]},
        headers=auth_headers(teacher_b),
    )
    assert resp.status_code == 404


def test_retry_failed(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    sub_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    from app.database import SessionLocal
    from app.models import SubmissionDetail

    db = SessionLocal()
    try:
        detail = db.query(SubmissionDetail).filter(SubmissionDetail.submission_id == sub_id).first()
        detail.status = "failed"
        db.commit()
    finally:
        db.close()

    retry_resp = client.post(f"/submissions/{sub_id}/retry-failed", headers=auth_headers(teacher_a))
    assert retry_resp.status_code == 202

    detail_after = client.get(f"/submissions/{sub_id}/details", headers=auth_headers(teacher_a)).json()
    assert detail_after["details"][0]["status"] == "done"


def test_retry_failed_no_failed_items(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    sub_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]

    resp = client.post(f"/submissions/{sub_id}/retry-failed", headers=auth_headers(teacher_a))
    assert resp.status_code == 409


def test_retry_failed_after_finalize(client, teacher_a, admin_user):
    exam_id, student_id, _ = _setup_exam(client, admin_user, teacher_a)
    sub_id = _upload(client, teacher_a, exam_id, student_id).json()["id"]
    client.post(f"/submissions/{sub_id}/finalize", headers=auth_headers(teacher_a))

    resp = client.post(f"/submissions/{sub_id}/retry-failed", headers=auth_headers(teacher_a))
    assert resp.status_code == 409


def _mcq_crop_bytes(key: str = "b") -> str:
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
    from prepare_dataset import render_mcq_option

    buffer = io.BytesIO()
    render_mcq_option(key).save(buffer, format="JPEG", quality=90)
    return base64.b64encode(buffer.getvalue()).decode()


def _mcq_exam(client, admin_user, teacher_token, key="B"):
    class_id = create_test_class(client, admin_user, teacher_token, name="Kelas MCQ", grade="8")
    resp = client.post(
        "/exams",
        json={"class_id": class_id, "title": "UTS MCQ", "total_score": 100},
        headers=auth_headers(teacher_token),
    )
    exam_id = resp.json()["id"]
    for number, qtype, answer_key in ((1, "mcq", key), (2, "short", "Jakarta")):
        client.post(
            f"/exams/{exam_id}/questions",
            json={"question_number": number, "type": qtype, "answer_key": answer_key, "weight": 5},
            headers=auth_headers(teacher_token),
        )
    student_id = create_test_student(client, admin_user, class_id, name="Ani", number="01")
    return exam_id, student_id


def test_mcq_tier1_mobile_answer_dipakai(client, teacher_a, admin_user):
    exam_id, student_id = _mcq_exam(client, admin_user, teacher_a)
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


def test_mcq_tier2_backend_cv_saat_mobile_ambigu(client, teacher_a, admin_user):
    exam_id, student_id = _mcq_exam(client, admin_user, teacher_a)
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


def test_mcq_tier2_salah_tetap_salah(client, teacher_a, admin_user):
    exam_id, student_id = _mcq_exam(client, admin_user, teacher_a)
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
