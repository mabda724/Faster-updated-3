-- Insert sample configuration data
-- This should be run after the main schema

-- Clear existing data (optional, for development)
-- DELETE FROM public.app_settings;

-- Insert configuration keys and values
INSERT INTO public.app_settings (key, value) VALUES
  ('supabase_url', 'https://xoxnjnhqpqkkctkvxzzy.supabase.co'),
  ('supabase_anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhveG5qbmhxcHFra2N0a3Z4enp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NjcyNDQsImV4cCI6MjA5MzA0MzI0NH0.LR_vZcSyt_Gj7xecnD_-zJDS--AGoJKgzIdJYdkp0iw'),
  ('kashier_merchant_id', 'MID-2-670'),
  ('kashier_mode', 'test'),
  ('admin_email', 'admin@faster.com'),
  ('payment_server_url', 'http://localhost:3001'),
  ('currency', 'جنيه'),
  ('default_commission_rate', '10.0')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  updated_at = now();