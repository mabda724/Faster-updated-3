-- =====================================================
-- FASTER APP - إصلاح شامل (Disable ALL RLS)
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- ==================== تعطيل كل RLS مؤقتاً ====================

ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE provider_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE provider_services DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE services DISABLE ROW LEVEL SECURITY;
ALTER TABLE categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE wallets DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE provider_locations DISABLE ROW LEVEL SECURITY;
ALTER TABLE fcm_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE refund_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE offers DISABLE ROW LEVEL SECURITY;
ALTER TABLE carousel_images DISABLE ROW LEVEL SECURITY;
ALTER TABLE provider_analytics DISABLE ROW LEVEL SECURITY;

-- ==================== إضافة الأعمدة الناقصة ====================

-- categories
DO $$ BEGIN
    ALTER TABLE categories ADD COLUMN IF NOT EXISTS icon_color TEXT DEFAULT '#3B82F6';
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
EXCEPTION WHEN others THEN NULL;
END $$;

-- provider_profiles
DO $$ BEGIN
    ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS address TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS address_details TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

-- bookings
DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS total_price DECIMAL(10,2);
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(10,2);
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS provider_earning DECIMAL(10,2);
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2);
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid';
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS address TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS address_details TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS client_lat DOUBLE PRECISION;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE bookings ADD COLUMN IF NOT EXISTS client_lng DOUBLE PRECISION;
EXCEPTION WHEN others THEN NULL;
END $$;

-- services
DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS title_ar TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS description TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS description_ar TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS image_url TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE services ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2) DEFAULT 0.10;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ==================== حذف البيانات القديمة ====================

DELETE FROM categories WHERE name IS NULL OR name = '';
DELETE FROM services WHERE title IS NULL OR title = '';

-- ==================== إضافة الأقسام الأساسية ====================

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color, is_active) VALUES
  ('plumbing', 'سباكة', 'Plumbing', '59299', '#3B82F6', true),
  ('electrical', 'كهرباء', 'Electrical', '58930', '#F59E0B', true),
  ('cleaning', 'تنظيف', 'Cleaning', '58937', '#22C55E', true),
  ('painting', 'دهان', 'Painting', '58935', '#8B5CF6', true),
  ('ac_repair', 'تكييف', 'AC Repair', '59008', '#06B6D4', true),
  ('carpentry', 'نجارة', 'Carpentry', '58934', '#EF4444', true),
  ('pest_control', 'مكافحة حشرات', 'Pest Control', '58942', '#84CC16', true),
  ('moving', 'نقل أثاث', 'Moving', '58946', '#F97316', true),
  ('gardening', 'حدائق', 'Gardening', '58941', '#10B981', true),
  ('appliance_repair', 'أجهزة منزلية', 'Appliance Repair', '59008', '#EC4899', true)
ON CONFLICT (name) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  icon_color = EXCLUDED.icon_color,
  is_active = true;

-- ==================== إضافة الخدمات ====================

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Leak Repair', 'إصلاح تسريب', 'Fix all types of leaks', 'إصلاح جميع أنواع التسريبات', 100, 100, id, true, 0.10 FROM categories WHERE name = 'plumbing' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Faucet Installation', 'تركيب خلاط', 'Install new faucet', 'تركيب خلاط جديد', 150, 150, id, true, 0.10 FROM categories WHERE name = 'plumbing' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Electrical Repair', 'إصلاح كهربائي', 'Fix electrical faults', 'إصلاح أعطال كهربائية', 150, 150, id, true, 0.10 FROM categories WHERE name = 'electrical' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Fan Installation', 'تركيب نجفة', 'Install ceiling fan', 'تركيب نجفة', 100, 100, id, true, 0.10 FROM categories WHERE name = 'electrical' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Home Cleaning', 'تنظيف منزل', 'Full home cleaning', 'تنظيف شامل للمنزل', 300, 300, id, true, 0.10 FROM categories WHERE name = 'cleaning' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Carpet Cleaning', 'غسيل سجاد', 'Clean carpets', 'غسيل سجاد وموكيت', 200, 200, id, true, 0.10 FROM categories WHERE name = 'cleaning' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Wall Painting', 'دهان حوائط', 'Paint room walls', 'دهان حوائط', 500, 500, id, true, 0.10 FROM categories WHERE name = 'painting' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'AC Maintenance', 'صيانة تكييف', 'Regular AC maintenance', 'صيانة دورية للتكييف', 200, 200, id, true, 0.10 FROM categories WHERE name = 'ac_repair' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'AC Cleaning', 'غسيل تكييف', 'Internal AC cleaning', 'غسيل داخلي للتكييف', 150, 150, id, true, 0.10 FROM categories WHERE name = 'ac_repair' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Furniture Repair', 'إصلاح أثاث', 'Repair wooden furniture', 'إصلاح أثاث خشبي', 200, 200, id, true, 0.10 FROM categories WHERE name = 'carpentry' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Pest Control', 'مكافحة حشرات', 'Spray pest control', 'رش مكافحة حشرات', 250, 250, id, true, 0.10 FROM categories WHERE name = 'pest_control' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Furniture Moving', 'نقل أثاث', 'Move household furniture', 'نقل أثاث منزلي', 500, 500, id, true, 0.10 FROM categories WHERE name = 'moving' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Tree Pruning', 'تقليم أشجار', 'Prune trees', 'تقليم وتهذيب أشجار', 200, 200, id, true, 0.10 FROM categories WHERE name = 'gardening' ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, description, description_ar, base_price, price, category_id, is_active, commission_rate) 
SELECT 'Appliance Repair', 'إصلاح أجهزة', 'Repair home appliances', 'إصلاح أجهزة منزلية', 200, 200, id, true, 0.10 FROM categories WHERE name = 'appliance_repair' ON CONFLICT DO NOTHING;

-- ==================== عرض النتيجة ====================
SELECT 'الأقسام: ' || COUNT(*) as result FROM categories;
SELECT 'الخدمات: ' || COUNT(*) as result FROM services;