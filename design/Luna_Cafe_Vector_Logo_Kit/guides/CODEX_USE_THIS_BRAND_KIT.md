# Codex instruction — use the provided Luna Cafe SVG brand kit

You are working in `KoeurngVireakk/Coffee-Management-System`. The scope is **Flutter Android/iOS mobile and tablet ONLY**. Laravel/MySQL remain existing back-end infrastructure. Do NOT implement any web UI.

## Required actions

1. First read `AGENTS.md`, `.agent/flutter/feature-first-flutter/SKILL.md`, `.agent/ux-ui/accessible-cambodian-pos/SKILL.md`, `docs/frontend/design-system.md` and the latest manager-dashboard specification.
2. Use the approved Luna Cafe logo vectors provided in this kit. **DO NOT autonomously regenerate, redraw, replace, or substantially alter the logo geometry.** `reference/user_approved_original_reference.jpeg` defines the source creative direction; the editable `.svg` files in `svg/` are the available reusable logo art.
3. Copy only needed SVG/PNG files to `apps/mobile/assets/branding/` and declare them properly in `apps/mobile/pubspec.yaml`. The provided wordmarks are converted to vector outlines, so do not install or redistribute fonts to reproduce them.
4. Use `svg/logo_stacked_transparent.svg` on Luna splash/onboarding or login, `svg/logo_horizontal_transparent.svg` only when it fits mobile header width, and `svg/monogram_gold_transparent.svg` on dark backgrounds. Use `png/app_icon_square_dark_1024x1024.png` as the starting source for generating platform-specific iOS icon assets, and the `android_*` files for Android adaptive icons. Review platform-specific masks/safe zones.
5. Build semantic color tokens in the existing Material 3 design system: `#2B1B0F`, `#4B3626`, `#C9A96A`, `#F8F3EA`, `#DCCEB7`, with independently validated text contrast. Preserve payment success, warning, error, and reconciliation status semantics.
6. Implement Flutter Phase 8 following `docs/frontend/manager-dashboard-specification.md`: real Laravel `/api/v1/reports/*` data, Cashier gated from view-reports, immutable exact integer USD cents, inventory exact fixed-point strings, `Asia/Phnom_Penh` report timezone contract, loading/empty/error/retry states and token-bound request lifecycles.
7. Inspect whether existing routes are managed by an internal shell or actual `go_router`; use existing implementation rather than adding a second router. Preserve API contracts, session protections, idempotency and existing business logic.
8. Existing modernization milestone baseline is 600 Flutter tests passing and 380 backend tests passing (73 skipped) based on user-reported results. Verify locally instead of assuming a pass. Run `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build apk --debug`; also backend tests if backend code is touched or API regressions need checking. Report actual run evidence.
9. Keep dependencies minimal. Add `flutter_svg` only if justified and compatible. Purposeful motion may use built-in animations first. Do not add web UI, demo-only fake production reports, invented menu prices, fake KHQR payment success, or new backend endpoints.
10. Show me a side-by-side preview of each logo applied to the login screen and app icon, then apply the already-approved geometry consistently. Commit/push only with explicit authorization.

Deliver a summary of changed files, screenshots for representative Android/iPhone and tablet widths, tests and any unverified platform limits.
