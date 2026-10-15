# Luna Cafe Phase 8B.1 POS vertical slice — engineering handoff

2026-10-15. Starting branch/commit: **main / 9d09c3c3e5485acf8f75375a7eabb13203742c14**. Authorized work: the [8B.0 audit/blueprint](luna-mobile-ux-rescue-audit.md) followed by the POS-only 8B.1 implementation. [Before/after gallery and capture matrix](../../design/luna-cafe/previews/phase-8b1/README.md).

Verified full baseline SHA: `9d09c3c3e5485acf8f75375a7eabb13203742c14`. [Published baseline CI run 38660023532](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/38660023532): both jobs succeeded. Fresh local baseline: **622 tests, clean analysis, 136 formatted files with zero changes**. At start, staging/tracked tree was clean; `docs/prompts/` was the owner's untracked input. Its contents are preserved. No commit or push occurred during implementation; the owner subsequently authorized publication to `main` on 2026-10-15. No workflow changed.

## Result and changed paths

The POS now gives products more room on phones, separates category/name/exact price/add hierarchy, keeps cart navigation below the catalog, and gives a 1024px tablet a persistent draft cart. 2× text uses natural wrapping and a scrollable review; money changes remain immediate. The supplied logo, Inter/Noto fonts, palette and semantic status tokens are unchanged.

| Path, relative to root | Reason and effect |
| --- | --- |
| `apps/mobile/lib/features/pos/presentation/pos_page.dart` | Slim header/search/filters, lazy equal-height rows, allocated compact summary, 720×text-scale tablet split, pull refresh, static loading, one equal-failure notice with both exact retry paths. Existing debounce/search limit, pagination and controller lifetime retained. |
| `…/pos_product_card.dart` | Full 16px names, 20px tabular prices, category treatment, 48dp plus, one semantic/native keyboard add action, visible focus/selection and 150–180ms count/color feedback. Selected category foreground corrected to `onPrimaryContainer` for contrast. |
| `…/pos_category_art.dart` (new) | Decorative existing Material coffee/tea/bakery glyphs beside authoritative category labels; neutral fallback. No images, API fields or product metadata invented. |
| `…/pos_cart_summary.dart` (new) | 56dp normal review button, count/exact total, two lines at large text, authoritative active-order summary. Decorative duplicate count can scale down; operational count/total text retains requested scaling. |
| `…/pos_cart_panel.dart` | Flatter draft lines, inline 48dp stepper with bounded quantity width, immediate subtotal, 56dp Checkout, full-panel scrolling when height/text demands it; existing confirmations/limits/CheckoutPanel delegation retained. |
| `apps/mobile/lib/shared/theme/app_motion.dart` | One helper returns zero duration for `disableAnimations` or `accessibleNavigation`; existing durations and other screens unchanged. |
| `apps/mobile/test/pos_rescue_test.dart` (new) | 32 regression cases: recovery/retained data/exact next-page requests, controller reflow/no redundant fetch, active order locks/no resubmission, motion preferences, immediate exact totals, full bilingual names, contrast, 48dp targets, keyboard semantics, maximum cart and scroll-reachable Checkout. |
| `apps/mobile/test/{pos_page,pos_session,checkout_page}_test.dart` | Three exact text expectations updated from “1 items” to “1 item”; original cases and financial assertions preserved. |
| `apps/mobile/tool/luna_audit_preview.dart` | Read-only fixture loading state and deterministic pending-request disposal; never imported by production entrypoint. |
| `apps/mobile/tool/luna_pos_rescue_capture_test.dart` (new) | 54 native captures, real bundled fonts/icons and decoded artwork checks, deterministic teardown before binding invariants. |
| `apps/mobile/tool/luna_pos_profile.dart` (new) | Read-only native profile sampling, no production timers or HTTP stack. |
| `design/luna-cafe/previews/phase-8b1/` (new) | 54 widget PNGs, one emulator PNG, timing/memory JSON and comparison README; excluded from runtime assets. |
| `docs/frontend/luna-mobile-ux-rescue-{audit,verification}.md`, `luna-mobile-ux-rescue-files.txt` (new) | Blueprint, evidence/limitations and exact path inventory. |
| `docs/frontend/design-system.md`, `docs/project/roadmap.md` | Scoped POS conventions, completed local verification and next review gate. |

The [exact file inventory](luna-mobile-ux-rescue-files.txt) expands every capture filename and abbreviated path above. No auth/order/inventory/backend, domain/data, controller, checkout panel, launcher/splash, brand geometry, font, lockfile or CI file changed. Staging was empty at implementation handoff; the owner's supplied master prompt is included unchanged in the authorized publication.

## Validation actually executed

From `apps/mobile`, unless otherwise noted:

| Check | Final result |
| --- | --- |
| `dart format --set-exit-if-changed .` | **141 files, zero changes**. |
| `flutter analyze` | **No issues**. |
| `flutter test --reporter expanded` | **654 passed**, original 622 retained plus 32 new cases; 12 seconds in final run. |
| `flutter test tool/luna_pos_rescue_capture_test.dart --reporter expanded` | **54 passed**, captures generated with no framework exceptions. |
| Focused POS checks | Earlier existing POS/session/widget set **55 passed**; new regression/capture iterations caught teardown mistakes and the cart stepper. Final full suite includes checkout, auth/session, orders, inventory precision and idempotent retry regressions. |
| `flutter build apk --debug` | **Passed**, production `lib/main.dart`, final 10.7 seconds. APK `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, 184,928,623 bytes; debug multi-ABI size is not a release download measurement. |
| APK/source checks | New POS summary/search compiled; fixture banner absent. Three bundled logo PNGs byte-identical to owner masters; boards/captures absent. Runtime assets and lockfile unchanged. |
| `php artisan test --compact` in `apps/backend` | **380 passed / 73 skipped / 2347 assertions**, 12.67 seconds, isolated in-memory SQLite. Optional MySQL-only suites remain skipped; no development database changes. |
| Diff/staging review | Whitespace clean; unrelated prompt preserved; no secret, build artifact or new dependency staged. |

APK SHA-256: `120ecee339419e27ecdcdb98163a550f3c58156b55d07df98d84b2d9c9a00aff`. Local ignored logs are `output/luna-rescue-{tests,captures,analyze,apk,backend-tests}.log`.

The first full regression found one remaining singular-label expectation; its exact copy was corrected, retaining server-price/authoritative-total assertions. Early capture failures were nullable fixture cleanup and pending timeout timers; cleanup now executes before Flutter's end-of-test invariants. The keyboard test's assertions passed; its semantics handle needed disposal inside the test body. No case was deleted/skipped or assertion loosened.

Profile compilation emitted existing SDK XML v3/v4 tool-version and Java source/target 8 deprecation warnings. The final incremental debug build emitted no new warning. No SDK/package upgrade or web product UI was introduced; existing web compatibility CI is unchanged. Its next run is triggered by the authorized publication; local APK/test results above do not claim that CI outcome.

## Accessibility, performance and dependencies

Calculated contrast for touched roles: coffee/white **16.58:1**, secondary/white **5.25:1**, selected category coffee/latte **13.42:1**, dark secondary/surface **9.08:1**, dark secondary/selected **8.25:1**, light/dark error text **5.57/5.39:1**. Plus/focus boundaries use brand primary with contrast above 3:1. Automated selected-category tests verify actual rendered foreground/background pairs; the earlier 4.25:1 secondary-on-latte pair is corrected locally. Decorative outer card outlines are not the only add affordance.

Native-font matrix: 360×800, 390×844, 768×1024, 1024×768, light/dark, 1×/2×; full mixed Khmer/English labels and maximum unit price. Tests additionally cover virtual keyboard insets, a unique accessible add action, full search semantics, 48dp filter/icon targets and exact maximum draft total. Existing keyboard Tab/Enter tests remain passing. No full translation, fluent-speaker signoff, TalkBack/VoiceOver or physical touch study is claimed.

**Zero new packages or licensed assets.** Flutter 3.44.6 / Dart 3.12.2, Material 3, existing `http 1.6.0`, `flutter_secure_storage 9.2.4`, `go_router 18.0.2` retained. Existing local Inter/Noto Sans Khmer OFL notices and owner-supplied artwork manifest unchanged; Material glyphs come from the Flutter SDK. Native widgets suffice, so no transitive dependency/runtime asset increase. `flutter_animate`, SVG, skeleton/chart libraries and Lottie/Rive are deferred with reasons in the audit. No new chart or financial animation exists.

Android measurement: headless Pixel_10_Pro_XL / Android API 37.2 x86_64, WHPX with **SwiftShader software GPU**, Impeller OpenGLES, 1344×2992 physical / 480dpi (~448×997 logical). Final 60-second sampling window included catalog swipes/add taps. **449 frames total; 447 after the first five seconds**. Final warm build p50/p95 **2.012/8.773 ms**, raster **51.665/74.863 ms**, total span **99.235/140.168 ms**; maxima build **39.968 ms**, raster **374.233 ms**. Snapshot PSS **118,397 KB**, RSS **236,700 KB**; one snapshot does not establish leak-free behavior. [Raw JSON](../../design/luna-cafe/previews/phase-8b1/profile-evidence.json) records all/warm results.

This software-rendered, high-resolution emulator is visibly slow and **does not pass a 60fps smoothness claim**. Earlier shorter/lighter interaction sampling yielded warm build/raster p95 3.02/50.887ms; host load/workload were not controlled, so differences are not a before/after benchmark. Initial idle-only sampling had no warm frames and was discarded as interaction evidence. Repeat controlled scrolling/cart measurement on a representative physical low-end Android device before release. The profile app and emulator launched for this task were stopped; the user's backend was left running.

Windows cannot validate an iOS build, native splash, rendering or VoiceOver; macOS/Xcode and a device/simulator are required. Emulator profiling used read-only fixtures, not live catalog/payment writes. No fresh payment provider, printer, offline queue or analytics claim is made.

## Owner review gate

Review the POS [before/after gallery](../../design/luna-cafe/previews/phase-8b1/README.md). The user's master prompt requires review **before 8B.2 whole-app propagation and before dashboard construction**. The owner authorized committing and pushing this completed slice to `main` on 2026-10-15. That publication authorization does not expand implementation into 8B.2 or reports.

Next bounded step after approval: compact login identity, navigation semantics/text scaling, permission-grounded cashier routes and manager landing with explicit direct-path/session-downgrade tests; then checkout/history/inventory presentation refinement. Before attaching real reports, close the existing Home/Dashboard placeholder and role-only landing gaps and follow verified backend contracts/timezone, not illustrative JSON. Physical-device performance and native iOS accessibility remain validation gaps. Existing rollback plan restores only reviewed presentation/tool/doc paths without resetting unrelated work.
