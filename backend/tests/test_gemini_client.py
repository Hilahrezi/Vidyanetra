"""Unit test routing model & fallback quota di services/gemini_client.py."""

from unittest.mock import patch

import pytest

from app.config import settings
from app.services import gemini_client
from app.services.batching_service import BatchItem, model_for


def test_model_for_routing():
    settings.gemini_model_mcq = "model-mcq"
    settings.gemini_model_short = "model-short"
    settings.gemini_model_essay = "model-essay"
    assert model_for("mcq") == "model-mcq"
    assert model_for("short") == "model-short"
    assert model_for("essay") == "model-essay"


def _dummy_item() -> BatchItem:
    return BatchItem(
        submission_id=7,
        question_number=1,
        type="essay",
        answer_key="kunci",
        image_path="nonexistent.jpg",
    )


def _fake_items():
    return [
        {
            "question_number": 1,
            "extracted_text": "teks",
            "similarity_score": 90,
            "is_correct": True,
            "confidence": 0.9,
            "reason": "alasan",
        }
    ]


def test_fallback_dipilih_saat_429():
    """429 di model utama -> otomatis pindah ke fallback, hasil memakai model_used fallback."""
    settings.gemini_model_essay = "model-utama"
    settings.gemini_model_fallback = "model-cadangan"

    calls = {"count": 0}

    def fake_generate(model_name, parts):
        calls["count"] += 1
        if model_name == "model-utama":
            raise Exception("429 RESOURCE_EXHAUSTED quota habis")
        items = _fake_items()
        items[0]["model_used"] = model_name
        return items

    client = gemini_client.GeminiClient.__new__(gemini_client.GeminiClient)
    with patch.object(gemini_client, "_build_parts", return_value=[]), patch.object(client, "_generate", fake_generate):
        results = client.evaluate_batch([_dummy_item()])

    assert calls["count"] == 2
    assert results[0]["model_used"] == "model-cadangan"
    assert results[0]["submission_id"] == 7


def test_fallback_tidak_dipakai_saat_sukses():
    settings.gemini_model_essay = "model-utama"
    settings.gemini_model_fallback = "model-cadangan"

    calls = {"count": 0}

    def fake_generate(model_name, parts):
        calls["count"] += 1
        items = _fake_items()
        items[0]["model_used"] = model_name
        return items

    client = gemini_client.GeminiClient.__new__(gemini_client.GeminiClient)
    with patch.object(gemini_client, "_build_parts", return_value=[]), patch.object(client, "_generate", fake_generate):
        results = client.evaluate_batch([_dummy_item()])

    assert calls["count"] == 1
    assert results[0]["model_used"] == "model-utama"


def test_gagal_total_setelah_max_attempts():
    settings.gemini_model_essay = "model-utama"
    settings.gemini_model_fallback = "model-cadangan"

    def fake_generate(model_name, parts):
        raise Exception("500 internal")

    client = gemini_client.GeminiClient.__new__(gemini_client.GeminiClient)
    with patch.object(gemini_client, "_build_parts", return_value=[]), patch.object(client, "_generate", fake_generate):
        with pytest.raises(RuntimeError, match="gagal"):
            client.evaluate_batch([_dummy_item()])
