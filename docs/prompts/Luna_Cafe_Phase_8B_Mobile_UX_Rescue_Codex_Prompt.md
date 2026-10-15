# CODEX MASTER PROMPT — Luna Cafe Mobile UX Rescue (Phase 8B Design Quality Gate)

You are the senior Flutter mobile architect, principal UX/UI designer, accessibility engineer and security-conscious POS engineer for **Luna Cafe**. Your task is to evolve the existing, functional Android/iOS **Flutter mobile + tablet POS** into a premium, restrained and fast professional café application. **This is a scoped design-quality improvement, not a rewrite.**

## Verified starting point — inspect again

- Repository: `https://github.com/KoeurngVireakk/Coffee-Management-System`.
- Baseline to verify: `main` at `9d09c3c3e5485acf8f75375a7eabb13203742c14` (Phase 8A brand kit integration). Do not assume that is still HEAD; check `git status`, `git log`, current branch and GitHub Actions.
- Phase 8A local handoff reported **622 Flutter tests passing**, zero analyzer issues, formatted Dart, a successful Android debug APK and **380 backend tests passed / 73 skipped**. These are baseline reports, not evidence of your new code's result. The push CI run `38660023532` was still in progress when this brief was assembled; check its final conclusion.
- Existing business features: authenticated roles, POS catalog/cart, checkout & cash settlement, safe external-payment uncertainty handling, orders/history and inventory; backend Laravel REST API + MySQL. Money is exact integer USD cents, inventory uses exact fixed-point decimals.
- Phase 8A was a **branding integration** (supplied monogram, local fonts, native splash/icons), not a complete visual redesign.
- Product/report figures shown in screenshots are synthetic audit fixtures, not live shop data.
- Web is **not** a product target. Do not build React, Blade, web dashboards, or Flutter web-only UI. Preserve existing CI jobs, including any pre-existing web *compatibility* check, unless explicitly instructed otherwise.

## Canonical files to read first

1. `AGENTS.md`, `.agent/README.md`, `.agent/flutter/feature-first-flutter/SKILL.md`, `.agent/ux-ui/accessible-cambodian-pos/SKILL.md` and security/testing skills relevant to touched code.
2. `docs/frontend/luna-cafe-phase-8-audit.md`, `docs/frontend/luna-cafe-phase-8a-verification.md`, `docs/frontend/luna-cafe-asset-integration.md`, `docs/frontend/design-system.md`, `docs/frontend/manager-dashboard-specification.md`, `docs/project/roadmap.md`.
3. `design/luna-cafe/reference/approved_reference.jpg`, `design/Luna_Cafe_Vector_Logo_Kit/` (especially `guides/CODEX_USE_THIS_BRAND_KIT.md`), `design/luna-cafe/artwork/supplied-kit/REVIEW.md`, all 9 captures in `design/luna-cafe/previews/phase-8a/`, and concept boards 01–10 as secondary inspiration.
4. `apps/mobile/lib/shared/{brand,theme,widgets,navigation}`, `apps/mobile/lib/features/{auth,pos,orders,inventory,shell,reports}`, `apps/mobile/lib/app.dart`, `apps/mobile/pubspec.yaml`, `pubspec.lock`, existing test and capture harnesses.
5. Backend `routes/api.php`, `ReportController`, `ReportService`, `ReportPeriod`, report requests, relevant test cases, but only as sources of authoritative API contracts. Do **not** change backend schemas or semantics.

## Audit conclusions to validate against actual screenshots

In `pos-phone-light.png`, repeated generic cup icons make all products look alike, rectangular white tiles have weak content hierarchy, and the large cart action competes with product browsing. In `pos-phone-2x.png`, the header and fixed controls consume most of the available area. In `pos-phone-error.png`, the same service error is shown twice. The login images use a very large raster lockup, leaving the interaction hierarchy underdeveloped. `pos-tablet-dark.png` shows a desktop-like sidebar but the tablet POS composition needs a stronger dedicated cart/catalog strategy. Permission audit identifies cashier-visible Home/Dashboard placeholders and manager landing behavior based on role instead of `view-reports`.

Treat these as grounded observations and investigate root causes. Do not claim that user studies, on-device frame times, or accessibility audits have occurred unless they actually have.

## Non-negotiable product design direction

**LUNA CAFE = European café elegance × Khmer cultural soul.** Inspired by Parisian boutique café restraint and authentic Cambodian decorative craftsmanship. Keep the **exact owner-approved LC crescent monogram**; use the supplied original SVG masters and existing runtime asset derivatives. **Do not redraw, replace, distort, or AI-regenerate the logo.** If SVG runtime support is unnecessary, keep the currently verified PNG versions.

Brand palette: `#2B1B0F` coffee brown, `#4B3626` espresso, `#F8F3EA` cream, `#DCCEB7` beige, `#C9A96A` decorative antique gold, with high-contrast foreground gold `#806127` where suitable. Preserve independent semantic success, warning, error and info colors. Do not use insufficient-contrast gold for operational labels. Use local Inter and Noto Sans Khmer (licensed fonts already bundled). Khmer ornaments are subtle edge details/illustrations, **never behind critical inputs, prices or payment status**. Avoid excessive gold gradients, ornamental borders, depth effects or excessive cards. This is **a high-speed operational app for busy staff**, not a promotional website or a wedding invitation. Draw inspiration from leading chain café interaction quality, **not their branding, trademarks or layouts**.

## Phase 8B.0 — UX audit + design quality gate (first deliverable)

Before code changes, produce `docs/frontend/luna-mobile-ux-rescue-audit.md` containing:
- Screen-by-screen critique with reference to actual Phase 8A screenshots (login, phone POS, tablet POS, cart, checkout, history, inventory, empty/error states). Clearly mark screens not yet captured.
- Prioritized root causes ranked by cashier speed, information hierarchy, brand coherence, accessibility and regression risk.
- One **concrete mobile redesign blueprint**, with ASCII wireframes or Flutter layout sketches for phone 390×844 and tablet 1024×768 in light/dark. Include compact 360×800 and 2.0× text considerations.
- A component inventory / reuse map and design tokens (layout rhythm, type scale, surfaces, content hierarchy, selected/pressed/disabled states, image strategy, motion, reduced motion, keyboard and semantics).
- Accessibility checks: >=48dp common touch targets, WCAG-like AA text contrast checks, 2× scaling, Khmer cluster legibility, screen reader semantics, safe-area and virtual keyboard behavior.
- Baseline -> target screenshots with success criteria, dependency decision record, explicit rejected alternatives, and a risk/rollback plan.

Do not generate fake sales figures, fake product prices, unverified stock, or placeholder claims of live Bakong payments. Use mock fixtures only in the audited fixture/preview harness.

## Phase 8B.1 — IMPLEMENT a high-fidelity POS vertical slice (first coding gate)

Implement a real, polished **phone-first POS** improvement only after completing the audit. Keep data contracts, state management and controller identities. Primary files likely: `pos_page.dart`, `pos_product_card.dart`, `pos_cart_panel.dart`, narrowly scoped shared widgets/tokens, and corresponding tests. The scope should deliver:

1. **Catalog visual hierarchy:** slim operational header, clear search, compact well-spaced category filters, dense yet breathable product presentation; product name, category, exact unit price and add-action visually distinguishable at a glance. Handle Khmer/English labels naturally. Do not create a marketing hero that pushes products below the fold.
2. **Product images:** First inspect whether the API model includes an *authorized* media URL and whether assets have approved provenance. If absent, do not invent API fields or fetch random remote product photos. Implement an elegant, recognizable category illustration/treatment from licensed/approved local assets or brand-native icons, and document how real catalog imagery could be added in a separate approved phase. Preserve text-first usability if images fail to load.
3. **Cart ergonomics:** Preserve quantity constraints, maximum distinct items, state across reflows and existing controller logic. Make the floating summary compact, safe-area aware and clear about item count/total; avoid covering products, error banners or the bottom navigation. For tablets, optimize catalog/cart coexistence without introducing a browser dashboard.
4. **Interaction states:** deliberate visual feedback for add/increment/decrement; visible cart updates and non-blocking, non-duplicated notices; beautiful and recoverable loading, empty, error, offline/timeout and permission-restricted states. Fix duplicated catalog errors at the presentation layer without suppressing useful distinct failures.
5. **Motion:** prefer built-in Flutter animated widgets (`AnimatedSwitcher`, `AnimatedContainer`, `TweenAnimationBuilder`, route transitions). Evaluate `flutter_animate` for a narrowly justified and tested use; if added, document exact version, license, transitive dependencies, size and compatibility. Use 120–280ms purposeful transitions; no constant shimmer/glow/bounce or celebratory payment effects. Respect `MediaQuery.disableAnimations` and `accessibleNavigation` where applicable, and avoid motion during financial confirmation.
6. **Design coherence:** rely on existing Material 3, `AppTheme`, `AppColors`, `CafeThemeExtension`, `AppSpacing`, `AppRadius`, `AppShadows` and local typography. Extend rather than replace. Keep native Material accessibility and strong dark-mode contrast; do not use an overly decorative visual system at checkout.
7. **Preview evidence:** produce fresh comparable widget captures for 390×844, 360×800, 768×1024 and 1024×768, light/dark, 2× type, data/empty/error. Review raster outputs for clipped Khmer text, title wrapping, navigation overlap and cart coverage. Name fixture captures honestly: these are not screenshots of real physical devices.

## Phase 8B.2 — focused polish AFTER review of the vertical slice

If the owner approves the POS direction, apply the same design discipline to the login and navigation shell, then to checkout, orders and inventory **without changing payment, order or stock semantics**. Reduce oversized branding in tight phone layouts, strengthen visual hierarchy and user feedback, but keep the source logo intact. Replace unnecessary/unauthorized cashier Home and Dashboard placeholder exposure with permission-grounded navigation behavior. Add explicit negative tests for cashier attempting dashboard/reports by navigation or direct path, plus session downgrade/logout. `view-reports` is mandatory for manager/admin reports; the backend is still authoritative. Do not automatically remove unimplemented pages if doing so changes required navigation semantics—document the safe plan and test it.

## Next feature milestone — Manager Dashboard (original planned Phase 8B)

Once the quality gate is accepted, implement the **read-only** Manager Dashboard using the updated authoritative backend code/contracts. Preserve the existing `manager-dashboard-specification.md`, but correct its illustrative outdated JSON rather than copying it blindly:
- `GET /api/v1/reports/overview`: `revenue_minor` and `average_order_value_minor` are **integer strings**, `reconciliation_required` not `reconciliation_required_orders`.
- `sales-trend`: top-level `period` plus `data` with date, integer-string revenue and paid-order count.
- `payment-methods`: `amount_minor` integer string; no server percentage/label field; calculate ratios only for visual chart presentation without using floats in financial arithmetic.
- `top-products`: `name`, `sku`, `quantity_sold`, integer-string `revenue_minor`, `limit` 1–50 (default 10).
- `reconciliation`: separate **undated** pagination contract (do not attach report date parameters).
- For date presets use authoritative shop-local `period.timezone`, not the device timezone; handle invalid server timezone 409. Guard on `view-reports` in navigation, construction and lifecycle.
- Dashboard KPI cards, chart and alerts must use live authorized API data. No fake revenue, fabricated KHR conversion or claims that disabled KHQR/Bakong is operational.
- Consider `fl_chart` for chart interaction *when dashboard development starts*, not as a prerequisite for the POS redesign.

## Dependencies — disciplined decisions, not package collecting

- **Keep:** Material 3/Flutter framework, existing HTTP/secure storage, feature-first architecture and session controllers.
- **Selective:** `flutter_animate` if built-ins genuinely limit the requested motion; `flutter_svg` if a verified runtime SVG use case exists (supplied PNG marks may already be sufficient); `fl_chart` for the dashboard; `skeletonizer` only if existing skeleton components are demonstrably inadequate.
- **Defer:** Lottie/Rive without an approved original animation file, 3D scene tools, heavy shaders, unsolicited new state-management frameworks.
- **Do not auto-install latest `flex_color_scheme` 9.x**: current published 9.x requires Flutter >=3.47, whereas audit reports Flutter 3.44.6. The custom theme is already mature. Do not upgrade Flutter merely to add a theme package.
- For every dependency: list use case, supported SDK, license, transitive impact, build size, maintenance, and why built-in widgets are insufficient. No accidental package churn.

## Frozen technical and security invariants

- Preserve all approved existing flows, exact cents and fixed-point stock arithmetic; never use `double` for prices, totals, tender, change, inventory subunits or settlement results.
- Keep backend source of truth, idempotency keys (no duplicate order/payment submissions), 401 session revocation, 403 permission handling, 409 conflict/reconciliation behavior, 422 validation, 429 cooldown/retry, 503 disabled provider, network ambiguity and safe cancellation.
- No backend schema/route mutations, no seed-data substitutions for live records, no permissive authorization shortcuts, no unreviewed external media, no new payment provider or printer/offline workflow.
- No destructive refactor of repository boundaries. Respect root single Git repo and avoid overwriting team changes. Do not commit or push to `main` without explicit approval.

## Required validation/reporting

Start by verifying `git status`/current commit/CI and running baseline tests. After each bounded change run `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (do not lower the existing 622-test baseline), focused role/checkout/inventory regression tests and `flutter build apk --debug`; run `php artisan test` when integration behavior is touched. Add screenshot/widget tests for light/dark, text scale, under-400dp widths, tablet ergonomics, cart error recovery and authorization. Profile on a real Android device or emulator where available and report frame/build observations; **do not claim 60 fps or iOS readiness without measuring**. A Windows build cannot prove native iOS rendering; document that gap. Do not remove the existing GitHub Actions web compatibility step solely because this project is mobile-focused.

Produce a concise progress report with: inspected commit/CI, files changed, dependency versions/licenses, screenshot paths, before/after critique, test counts, analyzer/build results, regression assessment, exact limitations, remaining risks and next review gate.

## First action NOW

**Do not rebuild the whole app.** Read the exact repo/docs/assets and inspect all nine Phase 8A captures. Produce the `Phase 8B.0` audit and blueprint, then implement only the **high-fidelity POS vertical slice** under `Phase 8B.1` with tests and comparable captures. Present results for approval BEFORE propagating the style to the whole application and BEFORE building the full reports dashboard. Prioritize working staff ergonomics and premium Luna Cafe craftsmanship equally. Do not push without permission.
