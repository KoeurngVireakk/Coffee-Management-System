# Implementation roadmap

All items below are planned, not implemented.

1. **Auth and access foundations:** define cashier/manager/admin requirements; add Laravel Sanctum token authentication, validated sign-in/sign-out/current-user endpoints, policies, and Flutter sign-in/session handling. Decide secure token storage and one state-management approach. Verify unauthorized/forbidden responses and session expiry across both apps.
2. **Categories and Products:** catalog schema, API resources, authorized management, and tablet-friendly browsing.
3. **Orders and POS:** order/cart contract, server-authoritative totals, order item price snapshots, and transactional checkout. Decide tax/discount/currency rules first.
4. **Payments/KHQR:** choose a provider and sandbox; implement server-side payment verification, idempotency, callbacks, and reconciliation. A displayed QR or client response must not alone mark an order paid.
5. **Inventory:** stock movement ledger and adjustments tied to order/payment lifecycle decisions.
6. **Users/Roles and Settings:** administration UI and store configuration building on the access foundation.
7. **Reports:** authorized operational summaries based on completed transactional schemas.

Before expanding POS, decide whether offline checkout, multiple stores, printers, and device-specific peripherals are required. Those choices materially affect architecture and remain open.
