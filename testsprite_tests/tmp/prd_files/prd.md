# Taskty Product Requirements Document (PRD)

## Project Overview
Taskty is a service marketplace connecting clients with service providers in real-time.

## Key Features
1. **User Authentication**: Login/Register for Clients and Providers.
2. **Service Radar**: Clients can request immediate service from nearby providers.
3. **Provider Map**: Providers can see and accept pending requests on a map.
4. **Real-time Tracking**: Clients can track the provider's location after acceptance.
5. **Admin Dashboard**: Management of services, providers, and analytics.
6. **Payment Integration**: Support for Cash and Paymob (Credit Card/Wallet).

## Technical Stack
- Flutter (Web/Android/iOS)
- Supabase (Backend/Auth/DB)
- Google Maps / Flutter Map
- Paymob (Payment Gateway)

## User Flows
- **Client**: Login -> Search -> Request -> Track -> Pay.
- **Provider**: Login -> Go Online -> Accept Request -> Complete Service.
- **Admin**: Login -> Manage Data -> Review Statistics.
