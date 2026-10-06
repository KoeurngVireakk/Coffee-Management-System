# Phase 6 verification: staff management, typed settings, and immutable administrative audit

Date: 2026-10-06, Asia/Bangkok. Authorized staff provisioning, role/activation management, password reset, token revocation, last-operational-admin concurrency protection, typed operational settings, and immutable administrative audit events milestone, with all 11 canonical skills assigned across the team. Commit and push to main authorized after the complete gate. No Flutter implementation, no reports, and no real provider traffic; stop before Phase 7.

## Baseline

Baseline commit: `68859e8062028f42a1e674111ec2b5f5ed94471b` (`fix: update database name and username in environment configuration`), preserving Phase 5 feature commit `a2f5bc263f61158e63f055d1d202afea8c222587`. Baseline SQLite tests passed (321 passed, 70 skipped, 1896 assertions); 28 route entries. Original migrations and Phase 1–5 APIs preserved.

## Decisions and assigned responsibilities

Staff administration belongs exclusively to the `admin` role (`manage-staff` permission). Fixed roles remain `cashier`, `manager`, `admin`, resolved by the `StaffRole` enum and database `roles` table. No dynamic role builder, permission tables, or RBAC packages were introduced. Unknown properties are rejected on all requests (`RejectsUnknownFields`). Staff email normalization trims and lowercases inputs; unique email collisions during concurrent registration are caught by database constraints and returned as 422 Unprocessable Content. Staff records are permanent; no DELETE endpoint exists to protect financial and historical foreign-key integrity.

Token revocation rules:
1. Name-only changes preserve existing tokens.
2. Role change, email change, or deactivation revokes all Sanctum personal access tokens for that account.
3. Password reset revokes all tokens.
4. Account reactivation does not automatically issue tokens.

Last operational admin protection ensures the system cannot reduce active admins (`is_active = true`, `role = admin`) from 1 to 0 via deactivation or demotion. Concurrency safety is achieved by row-locking the `admin` row in the `roles` table (`Role::where('name', 'admin')->lockForUpdate()`), preventing race-condition lockouts and returning 409 Conflict.

Operational settings use an allow-listed registry (`SettingRegistry`) supporting `shop_name` (string, max 120) and `shop_timezone` (valid IANA timezone string). Unregistered keys and secret keys (`APP_KEY`, `DB_PASSWORD`, `INVENTORY_TRACKING_ENABLED`) return 422. Managers may read settings; admins may read and update settings; cashiers are denied.

Administrative audit events (`audit_events`) are append-only. The `AuditEvent` Eloquent model hooks `updating` and `deleting` events and throws `LogicException`. Events record actor, polymorphic subject, action, structured metadata (JSON), and UTC `created_at`. No passwords, token secrets, or hashes are logged. Admin-only query API supports filtering by actor, action, subject, and date ranges.

The 11 canonical skills were coordinated across the phase: System Architect designed invariants and boundaries; Laravel REST API and MySQL Design implemented schemas, models, services, requests, resources, and policies; Cybersecurity reviewed privilege escalation, token revocation, secrecy, and tampering; Risk-Based QA executed SQLite, MySQL multi-process concurrency, and migration upgrade tests; Flutter and UX reviewers verified API contracts for future client consumption; Evidence-Based Code Review, Safe CI, and Preserve Git Workflow validated the final diff, CI safety, and publication readiness.

## Incremental milestone outcomes

| Scope | Implemented outcome |
| --- | --- |
| Decision freeze / roles | Fixed roles `cashier`, `manager`, `admin` frozen; single nullable FK; code-based permissions in `StaffRole`; no super-admin bypass |
| Database schema | Two additive migrations: `settings` (key VARCHAR(64) PK, JSON value, updated_by FK RESTRICT) and `audit_events` (BIGINT PK, actor FK RESTRICT, polymorphic subject, action, JSON metadata, created_at timestamp); composite query indexes |
| Staff provisioning | `POST /api/v1/staff`: admin-only; validates name, email, role, is_active, password (min 12 chars); email normalized; duplicate race caught via unique constraint (422); records `staff.created` audit event |
| Staff listing & detail | `GET /api/v1/staff`, `GET /api/v1/staff/{user}`: admin-only; filtered by role, is_active, search (name/email); bounded pagination (1–100); never exposes password or token hashes |
| Staff update | `PATCH /api/v1/staff/{user}`: admin-only; updates name, email, role, is_active; rejects unknown fields; enforces token revocation policy; records audit events |
| Last operational admin | Prevents deactivation or demotion reducing active admins from 1 to 0; row-level lock on `admin` role guarantees concurrency safety; returns 409 Conflict |
| Password reset | `POST /api/v1/staff/{user}/password`: admin-only; requires min 12 chars + confirmation; hashes securely; revokes all account tokens; records `staff.password_reset` with zero secret leakage |
| Token revocation | `POST /api/v1/staff/{user}/tokens/revoke`: admin-only; revokes all personal access tokens; records `staff.tokens_revoked` with reason |
| Typed settings | `GET /api/v1/settings`, `GET /api/v1/settings/{key}`, `PUT /api/v1/settings/{key}`: allow-lists `shop_name` and `shop_timezone`; absent keys return null; rejects arbitrary/secret keys (422); admin write, manager read-only; records `setting.updated` |
| Audit events API | `GET /api/v1/audit-events`: admin-only; filtered by actor_id, action, subject_type, subject_id, from_date, to_date; bounded pagination; indexed query execution |
| Audit immutability | `AuditEvent` model registers `updating` and `deleting` hooks that throw `LogicException`; table is append-only |
| Documentation & OpenAPI | Created `docs/api/staff.md`, `docs/api/settings.md`, `docs/api/audit.md`; updated `docs/api/openapi.json` (26 paths, 53 schemas); updated system analysis documents |
| Publication | Normal `main` commit and push authorized after passing all gates; CI inspected after push |

## Isolated MySQL upgrade and query evidence

Isolated MySQL 8.0.39 server ran on port 33386 with dedicated data directory `apps/backend/storage/framework/testing/staff-mysql-20261006`. Verified `@@datadir` before executing migrations; the shared MySQL service was untouched. The disposable test server was cleanly shut down after verification.

### Additive upgrade verification

The upgrade test script (`phase6-upgrade.php`) created the database at all 17 Phase 5 migrations, populated synthetic rows across all 13 existing tables (`users`, `roles`, `personal_access_tokens`, `categories`, `products`, `orders`, `order_items`, `payments`, `payment_evidence`, `inventory_items`, `product_ingredients`, `stock_reservations`, `stock_movements`), and applied the 2 additive Phase 6 migrations (`2026_10_06_000015_create_settings_table.php` and `2026_10_06_000016_create_audit_events_table.php`).

Results:
- Total migrations increased from 17 to 19.
- Row-by-row snapshot comparison before and after migration confirmed 100% preservation across all 13 prior tables.
- Foreign keys between `settings.updated_by` -> `users.id` and `audit_events.actor_id` -> `users.id` correctly use `RESTRICT` on delete.
- Original Phase 1–5 migrations remain strictly unmodified.

### Physical schema verification

Inspecting `information_schema.columns` and `information_schema.table_constraints`:
- `settings`: `key` VARCHAR(64) PK, `value` JSON NOT NULL, `updated_by` BIGINT UNSIGNED NULL FK `users(id)` RESTRICT, `created_at` / `updated_at` TIMESTAMP NULL.
- `audit_events`: `id` BIGINT UNSIGNED AUTO_INCREMENT PK, `actor_id` BIGINT UNSIGNED NULL FK `users(id)` RESTRICT, `action` VARCHAR(64) NOT NULL, `subject_type` VARCHAR(64) NULL, `subject_id` BIGINT UNSIGNED NULL, `metadata` JSON NULL, `created_at` TIMESTAMP NOT NULL.

### Query plan verification (`EXPLAIN`)

On a populated synthetic database:
- `SELECT * FROM settings WHERE key = 'shop_name'`: uses `PRIMARY` index with `type: const`, examining 1 row.
- `SELECT * FROM audit_events WHERE subject_type = 'user' AND subject_id = 1 ORDER BY created_at DESC, id DESC`: uses composite index `audit_events_subject_type_subject_id_created_at_id_index` with backward index scan; no filesort.
- `SELECT * FROM audit_events WHERE actor_id = 1 ORDER BY created_at DESC, id DESC`: uses composite index `audit_events_actor_id_created_at_id_index` with backward index scan; no filesort.

## Concurrency and race evidence

Concurrency tests used independent worker processes (`staff-worker.php`) connected to real MySQL 8.0:

1. **Last operational admin deactivation race:**
   - Setup: exactly 2 active admins (Admin A, Admin B).
   - Action: 2 concurrent processes; Process 1 attempts to deactivate Admin A, Process 2 attempts to deactivate Admin B.
   - Result: Exactly 1 process succeeded (HTTP 200), and 1 process was rejected with HTTP 409 Conflict (`Cannot deactivate or demote the last operational admin`).
   - Outcome: Exactly 1 active operational admin remained in the database. Zero-admin lockout was completely prevented.

2. **Last operational admin demotion race:**
   - Setup: exactly 2 active admins (Admin A, Admin B).
   - Action: 2 concurrent processes; Process 1 attempts to demote Admin A to cashier, Process 2 attempts to demote Admin B to cashier.
   - Result: Exactly 1 process succeeded (HTTP 200), and 1 process was rejected with HTTP 409 Conflict.
   - Outcome: Exactly 1 active operational admin remained in the database.

3. **Concurrent email collision race:**
   - Setup: 2 concurrent processes attempt to provision a new staff member with the same email `duplicate@test.com`.
   - Result: Process 1 succeeded (HTTP 201), Process 2 caught the database unique constraint violation and returned HTTP 422 Unprocessable Content with message `A staff member with this email address already exists.`
   - Outcome: No 500 error or unhandled database exception occurred.

## Separate final reviews: all 11 canonical skills

| Canonical skill | Assigned review and final evidence |
| --- | --- |
| [Practical system design](../../.agent/architecture/practical-system-design/SKILL.md) | Enforced clear boundary between staff identity, operational settings, and audit logging. Prevented dynamic IAM sprawl; kept 3 fixed roles. Admin invariants protected against lockout. Reports and UI cleanly deferred to future phases. |
| [Evidence-based code review](../../.agent/architecture/evidence-code-review/SKILL.md) | Reviewed the complete Phase 6 diff across all 35+ files. Confirmed no regression in Phase 1–5 auth, catalog, orders, payments, or inventory features. Verified that `SettingController::update` explicitly returns 200 OK for both create and update operations. |
| [Laravel REST API](../../.agent/laravel/laravel-rest-api/SKILL.md) | Controllers remain thin and delegate orchestration to `StaffManagementService` and `SettingService`. Form Requests use `RejectsUnknownFields` trait. API Resources strictly allow-list response fields. `UserPolicy` and `SettingPolicy` enforce granular ability checks. |
| [MySQL design](../../.agent/database/mysql-design/SKILL.md) | VARCHAR(64) PK for settings, BIGINT PK for audit_events. RESTRICT FKs protect relational integrity. Row-level locking on `roles` table eliminates race conditions without gap-lock deadlocks. Verified index utilization via EXPLAIN. |
| [API/payment security](../../.agent/cybersecurity/api-payment-security/SKILL.md) | Password fields strictly excluded from serialization and audit metadata. Token revocation policy immediately terminates sessions on privilege or credential changes. Secret keys (`APP_KEY`, `DB_PASSWORD`, `INVENTORY_TRACKING_ENABLED`) are rejected. |
| [Risk-based QA](../../.agent/testing/risk-based-qa/SKILL.md) | 356 SQLite tests passed; MySQL upgrade and concurrency races verified with independent processes. Negative paths covered: unauthorized actors, invalid roles, weak passwords, malformed timezones, duplicate emails, and audit mutation attempts. |
| [Preserve Git workflow](../../.agent/git/preserve-git-workflow/SKILL.md) | Verified baseline `68859e8062028f42a1e674111ec2b5f5ed94471b`. Staged only Phase 6 manifest files. No force-pushing or history rewriting. Verified clean synchronization with `origin/main`. |
| [Safe CI maintenance](../../.agent/devops/safe-ci-maintenance/SKILL.md) | Preserved CI workflows. No external dependencies or breaking packages added. Tests run cleanly in both SQLite memory and MySQL environments. |
| [Feature-first Flutter](../../.agent/flutter/feature-first-flutter/SKILL.md) | API contract review: `StaffResource`, `SettingResource`, and `AuditEventResource` provide consistent, strongly-typed JSON contracts with ISO 8601 timestamps and standard error envelopes. No Flutter code added. |
| [Accessible Cambodian POS](../../.agent/ux-ui/accessible-cambodian-pos/SKILL.md) | UX review: Error messages for 409 Conflict clearly explain administrative lockout prevention. Settings keys are human-readable (`shop_name`, `shop_timezone`). Status indicators (`is_active`, `role`) are explicit booleans and strings. No UI code added. |
| [Intentional frontend design](../../.agent/frontend/intentional-frontend-design/SKILL.md) | Interface contract review: Query parameters for filtering and pagination are standard and predictable. Absent settings return `{ key: "...", value: null }` rather than 404, simplifying UI initialization. No web framework added. |

## Known limits and recommended next scope

1. **Reports (Phase 7):** Operational sales, payment method, and inventory ledger reporting endpoints remain planned for Phase 7.
2. **Flutter Administration UI:** Administrative screens in Flutter remain planned for a later client milestone.
3. **Real Bakong/KHQR Integration:** External payment network integration remains disabled pending official provider credentials.
4. **Self-Service Password Reset:** Password recovery is admin-controlled only; public self-service email reset workflows are not implemented.

Recommended next milestone: **Phase 7 — Operational Reporting and Analytics Foundation**.

## Final local release gate

PHP 8.4.4, Composer 2.8.11, Laravel 13.34.0, PHPUnit 12.5.37.

| Check | Final result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer lint` | Passed |
| `composer test` (SQLite) | 356 passed, 73 skipped, 2119 assertions (9.93s) |
| `php artisan route:list` | 38 route entries (10 new Phase 6 endpoints) |
| Multi-process MySQL races | 3 races passed: deactivation conflict, demotion conflict, duplicate email |
| Additive Phase 5 upgrade | 17 -> 19 migrations, all 13 prior tables preserved with 100% data integrity |
| OpenAPI JSON parity | 26 paths, 53 schemas; matches all 38 route entries |
| Documentation links & fences | All links verified; Mermaid code blocks balanced |
| `git diff --check` | Passed |
| Protected paths & credentials | Passed; zero secrets or passwords in source or committed tests |

## Changed file manifest

Complete manifest of Phase 6 deliverable:

```text
GEMINI.md
README.md
apps/backend/app/Http/Controllers/Api/V1/AuditEventController.php
apps/backend/app/Http/Controllers/Api/V1/SettingController.php
apps/backend/app/Http/Controllers/Api/V1/StaffController.php
apps/backend/app/Http/Requests/Audit/AuditEventIndexRequest.php
apps/backend/app/Http/Requests/Settings/UpdateSettingRequest.php
apps/backend/app/Http/Requests/Staff/CreateStaffRequest.php
apps/backend/app/Http/Requests/Staff/ResetStaffPasswordRequest.php
apps/backend/app/Http/Requests/Staff/RevokeStaffTokensRequest.php
apps/backend/app/Http/Requests/Staff/StaffIndexRequest.php
apps/backend/app/Http/Requests/Staff/UpdateStaffRequest.php
apps/backend/app/Http/Resources/AuditEventResource.php
apps/backend/app/Http/Resources/SettingResource.php
apps/backend/app/Http/Resources/StaffResource.php
apps/backend/app/Models/AuditEvent.php
apps/backend/app/Models/Setting.php
apps/backend/app/Models/User.php
apps/backend/app/Policies/UserPolicy.php
apps/backend/app/Services/AuditService.php
apps/backend/app/Services/SettingService.php
apps/backend/app/Services/StaffManagementService.php
apps/backend/app/Settings/SettingRegistry.php
apps/backend/database/migrations/2026_10_06_000015_create_settings_table.php
apps/backend/database/migrations/2026_10_06_000016_create_audit_events_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/AuditEventApiTest.php
apps/backend/tests/Feature/SettingApiTest.php
apps/backend/tests/Feature/StaffApiTest.php
apps/backend/tests/Feature/StaffConcurrencyTest.php
apps/backend/tests/Feature/StaffSchemaTest.php
apps/backend/tests/Feature/StaffSecurityTest.php
apps/backend/tests/Feature/StaffWriteRaceTest.php
apps/backend/tests/Support/staff-worker.php
docs/api/README.md
docs/api/audit.md
docs/api/openapi.json
docs/api/settings.md
docs/api/staff.md
docs/architecture/README.md
docs/database/README.md
docs/project/gemini-phase-workflow.md
docs/project/roadmap.md
docs/system-analysis/backend-plan.md
docs/system-analysis/business-rules.md
docs/system-analysis/erd.md
docs/system-analysis/phase-6-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```

