import 'dart:ui';

import 'package:armscan/models/scan_document.dart';
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
            lines: [const OcrLine('Total due 42.00', Rect.fromLTWH(10, 20, 300, 24))],
          ),
          ScanPage(fileName: 'p2.jpg', width: 1240, height: 1754),
        ],
        oneDriveUrl: 'https://example.com/x',
      );

  test('document survives a JSON round trip', () {
    final doc = ScanDocument.fromJson(sample().toJson());
    expect(doc.name, 'Invoice March');
    expect(doc.pages, hasLength(2));
    expect(doc.pages.first.lines.single.box, const Rect.fromLTWH(10, 20, 300, 24));
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
    expect(defaultDocumentName(DateTime(2026, 1, 2, 3, 4)), 'Scan 2026-01-02 03.04');
    expect(safeFileName('a/b:c*d?  e'), 'a-b-c-d- e');
    expect(safeFileName('  '), 'Scan');
  });

  test('PDF text layer replaces characters outside Latin-1', () {
    expect(latin1Safe('Café “quoted” – 5€'), 'Café "quoted" - 5?');
  });
}
