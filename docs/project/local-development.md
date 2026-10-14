# Local development on Windows

After cloning, use the root `setup.ps1` once and `run.ps1` for daily work. Both work with Windows PowerShell 5.1 and PowerShell 7 on Windows, from any working directory when invoked by their full path. They use this repository's existing Composer and Flutter dependencies.

## Install the tools once

Install these on each teammate's computer, add their executables to PATH, and reopen PowerShell:

| Tool | Requirement | Official installation guide |
| --- | --- | --- |
| Git | A current Git installation | [Git for Windows](https://git-scm.com/downloads/win) |
| PHP | PHP 8.4+ within 8.x; CLI extensions including `pdo_mysql`, `pdo_sqlite`, `mbstring`, `dom`, `curl`, `fileinfo`, `openssl`, `xml`, `zip` | [PHP for Windows](https://windows.php.net/download/) |
| Composer | Composer 2.x | [Composer](https://getcomposer.org/download/) |
| MySQL | MySQL 8.0.16+; a running local server and a development account | [MySQL installation](https://dev.mysql.com/doc/refman/8.4/en/installing.html) |
| Flutter | Flutter 3.44.6 stable / Dart 3.12.2 is the CI baseline | [Flutter installation](https://docs.flutter.dev/install) |
| Chrome | For the default browser preview; Edge is also supported by the runner | [Chrome](https://www.google.com/chrome/) |
| Android Studio | For Android: SDK, JDK 21, an emulator or USB-debugging device, reviewed SDK licenses | [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup) |

Setup checks prerequisites and gives installation links when a tool is missing. It does not install system software, change PATH, alter execution policy, start MySQL services, accept licenses, or replace SDKs automatically. Node/npm and Visual Studio are not needed for the Chrome/Android targets.

## First setup after cloning

In the repository root:

```powershell
.\setup.ps1 -Check     # Optional: check PHP, extensions, Composer and Flutter only
.\setup.ps1            # Guided project setup; browser is the default target
```

The guided setup:

1. Copies `apps/backend/.env.example` to `.env` only when `.env` is missing. Installs PHP dependencies from `composer.lock`, validates local configuration, and runs the reviewed Laravel package-discovery hook.
2. Prompts for MySQL host, port, database, username and a hidden password on a fresh setup. Press Enter to use a displayed default; an empty password is supported for a local account that actually has one. Use a dedicated application account when available; the template's `root` default is a local convenience. See [database accounts and grants](../database/README.md).
3. Writes only the five database settings. Special characters, spaces, backslashes, dollar signs and Unicode passwords are encoded for dotenv. Saves the previous `.env` in an ignored `.env.setup-backup.*` file. These backups contain credentials: keep them private and remove them when no longer needed.
4. Clears stale Laravel configuration and generates `APP_KEY` only if missing. Existing keys are preserved.
5. Checks a local MySQL connection/version, displays the target, and asks you to type the database name. This confirms it is dedicated to this checkout. Creates a missing database using the supplied account if that account has `CREATE` privilege, applies pending migrations, and seeds only the three staff roles. It never drops databases/tables, runs `migrate:fresh`, or resets users.
6. Offers to create the first active local administrator if none exists. Choose your own app login password of at least 12 characters. This password is separate from MySQL. There is no default app password, no promotion of existing users, and no overwrite of existing admin credentials. Later staff accounts belong in the existing staff-management API. Use `-SkipAdmin` to skip this prompt.
7. Runs `flutter pub get --enforce-lockfile`, copies the public Flutter configuration example only when missing, and prints `flutter doctor -v` findings. Android setup checks the Android toolchain; browser setup checks Chrome detection. A missing Windows desktop toolchain does not block these targets.

Existing `.env` settings and app keys are preserved on repeat runs. Setup still asks for the database name before applying pending migrations. To change database credentials deliberately:

```powershell
.\setup.ps1 -ConfigureDatabase
.\setup.ps1 -Target android
```

Configuration is retained if a later step fails, so fix the reported problem and rerun setup. A failed migration can have applied earlier pending migrations; there is no automatic rollback. A cancelled database confirmation runs no migrations or role seeding.

Setup only accepts `APP_ENV=local`, MySQL at `127.0.0.1`/`localhost`, a valid dedicated database name, and no `DB_URL`/`DB_SOCKET`. It rejects inherited environment variables that could override the chosen `.env` target, as well as system databases and the reserved disposable test database. Shared/remote environments must be configured and migrated manually. Being local alone does not prove a database is disposable; read the target before confirming.

## Run the project

```powershell
.\run.ps1                               # Laravel + Flutter in Chrome
.\run.ps1 -DeviceId edge                # Laravel + Flutter in Edge
.\run.ps1 -Target backend               # Laravel only
.\run.ps1 -Target android -DeviceId emulator-5554
.\run.ps1 -Target android -Emulator Pixel_10_Pro_XL
```

Use `flutter emulators` to find your own emulator name, and `flutter devices` to find a device ID. `-Emulator` requests a cold boot and waits up to two minutes for an Android device. If multiple devices are connected, supply `-DeviceId` explicitly.

The runner checks local configuration, MySQL access, completed migrations and seeded roles. It starts Laravel's PHP development router, waits for `/up`, then starts Flutter. The API defaults to port 8000; Chrome/Edge defaults to 5173. API logs are in ignored `.dev/`. `/up` checks framework startup; the separate database checks establish readiness.

The public `API_BASE_URL` is passed explicitly for the selected target: `http://localhost:8000/api/v1` for browsers and `http://10.0.2.2:8000/api/v1` for Android emulators. `run.ps1` calculates this URL and does not read `config/development.local.json`; use the manual `flutter run --dart-define-from-file=...` command if you prefer that configuration file. Credentials never belong in Flutter defines.

To use different ports:

```powershell
.\run.ps1 -ApiPort 8001 -WebPort 5174
```

For a physical Android device on the same trusted network, substitute your PC's LAN IP and device ID. Allow the chosen API port through your local firewall if necessary:

```powershell
.\run.ps1 -Target android -DeviceId YOUR_DEVICE_ID -BindAddress 0.0.0.0 -ApiBaseUrl http://192.168.1.20:8000/api/v1
```

Use Flutter's `r`/`R` hot reload/restart controls and `q` to quit. Ctrl+C also exits. The runner stops only the PHP API process it created, and leaves MySQL/emulators running. Closing or forcibly terminating the terminal may bypass cleanup; stop a leftover API process yourself if its port remains occupied. The PHP development server is for local use.

## Troubleshooting

Failures stop with a nonzero exit code, the real command/helper error with known secrets redacted, and a suggested next step. Different failures need different fixes; setup cannot guarantee that every machine or network will work.

| Finding | Next step |
| --- | --- |
| Script execution is disabled | Review the local scripts, then allow only this invocation: `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`. Use the same form for `run.ps1`. An organization policy may require your administrator's help. No persistent execution-policy change is needed. |
| `php`, `composer` or `flutter` not found | Install the missing tool using the links above, fix PATH, and reopen PowerShell. |
| Missing PHP extension | Run `php --ini`, edit the loaded `php.ini`, enable the named extension, and rerun `setup.ps1 -Check`. |
| Composer/pub download failure | Read the reported network/TLS/version error. Check connectivity or your required proxy/certificate configuration; use `composer diagnose` for Composer. Do not disable TLS verification or discard lockfiles. |
| Windows file/path-too-long error | Clone into a short directory such as `D:\Coffee-Management-System`, then rerun setup. Avoid deeply nested clone paths. |
| MySQL connection refused / 2002 / 2003 | Start your local MySQL service with Services (`services.msc`) or your Docker controls; verify host/port. Setup uses PHP PDO, so the `mysql` CLI need not be on PATH. |
| MySQL access denied / 1045 | Check the username, password and account host grants; rerun `setup.ps1 -ConfigureDatabase`. |
| MySQL privilege error / 1044 / 1142 / 1227 | Have your local MySQL administrator create the development database/account or grant the required database privileges. Follow [database setup](../database/README.md). Existing accounts/passwords are never changed by setup. |
| Invalid `.env`, duplicate keys, remote target or environment override | Correct the reported key locally. Remove conflicting terminal environment variables, retain one entry per key, and choose a dedicated local `.env`. Values from invalid dotenv errors are omitted to protect credentials. |
| Pending migrations / missing roles / app key | Rerun `setup.ps1` and confirm the correct database; do not reset the database. |
| No first admin login | Rerun setup without `-SkipAdmin`; creation is offered only when no active admin exists. Existing accounts require staff-management provisioning or a trusted manual process. |
| Port already occupied | Stop your existing dev server or choose `-ApiPort`/`-WebPort`. The runner will not stop an unrelated process. |
| Android SDK/licenses/JDK error | Run `flutter doctor -v`; review licenses using `flutter doctor --android-licenses`, and verify SDK/JDK setup. |
| Emulator hangs or exits after startup | Try Device Manager > Cold Boot, close unused apps to free RAM, and inspect the actual emulator error. The runner's `-Emulator` option requests a cold boot; it does not wipe AVD data. |
| API startup failure | Read the displayed `.dev/` log and `apps/backend/storage/logs/laravel.log`. For client/API failures, verify the target-specific API URL, CORS and physical-device network access. Keep logs private. |

## Verify changes to the onboarding scripts

These checks use synthetic values and temporary files, without touching a development database:

```powershell
powershell -NoProfile -File scripts/tests/project-test.ps1
php scripts/tests/dev-setup-test.php
.\setup.ps1 -Check
```

PHP dependency installation is required for the dotenv checks. These checks validate script syntax, password encoding/redaction, local-target guards, backups, native exit codes, working-directory restoration, argument quoting and port-conflict handling. They do not replace testing a fresh setup against a dedicated MySQL instance, actual Flutter builds or device runs.

Verification on 2026-10-15 (Asia/Bangkok): 42 PHP checks and 18 PowerShell checks passed on Windows PowerShell 5.1 / PHP 8.4.4. A separate disposable MySQL 8.0.39 instance verified guided setup, a password containing spaces/special characters, database creation, all pending migrations, role seeding, first-admin creation and repeat setup. Runner verification exercised the real API health check, admin sign-in, browser API URL selection, PHP process cleanup and `.env` preservation; the Flutter foreground command was stubbed. Flutter 3.44.6 tool checks and actual locked dependency installation passed. PowerShell 7, a fresh network download, browser UI launch, and Android device launch were not exercised in this script verification. The developer's existing `.env` and database were not modified.
