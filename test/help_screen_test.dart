import 'package:armscan/app/theme.dart';
import 'package:armscan/screens/help_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Help covers the main features', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const HelpScreen(),
    ));
    for (final title in [
      'Scan a document',
      'Review before saving',
      'Black and white, Gray, or Color',
      'Page sizes',
      'Text and search',
      'Share and save as PDF',
      'OneDrive',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 300);
      expect(find.text(title), findsOneWidget);
    }
  });
}
