-- Add commission_rate column to services table
ALTER TABLE public.services 
ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2) DEFAULT 0.10;

-- Update existing rows to use default 10% commission
UPDATE public.services 
SET commission_rate = 0.10 
WHERE commission_rate IS NULL;

-- Add default commission_rate to app_settings if not exists
INSERT INTO public.app_settings (key, value)
SELECT 'default_commission_rate', '10.0'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_settings WHERE key = 'default_commission_rate'
);
