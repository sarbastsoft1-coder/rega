# rega

**REGA (ڕێگا)** — Unified Multi-App Hyperlocal Delivery Marketplace Ecosystem for **Kalar (کەلار)**, 100% live-connected to **Laravel 12 + PostgreSQL**.

---

## Monorepo Architecture (All 5 Parts Connected Live)

| Directory | Live Local Port | Stack | Role |
|---|---|---|---|
| [`rega_backend/`](./rega_backend) | `http://127.0.0.1:8001` | Laravel 12 + PostgreSQL + Sanctum | **Unified REST API + 1s Live Telemetry Engine** — Powers all 4 Flutter apps (`/api/v1/public/*`, `/customer/*`, `/vendor/*`, `/driver/*`, `/admin/*`, `/live-telemetry/*`) |
| [`rega_admin/`](./rega_admin) | `http://127.0.0.1:8080` | Flutter (Web / Desktop / Tablet) | **Admin Control Center** — Features **3 Core Dedicated Ecosystem Parts (`Vendor Hub`, `Customer Hub`, `Delivery Hub`)**, Executive KPIs, 1-second Live Kalar Radar, KYC, Zones, Marketing & Finance |
| [`rega_froshyar/`](./rega_froshyar) | `http://127.0.0.1:8081` | Flutter | **Vendor / Merchant App** — Live PostgreSQL store sync, kitchen order queue, 4s new-order alert polling, 4-digit handover PIN verification & menu CRUD |
| [`rega/`](./rega) | `http://127.0.0.1:8082` | Flutter | **Customer App** — Live Kalar stores/menus/zones bootstrap, real PostgreSQL order checkout, 1-second live street order tracker (`MM:SS` & meters) & 4-digit delivery PIN |
| [`rega_delivery/`](./rega_delivery) | `http://127.0.0.1:8083` | Flutter | **Driver / Captain App** — Live driver profile, online toggle, assigned order sync, handover & delivery PIN verification, live earnings ledger & 1s GPS telemetry map |

---

## Admin Control Center — 3 Dedicated Core Parts (`rega_admin`)

1. **بەشی فرۆشیار — Vendor Hub (`lib/screens/vendor_part_screen.dart`)**
   - Store gross sales, platform commissions & net vendor profit KPIs, live kitchen order queue + 4-digit driver handover PIN verification, store onboarding/accounts, product/menu management, and vendor wallet payouts.
2. **بەشی کڕیار — Customer Hub (`lib/screens/customer_part_screen.dart`)**
   - VIP customer spend & saved GPS address inspector, live Admin-to-Customer order creator + 4-digit customer delivery PIN verification, customer account controls, Kalar delivery zones & categories, and coupons/banners.
3. **بەشی گەیاندن — Delivery Hub (`lib/screens/delivery_part_screen.dart`)**
   - Embedded 1-second live Kalar `FlutterMap` fleet radar + instant driver dispatch queue, captain onboarding & 3-document KYC verification, delivery status audit, and COD cash-in-hand collection & driver payouts.

---

## Quick Start

### One-Click Full Ecosystem Launch (Windows PowerShell)
```powershell
.\run_all_rega.ps1
```

### Manual Backend Setup (`rega_backend` — Laravel 12 + PostgreSQL)

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

### Default Seeded Accounts (Password: `password123`)

- **Super Admin**: `07700000001` / `admin@rega.iq`
- **Vendor (کەبابی مام ڕەشید)**: `07701112233`
- **Driver (ڕەوەند کەریم — RA-884)**: `07501234567`
- **Customer (ئاراس ڕەحمان)**: `07703331122`
