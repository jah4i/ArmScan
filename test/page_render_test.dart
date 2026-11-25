@Tags(['opencv'])
library;

import 'dart:io';

import 'package:armscan/scanner/page_processor.dart';
import 'package:armscan/scanner/paper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

// 850 x 1130: close to Letter (1.29) but not exact, with a heavy shadow on
// the right half.
const _page = 'test/fixtures/render/shadow_page.jpg';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('render'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('Auto snaps a near-Letter page to exactly Letter', () async {
    final r = await PageProcessor.render(
      _page,
      '${tmp.path}/a.jpg',
      mode: ColorMode.color,
      paper: PaperChoice.auto,
    );
    expect(r.paper, PaperSize.letter);
    expect(r.height / r.width, closeTo(PaperSize.letter.ratio, 0.003));
    final img = cv.imread(r.path);
    expect((img.cols, img.rows), (r.width, r.height));
  });

  test('Auto leaves an uncropped photo as it is', () async {
    final r = await PageProcessor.render(
      _page,
      '${tmp.path}/a.jpg',
      mode: ColorMode.color,
      paper: PaperChoice.auto,
      cropped: false,
    );
    expect(r.paper, isNull);
    expect((r.width, r.height), (850, 1130));
  });

  test('a fixed choice reshapes to that size', () async {
    final r = await PageProcessor.render(
      _page,
      '${tmp.path}/a.jpg',
      mode: ColorMode.color,
      paper: PaperChoice.legal,
    );
    expect(r.paper, PaperSize.legal);
    expect(r.height / r.width, closeTo(PaperSize.legal.ratio, 0.003));
  });

  test('B&W removes the shadow and keeps the text', () async {
    final r = await PageProcessor.render(
      _page,
      '${tmp.path}/bw.jpg',
      mode: ColorMode.bw,
      paper: PaperChoice.auto,
    );
    final img = cv.imread(r.path, flags: cv.IMREAD_GRAYSCALE);
    final w = img.cols, h = img.rows;

    // Blank paper in the shadow (right margin) and in the light (left
    // margin) both come out white.
    double meanOf(int x0, int y0, int x1, int y1) {
      final roi = img.region(cv.Rect(x0, y0, x1 - x0, y1 - y0));
      return cv.mean(roi).val1;
    }

    expect(
      meanOf(w * 90 ~/ 100, h * 40 ~/ 100, w * 97 ~/ 100, h * 60 ~/ 100),
      greaterThan(240),
      reason: 'shadowed paper should be white',
    );
    expect(
      meanOf(w * 2 ~/ 100, h * 40 ~/ 100, w * 6 ~/ 100, h * 60 ~/ 100),
      greaterThan(240),
      reason: 'lit paper should be white',
    );

    // The text block still has plenty of black.
    final text = meanOf(
      w * 10 ~/ 100,
      h * 20 ~/ 100,
      w * 80 ~/ 100,
      h * 85 ~/ 100,
    );
    expect(text, lessThan(235));
    expect(text, greaterThan(150));

    // Almost every pixel is near pure black or white.
    final total = w * h;
    final (_, mid) = cv.threshold(img, 200, 255, cv.THRESH_BINARY_INV);
    final (_, black) = cv.threshold(img, 55, 255, cv.THRESH_BINARY_INV);
    final inBetween = (cv.countNonZero(mid) - cv.countNonZero(black)) / total;
    expect(inBetween, lessThan(0.03));
  });

  test('B&W keeps solid black areas solid, like a photocopy', () async {
    final r = await PageProcessor.render(
      'test/fixtures/render/solid_page.jpg',
      '${tmp.path}/solid.jpg',
      mode: ColorMode.bw,
      paper: PaperChoice.auto,
    );
    final img = cv.imread(r.path, flags: cv.IMREAD_GRAYSCALE);
    final sx = img.cols / 850, sy = img.rows / 1100;
    double meanOf(int x0, int y0, int x1, int y1) => cv
        .mean(
          img.region(
            cv.Rect(
              (x0 * sx).round(),
              (y0 * sy).round(),
              ((x1 - x0) * sx).round(),
              ((y1 - y0) * sy).round(),
            ),
          ),
        )
        .val1;

    // Inside the black block, away from the white lettering.
    expect(meanOf(80, 90, 410, 150), lessThan(30));
    // The red block prints black too.
    expect(meanOf(500, 100, 760, 180), lessThan(30));
    // Shadowed blank paper is still white.
    expect(meanOf(770, 300, 830, 380), greaterThan(235));
  });

  test('Gray evens out the lighting', () async {
    final r = await PageProcessor.render(
      _page,
      '${tmp.path}/g.jpg',
      mode: ColorMode.gray,
      paper: PaperChoice.auto,
    );
    final img = cv.imread(r.path);
    expect(img.channels, 3); // JPEG decoder returns BGR; pixels are gray
    final g = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
    final w = g.cols, h = g.rows;
    final shadow = cv
        .mean(
          g.region(
            cv.Rect(w * 90 ~/ 100, h * 40 ~/ 100, w * 7 ~/ 100, h * 20 ~/ 100),
          ),
        )
        .val1;
    expect(shadow, greaterThan(225));
  });

  // Writes the outputs where a person can look at them:
  //   ARMSCAN_RENDER_OUT=/some/dir flutter test test/page_render_test.dart
  test('debug output', () async {
    final out = Platform.environment['ARMSCAN_RENDER_OUT'];
    if (out == null) return;
    await PageProcessor.render(
      'test/fixtures/render/solid_page.jpg',
      '$out/render_solid_bw.jpg',
      mode: ColorMode.bw,
      paper: PaperChoice.auto,
    );
    for (final m in ColorMode.values) {
      await PageProcessor.render(
        _page,
        '$out/render_${m.name}.jpg',
        mode: m,
        paper: PaperChoice.auto,
      );
    }
  });
}
