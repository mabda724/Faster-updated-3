-- Migration: UX Audit Improvements
-- 1. Create suspicious_messages table
-- 2. Add indexes for performance optimization
-- 3. Trigger for automated account ban on 3 suspicious messages

-- 1. Create suspicious_messages table
CREATE TABLE IF NOT EXISTS public.suspicious_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    flagged_pattern TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.suspicious_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert their own suspicious messages" ON public.suspicious_messages;
DROP POLICY IF EXISTS "Admins can read suspicious messages" ON public.suspicious_messages;

-- RLS Policies
CREATE POLICY "Users can insert their own suspicious messages" 
ON public.suspicious_messages FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Admins can read suspicious messages" 
ON public.suspicious_messages FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_client_provider ON public.bookings(client_id, provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_category ON public.provider_profiles(category_id);

-- 3. Auto-ban trigger on 3 suspicious messages
CREATE OR REPLACE FUNCTION check_suspicious_message_limit()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    suspicious_count INT;
BEGIN
    -- Count suspicious messages sent by the sender
    SELECT COUNT(*) INTO suspicious_count 
    FROM public.suspicious_messages 
    WHERE sender_id = NEW.sender_id;

    -- If suspicious messages reach or exceed 3, auto-ban the user
    IF suspicious_count >= 3 THEN
        -- Update the profiles table
        UPDATE public.profiles 
        SET 
            banned_at = NOW(),
            ban_reason = 'تم حظر الحساب تلقائياً بسبب تكرار محاولة إجراء معاملات خارج التطبيق أو كتابة رسائل مشبوهة.'
        WHERE id = NEW.sender_id;

        -- Create a warning record in admin_warnings
        INSERT INTO public.admin_warnings (
            provider_id,
            warning_type,
            message,
            action_taken,
            is_report
        )
        VALUES (
            NEW.sender_id,
            'auto_ban_suspicious_messages',
            'تم حظر الحساب تلقائياً لتجاوز الحد المسموح به من الرسائل المشبوهة (3 رسائل)',
            'banned',
            false
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_suspicious_message_limit ON public.suspicious_messages;
CREATE TRIGGER trg_suspicious_message_limit
    AFTER INSERT ON public.suspicious_messages
    FOR EACH ROW EXECUTE FUNCTION check_suspicious_message_limit();
