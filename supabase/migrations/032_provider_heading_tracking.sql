-- Migration: Add provider heading/bearing tracking
-- This tracks the direction the provider is facing (compass heading)
-- Used to show direction indicator on client's map

-- Add heading column to provider_profiles
ALTER TABLE provider_profiles
ADD COLUMN IF NOT EXISTS heading DECIMAL(5, 2) DEFAULT 0;

-- Add heading column to provider_locations for real-time tracking
ALTER TABLE provider_locations
ADD COLUMN IF NOT EXISTS heading DECIMAL(5, 2) DEFAULT 0;

-- Comment on columns
COMMENT ON COLUMN provider_profiles.heading IS 'Compass heading in degrees (0-360). 0 = North, 90 = East, 180 = South, 270 = West';
COMMENT ON COLUMN provider_locations.heading IS 'Real-time compass heading for tracking';
