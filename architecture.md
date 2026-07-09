# System Architecture - Faster App

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter 3.5+ / Dart |
| **Backend** | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| **Push Notifications** | Firebase Cloud Messaging |
| **Payments** | Paymob SDK |
| **Maps** | flutter_map + OpenStreetMap |
| **Location** | Geolocator package |
| **State Management** | StatefulWidget + flutter_riverpod |
| **Local Storage** | SharedPreferences + Hive |

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App constants, API keys
│   ├── services/           # Location, notifications, chat cleanup
│   ├── theme/              # Design tokens, app theme
│   └── utils/              # Helper functions
├── features/
│   ├── admin/              # Admin dashboard, orders, providers, settings
│   ├── auth/               # Login, register, OTP verification
│   ├── booking/            # Booking flow, tracking, my orders
│   ├── chat/               # In-app messaging
│   ├── home/               # Home screen, categories, search
│   ├── notifications/      # Notification center
│   ├── profile/            # User profile, settings, referral
│   ├── provider/           # Provider dashboard, orders, wallet
│   ├── services/           # Service listing
│   ├── developer/          # Developer tools
│   └── prescription/       # Prescription upload
└── main.dart
```

## Backend Architecture (Supabase)

### Database Tables (22+)

| Table | Purpose |
|-------|---------|
| profiles | User accounts (client/provider/admin) |
| provider_profiles | Extended provider data |
| categories | Service categories |
| services | Service offerings |
| provider_services | Provider-service relationships |
| bookings | Service orders |
| service_requests | Quick broadcast requests |
| reviews | Provider ratings |
| chat_messages | In-app messaging |
| wallets | Provider earnings |
| transactions | Financial history |
| withdrawal_requests | Provider withdrawals |
| offers | Promotional offers |
| carousel_images | Home screen banners |
| fcm_tokens | Push notification tokens |
| notifications | In-app notifications |
| provider_locations | Real-time location tracking |
| provider_analytics | Provider statistics |
| refund_requests | Client refund requests |
| admin_warnings | Admin warnings + reports |
| commission_settlements | Commission payment tracking |
| chat_cleanup_log | Chat auto-deletion logs |

### Security

- Row Level Security (RLS) policies on all tables
- Role-based access (client, provider, admin)
- JWT authentication via Supabase Auth
- Secure API key management

## Feature Modules

### Auth Module (6 screens)
- Login with phone/email
- Registration (phone mandatory)
- OTP verification
- Password reset
- Profile setup

### Booking Module (10 screens)
- Service booking flow
- Real-time tracking
- My orders (current/past)
- Waiting for provider
- Price negotiation

### Provider Module (18 screens)
- Dashboard with earnings
- Order management
- Wallet & settlements
- Profile & documents
- Request map with radius

### Admin Module (18 screens)
- Dashboard with statistics
- Order management
- Provider management
- User management
- Financial reports

## Push Notifications

- Firebase Cloud Messaging (FCM)
- Foreground message handling
- Background message handling
- Topic-based subscriptions
- Custom notification sounds

## Payment Integration

- Paymob SDK for card payments
- Wallet payments
- Cash on delivery
- Commission tracking
- Settlement management

## Location Services

- Real-time GPS tracking
- Provider location updates (5-second intervals)
- Distance calculation (Haversine formula)
- Search radius filtering
- Auto-capture on booking

## Design System

- Centralized design tokens (`design_tokens.dart`)
- Consistent spacing, radius, elevation
- Light and dark theme support
- Responsive layout with screenutil
- Arabic-first RTL support
