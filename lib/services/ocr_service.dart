import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/scan_document.dart';

class OcrResult {
  const OcrResult(this.text, this.lines);
  final String text;
  final List<OcrLine> lines;
}

/// On-device text recognition (Google ML Kit on both iOS and Android).
///
/// Runs fully offline; no page image leaves the phone. Latin script only in
/// v1. Other scripts (Chinese, Devanagari, Japanese, Korean) are available as
/// separate ML Kit models if needed.
class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _r =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognize(String imagePath) async {
    final result = await _r.processImage(InputImage.fromFilePath(imagePath));
    final lines = <OcrLine>[
      for (final block in result.blocks)
        for (final line in block.lines) OcrLine(line.text, line.boundingBox),
    ];
    return OcrResult(result.text, lines);
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
