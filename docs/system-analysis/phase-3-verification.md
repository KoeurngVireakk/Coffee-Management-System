# Phase 3: Orders and POS checkout verification

Date: 2026-10-06 (Asia/Bangkok). This milestone creates unpaid orders and scoped history only. No payment attempt, cash settlement, KHQR, inventory record, stock change, paid receipt or Flutter/UI implementation.

## Phase 3.0 baseline

Clean main at cbb263a70fd02e380d7647f6cac10da7f8322d39, matching GitHub main. Existing authentication/catalog implementations and the six project skills were inspected. Composer validation/lint passed; SQLite baseline: 96 passed / 762 assertions, four MySQL-only tests skipped. Route inventory: 12 entries. Previous [CI run 37435633859](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/37435633859) completed successfully; read-only inspection, no remote rerun.

## Decision freeze and design

- USD scale 2, signed BIGINT cents, discount/tax zero, no conversion or implicit rounding. Maximum 50 distinct lines and quantity 1-99; product prices retain the Phase 2 0-999999 cap. Maximum possible subtotal is 4949995050 cents, well within signed BIGINT; application arithmetic is checked before multiplying/adding.
- Only product_id/quantity in item intent; strict JSON integers. Idempotency-Key is a required, case-sensitive ASCII header, 8-64 characters, first alphanumeric then alphanumeric/dot/underscore/hyphen. No competing body key transport was previously approved. Hash version 1 canonicalizes sorted product IDs/quantities plus fixed USD context; prices and secrets are excluded.
- New orders are pending_payment and inventory_tracked=false. No future payment FKs/expiry/paid columns are added. Existing documented lifecycle states remain enum/database values for later milestones, without transition APIs here.
- Product primary keys in ascending order receive shared locks, then their actual category IDs in ascending order receive shared locks. This prevents catalog mutations during snapshot creation, allows concurrent readers, and matches Product update -> category FK lock direction. Rows are looked up by PK individually to make acquisition order explicit. No user/provider/stock I/O under these locks. Local transaction has at most three deadlock attempts.
- UNIQUE(created_by,checkout_key) arbitrates concurrent replay; catch the losing insert outside its rolled-back transaction, load the committed winner and compare the canonical hash. Same intent returns original snapshot even if current catalog changed; changed intent is 409. No missing-key gap lock or per-actor serialization of unrelated checkouts.
- Public order URIs use ORD-ULID rather than numeric IDs. Order reads scope the query before lookup and additionally enforce OrderPolicy. Cashiers see own orders; managers/admins see the shop. History uses UTC absolute timestamp boundaries and deterministic created_at DESC/id DESC.

## Incremental results: Phases 3.1-3.9

- **3.1-3.3 schema/models:** two additive migrations, OrderStatus, guarded Order/OrderItem, relations and synthetic factories. Initial OrderSchemaTest: 13 passed / 24 assertions; 11 MySQL CHECK cases skipped on SQLite. Subsequent tests add raw parent-delete FK restriction and UTC physical epoch verification. No future payment FK/expiry/paid columns or stock table.
- **3.4 contract:** CheckoutRequest strictly allows only items; nested lines allow product_id/quantity; header replay key validated separately. Cart/list/quantity/duplicate/header/property attacks covered, including malicious top-level names resembling nested wildcard rules.
- **3.5 service:** authoritative current product/category reads under deterministic shared PK locks; exact checked integer calculation; unique ORD-ULID; immutable item rows; all-or-nothing transaction. Controlled second-item failure leaves zero orders/items and retry can reuse the key.
- **3.6 replay:** canonical sorted intent, version 1 / USD context, per-actor case-sensitive key. 201 first / 200 replay / 409 changed intent. Replays retain old snapshots after rename/price/retirement. Fresh winner comparison happens outside rollback on uniqueness or concurrent catalog-validation failure.
- **3.7-3.9 policy/history/resources:** cashier own query scope before lookup + OrderPolicy; manager/admin shop reads; missing/unowned reference returns identical 404. Only create/list/detail routes. Absolute UTC inclusive filters, ordered/paginated history, eager item/creator queries and exact string Resources; key/hash/credentials absent.

## Phase 3.10-3.12: security and real MySQL evidence

The server is MySQL 8.0.39 on 127.0.0.1:33381, initialized with --no-defaults and its own ignored data directory `apps/backend/storage/framework/testing/orders-mysql-20261006`. @@datadir was verified before database creation/upgrade and worker use. Existing normal MySQL service/database was not mutated. `coffee_management_auth_test` is the guarded disposable PHPUnit target; `coffee_management_order_upgrade_test` separately verifies additive rollout.

Concurrency tests use eight scenarios with independent PHP processes/connections and explicit barriers (no pcntl/new test dependency). Worker processes receive only selected test DB configuration/synthetic intent over stdin, print public outcome/counters, verify exact host/database/datadir, and never migrate/reset. Performance Schema lock waits are observed, not inferred from a sleep:

1. Same actor/key/same cart: both transactions pass the initial missing-order check and attempt insertion; exactly one 201 and one 200, same reference, one order/item. Loser has a second fresh winner read.
2. Same actor/key/different quantities: both attempt insertion; one 201, one 409; no second order.
3. Price writer first: checkout is observed waiting on an InnoDB row lock; after writer commits, snapshot uses the new 700-cent price.
4. Product retirement writer first: observed lock wait, then 422 and zero order/item rows.
5. Category retirement writer first: observed lock wait, then 422 and zero order/item rows.
6. Checkout reader first: later price writer waits until checkout commits; snapshot stays 325 while catalog becomes 700.
7. Unselected product in another category can update while checkout holds selected catalog locks; no table-wide/unrelated row locking.
8. Winner commits after a waiter's old replay read, then product retires: waiter rolls back catalog validation and loads the committed original, 200; one order/item.

The first seven passed **7 tests / 40 assertions**; the added retirement/replay race adds six assertions. These are correctness/race scenarios, not a throughput or deadlock stress benchmark. Local transactions retry deadlocks at most three times; direct no-provider workflows are retry-safe.

MySQL schema verification covers RESTRICT creator/product/order FKs, unique reference, actor/key (case-sensitive), item line/product uniqueness, exact signed BIGINT money columns, lifecycle/currency/money/quantity CHECKs and query indexes. Cross-row sums/at-least-one item are service invariants. SQLite omits production CHECKs and lock/physical-timezone guarantees.

### UTC finding and correction

The native local server reports SYSTEM / SE Asia Standard Time by default. Laravel MySQL connection now explicitly sets +00:00, verified by both @@session.time_zone and UNIX_TIMESTAMP(created_at) matching the intended UTC epoch. No shared-data conversion/backfill occurs. Before deployment, audit legacy timestamp interpretation if previous writes used a non-UTC session; the fresh upgrade fixture does not prove correctness of such legacy misinterpreted timestamps.

History initially exposed SQLite text comparison of whole seconds against a .000000 lower boundary; normalized zero-fraction boundaries now preserve inclusive equality and nonzero fractional boundaries remain precise. Calendar/offset validation rejects impossible dates, timezone-less/date-only input, leap-second normalization and malformed/out-of-range offsets.

### Additive upgrade

Created the separate verified upgrade DB. Migrated the eight existing Phase 2 migrations, seeded roles, inserted synthetic active manager/token/category/product data, then applied the two Orders migrations. All ten migrations show ran. Assertions preserve staff name/role/status/token presence and product name/category/325-cent price; an upgraded checkout successfully creates a pending untracked 650-cent order. No old migrations or Auth/Catalog implementation were rewritten.

### Representative history plans

EXPLAIN on 1000 synthetic orders / five actors in a rolled-back transaction:

| Query | Selected index / observation |
| --- | --- |
| Cashier own history | orders_created_by_created_at_id_index; backward index scan, actor filter |
| Manager/admin shop history | orders_created_at_id_index; backward index scan, limit 25 |
| Status-filtered history | orders_status_created_at_id_index; backward index scan |

No filesort reported for these queries. Money columns in both tables verified as signed BIGINT. History selects/eager item/creator query count remains constant for pages of one versus 20 orders (<=9 total queries including authentication/token work). Shop-scale synthetic plans are not production p95 measurements.

## Phase 3.13-3.14: synchronized docs and final gates

| Command/check | Final result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer lint` | Passed |
| `composer test` | SQLite: **147 passed / 1064 assertions; 24 skipped** |
| `php vendor/bin/phpunit --configuration phpunit.mysql.xml --no-progress --colors=never` with DB_PORT=33381 | MySQL: **170 passed / 1123 assertions; 1 skipped**, 171 total cases |
| `php artisan route:list --json` | 15 route entries; only three Orders routes added |
| OpenAPI JSON/reference/route parity | 10 paths / 17 explicit operations; 84 refs resolve; exact parity excluding implicit HEAD |
| Documentation link/fence check | 60 local links resolve; balanced fences; eight Mermaid source blocks |
| `git diff --check`, staged/protected paths and credential-marker check | Passed; no staged changes, Flutter edits, dependency changes or Auth/Catalog redesign |

SQLite skips: four existing Product CHECK cases, eleven Order CHECK cases, eight real MySQL concurrency cases and one physical UTC test. MySQL skips only the SQLite-specific corrupt-catalog fixture because MySQL CHECKs prevent constructing it. AuthMigrationUpgradeTest explicitly uses its own SQLite connection even within the MySQL suite; real Phase 2->3 upgrade is separately evidenced above.

Orders API/OpenAPI document actual create/replay/status/errors/history/resources. Requirements mark backend unpaid checkout/history only implemented. ERD retains its business structure; TRD explicitly separates the Phase 3 physical tables from later payment-selection/expiry columns. DFD/flowchart captions identify the implemented 3.1-3.5 and 3.8 subset; payment/inventory branches stay proposed. Fixed zero tax/discount and no options are the user's Phase 3 freeze, not guessed future financial rules.

### Separate specialty reviews

| Skill/reviewer | Review outcome |
| --- | --- |
| Architect / practical-system-design | DFD scope and service match unpaid checkout/history; no payment, inventory, receipt or Flutter responsibility leaked in; one purposeful workflow service |
| Database / mysql-design | Exact bounded arithmetic/signed BIGINT, immutable snapshots, RESTRICT FKs, useful query indexes, short local transactions, per-actor uniqueness and real shared-lock races verified |
| Laravel / laravel-rest-api | Conventional Request/Resource/Policy/Controller/service/model/enum/factory boundaries, no generic repositories/services, no new package |
| Security / api-payment-security | Scoped lookup plus policy prevents BOLA; direct/nested/wildcard-shaped property injection rejected; keys/carts/pagination/time bounded; no secret/internal serialization; unavailable catalog fails closed |
| QA / risk-based-qa | Real bearer HTTP paths, rollback state, replay conflict, max 64-bit total, accurate dates, separate processes/barriers/observable waits, and all Auth/Catalog regressions |
| Git / preserve-git-workflow | Clean main at baseline; all changes unstaged; single root repo; only Phase 3 code/docs plus necessary UTC session correction; no credentials/generated DB files/Flutter/dependencies/external mutation |

Test harness corrections: renamed a helper that collided with PHPUnit's final result() method; used Laravel's actual beforeRefreshingDatabase hook for MySQL-only skips; process status polling now pumps asynchronous GO input before observing locks. Production lock rules were not weakened to accommodate harness failures. Review fixed the concurrent winner/retirement replay edge and the root-field wildcard-name allowance; each has a regression.

References checked against installed framework and official [Laravel transactions](https://laravel.com/framework/docs/13.x/database), [validation](https://laravel.com/framework/docs/13.x/validation) and [MySQL locking reads](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html). OpenAPI was parsed/reference/parity-checked, not certified by an added specification validator. Mermaid source/fences checked; no renderer installed/run.

## Rollout, remaining decisions and stop boundary

Migrate only after verifying target/backup; destructive down migrations are not cancellation. Model instance update/delete guards protect history but trusted raw SQL/query-builder operations bypass Eloquent events. Future Phase 4 must introduce an authorized status workflow while preserving order amounts/snapshots; it must not simply expose arbitrary Order updates. No speculative DB trigger framework is added.

Pending orders do not expire/cancel/pay automatically; inventory is explicitly untracked. Currency/zero tax/discount/no options are resolved for Phase 3; future tax/discount/option/receipt/business-reporting timezone/provider rules remain separate decisions. No paid receipt, cash, KHQR, callback, settlement, stock ledger, Flutter or report is implemented. Recommended next scope: Phase 4 cash/payment attempts and atomic verified settlement with idempotency, provider-specific authenticity/amount/currency/merchant checks, uncertain-outcome recovery and reconciliation, separately authorized.

Only the existing Phase 2 CI result was inspected. New work was not committed/pushed, no remote CI rerun/deploy/provider request. Disposable MySQL server was shut down after checks; its ignored synthetic data remains under the new test directory. Existing MySQL80 service remained running. Recursive cleanup was not retried after the earlier Phase 1 policy rejection.

## Complete changed/created path manifest

42 task paths; the replaced Services/.gitkeep is removed. All other paths are created/modified for Phase 3.

```text
README.md
apps/backend/app/Enums/OrderStatus.php
apps/backend/app/Http/Controllers/Api/V1/OrderController.php
apps/backend/app/Http/Requests/Orders/CheckoutRequest.php
apps/backend/app/Http/Requests/Orders/OrderIndexRequest.php
apps/backend/app/Http/Resources/OrderItemResource.php
apps/backend/app/Http/Resources/OrderResource.php
apps/backend/app/Models/Order.php
apps/backend/app/Models/OrderItem.php
apps/backend/app/Policies/OrderPolicy.php
apps/backend/app/Rules/AbsoluteTimestamp.php
apps/backend/app/Services/.gitkeep
apps/backend/app/Services/OrderCheckoutService.php
apps/backend/config/database.php
apps/backend/database/factories/OrderFactory.php
apps/backend/database/factories/OrderItemFactory.php
apps/backend/database/migrations/2026_10_06_000006_create_orders_table.php
apps/backend/database/migrations/2026_10_06_000007_create_order_items_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/CheckoutTest.php
apps/backend/tests/Feature/OrderConcurrencyTest.php
apps/backend/tests/Feature/OrderHistoryTest.php
apps/backend/tests/Feature/OrderSchemaTest.php
apps/backend/tests/Support/order-worker.php
docs/api/README.md
docs/api/openapi.json
docs/api/orders.md
docs/architecture/README.md
docs/database/README.md
docs/project/roadmap.md
docs/project/verification.md
docs/system-analysis/README.md
docs/system-analysis/backend-plan.md
docs/system-analysis/business-rules.md
docs/system-analysis/dfd-level-1.md
docs/system-analysis/dfd-level-2.md
docs/system-analysis/erd.md
docs/system-analysis/flowcharts.md
docs/system-analysis/phase-3-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```
