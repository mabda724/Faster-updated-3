# إعداد Firebase FCM في Supabase Edge Functions

## الخطوة 1: إضافة Firebase Service Account إلى Supabase

### 1. الدخول إلى Supabase Dashboard
1. اذهب إلى [Supabase Dashboard](https://supabase.com/dashboard)
2. اختر مشروعك

### 2. إضافة متغير البيئة
1. من القائمة الجانبية، اختر **Edge Functions**
2. انقر على **Settings** (الإعدادات)
3. انتقل إلى قسم **Environment Variables**
4. أضف متغير جديد:
   - **Name**: `FIREBASE_SERVICE_ACCOUNT`
   - **Value**: الصق JSON التالي بالكامل:

```json
{
  "type": "service_account",
  "project_id": "faster-5d279",
  "private_key_id": "REDACTED_GET_FROM_FIREBASE_CONSOLE",
  "private_key": "-----BEGIN PRIVATE KEY-----\nREDACTED_GET_FROM_FIREBASE_CONSOLE\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@faster-5d279.iam.gserviceaccount.com",
  "client_id": "REDACTED",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40faster-5d279.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
```

5. انقر على **Save**
6. انتظر حتى يتم نشر Edge Function

## الخطوة 2: اختبار Edge Function

### اختبار باستخدام curl
```bash
curl -X POST https://your-project.supabase.co/functions/v1/send-notification \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "YOUR_USER_ID",
    "title": "Test Notification",
    "body": "This is a test notification from Supabase Edge Function",
    "type": "test",
    "data": {}
  }'
```

### اختبار من التطبيق
بعد إضافة متغير البيئة، سيتم إرسال الإشعارات تلقائياً عند:
- تغيير حالة الطلب
- توريد العمولة
- إرسال رسالة محادثة
- طلب سحب
- أي إجراء آخر يستخدم `NotificationService.sendPushNotification()`

## الخطوة 3: التحقق من FCM Token

تأكد من أن FCM token محفوظ في قاعدة البيانات:

```sql
SELECT id, full_name, fcm_token 
FROM profiles 
WHERE fcm_token IS NOT NULL;
```

إذا لم يكن FCM token محفوظاً، تأكد من:
1. التطبيق لديه صلاحيات الإشعارات
2. `NotificationService.initialize()` تم استدعاؤه
3. المستخدم مسجل الدخول

## استكشاف الأخطاء

### الإشعارات لا تصل
1. تحقق من متغير البيئة `FIREBASE_SERVICE_ACCOUNT` في Supabase
2. تحقق من FCM token في قاعدة البيانات
3. تحقق من سجلات Edge Function في Supabase Dashboard
4. تأكد من أن التطبيق لديه صلاحيات الإشعارات

### خطأ في Edge Function
1. تحقق من سجلات Edge Function
2. تأكد من أن JSON صحيح
3. تأكد من أن Firebase Service Account صالح

### FCM token غير محفوظ
1. تأكد من أن `NotificationService.initialize()` تم استدعاؤه
2. تحقق من صلاحيات الإشعارات في التطبيق
3. أعد تشغيل التطبيق

## Edge Function الموجودة

الـ Edge Function `send-notification` موجودة بالفعل في:
`supabase/functions/send-notification/index.ts`

وهي مهيئة لـ:
- FCM v1 API
- Firebase Service Account authentication
- إرسال إشعارات فردية أو broadcast
- معالجة الأخطاء

## بعد الإعداد

بعد إضافة متغير البيئة:
1. أعد تشغيل التطبيق
2. تأكد من تسجيل الدخول
3. قم بإجراء تغيير في حالة الطلب
4. تحقق من وصول الإشعار

إذا وصلت الإشعار، فالإعداد ناجح! 🎉
