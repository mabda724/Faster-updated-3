-- Create missing tables for referral/points system

-- Generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INT, 1);
  END LOOP;
  RETURN result;
END;
$$;

-- Referral codes table
CREATE TABLE IF NOT EXISTS referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  code TEXT UNIQUE NOT NULL DEFAULT generate_referral_code(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Referrals tracking
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  referred_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  points_awarded INTEGER DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User points
CREATE TABLE IF NOT EXISTS user_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  points INTEGER DEFAULT 0,
  lifetime_points INTEGER DEFAULT 0,
  redeemed_points INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add referral_code_used to profiles for signup tracking
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by TEXT;

-- Auto-create referral code on profile insert (safe version)
CREATE OR REPLACE FUNCTION auto_create_referral()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    INSERT INTO referral_codes (user_id) VALUES (NEW.id);
  EXCEPTION WHEN OTHERS THEN
  END;
  BEGIN
    INSERT INTO user_points (user_id) VALUES (NEW.id);
  EXCEPTION WHEN OTHERS THEN
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_referral ON profiles;
CREATE TRIGGER trg_auto_referral
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION auto_create_referral();

-- Award points when referral is used
CREATE OR REPLACE FUNCTION award_referral_points()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE user_points SET points = points + 50, lifetime_points = lifetime_points + 50, updated_at = NOW()
  WHERE user_id = NEW.referrer_id;
  UPDATE user_points SET points = points + 25, lifetime_points = lifetime_points + 25, updated_at = NOW()
  WHERE user_id = NEW.referred_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_points ON referrals;
CREATE TRIGGER trg_award_points
  AFTER INSERT ON referrals
  FOR EACH ROW EXECUTE FUNCTION award_referral_points();

-- Disable RLS for simplicity
ALTER TABLE referral_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE referrals DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_points DISABLE ROW LEVEL SECURITY;

-- Grant access
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
