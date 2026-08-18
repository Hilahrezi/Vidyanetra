"""Jalankan benchmark model Gemini: 1 request interleaved per model.

Prompt-Level Batching + Interleaved Prompting:
- Semua 8 gambar test dikirim dalam satu request, masing-masing diikuti
  instruksi tugasnya + kunci jawaban (interleaved parts).
- Output JSON array (response_schema); fallback ke JSON mime bila schema ditolak.
- Hasil + latency disimpan ke results/<model>.json

usage: python scripts/benchmark/run_benchmark.py [--models ...] [--dry-run]
"""

import argparse
import base64
import io
import json
import sys
import time
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image

from app.config import settings

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
RESULTS_DIR = BASE_DIR / "results"

DEFAULT_MODELS = [
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.5-preview",
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
]

SYSTEM_PROMPT = (
    "Kamu adalah asisten koreksi ujian sekolah menengah di Indonesia. "
    "Kamu menerima beberapa gambar jawaban tulisan tangan yang dinomori. "
    "Evaluasi SETIAP gambar secara independen terhadap kunci jawaban dan instruksi tugasnya. "
    "Jangan mencampur jawaban antar gambar."
)

TASK_INSTRUCTIONS = {
    "mcq": "Baca huruf yang ditulis siswa (A/B/C/D). Bila ambigu, beri confidence rendah dan best guess. "
    "is_correct = true jika huruf cocok dengan kunci (tidak peduli huruf besar/kecil).",
    "short": "Transkripsi jawaban siswa apa adanya ke extracted_text. similarity_score (0-100): "
    "kemiripan makna dengan kunci; alternatif kunci dipisah oleh '|', cocok dengan salah satunya "
    "dianggap benar penuh. is_correct = similarity_score >= 70.",
    "essay": "Transkripsi jawaban siswa lengkap ke extracted_text. similarity_score (0-100): nilai SEMANTIK, "
    "bukan kesamaan kata per kata; beri skor parsial bila sebagian gagasan utama muncul atau diparafrase. "
    "reason: 1-2 kalimat penjelasan skor. is_correct = similarity_score >= 70.",
    "transcribe": "Transkripsi SELURUH teks pada gambar secara akurat ke extracted_text, apa adanya, "
    "termasuk rumus matematika (tuliskan simbol dengan teks biasa, misal y'' = g, mv' = mg - bv2). "
    "Jangan parafrase, jangan menambah atau mengurangi konten. Pertahankan struktur baris. "
    "similarity_score: perkiraan akurasi transkripsi Anda (0-100). is_correct = similarity_score >= 70.",
}

RESPONSE_SCHEMA = {
    "type": "ARRAY",
    "items": {
        "type": "OBJECT",
        "properties": {
            "item_id": {"type": "STRING"},
            "extracted_text": {"type": "STRING"},
            "similarity_score": {"type": "NUMBER"},
            "is_correct": {"type": "BOOLEAN"},
            "confidence": {"type": "NUMBER"},
            "reason": {"type": "STRING"},
        },
        "required": ["item_id", "extracted_text", "similarity_score", "is_correct"],
    },
}


def load_ground_truth() -> list[dict]:
    return json.loads((DATA_DIR / "ground_truth.json").read_text(encoding="utf-8"))


def encode_image_bytes(path: Path, max_px: int = 768) -> bytes:
    img = Image.open(path).convert("RGB")
    if max(img.size) > max_px:
        ratio = max_px / max(img.size)
        img = img.resize((int(img.width * ratio), int(img.height * ratio)), Image.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue()


def _resolve_image(item: dict) -> Path:
    p = Path(item["image"])
    return p if p.is_absolute() else DATA_DIR / p


def build_parts(items: list[dict], max_px: int = 768) -> list:
    parts = []
    for idx, item in enumerate(items, start=1):
        parts.append(
            types.Part(
                inline_data=types.Blob(
                    mime_type="image/jpeg",
                    data=encode_image_bytes(_resolve_image(item), max_px),
                )
            )
        )
        parts.append(
            types.Part(
                text=f"ITEM {idx} -> item_id: {item['id']} | TASK: {item['task']} | KUNCI: \"{item['key']}\"\n"
                f"Instruksi tugas: {TASK_INSTRUCTIONS[item['task']]}"
            )
        )
    parts.append(
        types.Part(
            text="Output: JSON array berisi SATU objek per item di atas (urut sesuai urutan gambar), "
            f"dengan field: item_id, extracted_text, similarity_score (0-100), is_correct, confidence (0-1), reason. "
            "Wajib: seluruh 8 objek ada."
        )
    )
    return parts


def call_model(model_name: str, items: list[dict], max_px: int = 768) -> dict:
    client = genai.Client(api_key=settings.gemini_api_key)
    parts = build_parts(items, max_px)

    start = time.perf_counter()
    error = None
    used_schema = True
    response = None
    try:
        response = client.models.generate_content(
            model=model_name,
            contents=parts,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                response_mime_type="application/json",
                response_schema=RESPONSE_SCHEMA,
                temperature=0.2,
            ),
        )
    except Exception as exc:
        used_schema = False
        try:
            response = client.models.generate_content(
                model=model_name,
                contents=parts,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    response_mime_type="application/json",
                    temperature=0.2,
                ),
            )
        except Exception as exc2:
            error = f"{type(exc2).__name__}: {exc2} (schema_fallback_error: {type(exc).__name__})"

    latency = round(time.perf_counter() - start, 2)

    result = {"model": model_name, "latency_s": latency, "used_schema": used_schema, "error": error, "items": None}
    if error:
        return result

    if response.text is not None:
        text = response.text.strip()
    elif hasattr(response, "parsed") and response.parsed is not None:
        text = json.dumps(response.parsed)
    else:
        result["error"] = "Tidak ada teks dalam respons"
        return result

    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:].strip()
    try:
        result["items"] = json.loads(text)
    except json.JSONDecodeError as exc:
        result["error"] = f"JSONDecodeError: {exc}"
        result["raw_text"] = text[:2000]
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", nargs="+", default=DEFAULT_MODELS)
    parser.add_argument("--data", default="data", help="Folder dataset (data | data_real)")
    parser.add_argument("--max-px", type=int, default=768, help="Resolusi maksimum gambar (untuk foto asli: 1600)")
    parser.add_argument("--dry-run", action="store_true", help="Uji 1 model, tanpa menulis file")
    parser.add_argument("--sleep", type=float, default=2.0, help="Jeda antar model (detik)")
    args = parser.parse_args()

    global DATA_DIR
    DATA_DIR = BASE_DIR / args.data
    items = load_ground_truth()
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Benchmark {len(items)} item terhadap {len(args.models)} model (1 request/model)\n")

    for model_name in args.models:
        if args.dry_run:
            print(f"[DRY-RUN] {model_name} — call dimulai (tanpa menyimpan)...")
        result = call_model(model_name, items, max_px=args.max_px)

        if result["error"]:
            print(f"  {model_name:24s} ERROR ({result['latency_s']}s): {result['error'][:120]}")
        else:
            n = len(result["items"]) if result["items"] else 0
            print(f"  {model_name:24s} OK  {result['latency_s']:6.2f}s  items={n}  schema={'yes' if result['used_schema'] else 'fallback'}")

        if not args.dry_run:
            (RESULTS_DIR / f"{model_name}.json").write_text(
                json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8"
            )
        time.sleep(args.sleep)

    print("\nSelesai. Hasil tersimpan di scripts/benchmark/results/" if not args.dry_run else "")


if __name__ == "__main__":
    main()
