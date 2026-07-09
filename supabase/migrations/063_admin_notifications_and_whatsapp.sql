-- Migration 020: Admin Notifications Broadcast & WhatsApp settings helpers
-- 1. Create a function to handle broadcasting admin notifications in a scalable, atomic transaction.
CREATE OR REPLACE FUNCTION public.send_admin_broadcast(
  p_title TEXT,
  p_body TEXT,
  p_target TEXT,
  p_admin_id UUID
) RETURNS VOID AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Insert into admin_broadcasts log
  INSERT INTO public.admin_broadcasts (title, body, target, admin_id, created_at)
  VALUES (p_title, p_body, p_target, p_admin_id, NOW());

  -- Create user notifications for targets
  IF p_target = 'all' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
    SELECT id, p_title, p_body, 'system', false, NOW()
    FROM public.profiles;
  ELSIF p_target = 'clients' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
    SELECT id, p_title, p_body, 'system', false, NOW()
    FROM public.profiles
    WHERE role = 'client';
  ELSIF p_target = 'providers' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
    SELECT id, p_title, p_body, 'system', false, NOW()
    FROM public.profiles
    WHERE role = 'provider';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
