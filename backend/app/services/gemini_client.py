"""Gemini client (google.genai) dengan Prompt-Level Batching + Interleaved Prompting.

Desain (hasil Fase 2A benchmark):
- Model dipilih per tugas via config: GEMINI_MODEL_MCQ / _SHORT / _ESSAY.
- Satu request = beberapa crop (batch 5, maks 15) dari tipe soal yang sama;
  tiap gambar di-interleave dengan instruksi tugasnya + kunci jawaban.
- Output JSON array strict via response_schema; fallback ke response_mime_type bila ditolak.
- Retry exponential backoff + jitter untuk 429/5xx; timeout 120s.
"""

import io
import json
import logging
import random
import time
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image

from ..config import settings
from .batching_service import PROMPT_ESSAY, PROMPT_MCQ, PROMPT_SHORT, RESPONSE_SCHEMA

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "Kamu adalah asisten koreksi ujian sekolah menengah di Indonesia. "
    "Kamu menerima beberapa gambar jawaban tulisan tangan yang dinomori. "
    "Evaluasi SETIAP gambar secara independen terhadap kunci jawaban dan instruksi tugasnya. "
    "Jangan mencampur jawaban antar gambar."
)

MAX_ATTEMPTS = 3
TIMEOUT_MS = 120_000
MAX_IMAGE_PX = 768
JPEG_QUALITY = 80


def _normalize_image(image_path: str) -> bytes:
    """Resize longest side <= 768px, re-compress JPEG -> bytes."""
    img = Image.open(Path(image_path)).convert("RGB")
    if max(img.size) > MAX_IMAGE_PX:
        ratio = MAX_IMAGE_PX / max(img.size)
        img = img.resize((int(img.width * ratio), int(img.height * ratio)), Image.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=JPEG_QUALITY)
    return buffer.getvalue()


def _build_parts(details: list) -> list:
    """Interleaved parts: [image1, instruksi1, image2, instruksi2, ..., permintaan output].

    details: list[BatchItem] (plain, thread-safe).
    """
    parts = []
    for item in details:
        instruction = {
            "mcq": PROMPT_MCQ,
            "short": PROMPT_SHORT,
            "essay": PROMPT_ESSAY,
        }[item.type].format(n=item.question_number, key=item.answer_key)

        parts.append(
            types.Part(
                inline_data=types.Blob(
                    mime_type="image/jpeg",
                    data=_normalize_image(item.image_path),
                )
            )
        )
        parts.append(types.Part(text=f"Gambar untuk soal {item.question_number}.\n{instruction}"))
    parts.append(
        types.Part(
            text=(
                "Output: JSON array berisi SATU objek per soal di atas (urut sesuai urutan gambar), "
                "dengan field: question_number, extracted_text, similarity_score (0-100), is_correct, "
                "confidence (0-1), reason. Wajib: seluruh objek ada, jangan ada yang terlewat."
            )
        )
    )
    return parts


class GeminiClient:
    def __init__(self):
        self._client = genai.Client(
            api_key=settings.gemini_api_key,
            http_options=types.HttpOptions(timeout=TIMEOUT_MS),
        )

    def _model_for(self, question_type: str) -> str:
        return {
            "mcq": settings.gemini_model_mcq,
            "short": settings.gemini_model_short,
            "essay": settings.gemini_model_essay,
        }[question_type]

    def _generate(self, model_name: str, parts: list) -> list[dict]:
        response = self._client.models.generate_content(
            model=model_name,
            contents=parts,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                response_mime_type="application/json",
                response_schema=RESPONSE_SCHEMA,
                temperature=0.2,
            ),
        )
        if response.text is None:
            raise RuntimeError("Respons tanpa teks")
        items = _parse_json(response.text)
        if items is None:
            raise ValueError("JSON tidak valid dari model")
        return items

    def evaluate_batch(self, details: list) -> list[dict]:
        """Evaluasi satu batch (tipe soal seragam) -> list dict hasil AI.

        Strategi model:
        1. Model utama sesuai tipe soal (config per tugas).
        2. Error 429/RESOURCE_EXHAUSTED (quota model utama habis) -> pindah ke
           GEMINI_MODEL_FALLBACK otomatis + warning log (tidak menandai failed).
        3. Error server lain -> retry exponential backoff pada model aktif.
        Raises jika gagal total (caller menandai failed).
        """
        if not details:
            return []
        question_type = details[0].type
        models_to_try = [self._model_for(question_type)]
        if settings.gemini_model_fallback and settings.gemini_model_fallback not in models_to_try:
            models_to_try.append(settings.gemini_model_fallback)
        parts = _build_parts(details)

        by_number = {d.question_number: d.submission_id for d in details}
        fallback_submission_id = details[0].submission_id

        for model_index, model_name in enumerate(models_to_try):
            attempts = 0
            while True:
                attempts += 1
                try:
                    items = self._generate(model_name, parts)
                    for item in items:
                        item["submission_id"] = by_number.get(item.get("question_number"), fallback_submission_id)
                        item["model_used"] = model_name
                    logger.info("Gemini %s: %d soal dievaluasi", model_name, len(details))
                    return items
                except Exception as exc:
                    is_rate = "429" in str(exc) or "RESOURCE_EXHAUSTED" in str(exc)
                    is_server = "503" in str(exc) or "500" in str(exc)
                    if is_rate and model_index + 1 < len(models_to_try):
                        logger.warning(
                            "Quota %s habis (%s) -> fallback ke %s",
                            model_name,
                            exc,
                            models_to_try[model_index + 1],
                        )
                        break  # pindah ke model fallback
                    if not (is_rate or is_server) or attempts >= MAX_ATTEMPTS:
                        raise RuntimeError(f"Gemini {model_name} gagal ({attempts}x): {exc}") from exc
                    backoff = min(2**attempts, 8) + random.uniform(0, 1)
                    logger.warning(
                        "Gemini %s %s -> retry dalam %.1fs (percobaan %d/%d)",
                        model_name,
                        exc,
                        backoff,
                        attempts + 1,
                        MAX_ATTEMPTS,
                    )
                    time.sleep(backoff)


def _parse_json(text: str) -> list[dict] | None:
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:].strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


class MockGeminiClient:
    """Deterministik, tanpa quota. Untuk dev/demo."""

    def evaluate_batch(self, details: list) -> list[dict]:
        results = []
        for i, item in enumerate(details):
            results.append(
                {
                    "submission_id": item.submission_id,
                    "question_number": item.question_number,
                    "extracted_text": f"(mock) jawaban nomor {item.question_number}",
                    "similarity_score": 85.0 if i % 3 else 45.0,
                    "is_correct": bool(i % 3),
                    "confidence": 0.9,
                    "model_used": "mock",
                    "reason": "Hasil simulasi (mock mode) - tidak memakai quota Gemini.",
                }
            )
        return results


_client = None


def get_client():
    global _client
    if _client is None:
        if settings.gemini_mock_mode or not settings.gemini_api_key:
            if not settings.gemini_mock_mode:
                logger.warning("GEMINI_API_KEY kosong -> fallback ke mock mode. Isi .env untuk evaluasi AI real.")
            _client = MockGeminiClient()
        else:
            _client = GeminiClient()
    return _client
