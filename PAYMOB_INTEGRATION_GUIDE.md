# Paymob Integration - Complete Setup Guide

## Overview

This guide covers the complete setup of Paymob payment gateway for the Faster app.

## Prerequisites

- [Paymob Account](https://dashboard.paymob.com/)
- Paymob API credentials (Public Key, Secret Key)
- Integration IDs for Card and Wallet payments
- Supabase project with Edge Functions enabled
- Flutter project with `flutter_paymob_sdk` package

---

## 1. Get Paymob Credentials

1. Log in to [Paymob Dashboard](https://dashboard.paymob.com/)
2. Go to **Developers** → **API Credentials**
3. Copy:
   - **Public Key** (公开密钥)
   - **Secret Key** (私钥)
4. Go to **Integrations** → **Accept Payment**
5. Create two integrations:
   - One for **Card Payments**
   - One for **Wallet Payments** (Mobil/Etisalat/Vodafone)
6. Copy the **Integration IDs** for each

---

## 2. Environment Variables

Create a `.env` file in the project root (copy from `.env.example`):

```bash
PAYMOB_PUBLIC_KEY=pk_test_your_public_key
PAYMOB_SECRET_KEY=sk_test_your_secret_key
PAYMOB_INTEGRATION_ID_CARD=your_card_integration_id
PAYMOB_INTEGRATION_ID_WALLET=your_wallet_integration_id
```

**Important:**
- These keys are also needed as **Supabase Secrets** for Edge Functions
- Use separate test/production keys

---

## 3. Supabase Configuration

### 3.1. Upload Edge Functions

```bash
# Login to Supabase
supabase login

# Link your project
supabase link --project-ref your-project-ref

# Deploy the paymob-create-intention function
supabase functions deploy paymob-create-intention --no-verify-jwt

# Deploy the paymob-webhook function
supabase functions deploy paymob-webhook --no-verify-jwt
```

### 3.2. Set Edge Function Secrets

In Supabase Dashboard → Edge Functions → **paymob-create-intention** → Secrets:

- `PAYMOB_SECRET_KEY` = your_secret_key
- `PAYMOB_PUBLIC_KEY` = your_public_key
- `PAYMOB_INTEGRATION_ID_CARD` = your_card_integration_id
- `PAYMOB_INTEGRATION_ID_WALLET` = your_wallet_integration_id
- `SUPABASE_URL` = your Supabase URL (auto-set usually)
- `SUPABASE_SERVICE_ROLE_KEY` = your service role key (auto-set usually)

For **paymob-webhook** function, set the same secrets.

### 3.3. Run Database Migrations

Apply these migrations in order:

```bash
# The migrations will be automatically applied when you run:
supabase db push
```

Or manually in Supabase Dashboard → SQL Editor, run:

1. `002_notifications_and_tracking.sql` - Creates payment tables
2. `070_payment_rls_policies.sql` - Enables RLS on payment tables
3. `071_update_settled_amount.sql` - Fixes settled_amount calculation
4. `072_fix_earnings_trigger.sql` - Makes earnings trigger idempotent
5. `paymob_create_intention` Edge Function dependencies (if any)

**Migration 070 is CRITICAL for security** - it enables RLS on payment tables so users can only see their own financial data.

---

## 4. Flutter Configuration

### 4.1. Add Dependency

```yaml
dependencies:
  flutter_paymob_sdk: ^latest_version
```

The package provides:
- Android Paymob SDK (via Gradle)
- iOS Paymob SDK (via CocoaPods)

### 4.2. Android Setup

No additional setup needed beyond the package. Ensure internet permission in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 4.3. iOS Setup

**Important:** The Paymob iOS SDK must be configured.

1. Open `ios/Podfile` and ensure platform is at least 13.0:
   ```ruby
   platform :ios, '13.0'
   ```

2. The Podfile should include the PaymobSDK pod (added automatically by the package):
   ```ruby
   pod 'PaymobSDK', '~> 1.0.20'
   ```

3. Run pod install:
   ```bash
   cd ios
   pod install
   ```

4. The `AppDelegate.swift` has been simplified to use the plugin's auto-registration.

---

## 5. Webhook Configuration

### 5.1. Get Paymob Webhook URL

Deploy the `paymob-webhook` Edge Function and get its URL:

```
https://your-project-ref.supabase.co/functions/v1/paymob-webhook
```

### 5.2. Configure Paymob Webhook

In Paymob Dashboard:

1. Go to **Developers** → **Webhooks**
2. Add a new webhook endpoint with the above URL
3. Select events to send:
   - `payment.success`
   - `payment.failed`
   - `payment.pending`
   - `refund.completed` (optional)

4. Paymob will send a test webhook - verify the signature (placeholder in our code) and completeness.

### 5.3. Webhook Security

The current webhook implementation **does not verify signatures**. For production:

1. In Paymob dashboard, get the **Webhook Secret Key**
2. Add it as `PAYMOB_WEBHOOK_SECRET` in Edge Function secrets
3. Uncomment and implement the `verifyPaymobSignature` function using HMAC-SHA256

---

## 6. Database Schema

### Required Tables

- `payment_intents`: Stores Paymob payment intention details
- `wallets`: Provider wallet balances
- `transactions`: Financial transaction history
- `withdrawal_requests`: Provider withdrawal requests

### Row-Level Security (RLS)

Migration `070_payment_rls_policies.sql` enables RLS with these policies:

**payment_intents:**
- Users can view/update their own payment_intents
- Admins can view/update all payment_intents
- Service role has full access

**wallets:**
- Providers can view/update their own wallet
- Admins can view/update all wallets
- Service role has full access

**transactions:**
- Providers can view their own transactions
- Admins can view/insert transactions
- Service role has full access

**withdrawal_requests:**
- Providers can view/insert/update their own
- Admins can view/update all
- Service role has full access

---

## 7. Payment Flow

### 7.1. Client Payment Flow

1. Client selects a service and clicks "ادفع واطلب"
2. `PaymobServiceWrapper.pay()` is called
3. Edge Function `paymob-create-intention` creates a Paymob order and returns client_secret
4. `flutter_paymob_sdk` displays Paymob payment UI
5. User completes payment
6. On success:
   - Booking is created with `payment_status: 'paid'`
   - `payment_intents` record created with status 'paid'
   - Webhook fires → `paymob-webhook` updates booking and payment_intent
7. On pending/failure: booking created with appropriate status

### 7.2. Provider Settlement Flow

1. Provider requests withdrawal from `provider_wallet_screen`
2. Withdrawal request created in `withdrawal_requests` table
3. Admin reviews withdrawal request in `admin_withdrawals_screen`
4. Admin verifies → `on_settlement_change()` trigger runs:
   - Updates `settled_amount` = sum of all verified settlements
   - Sends notification to provider
5. Provider's wallet shows updated settled_amount and commission remaining

---

## 8. Testing Checklist

### Unit Tests
- [ ] `PaymobServiceWrapper.pay()` invokes Edge Function correctly
- [ ] `client_checkout_screen` handles all payment results (success/pending/failure)
- [ ] `provider_wallet_screen` calculates commission remaining correctly

### Integration Tests
- [ ] Card payment flow end-to-end (test mode)
- [ ] Wallet payment flow end-to-end (test mode)
- [ ] Webhook updates booking status correctly
- [ ] calculate_provider_earnings trigger fires only once
- [ ] settled_amount updates on admin verification
- [ ] RLS policies block unauthorized access

### Security Tests
- [ ] User A cannot read User B's payment_intents
- [ ] Provider A cannot read Provider B's wallets/transactions
- [ ] Admin can read all financial data
- [ ] Webhook signature verification (if implemented)

---

## 9. Production Deployment

1. **Switch to Production Keys:**
   - Update `.env` with production Paymob keys
   - Update Supabase Edge Function secrets with production keys
   - Use production mode in Flutter app (`FLUTTER_ENV=production`)

2. **Enable Paymob Production:**
   - In Paymob dashboard, switch integrations to live mode
   - Update integration IDs in `.env` if changed

3. **Verify SSL:**
   - All Edge Functions must use HTTPS
   - Paymob webhook requires valid SSL certificate

4. **Monitor Webhooks:**
   - Check Paymob webhook delivery logs
   - Set up alerts for webhook failures

5. **Test Real Payment:**
   - Use Paymob test card numbers first
   - Then do a small real transaction (1 EGP) to verify live mode

---

## 10. Troubleshooting

### Payment fails with "Successfully processed but status is not paid"
- Check webhook is configured and firing
- Verify `paymob-webhook` function is deployed and has correct secrets
- Check Supabase logs for webhook errors

### Cannot see payment_intents in app
- Verify RLS policies are applied (run verification queries in migration)
- Check that user_id in payment_intents matches the logged-in user

### iOS payments not working
- Ensure `PaymobSDK` pod is installed (`pod install`)
- Check Podfile platform version >= 13.0
- Verify GoogleService-Info.plist exists for Firebase (if used)

### Webhook not firing
- Confirm webhook URL is correct and deployed
- Check Paymob dashboard webhook delivery logs
- Ensure Edge Function has `--no-verify-jwt` flag to accept Paymob's requests

---

## 11. Support and Resources

- **Paymob Docs:** https://docs.paymob.com/
- **Flutter Package:** https://pub.dev/packages/flutter_paymob_sdk
- **Supabase Edge Functions:** https://supabase.com/docs/guides/functions
- **RLS Policies:** See `070_payment_rls_policies.sql`

---

## Summary of Changes Made

✅ Migration 070: RLS policies on all payment tables
✅ Migration 071: settled_amount recalculation on settlement verification
✅ Migration 072: Idempotent earnings trigger
✅ Edge Function: paymob-create-intention (existing, verified)
✅ Edge Function: paymob-webhook (new) - handles async payment status
✅ Flutter PaymobServiceWrapper: Returns order ID for tracking
✅ client_checkout_screen: Creates payment_intent linking to booking
✅ iOS Podfile: Updated platform to 13.0, added PaymobSDK pod
✅ iOS AppDelegate: Simplified to use plugin auto-registration
✅ provider_wallet_screen: Uses settled_amount from database (not recalculated in UI)
✅ Admin dashboard: Shows financial statistics using RLS policies

---

**Next Steps:** Deploy migrations, configure Edge Function secrets, test thoroughly in test mode before going live.
