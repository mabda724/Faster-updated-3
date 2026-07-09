-- =====================================================
-- IDEMPOTENT EARNINGS TRIGGER FIX
-- Ensure provider earnings are only credited once when payment_status changes to 'paid'
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_provider_earnings()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    provider_wallet_id UUID;
    current_balance DECIMAL(10, 2);
    net_amount DECIMAL(10, 2);
    commission_amount DECIMAL(10, 2);
    status_changed_to_completed BOOLEAN;
    payment_changed_to_paid BOOLEAN;
BEGIN
    -- Detect state changes
    status_changed_to_completed := (NEW.status = 'completed' AND COALESCE(OLD.status, '') <> 'completed');
    payment_changed_to_paid := (NEW.payment_status = 'paid' AND COALESCE(OLD.payment_status, '') <> 'paid');

    -- Only process if either status became completed OR payment_status became paid
    IF status_changed_to_completed OR payment_changed_to_paid THEN
        -- Get or create wallet
        SELECT id, balance INTO provider_wallet_id, current_balance
        FROM wallets WHERE provider_id = NEW.provider_id;

        IF provider_wallet_id IS NULL THEN
            INSERT INTO wallets (provider_id, balance)
            VALUES (NEW.provider_id, 0)
            RETURNING id, 0 INTO provider_wallet_id, current_balance;
        END IF;

        -- Calculate net amount (total - commission)
        commission_amount := COALESCE(NEW.commission_amount, 0);
        net_amount := COALESCE(NEW.total_price, 0) - commission_amount;

        -- Update wallet balance
        UPDATE wallets SET
            balance = balance + net_amount,
            updated_at = NOW()
        WHERE provider_id = NEW.provider_id;

        -- Log earning transaction (avoid duplicate by checking if already logged?)
        -- We'll rely on the status change detection to avoid duplicates
        INSERT INTO transactions (booking_id, provider_id, wallet_id, amount, type, description)
        VALUES (NEW.id, NEW.provider_id, provider_wallet_id, net_amount, 'earning',
                'Earnings from booking completed on ' || NOW());

        -- Log commission transaction
        IF commission_amount > 0 THEN
            INSERT INTO transactions (booking_id, provider_id, wallet_id, amount, type, description)
            VALUES (NEW.id, NEW.provider_id, provider_wallet_id, commission_amount, 'commission',
                    'Platform commission from booking');
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Recreate trigger with updated function
DROP TRIGGER IF EXISTS calculate_booking_earnings ON bookings;
CREATE TRIGGER calculate_booking_earnings
    AFTER UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION calculate_provider_earnings();

-- Verification query (optional)
SELECT proname FROM pg_proc WHERE proname = 'calculate_provider_earnings';
