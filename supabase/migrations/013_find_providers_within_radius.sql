CREATE OR REPLACE FUNCTION find_providers_within_radius(
  client_lat DOUBLE PRECISION,
  client_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 3,
  service_category_id BIGINT DEFAULT NULL
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
  JOIN provider_services ps ON ps.provider_id = p.id
  JOIN services s ON s.id = ps.service_id
  WHERE
    p.is_online = true
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND p.document_verification_status = 'approved'
    AND (service_category_id IS NULL OR s.category_id = service_category_id)
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
