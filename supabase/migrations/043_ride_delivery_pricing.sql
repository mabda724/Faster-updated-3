-- =========================================================
-- Ride & Delivery System with Per-Km Pricing
-- Created: 2026-06-20
-- =========================================================

-- 1. Add ride-specific columns to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
ADD COLUMN IF NOT EXISTS pickup_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pickup_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pickup_address TEXT,
ADD COLUMN IF NOT EXISTS dest_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS dest_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS dest_address TEXT,
ADD COLUMN IF NOT EXISTS distance_km DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS duration_min INTEGER,
ADD COLUMN IF NOT EXISTS client_qr_code TEXT,
ADD COLUMN IF NOT EXISTS fee_breakdown JSONB; -- stores {delivery_fee, items_total, flat_fee, discount_applied}

-- 2. Add transaction fees table for clear pricing
CREATE TABLE IF NOT EXISTS fee_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    items_total DOUBLE PRECISION DEFAULT 0,
    delivery_fee DOUBLE PRECISION DEFAULT 0,
    platform_fee DOUBLE PRECISION DEFAULT 0,
    commission_amount DOUBLE PRECISION DEFAULT 0,
    discount_applied DOUBLE PRECISION DEFAULT 0,
    total_paid DOUBLE PRECISION DEFAULT 0,
    fee_type TEXT DEFAULT 'normal', -- 'normal', 'minimum_cap', 'free_delivery'
    fee_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fee_calculations_booking_id ON fee_calculations(booking_id);

-- 3. Create function to calculate ride price
CREATE OR REPLACE FUNCTION calculate_ride_price(
    p_distance_km DOUBLE PRECISION,
    p_vehicle_type TEXT
)
RETURNS JSON AS $$
DECLARE
    v_price_per_km DOUBLE PRECISION;
    v_total_price DOUBLE PRECISION;
    v_setting_value TEXT;
    v_setting_car TEXT;
    v_setting_scooter TEXT;
BEGIN
    v_setting_car := 'driver_car_price_per_km';
    v_setting_scooter := 'driver_scooter_price_per_km';
    
    SELECT value INTO v_setting_value
    FROM app_settings
    WHERE key = COALESCE(
        CASE WHEN p_vehicle_type = 'car' THEN v_setting_car ELSE v_setting_scooter END,
        v_setting_scooter
    )
    LIMIT 1;
    
    v_price_per_km := COALESCE(v_setting_value::DOUBLE PRECISION, 
        CASE WHEN p_vehicle_type = 'car' THEN 3.5 ELSE 2.0 END
    );
    
    v_total_price := p_distance_km * v_price_per_km;
    
    RETURN json_build_object(
        'distance_km', p_distance_km,
        'price_per_km', v_price_per_km,
        'total_price', round(v_total_price::numeric, 2)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create function to calculate smart delivery fee
CREATE OR REPLACE FUNCTION calculate_smart_delivery_fee(
    p_distance_km DOUBLE PRECISION,
    p_items_total DOUBLE PRECISION
)
RETURNS JSON AS $$
DECLARE
    v_price_per_km DOUBLE PRECISION;
    v_min_fee DOUBLE PRECISION;
    v_max_ratio DOUBLE PRECISION;
    v_raw_fee DOUBLE PRECISION;
    v_final_fee DOUBLE PRECISION;
    v_fee_type TEXT := 'normal';
    v_notes TEXT := '';
    v_setting_value TEXT;
BEGIN
    SELECT value INTO v_setting_value FROM app_settings WHERE key = 'delivery_price_per_km' LIMIT 1;
    v_price_per_km := COALESCE(v_setting_value::DOUBLE PRECISION, 2.5);
    
    SELECT value INTO v_setting_value FROM app_settings WHERE key = 'delivery_min_fee' LIMIT 1;
    v_min_fee := COALESCE(v_setting_value::DOUBLE PRECISION, 15.0);
    
    SELECT value INTO v_setting_value FROM app_settings WHERE key = 'delivery_max_fee_ratio' LIMIT 1;
    v_max_ratio := COALESCE(v_setting_value::DOUBLE PRECISION, 0.8);
    
    v_raw_fee := GREATEST(v_min_fee, p_distance_km * v_price_per_km);
    
    IF p_items_total >= 200 THEN
        v_final_fee := 0;
        v_fee_type := 'free_delivery';
        v_notes := 'توصيل مجاني لأن قيمة الطلب 200 ج.م أو أكثر';
    ELSIF p_items_total > 0 AND v_raw_fee > (p_items_total * v_max_ratio) THEN
        v_final_fee := p_items_total * v_max_ratio;
        v_fee_type := 'capped';
        v_notes := 'الرسوم تقليلت تلقائياً لأنها كانت أعلى من ' || (v_max_ratio * 100)::text || '% من قيمة الطلب';
    ELSIF p_items_total > 0 AND v_raw_fee > p_items_total THEN
        v_final_fee := LEAST(v_raw_fee, p_items_total * 0.5);
        v_fee_type := 'capped';
        v_notes := 'رسوم التوصيل لا يمكن أن تتجاوز قيمة الطلب';
    ELSE
        v_final_fee := v_raw_fee;
    END IF;
    
    RETURN json_build_object(
        'delivery_fee', round(v_final_fee::numeric, 2),
        'raw_fee', round(v_raw_fee::numeric, 2),
        'distance_km', p_distance_km,
        'price_per_km', v_price_per_km,
        'fee_type', v_fee_type,
        'notes', v_notes,
        'items_total', p_items_total
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION calculate_ride_price(DOUBLE PRECISION, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION calculate_smart_delivery_fee(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, anon;
