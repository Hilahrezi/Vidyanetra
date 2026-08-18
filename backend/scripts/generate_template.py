"""Generate PDF template lembar jawaban A4 + verifikasi deteksi marker.

usage:
  python scripts/generate_template.py --title "UTS Matematika" \
         --questions "mcq:5 short:3 essay:2" --out lembar_jawaban.pdf
  python scripts/generate_template.py --verify --out lembar_jawaban.pdf
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.marker_detection import detect_markers, warp_page, MarkerDetectionError, load_layout  # noqa: E402
from app.services.template_service import build_pdf  # noqa: E402

VALID_TYPES = ("mcq", "short", "essay")


def parse_questions(spec: str) -> list[str]:
    questions: list[str] = []
    for token in spec.split():
        try:
            qtype, count = token.split(":")
        except ValueError:
            raise SystemExit(f"Format --questions salah: '{token}' (harus 'tipe:jumlah')")
        if qtype not in VALID_TYPES:
            raise SystemExit(f"Tipe soal tidak dikenal: '{qtype}' (pilihan: mcq, short, essay)")
        questions.extend([qtype] * int(count))
    if not questions:
        raise SystemExit("--questions tidak boleh kosong")
    return questions


def render_pdf_to_png(pdf_path: Path, page_index: int, out_png: Path | None = None, dpi: int = 300) -> Path:
    import pymupdf

    doc = pymupdf.open(str(pdf_path))
    page = doc[page_index]
    pix = page.get_pixmap(dpi=dpi)
    png_path = out_png or pdf_path.with_suffix(f".page{page_index + 1}.verify.png")
    pix.save(str(png_path))
    doc.close()
    return png_path


def verify_template(pdf_path: Path, layout_path: Path) -> int:
    import cv2

    pages = load_layout(layout_path)
    print(f"[verify] Render PDF -> PNG (300 dpi), {len(pages)} halaman...")

    for page_index, page in enumerate(pages):
        print(f"\n  Halaman {page_index + 1}:")
        png = render_pdf_to_png(pdf_path, page_index)
        img = cv2.imread(str(png))
        if img is None:
            print(f"    ERROR: tidak bisa membaca {png}")
            return 1

        # 1) Deteksi marker
        try:
            corners = detect_markers(img)
        except MarkerDetectionError as exc:
            print(f"    FAIL: {exc}")
            return 1
        print(f"    Marker terdeteksi: 4/4 OK")

        # 2) Cek posisi vs layout (warp error)
        expected = [
            page.markers_px["tl"],
            page.markers_px["tr"],
            page.markers_px["bl"],
            page.markers_px["br"],
        ]
        max_err = 0.0
        for (cx, cy), (ex, ey) in zip(corners, expected):
            max_err = max(max_err, ((cx - ex) ** 2 + (cy - ey) ** 2) ** 0.5)
        print(f"    Posisi marker vs layout: max error {max_err:.2f}px")
        if max_err > 2.0:
            print("    FAIL: error posisi marker > 2px")
            return 1

        # 3) Warp + crop tiap sel (validasi geometri)
        warped = warp_page(img, corners, page)
        for cell in page.cells:
            crop = warped[cell.y : cell.y + cell.h, cell.x : cell.x + cell.w]
            mean = float(crop.mean())
            if mean < 200:
                print(f"    FAIL: sel {cell.question_number} ({cell.type}) gelap (mean={mean:.0f}) — koordinat salah?")
                return 1
        print(f"    Warp OK, {len(page.cells)} sel ter-crop dengan benar")

    print("\nVERIFY: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate lembar jawaban A4 dengan fiducial markers")
    parser.add_argument("--title", default="UJIAN SEKOLAH")
    parser.add_argument("--class-name", default="")
    parser.add_argument("--questions", default="mcq:5 short:3 essay:2", help="format 'mcq:5 short:3 essay:2'")
    parser.add_argument("--out", default="lembar_jawaban.pdf")
    parser.add_argument("--layout-out", default=None, help="Path layout.json (default: <out>.layout.json)")
    parser.add_argument("--verify", action="store_true", help="Jalankan verifikasi deteksi + crop setelah generate")
    args = parser.parse_args()

    questions = parse_questions(args.questions)
    out_pdf = Path(args.out)
    layout_path = Path(args.layout_out) if args.layout_out else out_pdf.with_suffix(".layout.json")

    pages = build_pdf(questions, args.title, args.class_name, out_pdf, layout_path)
    print(f"PDF dibuat: {out_pdf.resolve()} ({len(questions)} soal, {len(pages)} halaman)")
    print(f"Layout: {layout_path.resolve()}")

    if args.verify:
        return verify_template(out_pdf, layout_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
