import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { JWT } from 'https://esm.sh/google-auth-library@9';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  try {
    const body = await req.json();
    
    // We now use Service Account JSON for FCM v1
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountStr) return jsonResponse({ error: 'FIREBASE_SERVICE_ACCOUNT not set' }, 500);
    
    const serviceAccount = JSON.parse(serviceAccountStr);

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { broadcast, target, userId, title, body: messageBody, type, data } = body;

    let tokens: string[] = [];

    if (broadcast) {
      let query = supabase.from('profiles').select('fcm_token').not('fcm_token', 'is', null);
      if (target === 'clients') query = query.eq('role', 'client');
      else if (target === 'providers') query = query.eq('role', 'provider');
      const { data: users } = await query;
      tokens = (users || []).map((u: any) => u.fcm_token).filter(Boolean);
    } else if (userId === 'broadcast') {
      // Special case: broadcast to providers based on category and location
      const categoryId = data?.category_id;
      const isUrgent = data?.is_urgent;

      let query = supabase
        .from('profiles')
        .select('fcm_token, provider_profiles!inner(category_id)')
        .eq('role', 'provider')
        .not('fcm_token', 'is', null);

      if (categoryId) {
        query = query.eq('provider_profiles.category_id', categoryId);
      }

      const { data: providers } = await query;
      tokens = (providers || []).map((u: any) => u.fcm_token).filter(Boolean);
    } else {
      if (!userId || !title || !messageBody) return jsonResponse({ error: 'Missing required fields' }, 400);
      const { data: user } = await supabase.from('profiles').select('fcm_token').eq('id', userId).single();
      if (user?.fcm_token) tokens = [user.fcm_token];
    }

    if (tokens.length === 0) return jsonResponse({ success: false, error: 'No FCM tokens' });

    // Authenticate with Google to get an access token for FCM v1
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const accessTokenObj = await jwtClient.getAccessToken();
    const accessToken = accessTokenObj.token;

    if (!accessToken) return jsonResponse({ error: 'Failed to get access token' }, 500);

    let successCount = 0;
    const projectId = serviceAccount.project_id;

    for (const token of tokens) {
      try {
        // FCM v1 payload structure
        const fcmPayload = {
          message: {
            token: token,
            notification: { title, body: messageBody },
            data: { type: type || 'general', ...(data || {}) },
          }
        };
        
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        });
        
        if (res.ok) successCount++;
        else console.error('FCM Send Error:', await res.text());
      } catch (err) {
        console.error('FCM Request Failed:', err);
      }
    }

    return jsonResponse({ success: true, sent: successCount, failed: tokens.length - successCount });
  } catch (error: any) {
    return jsonResponse({ error: error.message }, 500);
  }
});
