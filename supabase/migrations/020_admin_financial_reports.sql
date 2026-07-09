-- Admin Financial Reports Functions
-- Functions to calculate commission statistics for admin dashboard

-- Function to get overall commission statistics
CREATE OR REPLACE FUNCTION get_admin_commission_stats()
RETURNS TABLE (
  expected_commission DECIMAL,
  received_commission DECIMAL,
  pending_commission DECIMAL,
  total_completed_services DECIMAL,
  total_services_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Expected commission (total from completed services)
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'completed' 
        THEN COALESCE(b.commission_amount, 0)
        ELSE 0
      END
    ), 0) as expected_commission,
    
    -- Received commission (verified settlements)
    COALESCE(
      (SELECT SUM(amount)
       FROM commission_settlements
       WHERE status = 'verified'),
      0
    ) as received_commission,
    
    -- Pending commission (awaiting verification)
    COALESCE(
      (SELECT SUM(amount)
       FROM commission_settlements
       WHERE status = 'pending'),
      0
    ) as pending_commission,
    
    -- Total completed services value
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'completed' 
        THEN COALESCE(b.offered_price, b.total_price, 0)
        ELSE 0
      END
    ), 0) as total_completed_services,
    
    -- Total completed services count
    COUNT(*) FILTER (WHERE b.status = 'completed') as total_services_count
  FROM bookings b;
END;
$$;

-- Function to get commission stats by date range
CREATE OR REPLACE FUNCTION get_commission_stats_by_date_range(
  p_start_date TIMESTAMP WITH TIME ZONE,
  p_end_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
  date TEXT,
  expected_commission DECIMAL,
  received_commission DECIMAL,
  pending_commission DECIMAL,
  completed_services_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TO_CHAR(b.created_at, 'YYYY-MM-DD') as date,
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'completed' 
        AND b.created_at >= p_start_date 
        AND b.created_at <= p_end_date
        THEN COALESCE(b.commission_amount, 0)
        ELSE 0
      END
    ), 0) as expected_commission,
    
    COALESCE(SUM(
      CASE 
        WHEN cs.status = 'verified'
        AND cs.created_at >= p_start_date 
        AND cs.created_at <= p_end_date
        THEN COALESCE(cs.amount, 0)
        ELSE 0
      END
    ), 0) as received_commission,
    
    COALESCE(SUM(
      CASE 
        WHEN cs.status = 'pending'
        AND cs.created_at >= p_start_date 
        AND cs.created_at <= p_end_date
        THEN COALESCE(cs.amount, 0)
        ELSE 0
      END
    ), 0) as pending_commission,
    
    COUNT(*) FILTER (
      WHERE b.status = 'completed'
      AND b.created_at >= p_start_date 
      AND b.created_at <= p_end_date
    ) as completed_services_count
  FROM bookings b
  LEFT JOIN commission_settlements cs ON b.provider_id = cs.provider_id
  WHERE b.created_at >= p_start_date AND b.created_at <= p_end_date
  GROUP BY TO_CHAR(b.created_at, 'YYYY-MM-DD')
  ORDER BY date;
END;
$$;

-- Function to get commission stats by provider
CREATE OR REPLACE FUNCTION get_commission_stats_by_provider()
RETURNS TABLE (
  provider_id TEXT,
  provider_name TEXT,
  expected_commission DECIMAL,
  received_commission DECIMAL,
  pending_commission DECIMAL,
  completed_services_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pp.id as provider_id,
    p.full_name as provider_name,
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'completed' 
        THEN COALESCE(b.commission_amount, 0)
        ELSE 0
      END
    ), 0) as expected_commission,
    
    COALESCE(
      (SELECT SUM(cs.amount)
       FROM commission_settlements cs
       WHERE cs.provider_id = pp.id AND cs.status = 'verified'),
      0
    ) as received_commission,
    
    COALESCE(
      (SELECT SUM(cs.amount)
       FROM commission_settlements cs
       WHERE cs.provider_id = pp.id AND cs.status = 'pending'),
      0
    ) as pending_commission,
    
    COUNT(*) FILTER (WHERE b.status = 'completed') as completed_services_count
  FROM provider_profiles pp
  JOIN profiles p ON pp.id = p.id
  LEFT JOIN bookings b ON b.provider_id = pp.id
  WHERE p.role = 'provider'
  GROUP BY pp.id, p.full_name
  ORDER BY expected_commission DESC;
END;
$$;

-- Function to get commission stats by category
CREATE OR REPLACE FUNCTION get_commission_stats_by_category()
RETURNS TABLE (
  category_id INTEGER,
  category_name TEXT,
  expected_commission DECIMAL,
  received_commission DECIMAL,
  pending_commission DECIMAL,
  completed_services_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id as category_id,
    c.name_ar as category_name,
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'completed' 
        THEN COALESCE(b.commission_amount, 0)
        ELSE 0
      END
    ), 0) as expected_commission,
    
    COALESCE(SUM(
      CASE 
        WHEN cs.status = 'verified'
        THEN COALESCE(cs.amount, 0)
        ELSE 0
      END
    ), 0) as received_commission,
    
    COALESCE(SUM(
      CASE 
        WHEN cs.status = 'pending'
        THEN COALESCE(cs.amount, 0)
        ELSE 0
      END
    ), 0) as pending_commission,
    
    COUNT(*) FILTER (WHERE b.status = 'completed') as completed_services_count
  FROM categories c
  LEFT JOIN services s ON s.category_id = c.id
  LEFT JOIN bookings b ON b.service_id = s.id
  LEFT JOIN commission_settlements cs ON b.provider_id = cs.provider_id
  GROUP BY c.id, c.name_ar
  ORDER BY expected_commission DESC;
END;
$$;

-- Function to get pending settlements for admin review
CREATE OR REPLACE FUNCTION get_pending_settlements()
RETURNS TABLE (
  id UUID,
  provider_id TEXT,
  provider_name TEXT,
  amount DECIMAL,
  method TEXT,
  proof_url TEXT,
  reference_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cs.id,
    cs.provider_id,
    p.full_name as provider_name,
    cs.amount,
    cs.method,
    cs.proof_url,
    cs.reference_number,
    cs.created_at,
    cs.status
  FROM commission_settlements cs
  JOIN profiles p ON cs.provider_id = p.id
  WHERE cs.status = 'pending'
  ORDER BY cs.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_admin_commission_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_commission_stats_by_date_range TO authenticated;
GRANT EXECUTE ON FUNCTION get_commission_stats_by_provider TO authenticated;
GRANT EXECUTE ON FUNCTION get_commission_stats_by_category TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_settlements TO authenticated;
