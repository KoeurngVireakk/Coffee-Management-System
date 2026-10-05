# Contributing

Use the repository root as the Git boundary. Keep work in short-lived branches such as `feat/auth`, `fix/api-validation`, or `docs/database-setup` and open a pull request into `main`. No commits or pushes are made by the scaffold setup itself.

Keep changes focused, document new API/schema contracts, and add tests for meaningful behavior. Before review, run backend `composer lint` / `composer test`, and Flutter formatting / analysis / tests. Build the affected platform when configuration or platform code changes. The PR template records scope and validation.

Commit dependency lockfiles. Install PHP packages in `apps/backend` and Dart packages in `apps/mobile`. Do not commit `.env`, signing files, local configuration JSON, dependencies, logs, generated SDK metadata, or build artifacts. Review `git status` before committing. The ignored local backend `.env` contains a generated application key; the tracked example keeps `APP_KEY` blank.

The GitHub Actions workflow validates both applications on pushes to `main` and pull requests targeting `main`. Repository administrators should enable branch protection, require both CI jobs and at least one review, and disable direct pushes to `main`. Those GitHub settings are recommendations and have not been modified. Add `CODEOWNERS` only after actual team ownership is agreed.

Keep architecture practical: use existing conventions, add a dependency for a concrete use, and record consequential design decisions in `docs/architecture` when they arise.
