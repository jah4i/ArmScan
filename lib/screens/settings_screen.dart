import 'package:material_ui/material_ui.dart';

import '../app/services.dart';
import '../app/theme.dart';
import '../config/onedrive_config.dart';
import 'help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(
              ArmSpacing.md, ArmSpacing.lg, ArmSpacing.md, ArmSpacing.sm),
          child: Text(title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.oneDrive, s.settings]),
        builder: (context, _) {
          final od = s.oneDrive;
          return ListView(
            children: [
              section('Help'),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('How to use ArmScan'),
                subtitle: const Text(
                    'Scanning, page sizes, B&W, PDF, search and OneDrive'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              section('Microsoft OneDrive'),
              if (!od.isConfigured)
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Not set up yet'),
                  subtitle: Text(
                      'This build has no Microsoft app ID. Scans are saved on '
                      'this device and can be shared or saved as PDF.'),
                )
              else if (!od.isSignedIn)
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Sign in to OneDrive'),
                  subtitle: Text(
                      'PDFs are saved to the "${OneDriveConfig.folderName}" folder'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      await od.signIn();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, 'Sign-in failed: $e', error: true);
                      }
                    }
                  },
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(od.accountName ?? 'Signed in'),
                  subtitle: Text(
                      'Saving to OneDrive / ${OneDriveConfig.folderName}'),
                  trailing: TextButton(
                    onPressed: od.signOut,
                    child: const Text('Sign out'),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sync),
                  title: const Text('Upload new scans automatically'),
                  subtitle: const Text('Each new scan is saved as a PDF'),
                  value: s.settings.autoUploadToOneDrive,
                  onChanged: s.settings.setAutoUploadToOneDrive,
                ),
              ],
              section('Privacy'),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Scans stay on your device'),
                subtitle: Text(
                    'Edge detection and text recognition run on the phone. '
                    'Nothing is uploaded unless you choose OneDrive.'),
              ),
              section('About'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('ArmScan'),
                subtitle: Text('Version 0.5.0'),
              ),
            ],
          );
        },
      ),
    );
  }
}
