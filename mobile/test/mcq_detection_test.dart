import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:autograding_mobile/core/opencv_pipeline.dart';

img.Image _load(String name) {
  final bytes = File('test/fixtures/$name').readAsBytesSync();
  return img.decodeImage(bytes)!;
}

void main() {
  test('deteksi X di kotak b', () {
    final mark = detectMcqAnswer(_load('mcq_b.png'));
    expect(mark.answer, 'b');
    expect(mark.ambiguous, isFalse);
    expect(mark.confidence, greaterThan(0.03));
  });

  test('deteksi X di kotak c dan a', () {
    expect(detectMcqAnswer(_load('mcq_c.png')).answer, 'c');
    expect(detectMcqAnswer(_load('mcq_a.png')).answer, 'a');
  });

  test('tanpa tanda -> ambiguous', () {
    final mark = detectMcqAnswer(_load('mcq_none.png'));
    expect(mark.ambiguous, isTrue);
  });

  test('X ganda -> ambiguous', () {
    final mark = detectMcqAnswer(_load('mcq_double.png'));
    expect(mark.ambiguous, isTrue);
  });
}
