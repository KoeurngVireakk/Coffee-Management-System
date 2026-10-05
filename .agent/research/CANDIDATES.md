# Candidate research and selection

Reviewed **2026-10-05, Asia/Bangkok**. GitHub counts below are exact repository-star snapshots returned by the REST API during this review. They describe broad repositories, not skill-specific quality or adoption. Repository push dates are UTC and may include automation, merges or unrelated files. The [source snapshot](sources.json) retains metadata, inspected file SHA-256 hashes, revisions and targeted commit history.

## Method

The skills.sh leaderboard was used for discovery, then candidate publishers were checked against GitHub and primary documentation. No registry installer was run. Reviewed main instructions, applicable license files, repository file trees, relevant rule/reference text and runtime/hook declarations where a candidate's design relied on them. The whole runtime of every large catalog was not audited; declining such packages keeps unreviewed code outside this repository.

Selection weighed task fit, recent substantive content changes, documentation specificity, publisher reputation, permission boundaries, license evidence and portability together. Stars were a signal, never a gate or score. Stable guidance in an active official repository can remain useful despite older skill-file dates. Archived sources were rejected for maintained imports. Documentation gaps were filled with explicitly original project guidance rather than presenting invented workflows as official skills.

## Comparison

| Repository / inspected candidate | Stars | Last repo push (UTC) | License evidence | Documentation / fit | Security or portability finding | Decision |
| --- | ---: | --- | --- | --- | --- | --- |
| [anthropics/skills](https://github.com/anthropics/skills): frontend-design | 179,660 | 2026-10-03 | Skill-local Apache-2.0 text | Strong design documentation; conditional web scope | Script-free selected skill; remove studio/novelty assumptions | Adapted |
| Same repository: webapp-testing | same | same | Skill-local Apache-2.0 | Good browser-testing recipes, limited mobile/backend fit | Explicitly says to run helper scripts before reading their source and use them as black boxes | Rejected as-is; no helpers executed |
| [flutter/agent-plugins](https://github.com/flutter/agent-plugins): architecture, responsive layout, widget tests | 3,026 | 2026-10-01 | BSD-3-Clause root license | Official, directly useful for Flutter POS | Upstream structure/package choices differ from this project; no generator/MCP/runtime rules needed | Adapted |
| Same repository: contributor code-review | same | same | BSD-3-Clause | Useful contextual review and self-critique | Vendor artifact directory and uninstalled companion skills removed; contributor workflow is not a universal standard | Adapted |
| Same repository: add-integration-test | same | same | BSD-3-Clause | Useful concepts, mixed legacy/new setup instructions | Mandates Flutter Driver entrypoint instrumentation and MCP workflow; unnecessary for this documentation task | Rejected as-is; use current integration-test docs |
| [laravel/boost](https://github.com/laravel/boost): Laravel best-practices and rules | 3,645 | 2026-10-04 | MIT text, Taylor Otwell | Strong framework-maintainer rule set; best PHP fit | Blade templates read as text only; no Boost install or MCP tool assumption retained | Adapted |
| [laravel/docs](https://github.com/laravel/docs) | 3,500 | 2026-10-03 | MIT | Version-specific authoritative REST/auth/validation references | Documentation only; verify against installed Laravel 13 | Reference only |
| [openai/skills](https://github.com/openai/skills): security-threat-model | 27,881 | 2026-09-08 | Skill-local Apache-2.0 | Strong language-neutral evidence workflow | Remove tool/output coupling and unconditional pause; add local provider-neutral invariants | Adapted |
| Same repository: security-best-practices | same | same | Skill-local Apache-2.0 | Good supported-language guidance | Declared support is Python, JS/TS and Go; PHP/Dart coverage is absent | Rejected for stack mismatch |
| Same repository: gh-fix-ci | same | same | Per-skill license exists in tree; no file copied | Useful PR-log workflow | Depends on a Python helper, gh auth and mandatory approval-plan loop; unnecessary for passive/local CI guidance | Replaced with original CI guide |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills): web-design-guidelines | 31,934 | 2026-08-28 | README declares MIT; no full license/notice file in inspected tree | Reputable web review entrypoint; lower native-POS fit | Delegates to freshly fetched `main` rules each review; complete redistributable notice not available | Deferred; no text copied |
| [OWASP/API-Security](https://github.com/OWASP/API-Security) | 2,374 | 2026-09-22 | Inspected LICENSE is CC-BY-SA-4.0 despite API `NOASSERTION` | Authoritative API risk taxonomy | Documentation, not an agent installer; avoid silently relicensing share-alike text | Reference only |
| [OWASP/CheatSheetSeries](https://github.com/OWASP/CheatSheetSeries) | 33,421 | 2026-10-04 | CC-BY-SA-4.0 metadata/README | Strong practical secure-coding references | No text bundle or scripts installed; direct official links | Reference only |
| [google/eng-practices](https://github.com/google/eng-practices) | 23,301 | 2024-09-19 | CC-BY-3.0 inspected text | Historically respected review guidance | GitHub reports repository archived; fails maintained-import requirement | Rejected for maintained collection |
| [mysql/mysql-server](https://github.com/mysql/mysql-server) + official manual | 12,441 | 2026-09-29 | Server GPLv2/third-party terms; manuals have separate Oracle terms | Authoritative engine facts, not an agent skill | Server popularity/activity does not date manual pages; no code/manual copying | Reference only; original database guide |
| [github/docs](https://github.com/github/docs) | 20,947 | 2026-10-02 | CC-BY-4.0 docs | Strong CI/Git workflow and security references | No actions/hooks installed; no privileged PR execution patterns imported | Reference only; original CI/Git guides |
| [w3c/wcag](https://github.com/w3c/wcag) + WCAG 2.2 | 1,504 | 2026-10-04 | W3C Document License linked by repository | Normative accessibility criteria | Standard text has redistribution/modification constraints; native checks still needed | Reference only; original POS guide |
| [obra/superpowers](https://github.com/obra/superpowers): using-superpowers/TDD | 295,315 | 2026-09-27 | MIT | Popular, detailed workflow system | Entry skill requires loading for essentially every response/action; broad forced process plus shell helper surface conflicts with small task-scoped collection | Rejected as-is; not evidence of credential theft |
| [affaan-m/ECC](https://github.com/affaan-m/ECC), formerly everything-claude-code | 273,025 | 2026-10-02 | MIT | Broad community library; relevant Laravel/MySQL files exist | Many runtime/session-observation/cost-tracking hooks; MySQL file includes account-deletion recipes; wider surface and overlap than needed | Rejected bundle; no hooks/scripts copied |
| [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) | 76,508 | 2026-09-18 | README Apache-2.0 declaration; individual licenses vary | Broad discovery catalog | Reviewed webapp-testing is byte-identical to upstream Anthropic file and retains black-box-helper instruction | Rejected duplicate/bulk import |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 133,067 | 2026-10-03 | MIT inspected text | Extensive design/search documentation | Python search/data/CLI dependency and persistent design-system outputs unnecessary; no malicious behavior established | Deferred for scope/runtime weight |
| [agentskills/agentskills](https://github.com/agentskills/agentskills) | 25,911 | 2026-08-09 | Apache-2.0 repo; docs CC-BY-4.0 | Maintained format specification | Format used; no reference CLI/library installed | Format reference only |

Seventeen GitHub repositories were researched; multiple candidates within a repository are shown separately. None was selected because it ranked first by stars.

## Meaningful update evidence

Path-level history is recorded separately from repository activity:

- Anthropic frontend-design: **2026-09-03**, substantive design-default revision.
- Flutter architecture, responsive layout and widget-test skills: **2026-04-21**, original skill additions; the repository remains active. The contributor review workflow was introduced **2026-05-08**, with related writing-reference maintenance **2026-05-11**.
- Laravel best-practices subtree: **2026-09-30**, command/template maintenance; **2026-09-04**, action-example update. The adaptation reads actual versioned source rules rather than inheriting upstream tool requirements.
- OpenAI threat-model: **2026-02-02**, substantive workflow addition; stable guidance in an active repository.
- OWASP REST security cheat sheet: **2026-10-04**, cache-scope/status/security clarifications.
- Vercel entrypoint's recent inspected commits are January formatting/version/reference maintenance, not proof that its dynamically fetched rules were recently reviewed.
- GitHub's inspected secure-use page history contains link/version maintenance. Its precise last substantive security-text edit was not established; it is not reported as the repository's last push date.
- Original local skills were created **2026-10-05**. MySQL manual/NBC PDF meaningful revision dates were not established; repository pushes and search crawl dates are not substitutes.

No fabricated freshness, skill-specific star count or install count is assigned to a new local skill. Every installed README states its origin and limits.

## Selection outcome

Six adapted workflows: frontend design, Flutter architecture/layout, Laravel REST, code review, widget-oriented QA, and security threat modeling. Five original guides: MySQL design, accessible Cambodian POS, practical cross-app design, safe CI maintenance, and preservation of Git state. Generic backend routing reuses those guides instead of adding a duplicate skill.

Official [NBC/Bakong payment references](https://bakong.nbc.gov.kh/en/download/KHQR/integration/QR%20Payment%20Integration.pdf) inform provider verification questions, but no KHQR SDK or API contract is installed. Provider-specific rules must be verified with the merchant's current integration documentation. Reputation does not guarantee freshness or remove license constraints.
