-- Referral Code System
-- Add referral code generation and tracking

-- Add columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS referral_code VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS referred_by VARCHAR(10),
ADD COLUMN IF NOT EXISTS referral_points INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS referrals_count INTEGER DEFAULT 0;

-- Create function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_code TEXT;
  v_exists INTEGER;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Removed similar characters (I, 1, O, 0)
  v_code_length INTEGER := 6;
BEGIN
  -- Try up to 20 times to generate a unique code
  FOR i IN 1..20 LOOP
    -- Generate 6-character alphanumeric code without similar characters
    v_code := '';
    FOR j IN 1..v_code_length LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars)) + 1, 1);
    END LOOP;
    
    -- Check if code already exists
    SELECT COUNT(*) INTO v_exists FROM profiles WHERE referral_code = v_code;
    
    IF v_exists = 0 THEN
      -- Update user's profile with the code
      UPDATE profiles 
      SET referral_code = v_code 
      WHERE id = p_user_id;
      
      RETURN v_code;
    END IF;
  END LOOP;
  
  RETURN NULL; -- Failed to generate unique code
END;
$$;

-- Create function to apply referral code
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
  -- Validate code format (6 alphanumeric characters without I, 1, O, 0)
  IF p_referral_code !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الدعوة غير صالح');
  END IF;
  
  -- Check if user already has a referral code or was referred
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id AND (referral_code IS NOT NULL OR referred_by IS NOT NULL)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'لقد استخدمت كود دعوة بالفعل');
  END IF;
  
  -- Find referrer
  SELECT id INTO v_referrer_id FROM profiles WHERE referral_code = p_referral_code;
  
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
  
  -- Log referral transaction (optional - create referral_transactions table if needed)
  -- For now, just return success
  
  RETURN jsonb_build_object(
    'success', true, 
    'referrer_points', v_referrer_current_points + v_points_per_referral,
    'new_user_points', v_new_user_bonus,
    'message', 'تم تطبيق كود الدعوة بنجاح'
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_referral_code(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_referral_code(UUID, VARCHAR) TO authenticated;

-- Add index on referral_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
