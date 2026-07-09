-- Migration 022: Fix arrival_verification_code being NULL

-- 1. Ensure the column exists (it should, but let's be safe)
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS arrival_verification_code TEXT;

-- 2. Create a function to generate a random 6-digit code if one doesn't exist
CREATE OR REPLACE FUNCTION public.ensure_arrival_verification_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.arrival_verification_code IS NULL THEN
    NEW.arrival_verification_code := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Add trigger to bookings table to auto-generate the code on INSERT
DROP TRIGGER IF EXISTS trg_ensure_arrival_code ON public.bookings;
CREATE TRIGGER trg_ensure_arrival_code
  BEFORE INSERT ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.ensure_arrival_verification_code();

-- 4. Update existing bookings that have NULL codes
UPDATE public.bookings
SET arrival_verification_code = lpad((floor(random() * 900000) + 100000)::int::text, 6, '0')
WHERE arrival_verification_code IS NULL;

-- 5. Update accept_broadcast_booking to ensure code is present (optional but good practice)
CREATE OR REPLACE FUNCTION public.accept_broadcast_booking(p_booking_id UUID, p_provider_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_provider UUID;
BEGIN
  -- Check if booking still has no provider
  SELECT provider_id INTO v_current_provider FROM public.bookings WHERE id = p_booking_id FOR UPDATE;

  IF v_current_provider IS NULL THEN
    UPDATE public.bookings
    SET
      provider_id = p_provider_id,
      status = 'accepted',
      accepted_at = NOW(),
      -- Ensure code exists even if trigger somehow missed it
      arrival_verification_code = COALESCE(arrival_verification_code, lpad((floor(random() * 900000) + 100000)::int::text, 6, '0'))
    WHERE id = p_booking_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
