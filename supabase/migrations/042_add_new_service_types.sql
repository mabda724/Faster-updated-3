-- =====================================================
-- MIGRATION 042: Add new service types
-- =====================================================
-- This migration adds new service types:
-- 1. توصيل طلبات (Delivery)
-- 2. سوبر ماركت (Supermarket)
-- 3. صيدلية (Pharmacy)
-- 4. مخبز (Bakery)
-- 5. خضار وفاكهة (Grocery)
-- 6. مشاوير (Errands)
-- These are separate from the existing "صنايعي" (Handyman) services

-- Insert new service types into categories table
INSERT INTO categories (name_ar, name_en, icon_url, icon_color, sort_order) VALUES
  ('توصيل طلبات', 'Delivery', '🚚', '#FF6B6B', 10),
  ('سوبر ماركت', 'Supermarket', '🛒', '#4ECDC4', 11),
  ('صيدلية', 'Pharmacy', '💊', '#95E1D3', 12),
  ('مخبز', 'Bakery', '🥖', '#F38181', 13),
  ('خضار وفاكهة', 'Grocery', '🥬', '#AA96DA', 14),
  ('مشاوير', 'Errands', '📦', '#FCBAD3', 15)
ON CONFLICT (name_ar) DO NOTHING;

-- Add provider_type column to provider_profiles to classify providers
ALTER TABLE provider_profiles
ADD COLUMN IF NOT EXISTS provider_type TEXT DEFAULT 'handyman'
CHECK (provider_type IN ('handyman', 'driver', 'both'));

-- Add comment to provider_type column
COMMENT ON COLUMN provider_profiles.provider_type IS 'Provider type: handyman (صنايعي), driver (سواق), or both';

-- Create index on provider_type for faster queries
CREATE INDEX IF NOT EXISTS idx_provider_profiles_type ON provider_profiles(provider_type);

-- Update existing providers to have provider_type based on their services
-- This is a one-time update for existing data
UPDATE provider_profiles pp
SET provider_type = 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM provider_services ps
      JOIN services s ON ps.service_id = s.id
      JOIN categories c ON s.category_id = c.id
      WHERE ps.provider_id = pp.id
      AND c.name_ar IN ('توصيل طلبات', 'مشاوير')
    ) THEN 'driver'
    WHEN EXISTS (
      SELECT 1 FROM provider_services ps
      JOIN services s ON ps.service_id = s.id
      JOIN categories c ON s.category_id = c.id
      WHERE ps.provider_id = pp.id
      AND c.name_ar NOT IN ('توصيل طلبات', 'مشاوير')
    ) THEN 'handyman'
    ELSE 'both'
  END
WHERE provider_type IS NULL OR provider_type = 'handyman';
