-- Add is_urgent column to bookings table
-- This column marks bookings that need immediate service (حالاً option)

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN DEFAULT false;

-- Add index for faster queries on urgent bookings
CREATE INDEX IF NOT EXISTS idx_bookings_is_urgent ON bookings(is_urgent);

-- Add comment
COMMENT ON COLUMN bookings.is_urgent IS 'Indicates if the booking needs immediate service (حالاً option)';
