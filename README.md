# Coffee Management System

A team monorepo for a Flutter mobile/tablet application, a Laravel REST API, and MySQL persistence.

**Status:** foundation scaffold only. The app displays a neutral startup screen; the API exposes Laravel's `/up` health endpoint. Authentication, catalog, POS, orders, payments/KHQR, inventory, reports, users/roles, and settings are planned and have no business implementation yet.

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
- MySQL **8.0+**, a dedicated database, and a dedicated application account.
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
- Future API base: `http://localhost:8000/api/v1`.
- The API base currently returns JSON 404 because no business routes exist.
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

**Next feature:** authentication with Laravel Sanctum, Flutter sign-in/session handling, and policy foundations for cashier/manager/admin access. Scope and subsequent milestones are in the [roadmap](docs/project/roadmap.md). No authentication package or role schema is installed yet.

## License

[MIT](LICENSE), copyright 2026 Koeurng Vireak. The existing license is preserved.
