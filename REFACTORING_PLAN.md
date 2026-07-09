# Faster App - التدقيق الشامل وخطة الإصلاح

## الهدف
إعادة هيكلة الكود، جعله نظيفاً ومرتباً، وتدقيق كامل لجميع الشاشات حسب الدور (عميل/مزود/أدمن) مع تصنيف المشكلات وترتيب حلها.

## الهيكل الحالي للمشروع
```
lib/
├── core/
│   ├── services/           (خدمات مشتركة)
│   ├── theme/              (الثيم والألوان)
│   ├── utils/              (الأدوات المساعدة)
│   ├── widgets/            (الوidges المشتركة)
│   └── models/             (النماذج)
├── features/
│   ├── admin/              (شاشات الأدمن)
│   ├── auth/               (شاشات المصادقة)
│   ├── booking/            (شاشات الحجوزات)
│   ├── chat/               (شاشات الدردشة)
│   ├── delivery/           (شاشات التوصيل)
│   ├── home/               (الشاشات الرئيسية)
│   ├── notifications/      (الإشعارات)
│   ├── onboarding/           (شاشات البداية)
│   ├── prescription/       (الروشتات)
│   ├── profile/            (الملف الشخصي)
│   ├── provider/           (شاشات المزود)
│   ├── ride/               (الرحلات)
│   ├── seller/             (البائعين)
│   ├── services/           (الخدمات)
│   └── shopping/           (التسوق)
```

---

## المشكلات العامة (مشتركة بين جميع الأدوار)

### 🔴 Critical (حرجة)
- **Mixing business logic with UI**: معظم الشاشات تحتوي على كود الـ Supabase مباشرة داخل الـ `build` أو داخل StatefulWidget بدون استخدام clean architecture (Repositories/UseCases).
- **Raw data fetching in UI**: طلبات قاعدة البيانات Ocuker مباشرة في الـ `State` بدون `ChangeNotifier` أو `BLoC` أو حتى `FutureBuilder` منظم.
- **No proper null safety handling**: بعض الشاشات تستخدم `!` بكثرة أو تتجاهل التعامل مع `null` مما قد يؤدي لـ Runtime Crashes (مثلا في parsing الـ `profiles` بعد查询).
- **Main.dart is bloated**: `main.dart` يحتوي على `FasterApp` + handler للـ notifications + route initialization + security checks. يجب تقسيمه.

### 🟠 High (عالية)
- **Hardcoded Colors**: استخدام `Color(0xFF...)` مباشرة في الشاشات بدلاً من `AppTheme`.
- **Bad imports**: كثير من الـ imports غير منظمة (مثلا `../../../core/theme/app_theme.dart`) سهل أن تتكسر.
- **Inconsistent naming**: أسماء classes/files مختلفة (مثلا `provider_...` و `admin_...` و `client_...`) بدون convention موحد.
- **No State Management**: لا يوجد `Provider`/`Riverpod`/`Bloc` في الشاشات الكبيرة (مثل `provider_dashboard`) مما يؤدي ل rebuilds كثيرة وأداء أقل.
- **Error handling**: `try-catch` عام كـ `catch(e)` بدون logging مناسب أو معالجة نوع الـ Exception.

### 🟡 Medium (متوسطة)
- **Magic numbers**: أرقام مثل `30` أو `500` أو `999` مُضمّنة مباشرة في الكود.
- **Repeated widgets**: بتحضيرCustom widgets مثل `AppTextField`، لكن بعض الشاشات تعيد تعريف الـ UI بشكل مكرر.
- **Assets/Images paths**: مسارات الصور مكتوبة بـ `String` hardcoded بدون class مركزي.

---

## 📋 نظام مراجعة الشاشات (حسب الدور)

### 👥 **دور العميل (Client Role)**
| الشاشة | الحالة | المشكلات | الأولوية |
|--------|--------|----------|----------|
| `home_screen.dart` | تحتاج تحسين | ألوان ثابتة، استدعاء الخدمات مباشرة | High |
| `login_screen.dart` | تحتاج تحسين | `AuthRepository` يُستخدم بدون BLoC | High |
| `register_screen.dart` | تحتاج تحسين | تحقق من البيانات مباشر | Medium |
| `main_nav_screen.dart` | تحتاج تنظيف | منطق الصفحات مُضمّن | Medium |
| `my_bookings_screen.dart` | تحتاج تحسين | طلبات قاعدة البيانات في State | High |
| `tracking_screen.dart` | تحتاج تحسين | منطق التتبع مربك | High |
| `booking_screen.dart` | تحتاج تحسين | كود طويل ومعقد | High |
| `chat_screen.dart` | تحتاج تحسين | سيناريو التقرير والمراسلة مختلط | Medium |
| `profile_screen.dart` | تحتاج تحسين | تعدد المهام | Medium |
| `waiting_for_provider_screen.dart` | تحتاج تحسين | Hardcoded strings | Low |

### 🔧 **دور المزود (Provider Role)**
| الشاشة | الحالة | المشكلات | الأولوية |
|--------|--------|----------|----------|
| `provider_dashboard_screen.dart` | تحتاج تحسين كبير | منطق معقد جداً + 60+ حقل | Critical |
| `provider_orders_screen.dart` | تحتاج تحسين | طلبات كثيرة وفلاتر مُضمّنة | High |
| `provider_wallet_screen.dart` | تحتاج تحسين | منطق اقتصادي حساس | High |
| `provider_nav_screen.dart` | تحتاج تحسين | Hardcoded strings | Medium |
| `provider_trip_history_screen.dart` | تحتاج تحسين | قابلة لاستخراج widgets | Medium |
| `provider_requests_map_screen.dart` | تحتاج تحسين | منطق الخرائط المربك | Medium |
| `provider_arrival_qr_scan_screen.dart` | تحتاج تحسين | كود مختص بسيط | Low |

### 🎛️ **دور الأدمن (Admin Role)**
社会活动 | الدولة | المشكلات | الأولوية |
|--------|--------|----------|----------|
| `admin_dashboard_screen.dart` | تحتاج تحسين | منطق إجماليات معقد | High |
| `admin_orders_screen.dart` | تحتاج تحسين | قابلة لاستخراج widgets | Medium |
| `admin_providers_screen.dart` | تحتاج تحسين | Can be refactored | Medium |
| `admin_withdrawals_screen.dart` | تحتاج تحسين | Table UI | Medium |
| `admin_settlements_screen.dart` | تحتاج تحسين | منطق مالي | Medium |
| `admin_services_screen.dart` | تحتاج تحسين | CRUD logic in UI | Medium |
| `admin_categories_screen.dart` | تحتاج تحسين | تحليل الفئات | Medium |
| `admin_offers_screen.dart` | تحتاج تحسين | Dropdown & CRUD | Medium |
| `admin_carousel_screen.dart` | تحتاج تحسين | Image management | Low |
| `admin_reports_screen.dart` | تحتاج تحسين | Report generation | Medium |
| `admin_cash_remittance_screen.dart` | تحتاج تحسين | Financial logic | Medium |
| `admin_notifications_screen.dart` | تحتاج تحسين | Notification handling | Medium |
| `admin_verification_screen.dart` | تحتاج تحسين | Verification flow | Medium |
| `admin_pricing_screen.dart` | تحتاج تحسين | Pricing rules | Low |
| `admin_quality_dashboard_screen.dart` | تحتاج تحسين | Dashboard metrics | Low |
| `admin_debug_screen.dart` | تحتاج تحسين | Debug tools | Low |

---

## 🛠️ خطة الإصلاح (المرحلة الأولى)

### الخطوة 1: إنشاء الأنماط الجديدة
1. **Extract Core Services & Repositories**:
   - نقل منطق الـ Supabase من الـ UI إلى `data/repositories/`.
   - إنشاء `abstract class` للـ Repositories.
2. **Enhance Core Widgets**:
   - تحسين `AppCard`, `AppButton`, `AppTextField` لتكون flexible أكثر.
3. **Standardize Error Handling**:
   - إنشاء `AppException` class و `ErrorHandler` widget.

### الخطوة 2: تنظيف الشاشات الحرجة
1. `provider_dashboard_screen.dart`:
   - استخراج الـ State إلى `ProviderDashboardController` (Riverpod/Bloc).
   - تقسيم الـ UI إلى `widgets` صغيرة.
2. `admin_dashboard_screen.dart`:
   - تحسين منطق الإجماليات.
   - استخراج الـ charts و UI widgets.
3. `home_screen.dart` + `my_bookings_screen.dart`:
   - استبدال الألوان الثابتة بـ `AppTheme`.
   - سهولة الـ reads من الـ database.

### الخطوة 3: تطبيع الـ Features
- نقل `core/widgets` المشتركة فقط، ونقل الـ widgets الخاصة بـ feature لتحت `features/<feature>/widgets/`.
- التأكد من أن كل feature يحتوي على: `data/`, `domain/`, `presentation/`.
