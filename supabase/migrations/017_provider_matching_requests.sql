-- =====================================================
-- MIGRATION 017: Provider matching requests by category + distance
-- =====================================================
-- This migration adds:
-- 1. Function to find matching requests for a provider based on:
--    - Provider's category (specialty)
--    - Distance from provider's location to client's location
-- 2. Configurable search radius stored in provider_profiles
-- 3. Index for faster category-based lookups on bookings

-- Add search_radius_km column to provider_profiles (default 20km)
ALTER TABLE provider_profiles
ADD COLUMN IF NOT EXISTS search_radius_km DOUBLE PRECISION DEFAULT 20;

-- Add index on bookings for faster pending+null-provider lookups
CREATE INDEX IF NOT EXISTS idx_bookings_pending_broadcast
ON bookings (status, service_id)
WHERE provider_id IS NULL AND status = 'pending';

-- =====================================================
-- Function: Find matching requests for a provider
-- Returns pending bookings that:
--   1. Match the provider's category (via service_id → services.category_id)
--   2. Are within the provider's search radius
--   3. Have no provider assigned yet
-- Ordered by distance (nearest first)
-- =====================================================
CREATE OR REPLACE FUNCTION find_matching_requests_for_provider(
  p_provider_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 20
)
RETURNS TABLE(
  id UUID,
  client_id UUID,
  service_id BIGINT,
  status TEXT,
  total_price NUMERIC,
  address TEXT,
  address_details TEXT,
  client_lat DOUBLE PRECISION,
  client_lng DOUBLE PRECISION,
  scheduled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  service_title TEXT,
  service_price NUMERIC,
  category_id BIGINT,
  client_name TEXT,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_provider_category_id BIGINT;
  v_provider_lat DOUBLE PRECISION;
  v_provider_lng DOUBLE PRECISION;
  v_radius DOUBLE PRECISION;
BEGIN
  -- Get provider's category and location
  SELECT category_id, latitude, longitude
  INTO v_provider_category_id, v_provider_lat, v_provider_lng
  FROM provider_profiles
  WHERE id = p_provider_id;

  -- If provider has no category, return nothing (must set category first)
  IF v_provider_category_id IS NULL THEN
    RETURN;
  END IF;

  -- Use provider's custom radius if p_radius_km is default (20), otherwise use the provided value
  IF p_radius_km = 20 THEN
    SELECT COALESCE(search_radius_km, 20) INTO v_radius
    FROM provider_profiles
    WHERE id = p_provider_id;
  ELSE
    v_radius := p_radius_km;
  END IF;

  -- If provider has no location, return requests matching category only (no distance filter)
  IF v_provider_lat IS NULL OR v_provider_lng IS NULL THEN
    RETURN QUERY
    SELECT
      b.id,
      b.client_id,
      b.service_id,
      b.status,
      b.total_price,
      b.address,
      b.address_details,
      b.client_lat,
      b.client_lng,
      b.scheduled_at,
      b.created_at,
      s.title AS service_title,
      s.price AS service_price,
      s.category_id,
      pr.full_name AS client_name,
      NULL::DOUBLE PRECISION AS distance_km
    FROM bookings b
    JOIN services s ON s.id = b.service_id
    JOIN profiles pr ON pr.id = b.client_id
    WHERE b.provider_id IS NULL
      AND b.status = 'pending'
      AND s.category_id = v_provider_category_id
    ORDER BY b.created_at DESC;
    RETURN;
  END IF;

  -- Return matching requests within radius, ordered by distance
  RETURN QUERY
  SELECT
    b.id,
    b.client_id,
    b.service_id,
    b.status,
    b.total_price,
    b.address,
    b.address_details,
    b.client_lat,
    b.client_lng,
    b.scheduled_at,
    b.created_at,
    s.title AS service_title,
    s.price AS service_price,
    s.category_id,
    pr.full_name AS client_name,
    (6371 * acos(
      LEAST(1.0, cos(radians(v_provider_lat)) *
      cos(radians(COALESCE(b.client_lat, 0))) *
      cos(radians(COALESCE(b.client_lng, 0)) - radians(v_provider_lng)) +
      sin(radians(v_provider_lat)) *
      sin(radians(COALESCE(b.client_lat, 0))))
    ))::DOUBLE PRECISION AS distance_km
  FROM bookings b
  JOIN services s ON s.id = b.service_id
  JOIN profiles pr ON pr.id = b.client_id
  WHERE b.provider_id IS NULL
    AND b.status = 'pending'
    AND s.category_id = v_category_id
    AND b.client_lat IS NOT NULL
    AND b.client_lng IS NOT NULL
    AND (6371 * acos(
      LEAST(1.0, cos(radians(v_provider_lat)) *
      cos(radians(b.client_lat)) *
      cos(radians(b.client_lng) - radians(v_provider_lng)) +
      sin(radians(v_provider_lat)) *
      sin(radians(b.client_lat)))
    )) <= v_radius
  ORDER BY distance_km ASC;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION find_matching_requests_for_provider(
  UUID, DOUBLE PRECISION
) TO authenticated;

-- Revoke from anon
REVOKE EXECUTE ON FUNCTION find_matching_requests_for_provider(
  UUID, DOUBLE PRECISION
) FROM anon;

-- =====================================================
-- Function: Find matching service_requests for a provider
-- Same logic but for the service_requests table (quick requests)
-- =====================================================
CREATE OR REPLACE FUNCTION find_matching_service_requests_for_provider(
  p_provider_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 20
)
RETURNS TABLE(
  id BIGINT,
  client_id UUID,
  service_id BIGINT,
  status TEXT,
  address TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  service_title TEXT,
  service_price NUMERIC,
  category_id BIGINT,
  client_name TEXT,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_provider_category_id BIGINT;
  v_provider_lat DOUBLE PRECISION;
  v_provider_lng DOUBLE PRECISION;
  v_radius DOUBLE PRECISION;
BEGIN
  -- Get provider's category and location
  SELECT category_id, latitude, longitude
  INTO v_provider_category_id, v_provider_lat, v_provider_lng
  FROM provider_profiles
  WHERE id = p_provider_id;

  -- If provider has no category, return nothing (must set category first)
  IF v_provider_category_id IS NULL THEN
    RETURN;
  END IF;

  -- Use provider's custom radius if p_radius_km is default (20)
  IF p_radius_km = 20 THEN
    SELECT COALESCE(search_radius_km, 20) INTO v_radius
    FROM provider_profiles
    WHERE id = p_provider_id;
  ELSE
    v_radius := p_radius_km;
  END IF;

  -- If provider has no location, return requests matching category only
  IF v_provider_lat IS NULL OR v_provider_lng IS NULL THEN
    RETURN QUERY
    SELECT
      sr.id,
      sr.client_id,
      sr.service_id,
      sr.status,
      sr.address,
      sr.lat,
      sr.lng,
      sr.created_at,
      s.title AS service_title,
      s.price AS service_price,
      s.category_id,
      pr.full_name AS client_name,
      NULL::DOUBLE PRECISION AS distance_km
    FROM service_requests sr
    JOIN services s ON s.id = sr.service_id
    JOIN profiles pr ON pr.id = sr.client_id
    WHERE sr.status = 'pending'
      AND s.category_id = v_provider_category_id
    ORDER BY sr.created_at DESC;
    RETURN;
  END IF;

  -- Return matching service_requests within radius, ordered by distance
  RETURN QUERY
  SELECT
    sr.id,
    sr.client_id,
    sr.service_id,
    sr.status,
    sr.address,
    sr.lat,
    sr.lng,
    sr.created_at,
    s.title AS service_title,
    s.price AS service_price,
    s.category_id,
    pr.full_name AS client_name,
    (6371 * acos(
      LEAST(1.0, cos(radians(v_provider_lat)) *
      cos(radians(COALESCE(sr.lat, 0))) *
      cos(radians(COALESCE(sr.lng, 0)) - radians(v_provider_lng)) +
      sin(radians(v_provider_lat)) *
      sin(radians(COALESCE(sr.lat, 0))))
    ))::DOUBLE PRECISION AS distance_km
  FROM service_requests sr
  JOIN services s ON s.id = sr.service_id
  JOIN profiles pr ON pr.id = sr.client_id
  WHERE sr.status = 'pending'
    AND s.category_id = v_category_id
    AND sr.lat IS NOT NULL
    AND sr.lng IS NOT NULL
    AND (6371 * acos(
      LEAST(1.0, cos(radians(v_provider_lat)) *
      cos(radians(sr.lat)) *
      cos(radians(sr.lng) - radians(v_provider_lng)) +
      sin(radians(v_provider_lat)) *
      sin(radians(sr.lat)))
    )) <= v_radius
  ORDER BY distance_km ASC;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION find_matching_service_requests_for_provider(
  UUID, DOUBLE PRECISION
) TO authenticated;

-- Revoke from anon
REVOKE EXECUTE ON FUNCTION find_matching_service_requests_for_provider(
  UUID, DOUBLE PRECISION
) FROM anon;
