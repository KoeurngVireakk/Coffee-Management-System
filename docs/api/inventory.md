# Inventory, recipes and reservations (Phase 5)

Base `/api/v1`, Sanctum bearer with staff ability and active recognized staff. Laravel owns exact stock balances; clients submit intent only. No delete endpoint, unit conversion, supplier, warehouse, lot, refund or automatic reservation expiry workflow.

## Deployment cutover

`INVENTORY_TRACKING_ENABLED=false` is the default, read through `config/inventory.php`. Deployment configuration is the only switch; no API can toggle it. Existing orders retain their immutable `inventory_tracked` value. Enabling tracking affects new checkouts only; retrying an old checkout key returns the original order even after the switch changes. Prepare recipes and auditable opening balances before activation. Disabling tracking later does not disable consumption/release for already-tracked orders.

## Exact quantity contract

Inventory, recipes, reservations and movement deltas use DECIMAL(14,4). JSON quantities are strings; accept canonical integer portions with optional 1-4 fractional digits and normalize to four places. Maximum magnitude is `9999999999.9999`. HTTP middleware trims surrounding whitespace before validation; embedded whitespace, numbers/floats, scientific notation, leading zeros, plus signs, excess precision and negative zero are rejected. Direct Quantity helper calls require already-trimmed strings. Signed values apply only to movement deltas. Backend arithmetic uses checked integer units of 0.0001; overflow is rejected, never rounded.

Base units are `g`, `ml`, `unit`, immutable after creation. No kg/L conversion. `available = on_hand - reserved`; `low_stock = available <= reorder_level`. Items begin at zero; initial quantity comes from an opening movement.

## Actual endpoints

| Method / path | Access / request | Result |
| --- | --- | --- |
| GET `/inventory/items` | All staff; status active (default)/inactive/all, literal search <=80, low_stock string 0/1, page/per_page | 200 paginated items, name ASC/id ASC |
| POST `/inventory/items` | Manager/admin; sku, name, base_unit, optional reorder_level/is_active | 201 zero balances |
| GET `/inventory/items/{inventoryItem}` | All staff | 200 item |
| PUT/PATCH `/inventory/items/{inventoryItem}` | Manager/admin; sku/name/reorder_level/is_active only | 200 metadata; retire via is_active=false |
| GET `/inventory/items/{inventoryItem}/movements` | Manager/admin; page/per_page only | 200 ledger, created_at DESC/id DESC |
| POST `/inventory/items/{inventoryItem}/movements` | Manager/admin; reason, quantity_delta, optional note; Idempotency-Key required | 201 movement / 200 same replay |
| GET `/products/{product}/recipe` | Manager/admin | 200 complete recipe |
| PUT `/products/{product}/recipe` | Manager/admin; ingredients array | 200 atomically replaced recipe |
| POST `/orders/{order}/cancel` | Cashier own / manager/admin shop; empty body | 200 cancelled OrderResource / same replay |

Numeric item/product IDs, ORD-ULID order reference. HEAD follows GET. Pagination defaults 25, max100, page<=10000. List/write Requests reject unknown query/body/nested fields. Inventory writes, recipe replacement and cancellation share a 60/minute actor limit with Retry-After. Existing checkout and payment limits remain unchanged.

401 authentication; 403 account/ability/action denial; 404 missing or hidden order/item/product; 422 invalid quantity/key/property/recipe or unavailable stock at checkout; 409 changed movement-key intent, prohibited opening, stock reserved against a negative movement, unsafe cancellation or invalid finalization; 429 write limit. API errors are JSON with existing message/errors shapes. Validation failures do not discard a future client's cart or editable intent.

## Item and recipe shapes

Item create example: `{"sku":"BEANS","name":"Coffee beans","base_unit":"g","reorder_level":"100"}`. Balances, available, actor, order, operation keys and tracking flag cannot be written through metadata. SKU is uppercased/trimmed, case-insensitively unique; allowed alphanumeric/underscore/hyphen, <=64. Name<=160, is_active native boolean. Item response fields: id, sku, name, base_unit, on_hand, reserved, available, reorder_level, is_active, low_stock, created_at, updated_at. Every quantity is a four-place string; retirement retains ledger/reservations.

Recipe request:

```json
{"ingredients":[{"inventory_item_id":1,"quantity":"18"},{"inventory_item_id":2,"quantity":"180.0000"}]}
```

Recipe quantities are positive per sold product unit. At most100 unique ingredient IDs, no extra properties; every referenced stock item must exist and be active under locks. Empty array clears a recipe; tracked checkout then rejects that product. Response: data.product_id and data.ingredients with inventory_item_id, sku, name, base_unit, is_active, quantity. A parent product exclusive lock protects complete replacement; checkout shared product locks plus current locking recipe reads prevent mixed/old recipe snapshots. Existing order reservations keep their original quantities after later recipe edits or item retirement.

## Auditable manual movements

```json
{"reason":"receipt","quantity_delta":"5000.0000","note":"Weekly bean delivery"}
```

Use one Idempotency-Key with the existing 8-64 ASCII alphanumeric/dot/underscore/hyphen convention. Identity is actor + key across all items. Same normalized item/reason/delta/trimmed note returns the original movement; changed intent returns409. Concurrent duplicate requests cannot move stock twice.

opening_balance/receipt require positive deltas; waste negative; adjustment nonzero either sign with a nonblank explanatory note (<=500 characters). Opening is allowed only before any movement history, not whenever stock reaches zero. Later receipts/adjustments preserve history. sale is system-only, tied to an order and deterministic `sale:<order-id>:<inventory-item-id>` identity. Release changes reserved only and does not append an on-hand movement. Negative manual movements cannot reduce on_hand below reserved; ledger insertion and balance update commit together.

Movement Resource exposes id, inventory_item_id, order_id, actor_id, quantity_delta, reason, note, created_at; actor/order are derived by the backend. Internal request hashes, keys and provider proof are excluded. Detailed ledger reads are restricted to management.

## Checkout, settlement and cancellation

Tracking off preserves existing checkout: no recipe/reservation/stock locks. Tracking on requires a recipe for every product, aggregates shared ingredients with checked quantity multiplication, locks inventory IDs ascending, checks active/available, then atomically persists order/items/reservation snapshots and increments reserved. Failure rolls everything back. Checkout never decreases on_hand.

Cash and trusted fake-provider confirmation use the same OrderSettlementService. It finalizes inside the existing payment transaction, consumes each tracked reserved snapshot, decreases on_hand/reserved, appends one sale movement per ingredient and marks reservations consumed before selecting the accepted payment/paid timestamp. Replay cannot consume again. Retired stock is still consumable for an existing valid reservation. Untracked historical orders settle without stock effects. Production external payments remain503 pending an approved contract; no real KHQR traffic was added.

Cancellation locks order/payment state before stock. Only pending orders with no accepted/active/unresolved/review payment may cancel. Paid orders cannot cancel. A verified failed/expired attempt without received-funds review can permit cancellation. Tracked cancellation decreases reserved and marks snapshots released while on_hand stays fixed; untracked cancellation has no stock effect. Repeat cancellation returns the same terminal order. Late verified funds on a cancelled order retain evidence/reconciliation and do not consume released stock. Automatic expiry, paid void/refund and client proof are excluded.

## Read-only reconciliation and limits

`php artisan inventory:check --json` checks balances vs the movement ledger, reserved totals, reservation lifecycle and matching sale quantities in a consistent read-only snapshot. It reports bounded IDs/codes/counts and fails on discrepancies; it never repairs stock. Restrict CLI access operationally. The command is not an API or a scheduled worker. Manual cancellation currently releases abandoned reservations; automatic expiry requires a later approved policy.

See [Phase 5 verification](../system-analysis/phase-5-verification.md) for actual MySQL races, upgrade and regression evidence, and [OpenAPI](openapi.json) for machine-readable contracts.

Future client limit: catalog ProductResource does not expose a computed per-product stock-availability read model. Stock-item quantities/status and authoritative checkout errors are available; advance product display and verified Khmer/English messages remain later client contracts.
