import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/scan_document.dart';
import 'document_store.dart';

/// Builds a searchable PDF: each page is the scanned image with an invisible
/// OCR text layer on top, so the text can be searched, selected and copied in
/// any PDF reader.
class PdfService {
  const PdfService();

  /// Writes the PDF to a temporary file and returns it.
  Future<File> buildPdf(DocumentStore store, ScanDocument doc) async {
    final jobs = <_PageJob>[];
    for (final page in doc.pages) {
      jobs.add(_PageJob(
        bytes: await store.pageFile(doc, page).readAsBytes(),
        width: page.width,
        height: page.height,
        lines: [
          for (final l in page.lines)
            _LineJob(l.text, l.box.left, l.box.top, l.box.width, l.box.height),
        ],
      ));
    }

    // PDF assembly runs on a background isolate to keep the UI at 60/120 fps.
    final bytes = await compute(_buildPdfBytes, _DocJob(doc.name, jobs));

    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${safeFileName(doc.name)}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class _LineJob {
  const _LineJob(this.text, this.x, this.y, this.w, this.h);
  final String text;
  final double x, y, w, h;
}

class _PageJob {
  const _PageJob({
    required this.bytes,
    required this.width,
    required this.height,
    required this.lines,
  });
  final Uint8List bytes;
  final int width, height;
  final List<_LineJob> lines;
}

class _DocJob {
  const _DocJob(this.title, this.pages);
  final String title;
  final List<_PageJob> pages;
}

/// Page width in PDF points (A4 width). Height follows the scan's aspect
/// ratio so nothing is letterboxed or cropped.
const double _pageWidthPt = 595.28;

Future<Uint8List> _buildPdfBytes(_DocJob job) async {
  final pdf = pw.Document(title: job.title, creator: 'ArmScan');

  for (final page in job.pages) {
    final scale = _pageWidthPt / page.width;
    final pageHeight = page.height * scale;
    final image = pw.MemoryImage(page.bytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_pageWidthPt, pageHeight),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.fill)),
            for (final line in page.lines)
              if (line.w > 0 && line.h > 0)
                pw.Positioned(
                  left: line.x * scale,
                  top: line.y * scale,
                  child: pw.SizedBox(
                    width: line.w * scale,
                    height: line.h * scale,
                    child: pw.FittedBox(
                      fit: pw.BoxFit.fill,
                      child: pw.Text(
                        latin1Safe(line.text),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          renderingMode: PdfTextRenderingMode.invisible,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
  return pdf.save();
}

/// The built-in PDF font (Helvetica) only covers Latin-1. Characters outside
/// it are replaced so export never fails on unusual text.
@visibleForTesting
String latin1Safe(String s) {
  const replacements = {
    '‘': "'", '’': "'", '“': '"', '”': '"',
    '–': '-', '—': '-', '…': '...', '•': '*',
  };
  final b = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (rune < 256) {
      b.write(ch);
    } else {
      b.write(replacements[ch] ?? '?');
    }
  }
  return b.toString();
}
