import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_document.dart';
import '../services/document_store.dart';
import '../services/onedrive_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/settings.dart';

/// Holds the app's services and the shared export actions.
class AppServices {
  AppServices({
    required this.store,
    required this.oneDrive,
    required this.settings,
    this.scanner = const ScannerService(),
    this.pdf = const PdfService(),
  });

  final DocumentStore store;
  final OneDriveService oneDrive;
  final AppSettings settings;
  final ScannerService scanner;
  final PdfService pdf;

  /// Waits (up to [timeout]) for background OCR so exported PDFs are
  /// searchable. Export still proceeds if OCR is slow.
  Future<void> waitForText(ScanDocument doc,
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (doc.ocrComplete) return;
    final done = Completer<void>();
    void check() {
      if ((doc.ocrComplete || !store.isReadingText(doc.id)) &&
          !done.isCompleted) {
        done.complete();
      }
    }

    store.addListener(check);
    check();
    try {
      await done.future.timeout(timeout, onTimeout: () {});
    } finally {
      store.removeListener(check);
    }
  }

  Future<void> sharePdf(BuildContext context, ScanDocument doc) async {
    final box = context.findRenderObject() as RenderBox?;
    await waitForText(doc);
    final file = await pdf.buildPdf(store, doc);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      title: doc.name,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  /// Opens the system "Save to" dialog (Files on iOS, storage picker on
  /// Android) so the PDF lands wherever the user chooses on the device.
  Future<bool> savePdfToDevice(ScanDocument doc) async {
    await waitForText(doc);
    final file = await pdf.buildPdf(store, doc);
    final uri = await FilePicker.saveFile(
      fileName: '${safeFileName(doc.name)}.pdf',
      bytes: await file.readAsBytes(),
      mimeType: 'application/pdf',
      dialogTitle: 'Save PDF',
    );
    return uri != null;
  }

  Future<String> uploadToOneDrive(ScanDocument doc) async {
    if (!oneDrive.isSignedIn) await oneDrive.signIn();
    await waitForText(doc);
    final file = await pdf.buildPdf(store, doc);
    final url = await oneDrive.upload(file, '${safeFileName(doc.name)}.pdf');
    await store.setOneDriveUrl(doc, url);
    return url;
  }
}

class Services extends InheritedWidget {
  const Services({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Services>()!.services;

  @override
  bool updateShouldNotify(Services oldWidget) =>
      services != oldWidget.services;
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? scheme.error : null,
    ));
}
