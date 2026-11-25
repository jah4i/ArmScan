import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'document_detector.dart';

/// Turns a raw camera photo into a clean page image: finds the page edges,
/// crops and straightens it, and saves a JPEG. Runs on a background isolate
/// so the camera preview never stutters.
abstract final class PageProcessor {
  /// Longest side of saved pages. ~300 dpi for A4/Letter, small enough to
  /// keep PDFs quick to build and upload.
  static const maxOutputSide = 3200;

  /// Processes [srcPath] into a new JPEG at [outPath] and returns `true` if a
  /// page outline was found (otherwise the whole photo is kept).
  ///
  /// [hint] is the outline seen in the live preview, used when the photo
  /// itself is ambiguous and the preview had the same framing.
  static Future<bool> process(
    String srcPath,
    String outPath, {
    Quad? hint,
    double? hintAspect,
  }) {
    final hintPoints = hint?.points.map((o) => [o.dx, o.dy]).toList();
    return Isolate.run(
        () => _process(srcPath, outPath, hintPoints, hintAspect));
  }
}

bool _process(
  String srcPath,
  String outPath,
  List<List<double>>? hintPoints,
  double? hintAspect,
) {
  // imread applies the photo's EXIF orientation, so the page is upright.
  final img = cv.imread(srcPath, flags: cv.IMREAD_COLOR);
  if (img.isEmpty) {
    img.dispose();
    throw FileSystemException('Could not read photo', srcPath);
  }
  cv.Mat? warped, scaled;
  try {
    var quad = const DocumentDetector(maxSide: 640).detect(img);
    if (quad == null && hintPoints != null && hintAspect != null) {
      final aspect = img.cols / img.rows;
      if ((aspect - hintAspect).abs() / hintAspect < 0.04) {
        quad = Quad([
          for (final p in hintPoints) Offset(p[0], p[1]),
        ]);
      }
    }
    var out = img;
    if (quad != null) out = warped = warpDocument(img, quad);

    final longest = math.max(out.cols, out.rows);
    if (longest > PageProcessor.maxOutputSide) {
      final s = PageProcessor.maxOutputSide / longest;
      out = scaled = cv.resize(
          out, ((out.cols * s).round(), (out.rows * s).round()),
          interpolation: cv.INTER_AREA);
    }
    final ok = cv.imwrite(outPath, out,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 88]));
    if (!ok) throw FileSystemException('Could not save page', outPath);
    return quad != null;
  } finally {
    img.dispose();
    warped?.dispose();
    scaled?.dispose();
  }
}
