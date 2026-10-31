# rega

**REGA (ڕێگا)** — Unified Multi-App Hyperlocal Delivery Marketplace Ecosystem for **Kalar (کەلار)**.

---

## Monorepo Architecture

| Directory | Stack | Role |
|---|---|---|
| [`rega/`](./rega) | Flutter | **Customer App** — Marketplace browsing, HD Kalar GPS pin picker, **1-second live street order tracker (`MM:SS` & meters)** & 4-digit delivery PIN |
| [`rega_froshyar/`](./rega_froshyar) | Flutter | **Vendor / Merchant App** — Store order queue, kitchen prep timer, handover PIN verification, menu & working hours |
| [`rega_delivery/`](./rega_delivery) | Flutter | **Driver / Captain App** — Real Kalar street navigation map (OSRM polylines, 60fps gliding motorcycle, 1s GPS telemetry sync), PIN verification & COD wallet |
| [`rega_admin/`](./rega_admin) | Flutter (Web / Desktop / Tablet) | **Admin Control Center** — Executive KPIs, **1-second Live Kalar Fleet & Order Radar**, dispatch, KYC, zones, marketing & finance |
| [`rega_backend/`](./rega_backend) | Laravel 12 + PostgreSQL + Sanctum | **Unified REST API + 1s Live Telemetry Engine** — Powers all apps (`/api/v1/public/*`, `/customer/*`, `/vendor/*`, `/driver/*`, `/admin/*`, `/live-telemetry/*`) |

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

