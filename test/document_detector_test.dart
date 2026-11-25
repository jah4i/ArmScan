@Tags(['opencv'])
library;


import 'package:armscan/scanner/document_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

const _dir = 'test/fixtures/detect';

// Page corners drawn into the fixtures (960 x 1280).
const _expected = [
  Offset(210 / 960, 180 / 1280),
  Offset(800 / 960, 250 / 1280),
  Offset(760 / 960, 1120 / 1280),
  Offset(150 / 960, 1040 / 1280),
];

void expectNear(Quad? q) {
  expect(q, isNotNull);
  for (var i = 0; i < 4; i++) {
    expect((q!.points[i] - _expected[i]).distance, lessThan(0.03),
        reason: 'corner $i: got ${q.points[i]}, want ${_expected[i]}');
  }
}

void main() {
  const detector = DocumentDetector();

  test('finds a white page on a dark desk', () {
    final img = cv.imread('$_dir/dark_desk.jpg');
    expectNear(detector.detect(img));
  });

  test('finds a white page on a light desk', () {
    final img = cv.imread('$_dir/light_desk.jpg');
    expectNear(detector.detect(img));
  });

  test('finds nothing when there is no page', () {
    final img = cv.imread('$_dir/empty.jpg');
    expect(detector.detect(img), isNull);
  });

  test('detects from a raw grayscale buffer like a camera Y plane', () {
    final img = cv.imread('$_dir/dark_desk.jpg', flags: cv.IMREAD_GRAYSCALE);
    final q = detector.detectGray(img.data, img.cols, img.rows);
    expectNear(q);
  });

  test('warp straightens the page to its real proportions', () {
    final img = cv.imread('$_dir/dark_desk.jpg');
    final q = detector.detect(img)!;
    final out = warpDocument(img, q);
    expect(out.cols, inInclusiveRange(560, 640));
    expect(out.rows, inInclusiveRange(840, 920));
    // Top margin of the straightened page is page-white, not desk-brown.
    final px = out.at<cv.Vec3b>(out.rows ~/ 12, out.cols ~/ 2);
    expect(px.val1, greaterThan(200));
  });

  test('corner ordering and stability helpers', () {
    final shuffled = [_expected[2], _expected[0], _expected[3], _expected[1]];
    expect(orderCorners(shuffled), _expected);
    final q = Quad(_expected);
    expect(q.maxCornerShift(q), 0);
    expect(q.lerp(q, 0.5).points, _expected);
    expect(q.area, greaterThan(0.4));
  });
}
