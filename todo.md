# Task Tracking - Faster App

## CRITICAL - Must Complete Before Release

- [ ] Set real Supabase credentials in `assets/.env` (currently placeholder values)
- [ ] Set real Paymob credentials in `assets/.env` (currently placeholder values)
- [ ] Create signing keystore for release builds
  ```bash
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] Add signing config to `android/app/build.gradle.kts`
- [ ] Uncomment Firebase in `android/app/build.gradle.kts` (`id("com.google.gms.google-services")`)
- [ ] Add `google-services.json` to `android/app/` for Firebase
- [ ] Add `GoogleService-Info.plist` to `ios/Runner/` for iOS Firebase
- [ ] Run all 58 SQL migrations in Supabase Dashboard in order

## HIGH - Important for Full Functionality

- [x] Fix 5 TODO items in `lib/features/provider/presentation/provider_products_screen.dart` - Done
- [x] Rename 9 duplicate migration files (012,013,019,020,021,022,023 → 060-068) - Done
- [ ] Create Supabase Storage buckets: `provider-documents`, `booking-photos`
- [ ] Set `app_settings` in Supabase (cancel windows, WhatsApp number, referral values)
- [ ] Create Supabase RLS policies for new tables if missing
- [ ] Test Paymob payment flow with real API keys

## MEDIUM - Quality Improvements

- [ ] Rename branch from `onesignal-integration` to `main` (OneSignal removed, name misleading)
- [ ] Add CI/CD pipeline (GitHub Actions or Codemagic)
- [ ] Write unit tests for core services (auth, booking, payment)
- [ ] Write integration tests for critical user flows
- [ ] Add `GoogleService-Info.plist` signing to iOS project
- [ ] Set up Firebase Analytics events tracking

## LOW - Cleanup

- [ ] Clean up `.devin/` directory (old dev agent artifacts)
- [ ] Remove any unused assets or dependencies
- [ ] Update README.md with setup instructions

## DONE

- [x] Commit all uncommitted changes (103 files) - Commit `5b49a93`
- [x] Commit TODO fixes + migration renames - Commit `a2b48ca`
- [x] Update `.gitignore` for build artifacts (`*.txt`)
- [x] Auth system - phone + email required during registration
- [x] Home screen carousel replacing flash deal section
- [x] Bottom nav gradient style applied
- [x] Fix 5 TODO items (provider products CRUD, map navigation)
- [x] Fix duplicate migration file numbers (9 files renamed)
- [x] Firebase FCM integration (replaced OneSignal)
- [x] Provider order cards layout enhancement
- [x] Price offer system (provider → client negotiation)
- [x] Automatic alternative provider search on negotiation failure
- [x] 500 EGP minimum withdrawal limit
- [x] Commission settlement tracking
- [x] Chat auto-deletion after 30 days
- [x] Client report system
- [x] Real-time location tracking (provider_locations table)
- [x] Provider category matching enforcement
