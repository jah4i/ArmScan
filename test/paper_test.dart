import 'package:armscan/scanner/paper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects Letter, Legal and A4 in either orientation', () {
    expect(detectPaper(850, 1100), PaperSize.letter);
    expect(detectPaper(1100, 850), PaperSize.letter);
    expect(detectPaper(850, 1400), PaperSize.legal);
    expect(detectPaper(2480, 3508), PaperSize.a4);
    expect(detectPaper(3508, 2480), PaperSize.a4);
  });

  test('tolerates a photo taken at a slight angle', () {
    expect(detectPaper(850, 1135), PaperSize.letter); // +3%
    expect(detectPaper(850, 1340), PaperSize.legal); // -4.3%
  });

  test('leaves odd shapes alone', () {
    expect(detectPaper(800, 2400), isNull); // receipt
    expect(detectPaper(1000, 1000), isNull); // square
    expect(detectPaper(1000, 1200), isNull); // photo print, 5:6
    expect(detectPaper(0, 100), isNull);
  });

  test('snaps to the exact ratio and keeps orientation', () {
    expect(snapToPaper(850, 1130, PaperSize.letter), (873, 1130));
    expect(snapToPaper(1130, 850, PaperSize.letter), (1130, 873));
    expect(snapToPaper(2000, 4000, PaperSize.legal, maxSide: 3200), (
      1943,
      3200,
    ));
  });

  test('PDF sizes in points', () {
    expect(PaperSize.letter.pdfSize(landscape: false), (612, 792));
    expect(PaperSize.legal.pdfSize(landscape: true), (1008, 612));
  });
}
