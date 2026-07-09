-- Migration 039: Admin Notifications Enhancements
-- Adds: scheduling, service linking, offer linking, reuse

-- 1. Add columns to admin_broadcasts for scheduling and linking
ALTER TABLE public.admin_broadcasts
ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS offer_id UUID REFERENCES public.offers(id) ON DELETE SET NULL;

-- 2. Update send_admin_broadcast to support scheduling and service linking
CREATE OR REPLACE FUNCTION public.send_admin_broadcast(
  p_title TEXT,
  p_body TEXT,
  p_target TEXT,
  p_admin_id UUID,
  p_action_type TEXT DEFAULT NULL,
  p_action_data JSONB DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_video_url TEXT DEFAULT NULL,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_service_id UUID DEFAULT NULL,
  p_offer_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_is_scheduled BOOLEAN;
BEGIN
  v_is_scheduled := p_scheduled_at IS NOT NULL AND p_scheduled_at > v_now;

  -- Insert into admin_broadcasts log
  INSERT INTO public.admin_broadcasts (title, body, target, admin_id, created_at, action_type, action_data, image_url, video_url, scheduled_at, service_id, offer_id)
  VALUES (p_title, p_body, p_target, p_admin_id, v_now, p_action_type, p_action_data, p_image_url, p_video_url, p_scheduled_at, p_service_id, p_offer_id);

  -- Only create user notifications if NOT scheduled (scheduled ones are processed by process_scheduled_broadcasts)
  IF NOT v_is_scheduled THEN
    IF p_target = 'all' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, p_title, p_body, 'system', false, v_now, p_action_type, p_action_data, p_image_url, p_video_url
      FROM public.profiles;
    ELSIF p_target = 'clients' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, p_title, p_body, 'system', false, v_now, p_action_type, p_action_data, p_image_url, p_video_url
      FROM public.profiles
      WHERE role = 'client';
    ELSIF p_target = 'providers' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, p_title, p_body, 'system', false, v_now, p_action_type, p_action_data, p_image_url, p_video_url
      FROM public.profiles
      WHERE role = 'provider';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Function to process scheduled broadcasts
CREATE OR REPLACE FUNCTION public.process_scheduled_broadcasts()
RETURNS TABLE(processed_count BIGINT) AS $$
DECLARE
  v_count BIGINT := 0;
  v_rec RECORD;
BEGIN
  FOR v_rec IN
    SELECT * FROM public.admin_broadcasts
    WHERE scheduled_at IS NOT NULL
      AND scheduled_at <= NOW()
    ORDER BY scheduled_at ASC
  LOOP
    -- Insert notifications for each target
    IF v_rec.target = 'all' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, v_rec.title, v_rec.body, 'system', false, NOW(), v_rec.action_type, v_rec.action_data, v_rec.image_url, v_rec.video_url
      FROM public.profiles;
    ELSIF v_rec.target = 'clients' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, v_rec.title, v_rec.body, 'system', false, NOW(), v_rec.action_type, v_rec.action_data, v_rec.image_url, v_rec.video_url
      FROM public.profiles
      WHERE role = 'client';
    ELSIF v_rec.target = 'providers' THEN
      INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at, action_type, action_data, image_url, video_url)
      SELECT id, v_rec.title, v_rec.body, 'system', false, NOW(), v_rec.action_type, v_rec.action_data, v_rec.image_url, v_rec.video_url
      FROM public.profiles
      WHERE role = 'provider';
    END IF;

    -- Clear scheduled_at so it won't be processed again
    UPDATE public.admin_broadcasts
    SET scheduled_at = NULL
    WHERE id = v_rec.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN QUERY SELECT v_count AS processed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Function to send document verification notification to provider
CREATE OR REPLACE FUNCTION public.notify_provider_document_verification(
  p_provider_id UUID,
  p_status TEXT,
  p_rejection_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_title TEXT;
  v_message TEXT;
  v_type TEXT;
BEGIN
  IF p_status = 'approved' THEN
    v_title := 'تم توثيق المستندات';
    v_message := 'تمت الموافقة على مستنداتك بنجاح. يمكنك الآن تقديم الخدمات للعملاء.';
    v_type := 'document_verified';
  ELSIF p_status = 'rejected' THEN
    v_title := 'تم رفض المستندات';
    v_message := 'لم تتم الموافقة على مستنداتك.' || COALESCE(' سبب الرفض: ' || p_rejection_reason, ' يرجى إعادة رفع المستندات الصحيحة.');
    v_type := 'document_rejected';
  ELSE
    RETURN;
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
  VALUES (p_provider_id, v_title, v_message, v_type, false, NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;