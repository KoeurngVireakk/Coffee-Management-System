# Safe CI maintenance - provenance

| Field | Record |
| --- | --- |
| Name | `safe-ci-maintenance` |
| Category | DevOps / CI/CD |
| Origin | Original project skill; documentation references only |
| Author / organization | Coffee Management System maintainers; references by GitHub |
| Source repository | [github/docs](https://github.com/github/docs) |
| GitHub popularity | 20,947 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-02T20:35:10Z (UTC); not proof of skill-content freshness |
| License | MIT (original project text only); see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | Local skill created 2026-10-05. Latest inspected GitHub page history was link/version maintenance; exact last substantive security-text edit not established. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

Least-privilege CI, lockfile reproducibility, runner diagnosis and no live-provider tests match the current GitHub team workflow.

## Adaptation and scope

Original guidance; no gh-fix-ci Python helper, mandatory approval-plan loop, GitHub credential scopes or deployment provider added.

## Security review

Official GitHub guidance referenced only (CC-BY-4.0 docs not copied). Passive/local diagnostics by default; untrusted PR execution in privileged workflow contexts is explicitly excluded. Existing CI is not changed.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
- [Current pipeline](../../../.github/workflows/ci.yml)
