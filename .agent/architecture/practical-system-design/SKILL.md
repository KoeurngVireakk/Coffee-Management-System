---
name: practical-system-design
description: Evaluate consequential architecture or cross-app contract changes using this monorepo's existing boundaries, concrete invariants and the smallest justified design.
license: MIT
---

# Practical system design

Original project workflow. See [sources](README.md) and [decision record](references/decision-record.md).

Map the implemented behavior before proposing a design. The feature folders are placeholders, not existing order/payment workflows. Read the root README and `docs/architecture/README.md` and distinguish current constraints from open product decisions.

- State the user's requested outcome and the invariant the change must protect. Identify ownership of state across Flutter, Laravel, MySQL and external providers.
- Preserve feature-first Flutter domain boundaries and Laravel conventions. Prefer a modular application; justify an interface, event, worker, cache or separate service by actual complexity, reuse, reliability or measured load.
- Keep authoritative prices, permissions and payment outcomes on the backend. Model failure and retries at each external boundary; record which operation can safely repeat and how uncertain outcomes are reconciled.
- Separate provider I/O from short database transactions. Decide durability and observability before introducing asynchronous workflows. A synchronous queue or client retry does not solve crash recovery.
- Evaluate the simplest viable alternative and the cost of change. Do not introduce tenancy, offline checkout, event sourcing or distributed services merely because a POS system might eventually need them.
- Describe migration/rollout implications and the focused tests that distinguish the selected design from a broken one.

For a consequential decision, write a compact record only where the task warrants it. For a routine implementation, explain the boundary directly without generating an architecture document. Follow the security skill for auth/payment boundaries and the database skill for schema/locking details.
