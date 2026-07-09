-- Add 'broadcast' status to bookings status check constraint
-- This allows urgent bookings (حالاً option) to use 'broadcast' status

DO $$
BEGIN
    -- Drop existing constraint
    ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
    
    -- Add the comprehensive constraint with 'broadcast' included
    ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'on_the_way', 'arrived', 'in_progress', 'completed', 'cancelled', 'broadcast'));
EXCEPTION
    WHEN undefined_table THEN
        -- Handle case where bookings table doesn't exist yet
        NULL;
END $$;
