# Phase 4: Payment settlement foundation verification

Date: 2026-10-06 (Asia/Bangkok). Scope: payment attempts, atomic cash settlement, provider-neutral external verification/reconciliation foundation. No Inventory or Flutter/UI work. Commit/push to main is explicitly authorized after the full gate passes.

## Baseline

Clean main at 3acdc3ded850e010dc1c5c17589b34d56179bc94; GitHub main matches. Composer validate/lint passed; SQLite baseline 147 passed / 1064 assertions, 24 MySQL-specific skips; 15 routes. [Phase 3 CI run 37441998233](https://github.com/KoeurngVireakk/Coffee-Management-System/actions/runs/37441998233) completed successfully. Six project skills applied; existing Auth/Catalog/checkout preserved.

## Provider gate and decisions

No real bank/KHQR provider, merchant credentials, endpoints or callback authentication contract is approved in the repository. Production external routes therefore fail closed with 503 through an unconfigured adapter. A test-only fake exercises persisted initiation/verification/reconciliation; it is not Bakong/KHQR integration. No public callback, real provider traffic or invented signature contract.

One active unresolved external attempt blocks cash/new attempts until trusted verification resolves it. Order-first then Payment locks serialize settlement. Per-order attempt key/hash covers method and canonical tender; replay precedes paid-state checks. No client amount/currency/status/ownership/transaction-ID proof.

Payments retain attempts; append-only payment_evidence additionally retains verified transaction observations, including mismatches or a second distinct payment on an already-confirmed attempt. This table is justified by the requirement not to discard extra received-funds evidence; it is not a generic event log. Provider-scoped transaction identity is unique across observations. Matching and eligible evidence alone can become the accepted settlement; mismatches/late/duplicate identities are quarantined for reconciliation.

Cash tender cap is 9999999999 exact cents (administrative safety limit, above the existing maximum order total); amount/change never use float. Existing order/item snapshots remain immutable. Narrow transaction-only Order methods select/clear active attempt and accept a matching confirmed payment; arbitrary Order instance updates remain denied.

## Final local validation

PHP 8.4.4, Composer 2.8.11, Laravel 13.34.0, Sanctum 4.3.3 and PHPUnit 12.5.37; existing locked dependencies only. Changes were built incrementally: schema/owning selectors, cash, external DTO/workflow, failure/recovery/evidence, then independent-connection races and regression.

| Check | Result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer lint` | Passed, including new payment code/tests |
| `composer test` (SQLite) | 186 passed, 36 MySQL-specific skips; 1330 assertions |
| `php vendor/bin/phpunit --configuration phpunit.mysql.xml --no-progress --colors=never` | 222 tests, 221 passed, 1 skipped; 1443 assertions |
| `php artisan route:list --json` | 19 route entries; 21 explicit operations excluding implicit HEAD |
| OpenAPI JSON and local references | Parsed; all 121 local references resolve; 14 paths / 21 operations exactly match routes with server prefixes |
| Changed documentation links / fences | Local targets exist; Markdown and Mermaid fences balanced; Mermaid sources were not rendered |
| `git diff --check` | Passed before staging |

MySQL suite used MySQL 8.0.39 at 127.0.0.1:33382, database coffee_management_auth_test, after verifying @@datadir was the dedicated ignored payments-mysql-20261006 directory. No shared database was reset. After validation the verified disposable server was shut down; the existing MySQL80 service remained running. Ignored local database files were retained and excluded from Git. The final first run was interrupted when this disposable server was unavailable; server options were corrected and the entire MySQL suite rerun successfully (1m25.621s). This interruption is not reported as a passing test run.

Coverage includes payment FK/UQ/owning-order selectors and MySQL CHECKs, immutable confirmed intent/identity, exact/excess/insufficient tender, every current staff role, disabled account/token ability, cross-cashier order/payment denial, unknown proof/owner/currency/status fields, canonical keys and tender, rate limiting, unchanged snapshots, stale model settlement replacement denial and controlled cash rollback.

Test-only external cases cover pending QR vs settlement, timeout/uncertainty, pending status and crash-before-initiation-reply recovery, strict native integer monetary normalization, merchant/amount/currency/order/correlation/provider mismatches, repeated verified results, global identity reuse, second distinct received transaction, late confirmation after failure/expiry and cash, sticky mismatched evidence, expired QR display suppression, outer-transaction rejection, local post-verification failure/rollback and trusted requery recovery. Http::preventStrayRequests guards the feature suite; no bank network request was made. Repeated verified observations cover replay behavior at the trusted boundary; a public callback route/authentication contract does not exist and was not tested.

## MySQL races, upgrade and query plans

Six payment tests use independent PHP worker processes and observe real InnoDB waits before releasing barriers: same cash key (201/200), different cash keys (201/409), cash first vs external, external first vs cash, two external attempts, and one provider transaction racing across two orders. Exactly one accepted selection wins each eligible race; the reused provider identity cannot credit both orders and the loser requires review. Workers verify the exact local disposable database/datadir and contain no schema reset. Phase 3 concurrency tests also passed in the full regression suite.

A separate verified disposable coffee_management_payment_upgrade_test database was populated at the 10-migration Phase 3 baseline with synthetic staff, a token, a product and a pending order. Applying only the three new Phase 4 migrations retained prior data/snapshots; all 13 migrations showed ran. A retained 650-cent order settled with 1000-cent tender and 350-cent change exactly once. Original Phase 3 migrations were not rewritten. FK removal order and fresh migrate/rollback paths also ran in the feature suite. Production backup/rollout and reversal of retained financial data remain operational work.

Physical inspection confirmed signed BIGINT for payment expected/tender/change and evidence amount. With synthetic rows rolled back after inspection, EXPLAIN selected payments_order_id_attempt_key_unique for keyed attempt lookup, payments_status_updated_at_id_index for status recovery and payments_reconciliation_required_updated_at_id_index for review scans. These are query-plan checks, not a production load benchmark.

## Final specialist self-review

These are six skill-guided engineering perspectives applied by the same agent, not independently delegated approvals.

| Perspective / canonical skill | Finding and evidence |
| --- | --- |
| Architecture: practical-system-design | Cash and external workflows are focused boundaries. Persisted intent precedes I/O; short order/payment transactions follow trusted verification. External entrypoints reject outer transactions. Manual recovery is explicit; no Inventory/Flutter code or speculative SDK/framework added. |
| Database: mysql-design | Exact cents, restricted financial FKs, composite owning-order selectors, unique per-order keys and provider identities, paid-selection CHECK and consistent order-first locks. MySQL constraints, six races, upgrade and plans passed. |
| Laravel: laravel-rest-api | Thin versioned controller, strict Requests, safe Resources, scoped Policies, ordinary Eloquent and focused services; accepted summaries eagerly loaded. Existing Auth/Catalog behavior is preserved. |
| Security: api-payment-security | Client flags/amount/currency/reference are never proof. Active staff/object authorization and throttling enforce the boundary. All trusted facts must match; immutable evidence quarantines replay/mismatch/extra funds. No secret/raw payload logging or public callback endpoint added. Fake provider remains test-only. |
| QA: risk-based-qa | Negative authorization/input, idempotency, timeout/crash, local rollback, immutable snapshot and real independent-connection race cases passed alongside Phase 1-3 regression. SQLite limits remain explicit. |
| Git: preserve-git-workflow | Clean recorded baseline; main matched origin/main before staging. Explicit Phase 4 manifest only; no Flutter, dependency changes, .env, credentials or ignored database/build artifacts included. Normal commit/push authorized; no history rewriting. |

## Limits, rollout and next milestone

Cash settlement is implemented. External/KHQR is a provider-neutral foundation tested with a fake; production remains disabled with 503. An approved official provider/merchant contract, authenticated transport and response normalization, sandbox validation and callback verification (if supported) are separate integration prerequisites. Durable scheduling/worker recovery, human review/refund/reassignment and receipt printing are not implemented. Manual reconciliation requires configured trusted status queries; client polling is not durability. Review records cannot be casually cleared by these endpoints.

Inventory enforcement remains false and there are no stock writes. Phase 5 should separately approve units/oversell/expiry/cutover rules, then add inventory/recipes, opening movement ledger, reservations, checkout enforcement, atomic paid-order consumption, cancellation/release and sorted stock-lock concurrency tests. No Phase 5 work was started.

## Publication evidence

The report records checks before the authorized commit and push. The Phase 4 commit and GitHub Actions outcome are reported after publication in the final user response; this file cannot include its own eventual commit SHA. Phase 3 CI above is baseline evidence, not a claim that new CI has passed.

## Changed-file manifest

The following is the complete Phase 4 source/documentation manifest (25 existing files modified, 32 files created). Ignored test databases and local artifacts are excluded.


```text
README.md
apps/backend/app/Enums/PaymentMethod.php
apps/backend/app/Enums/PaymentStatus.php
apps/backend/app/Http/Controllers/Api/V1/OrderController.php
apps/backend/app/Http/Controllers/Api/V1/PaymentController.php
apps/backend/app/Http/Requests/Payments/CashPaymentRequest.php
apps/backend/app/Http/Requests/Payments/ExternalPaymentRequest.php
apps/backend/app/Http/Requests/Payments/PaymentIndexRequest.php
apps/backend/app/Http/Requests/Payments/ReconcilePaymentRequest.php
apps/backend/app/Http/Resources/OrderResource.php
apps/backend/app/Http/Resources/PaymentResource.php
apps/backend/app/Models/Order.php
apps/backend/app/Models/Payment.php
apps/backend/app/Models/PaymentEvidence.php
apps/backend/app/Payments/InitiationResult.php
apps/backend/app/Payments/PaymentIntent.php
apps/backend/app/Payments/PaymentProvider.php
apps/backend/app/Payments/ProviderIdentity.php
apps/backend/app/Payments/ProviderTimeout.php
apps/backend/app/Payments/UnconfiguredPaymentProvider.php
apps/backend/app/Payments/VerificationResult.php
apps/backend/app/Policies/OrderPolicy.php
apps/backend/app/Policies/PaymentPolicy.php
apps/backend/app/Providers/AppServiceProvider.php
apps/backend/app/Services/CashPaymentService.php
apps/backend/app/Services/ExternalPaymentService.php
apps/backend/app/Services/OrderCheckoutService.php
apps/backend/database/factories/PaymentFactory.php
apps/backend/database/migrations/2026_10_06_000008_create_payments_table.php
apps/backend/database/migrations/2026_10_06_000009_add_order_payment_selection.php
apps/backend/database/migrations/2026_10_06_000010_create_payment_evidence_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/CashPaymentTest.php
apps/backend/tests/Feature/ExternalPaymentTest.php
apps/backend/tests/Feature/PaymentConcurrencyTest.php
apps/backend/tests/Feature/PaymentSchemaTest.php
apps/backend/tests/Support/FakePaymentProvider.php
apps/backend/tests/Support/payment-worker.php
docs/api/README.md
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
docs/system-analysis/phase-4-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```
