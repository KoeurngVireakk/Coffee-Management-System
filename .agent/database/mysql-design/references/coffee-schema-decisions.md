# Coffee-shop schema decisions

Original project checklist; no business schema is prescribed or implemented.

Before choosing columns, settle currency and rounding rules, tax/discount ownership, whether orders can be edited after payment, stock reservation timing, refund behavior, and whether multiple stores are in scope. KHR/USD and an exchange rate are product decisions; do not invent a rate or assume two currencies are interchangeable.

Represent an order and its payment attempts separately when retries/reconciliation require distinct lifecycles. Use a provider-scoped unique transaction identity to prevent one external payment from satisfying multiple orders. Keep sensitive provider tokens out of financial rows and migrations.

For an inventory movement, capture the reason and traceable originating operation. Decide who can adjust stock and how corrections are recorded. A stock balance column alone is insufficient evidence of why stock changed; introduce a ledger only when inventory scope requires it.

Document candidate indexes with the queries they serve and verify using representative data. A report's date range, business timezone and final/void/refunded order rules must be explicit. Store interoperable timestamps and handle Asia/Phnom_Penh business boundaries deliberately; do not infer business time from the development machine.
