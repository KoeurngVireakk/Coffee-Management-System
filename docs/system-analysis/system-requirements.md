# System requirements

Status legend: **implemented** means backend behavior exists in this milestone; **foundation** means rules/gates exist but the business endpoint does not; **planned** means design only. Flutter remains scaffolded. Acceptance below specifies the target behavior; authentication, Categories/Products and checkout/order history and cash settlement are executable; provider-neutral external workflows are fake-tested and real provider traffic remains gated. Other acceptance criteria remain target behavior.

## Functional requirements

| ID | Requirement and acceptance | Status |
| --- | --- | --- |
| FR-AUTH-001 | Active assigned staff sign in with email/password; generic credential failure; bounded input; throttle attempts; return expiring token once | Implemented |
| FR-AUTH-002 | Sign out revokes only the calling token; reuse returns 401; other device tokens survive | Implemented |
| FR-AUTH-003 | Current-user returns allow-listed identity, role and permission names for the caller; no credential hashes | Implemented |
| FR-AUTH-004 | Laravel enforces a fixed cashier/manager/admin access map; unassigned/inactive accounts and unknown roles fail closed | Foundation; authentication checks implemented |
| FR-USER-001 | Admin creates/updates/deactivates staff and assigns approved roles; no public registration; audit sensitive changes and revoke tokens on password recovery | Planned |
| FR-CAT-001 | Manager/admin creates, renames and retires categories; retire/reactivate without deleting financial history | Implemented; restrictive historical order/payment FKs retain records |
| FR-PROD-001 | Manager/admin maintains SKU, name, category, exact price and active status; category is required | Implemented, USD cents |
| FR-PROD-002 | Staff browse/search active menu with bounded pagination and stable order; unavailable/retired products cannot be added | Catalog and backend sellability revalidation implemented; Flutter cart/stock availability remain planned |
| FR-POS-001 | All staff construct a client cart from product IDs and bounded positive quantities; server rechecks availability | Backend cart intent/sellability implemented (50 lines, qty 1-99); Flutter cart/stock still planned |
| FR-POS-002 | Server builds immutable item name/unit-price/quantity/line-total snapshots and authoritative order totals; submitted prices are rejected | Implemented for unpaid orders, exact USD cents; zero discount/tax |
| FR-POS-003 | Replay of a checkout key returns the original order; altered payload with same key conflicts | Implemented, Idempotency-Key header per actor; canonical intent; MySQL race verified |
| FR-ORD-001 | Pending order has items, owner, currency and unique public reference; transitions follow business rules | Pending creation and paid settlement implemented; cancel/refund/void/expiry transitions planned |
| FR-ORD-002 | Cashier views own order history; manager/admin views shop history; date filters and pagination are bounded | Implemented with absolute UTC boundaries, bounded pages and scoped opaque references |
| FR-ORD-003 | Final receipt comes from persisted paid order and confirmed payment; no client-generated financial truth | Planned |
| FR-DISC-001 | Discounts/tax disabled until rules are approved; later privileged discounts are validated and snapshotted with actor/reason | Phase 3 zero values enforced; future discount/tax workflows planned |
| FR-PAY-001 | Staff selects cash or supported external method for an unpaid order; currency and due amount come from order | Cash implemented; external foundation gated by unconfigured production adapter |
| FR-PAY-002 | Cash tender is validated in exact units; tender >= due; server calculates change and atomically completes sale | Implemented, no inventory/receipt printing |
| FR-PAY-003 | Backend initiates generic KHQR attempt, persists correlation/expiry and returns display data; displaying QR leaves order pending | Provider-neutral persistence/display foundation fake-tested; real KHQR planned |
| FR-PAY-004 | Provider verification checks transaction identity, attempt, merchant, currency and exact amount before confirming payment | Core verification/evidence/acceptance implemented and fake-tested; real provider authentication pending |
| FR-PAY-005 | Duplicate/replayed callback/poll applies payment/stock once; uncertain outcomes and late settlements are reconciled | Payment replay/quarantine/manual recovery implemented; public callback, durable worker and stock planned |
| FR-INV-001 | Manager/admin records receipts, waste and reasoned adjustments; append movements and maintain reconciled balance | Planned |
| FR-INV-002 | Recipes map products to stock items and positive base-unit quantities; checkout reserves and completion consumes stock if enabled | Planned |
| FR-INV-003 | Authorized staff sees unavailable/low-stock information computed from on-hand minus reservations and reorder thresholds | Planned |
| FR-INV-004 | Ledger links sale to order and actor; corrections are compensating movements, never overwritten history | Planned |
| FR-REP-001 | Manager/admin views paid-sales, payment-method and stock summaries from authoritative records within a bounded date range | Planned |
| FR-SET-001 | Admin updates approved store settings; manager reads operational settings; never store secrets in editable settings | Planned |

Product options/variants are not approved. Phase 3 accepts product and quantity only; a later option model must price and validate selections on Laravel before it can be sold. Refunds/void permissions and lifecycle require approval before exposing those mutations.

## Non-functional requirements

| ID | Requirement | Acceptance / target |
| --- | --- | --- |
| NFR-SEC-001 | HTTPS and server-only secrets | Production TLS; APP_DEBUG=false; no credentials/tokens in client builds, logs or repository; explicit CORS origins |
| NFR-AUTHZ-001 | Action/property/object authorization | 401 missing/expired/revoked token; 403 forbidden active-role/action/object; test second actor and privilege injection for each protected resource |
| NFR-VAL-001 | Bounded validation | Form Requests; allow-list properties; cap strings, item count, quantity, filters and page size before work |
| NFR-API-001 | Consistent JSON / versioning | `/api/v1`; Laravel message/errors for failures; Resources with data envelope; meaningful status codes; synchronized implemented contract |
| NFR-PERF-001 | Appropriate shop performance | Proposed initial acceptance: 10 simultaneous staff, catalog/current-user p95 <500 ms, local checkout p95 <1 s excluding provider I/O; benchmark with realistic data before promising an SLA |
| NFR-REL-001 | Reliable checkout and payment | Atomic local state; replay keys; provider timeouts become pending reconciliation; recovery after crash between request and confirmation |
| NFR-CON-001 | Concurrent integrity | Stable row lock order, bounded deadlock retry; no negative available stock/duplicate settlement under concurrent tests |
| NFR-AUD-001 | Traceability | Immutable order snapshots/payment identities/stock movements; admin/discount adjustments include actor, reason and UTC timestamp; no raw credentials |
| NFR-MAINT-001 | Maintainability | Laravel conventions, focused feature tests, locked dependencies, no Eloquent repository wrappers; preserve Flutter domain boundaries |
| NFR-ACC-001 | Future accessible clients | Khmer/English labels, touch targets, keyboard/screen-reader access, text scaling and explicit payment/error states; API sends stable codes/data; no UI implementation now |
| NFR-SCALE-001 | Shop-scale deployment | One API and MySQL initially; pagination/query-driven indexes before caching; shared throttle cache if multiple API instances; durable worker only for real payment recovery |
| NFR-REC-001 | Backup/recovery | Proposed nightly encrypted backups, 24-hour RPO/4-hour RTO for owner approval; restore drill into isolated database; payment reconciliation after restore; binlog/PITR if approved loss window requires it |
| NFR-LOG-001 | Safe observability | Request/error correlation and transition outcomes; redact Authorization/password/PII/provider payloads; bounded retention and access; operational logs are not the financial ledger |

Performance, backup targets and business timezone are proposals, not measured properties. Existing file cache and sync queue are adequate for local auth but do not supply multi-node throttling or durable payment recovery.

## Dependencies and acceptance trace

FR-PAY-* -> [payment API](../api/payments.md), CashPaymentTest, ExternalPaymentTest, PaymentSchemaTest, PaymentConcurrencyTest and [Phase 4 evidence](phase-4-verification.md). Fake-only tests are not real bank/KHQR validation; no callback/stock/automatic worker behavior is claimed.

FR-AUTH-* -> [implemented auth contract](../api/README.md) -> AuthTest, AccessControlTest, AuthSchemaTest. FR-POS/ORD -> [Orders contract](../api/orders.md), OrderSchemaTest, CheckoutTest, OrderHistoryTest, OrderConcurrencyTest and [Phase 3 evidence](phase-3-verification.md). FR-PAY/INV and paid receipt acceptance remain future milestones; stock/payment effects are not claimed. FR-USER/REP/SET -> access matrix and future action/resource policy tests.

FR-CAT/PROD -> [catalog API contract](../api/README.md), `CategorySchemaTest`, `CategoryApiTest`, `ProductSchemaTest`, `ProductApiTest`, `CatalogQueryTest`, `ProductWriteRaceTest`; [Phase 2 verification](phase-2-verification.md) separates SQLite results from MySQL production constraints. Fixed ordering is name+id, page sizes 1-100, bounded literal search, and eager category loading. No caching, Flutter POS or stock capability is implied.
