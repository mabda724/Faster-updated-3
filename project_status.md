# Project Status - Faster App

## Overview

| Field | Value |
|-------|-------|
| **Version** | 1.0.1+2 |
| **Branch** | `onesignal-integration` (misleading - OneSignal removed) |
| **Status** | FUNCTIONAL but pre-production |
| **Last Commit** | `5b49a93` (103 files, +11780/-5239) |
| **Flutter Analyze** | PASS (0 errors, warnings only) |

## Codebase Metrics

| Metric | Count |
|--------|-------|
| Dart Files | 138 |
| Screen Files | 93 |
| SQL Migrations | 58 |
| Feature Modules | 11 |
| Core Files | 41 |
| Database Tables | 22+ |

## Feature Modules

| Module | Screens | Description |
|--------|---------|-------------|
| admin | 18 | Dashboard, orders, providers, users, offers, settings |
| auth | 6 | Login, register, OTP, forgot password |
| booking | 10 | Booking flow, tracking, my orders, waiting screen |
| chat | 1 | In-app messaging |
| home | 7 | Home screen, categories, service details, search |
| notifications | 1 | In-app notification center |
| profile | 5 | User profile, settings, referral, wallet |
| provider | 18 | Dashboard, orders, wallet, profile, requests map |
| services | 3 | Service listing and details |
| developer | 1 | Developer tools |
| prescription | 1 | Prescription upload |

## Tech Stack

- **Framework**: Flutter 3.5+ / Dart
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
- **Push Notifications**: Firebase Cloud Messaging (replaced OneSignal)
- **Payments**: Paymob SDK
- **Maps**: flutter_map + OpenStreetMap + Geolocator
- **State Management**: StatefulWidget + flutter_riverpod

## Key Features

- Phone + email authentication (phone mandatory for new users)
- Real-time provider location tracking
- Price offer negotiation system
- Commission settlement tracking
- Chat with 30-day auto-deletion
- Client report system
- Promotional carousel on home screen
- Provider category-based request matching
- 500 EGP minimum withdrawal limit

## Pre-Production Checklist

- [ ] Real credentials in `.env`
- [ ] Signing keystore created
- [ ] Firebase configured for both platforms
- [ ] All SQL migrations run
- [ ] Storage buckets created
- [ ] App settings configured
- [ ] Tests written and passing
