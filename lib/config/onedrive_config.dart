/// Microsoft OneDrive settings.
///
/// TODO(Sean): fill these in after creating the Azure app registration.
/// See docs/ONEDRIVE_SETUP.md. While [clientId] is empty, the app shows
/// OneDrive as "Not set up" and everything else works normally.
abstract final class OneDriveConfig {
  /// "Application (client) ID" from the Azure portal.
  static const clientId = String.fromEnvironment('ARMSCAN_MS_CLIENT_ID');

  /// Android redirect URI from Azure:
  /// `msauth://com.armscan.armscan/BASE64_SIGNATURE_HASH`
  static const androidRedirectUri =
      String.fromEnvironment('ARMSCAN_MS_ANDROID_REDIRECT');

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

  static bool get isConfigured => clientId.isNotEmpty;
}
