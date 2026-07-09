#!/usr/bin/env sh
# PostToolUse hook for Edit/Write/MultiEdit. Scans the edited file for obvious
# secrets (exit 2 to block) and formats it with whatever formatter is installed
# (no-op when the tool is missing). Self-contained: sh, python3, grep, plus your
# formatters on $PATH.

input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("tool_input") or {}).get("file_path", ""))' 2>/dev/null)"

[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Block on a likely hardcoded credential.
if grep -Eiq 'AKIA[0-9A-Z]{16}|-----BEGIN[[:space:]][A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}' "$file" 2>/dev/null; then
  printf 'post-edit: possible hardcoded secret in %s — move it to an env var or a secret manager.\n' "$file" >&2
  exit 2
fi

# Format by extension, only when the formatter exists.
case "$file" in
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file"
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)
    command -v prettier >/dev/null 2>&1 && prettier --write "$file" >/dev/null 2>&1
    ;;
  *.py)
    command -v ruff >/dev/null 2>&1 && ruff format "$file" >/dev/null 2>&1
    ;;
esac

exit 0
