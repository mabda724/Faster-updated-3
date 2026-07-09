INSERT INTO app_settings (key, value) VALUES
  ('cancel_free_minutes', '{"minutes": 5}'),
  ('cancel_commission_minutes', '{"minutes": 30}'),
  ('default_commission_rate', '0.10'),
  ('admin_whatsapp_number', '+201234567890'),
  ('referral_points_earner', '50'),
  ('referral_points_new_user', '25'),
  ('maintenance_mode', 'false'),
  ('cancel_window_hours', '24')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
