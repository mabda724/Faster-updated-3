-- Migration: Fix notifications RLS and type constraint
-- This migration fixes:
-- 1. RLS policy that prevents inserting notifications
-- 2. Type constraint to allow dynamic types like order_status-accepted
-- 3. Ensure all notification functions work correctly

-- Drop existing type constraint to allow more flexible types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new check constraint with broader pattern matching
-- This allows types like: order_status, order_status-accepted, new_booking, etc.
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check
CHECK (
  type ~ '^(booking|payment|review|general|system|order_status|new_booking|price_offer|price_offer_response|price_suggestion|free_service|settlement|chat_message|withdrawal_request|withdrawal_update|order_status-[a-z_]+)$'
);

-- Fix RLS policies for notifications table
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;

-- Create proper RLS policies
CREATE POLICY "Users can insert notifications"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO anon;

-- Ensure RLS is enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Update the send_notification_to_user function to handle types correctly
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

-- Grant execute on the function
GRANT EXECUTE ON FUNCTION send_notification_to_user(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
