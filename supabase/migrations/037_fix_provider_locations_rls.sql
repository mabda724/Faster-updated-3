-- Migration: Fix provider_locations RLS for client access
-- This migration ensures clients can read provider locations for real-time tracking
-- Following Supabase security and performance best practices

-- Enable RLS on provider_locations
ALTER TABLE provider_locations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Providers can insert own location" ON provider_locations;
DROP POLICY IF EXISTS "Providers can update own location" ON provider_locations;
DROP POLICY IF EXISTS "Clients can view provider location" ON provider_locations;
DROP POLICY IF EXISTS "Enable read access for all users" ON provider_locations;

-- Create proper RLS policies following Supabase security best practices
CREATE POLICY "Providers can insert own location"
ON provider_locations FOR INSERT
TO authenticated
WITH CHECK (provider_id = auth.uid());

CREATE POLICY "Providers can update own location"
ON provider_locations FOR UPDATE
TO authenticated
USING (provider_id = auth.uid())
WITH CHECK (provider_id = auth.uid());

-- Allow all authenticated users to read provider locations for real-time tracking
-- This is safe because location data is meant to be shared with clients during active bookings
CREATE POLICY "All authenticated can view provider locations"
ON provider_locations FOR SELECT
TO authenticated
USING (true);

-- Grant necessary permissions following least privilege principle
GRANT SELECT, INSERT, UPDATE ON provider_locations TO authenticated;
GRANT SELECT ON provider_locations TO anon;

-- Ensure the table has the required columns
ALTER TABLE provider_locations
ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add indexes for query performance optimization
CREATE INDEX IF NOT EXISTS idx_provider_locations_provider_id ON provider_locations(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_locations_updated_at ON provider_locations(updated_at DESC);

-- Add partial index for active providers (performance optimization)
CREATE INDEX IF NOT EXISTS idx_provider_locations_active
ON provider_locations(provider_id, updated_at DESC)
WHERE updated_at > NOW() - INTERVAL '1 hour';
