# Faster Database Schema (Demo / Placeholder)

**⚠️ DEMO ONLY — This schema is a placeholder with fake tables and fields.**
**It does not represent the actual production database structure.**

## Overview

This document describes a simplified, fake database schema used for demonstration
and training purposes. All table names, column names, relationships, and data types
shown here are **fabricated representations**.

## Entity Relationship Diagram (Conceptual)

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  demo_users  │────→│ demo_bookings │────→│demo_payments │
└──────────────┘     └───────────────┘     └──────────────┘
       │                    │                       │
       │                    │                       │
       ▼                    ▼                       ▼
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│demo_profiles │     │ demo_reviews  │     │demo_receipts │
└──────────────┘     └───────────────┘     └──────────────┘
```

## Placeholder Tables

### `demo_users`
| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID (PK) | Fake user identifier |
| `username` | VARCHAR(100) | Placeholder username |
| `email_address` | VARCHAR(255) | Sample email (e.g. `user@demo.local`) |
| `phone_contact` | VARCHAR(20) | Fake phone number |
| `account_status` | VARCHAR(20) | `active`, `inactive`, `suspended` |
| `role_label` | VARCHAR(50) | `client`, `provider`, `admin`, `driver` |
| `created_on` | TIMESTAMP | Record creation timestamp |
| `last_login` | TIMESTAMP | Last login timestamp |

### `demo_profiles`
| Column | Type | Description |
|--------|------|-------------|
| `profile_id` | UUID (PK) | Fake profile identifier |
| `user_id` | UUID (FK → demo_users) | Reference to fake user |
| `display_name` | VARCHAR(200) | Placeholder full name |
| `avatar_url` | TEXT | Fake avatar URL |
| `bio_text` | TEXT | Sample biography |
| `rating_score` | DECIMAL(3,2) | Fake rating (1.00–5.00) |
| `total_orders` | INTEGER | Fake order count |
| `member_since` | DATE | Fake member date |

### `demo_bookings`
| Column | Type | Description |
|--------|------|-------------|
| `booking_id` | UUID (PK) | Fake booking identifier |
| `client_id` | UUID (FK → demo_users) | Fake client reference |
| `provider_id` | UUID (FK → demo_users) | Fake provider reference |
| `service_category` | VARCHAR(100) | Placeholder service name |
| `booking_status` | VARCHAR(30) | `pending`, `confirmed`, `in_progress`, `completed`, `cancelled` |
| `scheduled_date` | TIMESTAMP | Fake scheduled time |
| `location_lat` | DECIMAL(10,7) | Fake latitude |
| `location_lng` | DECIMAL(10,7) | Fake longitude |
| `price_amount` | DECIMAL(10,2) | Fake price |
| `notes` | TEXT | Sample client notes |

### `demo_payments`
| Column | Type | Description |
|--------|------|-------------|
| `payment_id` | UUID (PK) | Fake payment identifier |
| `booking_id` | UUID (FK → demo_bookings) | Fake booking reference |
| `payer_id` | UUID (FK → demo_users) | Fake client reference |
| `amount` | DECIMAL(10,2) | Fake amount |
| `currency` | VARCHAR(10) | Placeholder currency (`DEMO`) |
| `payment_method` | VARCHAR(50) | `card_demo`, `cash_demo`, `wallet_demo` |
| `transaction_ref` | VARCHAR(100) | Fake transaction reference |
| `status` | VARCHAR(30) | `demo_pending`, `demo_completed`, `demo_failed` |
| `paid_at` | TIMESTAMP | Fake payment timestamp |

### `demo_reviews`
| Column | Type | Description |
|--------|------|-------------|
| `review_id` | UUID (PK) | Fake review identifier |
| `booking_id` | UUID (FK → demo_bookings) | Fake booking reference |
| `reviewer_id` | UUID (FK → demo_users) | Fake reviewer |
| `rating` | INTEGER | 1–5 fake rating |
| `comment_text` | TEXT | Sample review comment |
| `submitted_at` | TIMESTAMP | Fake timestamp |

### `demo_services`
| Column | Type | Description |
|--------|------|-------------|
| `service_id` | UUID (PK) | Fake service identifier |
| `provider_id` | UUID (FK → demo_users) | Fake provider reference |
| `service_name` | VARCHAR(200) | Placeholder service name |
| `description` | TEXT | Sample description |
| `base_price` | DECIMAL(10,2) | Fake starting price |
| `duration_minutes` | INTEGER | Fake duration |
| `is_active` | BOOLEAN | `TRUE` for demo |

### `demo_categories`
| Column | Type | Description |
|--------|------|-------------|
| `category_id` | INTEGER (PK) | Fake category ID |
| `name_ar` | VARCHAR(100) | Arabic placeholder name |
| `name_en` | VARCHAR(100) | English placeholder name |
| `icon_url` | TEXT | Fake icon path |
| `sort_order` | INTEGER | Display order |

### `demo_notifications`
| Column | Type | Description |
|--------|------|-------------|
| `notification_id` | UUID (PK) | Fake notification identifier |
| `user_id` | UUID (FK → demo_users) | Fake recipient |
| `title` | VARCHAR(200) | Sample notification title |
| `body_text` | TEXT | Sample notification body |
| `type` | VARCHAR(50) | `demo_info`, `demo_alert`, `demo_update` |
| `is_read` | BOOLEAN | Read status |
| `created_at` | TIMESTAMP | Fake timestamp |

## Sample Queries (Demo)

```sql
-- Get fake user profile
SELECT * FROM demo_profiles WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- Get fake bookings for a user
SELECT * FROM demo_bookings WHERE client_id = '00000000-0000-0000-0000-000000000001';

-- Get fake reviews for a provider
SELECT r.*, u.display_name 
FROM demo_reviews r 
JOIN demo_users u ON r.reviewer_id = u.user_id 
WHERE r.booking_id IN (SELECT booking_id FROM demo_bookings WHERE provider_id = '...');
```

## Important Notes

1. **ALL DATA IS FAKE.** No real user information, transactions, or business
   data is used or stored.

2. **ALL FIELD NAMES ARE PLACEHOLDERS.** They do not correspond to actual
   production database columns.

3. **NO REAL CONSTRAINTS.** No foreign keys, unique constraints, or indexes
   are enforced.

4. **NO REAL TRIGGERS.** No RLS policies, triggers, or stored procedures
   are implemented.

5. **NO MIGRATIONS.** This schema is for documentation only. No actual
   database migrations are associated with it.

---

**⚠️ DEMO ONLY — Not a real database schema ⚠️**
