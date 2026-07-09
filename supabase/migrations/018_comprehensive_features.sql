-- =====================================================
-- MIGRATION 018: Comprehensive feature additions
-- =====================================================
-- Based on tester feedback, this migration adds:
-- 1. Cancel order with graduated commission (first X min free, then commission, then support only)
-- 2. Fault photo (before work) and completion photo (after work) required
-- 3. Price offer (provider can offer higher price)
-- 4. Order code with full details
-- 5. Favorite services
-- 6. Referral/promo code system
-- 7. Admin-controlled wallet threshold for auto-offline
-- 8. Chat hidden after service completion
-- 9. Cancel reason tracking
-- 10. WhatsApp customer service number in app_settings

-- =====================================================
-- 1. Bookings table additions
-- =====================================================

-- Fault photo URL (uploaded before starting work)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS fault_photo_url TEXT;

-- Completion photo URLs (uploaded before completing - already exists as completion_photo_urls)
-- Make sure it exists
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS completion_photo_urls TEXT[] DEFAULT '{}';

-- Provider's offered price (if higher than listed)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS offered_price NUMERIC;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS offered_price_reason TEXT;

-- Order code - unique short code for each booking
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS order_code TEXT UNIQUE;

-- Cancel reason and cancelled_by
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_by UUID; -- who cancelled (client_id or provider_id)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- Commission deduction on cancel
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancel_commission_deducted NUMERIC DEFAULT 0;

-- Chat visibility flag (hidden after service completion)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS chat_visible BOOLEAN DEFAULT true;

-- Accepted at timestamp (for cancel window calculation)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;

-- =====================================================
-- 2. Generate order codes for existing bookings
-- =====================================================

-- Function to generate a unique 8-character order code
CREATE OR REPLACE FUNCTION generate_order_code()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code TEXT;
  exists BOOLEAN;
BEGIN
  LOOP
    code := '';
    FOR i IN 1..8 LOOP
      code := code || substr(chars, floor(random() * length(chars)::numeric + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM bookings WHERE order_code = code) INTO exists;
    EXIT WHEN NOT exists;
  END LOOP;
  RETURN code;
END;
$$;

-- Add order codes to existing bookings that don't have one
UPDATE bookings SET order_code = generate_order_code() WHERE order_code IS NULL;

-- =====================================================
-- 3. Trigger to auto-generate order_code on insert
-- =====================================================

CREATE OR REPLACE FUNCTION set_order_code_on_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.order_code IS NULL THEN
    NEW.order_code := generate_order_code();
  END IF;
  -- Set accepted_at when status changes to accepted
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    NEW.accepted_at := NOW();
  END IF;
  -- Hide chat when status becomes completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    NEW.chat_visible := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_order_code ON bookings;
CREATE TRIGGER trg_set_order_code
  BEFORE INSERT OR UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_order_code_on_insert();

-- =====================================================
-- 4. Cancel booking with graduated commission (RPC)
-- =====================================================
-- Cancel rules (configurable via app_settings):
--   cancel_free_minutes: First X minutes = no commission (default 5)
--   cancel_commission_minutes: Within X minutes = commission deducted (default 30)
--   After that = only via customer service

CREATE OR REPLACE FUNCTION cancel_booking_graduated(
  p_booking_id UUID,
  p_cancelled_by UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking RECORD;
  v_status TEXT;
  v_accepted_at TIMESTAMPTZ;
  v_total_price NUMERIC;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_minutes_since_accept DOUBLE PRECISION;
  v_cancel_free_minutes INTEGER;
  v_cancel_commission_minutes INTEGER;
  v_deduction_type TEXT;
  v_provider_id UUID;
  v_client_id UUID;
BEGIN
  -- Get configurable cancel windows from app_settings
  BEGIN
    SELECT (value::jsonb->>'minutes')::INTEGER INTO v_cancel_free_minutes
    FROM app_settings WHERE key = 'cancel_free_minutes';
  EXCEPTION WHEN OTHERS THEN v_cancel_free_minutes := 5;
  END;
  IF v_cancel_free_minutes IS NULL THEN v_cancel_free_minutes := 5; END IF;

  BEGIN
    SELECT (value::jsonb->>'minutes')::INTEGER INTO v_cancel_commission_minutes
    FROM app_settings WHERE key = 'cancel_commission_minutes';
  EXCEPTION WHEN OTHERS THEN v_cancel_commission_minutes := 30;
  END;
  IF v_cancel_commission_minutes IS NULL THEN v_cancel_commission_minutes := 30; END IF;

  -- Lock and get booking
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  v_status := v_booking.status;
  v_accepted_at := v_booking.accepted_at;
  v_total_price := COALESCE(v_booking.total_price, v_booking.price, 0);
  v_commission_rate := COALESCE(v_booking.commission_rate, 0.10);
  v_provider_id := v_booking.provider_id;
  v_client_id := v_booking.client_id;

  -- Can only cancel accepted/on_the_way/arrived orders
  IF v_status NOT IN ('accepted', 'on_the_way', 'arrived', 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel order in this status');
  END IF;

  -- Calculate minutes since acceptance
  IF v_accepted_at IS NOT NULL THEN
    v_minutes_since_accept := EXTRACT(EPOCH FROM (NOW() - v_accepted_at)) / 60.0;
  ELSE
    v_minutes_since_accept := 0;
  END IF;

  -- Determine deduction type
  IF v_minutes_since_accept <= v_cancel_free_minutes THEN
    -- Free cancellation (no commission deducted)
    v_deduction_type := 'free';
    v_commission_amount := 0;
  ELSIF v_minutes_since_accept <= v_cancel_commission_minutes THEN
    -- Commission deducted
    v_deduction_type := 'commission';
    v_commission_amount := v_total_price * v_commission_rate;
  ELSE
    -- Cannot cancel (must contact support)
    RETURN jsonb_build_object(
      'success', false,
      'error', 'لا يمكن إلغاء الطلب بعد ${v_cancel_commission_minutes} دقيقة من القبول. تواصل مع خدمة العملاء.',
      'minutes_since_accept', v_minutes_since_accept,
      'cancel_commission_minutes', v_cancel_commission_minutes
    );
  END IF;

  -- If provider cancelled, deduct commission from their wallet
  IF p_cancelled_by = v_provider_id AND v_commission_amount > 0 THEN
    UPDATE provider_profiles
    SET wallet_balance = GREATEST(wallet_balance - v_commission_amount, 0)
    WHERE id = v_provider_id;

    -- Log the deduction as a transaction
    INSERT INTO transactions (provider_id, amount, type, description, booking_id)
    VALUES (v_provider_id, -v_commission_amount, 'cancel_commission',
      'خصم عمولة إلغاء الطلب #${p_booking_id}', p_booking_id);
  END IF;

  -- Re-assign: if provider cancelled, set provider_id to NULL so other providers can see it
  IF p_cancelled_by = v_provider_id THEN
    UPDATE bookings SET
      status = 'pending',
      provider_id = NULL,
      cancel_reason = p_reason,
      cancelled_by = p_cancelled_by,
      cancelled_at = NOW(),
      cancel_commission_deducted = v_commission_amount,
      accepted_at = NULL
    WHERE id = p_booking_id;
  ELSE
    -- Client cancelled
    UPDATE bookings SET
      status = 'cancelled',
      cancel_reason = p_reason,
      cancelled_by = p_cancelled_by,
      cancelled_at = NOW(),
      cancel_commission_deducted = v_commission_amount
    WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'deduction_type', v_deduction_type,
    'commission_deducted', v_commission_amount,
    'minutes_since_accept', v_minutes_since_accept,
    'reassigned', p_cancelled_by = v_provider_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_booking_graduated(UUID, UUID, TEXT) TO authenticated;

-- =====================================================
-- 5. Favorite services table
-- =====================================================

CREATE TABLE IF NOT EXISTS favorite_services (
  id BIGSERIAL PRIMARY KEY,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  service_id BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(client_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_favorite_services_client ON favorite_services(client_id);
CREATE INDEX IF NOT EXISTS idx_favorite_services_service ON favorite_services(service_id);

-- RLS
ALTER TABLE favorite_services ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own favorites" ON favorite_services;
DROP POLICY IF EXISTS "Users can add own favorites" ON favorite_services;
DROP POLICY IF EXISTS "Users can delete own favorites" ON favorite_services;
CREATE POLICY "Users can view own favorites" ON favorite_services FOR SELECT USING (client_id = auth.uid());
CREATE POLICY "Users can add own favorites" ON favorite_services FOR INSERT WITH CHECK (client_id = auth.uid());
CREATE POLICY "Users can delete own favorites" ON favorite_services FOR DELETE USING (client_id = auth.uid());

-- =====================================================
-- 6. Referral system
-- =====================================================

CREATE TABLE IF NOT EXISTS referral_codes (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  promo_value NUMERIC DEFAULT 0,
  promo_type TEXT DEFAULT 'fixed' CHECK (promo_type IN ('fixed', 'percentage')),
  uses_count INTEGER DEFAULT 0,
  max_uses INTEGER DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS referral_uses (
  id BIGSERIAL PRIMARY KEY,
  referrer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  code_used TEXT NOT NULL,
  reward_given_referrer NUMERIC DEFAULT 0,
  reward_given_referred NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(referred_id) -- each user can only use a referral code once
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_user ON referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_uses_referrer ON referral_uses(referrer_id);

-- RLS
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Users can insert own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Users can update own referral code" ON referral_codes;
CREATE POLICY "Users can view own referral code" ON referral_codes FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert own referral code" ON referral_codes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own referral code" ON referral_codes FOR UPDATE USING (user_id = auth.uid());

ALTER TABLE referral_uses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own referral uses" ON referral_uses;
DROP POLICY IF EXISTS "Anyone can insert referral use" ON referral_uses;
CREATE POLICY "Users can view own referral uses" ON referral_uses FOR SELECT USING (referrer_id = auth.uid() OR referred_id = auth.uid());
CREATE POLICY "Anyone can insert referral use" ON referral_uses FOR INSERT WITH CHECK (true);

-- Generate referral code for new users
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code TEXT;
  exists BOOLEAN;
BEGIN
  LOOP
    code := 'FAST';
    FOR i IN 1..6 LOOP
      code := code || substr(chars, floor(random() * length(chars)::numeric + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = code) INTO exists;
    EXIT WHEN NOT exists;
  END LOOP;
  RETURN code;
END;
$$;

-- Auto-create referral code when a new user signs up
CREATE OR REPLACE FUNCTION auto_create_referral_code()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_code TEXT;
  v_promo_value NUMERIC;
BEGIN
  -- Get default promo value from app_settings
  BEGIN
    SELECT (value::jsonb->>'value')::NUMERIC INTO v_promo_value
    FROM app_settings WHERE key = 'referral_promo_value';
  EXCEPTION WHEN OTHERS THEN v_promo_value := 20;
  END;
  IF v_promo_value IS NULL THEN v_promo_value := 20; END IF;

  v_code := generate_referral_code();
  INSERT INTO referral_codes (user_id, code, promo_value, promo_type)
  VALUES (NEW.id, v_code, v_promo_value, 'fixed');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_referral_code ON profiles;
CREATE TRIGGER trg_auto_referral_code
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION auto_create_referral_code();

-- Apply referral code (when a new user uses someone's code)
CREATE OR REPLACE FUNCTION apply_referral_code(
  p_referred_id UUID,
  p_code TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_referral RECORD;
  v_referrer_reward NUMERIC;
  v_referred_reward NUMERIC;
BEGIN
  -- Get the referral code
  SELECT * INTO v_referral FROM referral_codes WHERE code = p_code;
  IF v_referral IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الإحالة غير صحيح');
  END IF;

  -- Can't use own code
  IF v_referral.user_id = p_referred_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكنك استخدام كود الإحالة الخاص بك');
  END IF;

  -- Check max uses
  IF v_referral.max_uses IS NOT NULL AND v_referral.uses_count >= v_referral.max_uses THEN
    RETURN jsonb_build_object('success', false, 'error', 'تم استخدام هذا الكود الحد الأقصى من المرات');
  END IF;

  -- Check if already used a referral code
  IF EXISTS(SELECT 1 FROM referral_uses WHERE referred_id = p_referred_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'لقد استخدمت كود إحالة من قبل');
  END IF;

  -- Get reward values from app_settings
  BEGIN
    SELECT (value::jsonb->>'referrer_reward')::NUMERIC INTO v_referrer_reward
    FROM app_settings WHERE key = 'referral_promo_value';
  EXCEPTION WHEN OTHERS THEN v_referrer_reward := 20;
  END;

  BEGIN
    SELECT (value::jsonb->>'referred_reward')::NUMERIC INTO v_referred_reward
    FROM app_settings WHERE key = 'referral_promo_value';
  EXCEPTION WHEN OTHERS THEN v_referred_reward := 20;
  END;

  IF v_referrer_reward IS NULL THEN v_referrer_reward := 20; END IF;
  IF v_referred_reward IS NULL THEN v_referred_reward := 20; END IF;

  -- Record the referral use
  INSERT INTO referral_uses (referrer_id, referred_id, code_used, reward_given_referrer, reward_given_referred)
  VALUES (v_referral.user_id, p_referred_id, p_code, v_referrer_reward, v_referred_reward);

  -- Update uses count
  UPDATE referral_codes SET uses_count = uses_count + 1 WHERE id = v_referral.id;

  -- Give rewards (add to wallets for providers, or as credit for clients)
  -- For now, add as wallet balance for providers, or just track for clients
  -- Referrer gets reward in wallet if they're a provider
  BEGIN
    UPDATE provider_profiles SET wallet_balance = wallet_balance + v_referrer_reward
    WHERE id = v_referral.user_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'referrer_reward', v_referrer_reward,
    'referred_reward', v_referred_reward
  );
END;
$$;

GRANT EXECUTE ON FUNCTION apply_referral_code(UUID, TEXT) TO authenticated;

-- =====================================================
-- 7. App settings for new features
-- =====================================================

INSERT INTO app_settings (key, value) VALUES
  ('cancel_free_minutes', '{"minutes": 5, "description": "أول 5 دقائق بدون خصم عمولة عند الإلغاء"}'),
  ('cancel_commission_minutes', '{"minutes": 30, "description": "بعد 5 دقائق وحتى 30 دقيقة خصم عمولة عند الإلغاء"}'),
  ('wallet_auto_offline_threshold', '{"value": -50, "enabled": true, "description": "غلق متاح تلقائياً عند وصول رصيد المحفظة لهذا الرقم"}'),
  ('whatsapp_customer_service', '{"number": "201000000000", "message": "مرحباً، أحتاج مساعدة"}'),
  ('referral_promo_value', '{"value": 20, "referrer_reward": 20, "referred_reward": 20, "type": "fixed", "description": "قيمة برومو كود الإحالة"}')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- =====================================================
-- 8. Provider can offer higher price (RPC)
-- =====================================================

CREATE OR REPLACE FUNCTION provider_offer_price(
  p_booking_id UUID,
  p_provider_id UUID,
  p_offered_price NUMERIC,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking RECORD;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.provider_id != p_provider_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not your booking');
  END IF;

  IF v_booking.status NOT IN ('accepted', 'on_the_way', 'arrived') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot offer price in this status');
  END IF;

  IF p_offered_price <= COALESCE(v_booking.total_price, v_booking.price, 0) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offered price must be higher than current price');
  END IF;

  UPDATE bookings SET
    offered_price = p_offered_price,
    offered_price_reason = p_reason
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'offered_price', p_offered_price);
END;
$$;

GRANT EXECUTE ON FUNCTION provider_offer_price(UUID, UUID, NUMERIC, TEXT) TO authenticated;

-- =====================================================
-- 9. Client accept/reject price offer (RPC)
-- =====================================================

CREATE OR REPLACE FUNCTION client_respond_price_offer(
  p_booking_id UUID,
  p_client_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking RECORD;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.client_id != p_client_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not your booking');
  END IF;

  IF v_booking.offered_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No price offer pending');
  END IF;

  IF p_accept THEN
    v_commission_rate := COALESCE(v_booking.commission_rate, 0.10);
    v_commission_amount := v_booking.offered_price * v_commission_rate;
    UPDATE bookings SET
      total_price = v_booking.offered_price,
      commission_amount = v_commission_amount,
      offered_price = NULL,
      offered_price_reason = NULL
    WHERE id = p_booking_id;
  ELSE
    UPDATE bookings SET
      offered_price = NULL,
      offered_price_reason = NULL
    WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END;
$$;

GRANT EXECUTE ON FUNCTION client_respond_price_offer(UUID, UUID, BOOLEAN) TO authenticated;

-- =====================================================
-- 10. Upload fault photo before starting work (RPC)
-- =====================================================

CREATE OR REPLACE FUNCTION upload_fault_photo(
  p_booking_id UUID,
  p_provider_id UUID,
  p_photo_url TEXT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking RECORD;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.provider_id != p_provider_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not your booking');
  END IF;

  UPDATE bookings SET fault_photo_url = p_photo_url WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION upload_fault_photo(UUID, UUID, TEXT) TO authenticated;

-- =====================================================
-- 11. Index for faster booking lookups
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_bookings_order_code ON bookings(order_code);
CREATE INDEX IF NOT EXISTS idx_bookings_cancelled_by ON bookings(cancelled_by) WHERE cancelled_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_chat_visible ON bookings(chat_visible) WHERE chat_visible = true;
