-- =====================================================
-- FASTER APP - Commission Settlements (InstaPay Proof)
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- 1. Settlements table: each row = one توريد attempt by a provider
CREATE TABLE IF NOT EXISTS commission_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    method TEXT DEFAULT 'instapay' CHECK (method IN ('instapay', 'wallet', 'card', 'bank')),
    proof_url TEXT,                      -- screenshot of the InstaPay transfer
    reference_number TEXT,               -- optional reference / transaction number
    note TEXT,                           -- optional provider note
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    verified_by UUID REFERENCES profiles(id),
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlements_provider ON commission_settlements(provider_id);
CREATE INDEX IF NOT EXISTS idx_settlements_status ON commission_settlements(status);
CREATE INDEX IF NOT EXISTS idx_settlements_created ON commission_settlements(created_at DESC);

ALTER TABLE commission_settlements DISABLE ROW LEVEL SECURITY;

-- 2. When a provider submits a settlement → reduce their debt immediately
--    (admin can later mark as 'verified' or 'rejected'; rejection restores debt)
CREATE OR REPLACE FUNCTION on_settlement_change() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- New submission: reduce debt + log a 'commission' transaction
    IF TG_OP = 'INSERT' THEN
        UPDATE provider_profiles
        SET debt_amount = GREATEST(0, COALESCE(debt_amount, 0) - NEW.amount),
            updated_at = NOW()
        WHERE id = NEW.provider_id;

        INSERT INTO transactions (provider_id, amount, type, status, description)
        VALUES (NEW.provider_id, NEW.amount, 'commission', 'completed',
                'توريد عمولة عبر InstaPay - بانتظار المراجعة');

        -- Notify admin
        INSERT INTO notifications (user_id, type, title, body, data)
        SELECT id, 'admin_settlement', 'توريد عمولة جديد',
               'قام مقدم خدمة بتوريد ' || NEW.amount || ' ج.م عبر InstaPay',
               jsonb_build_object('settlement_id', NEW.id, 'provider_id', NEW.provider_id, 'amount', NEW.amount)
        FROM profiles WHERE role = 'admin';
        RETURN NEW;
    END IF;

    -- Rejected by admin → restore the debt
    IF TG_OP = 'UPDATE' AND NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
        UPDATE provider_profiles
        SET debt_amount = COALESCE(debt_amount, 0) + NEW.amount,
            updated_at = NOW()
        WHERE id = NEW.provider_id;

        INSERT INTO notifications (user_id, type, title, body, data)
        VALUES (NEW.provider_id, 'settlement_rejected', 'تم رفض إيصال التوريد',
                COALESCE(NEW.rejection_reason, 'يرجى إعادة رفع إيصال صحيح'),
                jsonb_build_object('settlement_id', NEW.id));
        RETURN NEW;
    END IF;

    -- Verified by admin → notify
    IF TG_OP = 'UPDATE' AND NEW.status = 'verified' AND OLD.status <> 'verified' THEN
        INSERT INTO notifications (user_id, type, title, body, data)
        VALUES (NEW.provider_id, 'settlement_verified', 'تم تأكيد توريد العمولة',
                'شكراً لك. تم توثيق توريد ' || NEW.amount || ' ج.م بنجاح.',
                jsonb_build_object('settlement_id', NEW.id));
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_settlement_change ON commission_settlements;
CREATE TRIGGER trg_settlement_change
AFTER INSERT OR UPDATE ON commission_settlements
FOR EACH ROW EXECUTE FUNCTION on_settlement_change();

-- 3. Storage bucket for proof screenshots (run once; safe to re-run)
INSERT INTO storage.buckets (id, name, public)
VALUES ('settlement-proofs', 'settlement-proofs', true)
ON CONFLICT (id) DO NOTHING;
