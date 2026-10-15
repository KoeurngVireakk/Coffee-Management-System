# Luna Cafe Phase 8A engineering handoff

Verified 2026-10-15 on Windows. Branch `main`, baseline commit `7420e04652da58cf2157ecb9eae63b52be941721`. Validation preceded publication; the owner subsequently authorized committing and pushing this 8A change to `main`. No deployment is included. **8A uses the owner-selected `Luna_Cafe_Vector_Logo_Kit`; supplied geometry is preserved and the earlier redraw is removed. 8B and 8C remain pending their agreed review gates.**

## Result and changed paths

Existing Material 3 tokens now carry coffee/cream and foreground-safe gold accents. Local fonts replace startup network dependence and unbundled font assumptions. Login, compact/tablet shell and More show the new identity. POS, checkout, orders and inventory inherit shared palette/type without controller, repository, API, money or settlement changes. Android/iOS identifiers are retained; display names and icon/splash sources change.

| Paths | Required change and effect |
| --- | --- |
| `apps/mobile/lib/shared/brand/luna_brand.dart` | Supplied stacked logo and light/dark monogram assets, bounded decode sizes, image semantics and compact native shop label. |
| `apps/mobile/lib/shared/theme/{app_colors,app_theme,app_typography,cafe_theme_extension}.dart` | Extend existing tokens, local operational fonts and accent contrast; status colors/tabular figures preserved. |
| `apps/mobile/lib/app.dart` | MaterialApp display title. |
| `apps/mobile/lib/features/auth/presentation/{login_page,authenticated_placeholder_page}.dart` | Supplied login artwork and consistent identity; form/session behavior retained. |
| `apps/mobile/lib/features/shell/presentation/{adaptive_app_shell,destination_pages}.dart` | Compact/tablet/More brand touchpoints; existing navigation behavior retained for 8A. |
| `apps/mobile/lib/features/preview/presentation/design_system_preview_page.dart` | Existing showcase title follows app identity. |
| `apps/mobile/pubspec.yaml`, `assets/branding/*`, `assets/fonts/*` | Three supplied PNGs, source manifest, local UI fonts and OFL notices; no dependency upgrade or branding font. |
| `apps/mobile/android/app/src/main/AndroidManifest.xml`, `res/*` | Luna display name, legacy/adaptive/monochrome icons and system light/dark splash. |
| `apps/mobile/ios/Runner/Info.plist`, `Base.lproj/LaunchScreen.storyboard`, `Assets.xcassets/*` | Luna display name, opaque RGB icons and source light/dark launch assets. |
| `apps/mobile/test/{app_bootstrap_test,login_page_test,adaptive_app_shell_test,responsive_test}.dart` | Updated identity assertions: supplied image with accessible shop name on login, native title elsewhere; all original cases and business assertions retained. |
| `apps/mobile/test/luna_brand_test.dart` | 22 new contrast, status distinction, native-font layout/form/error tests. |
| `apps/mobile/tool/luna_audit_preview.dart` | Read-only synthetic mobile preview using existing injected repository seams. |
| `apps/mobile/tool/{luna_asset_export_test,luna_mobile_capture_test}.dart` | Package the supplied icon/monogram resources and reproduce nine native captures; assert images decode before capture. |
| `design/luna-cafe/{README.md,artwork/supplied-kit/*,previews/phase-8a/*}` | Kit/application comparison and synthetic native phone/tablet evidence. The owner's source kit is not modified. |
| `docs/frontend/luna-cafe-{phase-8-audit,asset-integration,phase-8a-verification}.md`, `luna-cafe-phase-8a-files.txt` | Confirmed audit/contracts, asset provenance and verification/exact inventory. |
| `docs/frontend/{design-system,manager-dashboard-specification}.md`, `docs/project/roadmap.md` | Current theme pointer, illustrative-contract warning and pending review/backlog status. |

The [exact file inventory](luna-cafe-phase-8a-files.txt) enumerates every affected file, including each generated variant. The [asset guide](luna-cafe-asset-integration.md) explains their filenames, dimensions, source/license and use. There are no backend or dependency lockfile changes.

## Executed checks

Flutter commands ran from `apps/mobile`; backend command from `apps/backend`.

| Command/check | Fresh result |
| --- | --- |
| `dart format --set-exit-if-changed .` | Passed: **136 files, zero changed**. |
| `flutter analyze` | Passed: **no issues**. |
| `flutter test --reporter expanded` | Passed: **622 tests**, original 600 retained plus 22 new tests. |
| `flutter test tool/luna_mobile_capture_test.dart --reporter expanded` | Passed: **9 captures** with real bundled English/Khmer fonts and Material icons. |
| `flutter test tool/luna_asset_export_test.dart --reporter expanded` | Passed: **1 export check**, no extra image package. |
| `flutter build apk --debug` | Passed: **21.9 seconds**, `build/app/outputs/flutter-apk/app-debug.apk`. |
| `php artisan test --compact` | Passed: **380 passed / 73 skipped / 2347 assertions**, 33.74 seconds. Isolated SQLite; optional MySQL integration suite skipped. |
| PNG/XML/font inspection | iOS icons RGB without alpha and correct dimensions; transparent brand exports preserve alpha; Android XML and iOS source XML/JSON parse; font hashes match provenance. |
| APK inspection | Two local UI fonts/notices and selected branding PNGs/manifest. Supplied logos are byte-identical inside the APK; redraw, Playfair font, boards and captures excluded. Debug APK **184,928,623 bytes**, not a release-download-size measurement. |
| Git review | Application/doc whitespace checks passed. Two upstream OFL notices retain their original trailing space; those known license lines are excluded from the staged whitespace check. Staging was empty before authorized publication; only reviewed 8A paths and the supplied kit are staged. No backend, lockfile, compiled APK or secret included. |

Final logs remain in ignored local `output/luna-phase-8a-{tests,backend-tests,apk}.log`. The baseline Android build emitted the SDK XML v4/v3 tool-version warning; the final incremental build emitted no additional warning. `flutter pub get` reported 22 newer incompatible versions; packages were not upgraded. An earlier existing web compatibility build passed with secure-storage Wasm and missing Cupertino-font warnings. No web product UI or CI gate was added/removed. An early browser audit hit a DWDS debug transport error; final captures use the native widget renderer.

The regression suite caught an oversized logo lockup on short viewports; its proportional size now responds to viewport height, keeping Sign In reachable without relaxing the existing tap assertions. Capture inspection also required waiting for asynchronous image decoding; capture tests now assert decoded pixels are present. Final checks above are green; no test was removed, skipped or relaxed.

## Mobile evidence and limits

Review the [supplied kit applied to login/app icon](../../design/luna-cafe/artwork/supplied-kit/REVIEW.md) and [nine captures](../../design/luna-cafe/previews/phase-8a/README.md). Runtime branding copies are byte-identical to supplied PNGs. The native-font login matrix covers 360×800, 390×844, 600×960, 768×1024 and 1024×768, each in light/dark at 1×/2× text, with the existing Khmer subtitle and reachable form validation. Tests verify decoded logo pixels are present. An extra timeout test verifies error/retry access at 2×. Existing tests continue exercising financial precision, checkout, orders/inventory, authorization and lifecycle. Fixture names/prices never become live SKUs.

No connected Android device was available in this phase. OS splash/icon rendering, physical taps, memory, low-end frame timing and TalkBack are **not verified**. Native widget captures are not emulator screenshots. iOS source/assets are prepared, but macOS/Xcode is required for build and launch/VoiceOver validation. Full translation and every Khmer cluster combination remain unverified. No golden baseline was introduced without an existing stable golden setup.

## Next review gate

The supplied master prompt says: **“Continue to 8B/8C only within the agreed review gates.”** The owner has already selected the supplied logo kit. Review the bounded 8A implementation before 8B starts; a second logo-selection approval is not required.

8B must close the existing cashier Dashboard/Home and role-only landing gaps before attaching real reports, use strict integer-string contracts and server-anchored dates, and test 401/403/409/422/429, malformed/partial data, concurrent refreshes and disposal. 8C must address the audited reduced-motion skeleton and field/button semantics issues with device evidence where available. Receipt UI does not exist. The external provider remains disabled; no live KHQR/Bakong claim is made.

After those gates, likely Phase 9 work is staff/product administration or settings. Those mobile destinations remain planned in the verified backlog and need a priority decision.
