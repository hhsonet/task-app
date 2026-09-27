# LocalTask

Offline-first Flutter task manager by daccadelight.com.

## Implemented

- Create, edit, delete, complete, and search tasks
- Categories, priorities, statuses, notes, due dates, due times, and recurrence fields
- Dashboard with today and completed counts
- Local persistence using `shared_preferences`
- Light/dark themes and reminder preference
- JSON export through the platform share sheet
- Material 3 Android UI

## Run

```bash
flutter pub get
flutter test
flutter run
```

## Release

The Android application ID is `com.daccadelight` and the user-facing app name is `LocalTask`.

Before publishing, create a Play App Signing/upload keystore, configure `android/key.properties` and the release signing block, then build:

```bash
flutter build appbundle --release
```

The generated bundle is placed under `build/app/outputs/bundle/release/`.

## Privacy

Tasks are stored locally on the device. The initial version has no account, analytics, or cloud backend.
