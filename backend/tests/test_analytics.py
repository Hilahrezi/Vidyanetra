import base64

from tests.conftest import auth_headers
from tests.test_submissions import _setup_exam, _upload


def _grade_all(client, token, exam_id, student_id, n_submissions=3):
    ids = []
    for _ in range(n_submissions):
        sub_id = _upload(client, token, exam_id, student_id).json()["id"]
        client.post(f"/submissions/{sub_id}/finalize", headers=auth_headers(token))
        ids.append(sub_id)
    return ids


def test_distribution_and_difficulty(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    _grade_all(client, teacher_a, exam_id, student_id, n_submissions=3)

    dist = client.get(f"/analytics/exams/{exam_id}/distribution", headers=auth_headers(teacher_a))
    assert dist.status_code == 200
    body = dist.json()
    assert body["total"] == 3
    assert sum(b["count"] for b in body["buckets"]) == 3

    diff = client.get(f"/analytics/exams/{exam_id}/question-difficulty", headers=auth_headers(teacher_a))
    assert diff.status_code == 200
    questions = diff.json()["questions"]
    assert len(questions) == 4
    assert all(q["attempted"] == 3 for q in questions)
    assert all(q["average_score"] is not None for q in questions)


def test_analytics_ownership(client, teacher_a, teacher_b):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    resp = client.get(f"/analytics/exams/{exam_id}/distribution", headers=auth_headers(teacher_b))
    assert resp.status_code == 404


def test_export_csv(client, teacher_a):
    exam_id, student_id, _ = _setup_exam(client, teacher_a)
    _grade_all(client, teacher_a, exam_id, student_id, n_submissions=1)

    resp = client.get(f"/exams/{exam_id}/export.csv", headers=auth_headers(teacher_a))
    assert resp.status_code == 200
    assert "text/csv" in resp.headers["content-type"]
    assert "attachment" in resp.headers["content-disposition"]

    lines = resp.text.strip().splitlines()
    assert lines[0].startswith("No Absen,Nama,Status")
    assert len(lines) == 2  # header + 1 siswa
    assert lines[1].startswith("01,Ani,")
