// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type PaymentBody = {
  amount: number;
  bookingId?: string;
  userId?: string;
  user_id?: string;
  full_name?: string;
  email?: string;
  phone?: string;
  currency?: string;
  payment_method?: 'card' | 'wallet';
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

function splitName(fullName?: string) {
  const parts = (fullName || 'Faster User').trim().split(/\s+/);
  return {
    firstName: parts.shift() || 'Faster',
    lastName: parts.join(' ') || 'User',
  };
}

// Helper to get environment variables with Deno (suppress TS error)
function getEnv(key: string): string {
  // @ts-ignore
  return Deno.env.get(key) || '';
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const body = (await req.json()) as PaymentBody;
    const amountCents = Math.round(Number(body.amount));

    if (!amountCents || amountCents < 100) {
      return jsonResponse({ error: 'المبلغ غير صالح' }, 400);
    }

    const paymobSecretKey = getEnv('PAYMOB_SECRET_KEY') || '';
    const paymobPublicKey = getEnv('PAYMOB_PUBLIC_KEY') || '';
    const cardIntegrationId =
      getEnv('PAYMOB_INTEGRATION_ID_CARD') ||
      getEnv('PAYMOB_INTEGRATION_ID') ||
      '';
    const walletIntegrationId =
      getEnv('PAYMOB_INTEGRATION_ID_WALLET') || cardIntegrationId;
    if (!paymobSecretKey || !paymobPublicKey || !cardIntegrationId) {
      return jsonResponse(
        {
          error: 'إعدادات Paymob ناقصة في Supabase Secrets',
          details:
            'أضف PAYMOB_SECRET_KEY و PAYMOB_PUBLIC_KEY و PAYMOB_INTEGRATION_ID_CARD',
        },
        500,
      );
    }

    const integrationId = Number(
      body.payment_method === 'wallet' ? walletIntegrationId : cardIntegrationId,
    );
    const userId = body.userId || body.user_id;
    const reference = body.bookingId || crypto.randomUUID();
    const { firstName, lastName } = splitName(body.full_name);
    const phone = body.phone || '+201010101010';
    const email = body.email || 'customer@faster.com';
    const currency = body.currency || 'EGP';

    const paymobResponse = await fetch('https://accept.paymob.com/v1/intention/', {
      method: 'POST',
      headers: {
        Authorization: `Token ${paymobSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountCents,
        currency,
        payment_methods: [integrationId],
        items: [
          {
            name: 'Faster service',
            amount: amountCents,
            description: 'Faster booking payment',
            quantity: 1,
          },
        ],
        billing_data: {
          apartment: 'NA',
          first_name: firstName,
          last_name: lastName,
          street: 'NA',
          building: 'NA',
          phone_number: phone,
          city: 'Cairo',
          country: 'EG',
          email,
          floor: 'NA',
          state: 'Cairo',
        },
        customer: {
          first_name: firstName,
          last_name: lastName,
          email,
          phone_number: phone,
        },
        extras: {
          booking_id: body.bookingId,
          user_id: userId,
        },
        special_reference: reference,
        expiration: 3600,
      }),
    });

    const intention = await paymobResponse.json();

    if (!paymobResponse.ok) {
      return jsonResponse(
        {
          error: 'فشل إنشاء عملية الدفع',
          details: intention,
        },
        500,
      );
    }

    const clientSecret = intention.client_secret;
    if (!clientSecret) {
      return jsonResponse(
        {
          error: 'Paymob لم يرجع client_secret',
          details: intention,
        },
        500,
      );
    }

    const supabaseUrl = getEnv('SUPABASE_URL');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (supabaseUrl && serviceRoleKey && userId) {
      await fetch(`${supabaseUrl}/rest/v1/payment_intents`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({
          booking_id: body.bookingId || null,
          user_id: userId,
          amount: amountCents / 100,
          currency,
          paymob_order_id: intention.id || reference,
          paymob_payment_key: clientSecret,
          status: 'pending',
          metadata: {
            booking_id: body.bookingId,
            user_id: userId,
            special_reference: reference,
            intention,
          },
        }),
      });
    }

    return jsonResponse({
      success: true,
      public_key: paymobPublicKey,
      client_secret: clientSecret,
      order_id: intention.id || reference,
      amount: amountCents / 100,
      currency,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: 'حدث خطأ أثناء تجهيز الدفع',
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
