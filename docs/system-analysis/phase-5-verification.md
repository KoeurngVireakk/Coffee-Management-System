# Phase 5 verification: inventory and stock reservations

Date: 2026-10-06, Asia/Bangkok. Authorized inventory/recipe/reservation/settlement/cancellation milestone, with all 11 canonical skills assigned across the team. Commit and push to main authorized after the complete gate. No Flutter implementation or real provider traffic; stop before Phase 6.

## Baseline

Clean main at 4ff2b8034fbc9031ad15f66386219ab13bb462ed, matching origin/main. [Exact Phase 4 CI](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/37461956910) completed successfully. Composer manifest/formatting passed, baseline SQLite186passed/36skipped/1330assertions;19routeentries. Original migrations and Auth/Catalog APIs preserved.

## Decisions and assigned responsibilities

Inventory owns exact stock balance/ledger/reservation changes. Checkout reserves; shared OrderSettlementService consumes on payment acceptance; manual cancellation releases only after safe payment state. Deployment config defaults disabled, historical tracking flags remain immutable, and a later switch does not rewrite old orders. Quantities use checked four-place integer arithmetic and DECIMAL(14,4), with g/ml/unit and no conversions. Opening balances must enter through append-only movements.

Root orchestrates architecture, integration, documentation and publication. inventory_schema implements and reviews quantity/schema/model integrity; inventory_api implements inventory/recipe/manual endpoints and reviews Laravel/security/client contracts; inventory_qa implements integration/concurrency/consistency verification and reviews evidence/CI. Separate final passes will record every canonical skill's findings against the actual complete diff. Tests and final evidence follow execution below.

## Incremental milestone outcomes

| Scope | Implemented outcome |
| --- | --- |
| Decision freeze / cutover | Deployment config false by default; historical flags immutable, no backfill; already-tracked orders still finalize with gate disabled |
| Schema / exact arithmetic | Four additive tables, DECIMAL(14,4), restricted history FKs, composite recipe/reservation PKs, unique SKU/manual/sale identities, MySQL CHECKs; checked native integer arithmetic rejects float coercion |
| Metadata / availability | Zero starting stock, immutable base unit, retire/reactivate, safe exact resources and bounded literal browse/low-stock filters |
| Recipes | Management complete replacement, positive unique active ingredients, product exclusive/shared synchronization with current checkout recipe reads |
| Opening / manual movements | Opening only before any movement history, permitted sign/note rules, management authorization, ledger/balance atomicity and actor-key semantic replay across items |
| Reservations / checkout | Exact multiply/aggregate, sorted stock locks, positive snapshots and reserved increment atomically with order/items; no stock work with gate disabled |
| Shared paid finalization | Confirmed owning exact payment and no review flag; payment/order/stock/sales/snapshots commit together; no duplicate consumption on replay |
| Cancellation / release | Authorized safe pending own/shop order only; unresolved/active/review payments block release; reserved decreases once, on_hand unchanged; repeat cancelled result safe |
| Reconciliation | Independent consistent read-only audit, ledger and reserved sums, tracked lifecycle/sale identity/delta checks, full finding_count with at most100 diagnostic samples; no repair |
| APIs / contracts | Inventory/recipe/movement/cancel operations, exact string resources, OpenAPI parity and future client error/state review |
| Publication | Normal main commit/push authorized only after final gates, manifest review and remote synchronization; CI checked after publication |

The shared finalizer review found that a confirmed payment requiring reconciliation could otherwise be accepted by a direct service call. Guarded finalization and Order acceptance now reject it. A newly matching second observation after earlier mismatched funds is retained as confirmed/review with both observations and no stock acceptance. This is a narrow payment-integrity correction needed at the new stock boundary; ordinary historical untracked cash/single-verification behavior remains unchanged. Two negative regressions cover the correction. An obsolete Phase 3 assertion that cancellation returned404 was updated for the authorized Phase 5 route; generic PUT/PATCH/DELETE, legacy pay, refund and receipt absence assertions remain.

## Isolated MySQL upgrade and query evidence

MySQL8.0.39 bound127.0.0.1:33383 with dedicated ignored datadir apps/backend/storage/framework/testing/inventory-mysql-20261006. Verified @@datadir before creating coffee_management_auth_test and coffee_management_inventory_upgrade_test; shared MySQL80 was not reset. After the final gate, this verified disposable server was shut down and MySQL80 remained running. Workers recheck exact instance/database and use synthetic stdin fixtures; no provider network requests. Dedicated files stay ignored and are retained, not published.

Upgrade fixture created all13 Phase4 migrations then synthetic role/staff/token/catalog/pending and paid orders and a pending external attempt. Four additive Phase5 migrations brought the total to17; exact rows in users, roles, personal_access_tokens, categories, products, orders, order_items and payments were preserved. After enabling tracking, historical pending cash and fake-external orders settled without any reservation/sale. A new tracked order reserved5.0000 from10.0000 and consumed it to5.0000 on_hand /0.0000 reserved; read-only audit reported0 findings. Original Phase1?4 migrations remain unchanged. This is a verified upgrade on a disposable database, not deployment/backup validation.

Physical information_schema inspection confirmed all six quantity columns across the four tables are DECIMAL(14,4). EXPLAIN used synthetic1001 stock rows/102 movement rows within a rolled-back transaction. Optimizer chose ALL/filesort for active/all browse and ledger history, is_active_name_id range plus residual expression for low stock, and PRIMARY ref for recipe/reservation lookup. These results are reported as measured plans; no forced-index or production performance claim. Browse/movement indexes remain aligned with filters/order, but production selectivity and scale need measurement before further tuning.

## Concurrency and rollback evidence

Fourteen independent-process MySQL cases observe actual InnoDB waits and assert persisted balances/order/reservation/sale outcomes: last-stock checkouts; checkout vs negative adjustment in both directions; two adjustments without lost updates; checkout vs complete recipe replacement; same-item manual retry; cross-item global actor/key conflict with loser rollback; cash vs cancellation in both directions; external confirmation vs cancellation; cancellation vs late trusted external confirmation after prior failure; duplicate cash key; duplicate verified result; two different payments on one tracked order. This covers every requested race category. Deadlock retry remains three local attempts; no provider I/O under SQL locks.

Failure injection covers recipe deletion/replacement rollback, movement insertion/balance rollback, partial second reservation failure, cash sale/order failure, fake verified external sale/order failure, and cancellation terminal-write failure. Expected absence of partial accepted payment, sale, consumed/released snapshot and stock balance change is asserted. Read-only diagnostics pass healthy pending/paid/cancelled fixtures and report five raw corruption modes without repair. SQLite fast coverage is not evidence of MySQL lock or CHECK behavior.

## Separate final reviews: all 11 canonical skills

Real sub-agent collaboration used inventory_schema, inventory_api and inventory_qa under the root orchestrator. Findings were challenged across schema/API/security/QA and fixed before release. Final passes inspected actual changed/untracked code and documentation; they do not claim an external compliance certification.

| Canonical skill | Assigned review and final evidence |
| --- | --- |
| [Practical system design](../../.agent/architecture/practical-system-design/SKILL.md) | Root/schema: inventory ownership, checkout reservation, shared paid finalization, safe cancellation, cutover and I/O boundaries. No supplier/warehouse/multi-store scope or frontend added. |
| [Evidence-based code review](../../.agent/architecture/evidence-code-review/SKILL.md) | QA/root: complete actual diff/callers/tests; fixed quarantined-payment finalizer gap and inaccurate stale documentation. No remaining material code finding in reviewed scope. |
| [Laravel REST API](../../.agent/laravel/laravel-rest-api/SKILL.md) | API/root: thin controllers, strict Requests, safe Resources, policy/gate checks, ordinary Eloquent and focused workflows; no generic repositories/new packages. |
| [MySQL design](../../.agent/database/mysql-design/SKILL.md) | Schema/root: exact native arithmetic/DECIMAL, FK/PK/UQ/CHECK, lock order, additive upgrades and candid query plans. Fixed native float coercion and unused index choice. |
| [API/payment security](../../.agent/cybersecurity/api-payment-security/SKILL.md) | API/QA/root: BOLA, actor/balance/sale injection, global manual idempotency, reserved floor and trusted settlement review guard; no secret or raw provider logging. |
| [Risk-based QA](../../.agent/testing/risk-based-qa/SKILL.md) | QA: negative paths, deliberate rollback, 14 InnoDB waits plus persisted effects, consistency diagnostics and full Phase1?4 regression. |
| [Preserve Git workflow](../../.agent/git/preserve-git-workflow/SKILL.md) | Root: clean baseline/staging, exact Phase5 manifest, protected paths/credentials/artifacts scan, normal authorized main publication, no force/history rewrite. |
| [Safe CI maintenance](../../.agent/devops/safe-ci-maintenance/SKILL.md) | QA/root: existing jobs discover new tests, verified disposable workers/fakes, unchanged workflow and mobile job; no disabled/weak CI or new dependency. |
| [Feature-first Flutter](../../.agent/flutter/feature-first-flutter/SKILL.md) | API/QA contract-only: four-place strings/units and authoritative order/stock status usable for future data/domain mapping and retry intent; no Flutter code. |
| [Accessible Cambodian POS](../../.agent/ux-ui/accessible-cambodian-pos/SKILL.md) | API/QA workflow-only: explicit available/low_stock/inactive values, field422 vs conflict409, retained intent and safe cancellation outcomes support future readable stock feedback. No UI/accessibility conformance claim. |
| [Intentional frontend design](../../.agent/frontend/intentional-frontend-design/SKILL.md) | API/QA data-contract-only: loading/empty/permission/validation/conflict/retry states supported; existing Flutter direction retained, no React or other surface introduced. |

Review also corrected note500/schema agreement, empty-update minProperties and HTTP middleware whitespace normalization documentation. Cashier cannot read management-only recipes; catalog has no per-product stock availability read model, explicitly retained as a future contract limit rather than redesigning Phase2 resources.

## Known limits and recommended next scope

Tracking defaults false until deployment explicitly prepares opening balances/recipes/audit and enables it. Abandoned reservations require safe manual cancellation; no automatic timeout/expiry policy or repair job. Audit is CLI-only and reports inconsistencies without correction; access and production backup/cutover need operational controls. No suppliers/warehouses/lots/automatic conversion, paid refund/void or receipt printing. Real external/KHQR remains disabled503; approved official provider contract and durable payment recovery are separate prerequisites. Flutter/UI and bilingual verified messages/per-product availability display remain later work.

Recommended Phase6 is separately authorized staff provisioning/role changes/activation/password recovery/token revocation/last-admin protections, typed settings and immutable admin audit, with these same11 review perspectives. Settings must not silently replace the inventory deployment gate. Stop after Phase5; no Phase6 implementation has started.

## Final local release gate

PHP8.4.4, Composer2.8.11, Laravel13.34.0 and PHPUnit12.5.37, existing locked dependencies only.

| Check | Final result |
| --- | --- |
| composer validate --strict | Passed |
| composer lint | Passed after final code/guard changes |
| composer test (SQLite) | 321passed,70MySQL-only skipped;1896assertions;9.10s |
| php vendor/bin/phpunit --configuration phpunit.mysql.xml --no-progress --colors=never (DB_PORT33383) | 360tests,359passed,1skipped;2134assertions;4m19.412s |
| Inventory independent MySQL races | All14 passed with observed InnoDB waits and persisted invariant checks |
| Additive Phase4 upgrade | 13->17 migrations, eight prior tables preserved, historical cash/external untracked compatibility and new tracked consumption verified |
| OpenAPI JSON/references/routes | Parsed;196localrefs resolve,19paths/31explicit operations match28routeentries; implicit HEAD excluded |
| Changed documentation | 94 local links verified, eight Mermaid sources/fences balanced; Mermaid render not performed |
| git diff --check | Passed |
| Git baseline before staging | main==origin/main at4ff2b80, no unexpected staged/unrelated work |
| Protected paths / credential marker scan | Passed; no mobile implementation/dependency/CI/original migration edits; ignored databases/artifacts excluded |

The initial full SQLite run found only the obsolete Phase3 cancellation-absence assertion; it was corrected for the new authorized route and the full suite rerun. Final code includes the two quarantined-payment guard regressions. Earlier targeted groups overlapped and are not summed as unique totals. The single MySQL skip is the existing corrupt-catalog-money checkout case because MySQL CHECKs already prevent that fixture; exact Phase5 migration upgrade ran separately above.

## Publication evidence and complete manifest

This file records the pre-publication gate and cannot contain its own eventual commit SHA. Authorized normal commit/push and exact new GitHub Actions outcome are reported in the final user response. Previous Phase4 CI is baseline evidence, not the Phase5 result. No history rewriting or Phase6 work.

Complete manifest:74files (29modified,45created). Includes only Phase5 source/config.example/test/documentation. The isolated database and upgrade fixture are ignored local verification artifacts.

```text
README.md
apps/backend/.env.example
apps/backend/app/Console/Commands/CheckInventoryConsistency.php
apps/backend/app/Http/Controllers/Api/V1/InventoryItemController.php
apps/backend/app/Http/Controllers/Api/V1/OrderController.php
apps/backend/app/Http/Controllers/Api/V1/RecipeController.php
apps/backend/app/Http/Controllers/Api/V1/StockMovementController.php
apps/backend/app/Http/Requests/Inventory/InventoryItemIndexRequest.php
apps/backend/app/Http/Requests/Inventory/ReplaceRecipeRequest.php
apps/backend/app/Http/Requests/Inventory/StockMovementIndexRequest.php
apps/backend/app/Http/Requests/Inventory/StoreInventoryItemRequest.php
apps/backend/app/Http/Requests/Inventory/StoreStockMovementRequest.php
apps/backend/app/Http/Requests/Inventory/UpdateInventoryItemRequest.php
apps/backend/app/Http/Requests/Orders/CancelOrderRequest.php
apps/backend/app/Http/Resources/InventoryItemResource.php
apps/backend/app/Http/Resources/StockMovementResource.php
apps/backend/app/Inventory/Quantity.php
apps/backend/app/Models/InventoryItem.php
apps/backend/app/Models/Order.php
apps/backend/app/Models/ProductIngredient.php
apps/backend/app/Models/StockMovement.php
apps/backend/app/Models/StockReservation.php
apps/backend/app/Policies/InventoryItemPolicy.php
apps/backend/app/Policies/OrderPolicy.php
apps/backend/app/Providers/AppServiceProvider.php
apps/backend/app/Services/CashPaymentService.php
apps/backend/app/Services/ExternalPaymentService.php
apps/backend/app/Services/InventoryConsistencyService.php
apps/backend/app/Services/InventoryItemService.php
apps/backend/app/Services/OrderCancellationService.php
apps/backend/app/Services/OrderCheckoutService.php
apps/backend/app/Services/OrderSettlementService.php
apps/backend/app/Services/RecipeService.php
apps/backend/app/Services/StockMovementService.php
apps/backend/app/Services/StockReservationService.php
apps/backend/config/inventory.php
apps/backend/database/factories/InventoryItemFactory.php
apps/backend/database/migrations/2026_10_06_000011_create_inventory_items_table.php
apps/backend/database/migrations/2026_10_06_000012_create_product_ingredients_table.php
apps/backend/database/migrations/2026_10_06_000013_create_stock_reservations_table.php
apps/backend/database/migrations/2026_10_06_000014_create_stock_movements_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/InventoryApiTest.php
apps/backend/tests/Feature/InventoryConcurrencyTest.php
apps/backend/tests/Feature/InventoryConsistencyTest.php
apps/backend/tests/Feature/InventorySchemaTest.php
apps/backend/tests/Feature/InventoryWorkflowGuardTest.php
apps/backend/tests/Feature/InventoryWorkflowTest.php
apps/backend/tests/Feature/MovementApiTest.php
apps/backend/tests/Feature/OrderHistoryTest.php
apps/backend/tests/Feature/RecipeApiTest.php
apps/backend/tests/Support/InventoryFixtures.php
apps/backend/tests/Support/inventory-worker.php
apps/backend/tests/Unit/QuantityTest.php
docs/api/README.md
docs/api/inventory.md
docs/api/openapi.json
docs/api/orders.md
docs/api/payments.md
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
docs/system-analysis/phase-5-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```
