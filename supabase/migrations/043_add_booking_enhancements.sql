-- =====================================================
-- MIGRATION 043: Add booking enhancements
-- =====================================================
-- This migration adds:
-- 1. description field to bookings (problem description)
-- 2. images field to bookings (array of image URLs)
-- 3. scheduled_type field to bookings (now, in_2_hours, later)
-- 4. started_at field to bookings (when service started)
-- 5. additional_costs field to bookings (JSON array of additional costs)

-- Add description field to bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS description TEXT;

-- Add images field to bookings (array of URLs)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS images TEXT[];

-- Add scheduled_type field to bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS scheduled_type TEXT DEFAULT 'now'
CHECK (scheduled_type IN ('now', 'in_2_hours', 'later'));

-- Add started_at field to bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;

-- Add additional_costs field to bookings (JSON array)
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS additional_costs JSONB DEFAULT '[]'::jsonb;

-- Add comments to new columns
COMMENT ON COLUMN bookings.description IS 'Problem description provided by client';
COMMENT ON COLUMN bookings.images IS 'Array of image URLs uploaded by client';
COMMENT ON COLUMN bookings.scheduled_type IS 'Schedule type: now, in_2_hours, or later';
COMMENT ON COLUMN bookings.started_at IS 'Timestamp when the service started';
COMMENT ON COLUMN bookings.additional_costs IS 'JSON array of additional costs with approval status';

-- Create index on scheduled_type for faster queries
CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_type ON bookings(scheduled_type);

-- Create index on started_at for tracking service duration
CREATE INDEX IF NOT EXISTS idx_bookings_started_at ON bookings(started_at) WHERE started_at IS NOT NULL;

-- Create trigger to auto-set started_at when status changes to in_progress
CREATE OR REPLACE FUNCTION set_started_at_on_in_progress()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'in_progress' AND OLD.status != 'in_progress' THEN
    NEW.started_at := COALESCE(NEW.started_at, NOW());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_booking_status_change ON bookings;
CREATE TRIGGER on_booking_status_change
BEFORE UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION set_started_at_on_in_progress();
