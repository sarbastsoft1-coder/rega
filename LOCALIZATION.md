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
