import { serve } from 'https://deno.land/std@0.168.0/http/function_server.ts';
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

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabase = createClient(supabaseUrl, serviceRoleKey);

// ── FCM v1 send using Service Account ──────────────────────────
async function sendFcmV1(tokens: string[], title: string, body: string, type: string, data: Record<string, string> = {}): Promise<number> {
  const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!serviceAccountStr) {
    console.error('FIREBASE_SERVICE_ACCOUNT not configured');
    return 0;
  }

  const serviceAccount = JSON.parse(serviceAccountStr);
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });
  const accessTokenObj = await jwtClient.getAccessToken();
  const accessToken = accessTokenObj.token;
  if (!accessToken) {
    console.error('Failed to get FCM access token');
    return 0;
  }

  const projectId = serviceAccount.project_id;
  let successCount = 0;

  for (const token of tokens) {
    try {
      const fcmPayload = {
        message: {
          token,
          notification: { title, body },
          data: { type: type || 'general', ...data },
          android: { priority: 'high', notification: { sound: 'default', channel_id: 'high_importance_channel' } },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      };

      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(fcmPayload),
      });

      if (res.ok) successCount++;
      else {
        const errText = await res.text();
        console.error('FCM Send Error:', errText);
        // If token is invalid, remove it
        if (res.status === 404 || errText.includes('NotRegistered') || errText.includes('InvalidRegistration')) {
          await supabase.from('profiles').update({ fcm_token: null }).eq('fcm_token', token);
        }
      }
    } catch (err) {
      console.error('FCM Request Failed:', err);
    }
  }
  return successCount;
}

async function getUserToken(userId: string): Promise<string | null> {
  const { data } = await supabase.from('profiles').select('fcm_token').eq('id', userId).single();
  return data?.fcm_token || null;
}

async function getUserName(userId: string): Promise<string> {
  const { data } = await supabase.from('profiles').select('full_name').eq('id', userId).single();
  return data?.full_name || 'مقدم الخدمة';
}

async function sendNotification(userId: string, title: string, body: string, type: string, data: Record<string, string> = {}): Promise<boolean> {
  const token = await getUserToken(userId);
  if (!token) {
    console.log(`No FCM token for user ${userId}`);
    return false;
  }
  const sent = await sendFcmV1([token], title, body, type, data);
  return sent > 0;
}

// ── Save in-app notification record ──────────────────────────
async function saveInAppNotification(userId: string, title: string, message: string, type: string, data: Record<string, string> = {}) {
  try {
    await supabase.from('notifications').insert({
      user_id: userId,
      type,
      title,
      message,
      data,
      is_read: false,
    });
  } catch (e) {
    console.error('Save in-app notification error:', e);
  }
}

// ── Booking status notification mappings ──────────────────────
const clientNotifications: Record<string, [string, string]> = {
  accepted:    ['تم قبول طلبك!', 'مقدم الخدمة وافق على طلبك وجاري التجهز'],
  on_the_way:  ['مقدم الخدمة في الطريق!', 'تابع موقعه على الخريطة الآن'],
  arrived:     ['مقدم الخدمة وصل!', 'افتح الباب، مقدم الخدمة عندك'],
  in_progress: ['بدأ تنفيذ الخدمة', 'مقدم الخدمة بيشتغل دلوقتي'],
  completed:   ['تمت الخدمة بنجاح!', 'شكراً ليك! قيّم تجربتك مع مقدم الخدمة'],
  cancelled:   ['تم إلغاء الطلب', 'تم إلغاء طلبك، يمكنك طلب خدمة جديدة'],
  rejected:    ['تم رفض الطلب', 'مقدم الخدمة لم يتمكن من قبول طلبك، جرب مقدم خدمة آخر'],
};

const providerNotifications: Record<string, [string, string]> = {
  pending:   ['طلب خدمة جديد!', 'عندك طلب جديد، شوف التفاصيل وشارك'],
  cancelled: ['العميل ألغى الطلب', 'العميل قرر إلغاء الطلب'],
  completed: ['تم إتمام الخدمة', 'شكراً ليك! الخدمة اتمت بنجاح'],
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  try {
    const payload = await req.json();
    const { type, table, record } = payload;
    const oldRecord = payload.old_record;

    // ── Handle Booking Changes ─────────────────────────────
    if (table === 'bookings') {
      const order = record;
      const oldStatus = oldRecord?.status;
      const newStatus = order.status;

      // Skip if status hasn't changed (unless it's a new INSERT)
      if (oldStatus === newStatus && type !== 'INSERT') {
        return jsonResponse({ message: 'No status change' });
      }

      const providerName = order.provider_id ? await getUserName(order.provider_id) : 'مقدم الخدمة';

      // Notify client about status change
      if (clientNotifications[newStatus]) {
        const [title, body] = clientNotifications[newStatus];
        const customBody = newStatus === 'accepted' ? `${providerName} وافق عليك` : body;
        await sendNotification(order.client_id, title, customBody, 'order_status', { order_id: order.id, status: newStatus });
        await saveInAppNotification(order.client_id, title, customBody, 'order_status', { order_id: order.id, status: newStatus });
      } else {
        // Fallback for any status not in the predefined list
        await sendNotification(order.client_id, 'تحديث حالة الطلب', `تم تغيير حالة طلبك إلى ${newStatus}`, 'order_status', { order_id: order.id, status: newStatus });
        await saveInAppNotification(order.client_id, 'تحديث حالة الطلب', `تم تغيير حالة طلبك إلى ${newStatus}`, 'order_status', { order_id: order.id, status: newStatus });
      }

      // Notify assigned provider about new order
      if (newStatus === 'pending' && order.provider_id) {
        const [title, body] = providerNotifications['pending'];
        await sendNotification(order.provider_id, title, body, 'new_booking', { order_id: order.id, status: newStatus });
        await saveInAppNotification(order.provider_id, title, body, 'new_booking', { order_id: order.id, status: newStatus });
      }

      // Notify provider about broadcast booking (new INSERT with null provider_id)
      if (type === 'INSERT' && !order.provider_id && newStatus === 'pending') {
        // Find nearby providers matching the service category
        try {
          const serviceData = await supabase
            .from('services')
            .select('category_id')
            .eq('id', order.service_id)
            .single();

          if (serviceData.data?.category_id) {
            const { data: providers } = await supabase
              .from('provider_profiles')
              .select('id, category_id, search_radius_km, latitude, longitude')
              .eq('is_online', true)
              .eq('category_id', serviceData.data.category_id)
              .not('latitude', 'is', null);

            if (providers && providers.length > 0 && order.client_lat && order.client_lng) {
              const R = 6371;
              const nearbyTokens: string[] = [];
              const nearbyIds: string[] = [];
              
              for (const p of providers) {
                const dLat = ((order.client_lat - p.latitude) * Math.PI) / 180;
                const dLon = ((order.client_lng - p.longitude) * Math.PI) / 180;
                const a = Math.sin(dLat / 2) ** 2 + Math.cos((p.latitude * Math.PI) / 180) * Math.cos((order.client_lat * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
                const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                const radius = p.search_radius_km || 20;
                
                if (dist <= radius) {
                  nearbyIds.push(p.id);
                  const token = await getUserToken(p.id);
                  if (token) nearbyTokens.push(token);
                }
              }

              if (nearbyTokens.length > 0) {
                await sendFcmV1(nearbyTokens, 'طلب جديد في منطقتك!', 'عندك طلب جديد ضمن تخصصك، شوف التفاصيل', 'new_booking', { order_id: order.id, status: 'pending' });
                for (const pid of nearbyIds) {
                  await saveInAppNotification(pid, 'طلب جديد في منطقتك!', 'عندك طلب جديد ضمن تخصصك', 'new_booking', { order_id: order.id });
                }
              }
            }
          }
        } catch (e) {
          console.error('Broadcast notification error:', e);
        }
      }

      // Notify provider about cancellation by client
      if (newStatus === 'cancelled' && order.provider_id) {
        const [title, body] = providerNotifications['cancelled'];
        await sendNotification(order.provider_id, title, body, 'order_status', { order_id: order.id, status: 'cancelled' });
        await saveInAppNotification(order.provider_id, title, body, 'order_status', { order_id: order.id, status: 'cancelled' });
      }

      // Notify provider about completion
      if (newStatus === 'completed' && order.provider_id) {
        const [title, body] = providerNotifications['completed'];
        await sendNotification(order.provider_id, title, body, 'order_status', { order_id: order.id, status: 'completed' });
        await saveInAppNotification(order.provider_id, title, body, 'order_status', { order_id: order.id, status: 'completed' });
      }
    }

    // ── Handle Chat Messages ─────────────────────────────
    if (table === 'chat_messages') {
      const msg = record;
      const senderId = msg.sender_id;
      const bookingId = msg.booking_id;

      if (bookingId) {
        // Get the booking to find the other party
        const { data: booking } = await supabase.from('bookings').select('client_id, provider_id').eq('id', bookingId).single();
        if (booking) {
          const recipientId = senderId === booking.client_id ? booking.provider_id : booking.client_id;
          if (recipientId) {
            const senderName = await getUserName(senderId);
            const preview = msg.message ? msg.message.substring(0, 50) : 'رسالة جديدة';
            await sendNotification(recipientId, `رسالة جديدة من ${senderName}`, preview, 'chat_message', { booking_id: bookingId, sender_id: senderId });
            await saveInAppNotification(recipientId, `رسالة جديدة من ${senderName}`, preview, 'chat_message', { booking_id: bookingId, sender_id: senderId });
          }
        }
      }
    }

    // ── Handle Withdrawal Request Changes ───────────────────
    if (table === 'withdrawal_requests') {
      const reqData = record;

      // New withdrawal request - notify admins
      if (type === 'INSERT') {
        const { data: admins } = await supabase.from('profiles').select('id').eq('role', 'admin');
        for (const admin of admins ?? []) {
          await sendNotification(admin.id, 'طلب سحب أرباح جديد!', `مقدم خدمة طلب سحب ${reqData.amount} جنيه`, 'withdrawal_request', { request_id: reqData.id, amount: String(reqData.amount) });
          await saveInAppNotification(admin.id, 'طلب سحب أرباح جديد!', `مقدم خدمة طلب سحب ${reqData.amount} جنيه`, 'withdrawal_request', { request_id: reqData.id });
        }
      }

      // Status update - notify provider
      if (type === 'UPDATE') {
        const statusMsgs: Record<string, [string, string]> = {
          approved: ['تم تحويل أرباحك!', `تم تحويل ${reqData.amount} جنيه لحسابك`],
          rejected: ['طلب السحب مرفوض', reqData.admin_note || 'تواصل مع الدعم للمزيد من التفاصيل'],
        };

        if (statusMsgs[reqData.status]) {
          const [title, body] = statusMsgs[reqData.status];
          await sendNotification(reqData.provider_id, title, body, 'withdrawal_update', { status: reqData.status, request_id: reqData.id });
          await saveInAppNotification(reqData.provider_id, title, body, 'withdrawal_update', { status: reqData.status, request_id: reqData.id });
        }
      }
    }

    // ── Handle Commission Settlement ───────────────────────
    if (table === 'commission_settlements') {
      const settlement = record;
      if (type === 'INSERT') {
        // Notify admin about new settlement
        const { data: admins } = await supabase.from('profiles').select('id').eq('role', 'admin');
        for (const admin of admins ?? []) {
          await sendNotification(admin.id, 'توريد عمولة جديد', `مقدم خدمة أرسل إثبات توريد ${settlement.amount} جنيه`, 'settlement', { settlement_id: settlement.id });
          await saveInAppNotification(admin.id, 'توريد عمولة جديد', `مقدم خدمة أرسل إثبات توريد ${settlement.amount} جنيه`, 'settlement', { settlement_id: settlement.id });
        }
      }
      if (type === 'UPDATE' && settlement.status === 'approved') {
        await sendNotification(settlement.provider_id, 'تم تأكيد التوريد', `تم تأكيد توريد ${settlement.amount} جنيه بنجاح`, 'settlement', { settlement_id: settlement.id });
        await saveInAppNotification(settlement.provider_id, 'تم تأكيد التوريد', `تم تأكيد توريد ${settlement.amount} جنيه بنجاح`, 'settlement', { settlement_id: settlement.id });
      }
    }

    return jsonResponse({ success: true, message: 'Notifications processed' });
  } catch (error) {
    console.error('Order notification trigger error:', error);
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});
