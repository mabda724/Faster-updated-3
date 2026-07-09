-- إعادة تصميم نظام تصنيف البروفايدر بشكل احترافي
-- التصنيفات الجديدة:
-- 1. تاجر (Merchant): سوبر ماركت، صيدلية، مخبز، خضار وفاكهة، جزار، فكهاني، إلخ
-- 2. سواق (Driver): توصيل طلبات، توصيل مشاوير
-- 3. صنايعي (Handyman): كهربائي، سباك، تكييف، نجار، دهانات، إلخ

-- تحديث عمود provider_type ليكون أكثر وضوحاً
ALTER TABLE provider_profiles 
DROP COLUMN IF EXISTS provider_type;

ALTER TABLE provider_profiles 
ADD COLUMN provider_type TEXT CHECK (provider_type IN ('merchant', 'driver', 'handyman', 'both'));

-- تحديث التصنيفات الحالية بناءً على الفئة
UPDATE provider_profiles pp
SET provider_type = 
  CASE 
    WHEN c.name_ar IN ('سوبر ماركت', 'صيدلية', 'مخبز', 'خضار وفاكهة', 'جزار', 'فكهاني', 'تاجر') THEN 'merchant'
    WHEN c.name_ar IN ('توصيل طلبات', 'توصيل مشاوير', 'سواق') THEN 'driver'
    WHEN c.name_ar IN ('كهربائي', 'سباك', 'تكييف', 'نجار', 'دهانات', 'صيانة', 'تنظيف', 'نقل أثاث') THEN 'handyman'
    ELSE 'both'
  END
FROM categories c
WHERE pp.category_id = c.id;

-- إضافة تعليق للعمود
COMMENT ON COLUMN provider_profiles.provider_type IS 'نوع مقدم الخدمة: merchant (تاجر), driver (سواق), handyman (صنايعي), both (كلاهما)';

-- إنشاء دالة لتحديث نوع البروفايدر تلقائياً عند تغيير الفئة
CREATE OR REPLACE FUNCTION update_provider_type_on_category_change()
RETURNS TRIGGER AS $$
BEGIN
  NEW.provider_type = 
    CASE 
      WHEN (SELECT name_ar FROM categories WHERE id = NEW.category_id) IN ('سوبر ماركت', 'صيدلية', 'مخبز', 'خضار وفاكهة', 'جزار', 'فكهاني', 'تاجر') THEN 'merchant'
      WHEN (SELECT name_ar FROM categories WHERE id = NEW.category_id) IN ('توصيل طلبات', 'توصيل مشاوير', 'سواق') THEN 'driver'
      WHEN (SELECT name_ar FROM categories WHERE id = NEW.category_id) IN ('كهربائي', 'سباك', 'تكييف', 'نجار', 'دهانات', 'صيانة', 'تنظيف', 'نقل أثاث') THEN 'handyman'
      ELSE 'both'
    END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء التريجر
DROP TRIGGER IF EXISTS on_provider_category_change ON provider_profiles;
CREATE TRIGGER on_provider_category_change
  BEFORE UPDATE OF category_id ON provider_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_provider_type_on_category_change();
