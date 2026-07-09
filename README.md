# my-claude-apm-setup

My Claude Code and Codex setup, kept in one [Microsoft APM](https://microsoft.github.io/apm/) manifest.

Agent config has a way of scattering: settings in JSON, skills as loose markdown, hooks wired by hand, MCP servers pasted into more JSON, and a `CLAUDE.md` plus an `AGENTS.md` that slowly say different things. This repo puts all of it behind `apm.yml` and a `.apm/` folder. Run `apm install` and both agents come up the same way, on any machine.

It is built around [yaah](https://github.com/dirien/yet-another-agent-harness) (my Go agent harness): the hooks and the MCP server call the `yaah` binary at runtime. APM handles the parts that can be declared; yaah handles the parts that have to run. `docs/TRANSFER-GAPS.md` draws that line precisely.

## What's in here

- 16 skills pulled from git and pinned to a commit (Go, CLI, DevOps, linting, repo hygiene, code review, security).
- Three local skills (`commit`, `pr`, `review`) and three subagents (`executor`, `librarian`, `reviewer`) under `.apm/`.
- Three MCP servers: Context7 for docs, Pulumi's hosted server, and yaah's own (`yaah serve`).
- Four LSP servers (gopls, typescript, pyright, csharp) written to `.lsp.json`.
- Five lifecycle hooks that hand off to `yaah hook <event>` (lint, command guard, secret scan, comment check, session log).
- One instruction source under `.apm/instructions/` that generates the agent context for both editors.

## Requirements

- [APM](https://microsoft.github.io/apm/) 0.22 or newer: `curl -sSL https://aka.ms/apm-unix | sh` or `brew install microsoft/apm/apm`
- [yaah](https://github.com/dirien/yet-another-agent-harness) on `$PATH` for the hooks and MCP server to work: `brew install dirien/tap/yaah`
- The LSP binaries you want (`gopls`, `typescript-language-server`, `pyright`, `csharp-ls`) — APM writes the config but does not install them

## Quickstart

```bash
git clone https://github.com/dirien/my-claude-apm-setup
cd my-claude-apm-setup

apm install --frozen           # reproduce the pinned deps, wire .claude/ and .codex/
apm compile -t claude,codex    # generate the agent context (see below)

# then open the folder in Claude Code or Codex
```

## How the agent context works

There is one source of truth for project rules: the files under `.apm/instructions/`. Each agent receives them through its own native mechanism, so nothing is written twice and the two can't drift.

| Agent | Where the rules land | Command |
| --- | --- | --- |
| Claude Code | `.claude/rules/*.md` | `apm install` |
| Codex | `AGENTS.md` (and `pkg/**/AGENTS.md` where the `applyTo` glob matches) | `apm compile -t claude,codex` |

When `.claude/rules/` already exists, `apm compile` skips `CLAUDE.md` on purpose so Claude does not read the same rules twice. Pass `--force-instructions` if you want a classic single-file `CLAUDE.md` instead. A rule scoped with `applyTo: "pkg/**/*.go"` is placed next to the code it governs, so an agent working in a subtree loads only what applies there.

Edit an instruction file, run `make sync`, commit. CI fails if you forget (see below).

## Make targets

```
make install     # apm install
make sync        # regenerate agent context after editing .apm/instructions
make check       # validate primitives + fail if AGENTS.md / .claude/rules are stale
make ci-install  # apm install --frozen + apm audit --ci  (the npm-ci equivalent)
make sbom        # CycloneDX + SPDX SBOM of the agent dependencies, offline and reproducible
make bundle      # offline release zip so others skip cloning the skill repos
```

The GitHub Actions workflow in `.github/workflows/apm.yml` runs the install, audit, validate, drift, and SBOM steps on every push.

## What's mine and what's borrowed

The three skills, three agents, five hooks, and the instruction files under `.apm/` are mine and live in this repo. The 16 skills under `dependencies` come from `jeffallan/claude-skills`, `rshade/agent-skills`, and `netresearch/agent-rules-skill`; `apm.lock.yaml` pins each to a commit and `apm install --frozen` reproduces them.

## Reading

- `docs/APM-ADOPTION.md` — which APM features this setup uses, which it skips, and why (each checked against `apm` 0.22).
- `docs/TRANSFER-GAPS.md` — what a package manager can't express about yaah, so it stays in the binary.

## License

MIT. See `LICENSE`.
