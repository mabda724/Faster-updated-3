-- Migration: Fix notifications type check constraint
-- Add new notification types to support all app features

-- Drop the old check constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new check constraint with all supported types
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check
CHECK (type IN (
  'booking',
  'payment',
  'review',
  'general',
  'system',
  'order_status',
  'new_booking',
  'price_offer',
  'price_offer_response',
  'price_suggestion',
  'free_service',
  'settlement',
  'chat_message',
  'withdrawal_request',
  'withdrawal_update'
));

-- Update RLS policy to allow authenticated users to insert notifications
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
CREATE POLICY "Users can insert notifications"
ON notifications FOR INSERT
WITH CHECK (true);

-- Update RLS policy to allow authenticated users to update notifications
DROP POLICY IF EXISTS "Users can update notifications" ON notifications;
CREATE POLICY "Users can update notifications"
ON notifications FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
