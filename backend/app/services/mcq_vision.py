"""Deteksi tanda X pada kotak opsi MCQ — Computer Vision murni (tanpa AI).

Crop MCQ sudah ter-warp ke geometri template (76x16mm) sehingga posisi 4 kotak
opsi SELALU tetap: fraksi berikut dihitung dari template_service (kotak 14mm,
gap 6mm, mulai x=27mm dalam cell 25..101mm).

Ambigu (X ganda/tak jelas/tanpa tanda) -> hasil dict ambiguous=True, caller
menentukan fallback (Gemini).
"""

import logging
from pathlib import Path

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Fraksi [x0, x1] tiap kotak opsi dalam crop MCQ (dari geometri template)
MCQ_BOX_FRACTIONS = [
    (0.0263, 0.2105),  # a
    (0.2895, 0.4737),  # b
    (0.5526, 0.7368),  # c
    (0.8158, 1.0000),  # d
]
MCQ_LETTERS = ("a", "b", "c", "d")

MIN_DENSITY = 0.03  # fraksi piksel gelap minimal agar dianggap ada tanda
MARGIN_RATIO = 1.5  # kotak terpilih harus >= 1.5x densitas kotak kedua
INSET = 0.15  # margin interior kotak (hindari garis tepi & huruf label)


def _density_per_box(binary: np.ndarray, w: int, h: int) -> list[float]:
    densities = []
    for x0f, x1f in MCQ_BOX_FRACTIONS:
        x0, x1 = int(x0f * w), int(x1f * w)
        mx = int((x1 - x0) * INSET)
        my = int(h * INSET)
        region = binary[my : h - my, x0 + mx : x1 - mx]
        densities.append(float(cv2.countNonZero(region)) / max(region.size, 1))
    return densities


def evaluate_mcq_crop(image_bytes: bytes) -> dict:
    """Deteksi opsi yang disilang dalam satu crop MCQ.

    Returns:
        {answer: str|None, confidence: float, ambiguous: bool, densities: list}
    """
    buf = np.frombuffer(image_bytes, dtype=np.uint8)
    gray = cv2.imdecode(buf, cv2.IMREAD_GRAYSCALE)
    if gray is None:
        return {"answer": None, "confidence": 0.0, "ambiguous": True, "densities": []}

    h, w = gray.shape
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    densities = _density_per_box(binary, w, h)

    order = sorted(range(4), key=lambda i: densities[i], reverse=True)
    best, second = order[0], order[1]

    ambiguous = densities[best] < MIN_DENSITY or densities[best] < MARGIN_RATIO * densities[second]
    return {
        "answer": MCQ_LETTERS[best] if not ambiguous else None,
        "confidence": round(densities[best], 4),
        "ambiguous": ambiguous,
        "densities": [round(d, 4) for d in densities],
    }


def evaluate_mcq_file(image_path: str | Path) -> dict:
    return evaluate_mcq_crop(Path(image_path).read_bytes())
