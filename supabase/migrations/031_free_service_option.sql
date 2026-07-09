-- Migration: Add free service option for providers
-- This allows providers to offer services for free (0 price)
-- Useful for promotional purposes or building reputation

-- Add column to bookings table
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT false;

-- Add column to provider_services table (default price per provider)
ALTER TABLE provider_services
ADD COLUMN IF NOT EXISTS allow_free BOOLEAN DEFAULT false;

-- Function: Provider can offer free service during booking
CREATE OR REPLACE FUNCTION provider_offer_free_service(
  p_booking_id UUID,
  p_provider_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_booking RECORD;
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  -- Verify provider owns this booking
  IF v_booking.provider_id != p_provider_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Check if booking is in a valid state
  IF v_booking.status NOT IN ('pending', 'accepted', 'on_the_way', 'arrived') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot change price in current status');
  END IF;

  -- Check if already free
  IF v_booking.is_free = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'Service is already free');
  END IF;

  -- Update booking to free
  UPDATE bookings
  SET
    is_free = true,
    price = 0,
    commission_amount = 0
  WHERE id = p_booking_id;

  -- Create notification for client
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    data
  ) VALUES (
    v_booking.client_id,
    'free_service',
    'خدمة مجانية!',
    'قدم مقدم الخدمة هذه الخدمة مجاناً',
    jsonb_build_object('booking_id', p_booking_id)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Service marked as free');
END;
$$;

-- Function: Client can request free service (if provider allows)
CREATE OR REPLACE FUNCTION client_request_free_service(
  p_booking_id UUID,
  p_client_id UUID
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_booking RECORD;
  v_provider_service RECORD;
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  -- Verify client owns this booking
  IF v_booking.client_id != p_client_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Check if booking is in a valid state
  IF v_booking.status NOT IN ('pending', 'accepted') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot request free service in current status');
  END IF;

  -- Check if provider allows free service for this service
  SELECT * INTO v_provider_service
  FROM provider_services
  WHERE provider_id = v_booking.provider_id
  AND service_id = v_booking.service_id;

  IF NOT FOUND OR v_provider_service.allow_free != true THEN
    RETURN jsonb_build_object('success', false, 'error', 'Provider does not offer free service');
  END IF;

  -- Check if already free
  IF v_booking.is_free = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'Service is already free');
  END IF;

  -- Create notification for provider
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    data
  ) VALUES (
    v_booking.provider_id,
    'free_service_request',
    'طلب خدمة مجانية',
    'طلب العميل الحصول على الخدمة مجاناً',
    jsonb_build_object('booking_id', p_booking_id)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Free service request sent');
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION provider_offer_free_service TO authenticated;
GRANT EXECUTE ON FUNCTION client_request_free_service TO authenticated;
