# Known Issues - Faster App

## CRITICAL - Blocks Release

### 1. Placeholder Credentials in .env
**File**: `assets/.env`
**Impact**: App cannot connect to backend or payment gateway
**Description**: Supabase URL/key and Paymob keys are placeholder values
**Fix**: Replace with real production credentials

### 2. No Signing Keystore for Release Builds
**File**: `android/app/build.gradle.kts`
**Impact**: Cannot build signed APK for Play Store
**Description**: Using debug signing config for release builds
**Fix**: Create keystore and add signing config:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 3. Firebase Commented Out in build.gradle.kts
**File**: `android/app/build.gradle.kts`
**Impact**: Firebase/FCM will not work on Android
**Description**: `id("com.google.gms.google-services")` is commented out
**Fix**: Uncomment the line and add `google-services.json`

### 4. Missing GoogleService-Info.plist for iOS
**File**: `ios/Runner/`
**Impact**: Firebase will not work on iOS
**Description**: `GoogleService-Info.plist` not added to project
**Fix**: Download from Firebase console and add to `ios/Runner/`

### 5. Duplicate Migration File Numbers
**Files**: `supabase/migrations/`
**Impact**: Migration ordering may cause errors
**Description**: Files 012, 013, 020, 021, 022, 023 have duplicates
**Fix**: Rename files to ensure unique sequential numbering

## MEDIUM - Should Fix Before Release

### 6. TODO Items in provider_products_screen.dart
**File**: `lib/features/provider/presentation/provider_products_screen.dart`
**Impact**: Incomplete navigation flows
**Description**: 5 TODO comments indicating unfinished work
**Fix**: Complete navigation implementations

### 7. Branch Name Mismatch
**Branch**: `onesignal-integration`
**Impact**: Confusing for team members
**Description**: Branch named after OneSignal but OneSignal has been removed
**Fix**: Rename branch to `main` or `develop`

### 8. No Tests Committed
**Impact**: No automated quality assurance
**Description**: Unit and integration tests not written
**Fix**: Write tests for core services and critical flows

## LOW - Nice to Fix

### 9. .devin/ Directory Cleanup
**Directory**: `.devin/`
**Impact**: Old dev agent artifacts cluttering repo
**Description**: Contains leftover files from development session
**Fix**: Delete directory or add to `.gitignore`

### 10. Unused Assets or Dependencies
**Impact**: Slightly larger app size
**Description**: Possible unused packages or assets
**Fix**: Run `flutter pub deps` and audit dependencies

## Resolved Issues

- [x] OneSignal → Firebase FCM migration (completed 2026-06-16)
- [x] UI overlap in my_bookings_screen (completed)
- [x] Location precision improved (completed)
- [x] Chat auto-deletion implemented (completed)
- [x] Provider category matching enforced (completed)
