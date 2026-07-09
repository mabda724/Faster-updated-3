-- Create buckets if not exist

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('provider-documents', 'provider-documents', false, 5242880, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('booking-photos', 'booking-photos', false, 10485760, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- Policies for provider-documents
INSERT INTO storage.policies (name, bucket_id, definition, check)
VALUES (
  'Users can upload own documents',
  'provider-documents',
  'auth.uid()::text = (storage.foldername(name))[1]',
  true
) ON CONFLICT DO NOTHING;

INSERT INTO storage.policies (name, bucket_id, definition, check)
VALUES (
  'Users can read own documents',
  'provider-documents',
  'auth.uid()::text = (storage.foldername(name))[1]',
  false
) ON CONFLICT DO NOTHING;

-- Optional: make booking-photos public readable
-- UPDATE storage.buckets SET public = true WHERE id = 'booking-photos';
