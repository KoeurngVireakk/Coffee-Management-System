# Luna Cafe mobile UX rescue — Phase 8B.0 audit and blueprint

2026-10-15, before implementation. Authorized scope: **8B.0 audit and 8B.1 POS vertical slice**. Login/shell-wide propagation, dashboard authorization repair and real analytics remain behind the prompt's 8B.2/feature review gates. Supplied logo geometry and runtime assets are fixed inputs.

## Verified baseline and evidence

`main` at `9d09c3c3e5485acf8f75375a7eabb13203742c14`; staging/tracked files clean; only the owner's new `docs/prompts/` is untracked. GitHub Actions [38660023532](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/38660023532) completed successfully, both jobs passed. Fresh local `flutter test --reporter expanded`: **622 passed**; `flutter analyze`: **no issues**; `dart format --output=none --set-exit-if-changed .`: **136 files, zero changes**. No connected Android device at audit time; emulator feasibility will be checked. Earlier APK/backend results are historical, not results for this slice.

Reviewed root/architecture docs, Phase 8A audit/verification/assets, design system, roadmap and manager specification; actual app composition, shell/destinations, POS/controller/domain/repositories, checkout, order/inventory cards, tests and capture harness. Reviewed the original approved reference, supplied kit/guide, all nine 8A captures and boards 01–10. Boards supply warm material restraint, hierarchy and edge ornament inspiration. Their menu prices, photos, dashboard numbers, web composition, tax/service charge and payment-provider visuals are not production requirements.

## Screen critique and roots

| Screen/evidence | Observation and code root | Priority/action |
| --- | --- | --- |
| `phase-8a/pos-phone-light.png` | First products start around y348; tall category-icon blocks, 18px product names, repeated cup artwork, 24px prices and a separate add row compete. `PosProductCard` makes every product visually alike. Marketing subtitle and vertical gaps push browsing down. | P1: shorten the operational header, category treatment and card; separate name, exact price and one add affordance. Keep whole tile tappable. |
| `pos-phone-2x.png` | The header wraps its refresh below the title; long search decoration and large cart Wrap consume most of the screen. Product controls already scroll together, but the initial composition is inefficient. | P1: one flexible header row, short visible search hint with full accessible name, no subtitle; 2× single-column cards with natural text wrapping and a smaller bottom review action. |
| `pos-tablet-dark.png` | 280dp shell sidebar leaves 744dp for POS, below the current **900 × text scale** split threshold; cart is a bottom action despite landscape width. Generic green product icons dominate coffee/cream identity. | P1: choose split from allocated POS width, 720dp at normal scale; reserve 304dp cart and a usable catalog. Keep the controller across reflows. At 2× or narrower tablet allocation use a review sheet; compact shell rail belongs to 8B.2. |
| `pos-phone-error.png` | Identical categories/products server failures render two large red blocks, each with Retry. This comes from independent API state rendered independently. | P1: coalesce only equal failure kinds, retaining both retry paths (including pagination); keep distinct failures and previous valid products visible. |
| `pos-phone-empty.png` | Large void, two separate empty messages, generic icon; empty cart action remains available. | P2: concise, recoverable empty/search/category feedback on the same scroll surface; keep cart accessible and distinguish no-data from errors. |
| Four login captures (390 light, 360 dark, 768 tablet, 360 at 2×) | Logo artwork is correct. Large dark lockup dominates; 2× fields/CTA require scrolling. Form accessibility has external label and button-semantic debt. | 8B.2: compact identity/header, field-label binding and focus/keyboard audit after POS direction approval. Do not edit approved logo. |
| Cart/draft review | **Not in the nine 8A captures. Source inspected.** Nested outlined item containers/dividers, mixed numeric/body styling, tall header/summary, explanatory implementation copy. Short-screen scrolling is conditional on a checkout controller. | In slice: cleaner item rhythm, explicit unit/line amounts, 48dp stepper, pinned subtotal/56dp checkout where height permits; scroll the full review at large type/short height. Preserve clear confirmation, limits, checkout locks and APIs. Add fresh draft-cart captures using read-only fixtures; do not imply an earlier captured cart baseline exists. |
| Checkout/payment | **Not captured in the supplied nine. Source/tests inspected.** Explicit pending/cash/uncertain states and keyed retry controls are vital; visual simplification cannot blur these states. | Regression only in 8B.1; leave `CheckoutPanel`/controllers unchanged. Fixture harness rejects writes, so do not mislabel its denial as a real checkout screenshot. |
| Orders/history | **Not captured in the nine. Source/tests inspected.** Rich status/date/total cards and recovery sections can create density; semantic order labels and status distinctions exist. | 8B.2 after review, no order recovery/state changes. |
| Inventory | **Not captured in the nine. Source/tests inspected.** Exact balances and operation controls exist; wrapped headers and hard-coded low-stock accents warrant later review. | 8B.2 after review; keep fixed-point math and readonly cashier operations intact. |
| Navigation | Cashier Home/Dashboard placeholders and role-only manager default remain confirmed from `app_destinations.dart` and shell path resolution. | Separate 8B.2 negative-route/session-downgrade tests before reports are connected. No unauthorized reports exist in this slice; backend already enforces `view-reports`. |

Priority ranking: **P1 browsing speed and recovery**, **P1 exact money/checkout regression protection**, **P2 hierarchy and brand coherence**, **P2 accessible input/motion**. No user study, fluent Khmer review or device frame-time audit is claimed.

## One concrete blueprint

Phone 390×844 / compact 360×800 (light cream/espresso; dark coffee/ivory):

```text
existing Luna Cafe shell / role                       (unchanged)
┌ Point of Sale                           refresh 48 ┐
│ Search menu (name / SKU semantics; 48dp controls)  │
│ [All] [Coffee] [Tea] [Bakery] → horizontal filters  │
│ one contextual failure + retry, only when needed   │
│ ┌ coffee glyph + category ┐ ┌ category + qty ┐     │
│ │ Cappuccino             │ │ Iced Americano│     │
│ │ exact $3.25         (+) │ │ $2.50      (+)│     │
│ └────────────────────────┘ └───────────────┘     │
│ next rows / pagination (all one lazy scroll)       │
├ View cart · items              exact total USD →  ┤
└ existing bottom navigation / safe area             ┘
```

The example values above are the **existing audit fixture**, never new catalog data. At 2×, use one full-width product per row, retain full names/prices, scroll controls out of the way and allow the summary to use two concise lines. No fixed-height price clipping, operational-text shrink or disabled text scaling. Review-sheet form/quantity controls scroll safely with keyboard insets.

Tablet 1024×768 (existing sidebar untouched):

```text
┌ existing 280dp sidebar ┐┌ catalog ~439dp ┐┌ cart 304dp ┐
│ supplied brand / user ││ slim controls ││ Current Order│
│ existing destinations ││ two columns   ││ item / each  │
│                       ││ category/name ││ – qty + / sum│
│                       ││ price / add   ││ ... scroll   │
│                       ││ ... lazy rows ││ subtotal USD │
│                       ││ retry/loadmore││ Checkout 56  │
└───────────────────────┘└───────────────┘└──────────────┘
```

The 768px portrait allocation remains a catalog plus compact review sheet because the unchanged sidebar leaves 488dp. At enlarged text a split is not forced. State survives every branch; `build` sends no requests. Tablet cart remains a POS panel, not a web/dashboard layout.

## Components, tokens and states

| Reuse/extension | Contract |
| --- | --- |
| Existing `PosController`, cart/domain/API seams | Unchanged identities and behavior. Integer USD cents and fixed-point inventory remain authoritative; stable idempotency and session lifecycle stay intact. |
| `PosProductCard` | Category icon and real label, 16px/1.45 semibold full name, 20px tabular price, compact 48dp plus treatment; entire tile is one native InkWell/semantic action. Unknown categories get neutral local icon. Icons are decorative beside text. |
| `PosPage` | Existing sliver/lazy rows, search debounce/80-rune limit, categories/pagination preserved. A dedicated compact summary allocates space instead of overlaying the catalog. |
| `PosCartPanel` | Existing callbacks/clear dialog/CheckoutPanel boundary, 48dp native quantity/remove/close controls; flatter lines, clear exact subtotal and 56dp checkout. |
| `AppColors`/theme extension | No palette replacement: cream/coffee surfaces, foreground-safe gold accent; semantic success/error/warning/info preserved. Selected catalog/cart is brand primary/container, not payment-success green. |
| `AppSpacing`/`AppRadius`/`AppShadows` | 16dp screen padding, 12dp card gaps/padding, 8dp internal gaps, 12–16dp radii; light shadows only for structure, not every nested surface. |
| `AppTypography` | Existing local Inter/Noto Khmer, safe name line heights, tabular prices; no uppercase Khmer, remote fonts or new serif download. |
| `AppMotion` | Native 150–180ms color/count transitions, stable layout bounds; immediate final state with `disableAnimations` **or** `accessibleNavigation`. No animation of amounts/payment confirmation. |
| Loading/refresh | Static card placeholders with an accessible loading message; no continuous shimmer/glow. Retain previous products during refresh with clear progress. Avoid using the currently repeating global skeleton until it is independently fixed. |
| Empty/error/forbidden | Real existing failure messages, one combined identical notice with both retry paths, distinct failures separate, preserved cart and previously loaded data. No fake successful payment or invented offline data. |

API imagery inspection: `ProductResource`, mobile DTO and `CatalogProduct` have **no media URL**. Use existing Material glyphs (coffee/tea/bakery; neutral fallback), not product photography or unapproved assets. Future approved imagery needs an explicit backend media contract, source/license, fail-safe text and bounded caching. It is not added here.

## Dependency decision and accessibility gate

**Zero new packages.** Flutter 3.44.6/Dart 3.12.2 already supports native implicit animation, Material input/focus/semantics and slivers. Existing `http 1.6.0`, `flutter_secure_storage 9.2.4`, `go_router 18.0.2`, local OFL fonts and supplied art are retained. No package/transitive/build-size addition is justified.

Rejected/deferred: `flutter_animate` (two native transitions suffice), `flutter_svg` (approved PNGs already verified), `skeletonizer` (simple static product placeholders suffice), `fl_chart` (dashboard not yet authorized), Lottie/Rive/3D/shaders (no approved motion asset), `flex_color_scheme` (existing theme fits, no SDK upgrade), new DI/router/state stack and random drink photos. UI/UX Pro Max's first dense-layout stack query returned no match; its narrower adaptive-layout query verified LayoutBuilder/Row/Column guidance. Reduced-motion guidance fits the task; native architecture and measured captures take precedence over generic recommendations.

Verify actual foreground/background pairs ≥4.5:1 for normal text, meaningful control/focus boundaries ≥3:1, 48dp controls and 56dp checkout. Test keyboard Tab/Enter, single add action/semantic name, current count announcements, disabled/locked states, 2× English/Khmer mixed labels, 360px widths and keyboard/safe-area insets. Widget tests do not establish TalkBack/VoiceOver conformance or fluent Khmer correctness.

## Success criteria, risk and rollback

- At 390×844, show two complete typical product rows before the cart summary; first products noticeably above the old y348 position. At 360×800/2×, make a full product/price reachable by scrolling without hiding navigation/cart.
- At 1024×768/1×, show catalog and draft cart together despite the existing sidebar; at 768 portrait/2× maintain a safe review sheet.
- Identical two-stream outage: exactly one message/retry; distinct/pagination failures remain recoverable, with no dropped cart or extra order.
- Category glyphs differ when existing API category labels are recognized; unknown labels remain correct text with neutral art. Never claim photos exist.
- Capture baseline/target light/dark/data/empty/error, 390, 360, 768 and 1024 layouts with native bundled fonts. Preserve all original captures; add a new `phase-8b1` directory and comparison document. Cart captures are new evidence, not part of the supplied baseline nine.
- Add negative/interaction/motion/layout tests; retain all 622 original tests. Run format/analyze/full tests/debug APK and backend regression if integration wiring warrants it. Check source/asset hashes and diff; no commit/push without new approval.

Risk: slimmer cards may reduce add affordance or obscure long names; verify full text, exact maximum-price formatting and hit targets. Lower tablet split threshold may squeeze checkout; test persistent/review-sheet reflow and active-order locks. Combined notices must not conflate different failures or lose next-page retries. Motion must not delay authoritative totals or create duplicate accessible actions. Keep reusable changes limited to the motion preference helper; preserve older screens.

Rollback is by the reviewed presentation/capture/doc paths only, restoring them from the verified baseline after explicit review; never reset unrelated work. Approve this completed POS slice before 8B.2 propagation or reports/dashboard construction. No financial/stock/controller/backend migration is part of the plan.
