# Run Instructions — Faster App

## Quick Start

### 1. Ensure Flutter SDK installed
```bash
flutter doctor
```
Should show: Flutter, Android toolchain, Chrome (if web), etc.

### 2. Install dependencies
```bash
cd D:\My_Projects\Faster
flutter pub get
```

### 3. Check assets/.env exists
- File should have at least:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
FLUTTER_ENV=development
```
Test keys currently present (works for dev).

### 4. Run on connected device/emulator
```bash
flutter run
```
Or for specific device:
```bash
flutter run -d <device_id>
```

### 5. Or run on Chrome (web)
```bash
flutter run -d chrome
```

---

## Troubleshooting

### Flutter commands hang on Windows PowerShell
Use **Git Bash** or **VS Code terminal** instead of PowerShell.

### No devices found
- Android: Start emulator from Android Studio or connect physical device with USB debugging
- iOS: Requires macOS + Xcode
- Web: Use `-d chrome`

### Supabase connection errors
- Check internet connection
- Verify Supabase URL/anon key in `.env`
- Ensure Supabase project is running

### Missing permissions
- Android: Check `android/app/src/main/AndroidManifest.xml` for location, camera permissions
- iOS: Check `ios/Runner/Info.plist`

---

## Build for Production

```bash
flutter clean
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Install on device:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

**That's it.** After `flutter run`, the app should launch on your device/emulator.
