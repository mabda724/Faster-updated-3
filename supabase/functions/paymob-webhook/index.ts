// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paymob-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

// Verify Paymob webhook signature for security
function verifyPaymobSignature(req: Request, secretKey: string): boolean {
  const signature = req.headers.get('x-paymob-signature');
  if (!signature) return false;

  // Paymob sends HMAC-SHA256 of the request body using the secret key
  // In production, implement proper HMAC verification
  return true; // Placeholder - implement actual HMAC verification
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Verify signature
  if (!verifyPaymobSignature(req, '')) {
    return jsonResponse({ error: 'Invalid signature' }, 401);
  }

  try {
    const event = await req.json();

    // Paymob webhook event types:
    // - payment.success
    // - payment.failed
    // - payment.pending
    // - refund.completed
    // etc.

    const eventType = event.type || event.event_type || event.event;
    const data = event.data || event;

    // Paymob webhook payload structure:
    // { event: 'payment.success', data: { id: 'txn_...', order: { id: 'order_...' }, ... } }
    // Extract order_id from nested order object or direct field
    let orderId = '';
    if (data.order?.id) {
      orderId = data.order.id;
    } else if (data.order_id) {
      orderId = data.order_id;
    } else if (data.id) {
      orderId = data.id;
    } else if (data.reference) {
      orderId = data.reference;
    }

    console.log('Paymob webhook received:', eventType, data);

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'Missing Supabase configuration' }, 500);
    }

    if (eventType === 'payment.success') {
      const status = 'paid';
      const transactionId = data.transaction_id || data.id || orderId;

      // 1. Find payment_intent by order_id
      const piRes = await fetch(`${supabaseUrl}/rest/v1/payment_intents?paymob_order_id=eq.${orderId}&select=id,booking_id,amount,user_id`, {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      const piData = await piRes.json();

      if (!piData || piData.length === 0) {
        console.log('Payment intent not found for order_id:', orderId);
        return jsonResponse({ success: true, message: 'Payment intent not found' });
      }

      const paymentIntent = piData[0];
      const bookingId = paymentIntent.booking_id;

      // 2. Update payment_intent status
      await fetch(`${supabaseUrl}/rest/v1/payment_intents?id=${paymentIntent.id}`, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          status: status,
          transaction_id: transactionId,
          updated_at: new Date().toISOString(),
        }),
      });

      // 3. If booking_id exists, update booking payment_status
      if (bookingId) {
        await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${bookingId}`, {
          method: 'PATCH',
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            payment_status: 'paid',
            transaction_id: transactionId,
            updated_at: new Date().toISOString(),
          }),
        });

        // 4. The calculate_provider_earnings trigger will fire automatically when booking payment_status changes
        // No need to manually trigger - the trigger handles wallet/transaction updates
      } else {
        // No booking linked - maybe it's for a provider settlement or other payment
        // You could add custom logic here for other payment types if needed
        console.log('Payment intent has no associated booking:', paymentIntent.id);
      }

      return jsonResponse({ success: true, status });
    }

    if (eventType === 'payment.failed') {
      const orderIdParam = data.order_id || data.id;
      await fetch(`${supabaseUrl}/rest/v1/payment_intents?paymob_order_id=eq.${orderIdParam}`, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          status: 'failed',
          updated_at: new Date().toISOString(),
        }),
      });

      return jsonResponse({ success: true, status: 'failed' });
    }

    if (eventType === 'payment.pending') {
      const orderIdParam = data.order_id || data.id;
      await fetch(`${supabaseUrl}/rest/v1/payment_intents?paymob_order_id=eq.${orderIdParam}`, {
        method: 'PATCH',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          status: 'pending',
          updated_at: new Date().toISOString(),
        }),
      });

      return jsonResponse({ success: true, status: 'pending' });
    }

    // Handle refunds
    if (eventType === 'refund.completed') {
      // Implement refund logic if needed
      console.log('Refund completed:', data);
      return jsonResponse({ success: true });
    }

    // Unknown event type - just acknowledge
    return jsonResponse({ success: true, message: 'Event received but not processed' });

  } catch (error) {
    console.error('Paymob webhook error:', error);
    return jsonResponse(
      { error: 'Webhook processing failed', details: error instanceof Error ? error.message : String(error) },
      500
    );
  }
});
