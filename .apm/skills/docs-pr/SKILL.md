---
name: docs-pr
description: "Update docs and create PR with squash merge"
---

# /docs-pr — Documentation Update + Pull Request

## When to use
When the user runs /docs-pr or asks to refresh documentation and open a pull request for it.

## Steps

1. Update all documentation that the change affects, following the file priority below.
2. Run `git status` and `git diff` to confirm only the intended doc changes are staged.
3. Commit the documentation changes with a clean message (no AI attribution — see Rules).
4. Push the branch: `git push -u origin HEAD`.
5. Create the PR with `gh pr create` (title under 70 chars, concise summary body).
6. Squash merge the PR: `gh pr merge --squash`.

## Documentation file priority

When updating agent/AI documentation files, follow this priority order:

1. **AGENTS.md first** — Look for `AGENTS.md` files (root and scoped in subdirectories). These are the source of truth.
2. **CLAUDE.md as fallback** — Only if no `AGENTS.md` exists in a given directory, look for and update `CLAUDE.md` instead.
3. **Symlink awareness** — If `CLAUDE.md` is a symlink to `AGENTS.md`, only edit `AGENTS.md`. Never replace a symlink with a regular file.
4. **When creating new docs** — Create `AGENTS.md` and add a `CLAUDE.md` symlink (`ln -s AGENTS.md CLAUDE.md`). Do not create duplicate files.

## Rules
- Do NOT approve the PR
- Squash merge the PR
- Do NOT add any co-authors to the commit message
- Do NOT add the "Co-Authored-By: Claude" footer
- Do NOT add the "Generated with Claude Code" footer
- Keep commit messages clean without any AI attribution
