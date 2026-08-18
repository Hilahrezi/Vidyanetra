"""Analisis validasi foto asli: bandingkan transkripsi AI vs ground truth.

usage: python scripts/benchmark/analyze_real.py [--show]  (--show = tampilkan teks lengkap)
"""

import argparse
import difflib
import json
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
RESULTS_DIR = BASE_DIR / "results"
DATA_DIR = BASE_DIR / "data_real"


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", text.lower()).split()


def token_scores(a: list, b: list) -> dict:
    set_a, set_b = set(a), set(b)
    overlap = len(set_a & set_b)
    jaccard = overlap / len(set_a | set_b) if set_a | set_b else 1.0
    f1 = (2 * overlap / (len(set_a) + len(set_b))) if (set_a or set_b) else 1.0
    ratio = difflib.SequenceMatcher(None, a, b).ratio()
    return {"jaccard": round(jaccard * 100, 1), "f1": round(f1 * 100, 1), "sequence": round(ratio * 100, 1)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--show", action="store_true", help="Tampilkan transkripsi AI lengkap")
    args = parser.parse_args()

    ground_truth = {g["id"]: g["expected_text"] for g in json.loads((DATA_DIR / "ground_truth.json").read_text(encoding="utf-8"))}

    results = {}
    for f in sorted(RESULTS_DIR.glob("gemini-*.json")):
        if f.name == "ringkasan.json":
            continue
        payload = json.loads(f.read_text(encoding="utf-8"))
        if payload.get("error"):
            continue
        by_id = {i.get("item_id"): i for i in payload.get("items") or []}
        # hanya sertakan file yang berisi item dataset saat ini (foto asli)
        if not any(item_id in by_id for item_id in ground_truth):
            continue
        results[payload["model"]] = by_id

    models = list(results)
    print(f"Perbandingan transkripsi tulisan tangan asli ({len(ground_truth)} foto)\n")
    print(f"{'Foto':<10} {'Metrik':<10} " + " ".join(f"{m.split('-')[-1]:>10}" for m in models))
    print("-" * (22 + 10 * len(models)))

    summary = {m: [] for m in models}
    for item_id, expected in ground_truth.items():
        a = norm(expected)
        metrics = {}
        for m in models:
            ai = (results[m].get(item_id, {}).get("extracted_text") or "") if item_id in results[m] else ""
            scores = token_scores(a, norm(ai))
            metrics[m] = scores
            summary[m].append(scores["f1"])
        for met in ("f1", "jaccard", "sequence"):
            row = " ".join(f"{metrics[m][met]:>10}" for m in models)
            print(f"{item_id:<10} {met:<10} {row}")
    print("-" * (22 + 10 * len(models)))
    avg_row = " ".join(f"{sum(summary[m]) / len(summary[m]):>10.1f}" for m in models)
    print(f"{'RATA-RATA':<10} {'f1':<10} {avg_row}")

    if args.show:
        for item_id, expected in ground_truth.items():
            print(f"\n{'='*80}\nFOTO {item_id}\n{'='*80}")
            print(f"--- GROUND TRUTH ---\n{expected}")
            for m in models:
                ai = (results[m].get(item_id, {}).get("extracted_text") or "-") if item_id in results[m] else "-"
                print(f"\n--- {m} ---\n{ai}")


if __name__ == "__main__":
    main()
