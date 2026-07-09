CREATE OR REPLACE FUNCTION find_providers_within_radius(
  client_lat DOUBLE PRECISION,
  client_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 3
) RETURNS TABLE(
  id UUID,
  full_name TEXT,
  profession TEXT,
  rating DECIMAL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    pr.full_name,
    p.profession,
    p.rating,
    p.latitude,
    p.longitude,
    (6371 * acos(
      cos(radians(client_lat)) *
      cos(radians(p.latitude)) *
      cos(radians(p.longitude) - radians(client_lng)) +
      sin(radians(client_lat)) *
      sin(radians(p.latitude))
    ))::DOUBLE PRECISION AS distance_km
  FROM provider_profiles p
  JOIN profiles pr ON pr.id = p.id
  WHERE
    p.is_online = true
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.document_verification_status = 'approved'
    AND (6371 * acos(
      cos(radians(client_lat)) *
      cos(radians(p.latitude)) *
      cos(radians(p.longitude) - radians(client_lng)) +
      sin(radians(client_lat)) *
      sin(radians(p.latitude))
    )) <= radius_km
  ORDER BY distance_km;
END;
$$;

-- Graduated search: tries 3km, 5km, 10km, 20km until providers found
CREATE OR REPLACE FUNCTION find_providers_graduated(
  client_lat DOUBLE PRECISION,
  client_lng DOUBLE PRECISION
) RETURNS TABLE(
  id UUID,
  full_name TEXT,
  profession TEXT,
  rating DECIMAL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  search_radius INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
  radii INTEGER[] := ARRAY[3, 5, 10, 20];
  r INTEGER;
  found_count INTEGER;
BEGIN
  FOREACH r IN ARRAY radii LOOP
    RETURN QUERY
    SELECT * FROM find_providers_within_radius(client_lat, client_lng, r) LIMIT 50;
    GET DIAGNOSTICS found_count = ROW_COUNT;
    IF found_count > 0 THEN
      -- Add search_radius column
      RETURN QUERY
      SELECT fp.id, fp.full_name, fp.profession, fp.rating, fp.latitude, fp.longitude, fp.distance_km, r::INTEGER
      FROM find_providers_within_radius(client_lat, client_lng, r) fp
      LIMIT 50;
      RETURN;
    END IF;
  END LOOP;
END;
$$;
