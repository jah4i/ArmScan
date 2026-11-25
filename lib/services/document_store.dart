import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_document.dart';
import '../scanner/captured_page.dart';
import 'ocr_service.dart';

/// Local-first storage for scanned documents.
///
/// Layout on disk (inside the app's private documents directory):
///   `documents/{id}/meta.json`
///   `documents/{id}/{page}.jpg`        finished page (B&W, Gray or Color)
///   `documents/{id}/{page}.orig.jpg`   cropped colour original
///
/// Everything is saved on the device first. Exports (PDF, OneDrive) are
/// produced from this store on demand.
class DocumentStore extends ChangeNotifier {
  DocumentStore({OcrService? ocr, Directory? rootOverride})
    : _ocr = ocr ?? OcrService(),
      _rootOverride = rootOverride; // ignore: prefer_initializing_formals

  final OcrService _ocr;
  final Directory? _rootOverride;
  final _uuid = const Uuid();

  late Directory _root;
  final List<ScanDocument> _docs = [];
  final Set<String> _ocrInProgress = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Newest first.
  List<ScanDocument> get documents => List.unmodifiable(_docs);

  bool isReadingText(String id) => _ocrInProgress.contains(id);

  ScanDocument? byId(String id) {
    for (final d in _docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  Directory dirFor(ScanDocument doc) => Directory('${_root.path}/${doc.id}');

  File pageFile(ScanDocument doc, ScanPage page) =>
      File('${_root.path}/${doc.id}/${page.fileName}');

  Future<void> load() async {
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    _root = Directory('${base.path}/documents');
    await _root.create(recursive: true);

    _docs.clear();
    await for (final entity in _root.list()) {
      if (entity is! Directory) continue;
      final meta = File('${entity.path}/meta.json');
      if (!await meta.exists()) continue;
      try {
        final json = jsonDecode(await meta.readAsString());
        _docs.add(ScanDocument.fromJson(Map<String, dynamic>.from(json)));
      } catch (e) {
        debugPrint('Skipping unreadable document ${entity.path}: $e');
      }
    }
    _sort();
    _loaded = true;
    notifyListeners();

    // Finish any OCR that was interrupted last time.
    for (final d in _docs.where((d) => !d.ocrComplete)) {
      _runOcr(d);
    }
  }

  /// Creates a document from reviewed scanner output. Images are moved into
  /// the store; OCR starts in the background so the UI is never blocked.
  Future<ScanDocument> createFromPages(List<CapturedPage> captured) async {
    final now = DateTime.now();
    final doc = ScanDocument(
      id: _uuid.v4(),
      name: defaultDocumentName(now),
      createdAt: now,
      updatedAt: now,
      pages: [],
    );
    await dirFor(doc).create(recursive: true);
    doc.pages = await _importPages(doc, captured);
    await _save(doc);
    _docs.insert(0, doc);
    notifyListeners();
    _runOcr(doc);
    return doc;
  }

  Future<void> addPages(ScanDocument doc, List<CapturedPage> captured) async {
    doc.pages = [...doc.pages, ...await _importPages(doc, captured)];
    await _touch(doc);
    _runOcr(doc);
  }

  Future<void> rename(ScanDocument doc, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    doc.name = trimmed;
    await _touch(doc);
  }

  Future<void> reorderPage(ScanDocument doc, int oldIndex, int newIndex) async {
    final pages = [...doc.pages];
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    doc.pages = pages;
    await _touch(doc);
  }

  Future<void> deletePage(ScanDocument doc, ScanPage page) async {
    doc.pages = doc.pages.where((p) => p != page).toList();
    for (final name in [page.fileName, ?page.original]) {
      final f = File('${dirFor(doc).path}/$name');
      if (await f.exists()) await f.delete();
    }
    if (doc.pages.isEmpty) {
      await delete(doc);
    } else {
      await _touch(doc);
    }
  }

  Future<void> setOneDriveUrl(ScanDocument doc, String? url) async {
    doc.oneDriveUrl = url;
    await _save(doc);
    notifyListeners();
  }

  Future<void> delete(ScanDocument doc) async {
    _docs.removeWhere((d) => d.id == doc.id);
    notifyListeners();
    final dir = dirFor(doc);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---------------------------------------------------------------------------

  Future<List<ScanPage>> _importPages(
    ScanDocument doc,
    List<CapturedPage> captured,
  ) async {
    final pages = <ScanPage>[];
    for (final c in captured) {
      final id = _uuid.v4();
      final name = '$id.jpg';
      final dest = await _moveInto(doc, c.rendered, name);
      String? original;
      if (c.original != c.rendered) {
        original = '$id.orig.jpg';
        await _moveInto(doc, c.original, original);
      }
      final size = await _imageSize(dest);
      pages.add(
        ScanPage(
          fileName: name,
          width: size.$1,
          height: size.$2,
          original: original,
          mode: c.mode,
          paper: c.paper,
        ),
      );
    }
    return pages;
  }

  Future<File> _moveInto(ScanDocument doc, String src, String name) async {
    final dest = File('${dirFor(doc).path}/$name');
    final source = File(src);
    try {
      await source.rename(dest.path); // fast path: same volume
    } on FileSystemException {
      await source.copy(dest.path);
      await source.delete().catchError((_) => source);
    }
    return dest;
  }

  /// Reads only the image header; does not decode pixels.
  Future<(int, int)> _imageSize(File f) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(f.path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  Future<void> _runOcr(ScanDocument doc) async {
    if (_ocrInProgress.contains(doc.id)) return;
    _ocrInProgress.add(doc.id);
    notifyListeners();
    var failed = false;
    try {
      for (final page in doc.pages.where((p) => !p.hasOcr).toList()) {
        final file = pageFile(doc, page);
        if (!await file.exists()) continue;
        final result = await _ocr.recognize(file.path);
        page.text = result.text;
        page.lines = result.lines;
        if (byId(doc.id) == null) return; // deleted meanwhile
        await _save(doc);
        notifyListeners();
      }
    } catch (e) {
      // Leave the page without text; it is retried on next app launch.
      failed = true;
      debugPrint('OCR failed for ${doc.id}: $e');
    } finally {
      _ocrInProgress.remove(doc.id);
      notifyListeners();
      // Pages may have been added while OCR was running.
      if (!failed && byId(doc.id) != null && !doc.ocrComplete) _runOcr(doc);
    }
  }

  Future<void> _touch(ScanDocument doc) async {
    doc.updatedAt = DateTime.now();
    await _save(doc);
    _sort();
    notifyListeners();
  }

  /// Atomic write: a crash mid-save never leaves a corrupt meta.json.
  Future<void> _save(ScanDocument doc) async {
    final dir = dirFor(doc);
    if (!await dir.exists()) return;
    final tmp = File('${dir.path}/meta.json.tmp');
    await tmp.writeAsString(jsonEncode(doc.toJson()), flush: true);
    await tmp.rename('${dir.path}/meta.json');
  }

  void _sort() => _docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }
}
