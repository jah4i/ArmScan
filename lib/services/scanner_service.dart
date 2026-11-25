import 'package:cunning_document_scanner/cunning_document_scanner.dart';

/// Opens the platform's native document scanner.
///
/// * iOS: Apple VisionKit (VNDocumentCameraViewController).
/// * Android: Google ML Kit Document Scanner (Play services).
///
/// Both give live edge detection, automatic capture when the page is steady,
/// perspective correction, multipage batches and a manual shutter fallback.
class ScannerService {
  const ScannerService();

  /// Returns image paths in page order, or an empty list if cancelled.
  Future<List<String>> scan({bool fromGallery = false}) async {
    final result = await CunningDocumentScanner.scanDocuments(
      noOfPages: 100,
      scannerSource:
          fromGallery ? ScannerSource.gallery : ScannerSource.camera,
      output: ScanOutput.images,
      // "full" adds ML Kit's crop, filter and stain/finger cleanup screen.
      androidScannerMode: AndroidScannerMode.full,
      iosScannerOptions: IosScannerOptions(
        // JPEG keeps files ~5-10x smaller than PNG and exports much faster.
        imageFormat: IosImageFormat.jpg,
        jpgCompressionQuality: 0.85,
        defaultFilter: IosDocumentFilter.color,
      ),
    );
    return result?.images ?? const [];
  }
}
