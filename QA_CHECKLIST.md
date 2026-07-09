# QUALITY ASSURANCE CHECKLIST
## Post-Implementation

---

### Compilation Check
- [ ] Run `flutter analyze --no-pub` — zero errors
- [ ] Fix any import errors, missing dependencies, type mismatches

### Database & Migrations
- [ ] Confirm migration `024_fix_debt_calculation_logic.sql` applied (contains `cancel_booking_graduated`)
- [ ] Confirm migration `045_add_products_table.sql` applied
- [ ] Confirm migration `20260615001_add_provider_type_and_partner_fields.sql` applied (partner RLS)
- [ ] Create Storage buckets: `provider-documents` (private), `booking-photos` (private or public)
- [ ] Verify RLS policies:
  - `provider_profiles`: partners can access own row only
  - `products`: provider (seller) can access own rows only
  - `profiles`: standard policies for role-based access

### Environment Configuration
- [ ] Replace Paymob test keys with production in `assets/.env`
- [ ] Ensure `GOOGLE_SERVICES_JSON` present and Firebase configured
- [ ] Set release keystore in `android/app/build.gradle.kts`
- [ ] Set `app_settings`:
  - `cancel_free_minutes` (default 5)
  - `cancel_commission_minutes` (default 30)
  - `default_commission_rate` (e.g., 0.10)
  - `admin_whatsapp_number`
  - `maintenance_mode` = false

---

### Manual Testing Scenarios

#### Seller Flow
1. Register as seller → directed to document upload → upload ID/profile → status shows pending/approved
2. Login as seller → dashboard shows stats → navigate to products tab
3. Add product with image → appears in list → edit → delete
4. Verify product visible only to that seller (RLS)
5. Check wallet: when orders placed for products, balance updates?

#### Driver/Delivery Profile
1. Login as driver → open profile → see driver-specific fields (no category, but can see rating, wallet)
2. Edit profile (name, phone) → changes saved
3. Check online toggle works
4. Same for delivery

#### Document Upload for All Partners
1. For each role (provider, seller, driver, delivery):
   - Register → should go to document upload screen
   - Upload documents → status changes to pending
   - Admin can verify → status changes to approved

#### Client Cancellation
1. Client creates booking → provider accepts within 5 minutes → client cancels → should succeed free
2. Provider accepts, wait >5 min but <30 min → client cancels → should succeed with commission deducted from provider debt (check provider wallet/transactions)
3. Wait >30 min → client cancel button should be blocked or show "contact support"
4. Verify `cancel_booking_graduated` RPC called (check Supabase logs or db changes)

#### Maintenance Mode
1. As admin/developer, enable maintenance for clients → client app shows overlay
2. Disable → client app returns to normal automatically
3. Admin should never be blocked

---

### Build & Release
- [ ] `flutter clean && flutter build apk --release`
- [ ] APK size < 50MB (if larger, consider app bundle)
- [ ] Verify signing certificate (not debug)
- [ ] Upload to Google Play Console (internal test track)

---

**All code changes completed. Ready for QA and deployment configuration.**
