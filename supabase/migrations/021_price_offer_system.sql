-- Add additional fields for price offer system tracking
-- Note: offered_price and offered_price_reason already exist in migration 018

-- Add new columns to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS original_price DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS price_offer_status VARCHAR(20) DEFAULT 'none';

-- price_offer_status values:
-- 'none' - no price offer active
-- 'pending' - provider offered a price, waiting for client response
-- 'accepted' - client accepted the offered price
-- 'rejected' - client rejected the offered price (back to original or reject provider)

-- Add comment for documentation
COMMENT ON COLUMN bookings.original_price IS 'Original price from the service request before any price negotiations';
COMMENT ON COLUMN bookings.price_offer_status IS 'Status of price offer: none, pending, accepted, rejected';

-- Update provider_offer_price function to set price_offer_status
-- Following Supabase security best practices
CREATE OR REPLACE FUNCTION provider_offer_price(
  p_booking_id UUID,
  p_provider_id UUID,
  p_offered_price NUMERIC,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking RECORD;
BEGIN
  -- Security check: Only the assigned provider can offer price
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.provider_id != p_provider_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not your booking');
  END IF;

  IF v_booking.status NOT IN ('accepted', 'on_the_way', 'arrived') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot offer price in this status');
  END IF;

  IF p_offered_price <= COALESCE(v_booking.total_price, v_booking.price, 0) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offered price must be higher than current price');
  END IF;

  UPDATE bookings SET
    offered_price = p_offered_price,
    offered_price_reason = p_reason,
    price_offer_status = 'pending'
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'offered_price', p_offered_price);
END;
$$;

-- Update client_respond_price_offer function to set price_offer_status
-- Following Supabase security best practices
CREATE OR REPLACE FUNCTION client_respond_price_offer(
  p_booking_id UUID,
  p_client_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking RECORD;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
BEGIN
  -- Security check: Only the client can respond to price offers
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.client_id != p_client_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not your booking');
  END IF;

  IF v_booking.offered_price IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No price offer pending');
  END IF;

  IF p_accept THEN
    v_commission_rate := COALESCE(v_booking.commission_rate, 0.10);
    v_commission_amount := v_booking.offered_price * v_commission_rate;
    UPDATE bookings SET
      total_price = v_booking.offered_price,
      commission_amount = v_commission_amount,
      offered_price = NULL,
      offered_price_reason = NULL,
      price_offer_status = 'accepted'
    WHERE id = p_booking_id;
  ELSE
    -- Reset to 'none' to allow provider to offer again (continuous negotiation)
    UPDATE bookings SET
      offered_price = NULL,
      offered_price_reason = NULL,
      price_offer_status = 'none'
    WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END;
$$;

-- Create function to initialize original_price when creating a booking
CREATE OR REPLACE FUNCTION initialize_original_price()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.original_price IS NULL THEN
    NEW.original_price := NEW.price;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to auto-set original_price on insert
DROP TRIGGER IF EXISTS on_booking_insert_set_original_price ON bookings;
CREATE TRIGGER on_booking_insert_set_original_price
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION initialize_original_price();

-- Update existing bookings to set original_price from current price
UPDATE bookings 
SET original_price = price 
WHERE original_price IS NULL;
