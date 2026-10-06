# Verification and separate engineering reviews

This record is completed with actual command results after implementation. Planned system diagrams do not establish working business functionality. No Flutter build, provider integration or production deployment is part of this task.

## Review scope

| Specialty / project skill | Review questions |
| --- | --- |
| System architect / practical-system-design | Context/DFD balancing; ERD/TRD/rules agree; authoritative state belongs to Laravel; uncertain provider outcome recoverable |
| Database / mysql-design | Nullable role rollout safe; FKs/history/no cascading loss; snapshot/ledger/reservation relationships and query indexes justified |
| Laravel / laravel-rest-api | Laravel 13 compatibility; Requests/Resources/controllers/gates/policies; bearer config; no generic abstractions |
| Security / api-payment-security | Denied roles and inactive accounts; input properties; BOLA; expiry/revocation/throttle; no sensitive output; planned payment controls labeled |
| QA / risk-based-qa | Isolated DB; positive and negative HTTP/data assertions; real bearer tests; constraint/migration checks; SQLite/MySQL distinction |
| Git / preserve-git-workflow | Baseline clean main; staging preserved; no mobile/unrelated changes; no external mutation/commit/push |

## Executed checks (2026-10-06, Windows)

PHP 8.4.4, Composer 2.8.11, Laravel 13.34.0, Sanctum 4.3.3, PHPUnit 12.5.37. Only Sanctum was added to the dependency lock; no existing package version changed. Dependency installation disabled Composer plugins/scripts; reviewed Laravel package discovery was invoked explicitly.

| Command / check | Final result |
| --- | --- |
| `composer validate --strict` (apps/backend) | Passed |
| `composer lint` | Passed |
| `php artisan test --filter=AuthTest` | Focused authentication paths passed after fixing API guest redirect handling |
| `php artisan test --filter='AccessControlTest\|AuthSchemaTest'` | 10 tests / 90 assertions passed |
| `composer test` | SQLite :memory:, **33 tests / 263 assertions passed** |
| `php vendor/bin/phpunit --configuration phpunit.mysql.xml --no-progress --colors=never` | Disposable MySQL 8.0.39, **33 tests / 263 assertions passed**; the migration-upgrade regression explicitly uses a separate in-memory SQLite connection |
| `php artisan route:list` and `--path=api -vv` / `--json` | Three auth routes plus /up; middleware includes Sanctum, active staff and staff ability; GET also supports HEAD |
| `php artisan migrate --path=database/migrations/0001_01_01_000000_create_users_table.php`, synthetic legacy insert, `php artisan migrate`, `db:seed --class=RoleSeeder`, `migrate:status` | On dedicated disposable MySQL upgrade DB: all six migrations ran; PHP assertions verified original name/email/password retained, role null and inactive default |
| MySQL suite with deliberately disallowed documentation-only host 192.0.2.1, one schema test selected | Expected guard failure before any reset/connection; guard error verified |
| Local Markdown link/fence check | 42 local links resolve; balanced fences; eight Mermaid source blocks |
| OpenAPI JSON parse and local-reference walk | Passed; 12 local references resolve; four paths match route inventory; no third-party validator installed |
| Existing Python/PyYAML parse of CI configuration | Passed; backend/mobile jobs preserved; CI has not run remotely |
| `git diff --check`, staged diff and mobile diff | Passed; staging empty as at baseline; mobile unchanged |

Final test coverage includes valid login, generic credential failure, inactive/unassigned/unknown roles, request bounds/types, privilege/property injection, unauthenticated JSON behavior with/without Accept, current-user identity scoping, resource/model sensitive fields, expiry (per-token and global), logout/current-token isolation, current database role changes, ability denial, password rehash, both throttle buckets and window recovery, action/object denial, mass assignment, seed idempotency/no accounts, FK/unique constraints and additive legacy upgrade.

## Review results and corrections

- **Architect:** context and level 1 external exchanges balance; level 2 explicitly decomposes P3/P4 and retains P5 collaborator. Conceptual ERD and physical TRD differ deliberately. Provider I/O, uncertainty and recovery are outside SQL transactions. Inventory tracking rollout is explicit; no unsupported extra modules.
- **Database:** nullable role + inactive default avoids granting legacy access. MySQL uniqueness/FK restrictions and upgraded-user preservation verified. Proposed order/payment reverse FKs prevent choosing another order's attempt; reservations snapshot recipe quantities; late settlements remain reconciliation exceptions. Business-table migrations and their concurrency constraints are not implemented/tested.
- **Laravel:** installed Sanctum 4.3.3 accepts Laravel 13; framework lock remains 13.34.0. Controllers/Requests/Resources/models/gates/policy follow project conventions. No generic services/repositories or business route closures. Auth flow follows [official Laravel 13 Sanctum guidance](https://laravel.com/framework/docs/13.x/sanctum).
- **Security:** tests caught the framework login-redirect failure when Accept was omitted; API guest redirect now returns null so JSON 401 is rendered. Review added required staff token ability, its denied tests, password-rehash test and caller-ID substitution test. All protected identity/account rules fail closed. Future finance/provider/stock controls remain clearly proposed.
- **QA:** fractional timestamp precision initially caused an expiry assertion mismatch; freezeSecond aligns the fixture with database timestamp precision. Real bearer tokens and persisted state are asserted; no cookie/testing shortcut hides revocation. Tests block stray Laravel HTTP calls and guard unsafe DB targets before RefreshDatabase.
- **Git:** clean main at baseline; all task changes unstaged; no mobile edits, rewritten original migrations, nested repository, commit, push, deploy or provider contact.

## Isolation, cleanup and limits

MySQL verification used a newly initialized data directory `apps/backend/storage/framework/testing/auth-mysql-20261006`, server 127.0.0.1:33379 and databases `coffee_management_auth_test` / `coffee_management_auth_upgrade_test`. The server data directory was checked through @@datadir before database creation and shutdown. The existing MySQL80 service/database was not mutated. The temporary server was shut down; the existing service remained running.

Automatic approval review rejected recursive removal of that temporary directory as **"blocked by policy"**. Its files remain ignored and are not source changes. No approval was requested or deletion retried through another mechanism.

No real payment calls, production/shared database writes, Flutter/UX work, browser/device build or deployed TLS/logging audit occurred. CI configuration is updated, but GitHub Actions has not run because nothing was pushed. Mermaid fences/source were inspected but diagrams were not rendered with a Mermaid engine; no renderer/dependency was installed. OpenAPI was parsed and references/inventory checked, not certified by a full specification validator. Performance/backup targets and business-table concurrency remain proposals.

The dummy bcrypt hash used for missing identities is a non-credential cost-12 value matching the repository's production default; review it if password algorithm/cost changes. Eight-hour expiry is enforced, but periodic deletion of expired token rows is an operational maintenance task (Sanctum prune command), not an automatically scheduled job here.

## Complete changed/created path manifest

Four replaced architectural .gitkeep markers below are deleted; all other listed paths are created or modified for this milestone. Initial Git status was clean, so no user edits were absorbed into this manifest.

```text
.github/workflows/ci.yml
README.md
apps/backend/app/Enums/StaffRole.php
apps/backend/app/Http/Controllers/Api/V1/.gitkeep
apps/backend/app/Http/Controllers/Api/V1/AuthController.php
apps/backend/app/Http/Middleware/EnsureActiveStaff.php
apps/backend/app/Http/Requests/.gitkeep
apps/backend/app/Http/Requests/Auth/LoginRequest.php
apps/backend/app/Http/Resources/.gitkeep
apps/backend/app/Http/Resources/UserResource.php
apps/backend/app/Models/Role.php
apps/backend/app/Models/User.php
apps/backend/app/Policies/.gitkeep
apps/backend/app/Policies/UserPolicy.php
apps/backend/app/Providers/AppServiceProvider.php
apps/backend/bootstrap/app.php
apps/backend/composer.json
apps/backend/composer.lock
apps/backend/config/auth.php
apps/backend/config/sanctum.php
apps/backend/database/factories/UserFactory.php
apps/backend/database/migrations/2026_10_06_000001_create_roles_table.php
apps/backend/database/migrations/2026_10_06_000002_add_staff_access_to_users_table.php
apps/backend/database/migrations/2026_10_06_000003_create_personal_access_tokens_table.php
apps/backend/database/seeders/DatabaseSeeder.php
apps/backend/database/seeders/RoleSeeder.php
apps/backend/phpunit.mysql.xml
apps/backend/phpunit.xml
apps/backend/routes/api.php
apps/backend/tests/Feature/AccessControlTest.php
apps/backend/tests/Feature/AuthMigrationUpgradeTest.php
apps/backend/tests/Feature/AuthSchemaTest.php
apps/backend/tests/Feature/AuthTest.php
apps/backend/tests/TestCase.php
docs/api/README.md
docs/api/openapi.json
docs/architecture/README.md
docs/database/README.md
docs/project/roadmap.md
docs/project/verification.md
docs/system-analysis/README.md
docs/system-analysis/backend-plan.md
docs/system-analysis/business-rules.md
docs/system-analysis/context-diagram.md
docs/system-analysis/dfd-level-1.md
docs/system-analysis/dfd-level-2.md
docs/system-analysis/erd.md
docs/system-analysis/flowcharts.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
docs/system-analysis/verification.md
```
