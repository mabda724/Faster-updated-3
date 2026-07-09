-- =====================================================
-- FASTER APP - RLS FIX (Safe version)
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- ==================== provider_profiles ====================
ALTER TABLE provider_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can insert own profile" ON provider_profiles;
DROP POLICY IF EXISTS "Providers can view own profile" ON provider_profiles;
DROP POLICY IF EXISTS "Providers can update own profile" ON provider_profiles;
DROP POLICY IF EXISTS "Admins can view all provider profiles" ON provider_profiles;
DROP POLICY IF EXISTS "Admins can update all provider profiles" ON provider_profiles;

CREATE POLICY "Providers can insert own profile"
    ON provider_profiles FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "Providers can view own profile"
    ON provider_profiles FOR SELECT USING (id = auth.uid());

CREATE POLICY "Providers can update own profile"
    ON provider_profiles FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Admins can view all provider profiles"
    ON provider_profiles FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ==================== provider_services ====================
ALTER TABLE provider_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can manage own services" ON provider_services;

CREATE POLICY "Providers can manage own services"
    ON provider_services FOR ALL USING (provider_id = auth.uid());

-- ==================== provider_locations ====================
ALTER TABLE provider_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can insert own location" ON provider_locations;
DROP POLICY IF EXISTS "Providers can update own location" ON provider_locations;
DROP POLICY IF EXISTS "Clients can view provider location" ON provider_locations;

CREATE POLICY "Providers can insert own location"
    ON provider_locations FOR INSERT WITH CHECK (provider_id = auth.uid());

CREATE POLICY "Providers can update own location"
    ON provider_locations FOR UPDATE USING (provider_id = auth.uid());

CREATE POLICY "Providers can view own location"
    ON provider_locations FOR SELECT USING (provider_id = auth.uid());

-- ==================== profiles (NO RECURSION) ====================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can manage profiles" ON profiles;

CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE USING (id = auth.uid());

-- Admins can view all (using direct subquery, no recursion)
CREATE POLICY "Admins can view profiles"
    ON profiles FOR SELECT USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    );

CREATE POLICY "Admins can update profiles"
    ON profiles FOR UPDATE USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    );
