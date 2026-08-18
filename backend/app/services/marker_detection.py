"""Deteksi fiducial marker + homografi + crop sel (logika SAMA dengan mobile Fase 4).

Pipeline:
1. Grayscale -> GaussianBlur -> Otsu (invert: hitam = 255).
2. findContours RETR_EXTERNAL -> filter ukuran & rasio ~1 -> 4 kandidat terbesar.
3. Centroid tiap marker -> urutkan TL, TR, BL, BR.
4. getPerspectiveTransform -> warp ke 2480x3508.
5. Crop sel pakai koordinat layout.json.
"""

import json
import logging
from pathlib import Path

import cv2
import numpy as np

from .template_service import (
    PAGE_H_PX,
    PAGE_W_PX,
    MARKER_SIZE_MM,
    PX_PER_MM,
    CellSpec,
    TemplateLayout,
)

logger = logging.getLogger(__name__)

# Rentang ukuran marker yang diterima (px). Marker 12mm @300dpi = 142px.
MIN_MARKER_PX = 40
MAX_MARKER_PX = int(MARKER_SIZE_MM * PX_PER_MM) * 3  # toleransi foto zoomed-in


class MarkerDetectionError(Exception):
    pass


def _ordered_corners(centroids: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """Urutkan 4 centroid: TL, TR, BL, BR."""
    if len(centroids) != 4:
        raise MarkerDetectionError(f"Dibutuhkan 4 marker, ditemukan {len(centroids)}")
    s = sorted(centroids)
    tl, bl = s[0], s[1]  # x terkecil -> dua titik kiri
    tr, br = s[2], s[3]
    # di antara pasangan kiri/kanan, yang y-nya lebih kecil = atas
    tl, bl = (tl, bl) if tl[1] < bl[1] else (bl, tl)
    tr, br = (tr, br) if tr[1] < br[1] else (br, tr)
    return [tl, tr, bl, br]


def _quad_center(contour: np.ndarray) -> tuple[float, float] | None:
    """Pusat marker via interseksi diagonal segiempat kontur (projective-invariant).

    Centroid (momen) TIDAK invariant terhadap transformasi perspektif; titik
    potong diagonal gambar segiempat justru memetakan pusat sejati marker.
    """
    peri = cv2.arcLength(contour, True)
    approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
    if len(approx) != 4:
        return None
    pts = approx.reshape(4, 2).astype(np.float64)
    s = pts.sum(axis=1)
    d = np.diff(pts, axis=1).ravel()
    tl, br = pts[np.argmin(s)], pts[np.argmax(s)]
    tr, bl = pts[np.argmin(d)], pts[np.argmax(d)]

    matrix = np.array([[br[0] - tl[0], tr[0] - bl[0]], [br[1] - tl[1], tr[1] - bl[1]]])
    b = np.array([tr[0] - tl[0], tr[1] - tl[1]])
    try:
        t, u = np.linalg.solve(matrix, b)
    except np.linalg.LinAlgError:
        return float((tl[0] + br[0]) / 2), float((tl[1] + br[1]) / 2)
    return float(tl[0] + t * (br[0] - tl[0])), float(tl[1] + t * (br[1] - tl[1]))


def detect_markers(image_bgr: np.ndarray) -> list[tuple[float, float]]:
    """Deteksi 4 marker -> titik tengah marker urut [TL, TR, BL, BR]."""
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, binary = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    candidates = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if w < MIN_MARKER_PX or h < MIN_MARKER_PX or w > MAX_MARKER_PX or h > MAX_MARKER_PX:
            continue
        aspect = max(w, h) / min(w, h)
        if aspect > 1.3:
            continue
        area = cv2.contourArea(contour)
        if area < MIN_MARKER_PX * MIN_MARKER_PX:
            continue
        # Marker = persegi SOLID (rasio isi hitam ~1); kotak jawaban hampa (rasio ~0.1)
        mask = np.zeros_like(binary)
        cv2.drawContours(mask, [contour], -1, 255, thickness=cv2.FILLED)
        black_inside = cv2.countNonZero(cv2.bitwise_and(mask, binary))
        if black_inside / max(cv2.countNonZero(mask), 1) < 0.7:
            continue
        center = _quad_center(contour)
        if center is None:
            moments = cv2.moments(contour)
            if moments["m00"] == 0:
                continue
            center = (moments["m10"] / moments["m00"], moments["m01"] / moments["m00"])
        candidates.append((area, center[0], center[1]))

    candidates.sort(key=lambda t: t[0], reverse=True)
    top = candidates[:4]
    if len(top) < 4:
        raise MarkerDetectionError(
            f"Terlalu sedikit marker terdeteksi ({len(top)}/4). Perbaiki pencahayaan/posisi lembar."
        )
    return _ordered_corners([(c[1], c[2]) for c in top])


def warp_page(image_bgr: np.ndarray, corners: list[tuple[float, float]], layout: TemplateLayout) -> np.ndarray:
    """Perspective warp ke ruang template 2480x3508 px (target = posisi marker layout)."""
    m = layout.markers_px
    expected = np.array(
        [m["tl"], m["tr"], m["bl"], m["br"]],
        dtype=np.float32,
    )
    src = np.array(corners, dtype=np.float32)
    matrix = cv2.getPerspectiveTransform(src, expected)
    return cv2.warpPerspective(image_bgr, matrix, (PAGE_W_PX, PAGE_H_PX))


def crop_cells(warped: np.ndarray, layout: TemplateLayout) -> list[tuple[int, np.ndarray]]:
    """Crop tiap sel sesuai layout -> [(question_number, crop_bgr)]."""
    crops = []
    for cell in layout.cells:
        x1, y1, x2, y2 = cell.x, cell.y, cell.x + cell.w, cell.y + cell.h
        crops.append((cell.question_number, warped[y1:y2, x1:x2]))
    return crops


def load_layout(path: Path | str) -> list[TemplateLayout]:
    """Baca layout.json -> daftar halaman (tiap halaman punya sel + marker)."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    pages = []
    for page_data in data["pages"]:
        page = TemplateLayout(
            page_size_px=tuple(data["page_size_px"]),
            markers_px=page_data["markers_px"],
            header_px=page_data.get("header_px", {}),
            cells=[],
        )
        for c in page_data["cells"]:
            page.cells.append(
                CellSpec(
                    question_number=c["question_number"],
                    type=c["type"],
                    x=c["x"],
                    y=c["y"],
                    w=c["w"],
                    h=c["h"],
                )
            )
        pages.append(page)
    return pages
