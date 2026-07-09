-- =====================================================
-- FASTER APP - NOTIFICATIONS & ADVANCED FEATURES
-- =====================================================

-- 1. FCM Tokens table for push notifications
CREATE TABLE IF NOT EXISTS fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);

-- RLS for FCM tokens
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own FCM token"
    ON fcm_tokens FOR ALL
    USING (auth.uid() = user_id);

-- 2. Provider Locations table for real-time tracking
CREATE TABLE IF NOT EXISTS provider_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
    order_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_provider_locations_provider ON provider_locations(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_locations_order ON provider_locations(order_id);

-- RLS for provider locations
ALTER TABLE provider_locations ENABLE ROW LEVEL SECURITY;

-- Providers can update their own location
CREATE POLICY "Providers can update their own location"
    ON provider_locations FOR UPDATE
    USING (auth.uid() = provider_id);

-- Clients can view provider location for their bookings
CREATE POLICY "Clients can view provider location for their bookings"
    ON provider_locations FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM bookings
            WHERE bookings.id = provider_locations.order_id
            AND bookings.client_id = auth.uid()
        )
    );

-- 3. Payment Intents table (if not exists)
CREATE TABLE IF NOT EXISTS payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    user_id UUID REFERENCES profiles(id),
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT DEFAULT 'EGP',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed', 'refunded')),
    paymob_order_id TEXT,
    paymob_payment_key TEXT,
    transaction_id TEXT,
    payment_method TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_intents_booking ON payment_intents(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_user ON payment_intents(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_status ON payment_intents(status);

-- 4. Wallets for providers
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    currency TEXT DEFAULT 'EGP',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallets_provider ON wallets(provider_id);

-- 5. Transactions log
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    provider_id UUID REFERENCES profiles(id),
    wallet_id UUID REFERENCES wallets(id),
    amount DECIMAL(10, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('earning', 'commission', 'withdrawal', 'refund')),
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    description TEXT,
    paymob_order_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_provider ON transactions(provider_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking ON transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);

-- 6. Withdrawal Requests
CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    wallet_id UUID REFERENCES wallets(id),
    amount DECIMAL(10, 2) NOT NULL,
    method TEXT NOT NULL CHECK (method IN ('bank', 'vodafone_cash', 'instapay', 'fawry')),
    account_number TEXT NOT NULL,
    account_holder TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'processing')),
    admin_id UUID REFERENCES profiles(id),
    admin_note TEXT,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_provider ON withdrawal_requests(provider_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON withdrawal_requests(status);

-- 7. Enable Realtime for tracking tables
ALTER PUBLICATION supabase_realtime ADD TABLE provider_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE withdrawal_requests;

-- 8. Function to handle booking notification trigger
CREATE OR REPLACE FUNCTION notify_booking_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    supabase_url TEXT;
    service_key TEXT;
BEGIN
    supabase_url := current_setting('app.supabase_url', true);
    service_key := current_setting('app.service_role_key', true);
    
    IF supabase_url IS NOT NULL AND service_key IS NOT NULL THEN
        PERFORM net.http_post(
            url := supabase_url || '/functions/v1/order-notification-trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'table', TG_TABLE_NAME,
                'type', TG_OP,
                'record', row_to_json(NEW),
                'old_record', row_to_json(OLD)
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- 9. Function to handle withdrawal notification trigger
CREATE OR REPLACE FUNCTION notify_withdrawal_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    supabase_url TEXT;
    service_key TEXT;
BEGIN
    supabase_url := current_setting('app.supabase_url', true);
    service_key := current_setting('app.service_role_key', true);
    
    IF supabase_url IS NOT NULL AND service_key IS NOT NULL THEN
        PERFORM net.http_post(
            url := supabase_url || '/functions/v1/order-notification-trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'table', TG_TABLE_NAME,
                'type', TG_OP,
                'record', row_to_json(NEW),
                'old_record', row_to_json(OLD)
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- 10. Triggers for bookings
DROP TRIGGER IF EXISTS on_booking_change ON bookings;
CREATE TRIGGER on_booking_change
    AFTER INSERT OR UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION notify_booking_change();

-- 11. Triggers for withdrawal requests
DROP TRIGGER IF EXISTS on_withdrawal_change ON withdrawal_requests;
CREATE TRIGGER on_withdrawal_change
    AFTER INSERT OR UPDATE ON withdrawal_requests
    FOR EACH ROW EXECUTE FUNCTION notify_withdrawal_change();

-- 12. Function to update location automatically from provider_profiles
CREATE OR REPLACE FUNCTION sync_provider_location()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        INSERT INTO provider_locations (provider_id, latitude, longitude, updated_at)
        VALUES (NEW.id, NEW.latitude, NEW.longitude, NOW())
        ON CONFLICT (provider_id) DO UPDATE SET
            latitude = NEW.latitude,
            longitude = NEW.longitude,
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

-- 13. Trigger to sync location from provider_profiles
DROP TRIGGER IF EXISTS sync_provider_location_trigger ON provider_profiles;
CREATE TRIGGER sync_provider_location_trigger
    AFTER UPDATE OF latitude, longitude ON provider_profiles
    FOR EACH ROW EXECUTE FUNCTION sync_provider_location();

-- 14. Function to calculate provider earnings on booking completion
CREATE OR REPLACE FUNCTION calculate_provider_earnings()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    provider_wallet_id UUID;
    current_balance DECIMAL(10, 2);
    net_amount DECIMAL(10, 2);
    commission_amount DECIMAL(10, 2);
BEGIN
    -- Only process on completion or payment
    IF (NEW.status = 'completed' OR NEW.payment_status = 'paid') AND OLD.status != 'completed' THEN
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
        
        -- Log transaction
        INSERT INTO transactions (booking_id, provider_id, wallet_id, amount, type, description)
        VALUES (NEW.id, NEW.provider_id, provider_wallet_id, net_amount, 'earning',
                'Earnings from booking completed on ' || NOW());
        
        -- Log commission
        IF commission_amount > 0 THEN
            INSERT INTO transactions (booking_id, provider_id, wallet_id, amount, type, description)
            VALUES (NEW.id, NEW.provider_id, provider_wallet_id, commission_amount, 'commission',
                    'Platform commission from booking');
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- 15. Trigger to calculate earnings on booking update
DROP TRIGGER IF EXISTS calculate_booking_earnings ON bookings;
CREATE TRIGGER calculate_booking_earnings
    AFTER UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION calculate_provider_earnings();

-- 16. Enable pg_net extension for HTTP calls
CREATE EXTENSION IF NOT EXISTS http;

-- =====================================================
-- NOTIFICATION SETUP NOTES
-- =====================================================
-- 1. Enable pg_net extension in Supabase Dashboard:
--    Dashboard → Database → Extensions → pg_net → Enable
--
-- 2. Add Supabase Secrets:
--    - FIREBASE_SERVER_KEY (from Firebase Console → Project Settings → Cloud Messaging)
--    - PAYMOB_SECRET_KEY
--    - PAYMOB_PUBLIC_KEY
--    - PAYMOB_INTEGRATION_ID_CARD
--    - PAYMOB_INTEGRATION_ID_WALLET
--    - PAYMOB_IFRAME_ID
--
-- 3. Deploy Edge Functions:
--    - order-notification-trigger
--    - send-notification
--
-- 4. Make sure FCM tokens are saved when users register/login

-- =====================================================
-- BROADCAST BOOKING - RACE CONDITION HANDLING
-- =====================================================

-- Function to atomically accept a broadcast booking
CREATE OR REPLACE FUNCTION accept_broadcast_booking(
    p_booking_id UUID,
    p_provider_id UUID
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_provider_id UUID;
BEGIN
    -- Try to update only if provider_id is still NULL (no one accepted yet)
    UPDATE bookings
    SET provider_id = p_provider_id, updated_at = NOW()
    WHERE id = p_booking_id AND provider_id IS NULL
    RETURNING provider_id INTO v_provider_id;

    -- If v_provider_id is NULL, update failed (someone else got it)
    RETURN v_provider_id IS NOT NULL;
END;
$$;

-- RLS policy for providers to view pending broadcast bookings
CREATE POLICY "Providers can view broadcast bookings"
    ON bookings FOR SELECT
    USING (provider_id IS NULL AND status = 'pending');
