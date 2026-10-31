# REGA Admin Control Center (`rega_admin`)

Full-featured **Flutter** Admin Panel (Web, Windows Desktop, Tablet & Mobile responsive) connected live to `rega_backend` (**Laravel 12 + PostgreSQL**).

## Key Features
- **3 Languages + Dynamic RTL/LTR**: Kurdish Sorani (`کوردی` — Default RTL), Arabic (`العربية` — RTL), English (`EN` — LTR) + Light/Dark Theme toggle.
- **Executive Dashboard**: 8 real-time KPIs, interactive 7/14/30-day GMV vs. 12% Commission bar charts (`fl_chart`), Order Status Donut Chart, Live Kalar Fleet & Store Radar Map, Category Sales, Top Stores & Top Drivers.
- **Live Orders & Dispatch**: Status filtering, Dual 4-digit Security PIN inspection (`Handover PIN` & `Delivery PIN`), 1-click Driver Assignment, Admin Status Override, Waiting Bonus (`+1,000 د.ع`), and chronological Audit Trail.
- **Admin-Provisioned Store & Vendor Onboarding**: Create Store + Vendor login credentials, configure custom commission %, base delivery fee, discount badges, and toggle Online/Approved flags.
- **Menu & Products Catalog**: Full CRUD in Kurdish/Arabic/English, regular & strikethrough discount pricing in IQD, and instant availability switches.
- **Drivers & 3-Document KYC Verification**: Onboard drivers & motorcycles, inspect/verify/reject `National ID`, `Driver License`, and `Vehicle Registration`, and monitor COD cash held.
- **Kalar Neighborhoods & Marketplace Categories**: Configure delivery fees (`1,000` / `1,500` / `2,000` IQD) and ETAs across all Kalar zones.
- **Marketing Suite**: Manage Promo Coupons (`REGA5`, `KALAR20`, `FREEDEL`), Home Banners, and Broadcast Notifications.
- **Finance, Commissions & COD Reconciliation**: Settle Vendor wallets, pay Drivers, and record COD cash collections from Drivers.
- **Support Tickets & PostgreSQL JSONB Settings**: Resolve urgent driver/customer tickets and configure global platform rules.

## Run
```bash
flutter run -d chrome
# or
flutter run -d windows
```
Default Admin Login: **`07700000001`** / **`password123`** (API Base URL: `http://127.0.0.1:8001/api/v1`).
