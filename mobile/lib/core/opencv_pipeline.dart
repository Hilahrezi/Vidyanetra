import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'template_constants.dart';

/// Pipeline pemindaian lembar jawaban — port dari backend
/// `app/services/marker_detection.py` (tanpa dependensi native).
///
/// 1. Grayscale -> Otsu binarize (hitam = latar depan)
/// 2. Connected-component labeling -> filter ukuran/aspect/fill-ratio
/// 3. Pusat marker via interseksi diagonal titik ekstrem (projective-invariant)
/// 4. Homografi DLT (marker terdeteksi -> posisi template)
/// 5. Sampling bilinear per sel jawaban (tidak warp seluruh halaman)

class DetectionResult {
  /// Pusat 4 marker urut [TL, TR, BL, BR] dalam koordinat foto asli.
  final List<(double, double)> corners;
  final double sourceScale; // resolusi kerja vs foto asli

  const DetectionResult(this.corners, this.sourceScale);
}

class MarkerDetectionException implements Exception {
  final String message;
  const MarkerDetectionException(this.message);
  @override
  String toString() => message;
}

class CellCrop {
  final int questionNumber;
  final Uint8List jpegBytes;
  final McqMark? mcqMark;
  const CellCrop(this.questionNumber, this.jpegBytes, {this.mcqMark});
}

/// Hasil deteksi tanda X pada kotak opsi MCQ (tier-1 mobile, tanpa AI).
class McqMark {
  final String answer; // a/b/c/d
  final double confidence; // densitas tinta kotak terpilih
  final bool ambiguous;
  const McqMark(this.answer, this.confidence, this.ambiguous);
}

/// Fraksi [x0, x1] tiap kotak opsi dalam crop MCQ (mirror geometri template).
const List<List<double>> _mcqBoxFractions = [
  [0.0263, 0.2105],
  [0.2895, 0.4737],
  [0.5526, 0.7368],
  [0.8158, 1.0000],
];
const List<String> _mcqLetters = ['a', 'b', 'c', 'd'];
const double _mcqMinDensity = 0.03;
const double _mcqMarginRatio = 1.5;
const double _mcqInset = 0.15;

/// Deteksi opsi yang disilang (X) dalam crop MCQ yang sudah ter-warp.
McqMark detectMcqAnswer(img.Image crop) {
  final gray = _toGray(crop);
  final (_, bin) = _otsu(gray);
  final w = crop.width, h = crop.height;
  final densities = List<double>.filled(4, 0);

  for (var i = 0; i < 4; i++) {
    final x0 = (_mcqBoxFractions[i][0] * w).round();
    final x1 = (_mcqBoxFractions[i][1] * w).round();
    final mx = ((x1 - x0) * _mcqInset).round();
    final my = (h * _mcqInset).round();
    var dark = 0, total = 0;
    for (var y = my; y < h - my; y++) {
      for (var x = x0 + mx; x < x1 - mx; x++) {
        total++;
        if (bin[y * w + x] != 0) dark++;
      }
    }
    densities[i] = total == 0 ? 0 : dark / total;
  }

  final order = List.generate(4, (i) => i)..sort((a, b) => densities[b].compareTo(densities[a]));
  final best = order[0], second = order[1];
  final ambiguous = densities[best] < _mcqMinDensity ||
      densities[best] < _mcqMarginRatio * densities[second];
  return McqMark(_mcqLetters[best], densities[best], ambiguous);
}

/// ---- Utilitas gambar ----

/// Grayscale dari gambar BGR.
Uint8List _toGray(img.Image image) {
  final gray = Uint8List(image.width * image.height);
  var i = 0;
  for (final p in image) {
    gray[i++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
  }
  return gray;
}

/// Threshold Otsu: kembalikan nilai threshold dan biner (255=latang depan/hitam).
(int, Uint8List) _otsu(Uint8List gray) {
  final hist = List<int>.filled(256, 0);
  for (final v in gray) {
    hist[v]++;
  }
  final total = gray.length;
  var sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0, wB = 0, maxVar = -1.0, threshold = 127;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final between = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      threshold = t;
    }
  }
  final bin = Uint8List(total);
  for (var i = 0; i < total; i++) {
    bin[i] = gray[i] < threshold ? 255 : 0; // hitam (tulisan/marker) = 255
  }
  return (threshold, bin);
}

/// ---- Connected-component labeling (scanline flood, stack-based) ----

class _Component {
  int area = 0;
  int minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
  // Titik ekstrem untuk tiap arah diagonal.
  int? tlx, tly, brx, bry, trx, trY, blx, bly;
}

List<_Component> _connectedComponents(Uint8List bin, int w, int h) {
  final labels = Int32List(w * h);
  final comps = <_Component>[];
  final stack = <int>[];

  void update(_Component c, int x, int y) {
    c.area++;
    if (x < c.minX) c.minX = x;
    if (x > c.maxX) c.maxX = x;
    if (y < c.minY) c.minY = y;
    if (y > c.maxY) c.maxY = y;
    final s = x + y, d = x - y;
    if (c.tlx == null || s < (c.tlx! + c.tly!)) { c.tlx = x; c.tly = y; }
    if (c.brx == null || s > (c.brx! + c.bry!)) { c.brx = x; c.bry = y; }
    if (c.trx == null || d < (c.trx! - c.trY!)) { c.trx = x; c.trY = y; }
    if (c.blx == null || d > (c.blx! - c.bly!)) { c.blx = x; c.bly = y; }
  }

  void flood(int start) {
    final label = comps.length;
    comps.add(_Component());
    stack..clear()..add(start);
    labels[start] = label + 1;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p % w, y = p ~/ w;
      update(comps[label], x, y);
      void push(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
        final np = ny * w + nx;
        if (bin[np] != 0 && labels[np] == 0) {
          labels[np] = label + 1;
          stack.add(np);
        }
      }

      push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
    }
  }

  for (var i = 0; i < bin.length; i++) {
    if (bin[i] != 0 && labels[i] == 0) flood(i);
  }
  return comps;
}

/// Interseksi dua garis (p1-p2 dan p3-p4).
(double, double) _lineIntersection(
    (double, double) p1, (double, double) p2, (double, double) p3, (double, double) p4) {
  final denom = (p1.$1 - p2.$1) * (p3.$2 - p4.$2) - (p1.$2 - p2.$2) * (p3.$1 - p4.$1);
  if (denom.abs() < 1e-9) {
    return ((p1.$1 + p2.$1) / 2, (p1.$2 + p2.$2) / 2);
  }
  final t = ((p1.$1 - p3.$1) * (p3.$2 - p4.$2) - (p1.$2 - p3.$2) * (p3.$1 - p4.$1)) / denom;
  return (p1.$1 + t * (p2.$1 - p1.$1), p1.$2 + t * (p2.$2 - p1.$2));
}

List<(double, double)> _orderCorners(List<(double, double)> pts) {
  if (pts.length != 4) {
    throw MarkerDetectionException('Dibutuhkan 4 marker, ditemukan ${pts.length}');
  }
  final sorted = List.of(pts)..sort((a, b) => a.$1.compareTo(b.$1));
  var tl = sorted[0], bl = sorted[1], tr = sorted[2], br = sorted[3];
  if (tl.$2 > bl.$2) { final t = tl; tl = bl; bl = t; }
  if (tr.$2 > br.$2) { final t = tr; tr = br; br = t; }
  return [tl, tr, bl, br];
}

/// ---- API utama ----

/// Deteksi 4 marker pada foto. Bekerja pada versi diperkecil (maks [workMaxPx])
/// agar CCL cepat; koordinat hasil diskalakan kembali ke foto asli.
DetectionResult detectMarkers(img.Image photo, {int workMaxPx = 1200}) {
  final photoW = photo.width, photoH = photo.height;
  final scale = math.min(1.0, workMaxPx / math.max(photoW, photoH));
  final workW = (photoW * scale).round(), workH = (photoH * scale).round();

  img.Image work = photo;
  if (scale < 1.0) {
    work = img.copyResize(photo, width: workW, height: workH, interpolation: img.Interpolation.average);
  }
  final gray = _toGray(work);
  final (_, bin) = _otsu(gray);

  final comps = _connectedComponents(bin, workW, workH);
  final minPx = 40.0 * scale;
  final maxPx = 142.0 * 3 * scale;

  final candidates = <(double, double, double)>[]; // (area, cx, cy) scale kerja
  for (final c in comps) {
    final w = c.maxX - c.minX + 1, h = c.maxY - c.minY + 1;
    if (w < minPx || h < minPx || w > maxPx || h > maxPx) continue;
    final aspect = math.max(w, h) / math.min(w, h);
    if (aspect > 1.3) continue;
    final bboxArea = w * h;
    if (c.area / bboxArea < 0.7) continue; // marker solid vs kotak hampa
    final center = _lineIntersection(
      (c.tlx!.toDouble(), c.tly!.toDouble()),
      (c.brx!.toDouble(), c.bry!.toDouble()),
      (c.trx!.toDouble(), c.trY!.toDouble()),
      (c.blx!.toDouble(), c.bly!.toDouble()),
    );
    candidates.add((c.area.toDouble(), center.$1, center.$2));
  }

  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  if (candidates.length < 4) {
    throw MarkerDetectionException(
        'Terlalu sedikit marker terdeteksi (${candidates.length}/4). Perbaiki pencahayaan/posisi lembar.');
  }
  final ordered = _orderCorners(
    candidates.sublist(0, 4).map((c) => (c.$2, c.$3)).toList(),
  );
  final invScale = 1 / scale;
  return DetectionResult(
    ordered.map((c) => (c.$1 * invScale, c.$2 * invScale)).toList(),
    scale,
  );
}

/// Homografi DLT: mapping 4 titik source -> 4 titik target. Return matriks 3x3.
List<double> _solveHomography(List<(double, double)> src, List<(double, double)> dst) {
  // Ax = b, 8 persamaan
  final a = List.generate(8, (_) => List<double>.filled(8, 0));
  final b = List<double>.filled(8, 0);
  for (var i = 0; i < 4; i++) {
    final (sx, sy) = src[i];
    final (dx, dy) = dst[i];
    a[i * 2] = [sx, sy, 1, 0, 0, 0, -dx * sx, -dx * sy];
    a[i * 2 + 1] = [0, 0, 0, sx, sy, 1, -dy * sx, -dy * sy];
    b[i * 2] = dx;
    b[i * 2 + 1] = dy;
  }
  // Gauss-Jordan
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var r = col + 1; r < 8; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    if (a[pivot][col].abs() < 1e-12) {
      throw const MarkerDetectionException('Homografi degenerasi');
    }
    final tmpRow = a[col]; a[col] = a[pivot]; a[pivot] = tmpRow;
    final tmpB = b[col]; b[col] = b[pivot]; b[pivot] = tmpB;
    for (var r = 0; r < 8; r++) {
      if (r == col) continue;
      final f = a[r][col] / a[col][col];
      for (var c2 = col; c2 < 8; c2++) {
        a[r][c2] -= f * a[col][c2];
      }
      b[r] -= f * b[col];
    }
  }
  final h = List<double>.filled(9, 0);
  for (var i = 0; i < 8; i++) {
    h[i] = b[i] / a[i][i];
  }
  h[8] = 1;
  return h;
}

/// Sampling bilinear satu sel: koordinat template (dst px) -> foto asli via
/// invers homografi. Return crop BGR.
img.Image _sampleCell(img.Image photo, List<double> h, CellRect cell) {
  final inv = _invert3x3(h);
  final out = img.Image(width: cell.w, height: cell.h, numChannels: 3);
  for (var y = 0; y < cell.h; y++) {
    for (var x = 0; x < cell.w; x++) {
      final tx = cell.x + x + 0.5;
      final ty = cell.y + y + 0.5;
      final denom = inv[6] * tx + inv[7] * ty + inv[8];
      final sx = (inv[0] * tx + inv[1] * ty + inv[2]) / denom;
      final sy = (inv[3] * tx + inv[4] * ty + inv[5]) / denom;
      // bilinear
      final x0 = sx.floor(), y0 = sy.floor();
      if (x0 < 0 || y0 < 0 || x0 >= photo.width - 1 || y0 >= photo.height - 1) {
        out.setPixelRgb(x, y, 255, 255, 255);
        continue;
      }
      final fx = sx - x0, fy = sy - y0;
      final p00 = photo.getPixel(x0, y0);
      final p10 = photo.getPixel(x0 + 1, y0);
      final p01 = photo.getPixel(x0, y0 + 1);
      final p11 = photo.getPixel(x0 + 1, y0 + 1);
      final r = _blend([p00.r, p10.r, p01.r, p11.r], fx, fy);
      final g = _blend([p00.g, p10.g, p01.g, p11.g], fx, fy);
      final bl = _blend([p00.b, p10.b, p01.b, p11.b], fx, fy);
      out.setPixelRgb(x, y, r, g, bl);
    }
  }
  return out;
}

int _blend(List<num> v, double fx, double fy) {
  final top = v[0] * (1 - fx) + v[1] * fx;
  final bottom = v[2] * (1 - fx) + v[3] * fx;
  return (top * (1 - fy) + bottom * fy).round().clamp(0, 255);
}

List<double> _invert3x3(List<double> m) {
  final det = m[0] * (m[4] * m[8] - m[5] * m[7]) -
      m[1] * (m[3] * m[8] - m[5] * m[6]) +
      m[2] * (m[3] * m[7] - m[4] * m[6]);
  if (det.abs() < 1e-12) {
    throw const MarkerDetectionException('Matriks singular');
  }
  final inv = List<double>.filled(9, 0);
  inv[0] = (m[4] * m[8] - m[5] * m[7]) / det;
  inv[1] = (m[2] * m[7] - m[1] * m[8]) / det;
  inv[2] = (m[1] * m[5] - m[2] * m[4]) / det;
  inv[3] = (m[5] * m[6] - m[3] * m[8]) / det;
  inv[4] = (m[0] * m[8] - m[2] * m[6]) / det;
  inv[5] = (m[2] * m[3] - m[0] * m[5]) / det;
  inv[6] = (m[3] * m[7] - m[4] * m[6]) / det;
  inv[7] = (m[1] * m[6] - m[0] * m[7]) / det;
  inv[8] = (m[0] * m[4] - m[1] * m[3]) / det;
  return inv;
}

/// Crop semua sel dari foto menggunakan hasil deteksi + layout halaman.
/// Output JPEG base64 (siap kirim ke backend).
List<CellCrop> cropCells(img.Image photo, DetectionResult result, List<CellRect> cells,
    {int quality = 70}) {
  final dst = markerCentersPx.map((m) => (m[0], m[1])).toList();
  final h = _solveHomography(result.corners, dst);
  final crops = <CellCrop>[];
  for (final cell in cells) {
    final sampled = _sampleCell(photo, h, cell);
    final mcqMark = cell.type == 'mcq' ? detectMcqAnswer(sampled) : null;
    // resize longest side <= 768px sesuai kontrak backend
    var resized = sampled;
    final longest = math.max(sampled.width, sampled.height);
    if (longest > 768) {
      final ratio = 768 / longest;
      resized = img.copyResize(sampled,
          width: (sampled.width * ratio).round(), height: (sampled.height * ratio).round(),
          interpolation: img.Interpolation.average);
    }
    final jpg = img.encodeJpg(resized, quality: quality);
    crops.add(CellCrop(cell.questionNumber, jpg, mcqMark: mcqMark));
  }
  return crops;
}
