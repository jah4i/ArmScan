import 'dart:io';

import 'package:armscan/app/services.dart';
import 'package:armscan/main.dart';
import 'package:armscan/services/document_store.dart';
import 'package:armscan/services/onedrive_service.dart';
import 'package:armscan/services/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch shows the empty state and scan button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tmp = Directory.systemTemp.createTempSync('armscan_test');
    final services = AppServices(
      store: DocumentStore(rootOverride: tmp),
      oneDrive: OneDriveService(),
      settings: AppSettings(),
    );
    await tester.runAsync(services.store.load);

    await tester.pumpWidget(ArmScanApp(services: services));
    await tester.pump();

    expect(find.bySemanticsLabel('ArmScan'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.byTooltip('Import from photos'), findsOneWidget);
    tmp.deleteSync(recursive: true);
  });
}
