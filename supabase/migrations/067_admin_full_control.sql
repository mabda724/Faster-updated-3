-- ============================
-- Migration 023: Admin Full Control
-- ============================
-- 1. admin_cancel_booking - Admin can cancel any booking
-- 2. admin_make_booking_free - Set booking price to 0
-- 3. check_late_providers - Detect late providers
-- 4. admin_get_booking_details - Full booking details

-- ============================
-- 1. Admin Cancel Booking
-- ============================
CREATE OR REPLACE FUNCTION admin_cancel_booking(
  p_booking_id UUID,
  p_admin_id UUID,
  p_reason TEXT DEFAULT 'ألغيت بواسطة الإدارة'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_client_id UUID;
  v_provider_id UUID;
BEGIN
  -- Check admin role
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بهذا الإجراء');
  END IF;

  -- Get booking
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'الطلب غير موجود');
  END IF;

  v_client_id := v_booking.client_id;
  v_provider_id := v_booking.provider_id;

  -- Update booking status to cancelled
  UPDATE bookings SET
    status = 'cancelled',
    cancel_reason = p_reason,
    cancelled_by = p_admin_id,
    cancelled_at = NOW(),
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Create notification for client
  INSERT INTO notifications (user_id, type, title, message, data, created_at)
  VALUES (
    v_client_id,
    'system',
    'تم إلغاء الطلب',
    'تم إلغاء طلبك بواسطة الإدارة. سبب الإلغاء: ' || p_reason,
    jsonb_build_object('booking_id', p_booking_id, 'cancelled_by_admin', true),
    NOW()
  );

  -- Create notification for provider if exists
  IF v_provider_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, message, data, created_at)
    VALUES (
      v_provider_id,
      'system',
      'تم إلغاء الطلب',
      'تم إلغاء الطلب بواسطة الإدارة. سبب الإلغاء: ' || p_reason,
      jsonb_build_object('booking_id', p_booking_id, 'cancelled_by_admin', true),
      NOW()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم إلغاء الطلب بنجاح');
END;
$$;

-- ============================
-- 2. Admin Make Booking Free
-- ============================
CREATE OR REPLACE FUNCTION admin_make_booking_free(
  p_booking_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_old_price NUMERIC;
  v_client_id UUID;
  v_provider_id UUID;
BEGIN
  -- Check admin role
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بهذا الإجراء');
  END IF;

  -- Get booking
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'الطلب غير موجود');
  END IF;

  v_old_price := COALESCE(v_booking.total_price, v_booking.price, 0);
  v_client_id := v_booking.client_id;
  v_provider_id := v_booking.provider_id;

  -- Update booking to free
  UPDATE bookings SET
    total_price = 0,
    price = 0,
    commission_amount = 0,
    provider_earning = 0,
    payment_status = 'free',
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Record transaction
  INSERT INTO transactions (provider_id, amount, type, description, booking_id, created_at)
  VALUES (v_provider_id, 0, 'adjustment', 'تم تحويل الطلب إلى مجاني بواسطة الإدارة', p_booking_id, NOW());

  -- Notify client
  INSERT INTO notifications (user_id, type, title, message, data, created_at)
  VALUES (
    v_client_id,
    'system',
    'تم تحويل الطلب إلى مجاني',
    'تم تحويل طلبك إلى خدمة مجانية بقرار من الإدارة',
    jsonb_build_object('booking_id', p_booking_id, 'old_price', v_old_price, 'made_free', true),
    NOW()
  );

  -- Notify provider
  IF v_provider_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, message, data, created_at)
    VALUES (
      v_provider_id,
      'system',
      'تم تحويل الطلب إلى مجاني',
      'تم تحويل الطلب إلى خدمة مجانية بقرار من الإدارة. السعر القديم: ' || v_old_price::TEXT || ' جنيه',
      jsonb_build_object('booking_id', p_booking_id, 'old_price', v_old_price, 'made_free', true),
      NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تحويل الطلب إلى مجاني',
    'old_price', v_old_price
  );
END;
$$;

-- ============================
-- 3. Check Late Providers
-- ============================
CREATE OR REPLACE FUNCTION check_late_providers()
RETURNS TABLE(
  booking_id UUID,
  provider_id UUID,
  provider_name TEXT,
  client_name TEXT,
  status TEXT,
  accepted_at TIMESTAMPTZ,
  minutes_late INTEGER,
  late_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Case 1: Provider accepted but hasn't moved to 'on_the_way' within 15 minutes
  RETURN QUERY
  SELECT
    b.id,
    b.provider_id,
    pp.profiles->>'full_name' AS provider_name,
    cp.full_name AS client_name,
    b.status,
    b.accepted_at,
    EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 AS minutes_late,
    'لم يتحرك إلى موقع الخدمة' AS late_type
  FROM bookings b
  JOIN profiles cp ON cp.id = b.client_id
  LEFT JOIN provider_profiles pp ON pp.id = b.provider_id
  WHERE b.status = 'accepted'
    AND b.accepted_at IS NOT NULL
    AND EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 > 15;

  -- Case 2: Provider is 'on_the_way' but hasn't arrived within 30 minutes
  RETURN QUERY
  SELECT
    b.id,
    b.provider_id,
    pp.profiles->>'full_name' AS provider_name,
    cp.full_name AS client_name,
    b.status,
    b.accepted_at,
    EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 AS minutes_late,
    'متأخر في الوصول' AS late_type
  FROM bookings b
  JOIN profiles cp ON cp.id = b.client_id
  LEFT JOIN provider_profiles pp ON pp.id = b.provider_id
  WHERE b.status = 'on_the_way'
    AND b.accepted_at IS NOT NULL
    AND EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 > 30;

  -- Case 3: Provider is 'in_progress' for more than 3 hours
  RETURN QUERY
  SELECT
    b.id,
    b.provider_id,
    pp.profiles->>'full_name' AS provider_name,
    cp.full_name AS client_name,
    b.status,
    b.accepted_at,
    EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 AS minutes_late,
    'الخدمة تستغرق وقتاً طويلاً' AS late_type
  FROM bookings b
  JOIN profiles cp ON cp.id = b.client_id
  LEFT JOIN provider_profiles pp ON pp.id = b.provider_id
  WHERE b.status = 'in_progress'
    AND b.accepted_at IS NOT NULL
    AND EXTRACT(EPOCH FROM (NOW() - b.accepted_at)) / 60 > 180;
END;
$$;

-- ============================
-- 4. Admin Get Full Booking Details
-- ============================
CREATE OR REPLACE FUNCTION admin_get_booking_details(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'booking', row_to_json(b.*),
    'client', row_to_json(c.*),
    'provider', row_to_json(p.*),
    'provider_profile', row_to_json(pp.*),
    'service', row_to_json(s.*),
    'category', row_to_json(cat.*),
    'reviews', (SELECT jsonb_agg(row_to_json(r.*)) FROM reviews r WHERE r.booking_id = b.id),
    'transactions', (SELECT jsonb_agg(row_to_json(t.*)) FROM transactions t WHERE t.booking_id = b.id),
    'chat_messages_count', (SELECT COUNT(*) FROM chat_messages cm WHERE cm.booking_id = b.id)
  )
  INTO v_result
  FROM bookings b
  LEFT JOIN profiles c ON c.id = b.client_id
  LEFT JOIN profiles p ON p.id = b.provider_id
  LEFT JOIN provider_profiles pp ON pp.id = b.provider_id
  LEFT JOIN services s ON s.id = b.service_id
  LEFT JOIN categories cat ON cat.id = s.category_id
  WHERE b.id = p_booking_id;

  RETURN v_result;
END;
$$;
