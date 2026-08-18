/// Geometri template lembar jawaban — mirror dari backend
/// `app/services/template_service.py` (single source of truth backend).
///
/// Koordinat dalam PIXEL ruang warp 2480x3508 (@300dpi). Generator backend
/// mengekspor layout.json dengan struktur yang sama; nilai di bawah harus
/// disinkronkan manual bila template diubah (dicek via test fixture).
library;

const int pageWidthPx = 2480;
const int pageHeightPx = 3508;

const double mmToPx = 300 / 25.4; // 11.811

/// Pusat 4 fiducial marker di ruang template (mm: persegi 12mm di (12,12) dll
/// -> pusat (18,18)mm dst).
const List<List<double>> markerCentersPx = [
  [18 * mmToPx, 18 * mmToPx], // TL
  [(210 - 18) * mmToPx, 18 * mmToPx], // TR
  [18 * mmToPx, (297 - 18) * mmToPx], // BL
  [(210 - 18) * mmToPx, (297 - 18) * mmToPx], // BR
];

/// Ukuran kotak jawaban per tipe (mm). MCQ = area baris berisi 4 kotak opsi.
const Map<String, List<double>> cellSizeMm = {
  'mcq': [76, 16],
  'short': [100, 18],
  'essay': [170, 45],
};

/// Konstanta tata letak (mm) — mirror template_service.py (redesain Fase 3-R).
const double marginMm = 15;
const double numLabelWMm = 10;
const double gridY0Mm = 97; // halaman 1 (setelah kop + identitas ramping)
const double gridY0SubMm = 32; // halaman 2+
const double rowGapMm = 8;
const double bottomLimitMm = 297 - marginMm - 12 - 2;

/// Data satu kotak jawaban di ruang warp (px).
class CellRect {
  final int questionNumber;
  final String type;
  final int x, y, w, h;

  const CellRect(this.questionNumber, this.type, this.x, this.y, this.w, this.h);
}

/// Hitung tata letak per halaman (paginasi sama dengan backend).
List<List<CellRect>> computeLayout(List<String> questions) {
  final pages = <List<CellRect>>[];
  var page = <CellRect>[];
  var yMm = gridY0Mm;

  for (var i = 0; i < questions.length; i++) {
    final qtype = questions[i];
    final size = cellSizeMm[qtype]!;
    final wMm = size[0], hMm = size[1];
    if (yMm + hMm > bottomLimitMm) {
      pages.add(page);
      page = [];
      yMm = gridY0SubMm;
    }
    page.add(CellRect(
      i + 1,
      qtype,
      ((marginMm + numLabelWMm) * mmToPx).round(),
      (yMm * mmToPx).round(),
      (wMm * mmToPx).round(),
      (hMm * mmToPx).round(),
    ));
    yMm += hMm + rowGapMm;
  }
  pages.add(page);
  return pages;
}
