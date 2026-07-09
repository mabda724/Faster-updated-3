-- =====================================================
-- PAYMOB PAYMENT TABLES - RLS POLICIES
-- Fixes critical security vulnerability from migration 006
-- =====================================================

-- Enable RLS on all payment-related tables
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PAYMENT_INTENTS POLICIES
-- =====================================================

-- Users can view their own payment intents
DROP POLICY IF EXISTS "Users can view own payment intents" ON payment_intents;
CREATE POLICY "Users can view own payment intents"
  ON payment_intents FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update their own payment intents (status changes, linking to bookings)
DROP POLICY IF EXISTS "Users can update own payment intents" ON payment_intents;
CREATE POLICY "Users can update own payment intents"
  ON payment_intents FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role has full access
DROP POLICY IF EXISTS "Service role can manage payment intents" ON payment_intents;
CREATE POLICY "Service role can manage payment intents"
  ON payment_intents FOR ALL
  USING (auth.role() = 'service_role');

-- Admins can view all payment intents
DROP POLICY IF EXISTS "Admins can view payment intents" ON payment_intents;
CREATE POLICY "Admins can view payment intents"
  ON payment_intents FOR SELECT
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- Admins can update all payment intents
DROP POLICY IF EXISTS "Admins can update payment intents" ON payment_intents;
CREATE POLICY "Admins can update payment intents"
  ON payment_intents FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- =====================================================
-- WALLETS POLICIES
-- =====================================================

-- Providers can view their own wallet
DROP POLICY IF EXISTS "Providers can view own wallet" ON wallets;
CREATE POLICY "Providers can view own wallet"
  ON wallets FOR SELECT
  USING (auth.uid() = provider_id);

-- Providers can update their own wallet (earnings added by system)
DROP POLICY IF EXISTS "Providers can update own wallet" ON wallets;
CREATE POLICY "Providers can update own wallet"
  ON wallets FOR UPDATE
  USING (auth.uid() = provider_id);

-- Service role can manage all wallets
DROP POLICY IF EXISTS "Service role can manage wallets" ON wallets;
CREATE POLICY "Service role can manage wallets"
  ON wallets FOR ALL
  USING (auth.role() = 'service_role');

-- Admins can view all wallets
DROP POLICY IF EXISTS "Admins can view wallets" ON wallets;
CREATE POLICY "Admins can view wallets"
  ON wallets FOR SELECT
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- Admins can update all wallets (manual adjustments)
DROP POLICY IF EXISTS "Admins can update wallets" ON wallets;
CREATE POLICY "Admins can update wallets"
  ON wallets FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- =====================================================
-- TRANSACTIONS POLICIES
-- =====================================================

-- Providers can view their own transactions
DROP POLICY IF EXISTS "Providers can view own transactions" ON transactions;
CREATE POLICY "Providers can view own transactions"
  ON transactions FOR SELECT
  USING (auth.uid() = provider_id);

-- Providers can insert their own transactions (system creates via triggers)
DROP POLICY IF EXISTS "Providers can insert own transactions" ON transactions;
CREATE POLICY "Providers can insert own transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid() = provider_id);

-- Service role can manage all transactions
DROP POLICY IF EXISTS "Service role can manage transactions" ON transactions;
CREATE POLICY "Service role can manage transactions"
  ON transactions FOR ALL
  USING (auth.role() = 'service_role');

-- Admins can view all transactions
DROP POLICY IF EXISTS "Admins can view transactions" ON transactions;
CREATE POLICY "Admins can view transactions"
  ON transactions FOR SELECT
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- Admins can insert transactions (manual adjustments)
DROP POLICY IF EXISTS "Admins can insert transactions" ON transactions;
CREATE POLICY "Admins can insert transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- =====================================================
-- WITHDRAWAL_REQUESTS POLICIES
-- =====================================================

-- Providers can view own withdrawal requests
DROP POLICY IF EXISTS "Providers can view own withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Providers can view own withdrawal requests"
  ON withdrawal_requests FOR SELECT
  USING (auth.uid() = provider_id);

-- Providers can insert own withdrawal requests
DROP POLICY IF EXISTS "Providers can insert own withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Providers can insert own withdrawal requests"
  ON withdrawal_requests FOR INSERT
  WITH CHECK (auth.uid() = provider_id);

-- Providers can update own withdrawal requests (e.g., cancel before approval)
DROP POLICY IF EXISTS "Providers can update own withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Providers can update own withdrawal requests"
  ON withdrawal_requests FOR UPDATE
  USING (auth.uid() = provider_id);

-- Service role can manage all withdrawal requests (approve/reject)
DROP POLICY IF EXISTS "Service role can manage withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Service role can manage withdrawal requests"
  ON withdrawal_requests FOR UPDATE
  USING (auth.role() = 'service_role');

-- Admins can view all withdrawal requests
DROP POLICY IF EXISTS "Admins can view withdrawal_requests" ON withdrawal_requests;
CREATE POLICY "Admins can view withdrawal_requests"
  ON withdrawal_requests FOR SELECT
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- Admins can update all withdrawal requests (approve/reject)
DROP POLICY IF EXISTS "Admins can update withdrawal_requests" ON withdrawal_requests;
CREATE POLICY "Admins can update withdrawal_requests"
  ON withdrawal_requests FOR UPDATE
  USING (auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin'));

-- =====================================================
-- VERIFICATION: Show RLS status for all tables
-- =====================================================
SELECT
  tablename,
  CASE WHEN rowsecurity THEN 'RLS ENABLED' ELSE 'RLS DISABLED' END as rls_status
FROM pg_tables
JOIN pg_class ON pg_tables.tablename = pg_class.relname
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE schemaname = 'public'
  AND tablename IN ('payment_intents', 'wallets', 'transactions', 'withdrawal_requests');
