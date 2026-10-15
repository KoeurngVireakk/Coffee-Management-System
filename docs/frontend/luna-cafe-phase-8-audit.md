# Luna Cafe Phase 8 audit and review gates

Audited 2026-10-15. Scope: the existing Flutter Android/iOS phone and tablet app. The supplied Phase 8 master prompt supersedes the older branding brief's web scope. No backend contracts, catalog records, settlement logic or database changes are authorized here.

## Repository and fresh baseline

- Branch `main`, commit `7420e04652da58cf2157ecb9eae63b52be941721`.
- Before brand implementation, tracked working tree and staging were clean. The only untracked path was this task's isolated `apps/mobile/tool/luna_audit_preview.dart` fixture entrypoint.
- Flutter 3.44.6 / Dart 3.12.2; installed direct dependencies: `http 1.6.0`, `flutter_secure_storage 9.2.4`, `go_router 18.0.2` (not used for current shell routing), `flutter_lints 6.0.0` and SDK `flutter_test`. No SVG, charts, animation or network font dependency is needed for 8A.
- `flutter test --reporter compact`: **600 passed**. `flutter analyze`: **no issues**. `dart format --output=none --set-exit-if-changed .`: **132 files, zero changed**.
- `flutter build apk --debug --no-pub`: **passed**, 24 seconds; Android SDK XML v4/v3 tool-version warning.
- Backend PHPUnit: **453 tests, 2347 assertions, 73 skipped** (380 passed), isolated SQLite memory configuration. No developer MySQL changes.
- Existing web compatibility build passed before the updated mobile-only brief; existing Wasm-incompatible secure-storage imports and missing Cupertino font warning remain. This is not evidence of native mobile behavior. Supplied GitHub Actions run 38606749147 was independently confirmed completed/success for the baseline commit during publication preparation.

## Confirmed implementation

`lib/app.dart` composes token-bound controllers and closes session-owned navigation on session change. `features/shell/presentation/adaptive_app_shell.dart` uses a local current-path switch and compact bottom navigation below 600dp, with a 280dp sidebar above that width. POS, cart, checkout/cash/uncertain external payments, order history and inventory/recipes are implemented. `features/reports/{domain,data,presentation}` contains skeletons only. Dashboard/Home, product administration, reports, staff and settings are placeholders.

The current shell permits cashiers to select Dashboard/Home placeholders and bases manager landing on role rather than `view-reports`. This must be closed with negative route and lifecycle tests in 8B before any real report data is attached. Backend authorization already enforces `view-reports`; hiding a tab alone is insufficient.

Existing `AppColors`, `AppTheme`, `CafeThemeExtension`, `AppTypography`, `AppMotion` and shared widgets are the integration points. Font fallback names currently reference Inter and Noto Sans Khmer without bundling them. Monetary typography uses tabular figures. Native application labels and launcher/splash images still use the generic project identity.

## Frozen reports contract (code takes precedence over illustrative specification)

Confirmed in `apps/backend/routes/api.php`, `app/Http/Controllers/Api/V1/ReportController.php`, `app/Services/ReportService.php`, `app/DTOs/ReportPeriod.php` and `app/Http/Requests/Reports/*`.

All URLs begin `/api/v1/reports/`; middleware requires authenticated active staff, the staff token ability and `can:view-reports`. Requests also check current granted permission. Controllers return JSON directly, not API Resource classes.

| GET endpoint | Actual response and parameters |
| --- | --- |
| `overview` | `data`: `period`, `revenue_minor` **integer string**, `currency: USD`, `paid_orders` integer, `average_order_value_minor` **integer string**, `low_stock_items` integer, `reconciliation_required` integer. Revenue uses accepted paid orders and `paid_at`; average uses integer division. Stock and reconciliation counts are current, not period-limited. |
| `sales-trend` | Top-level `period` and `data` array: `date`, `revenue_minor` integer string, `paid_orders` integer. Continuous zero-filled shop-local days. |
| `payment-methods` | Top-level `period`, `currency`, `data`: `method`, `paid_orders`, `amount_minor` integer string. No label, percentage or `share_percentage`; no implication that KHQR is live. |
| `top-products` | Same envelope; rows: `product_id`, `sku`, `name`, `quantity_sold`, `revenue_minor` integer string. No category or unit price. `limit` defaults to **10**, allowed **1–50**. |
| `reconciliation` | **No date parameters allowed.** `page`, `per_page` (default 25, max 100). `summary` contains `reconciliation_required_count`, `unresolved_attempts_count`; `meta` contains current/last page, per-page, total. Rows identify payment ID, order ID/reference, method/status, expected/tender/change integer strings, currency, reconciliation flag/reason and timestamps. Order detail links must use valid public order references. |

The first four accept paired `from_date`/`to_date` in `Y-m-d`, ordered, at most 366 days apart; unknown fields are rejected. Omitting both uses the last 30 shop-local calendar days. `period.timezone` is authoritative, not `shop_timezone` in the response. Missing/invalid configured timezone produces 409. Bounds are half-open UTC intervals. Today/7/30 presets therefore need an authoritative initial period before deriving dates; never use the device timezone as a substitute.

The manager specification's example JSON, gross-sales labels, KHQR labels, product fields and max-100 limit are not authoritative. 8B will update that document to the verified contract without changing Laravel.

## Brand assets and measured risks

Primary direction: `design/luna-cafe/reference/approved_reference.jpg`. Supporting boards 01–09 are concepts; board 10 supplies visual language only. No board, illustrative menu price or mock report figure belongs in the runtime bundle.

The initial audit found no editable artwork in the reference boards. The owner subsequently supplied and explicitly selected `design/Luna_Cafe_Vector_Logo_Kit`. Current 8A uses that kit's SVG-authored PNG equivalents without redrawing geometry; the earlier candidate is removed. See the [supplied-kit application comparison](../../design/luna-cafe/artwork/supplied-kit/REVIEW.md). Source kit files remain untouched.

Contrast: coffee `#2B1B0F` on cream `#F8F3EA` is 15.00:1; antique gold `#C9A96A` on cream is only 2.03:1. Use gold decoratively; foreground gold `#806127` is 5.20:1 on cream. Existing success/error/warning/info values and exact numeric formatting are preserved. Local Inter/Noto Sans Khmer replace unbundled UI font assumptions; the supplied outlined wordmark needs no Playfair or other branding font.

Other risks: fixed tablet sidebar density at 600–768dp; repeating skeleton animation does not currently respect reduced motion; nested button semantics and unbound external field labels need focused accessibility review; production payment provider remains disabled. Windows cannot build iOS. Emulator/device frame-time, TalkBack/VoiceOver and real-device memory evidence must be reported separately from widget and screenshot checks.

## Execution and review gates

1. **8A authorized:** limited shared palette/type, login/shell identity, owner-selected kit integration, mobile icons/splash, local UI fonts/licenses and source guide. Preserve controllers, API seams, money, inventory precision and permission behavior. Independently verify full tests/build and provide native phone/tablet fixtures clearly marked as synthetic.
2. **8B pending review:** review the completed 8A result, then build strict reports domain/data/controller/presentation with secure navigation, authoritative dates, partial/error states and lifecycle tests. The owner has already selected the supplied logo geometry; do not request that selection again.
3. **8C pending review:** selective native motion/accessibility/performance fixes after dashboard review; no dependency shopping list or wholesale rewrite.

No commit, push, deployment or external-service mutation is included. Phase 9 should be selected from the remaining staff/product administration and settings backlog after 8B/8C, rather than assuming those screens already work.
