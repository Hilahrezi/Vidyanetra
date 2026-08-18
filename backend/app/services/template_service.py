"""Layout engine lembar jawaban A4 (Fase 3-R — redesign).

- Render PDF via reportlab (hitam-putih murni, kontras maksimal).
- 4 fiducial marker: persegi solid hitam 12mm di keempat sudut (TIDAK berubah,
  kontrak deteksi tetap).
- Halaman 1: kop dummy (logo + nama sekolah + alamat + baris ujian),
  identitas ramping (NAMA; KELAS + NO.ABSEN + TANGGAL sejajar).
  Halaman 2+: grid saja (tanpa kop/identitas).
- Grid 1 kolom: mcq = 4 kotak opsi a/b/c/d (siswa menyilang satu),
  short = 100x18mm, essay = 170x50mm (fix: sebelumnya 180mm terpotong tepi).
- Nomor halaman di FOOTER kiri bawah (fix: sebelumnya menimpa marker TR).
- Ekspor layout.json (koordinat PIXEL ruang warp 2480x3508 @300dpi) —
  KONTRAK dengan mobile & verifikasi crop.

Konstanta geometri hanya di file ini (single source of truth).
"""

import json
from dataclasses import dataclass, field
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

MM = 72 / 25.4  # mm -> pt (reportlab)
DPI = 300
PX_PER_MM = DPI / 25.4  # 11.811 px per mm

PAGE_W_MM, PAGE_H_MM = 210.0, 297.0
PAGE_W_PT, PAGE_H_PT = A4
PAGE_W_PX = int(PAGE_W_MM * PX_PER_MM)  # 2480
PAGE_H_PX = int(PAGE_H_MM * PX_PER_MM)  # 3508

MARGIN_MM = 15.0
MARKER_SIZE_MM = 12.0
MARKER_RING_MM = 2.0  # jarak aman ke konten lain
MARKER_POS_MM = {  # titik kiri-atas persegi marker (tidak berubah)
    "tl": (12.0, 12.0),
    "tr": (PAGE_W_MM - MARKER_SIZE_MM - 12.0, 12.0),
    "bl": (12.0, PAGE_H_MM - MARKER_SIZE_MM - 12.0),
    "br": (PAGE_W_MM - MARKER_SIZE_MM - 12.0, PAGE_H_MM - MARKER_SIZE_MM - 12.0),
}

# ---- Kop (halaman 1) — dimulai di bawah marker TL (marker y 12-26mm) ----
KOP_LOGO_X_MM, KOP_LOGO_Y_MM, KOP_LOGO_SIZE_MM = 15.0, 29.0, 20.0
KOP_SCHOOL_X_MM = 42.0
KOP_SCHOOL_Y_MM = 34.0
KOP_ADDR_Y_MM = 41.0
KOP_LINE_Y_MM = 54.0
KOP_UJIAN_Y_MM = 61.0

# ---- Identitas ramping (halaman 1) ----
FIELD_H_MM = 9.0
FIELD_GAP_MM = 4.0
IDENT_Y0_MM = 70.0  # baris 1: NAMA
IDENT_Y1_MM = IDENT_Y0_MM + FIELD_H_MM + FIELD_GAP_MM  # baris 2: KELAS/ABSEN/TANGGAL
GRID_Y0_MM = IDENT_Y1_MM + FIELD_H_MM + 5.0  # 97mm
GRID_Y0_SUB_MM = 32.0  # halaman 2+

FIELD_ROWS = {
    "nama": (15.0, 43.0, 120.0),
    "kelas": (15.0, 43.0, 30.0),
    "absen": (78.0, 106.0, 30.0),
    "tanggal": (141.0, 169.0, 26.0),
}

# ---- Grid ----
CELL_SIZE_MM = {"mcq": (76.0, 16.0), "short": (100.0, 18.0), "essay": (170.0, 45.0)}
ROW_GAP_MM = 8.0
NUM_LABEL_X_MM = 15.0
NUM_LABEL_W_MM = 10.0
MCQ_OPTIONS = ("a", "b", "c", "d")
MCQ_BOX_SIZE_MM = (14.0, 16.0)
MCQ_BOX_GAP_MM = 6.0
MCQ_FIRST_X_MM = 27.0  # kotak a..d: 27..101mm (dalam cell 25..101mm)
BOTTOM_LIMIT_MM = PAGE_H_MM - MARGIN_MM - MARKER_SIZE_MM - MARKER_RING_MM  # 268

# ---- Footer ----
FOOTER_Y_MM = PAGE_H_MM - 7.0  # 290mm dari atas (di bawah marker BL/BR)


@dataclass
class CellSpec:
    question_number: int
    type: str
    x: int
    y: int
    w: int
    h: int


@dataclass
class TemplateLayout:
    page_size_px: tuple[int, int] = (PAGE_W_PX, PAGE_H_PX)
    markers_px: dict = field(default_factory=dict)
    cells: list[CellSpec] = field(default_factory=list)
    header_px: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "page_size_px": list(self.page_size_px),
            "markers_px": self.markers_px,
            "header_px": self.header_px,
            "cells": [
                {"question_number": c.question_number, "type": c.type, "x": c.x, "y": c.y, "w": c.w, "h": c.h}
                for c in self.cells
            ],
        }


def _marker_centers_px() -> dict:
    centers = {}
    for name, (x_mm, y_mm) in MARKER_POS_MM.items():
        cx = (x_mm + MARKER_SIZE_MM / 2) * PX_PER_MM
        cy = (y_mm + MARKER_SIZE_MM / 2) * PX_PER_MM
        centers[name] = [round(cx), round(cy)]
    return centers


def _mcq_option_x_mm() -> list[float]:
    xs = []
    for i in range(len(MCQ_OPTIONS)):
        xs.append(MCQ_FIRST_X_MM + i * (MCQ_BOX_SIZE_MM[0] + MCQ_BOX_GAP_MM))
    return xs


def compute_layout(questions: list[str]) -> list[TemplateLayout]:
    """Hitung posisi sel per halaman (px, ruang warp 2480x3508).

    Multi-page: halaman 1 dimulai di GRID_Y0_MM (setelah kop+identitas),
    halaman berikutnya GRID_Y0_SUB_MM. Tiap halaman membawa 4 marker yang sama.
    """
    pages: list[TemplateLayout] = []
    page = TemplateLayout(markers_px=_marker_centers_px())
    y_mm = GRID_Y0_MM

    for number, qtype in enumerate(questions, start=1):
        w_mm, h_mm = CELL_SIZE_MM[qtype]
        if y_mm + h_mm > BOTTOM_LIMIT_MM:
            pages.append(page)
            page = TemplateLayout(markers_px=_marker_centers_px())
            y_mm = GRID_Y0_SUB_MM

        cell_x_mm = NUM_LABEL_X_MM + NUM_LABEL_W_MM
        page.cells.append(
            CellSpec(
                question_number=number,
                type=qtype,
                x=round(cell_x_mm * PX_PER_MM),
                y=round(y_mm * PX_PER_MM),
                w=round(w_mm * PX_PER_MM),
                h=round(h_mm * PX_PER_MM),
            )
        )
        y_mm += h_mm + ROW_GAP_MM

    pages.append(page)
    return pages


def _draw_header_fields(c: canvas.Canvas, page_index: int, title: str, class_name: str) -> None:
    """Kop + identitas hanya untuk halaman 1."""
    c.setFont("Helvetica-Bold", 14)
    c.drawString(KOP_SCHOOL_X_MM * MM, (PAGE_H_MM - KOP_SCHOOL_Y_MM) * MM, "SEKOLAH MENENGAH PERTAMA NEGERI 1 CONTOH")
    c.setFont("Helvetica", 9)
    c.drawString(KOP_SCHOOL_X_MM * MM, (PAGE_H_MM - KOP_ADDR_Y_MM) * MM, "Jl. Pendidikan No. 1, Kota Contoh - Telp. (021) 1234567")
    # logo dummy
    c.setLineWidth(1.2)
    c.rect(KOP_LOGO_X_MM * MM, (PAGE_H_MM - KOP_LOGO_Y_MM - KOP_LOGO_SIZE_MM) * MM, KOP_LOGO_SIZE_MM * MM, KOP_LOGO_SIZE_MM * MM)
    c.setFont("Helvetica", 7)
    c.drawCentredString((KOP_LOGO_X_MM + KOP_LOGO_SIZE_MM / 2) * MM, (PAGE_H_MM - KOP_LOGO_Y_MM - KOP_LOGO_SIZE_MM / 2) * MM, "LOGO")
    # garis kop
    c.setLineWidth(1.5)
    c.line(MARGIN_MM * MM, (PAGE_H_MM - KOP_LINE_Y_MM) * MM, (PAGE_W_MM - MARGIN_MM) * MM, (PAGE_H_MM - KOP_LINE_Y_MM) * MM)
    # baris ujian
    c.setFont("Helvetica-Bold", 11)
    c.drawString(MARGIN_MM * MM, (PAGE_H_MM - KOP_UJIAN_Y_MM) * MM, f"UJIAN: {title}")
    c.setFont("Helvetica", 10)
    c.drawRightString((PAGE_W_MM - MARGIN_MM) * MM, (PAGE_H_MM - KOP_UJIAN_Y_MM) * MM, f"Kelas: {class_name}")

    # ---- Identitas ramping ----
    def field(label: str, x_label: float, x_box: float, w_box: float, y_mm: float) -> None:
        c.setFont("Helvetica-Bold", 9)
        c.drawString(x_label * MM, (PAGE_H_MM - y_mm - FIELD_H_MM / 2) * MM, label + ":")
        c.setLineWidth(1.0)
        c.rect(x_box * MM, (PAGE_H_MM - y_mm - FIELD_H_MM) * MM, w_box * MM, FIELD_H_MM * MM)

    field("NAMA", *FIELD_ROWS["nama"], IDENT_Y0_MM)
    field("KELAS", *FIELD_ROWS["kelas"], IDENT_Y1_MM)
    field("NO. ABSEN", *FIELD_ROWS["absen"], IDENT_Y1_MM)
    field("TANGGAL", *FIELD_ROWS["tanggal"], IDENT_Y1_MM)

    # petunjuk
    c.setFont("Helvetica-Oblique", 8)
    c.drawString(MARGIN_MM * MM, (PAGE_H_MM - GRID_Y0_MM + 2) * MM,
                 "Petunjuk: tulis jawaban di dalam kotak. Untuk pilihan ganda, silang (X) salah satu kotak a/b/c/d.")


def _draw_footer(c: canvas.Canvas, page_index: int, total_pages: int) -> None:
    c.setFont("Helvetica", 8)
    c.drawString(MARGIN_MM * MM, (PAGE_H_MM - FOOTER_Y_MM) * MM, f"Halaman {page_index} dari {total_pages}")


def build_pdf(questions: list[str], title: str, class_name: str, out_pdf: Path, out_layout: Path | None = None) -> list[TemplateLayout]:
    """Render PDF (multi-page) + layout.json. questions = list tipe ('mcq'|'short'|'essay')."""
    pages = compute_layout(questions)
    total_pages = len(pages)

    c = canvas.Canvas(str(out_pdf), pagesize=A4)
    c.setTitle(title)

    for page_index, page in enumerate(pages, start=1):
        if page_index > 1:
            c.showPage()

        if page_index == 1:
            _draw_header_fields(c, page_index, title, class_name)

        # ---- Marker ----
        c.setFillColorRGB(0, 0, 0)
        for (x_mm, y_mm) in MARKER_POS_MM.values():
            c.rect(x_mm * MM, (PAGE_H_MM - y_mm - MARKER_SIZE_MM) * MM, MARKER_SIZE_MM * MM, MARKER_SIZE_MM * MM, fill=1, stroke=0)
        c.setFillColorRGB(0, 0, 0)

        # ---- Grid jawaban ----
        for cell in page.cells:
            w_mm = cell.w / PX_PER_MM
            h_mm = cell.h / PX_PER_MM
            x_mm = cell.x / PX_PER_MM
            y_mm = cell.y / PX_PER_MM

            if cell.type == "mcq":
                # 4 kotak opsi a/b/c/d
                for i, opt in enumerate(MCQ_OPTIONS):
                    ox = MCQ_FIRST_X_MM + i * (MCQ_BOX_SIZE_MM[0] + MCQ_BOX_GAP_MM)
                    c.setLineWidth(1.2)
                    c.rect(ox * MM, (PAGE_H_MM - y_mm - MCQ_BOX_SIZE_MM[1]) * MM,
                           MCQ_BOX_SIZE_MM[0] * MM, MCQ_BOX_SIZE_MM[1] * MM)
                    c.setFont("Helvetica-Bold", 9)
                    c.drawCentredString((ox + MCQ_BOX_SIZE_MM[0] / 2) * MM,
                                        (PAGE_H_MM - y_mm - MCQ_BOX_SIZE_MM[1] / 2) * MM, opt)
                c.setFont("Helvetica-Bold", 10)
                c.drawRightString(NUM_LABEL_X_MM * MM, (PAGE_H_MM - y_mm - h_mm / 2) * MM, f"{cell.question_number}.")
            else:
                c.setLineWidth(1.4)
                c.rect(x_mm * MM, (PAGE_H_MM - y_mm - h_mm) * MM, w_mm * MM, h_mm * MM)
                c.setFont("Helvetica-Bold", 12)
                c.drawRightString((x_mm - 2) * MM, (PAGE_H_MM - y_mm - h_mm / 2) * MM, f"{cell.question_number}.")

        _draw_footer(c, page_index, total_pages)

    c.showPage()
    c.save()

    if out_layout is not None:
        out_layout.write_text(
            json.dumps(
                {"page_size_px": list(pages[0].page_size_px), "pages": [p.to_dict() for p in pages]},
                indent=2,
            ),
            encoding="utf-8",
        )

    return pages
