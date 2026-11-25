import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Four document corners in normalized image coordinates (0..1), ordered
/// top-left, top-right, bottom-right, bottom-left.
class Quad {
  const Quad(this.points) : assert(points.length == 4);

  final List<Offset> points;

  Offset get tl => points[0];
  Offset get tr => points[1];
  Offset get br => points[2];
  Offset get bl => points[3];

  /// Largest distance any corner moved, in normalized units.
  double maxCornerShift(Quad other) {
    var m = 0.0;
    for (var i = 0; i < 4; i++) {
      m = math.max(m, (points[i] - other.points[i]).distance);
    }
    return m;
  }

  /// Corner-wise linear interpolation, used to smooth the live outline.
  Quad lerp(Quad other, double t) => Quad([
        for (var i = 0; i < 4; i++)
          Offset.lerp(points[i], other.points[i], t)!,
      ]);

  /// Area in normalized units (shoelace formula).
  double get area {
    var s = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = points[i], b = points[(i + 1) % 4];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }

  @override
  String toString() => 'Quad(${points.map((p) => '(${p.dx.toStringAsFixed(3)}, '
      '${p.dy.toStringAsFixed(3)})').join(', ')})';
}

/// Classic document detection: blur, edges, contours, then the largest convex
/// four-sided contour. Falls back to an Otsu threshold pass for low-contrast
/// edges (white page on a light desk).
class DocumentDetector {
  const DocumentDetector({this.maxSide = 400, this.minAreaFraction = 0.12});

  /// Frames are downscaled so their longest side is at most this many pixels.
  final int maxSide;

  /// Smallest document, as a fraction of the frame, that counts as a page.
  final double minAreaFraction;

  /// Detects a page in an 8-bit single-channel image of [width] x [height].
  Quad? detectGray(Uint8List gray, int width, int height) {
    final mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, gray);
    try {
      return detect(mat);
    } finally {
      mat.dispose();
    }
  }

  /// Detects a page in a grayscale or BGR [image].
  Quad? detect(cv.Mat image) {
    final disposables = <cv.Mat>[];
    cv.Mat track(cv.Mat m) {
      disposables.add(m);
      return m;
    }

    try {
      var gray = image.channels == 1
          ? image
          : track(cv.cvtColor(image, cv.COLOR_BGR2GRAY));
      final scale = maxSide / math.max(gray.cols, gray.rows);
      if (scale < 1) {
        gray = track(cv.resize(
          gray,
          ((gray.cols * scale).round(), (gray.rows * scale).round()),
          interpolation: cv.INTER_AREA,
        ));
      }
      final w = gray.cols.toDouble(), h = gray.rows.toDouble();
      final blurred = track(cv.gaussianBlur(gray, (5, 5), 0));
      final kernel = track(cv.getStructuringElement(cv.MORPH_RECT, (3, 3)));

      // Pass 1: Canny edges, dilated to close small gaps in the outline.
      final edges = track(cv.canny(blurred, 40, 120));
      final closed = track(cv.dilate(edges, kernel, iterations: 2));
      final q1 = _bestQuad(closed, w, h);
      if (q1 != null) return q1;

      // Pass 2: Otsu threshold separates a bright page from its background.
      final (_, bin) = cv.threshold(
          blurred, 0, 255, cv.THRESH_BINARY | cv.THRESH_OTSU);
      track(bin);
      return _bestQuad(bin, w, h);
    } finally {
      for (final m in disposables) {
        m.dispose();
      }
    }
  }

  Quad? _bestQuad(cv.Mat binary, double w, double h) {
    final (contours, hierarchy) =
        cv.findContours(binary, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    try {
      final minArea = minAreaFraction * w * h;
      final candidates = <(double, cv.VecPoint)>[];
      for (final c in contours) {
        final a = cv.contourArea(c);
        if (a >= minArea) candidates.add((a, c));
      }
      candidates.sort((a, b) => b.$1.compareTo(a.$1));

      for (final (_, contour) in candidates.take(6)) {
        final peri = cv.arcLength(contour, true);
        for (final eps in const [0.02, 0.03, 0.045]) {
          final approx = cv.approxPolyDP(contour, eps * peri, true);
          if (approx.length == 4 && cv.isContourConvex(approx)) {
            final pts = [
              for (var i = 0; i < 4; i++)
                Offset(approx[i].x / w, approx[i].y / h),
            ];
            approx.dispose();
            final quad = Quad(orderCorners(pts));
            // Reject the frame border itself (whole image detected as page).
            if (quad.area > 0.97) continue;
            return quad;
          }
          approx.dispose();
        }
      }
      return null;
    } finally {
      contours.dispose();
      hierarchy.dispose();
    }
  }
}

/// Orders four points as top-left, top-right, bottom-right, bottom-left.
List<Offset> orderCorners(List<Offset> pts) {
  final bySum = [...pts]..sort((a, b) => (a.dx + a.dy).compareTo(b.dx + b.dy));
  final byDiff = [...pts]..sort((a, b) => (a.dy - a.dx).compareTo(b.dy - b.dx));
  final tl = bySum.first, br = bySum.last;
  final tr = byDiff.first, bl = byDiff.last;
  // Degenerate (very rotated) input: fall back to angular order around centre.
  if ({tl, tr, br, bl}.length < 4) {
    final c = pts.reduce((a, b) => a + b) / 4;
    final sorted = [...pts]..sort((a, b) =>
        math.atan2(a.dy - c.dy, a.dx - c.dx)
            .compareTo(math.atan2(b.dy - c.dy, b.dx - c.dx)));
    // atan2 order starts at the left (-pi); rotate so it begins top-left.
    final start = sorted.indexOf(sorted.reduce(
        (a, b) => (a.dx + a.dy) <= (b.dx + b.dy) ? a : b));
    return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
  }
  return [tl, tr, br, bl];
}

/// Crops and straightens the page inside [quad] from a full-resolution
/// BGR [image]. Output size follows the page's real proportions.
cv.Mat warpDocument(cv.Mat image, Quad quad) {
  final w = image.cols.toDouble(), h = image.rows.toDouble();
  final p = [for (final o in quad.points) Offset(o.dx * w, o.dy * h)];
  final outW = math.max((p[1] - p[0]).distance, (p[2] - p[3]).distance).round();
  final outH = math.max((p[3] - p[0]).distance, (p[2] - p[1]).distance).round();

  final src = cv.VecPoint2f.fromList(
      [for (final o in p) cv.Point2f(o.dx, o.dy)]);
  final dst = cv.VecPoint2f.fromList([
    cv.Point2f(0, 0),
    cv.Point2f(outW - 1, 0),
    cv.Point2f(outW - 1, outH - 1),
    cv.Point2f(0, outH - 1),
  ]);
  final m = cv.getPerspectiveTransform2f(src, dst);
  try {
    return cv.warpPerspective(image, m, (outW, outH),
        flags: cv.INTER_LINEAR, borderMode: cv.BORDER_REPLICATE);
  } finally {
    m.dispose();
    src.dispose();
    dst.dispose();
  }
}
