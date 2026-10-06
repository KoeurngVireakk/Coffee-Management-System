# Scaffold verification

Historical foundation record. Current settlement checks are in [Phase 4 verification](../system-analysis/phase-4-verification.md). Current unpaid checkout checks are in [Phase 3 verification](../system-analysis/phase-3-verification.md). Current catalog checks are in [Phase 2 verification](../system-analysis/phase-2-verification.md). For the 2026-10-06 authentication/access milestone and current checks, see [system-analysis verification](../system-analysis/verification.md). The results below describe the earlier scaffold and have not been relabeled as current feature verification.

Verified locally on **2026-10-05 (Asia/Bangkok)** on Windows. No business features were implemented.

## Toolchain

| Tool | Verified version |
| --- | --- |
| PHP | 8.4.4, including `pdo_mysql` and `pdo_sqlite` |
| Composer | 2.8.11 |
| Laravel framework | 13.34.0, from `composer.lock` |
| Flutter | 3.44.6 stable |
| Dart | 3.12.2 |
| MySQL used for verification | 8.0.39 |
| Android JDK | Android Studio bundled OpenJDK 21 |

## Results

| Check | Result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer check-platform-reqs` | Passed |
| `composer lint` | Passed |
| `composer test` | 3 bootstrap tests, 8 assertions passed |
| `php artisan route:list` | Only `/up` is registered |
| Live `php artisan serve` | Started; HTTP `/up` returned 200 |
| Live unknown `/api/v1/...` request | HTTP 404, `application/json` |
| Default migrations on isolated MySQL | All 3 migrations passed; status confirmed |
| Dart formatting | Passed |
| `flutter analyze` | No issues |
| `flutter test` | 1 application-shell test passed |
| `flutter pub get --enforce-lockfile` | Passed |
| `flutter build apk --debug` | Passed; `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build web` | Passed; `apps/mobile/build/web/` |
| `flutter run -d web-server --web-port=5173` | Started successfully |
| Chrome via Playwright | App title and rendered startup text confirmed; no console errors/warnings |
| Workflow / issue templates / Flutter YAML | Parsed successfully |
| Git inspection | Original commit/license preserved; no nested `.git`; no commit or push |
| Ignore rules | Local `.env`, dependencies, builds, and local configuration ignored; examples/lockfiles included |

## Limits and local setup still needed

The MySQL check used a disposable server bound to `127.0.0.1:13306` with its own data directory and database. It verified the framework migrations without changing existing MySQL databases or provisioning the project's permanent local database/account. The temporary server was shut down. Recursive cleanup was rejected by automatic approval review as "blocked by policy"; its ignored data files remain at `apps/backend/storage/framework/testing/mysql-smoke`. They are not part of the scaffold source.

Configure a permanent MySQL database/account and update ignored `apps/backend/.env` before database-backed feature development. The committed `.env.example` contains no real credentials and leaves `APP_KEY` blank; the ignored local `.env` has a generated key.

No Android device/emulator was connected during validation, so device launch was not tested. The debug APK was built successfully. iOS was generated but cannot be built on this Windows host; use macOS/Xcode. Flutter's Windows desktop doctor warning is outside the selected Android/iOS/web targets.

The initial Android build installed a required SDK build-tools component and emitted an SDK metadata warning. The web build emitted an icon-font diagnostic. Both completed successfully. Build artifacts and browser session logs remain local and ignored.

All API/browser/MySQL verification servers and the Playwright browser session were stopped after verification. GitHub Actions is configured and YAML-validated locally, but has not run on GitHub because no changes were pushed. Production app identifiers, release signing, production URLs, and payment provider credentials are not configured.

Current inventory checks and complete Phase 5 manifest are recorded in [Phase 5 verification](../system-analysis/phase-5-verification.md); the scaffold results above remain historical.
