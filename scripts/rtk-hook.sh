#!/usr/bin/env sh
# PreToolUse rtk rewrite for the Bash tool. Hands the hook JSON to `rtk hook claude`,
# which rewrites the command (`git status` -> `rtk git status`) so its output is
# compressed before the agent reads it.
#
# Inside a Claude Code worktree (cwd under .claude/worktrees/) it passes the command
# through unchanged instead. Worktree-isolated sessions refuse any command whose git
# use they cannot verify from the command text, and a launcher in front of git
# (`rtk git ...`) is exactly that, so every rewritten git command is refused there.
# See https://github.com/rtk-ai/rtk/issues/3864.
#
# No-ops when rtk is absent, so an install that skipped `apm lifecycle trust` still
# works. Self-contained: needs only sh and python3.

PATH="$HOME/.local/bin:$PATH"
command -v rtk >/dev/null 2>&1 || exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("cwd") or "")' 2>/dev/null)"

case "${cwd:-$PWD}/" in
  */.claude/worktrees/*) exit 0 ;;
esac

printf '%s' "$input" | rtk hook claude
