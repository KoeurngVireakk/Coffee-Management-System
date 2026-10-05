# Risk-based test matrix

Project-specific additions to the adapted testing workflow; BSD-3-Clause. These are cases to implement when the corresponding feature exists, not claims about current coverage.

| Boundary | Useful regression scenarios |
| --- | --- |
| Auth | Invalid credentials, expired/revoked token, sign-out, rate-limit response and session recovery |
| Authorization | Cashier vs manager permissions; actor A reads/mutates actor B's protected resource; server rejects privilege fields |
| Input | Missing/extra/invalid fields, allowed sort identifiers, bounds and stable validation errors |
| POS | Resize/rotate preserves cart; long Khmer text; enlarged text; keyboard/screen-reader access; offline error recovery |
| Orders/inventory | Authoritative price, rejected discount, simultaneous purchases, stock invariants and transaction rollback |
| Payments | Duplicate submission/notification, reused provider transaction, wrong amount/currency/merchant, timeout then late success, QR expiry and reconciliation |
| Database | Fresh vs upgraded schema, constraint behavior, safe rollout and query-plan assumptions on MySQL |
| Reports | Date boundaries, Asia/Phnom_Penh business day, void/refund rules and restricted visibility |

Use a deterministic fake clock/provider for expiry and late outcomes. A successful HTTP response alone is not enough for financial assertions: inspect persisted state and the number of applied transitions. Avoid live sandbox calls in ordinary unit/feature tests; a separately authorized sandbox check should be explicit and isolated.
