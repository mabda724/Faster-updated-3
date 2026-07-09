-- =====================================================
-- Settled Amount Calculation Fix
-- Ensures settled_amount updates when commission_settlements status changes
-- =====================================================

-- Replace the on_settlement_change() function to also update settled_amount
CREATE OR REPLACE FUNCTION on_settlement_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    total_verified DECIMAL(10, 2);
BEGIN
    -- New submission: reduce debt + log a 'commission' transaction
    IF TG_OP = 'INSERT' THEN
        UPDATE provider_profiles
        SET debt_amount = GREATEST(0, COALESCE(debt_amount, 0) - NEW.amount),
            updated_at = NOW()
        WHERE id = NEW.provider_id;

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

    -- Verified by admin → recalculate settled_amount + notify
    IF TG_OP = 'UPDATE' AND NEW.status = 'verified' AND OLD.status <> 'verified' THEN
        -- Recalculate total verified settlements for this provider
        SELECT COALESCE(SUM(amount), 0) INTO total_verified
        FROM commission_settlements
        WHERE provider_id = NEW.provider_id AND status = 'verified';

        UPDATE provider_profiles
        SET settled_amount = total_verified,
            updated_at = NOW()
        WHERE id = NEW.provider_id;

        INSERT INTO notifications (user_id, type, title, body, data)
        VALUES (NEW.provider_id, 'settlement_verified', 'تم تأكيد توريد العمولة',
                'شكراً لك. تم توثيق توريد ' || NEW.amount || ' ج.م بنجاح. إجمالي المسجل: ' || total_verified || ' ج.م',
                jsonb_build_object('settlement_id', NEW.id, 'total_verified', total_verified));
        RETURN NEW;
    END IF;

    -- If status changed from verified to something else (unlikely but handle)
    IF TG_OP = 'UPDATE' AND OLD.status = 'verified' AND NEW.status <> 'verified' THEN
        -- Recalculate settled_amount without this settlement
        SELECT COALESCE(SUM(amount), 0) INTO total_verified
        FROM commission_settlements
        WHERE provider_id = NEW.provider_id AND status = 'verified';

        UPDATE provider_profiles
        SET settled_amount = total_verified,
            updated_at = NOW()
        WHERE id = NEW.provider_id;
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

-- Recreate trigger with updated function (safe to re-run)
DROP TRIGGER IF EXISTS trg_settlement_change ON commission_settlements;
CREATE TRIGGER trg_settlement_change
AFTER INSERT OR UPDATE ON commission_settlements
FOR EACH ROW EXECUTE FUNCTION on_settlement_change();

-- Verify function exists
SELECT proname FROM pg_proc WHERE proname = 'on_settlement_change';
