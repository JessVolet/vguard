# Contributing Guidelines

This document outlines the rules for collaborating, versioning, and managing releases in the VGUARD project.

## 1. Semantic Versioning (SemVer)
VGUARD follows strict semantic versioning (`vMAJOR.MINOR.PATCH`). Always use Git tags matching this format for releases.

* **MAJOR (`vX.0.0`):** Breaking changes to the policy engine, `vguard.conf` structure, or core architecture. Backwards compatibility is broken.
* **MINOR (`v0.X.0`):** New features, commands, or enhancements that are backwards-compatible.
* **PATCH (`v0.0.X`):** Bug fixes, security patches, or linter corrections that do not add new features.

## 2. Conventional Commits
All Git commit messages must follow the Conventional Commits specification. This automates changelog generation, makes the git history readable, and clarifies the intent of every change.

Allowed prefixes:
* `feat:` A new feature or command (e.g., `feat: add --dry-run flag to heal command`).
* `fix:` A bug fix (e.g., `fix: prevent signal 13 crash on protected metadata files`).
* `docs:` Documentation changes only (e.g., updating README or CODESTYLE).
* `refactor:` Code changes that neither fix a bug nor add a feature (e.g., separating Python logic into a helper).
* `chore:` Routine tasks, dependency updates, or release bumping (e.g., `chore: bump version to 3.1.1`).

## 3. Pull Requests & Code Review
* Ensure all code complies with the rules defined in `codestyle.md`.
* Run linters (`shellcheck` and `flake8`/`black` for PEP-8) before pushing.
* Keep PRs focused on a Single Responsibility (SRP). If you are fixing a bug and adding a feature, open two separate PRs.
