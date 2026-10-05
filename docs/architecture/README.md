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
| `users` | User administration, roles and permissions |
| `settings` | Store configuration and authorized preferences |

These are ownership boundaries, not implemented modules. KHQR remains within Payments. Roles remain within Users until a real need warrants a separate module. Cross-feature checkout belongs in an Orders service with explicit dependencies and transactions, rather than duplicated controllers.

## Operational defaults

Versioned API routing and JSON API errors are configured. Laravel's `/up` route is the only successful application endpoint. MySQL is the local application database; isolated tests use SQLite in memory. File cache/sessions and synchronous queues keep the starting environment small. Introduce database/Redis queues and workers when durable background work is implemented.

Keep provider credentials on the backend, supply secrets through ignored local configuration or deployment secrets, and log neither tokens nor full payment credentials. Add Sanctum and role policies as part of the first authentication feature. Offline POS, multi-store tenancy, and payment-provider selection remain product decisions, not scaffold assumptions.
