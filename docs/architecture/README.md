# Architecture

## System boundary

Flutter communicates with Laravel over HTTPS JSON REST. Laravel is the sole owner of MySQL and, later, payment-provider credentials. Mobile clients never connect directly to the database or decide authoritative prices, permissions, or payment completion.

The monorepo shares documentation and CI but keeps Composer and Flutter dependency graphs independent. There is one root Git repository; do not initialize Git inside either app.

## Flutter boundaries

| Directory | Responsibility |
| --- | --- |
| `config/` | Public build settings, app composition and future route configuration |
| `core/` | Shared technical infrastructure: networking, errors, utilities |
| `shared/` | Reusable UI widgets and theme; avoid feature-specific behavior |
| `features/<name>/presentation/` | Screens, state, interaction logic |
| `features/<name>/domain/` | Plain Dart entities, business rules, repository contracts |
| `features/<name>/data/` | DTOs, data sources, repository implementations |

Presentation and data depend on domain. Domain must not import Flutter, HTTP clients, or storage packages. Compose implementations at the app boundary when needed. Keep features independent; use deliberate domain contracts if a workflow spans features. Do not move code into `shared` just because two files look similar.

State management, routing, networking, storage, and dependency-injection packages are deferred until the first feature creates a concrete need. Prefer one consistent approach across features. Add use cases for meaningful rules or orchestration, not for every getter or one-line repository call.

## Laravel boundaries

| Layer | Responsibility |
| --- | --- |
| `Http/Controllers/Api/V1` | HTTP orchestration; thin endpoint handlers |
| `Http/Requests` | Input validation and request-level authorization |
| `Http/Resources` | Stable JSON serialization |
| `Models` | Eloquent persistence, relationships and local model behavior |
| `Services` | Workflows and transaction boundaries when justified |
| `Policies` | Resource/action authorization |
| `Providers` | Framework registration and justified bindings |

Follow normal Eloquent conventions. Add per-feature namespaces within a layer once real code warrants them. Do not add generic repositories over Eloquent, abstract CRUD controllers, event buses, or service interfaces in anticipation of future work. Jobs, events, listeners, enums, and provider adapters belong in their standard Laravel locations when an actual workflow needs them.

## Feature ownership (planned)

| Flutter feature | Planned backend responsibility |
| --- | --- |
| `auth` | Identity, sign-in/out, tokens and session lifecycle |
| `products` | Product catalog and pricing |
| `categories` | Catalog grouping |
| `pos` | Checkout UI and cart; authoritative checkout through Orders |
| `orders` | Order lifecycle, items, totals and checkout transaction |
| `payments` | Payment attempts, KHQR/provider integration and reconciliation |
| `inventory` | Stock movements and adjustments |
| `reports` | Authorized aggregates derived from operational records |
| `users` | Staff administration, roles, password reset, token revocation, audit log |
| `settings` | Typed allow-listed store configuration (`shop_name`, `shop_timezone`) |

These are ownership boundaries. Backend auth/role foundations, Category/Product catalog, Orders checkout/history, cash/payment settlement foundation, Phase 5 inventory workflows, Phase 6 staff administration, typed settings, and immutable audit events, and Phase 7 operational reporting and analytics exist; real provider integration and Flutter screens remain planned. KHQR remains within Payments. Roles remain within Users until a real need warrants a separate module. Cross-feature checkout belongs in an Orders service with explicit dependencies and transactions, rather than duplicated controllers. See [system analysis](../system-analysis/README.md) for the proposed ERD/TRD, workflows and decision gates.

## Operational defaults

Versioned API routing and JSON API errors are configured. Laravel's `/up`, three `/api/v1/auth` endpoints and Category/Product read/create/update endpoints exist. Three unpaid Orders create/history/detail routes exist; no DELETE catalog/order, receipt printing. Phase 5 adds exact inventory APIs and safe manual cancellation, with deployment-gated tracking. Phase 4 payment routes implement cash and a fake-tested provider-neutral workflow, with production external adapter disabled. Phase 6 adds admin-only staff management endpoints under `/api/v1/staff`, operational settings under `/api/v1/settings`, and immutable administrative audit logs under `/api/v1/audit-events`. Phase 7 adds operational reporting and analytics endpoints under `/api/v1/reports/*` (`overview`, `sales-trend`, `payment-methods`, `top-products`, `inventory`, `reconciliation`). Sanctum uses bearer-only tokens with eight-hour expiry; fixed roles and gates use current database identity. Inactive/unassigned/unknown-role staff fail closed. MySQL is the application database; tests use SQLite in memory and a separately configured disposable MySQL database. File cache/sessions and synchronous queues keep the starting environment small. Introduce shared throttle cache for multiple API nodes and durable queues/workers when payment recovery is implemented.

Keep provider credentials on the backend, supply secrets through ignored local configuration or deployment secrets, and log neither tokens nor full payment credentials. Sanctum, role gates, UserPolicy and SettingPolicy enforce strict authorization. Category/Product policies enforce catalog management and active-read boundaries; OrderPolicy plus actor-scoped queries protect unpaid history; PaymentPolicy and owning OrderPolicy pay rules protect settlement/reconciliation; UserPolicy restricts staff provisioning, role updates, and password resets to active administrators. First-party Web cookie/CSRF authentication and native secure token storage belong to the later client milestone. Offline POS, multi-store tenancy, and payment-provider selection remain product decisions, not scaffold assumptions.

## Phase 5 ownership and transaction integration

Inventory owns exact balance/ledger/reservation transitions. Product parent locks coordinate complete recipe replacement with checkout reads. Checkout reserves snapshots only when enabled; immutable persisted tracking flag survives rollout/retries. Cash and trusted external workflows call one OrderSettlementService inside payment confirmation transactions; sorted stock locks and snapshots consume atomically. Safe cancellation locks order/payment before stock and releases without on-hand movement. InventoryConsistencyService runs read-only audit snapshots and reports discrepancies without repair. No new framework/dependencies/frontend were introduced.

## Phase 6 staff, settings, and audit integration

StaffManagementService coordinates staff provisioning, updates, password resets, and token revocation. Last operational admin protection acquires a row lock on the `admin` role in `roles` before verifying that active operational admin count does not decrease from 1 to 0 under concurrency. SettingRegistry allow-lists only `shop_name` and `shop_timezone` while strictly rejecting secrets and arbitrary keys. SettingService updates settings atomically and emits audit events. AuditService records immutable structured audit events in active database transactions, and the `AuditEvent` model strictly denies Eloquent update and delete operations.
