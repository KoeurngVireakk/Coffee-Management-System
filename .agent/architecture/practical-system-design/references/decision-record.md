# Compact decision record

Original project template. Fill with evidence; omit irrelevant fields.

- Context: requested behavior, current implementation and constraints.
- Invariant and owner: what must remain true, and which component enforces it.
- Options: simplest viable approach and the material alternative.
- Decision: concrete boundaries and why they fit current needs.
- Consequences: dependencies, failure modes, rollout/migration and operating cost.
- Verification: observable scenarios proving the invariant, including failure/retry paths.
- Unknowns: product/provider facts that still need confirmation.

Example question, not a prescribed implementation: can a payment-status refresh be read-only while a reconciliation operation applies a verified external transaction exactly once? Decide from the chosen provider's actual contract, persisted state and authorization requirements.
