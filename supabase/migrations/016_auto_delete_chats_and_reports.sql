-- Migration: Auto-delete chat messages 30 days after service completion
-- Also adds report fields to admin_warnings and is_report column

-- 1. Add is_report column to admin_warnings if not exists
ALTER TABLE admin_warnings ADD COLUMN IF NOT EXISTS is_report BOOLEAN DEFAULT false;
ALTER TABLE admin_warnings ADD COLUMN IF NOT EXISTS reported_by UUID REFERENCES profiles(id);
ALTER TABLE admin_warnings ADD COLUMN IF NOT EXISTS comment TEXT;

-- 2. Add completed_at index for efficient chat cleanup queries
CREATE INDEX IF NOT EXISTS idx_bookings_completed_at ON bookings(completed_at) WHERE status = 'completed';

-- 3. Function to auto-delete chat messages 30 days after booking completion
CREATE OR REPLACE FUNCTION auto_delete_old_chat_messages()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Delete chat messages where the associated booking was completed more than 30 days ago
    DELETE FROM chat_messages
    WHERE created_at < NOW() - INTERVAL '30 days'
    AND (
        -- Sender is the client of a completed booking
        sender_id IN (
            SELECT b.client_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
        )
        OR sender_id IN (
            SELECT b.provider_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
            AND b.provider_id IS NOT NULL
        )
        OR receiver_id IN (
            SELECT b.client_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
        )
        OR receiver_id IN (
            SELECT b.provider_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
            AND b.provider_id IS NOT NULL
        )
    );
END;
$$;

-- 4. Schedule the cleanup using pg_cron (if available)
-- This requires pg_cron extension to be enabled in Supabase
-- If pg_cron is not available, this will be called from the app periodically
-- Uncomment the following lines if pg_cron is enabled:
-- SELECT cron.schedule(
--     'auto-delete-old-chats',
--     '0 3 * * *',  -- Run daily at 3 AM UTC
--     $$ SELECT auto_delete_old_chat_messages(); $$
-- );

-- 5. Add chat_messages cleanup tracking
CREATE TABLE IF NOT EXISTS chat_cleanup_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    messages_deleted INT NOT NULL DEFAULT 0,
    ran_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Function that logs the cleanup
CREATE OR REPLACE FUNCTION auto_delete_old_chat_messages_with_log()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    deleted_count INT;
BEGIN
    DELETE FROM chat_messages
    WHERE created_at < NOW() - INTERVAL '30 days'
    AND (
        sender_id IN (
            SELECT b.client_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
        )
        OR sender_id IN (
            SELECT b.provider_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
            AND b.provider_id IS NOT NULL
        )
        OR receiver_id IN (
            SELECT b.client_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
        )
        OR receiver_id IN (
            SELECT b.provider_id FROM bookings b
            WHERE b.status = 'completed'
            AND b.completed_at < NOW() - INTERVAL '30 days'
            AND b.provider_id IS NOT NULL
        )
    );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    INSERT INTO chat_cleanup_log (messages_deleted) VALUES (deleted_count);
END;
$$;

-- 7. Add booking_id column to chat_messages for easier cleanup
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES bookings(id);

-- 8. Function to link chat messages to bookings
CREATE OR REPLACE FUNCTION link_chat_to_booking()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Try to find a booking between sender and receiver
    UPDATE chat_messages
    SET booking_id = (
        SELECT b.id FROM bookings b
        WHERE 
            (b.client_id = NEW.sender_id OR b.client_id = NEW.receiver_id)
            AND (b.provider_id = NEW.sender_id OR b.provider_id = NEW.receiver_id)
        ORDER BY b.created_at DESC
        LIMIT 1
    )
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_message_link ON chat_messages;
CREATE TRIGGER on_chat_message_link
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION link_chat_to_booking();

-- 9. Simplified cleanup function using booking_id
CREATE OR REPLACE FUNCTION cleanup_expired_chats()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    deleted_count INT;
BEGIN
    -- Delete messages linked to bookings completed > 30 days ago
    DELETE FROM chat_messages
    WHERE booking_id IN (
        SELECT id FROM bookings
        WHERE status = 'completed'
        AND completed_at < NOW() - INTERVAL '30 days'
    );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Also delete orphaned messages older than 30 days (not linked to any booking)
    DELETE FROM chat_messages
    WHERE booking_id IS NULL
    AND created_at < NOW() - INTERVAL '30 days';
    
    INSERT INTO chat_cleanup_log (messages_deleted) VALUES (deleted_count);
END;
$$;
