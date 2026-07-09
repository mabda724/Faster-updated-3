-- =====================================================
-- FASTER APP - إضافة الأعمدة والتخصصات
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- ==================== إضافة أعمدة للأقسام ====================
DO $$ BEGIN
    ALTER TABLE categories ADD COLUMN IF NOT EXISTS icon_color TEXT DEFAULT '#3B82F6';
EXCEPTION WHEN others THEN NULL;
END $$;

-- ==================== إضافة الأقسام (Categories) ====================

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('plumbing', 'سباكة', 'Plumbing', '59299', '#3B82F6')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('electrical', 'كهرباء', 'Electrical', '58930', '#F59E0B')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('cleaning', 'تنظيف', 'Cleaning', '58937', '#22C55E')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('painting', 'دهان', 'Painting', '58935', '#8B5CF6')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('ac_repair', 'تكييف', 'AC Repair', '59008', '#06B6D4')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('carpentry', 'نجارة', 'Carpentry', '58934', '#EF4444')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('pest_control', 'مكافحة حشرات', 'Pest Control', '58942', '#84CC16')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('moving', 'نقل أثاث', 'Moving', '58946', '#F97316')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('gardening', 'حدائق', 'Gardening', '58941', '#10B981')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('appliance_repair', 'أجهزة منزلية', 'Appliance Repair', '59008', '#EC4899')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('metal_work', 'حدادة', 'Metal Work', '58933', '#6366F1')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

INSERT INTO categories (name, name_ar, name_en, icon_url, icon_color) VALUES
  ('car_wash', 'غسيل سيارات', 'Car Wash', '58947', '#0EA5E9')
ON CONFLICT (name) DO UPDATE SET 
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon_url = EXCLUDED.icon_url,
  icon_color = EXCLUDED.icon_color;

-- ==================== إضافة الخدمات ====================

-- خدمات السباكة
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح تسريب', 'Leak Repair', 100, 100, id, true, 0.10 FROM categories WHERE name = 'plumbing'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تركيب خلاط', 'Faucet Installation', 150, 150, id, true, 0.10 FROM categories WHERE name = 'plumbing'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تسليك مجاري', 'Drain Cleaning', 200, 200, id, true, 0.10 FROM categories WHERE name = 'plumbing'
ON CONFLICT DO NOTHING;

-- خدمات الكهرباء
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح كهربائي', 'Electrical Repair', 150, 150, id, true, 0.10 FROM categories WHERE name = 'electrical'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تركيب نجفة', 'Fan Installation', 100, 100, id, true, 0.10 FROM categories WHERE name = 'electrical'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تركيب إضاءة LED', 'LED Lighting', 120, 120, id, true, 0.10 FROM categories WHERE name = 'electrical'
ON CONFLICT DO NOTHING;

-- خدمات التنظيف
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تنظيف منزل شامل', 'Full Home Cleaning', 300, 300, id, true, 0.10 FROM categories WHERE name = 'cleaning'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تنظيف نوافذ', 'Window Cleaning', 150, 150, id, true, 0.10 FROM categories WHERE name = 'cleaning'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'غسيل سجاد', 'Carpet Cleaning', 200, 200, id, true, 0.10 FROM categories WHERE name = 'cleaning'
ON CONFLICT DO NOTHING;

-- خدمات الدهان
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'دهان حوائط', 'Wall Painting', 500, 500, id, true, 0.10 FROM categories WHERE name = 'painting'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'دهان سقف', 'Ceiling Painting', 400, 400, id, true, 0.10 FROM categories WHERE name = 'painting'
ON CONFLICT DO NOTHING;

-- خدمات التكييف
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'صيانة تكييف', 'AC Maintenance', 200, 200, id, true, 0.10 FROM categories WHERE name = 'ac_repair'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تعبئة فريون', 'Refrigerant Refill', 250, 250, id, true, 0.10 FROM categories WHERE name = 'ac_repair'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'غسيل تكييف', 'AC Cleaning', 150, 150, id, true, 0.10 FROM categories WHERE name = 'ac_repair'
ON CONFLICT DO NOTHING;

-- خدمات النجارة
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح أثاث', 'Furniture Repair', 200, 200, id, true, 0.10 FROM categories WHERE name = 'carpentry'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تركيب باب', 'Door Installation', 350, 350, id, true, 0.10 FROM categories WHERE name = 'carpentry'
ON CONFLICT DO NOTHING;

-- خدمات مكافحة الحشرات
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'رش حشرات', 'Pest Control Spray', 250, 250, id, true, 0.10 FROM categories WHERE name = 'pest_control'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'مكافحة صراصير', 'Cockroach Control', 150, 150, id, true, 0.10 FROM categories WHERE name = 'pest_control'
ON CONFLICT DO NOTHING;

-- خدمات نقل الأثاث
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'نقل أثاث', 'Furniture Moving', 500, 500, id, true, 0.10 FROM categories WHERE name = 'moving'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'فك وتركيب أثاث', 'Furniture Assembly', 300, 300, id, true, 0.10 FROM categories WHERE name = 'moving'
ON CONFLICT DO NOTHING;

-- خدمات الحدائق
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تقليم أشجار', 'Tree Pruning', 200, 200, id, true, 0.10 FROM categories WHERE name = 'gardening'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'زراعة حديقة', 'Garden Planting', 300, 300, id, true, 0.10 FROM categories WHERE name = 'gardening'
ON CONFLICT DO NOTHING;

-- خدمات الأجهزة المنزلية
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح ثلاجة', 'Fridge Repair', 200, 200, id, true, 0.10 FROM categories WHERE name = 'appliance_repair'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح غسالة', 'Washing Machine Repair', 180, 180, id, true, 0.10 FROM categories WHERE name = 'appliance_repair'
ON CONFLICT DO NOTHING;

-- خدمات الحدادة
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'تصنيع بوابة', 'Gate Manufacturing', 1500, 1500, id, true, 0.10 FROM categories WHERE name = 'metal_work'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'إصلاح بوابة', 'Gate Repair', 300, 300, id, true, 0.10 FROM categories WHERE name = 'metal_work'
ON CONFLICT DO NOTHING;

-- خدمات غسيل السيارات
INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'غسيل سيارة خارجي', 'External Car Wash', 100, 100, id, true, 0.10 FROM categories WHERE name = 'car_wash'
ON CONFLICT DO NOTHING;

INSERT INTO services (title, title_ar, base_price, price, category_id, is_active, commission_rate)
SELECT 'غسيل سيارة شامل', 'Full Car Wash', 200, 200, id, true, 0.10 FROM categories WHERE name = 'car_wash'
ON CONFLICT DO NOTHING;

-- ==================== عرض النتيجة ====================
SELECT 'تم إضافة ' || COUNT(*) || ' قسم' as result FROM categories;
SELECT 'تم إضافة ' || COUNT(*) || ' خدمة' as result FROM services;