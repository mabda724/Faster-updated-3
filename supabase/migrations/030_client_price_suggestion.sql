-- Migration: Add client price suggestion feature
-- This allows clients to suggest a price they're willing to pay
-- Providers can accept or reject the suggested price

-- Add columns to bookings table
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS client_suggested_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS client_suggested_price_status TEXT DEFAULT 'none'
CHECK (client_suggested_price_status IN ('none', 'pending', 'accepted', 'rejected'));

-- Function: Client suggests a price
CREATE OR REPLACE FUNCTION client_suggest_price(
  p_booking_id UUID,
  p_suggested_price DECIMAL(10, 2)
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_booking RECORD;
  v_app_settings JSONB;
  v_min_discount_percent INTEGER;
  v_min_price DECIMAL(10, 2);
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  -- Check if booking is in a valid state for price suggestion
  IF v_booking.status NOT IN ('pending', 'accepted', 'on_the_way', 'arrived') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot suggest price in current status');
  END IF;

  -- Check if there's already a pending price suggestion
  IF v_booking.client_suggested_price_status = 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Price suggestion already pending');
  END IF;

  -- Get app settings for minimum discount
  SELECT value INTO v_app_settings
  FROM app_settings
  WHERE key = 'pricing';

  IF v_app_settings IS NOT NULL THEN
    v_min_discount_percent := COALESCE((v_app_settings->>'min_discount_percent')::INTEGER, 10);
  ELSE
    v_min_discount_percent := 10; -- Default 10% discount minimum
  END IF;

  -- Calculate minimum allowed price (original price - discount)
  v_min_price := COALESCE(v_booking.original_price, v_booking.price) * (1 - v_min_discount_percent / 100.0);

  -- Validate suggested price
  IF p_suggested_price < v_min_price THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Suggested price is too low',
      'min_price', v_min_price
    );
  END IF;

  IF p_suggested_price >= v_booking.price THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Suggested price must be lower than current price'
    );
  END IF;

  -- Update booking with client's suggested price
  UPDATE bookings
  SET
    client_suggested_price = p_suggested_price,
    client_suggested_price_status = 'pending'
  WHERE id = p_booking_id;

  -- Create notification for provider
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    data
  ) VALUES (
    v_booking.provider_id,
    'price_suggestion',
    'اقتراح سعر جديد',
    'اقترح العميل سعر ' || p_suggested_price || ' جنيه للخدمة',
    jsonb_build_object(
      'booking_id', p_booking_id,
      'suggested_price', p_suggested_price,
      'current_price', v_booking.price
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'Price suggestion sent successfully');
END;
$$;

-- Function: Provider responds to client's price suggestion
CREATE OR REPLACE FUNCTION provider_respond_client_suggestion(
  p_booking_id UUID,
  p_provider_id UUID,
  p_accept BOOLEAN
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_booking RECORD;
  v_commission_percent DECIMAL(5, 2);
  v_new_commission DECIMAL(10, 2);
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

  -- Check if there's a pending suggestion
  IF v_booking.client_suggested_price_status != 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No pending price suggestion');
  END IF;

  IF p_accept THEN
    -- Accept the suggestion: update price and recalculate commission
    -- Get commission percent from app settings
    SELECT (value->>'commission_percent')::DECIMAL(5, 2) INTO v_commission_percent
    FROM app_settings
    WHERE key = 'pricing';

    IF v_commission_percent IS NULL THEN
      v_commission_percent := 15.0; -- Default 15%
    END IF;

    -- Calculate new commission
    v_new_commission := v_booking.client_suggested_price * (v_commission_percent / 100.0);

    -- Update booking
    UPDATE bookings
    SET
      price = v_booking.client_suggested_price,
      commission_amount = v_new_commission,
      client_suggested_price_status = 'accepted'
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
      'price_suggestion_accepted',
      'تم قبول اقتراح السعر',
      'قبل مقدم الخدمة سعر ' || v_booking.client_suggested_price || ' جنيه',
      jsonb_build_object(
        'booking_id', p_booking_id,
        'new_price', v_booking.client_suggested_price
      )
    );

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Price suggestion accepted',
      'new_price', v_booking.client_suggested_price,
      'new_commission', v_new_commission
    );
  ELSE
    -- Reject the suggestion
    UPDATE bookings
    SET client_suggested_price_status = 'rejected'
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
      'price_suggestion_rejected',
      'تم رفض اقتراح السعر',
      'رفض مقدم الخدمة اقتراح السعر',
      jsonb_build_object('booking_id', p_booking_id)
    );

    RETURN jsonb_build_object('success', true, 'message', 'Price suggestion rejected');
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION client_suggest_price TO authenticated;
GRANT EXECUTE ON FUNCTION provider_respond_client_suggestion TO authenticated;
