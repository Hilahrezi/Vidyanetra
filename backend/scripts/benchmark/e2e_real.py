"""E2E pipeline produksi dengan Gemini REAL menggunakan dataset benchmark.

Alur: login -> buat kelas/ujian/soal (kunci dari ground_truth) -> upload crop
sintetis -> poll grading (GeminiClient produksi: interleaved batching) ->
bandingkan hasil vs ground truth -> finalize.

Requires: server uvicorn jalan + GEMINI_API_KEY terisi + mock mode OFF.

usage: python scripts/benchmark/e2e_real.py [--base http://127.0.0.1:8000]
"""

import argparse
import base64
import json
import sys
import time
from pathlib import Path

import httpx

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"

KEY_TO_TYPE = {"mcq": "mcq", "short": "short", "essay": "essay"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    ground_truth = json.loads((DATA_DIR / "ground_truth.json").read_text(encoding="utf-8"))
    client = httpx.Client(base_url=args.base, timeout=180)

    login = client.post("/auth/login", json={"email": "guru@sekolah.id", "password": "rahasia123"})
    login.raise_for_status()
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    print("1. Login OK")

    class_id = client.post("/classes", json={"name": "Kelas Benchmark", "grade_level": "8"}, headers=headers).json()["id"]
    exam_id = client.post("/exams", json={"class_id": class_id, "title": "UTS Benchmark AI", "total_score": 100}, headers=headers).json()["id"]
    for i, g in enumerate(ground_truth, start=1):
        client.post(
            f"/exams/{exam_id}/questions",
            json={"question_number": i, "type": KEY_TO_TYPE[g["task"]], "answer_key": g["key"], "weight": 1},
            headers=headers,
        )
    student_id = client.post(
        f"/classes/{class_id}/students", json={"name": "Siswa Bench", "student_number": "01"}, headers=headers
    ).json()["id"]
    print(f"2. Ujian #{exam_id} dibuat ({len(ground_truth)} soal, kunci dari ground truth)")

    crops = []
    for i, g in enumerate(ground_truth, start=1):
        raw = (DATA_DIR / g["image"]).read_bytes()
        crops.append({"question_number": i, "image_base64": base64.b64encode(raw).decode()})
    upload = client.post(
        "/submissions/upload-crops",
        json={"exam_id": exam_id, "student_id": student_id, "crops": crops},
        headers=headers,
    )
    upload.raise_for_status()
    submission_id = upload.json()["id"]
    print(f"3. Upload OK -> submission #{submission_id} (evaluasi Gemini real berjalan...)")

    detail = None
    for _ in range(90):
        detail = client.get(f"/submissions/{submission_id}/details", headers=headers).json()
        if detail["status"] in ("graded", "finalized"):
            break
        time.sleep(2)
    if detail is None or detail["status"] not in ("graded", "finalized"):
        print("ERROR: timeout menunggu grading")
        sys.exit(1)

    print(f"4. Status: {detail['status']}")
    print(f"   {'Soal':<4} {'Tipe':<6} {'Extracted (AI)':<38} {'Skor':>5} {'Expected':<10} {'OK?'}")
    print("   " + "-" * 80)
    mismatches = 0
    for d in sorted(detail["details"], key=lambda x: x["question_number"]):
        gt = ground_truth[d["question_number"] - 1]
        expected = gt["expected_text"] or f"skor {gt['score_range']}"
        ai_text = (d["student_answer_text"] or "").strip()
        ok = ai_text.lower().strip() == gt["expected_text"].lower().strip() if gt["expected_text"] else True
        if not ok:
            mismatches += 1
        print(
            f"   {d['question_number']:<4} {gt['task']:<6} {(ai_text[:37] or '-'):<38} "
            f"{d['similarity_score'] or 0:>5.0f} {expected:<10} {'V' if ok else 'X'}"
        )
    print(f"\n   HWR mismatch (teks tidak persis): {mismatches}/{len(ground_truth)}")

    finalize = client.post(f"/submissions/{submission_id}/finalize", headers=headers)
    finalize.raise_for_status()
    print(f"5. Finalized — total_score = {finalize.json()['total_score']}")

    dist = client.get(f"/analytics/exams/{exam_id}/distribution", headers=headers).json()
    print(f"6. Distribusi: total={dist['total']}, bucket 90-100 = {dist['buckets'][9]['count']}")


if __name__ == "__main__":
    main()
