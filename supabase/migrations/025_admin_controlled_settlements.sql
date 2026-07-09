-- Migration 025: Switch to Admin-controlled settlement logic
-- Debt is reduced ONLY when admin verifies the proof.

-- 1. Update the trigger function
CREATE OR REPLACE FUNCTION public.on_settlement_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Case A: NEW Submission (INSERT)
    IF TG_OP = 'INSERT' THEN
        -- We no longer reduce debt here. We just wait for admin verification.
        -- Just notify the admin.
        INSERT INTO public.notifications (user_id, type, title, message, data)
        SELECT id, 'admin_settlement', 'إشعار توريد جديد',
               'قام مقدم خدمة بتوريد ' || NEW.amount || ' ج.م. يرجى المراجعة.',
               jsonb_build_object('settlement_id', NEW.id, 'provider_id', NEW.provider_id, 'amount', NEW.amount)
        FROM public.profiles WHERE role = 'admin';

        RETURN NEW;
    END IF;

    -- Case B: Verified by Admin (UPDATE to verified)
    IF TG_OP = 'UPDATE' AND NEW.status = 'verified' AND OLD.status <> 'verified' THEN
        -- 1. Reduce the debt amount in provider profile
        UPDATE public.provider_profiles
        SET debt_amount = GREATEST(0, COALESCE(debt_amount, 0) - NEW.amount),
            updated_at = NOW()
        WHERE id = NEW.provider_id;

        -- 2. Log a formal transaction
        INSERT INTO public.transactions (provider_id, amount, type, status, description)
        VALUES (NEW.provider_id, NEW.amount, 'commission', 'completed',
                'تم تأكيد توريد مبلغ ' || NEW.amount || ' ج.م من قبل الإدارة (رقم: ' || COALESCE(NEW.reference_number, 'بدون') || ')');

        -- 3. Notify the provider
        INSERT INTO public.notifications (user_id, type, title, message, data)
        VALUES (NEW.provider_id, 'settlement_verified', 'تم قبول التوريد بنجاح',
                'شكراً لك. تم توثيق مبلغ ' || NEW.amount || ' ج.م وتصفيره من مديونيتك.',
                jsonb_build_object('settlement_id', NEW.id));

        RETURN NEW;
    END IF;

    -- Case C: Rejected by Admin (UPDATE to rejected)
    IF TG_OP = 'UPDATE' AND NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
        -- No debt change needed because it wasn't reduced on INSERT.

        -- Notify the provider about rejection
        INSERT INTO public.notifications (user_id, type, title, message, data)
        VALUES (NEW.provider_id, 'settlement_rejected', 'تم رفض إثبات التوريد',
                COALESCE(NEW.rejection_reason, 'يرجى مراجعة بيانات التحويل وإعادة الرفع.'),
                jsonb_build_object('settlement_id', NEW.id));

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

-- 2. Add default InstaPay settings if not exists
INSERT INTO public.app_settings (key, value, description)
VALUES
  ('instapay_name', 'Faster App Support', 'اسم الحساب في انستا باي'),
  ('instapay_number', '010254464646', 'رقم الهاتف المرتبط بانستا باي')
ON CONFLICT (key) DO NOTHING;
