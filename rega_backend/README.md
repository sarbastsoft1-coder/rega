# REGA Unified Platform Backend (`rega_backend`)

Production-ready **Laravel 12 + PostgreSQL** REST API powering the entire **REGA (ڕێگا)** ecosystem in **Kalar (کەلار)**:
- **`rega_admin`** — Flutter Admin Control Center
- **`rega`** — Customer Mobile App
- **`rega_froshyar`** — Vendor / Store App
- **`rega_delivery`** — Delivery Driver App

## Database Configuration (PostgreSQL)
- **Driver**: `pgsql` (`pdo_pgsql`)
- **Host / Port**: `127.0.0.1:5432`
- **Database**: `rega_db` (Test DB: `rega_test_db`)

## Quick Start
```bash
php artisan migrate:fresh --seed
php artisan serve --host=127.0.0.1 --port=8001
```
Or double-click `start_backend.bat`.

## Seeded Demo Accounts (Password for all: `password123`)
| Role | Name | Phone | Email |
|---|---|---|---|
| Super Admin | سەربەست کەریم | `07700000001` | `admin@rega.iq` |
| Dispatcher | دیار حەسەن | `07700000002` | `ops@rega.iq` |
| Vendor (Mam Rashid) | حاجی ڕەشید ئەحمەد | `07701112233` | `mam-rashid@vendor.rega.iq` |
| Vendor (Diwan Fast Food) | کارزان سەعید | `07504448899` | `diwan-pizza-burger@vendor.rega.iq` |
| Driver (`RA-884`) | ڕەوەند کەریم | `07501234567` | `ra-884@driver.rega.iq` |
| Customer | ئاراس ڕەحمان | `07703331122` | — |

## Automated PostgreSQL Test Suite
```bash
php artisan test
```
