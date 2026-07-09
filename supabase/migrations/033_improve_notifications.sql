-- Migration: Improve notification system
-- Add functions to send notifications from database triggers
-- This ensures notifications work even when Supabase Edge Functions are down

-- Function: Send notification to user
CREATE OR REPLACE FUNCTION send_notification_to_user(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_data JSONB DEFAULT '{}'::jsonb
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (p_user_id, p_type, p_title, p_message, p_data);
END;
$$;

-- Trigger: Send notification when booking status changes
CREATE OR REPLACE FUNCTION notify_on_booking_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Only notify on status changes, not inserts
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- Notify client
    IF NEW.client_id IS NOT NULL THEN
      PERFORM send_notification_to_user(
        NEW.client_id,
        'order_status',
        'تحديث حالة الطلب',
        'تم تغيير حالة طلبك إلى ' || NEW.status,
        jsonb_build_object('booking_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
      );
    END IF;

    -- Notify provider
    IF NEW.provider_id IS NOT NULL THEN
      PERFORM send_notification_to_user(
        NEW.provider_id,
        'order_status',
        'تحديث حالة الطلب',
        'تم تغيير حالة الطلب إلى ' || NEW.status,
        jsonb_build_object('booking_id', NEW.id, 'old_status', OLD.status, 'new_status', NEW.status)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_booking_status_change ON bookings;
CREATE TRIGGER on_booking_status_change
AFTER UPDATE OF status ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_on_booking_status_change();

-- Trigger: Send notification when new booking is created
CREATE OR REPLACE FUNCTION notify_on_new_booking()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Notify provider if assigned
  IF NEW.provider_id IS NOT NULL THEN
    PERFORM send_notification_to_user(
      NEW.provider_id,
      'new_booking',
      'طلب جديد',
      'لديك طلب خدمة جديد',
      jsonb_build_object('booking_id', NEW.id, 'service_id', NEW.service_id)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_booking ON bookings;
CREATE TRIGGER on_new_booking
AFTER INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_on_new_booking();

-- Trigger: Send notification when price offer is made
CREATE OR REPLACE FUNCTION notify_on_price_offer()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.offered_price IS NOT NULL AND OLD.offered_price IS NULL THEN
    -- Notify client
    IF NEW.client_id IS NOT NULL THEN
      PERFORM send_notification_to_user(
        NEW.client_id,
        'price_offer',
        'عرض سعر جديد',
        'اقترح مقدم الخدمة سعر ' || NEW.offered_price || ' جنيه',
        jsonb_build_object('booking_id', NEW.id, 'offered_price', NEW.offered_price)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_price_offer ON bookings;
CREATE TRIGGER on_price_offer
AFTER UPDATE OF offered_price ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_on_price_offer();

-- Trigger: Send notification when client suggests price
CREATE OR REPLACE FUNCTION notify_on_client_suggestion()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.client_suggested_price_status = 'pending' AND OLD.client_suggested_price_status != 'pending' THEN
    -- Notify provider
    IF NEW.provider_id IS NOT NULL THEN
      PERFORM send_notification_to_user(
        NEW.provider_id,
        'price_suggestion',
        'اقتراح سعر من العميل',
        'اقترح العميل سعر ' || NEW.client_suggested_price || ' جنيه',
        jsonb_build_object('booking_id', NEW.id, 'suggested_price', NEW.client_suggested_price)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_client_suggestion ON bookings;
CREATE TRIGGER on_client_suggestion
AFTER UPDATE OF client_suggested_price_status ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_on_client_suggestion();

-- Trigger: Send notification when service is marked as free
CREATE OR REPLACE FUNCTION notify_on_free_service()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.is_free = true AND OLD.is_free = false THEN
    -- Notify client
    IF NEW.client_id IS NOT NULL THEN
      PERFORM send_notification_to_user(
        NEW.client_id,
        'free_service',
        'خدمة مجانية',
        'قدم مقدم الخدمة هذه الخدمة مجاناً',
        jsonb_build_object('booking_id', NEW.id)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_free_service ON bookings;
CREATE TRIGGER on_free_service
AFTER UPDATE OF is_free ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_on_free_service();

-- Grant execute permissions on all notification functions
GRANT EXECUTE ON FUNCTION send_notification_to_user(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_on_booking_status_change() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_on_new_booking() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_on_price_offer() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_on_client_suggestion() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_on_free_service() TO authenticated;
