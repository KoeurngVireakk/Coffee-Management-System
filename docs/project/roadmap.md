# Implementation roadmap

Backend Phases 1-2 and Phase 3 unpaid Orders checkout/history are implemented. Flutter remains scaffolded; the remaining business modules below are planned. See [system analysis](../system-analysis/README.md) and [backend implementation plan](../system-analysis/backend-plan.md) for requirements, diagrams and acceptance gates.

1. **Auth and access foundations:** backend complete for this milestone: Sanctum bearer login/logout/me, eight-hour expiry, live staff-account checks, fixed roles/gates, user-view policy, validation/resources/throttling and negative-path tests. No staff administration or public registration. Flutter sign-in/session handling, native secure storage, first-party Web cookie/CSRF flow and state-management selection remain planned; cross-app expiry handling is not verified.
2. **Categories and Products:** backend implemented: schemas, policies, Resources, strict manager/admin management, retirement/reactivation, paginated literal search and exact USD-cent prices. Flutter/tablet browsing remains planned. See [Phase 2 verification](../system-analysis/phase-2-verification.md).
3. **Orders and POS:** backend unpaid checkout/history implemented: USD cents, zero tax/discount, no options, immutable snapshots, scoped reads and actor-key replay; inventory_tracked=false. Paid settlement/receipts, stock and Flutter POS remain planned. See [Phase 3 verification](../system-analysis/phase-3-verification.md).
4. **Payments/KHQR:** choose a provider and sandbox; implement server-side payment verification, idempotency, callbacks, and reconciliation. A displayed QR or client response must not alone mark an order paid.
5. **Inventory:** stock movement ledger and adjustments tied to order/payment lifecycle decisions.
6. **Users/Roles and Settings:** administration UI and store configuration building on the access foundation.
7. **Reports:** authorized operational summaries based on completed transactional schemas.

Before expanding POS, decide whether offline checkout, multiple stores, printers, and device-specific peripherals are required. Those choices materially affect architecture and remain open.
