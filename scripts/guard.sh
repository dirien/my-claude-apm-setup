#!/usr/bin/env sh
# PreToolUse guard for the Bash tool. Reads the hook JSON on stdin, inspects the
# command, and exits 2 to block it (the message on stderr is shown to the agent).
# Self-contained: needs only sh, python3, and grep.

input="$(cat)"
cmd="$(printf '%s' "$input" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("tool_input") or {}).get("command", ""))' 2>/dev/null)"

[ -z "$cmd" ] && exit 0

# Destructive patterns worth stopping before they run.
if printf '%s\n' "$cmd" | grep -Eiq \
  'rm[[:space:]]+-[a-z]*rf?[[:space:]]+(/|/\*|~|\$HOME)([[:space:]]|$)|rm[[:space:]]+.*--no-preserve-root|:\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:|git[[:space:]]+push[[:space:]].*(--force([[:space:]]|=)|[[:space:]]-f([[:space:]]|$))|git[[:space:]]+reset[[:space:]]+--hard|\bmkfs\b|dd[[:space:]]+if=|chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/|DROP[[:space:]]+TABLE'; then
  printf 'guard: blocked a destructive command:\n  %s\n' "$cmd" >&2
  exit 2
fi

exit 0
