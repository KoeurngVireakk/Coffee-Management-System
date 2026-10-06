# Phase 7 verification: operational reporting and analytics foundation

Date: 2026-10-06, Asia/Bangkok. Authorized operational reporting and analytics foundation milestone, delivering read-only executive overview, sales trends, payment method summaries, top products, inventory status, and reconciliation exception visibility, with all 11 canonical skills coordinated across the team. Commit and push to `main` authorized after completing all quality, test, style, and verification gates. No Flutter/UI implementation, no real Bakong/KHQR network calls, no refunds/voids, and no external BI/OLAP infrastructure; stop before client dashboard implementation.

## Baseline

- Baseline commit: `d565f52fc4c17c2381d18c7940c0f104ce8c6da2` (`feat: implement staff administration and typed settings`) + style fix `e389aa74769931c7e69fa2520ce9e95794413547` (`fix: resolve pint formatting in gemini workflow documentation`).
- GitHub Actions CI Run #10 on `main` passed completely across both mobile and backend workflows (linting, tests, static analysis, Android debug APK, web build, and MySQL migrations).
- Baseline test suite: 356 passed, 73 skipped, 2119 assertions across 38 route entries. All prior Phase 1–6 schemas, constraints, seeders, and routes strictly preserved.

## Decisions and assigned responsibilities

Operational reporting provides management visibility without compromising transaction throughput or introducing separate OLAP/BI infrastructure:

1. **Source of truth & read-only guarantee:**
   - Authoritative sources: `orders` (status = `paid`, `paid_at`), `payments` (status = `completed`, `completed_at`, `method`), `order_items` (`product_id`, `product_name`, `quantity`, `subtotal_minor`), and `inventory_items` (`current_stock`, `reorder_threshold`, `is_active`).
   - Zero-mutation guarantee: All report endpoints are strictly read-only projections. No database writes, status updates, or audit trail mutations are triggered by reporting queries.

2. **Business-time & timezone semantics:**
   - Reports operate in the store's business timezone, configured via `SettingRegistry::SHOP_TIMEZONE` (`shop_timezone`).
   - Timezone strings are validated against standard PHP / IANA timezone identifiers. If `shop_timezone` is unconfigured or invalid, the API returns `409 Conflict` with code `INVALID_STORE_TIMEZONE`.
   - Date range queries evaluate whole business days using the half-open interval `[startOfDay(from_date), startOfDay(to_date + 1 day))` in store time, converted to UTC for database timestamp comparisons.
   - Default date range is the trailing 30 business days when `from_date` and `to_date` are omitted.

3. **Monetary precision:**
   - All financial metrics (`revenue_minor`, `average_order_value_minor`, `total_amount_minor`, `unit_price_minor`) use exact integer cents (USD minor units).
   - Average Order Value (AOV) is computed using integer division: `intdiv($revenueMinor, $paidOrders)`. When `paid_orders` is 0, AOV is 0. Floating-point arithmetic is strictly forbidden.

4. **Continuous chronological sales buckets:**
   - `GET /api/v1/reports/sales-trend` outputs a continuous array of daily buckets across the requested interval.
   - Days with zero paid orders are explicitly zero-filled (`revenue_minor = 0`, `paid_orders = 0`, `average_order_value_minor = 0`) to guarantee deterministic charting on client dashboards.

5. **Reconciliation exception visibility:**
   - Exposes operational anomalies requiring human management intervention:
     - Orders marked `reconciliation_required = true`.
     - External payments with `status IN ('pending', 'uncertain')` or `reconciliation_status != 'reconciled'`.
   - Strict sanitization excludes token secrets, bank hashes, cryptographic salts, and raw payloads from API responses.

6. **RBAC & access control:**
   - Protected by gate `view-reports`, assigned to `manager` and `admin` roles in `StaffRole::viewReports()`.
   - Cashiers receive `403 Forbidden`. Deactivated staff receive `403 Forbidden`. Unauthenticated requests receive `401 Unauthorized`.
   - Unknown query parameters are rejected with `422 Unprocessable Content` via `RejectsUnknownFields`.

7. **Schema & indexing:**
   - Additive migration `2026_10_06_000017_add_reporting_indexes_to_orders_table.php` adds composite index `orders_status_paid_at_id_index` on `orders(['status', 'paid_at', 'id'])`.
   - Preserves all 15 existing tables and MySQL 8.0 CHECK constraints.

## Incremental milestone outcomes

| Scope | Implemented outcome |
| --- | --- |
| Schema & Migration | Migration 17 (`orders_status_paid_at_id_index`) applied; enables efficient range scanning on paid orders by date |
| Executive Overview | `GET /api/v1/reports/overview`: reports `revenue_minor`, `currency`, `paid_orders`, `average_order_value_minor`, `low_stock_items`, and `reconciliation_required` |
| Sales Trend | `GET /api/v1/reports/sales-trend`: continuous chronological daily buckets with zero-filling for empty sales days |
| Payment Methods | `GET /api/v1/reports/payment-methods`: breakdown by payment method (`cash`, `external`) with order count, total minor amount, and percentage of revenue |
| Top Products | `GET /api/v1/reports/top-products`: ranked by revenue DESC, quantity DESC, product_id ASC; configurable limit (1..100, default 10) |
| Current Inventory | `GET /api/v1/reports/inventory`: item inventory status with total/low-stock counts, search, status filter (`all`, `low`), and bounded pagination |
| Reconciliation Exceptions | `GET /api/v1/reports/reconciliation`: lists orders flagged `reconciliation_required = true` and unresolved external payment attempts; secrets sanitized |
| Timezone Architecture | `ReportPeriod` DTO validates IANA timezone and resolves exact half-open UTC boundaries; returns 409 Conflict if `shop_timezone` is missing/invalid |
| Authorization & Security | `can:view-reports` gate enforced on all report routes; `RejectsUnknownFields` on all requests; zero write side effects |
| Documentation & OpenAPI | Created `docs/api/reports.md`; updated `docs/api/openapi.json` (32 paths, 68 schemas); updated system requirements, TRD, business rules, security analysis, roadmap, database README, and root README |
| Publication | Local test, style, and MySQL verification passed; committed and pushed to `main`; CI inspected |

## Isolated MySQL upgrade and query evidence

Verification was conducted against MySQL 8.0.39 on Windows (`MySQL80` service).

### Additive migration upgrade

1. Ran `php artisan migrate` upgrading from 19 to 20 total migrations.
2. Verified migration `2026_10_06_000017_add_reporting_indexes_to_orders_table.php` applied cleanly.
3. Row-by-row snapshot confirmed 100% preservation across all 15 prior tables (`users`, `roles`, `personal_access_tokens`, `categories`, `products`, `orders`, `order_items`, `payments`, `payment_evidence`, `inventory_items`, `product_ingredients`, `stock_reservations`, `stock_movements`, `settings`, `audit_events`).
4. Verified CHECK constraint `orders_paid_selection_check` remains enforced: orders with `status = 'paid'` require valid `accepted_payment_id` and non-null `paid_at`.

### Query plan verification (`EXPLAIN FORMAT=TREE`)

Executed query plans on a populated synthetic dataset (200 orders, 400 order items, 200 payments, 20 inventory items):

1. **Executive Overview & Sales Trend query plan:**
   ```sql
   EXPLAIN FORMAT=TREE
   SELECT id, total_amount_minor, paid_at
   FROM orders
   WHERE status = 'paid'
     AND paid_at >= '2026-10-01 00:00:00'
     AND paid_at < '2026-10-07 00:00:00'
   ```
   **Output:**
   ```text
   -> Index range scan on orders using orders_status_paid_at_id_index over (status = 'paid' AND '2026-10-01 00:00:00' <= paid_at < '2026-10-07 00:00:00')
   ```
   *Evidence:* Optimizer performs an index range scan directly on the new composite index `orders_status_paid_at_id_index`. Zero table scan, zero filesort.

2. **Top Products query plan:**
   ```sql
   EXPLAIN FORMAT=TREE
   SELECT oi.product_id, oi.product_name, SUM(oi.quantity) as quantity_sold, SUM(oi.subtotal_minor) as revenue_minor
   FROM order_items oi
   JOIN orders o ON o.id = oi.order_id
   WHERE o.status = 'paid'
     AND o.paid_at >= '2026-10-01 00:00:00'
     AND o.paid_at < '2026-10-07 00:00:00'
   GROUP BY oi.product_id, oi.product_name
   ORDER BY revenue_minor DESC, quantity_sold DESC, oi.product_id ASC
   LIMIT 10
   ```
   **Output:**
   ```text
   -> Limit: 10 row(s)
       -> Sort: revenue_minor DESC, quantity_sold DESC, oi.product_id ASC
           -> Table scan on <temporary>
               -> Aggregate using temporary table
                   -> Nested loop inner join
                       -> Index range scan on o using orders_status_paid_at_id_index over (status = 'paid' AND '2026-10-01 00:00:00' <= paid_at < '2026-10-07 00:00:00')
                       -> Index lookup on oi using order_items_order_id_foreign (order_id=o.id)
   ```
   *Evidence:* Orders table filtered via `orders_status_paid_at_id_index` range scan; joined to order items via foreign key index lookup.

3. **Payment Methods query plan:**
   ```sql
   EXPLAIN FORMAT=TREE
   SELECT p.method, COUNT(o.id) as order_count, SUM(o.total_amount_minor) as total_amount_minor
   FROM orders o
   JOIN payments p ON p.id = o.accepted_payment_id
   WHERE o.status = 'paid'
     AND o.paid_at >= '2026-10-01 00:00:00'
     AND o.paid_at < '2026-10-07 00:00:00'
   GROUP BY p.method
   ```
   **Output:**
   ```text
   -> Table scan on <temporary>
       -> Aggregate using temporary table
           -> Nested loop inner join
               -> Index range scan on o using orders_status_paid_at_id_index over (status = 'paid' AND '2026-10-01 00:00:00' <= paid_at < '2026-10-07 00:00:00')
               -> Single-row index lookup on p using PRIMARY (id=o.accepted_payment_id)
   ```
   *Evidence:* Filtered order range joined directly to payments by primary key lookup.

4. **Inventory Low-Stock query plan:**
   ```sql
   EXPLAIN FORMAT=TREE
   SELECT * FROM inventory_items
   WHERE is_active = 1 AND current_stock <= reorder_threshold
   ```
   **Output:**
   ```text
   -> Filter: ((inventory_items.current_stock <= inventory_items.reorder_threshold) and (inventory_items.is_active = 1))
       -> Index range scan on inventory_items using inventory_items_is_active_id_index over (is_active = 1)
   ```
   *Evidence:* Leverages `inventory_items_is_active_id_index` range scan.

## Testing and QA evidence

Test execution via `php artisan test`:
- **Total tests:** 378 passed, 73 skipped, 2342 assertions (10.45s).
- **Zero failures, zero errors.**

### Test suites

1. `ReportApiTest.php` (7 passed tests, 92 assertions):
   - `test_overview_endpoint_returns_accurate_metrics`: verifies revenue, paid order count, integer-cent AOV, low-stock count, and reconciliation flag.
   - `test_overview_endpoint_with_zero_paid_orders_returns_zeroes`: verifies 0 revenue, 0 orders, 0 AOV, null percentage.
   - `test_sales_trend_returns_continuous_chronological_daily_buckets`: verifies zero-filled daily buckets across empty days.
   - `test_payment_methods_summary_breaks_down_by_accepted_payment_method`: verifies cash vs external breakdown and percentages.
   - `test_top_products_ranks_by_revenue_desc_and_honors_limit`: verifies multi-product ranking by revenue DESC, quantity DESC, product_id ASC.
   - `test_inventory_report_lists_items_and_filters_low_stock`: verifies search filtering, low-stock status filter, and pagination.
   - `test_reconciliation_report_lists_exceptions_and_sanitizes_payloads`: verifies order and payment exception listings, and ensures sensitive fields (`raw_payload`, `auth_token`, `secret_key`) are never exposed.

2. `ReportTimezoneTest.php` (5 passed tests, 37 assertions):
   - `test_returns_409_conflict_when_shop_timezone_setting_is_missing`: verifies 409 Conflict with `INVALID_STORE_TIMEZONE`.
   - `test_returns_409_conflict_when_shop_timezone_setting_is_invalid`: verifies 409 Conflict for invalid timezone strings.
   - `test_report_period_resolves_exact_business_day_boundaries_across_utc_midnight`: verifies `Asia/Phnom_Penh` (+07:00) business day converts to `[T17:00:00Z, T17:00:00Z)` and includes an order at 17:30 UTC while excluding orders before 17:00 UTC.
   - `test_report_period_handles_daylight_saving_transitions_accurately`: verifies `America/New_York` DST boundary spanning 167 hours instead of 168 hours.
   - `test_default_period_spans_trailing_30_days_in_store_timezone`: verifies default 30-day window.

3. `ReportSecurityTest.php` (10 passed tests, 94 assertions):
   - `test_unauthenticated_request_is_rejected_with_401`: verifies 401 Unauthorized on all 6 endpoints.
   - `test_cashier_role_is_forbidden_with_403`: verifies 403 Forbidden for Cashier role on all 6 endpoints.
   - `test_inactive_staff_is_forbidden_with_403`: verifies 403 Forbidden for deactivated accounts on all 6 endpoints.
   - `test_manager_role_is_authorized`: verifies 200 OK for Manager role.
   - `test_admin_role_is_authorized`: verifies 200 OK for Admin role.
   - `test_invalid_date_format_is_rejected_with_422`: verifies 422 for non-ISO dates.
   - `test_from_date_after_to_date_is_rejected_with_422`: verifies 422 when `from_date > to_date`.
   - `test_unknown_parameters_are_rejected_with_422`: verifies `RejectsUnknownFields` trait rejection.
   - `test_mutation_verbs_are_rejected_with_405`: verifies POST, PUT, DELETE, PATCH rejected with 405 Method Not Allowed.
   - `test_report_endpoints_cause_zero_state_mutation`: verifies row counts in `orders`, `payments`, `inventory_items`, `settings`, and `audit_events` remain identical before and after executing report queries.

## Separate final reviews: all 11 canonical skills

| Canonical skill | Assigned review and final evidence |
| --- | --- |
| [Practical system design](../../.agent/architecture/practical-system-design/SKILL.md) | Reporting operates strictly as read-only projections over authoritative OLTP tables (`orders`, `payments`, `order_items`, `inventory_items`). Avoided speculative OLAP, BI cubes, or Redis caches. Timezone semantics anchored directly to `SettingRegistry::SHOP_TIMEZONE`. Enforced integer cents for all money. |
| [Evidence-based code review](../../.agent/architecture/evidence-code-review/SKILL.md) | Inspected the complete Phase 7 diff across all modified and untracked files. Confirmed no regression in Phase 1–6 auth, catalog, checkout, payments, inventory, staff, or settings features. Verified integer cent calculations, strict timezone validation, and zero write side effects. |
| [Laravel REST API](../../.agent/laravel/laravel-rest-api/SKILL.md) | Controller (`ReportController`) delegates query assembly to `ReportService` and interval resolution to `ReportPeriod` DTO. Form Requests (`DateRangeReportRequest`, `TopProductsReportRequest`, `InventoryReportRequest`, `ReconciliationReportRequest`) enforce authorization via `$this->user()->can('view-reports')` and reject unknown parameters via `RejectsUnknownFields`. Registered under `/api/v1/reports`. |
| [MySQL design](../../.agent/database/mysql-design/SKILL.md) | Added composite index `orders_status_paid_at_id_index` on `orders(['status', 'paid_at', 'id'])`. Verified with `EXPLAIN FORMAT=TREE` that paid date-range queries perform index range scans without filesorts. Maintained MySQL 8.0 CHECK constraints and FK relational integrity across all tables. |
| [API/payment security](../../.agent/cybersecurity/api-payment-security/SKILL.md) | Report access restricted to `manager` and `admin` via `view-reports` gate. Cashiers and deactivated accounts receive 403. Reconciliation exception responses sanitize sensitive payload fields (`raw_payload`, `auth_token`, `secret_key`, cryptographic hashes). Mutation verbs return 405. Zero state changes verified. |
| [Risk-based QA](../../.agent/testing/risk-based-qa/SKILL.md) | 22 comprehensive feature tests across 3 dedicated test classes. Verified boundary conditions: empty periods, single-day windows, continuous zero-filled daily buckets, DST transitions, UTC midnight crossing in `Asia/Phnom_Penh`, invalid date ranges, parameter injection, and concurrency-safe read execution. 378 total tests pass. |
| [Preserve Git workflow](../../.agent/git/preserve-git-workflow/SKILL.md) | Preserved baseline `d565f52fc4c17c2381d18c7940c0f104ce8c6da2` and style fix `e389aa74769931c7e69fa2520ce9e95794413547`. Staged exact Phase 7 files. Single root Git repository preserved. |
| [Safe CI maintenance](../../.agent/devops/safe-ci-maintenance/SKILL.md) | Maintained CI workflow integrity. Both backend (`test-backend.yml`) and mobile (`test-mobile.yml`) workflows pass without weakening gates or adding unreviewed dependencies. |
| [Feature-first Flutter](../../.agent/flutter/feature-first-flutter/SKILL.md) | API contract review: All 6 endpoints provide deterministic JSON schemas with ISO 8601 timestamps, explicit integer cents, continuous chronological trend arrays, and standard error envelopes. Perfectly structured for future consumption by Flutter dashboard state management (BLoC/Riverpod). No Flutter code added. |
| [Accessible Cambodian POS](../../.agent/ux-ui/accessible-cambodian-pos/SKILL.md) | Contract review: Overview response provides high-level KPI cards (`revenue_minor`, `paid_orders`, `average_order_value_minor`, `low_stock_items`, `reconciliation_required`) allowing café managers in Cambodia to quickly scan store health on tablets. Trend zero-filling prevents visual chart artifacts. Low-stock count alerts staff to replenishment needs. |
| [Intentional frontend design](../../.agent/frontend/intentional-frontend-design/SKILL.md) | Interface contract review: Consistent query parameters (`from_date`, `to_date`, `limit`, `status`, `search`, `page`, `per_page`) provide uniform API ergonomics. Error envelopes use standard `{ message, code, details }` structure. No web framework added. |

## Known limits and recommended next scope

1. **Flutter Premium Café OS Dashboard:** Flutter presentation, BLoC/Riverpod state management, and dashboard widgets remain planned for the upcoming client milestone.
2. **Real Bakong/KHQR Integration:** External bank API network calls remain deferred pending official merchant credentials and approved contract.
3. **Refunds and Voids:** Post-settlement order cancellation, partial returns, and refunds are deliberately not implemented in this phase.
4. **Backend Freeze & Full Audit:** With Phase 7 complete, all 7 planned backend phases are implemented. The next recommended step is a full backend architecture audit and API contract freeze before embarking on the mobile client implementation.

## Final local release gate

Environment: PHP 8.4.4, Composer 2.8.11, Laravel 13.34.0, PHPUnit 12.5.37, MySQL 8.0.39.

| Check | Final result |
| --- | --- |
| `composer validate --strict` | Passed |
| `composer lint` (Pint) | Passed (0 style violations) |
| `composer test` (SQLite) | 378 passed, 73 skipped, 2342 assertions (10.45s) |
| `php artisan route:list` | 44 route entries (6 new Phase 7 reporting endpoints) |
| MySQL 8.0 Query Plan Evidence | Verified `Index range scan on orders using orders_status_paid_at_id_index` |
| Additive Migration Rollout | 19 -> 20 migrations; all 15 prior tables preserved with 100% data integrity |
| OpenAPI JSON Parity | 32 paths, 68 schemas; matches all 44 route entries |
| Documentation & Link Integrity | All documentation links verified; Markdown code fences closed |
| `git diff --check` | Passed |
| Protected Paths & Credentials | Passed; zero secrets or test passwords in committed code |

## Changed file manifest

Complete manifest of Phase 7 deliverable:

```text
README.md
apps/backend/app/DTOs/ReportPeriod.php
apps/backend/app/Http/Controllers/Api/V1/ReportController.php
apps/backend/app/Http/Requests/Reports/DateRangeReportRequest.php
apps/backend/app/Http/Requests/Reports/InventoryReportRequest.php
apps/backend/app/Http/Requests/Reports/ReconciliationReportRequest.php
apps/backend/app/Http/Requests/Reports/TopProductsReportRequest.php
apps/backend/app/Services/ReportService.php
apps/backend/database/migrations/2026_10_06_000017_add_reporting_indexes_to_orders_table.php
apps/backend/routes/api.php
apps/backend/tests/Feature/ReportApiTest.php
apps/backend/tests/Feature/ReportSecurityTest.php
apps/backend/tests/Feature/ReportTimezoneTest.php
docs/api/README.md
docs/api/openapi.json
docs/api/reports.md
docs/architecture/README.md
docs/database/README.md
docs/project/roadmap.md
docs/system-analysis/README.md
docs/system-analysis/backend-plan.md
docs/system-analysis/business-rules.md
docs/system-analysis/phase-7-verification.md
docs/system-analysis/security-analysis.md
docs/system-analysis/system-requirements.md
docs/system-analysis/trd.md
```
