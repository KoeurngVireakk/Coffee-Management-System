# MySQL design - provenance

| Field | Record |
| --- | --- |
| Name | `mysql-design` |
| Category | MySQL / Database Architecture |
| Origin | Original project skill; documentation references only |
| Author / organization | Coffee Management System maintainers; references by Oracle/MySQL and Laravel |
| Source repository | [mysql/mysql-server](https://github.com/mysql/mysql-server) |
| GitHub popularity | 12,441 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-09-29T22:54:42Z (UTC); not proof of skill-content freshness |
| License | MIT (original project text only); see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | Local skill created 2026-10-05. Exact manual-page meaningful update unavailable; server repository push is not a manual update. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Version-aware schema/query/transaction decisions fit MySQL and financial invariants better than bulk imported database recipes.

## Adaptation and scope

Written for this monorepo; no upstream skill, manual excerpt, SQL account-management script or MySQL code vendored.

## Security review

Read official transaction, exact-number and index manuals plus server license context. Restricted shared-data actions and explained that EXPLAIN ANALYZE executes a query. GPL/server terms and Oracle manual terms are not applied to independently authored instructions.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [MySQL InnoDB transactions](https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-model.html)
- [MySQL exact numeric types](https://dev.mysql.com/doc/refman/8.0/en/fixed-point-types.html)
- [MySQL index design](https://dev.mysql.com/doc/refman/8.0/en/optimization-indexes.html)
- [Project database contract](../../../docs/database/README.md)
