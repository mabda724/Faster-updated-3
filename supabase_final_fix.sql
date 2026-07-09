-- =====================================================
-- FASTER APP - FINAL DATABASE FIX & SIGNUP SYNC
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- 0. Ensure categories table has all required columns
CREATE TABLE IF NOT EXISTS public.categories (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT UNIQUE NOT NULL,
    name_ar TEXT,
    name_en TEXT,
    icon_url TEXT,
    icon_color TEXT DEFAULT '#3B82F6',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

DO $$ BEGIN
    ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS icon_color TEXT DEFAULT '#3B82F6';
    ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
    ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS name_ar TEXT;
    ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS name_en TEXT;
    
    -- Ensure UNIQUE constraint exists for 'name'
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'categories_name_key') THEN
        ALTER TABLE public.categories ADD CONSTRAINT categories_name_key UNIQUE (name);
    END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- 1. Ensure profiles table exists with all required columns
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone_number TEXT,
    role TEXT DEFAULT 'client' CHECK (role IN ('client', 'provider', 'admin')),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns to profiles if they don't exist
DO $$ BEGIN
    ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

-- 2. Ensure provider_profiles exists
CREATE TABLE IF NOT EXISTS public.provider_profiles (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    profession TEXT,
    category_id BIGINT REFERENCES public.categories(id),
    national_id_number TEXT,
    bio TEXT,
    rating DECIMAL(3,2) DEFAULT 0,
    is_online BOOLEAN DEFAULT false,
    wallet_balance DECIMAL(10,2) DEFAULT 0,
    document_verification_status TEXT DEFAULT 'pending' CHECK (document_verification_status IN ('pending', 'approved', 'rejected')),
    id_document_url TEXT,
    profile_document_url TEXT,
    other_documents TEXT[],
    address TEXT,
    address_details TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist in provider_profiles if table was already there
DO $$ BEGIN
    ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS id_document_url TEXT;
    ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS profile_document_url TEXT;
    ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS other_documents TEXT[];
    ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS document_verification_status TEXT DEFAULT 'pending';
EXCEPTION WHEN others THEN NULL;
END $$;

-- 2.5 Ensure bookings table has all required columns
DO $$ BEGIN
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS total_price DECIMAL(10,2);
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(10,2);
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS provider_earning DECIMAL(10,2);
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2);
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid';
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS address TEXT;
    ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS address_details TEXT;
EXCEPTION WHEN others THEN NULL;
END $$;

-- 3. CREATE ROBUST TRIGGER FUNCTION FOR NEW USERS
-- This ensures that even if the Flutter app fails to insert into profiles, 
-- the database will handle it automatically upon Auth Signup.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, is_verified)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'client'),
    CASE WHEN (NEW.raw_user_meta_data->>'role') = 'client' THEN true ELSE false END
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.5 CREATE BROADCAST ACCEPTANCE FUNCTION
CREATE OR REPLACE FUNCTION public.accept_broadcast_booking(p_booking_id UUID, p_provider_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_provider UUID;
BEGIN
  -- Check if booking still has no provider
  SELECT provider_id INTO v_current_provider FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF v_current_provider IS NULL THEN
    UPDATE public.bookings 
    SET 
      provider_id = p_provider_id,
      status = 'accepted',
      accepted_at = NOW()
    WHERE id = p_booking_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. FIX RLS POLICIES (Make them permissive for development/production stability)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.services DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions DISABLE ROW LEVEL SECURITY;

-- 5. ENSURE CATEGORIES HAVE CORRECT DATA
INSERT INTO public.categories (name, name_ar, name_en, icon_url, icon_color, is_active)
VALUES 
  ('plumbing', 'سباكة', 'Plumbing', '59299', '#3B82F6', true),
  ('electrical', 'كهرباء', 'Electrical', '58930', '#F59E0B', true),
  ('cleaning', 'تنظيف', 'Cleaning', '58937', '#22C55E', true),
  ('painting', 'دهان', 'Painting', '58935', '#8B5CF6', true),
  ('ac_repair', 'تكييف', 'AC Repair', '59008', '#06B6D4', true),
  ('carpentry', 'نجارة', 'Carpentry', '58934', '#EF4444', true)
ON CONFLICT (name) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  is_active = true;

-- 3.7 FIX PROVIDER ANALYTICS FUNCTION (Ambiguity Fix)
CREATE OR REPLACE FUNCTION public.update_provider_analytics(p_provider_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_total INTEGER;
    v_completed INTEGER;
    v_cancelled INTEGER;
    v_earnings DECIMAL(10, 2);
    v_rating DECIMAL(3, 2);
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM public.bookings WHERE provider_id = p_provider_id;
    
    SELECT COUNT(*) INTO v_completed
    FROM public.bookings WHERE provider_id = p_provider_id AND status = 'completed';
    
    SELECT COUNT(*) INTO v_cancelled
    FROM public.bookings WHERE provider_id = p_provider_id AND status = 'cancelled';
    
    SELECT COALESCE(SUM(total_price - COALESCE(commission_amount, 0)), 0) INTO v_earnings
    FROM public.bookings WHERE provider_id = p_provider_id AND status = 'completed';
    
    SELECT COALESCE(AVG(rating), 0) INTO v_rating
    FROM public.reviews WHERE provider_id = p_provider_id;
    
    INSERT INTO public.provider_analytics (provider_id, total_bookings, completed_bookings, cancelled_bookings, total_earnings, average_rating, last_updated)
    VALUES (p_provider_id, v_total, v_completed, v_cancelled, v_earnings, v_rating, NOW())
    ON CONFLICT (provider_id) DO UPDATE SET
        total_bookings = EXCLUDED.total_bookings,
        completed_bookings = EXCLUDED.completed_bookings,
        cancelled_bookings = EXCLUDED.cancelled_bookings,
        total_earnings = EXCLUDED.total_earnings,
        average_rating = EXCLUDED.average_rating,
        last_updated = NOW();
END;
$$;

-- 6. ENSURE APP SETTINGS
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. FIX BOOKINGS STATUS CONSTRAINT
DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
    
    -- Add the comprehensive constraint
    ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'on_the_way', 'arrived', 'in_progress', 'completed', 'cancelled'));
EXCEPTION
    WHEN undefined_table THEN
        -- Handle case where bookings table doesn't exist yet (unlikely here)
        NULL;
END $$;

INSERT INTO public.app_settings (key, value) VALUES
  ('currency', 'جنيه'),
  ('admin_email', 'admin@faster.com'),
  ('default_commission_rate', '10.0')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Grant access to the functions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
