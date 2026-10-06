# Database setup and conventions

The catalog now requires MySQL 8.0.16+ with enforced CHECK constraints. The example environment uses `127.0.0.1:3306`, database `coffee_management`, and a dedicated `coffee_management` account. No real credentials are committed.

Connect as your local database administrator (`mysql -u root -p`, adjusting host/port if needed). For a new local development database, run the following after replacing the example password locally:

```sql
CREATE DATABASE coffee_management
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'coffee_management'@'127.0.0.1'
  IDENTIFIED BY 'REPLACE_WITH_YOUR_LOCAL_PASSWORD';
GRANT ALL PRIVILEGES ON coffee_management.*
  TO 'coffee_management'@'127.0.0.1';
```

Use the account host appropriate for your MySQL installation; Docker/network connections may require a different host rule. For an existing database/account, use the existing configuration instead of recreating it. These grants support local migrations; restrict runtime privileges separately in production.

Set `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` in ignored `apps/backend/.env`. Quote passwords with spaces or special dotenv characters. Then, in `apps/backend`:

```sh
php artisan config:clear
php artisan migrate
php artisan migrate:status
```

Laravel's default users/password reset/session, cache, and jobs migrations remain unchanged. Phase 1 adds `roles`, nullable `users.role_id` (RESTRICT), inactive-by-default `users.is_active`, and Sanctum `personal_access_tokens`. The root seeder calls the idempotent RoleSeeder for cashier/manager/admin and creates no accounts. Phase 2 adds categories/products and a RESTRICT category FK. Phase 3 adds orders/order_items with exact cents, immutable snapshots, actor/key uniqueness and RESTRICT history FKs. Phase 4 adds payments, immutable payment_evidence, and owning-order composite accepted/active selection FKs plus paid_at. Phase 5 adds four exact inventory/recipe/reservation/movement tables. Phase 6 adds settings (`key` VARCHAR(64) PK, JSON `value`, `updated_by` FK RESTRICT) and audit_events (`id` BIGINT UNSIGNED PK, `actor_id` FK RESTRICT, polymorphic subject, action, JSON `metadata`, `created_at` timestamp). File cache/session drivers and synchronous queues do not use their database infrastructure tables yet. The [physical TRD](../system-analysis/trd.md) separates actual tables from proposed business design.

After migrating a verified dedicated development database, run `php artisan db:seed --class=RoleSeeder`. Existing users retain their name/email/password and become unassigned/inactive; do not automatically assign admin privileges. Initial synthetic local accounts can be deliberately created in Tinker with `User::factory()->withRole(StaffRole::Cashier)` or `StaffRole::Admin`, an explicit lowercase example.test email and an explicit randomly generated local password. The factory defaults active with a cashier role and a known **test-only** password; never use that default as a deployed/staff credential. Seeders contain no initial/default user or password. Admin staff provisioning, role updates, and password resets are managed through `/api/v1/staff`.

The password hashed cast protects trusted creation. User mass assignment excludes role_id/is_active; a trusted provisioner uses explicit assignment, while factories bypass mass-assignment guarding for synthetic data only. No public registration/bootstrap-admin endpoint exists.

MySQL connections now explicitly set time_zone='+00:00' to match UTC application timestamps. Verification found the local server default was SYSTEM / SE Asia Standard Time. Audit legacy TIMESTAMP rows before deployment if they were previously written with a non-UTC session; this task does not mutate/backfill shared data. See [Phase 3 verification](../system-analysis/phase-3-verification.md) for physical epoch, upgrade, money CHECK, real independent-process race and history-index evidence. Concurrency tests use the existing MySQL suite and require process spawning plus read access to performance_schema.data_lock_waits/threads for observation (available on the disposable root/CI instance); no worker runs migrations.

Use migrations as the schema source of truth. Future schema changes should define foreign keys, indexes for real query patterns, and transaction boundaries. Represent monetary amounts consistently using decimal values or integer minor units after deciding supported currencies; do not use floating-point amounts. Immutable order snapshots are now implemented; stock/payment records and exact stock ledger are implemented in Phases 4-5.

PHPUnit defaults to forced SQLite `:memory:` and testing mode. `phpunit.mysql.xml` runs the feature suite against **only** a separately provisioned local disposable database named `coffee_management_auth_test`; it forcibly clears DB_URL and sets the database/driver. TestCase checks testing mode, the exact database, local host and absence of URL/socket overrides **before** RefreshDatabase can reset tables. This is an additional guard, not proof that a database is disposable: verify the instance and use a test-only account before running it. CI uses a fresh runner-local MySQL 8.0 service.

```powershell
# Only after provisioning/verifying your disposable MySQL instance and test account:
# Set DB_HOST/DB_PORT/DB_USERNAME/DB_PASSWORD locally if its defaults differ.
php artisan config:clear
php vendor/bin/phpunit --configuration phpunit.mysql.xml
```

The suite uses migrate:fresh internally and destroys tables in that test database. Never point it at production/shared data. The MySQL run in this milestone used its own data directory, 127.0.0.1:33386, MySQL 8.0.39 and synthetic data; the normal local MySQL service/database was not mutated. See [verification](../system-analysis/verification.md). [Phase 2 verification](../system-analysis/phase-2-verification.md) adds catalog FK/SKU/index/money CHECK tests, query plans and upgrade preservation. Future order/payment/inventory locking still requires its own tests; catalog results do not prove checkout concurrency.

## Phase 5 inventory rollout

Apply four additive migrations on a verified backed-up target; prior Phase 1-4 migrations stay immutable. Stock begins zero; management creates base-unit items and recipes, then opening movements, checks inventory:check, and only then enables INVENTORY_TRACKING_ENABLED via deployment config. Historical orders retain their flag; pending tracked orders still consume/release if the gate is later disabled. DECIMAL(14,4) values cross PHP/API boundaries as exact strings with checked scale10000 arithmetic. Circular payment selection remains Phase 4; all stock/financial history FKs RESTRICT deletion. Rollbacks drop new stock history and are not an operational repair/cancellation mechanism. See [Phase 5 evidence](../system-analysis/phase-5-verification.md).

## Phase 6 staff, settings, and audit rollout

Phase 6 introduces two additive migrations: `2026_10_06_000015_create_settings_table.php` and `2026_10_06_000016_create_audit_events_table.php`. Applying these migrations preserves all 13 prior tables and their historical records. Last operational admin protection relies on explicit row-level locking of the `admin` row in the `roles` table. Audit records are append-only and protected against Eloquent mutation. Operational settings enforce allow-listing at the application level. See [Phase 6 evidence](../system-analysis/phase-6-verification.md).
