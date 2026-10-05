---
name: evidence-code-review
description: Review a specified local diff or pull request for actionable correctness, security, compatibility and maintainability defects, with evidence and calibrated severity.
license: BSD-3-Clause
---

# Evidence-based code review

Adapted from the code-review workflow in Flutter's agent-plugins repository. Vendor artifact paths and dependency on uninstalled writing/review skills are removed. See [provenance](README.md) and [license](../../licenses/flutter-bsd-3-clause.txt).

Establish the requested review boundary: staged changes, unstaged changes, a commit range or a PR. Inspect `git status` and both relevant diffs without changing staging. For untracked files, inspect their contents explicitly. Read callers, tests and framework configuration needed to assess changed behavior.

- Prioritize concrete defects: broken contracts, missing ownership checks, unsafe input, money/race/retry bugs, lost UI state, migration risk and absent regression coverage for those behaviors.
- Anchor a finding at the relevant changed line when possible; follow unchanged dependencies when they establish impact. Do not invent a diff restriction that hides a defect caused by the change.
- Explain the trigger, observable impact and a practical correction. Verify framework claims for the installed version. Mark assumptions and confidence when evidence is incomplete.
- Re-read findings and remove duplicates, style preferences presented as bugs, unsupported exploit claims and praise-only comments. Use the project's established conventions.
- Keep review read-only unless fixes are requested. Return results locally; posting GitHub comments/reviews requires explicit authorization.

Use [finding criteria](references/finding-criteria.md) for severity and output. A clean review means no actionable defect was found in the inspected scope; it is not a guarantee about the entire application.
