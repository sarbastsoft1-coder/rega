# REGA — iPhone downloadable apps (free Apple ID)

Built from Windows via **Codemagic cloud Mac** + install with **Sideloadly** (free Apple ID).

## Free Apple ID limits (important)

| | Free Apple ID | Paid Developer ($99/yr) |
|--|--|--|
| Install on your iPhone | Yes (via Sideloadly) | Yes |
| App Store / TestFlight | No | Yes |
| How long it lasts | **~7 days**, then re-sign | 1 year |
| How many devices | Few personal devices | Many |

---

## 1) Repo

`https://github.com/sarbastsoft1-coder/rega`

## 2) Codemagic cloud build

1. Open https://codemagic.io → Sign in with **GitHub**
2. Add application → `sarbastsoft1-coder/rega`
3. Workflow **iPhone IPA — Customer** (or Vendor / Delivery / Admin)
4. Set env **`REGA_API_HOST`** to a URL the iPhone can reach:
   - Same Wi‑Fi: `http://YOUR-PC-LAN-IP:8001`  
     (`php artisan serve --host=0.0.0.0 --port=8001`)
   - Or public HTTPS later  
   - Never `127.0.0.1` / `api.example.com` on a real phone
5. Start build → **Artifacts** → download **`.ipa`**

### Free Apple ID signing
- Prefer **Sideloadly** on Windows with free Apple ID
- Or Codemagic → Teams → Code signing identities

## 3) Install with Sideloadly

1. Enable **Developer Mode** on iPhone if asked  
2. Install [Sideloadly](https://sideloadly.io/) on Windows  
3. USB connect iPhone → trust computer  
4. Drag `.ipa` → enter free Apple ID → Start  
5. iPhone: Settings → General → VPN & Device Management → Trust  

Re-sign every **~7 days**.

## Bundle IDs

- Customer `iq.rega.customer`
- Vendor `iq.rega.vendor`
- Delivery `iq.rega.delivery`
- Admin `iq.rega.admin`

## Fixed in repo (code blockers)

- Customer broken `Info.plist` repaired + renamed from Xera → REGA
- HTTP App Transport Security for local/API HTTP
- Location / notification / camera / photo permission strings
- Vendor Android camera permissions
- Delivery background location mode
- iOS 15 + Podfiles with permission macros
