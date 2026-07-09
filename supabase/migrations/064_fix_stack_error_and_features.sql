-- Migration 021: Fix recursive trigger and add advanced features

-- 1. Absolute Fix for Recursive Trigger
-- This removes the table-wide update from the row-level trigger which caused "stack depth limit exceeded"
-- because updating bookings would trigger this function again for every row.

DROP TRIGGER IF EXISTS on_booking_expiration ON public.bookings;

CREATE OR REPLACE FUNCTION public.check_booking_expiration()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- We REMOVED the UPDATE bookings ... WHERE ... block that caused recursion.
    -- Expiration of other rows should be handled by a cron job or a specific cleanup RPC.

    -- We only check and modify the CURRENT row (NEW) if it meets the expiration criteria.
    IF NEW.provider_id IS NULL AND NEW.status = 'pending' AND NEW.created_at < NOW() - INTERVAL '15 minutes' THEN
        NEW.status := 'cancelled';
        NEW.updated_at := NOW();
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER on_booking_expiration
    BEFORE INSERT OR UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.check_booking_expiration();

-- 2. Add Admin Bank Accounts Table
CREATE TABLE IF NOT EXISTS public.admin_bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name TEXT NOT NULL,
    account_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for admin_bank_accounts
ALTER TABLE public.admin_bank_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view active bank accounts" ON public.admin_bank_accounts FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage bank accounts" ON public.admin_bank_accounts FOR ALL USING (
    auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin')
);

-- 3. Update Notifications and Admin Broadcasts with advanced fields
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS action_type TEXT,
ADD COLUMN IF NOT EXISTS action_data JSONB,
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS video_url TEXT,
ADD COLUMN IF NOT EXISTS sound TEXT;

ALTER TABLE public.admin_broadcasts
ADD COLUMN IF NOT EXISTS action_type TEXT,
ADD COLUMN IF NOT EXISTS action_data JSONB,
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS video_url TEXT;

-- 4. Update send_admin_broadcast function to support new fields
CREATE OR REPLACE FUNCTION public.send_admin_broadcast(
  p_title TEXT,
  p_body TEXT,
  p_target TEXT,
  p_admin_id UUID,
  p_action_type TEXT DEFAULT NULL,
  p_action_data JSONB DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_video_url TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  -- Insert into admin_broadcasts log
  INSERT INTO public.admin_broadcasts (title, body, target, admin_id, created_at, action_type, action_data, image_url, video_url)
  VALUES (p_title, p_body, p_target, p_admin_id, NOW(), p_action_type, p_action_data, p_image_url, p_video_url);

  -- Create user notifications for targets
  IF p_target = 'all' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
    SELECT id, p_title, p_body, 'system', false, NOW(), p_action_type, p_action_data, p_image_url, p_video_url
    FROM public.profiles;
  ELSIF p_target = 'clients' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
    SELECT id, p_title, p_body, 'system', false, NOW(), p_action_type, p_action_data, p_image_url, p_video_url
    FROM public.profiles
    WHERE role = 'client';
  ELSIF p_target = 'providers' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
    SELECT id, p_title, p_body, 'system', false, NOW(), p_action_type, p_action_data, p_image_url, p_video_url
    FROM public.profiles
    WHERE role = 'provider';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
