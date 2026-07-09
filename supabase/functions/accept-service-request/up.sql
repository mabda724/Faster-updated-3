-- ===================================================
-- RPC: Atomic accept service request
-- ===================================================
-- This function atomically:
-- 1. Updates service_requests status from 'pending' → 'accepted'
-- 2. Sets accepted_provider_id
-- 3. Creates the corresponding booking record
-- Returns the new booking on success, or NULL if failed

create or replace function public.accept_service_request(
  p_request_id bigint,
  p_provider_id uuid,
  p_client_id uuid,
  p_service_id bigint,
  p_price numeric,
  p_commission_rate numeric,
  p_address text,
  p_lat numeric,
  p_lng numeric
)
returns jsonb
language plpgsql
security definer  -- runs with owner privileges
as $$
declare
  v_request record;
  v_commission_amount numeric;
  v_booking record;
  v_arrival_code text;
begin
  -- Lock the row to prevent concurrent modifications
  select * into v_request
  from public.service_requests
  where id = p_request_id
  for update;

  if v_request is null then
    return jsonb_build_object('success', false, 'error', 'Request not found');
  end if;

  if v_request.status != 'pending' then
    return jsonb_build_object('success', false, 'error', 'Request already taken');
  end if;

  -- Calculate commission
  v_commission_amount := p_price * p_commission_rate;
  v_arrival_code := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  -- Create booking
  insert into public.bookings (
    client_id, provider_id, service_id, status,
    payment_method, payment_status,
    total_price, commission_amount, commission_rate,
    scheduled_at, address, client_lat, client_lng,
    arrival_verification_code
  ) values (
    p_client_id, p_provider_id, p_service_id, 'accepted',
    'cash', 'unpaid',
    p_price, v_commission_amount, p_commission_rate,
    now(), p_address, p_lat, p_lng,
    v_arrival_code
  )
  returning * into v_booking;

  -- Update request status
  update public.service_requests
  set
    status = 'accepted',
    accepted_provider_id = p_provider_id
  where id = p_request_id;

  return jsonb_build_object(
    'success', true,
    'booking', to_jsonb(v_booking)
  );
exception
  when others then
    return jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
end;
$$;

-- Grant execute to authenticated users
grant execute on function public.accept_service_request(
  bigint, uuid, uuid, bigint, numeric, numeric, text, numeric, numeric
) to authenticated;

-- Revoke from anon
revoke execute on function public.accept_service_request(
  bigint, uuid, uuid, bigint, numeric, numeric, text, numeric, numeric
) from anon;
