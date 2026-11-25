import 'dart:io';

import 'package:armscan/app/theme.dart';
import 'package:armscan/scanner/captured_page.dart';
import 'package:armscan/scanner/paper.dart';
import 'package:armscan/scanner/review_screen.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory tmp;
  late ScanSession session;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('review');
    session = ScanSession();
    for (var i = 1; i <= 3; i++) {
      final f = File('${tmp.path}/p$i.jpg')..writeAsBytesSync([0]);
      session.pages.add(
        CapturedPage(
          original: f.path,
          rendered: f.path,
          width: 850,
          height: 1100,
          mode: ColorMode.bw,
          paper: PaperSize.letter,
        ),
      );
    }
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ReviewAction?> pump(WidgetTester tester) async {
    ReviewAction? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ReviewAction>(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(session: session),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  String names() => session.pages
      .map((p) => p.original.split('/').last.replaceAll('.jpg', ''))
      .join(',');

  testWidgets('shows every page with B&W and Auto selected', (tester) async {
    await pump(tester);
    expect(find.text('Review 3 pages'), findsOneWidget);
    expect(find.text('Save 3 pages'), findsOneWidget);
    expect(find.text('Letter  ·  B&W'), findsWidgets);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Mode B&W')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Paper size Auto')),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('delete removes a page and Undo puts it back', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Delete page 2'));
    await tester.pumpAndSettle();
    expect(names(), 'p1,p3');
    expect(find.text('Save 2 pages'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(names(), 'p1,p2,p3');
  });

  testWidgets('pages can be moved with accessibility actions', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    // ignore: deprecated_member_use
    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    final node = tester.getSemantics(find.bySemanticsLabel('Page 1').first);
    // The custom action lives on an ancestor of the image.
    SemanticsNode? target = node;
    while (target != null &&
        !target.getSemanticsData().customSemanticsActionIds!.isNotEmpty) {
      target = target.parent;
    }
    expect(target, isNotNull);
    final moveLater = CustomSemanticsAction.getIdentifier(
      const CustomSemanticsAction(label: 'Move later'),
    );
    owner.performAction(target!.id, SemanticsAction.customAction, moveLater);
    await tester.pumpAndSettle();
    expect(names(), 'p2,p1,p3');
    handle.dispose();
  });

  testWidgets('Save and Add more return the choice', (tester) async {
    ReviewAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ReviewAction>(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(session: session),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add more'));
    await tester.pumpAndSettle();
    expect(result, ReviewAction.addMore);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 3 pages'));
    await tester.pumpAndSettle();
    expect(result, ReviewAction.save);
  });
}
