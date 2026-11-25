import 'dart:io';

import 'page_processor.dart';
import 'paper.dart';

/// A page that has been captured but not saved yet.
///
/// [original] is the cropped, straightened colour photo. [rendered] is what
/// the page looks like with the current colour mode and paper size; it is
/// rebuilt from [original] whenever either changes, so switching from B&W
/// back to Color loses nothing.
class CapturedPage {
  CapturedPage({
    required this.original,
    required this.rendered,
    required this.width,
    required this.height,
    required this.mode,
    this.paper,
    this.cropped = true,
  });

  final String original;
  String rendered;
  int width;
  int height;
  ColorMode mode;

  /// Standard size the page was snapped to, or null when left as captured.
  PaperSize? paper;

  /// Whether page edges were found. Uncropped photos are not snapped to a
  /// paper size automatically.
  final bool cropped;

  /// Deletes both image files (used when a page is discarded).
  void deleteFiles() {
    for (final p in {original, rendered}) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }
}

int _renderCounter = 0;

/// A fresh file name next to [original] for a rendered version. A new name
/// each time means image caches never show a stale page.
String _renderPath(String original) {
  final base = original.endsWith('.jpg')
      ? original.substring(0, original.length - 4)
      : original;
  _renderCounter++;
  return '${base}_r${DateTime.now().microsecondsSinceEpoch}_$_renderCounter.jpg';
}

/// Renders a freshly cropped page with the session's settings.
Future<CapturedPage> finishPage(
  String original, {
  required ColorMode mode,
  required PaperChoice paper,
  bool cropped = true,
}) async {
  final r = await PageProcessor.render(
    original,
    _renderPath(original),
    mode: mode,
    paper: paper,
    cropped: cropped,
  );
  return CapturedPage(
    original: original,
    rendered: r.path,
    width: r.width,
    height: r.height,
    mode: mode,
    paper: r.paper,
    cropped: cropped,
  );
}

/// Renders [page] again with new settings without changing it. The caller
/// applies the result with [CapturedPage.apply], or deletes the file if the
/// result is no longer wanted.
Future<RenderedPage> renderAgain(
  CapturedPage page,
  ColorMode mode,
  PaperChoice paper,
) {
  return PageProcessor.render(
    page.original,
    _renderPath(page.original),
    mode: mode,
    paper: paper,
    cropped: page.cropped,
  );
}

extension ApplyRender on CapturedPage {
  /// Swaps in a new rendering and deletes the previous one.
  void apply(RenderedPage r, ColorMode newMode) {
    final old = rendered;
    rendered = r.path;
    width = r.width;
    height = r.height;
    paper = r.paper;
    mode = newMode;
    if (old != original && old != r.path) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
  }
}

/// Pages and settings shared by the scanner and the review screen while a
/// scan is in progress.
class ScanSession {
  ScanSession({this.mode = ColorMode.bw, this.paper = PaperChoice.auto});

  final List<CapturedPage> pages = [];
  ColorMode mode;
  PaperChoice paper;

  void discardAll() {
    for (final p in pages) {
      p.deleteFiles();
    }
    pages.clear();
  }
}
