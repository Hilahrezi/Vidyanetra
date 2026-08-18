"""Analisis hasil benchmark: metrik per tugas + tabel keputusan model.

usage: python scripts/benchmark/analyze.py [--json-out results/ringkasan.json]
"""

import argparse
import difflib
import json
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
RESULTS_DIR = BASE_DIR / "results"

# Model yang TIDAK boleh dipilih produksi (pembanding/referensi saja)
REFERENCE_ONLY = {"gemini-3.5-preview"}
UNAVAILABLE = {"gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3.5-preview"}


def norm(text: str | None) -> str:
    if not text:
        return ""
    return re.sub(r"[^a-z0-9]", "", text.lower())


def text_similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, norm(a), norm(b)).ratio()


def score_item(item: dict, result: dict | None) -> dict:
    """Skor 0-100 per item berdasarkan ground truth."""
    task = item["task"]
    if result is None:
        return {"task": task, "score": 0.0, "detail": "tidak ada respons"}

    text = result.get("extracted_text") or ""
    score = result.get("similarity_score")
    correct = result.get("is_correct")
    reason = result.get("reason") or ""

    if task == "mcq":
        s_text = 60 if text_similarity(text, item["expected_text"]) >= 0.9 else 0
        s_correct = 40 if correct == item["expected_correct"] else 0
        total = s_text + s_correct
        return {"task": task, "score": total, "detail": f"text='{text}' correct={correct}"}

    if task == "short":
        s_text = 50 * text_similarity(text, item["expected_text"])
        s_correct = 30 if correct == item["expected_correct"] else 0
        lo, hi = item["score_range"]
        s_range = 20 if (score is not None and lo <= score <= hi) else 0
        return {
            "task": task,
            "score": round(s_text + s_correct + s_range, 1),
            "detail": f"text='{text}' score={score} correct={correct}",
        }

    # essay
    lo, hi = item["score_range"]
    s_score = 0.0
    if score is not None:
        if lo <= score <= hi:
            s_score = 40.0
        else:
            s_score = max(0.0, 20.0 - abs(score - (lo + hi) / 2) * 0.4)
    keywords = item["keywords"]
    found = sum(1 for k in keywords if k in norm(text)) if keywords else 0
    s_kw = 30 * (found / len(keywords)) if keywords else 30
    s_reason = 30 if len(reason) >= 25 else (15 if len(reason) > 0 else 0)
    return {
        "task": task,
        "score": round(s_score + s_kw + s_reason, 1),
        "detail": f"score={score} keywords={found}/{len(keywords)} reason_len={len(reason)}",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json-out", default=str(RESULTS_DIR / "ringkasan.json"))
    args = parser.parse_args()

    ground_truth = json.loads((DATA_DIR / "ground_truth.json").read_text(encoding="utf-8"))
    gt_by_id = {g["id"]: g for g in ground_truth}

    rows = []
    for result_file in sorted(RESULTS_DIR.glob("*.json")):
        if result_file.name == "ringkasan.json":
            continue
        payload = json.loads(result_file.read_text(encoding="utf-8"))
        model = payload["model"]

        if payload.get("error"):
            rows.append(
                {
                    "model": model,
                    "status": "ERROR",
                    "error": payload["error"][:90],
                    "mcq": None,
                    "short": None,
                    "essay": None,
                    "json_valid": False,
                    "items": 0,
                    "latency_s": payload.get("latency_s"),
                }
            )
            continue

        items = payload.get("items") or []
        by_id = {str(i.get("item_id")): i for i in items if isinstance(i, dict)}
        task_scores = {"mcq": [], "short": [], "essay": []}
        for g in ground_truth:
            scored = score_item(g, by_id.get(g["id"]))
            task_scores[scored["task"]].append(scored["score"])

        avg = lambda key: round(sum(task_scores[key]) / len(task_scores[key]), 1) if task_scores[key] else 0.0
        rows.append(
            {
                "model": model,
                "status": "OK",
                "mcq": avg("mcq"),
                "short": avg("short"),
                "essay": avg("essay"),
                "json_valid": True,
                "items": len(items),
                "latency_s": payload.get("latency_s"),
            }
        )

    # ---- Tabel ----
    print(f"{'Model':<24} {'Status':<7} {'MCQ':>6} {'Isian':>6} {'Esai':>6} {'JSON':>6} {'Items':>6} {'Latency':>9}")
    print("-" * 76)
    for r in rows:
        if r["status"] == "OK":
            print(
                f"{r['model']:<24} {'OK':<7} {r['mcq']:>6} {r['short']:>6} {r['essay']:>6} "
                f"{'yes':>6} {r['items']:>6} {r['latency_s']:>8.1f}s"
            )
        else:
            print(f"{r['model']:<24} {'ERROR':<7} {'-':>6} {'-':>6} {'-':>6} {'no':>6} {'-':>6} {r['latency_s']:>8.1f}s  {r['error']}")

    # ---- Rekomendasi ----
    print("\nRekomendasi (1 model per tugas, hanya keluarga flash yang tersedia):")
    eligible = [r for r in rows if r["status"] == "OK" and r["model"] not in UNAVAILABLE and r["model"] not in REFERENCE_ONLY]
    if not eligible:
        print("  Tidak ada model flash yang berhasil diuji.")
        return

    picks = {}
    for task, label in (("mcq", "MCQ"), ("short", "Isian singkat"), ("essay", "Esai")):
        best = max(eligible, key=lambda r: (r[task] is not None, r[task]))
        picks[task] = best["model"]
        ties = [r["model"] for r in eligible if r[task] == best[task]]
        print(f"  {label:<14} -> {best['model']:<20} skor={best[task]:>6}  (seri: {', '.join(ties) if len(ties) > 1 else '-'})")

    summary = {"picks": picks, "rows": rows}
    Path(args.json_out).write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nRingkasan tersimpan: {args.json_out}")


if __name__ == "__main__":
    main()
