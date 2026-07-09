-- 1. Notification trigger for chat messages
CREATE OR REPLACE FUNCTION notify_chat_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    supabase_url TEXT;
    service_key TEXT;
BEGIN
    supabase_url := current_setting('app.supabase_url', true);
    service_key := current_setting('app.service_role_key', true);
    
    IF supabase_url IS NOT NULL AND service_key IS NOT NULL THEN
        PERFORM net.http_post(
            url := supabase_url || '/functions/v1/order-notification-trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'table', 'chat_messages',
                'type', 'INSERT',
                'record', row_to_json(NEW)
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_message ON chat_messages;
CREATE TRIGGER on_chat_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION notify_chat_message();

-- 2. Notification trigger for bookings
CREATE OR REPLACE FUNCTION notify_booking_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    supabase_url TEXT;
    service_key TEXT;
BEGIN
    supabase_url := current_setting('app.supabase_url', true);
    service_key := current_setting('app.service_role_key', true);
    
    IF supabase_url IS NOT NULL AND service_key IS NOT NULL THEN
        PERFORM net.http_post(
            url := supabase_url || '/functions/v1/order-notification-trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'table', 'bookings',
                'type', CASE WHEN TG_OP = 'INSERT' THEN 'INSERT' ELSE 'UPDATE' END,
                'record', row_to_json(NEW)
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_booking_change ON bookings;
CREATE TRIGGER on_booking_change
    AFTER INSERT OR UPDATE OF status ON bookings
    FOR EACH ROW EXECUTE FUNCTION notify_booking_event();

-- 3. Add InstaPay settings to app_settings if not exists
INSERT INTO app_settings (key, value, description)
VALUES 
('instapay_number', '010254464646', 'رقم انستا باي لتوريد العمولات'),
('instapay_name', 'Faster App Support', 'اسم الحساب في انستا باي')
ON CONFLICT (key) DO NOTHING;
