---
description: Core repo conventions for all agents
---

- Skills, agents, hooks, MCP, and LSP are declared in `apm.yml` and `.apm/`. Add capabilities there, not by hand-writing agent config.
- After editing anything under `.apm/instructions/`, run `apm compile -t claude,codex` to regenerate the context. Never hand-edit the generated `AGENTS.md` or files under `.claude/rules/`.
- Reproduce the setup on a new machine with `apm install --frozen`.
- Use Conventional Commits for every commit message (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).
- The guardrail hooks under `scripts/` block destructive shell commands and scan edited files for secrets. Keep them fast and dependency-light (sh, python3, grep).
