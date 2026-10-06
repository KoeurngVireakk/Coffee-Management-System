# Payment settlement foundation (Phase 4)

Base `/api/v1`. Existing Sanctum bearer/staff ability and active cashier/manager/admin identity required. Cashier operates on own orders; manager/admin may operate on shop orders. Scoped order lookup plus OrderPolicy/PaymentPolicy enforce object access. Phase 5 integrates [tracked inventory finalization](inventory.md); no Flutter implementation, no refunds/split/partial payments, no receipt-printing endpoint.

## Actual endpoints

| Method / URL | Request / roles | Success | Errors |
| --- | --- | --- | --- |
| POST `/orders/{order}/payments/cash` | Authorized POS staff; strict tender_minor string + Idempotency-Key | 201 first settlement / 200 same replay | 401, 403 account/ability/action, 404 hidden/missing order, 409 paid/active attempt/changed key intent, 422 tender/key/unknown fields, 429 |
| POST `/orders/{order}/payments/external` | Authorized POS staff; empty body + Idempotency-Key | 201 new persisted attempt / 200 existing result when an approved adapter is available | 401/403/404/409/422/429; **503 by default: no real provider configured** |
| GET `/orders/{order}/payments` | Authorized own/shop order; page/per_page only | 200 paginated Payment Resources | 401/403/404, 422 invalid/unknown query, 429 |
| POST `/orders/{order}/payments/{payment}/reconcile` | Authorized POS staff; empty body; payment must belong to scoped order | 200 persisted verified/current/quarantined result | 401/403/404, 409 cash-method conflict, 422 unknown fields, 429; **503 without configured adapter** |

Order uses ORD-ULID URI; payment is numeric ID constrained to its order. GET supports HEAD. Every payment route is limited to 30 requests/minute per authenticated actor; successes/invalid attempts count, 429 includes Retry-After. Existing role semantics give all current read-capable roles POS permission. No generic provider callback/webhook endpoint exists because no callback authentication contract is approved.

## Cash intent / authoritative settlement

```http
POST /api/v1/orders/ORD-01K6WY00000000000000000000/payments/cash
Authorization: Bearer SYNTHETIC_TOKEN_PLACEHOLDER
Content-Type: application/json
Accept: application/json
Idempotency-Key: 6583ca16-7074-48ae-83a9-5b01b0d6a981
```

```json
{"tender_minor":"1000"}
```

tender_minor is canonical integer-cent string 0-9999999999. No floats/JSON numbers/fractional values/leading zeros. It must cover the persisted order total; the cap is administrative, not suggested cash tender. Idempotency-Key uses the checkout convention: one case-sensitive ASCII header, 8-64 characters, first alphanumeric then alphanumeric/dot/underscore/hyphen. No body key transport.

Only tender_minor is writable. Expected amount, currency, status, change, owner/initiated_by, paid_at, provider/transaction IDs, signatures, discount/tax and arbitrary fields are rejected with 422. USD total/currency and change are derived from immutable order records, not current catalog/UI totals. Cash confirmation is an authorized staff action; client paid flags are never proof.

Order row locks precede Payment locks. One transaction creates a confirmed cash attempt, stores initiator and verified time, selects its owning-order accepted FK and moves pending_payment -> paid with paid_at. Snapshot items/totals/creator remain unchanged. Shared OrderSettlementService consumes valid tracked reservation snapshots and appends deterministic sale movements in that same transaction; untracked orders retain their original no-stock path. A controlled failure rolls back payment, accepted state and all local stock effects together.

Example 201 result for order total 325 cents:

```json
{
  "data": {
    "id": 1,
    "method": "cash",
    "status": "confirmed",
    "expected_amount_minor": "325",
    "currency": "USD",
    "tender_minor": "1000",
    "change_minor": "675",
    "provider": null,
    "reconciliation_required": false,
    "expires_at": null,
    "verified_at": "2026-10-06T10:00:00+00:00",
    "created_at": "2026-10-06T10:00:00+00:00",
    "qr_payload": null
  }
}
```

The same per-order key/method/tender returns existing Payment with 200 even after the order is paid. Changing tender/method under that key is 409. A different key cannot settle a paid order; concurrent cash requests have one accepted winner. Cash is blocked while an external attempt is initiated/pending/uncertain or retained evidence still requires review. A verified failure/expiry without received-funds evidence clears the active pointer and permits another attempt.

## External/provider implementation gate

**Implemented foundation:** PaymentProvider contract, typed identity/intent/initiation/verification objects, persisted attempt-before-I/O workflow, safe display field, strict verification, quarantined immutable observations, manually triggerable reconciliation, idempotency and fake-provider tests.

**Not implemented:** real Bakong/bank/KHQR HTTP calls, merchant provisioning, credentials, official endpoints/signatures/callback authentication, sandbox/live traffic, durable recovery worker or scheduled reconciliation. Production binds UnconfiguredPaymentProvider and returns 503 before starting external intent. Test-only FakePaymentProvider is never a production binding and its SYNTHETIC-QR payload is not KHQR.

No provider/merchant/client proof fields are accepted on external initiation or reconciliation. The configured trusted adapter supplies identity and verifies server-to-server results. Both services reject starting inside an outer transaction, so provider I/O never spans SQL locks. Approved future adapters must implement HTTPS/timeouts/authentication/response normalization from the merchant's current official contract; no such contract is guessed here.

Initiation persists provider/merchant/correlation/expected amount/currency and active pointer before I/O, then commits. A valid initiation reply becomes pending and stores display/expiry information; displaying it is not paid. Timeout becomes uncertain and blocks another attempt. Crash after intent commit can be reconciled using its stable correlation; replay never blindly resends initiation. QR is exposed only while pending and before display expiry. Expiry time alone does not mark payment/order terminal; verified provider semantics do.

## Verification and reconciliation

For confirmed provider evidence, compare provider identity, transaction ID, intended order reference, attempt correlation, merchant, exact amount and USD currency. Only matching eligible evidence may confirm/select an accepted payment and mark paid atomically. Monetary provider values must be native exact integers, never silently coerced float/string. Nullable unique identities are not proof; nonblank verified identity/context is required.

Repeated verified transaction/result is idempotent. Globally unique `(provider,external_transaction_id)` on immutable payment_evidence prevents crediting two orders; payments also uniquely retain their primary confirmed identity. Evidence preserves normalized transaction facts, not credentials/raw provider payloads. Mismatches create review state and never pay an order; they cannot be dismissed by a later pending/failed query while received-funds observations remain.

A second distinct transaction on the same attempt appends evidence and sets reconciliation_required; the original confirmed identity/accepted pointer stay fixed. Late funds after another cash/verified settlement are retained and flagged, never silently discarded or accepted twice. Verified failure/expiry is terminal; a later trusted confirmation records funds plus review requirement without automatically resurrecting the attempt/order. Contradictory facts for an existing transaction are quarantined.

Manual POST reconcile/service is a recovery trigger, not a durability claim. Provider timeout/lost callback/local rollback/crash leaves a persisted attempt suitable for a subsequent trusted status query. No automatic worker runs and no client polling is claimed to recover crashes reliably. Human resolution/refund/reassignment of quarantined observations requires a later approved workflow; this API cannot casually clear review or change financial facts.

## Read/resources and errors

Payment list defaults 25, max 100/page, page 1-10000; order created_at DESC/id DESC, stable standard data/links/meta pagination. No client SQL sort/owner/provider filters. Resources expose only the example fields; no attempt key/hash, merchant, external transaction identity, initiator/internal authority, credentials, signatures or evidence payloads.

Paid OrderResource adds accepted_payment using the same safe Resource and paid_at; pending order response remains compatible. These are persisted settlement summaries, not a final printed receipt. No ordinary Order PUT/PATCH/DELETE route; narrow transaction-only selection methods enforce owning payment, eligibility and optimistic current-state predicates. Immutable amounts/items/creator cannot change; paid selection cannot be replaced by a stale model.

401/403/404 retain auth/scope behavior; 422 uses message/errors (header failures under idempotency_key). 409 uses message for already-settled/active-attempt/conflicting-intent errors. 429 includes Retry-After. 503 clearly reports external provider unavailable. API errors use no-store/private; deployment requires HTTPS and APP_DEBUG=false. See [Phase 4 verification](../system-analysis/phase-4-verification.md) for actual test/concurrency/upgrade results; [OpenAPI](openapi.json) is synchronized with implemented routes.

## Phase 5 settlement integration

Payment confirmation, stock consumption and paid transition share one local transaction. Configuration changes never disable consumption for already-tracked orders. Tracked reservations must exist, remain reserved and have matching sale evidence before acceptance. A confirmed payment requiring reconciliation is ineligible for finalization; distinct/mismatched observations retain review state and cannot bypass inventory. Safe order cancellation requires verified no-settlement state and releases stock once. Late received funds after cancellation are quarantined without consuming released stock. Production external adapter remains disabled; all integration verification uses the test fake.
