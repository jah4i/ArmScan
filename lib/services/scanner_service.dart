import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../scanner/page_processor.dart';
import '../scanner/scanner_screen.dart';

/// Entry points for getting pages into ArmScan.
class ScannerService {
  const ScannerService();

  /// Opens the live scanner. Returns page image paths in order, or an empty
  /// list if the user cancelled.
  Future<List<String>> scan(BuildContext context) async {
    final pages = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ScannerScreen(),
      ),
    );
    return pages ?? const [];
  }

  /// Imports photos of documents; each is auto-cropped and straightened.
  Future<List<String>> importFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return const [];
    final dir = await getTemporaryDirectory();
    final out = <String>[];
    for (final photo in picked) {
      final path = '${dir.path}/page_${const Uuid().v4()}.jpg';
      await PageProcessor.process(photo.path, path);
      out.add(path);
    }
    return out;
  }
}
