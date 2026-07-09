-- تحسينات واجهة الصناعي والميزات الجديدة
-- Migration: 023_provider_enhancements.sql

-- 1. إضافة عمود لتتبع موقع الصناعي في الوقت الحقيقي
ALTER TABLE provider_profiles 
ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP WITH TIME ZONE;

-- 2. إضافة عمود لتصنيف الصناعي حسب التقييم
ALTER TABLE provider_profiles 
ADD COLUMN IF NOT EXISTS rating_tier TEXT DEFAULT 'bronze',
ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS avg_rating DOUBLE PRECISION DEFAULT 0.0;

-- 3. إضافة عمود للتحكم في إلغاء الطلب
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS cancellation_allowed BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS cancellation_deadline TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS cancelled_by_provider_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_free_service BOOLEAN DEFAULT false;

-- 4. إضافة عمود لتصوير العطل
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS job_photo_url TEXT,
ADD COLUMN IF NOT EXISTS job_photo_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS job_photo_verified_at TIMESTAMP WITH TIME ZONE;

-- 5. إضافة حالة قيد الانتظار للصناعي
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS provider_status TEXT DEFAULT 'pending';

-- 6. إضافة عمود لتتبع حالة الطلب بشكل أفضل
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS client_notified_of_arrival BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS provider_notified_of_completion BOOLEAN DEFAULT false;

-- 7. إنشاء دالة لتحديث تصنيف الصناعي حسب التقييم
CREATE OR REPLACE FUNCTION update_provider_rating_tier()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE provider_profiles pp
    SET 
        avg_rating = (
            SELECT COALESCE(AVG(r.rating), 0)
            FROM reviews r
            WHERE r.provider_id = pp.id
        ),
        total_reviews = (
            SELECT COUNT(*)
            FROM reviews r
            WHERE r.provider_id = pp.id
        ),
        rating_tier = CASE
            WHEN (
                SELECT COALESCE(AVG(r.rating), 0)
                FROM reviews r
                WHERE r.provider_id = pp.id
            ) >= 4.5 THEN 'gold'
            WHEN (
                SELECT COALESCE(AVG(r.rating), 0)
                FROM reviews r
                WHERE r.provider_id = pp.id
            ) >= 4.0 THEN 'silver'
            WHEN (
                SELECT COALESCE(AVG(r.rating), 0)
                FROM reviews r
                WHERE r.provider_id = pp.id
            ) >= 3.5 THEN 'bronze'
            ELSE 'new'
        END
    WHERE pp.id = NEW.provider_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. إنشاء Trigger لتحديث التصنيف عند إضافة تقييم جديد
DROP TRIGGER IF EXISTS update_provider_rating_on_review ON reviews;
CREATE TRIGGER update_provider_rating_on_review
AFTER INSERT OR UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_provider_rating_tier();

-- 9. إنشاء دالة للتحديث موقع الصناعي
CREATE OR REPLACE FUNCTION update_provider_location(provider_id UUID, lat DOUBLE PRECISION, lng DOUBLE PRECISION)
RETURNS VOID AS $$
BEGIN
    UPDATE provider_profiles
    SET 
        current_lat = lat,
        current_lng = lng,
        last_location_update = NOW()
    WHERE id = provider_id;
END;
$$ LANGUAGE plpgsql;

-- 10. إنشاء دالة للتحديث حالة الصناعي في الطلب
CREATE OR REPLACE FUNCTION update_provider_booking_status(booking_id UUID, new_status TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE bookings
    SET provider_status = new_status
    WHERE id = booking_id;
END;
$$ LANGUAGE plpgsql;

-- 11. إنشاء دالة للسماح إمكانية إلغاء الطلب
CREATE OR REPLACE FUNCTION check_cancellation_allowed(booking_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    booking_status TEXT;
    booking_created_at TIMESTAMP WITH TIME ZONE;
    deadline TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT status, created_at, cancellation_deadline
    INTO booking_status, booking_created_at, deadline
    FROM bookings
    WHERE id = booking_id;
    
    -- يمكن إلغاء الطلب فقط إذا كان في حالة معينة ولم ينتهي الوقت المحدد
    IF booking_status IN ('accepted', 'on_the_way', 'arrived') 
       AND deadline IS NOT NULL 
       AND deadline > NOW() THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 12. إنشاء دالة للتحديث وقت إلغاء الطلب
CREATE OR REPLACE FUNCTION set_cancellation_deadline(booking_id UUID, minutes INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE bookings
    SET cancellation_deadline = NOW() + (minutes || ' minutes')::INTERVAL
    WHERE id = booking_id;
END;
$$ LANGUAGE plpgsql;

-- 13. إنشاء دالة لنقل الطلب تلقائياً لصناعي آخر عند الإلغاء
CREATE OR REPLACE FUNCTION reassign_booking_to_next_provider(booking_id UUID)
RETURNS UUID AS $$
DECLARE
    original_provider_id UUID;
    service_id UUID;
    client_lat DOUBLE PRECISION;
    client_lng DOUBLE PRECISION;
    search_radius_km INTEGER;
    new_provider_id UUID;
BEGIN
    -- الحصول على بيانات الطلب الأصلي
    SELECT provider_id, service_id, client_lat, client_lng
    INTO original_provider_id, service_id, client_lat, client_lng
    FROM bookings
    WHERE id = booking_id;
    
    -- الحصول على نصف البحث للخدمة
    SELECT search_radius_km
    INTO search_radius_km
    FROM services
    WHERE id = service_id;
    
    -- البحث عن صناعي آخر متاح وقريب
    SELECT pp.id
    INTO new_provider_id
    FROM provider_profiles pp
    JOIN provider_services ps ON pp.id = ps.provider_id
    WHERE ps.service_id = service_id
      AND pp.is_online = true
      AND pp.is_verified = true
      AND pp.id != original_provider_id
      AND pp.current_lat IS NOT NULL
      AND pp.current_lng IS NOT NULL
      AND client_lat IS NOT NULL
      AND client_lng IS NOT NULL
      AND ST_DWithin(
        ST_MakePoint(pp.current_lng, pp.current_lat)::geography,
        ST_MakePoint(client_lng, client_lat)::geography,
        search_radius_km * 1000
      )
    ORDER BY pp.rating DESC
    LIMIT 1;
    
    -- إذا وجدنا صناعي آخر، حدثف الطلب إليه
    IF new_provider_id IS NOT NULL THEN
        UPDATE bookings
        SET 
            provider_id = new_provider_id,
            status = 'pending',
            provider_status = 'pending',
            cancellation_deadline = NULL,
            cancelled_by_provider_id = NULL
        WHERE id = booking_id;
        
        RETURN new_provider_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 14. إنشاء دالة لإرسال إشعار للعميل عند وصول الصناعي
CREATE OR REPLACE FUNCTION notify_client_of_arrival(booking_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE bookings
    SET client_notified_of_arrival = TRUE
    WHERE id = booking_id;
END;
$$ LANGUAGE plpgsql;

-- 15. إنشاء دالة لإرسال إشعار للصناعي عند إتمام الخدمة
CREATE OR REPLACE FUNCTION notify_provider_of_completion(booking_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE bookings
    SET provider_notified_of_completion = TRUE
    WHERE id = booking_id;
END;
$$ LANGUAGE plpgsql;

-- 16. إضافة فهارس لتسريع الاستعلامات
CREATE INDEX IF NOT EXISTS idx_provider_profiles_rating_tier ON provider_profiles(rating_tier);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_status ON bookings(provider_status);
CREATE INDEX IF NOT EXISTS idx_bookings_cancellation_deadline ON bookings(cancellation_deadline);
CREATE INDEX IF NOT EXISTS idx_bookings_is_free_service ON bookings(is_free_service);

-- 17. إضافة تعليقات
COMMENT ON COLUMN provider_profiles.current_lat IS 'Current latitude of provider for real-time tracking';
COMMENT ON COLUMN provider_profiles.current_lng IS 'Current longitude of provider for real-time tracking';
COMMENT ON COLUMN provider_profiles.rating_tier IS 'Provider rating tier: gold (4.5+), silver (4.0+), bronze (3.5+), new (<3.5)';
COMMENT ON COLUMN bookings.cancellation_allowed IS 'Whether the provider can cancel this booking';
COMMENT ON COLUMN bookings.cancellation_deadline IS 'Deadline for provider to cancel the booking (5 minutes after acceptance)';
COMMENT ON COLUMN bookings.provider_status IS 'Provider status: pending, accepted, on_the_way, arrived, in_progress, completed, cancelled';
COMMENT ON COLUMN bookings.job_photo_url IS 'URL of job photo taken before starting work';
COMMENT ON COLUMN bookings.job_photo_verified IS 'Whether the job photo has been verified by admin';

-- 18. تحديث البيانات الموجودة
-- تحديث التصنيف الحالي للصناعيين
UPDATE provider_profiles
SET 
    avg_rating = (
        SELECT COALESCE(AVG(r.rating), 0)
        FROM reviews r
        WHERE r.provider_id = provider_profiles.id
    ),
    total_reviews = (
        SELECT COUNT(*)
        FROM reviews r
        WHERE r.provider_id = provider_profiles.id
    ),
    rating_tier = CASE
        WHEN (
            SELECT COALESCE(AVG(r.rating), 0)
            FROM reviews r
            WHERE r.provider_id = provider_profiles.id
        ) >= 4.5 THEN 'gold'
        WHEN (
            SELECT COALESCE(AVG(r.rating), 0)
            FROM reviews r
            WHERE r.provider_id = provider_profiles.id
        ) >= 4.0 THEN 'silver'
        WHEN (
            SELECT COALESCE(AVG(r.rating), 0)
            FROM reviews r
            WHERE r.provider_id = provider_profiles.id
        ) >= 3.5 THEN 'bronze'
        ELSE 'new'
    END;

-- تحديث حالة الصناعي في الطلبات الحالية
UPDATE bookings
SET provider_status = CASE
    WHEN status = 'accepted' THEN 'accepted'
    WHEN status = 'on_the_way' THEN 'on_the_way'
    WHEN status = 'arrived' THEN 'arrived'
    WHEN status = 'in_progress' THEN 'in_progress'
    WHEN status = 'completed' THEN 'completed'
    WHEN status = 'cancelled' THEN 'cancelled'
    ELSE 'pending'
END
WHERE provider_status IS NULL OR provider_status = '';
