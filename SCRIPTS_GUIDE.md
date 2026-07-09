# AUTO-SETUP SCRIPT FOR WINDOWS
## Complete Pre-Release Configuration

---

## Script 1: Flutter Build & Analyze

**File:** `scripts\setup_build.bat`

```batch
@echo off
cd /d "D:\My_Projects\Faster"

echo Running flutter analyze...
flutter analyze --no-pub > analysis.txt 2>&1
if errorlevel 1 (
    echo Errors found! Check analysis.txt
    pause
    exit /b 1
)
echo Analyze passed.

echo Running flutter test...
flutter test > test_results.txt 2>&1
if errorlevel 1 (
    echo Tests failed! Check test_results.txt
    pause
    exit /b 1
)
echo Tests passed.

echo Building release APK...
flutter build apk --release
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)
echo Build successful: build/app/outputs/flutter-apk/app-release.apk
pause
```

---

## Script 2: Supabase Migrations Applier

**File:** `scripts\apply_migrations.sql`

```sql
-- Run this in Supabase SQL Editor
-- It applies all migrations in order

BEGIN;

-- Create a table to track applied migrations if not exists
CREATE TABLE IF NOT EXISTS _migration_log (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to apply a migration if not already applied
DO $$
DECLARE
    f TEXT;
    sql TEXT;
BEGIN
    FOR f IN SELECT unnest(ARRAY[
        '001_app_settings_data.sql',
        '002_notifications_and_tracking.sql',
        '003_improvements_and_security.sql',
        '004_rls_fix_provider_profiles.sql',
        '005_add_categories_services.sql',
        '006_fix_all.sql',
        '007_fix_rls_simple.sql',
        '008_fix_signup.sql',
        '009_chat_notifications_and_instapay.sql',
        '010_commission_settlements.sql',
        '011_add_commission_rate.sql',
        '012_anti_fraud.sql',
        '013_find_providers_within_radius.sql',
        '014_referral_points.sql',
        '015_anti_fraud_verification.sql',
        '016_auto_delete_chats_and_reports.sql',
        '017_provider_matching_requests.sql',
        '018_comprehensive_features.sql',
        '019_add_settled_amount_to_provider_profiles.sql',
        '020_admin_financial_reports.sql',
        '021_price_offer_system.sql',
        '022_referral_system.sql',
        '023_provider_enhancements.sql',
        '024_fix_debt_calculation_logic.sql',
        '025_admin_controlled_settlements.sql',
        '026_enhance_offers.sql',
        '027_drop_auth_trigger.sql',
        '028_add_is_urgent_column.sql',
        '029_add_broadcast_status.sql',
        '030_client_price_suggestion.sql',
        '031_free_service_option.sql',
        '032_provider_heading_tracking.sql',
        '033_improve_notifications.sql',
        '034_fix_notifications_types.sql',
        '035_fix_notifications_rls_and_types.sql',
        '036_fix_notification_types_simple.sql',
        '037_fix_provider_locations_rls.sql',
        '038_fix_notifications_rls_cross_user.sql',
        '039_admin_notifications_enhancements.sql',
        '040_fix_document_verification.sql',
        '041_add_name_and_city_to_profiles.sql',
        '042_add_new_service_types.sql',
        '043_add_booking_enhancements.sql',
        '044_redesign_provider_classification.sql',
        '045_add_products_table.sql',
        '047_points_redeem.sql',
        '049_provider_schedule.sql',
        '058_admin_quality_view.sql',
        '060_add_admin_broadcasts.sql',
        '061_find_providers_graduated.sql',
        '062_ux_audit_improvements.sql',
        '063_admin_notifications_and_whatsapp.sql',
        '064_fix_stack_error_and_features.sql',
        '065_add_onesignal_id_to_profiles.sql',
        '066_fix_arrival_verification_code.sql',
        '067_admin_full_control.sql',
        '068_update_transactions_check_constraint.sql',
        '20260615001_add_provider_type_and_partner_fields.sql'
    ]) LOOP
        IF NOT EXISTS (SELECT 1 FROM _migration_log WHERE filename = f) THEN
            BEGIN
                EXECUTE format('SELECT pg_catalog.pg_read_file(''supabase/migrations/%s'')', f) INTO sql;
                IF sql IS NOT NULL THEN
                    EXECUTE sql;
                    INSERT INTO _migration_log (filename) VALUES (f);
                    RAISE NOTICE 'Applied: %', f;
                ELSE
                    RAISE WARNING 'File not found or empty: %', f;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Failed to apply %: %', f, SQLERRM;
            END;
        END IF;
    END LOOP;
END $$;

COMMIT;
```

**Usage:**
1. Open Supabase Dashboard → SQL Editor
2. Paste this entire script
3. Run it. It will apply all migrations that haven't been applied yet.

---

## Script 3: Create Storage Buckets

**File:** `scripts\create_storage_buckets.sql`

```sql
-- Create buckets if not exist

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('provider-documents', 'provider-documents', false, 5242880, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('booking-photos', 'booking-photos', false, 10485760, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- Set up policies for provider-documents (authenticated users can upload to their own folder)
INSERT INTO storage.policies (name, bucket_id, definition, check)
VALUES (
  'Users can upload own documents',
  'provider-documents',
  'auth.uid()::text = (storage.foldername(name))[1]',
  true
) ON CONFLICT DO NOTHING;

INSERT INTO storage.policies (name, bucket_id, definition, check)
VALUES (
  'Users can read own documents',
  'provider-documents',
  'auth.uid()::text = (storage.foldername(name))[1]',
  false
) ON CONFLICT DO NOTHING;

-- For booking-photos, allow public read (if needed)
-- UPDATE storage.buckets SET public = true WHERE id = 'booking-photos';
```

---

## Script 4: Set app_settings

**File:** `scripts\set_app_settings.sql`

```sql
INSERT INTO app_settings (key, value) VALUES
  ('cancel_free_minutes', '{"minutes": 5}'),
  ('cancel_commission_minutes', '{"minutes": 30}'),
  ('default_commission_rate', '0.10'),
  ('admin_whatsapp_number', '+201234567890'), -- CHANGE THIS
  ('referral_points_earner', '50'),
  ('referral_points_new_user', '25'),
  ('maintenance_mode', 'false'),
  ('cancel_window_hours', '24')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

---

## Script 5: Generate Keystore (Manual)

Run in CMD as Administrator:

```cmd
cd /d "D:\My_Projects\Faster\android\app"
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Remember passwords. Then edit `android/app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("release") {
            val keystoreFile = file("upload-keystore.jks")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = "YOUR_KEYSTORE_PASSWORD"
                keyAlias = "upload"
                keyPassword = "YOUR_KEY_PASSWORD"
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
```

---

## Script 6: Replace Paymob Keys

**File:** `scripts\update_env.bat`

```batch
@echo off
set /p PAYMOB_PUBLIC_KEY=Enter Paymob Public Key (egy_pk_...):
set /p PAYMOB_SECRET_KEY=Enter Paymob Secret Key (egy_sk_...):
set /p PAYMOB_INTEGRATION_ID_CARD=Enter Paymob Card Integration ID:
set /p PAYMOB_INTEGRATION_ID_WALLET=Enter Paymob Wallet Integration ID:

(
echo # Supabase Configuration
echo SUPABASE_URL=https://xoxnjnhqpqkkctkvxzzy.supabase.co
echo SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
echo.
echo # Paymob Configuration
echo PAYMOB_PUBLIC_KEY=%PAYMOB_PUBLIC_KEY%
echo PAYMOB_SECRET_KEY=%PAYMOB_SECRET_KEY%
echo PAYMOB_INTEGRATION_ID_CARD=%PAYMOB_INTEGRATION_ID_CARD%
echo PAYMOB_INTEGRATION_ID_WALLET=%PAYMOB_INTEGRATION_ID_WALLET%
echo.
echo # Admin
echo ADMIN_EMAIL=admin@faster.com
echo.
echo # Environment
echo FLUTTER_ENV=production
) > "D:\My_Projects\Faster\assets\.env.new"

echo New .env created. Verify contents before replacing.
pause
```

---

## Next Steps

1. Run `scripts\setup_build.bat` — capture analyze/test results, build APK
2. Apply migrations using `scripts\apply_migrations.sql` in Supabase
3. Run `scripts\create_storage_buckets.sql` in Supabase
4. Run `scripts\set_app_settings.sql` in Supabase
5. Update Paymob keys via `scripts\update_env.bat` or manually
6. Generate keystore and update `build.gradle.kts`
7. Run manual tests from `verification/TEST_RESULTS.md`
8. Update `TASK_QUEUE.md` as you complete each

---

**All code changes are done. These scripts automate the remaining DevOps tasks.**
