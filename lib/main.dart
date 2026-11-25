import 'package:material_ui/material_ui.dart';

import 'app/services.dart';
import 'app/theme.dart';
import 'screens/home_screen.dart';
import 'services/document_store.dart';
import 'services/onedrive_service.dart';
import 'services/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final services = AppServices(
    store: DocumentStore(),
    oneDrive: OneDriveService(),
    settings: AppSettings(),
  );

  // Load in the background; the home screen shows a skeleton meanwhile so the
  // first frame is never blocked on disk I/O.
  services.store.load();
  services.settings.load();
  services.oneDrive.restore();

  runApp(ArmScanApp(services: services));
}

class ArmScanApp extends StatelessWidget {
  const ArmScanApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Services(
      services: services,
      child: MaterialApp(
        title: 'ArmScan',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
