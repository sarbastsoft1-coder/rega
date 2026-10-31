# rega

**REGA (ڕێگا)** — Unified Multi-App Hyperlocal Delivery Marketplace Ecosystem for **Kalar (کەلار)**.

---

## Monorepo Architecture

| Directory | Stack | Role |
|---|---|---|
| [`rega/`](./rega) | Flutter | **Customer App** — Marketplace browsing, search, cart, coupons, checkout, live order tracking & delivery PIN |
| [`rega_froshyar/`](./rega_froshyar) | Flutter | **Vendor / Merchant App** — Store order queue, kitchen prep timer, handover PIN verification, menu & working hours |
| [`rega_delivery/`](./rega_delivery) | Flutter | **Driver / Captain App** — Dispatch radar, route stages, handover & delivery PIN verification, COD wallet & KYC |
| [`rega_admin/`](./rega_admin) | Flutter (Web / Desktop / Tablet) | **Admin Control Center** — Executive KPIs, live dispatch, store/driver provisioning, KYC, zones, marketing, finance & settings |
| [`rega_backend/`](./rega_backend) | Laravel 12 + PostgreSQL + Sanctum | **Unified REST API Backend** — Powers all 4 apps (`/api/v1/public/*`, `/customer/*`, `/vendor/*`, `/driver/*`, `/admin/*`) |

---

## Quick Start

### 1. Backend (`rega_backend` — Laravel 12 + PostgreSQL)

```bash
cd rega_backend
cp .env.example .env
composer install
php artisan key:generate
# Ensure PostgreSQL database `rega_db` exists (127.0.0.1:5432)
php artisan migrate:fresh --seed
php artisan serve --host=127.0.0.1 --port=8001
```

Run backend automated tests (PostgreSQL `rega_test_db`):
```bash
php artisan test
```

### 2. Admin Control Center (`rega_admin` — Flutter)

```bash
cd rega_admin
flutter pub get
flutter run -d chrome
# or on Windows Desktop:
flutter run -d windows
```

### Default Seeded Accounts (Password: `password123`)

- **Super Admin**: `07700000001` / `admin@rega.iq`
- **Vendor (کەبابخانەی کەلار)**: `07701112233`
- **Driver (کاروان محەمەد)**: `07702001001`
- **Customer (سەربەست عەلی)**: `07703001001`

