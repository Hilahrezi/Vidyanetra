"""Siapkan dataset validasi dari foto tulisan tangan asli (folder /handwriting-test).

Setiap pasangan image0X.png + image0X-text.txt menjadi 1 item bertipe 'transcribe':
ground truth = isi file teks (transkripsi harapan).

usage: python scripts/benchmark/prepare_real.py
"""

import json
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent.parent.parent  # backend/scripts/benchmark -> project root
HANDWRITING_DIR = PROJECT_ROOT / "handwriting-test"
OUT_DIR = BASE_DIR / "data_real"


def main() -> None:
    if not HANDWRITING_DIR.exists():
        print(f"Folder {HANDWRITING_DIR} tidak ditemukan.")
        return

    items = []
    for img_path in sorted(HANDWRITING_DIR.glob("image*.png")):
        stem = img_path.stem
        txt_path = HANDWRITING_DIR / f"{stem}-text.txt"
        if not txt_path.exists():
            print(f"  skip {img_path.name}: pasangan teks tidak ada")
            continue
        expected = txt_path.read_text(encoding="utf-8", errors="replace").strip()
        items.append(
            {
                "id": stem,
                "task": "transcribe",
                "key": "",
                "student_text": expected,
                "expected_text": expected,
                "score_range": [0, 100],
                "expected_correct": True,
                "keywords": [],
                "image": str(img_path),
            }
        )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "ground_truth.json").write_text(
        json.dumps(items, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"Dataset validasi: {len(items)} foto tulisan tangan asli -> {OUT_DIR}")
    for it in items:
        lines = len(it["expected_text"].splitlines())
        print(f"  {it['id']}  {lines} baris ground truth ({len(it['expected_text'])} chars)")


if __name__ == "__main__":
    main()
