-- =====================================================
-- FASTER APP - Drop problematic triggers for signup
-- =====================================================
-- Run this in Supabase Dashboard → SQL Editor
-- This fixes signup errors by removing conflicting triggers

-- Drop auth.users trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Drop profiles referral trigger (causes "column reference code is ambiguous" error)
DROP TRIGGER IF EXISTS trg_auto_referral_code ON profiles;
DROP FUNCTION IF EXISTS public.auto_create_referral_code();

-- Drop other problematic triggers on profiles
DROP TRIGGER IF EXISTS trg_auto_referral ON profiles;
DROP FUNCTION IF EXISTS public.auto_create_referral();
DROP TRIGGER IF EXISTS trg_duplicate_check ON profiles;
DROP FUNCTION IF EXISTS public.check_duplicate_account();

-- Update referral code function to use referral_codes table instead of profiles.referral_code
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_code TEXT;
  v_exists INTEGER;
  v_promo_value NUMERIC;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Removed similar characters (I, 1, O, 0)
  v_code_length INTEGER := 6;
BEGIN
  -- Get default promo value from app_settings
  BEGIN
    SELECT (value::jsonb->>'value')::NUMERIC INTO v_promo_value
    FROM app_settings WHERE key = 'referral_promo_value';
  EXCEPTION WHEN OTHERS THEN v_promo_value := 20;
  END;
  IF v_promo_value IS NULL THEN v_promo_value := 20; END IF;

  -- Try up to 20 times to generate a unique code
  FOR i IN 1..20 LOOP
    -- Generate 6-character alphanumeric code without similar characters
    v_code := 'FAST';
    FOR j IN 1..v_code_length LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars)) + 1, 1);
    END LOOP;
    
    -- Check if code already exists in referral_codes table
    SELECT COUNT(*) INTO v_exists FROM referral_codes WHERE code = v_code;
    
    IF v_exists = 0 THEN
      -- Insert into referral_codes table
      INSERT INTO referral_codes (user_id, code, promo_value, promo_type)
      VALUES (p_user_id, v_code, v_promo_value, 'fixed');
      
      RETURN v_code;
    END IF;
  END LOOP;
  
  RETURN NULL; -- Failed to generate unique code
END;
$$;

-- Update apply_referral_code function to use referral_codes table
CREATE OR REPLACE FUNCTION apply_referral_code(p_user_id UUID, p_referral_code VARCHAR)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_referrer_id UUID;
  v_referrer_points INTEGER;
  v_referrer_current_points INTEGER;
  v_new_user_points INTEGER;
  v_points_per_referral INTEGER := 50;
  v_new_user_bonus INTEGER := 25;
BEGIN
  -- Validate code format (FAST + 6 alphanumeric characters without I, 1, O, 0)
  IF p_referral_code !~ '^FAST[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الدعوة غير صالح');
  END IF;
  
  -- Check if user already was referred
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id AND referred_by IS NOT NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'لقد استخدمت كود دعوة بالفعل');
  END IF;
  
  -- Find referrer from referral_codes table
  SELECT user_id INTO v_referrer_id FROM referral_codes WHERE code = p_referral_code;
  
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الدعوة غير موجود');
  END IF;
  
  IF v_referrer_id = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكنك استخدام كود الدعوة الخاص بك');
  END IF;
  
  -- Get current points
  SELECT referral_points INTO v_referrer_current_points FROM profiles WHERE id = v_referrer_id;
  
  -- Update referrer
  UPDATE profiles 
  SET 
    referral_points = COALESCE(referral_points, 0) + v_points_per_referral,
    referrals_count = COALESCE(referrals_count, 0) + 1
  WHERE id = v_referrer_id;
  
  -- Update new user
  UPDATE profiles 
  SET 
    referred_by = p_referral_code,
    referral_points = COALESCE(referral_points, 0) + v_new_user_bonus
  WHERE id = p_user_id;
  
  -- Log referral use
  INSERT INTO referral_uses (referrer_id, referred_id, code_used, reward_given_referrer, reward_given_referred)
  VALUES (v_referrer_id, p_user_id, p_referral_code, v_points_per_referral, v_new_user_bonus);
  
  RETURN jsonb_build_object(
    'success', true, 
    'referrer_points', v_referrer_current_points + v_points_per_referral,
    'new_user_points', v_new_user_bonus,
    'message', 'تم تطبيق كود الدعوة بنجاح'
  );
END;
$$;
