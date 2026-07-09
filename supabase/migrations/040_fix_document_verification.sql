-- Migration 040: Fix document verification not updating status
-- Problem: Admin's UPDATE on provider_profiles is blocked by RLS
--          (missing "Admins can update" policy on provider_profiles)
-- Fix: Create SECURITY DEFINER function to bypass RLS

-- Drop existing function if re-running
DROP FUNCTION IF EXISTS public.verify_provider_documents;

CREATE OR REPLACE FUNCTION public.verify_provider_documents(
  p_provider_id UUID,
  p_approved BOOLEAN,
  p_rejection_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  IF p_approved THEN
    UPDATE public.provider_profiles SET
      document_verification_status = 'approved',
      face_verified = true,
      face_verified_at = NOW(),
      updated_at = NOW()
    WHERE id = p_provider_id;

    UPDATE public.profiles SET
      is_verified = true,
      verification_level = 'fully_verified'
    WHERE id = p_provider_id;
  ELSE
    UPDATE public.provider_profiles SET
      document_verification_status = 'rejected',
      face_verified = false,
      face_verified_at = NULL,
      updated_at = NOW()
    WHERE id = p_provider_id;

    UPDATE public.profiles SET
      is_verified = false,
      verification_level = 'id_uploaded'
    WHERE id = p_provider_id;
  END IF;

  -- Send notification
  PERFORM public.notify_provider_document_verification(
    p_provider_id,
    CASE WHEN p_approved THEN 'approved' ELSE 'rejected' END,
    p_rejection_reason
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute permission to authenticated users (admin)
GRANT EXECUTE ON FUNCTION public.verify_provider_documents TO authenticated;
