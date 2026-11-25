import 'dart:ui' show Rect;

/// One recognised line of text on a page, in image pixel coordinates.
class OcrLine {
  const OcrLine(this.text, this.box);

  final String text;
  final Rect box;

  Map<String, dynamic> toJson() => {
        't': text,
        'b': [box.left, box.top, box.width, box.height],
      };

  factory OcrLine.fromJson(Map<String, dynamic> j) {
    final b = (j['b'] as List).cast<num>();
    return OcrLine(
      j['t'] as String,
      Rect.fromLTWH(
          b[0].toDouble(), b[1].toDouble(), b[2].toDouble(), b[3].toDouble()),
    );
  }
}

/// One scanned page. The image file lives in the document's folder.
class ScanPage {
  ScanPage({
    required this.fileName,
    required this.width,
    required this.height,
    this.text,
    this.lines = const [],
  });

  final String fileName;
  final int width;
  final int height;

  /// Full recognised text, null until OCR has run.
  String? text;

  /// Line boxes used to build a searchable PDF text layer.
  List<OcrLine> lines;

  bool get hasOcr => text != null;

  Map<String, dynamic> toJson() => {
        'file': fileName,
        'w': width,
        'h': height,
        if (text != null) 'text': text,
        if (lines.isNotEmpty) 'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory ScanPage.fromJson(Map<String, dynamic> j) => ScanPage(
        fileName: j['file'] as String,
        width: j['w'] as int,
        height: j['h'] as int,
        text: j['text'] as String?,
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => OcrLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A multipage scanned document.
class ScanDocument {
  ScanDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.oneDriveUrl,
  });

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ScanPage> pages;

  /// Web URL of the last OneDrive upload, if any.
  String? oneDriveUrl;

  bool get ocrComplete => pages.every((p) => p.hasOcr);

  String get fullText => pages
      .map((p) => p.text ?? '')
      .where((t) => t.trim().isNotEmpty)
      .join('\n\n');

  /// Matches on name or recognised text (case-insensitive).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    return pages.any((p) => (p.text ?? '').toLowerCase().contains(q));
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pages': pages.map((p) => p.toJson()).toList(),
        if (oneDriveUrl != null) 'oneDriveUrl': oneDriveUrl,
      };

  factory ScanDocument.fromJson(Map<String, dynamic> j) => ScanDocument(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        pages: (j['pages'] as List)
            .map((e) => ScanPage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        oneDriveUrl: j['oneDriveUrl'] as String?,
      );
}

/// Default name, e.g. "Scan 2026-11-25 14.51". Uses only characters that are
/// safe in file names on iOS, Android and OneDrive.
String defaultDocumentName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Scan ${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}.${two(t.minute)}';
}

/// Strips characters OneDrive and common file systems reject.
String safeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|#%]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'Scan' : cleaned;
}
