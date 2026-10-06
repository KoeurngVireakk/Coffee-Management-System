# Business rules and access model

Authentication foundation rules below are implemented; order/payment/inventory rules are proposed invariants for future phases.

## Identity and access

- BR-AUTH-001: protected APIs authenticate a Sanctum bearer token with staff ability. Tokens expire after eight hours; no refresh/registration endpoint. Logout revokes the current device token. Passwords use Laravel's hashed cast; token hashes use Sanctum.
- BR-AUTH-002: one nullable FK assigns a staff role. No role, unknown role or inactive account grants no access. New/migrated accounts default inactive and unassigned. Trusted provisioning explicitly assigns role and active status. Never automatically promote existing users.
- BR-AUTH-003: fixed role names are cashier, manager, admin. Permission mapping lives in code and gates evaluate the current database role, rather than embedding a role grant permanently in a token. There is no superuser bypass.
- BR-AUTH-004: requests cannot assign role/permission/active/ownership properties. Login accepts only email/password/device_name and rejects other top-level properties. Current-user targets only the caller.

| Action / gate | Cashier | Manager | Admin | Enforcement status |
| --- | --- | --- | --- | --- |
| Current user / own user policy view | Yes | Yes | Yes | Implemented endpoint and policy |
| Catalog read (`view-catalog`) | Yes | Yes | Yes | Gate only |
| POS and own orders (`process-pos`, `view-own-orders`) | Yes | Yes | Yes | Gates only |
| Catalog management (`manage-catalog`) | No | Yes | Yes | Gate only |
| All shop orders (`view-all-orders`) | No | Yes | Yes | Gate only |
| Stock read (`view-inventory`) | Yes | Yes | Yes | Gate only |
| Stock adjustment (`adjust-inventory`) | No | Yes | Yes | Gate only |
| Reports (`view-reports`) | No | Yes | Yes | Gate only |
| Staff administration (`manage-staff`) | No | No | Yes | Gate and other-user view policy only |
| Operational settings read (`view-settings`) | No | Yes | Yes | Gate only |
| Settings write (`manage-settings`) | No | No | Yes | Gate only |

Managers do not inherit staff administration. Future resource policies must additionally restrict objects (e.g. cashier orders by created_by), transitions and properties. These gates alone do not implement catalog, orders or administration. All staff can process cash/KHQR on their authorized orders; refunds/voids remain unapproved.

## Catalog and money

- BR-CAT-001: each product belongs to one category. Retire categories/products using is_active; archive rather than cascade-delete referenced history.
- BR-CAT-002: inactive product/category is not normally sellable. Checkout reloads the catalog; client menu cache is advisory.
- BR-MONEY-001: monetary columns are signed BIGINT minor units with currency CHAR(3). Never FLOAT/DOUBLE. API money is an integer string plus currency; reject amounts outside supported bounds. Currency scale must be configured/validated before orders exist.
- BR-MONEY-002: Laravel calculates subtotal, discount, tax and total. Submitted authoritative prices/paid flags are invalid. Item name, SKU, price, quantity and computed totals are historical snapshots. Changes to product prices do not rewrite existing orders.
- BR-MONEY-003: subtotal=sum(line subtotals); total=subtotal-discount+tax; all totals nonnegative; discount <= subtotal. Discounts/tax initially zero, until approved rules specify scope, rounding, authority and snapshot data. No currency conversion is implied.

## Orders and payments

- BR-ORD-001: proposed lifecycle is pending_payment -> paid OR cancelled/expired. Paid/cancelled/expired orders cannot be edited. Refunds need a later explicit model. Orders have at least one positive-quantity item and a unique public reference.
- BR-ORD-002: a unique checkout key per actor plus canonical request hash prevents duplicate orders. Repeated same intent returns original order; changed intent with same key returns 409. The stored hash includes item selection/currency and accepted options, never secrets.
- BR-PAY-001: orders have multiple payment attempts, but at most one accepted full settlement. Split/partial payments are excluded for now. Pending order has at most one current attempt, enforced by order lock/active_payment_id; decline/expiry permits a new attempt only after uncertainty is resolved.
- BR-PAY-002: cash tender >= due; change=tender-due in order currency. Cash confirmation and paid order commit together. A chosen method, QR display, client success or screenshot never proves external payment.
- BR-PAY-003: backend verification matches merchant, order/attempt correlation, exact amount/currency and provider transaction ID. Authenticated callbacks follow selected provider contract; unsigned callbacks are hints requiring server verification.
- BR-PAY-004: `(provider, external_transaction_id)` is unique. Repeated callback/poll must have no duplicate payment or stock effect. A second distinct paid attempt becomes a reconciliation exception; do not discard the received funds or pay the order twice.
- BR-PAY-005: attempt states: initiated -> pending -> confirmed/failed/expired; provider timeout -> uncertain -> verified terminal outcome. Do not retry state-changing remote I/O blindly. Expiry/cancellation requires verified no-settlement or quarantine. A late success after an order expired records settlement and manual-review requirement without automatically changing already released stock.

## Inventory and reporting

- BR-INV-001: stock tracking is explicitly disabled until inventory rollout. When enabled, every sellable tracked product has a valid recipe, or checkout fails. Packaged products map to one stock item. Use one base unit per item; quantities DECIMAL(14,4), positive recipe quantities and signed ledger deltas.
- BR-INV-002: available=on_hand-reserved. Checkout reserves under item locks if tracking is enabled; cannot reserve more than available. Payment confirms consume reserved stock with movement; verified cancellation/expiry releases reservation. Locks use sorted stock-item IDs.
- BR-INV-003: movements are immutable and contain reason, actor/source, quantity and unique operation key. Corrections append compensating records. Cached balances update atomically with ledger; periodic ledger reconciliation detects drift.
- BR-INV-004: recipes/required quantities are snapshotted into per-order reservations; recipe edits cannot alter a pending order's stock requirement. Manual negative adjustments cannot reduce on_hand below reserved.
- BR-REP-001: reports derive from paid orders and accepted verified payments, with reconciliation exceptions shown separately. Define refund treatment before adding refunds. Stock reports derive from ledger/balances. Use UTC timestamps and explicitly configured shop-day boundaries; never the host timezone.
- BR-SET-001: store settings use an allow-listed typed schema and admin gate; provider secrets stay in backend secret configuration. Currency changes cannot reinterpret existing money snapshots.

## Open decisions and blockers

| Decision | Proposed position / gate |
| --- | --- |
| Currency / scale / rounding | Choose supported currency first; no assumed KHR/USD conversion; blocker for Phase 3 |
| Tax / discount / modifiers | Disabled initially; approve rules and schema extension before use |
| Shop timezone / receipt numbering | Candidate Asia/Phnom_Penh, immutable public reference; owner confirms |
| Inventory scope / units / overselling | Ingredients + packaged goods; no negative available stock proposed; confirm before Phase 5 |
| Reservation timeout / late payments | Provider-specific safe expiry and reconciliation; blocker for Phase 4/5 integration |
| Refunds / voids | No endpoint yet; need permissions, compensating finance/stock and provider support |
| Provider / merchant / callbacks | Not selected; use official contract and fake provider before separately authorized sandbox work |
| Backups / retention | Owner approves targets and history retention; no destructive deletion policy assumed |
| Browser auth / client storage | Secure native storage and first-party cookie/CSRF flow designed with Flutter later |
| Multi-store / offline / loyalty / delivery / customer / printers | Excluded unless newly requested; no tables or abstractions for them |
