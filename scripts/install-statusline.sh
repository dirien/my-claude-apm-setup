#!/usr/bin/env sh
# install-statusline.sh — install the colored Claude Code status line. Run
# automatically by apm.yml's `lifecycle: post-install`; also runnable by hand:
# `sh scripts/install-statusline.sh`.
#
# Copies scripts/statusline.sh to ~/.claude/apm-statusline.sh (refreshed on every
# run) and points `statusLine` in ~/.claude/settings.json at it. A statusLine you
# configured yourself is left alone: the setting is only written when it is
# missing or already points at this script. Every other key in settings.json is
# preserved.
#
# Idempotent and safe to re-run, e.g. from a sandbox startup step after the
# agent config has been reseeded. NEVER fails the install: every error path
# warns and exits 0, because a missing status line is purely cosmetic.
# APM_STATUSLINE=0 skips it entirely.
#
# Self-contained: sh and python3.
set -eu

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CLAUDE_HOME/apm-statusline.sh"

log()  { printf '[statusline] %s\n' "$*" >&2; }
skip() { printf '[statusline] %s\n' "$*" >&2; exit 0; }

[ "${APM_STATUSLINE:-1}" = "0" ] && skip "APM_STATUSLINE=0; skipping status line install"
command -v python3 >/dev/null 2>&1 || skip "python3 not found; skipping status line install"

src="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
[ -f "$src" ] || skip "no statusline.sh next to this script; skipping status line install"

mkdir -p "$CLAUDE_HOME" || skip "could not create $CLAUDE_HOME; skipping status line install"
cp "$src" "$DEST" && chmod +x "$DEST" || skip "could not write $DEST; skipping status line install"

SETTINGS="$CLAUDE_HOME/settings.json" DEST="$DEST" python3 - <<'PY' || skip "could not update settings.json; skipping status line install"
import json, os, sys
path, dest = os.environ["SETTINGS"], os.environ["DEST"]
try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except Exception as e:
    sys.exit(f"[statusline] {path} is not valid JSON ({e}); leaving it untouched")

current = settings.get("statusLine")
cmd = current.get("command", "") if isinstance(current, dict) else str(current or "")
if current and "apm-statusline.sh" not in cmd:
    print(f"[statusline] custom statusLine already set in {path}; leaving it alone", file=sys.stderr)
    sys.exit(0)

settings["statusLine"] = {"type": "command", "command": f'sh "{dest}"'}
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
print(f"[statusline] statusLine -> {dest}", file=sys.stderr)
PY
exit 0
