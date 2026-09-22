# PillOra — Your Medication, Remembered

PillOra is a simple, offline-first medication reminder app that makes it easy to track your pills and know exactly when you're meant to take them. Built with Flutter, it runs fully on-device — no accounts, no login, no data uploads.

| | | | |
|---|---|---|---|
| ![Screenshot 1](ex_images/image.png) | ![Screenshot 2](ex_images/image1.png) | ![Screenshot 3](ex_images/image2.png) | ![Screenshot 4](ex_images/image3.png) |

## Features

### Never miss a dose

- Add any medication with a name, dosage, and one or more daily dose times.
- Get reliable local notifications at each scheduled time — even when the app is closed or your phone is locked.
- Morning, afternoon, evening, or anywhere in between; set your own schedule in seconds.
- Snooze a reminder if you're not ready, or mark a dose as taken in one tap.

### Know what to take, and when

- A smart "Today's Medications" checklist shows what's taken, skipped, missed, and still upcoming at a glance, with a daily progress bar.
- Scan a pill from your camera or gallery, tap the matching medication, and PillOra tells you right away: **Should take** (you missed a dose), **Not yet** (next dose at a specific time), or **Nothing to take**.
- Missed doses are highlighted so you never lose track.

### Understand your medicine

- Built-in offline database of 7,800+ medications with descriptions, side effects, and drug interactions — searchable without an internet connection.
- Meal timing guidance (before/after meals) and dietary restriction warnings such as "No grapefruit" or "No dairy."

### Stay on track

- Daily streaks, 7-day and 30-day adherence percentages, and a 14-day calendar history show how consistently you're taking your medications.
- Everything is stored on your device — no accounts, no login, no data uploads.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `pubspec.yaml` for the required Dart SDK version)

### Installation

```sh
git clone <repo-url>
cd pill_app
flutter pub get
flutter run
```

### Build a release APK

```sh
flutter build apk --release
```

The output APK will be written to `build/app/outputs/flutter-apk/app-release.apk`.

## Tech Stack

- **Flutter** — cross-platform UI framework
- **Hive** — local, fast key-value storage (medications and dose history)
- **flutter_local_notifications** — scheduled dose reminders, even when the app is closed
- **google_mlkit_image_labeling** — on-device pill recognition from camera or gallery
- **Provider** — simple, testable state management

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/                    # Medicine and dose-event data models (Hive)
├── screens/
│   ├── add_medicine_screen.dart
│   ├── camera_screen.dart     # Pill scanning / recognition
│   ├── history_screen.dart    # Adherence history & calendar
│   ├── home_screen.dart       # Today's medications checklist
│   └── medicine_info_screen.dart
└── services/
    ├── dose_forms.dart
    ├── medicine_database.dart # Offline medicine reference DB
    ├── notification_service.dart
    └── schedule_service.dart
```

## License

Distributed under the MIT License. See `LICENSE` for more information.
