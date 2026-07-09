# yaah → Microsoft APM: what could not transfer

`apm.yml` in this directory ports the **declarative** slice of yaah's `AllDefaults()` to
Microsoft APM, and was verified end-to-end (`apm install` → real `.claude/`, idempotent,
`--frozen`-reproducible). This file records everything that stayed behind, and why.

The one-line reason for almost every gap: **APM is a package manager — it declares
dependencies and places static primitives. yaah is a runtime + code generator + MCP server.**
Anything that is *behavior*, *generated per-target*, or *stateful* has no manifest form.

> **Scope note:** this manifest now targets **claude + codex only**. Findings #7 (Copilot
> hooks) and #8 (OpenCode agents) below therefore **no longer apply to this manifest** — they
> are retained purely as true statements about APM's per-target behavior. Narrowing the targets
> is exactly what makes them moot: `apm install` no longer emits any copilot/opencode surface.

---

## ✅ Transferred cleanly (for reference)

| yaah feature | APM mechanism |
| --- | --- |
| 46 remote skills (curated 16 here) | `dependencies.apm:` → git-resolved, pinned in `apm.lock.yaml` |
| MCP servers: context7, pulumi, yaah *(registration)* | `dependencies.mcp:` → `.mcp.json` / per-agent MCP config |
| LSP: gopls, pyright, typescript, csharp *(intent)* | `dependencies.lsp:` → `.lsp.json` |
| Built-in skills: commit, pr, review | `.apm/skills/*/SKILL.md` |
| Built-in agents: executor, librarian, reviewer | `.apm/agents/*.md` |
| Hook **wiring** (5 events → `yaah hook <event>`) | `.apm/hooks/*.json` → settings.json (claude/codex/opencode) |

---

## ❌ Could not transfer

### Behavior / logic (not data)
1. **The 5 hook handlers' logic.** SecretScanner's regex set, CommandGuard's blocklist
   (`rm -rf /`, `git push --force`, `DROP TABLE`…), the Linter profiles
   (golangci-lint / ruff / prettier / tsc / biome / rustfmt / go vet), CommentChecker's
   placeholder patterns, SessionLogger. APM wires a hook to a *command*; the command is the
   opaque `yaah` binary. You can declare *that a hook runs*, never *what it decides*.
2. **Middleware chains & combinators** (`Chain`, `HandlerLink`, `OnBlock`, `OnError`,
   `Transform`) — conditional handler pipelines like "scan secrets → if blocked, append
   remediation." A Go composition model with no manifest analogue.
3. **The yaah MCP server implementation.** Registration transfers; the tools do not —
   `yaah_scan_secrets`, `yaah_lint`, `yaah_check_command`, `yaah_doctor`,
   `yaah_session_info`, `yaah_planning_status`, `yaah_planning_init` are Go backed by the
   same handler instances. Without the `yaah` binary the MCP entry is a dangling pointer.
4. **Session tracking / session store** — runtime persistence of tool calls, blocked
   commands, files-modified, and findings to `.claude/sessions/*.json`, plus
   `yaah session list/show/clean`. Pure runtime; nothing to install.
5. **`yaah doctor` component validation** — per-binary presence checks with tailored install
   hints, tied to the registered providers. APM's `apm doctor` only diagnoses the environment.
6. **The `yaah` binary itself.** Everything runtime hinges on `yaah` being on `$PATH`
   (hook dispatch + MCP server). APM installs packages/primitives, not an arbitrary Go CLI —
   so the harness runtime is *assumed present*, never installed, by the manifest.

### Per-agent generation (proven by the install run)
7. **Copilot hooks are dropped.** APM's hook integrator reported *"hook event casing
   mismatch (no mapping): PostToolUse, PreToolUse, …"* for the copilot target and integrated
   hooks into only **3 of 4** targets, leaving orphaned `.github/hooks/*.json` (visible in
   `apm audit`). yaah emits `.github/hooks/hooks.json` in Copilot's camelCase itself.
8. **OpenCode agents will be rejected at load.** APM copies agent frontmatter verbatim;
   `librarian`/`reviewer` carry `tools: Read, Grep, Glob` (string). OpenCode requires a
   `{Read: true}` map — APM *warns* but can't rewrite it. yaah's OpenCode generator produces
   the disable-map form. (This is the general case: APM does placement, yaah does translation
   of MCP shape, hook delivery, agent tools, and skill frontmatter per agent.)
9. **The OpenCode JS hook bridge** (`.opencode/plugins/yaah.js`, `tool.execute.before/after`)
   — a generated runtime plugin. APM does not emit runtime bridge code.
10. **Agent advanced frontmatter normalization** — `disallowedTools`, `permissionMode`,
    `maxTurns`, preload `skills`, per-agent `mcpServers`/`hooks`, `memory` scope,
    `background`, `isolation: worktree`. APM copies whatever is in the file; yaah *generates
    and normalizes* these (it even strips remote frontmatter and regenerates clean fields).
    That normalization has no manifest equivalent — and, per #8, unadapted frontmatter can be
    wrong for the target.

### Settings & platform integration
11. **Claude Code `settings.json` core fields** — `model`, `alwaysThinkingEnabled`,
    `effortLevel`, `autoUpdatesChannel`, `statusLine`, `permissions`, `sandbox`, `env`,
    `teammateMode`, `fastMode`, `spinnerVerbs`, output style … the ~12 setting groups
    `schema.Settings` covers. APM merged only `hooks` into settings.json; yaah's version also
    set `model` / `effortLevel` / `enabledPlugins`. APM does not own these.
12. **LSP delivery mechanism differs.** yaah enables LSP via `enabledPlugins`
    (`gopls-lsp@claude-plugins-official`) in settings.json; APM writes a standalone
    `.lsp.json`. Intent transfers, mechanism (and marketplace auto-enable) does not.
13. **Marketplace plugins / the Codex plugin.** yaah registers `codex@openai-codex` into
    `enabledPlugins`, adding `/codex:*` commands, a rescue subagent, and stop-time
    review-gate hooks. APM has its own plugin model (`apm plugin`) and doesn't populate
    Claude's `enabledPlugins`; this integration doesn't port.

### Advanced hook & command types
14. **FactCheck experimental agent hooks** — `type: agent` Stop/SubagentStop hooks that spawn
    a Sonnet subagent (Read/Grep/Glob/WebFetch) with model + prompt + timeout. APM's
    discovered-hook model expresses *command* hooks; agent/prompt/http types don't fit.
15. **Richer hook fields** — `type: http` (POST + headers + `allowedEnvVars` interpolation),
    `type: prompt` (LLM prompt + model), `async`, `statusMessage`, `once`. Command hooks
    transfer; these yaah-generated variants do not.
16. **The 29 `/yaah:*` workflow commands + the `.planning/` engine.** The command *markdown*
    could ship as static `.apm/` files, but they drive a stateful workflow — waves, parallel
    executor subagents, SUMMARY/VERIFICATION artifacts, resume, milestones. The state machine
    and the subagent orchestration don't transfer, and frozen copies would rot out of sync
    with yaah's Go source. (Deliberately omitted from the manifest.)

### Discovery / curation tooling
17. **Skill catalog, bundles & discovery.** yaah's catalog taxonomy (`Category`, `Tags`,
    `Risk`, `Tier`, `Aliases`), 10 role bundles (`go-dev`, `security`, …), the
    `yaah skills list/search/info/bundles/validate` CLI, `skills-registry.json`, and
    `NewFromCatalog`. A flat `apm:` list can *name* the resolved skills but not reproduce the
    curation, risk/tier gating, or bundle grouping.

---

## Partial (mechanism differs, not a hard wall)
- MCP servers, LSP, and remote skills all transfer, but through APM's own file layout
  (`.lsp.json` vs `enabledPlugins`; `.agents/skills/` shared dir vs per-client). The agent
  ends up equipped; the on-disk shape is APM's, not yaah's.

## Manifest note
- The 16 `apm:` deps are unpinned (`#main`); APM warns about drift. That's advisory — the
  committed `apm.lock.yaml` pins exact commits and `apm install --frozen` reproduces them
  bit-for-bit. Commit the lockfile; pin `#<sha>` in `apm.yml` only if you want the manifest
  itself to be self-describing without the lock.
