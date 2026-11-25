import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../scanner/captured_page.dart';
import '../scanner/page_processor.dart';
import '../scanner/review_screen.dart';
import '../scanner/scanner_screen.dart';

/// Entry points for getting pages into ArmScan.
///
/// Every new page starts in black and white with its paper size detected.
/// The user reviews all pages (order, deletions, colour, size) before they
/// are returned.
class ScannerService {
  const ScannerService();

  /// Opens the live scanner, then the review grid. Returns the approved
  /// pages in order, or an empty list if the user cancelled.
  Future<List<CapturedPage>> scan(
    BuildContext context, {
    String saveLabel = 'Save',
  }) async {
    final session = ScanSession();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScannerScreen(session: session, saveLabel: saveLabel),
      ),
    );
    if (saved != true) {
      session.discardAll();
      return const [];
    }
    return List.of(session.pages);
  }

  /// Imports photos of documents; each is auto-cropped, straightened and
  /// cleaned up, then shown in the review grid.
  Future<List<CapturedPage>> importFromGallery(
    BuildContext context, {
    String saveLabel = 'Save',
  }) async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return const [];
    final dir = await getTemporaryDirectory();
    final session = ScanSession();
    for (final photo in picked) {
      final path = '${dir.path}/page_${const Uuid().v4()}.jpg';
      final cropped = await PageProcessor.process(photo.path, path);
      session.pages.add(
        await finishPage(
          path,
          mode: session.mode,
          paper: session.paper,
          cropped: cropped,
        ),
      );
    }
    if (!context.mounted) {
      session.discardAll();
      return const [];
    }
    final action = await Navigator.of(context).push<ReviewAction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReviewScreen(
          session: session,
          canAddMore: false,
          saveLabel: saveLabel,
        ),
      ),
    );
    if (action != ReviewAction.save) {
      session.discardAll();
      return const [];
    }
    return List.of(session.pages);
  }
}
