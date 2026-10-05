# Intentional frontend design - provenance

| Field | Record |
| --- | --- |
| Name | `intentional-frontend-design` |
| Category | Frontend Engineering |
| Origin | Adapted upstream skill |
| Author / organization | Anthropic; adapted by Coffee Management System maintainers |
| Source repository | [anthropics/skills](https://github.com/anthropics/skills) |
| GitHub popularity | 179,660 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-03T20:38:10Z (UTC); not proof of skill-content freshness |
| License | Apache-2.0; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-09-03: substantive frontend-design revision |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

A reputable, script-free design workflow. Scoped to explicitly requested custom web surfaces so it cannot replace Flutter or add React.

## Adaptation and scope

Renamed and narrowed; removed design-studio/client assumptions and mandatory novelty/two-pass rules; added existing-stack and POS usability constraints.

## Security review

Reviewed full SKILL.md, its skill-level license, repository file tree and third-party notice applicability. No scripts/assets/hooks copied. The repository-wide notice lists components used by other skills; none is included in this adaptation.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `skills/frontend-design/SKILL.md`](https://github.com/anthropics/skills/blob/8a1541c4a3ffa5a20a5a91de0dcf3f0bab1d1ef4/skills/frontend-design/SKILL.md)
- [Agent Skills specification](https://agentskills.io/specification)
