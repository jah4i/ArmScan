// Renders marketing-quality screenshots of the main screens.
// Run: flutter test test/screenshots --update-goldens --tags screenshots
@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:armscan/app/services.dart';
import 'package:armscan/main.dart';
import 'package:armscan/models/scan_document.dart';
import 'package:armscan/scanner/captured_page.dart';
import 'package:armscan/scanner/paper.dart';
import 'package:armscan/scanner/review_screen.dart';
import 'package:armscan/screens/document_screen.dart';
import 'package:armscan/services/document_store.dart';
import 'package:armscan/services/onedrive_service.dart';
import 'package:armscan/services/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixtures = 'test/screenshots/fixtures';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT'] ?? '../flutter-sdk'}'
      '/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      File('$dir/Roboto-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('$dir/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)),
    );
  await icons.load();
}

void _writeDoc(
  Directory root,
  String id,
  String name,
  DateTime at,
  List<(String, String)> pages, {
  String? oneDrive,
}) {
  final dir = Directory('${root.path}/documents/$id')
    ..createSync(recursive: true);
  final doc = ScanDocument(
    id: id,
    name: name,
    createdAt: at,
    updatedAt: at,
    oneDriveUrl: oneDrive,
    pages: [
      for (final (file, text) in pages)
        ScanPage(fileName: file, width: 1240, height: 1754, text: text),
    ],
  );
  for (final (file, _) in pages) {
    File('$_fixtures/$file').copySync('${dir.path}/$file');
  }
  File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(doc.toJson()));
}

Future<AppServices> _services(WidgetTester tester, {bool empty = false}) async {
  SharedPreferences.setMockInitialValues({});
  final tmp = Directory.systemTemp.createTempSync('armscan_shots');
  if (!empty) {
    _writeDoc(
      tmp,
      'a',
      'Invoice 2041 Northwind',
      DateTime(2026, 11, 25, 10, 12),
      [('invoice.jpg', 'INVOICE #2041 Total due 1,526.70')],
      oneDrive: 'https://1drv.ms/x',
    );
    _writeDoc(tmp, 'b', 'Lease agreement', DateTime(2026, 11, 24, 16, 40), [
      ('lease1.jpg', 'Lease Agreement'),
      ('lease2.jpg', 'Schedule A'),
    ]);
    _writeDoc(
      tmp,
      'c',
      'Harbor Hardware receipt',
      DateTime(2026, 11, 22, 9, 5),
      [('receipt.jpg', 'RECEIPT Harbor Hardware')],
    );
  }
  final s = AppServices(
    store: DocumentStore(rootOverride: tmp),
    oneDrive: OneDriveService(),
    settings: AppSettings(),
  );
  await tester.runAsync(s.store.load);
  return s;
}

Future<void> _settle(WidgetTester tester) async {
  // Page thumbnails may render blank here: Image.file decoding does not
  // complete reliably inside widget tests. Layout and styling are accurate.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('home $mode', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      final s = await _services(tester);
      await tester.pumpWidget(ArmScanApp(services: s));
      await _settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$mode.png'),
      );
    });

    testWidgets('document $mode', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      final s = await _services(tester);
      await tester.pumpWidget(ArmScanApp(services: s));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const DocumentScreen(documentId: 'b'),
        ),
      );
      await tester.pumpAndSettle();
      await _settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/document_$mode.png'),
      );
    });
  }

  testWidgets('review light', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    final s = await _services(tester);
    final tmp = Directory.systemTemp.createTempSync('armscan_review');
    final session = ScanSession();
    for (final (f, paper) in [
      ('lease1.jpg', PaperSize.letter),
      ('lease2.jpg', PaperSize.letter),
      ('invoice.jpg', PaperSize.legal),
      ('receipt.jpg', null),
    ]) {
      final path = File('$_fixtures/$f').copySync('${tmp.path}/$f').path;
      session.pages.add(
        CapturedPage(
          original: path,
          rendered: path,
          width: 1240,
          height: 1754,
          mode: ColorMode.bw,
          paper: paper,
        ),
      );
    }
    await tester.pumpWidget(ArmScanApp(services: s));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(builder: (_) => ReviewScreen(session: session)),
    );
    await tester.pumpAndSettle();
    await _settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/review_light.png'),
    );
  });

  testWidgets('empty light', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    final s = await _services(tester, empty: true);
    await tester.pumpWidget(ArmScanApp(services: s));
    await _settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/empty_light.png'),
    );
  });
}
