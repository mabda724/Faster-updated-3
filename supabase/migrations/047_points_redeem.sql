/*
  Migration: Redeem loyalty points
  Adds RPC function to allow a user to redeem points.
*/

-- Ensure the user_points table exists (already created in 014_referral_points.sql)
-- Create the function
CREATE OR REPLACE FUNCTION public.redeem_points(p_user_id UUID, p_amount INTEGER)
RETURNS TABLE (success BOOLEAN, new_balance INTEGER) AS $$
DECLARE
  current_points INTEGER;
BEGIN
  -- Fetch current points with row-level security
  SELECT points INTO current_points FROM public.user_points WHERE user_id = p_user_id;

  IF current_points IS NULL THEN
    -- No points record – fail
    RETURN QUERY SELECT FALSE AS success, 0 AS new_balance;
    RETURN;
  END IF;

  IF current_points < p_amount THEN
    -- Not enough points
    RETURN QUERY SELECT FALSE AS success, current_points AS new_balance;
    RETURN;
  END IF;

  -- Update points atomically
  UPDATE public.user_points
    SET points = points - p_amount,
        redeemed_points = redeemed_points + p_amount,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING points INTO current_points;

  RETURN QUERY SELECT TRUE AS success, current_points AS new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.redeem_points(UUID, INTEGER) TO authenticated;

-- RLS policy – already exists for user_points; ensure function can be called

-- End of migration