-- Migration 024: Fix real-time debt and earning calculation logic

-- 1. Create a robust function to calculate provider's current debt (un-settled commissions)
-- This sums up commissions from all completed cash bookings that haven't been settled yet.
CREATE OR REPLACE FUNCTION public.calculate_provider_current_debt(p_provider_id UUID)
RETURNS DECIMAL(10, 2) LANGUAGE plpgsql AS $$
DECLARE
    v_total_commissions DECIMAL(10, 2);
    v_total_settled DECIMAL(10, 2);
BEGIN
    -- Sum of commissions from all completed cash bookings
    SELECT COALESCE(SUM(commission_amount), 0) INTO v_total_commissions
    FROM public.bookings
    WHERE provider_id = p_provider_id
      AND status = 'completed'
      AND payment_method = 'cash';

    -- Sum of commissions from cancellations (penalties)
    SELECT COALESCE(SUM(cancel_commission_deducted), 0) INTO v_total_commissions
    FROM public.bookings
    WHERE provider_id = p_provider_id
      AND status = 'pending' -- reassigned after provider cancel
      AND cancelled_by = p_provider_id;

    -- Add existing penalties from transactions if any not covered above
    -- (This logic depends on how you want to aggregate. A simpler way is to use the debt_amount column
    -- but ensure it's updated correctly by every single action.)

    -- For maximum accuracy as requested ("real time sums"), we rely on the source of truth (bookings + settlements)

    -- Sum of verified settlements
    SELECT COALESCE(SUM(amount), 0) INTO v_total_settled
    FROM public.commission_settlements
    WHERE provider_id = p_provider_id AND status = 'verified';

    RETURN GREATEST(0, v_total_commissions - v_total_settled);
END;
$$;

-- 2. Update the main trigger function to handle both Earning (Online) and Debt (Cash)
CREATE OR REPLACE FUNCTION public.calculate_provider_earnings()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_commission_amount DECIMAL(10, 2);
    v_provider_earning DECIMAL(10, 2);
BEGIN
    -- Only process when booking status changes to 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN

        v_commission_amount := COALESCE(NEW.commission_amount, 0);
        v_provider_earning := COALESCE(NEW.total_price, 0) - v_commission_amount;

        -- Handle Cash Payment
        IF NEW.payment_method = 'cash' THEN
            -- Provider took 100% cash from client, so they OWE the commission to the app
            UPDATE public.provider_profiles
            SET debt_amount = COALESCE(debt_amount, 0) + v_commission_amount,
                updated_at = NOW()
            WHERE id = NEW.provider_id;

            INSERT INTO public.transactions (booking_id, provider_id, amount, type, status, description)
            VALUES (NEW.id, NEW.provider_id, -v_commission_amount, 'commission', 'completed',
                    'عمولة مستحقة عن طلب كاش رقم ' || COALESCE(NEW.order_code, NEW.id::text));

        -- Handle Online Payment (Paid via Paymob)
        ELSE
            -- App has the money, so the app OWES the net earning to the provider
            UPDATE public.provider_profiles
            SET wallet_balance = COALESCE(wallet_balance, 0) + v_provider_earning,
                updated_at = NOW()
            WHERE id = NEW.provider_id;

            INSERT INTO public.transactions (booking_id, provider_id, amount, type, status, description)
            VALUES (NEW.id, NEW.provider_id, v_provider_earning, 'earning', 'completed',
                    'أرباح محولة للمحفظة عن طلب رقم ' || COALESCE(NEW.order_code, NEW.id::text));
        END IF;

        -- Update Analytics
        PERFORM public.update_provider_analytics(NEW.provider_id);
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Fix the cancellation logic in the RPC to use debt_amount for cash penalty
CREATE OR REPLACE FUNCTION public.cancel_booking_graduated(
  p_booking_id UUID,
  p_cancelled_by UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking RECORD;
  v_status TEXT;
  v_accepted_at TIMESTAMPTZ;
  v_total_price NUMERIC;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_minutes_since_accept DOUBLE PRECISION;
  v_cancel_free_minutes INTEGER;
  v_cancel_commission_minutes INTEGER;
  v_deduction_type TEXT;
  v_provider_id UUID;
BEGIN
  -- Get configuration
  SELECT (value::jsonb->>'minutes')::INTEGER INTO v_cancel_free_minutes FROM app_settings WHERE key = 'cancel_free_minutes';
  SELECT (value::jsonb->>'minutes')::INTEGER INTO v_cancel_commission_minutes FROM app_settings WHERE key = 'cancel_commission_minutes';

  v_cancel_free_minutes := COALESCE(v_cancel_free_minutes, 5);
  v_cancel_commission_minutes := COALESCE(v_cancel_commission_minutes, 30);

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Booking not found'); END IF;

  v_status := v_booking.status;
  v_accepted_at := v_booking.accepted_at;
  v_total_price := COALESCE(v_booking.total_price, v_booking.price, 0);
  v_commission_rate := COALESCE(v_booking.commission_rate, 0.10);
  v_provider_id := v_booking.provider_id;

  IF v_status NOT IN ('accepted', 'on_the_way', 'arrived', 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel in current status');
  END IF;

  v_minutes_since_accept := EXTRACT(EPOCH FROM (NOW() - v_accepted_at)) / 60.0;

  IF v_minutes_since_accept <= v_cancel_free_minutes THEN
    v_deduction_type := 'free';
    v_commission_amount := 0;
  ELSIF v_minutes_since_accept <= v_cancel_commission_minutes THEN
    v_deduction_type := 'commission';
    v_commission_amount := v_total_price * v_commission_rate;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'تواصل مع الدعم الفني للإلغاء');
  END IF;

  -- Apply penalty if provider cancelled
  IF p_cancelled_by = v_provider_id AND v_commission_amount > 0 THEN
     -- For simplicity and consistency, any penalty becomes a DEBT
     UPDATE provider_profiles
     SET debt_amount = COALESCE(debt_amount, 0) + v_commission_amount,
         updated_at = NOW()
     WHERE id = v_provider_id;

     INSERT INTO transactions (provider_id, amount, type, description, booking_id)
     VALUES (v_provider_id, -v_commission_amount, 'cancel_commission', 'غرامة إلغاء طلب رقم ' || v_booking.order_code, p_booking_id);
  END IF;

  -- Update booking
  IF p_cancelled_by = v_provider_id THEN
    UPDATE bookings SET status = 'pending', provider_id = NULL, cancel_reason = p_reason, cancelled_by = p_cancelled_by, cancelled_at = NOW(), cancel_commission_deducted = v_commission_amount, accepted_at = NULL WHERE id = p_booking_id;
  ELSE
    UPDATE bookings SET status = 'cancelled', cancel_reason = p_reason, cancelled_by = p_cancelled_by, cancelled_at = NOW(), cancel_commission_deducted = v_commission_amount WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'deduction_type', v_deduction_type, 'commission_deducted', v_commission_amount);
END;
$$;

-- 4. Sync current debt_amount column for all providers based on history
-- This ensures the column matches the "real time" sum of their activities
UPDATE public.provider_profiles pp
SET debt_amount = (
    SELECT
      COALESCE((SELECT SUM(commission_amount) FROM bookings WHERE provider_id = pp.id AND status = 'completed' AND payment_method = 'cash'), 0) +
      COALESCE((SELECT SUM(cancel_commission_deducted) FROM bookings WHERE provider_id = pp.id AND cancelled_by = pp.id), 0) -
      COALESCE((SELECT SUM(amount) FROM commission_settlements WHERE provider_id = pp.id AND status = 'verified'), 0)
);
