# Payment and KHQR invariants

Project-specific additions to the adapted Apache-2.0 workflow. NBC/Bakong manuals are references only; no SDK or provider code is installed.

Select the merchant's actual bank/provider, current official integration contract, sandbox access and settlement/reconciliation requirements before implementing. The linked NBC PDFs are historical public references with uncertain revision freshness; verify endpoint/status/auth details with the provider. Do not treat an unofficial community SDK as NBC endorsement.

1. A displayed/scanned QR, client success message or screenshot is not proof of settlement. Obtain a trustworthy server-to-server verification result and match merchant/recipient, exact amount, currency, transaction identity and the intended payment attempt.
2. Persist order and payment-attempt lifecycles explicitly. A request timeout can mean the payment completed remotely; keep the outcome uncertain and reconcile before a repeated state-changing request.
3. A verified external transaction must be applied at most once and must not pay multiple orders. Use provider-scoped uniqueness and an atomic database transition. Support repeated notifications and concurrent polls without duplicate ledger/stock effects.
4. Treat a callback as authentic only through the provider's documented mechanism. If signatures are unsupported, treat notifications as hints and confirm through the authenticated provider API. Never invent a webhook-signature contract.
5. Use bounded polling/backoff, expiry and recovery according to the chosen provider. Rate limiting must protect provider quotas without preventing legitimate reconciliation. Do not run provider I/O while holding long database locks.
6. A QR-derived MD5/hash is a correlation field when the API uses it; it is not encryption or an authentication signature. Keep access tokens on Laravel, validate responses, and redact account/token/payment details from logs.

Test wrong recipient/amount/currency, replay/reused transaction, duplicate notification, concurrent poll, expired QR, timeout with late success and refund/correction permissions using synthetic fixtures. These are design invariants to implement when Payments begins, not current application behavior.
