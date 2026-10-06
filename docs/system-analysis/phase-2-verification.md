# Phase 2: Categories and Products verification

Date: 2026-10-06 (Asia/Bangkok). This record distinguishes each incremental phase from the earlier [Phase 1 verification](verification.md).

## Phase 2.0 baseline

- Branch `main`, HEAD `580d94f97d04937c6b463e2408e7c8651f0b3351`; tracked, staged and untracked state clean before edits.
- Laravel 13.34.0 / PHP 8.4.4, Sanctum 4.3.3 and existing auth/access implementation inspected. No catalog schema or endpoint existed.
- `composer validate --strict`, `composer lint`, `composer test`: passed; **33 tests / 263 assertions**. `php artisan route:list`: three auth routes plus `/up`.
- Read-only GitHub API inspection: [CI run 37429792563](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/37429792563) for the exact Phase 1 SHA completed successfully. No remote rerun or CI mutation.
- Six project architecture/Laravel/database/security/QA/Git skills applied. Existing auth retained; no Flutter/UI, Orders, payments or inventory implementation authorized.

## Phase 2.3 currency decision

The existing analysis had no approved selling currency. During this task, the user explicitly selected **USD with two decimal places**. Catalog prices therefore use exact integer cents stored in signed BIGINT, serialized/accepted as canonical decimal integer strings. There is no conversion, exchange rate or floating-point calculation. Submitted fractional cents are rejected rather than rounded. Tax, discounts, option pricing and checkout rounding remain Phase 3 decisions.

## Incremental implementation and checks

## Phase 2.1: Category domain / database

Created the additive Category migration/model/factory with only id, name, is_active and timestamps. Duplicate names remain allowed. Active browsing orders by name/id and uses (is_active,name,id). No soft deletes or speculative display fields. The initial `php artisan test --filter=CategorySchemaTest` passed **5 tests / 10 assertions** before Category APIs or Product implementation began.

## Phase 2.2: Category API

Created CategoryPolicy, store/update/index Requests, CategoryResource and Api/V1 CategoryController. Routes reuse existing Sanctum, active-staff and staff-ability middleware. Manager/admin mutations and retired reads are authorized through existing gates; cashier reads active records. No DELETE route; retirement/reactivation is is_active. Strict write/query fields, nonempty updates, stable pagination and bounded literal search are tested. `php artisan test --filter='CategoryApiTest|CategorySchemaTest'` passed **19 tests / 126 assertions** before Product implementation.

## Phase 2.4: Product domain / database

Added Product migration/model/factory, category relationship and sellability rule. Price storage is signed BIGINT; initial administrative API/DB cap is 999999 cents ($9,999.99). Category FK is RESTRICT. SKU is case-insensitive unique and API-normalized to uppercase ASCII; SQLite NOCASE approximates the MySQL utf8mb4_unicode_ci SKU behavior for the approved ASCII alphabet. Currency is CHAR(3) / utf8mb4_bin with exact USD CHECK on MySQL.

The initial ProductSchemaTest passed **7 tests / 16 assertions**, with four MySQL-only CHECK tests intentionally skipped on SQLite. A later model mass-assignment test adds coverage. Product migration requires MySQL >=8.0.16 before table creation; no shared/old migrations were edited.

## Phase 2.5: Product API

Implemented ProductPolicy, store/update/index Requests, ProductResource and Api/V1 ProductController. Manager/admin create/update/retire/reactivate; all staff browse sellable products. Manager/admin can maintain a product under a retired category; it remains non-sellable. ProductResource returns exact price strings and a minimal category summary. Unknown internal properties and invalid monetary/currency/ID/string inputs are rejected. The initial `php artisan test --filter=ProductApiTest` passed **28 tests / 280 assertions**.

## Phase 2.6-2.7: queries and security

- Category filtering, literal name/SKU search (80 characters), status filters limited by role, default page size 25 / max 100 / page max 10000, fixed name+id ordering.
- Product and category retirement independently remove products from the sellable menu; manager filters cannot leak into cashier reads. Cashier hidden detail = 404, prohibited mutation = 403.
- Product categories are eager-loaded once per page; SELECT count is constant between 1 and 20 returned products and total query count stays <=8 including identity/token work. Sanctum may omit a last_used_at update within the same timestamp second; that write is not an N+1 read.
- Replayed/colliding SKU writes after validation return 422 through the unique constraint catch. Deterministic tests interleave a competing write for create/update; they do not claim a load/concurrency benchmark.
- Numeric path constraints prevent MySQL coercing an ID such as 1suffix to record 1. Model mass assignment excludes id/ownership/derived/privilege fields. Form Requests reject unknown body/query fields, bound values and fixed SQL identifiers prevent injection.
- Review fixed the PHP falsy-search edge case for the valid term "0". Query instrumentation was corrected to distinguish a primary categories fetch from EXISTS subqueries and optional token timestamp writes; no production query behavior was weakened to satisfy tests.

## Phase 2.8: isolated MySQL evidence

Existing MySQL 8.0.39 executable; new data directory `apps/backend/storage/framework/testing/catalog-mysql-20261006`, loopback 127.0.0.1:33380, no normal-service configuration loaded. @@datadir was verified before creating test databases. `coffee_management_auth_test` uses the existing guarded MySQL PHPUnit configuration; a separate `coffee_management_catalog_upgrade_test` checks additive rollout. Synthetic data only; no shared/application database was reset.

- Full feature suite on MySQL: **100 tests / 766 assertions**, no skipped CHECK cases. AuthMigrationUpgradeTest itself deliberately uses its own SQLite connection; catalog upgrade was separately exercised on real MySQL.
- Verified FK restriction, case-insensitive SKU uniqueness, both query indexes and four direct invalid-money CHECK cases (negative/excessive price, KHR, lowercase usd).
- information_schema confirms price_minor=BIGINT signed, category_id=BIGINT UNSIGNED, currency=CHAR(3) utf8mb4_bin, SKU=VARCHAR(64) utf8mb4_unicode_ci; both product CHECK clauses exist.
- Upgrade: migrate the six Phase 1 migrations, seed roles, insert synthetic active admin identity and existing token hash, apply the two catalog migrations. All eight migrations report ran; exact name/email/password/role/status/token preservation assertions pass.
- EXPLAIN on 20 synthetic categories / 1000 products in a rolled-back transaction: active category query uses categories_is_active_name_id_index (covering); unfiltered menu uses products_is_active_name_id_index and PK category lookups; filtered menu uses products_category_id_is_active_name_id_index; no filesort reported for these menu queries.
- Literal substring search uses the active index but still examines candidate rows; no claim of index-accelerated substring lookup. Shop-scale evidence does not establish production p95/SLA. No cache, FULLTEXT or new package added.

## Phase 2.9: contracts and final checks

| Command/check | Result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer lint` | Passed |
| `composer test` | **96 passed / 762 assertions; 4 MySQL-only tests skipped** on SQLite :memory: |
| `php vendor/bin/phpunit --configuration phpunit.mysql.xml --no-progress --colors=never` with DB_PORT=33380 | **100 passed / 766 assertions** on disposable MySQL 8.0.39 |
| `php artisan route:list --json` | 12 route entries, including existing auth/health; catalog GET/POST/PUT/PATCH only, no DELETE |
| OpenAPI parse / reference walk / bidirectional route inventory comparison | 8 paths / 14 explicit operations; 66 local refs resolve; exact method/path parity (HEAD implicit) |
| Local documentation links / fences | 55 links resolve; fences balanced; eight Mermaid sources remain |
| `git diff --check` / staging / protected-file comparison | Passed; staging empty as at baseline; Auth implementation, Flutter, Composer manifest/lock unchanged |

API README, catalog contract and OpenAPI synchronize actual endpoints, requests/resources/statuses. Requirements mark only catalog behavior implemented; cart/order/stock remain planned. ERD business structure is retained. TRD legitimately records USD approval, an additional unfiltered-menu index justified by real query plans, production CHECKs, exact SKU/currency collations and the new MySQL minimum.

Laravel APIs were checked against installed Laravel 13 and [official validation](https://laravel.com/framework/docs/13.x/validation)/[Resources](https://laravel.com/framework/docs/13.x/eloquent-resources). The minimum CHECK version follows [official MySQL documentation](https://dev.mysql.com/doc/refman/8.0/en/create-table-check-constraints.html). OpenAPI JSON/reference/parity checks are not a full third-party specification certification; no diagram renderer was installed or run.

## Separate self-review passes

| Reviewer / project skill | Outcome |
| --- | --- |
| Architect / practical-system-design | Catalog boundaries match requirements, shared staff roles and documented lifecycles; no Inventory/POS/Orders responsibilities or generic service/repository layer |
| Database / mysql-design | Signed exact money, RESTRICT FK, query-supported indexes, SKU/currency collations and CHECK enforcement verified on MySQL; Phase 1 upgrade preserved |
| Laravel / laravel-rest-api | Thin conventional controllers, Requests/Resources/Policies, Eloquent scopes/relations and resource routes; authentication reused unchanged; no new package |
| Security / api-payment-security | Cashier write/retired-read denial, live staff/ability checks, numeric route IDs, strict fields and exact price validation; N+1 and pagination abuse covered; SKU race handled |
| QA / risk-based-qa | Positive/negative paths, direct schema assertions, real bearer tokens, fake/interleaved race regression and Auth regressions; SQLite/MySQL limits explicit |
| Git / preserve-git-workflow | Baseline clean main; all changes unstaged; no user work/staging touched; no secrets/generated files/dependencies/Flutter changes; no commit/push/deploy/external mutation |

## Limits, rollout and next phase

Apply additive migrations only after verifying the dedicated deployment/development database and backup. Downgrading catalog migrations deletes catalog data and is not an ordinary retirement operation. Runtime API retirement preserves records; future order history will require its planned restrictive FKs and immutable snapshots.

Tax/discount/checkout rounding, store business timezone/receipt numbering, stock rules and provider remain open. USD/scale 2 is resolved for catalog. Phase 3 Orders + POS Checkout remains a separate authorized task; no Phase 3 code exists here. No frontend/UX, payment calls or deployment occurred. Only the previous Phase 1 CI result was inspected; Phase 2 changes were not pushed and no remote CI was triggered.

The disposable catalog MySQL server was shut down after verification; its ignored synthetic data files remain under the test directory. Existing MySQL80 service stayed running. No recursive cleanup was attempted; earlier directory cleanup had already been rejected by automatic approval review in Phase 1.

## Complete changed/created file manifest

All 43 paths below belong to this milestone. No unrelated or staged work existed at baseline.

```text
README.md
apps/backend/app/Http/Controllers/Api/V1/CategoryController.php
apps/backend/app/Http/Controllers/Api/V1/ProductController.php
apps/backend/app/Http/Requests/Catalog/CategoryIndexRequest.php
apps/backend/app/Http/Requests/Catalog/ProductIndexRequest.php
apps/backend/app/Http/Requests/Catalog/StoreCategoryRequest.php
apps/backend/app/Http/Requests/Catalog/StoreProductRequest.php
apps/backend/app/Http/Requests/Catalog/UpdateCategoryRequest.php
apps/backend/app/Http/Requests/Catalog/UpdateProductRequest.php
apps/backend/app/Http/Requests/Concerns/RejectsUnknownFields.php
apps/backend/app/Http/Resources/CategoryResource.php
apps/backend/app/Http/Resources/ProductResource.php
apps/backend/app/Models/Category.php
apps/backend/app/Models/Product.php
apps/backend/app/Policies/CategoryPolicy.php
apps/backend/app/Policies/ProductPolicy.php
apps/backend/database/factories/CategoryFactory.php
apps/backend/database/factories/ProductFactory.php
apps/backend/database/migrations/2026_10_06_000004_create_categories_table.php
apps/backend/database/migrations/2026_10_06_000005_create_products_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/CatalogQueryTest.php
apps/backend/tests/Feature/CategoryApiTest.php
apps/backend/tests/Feature/CategorySchemaTest.php
apps/backend/tests/Feature/ProductApiTest.php
apps/backend/tests/Feature/ProductSchemaTest.php
apps/backend/tests/Feature/ProductWriteRaceTest.php
docs/api/README.md
docs/api/catalog.md
docs/api/openapi.json
docs/architecture/README.md
docs/database/README.md
docs/project/roadmap.md
docs/project/verification.md
docs/system-analysis/README.md
docs/system-analysis/backend-plan.md
docs/system-analysis/business-rules.md
docs/system-analysis/dfd-level-1.md
docs/system-analysis/erd.md
docs/system-analysis/phase-2-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```
