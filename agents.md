# AI Agent Router & System Prompt

Hello AI Agent! Welcome to the VGUARD repository.

VGUARD is a Volume Guard and Storage Infrastructure Policy Engine. It is a dual-language system (Bash + Python) designed to enforce declarative permissions (SSOT), manage LVM volumes, and provide a TUI for managing storage, with a strong focus on being Container-Aware (Docker/Podman).

**CRITICAL DIRECTIVES FOR AI AGENTS:**
Before you propose any code changes, write any scripts, or execute any commits in this repository, you **MUST** read and understand the following context files:

1. **`docs/agents/codestyle.md`** - Contains mandatory rules on defensive programming (Bash `set -e`), the 150-line modularization rule, Dry-Run principles, and Container-Aware restrictions.
2. **`docs/agents/contributing.md`** - Contains mandatory rules on Semantic Versioning and Conventional Commits.

Failure to follow these rules will result in broken pipelines, destructive permission changes on user containers, or rejected code. 

Please acknowledge these rules in your internal reasoning before proceeding with any user request.
