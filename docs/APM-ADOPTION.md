# APM features this setup uses (and the ones it skips)

A pass over Microsoft APM 0.22's surface, checked with real `apm` probes. **Adopted** is what
this repo uses; **Recommended** and **Skip** are notes for anyone extending it.

## Adopted

### 1. Targets scoped to `claude, codex`
APM writes each agent's native layout and skips the rest. `apm install` prints
`Skipped MCP config for copilot, vscode` and integrates hooks only into `.claude/settings.json`
and `.codex/hooks.json`.

### 2. Single-source instructions → `.claude/rules/` and `AGENTS.md`
One source under `.apm/instructions/` feeds both agents. Claude reads `.claude/rules/*.md`
(written by `apm install`); Codex reads `AGENTS.md` (written by `apm compile`). When
`.claude/rules/` exists, `apm compile` skips `CLAUDE.md` to avoid duplicate context; pass
`--force-instructions` to get the single-file form. A rule scoped with `applyTo: "pkg/**/*.go"`
is placed next to the code it governs.

### 3. Package metadata passthrough
`homepage`, `repository`, and `keywords` land verbatim in the `.claude-plugin/plugin.json`
that `apm pack` emits.

### 4. `scripts:` + `apm run`
`apm run sync` runs `apm compile -t claude,codex --clean` to regenerate the agent context.
Values are bare shell strings; `apm run` is flagged experimental but needs no enable.

### 5. `compilation:` block
`strategy: distributed` plus `exclude: ["apm_modules/**"]` pins compile behaviour so every
contributor and CI run emits identical files without remembering flags.

### 6. SHA-pinned dependencies
Each skill is pinned to a commit in `apm.yml`, and `apm.lock.yaml` records the same SHAs.
`apm install --frozen` reproduces them exactly.

## Adopt in CI / Makefile

Verified on 0.22:

```makefile
sync:       apm compile -t claude,codex --clean
check:      apm compile -t claude,codex --validate && \
            apm compile -t claude,codex --clean --local-only && \
            git diff --exit-code AGENTS.md .claude/rules/
ci-install: apm install --frozen && apm audit --ci
sbom:       apm lock export -f cyclonedx --timestamp $(SOURCE_DATE) -o sbom/agents.cdx.json && \
            apm lock export -f spdx      --timestamp $(SOURCE_DATE) -o sbom/agents.spdx.json
bundle:     apm install && apm pack --archive
```

- `apm compile --validate` → "All primitives validated successfully!" (writes nothing).
- `apm lock export` → CycloneDX 1.5 + SPDX, offline and reproducible via `--timestamp`. Pairs
  with a source-code SBOM if you sign releases.
- `apm pack --archive` → a plugin bundle zip with `plugin.json` + the vendored skills, so
  consumers skip cloning the skill repos. Build it after `apm install`; do not pass
  `--target claude` (deprecated) or `--format apm` (packs the whole materialized tree).

CI keeps the version-robust gates (frozen install, audit, validate, SBOM). The drift check
lives in `make check` for local use rather than CI, because the generated files carry an
APM-version stamp that trips a hard git-diff gate when the runner's APM is newer.

## Recommended, optional

- **`devDependencies:`** — a dev-only skill set that `apm pack` excludes. **Caveat learned in
  CI:** a production install (`apm install --frozen`) does not deploy dev deps, so
  `apm audit --ci` then reports them as `no-orphaned-packages` failures. This repo keeps all 16
  skills as regular `dependencies` so `apm audit --ci` stays green; adopt `devDependencies` only
  if you drop `apm audit --ci` from CI or install with dev deps included.
- **Maintenance loop** — `apm outdated` → `apm update --dry-run` → `apm update -y` when you want
  to bump the pinned skill commits.
- **Transitive-MCP note** — the MCP servers here are self-defined (`registry: false`). A repo
  that pulls this setup *transitively* must re-declare a self-defined server or install with
  `--trust-transitive-mcp`, or the server is dropped (hooks and skills still integrate).

## Skip

- **`executables.allow` / `apm approve`** — the trust gate governs *dependencies'* executables,
  not this project's own primitives; inert in this manifest (`apm approve --list` → "No installed
  packages declare executable primitives"). A consumer who wants gating runs `apm approve` themselves.
- **`apm publish` + `registries:`** — experimental REST-registry path; a public GitHub repo is
  installable via `apm install dirien/my-claude-apm-setup` with zero publish.
- **Spec Kit constitution** — 0.22 renders it twice on the claude target; project principles fit
  better in the global instructions file. (The path is `.specify/memory/constitution.md`, not the
  `memory/…` the CLI help claims.)
- **Chatmodes** — `--chatmode` prepends a persona to `AGENTS.md` only (codex); the three subagents
  already cover role personas.
- **`marketplace:` block** — only if you want the skills individually browsable via
  `/plugin marketplace add` instead of one plugin bundle.
