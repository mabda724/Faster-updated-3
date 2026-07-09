-- =====================================================
-- MIGRATION 042: Ride-hailing & Delivery System
-- =====================================================
-- Adds:
--   booking_type on bookings (service | ride | delivery)
--   vehicle_type on provider_profiles (car | scooter)
--   ride/delivery columns on bookings
--   Pricing settings in app_settings
--   RPC functions: calculate_ride_price, calculate_delivery_fee,
--                  create_ride_request, create_delivery_order,
--                  find_nearby_ride_requests, find_nearby_delivery_orders
--   RLS and indexes
-- =====================================================

-- 1. booking_type on bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS booking_type TEXT DEFAULT 'service'
  CHECK (booking_type IN ('service', 'ride', 'delivery'));

-- 2. vehicle_type on provider_profiles
ALTER TABLE provider_profiles
ADD COLUMN IF NOT EXISTS vehicle_type TEXT DEFAULT NULL
  CHECK (vehicle_type IN ('car', 'scooter'));

-- 3. ride / delivery columns on bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS pickup_lat      DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pickup_lng      DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pickup_address TEXT,
ADD COLUMN IF NOT EXISTS destination_lat   DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS destination_lng   DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS destination_address TEXT,
ADD COLUMN IF NOT EXISTS distance_km        DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS estimated_duration_min INTEGER,
ADD COLUMN IF NOT EXISTS ride_vehicle_type  TEXT
  CHECK (ride_vehicle_type IN ('car', 'scooter') OR ride_vehicle_type IS NULL);

-- Indexes for fast ride/delivery lookups
CREATE INDEX IF NOT EXISTS idx_bookings_booking_type
  ON bookings (booking_type, status, created_at DESC)
  WHERE booking_type IN ('ride', 'delivery');

CREATE INDEX IF NOT EXISTS idx_bookings_ride_pending
  ON bookings (id, status)
  WHERE booking_type = 'ride' AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_bookings_delivery_ready
  ON bookings (id, status)
  WHERE booking_type = 'delivery' AND status = 'ready_for_delivery';

CREATE INDEX IF NOT EXISTS idx_provider_profiles_vehicle_type
  ON provider_profiles (vehicle_type)
  WHERE vehicle_type IS NOT NULL;

-- 4. Pricing settings in app_settings
INSERT INTO app_settings (key, value) VALUES
  ('driver_car_price_per_km',    '3.5'),
  ('driver_scooter_price_per_km','2.0'),
  ('delivery_price_per_km',      '2.5'),
  ('delivery_min_fee',           '15'),
  ('delivery_max_fee_ratio',     '0.8')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value;

-- =====================================================
-- Helper: Haversine distance in KM
-- =====================================================
CREATE OR REPLACE FUNCTION haversine_km(
  lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  r DOUBLE PRECISION := 6371; -- Earth radius in km
  dlat DOUBLE PRECISION := radians(lat2 - lat1);
  dlng DOUBLE PRECISION := radians(lng2 - lng1);
  a   DOUBLE PRECISION;
  c   DOUBLE PRECISION;
BEGIN
  a := sin(dlat/2)^2
     + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng/2)^2;
  c := 2 * atan2(sqrt(a), sqrt(1 - a));
  RETURN r * c;
END;
$$;

-- =====================================================
-- RPC: calculate_ride_price
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_ride_price(
  p_pickup_lat   DOUBLE PRECISION,
  p_pickup_lng   DOUBLE PRECISION,
  p_dest_lat     DOUBLE PRECISION,
  p_dest_lng     DOUBLE PRECISION,
  p_vehicle_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_distance_km   DOUBLE PRECISION;
  v_duration_min   INTEGER;
  v_price_per_km   DOUBLE PRECISION;
  v_total_price    DOUBLE PRECISION;
  v_setting_key    TEXT;
BEGIN
  -- Haversine distance
  v_distance_km := haversine_km(p_pickup_lat, p_pickup_lng, p_dest_lat, p_dest_lng);

  -- Rough duration: ~30 km/h average in city
  v_duration_min := GREATEST(5, CEIL(v_distance_km / 0.5)::INTEGER);

  -- Price per km from app_settings
  IF p_vehicle_type = 'scooter' THEN
    v_setting_key := 'driver_scooter_price_per_km';
  ELSE
    v_setting_key := 'driver_car_price_per_km';
  END IF;

  SELECT COALESCE(value::DOUBLE PRECISION, 2.5)
  INTO v_price_per_km
  FROM app_settings
  WHERE key = v_setting_key;

  v_total_price := CEIL(v_distance_km * v_price_per_km);

  RETURN jsonb_build_object(
    'distance_km',   ROUND(v_distance_km::NUMERIC, 2),
    'duration_min',  v_duration_min,
    'price_per_km',  v_price_per_km,
    'total_price',   v_total_price,
    'vehicle_type',  p_vehicle_type
  );
END;
$$;

-- =====================================================
-- RPC: calculate_delivery_fee  (SMART PRICING)
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_delivery_fee(
  p_seller_lat    DOUBLE PRECISION,
  p_seller_lng    DOUBLE PRECISION,
  p_client_lat    DOUBLE PRECISION,
  p_client_lng    DOUBLE PRECISION,
  p_order_total   NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_distance_km  DOUBLE PRECISION;
  v_price_per_km  DOUBLE PRECISION;
  v_base_fee      NUMERIC;
  v_min_fee       NUMERIC;
  v_max_ratio     DOUBLE PRECISION;
  v_fee           NUMERIC;
  v_capped_fee    NUMERIC;
BEGIN
  -- Haversine distance
  v_distance_km := haversine_km(p_seller_lat, p_seller_lng, p_client_lat, p_client_lng);

  -- Settings
  SELECT COALESCE(value::DOUBLE PRECISION, 2.5)
  INTO v_price_per_km
  FROM app_settings
  WHERE key = 'delivery_price_per_km';

  SELECT COALESCE(value::NUMERIC, 15)
  INTO v_min_fee
  FROM app_settings
  WHERE key = 'delivery_min_fee';

  SELECT COALESCE(value::DOUBLE PRECISION, 0.8)
  INTO v_max_ratio
  FROM app_settings
  WHERE key = 'delivery_max_fee_ratio';

  -- Base fee
  v_base_fee := ROUND(v_distance_km * v_price_per_km::NUMERIC, 2);

  -- Apply minimum fee
  v_fee := GREATEST(v_base_fee, v_min_fee);

  -- Smart cap: if fee exceeds max_ratio of order total, cap it
  IF p_order_total > 0 AND v_fee > p_order_total * v_max_ratio THEN
    v_capped_fee := CEIL(p_order_total * v_max_ratio);
    -- Round up to nearest 5 EGP for cleaner UX
    v_capped_fee := CEIL(v_capped_fee / 5.0) * 5;
  ELSE
    v_capped_fee := NULL;
  END IF;

  RETURN jsonb_build_object(
    'distance_km',    ROUND(v_distance_km::NUMERIC, 2),
    'price_per_km',   v_price_per_km,
    'base_fee',       v_base_fee,
    'min_fee',        v_min_fee,
    'calculated_fee', v_fee,
    'capped_fee',     v_capped_fee,
    'final_fee',      COALESCE(v_capped_fee, v_fee),
    'order_total',    p_order_total,
    'is_capped',      v_capped_fee IS NOT NULL
  );
END;
$$;

-- =====================================================
-- RPC: create_ride_request
-- =====================================================
CREATE OR REPLACE FUNCTION create_ride_request(
  p_client_id       UUID,
  p_pickup_lat      DOUBLE PRECISION,
  p_pickup_lng      DOUBLE PRECISION,
  p_pickup_address  TEXT,
  p_dest_lat        DOUBLE PRECISION,
  p_dest_lng        DOUBLE PRECISION,
  p_dest_address    TEXT,
  p_vehicle_type    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_price_data   JSONB;
  v_booking_id   UUID;
  v_total_price  NUMERIC;
BEGIN
  -- Calculate price
  v_price_data := calculate_ride_price(
    p_pickup_lat, p_pickup_lng, p_dest_lat, p_dest_lng, p_vehicle_type
  );

  v_total_price := (v_price_data->>'total_price')::NUMERIC;

  -- Create booking
  INSERT INTO bookings (
    client_id,
    service_id,
    status,
    booking_type,
    base_price,
    total_price,
    commission_rate,
    commission_amount,
    pickup_lat,
    pickup_lng,
    pickup_address,
    destination_lat,
    destination_lng,
    destination_address,
    distance_km,
    estimated_duration_min,
    ride_vehicle_type,
    notes,
    created_at,
    updated_at
  ) VALUES (
    p_client_id,
    NULL,                   -- no service_id for rides
    'pending',
    'ride',
    v_total_price,
    v_total_price,
    0,                      -- no commission on rides (driver keeps full amount)
    0,
    p_pickup_lat,
    p_pickup_lng,
    p_pickup_address,
    p_dest_lat,
    p_dest_lng,
    p_dest_address,
    (v_price_data->>'distance_km')::DOUBLE PRECISION,
    (v_price_data->>'duration_min')::INTEGER,
    p_vehicle_type,
    '',                     -- notes empty
    NOW(),
    NOW()
  )
  RETURNING id INTO v_booking_id;

  -- Send broadcast notification to nearby drivers
  PERFORM pg_notify(
    'new_ride_request',
    jsonb_build_object(
      'booking_id', v_booking_id,
      'vehicle_type', p_vehicle_type,
      'pickup_lat',  p_pickup_lat,
      'pickup_lng',  p_pickup_lng,
      'dest_lat',    p_dest_lat,
      'dest_lng',    p_dest_lng,
      'total_price', v_total_price
    )::TEXT
  );

  RETURN jsonb_build_object(
    'booking_id',   v_booking_id,
    'total_price',  v_total_price,
    'distance_km',  v_price_data->>'distance_km',
    'duration_min', v_price_data->>'duration_min'
  );
END;
$$;

-- =====================================================
-- RPC: create_delivery_order
-- =====================================================
CREATE OR REPLACE FUNCTION create_delivery_order(
  p_seller_id      UUID,
  p_client_id      UUID,
  p_client_lat     DOUBLE PRECISION,
  p_client_lng     DOUBLE PRECISION,
  p_client_address TEXT,
  p_order_items    JSONB,
  p_order_total    NUMERIC,
  p_seller_lat     DOUBLE PRECISION,
  p_seller_lng     DOUBLE PRECISION,
  p_seller_address TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fee_data      JSONB;
  v_delivery_fee  NUMERIC;
  v_grand_total   NUMERIC;
  v_booking_id    UUID;
  v_service_id    BIGINT;
BEGIN
  -- Find a generic delivery service_id (first delivery-type service)
  SELECT id INTO v_service_id
  FROM services
  WHERE category_id IN (
    SELECT id FROM categories WHERE name_ar ILIKE '%توصيل%' OR name_en ILIKE '%delivery%'
  )
  LIMIT 1;

  IF v_service_id IS NULL THEN
    -- fallback: first available service
    SELECT id INTO v_service_id FROM services LIMIT 1;
  END IF;

  -- Calculate delivery fee with smart pricing
  v_fee_data := calculate_delivery_fee(
    p_seller_lat, p_seller_lng, p_client_lat, p_client_lng, p_order_total
  );

  v_delivery_fee := (v_fee_data->>'final_fee')::NUMERIC;
  v_grand_total  := p_order_total + v_delivery_fee;

  -- Create booking
  INSERT INTO bookings (
    client_id,
    provider_id,           -- seller becomes the "provider" in bookings
    service_id,
    status,
    booking_type,
    base_price,
    total_price,
    commission_rate,
    commission_amount,
    pickup_lat,
    pickup_lng,
    pickup_address,
    destination_lat,
    destination_lng,
    destination_address,
    distance_km,
    ride_vehicle_type,
    notes,
    created_at,
    updated_at
  ) VALUES (
    p_client_id,
    p_seller_id,
    v_service_id,
    'ready_for_delivery',
    'delivery',
    p_order_total,         -- base = product total
    v_grand_total,         -- total = products + delivery
    10,                    -- 10% commission on delivery fee
    ROUND(v_delivery_fee * 0.10, 2),
    p_seller_lat,
    p_seller_lng,
    p_seller_address,
    p_client_lat,
    p_client_lng,
    p_client_address,
    (v_fee_data->>'distance_km')::DOUBLE PRECISION,
    NULL,                  -- no vehicle type for delivery
    p_order_items::TEXT,   -- store order items as JSON string in notes
    NOW(),
    NOW()
  )
  RETURNING id INTO v_booking_id;

  -- Send notification to nearby delivery drivers
  PERFORM pg_notify(
    'new_delivery_order',
    jsonb_build_object(
      'booking_id',    v_booking_id,
      'seller_id',     p_seller_id,
      'seller_lat',    p_seller_lat,
      'seller_lng',    p_seller_lng,
      'client_lat',    p_client_lat,
      'client_lng',    p_client_lng,
      'order_total',   p_order_total,
      'delivery_fee',  v_delivery_fee,
      'grand_total',   v_grand_total
    )::TEXT
  );

  RETURN jsonb_build_object(
    'booking_id',     v_booking_id,
    'order_total',    p_order_total,
    'delivery_fee',   v_delivery_fee,
    'grand_total',    v_grand_total,
    'distance_km',    v_fee_data->>'distance_km',
    'is_capped',      (v_fee_data->>'is_capped')::BOOLEAN,
    'original_calculated_fee', v_fee_data->>'calculated_fee'
  );
END;
$$;

-- =====================================================
-- RPC: find_nearby_ride_requests
-- =====================================================
CREATE OR REPLACE FUNCTION find_nearby_ride_requests(
  p_driver_id   UUID,
  p_radius_km   DOUBLE PRECISION DEFAULT 20
)
RETURNS TABLE(
  id              UUID,
  client_id       UUID,
  status          TEXT,
  total_price     NUMERIC,
  pickup_lat      DOUBLE PRECISION,
  pickup_lng      DOUBLE PRECISION,
  destination_lat DOUBLE PRECISION,
  destination_lng DOUBLE PRECISION,
  distance_km     DOUBLE PRECISION,
  ride_vehicle_type TEXT,
  client_name     TEXT,
  client_phone    TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_lat   DOUBLE PRECISION;
  v_driver_lng   DOUBLE PRECISION;
  v_vehicle_type TEXT;
BEGIN
  -- Get driver's current location and vehicle type
  SELECT pp.latitude, pp.longitude, pp.vehicle_type
  INTO v_driver_lat, v_driver_lng, v_vehicle_type
  FROM provider_profiles pp
  WHERE pp.id = p_driver_id;

  IF v_driver_lat IS NULL OR v_driver_lng IS NULL THEN
    -- No location: return pending ride requests with no distance
    RETURN QUERY
    SELECT
      b.id,
      b.client_id,
      b.status,
      b.total_price,
      b.pickup_lat,
      b.pickup_lng,
      b.destination_lat,
      b.destination_lng,
      NULL::DOUBLE PRECISION AS distance_km,
      b.ride_vehicle_type,
      p.full_name,
      p.phone
    FROM bookings b
    JOIN profiles p ON p.id = b.client_id
    WHERE b.booking_type = 'ride'
      AND b.status = 'pending'
      AND (b.ride_vehicle_type = v_vehicle_type OR v_vehicle_type IS NULL)
    ORDER BY b.created_at DESC;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.client_id,
    b.status,
    b.total_price,
    b.pickup_lat,
    b.pickup_lng,
    b.destination_lat,
    b.destination_lng,
    ROUND(haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng)::NUMERIC, 2),
    b.ride_vehicle_type,
    p.full_name,
    p.phone
  FROM bookings b
  JOIN profiles p ON p.id = b.client_id
  WHERE b.booking_type = 'ride'
    AND b.status = 'pending'
    AND (b.ride_vehicle_type = v_vehicle_type OR v_vehicle_type IS NULL)
    AND haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng) <= p_radius_km
  ORDER BY haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng) ASC;
END;
$$;

-- =====================================================
-- RPC: find_nearby_delivery_orders
-- =====================================================
CREATE OR REPLACE FUNCTION find_nearby_delivery_orders(
  p_delivery_id UUID,
  p_radius_km   DOUBLE PRECISION DEFAULT 20
)
RETURNS TABLE(
  id               UUID,
  seller_id        UUID,
  client_id        UUID,
  status           TEXT,
  total_price      NUMERIC,
  pickup_lat       DOUBLE PRECISION,
  pickup_lng       DOUBLE PRECISION,
  destination_lat  DOUBLE PRECISION,
  destination_lng  DOUBLE PRECISION,
  distance_km      DOUBLE PRECISION,
  seller_name      TEXT,
  seller_address   TEXT,
  client_name      TEXT,
  client_address   TEXT,
  order_items      TEXT   -- notes column stores JSON order items
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_lat   DOUBLE PRECISION;
  v_driver_lng   DOUBLE PRECISION;
BEGIN
  -- Get delivery driver's current location
  SELECT pp.latitude, pp.longitude
  INTO v_driver_lat, v_driver_lng
  FROM provider_profiles pp
  WHERE pp.id = p_delivery_id;

  IF v_driver_lat IS NULL OR v_driver_lng IS NULL THEN
    -- No location: return all ready delivery orders
    RETURN QUERY
    SELECT
      b.id,
      b.provider_id,
      b.client_id,
      b.status,
      b.total_price,
      b.pickup_lat,
      b.pickup_lng,
      b.destination_lat,
      b.destination_lng,
      NULL::DOUBLE PRECISION AS distance_km,
      sp.full_name,
      b.pickup_address,
      cp.full_name,
      b.destination_address,
      b.notes
    FROM bookings b
    JOIN profiles sp ON sp.id = b.provider_id    -- seller
    JOIN profiles cp ON cp.id = b.client_id      -- client
    WHERE b.booking_type = 'delivery'
      AND b.status = 'ready_for_delivery'
    ORDER BY b.created_at DESC;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.provider_id,
    b.client_id,
    b.status,
    b.total_price,
    b.pickup_lat,
    b.pickup_lng,
    b.destination_lat,
    b.destination_lng,
    ROUND(haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng)::NUMERIC, 2),
    sp.full_name,
    b.pickup_address,
    cp.full_name,
    b.destination_address,
    b.notes
  FROM bookings b
  JOIN profiles sp ON sp.id = b.provider_id
  JOIN profiles cp ON cp.id = b.client_id
  WHERE b.booking_type = 'delivery'
    AND b.status = 'ready_for_delivery'
    AND haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng) <= p_radius_km
  ORDER BY haversine_km(v_driver_lat, v_driver_lng, b.pickup_lat, b.pickup_lng) ASC;
END;
$$;

-- =====================================================
-- Permissions: RPC execution
-- =====================================================
GRANT EXECUTE ON FUNCTION calculate_ride_price(DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_delivery_fee(DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION create_ride_request(UUID,DOUBLE PRECISION,DOUBLE PRECISION,TEXT,DOUBLE PRECISION,DOUBLE PRECISION,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_delivery_order(UUID,UUID,DOUBLE PRECISION,DOUBLE PRECISION,TEXT,JSONB,NUMERIC,DOUBLE PRECISION,DOUBLE PRECISION,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearby_ride_requests(UUID,DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearby_delivery_orders(UUID,DOUBLE PRECISION) TO authenticated;
