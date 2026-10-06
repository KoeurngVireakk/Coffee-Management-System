# Coffee Management System

A team monorepo for a Flutter mobile/tablet application, a Laravel REST API, and MySQL persistence.

**Status:** backend authentication/access foundations are implemented: Sanctum sign-in/sign-out/current-user, cashier/manager/admin roles and gates. The app still displays a neutral startup screen. Categories/Products are implemented with authorized management, active menu reads and exact USD-cent prices. Phase 3 adds unpaid POS checkout and role-scoped order history with immutable snapshots and actor-scoped replay keys. Phase 4 adds payment attempts, atomic cash settlement and a verified external/reconciliation foundation tested with a fake. Real bank/KHQR integration is disabled pending an approved contract. Phase 5 adds exact inventory, recipes, auditable movements, tracked checkout reservations, atomic paid-order consumption and safe manual cancellation. Tracking defaults disabled through deployment configuration; historical orders stay untracked. Paid receipt printing, reports, staff administration and settings remain planned. See [system analysis and diagrams](docs/system-analysis/README.md) for the proposed full system and [API contract](docs/api/README.md) for actual endpoints.

## Repository layout

```text
Coffee-Management-System/
├── apps/
│   ├── backend/                 Laravel 13 REST API
│   │   ├── app/
│   │   │   ├── Http/Controllers/Api/V1/
│   │   │   ├── Http/Requests/
│   │   │   ├── Http/Resources/
│   │   │   ├── Models/
│   │   │   ├── Policies/
│   │   │   ├── Providers/
│   │   │   └── Services/
│   │   ├── bootstrap/
│   │   ├── config/
│   │   ├── database/{factories,migrations,seeders}/
│   │   ├── public/
│   │   ├── resources/
│   │   ├── routes/{api,web,console}.php
│   │   ├── storage/
│   │   └── tests/{Feature,Unit}/
│   └── mobile/                  Flutter app (Android, iOS, web)
│       ├── android/
│       ├── ios/
│       ├── web/
│       ├── config/              Public build configuration examples
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart
│       │   ├── config/
│       │   ├── core/{errors,network,utils}/
│       │   ├── shared/{theme,widgets}/
│       │   └── features/
│       │       ├── auth/
│       │       ├── products/
│       │       ├── categories/
│       │       ├── pos/
│       │       ├── orders/
│       │       ├── payments/
│       │       ├── inventory/
│       │       ├── reports/
│       │       ├── users/
│       │       └── settings/
│       └── test/
├── docs/{architecture,api,database,project}/
├── .github/                    CI, issue templates, PR template
├── .editorconfig
├── .gitattributes
├── .gitignore
├── README.md
└── LICENSE
```

Every Flutter feature contains `data/`, `domain/`, and `presentation/` placeholders. Git tracks empty architectural boundaries with `.gitkeep`; replace those markers when adding real files. Generated dependencies and build output are ignored. Both applications share the single root Git repository.

## Architecture

Flutter uses feature-first Clean Architecture: presentation owns screens and state, domain owns plain Dart business rules and repository contracts, and data owns API models and repository implementations. Dependencies point inward toward domain. `core` holds technical infrastructure, `config` holds app configuration, and `shared` holds reusable UI. Add abstractions only when a concrete feature needs them.

Laravel follows framework conventions. API controllers live under `App\Http\Controllers\Api\V1`; Form Requests validate input, API Resources shape output, Eloquent models persist data, policies authorize access, and services handle workflows when a controller/model would become too large. The versioned route group is `/api/v1`. Repository wrappers, generic base services, a DI framework for Flutter, and payment SDKs are deliberately deferred.

See [architecture](docs/architecture/README.md), [API boundaries](docs/api/README.md), and [database guidance](docs/database/README.md).

## Prerequisites

- Git and Composer 2.x.
- PHP **8.4+** with Laravel's required extensions, including `pdo_mysql`; `pdo_sqlite` is used by the isolated test configuration. The committed dependency lock targets PHP 8.4.
- MySQL **8.0.16+**, a dedicated database, and a dedicated application account.
- Flutter **3.44.6 stable** / Dart **3.12.2** (the CI baseline).
- Android Studio, Android SDK, its bundled JDK, accepted Android licenses, and an emulator or device for Android development.
- macOS and Xcode to build/run iOS. Web preview requires Chrome or Edge.

This backend is API-only and has no Node/Vite build step. See the official [Laravel installation guide](https://laravel.com/framework/docs/13.x/installation) and [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup) for SDK installation.

## Run the backend

From the repository root, in PowerShell:

```powershell
cd apps/backend
composer install
Copy-Item .env.example .env
php artisan key:generate
```

Create your local database/account as described in [database setup](docs/database/README.md). Edit the ignored `apps/backend/.env` with your MySQL host, port, database, username, and password, then run:

```powershell
php artisan migrate
php artisan serve --host=127.0.0.1 --port=8000
```

On macOS/Linux, use `cp .env.example .env` in place of `Copy-Item`. Copy the example only for first-time setup; preserve your existing local settings on later installs. `composer dev` also starts the API server.

- Health: `http://localhost:8000/up` (boot check; does not test MySQL connectivity).
- API base: `http://localhost:8000/api/v1`; authentication endpoints live under `/auth`.
- The bare API base and unimplemented routes return JSON 404.
- File cache/sessions and synchronous queues let the framework boot before MySQL is configured; database operations still require MySQL.

For a physical device, bind Laravel to `0.0.0.0` on your trusted development network and use your computer's LAN IP in the app configuration.

## Run Flutter

Open another terminal at the repository root:

```powershell
cd apps/mobile
flutter pub get
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The URL above is for the Android Emulator. Use `http://localhost:8000/api/v1` for an iOS simulator or browser and your computer's LAN IP for a physical device. The shell does not make API requests yet; the value is available in `AppConfig.apiBaseUrl` for future data-layer code.

Browser preview with the configured CORS port:

```powershell
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Alternatively, copy `config/development.example.json` to ignored `config/development.local.json`, edit its public URL, and pass `--dart-define-from-file=config/development.local.json`. Flutter does not load Laravel's `.env`. Build-time defines are readable from compiled apps; never put secrets in them.

Debug Android builds permit local HTTP. Release builds should use HTTPS. The generated Android/iOS application IDs use `com.coffeemanagement` as a provisional organization; confirm identifiers and release signing before distribution. The generated Android release block currently uses debug signing and is not a publishing configuration.

## Checks and builds

```powershell
# apps/backend
composer validate --strict
composer lint
composer test
php artisan route:list

# apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

GitHub Actions runs backend formatting/tests plus MySQL migrations, and Flutter formatting/analysis/tests plus web and debug APK builds. See [local verification](docs/project/verification.md) for actual results and platform limits.

## Team workflow and roadmap

Use short-lived branches and reviewed pull requests into `main`; do not commit dependencies, local configuration, credentials, generated output, or signing keys. Commit `composer.lock` and `pubspec.lock` so the team installs consistent versions. Recommended branch protection and contribution rules are in [contributing](docs/project/contributing.md).

**Next backend feature:** Phase 6 Staff Management + Settings + Audit, separately authorized. Phase 5 inventory is implemented; see [inventory contract](docs/api/inventory.md) and [Phase 5 verification](docs/system-analysis/phase-5-verification.md). Phase 4 cash settlement and provider-neutral verification/reconciliation foundation are implemented; real bank/KHQR contract, credentials/callback authentication and a durable recovery worker remain pending. Phase 3 unpaid checkout/history is implemented with zero tax/discount and inventory enforcement off. Categories/Products are implemented with USD cents and no conversion. Flutter sign-in/session handling remains a separate planned client milestone. Scope and decision gates are in the [roadmap](docs/project/roadmap.md) and [backend plan](docs/system-analysis/backend-plan.md). After migrating a verified local database, run `php artisan db:seed --class=RoleSeeder` for standard roles; seeders create no accounts. Existing/new ordinary users are inactive and unassigned until deliberately provisioned through a trusted process. See [database guidance](docs/database/README.md).

## License

[MIT](LICENSE), copyright 2026 Koeurng Vireak. The existing license is preserved.
