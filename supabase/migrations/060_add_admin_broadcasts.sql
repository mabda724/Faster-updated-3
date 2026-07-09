-- Create admin_broadcasts table for storing sent broadcasts
CREATE TABLE IF NOT EXISTS public.admin_broadcasts (
  id BIGSERIAL PRIMARY KEY,
  admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target TEXT NOT NULL DEFAULT 'all',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.admin_broadcasts ENABLE ROW LEVEL SECURITY;

-- Only admins can read
CREATE POLICY "Admins can read broadcasts"
  ON public.admin_broadcasts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Only admins can insert
CREATE POLICY "Admins can insert broadcasts"
  ON public.admin_broadcasts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
