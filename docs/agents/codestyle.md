# VGUARD Code Style & Development Guidelines

This document outlines the coding standards, architectural rules, and best practices for developing and contributing to VGUARD.

## 1. Core Philosophy
* **Token Efficiency:** Keep code minimal and concise. Avoid redundant structures, bloated text, or unnecessary boilerplate.
* **Minimal Comments:** Write self-documenting code. Use comments only to explain *why* a complex decision was made, not *what* the code is doing.
* **Keep It Simple:** Avoid over-engineering. Choose the most straightforward approach that solves the problem.
* **No Emojis:** Do not use emojis in source code, logs, internal messages, or terminal outputs. Rely on ANSI colors and standard ASCII symbols (e.g., `[*]`, `[✓]`, `[✗]`).

## 2. Language & Internationalization (i18n)
* **Code in English:** All variable names, function names, classes, file names, commit messages, and internal logic MUST be written in English.
* **Bilingual Support (i18n):** User-facing terminal outputs must never be hardcoded in a single language. Use the translation engine (`src/i18n.sh`) to provide dual support for Spanish and English.

## 3. Bash Scripting Practices
* **Strict Mode Awareness:** VGUARD uses `set -e` globally to fail fast. You must program defensively.
* **Graceful Failures:** If a command is expected to fail (e.g., reading a protected file without `sudo`, or running `stat`), append `|| true` or use an `if` statement. Failing to do so will cause the script to crash abruptly.
* **Pipe and Loop Safety:** Be cautious when piping outputs to loops (e.g., `while read ... < <(find ...)`). An unhandled error inside the loop will trigger `set -e`, break the pipe, and cause a fatal `Signal 13` (SIGPIPE).

## 4. Architecture & Policy Engine
* **Modularization (The 150-Line Rule):** Reaching 150 lines in a script is a "yellow flag". However, do not split code purely based on line count. The trigger to extract code into `src/utils/` or `src/core/` must be based on:
  * **SRP (Single Responsibility Principle):** A module should do only one thing.
  * **Excessive Nesting:** If logic becomes too deep, extract it.
  * **DRY (Don't Repeat Yourself):** If you need the logic elsewhere, move it to a shared helper.
* **Separation of Concerns:**
  * **Bash:** Used exclusively for CLI routing, UI orchestration, and standard filesystem commands.
  * **Python:** Used for JSON parsing, declarative state resolution, and complex comparisons.
* **Declarative SSOT:** The JSON configuration (`vguard.conf`) is the Single Source of Truth. Do not execute filesystem mutations without verifying the target state against the policy engine first.
* **Container-Aware Execution:** Always assume that a volume is managed by a container engine (Docker/Podman).
  * **Rule of Thumb:** Never apply recursive modifications (like `chown -R` or `chmod -R`) without checking if the volume is `container_managed`. Doing so will destroy internal container permissions (e.g., databases, SSH keys).
  * SELinux labels (`container_file_t`), however, must always be applied recursively.

## 5. Security & Modification Precautions
* **Do Not Break Policies:** When editing `policy_helper.py` or `heal.sh`, extreme caution is required. Changing how permissions are evaluated or applied can trigger massive "DRIFTED" false-positives or lock the user out of their own volumes.
* **Least Privilege:** Do not assume the script is always running as root. Handle permission denied errors elegantly and prompt the user to use `sudo` only when strictly necessary.
* **The Dry-Run Principle:** Any new destructive feature or function (e.g., recursive `chmod`/`chown` modifications, policy deletions, or volume removals) MUST include a mechanism to simulate the action without writing to disk (e.g., a `--dry-run` flag). This guarantees that administrators can safely preview exactly which files will be affected before pulling the trigger.

## 6. Code Quality & Tooling
* **Mandatory Linters:** 
  * **Bash:** All `.sh` scripts must pass `shellcheck` without critical warnings before being merged or committed. 
  * **Python:** All `.py` scripts must adhere to PEP-8 standards for clean and readable formatting. Automate stylistic checks wherever possible.

## 7. Audit Before Code (Auditoría Previa)
* Antes de implementar una nueva función, módulo o bloque de código, DEBES escanear el repositorio y en específico esa característica para verificar si la funcionalidad (o una muy similar) ya existe.
* Si la funcionalidad ya existe y funciona bien, debes detenerte, informar al usuario que ya existe y evitar reescribirla.
* Si la funcionalidad existe pero está obsoleta o tiene errores, debes proponer una refactorización (`refactor:`) o corrección (`fix:`) en lugar de crear un módulo duplicado.
* Solo si la funcionalidad no existe en absoluto, debes proceder a crearla desde cero (`feat:`).
