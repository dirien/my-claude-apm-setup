---
description: Core yaah repo conventions for all agents
---

- Build with `make build`; never hand-edit generated files under `.claude/`, `.codex/`, `CLAUDE.md`, or `AGENTS.md` — regenerate with `apm compile -t claude,codex`.
- All Go code must pass `golangci-lint run` and `gofmt -l` cleanly before commit.
- Prefer table-driven tests in `_test.go` files; add coverage for every new package.
- Use Conventional Commits for every commit message (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).
- The `yaah` binary must be on `$PATH` for the lifecycle hooks and the `yaah serve` MCP server to work at runtime.
- Skills, agents, hooks, MCP, and LSP are declared in `apm.yml` + `.apm/` — add capabilities there, not by hand-writing agent config.
