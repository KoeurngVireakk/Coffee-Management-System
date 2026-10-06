# Coffee Management System analysis

Analysis date: 2026-10-06 (Asia/Bangkok). Scope: a single coffee shop, online staff POS, Flutter clients, Laravel 13 API, MySQL 8.0.16+ for the implemented catalog CHECKs. This is a modular application within the existing monorepo.

## Evidence and status

Before this milestone, inspection found a clean `main`, Laravel 13.34.0, PHP 8.4.4, default framework migrations/User/factory, `/up`, empty `/api/v1`, and three bootstrap tests. Flutter contains feature boundaries and a startup screen. No business modules existed.

Phase 1 implemented backend authentication/access foundations. Phase 2 implements Categories and Products: role-authorized management, retirement/reactivation, active menu browsing, strict inputs, bounded pagination/search and exact USD-cent prices. Phase 3 adds atomic unpaid checkout and scoped order history: server prices, immutable snapshots, actor-scoped replay and UTC time. Phase 4 adds cash settlement and provider-neutral attempt/verified-evidence/reconciliation workflows with a test-only fake; production external adapter fails closed. Phase 5 adds exact inventory, recipes, reservations, consumption, movements, and deployment-gated tracking. Phase 6 adds staff management, typed settings, last-admin protection, and immutable audit events. Phase 7 adds operational reporting and analytics foundations (overview, sales trend, payment methods, top products, inventory status, reconciliation exceptions) with store-timezone boundaries. Flutter UI, real bank/KHQR integration, receipt printing, and customer delivery remain separate planned milestones. See [actual API contract](../api/README.md).

## Documents

| Document | Purpose |
| --- | --- |
| [System requirements](system-requirements.md) | Identified functional/non-functional requirements and acceptance criteria |
| [Business rules](business-rules.md) | Authority, lifecycle, access matrix and open decisions |
| [Conceptual ERD](erd.md) | Business entities, cardinality and normalization |
| [Physical TRD](trd.md) | Table relationships, dictionary, constraints, indexes and transaction boundaries |
| [Context diagram](context-diagram.md) | Actors/services and system boundary |
| [DFD level 1](dfd-level-1.md) | Major processes and logical data stores |
| [DFD level 2](dfd-level-2.md) | Checkout/payment decomposition and recovery |
| [Flowcharts](flowcharts.md) | Authentication, checkout and generic KHQR paths |
| [Security analysis](security-analysis.md) | Trust boundaries, abuse cases and current/planned controls |
| [Backend plan](backend-plan.md) | Ordered milestones, rollout and acceptance gates |
| [Verification and review](verification.md) | Phase 1 checks, review findings and limits |
| [Phase 2 verification](phase-2-verification.md) | Incremental catalog checks, approved USD decision, MySQL plans and reviews |
| [Phase 3 verification](phase-3-verification.md) | Unpaid checkout/history, replay, UTC, real MySQL races and review evidence |
| [Phase 4 verification](phase-4-verification.md) | Payment/cash/fake-provider proof, reconciliation, MySQL races/upgrade and authorized Git publication |
| [Phase 5 verification](phase-5-verification.md) | Exact inventory, recipes, reservations, consumption, movements, upgrade evidence |
| [Phase 6 verification](phase-6-verification.md) | Staff provisioning, role/activation management, password reset, token revocation, last-admin protection, typed settings, immutable audit |
| [Phase 7 verification](phase-7-verification.md) | Operational reporting foundation: overview, sales trend, payment methods, top products, inventory, reconciliation exceptions, store-timezone boundaries |
| [Backend final audit](backend-final-audit.md) | Comprehensive cross-phase audit, CI repair, MySQL verification, and API contract freeze |

Mermaid blocks are the diagram source of truth. No renderer or diagram dependency is required. DFD arrows represent data, while flowchart arrows represent execution. The level 2 diagram decomposes level 1 processes 3 and 4 as one checkout boundary, retaining process 5 as an external collaborator.

## Design decisions

- Laravel owns prices, permissions, order/payment transitions and inventory. Flutter sends intent over HTTPS JSON; MySQL is reachable only by the backend.
- One role per staff account is sufficient for cashier/manager/admin. A normalized roles table and a fixed, code-reviewed permission map avoid a permission editor/package. Missing/unknown roles fail closed. Role changes take effect on the next request.
- Native authentication uses expiring Sanctum bearer tokens. No refresh endpoint, public registration or default seeded accounts. First-party browser cookie/CSRF authentication and secure client storage are a later Flutter/Web milestone, following [Sanctum's distinction between API tokens and SPA authentication](https://laravel.com/framework/docs/13.x/sanctum).
- Phase 2 currency decision: the user approved USD with scale 2 on 2026-10-06. Product prices use signed BIGINT cents with an exact string API. Fractional cents are rejected; no conversion or exchange rate exists. Phase 3 freezes tax/discount to zero, accepts integer quantity without options and performs no rounding. Later tax/discount/option changes need approval.
- Implemented Phase 5 inventory uses ingredients/stock items, recipes and an append-only movement ledger. Packaged products can have a one-item recipe. Reservations prevent overselling during external payment; confirmed sales consume reserved stock exactly once. Inventory deployment defaults disabled and must be enabled explicitly, never silently half-enforced.
- Payment I/O stays outside short database transactions. Durable pending attempts and recovery scans precede real provider integration. Timeouts are uncertain outcomes, not failed payments.

## Boundaries and assumptions

No multi-store, offline POS, loyalty, delivery, customer accounts, printers or payment SDK is assumed. The coffee shop's timezone (candidate Asia/Phnom_Penh), receipt numbering, refunds, payment provider and retention/backup targets require business confirmation. Proposed defaults are labeled in the linked documents and are not production configuration.

Architecture follows [existing boundaries](../architecture/README.md); the six project architecture/database/Laravel/security/QA/Git skills were applied for their specialties. No generic backend package, UI change, live provider call, commit, push or deployment belongs to this milestone.
