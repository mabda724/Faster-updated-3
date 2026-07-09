# IMMEDIATE NEXT ACTIONS

---

## For You (Manual Steps)

### Step 1: Build & Analyze
Open VS Code terminal in `D:\My_Projects\Faster`:
```bash
flutter analyze --no-pub > analysis.txt
flutter test > test_results.txt
flutter build apk --release
```
Check outputs for errors; fix before proceeding.

### Step 2: Database (Supabase Dashboard)
- Run every SQL file in `supabase/migrations/` (016 through latest) in order.
- Create Storage buckets: `provider-documents`, `booking-photos`.
- Insert `app_settings` values (see FINAL_REPORT).

### Step 3: Replace Keys
Edit `assets/.env`:
- Replace `PAYMOB_PUBLIC_KEY` and `PAYMOB_SECRET_KEY` with production keys from Paymob dashboard.
- Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` point to production project.
- Keep `FLUTTER_ENV=production`.

### Step 4: Release Keystore
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Add passwords to `android/app/build.gradle.kts` signingConfig.

### Step 5: Manual Testing
Follow `verification/TEST_STRATEGY.md`. Document Pass/Fail in `verification/TEST_RESULTS.md`.

---

## Or Activate Harness System

To automate tracking and execution:

1. Open new AI agent (Claude Desktop, ChatGPT, etc.)
2. Paste entire contents of `harness-system/prompts/INITIALIZATION_PROMPT.md`
3. Agent will read `memory/` and start working through `TASK_QUEUE.md`
4. It will enforce quality gates, log decisions, and update state automatically.

---

**Done. Ready to proceed.**
