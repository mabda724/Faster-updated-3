-- Honeypot Security: Server-side detection for tampered payload fields

-- Security event log table
CREATE TABLE IF NOT EXISTS security_event_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  detail TEXT,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}',
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for querying by user and severity
CREATE INDEX IF NOT EXISTS idx_security_event_log_user ON security_event_log(user_id);
CREATE INDEX IF NOT EXISTS idx_security_event_log_severity ON security_event_log(severity);
CREATE INDEX IF NOT EXISTS idx_security_event_log_created ON security_event_log(created_at DESC);

-- Enable RLS
ALTER TABLE security_event_log ENABLE ROW LEVEL SECURITY;

-- Service role can insert (from backend functions)
-- Authenticated users can read their own events
CREATE POLICY "Users can read own security events"
  ON security_event_log FOR SELECT
  USING (auth.uid() = user_id);

-- Admin can read all
CREATE POLICY "Admins can read all security events"
  ON security_event_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Service role insert (for edge functions)
CREATE POLICY "Service role can insert"
  ON security_event_log FOR INSERT
  WITH CHECK (true);

-- Function: log_security_event (callable from edge function or trigger)
CREATE OR REPLACE FUNCTION log_security_event(
  p_event_type TEXT,
  p_severity TEXT,
  p_detail TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO security_event_log (event_type, severity, detail, user_id, metadata)
  VALUES (p_event_type, p_severity, p_detail, p_user_id, p_metadata)
  RETURNING id INTO v_id;

  -- Auto-ban on critical severity (more than 3 critical events in 24h)
  IF p_severity = 'critical' AND p_user_id IS NOT NULL THEN
    IF (
      SELECT COUNT(*)
      FROM security_event_log
      WHERE user_id = p_user_id
        AND severity = 'critical'
        AND created_at > NOW() - INTERVAL '24 hours'
    ) >= 3 THEN
      UPDATE profiles
      SET
        banned_at = NOW(),
        ban_reason = 'تجاوز حد الأمان: تم اكتشاف نشاط ضار متكرر من الحساب'
      WHERE id = p_user_id;
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

-- Function: check_honeypot_fields (callable from edge function to validate payloads)
CREATE OR REPLACE FUNCTION check_honeypot_fields(
  p_payload JSONB,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_bypass BOOLEAN;
  v_client_token TEXT;
  v_expected_token TEXT := '__hpt_f8a2b3c4__';
  v_result JSONB;
BEGIN
  v_is_bypass := (p_payload->>'is_superuser_bypass')::BOOLEAN;
  v_client_token := p_payload->>'honeypot_client_token';

  v_result := '{}'::JSONB;

  IF v_is_bypass IS TRUE THEN
    v_result := v_result || jsonb_build_object(
      'honeypot_triggered', true,
      'reason', 'is_superuser_bypass tampered',
      'severity', 'critical'
    );
    PERFORM log_security_event(
      'honeypot_field_tamper', 'critical',
      'is_superuser_bypass set to true in payload',
      p_user_id,
      jsonb_build_object('field', 'is_superuser_bypass', 'received_value', v_is_bypass)
    );
  END IF;

  IF v_client_token IS NOT NULL AND v_client_token != v_expected_token THEN
    v_result := v_result || jsonb_build_object(
      'honeypot_triggered', true,
      'reason', 'honeypot_client_token tampered',
      'severity', 'high'
    );
    PERFORM log_security_event(
      'honeypot_field_tamper', 'high',
      'honeypot_client_token tampered in payload',
      p_user_id,
      jsonb_build_object('field', 'honeypot_client_token', 'received', v_client_token, 'expected', v_expected_token)
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Trigger: auto-check honeypot fields on booking insert/update (if fields sent)
CREATE OR REPLACE FUNCTION trigger_check_booking_honeypot()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check JSONB;
BEGIN
  v_check := check_honeypot_fields(row_to_json(NEW)::JSONB, NEW.client_id);
  RETURN NEW;
END;
$$;

-- Note: The trigger is defined but NOT attached by default
-- To attach: CREATE TRIGGER trg_booking_honeypot_check
--   BEFORE INSERT OR UPDATE ON bookings
--   FOR EACH ROW EXECUTE FUNCTION trigger_check_booking_honeypot();
-- We keep the trigger function available for manual activation when needed.

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION log_security_event TO service_role;
GRANT EXECUTE ON FUNCTION check_honeypot_fields TO service_role;
GRANT SELECT, INSERT ON security_event_log TO service_role;
