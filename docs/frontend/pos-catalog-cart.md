# Flutter Phase 4 — POS Catalog & Cart

The `/pos` destination now reads the frozen Laravel catalog and builds an in-memory order preview. Only staff with `process-pos` can mount it; the server still authorizes every request. Dashboard and catalog management destinations retain their existing placeholders. No order or payment is created.

## Architecture and lifetime

| Boundary | Responsibility |
| --- | --- |
| `features/pos/domain/catalog.dart` | Plain Dart category/product values and numeric page metadata |
| `features/pos/domain/cart.dart` | Exact totals, stable insertion order, unique product lines and bounded quantities |
| `features/pos/domain/catalog_repository.dart` | Catalog read contract and controlled failures without HTTP/Flutter imports |
| `features/pos/data/catalog_dto.dart` | Strict Resource/envelope decoding; malformed identity, money, currency, category and pagination fail closed |
| `features/pos/data/api_catalog_repository.dart` | Authenticated, bounded active-catalog GET requests using the existing `ApiClient` |
| `features/pos/presentation/pos_controller.dart` | Independent category/product state, debounce, request generations, pagination and cart notifications |
| `features/pos/presentation/pos_page.dart` | Responsive catalog, search, filters, retry and compact cart affordance |
| `features/pos/presentation/pos_product_card.dart` | Operational name/category/price/add card; presentation-only café glyph |
| `features/pos/presentation/pos_cart_panel.dart` | Order lines, explicit removal, confirmed clear, quantity controls and exact subtotal |
| `app.dart` | One HTTP client shared with auth; one POS controller per authenticated session, independently of shell layout/routes/theme |

The app owns and disposes POS state. Navigating away and back, resizing, changing theme, filtering, searching, pagination and catalog failures preserve the cart. Logout/session invalidation disposes that session's POS controller and dismisses its modal routes. Staff sessions never share a cart.

The cart has **no persistence**: application restart or browser reload loses it. No storage, cache, state-management, networking or UI dependency was added. `go_router` remains installed but this phase preserves the Phase 3 routing approach.

## Frozen API usage

Base URL comes from public `AppConfig.apiBaseUrl`; paths are relative to `/api/v1`.

| Request | Query |
| --- | --- |
| `GET /categories` | `page`, `per_page=50`; default active categories |
| `GET /products` | `page`, `per_page=25`, optional `category_id`, optional `search`; default sellable products |

There is no `status=all`, `status=inactive`, custom sorting, inventory availability request or catalog mutation. Product/category Resources, Requests, policies, controllers, tests and OpenAPI were inspected before implementation. Required fields are not replaced with empty strings or zero. Nullable Resource timestamps/descriptions must still have the correct shape.

The parser validates `data`, page bounds, page size, total/last-page consistency, `from`/`to` and navigation links. Duplicate identities within one response and unexpected retired/non-sellable entries are invalid responses. Across pages, the controller merges by ID, preserving first-seen order and applying the latest returned value. Concurrent catalog edits can shift offset pages; refresh starts a fresh first page. Request URLs are built locally with `Uri.replace(queryParameters: ...)`; server-supplied pagination URLs are validated but **never followed**, so a Bearer token is not forwarded to an arbitrary link.

Numeric IDs above Dart web's exact integer range (`2^53 - 1`) are rejected rather than rounded. This is an explicit client representability boundary; the Laravel int64 schema is unchanged.

## Search, filtering and pagination

Search matches backend-defined name/SKU substrings. Input is bounded to 80 Unicode code points, normalized with whitespace trimming and debounced for 300ms using `dart:async` `Timer`. `"0"` remains a valid search. No search values or headers are logged.

Typing invalidates the product request generation immediately, before debounce fires. Category selection, first-page reload and load-more use the same generation boundary. Late results/errors cannot replace a newer query; a same-session 401 still proves that token unusable. Disposal cancels timers and ignores late responses.

Categories scroll horizontally with selected checkmark and native selected semantics. “More categories” loads one page at a time, so categories beyond the first 50 remain reachable. The selected category stays identifiable if a refreshed first page omits it.

“Load more products” performs one bounded next-page request. Duplicate in-flight calls are prevented. Search/filter/refresh reset pagination. A failed next page retains cards, cart and the last successful page pointer; Retry requests that same next page. The API's maximum page of 10000 is honored. Product/category errors and retries are independent.

`CatalogPhase` distinguishes initial, loading, ready, empty, refreshing, loading-more and error. Background requests retain usable content with progress feedback. After an error, retained cards are labeled as previously loaded products. Empty shop, empty category and empty search have specific copy; they are distinct from transport or parsing failures.

## Cart and money

- Products merge by `product_id`; insertion order is deterministic.
- At most 50 distinct lines; each quantity is an integer from 1 through 99.
- Adding/incrementing at 99 or adding a 51st product returns an explicit limit with accessible feedback.
- Decrement at one is disabled; Remove is the explicit deletion action. Clear cart requires confirmation.
- Unit price, line subtotal, subtotal and total use integer USD cents. `subtotal == total`; no tax, discount, conversion or rounding exists.
- `price_minor` must be the canonical string `"0"` through `"999999"`; JSON numbers, fractions, signs, whitespace, leading zeros, scientific notation and oversized values are rejected.
- Existing `Formatters.formatCents` renders every price. The maximum allowed cart is 4,949,995,050 cents, exactly representable on native and web targets.

Returned catalog products refresh the corresponding cart's name/price previews while preserving quantities/order. Lines absent from a result page remain unchanged: absence in a filtered page is not proof of retirement. A current returned product's price also applies when adding it again. The client never claims to lock prices or prove availability. Changes to previews are announced through the live subtotal; Phase 5 must re-read prices and sellability and revalidate all lines on the backend.

## Responsive POS and accessibility

The existing app sidebar/bottom navigation remains the only application navigation. POS measures its **allocated content width**, after the sidebar, with `LayoutBuilder`.

At sufficient width (existing 900dp expanded token, adjusted for text scale), a flexible catalog sits beside a persistent 360dp Current Order panel. Smaller allocations, including tablet portrait, show a responsive grid and persistent item-count/subtotal/View cart control above bottom navigation. The cart opens in a safe-area modal sheet with a close button and independently scrollable lines. Product rows are lazily built, with natural text height rather than fixed card height. Narrow normal-text layouts support two cards where they fit; large text reduces column count.

The screen reuses `AppTheme`, `CafeThemeExtension`, spacing/radius/typography tokens, formatter, empty states and loading indicator. Colors adapt to light/dark themes. All POS action targets meet 48dp, including icon controls. Category selection uses a checkmark/selected semantics; quantity and limit states include text. Product semantics announce name, USD price, category, action and cart quantity. Search has a label; quantity/remove/close controls have meaningful tooltips. Native controls provide keyboard traversal/focus feedback and Enter activation; meaningful cart totals are live regions. No decorative animation is added.

Khmer catalog names reuse the existing fallback typography without invented translations or letter-spacing transforms. Font bundling/localization is not redesigned. Widget samples cover mixed Khmer/English at 2× text; these checks do not replace fluent-speaker or TalkBack/VoiceOver review.

## Session and security semantics

| Failure | Behavior |
| --- | --- |
| 401 | `AuthController.invalidateSession(token: ...)` immediately fails authentication closed, clears invalid token storage, disposes the cart and returns to login |
| 403 | Access-denied feature error; session/cart remain intact |
| 422 | Rejected-query message with filter/retry guidance |
| 429 | Wait-and-retry message |
| 5xx | Catalog service unavailable; retry |
| Network/timeout | Connection guidance; cart retained |
| Invalid response | Safe decoding failure; no financial defaults or raw exception details |

Invalidation compares the token that issued the request with the current session: a previous session's late 401 cannot log out a newly signed-in staff member. New login waits for old-session storage deletion to finish, preventing deletion of fresh credentials. No additional logout request is sent for a token already proved invalid.

Backend authorization, exact prices and future checkout/payment outcomes remain authoritative. No token, password, raw secure-storage value or provider secret is logged or displayed. Browser test fixtures contain synthetic data only. Laravel/schema/permissions/checkout semantics and dependency locks remain unchanged.

## Verification and review (2026-10-07, Asia/Bangkok)

Installed SDK matches CI: Flutter 3.44.6 / Dart 3.12.2. Locked package versions inspected: http 1.6.0, flutter_secure_storage 9.2.4, go_router 18.0.2. Architecture choices follow the current project first, then official [Flutter architecture guidance](https://docs.flutter.dev/app-architecture/guide), [Dart URI query APIs](https://api.dart.dev/dart-core/Uri/replace.html), [Timer cancellation](https://api.dart.dev/dart-async/Timer-class.html) and the [locked http package documentation](https://pub.dev/packages/http/versions/1.6.0). No new dependency is justified.

| Gate | Evidence |
| --- | --- |
| Locked dependency install | `flutter pub get --enforce-lockfile` passed; manifests/lock unchanged |
| Formatting and analysis | Dart formatting check passed; `flutter analyze` reports no issues |
| Flutter tests | 265 tests passed, including existing auth/shell tests and new domain/data/controller/widget/session regressions |
| Web | `flutter build web --no-pub` passed (JavaScript target) |
| Android | `flutter build apk --debug` passed; development artifact only |
| Backend | `php artisan test`: 378 passed, 2342 assertions, 73 SQLite skips |
| Browser | Chromium via existing cached Playwright CLI: synthetic cashier sign-in, real production UI, search/filter, repeated add, quantities/remove/clear, desktop/mobile resize and light/dark visual inspection |
| Local MySQL | Not repeated: backend/schema unchanged; required isolated migrations/MySQL suite remain in GitHub Actions |
| GitHub Actions | Publication gate requires the new commit's CI run to finish successfully; report its run ID/conclusion after push |

Tests include strict DTO/money/identity/currency/category failures, both GET query/header contracts, Laravel pagination, 401/403/422/429/5xx/network/timeout/invalid payloads, 99/50 limits, exact maximum-cart arithmetic, first-load/retry/independent errors, debounce, out-of-order search/filter/pagination, duplicate requests, late disposal, updated previews and auth/session cleanup races. Widget viewports: 320×720, 375×812, 390×844, 768×1024, 1024×768, 1440×900 and 844×390, with both themes and 2× text/reduced-motion media settings; keyboard activation and measured 48dp controls are verified.

The 11 canonical `.agent` skills were read and applied by boundary. Evidence review covered money, strict parsing, request races, pagination, cart lifetime/limits, session semantics, token transport, permission guards, accessibility, themes, scope and CI/Git preservation. Review fixed 40dp Material icon targets, exact full-string money/SKU matching, selected-category visibility after first-page refresh and labels for retained results after failures. Laravel/MySQL act as frozen-contract reviewers; no backend changes or speculative features were introduced.

Screenshots and browser fixtures live in ignored `output/playwright/`; test/build logs live in ignored app output directories. Web build emits existing secure-storage plugin WebAssembly dry-run and Cupertino font warnings; the JavaScript target succeeds. APK build emits existing Java 8 source/target deprecation warnings. No emulator/device or iOS/Xcode run, real credential login, live Laravel/browser end-to-end run, assistive-technology conformance audit or fluent Khmer review is claimed.

## Intentional limits and Phase 5 handoff

No checkout button, `POST /orders`, idempotency key, payment/KHQR/Bakong, receipt, stock reservation/availability badge, product media, catalog CRUD, offline persistence or speculative options/customer features exist in this phase. Product glyphs are presentation only and never imply media supplied by the API.

Phase 5 — Checkout & Payment Flow must turn cart IDs/quantities into the frozen `items: [{product_id, quantity}]` request, establish the real idempotency/retry lifecycle, revalidate all products/prices/stock through the backend and implement the separately authorized payment workflow. A preview subtotal or locally displayed status is never payment evidence. Do not begin that milestone automatically.
