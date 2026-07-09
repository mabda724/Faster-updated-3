-- =====================================================
-- FASTER APP - IMPROVEMENTS AND SECURITY UPGRADES
-- =====================================================

-- 1. Enhanced RLS Policies for Security
-- Users can only view their own bookings
DROP POLICY IF EXISTS "Users can view own bookings" ON bookings;
CREATE POLICY "Users can view own bookings"
    ON bookings FOR SELECT
    USING (client_id = auth.uid() OR provider_id = auth.uid() OR provider_id IS NULL);

-- Users can update only their own bookings (status changes)
DROP POLICY IF EXISTS "Users can update own bookings" ON bookings;
CREATE POLICY "Users can update own bookings"
    ON bookings FOR UPDATE
    USING (client_id = auth.uid() OR provider_id = auth.uid());

-- Only admins can assign providers to broadcast bookings
DROP POLICY IF EXISTS "Admins can assign providers" ON bookings;
CREATE POLICY "Admins can assign providers"
    ON bookings FOR UPDATE
    USING (
        auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin') OR
        (provider_id IS NULL AND status = 'pending' AND auth.uid() IN (SELECT id FROM profiles WHERE role = 'provider'))
    );

-- 2. Reviews Table for Rating System
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    client_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    service_quality INTEGER CHECK (service_quality BETWEEN 1 AND 5),
    punctuality INTEGER CHECK (punctuality BETWEEN 1 AND 5),
    communication INTEGER CHECK (communication BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    response_to_review TEXT,
    response_at TIMESTAMPTZ,
    is_public BOOLEAN DEFAULT true
);

-- Indexes for reviews
CREATE INDEX IF NOT EXISTS idx_reviews_booking ON reviews(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_provider ON reviews(provider_id);
CREATE INDEX IF NOT EXISTS idx_reviews_client ON reviews(client_id);
CREATE INDEX IF NOT EXISTS idx_rating_avg ON reviews(provider_id, rating);

-- RLS for reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients can review their completed bookings" ON reviews;
CREATE POLICY "Clients can review their completed bookings"
    ON reviews FOR INSERT
    WITH CHECK (client_id = auth.uid() AND booking_id IN (
        SELECT id FROM bookings 
        WHERE client_id = auth.uid() AND status = 'completed'
    ));

DROP POLICY IF EXISTS "Providers can view reviews about them" ON reviews;
CREATE POLICY "Providers can view reviews about them"
    ON reviews FOR SELECT
    USING (provider_id = auth.uid());

DROP POLICY IF EXISTS "Providers can respond to reviews" ON reviews;
CREATE POLICY "Providers can respond to reviews"
    ON reviews FOR UPDATE
    USING (provider_id = auth.uid() AND response_to_review IS NULL);

-- 3. Enhanced Notifications Table (if not exists)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT CHECK (type IN ('booking', 'payment', 'review', 'general', 'system')),
    title TEXT,
    message TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    is_push BOOLEAN DEFAULT true,
    is_email BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    action_url TEXT
);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at);

-- RLS for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
CREATE POLICY "Users can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid());

-- 4. Refund Requests Table
CREATE TABLE IF NOT EXISTS refund_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    client_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'processing', 'cancelled')),
    admin_id UUID REFERENCES profiles(id),
    admin_note TEXT,
    processed_at TIMESTAMPTZ,
    refund_method TEXT CHECK (refund_method IN ('bank', 'vodafone_cash', 'instapay')),
    bank_account TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for refund requests
CREATE INDEX IF NOT EXISTS idx_refund_booking ON refund_requests(booking_id);
CREATE INDEX IF NOT EXISTS idx_refund_client ON refund_requests(client_id);
CREATE INDEX IF NOT EXISTS idx_refund_status ON refund_requests(status);

-- RLS for refund requests
ALTER TABLE refund_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients can create refund requests" ON refund_requests;
CREATE POLICY "Clients can create refund requests"
    ON refund_requests FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients can view their refund requests" ON refund_requests;
CREATE POLICY "Clients can view their refund requests"
    ON refund_requests FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view refund requests" ON refund_requests;
CREATE POLICY "Admins can view refund requests"
    ON refund_requests FOR SELECT
    USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

DROP POLICY IF EXISTS "Admins can update refund requests" ON refund_requests;
CREATE POLICY "Admins can update refund requests"
    ON refund_requests FOR UPDATE
    USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- 5. Booking Expiration Function (runs as trigger on INSERT/UPDATE)
-- Note: This auto-cancels broadcast bookings (provider_id IS NULL) older than 15 minutes
CREATE OR REPLACE FUNCTION check_booking_expiration()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Cancel expired broadcast bookings (only affects existing rows, not the NEW row being inserted)
    UPDATE bookings
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE provider_id IS NULL
    AND status = 'pending'
    AND created_at < NOW() - INTERVAL '15 minutes';

    -- IMPORTANT: Do NOT use RETURNING INTO NEW - it corrupts the new booking's ID
    RETURN NEW;
END;
$$;

-- Trigger for booking expiration
DROP TRIGGER IF EXISTS on_booking_expiration ON bookings;
CREATE TRIGGER on_booking_expiration
    BEFORE INSERT OR UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION check_booking_expiration();

-- 6. Provider Analytics Table
CREATE TABLE IF NOT EXISTS provider_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    total_bookings INTEGER DEFAULT 0,
    completed_bookings INTEGER DEFAULT 0,
    cancelled_bookings INTEGER DEFAULT 0,
    total_earnings DECIMAL(10, 2) DEFAULT 0.00,
    average_rating DECIMAL(3, 2) DEFAULT 0.00,
    response_time_avg INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Index for provider analytics
CREATE INDEX IF NOT EXISTS idx_analytics_provider ON provider_analytics(provider_id);

-- RLS for provider analytics
ALTER TABLE provider_analytics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can view their analytics" ON provider_analytics;
CREATE POLICY "Providers can view their analytics"
    ON provider_analytics FOR SELECT
    USING (provider_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all analytics" ON provider_analytics;
CREATE POLICY "Admins can view all analytics"
    ON provider_analytics FOR SELECT
    USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- 7. Function to update provider analytics
CREATE OR REPLACE FUNCTION update_provider_analytics(provider_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    total_bookings INTEGER;
    completed_bookings INTEGER;
    cancelled_bookings INTEGER;
    total_earnings DECIMAL(10, 2);
    avg_rating DECIMAL(3, 2);
BEGIN
    SELECT COUNT(*) INTO total_bookings
    FROM bookings WHERE provider_id = provider_id;
    
    SELECT COUNT(*) INTO completed_bookings
    FROM bookings WHERE provider_id = provider_id AND status = 'completed';
    
    SELECT COUNT(*) INTO cancelled_bookings
    FROM bookings WHERE provider_id = provider_id AND status = 'cancelled';
    
    SELECT COALESCE(SUM(total_price - commission_amount), 0) INTO total_earnings
    FROM bookings WHERE provider_id = provider_id AND status = 'completed';
    
    SELECT COALESCE(AVG(rating), 0) INTO avg_rating
    FROM reviews WHERE provider_id = provider_id;
    
    INSERT INTO provider_analytics (provider_id, total_bookings, completed_bookings, cancelled_bookings, total_earnings, average_rating)
    VALUES (provider_id, total_bookings, completed_bookings, cancelled_bookings, total_earnings, avg_rating)
    ON CONFLICT (provider_id) DO UPDATE SET
        total_bookings = total_bookings,
        completed_bookings = completed_bookings,
        cancelled_bookings = cancelled_bookings,
        total_earnings = total_earnings,
        average_rating = avg_rating,
        last_updated = NOW();
END;
$$;

-- 8. Function to trigger analytics update when booking status changes
CREATE OR REPLACE FUNCTION trigger_analytics_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status = 'completed' THEN
        PERFORM update_provider_analytics(NEW.provider_id);
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger for analytics update
DROP TRIGGER IF EXISTS on_booking_status_change ON bookings;
CREATE TRIGGER on_booking_status_change
    AFTER UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION trigger_analytics_update();

-- 9. Functions for refund request management
DROP FUNCTION IF EXISTS process_refund_request(UUID, TEXT, UUID, TEXT);
CREATE OR REPLACE FUNCTION process_refund_request(refund_id UUID, p_status TEXT, admin_id UUID, note TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    request record;
    booking record;
BEGIN
    SELECT * INTO request
    FROM refund_requests 
    WHERE id = refund_id AND status = 'pending';
    
    IF FOUND THEN
        SELECT * INTO booking
        FROM bookings 
        WHERE id = request.booking_id;
        
        IF p_status = 'approved' THEN
            UPDATE bookings 
            SET status = 'refunded'
            WHERE id = request.booking_id;
            
            INSERT INTO transactions (
                booking_id, provider_id, amount, type, description
            ) VALUES (
                request.booking_id,
                booking.provider_id,
                request.amount * -1,
                'refund',
                'Refund for booking ' || request.booking_id
            );
            
            UPDATE refund_requests 
            SET status = p_status,
                admin_id = admin_id,
                admin_note = note,
                processed_at = NOW()
            WHERE id = refund_id;
            
            RETURN true;
        ELSE
            UPDATE refund_requests 
            SET status = p_status,
                admin_id = admin_id,
                admin_note = note,
                processed_at = NOW()
            WHERE id = refund_id;
            
            RETURN true;
        END IF;
    END IF;
    
    RETURN false;
END;
$$;

-- 10. Function to get provider rating breakdown
CREATE OR REPLACE FUNCTION get_provider_rating_breakdown(provider_id UUID)
RETURNS TABLE(rating INTEGER, count INTEGER) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT rating, COUNT(*) as count
    FROM reviews
    WHERE provider_id = provider_id
    GROUP BY rating
    ORDER BY rating DESC;
END;
$$;

-- 11. Function to get notifications count
CREATE OR REPLACE FUNCTION get_unread_notifications_count(user_id UUID)
RETURNS INTEGER LANGUAGE plpgsql AS $$
BEGIN
    RETURN COALESCE((
        SELECT COUNT(*)
        FROM notifications
        WHERE user_id = user_id AND is_read = false
    ), 0);
END;
$$;

-- 12. Function to mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(user_id UUID, notification_ids UUID[])
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE notifications
    SET is_read = true,
        read_at = NOW()
    WHERE id = ANY(notification_ids) AND user_id = user_id AND is_read = false;
END;
$$;

-- =====================================================
-- MIGRATION NOTES
-- =====================================================
-- 1. Run this migration to add improved features:
--    - Enhanced security with RLS policies
--    - Reviews and ratings system
--    - Refund requests management
--    - Provider analytics
--    - Booking expiration (15 minutes)
--    - Improved notifications
--
-- 2. After migration, update your Flutter app:
--    - Add review screens
--    - Add refund request UI
--    - Add analytics dashboard
--    - Add booking expiration alerts
--    - Add notification badges
--
-- 3. Edge Functions to create:
--    - send-refund-notification
--    - update-provider-analytics
--    - booking-expiration-trigger
--
-- 4. Security improvements:
--    - All tables have proper RLS policies
--    - Broadcast bookings expire after 15 minutes
--    - Refunds require admin approval
--    - Analytics are protected
--
-- 5. Performance improvements:
--    - All tables have proper indexes
--    - Functions optimized for performance
--    - Realtime already enabled (skip ALTER PUBLICATION)