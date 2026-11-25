/// Standard paper sizes ArmScan recognises, and how a page is finished.
library;

/// A physical paper size. Sizes are portrait, in PDF points (1/72 inch).
enum PaperSize {
  letter('Letter', 612, 792),
  legal('Legal', 612, 1008),
  a4('A4', 595.28, 841.89);

  const PaperSize(this.label, this.widthPt, this.heightPt);

  final String label;
  final double widthPt;
  final double heightPt;

  /// Long side divided by short side.
  double get ratio => heightPt / widthPt;

  static PaperSize? byName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// PDF page size (width, height) in points, landscape when the scan is.
  (double, double) pdfSize({required bool landscape}) =>
      landscape ? (heightPt, widthPt) : (widthPt, heightPt);
}

/// What the user picked in the size picker. [auto] detects per page.
enum PaperChoice {
  auto('Auto'),
  letter('Letter'),
  legal('Legal'),
  a4('A4');

  const PaperChoice(this.label);
  final String label;

  PaperSize? get fixed => switch (this) {
    PaperChoice.auto => null,
    PaperChoice.letter => PaperSize.letter,
    PaperChoice.legal => PaperSize.legal,
    PaperChoice.a4 => PaperSize.a4,
  };
}

/// How the page image is finished.
enum ColorMode {
  bw('B&W'),
  gray('Gray'),
  color('Color');

  const ColorMode(this.label);
  final String label;

  static ColorMode byName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => ColorMode.color);
}

/// How far (relative) a page's shape may be from its closest standard size
/// and still be treated as that size. A photo taken at an angle can stretch
/// the measured shape by a few percent, so this is generous; the closest
/// size always wins, so Letter (1.29) and A4 (1.41) never overlap.
const double paperTolerance = 0.06;

/// Closest standard size to a page of [width] x [height] pixels, or null when
/// the page is not close to any of them (a receipt, a card, a book page).
PaperSize? detectPaper(num width, num height) {
  if (width <= 0 || height <= 0) return null;
  final long = width > height ? width : height;
  final short = width > height ? height : width;
  final ratio = long / short;
  PaperSize? best;
  var bestDiff = double.infinity;
  for (final p in PaperSize.values) {
    final diff = (ratio - p.ratio).abs() / p.ratio;
    if (diff < bestDiff) {
      bestDiff = diff;
      best = p;
    }
  }
  return bestDiff <= paperTolerance ? best : null;
}

/// Pixel size for a page of [width] x [height] reshaped to [paper], keeping
/// its orientation and its long side (capped at [maxSide]).
(int, int) snapToPaper(
  int width,
  int height,
  PaperSize paper, {
  int maxSide = 1 << 30,
}) {
  final landscape = width > height;
  var long = width > height ? width : height;
  if (long > maxSide) long = maxSide;
  final short = (long / paper.ratio).round();
  return landscape ? (long, short) : (short, long);
}
