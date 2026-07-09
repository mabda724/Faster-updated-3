-- =====================================================
-- FASTER APP - إصلاح مشاكل تسجيل المستخدمين
-- =====================================================

-- تعطيل RLS على profiles
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- إعادة تفعيل مع policies للقراءة والكتابة
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_insert" ON profiles;
DROP POLICY IF EXISTS "profiles_select" ON profiles;
DROP POLICY IF EXISTS "profiles_update" ON profiles;

CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (true);
