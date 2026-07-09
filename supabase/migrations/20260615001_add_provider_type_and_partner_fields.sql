-- هجرة: إضافة أعمدة provider_type والمعلومات الإضافية للشركاء
-- تم إنشاؤها في: 2025-06-15

ALTER TABLE provider_profiles
  ADD COLUMN IF NOT EXISTS provider_type TEXT,
  ADD COLUMN IF NOT EXISTS store_address TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_model TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_plate TEXT,
  ADD COLUMN IF NOT EXISTS delivery_area TEXT;

-- إضافة فهرس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_provider_profiles_provider_type ON provider_profiles(provider_type);

-- تحديث políticas RLS لتمكين الوصول للشركاء
DROP POLICY IF EXISTS "Partner access" ON provider_profiles;
CREATE POLICY "Partner access" ON provider_profiles
  FOR ALL USING (
    auth.uid() = id
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('provider', 'seller', 'driver', 'delivery')
    )
  );

-- سياسة للقراءة فقط للمديرين
DROP POLICY IF EXISTS "Admin read all partners" ON provider_profiles;
CREATE POLICY "Admin read all partners" ON provider_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
