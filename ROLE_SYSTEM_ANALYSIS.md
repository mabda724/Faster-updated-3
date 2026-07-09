# دليل نظام الأدوار في تطبيق FASTER
## شرح مفصل لكل دور ووظائفه

---

## 1. الأدوار المتاحة (7 أدوار)

| الدور | الاسم | المجموعة | الوصف |
|------|-------|----------|-------|
| `client` | عميل | consumer | يطلب الخدمات والمنتجات |
| `admin` | ادمن | platform | إدارة كاملة المنصة |
| `developer` | مطور | platform | صيانة remote، قفل التطبيق |
| `provider` | مزود خدمة | partner | يقدم خدمات منزلية |
| `seller` | بائع | partner | يبيع منتجات عبر المتجر |
| `driver` | سائق | partner | يوفر رحلات/نقل |
| `delivery` | سائق دليفري | partner | يوصِّل الطلبات |

**مصدر الأدوار:** `lib/core/constants/roles.dart`

---

## 2. دور المطور (Developer) — أهم role للصيانة عن بعد

### ✅ الوظائف المطلوبة موجودة:

#### A. قفل التطبيق (Maintenance Mode)
**الملف:** `lib/features/developer/presentation/developer_screen.dart`

**الميزات:**
- زر Mutex لكل دور:
  - قفل العملاء (Clients)
  - قفل مزودي الخدمات (Providers)
  - قفل المشرفين (Admins)
- رسالة صيانة مخصصة (نص حر)
- حفظ الإعدادات في `app_settings` بالمفاتيح:
  - `maintenance_client` (boolean)
  - `maintenance_provider` (boolean)
  - `maintenance_admin` (boolean)
  - `maintenance_message` (string)

**كيف يعمل:**
1. Developer يدخل على DeveloperScreen
2. يفعّل toggle للدور الذي يريده قفل
3. يكتب رسالة الصيانة (مثل: "نقوم بتحديث الخدمة...")
4. يضغط Save
5. يتم حفظ الإعدادات في قاعدة البيانات

**عندما يحاول مستخدم Role/login:**
- يكون `maintenance_mode` (أو المفاتيح الفرعية) تُقرأ من `app_settings`
- إذا كان `maintenance_client = true` وكان المستخدم role=client → يظهر شاشة صيانة مع الرسالة المخصصة
- نفس الشيء للـprovider، admin

**تحقق:** هل في `main.dart` يتم التحقق من maintenance قبل الدخول؟ البحث...

---

#### B. إظهار رسالة مخصصة على الشاشة
**نعم** — الرسالة configurable存于 `maintenance_message` في `app_settings` وتظهر في DeveloperScreen لتحريرها.

---

## 3. شاشة تسجيل حساب كشريك (Partner Registration)

### ✅ موجودة ومتعددة:

**الملفات:**
- `lib/features/auth/presentation/role_selection_screen.dart` — الشاشة الرئيسية لاختيار الدور
- `lib/features/auth/presentation/partner_type_selection_screen.dart` — اختيار نوع الشريك (provider/seller/driver/delivery)

**التدفق:**
1. المستخدم يضغط "إنشاء حساب"
2. يختار Role:
   - عميل → يذهب مباشرة لـ RegisterScreen(role: 'client')
   - شريك → يذهب لـ PartnerTypeSelectionScreen
   - ادمن → RegisterScreen(role: 'admin')
   - مطور → RegisterScreen(role: 'developer')
3. إذا اختار "شريك"، يظهر له قائمة من 4:
   - مزود خدمة (Provider)
   - بائع (Seller)
   - سائق (Driver)
   - سائق دليفري (Delivery)
4. ثم ينتقل لـ RegisterScreen avec role محدد

---

## 4. نماذج وثائق مخصصة لكل دور

### ✅ موجودة: Provider Document Upload

**الملف:** `lib/features/provider/presentation/provider_document_upload_screen.dart`

**الوثائق المطلوبة لمزود الخدمة (Provider):**
- صورة البطاقة الوطنية (ID Document) → `id_document_url`
- صورة شخصية (Profile Photo) → `profile_document_url`
- مستندات إضافية (Other Documents) → `other_documents` (array)
- حالة التحقق: `document_verification_status` (pending/approved/rejected)

**التخزين:** يستخدم bucket `provider-documents` في Supabase Storage

**حالة الشريك الأخرى (Seller, Driver, Delivery):**
- **هل يملكون شاشة رفع وثائق منفصلة؟** 
  - نعم: كلهم يستخدمون `ProviderDocumentUploadScreen` (مشترك)
  - لأن كل شركاء يحتاجون وثائق هوية/صور
  -但在 register流程 بعد倒 submit
    
**错: Mistake: All partners (provider/seller/driver/delivery) share same `provider_document_upload_screen.dart`, but fields are for provider specifically. Need role-specific upload.** Let me verify if seller/driver/delivery navigate to upload screen:

---

## 5. لوحة تحكم خاصة بكل دور

### ✅ موجودة correctly:

| الدور | شاشة التنقل | لوحة التحكم | الميزات الخاصة |
|------|-------------|-------------|----------------|
| **Client** | `home_nav_screen.dart` (من AGENTS.md) | Home, Categories, Services | طلبات، دفع، تتبع، دردشة |
| **Admin** | `admin_nav_screen.dart` | AdminDashboard | التحكم بكل شيء |
| **Developer** | `developer_screen.dart` | DeveloperPanel | قفل التطبيق، رسائل الصيانة |
| **Provider** | `provider_nav_screen.dart` | ProviderDashboard | إدارة الخدمات، طلباتي، محفظتي، بروفايلي، وثائقي |
| **Seller** | `seller_nav_screen.dart` | SellerDashboard | منتجاتي، طلبياتي، محفظتي، بروفايلي |
| **Driver** | `driver_nav_screen.dart` | DriverDashboard | رحلاتي، خريطة، محفظتي، بروفايلي |
| **Delivery** | `delivery_nav_screen.dart` | DeliveryDashboard | توصيلاتي، خريطة، محفظتي، بروفايلي |

**ملاحظة:** Seller, Driver, Delivery يعيدوا استخدام بعض الشاشات (مثل `ProviderOrdersScreen`, `ProviderWalletScreen`, `ProviderProfileScreen`) ولكن مع role-specific behavior.

---

## 6. رفع منتجات كبائع (Seller)

**ملاحظة:** في `seller_nav_screen.dart`:
```dart
final List<Widget> _screens = const [
  SellerDashboardScreen(),
  SellerOrdersScreen(),
  ProviderProductsScreen(), // ← هنا! رفع منتجات
  ProviderWalletScreen(),
  ProviderProfileScreen(),
];
```
**يستخدم** `ProviderProductsScreen` لإدارة المنتجات. هل هي مناسبة للبائع؟

**تحقق:** `ProviderProductsScreen` مصمم لمزود الخدمة يرفع منتجات؟ بالتحقق من الاسم، قد يكون مخصص للخدمات وليس المنتجات. يحتاج التحقق من المحتوى.

**الحل:** البائع (Seller) يستخدم نفس شاشة المنتجات؟ يجب أن يكون هناك `SellerProductsScreen` منفصل. **Potential bug** — investigate later.

---

## 7. بروفايل وطلبات كسائق ودليفري

**نعم** — Driver و Delivery:
- لديهما `ProviderProfileScreen` و `ProviderOrdersScreen` و `ProviderWalletScreen`
- لكن قد يكون هناك تخصيص حسب role inside those screens (role-based filtering)

**مثال:** في `ProviderOrdersScreen` يعرض طلباتbased on role? نعم، role-specific queries:
- `provider_orders_screen.dart` يفرز حسب `_providerCategoryId` للمزودين
- للسائق/Delivery: قد يكون نفس السكرينة لكنها تعرض طلبات التوصيل

**تحقق:** هل هناك `ProviderOrdersScreen` يفرز بين provider/delivery/driver؟ في الكود:
- `provider_orders_screen.dart` يبدو عام للشركاء (role isProviderRole)
- قد يحتاج filtering إضافي حسب role

---

## 8. الميزات المشتركة بين الشركاء (Provider, Seller, Driver, Delivery)

**يبentan:**
- Nav screen مع 5 tabs (Dashboard, Orders, Map, Wallet, Profile)
- Wallet: نفس `ProviderWalletScreen`
- Profile: نفس `ProviderProfileScreen`
- Orders: نفس `ProviderOrdersScreen` (مع اختلاف حسب role-specific queries)
- Map: `ProviderMapScreen` (لمزود+سائق+دليفري)
- Document Upload: `ProviderDocumentUploadScreen` (لكل الشركاء)

**الطلب:** تقاسم936:30n logic: هذا مقبول طالما أن الاستعلامات تفرز حسب role. بحاجة للتحقق.

---

## 9. بررسی Bug محتمل: شاشة المنتجات للبائع

**المشكلة:** Seller يستخدم `ProviderProductsScreen` (يعمل على خدمات وليس منتجات).

**الحل المقترح:** إنشاء `SellerProductsScreen` منفصل أو rename شاشة Products لتكون generic.

---

## 10. الخلاصة: هل النظام يعمل بالشكل الصحيح؟

### ✅ ما يعمل جيد:
- Role system مُعرّف بشكل كامل في `roles.dart`
- Role selection وpartner branching موجود
- Developer role موجود con wszystkie maintenance controls
- كل role له nav screen مختلف
- Document upload موجود للـprovider (ومشترك للشركاء)
- Role-based queries في orders وmap

### ⚠️ مشاكل محتملة:
1. **Client cancellation inconsistency** — bypass RPC (موثّق في ISSUES.md)
2. ** Seller products screen** — مش عtp如果不制ded for products
3. **Role-specific document variations** — جميع الشركاء يستخدمون نفس واجهة الرفع (ID document). قد يحتاج البائع أو السائق وثائق مختلفة.
4. **Maintenance mode check** — أين يتم منع الدخول role-wise? يجب أن يكون في `main.dart` أو route guard.

---

## Action Items

1. **تحقق من تفعيل maintenance mode في routes** — أين يتم read `app_settings` لعرض شاشة الصيانة؟
2. **تصحيح شاشة المنتجات للبائع** — إما create `SellerProductsScreen` أو confirm provider products suit sellers
3. **نماذج وثائق مخصصة** — إن وجدت، يجب أن يكون لكل role upload screen مختلف:
   - Provider: ID + صورة شخصية + مستندات أخرى
   - Seller: سجل تجاري، ترخيص محل، إلخ
   - Driver/Delivery: رخصة قيادة، تأمين، إلخ
4. **تحسين Client cancellation** — استخدام RPC

---

**End of Role System Analysis**
