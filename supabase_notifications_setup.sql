-- Add triggers to insert into notifications table automatically

-- 1. Trigger for Booking Status Changes
CREATE OR REPLACE FUNCTION create_booking_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    target_user_id UUID;
    v_title TEXT;
    v_message TEXT;
BEGIN
    -- Determine who to notify
    IF NEW.status != OLD.status THEN
        -- If status changed
        IF NEW.status = 'accepted' THEN
            target_user_id := NEW.client_id;
            v_title := 'تم قبول طلبك';
            v_message := 'وافق مقدم الخدمة على طلبك وهو الآن يجهز نفسه.';
        ELSIF NEW.status = 'on_the_way' THEN
            target_user_id := NEW.client_id;
            v_title := 'مقدم الخدمة في الطريق';
            v_message := 'تحرك مقدم الخدمة باتجاه موقعك الآن.';
        ELSIF NEW.status = 'arrived' THEN
            target_user_id := NEW.client_id;
            v_title := 'وصل مقدم الخدمة';
            v_message := 'مقدم الخدمة وصل إلى موقعك الآن.';
        ELSIF NEW.status = 'completed' THEN
            target_user_id := NEW.client_id;
            v_title := 'اكتملت الخدمة';
            v_message := 'نتمنى أن تكون الخدمة نالت إعجابك. يرجى تقييم مقدم الخدمة.';
        ELSIF NEW.status = 'rejected' THEN
            target_user_id := NEW.client_id;
            v_title := 'نعتذر، تم رفض الطلب';
            v_message := 'نعتذر منك، لم يتمكن مقدم الخدمة من قبول طلبك حالياً.';
        END IF;

        -- Insert notification if we have a target
        IF target_user_id IS NOT NULL THEN
            INSERT INTO notifications (user_id, type, title, message, data)
            VALUES (target_user_id, 'booking', v_title, v_message, jsonb_build_object('booking_id', NEW.id, 'status', NEW.status));
        END IF;
    END IF;

    -- Special case: New Booking for Provider (Direct Booking)
    IF TG_OP = 'INSERT' AND NEW.provider_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (NEW.provider_id, 'booking', 'طلب جديد', 'لديك طلب خدمة جديد بانتظار موافقتك.', jsonb_build_object('booking_id', NEW.id, 'status', NEW.status));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_booking_notification ON bookings;
CREATE TRIGGER on_booking_notification
    AFTER INSERT OR UPDATE OF status ON bookings
    FOR EACH ROW EXECUTE FUNCTION create_booking_notification();

-- 2. Trigger for Chat Messages
CREATE OR REPLACE FUNCTION create_chat_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO notifications (user_id, type, title, message, data)
    VALUES (
        NEW.receiver_id, 
        'chat', 
        'رسالة جديدة', 
        'وصلتك رسالة جديدة: ' || LEFT(NEW.text, 50), 
        jsonb_build_object('sender_id', NEW.sender_id, 'text', NEW.text)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_notification ON chat_messages;
CREATE TRIGGER on_chat_notification
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION create_chat_notification();

-- Enable Realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
