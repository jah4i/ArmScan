# Releasing ArmScan to Intune (private Managed Google Play app)

Test builds (the `android-latest` release) use the shared development key and
are for sideloading only. Production builds are signed with a private
**upload key** kept in GitHub secrets and published through Managed Google
Play, which Intune then deploys.

## 1. Release key (one time)

The upload key is a Java keystore. Its four values live in the repository's
GitHub secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
| --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | the `.jks` file, base64-encoded |
| `ANDROID_UPLOAD_STORE_PASSWORD` | keystore password |
| `ANDROID_UPLOAD_KEY_ALIAS` | key alias (`armscan-upload`) |
| `ANDROID_UPLOAD_KEY_PASSWORD` | key password |

Keep an offline backup of the `.jks` file and its passwords (for example in
a password manager). Every update to the app must be signed with the same
upload key.

## 2. Build the release

1. Set `version:` in `pubspec.yaml` (and `appVersion` in
   `lib/screens/settings_screen.dart`). The number after `+` must go up for
   every upload, e.g. `1.0.0+10`, then `1.0.1+11`.
2. GitHub > Actions > **Android release (Managed Google Play)** > Run workflow.
3. When it finishes, open the **draft** release it created (visible only to
   repository collaborators) and download `ArmScan-<version>.aab` (and `.apk`).
   The run summary shows the signature hash built into the app.

## 3. Publish in Intune

Prerequisite: the Intune tenant is connected to Managed Google Play
(Intune admin center > Tenant administration > Connectors and tokens >
Managed Google Play).

1. Intune admin center > **Apps** > **Android** > **+ Add** >
   App type **Managed Google Play app** > **Select**.
2. In the Google Play window, choose **Private apps** (padlock icon on the
   left) > **+**.
3. Title: `ArmScan`. Upload the `.aab` (or the `.apk` if only an APK is
   accepted). Create.
4. Google takes about 10 minutes (sometimes longer) to make a new private app
   available. If it does not appear in Intune, click **Sync** under
   Tenant administration > Connectors and tokens > Managed Google Play.
5. Open **ArmScan** in the Intune app list > **Properties** > **Assignments**:
   assign it as **Required** or **Available for enrolled devices** to the
   right groups.

Updates: bump the version, run the workflow again, then in the same private
apps page open ArmScan > **Edit** > upload the new file. Devices update from
Google Play automatically.

## 4. Microsoft sign-in (OneDrive)

Microsoft sign-in only works when the app's **signature hash** is registered
in Azure (App registrations > ArmScan > Authentication > Android platform,
package `com.armscan.armscan`).

Google Play may re-sign apps with its own app signing key, which changes the
hash. To check:

1. Install ArmScan from Managed Google Play on a work device.
2. Open Settings > About in ArmScan. It shows the **Signature hash** of the
   installed copy (tap the copy button).
3. Add that hash as an Android redirect in Azure (if it is not there yet).
4. If it differs from the hash in the release run summary, run the release
   workflow again with that value in **signature_hash**, bump the build
   number, and upload the update. OneDrive sign-in works from that version.

Before installing from Play on a phone that has a test build, uninstall the
test build: the two are signed with different keys.
