-- Migration 026: Enhance offers table with images and actions

-- 1. Ensure columns exist for images and actions
ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS action_type TEXT DEFAULT 'none'; -- 'none', 'service', 'category', 'url'
ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS action_data TEXT; -- id of service/category or a web url

-- 2. Storage bucket for offer images
INSERT INTO storage.buckets (id, name, public)
VALUES ('offer-images', 'offer-images', true)
ON CONFLICT (id) DO NOTHING;

-- 3. RLS for bucket (allow anyone to view, admins to manage)
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'offer-images');
DROP POLICY IF EXISTS "Admin Manage" ON storage.objects;
CREATE POLICY "Admin Manage" ON storage.objects FOR ALL USING (
    bucket_id = 'offer-images' AND
    (auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin'))
);
