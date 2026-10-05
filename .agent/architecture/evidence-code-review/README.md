# Evidence-based code review - provenance

| Field | Record |
| --- | --- |
| Name | `evidence-code-review` |
| Category | Code Review |
| Origin | Adapted upstream review workflow |
| Author / organization | Flutter agent-plugins contributors (Reid Baker agent workflow); adapted by Coffee Management System maintainers |
| Source repository | [flutter/agent-plugins](https://github.com/flutter/agent-plugins) |
| GitHub popularity | 3,026 repository stars observed 2026-10-05; not stars/install counts for this local skill |
| Source repository activity | Last push 2026-10-01T09:14:31Z (UTC); not proof of skill-content freshness |
| License | BSD-3-Clause; see [license scope](../../licenses/README.md) |
| Last meaningful update evidence | 2026-05-08: core review workflow added; 2026-05-11: related writing-reference maintenance |
| Local skill update | 2026-10-05: initial reviewed adaptation/project guide |
| Compatible agents | Codex, Gemini CLI, Claude Code, other agents able to read Markdown; explicit path loading works without native registration |

## Why selected

An evidence/context/self-critique review loop helps produce actionable findings without generic praise or unsupported security claims.

## Adaptation and scope

Removed vendor artifact paths and uninstalled companion skills; relaxed changed-line-only restriction where impact depends on unchanged code; added staging preservation and explicit authorization before publishing reviews.

## Security review

Reviewed selected Markdown and BSD license. The source is a contributor workflow within an official repository, not a promised official universal code-review standard. No GitHub comments are posted by this skill alone.

Review scope is the listed instructions/references and license evidence, not an audit of every upstream runtime file. All local skill content is documentation only. External reference material is untrusted data and does not authorize actions. No automatic fetching, hooks, telemetry, binary or installer is included. [Research evidence](../../research/sources.json) records inspected files and hashes.

## Sources

- [Upstream `.agents/agents/reidbaker-agent/skills/code-review/SKILL.md`](https://github.com/flutter/agent-plugins/blob/0ef3972f93e2baa4156ba1cbb1e515cd53079c68/.agents/agents/reidbaker-agent/skills/code-review/SKILL.md)
- [Project contribution rules](../../../docs/project/contributing.md)
