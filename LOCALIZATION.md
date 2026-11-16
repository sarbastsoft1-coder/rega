# REGA Localization (ku / ar / en)

All four Flutter apps support **Kurdish**, **Arabic**, and **English**.

| App | How it works | File |
|-----|----------------|------|
| Customer | `_t('...')` + `CustomerL10n` | `rega/lib/l10n/customer_l10n.dart` |
| Vendor | `t('...')` / `Trans` | `rega_froshyar/lib/main.dart` (`Trans`) |
| Delivery | `t('key')` + `_trans` map | `rega_delivery/lib/main.dart` |
| Admin | `AppStrings.tr(key, lang)` | `rega_admin/lib/core/localization/app_strings.dart` |

## Language codes (unified)

- `ku` — Kurdish (also accepts legacy `ckb`)
- `ar` — Arabic
- `en` — English

RTL for `ku` and `ar`, LTR for `en`.

## How to add a new string

1. Add the Kurdish source / key to the app’s dictionary with `ku`, `ar`, `en` values.
2. In UI use `_t('کوردی text')` (customer), `t('...')` (vendor/delivery), or `AppStrings.tr('key', lang)` (admin).
3. Do **not** leave raw `Text('کوردی...')` for user-facing copy.

## Still expanding

Product names from the backend (`name_ku` / `name_ar` / `name_en`) should keep coming from the API. UI chrome (buttons, tabs, errors, GPS messages) belongs in these dictionaries.

## Shared translator: `tx()` (all four apps)

Every app now has `lib/rega_i18n.dart` + `lib/rega_i18n_dict.dart` (identical copies).

- Every `Text(...)` / `SelectableText(...)`, plus `hintText`, `labelText`, `tooltip`, etc., goes through `tx(...)` (or `txn(...)` for nullable values).
- `tx()` turns any Kurdish/Arabic source text into the active language, so **English shows no Kurdish/Arabic** and **Arabic shows no Kurdish**:
  1. exact match in `kRegaI18n` (key = source text, value = `[ku, ar, en]`),
  2. template keys with `{placeholders}` (e.g. `داواکاری #{id}` → `Order #42`),
  3. phrase-by-phrase for interpolated strings (only when every word is covered — names stay untouched),
  4. names learned from API data: `regaJsonDecode()` remembers every `name_ku/_ar/_en` (also `title_`, `address_`, `description_`) so store / category / zone names show in the right language.
- English also converts Eastern digits (`١٢٣` → `123`) and `، ؟ ٪`.
- Each app calls `RegaI18n.setLang(code)` in its root `build`; a change rebuilds the whole tree.

**Adding UI text:** write it in Kurdish as before inside `Text('...')`, then add a row to `rega_i18n_dict.dart` in all four apps:
`'کوردی': ['کوردی', 'العربية', 'English'],`

**Finding missed text:** build with `--dart-define=REGA_I18N_AUDIT=true`, switch the app to English (or Arabic) and watch the browser/device console for `I18N-MISS[en]: ...` lines.

## Light / dark mode: `RC` (all four apps)

`lib/rega_colors.dart` (identical copy in every app) adapts inline colors to the active mode.

- Inline colors are wrapped as `RC.bg(...)` (surfaces, fills, borders) or `RC.fg(...)` (text, icons).
- Light mode returns the color unchanged. Dark mode maps white cards → `#1A2333`, page backgrounds → `#0F172A`, grey fills → `#243045`, borders → `#334155`, pale badges → deep tints of the same hue, dark text → light text. Brand/accent colors (yellow, orange, green buttons…) stay the same.
- Each app calls `RC.setDark(...)` in its root `build`; toggling rebuilds the whole tree.
- Toggles: customer (profile), delivery (profile → theme card), vendor (settings → Appearance, new), admin (moon button in the top bar).

**Adding UI:** wrap new inline colors the same way, e.g. `color: RC.bg(Colors.white)` for a card and `TextStyle(color: RC.fg(const Color(0xFF0F172A)))` for text.
