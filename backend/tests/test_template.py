"""Test Fase 3: template PDF, deteksi marker, warp, crop (termasuk simulasi foto miring)."""

import json

import cv2
import numpy as np
import pytest

from app.services.marker_detection import (
    MarkerDetectionError,
    crop_cells,
    detect_markers,
    load_layout,
    warp_page,
)
from app.services.template_service import (
    PAGE_H_PX,
    PAGE_W_PX,
    PX_PER_MM,
    build_pdf,
)

QUESTIONS = ["mcq"] * 3 + ["short"] * 2 + ["essay"] * 2  # 7 soal


def _render(pdf_path, page_index: int = 0, dpi: int = 300) -> np.ndarray:
    import pymupdf

    doc = pymupdf.open(str(pdf_path))
    pix = doc[page_index].get_pixmap(dpi=dpi)
    arr = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    doc.close()
    return cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)


@pytest.fixture()
def built(tmp_path):
    out_pdf = tmp_path / "lembar.pdf"
    out_layout = tmp_path / "lembar.layout.json"
    pages = build_pdf(QUESTIONS, "UTS Test", "Kelas 8A", out_pdf, out_layout)
    return out_pdf, out_layout, pages


def test_build_pdf_and_layout_contract(built):
    out_pdf, out_layout, pages = built
    assert out_pdf.exists()
    assert out_layout.exists()

    data = json.loads(out_layout.read_text(encoding="utf-8"))
    assert data["page_size_px"] == [PAGE_W_PX, PAGE_H_PX]

    all_cells = [c for p in pages for c in p.cells]
    assert len(all_cells) == len(QUESTIONS)
    assert [c.type for c in all_cells] == QUESTIONS
    assert [c.question_number for c in all_cells] == list(range(1, 8))

    # marker center harus sesuai posisi template (px): persegi 12mm di (12,12)mm
    # -> center (18,18)mm
    m = pages[0].markers_px
    assert m["tl"] == [round(18 * PX_PER_MM), round(18 * PX_PER_MM)]
    assert m["br"][0] == round((210 - 18) * PX_PER_MM)

    # halaman 1 = 6 sel (3 mcq + 2 short + 1 essay), halaman 2 = 1 essay
    assert [len(p.cells) for p in pages] == [6, 1]

    # kotak esai tidak boleh menyentuh tepi kanan (fix bug terpotong cetak)
    essay = all_cells[-1]
    assert essay.x + essay.w < 210 * PX_PER_MM - 5 * PX_PER_MM


def test_detect_and_warp_on_render(built):
    out_pdf, out_layout, pages = built
    img = _render(out_pdf, 0)
    # PyMuPDF membulatkan lebar 2480.3 -> 2481 px; toleransi 1px
    assert abs(img.shape[1] - PAGE_W_PX) <= 1
    assert abs(img.shape[0] - PAGE_H_PX) <= 1

    corners = detect_markers(img)
    expected = [
        pages[0].markers_px["tl"],
        pages[0].markers_px["tr"],
        pages[0].markers_px["bl"],
        pages[0].markers_px["br"],
    ]
    max_err = max(np.hypot(cx - ex, cy - ey) for (cx, cy), (ex, ey) in zip(corners, expected))
    assert max_err < 2.0, f"marker error {max_err:.2f}px"

    warped = warp_page(img, corners, pages[0])
    crops = crop_cells(warped, pages[0])
    assert len(crops) == 6
    for _, crop in crops:
        assert crop.mean() > 200  # sel kosong = terang


def test_perspective_roundtrip_simulated_photo(built):
    """Simulasi foto miring: transformasi perspektif acak -> deteksi -> warp balik -> identik."""
    out_pdf, out_layout, pages = built
    img_full = _render(out_pdf, 0)
    img = img_full[:PAGE_H_PX, :PAGE_W_PX]  # potong selisih 1px render

    src = np.array(
        [
            pages[0].markers_px["tl"],
            pages[0].markers_px["tr"],
            pages[0].markers_px["bl"],
            pages[0].markers_px["br"],
        ],
        dtype=np.float32,
    )
    rng = np.random.default_rng(7)
    # offset dijaga agar 4 marker tetap UTUH di dalam canvas (tidak terpotong tepi)
    offsets = np.array([[-120, -140], [140, -120], [-110, 130], [120, 120]], dtype=np.float32)
    dst = src + offsets
    # canvas diperbesar + margin 200px di semua sisi agar seluruh halaman
    # terlihat (simulasi foto utuh, tanpa area putih hasil warp)
    pad = 200
    shifted = dst + pad
    matrix = cv2.getPerspectiveTransform(src, shifted)
    canvas = cv2.warpPerspective(
        img_full, matrix, (img_full.shape[1] + 2 * pad, img_full.shape[0] + 2 * pad), borderValue=(255, 255, 255)
    )

    corners = detect_markers(canvas)
    recovered = warp_page(canvas, corners, pages[0])

    # halaman hasil warp-balik harus ≈ halaman asli (hanya selisih interpolasi)
    diff = np.abs(recovered.astype(int) - img.astype(int)).mean()
    assert diff < 8.0, f"diff={diff:.2f}"

    crops_orig = crop_cells(img, pages[0])
    crops_rec = crop_cells(recovered, pages[0])
    for (n1, c1), (n2, c2) in zip(crops_orig, crops_rec):
        assert n1 == n2
        assert np.abs(c1.astype(int) - c2.astype(int)).mean() < 8.0


def test_detect_fails_on_random_image():
    img = np.full((800, 600, 3), 200, dtype=np.uint8)
    with pytest.raises(MarkerDetectionError):
        detect_markers(img)
