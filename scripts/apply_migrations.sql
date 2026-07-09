-- Apply all migrations in order
BEGIN;

CREATE TABLE IF NOT EXISTS _migration_log (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW()
);

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
