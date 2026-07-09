-- إضافة جدول المنتجات للتجار
CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL CHECK (price >= 0),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  image_url TEXT,
  category_id BIGINT REFERENCES categories(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_products_provider_id ON products(provider_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);

-- إضافة Trigger لتحديث updated_at
CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_products_update ON products;
CREATE TRIGGER on_products_update
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_products_updated_at();

-- إضافة RLS Policies
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Policy: التاجر يمكنه رؤية منتجاته فقط
CREATE POLICY "التاجر يمكنه رؤية منتجاته فقط"
ON products FOR SELECT
USING (auth.uid() = provider_id);

-- Policy: التاجر يمكنه إضافة منتجات جديدة
CREATE POLICY "التاجر يمكنه إضافة منتجات جديدة"
ON products FOR INSERT
WITH CHECK (auth.uid() = provider_id);

-- Policy: التاجر يمكنه تعديل منتجاته فقط
CREATE POLICY "التاجر يمكنه تعديل منتجاته فقط"
ON products FOR UPDATE
USING (auth.uid() = provider_id);

-- Policy: التاجر يمكنه حذف منتجاته فقط
CREATE POLICY "التاجر يمكنه حذف منتجاته فقط"
ON products FOR DELETE
USING (auth.uid() = provider_id);

-- Policy: العملاء يمكنهم رؤية المنتجات النشطة فقط
CREATE POLICY "العملاء يمكنهم رؤية المنتجات النشطة فقط"
ON products FOR SELECT
USING (is_active = true);

-- إضافة تعليق للجدول
COMMENT ON TABLE products IS 'جدول المنتجات للتجار - يحتوي على المنتجات التي يرفعها التجار';
