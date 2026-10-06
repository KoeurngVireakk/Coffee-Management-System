# Business rules and access model

Authentication, catalog, unpaid checkout and scoped order reads are implemented. Phase 4 payment attempts/cash/verified acceptance and reconciliation are implemented; Phase 5 inventory/recipes/reservation/consumption/manual cancellation are implemented; provider-specific integration and reports remain planned.

## Identity and access

- BR-AUTH-001: protected APIs authenticate a Sanctum bearer token with staff ability. Tokens expire after eight hours; no refresh/registration endpoint. Logout revokes the current device token. Passwords use Laravel's hashed cast; token hashes use Sanctum.
- BR-AUTH-002: one nullable FK assigns a staff role. No role, unknown role or inactive account grants no access. New/migrated accounts default inactive and unassigned. Trusted provisioning explicitly assigns role and active status. Never automatically promote existing users.
- BR-AUTH-003: fixed role names are cashier, manager, admin. Permission mapping lives in code and gates evaluate the current database role, rather than embedding a role grant permanently in a token. There is no superuser bypass.
- BR-AUTH-004: requests cannot assign role/permission/active/ownership properties. Login accepts only email/password/device_name and rejects other top-level properties. Current-user targets only the caller.

| Action / gate | Cashier | Manager | Admin | Enforcement status |
| --- | --- | --- | --- | --- |
| Current user / own user policy view | Yes | Yes | Yes | Implemented endpoint and policy |
| Catalog read (`view-catalog`) | Yes | Yes | Yes | Category/Product policies and endpoints implemented |
| POS and own orders (`process-pos`, `view-own-orders`) | Yes | Yes | Yes | Unpaid checkout and OrderPolicy/scoped history implemented |
| Catalog management (`manage-catalog`) | No | Yes | Yes | Category/Product policies and endpoints implemented |
| All shop orders (`view-all-orders`) | No | Yes | Yes | OrderPolicy and scoped history implemented |
| Stock read (`view-inventory`) | Yes | Yes | Yes | Inventory API implemented |
| Stock adjustment (`adjust-inventory`) | No | Yes | Yes | Inventory API implemented |
| Reports (`view-reports`) | No | Yes | Yes | Gate only; endpoint planned |
| Staff administration (`manage-staff`) | No | No | Yes | Gate and other-user view policy only |
| Operational settings read (`view-settings`) | No | Yes | Yes | Gate only; endpoint planned |
| Settings write (`manage-settings`) | No | No | Yes | Gate only; endpoint planned |

Managers do not inherit staff administration. OrderPolicy now restricts cashier reads by created_by; future payment/admin policies must still protect objects, transitions and properties. Catalog and unpaid orders use enforced action/object scoping; paid acceptance now uses narrow locked payment workflows; administration remains unimplemented. Staff can process authorized cash payments and the provider-neutral foundation; real KHQR remains gated; refunds/voids remain unapproved.

## Catalog and money

- BR-CAT-001: each product belongs to one category. Retire categories/products using is_active; archive rather than cascade-delete referenced history.
- BR-CAT-002: inactive product/category is not normally sellable. Checkout reloads the catalog; client menu cache is advisory.
- BR-CAT-003 (Phase 2 implemented): staff reads default to active categories/sellable products. Only managers/admins can request status=all/inactive or view retired records; cashier detail requests for non-sellable records return 404. Retirement is an is_active update, never DELETE. Category/product flags are independent: reactivating a product under an inactive category does not make it sellable.
- BR-CAT-004 (Phase 2 implemented): SKU is normalized to uppercase ASCII, 1-64 characters from letters/digits/hyphen/underscore (first character letter/digit); unique case-insensitively on MySQL and SQLite. Category names are not assumed unique. Lists order by name then id, with bounded page/search input and no client-controlled sorting.
- BR-MONEY-001: monetary columns are signed BIGINT minor units with currency CHAR(3). Never FLOAT/DOUBLE. API money is an integer string plus currency; reject amounts outside supported bounds. The user approved USD with scale 2 for the catalog on 2026-10-06. Product price_minor accepts/returns canonical integer-cent strings, from 0 through 999999 ($0.00 through $9,999.99), an explicit administrative input cap. Fractional cents are rejected, never rounded. Currency is exactly USD; no conversion exists.
- BR-MONEY-002: Laravel calculates subtotal, discount, tax and total. Submitted checkout prices/paid flags are rejected. Manager/admin catalog endpoints can deliberately set product prices; cashiers cannot. Item name, SKU, price, quantity and computed totals are historical snapshots. Changes to product prices do not rewrite existing orders.
- BR-MONEY-003: subtotal=sum(line subtotals); total=subtotal-discount+tax; all totals nonnegative; discount <= subtotal. Phase 3 freezes discount/tax at zero and total=subtotal; no options, rounding or conversion. Future tax/discount rules need approval. No currency conversion is implied.

## Orders and payments

- BR-ORD-001: Phase 3 creates pending_payment only, with 1-50 distinct lines and strict JSON integer quantity 1-99. URI identity is server-generated ORD-ULID; amount snapshots and history are immutable in model/API workflows. No arbitrary update/delete/receipt-printing endpoint; safe manual pending cancellation is implemented in Phase 5. Phase 4 adds separate authorized payment/paid-acceptance routes; The enum/DB allow planned paid/cancelled/expired states, whose paid acceptance now belongs to Phase 4; automatic expiry/refund transitions remain later workflows. Refunds need a later explicit model.
- BR-ORD-002: a unique checkout key per actor plus canonical request hash prevents duplicate orders. Repeated same intent returns original order; changed intent with same key returns 409. Idempotency-Key is a required 8-64-character case-sensitive ASCII header (first alphanumeric; rest alphanumeric/dot/underscore/hyphen), not a body field. Version-1 hash contains sorted product IDs/quantities and USD context, never prices/credentials/options. Reordered input is equivalent; original snapshots replay after catalog changes. Concurrent loser reloads the committed winner after rollback, including catalog-retirement races.
- BR-PAY-001: orders have multiple payment attempts, but at most one accepted full settlement. Split/partial payments are excluded for now. Pending order has at most one current attempt, enforced by order lock/active_payment_id; decline/expiry permits a new attempt only after uncertainty is resolved.
- BR-PAY-002: cash tender >= due; change=tender-due in order currency. Cash confirmation and paid order commit together. A chosen method, QR display, client success or screenshot never proves external payment.
- BR-PAY-003: backend verification matches merchant, order/attempt correlation, exact amount/currency and provider transaction ID. No public callback is implemented until a real provider contract is selected. The provider-neutral verifier queries trusted server evidence; future unsigned notifications can only be hints requiring that verification.
- BR-PAY-004: `(provider, external_transaction_id)` is unique. Repeated callback/poll must have no duplicate payment or stock effect. A second distinct paid attempt becomes a reconciliation exception; do not discard the received funds or pay the order twice.
- BR-PAY-005: attempt states: initiated -> pending -> confirmed/failed/expired; provider timeout -> uncertain -> verified terminal outcome. Do not retry state-changing remote I/O blindly. Expiry/cancellation requires verified no-settlement or quarantine. A late success after a cancelled order (or a future approved order-expiry workflow) records settlement and manual-review requirement without automatically changing already released stock.

## Inventory and reporting

- BR-PAY-006 (Phase 4): cash/external attempt keys are per-order case-sensitive headers, with method/tender semantic hash. Replay precedes paid checks. Order locks precede Payment locks; at most one accepted pointer. Initiator is backend-derived and retained internally. Cash tender is canonical exact cents <=9999999999; change is derived; untracked orders have no stock effects, tracked orders consume reservations atomically in Phase 5.
- BR-PAY-007 (Phase 4): append-only payment_evidence preserves normalized provider transaction observations, including wrong facts or extra distinct funds. Global provider/transaction uniqueness prevents double credit. Mismatch/second/late facts require review; pending/failed responses cannot dismiss received-funds evidence. No human clearing/refund/reassignment API yet.
- BR-PAY-008 (Phase 4): no provider contract approved; default adapter returns 503, fake exists only in tests. Services reject outer transactions before I/O. Persisted initiated/uncertain attempt/correlation supports manual trusted reconciliation, not automatic durability. Verified failure/expiry without evidence releases the active pointer; uncertain/evidence-bearing attempts block new methods. QR expiry only suppresses display, not automatic paid/failed state.

- BR-ORD-003 (Phase 3): all monetary fields use checked integer arithmetic and exact string output; subtotal/total cap 4949995050 cents from existing product cap x 99 x 50. Every creation is pending_payment; historical/default-disabled orders are untracked, new enabled checkouts are tracked with reservations. Shared product locks (ascending IDs), then shared category locks (ascending IDs) prevent inconsistent snapshots; transaction retries at most three times on deadlock.
- BR-ORD-004 (Phase 3): cashier history is scoped to created_by before lookup; manager/admin can see all shop orders, with policy defense. Fixed created_at DESC/id DESC; 25 default, 100 max/page, page max 10000. ISO boundaries require explicit UTC offset and valid calendar/time; normalize to UTC, no business-day inference. Raw query-builder/SQL can bypass model immutability guards and is trusted maintenance, not an API capability.

- BR-INV-001: stock tracking defaults disabled through INVENTORY_TRACKING_ENABLED deployment configuration. When enabled, every sellable tracked product has a valid recipe, or checkout fails. Packaged products map to one stock item. Use one base unit per item; quantities DECIMAL(14,4), positive recipe quantities and signed ledger deltas.
- BR-INV-002: available=on_hand-reserved. Checkout reserves under item locks if tracking is enabled; cannot reserve more than available. Payment confirms consume reserved stock with movement; safe manual cancellation releases reservation; automatic expiry remains future policy. Locks use sorted stock-item IDs.
- BR-INV-003: movements are immutable and contain reason, actor/source, quantity and unique operation key. Corrections append compensating records. Cached balances update atomically with ledger; periodic ledger reconciliation detects drift.
- BR-INV-004: recipes/required quantities are snapshotted into per-order reservations; recipe edits cannot alter a pending order's stock requirement. Manual negative adjustments cannot reduce on_hand below reserved.
- BR-REP-001: reports derive from paid orders and accepted verified payments, with reconciliation exceptions shown separately. Define refund treatment before adding refunds. Stock reports derive from ledger/balances. Use UTC timestamps and explicitly configured shop-day boundaries; never the host timezone.
- BR-SET-001: store settings use an allow-listed typed schema and admin gate; provider secrets stay in backend secret configuration. Currency changes cannot reinterpret existing money snapshots.

## Open decisions and blockers

| Decision | Proposed position / gate |
| --- | --- |
| Currency / scale / rounding | USD / scale 2 approved for catalog; fractional cents rejected; Phase 3 tax/discount zero, integer quantities and no rounding/options frozen; future changes need approval |
| Tax / discount / modifiers | Disabled initially; approve rules and schema extension before use |
| Shop timezone / receipt numbering | Candidate Asia/Phnom_Penh, immutable public reference; owner confirms |
| Inventory scope / units / overselling | Phase 5 approved: ingredients + packaged goods, g/ml/unit, exact DECIMAL(14,4), no negative available stock; no unit conversion |
| Reservation timeout / late payments | Automatic expiry deferred until approved provider/business semantics; Phase 5 manual safe cancellation is sufficient |
| Refunds / voids | No endpoint yet; need permissions, compensating finance/stock and provider support |
| Provider / merchant / callbacks | Not selected; use official contract and fake provider before separately authorized sandbox work |
| Backups / retention | Owner approves targets and history retention; no destructive deletion policy assumed |
| Browser auth / client storage | Secure native storage and first-party cookie/CSRF flow designed with Flutter later |
| Multi-store / offline / loyalty / delivery / customer / printers | Excluded unless newly requested; no tables or abstractions for them |

## Phase 5 frozen operational rules

Units g/ml/unit, DECIMAL(14,4), exact string boundaries and checked scale10000 integers; no conversions or oversell. Items start zero. Opening/receipt positive, waste negative, adjustment nonzero with explanatory note; opening allowed only before any movement history. Sale is system-only and append-only; release only changes reserved. Manual idempotency is actor+key across items and normalized reason/delta/note. Negative movements cannot use reserved stock. Management alone creates metadata/recipes/manual movements or reads detailed ledger; all active staff may read item availability.

Tracking is immutable per order; activation never backfills old orders. Enabled checkout aggregates positive recipe requirements, sorts inventory locks and snapshots reservations atomically. Cash and trusted fake-provider settlement consume snapshots once within payment/order finalization. Only safe pending own/shop orders cancel; unresolved/received/review payment blocks release. Same cancellation is idempotent. Read-only inventory:check diagnoses consistency and never repairs history.
