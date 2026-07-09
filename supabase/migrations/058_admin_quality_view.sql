/*
  Migration: Admin Quality Metrics View
  Provides aggregated statistics for the admin quality dashboard.
*/

CREATE OR REPLACE VIEW public.admin_quality_metrics AS
SELECT 
  COUNT(*) AS total_bookings,
  CASE WHEN COUNT(*) = 0 THEN 0 ELSE (SUM(CASE WHEN b.status = 'accepted' THEN 1 ELSE 0 END)::float / COUNT(*)) END AS acceptance_rate,
  AVG(pp.avg_rating)::float AS avg_provider_rating,
  COUNT(aw.id) FILTER (WHERE aw.is_report = true) AS total_complaints,
  AVG(EXTRACT(EPOCH FROM (c.first_msg_at - b.created_at))) / 60.0 AS avg_response_time_minutes
FROM bookings b
LEFT JOIN provider_profiles pp ON pp.id = b.provider_id
LEFT JOIN LATERAL (
  SELECT MIN(created_at) AS first_msg_at
  FROM chat_messages cm
  WHERE cm.booking_id = b.id
) c ON true
LEFT JOIN admin_warnings aw ON aw.booking_id = b.id;

-- Enable row level security for admin role (assumes a role 'admin' exists)
ALTER VIEW public.admin_quality_metrics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can read quality metrics" ON public.admin_quality_metrics FOR SELECT USING (auth.role() = 'authenticated' AND (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true);

-- End of migration