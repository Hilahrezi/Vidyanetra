import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:autograding_mobile/core/opencv_pipeline.dart';
import 'package:autograding_mobile/core/template_constants.dart';

img.Image _load(String name) {
  final bytes = File('test/fixtures/$name').readAsBytesSync();
  return img.decodeImage(bytes)!;
}

const List<String> questions = ['mcq', 'mcq', 'mcq', 'short', 'short', 'essay', 'essay'];

void main() {
  test('deteksi marker pada render flat', () {
    final photo = _load('fixture_flat.png');
    final res = detectMarkers(photo);

    // posisi marker template (px) — toleransi 6px (resolusi kerja + render 2481 vs 2480)
    final expected = markerCentersPx
        .map((m) => ((m[0] * 2481 / 2480), m[1]))
        .toList();
    for (var i = 0; i < 4; i++) {
      final dx = res.corners[i].$1 - expected[i].$1;
      final dy = res.corners[i].$2 - expected[i].$2;
      expect(dx.abs() < 6 && dy.abs() < 6, isTrue,
          reason: 'marker $i error (${dx.toStringAsFixed(1)},${dy.toStringAsFixed(1)})px');
    }
  });

  test('crop sel pada render flat menghasilkan JPEG valid', () {
    final photo = _load('fixture_flat.png');
    final res = detectMarkers(photo);
    final layout = computeLayout(questions);
    final crops = cropCells(photo, res, layout[0]);

    expect(crops.length, 6);
    for (final c in crops) {
      expect(c.questionNumber, greaterThan(0));
      final decoded = img.decodeJpg(c.jpegBytes);
      expect(decoded, isNotNull);
      // sel kosong = dominan terang
      final gray = _meanBrightness(decoded!);
      expect(gray, greaterThan(200), reason: 'sel ${c.questionNumber} harus terang');
    }
  });

  test('roundtrip foto miring: crop sel sama dengan render flat', () {
    final photoFlat = _load('fixture_flat.png');
    final photoPersp = _load('fixture_persp.png');
    final layout = computeLayout(questions);

    final resFlat = detectMarkers(photoFlat);
    final resPersp = detectMarkers(photoPersp);

    final cropsFlat = cropCells(photoFlat, resFlat, layout[0]);
    final cropsPersp = cropCells(photoPersp, resPersp, layout[0]);

    expect(cropsPersp.length, cropsFlat.length);
    for (var i = 0; i < cropsFlat.length; i++) {
      final a = img.decodeJpg(cropsFlat[i].jpegBytes)!;
      final b = img.decodeJpg(cropsPersp[i].jpegBytes)!;
      final meanDiff = _meanAbsDiff(a, b);
      expect(meanDiff, lessThan(10),
          reason: 'sel ${cropsFlat[i].questionNumber} diff=$meanDiff');
    }
  });

  test('gambar tanpa marker -> MarkerDetectionException', () {
    final blank = img.Image(width: 800, height: 600);
    img.fill(blank, color: img.ColorRgb8(200, 200, 200));
    expect(() => detectMarkers(blank), throwsA(isA<MarkerDetectionException>()));
  });
}

double _meanBrightness(img.Image image) {
  var sum = 0.0;
  for (final p in image) {
    sum += p.r;
  }
  return sum / (image.width * image.height);
}

double _meanAbsDiff(img.Image a, img.Image b) {
  expect(a.width, b.width);
  expect(a.height, b.height);
  var sum = 0.0;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      sum += ((pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs()) / 3.0;
    }
  }
  return sum / (a.width * a.height);
}
