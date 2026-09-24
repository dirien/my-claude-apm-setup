#!/bin/sh
# statusline.sh — Claude Code status line: dir ⎇ branch(*) │ model │ ctx used%.
# Installed to ~/.claude/apm-statusline.sh by scripts/install-statusline.sh.
# Colored with ANSI escapes; the branch turns yellow with a trailing * when the
# tree is dirty, and context use goes green -> yellow (50%) -> red (80%).
# Dependency-light: uses jq when available, falls back to sed otherwise.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
  model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
  used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
else
  cwd=$(printf '%s' "$input" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -z "$cwd" ] && cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  model=$(printf '%s' "$input" | sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  used=$(printf '%s' "$input" | sed -n 's/.*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | head -n1)
fi

[ -z "$cwd" ] && cwd="$PWD"
dir=$(basename "$cwd")

esc=$(printf '\033')
reset="${esc}[0m"
dim="${esc}[2m"
blue="${esc}[1;34m"
green="${esc}[32m"
yellow="${esc}[33m"
red="${esc}[31m"
magenta="${esc}[35m"
sep=" ${dim}│${reset} "

branch=""
branch_color="$green"
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ] && [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    branch="${branch}*"
    branch_color="$yellow"
  fi
fi

out="${blue}${dir}${reset}"
[ -n "$branch" ] && out="$out ${branch_color}⎇ ${branch}${reset}"
[ -n "$model" ] && out="$out${sep}${magenta}${model}${reset}"
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used" 2>/dev/null)
  [ -z "$used_int" ] && used_int="$used"
  ctx_color="$green"
  [ "$used_int" -ge 50 ] 2>/dev/null && ctx_color="$yellow"
  [ "$used_int" -ge 80 ] 2>/dev/null && ctx_color="$red"
  out="$out${sep}${ctx_color}${used_int}% ctx${reset}"
fi

printf '%s' "$out"
