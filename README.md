# ArmScan

Fast, clean document scanner for iOS and Android, built with Flutter on top of the
platforms' native scanning engines.

| Feature | How |
|---|---|
| Auto border detection + auto capture | Apple VisionKit (iOS), Google ML Kit Document Scanner (Android) via `cunning_document_scanner` |
| Multipage scanning | Native batch capture; add / delete / drag-to-reorder pages |
| OCR | Google ML Kit Text Recognition, on device, runs in the background |
| PDF export | Searchable PDF (image + invisible text layer), built off the UI thread |
| Local storage | Every scan is saved in the app; "Save PDF" writes to Files / device storage |
| OneDrive | MSAL sign-in + Microsoft Graph upload to `OneDrive/ArmScan` (needs setup, see `docs/ONEDRIVE_SETUP.md`) |
| Search | Home screen searches names and recognised text |

## Install on Android (no computer needed)

Every push to `main` builds an APK and publishes it as the
[android-latest release](https://github.com/jah4i/ArmScan/releases/tag/android-latest).
Open that page on the phone, download `ArmScan.apk`, open it, allow installs from your
browser when Android asks, and tap Install. New builds install over the old one.

## Run

```
flutter pub get
flutter run            # iOS 15.5+ / Android 7.0 (API 24)+, real device needed for the camera
flutter test           # unit + widget tests
flutter test test/screenshots --update-goldens   # re-render screenshots
```

## Layout

```
lib/
  app/        theme (design tokens), services wiring and export actions
  config/     OneDrive settings (filled via --dart-define)
  models/     ScanDocument / ScanPage / OcrLine
  services/   scanner, OCR, PDF, local store, OneDrive, settings
  screens/    home, document, page viewer, text, settings
  widgets/    document tile, page thumbnail
docs/         UX research, OneDrive setup
```

Design notes: see `docs/UX_RESEARCH.md`.
