# my-claude-apm-setup

My Claude Code and Codex setup, kept in one [Microsoft APM](https://microsoft.github.io/apm/) manifest.

Agent config has a way of scattering: settings in JSON, skills as loose markdown, hooks wired by hand, MCP servers pasted into more JSON, and a `CLAUDE.md` plus an `AGENTS.md` that slowly say different things. This repo puts all of it behind `apm.yml` and a `.apm/` folder. Run `apm install` and both agents come up the same way, on any machine.

It is self-contained. The guardrails are plain shell scripts under `scripts/`, so there is no extra tool or daemon to install — just APM, your language servers, and the tools you already use.

## What's in here

- 29 skills pulled from git and pinned to a commit (Go, CLI, DevOps, linting, repo hygiene, code review, security, plan grilling, prose humanizing, the official Pulumi skills, Terraform/OpenTofu, LSP-first code intelligence).
- Four local skills (`commit`, `docs-pr`, `pr`, `review`) and three subagents (`executor`, `librarian`, `reviewer`) under `.apm/`.
- One MCP server: Pulumi's hosted server.
- Four LSP servers (gopls, typescript, pyright, csharp) written to `.lsp.json`.
- Two guardrail hooks, as shell scripts in `scripts/`: a `PreToolUse` guard that blocks destructive Bash commands, and a `PostToolUse` hook that scans edited files for secrets and formats them.
- One instruction source under `.apm/instructions/` that generates the agent context for both editors.

## Requirements

- [APM](https://microsoft.github.io/apm/) 0.22 or newer: `curl -sSL https://aka.ms/apm-unix | sh` or `brew install microsoft/apm/apm`
- `sh`, `python3`, and `grep` for the guardrail hooks (already on any dev box)
- The LSP binaries you want (`gopls`, `typescript-language-server`, `pyright`, `csharp-ls`) — APM writes the config but does not install them
- Optional formatters the post-edit hook uses when present: `gofmt`, `prettier`, `ruff`

## Quickstart

```bash
git clone https://github.com/dirien/my-claude-apm-setup
cd my-claude-apm-setup

apm install --frozen           # reproduce the pinned deps, wire .claude/ and .codex/
apm compile -t claude,codex    # generate the agent context (see below)

# then open the folder in Claude Code or Codex
```

## Use in another repo

You don't copy `.apm/` around. Depend on this repo as a single APM package and `apm install` pulls the whole thing — all skills, subagents, instructions, guardrail hooks, MCP, and LSP — into that repo's `.claude/`.

The entire consumer `apm.yml` is one dependency line:

```yaml
name: my-project
version: 1.0.0
targets:
  - claude
dependencies:
  apm:
    # '#' is the git-ref separator; '@' is reserved for the alias object-form.
    - dirien/my-claude-apm-setup#v0.6.1
includes: auto
```

```bash
apm install            # writes apm.lock.yaml + materializes .claude/
apm install --frozen   # reproducible install from the lock (use this in CI)
```

That single dependency materializes 33 skills into `.claude/skills/`, the three subagents into `.claude/agents/`, the instructions into `.claude/rules/`, the guardrail hooks into `.claude/apm-hooks.json` + `.claude/settings.json`, and the MCP/LSP servers into `.mcp.json` + `.lsp.json`.

Notes:

- **Pin it.** An unpinned dep installs the latest commit and drifts; `apm install` warns about it. Pin a tag (`#v0.6.1`) or a commit (`#<sha>`).
- **Generated vs vendored.** `apm_modules/` is auto-added to `.gitignore`. `.claude/` is generated — commit it, or gitignore it and run `apm install --frozen` in CI. Don't hand-edit `.claude/skills/*`; it is overwritten.
- **MCP.** `pulumi` configures automatically as a direct dep of this package. Nested a layer deeper it can be dropped unless re-declared or installed with `--trust-transitive-mcp`.

## How the agent context works

There is one source of truth for project rules: the files under `.apm/instructions/`. Each agent receives them through its own native mechanism, so nothing is written twice and the two can't drift.

| Agent | Where the rules land | Command |
| --- | --- | --- |
| Claude Code | `.claude/rules/*.md` | `apm install` |
| Codex | `AGENTS.md` (and `pkg/**/AGENTS.md` where the `applyTo` glob matches) | `apm compile -t claude,codex` |

When `.claude/rules/` already exists, `apm compile` skips `CLAUDE.md` on purpose so Claude does not read the same rules twice. Pass `--force-instructions` if you want a classic single-file `CLAUDE.md` instead. A rule scoped with `applyTo: "pkg/**/*.go"` is placed next to the code it governs, so an agent working in a subtree loads only what applies there.

Edit an instruction file, run `make sync`, commit.

## Guardrail hooks

Two small POSIX shell scripts, wired to Claude Code and Codex through `.apm/hooks/guardrails.json`:

- `scripts/guard.sh` runs before every Bash call and blocks destructive commands (`rm -rf /`, `git push --force`, `git reset --hard`, `mkfs`, `dd if=`, and similar).
- `scripts/post-edit.sh` runs after every edit: it blocks a write that adds an obvious credential (AWS key, private key, `ghp_…`, `sk-…`, Slack token) and formats the file with `gofmt`, `prettier`, or `ruff` when the tool is installed.

Both read the hook JSON on stdin and exit 2 to block. Edit the patterns to taste.

## Make targets

```
make install     # apm install
make sync        # regenerate agent context after editing .apm/instructions
make check       # validate primitives + fail if AGENTS.md / .claude/rules are stale
make ci-install  # apm install --frozen + apm audit --ci  (the npm-ci equivalent)
make sbom        # CycloneDX + SPDX SBOM of the agent dependencies, offline and reproducible
make bundle      # offline release zip so others skip cloning the skill repos
```

The GitHub Actions workflow in `.github/workflows/apm.yml` runs the install, audit, validate, and SBOM steps on every push.

## What's mine and what's borrowed

The four workflow skills, the vendored `humanizer` skill (copied from `blader/humanizer@1b48564` — its skill sits at the repo root, which apm 0.27+ no longer resolves as a dependency), three agents, two guardrail hooks, and the instruction files under `.apm/` live in this repo. The 28 skills under `dependencies` come from `jeffallan/claude-skills`, `rshade/agent-skills`, `netresearch/agent-rules-skill`, `mattpocock/skills`, `pulumi/agent-skills` (the eight skills of its `pulumi/` plugin), and `antonbabenko/terraform-skill` plus its recommended companion plugin `antonbabenko/agent-plugins/plugins/code-intelligence`; `apm.lock.yaml` pins each to a commit and `apm install --frozen` reproduces them.

## Reading

- `docs/APM-ADOPTION.md` — which APM features this setup uses, which it skips, and why (each checked against `apm` 0.22).

## License

MIT. See `LICENSE`.
