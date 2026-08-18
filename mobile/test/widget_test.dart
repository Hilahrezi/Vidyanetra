import 'package:flutter_test/flutter_test.dart';

import 'package:autograding_mobile/core/template_constants.dart';

void main() {
  test('layout halaman tunggal', () {
    final pages = computeLayout(['mcq', 'mcq', 'mcq', 'short', 'short', 'essay', 'essay']);
    expect(pages.length, 2);
    expect(pages[0].length, 6);
    expect(pages[1].length, 1);
    final all = [...pages[0], ...pages[1]];
    expect(all.map((c) => c.questionNumber).toList(), [1, 2, 3, 4, 5, 6, 7]);
  });

  test('marker center pada posisi template', () {
    // persegi 12mm di (12,12)mm -> pusat (18,18)mm
    expect(markerCentersPx[0][0], closeTo(18 * (300 / 25.4), 0.01));
    expect(markerCentersPx[1][0], closeTo((210 - 18) * (300 / 25.4), 0.01));
  });
}
