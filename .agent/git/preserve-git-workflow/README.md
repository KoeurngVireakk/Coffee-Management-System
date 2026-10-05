# Preserve Git workflow - provenance

| Field | Record |
| --- | --- |
| Name | `preserve-git-workflow` |
| Category | Git / GitHub Workflow |
| Origin | Original project skill; documentation references only |
| Author / organization | Coffee Management System maintainers; references by GitHub |
| Source repository | [github/docs](https://github.com/github/docs) |
| GitHub popularity | 20,947 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-02T20:35:10Z (UTC); not proof of skill-content freshness |
| License | MIT (original project text only); see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | Local skill created 2026-10-05; documentation meaningful update not independently established. |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

User staging, one root repository, focused review and explicit publication boundaries are more relevant than bulk Git automation.

## Adaptation and scope

Original workflow referencing GitHub flow; no shell helpers, aggressive cleanup commands, hooks or automatic commit/push instructions.

## Security review

Preserves staged and unstaged work and does not execute issue/PR instructions. No external write or branch protection setting changes are implied.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Project contribution rules](../../../docs/project/contributing.md)
