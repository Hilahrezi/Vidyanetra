"""Simulasi alur submission end-to-end terhadap backend yang sedang berjalan.

Menggunakan data seed (guru@sekolah.id / rahasia123, ujian "UTS Matematika Genap"):
1. Login
2. Ambil soal ujian
3. Upload crop dummy untuk setiap soal (gambar noise, base64)
4. Polling status hingga graded
5. Tampilkan ringkasan hasil per soal (mock AI)
6. Finalize

usage: python scripts/simulate_upload.py [--base http://127.0.0.1:8000] [--student 1]
"""

import argparse
import base64
import io
import time

import httpx
from PIL import Image


def fake_crop(question_type: str, seed: int) -> str:
    width = 200 if question_type == "mcq" else (400 if question_type == "short" else 600)
    img = Image.new("RGB", (width, 150), color=(seed * 37 % 255, seed * 91 % 255, seed * 17 % 255))
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=70)
    return base64.b64encode(buffer.getvalue()).decode()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8000")
    parser.add_argument("--student", type=int, default=1)
    args = parser.parse_args()

    client = httpx.Client(base_url=args.base, timeout=30)

    login = client.post("/auth/login", json={"email": "guru@sekolah.id", "password": "rahasia123"})
    login.raise_for_status()
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("1. Login OK")

    exams = client.get("/exams", headers=headers).json()
    exam = next(e for e in exams if e["title"].startswith("UTS Matematika"))
    questions = client.get(f"/exams/{exam['id']}/questions", headers=headers).json()
    print(f"2. Ujian '{exam['title']}' — {len(questions)} soal")

    crops = [
        {"question_number": q["question_number"], "image_base64": fake_crop(q["type"], q["question_number"])}
        for q in questions
    ]
    upload = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam["id"], "student_id": args.student, "crops": crops},
        headers=headers,
    )
    upload.raise_for_status()
    submission_id = upload.json()["id"]
    print(f"3. Upload OK — submission #{submission_id}")

    for _ in range(20):
        detail = client.get(f"/submissions/{submission_id}/details", headers=headers).json()
        if detail["status"] in ("graded", "finalized"):
            break
        time.sleep(1)
    print(f"4. Status: {detail['status']}")
    for d in detail["details"]:
        print(f"   Soal {d['question_number']}: [{d['status']}] skor={d['similarity_score']} "
              f"text='{d['student_answer_text']}'")

    finalize = client.post(f"/submissions/{submission_id}/finalize", headers=headers)
    finalize.raise_for_status()
    print(f"5. Finalized — total_score = {finalize.json()['total_score']}")

    diff = client.get(f"/analytics/exams/{exam['id']}/question-difficulty", headers=headers).json()
    print(f"6. Analitik: {len(diff['questions'])} soal, rata-rata per soal tersedia")
    csv_resp = client.get(f"/exams/{exam['id']}/export.csv", headers=headers)
    csv_resp.raise_for_status()
    print(f"7. Export CSV OK ({len(csv_resp.text)} bytes)")


if __name__ == "__main__":
    main()
