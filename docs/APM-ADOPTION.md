# APM features yaah was leaving on the table (claude + codex)

Audit of Microsoft APM 0.22.0's surface vs the original `apm.yml`, verified with real `apm`
probes. Everything in **Adopted** is already in this manifest; **Recommended** and **Skip**
are your call. Nothing here needs opencode/copilot.

---

## Adopted (TIER 1 — in this manifest, verified)

### 1. Targets scoped to `claude, codex`
Removes the un-generated opencode/copilot surface. Verified: `apm install` prints
`Skipped MCP config for copilot, vscode` and integrates hooks to only `.claude/settings.json`
+ `.codex/hooks.json` — no more "hook event casing mismatch" (copilot) or "tools as str"
(opencode) warnings.

### 2. Single-source instructions → `.claude/rules/` **and** `AGENTS.md`  ← the big one
yaah hand-maintains `CLAUDE.md`, `AGENTS.md`, and `pkg/AGENTS.md` separately. APM generates
all of them from **one** source under `.apm/instructions/`. The exact, tested mechanism:

| Agent | How it receives the instructions | Command that produces it |
| --- | --- | --- |
| **Claude Code** | `.claude/rules/repo-conventions.md`, `.claude/rules/pkg-go.md` (Claude reads `.claude/rules/` natively) | `apm install` |
| **Codex** | root `AGENTS.md` (+ scoped `pkg/**/AGENTS.md` where `.go` files exist) | `apm compile -t claude,codex` |
| *(optional)* classic root `CLAUDE.md` | only if you want the single-file form | `apm compile … --force-instructions` |

Verified: with `.claude/rules/` populated, `apm compile` **deliberately skips** `CLAUDE.md`
("Claude Code reads .claude/rules/ directly") to avoid duplicated context — that's a feature,
not a miss. Scoped placement confirmed in a tree with real `pkg/harness/*.go`:
`applyTo: "pkg/**/*.go"` → `pkg/harness/AGENTS.md` + `pkg/harness/CLAUDE.md`. In a tree with no
matching `.go` files it warns and falls back to root (harmless).

**This is a migration, not a drop-in:** reshape the prose in your current `CLAUDE.md` /
`AGENTS.md` / `pkg/AGENTS.md` into the bullet-rule form inside `.apm/instructions/*.md`, then
delete the hand-written originals (the generated files carry a `Do not edit manually` marker).

### 3. Package metadata passthrough
`homepage` / `repository` / `keywords` flow verbatim into the synthesised
`.claude-plugin/plugin.json` at `apm pack`. Verified: all three present in the packed manifest.

### 4. `scripts:` wrappers around the yaah binary
`apm run doctor` → `yaah doctor`, `apm run generate -p agent=claude` → `yaah generate --agent
claude`. Uniform post-install entrypoints, discoverable via `apm list`. Verified end-to-end
(yaah 0.5.0 on PATH; `apm run doctor` even validated APM's own `.claude/settings.json` +
`.codex/config.toml` as good). Values are bare shell strings; `apm run` is flagged
experimental but needs no enable.

---

## Adopt in CI / Makefile / release (TIER 1 — process, verified)

```makefile
# Makefile (excerpt) — see the shipped Makefile
apm-sync:   ## regenerate agent context from .apm/instructions (run after editing them)
	apm compile -t claude,codex --clean

apm-check:  ## CI gate: primitives valid AND generated files not drifted
	apm compile -t claude,codex --validate
	apm compile -t claude,codex --clean --local-only
	git diff --exit-code CLAUDE.md AGENTS.md .claude/rules/ pkg/

apm-ci-install:  ## npm-ci equivalent: reproduce pinned deps, fail on drift
	apm install --frozen
	apm audit --ci

apm-sbom:   ## agent-dependency SBOM (on-brand with yaah's Go SBOM + cosign)
	apm lock export -f cyclonedx --timestamp $(SOURCE_DATE) -o sbom/agents.cdx.json
	apm lock export -f spdx      --timestamp $(SOURCE_DATE) -o sbom/agents.spdx.json

apm-bundle: ## offline release zip so consumers skip cloning 16 repos
	apm install
	apm pack --archive            # -> build/yet-another-agent-harness-<ver>.zip
```

All verified on 0.22.0: `--validate` → "All primitives validated successfully!";
`apm lock export` → CycloneDX 1.5 (16 components) + SPDX, offline & reproducible via
`--timestamp`; `apm pack --archive` → `build/…-0.1.0.zip` (46 files) with embedded
`plugin.json` + `apm.lock.yaml`. Caveats: build the bundle **after** `apm install`; do **not**
pass `--target claude` (deprecated/ignored) or `--format apm` (packs the whole materialized tree).

---

## Recommended, optional (TIER 2)

- **`compilation:` block** — pin `strategy: distributed` + `exclude: ["apm_modules/**"]` so every
  contributor emits identical files without remembering flags. (`distributed` is already the
  default and matches yaah's `pkg/AGENTS.md` layout, so this is determinism insurance.)
- **SHA-pin deps** — the committed `apm.lock.yaml` + `apm install --frozen` already give
  reproducibility; pin `#<sha>` in `apm.yml` only if you want the manifest self-describing and
  the drift warning gone. These 3 repos publish no tags, so `#<sha>` (already in the lockfile)
  is the only immutable option; bump via `apm update`.
- **`devDependencies:`** — move develop-only skills (code-reviewer, security-audit, tech-debt,
  go-nolint-audit, architecture-designer) out of runtime; `apm pack` excludes them and
  `apm lock -v` records `is_dev: true`. **Caveat (learned the hard way in CI):** a production
  install (`apm install --frozen`) does not deploy dev deps, so `apm audit --ci` then reports
  them as `no-orphaned-packages` failures ("N orphaned package(s) in lockfile"). This repo keeps
  all 16 skills as regular `dependencies` so `apm audit --ci` stays green; adopt `devDependencies`
  only if you drop `apm audit --ci` from CI or install with dev deps included.
- **Maintenance loop** — `apm outdated` → `apm update --dry-run` → `apm update -y` in CONTRIBUTING.
- **Transitive-MCP note (docs)** — a downstream repo that pulls yaah *transitively* silently
  drops the self-defined `yaah` MCP unless it re-declares it or installs with
  `--trust-transitive-mcp`. Already noted in `apm.yml`.

## Skip (TIER 3 — verified not worth it)

- **`executables.allow` / `apm approve`** — the trust gate governs *dependencies'* executables,
  not your own project's; inert in yaah's own manifest (`apm approve --list` → "No installed
  packages declare executable primitives"). A consumer who wants gating runs `apm approve
  yet-another-agent-harness` themselves; you can't pre-approve for them.
- **`apm publish` + `registries:`** — experimental REST-registry path; a public GitHub repo is
  installable via `apm install dirien/yet-another-agent-harness` with zero publish.
- **Spec Kit constitution** — 0.22.0 renders it twice on the claude target; principles fit
  better in the global instructions file. (Also: the path is `.specify/memory/constitution.md`,
  not the `memory/…` the CLI help claims.)
- **Chatmodes** — `--chatmode` prepends a persona to **AGENTS.md only (codex)**; yaah's three
  subagents already cover role personas.
- **`marketplace:` block** — only if you want the 46-skill catalog individually browsable via
  `/plugin marketplace add` instead of one plugin bundle.
