---
name: mysql-design
description: Design or review MySQL schemas, migrations, indexes and concurrency boundaries for catalog, orders, inventory and payments; use isolated data for executable checks.
license: MIT
---

# MySQL design

Original project instructions; official manuals are references only. See [sources and provenance](README.md).

Start with actual queries, invariants, supported MySQL version and existing migrations. Distinguish a proposed schema from a deployed schema. Read [coffee-shop decisions](references/coffee-schema-decisions.md) for order/payment changes.

- Choose keys, nullability, foreign-key actions and unique constraints from ownership/lifecycle rules. Do not cascade-delete financial history because a product or user is removed.
- Store money with exact representations and explicit currency/scale. Preserve historical order price snapshots. Keep application/provider conversion at a validated boundary rather than using floating-point arithmetic for totals.
- Plan indexes around real filters, joins and stable ordering, considering composite order, existing FK indexes, selectivity and write cost. Bound reports and pagination; check query counts before adding caching.
- Use InnoDB transactions, constraints and atomic updates or row locks to enforce concurrent invariants. Define consistent lock order, bounded deadlock retries and idempotency for workflows that can be repeated.
- Treat shared/deployed migrations as immutable. Stage risky changes as expand, backfill, validate, contract. Describe data-loss/locking implications and recovery rather than calling every `down()` safe.

Prefer read-only plans with synthetic or sanitized data. `EXPLAIN ANALYZE` executes the query; it is not a harmless substitute for `EXPLAIN`. Do not reset schemas, change accounts, apply destructive SQL or run migration rollbacks in a shared environment without explicit authorization and a verified target.

For MySQL-specific correctness, verify against an isolated MySQL instance; SQLite tests do not prove equivalent locks, collations, indexes or JSON behavior. Report target/version and evidence.
