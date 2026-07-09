-- Advanced Verification & Anti-Fraud

-- 1. Identity verification level per user
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS verification_level TEXT DEFAULT 'none'
  CHECK (verification_level IN ('none', 'phone', 'email', 'id_uploaded', 'id_verified', 'face_verified', 'fully_verified'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_front_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_back_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS selfie_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address_proof_url TEXT;

-- 2. Device & login tracking
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  device_id TEXT,
  device_name TEXT,
  ip_address TEXT,
  last_login TIMESTAMPTZ DEFAULT NOW(),
  is_trusted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Identity comparison (admin view: ID photo vs selfie)
-- Already have: id_document_url (ID card photo), profile_document_url (selfie) in provider_profiles
-- Add for clients too
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS face_verified BOOLEAN DEFAULT false;
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS face_verified_at TIMESTAMPTZ;

-- 4. Automated fraud detection flags
CREATE TABLE IF NOT EXISTS fraud_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  flag_type TEXT NOT NULL, -- 'duplicate_phone', 'duplicate_id', 'suspicious_ip', 'rapid_bookings', 'multiple_accounts'
  description TEXT,
  severity TEXT DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  is_resolved BOOLEAN DEFAULT false,
  resolved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- 5. Booking verification codes (already have arrival_verification_code)
-- Add client verification at booking
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS client_verified_arrival BOOLEAN DEFAULT false;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS provider_verified_completion BOOLEAN DEFAULT false;

-- 6. Onboarding completion checklist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS accepted_terms_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS accepted_privacy_at TIMESTAMPTZ;

-- 7. Function to detect duplicate accounts
CREATE OR REPLACE FUNCTION check_duplicate_account()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  existing_count INT;
BEGIN
  IF NEW.phone_number IS NOT NULL THEN
    SELECT COUNT(*) INTO existing_count FROM profiles
    WHERE phone_number = NEW.phone_number AND id != NEW.id;
    IF existing_count > 0 THEN
      INSERT INTO fraud_flags (user_id, flag_type, description, severity)
      VALUES (NEW.id, 'duplicate_phone', 'Phone number used by ' || existing_count || ' other account(s)', 'medium');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_duplicate_check ON profiles;
CREATE TRIGGER trg_duplicate_check
  AFTER INSERT OR UPDATE OF phone_number ON profiles
  FOR EACH ROW EXECUTE FUNCTION check_duplicate_account();

-- 8. Admin view: providers pending face verification
CREATE OR REPLACE VIEW pending_face_verification AS
SELECT
  pp.id,
  pr.full_name,
  pp.profession,
  pp.id_document_url,
  pp.profile_document_url,
  pp.document_verification_status,
  pp.face_verified,
  pp.created_at
FROM provider_profiles pp
JOIN profiles pr ON pr.id = pp.id
WHERE pp.document_verification_status = 'pending'
   OR (pp.document_verification_status = 'approved' AND pp.face_verified = false)
ORDER BY pp.created_at ASC;
