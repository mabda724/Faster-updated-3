<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Supabase-2.8-3FCF8E?logo=supabase&logoColor=white" alt="Supabase">
  <img src="https://img.shields.io/badge/Firebase-Messaging-FFCA28?logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Paymob-Integration-00B4D8?logo=payment&logoColor=white" alt="Paymob">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <br><br>
  <h1>⚡ FASTER</h1>
  <h3>منصة حجز الخدمات المنزلية - Home Services Booking Platform</h3>
  <p><em>اطلب الخدمة في السريع ⚡</em></p>
</div>

---

## 📋 نظرة عامة | Overview

**FASTER** هو تطبيق متكامل لربط العملاء بمقدمي الخدمات المنزلية (فنيين، سباكين، كهربائيين، نجارين، وغيرهم) في مصر. يقدم التطبيق تجربة مستخدم سلسة مع دعم كامل للغة العربية وواجهة عصرية.

**FASTER** is a comprehensive platform connecting clients with home service providers (technicians, plumbers, electricians, carpenters, etc.) in Egypt, featuring a seamless user experience with full Arabic support and a modern UI.

---

## 🚀 المميزات الرئيسية | Key Features

### 👤 للعملاء | For Clients
- **طلب فوري للخدمات** - تصفح الخدمات والأقسام واختيار الأنسب
- **نظام البث (Broadcast)** - إرسال طلب لعدة مقدمي خدمات واستقبال العروض
- **تتبع مباشر** - متابعة موقع مقدم الخدمة لحظة بلحظة
- **دردشة فورية** - تواصل مباشر مع مقدم الخدمة
- **نظام تقييم ومراجعات** - تقييم الخدمات ومقدميها
- **مدفوعات إلكترونية** - عبر Paymob
- **QR Code** - تأكيد الوصول والدفع عبر QR
- **طلبات استرداد** - تقديم طلبات استرداد المبالغ

### 🔧 لمقدمي الخدمات | For Providers
- **لوحة تحكم متكاملة** - إدارة الطلبات والأرباح
- **محفظة مالية** - تتبع الأرباح وسحب الأموال
- **إدارة الخدمات** - إضافة وتعديل الخدمات المقدمة
- **تحديثات فورية** - استلام إشعارات الطلبات الجديدة
- **رفع المستندات** - توثيق الحساب (الرقم القومي، صورة شخصية)
- **إحصائيات وتحليلات** - تقارير الأداء والأرباح

### 👑 للإدارة | For Admins
- **لوحة تحكم إدارية** - إدارة كاملة للمنصة
- **إدارة الأقسام والخدمات** - إضافة وتعديل الأقسام والخدمات
- **إدارة المستخدمين** - مراقبة العملاء ومقدمي الخدمات
- **تقارير مالية** - إجمالي الإيرادات والمعاملات
- **إدارة العروض** - إنشاء عروض ترويجية
- **صور الكاروسيل** - إدارة صور الصفحة الرئيسية
- **نظام الصيانة** - تفعيل وضع الصيانة للتطبيق

---

## 🛠️ التقنيات المستخدمة | Tech Stack

| التقنية | Tech | الاستخدام |
|---------|------|-----------|
| <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" width="100"> | **Flutter 3.41+** | إطار العمل الرئيسي |
| <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" width="80"> | **Dart 3.11+** | لغة البرمجة |
| <img src="https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white" width="120"> | **Supabase** | قاعدة البيانات والمصادقة والتخزين |
| <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black" width="120"> | **Firebase Cloud Messaging** | الإشعارات الفورية |
| <img src="https://img.shields.io/badge/Paymob-00B4D8?logo=&logoColor=white" width="100"> | **Paymob** | بوابة الدفع الإلكتروني |
| <img src="https://img.shields.io/badge/Riverpod-FF6B6B?logo=&logoColor=white" width="110"> | **Riverpod** | إدارة الحالة |
| <img src="https://img.shields.io/badge/Flutter%20Map-34C759?logo=openstreetmap&logoColor=white" width="140"> | **Flutter Map + OpenStreetMap** | الخرائط والموقع |

---

## 📦 الحزم المستخدمة | Packages

| الحزمة | الإصدار | الاستخدام |
|--------|---------|-----------|
| `flutter_riverpod` | ^2.6.1 | إدارة الحالة |
| `supabase_flutter` | ^2.8.4 | قاعدة البيانات والمصادقة |
| `firebase_messaging` | ^16.2.0 | الإشعارات |
| `flutter_map` | ^8.3.0 | الخرائط |
| `geolocator` | ^13.0.2 | تحديد الموقع |
| `image_picker` | ^1.1.2 | اختيار الصور |
| `carousel_slider` | ^5.1.2 | صور الكاروسيل |
| `cached_network_image` | ^3.4.1 | تحميل الصور |
| `fl_chart` | ^0.70.2 | الرسوم البيانية |
| `mobile_scanner` | ^5.2.3 | مسح QR Code |
| `url_launcher` | ^6.3.2 | فتح الروابط |
| `share_plus` | ^10.1.4 | المشاركة |
| `flutter_paymob_sdk` | ^1.0.1 | الدفع الإلكتروني |
| `flutter_local_notifications` | ^18.0.0 | الإشعارات المحلية |
| `google_fonts` | ^8.0.2 | الخطوط |
| `font_awesome_flutter` | ^11.0.0 | الأيقونات |
| `intl` | ^0.20.2 | الترجمة والتنسيق |
| `qr_flutter` | ^4.1.0 | إنشاء QR Code |

---

## 🗄️ قاعدة البيانات | Database Schema

قاعدة البيانات تحتوي على **21 جدولاً** مع Policies وTriggers وFunctions:

### الجداول الرئيسية
| الجدول | الوصف |
|--------|-------|
| `profiles` | حسابات المستخدمين (client / provider / admin) |
| `categories` | أقسام الخدمات الرئيسية |
| `services` | الخدمات المقدمة |
| `provider_profiles` | ملفات مقدمي الخدمات |
| `bookings` | الحجوزات والطلبات |
| `service_requests` | طلبات البث السريع |
| `reviews` | التقييمات والمراجعات |
| `chat_messages` | رسائل الدردشة |
| `wallets` | محافظ مقدمي الخدمات |
| `transactions` | سجل المعاملات المالية |
| `notifications` | الإشعارات |
| `provider_locations` | مواقع مقدمي الخدمات (实时) |

### أنظمة متكاملة
- **🔐 RLS Policies** - حماية البيانات على مستوى الصف
- **📊 Triggers** - تحديثات تلقائية للإحصائيات
- **📧 Functions** - دوال الخلفية (Edge Functions)
- **📁 Storage** - تخزين الصور والمستندات

---

## 🏗️ هيكل المشروع | Project Structure

```
faster_app/
├── lib/
│   ├── main.dart                          # نقطة الدخول
│   ├── config/                            # إعدادات التطبيق
│   ├── core/
│   │   ├── config/                        # إعدادات أساسية
│   │   ├── constants/                     # ثوابت التطبيق
│   │   ├── exceptions/                    # معالجة الأخطاء
│   │   ├── models/                        # نماذج مشتركة
│   │   ├── navigation/                    # نظام التوجيه
│   │   ├── services/                      # خدمات أساسية
│   │   ├── state/                         # إدارة الحالة
│   │   ├── theme/                         # الثيم والألوان
│   │   ├── utils/                         # دوال مساعدة
│   │   └── widgets/                       # ويدجت مشتركة
│   └── features/
│       ├── admin/                         # لوحة الإدارة
│       ├── auth/                          # المصادقة
│       ├── booking/                       # الحجوزات
│       ├── chat/                          # الدردشة
│       ├── home/                          # الصفحة الرئيسية
│       ├── profile/                       # الملف الشخصي
│       ├── provider/                      # مقدمي الخدمات
│       └── services/                      # الخدمات
├── android/                               # إعدادات Android
├── ios/                                   # إعدادات iOS
├── supabase/
│   ├── functions/                         # Edge Functions
│   └── migrations/                        # SQL Migrations
├── supabase_complete_schema.sql           # كامل قاعدة البيانات
├── supabase_final_fix.sql                 # الإصلاحات النهائية
└── pubspec.yaml                           # تعريف المشروع
```

---

## ⚙️ التشغيل | Getting Started

### المتطلبات | Prerequisites
- **Flutter SDK** 3.41+ ([Install](https://flutter.dev/docs/get-started/install))
- **Supabase** حساب ([Supabase](https://supabase.com))
- **Firebase** مشروع للإشعارات ([Firebase](https://firebase.google.com))
- **Paymob** حساب للدفع ([Paymob](https://paymob.com))

### خطوات التثبيت | Installation

```bash
# 1. Clone the repository
git clone https://github.com/mabda724/Faster-updated-3.git
cd Faster

# 2. Switch to updated branch
git checkout updated

# 3. Install dependencies
flutter pub get

# 4. Configure environment
# Create assets/.env file with your Supabase credentials:
echo "SUPABASE_URL=https://your-project.supabase.co" >> assets/.env
echo "SUPABASE_ANON_KEY=your-anon-key" >> assets/.env

# 5. Run database migrations
# Execute supabase_complete_schema.sql in Supabase SQL Editor

# 6. Run the app
flutter run -d chrome        # Web
flutter run -d windows       # Windows Desktop
flutter build apk --debug    # Android APK
```

---

## 🌐 متغيرات البيئة | Environment Variables

أنشئ ملف `assets/.env` بالمحتوى التالي:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
```

---

## 📱 لقطات الشاشة | Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center"><b>الصفحة الرئيسية</b></td>
      <td align="center"><b>الخدمات</b></td>
      <td align="center"><b>الحجوزات</b></td>
    </tr>
    <tr>
      <td><img src="screenshots/home.png" width="200" alt="Home"></td>
      <td><img src="screenshots/services.png" width="200" alt="Services"></td>
      <td><img src="screenshots/booking.png" width="200" alt="Booking"></td>
    </tr>
  </table>
</div>

---

## 🤝 المساهمة | Contributing

نرحب بمساهماتك! يرجى اتباع الخطوات:

1. Fork المشروع
2. إنشاء فرع للميزة: `git checkout -b feature/my-feature`
3. عمل Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. فتح Pull Request

---

## 📄 الترخيص | License

هذا المشروع مرخص تحت **MIT License**.

```
MIT License

Copyright (c) 2026 FASTER Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files...
```

---

## 👨‍💻 فريق التطوير | Development Team

- **المطور**: [@mabda724](https://github.com/mabda724)
- **البريد الإلكتروني**: support@faster-app.com

---

<div align="center">
  <p>⭐ لا تنسى إعطاء المشروع نجمة إذا أعجبك!</p>
  <p>⚡ Faster - خدمات منزلية تثق فيها ⚡</p>
</div>
