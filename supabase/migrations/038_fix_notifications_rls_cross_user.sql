-- Migration: Fix notifications RLS to allow cross-user notifications
-- This migration fixes the RLS policy to allow users to send notifications to other users
-- This is necessary for chat messages, status updates, and other cross-user notifications

-- Drop the restrictive INSERT policy
DROP POLICY IF EXISTS "Users can insert own notifications" ON notifications;

-- Create a more permissive INSERT policy that allows cross-user notifications
-- This is safe because notifications are one-way communication (user_id is the recipient)
CREATE POLICY "Users can insert notifications"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);

-- Keep the SELECT, UPDATE, DELETE policies restricted to own notifications
-- These should remain as-is for security
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Ensure RLS is enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
