import 'dart:ui';

import 'package:armscan/models/scan_document.dart';
import 'package:armscan/scanner/paper.dart';
import 'package:armscan/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScanDocument sample() => ScanDocument(
    id: 'abc',
    name: 'Invoice March',
    createdAt: DateTime(2026, 11, 25, 9, 5),
    updatedAt: DateTime(2026, 11, 25, 9, 6),
    pages: [
      ScanPage(
        fileName: 'p1.jpg',
        width: 1240,
        height: 1754,
        text: 'Total due 42.00',
        lines: [
          const OcrLine('Total due 42.00', Rect.fromLTWH(10, 20, 300, 24)),
        ],
      ),
      ScanPage(fileName: 'p2.jpg', width: 1240, height: 1754),
    ],
    oneDriveUrl: 'https://example.com/x',
  );

  test('document survives a JSON round trip', () {
    final doc = ScanDocument.fromJson(sample().toJson());
    expect(doc.name, 'Invoice March');
    expect(doc.pages, hasLength(2));
    expect(
      doc.pages.first.lines.single.box,
      const Rect.fromLTWH(10, 20, 300, 24),
    );
    expect(doc.pages.last.hasOcr, isFalse);
    expect(doc.ocrComplete, isFalse);
    expect(doc.oneDriveUrl, 'https://example.com/x');
  });

  test('search matches name and recognised text, case-insensitive', () {
    final doc = sample();
    expect(doc.matches('invoice'), isTrue);
    expect(doc.matches('TOTAL DUE'), isTrue);
    expect(doc.matches('receipt'), isFalse);
    expect(doc.matches('  '), isTrue);
  });

  test('default name and safe file names', () {
    expect(
      defaultDocumentName(DateTime(2026, 1, 2, 3, 4)),
      'Scan 2026-01-02 03.04',
    );
    expect(safeFileName('a/b:c*d?  e'), 'a-b-c-d- e');
    expect(safeFileName('  '), 'Scan');
  });

  test('PDF text layer replaces characters outside Latin-1', () {
    expect(latin1Safe('Café “quoted” – 5€'), 'Café "quoted" - 5?');
  });

  test('page colour mode, paper size and original survive JSON', () {
    final page = ScanPage.fromJson(
      ScanPage(
        fileName: 'a.jpg',
        width: 1700,
        height: 2200,
        original: 'a.orig.jpg',
        mode: ColorMode.bw,
        paper: PaperSize.letter,
      ).toJson(),
    );
    expect(page.original, 'a.orig.jpg');
    expect(page.mode, ColorMode.bw);
    expect(page.paper, PaperSize.letter);
  });

  test('pages saved before v0.3 still load', () {
    final page = ScanPage.fromJson({'file': 'p.jpg', 'w': 10, 'h': 20});
    expect(page.original, isNull);
    expect(page.mode, ColorMode.color);
    expect(page.paper, isNull);
  });

  test('PDF page uses the paper size, or Letter width otherwise', () {
    expect(pdfPageSize(PaperSize.legal, 1700, 2800), (612, 1008));
    expect(pdfPageSize(PaperSize.a4, 2800, 1980), (841.89, 595.28));
    expect(pdfPageSize(null, 1000, 2000), (612, 1224));
  });
}
