import 'dart:io' show Platform;

/// Microsoft OneDrive settings.
///
/// See docs/ONEDRIVE_SETUP.md. While a platform is missing its values, the
/// app shows OneDrive as "Not set up" and everything else works normally.
abstract final class OneDriveConfig {
  /// "Application (client) ID" of the ArmScan Entra app registration.
  /// A public client ID, not a secret. Override with --dart-define.
  static const clientId = String.fromEnvironment(
    'ARMSCAN_MS_CLIENT_ID',
    defaultValue: 'cadbdd9e-b545-4642-9bb9-1008d77dbd07',
  );

  /// Android redirect URI from Azure:
  /// `msauth://com.armscan.armscan/BASE64_SIGNATURE_HASH`
  static const androidRedirectUri = String.fromEnvironment(
    'ARMSCAN_MS_ANDROID_REDIRECT',
    defaultValue: 'msauth://com.armscan.armscan/g%2BzM9Zq6n3BRC10bbVes7QVBx5k%3D',
  );

  /// "common" lets both personal Microsoft accounts and work/school
  /// accounts sign in.
  static const authority = 'https://login.microsoftonline.com/common';

  /// Least privilege for saving into the user's own OneDrive.
  static const scopes = <String>[
    'https://graph.microsoft.com/Files.ReadWrite',
    'https://graph.microsoft.com/User.Read',
  ];

  /// Folder created in the root of the user's OneDrive.
  static const folderName = 'ArmScan';

  /// Android also needs the signature-hash redirect URI (not set yet).
  static bool get isConfigured =>
      clientId.isNotEmpty &&
      (!Platform.isAndroid || androidRedirectUri.isNotEmpty);
}
