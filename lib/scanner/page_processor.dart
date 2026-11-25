import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'document_detector.dart';
import 'paper.dart';

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
      () => _process(srcPath, outPath, hintPoints, hintAspect),
    );
  }

  /// Finishes a cropped page: reshapes it to a standard paper size and
  /// applies the colour mode, writing a JPEG to [outPath].
  ///
  /// With [PaperChoice.auto] the page is snapped only when it was cropped
  /// ([cropped]) and its shape is close to Letter, Legal or A4.
  static Future<RenderedPage> render(
    String originalPath,
    String outPath, {
    required ColorMode mode,
    required PaperChoice paper,
    bool cropped = true,
  }) async {
    final (w, h, name) = await Isolate.run(
      () => _render(originalPath, outPath, mode.name, paper.name, cropped),
    );
    return RenderedPage(outPath, w, h, PaperSize.byName(name));
  }
}

/// Result of [PageProcessor.render].
class RenderedPage {
  const RenderedPage(this.path, this.width, this.height, this.paper);
  final String path;
  final int width;
  final int height;

  /// The standard size the page was snapped to, or null if left as is.
  final PaperSize? paper;
}

(int, int, String?) _render(
  String originalPath,
  String outPath,
  String modeName,
  String paperName,
  bool cropped,
) {
  final mode = ColorMode.byName(modeName);
  final choice = PaperChoice.values.byName(paperName);
  final img = cv.imread(originalPath, flags: cv.IMREAD_COLOR);
  if (img.isEmpty) {
    img.dispose();
    throw FileSystemException('Could not read page', originalPath);
  }
  final owned = <cv.Mat>[img];
  try {
    var out = img;
    final paper =
        choice.fixed ?? (cropped ? detectPaper(img.cols, img.rows) : null);
    if (paper != null) {
      final (w, h) = snapToPaper(
        img.cols,
        img.rows,
        paper,
        maxSide: PageProcessor.maxOutputSide,
      );
      if (w != img.cols || h != img.rows) {
        out = cv.resize(img, (w, h), interpolation: cv.INTER_AREA);
        owned.add(out);
      }
    }
    if (mode != ColorMode.color) {
      final cleaned = cleanUpGray(out, binarize: mode == ColorMode.bw);
      owned.addAll(cleaned.$2);
      out = cleaned.$1;
    }
    final ok = cv.imwrite(
      outPath,
      out,
      params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 88]),
    );
    if (!ok) throw FileSystemException('Could not save page', outPath);
    return (out.cols, out.rows, paper?.name);
  } finally {
    for (final m in owned) {
      m.dispose();
    }
  }
}

/// Grayscale with shadows and uneven lighting removed: each pixel is divided
/// by an estimate of the blank paper around it, so the paper turns white
/// and ink stays dark. With [binarize], it is then made pure black and white.
///
/// Returns the result and every intermediate Mat, which the caller disposes.
(cv.Mat, List<cv.Mat>) cleanUpGray(cv.Mat bgr, {required bool binarize}) {
  final mats = <cv.Mat>[];
  cv.Mat keep(cv.Mat m) {
    mats.add(m);
    return m;
  }

  final gray = keep(cv.cvtColor(bgr, cv.COLOR_BGR2GRAY));

  // Paper estimate: work at a quarter size for speed. Dilating removes thin
  // dark strokes (text), the median blur smooths what is left.
  final small = keep(
    cv.resize(gray, (
      math.max(1, gray.cols ~/ 4),
      math.max(1, gray.rows ~/ 4),
    ), interpolation: cv.INTER_AREA),
  );
  final kernel = keep(cv.getStructuringElement(cv.MORPH_RECT, (7, 7)));
  final dilated = keep(cv.dilate(small, kernel));
  final bgSmall = keep(cv.medianBlur(dilated, 21));
  final bg = keep(
    cv.resize(bgSmall, (gray.cols, gray.rows), interpolation: cv.INTER_LINEAR),
  );
  final flat = keep(cv.divide(gray, bg, scale: 255));
  if (!binarize) return (flat, mats);

  // Block size scales with the page so strokes look the same at any
  // resolution (~1/40 of the short side, odd, at least 15 px).
  var block = math.min(flat.cols, flat.rows) ~/ 40;
  if (block.isEven) block++;
  if (block < 15) block = 15;
  final bw = keep(
    cv.adaptiveThreshold(
      flat,
      255,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY,
      block,
      18,
    ),
  );

  // Like a photocopier, anything genuinely dark stays solid black. The
  // local threshold above only sees edges, so on its own a filled black
  // area would come out as an outline. "Dark" is judged against the paper
  // brightness, so shadows on the paper are not filled in.
  final paperLevel = _percentile(small, 0.90);
  final smooth = keep(cv.gaussianBlur(gray, (3, 3), 0));
  final (_, dark) = cv.threshold(
    smooth,
    paperLevel * solidDarkFraction,
    255,
    cv.THRESH_BINARY_INV,
  );
  keep(dark);
  final copy = keep(cv.subtract(bw, dark));
  return (copy, mats);
}

/// Pixels darker than this fraction of the paper brightness print as solid
/// black in B&W.
const double solidDarkFraction = 0.55;

/// Brightness below which [fraction] of the pixels of a gray [mat] fall.
double _percentile(cv.Mat mat, double fraction) {
  final hist = List<int>.filled(256, 0);
  final data = mat.data;
  for (var i = 0; i < data.length; i++) {
    hist[data[i]]++;
  }
  final target = data.length * fraction;
  var seen = 0;
  for (var v = 0; v < 256; v++) {
    seen += hist[v];
    if (seen >= target) return v.toDouble();
  }
  return 255;
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
        quad = Quad([for (final p in hintPoints) Offset(p[0], p[1])]);
      }
    }
    var out = img;
    if (quad != null) out = warped = warpDocument(img, quad);

    final longest = math.max(out.cols, out.rows);
    if (longest > PageProcessor.maxOutputSide) {
      final s = PageProcessor.maxOutputSide / longest;
      out = scaled = cv.resize(out, (
        (out.cols * s).round(),
        (out.rows * s).round(),
      ), interpolation: cv.INTER_AREA);
    }
    final ok = cv.imwrite(
      outPath,
      out,
      params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 88]),
    );
    if (!ok) throw FileSystemException('Could not save page', outPath);
    return quad != null;
  } finally {
    img.dispose();
    warped?.dispose();
    scaled?.dispose();
  }
}
