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

## 1) Push is done to GitHub

Repo: `https://github.com/sarbastsoft1-coder/rega`

## 2) Codemagic cloud build

1. Open https://codemagic.io → Sign in with **GitHub**
2. Add application → `sarbastsoft1-coder/rega`
3. Open workflow **iPhone IPA — Customer** (or Vendor / Delivery / Admin)
4. Set env `REGA_API_HOST` to a URL your iPhone can reach  
   (public server — **not** `127.0.0.1`)
5. Start build → download **`.ipa`** from Artifacts  
   (if unsigned, use the `.app` / ask Codemagic to sign with your Apple ID in Teams → Code signing)

### Free Apple ID on Codemagic
- In Codemagic → **Teams** → **Code signing identities** → add Apple ID (personal team)
- Or build unsigned, then sign/install with **Sideloadly** on Windows (below)

## 3) Install on iPhone with Sideloadly (Windows + free Apple ID)

1. On iPhone: Settings → enable **Developer Mode** if asked  
2. Install [Sideloadly](https://sideloadly.io/) on Windows  
3. Connect iPhone with USB cable  
4. Trust the computer on iPhone  
5. Drag the `.ipa` into Sideloadly  
6. Enter your **free Apple ID** → Start  
7. On iPhone: Settings → General → VPN & Device Management → Trust the app  

Re-install / re-sign every **~7 days** with Sideloadly.

## Bundle IDs

- Customer `iq.rega.customer`
- Vendor `iq.rega.vendor`
- Delivery `iq.rega.delivery`
- Admin `iq.rega.admin`
