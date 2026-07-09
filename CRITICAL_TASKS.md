# IMMEDIATE CRITICAL TASKS
## Pre-Release Execution Order

---

### Task 1: Build & Test Verification
**Owner:** Developer (you)
**Command:** Run in VS Code terminal (not PowerShell):
```bash
cd "D:\My_Projects\Faster"
flutter analyze --no-pub > analysis.txt
flutter test > test_results.txt
flutter build apk --release
```
**Expected outputs:**
- `analysis.txt`: Should contain "No issues found" or list warnings/errors
- `test_results.txt`: Should show "All tests passed" or failures
- APK built at: `build/app/outputs/flutter-apk/app-release.apk`
**Deliverables:** Share contents of `analysis.txt` and `test_results.txt` with agent.

---

### Task 2: Supabase Migrations Application
**Owner:** Developer/Admin
**Action:** Apply all SQL migrations in order to production Supabase.
**Instructions:**
1. Go to Supabase Dashboard → Project → SQL Editor
2. Run each file in `D:\My_Projects\Faster\supabase\migrations\` in numeric order:
   - Start from `001_app_settings_data.sql` up to latest (`068_update_transactions_check_constraint.sql`)
3. Also run: `D:\My_Projects\Faster\supabase\create_referral_tables.sql` if not already included
4. Verify functions exist:
   - `cancel_booking_graduated`
   - `cleanup_expired_chats`
   - `find_matching_requests_for_provider`
   - `provider_offer_price`
   - `client_respond_price_offer`
   - `get_admin_commission_stats` and related reporting functions

**Validation query:**
```sql
SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%graduated%' OR routine_name LIKE '%cleanup%' OR routine_name LIKE '%matching%' OR routine_name LIKE '%offer%';
```
**Deliverable:** Screenshot or list of confirmed functions.

---

### Task 3: Create Storage Buckets
**Owner:** Admin
**Action:** Create two buckets in Supabase Storage:
- `provider-documents` (private, enable RLS)
- `booking-photos` (private or public as needed)
**Steps:**
1. Supabase Dashboard → Storage → New bucket
2. Name: `provider-documents`; Set access: Private; Enable Row Level Security
3. Name: `booking-photos`; Set as needed (likely Private)
4. (Optional) Set up policies: authenticated users can upload to their own folders

**Deliverable:** Confirm bucket names exist via API or Dashboard screenshot.

---

### Task 4: Replace Paymob Test Keys
**Owner:** DevOps
**File:** `D:\My_Projects\Faster\assets\.env`
**Action:** Replace lines 6-9 with production Paymob keys from Paymob dashboard.
**Current (test):**
```
PAYMOB_PUBLIC_KEY=egy_pk_test_...
PAYMOB_SECRET_KEY=egy_sk_test_...
PAYMOB_INTEGRATION_ID_CARD=5646837
PAYMOB_INTEGRATION_ID_WALLET=5645306
```
**Replace with:**
- Production Public Key (starts with `egy_pk_` but not "test")
- Production Secret Key (starts with `egy_sk_` but not "test")
- Same integration IDs work for prod? Verify in Paymob; if different, update.
**Important:** Do not commit `.env` with real keys if repo is public; use Supabase Secrets for production.

**Deliverable:** Confirm `.env` has non-test keys (show last 4 chars only for security).

---

### Task 5: Generate Release Keystore
**Owner:** DevOps
**Command:**
```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
**Options:**
- Keystore password: choose strong
- Name/org: Your company
- Validity: 10000 days (as suggested)
**Then:**
- Place `upload-keystore.jks` in `D:\My_Projects\Faster\android\app\` (or secure location)
- Update `android/app/build.gradle.kts` → `signingConfigs.release` to load keystore from file and use passwords (can store in gradle.properties or environment variables)
**Deliverable:** Keystore file exists; `keytool -list -v -keystore upload-keystore.jks` shows certificate.

---

### Task 6: Set app_settings Values
**Owner:** Admin
**Action:** Insert required settings into `app_settings` table in Supabase.
**SQL:**
```sql
INSERT INTO app_settings (key, value) VALUES
  ('cancel_free_minutes', '{"minutes": 5}'),
  ('cancel_commission_minutes', '{"minutes": 30}'),
  ('default_commission_rate', '0.10'),
  ('admin_whatsapp_number', '+201234567890'),
  ('referral_points_earner', '50'),
  ('referral_points_new_user', '25'),
  ('maintenance_mode', 'false')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```
**Notes:** Adjust values per business rules (commission rate may vary by category).
**Deliverable:** Query `SELECT * FROM app_settings WHERE key IN ('cancel_free_minutes','cancel_commission_minutes','default_commission_rate','admin_whatsapp_number','referral_points_earner','referral_points_new_user','maintenance_mode');` shows correct values.

---

### Task 7: Manual Testing Execution
**Owner:** QA/Developer
**Action:** Execute 30 test cases in `harness-system/verification/TEST_RESULTS.md`
**Process:**
1. For each test case, follow steps on a real device or emulator
2. Record Pass/Fail and notes (screenshots if possible)
3. Update `TEST_RESULTS.md` with actual results
**High priority first:**
- 500 EGP withdrawal
- Price offer flow + auto provider search
- Settlement flow
- Category matching
- Rating auto-show
- FCM notifications

**Deliverable:** Completed `TEST_RESULTS.md` with no "PENDING" entries.

---

### Task 8: Fix Client Cancellation RPC Inconsistency
**Owner:** Frontend developer
**File:** `lib/features/booking/presentation/tracking_screen.dart`
**Change:** Replace direct update (around lines 300-330) with call to `cancel_booking_graduated` RPC, similar to provider's `_cancelOrder` in `provider_order_detail_screen.dart`.
**Steps:**
1. Create `_getCancelInfo()` function (copied from provider screen) to show free/commission status before confirming.
2. Change `_clientCancelOrder` to:
   - Show dialog with cancellation info
   - Call `SupabaseService.db.rpc('cancel_booking_graduated', params: {...})`
   - Handle response: if success, update UI; if error, show message
   - If `deduction_type == 'free'`, allow cancellation; if `'commission'`, inform client of any charge (if policy); if `'not_allowed'`, block.
3. Ensure booking status updates correctly (RPC sets `'cancelled'` for client).
**Impact:** Consistent financial handling; prevents provider disputes.
**Deliverable:** Code changed, tested manually for both free and commission windows.

---

### Task 9: Final Release Build
**Owner:** DevOps
**Command (after keystore configured):**
```bash
flutter clean
flutter build apk --release
```
**Verify:**
- APK size < 50MB (if larger, consider appbundle)
- Signature: `jarsigner -verify -verbose -certs app-release.apk`
**Upload:** Google Play Console → Internal testing track first.
**Deliverable:** APK file ready, Play Store upload initiated.

---

### Task 10: Documentation Finalization
**Owner:** Technical writer
**Files to update:**
- `README.md`: Add setup instructions, testing guide, release checklist
- `ADMIN_GUIDE.md` (new): How to manage providers, verify documents, process withdrawals, view financial reports
- `USER_GUIDE.md` (new): For end-users (optional)
**Deliverable:** Documentation complete and reviewed.

---

## Execution Strategy

**Parallel work possible:**
- Tasks 1, 2, 3, 4, 5, 6 can be done in parallel by different people.
- Task 7 depends on 1-6 completion (needs working app + DB configured)
- Task 8 depends on understanding RPC; can be done anytime before release
- Task 9 depends on 4 (keystore) and 5 (settings)
- Task 10 can be done alongside others

**If using Harness System:**
- Paste `INITIALIZATION_PROMPT.md` into new agent
- Agent will break down these tasks into subtasks, track progress, enforce gates
- You provide manual outputs (build logs, DB access) when asked

---

**Start now:** Choose task based on your role and resources. Report progress.
