-- Add onesignal_id column to profiles table
-- This column stores the OneSignal user ID for each user
-- Used for sending push notifications via OneSignal

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS onesignal_id TEXT;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_onesignal_id ON profiles(onesignal_id);

-- Add comment
COMMENT ON COLUMN profiles.onesignal_id IS 'OneSignal user ID for push notifications';
