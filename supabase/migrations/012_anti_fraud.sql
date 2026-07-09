-- Anti-Fraud & Evidence System
-- Adds columns for location proof, photo evidence, and status timeline

-- GPS coordinates when provider arrived at client location
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS arrived_lat DOUBLE PRECISION;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS arrived_lng DOUBLE PRECISION;

-- GPS coordinates when booking was completed
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS completed_lat DOUBLE PRECISION;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS completed_lng DOUBLE PRECISION;

-- URLs of completion evidence photos
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS completion_photo_urls TEXT[] DEFAULT '{}';

-- Full status change audit trail: [{status, timestamp, lat, lng, note}]
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS status_timeline JSONB DEFAULT '[]'::jsonb;

-- Client GPS at time of booking creation
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS client_lat DOUBLE PRECISION;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS client_lng DOUBLE PRECISION;

-- Dispute evidence fields
ALTER TABLE public.refund_requests ADD COLUMN IF NOT EXISTS client_evidence_urls TEXT[] DEFAULT '{}';
ALTER TABLE public.refund_requests ADD COLUMN IF NOT EXISTS provider_evidence_urls TEXT[] DEFAULT '{}';
ALTER TABLE public.refund_requests ADD COLUMN IF NOT EXISTS admin_notes TEXT;
ALTER TABLE public.refund_requests ADD COLUMN IF NOT EXISTS booking_snapshot JSONB;

-- Function to append to status_timeline
CREATE OR REPLACE FUNCTION append_status_timeline()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  new_entry JSONB;
  current_pos_lat DOUBLE PRECISION;
  current_pos_lng DOUBLE PRECISION;
BEGIN
  -- Get current position from provider_profiles if available
  IF NEW.provider_id IS NOT NULL THEN
    SELECT latitude, longitude INTO current_pos_lat, current_pos_lng
    FROM provider_profiles WHERE id = NEW.provider_id;
  END IF;

  new_entry := jsonb_build_object(
    'status', NEW.status,
    'timestamp', NOW(),
    'lat', current_pos_lat,
    'lng', current_pos_lng
  );

  NEW.status_timeline := COALESCE(OLD.status_timeline, '[]'::jsonb) || new_entry;

  -- Record location when arriving
  IF NEW.status = 'arrived' AND current_pos_lat IS NOT NULL THEN
    NEW.arrived_lat := current_pos_lat;
    NEW.arrived_lng := current_pos_lng;
  END IF;

  -- Record location when completing
  IF NEW.status = 'completed' AND current_pos_lat IS NOT NULL THEN
    NEW.completed_lat := current_pos_lat;
    NEW.completed_lng := current_pos_lng;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger to auto-record timeline on status change
DROP TRIGGER IF EXISTS trg_status_timeline ON public.bookings;
CREATE TRIGGER trg_status_timeline
  BEFORE UPDATE OF status ON public.bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION append_status_timeline();

-- Index on status_timeline for faster queries
CREATE INDEX IF NOT EXISTS idx_bookings_status_timeline ON public.bookings USING gin (status_timeline);
