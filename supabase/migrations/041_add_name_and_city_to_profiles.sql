-- =====================================================
-- MIGRATION 041: Add name and city to profiles
-- =====================================================
-- This migration adds:
-- 1. full_name column to profiles table (if not exists)
-- 2. city column to profiles table (if not exists)
-- These fields are needed for the new login flow

-- Add full_name column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Add city column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS city TEXT;

-- Create index on city for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_city ON profiles(city) WHERE city IS NOT NULL;

-- Add comment to columns
COMMENT ON COLUMN profiles.full_name IS 'Full name of the user';
COMMENT ON COLUMN profiles.city IS 'City where the user is located';
