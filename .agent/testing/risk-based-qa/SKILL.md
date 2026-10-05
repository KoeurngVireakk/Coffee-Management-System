---
name: risk-based-qa
description: Plan and run focused Flutter/Laravel tests for meaningful behavior, regression risks and integration boundaries, using isolated databases and fake payment providers.
license: BSD-3-Clause
---

# Risk-based QA

Adapted from Flutter's widget-testing skill with project-specific backend coverage. Integration guidance uses official testing documentation; the inspected skill's mandatory legacy-driver setup is not adopted. See [provenance](README.md) and [license](../../licenses/flutter-bsd-3-clause.txt).

Define expected behavior before choosing tests. Inspect existing test tools and architecture. Do not add a test framework, mock generator or arbitrary coverage threshold just to follow this skill.

- Use domain/unit tests for deterministic rules, widget tests for state and interaction, Laravel feature tests for HTTP/auth/data boundaries, and integration tests for a small set of real end-to-end workflows.
- Test invalid/denied/error behavior that could break the invariant, not only happy-path snapshots. Read [risk matrix](references/risk-matrix.md) when auth, money, inventory or device UX changes.
- In Flutter, pump the state change deliberately. Do not blindly `pumpAndSettle()` while an indefinite spinner or repeated async work is active. Dispose test overrides and keep layout/text-scale scenarios deterministic.
- In Laravel, fake providers and prevent stray outbound requests. Verify authorization with separate actors and inspect database state as well as status codes. MySQL-specific concurrency/migration behavior needs an isolated MySQL test; in-memory SQLite alone is insufficient.
- Keep destructive setup inside a verified, disposable test environment. Never point resets or real payment traffic at a developer's shared database or provider account. Use synthetic secrets and payment data.

Run the narrowest useful test first, then the existing formatting/analysis/build gates affected by the change. Distinguish a passing widget test, browser render, APK build, emulator run and iOS validation. Report exactly what ran and what did not.
