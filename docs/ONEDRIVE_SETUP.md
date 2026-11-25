# OneDrive setup

**Status (2026-11-25):** app registered; client ID `cadbdd9e-b545-4642-9bb9-1008d77dbd07` is built in.
iOS sign-in is ready once the iOS platform (bundle ID `com.armscan.armscan`) is added in Azure → Authentication.
Android: builds are signed with the shared dev key `android/app/armscan-dev.keystore`, so the
values are fixed and already built in. In Azure → Authentication → Add a platform → Android, enter
package `com.armscan.armscan` and signature hash `g+zM9Zq6n3BRC10bbVes7QVBx5k=`.
A Play Store release will need its own private key and a second Android entry in Azure.

OneDrive sign-in needs a free Microsoft Entra (Azure) app registration that only the
account owner can create. Until then the app shows OneDrive as "Not set up yet" and
everything else works.

1. Go to https://entra.microsoft.com → App registrations → New registration.
   - Name: ArmScan
   - Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
     (lets both work/school and personal OneDrive users sign in). Choose a narrower option if
     ArmScan is only for your organisation.
2. Copy the **Application (client) ID**.
3. Authentication → Add a platform:
   - **iOS/macOS**: bundle ID `com.armscan.armscan` (redirect becomes `msauth.com.armscan.armscan://auth`).
   - **Android**: package `com.armscan.armscan` and the signature hash of your signing key:
     `keytool -exportcert -alias <alias> -keystore <keystore> | openssl sha1 -binary | openssl base64`
     Azure shows the redirect URI `msauth://com.armscan.armscan/<hash>`.
4. API permissions → Microsoft Graph → Delegated: `Files.ReadWrite`, `User.Read` (both need no admin consent).
5. Build with the values (nothing secret is stored in code):
   ```
   flutter run \
     --dart-define=ARMSCAN_MS_ANDROID_REDIRECT=msauth://com.armscan.armscan/<url-encoded hash> \
     -PmsalSignatureHash=<hash>      # or edit android/app/build.gradle.kts
   ```
6. iOS: in Xcode, set your signing Team. Keychain sharing (`com.microsoft.adalcache`) is already in `Runner.entitlements`.

Scans upload as searchable PDFs to **OneDrive / ArmScan /**. Files over 4 MB use a resumable upload session.
