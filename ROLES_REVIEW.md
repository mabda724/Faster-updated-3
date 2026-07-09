# مراجعة كاملة للدوار و الوظائف
##roles correct+a implementation status

---

## 1. دور المطور (Developer)

**الوظيفة:** قفل التطبيق للصيانة عن بعد مع إظهار رسالة مخصصة

**التنفيذ:**
- ✅ شاشة `DeveloperScreen` تتيح:
  - تفعيل/تعطيل الصيانة لكل دور (clients, providers, admins)
  - إدخال رسالة مخصصة تظهر للمستخدمين
  - الحفظ في `app_settings` جدول
- ✅ `MaintenanceService` يقرأ الإعدادات ويتحقق مما إذا كان الدور مقفولاً
- ✅ `MaintenanceScreen` يظهر شاشة كاملة مع:
  - رسالة الصيانة المخصصة
  - أيقونة متحركة
  - تحديث تلقائي كل 15 ثانية (إذا رفع الصيانة، يعيد التوجيه للصفحة الرئيسية)
- ✅ التفعيل发生在 `main.dart` بعد تهيئة Supabase

**صحيح بنسبة 100%:** نعم، يعمل بالشكل الصحيح.

**ملاحظة:** أدمن أيضاً يمكنه تفعيل الصيانة عبر `AdminMaintenanceScreen` (ميزة مكررة).

---

## 2. شاشة تسجيل الحساب كشريك + اختيار الدور

**التنفيذ:**
- ✅ `RoleSelectionScreen` تعرض 4 خيارات:
  - عميل (client)
  - ادمن (admin)
  - مطور (developer)
  - شريك (partner)
- ✅ اختيار "شريك" يفتح `PartnerTypeSelectionScreen` لاختيار نوع الشريك:
  - مزود خدمة (provider)
  - بائع (seller)
  - سائق (driver)
  - سائق دليفري (delivery)
- ✅ كل نوع يوجه إلى `RegisterScreen(role: role)` مع modelos específices

**صحيح:** نعم، التدفق سليم.

---

## 3. نماذج وثائق مخصصة لكل دور

**الواقع:**
- ❌ **ليس مخصصة لكل دور بشكل كامل** — هناك تفضيل للبساطة.
- ✅ جميع "الشركاء" (provider, seller, driver, delivery) يستخدمون نفس جدول `provider_profiles` في قاعدة البيانات.
- ✅ `provider_document_upload_screen.dart` مخصص لمقدمي الخدمة فقط (مزودو الخدمة).
- ❌ البائعين (seller) والسائقين (driver/delivery) **ليس لديهم شاشة رفع وثائق منفصلة**.
- يتم إدخال بياناتهم في `provider_profiles` أيضًا (مثل business_hours للبائعين، address، إلخ) ولكن دون وثائق تحقق (ID verification) إلا إذا كانوا أيضاً "مزود خدمة".

**المشكلة:** إذا كان الـ seller أو driver يحتاج رفع وثائق (للتحقق من الهوية)، لا يوجد له واجهة مخصصة. يستخدم نفس شاشة مزود الخدمة أو لا يرفع وثائق إطلاقاً.

**التصحيح المقترح:** إما:
- جعل وثائق التحقق مشتركة لكل الشركاء (جميع من يكون `provider_profiles` يرفع وثائق)
- أو فصل جدول `partner_profiles` عن `provider_profiles` وجعل كل نوع لديه extensión fields.

**الحالة الحالية:** موحدة في `provider_profiles` — غير صحيح من حيث التسمية والمصطلحات.

---

## 4. لوحة تحكم ورفع منتجات للبائع (Seller)

**التنفيذ:**
- ✅ `SellerDashboardScreen` — تعرض:
  - اسم المتجر
  - إجمالي المنتجات
  - إجمالي المبيعات
  - الرصيد (wallet_balance)
  - الطلبات النشطة
  - التحميل يعتمد على `products` جدول و `bookings`
- ✅ `SellerStoreProfileScreen` — تعديل ملف المتجر (الاسم، الوصف، الهاتف، البريد، العنوان، ساعات العمل، الشعار)
- ✅ `SellerOrdersScreen` — إدارة طلبات البيع
- ❌ **لم يتم العثور على شاشة "رفع منتجات" مخصصة للبائع** — ربما `ProviderProductsScreen` تُستخدم أيضاً للبائعين؟ (تحقق)

**التحقق:** أين `seller_add_product_screen.dart` أو `products_screen.dart` للبائعين؟
- `provider_products_screen.dart` موجود — قد يكون مُشاركاً (لكن اسمه provider products)
- لا يوجد `seller_products_screen.dart` منفصل

**الاستنتاج:** البائعين或许 يستخدمون نفس واجهة إدارة المنتجات الخاصة بمقدمي الخدمات، وهذا غير منطقي لأن Products table предназначен для البائعين (مادة 045)，لكن Provider عادة يقدم خدمات، ليس منتجات.

**مشكلة تصميم:** الجدول `products` مرتبط بـ `provider_profiles` حسب migration 045:
```sql
provider_id UUID NOT NULL REFERENCES provider_profiles(id)
```
هذا يعني كل المنتجات تنتمي إلى `provider_profiles`. ولكن البائع هو subtype من provider (نفس الجدول).ifolia
**صحيح تقنياً:** نعم، لكنslags UI غامض.

**تحتاج مراجعة:** هل هناك `seller_products_screen.dart`؟ إذا لا، يجب إنشاؤه أو إعادة تسمية الشاشة المشتركة.

---

## 5. بروفايل و تلقي طلبات كسائق و دليفري

**التنفيذ:**

### Driver
- ✅ `DriverDashboardScreen` — اسم، رصيد، إحصاءات اليوم (أرباح، رحلات)، تقييم، active ride
- ✅ `DriverActiveRideScreen` — تفاصيل الرحلة النشطة
- ✅ `DriverHistoryScreen` — الرحلات السابقة
- ✅ `DriverNavScreen` — navigation bar
- ✅ يعتمد على `bookings` table مع `provider_id` و statuses
- ❌ **لا يوجد شاشة بروفايل مخصصة لل bottlen** — قد يستخدم `ProviderProfileScreen` أو `ProfileScreen` العامة

### Delivery
- ✅ `DeliveryDashboardScreen` — اسم، حالة التوصيلات، إحصاءات اليوم، تقييم
- ✅ `DeliveryActiveScreen` — التوصيل النشط
- ✅ `DeliveryHistoryScreen` — سجل التوصيلات
- ✅ `DeliveryNavScreen` — navigation
- ❌ **لا توجد شاشة بروفايل مخصصة لل delivery** — قد يستخدم `ProviderProfileScreen` أو `ProfileScreen`

**الملاحظة:** كل من driver و delivery يستخدمان نفس `provider_profiles` table ( caption لـ lat/lng, rating, is_online, wallet_balance, settlement_amount إلخ). هذا مقبول إذا اعتبرناهما "مزودي خدمة" نوعاً ما، لكن الاسم أحياناً يكون مضللاً: driver يقدم خدمة النقل، delivery يقدم خدمة التوصيل، وكلاهما ليس "مزود خدمة منزلية".

**تحسين:** إعادة تسمية الملفات والمفاهيم:
- `Provider` = home services (f laparoscopic)
- `Seller` = product seller
- `Driver` = ride-hailing/transport
- `Delivery` = delivery/logistics

**لكن التنفيذ الحالي عملي وموحد.**

---

## 6. هل الأدوار تعمل بالشكل الصحيح؟

### تحليل الصحة:

| الدور |ashboard | Profile | Orders | Wallet | Products | Documents | الملاحظات |
|------|----------|---------|--------|--------|----------|-----------|----------|
| Client | ✅ Home | ✅ Profile | ✅ My Bookings | ❌ No wallet | ❌ | ❌ | عميل عادي |
| Admin | ✅ Dashboard | ✅ (admin profile) | ✅ All orders | ❌ | ❌ | ❌ | ادمن كامل الصلاحيات |
| Developer | ✅ Dev panel | — | — | — | — | — | يتحكم بالصيانة فقط |
| Provider | ✅ Dashboard | ✅ Profile | ✅ Orders | ✅ Wallet | ❌ (.services, not products) | ✅ Upload | مزود خدمات منزلية |
| Seller | ✅ Dashboard | ✅ Store profile | ✅ Orders | ✅ Wallet | ✅ (via ProviderProducts?) | ❌ (none) | بائع منتجات — يحتاج UI/products مخصص |
| Driver | ✅ Dashboard | ❌ (uses provider?) | ✅ Orders | ✅ Wallet | ❌ | ❌ | سائق رحلات — يحتاج profile screen |
| Delivery | ✅ Dashboard | ❌ (uses provider?) | ✅ Orders | ✅ Wallet | ❌ | ❌ | سائق توصيل — يحتاج profile screen |

### الخلل:
1. **Seller lacks separate products UI** — إما ينشئ `seller_products_screen.dart` أو يعيد تسمية `provider_products_screen.dart` إلى `products_screen.dart` ويجعلها مشتركة.
2. **Driver & Delivery lack profile screens** — حاليًا إذا pressed على البروفايل من القائمة قد يفتح `ProviderProfileScreen` (غير مناسب).
3. **Document upload** مخصص apenas لـ provider (مزود خدمة).seller & driver/delivery ليس لديهم وثائق. إذا كان التحقق مطلوباً للبائعين والسائقين، يجب توسيع الشاشة أو إنشاء جديدة.

### ما يعمل بشكل صحيح:
- ✅ maintenance mode toggle (developer & admin)
- ✅ role selection + partner subtype
- ✅ dashboard لكل دور
- ✅ wallet system لكل الشركاء (provider/seller/driver/delivery)
- ✅ orders flow لكل نوع

---

## التوصيات للإصلاح قبل الإطلاق:

1. **توحيد المنتجات:** إنشاء شاشة `ProductsScreen` مشتركة للبائعين فقط (وليسProviders) وتعديل الـ routes.
2. **بروفايل فردي للسائقين:** إنشاء `DriverProfileScreen` و `DeliveryProfileScreen` أو شاشة `PartnerProfileScreen` عامة.
3. **التحقق من الوثائق:** إما حذف التحقق من driver/delivery أو إضافته.
4. **إزالة duplication:** `DeveloperScreen` و `AdminMaintenanceScreen`536

 يعملان نفس المهمة — اختر واحداً وأزل الآخر أو خصص Developer للمطورين فقط (مkie إعدادات تقنية ليست للصيانة).

---

**End of Roles Review**
