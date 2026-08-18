"""Test deteksi X MCQ (CV) + alur 3-tier di batching_service."""

import io
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts" / "benchmark"))

from app.services import mcq_vision
from prepare_dataset import render_mcq_option


def _crop_bytes(key: str, extra_x: str | None = None, font_index: int = 0, no_mark: bool = False) -> bytes:
    """Crop MCQ sintetis: X di kotak `key`, opsional X kedua di `extra_x`."""
    img = render_mcq_option(key, extra_x=extra_x, font_index=font_index, no_mark=no_mark)
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue()


def test_detect_x_on_each_option():
    for key in ("a", "b", "c", "d"):
        res = mcq_vision.evaluate_mcq_crop(_crop_bytes(key))
        assert res["answer"] == key, f"kotak {key} -> {res}"
        assert res["ambiguous"] is False
        assert res["confidence"] >= mcq_vision.MIN_DENSITY


def test_detect_ambiguous_no_mark():
    res = mcq_vision.evaluate_mcq_crop(_crop_bytes("", no_mark=True))
    assert res["ambiguous"] is True
    assert res["answer"] is None


def test_detect_ambiguous_double_x():
    res = mcq_vision.evaluate_mcq_crop(_crop_bytes("b", extra_x="d"))
    assert res["ambiguous"] is True


def test_detect_robust_rotation_fonts():
    # font & rotasi berbeda
    res = mcq_vision.evaluate_mcq_crop(_crop_bytes("c", font_index=2))
    assert res["answer"] == "c"
    assert res["ambiguous"] is False
