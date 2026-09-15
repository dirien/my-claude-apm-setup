#!/usr/bin/env sh
# install-rtk.sh — install the pinned rtk CLI (https://github.com/rtk-ai/rtk) into
# ~/.local/bin. Run automatically by apm.yml's `lifecycle: post-install`, so a
# plain `apm install` brings the binary the PreToolUse hook in .apm/hooks/rtk.json
# needs. Also runnable by hand: `sh scripts/install-rtk.sh`.
#
# rtk is a CLI proxy that compresses command output before the agent reads it
# (git/ls/grep/test/lint plus terraform, tofu, pulumi, kubectl, docker, aws).
#
# Idempotent (a matching version short-circuits), pinned and SHA256-verified
# against the release's own checksums.txt. NEVER fails the install: every error
# path warns and exits 0, because a missing rtk only costs token savings — the
# hook degrades to a no-op when the binary is absent.
#
# Self-contained: sh, curl, tar, and sha256sum (Linux) or shasum (macOS).
set -eu

RTK_VERSION="${RTK_VERSION:-0.49.0}"
BIN_DIR="${RTK_BIN_DIR:-$HOME/.local/bin}"

log()  { printf '[rtk] %s\n' "$*" >&2; }
skip() { printf '[rtk] %s\n' "$*" >&2; exit 0; }

# Already at the pinned version? Nothing to do.
if command -v rtk >/dev/null 2>&1 && rtk --version 2>/dev/null | grep -qF " ${RTK_VERSION}"; then
  skip "rtk ${RTK_VERSION} already installed"
fi
if [ -x "$BIN_DIR/rtk" ] && "$BIN_DIR/rtk" --version 2>/dev/null | grep -qF " ${RTK_VERSION}"; then
  skip "rtk ${RTK_VERSION} already installed ($BIN_DIR/rtk)"
fi

# Release-artifact target triple. rtk ships gnu for linux-arm64 and musl for
# linux-x86_64; anything else is unsupported and simply skipped.
case "$(uname -s)" in
  Linux)  os=linux  ;;
  Darwin) os=darwin ;;
  *)      skip "unsupported OS $(uname -s); skipping rtk install" ;;
esac
case "$(uname -m)" in
  arm64|aarch64) arch=aarch64 ;;
  x86_64|amd64)  arch=x86_64  ;;
  *)             skip "unsupported architecture $(uname -m); skipping rtk install" ;;
esac
case "$os-$arch" in
  linux-aarch64)  asset="rtk-aarch64-unknown-linux-gnu.tar.gz"  ;;
  linux-x86_64)   asset="rtk-x86_64-unknown-linux-musl.tar.gz"  ;;
  darwin-aarch64) asset="rtk-aarch64-apple-darwin.tar.gz"       ;;
  darwin-x86_64)  asset="rtk-x86_64-apple-darwin.tar.gz"        ;;
esac

base="https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}"
tmp="$(mktemp -d)"
# shellcheck disable=SC2064  # expand $tmp now, not at trap time
trap "rm -rf '$tmp'" EXIT INT TERM

fetch() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 -o "$2" "$1"
}

log "installing rtk ${RTK_VERSION} (${asset})"
fetch "$base/$asset"        "$tmp/$asset"        || skip "download failed; skipping rtk install"
fetch "$base/checksums.txt" "$tmp/checksums.txt" || skip "checksum download failed; skipping rtk install"

expected="$(awk -v n="$asset" '$2==n {print $1}' "$tmp/checksums.txt" | head -1)"
[ -n "$expected" ] || skip "no checksum entry for $asset; skipping rtk install"
if command -v sha256sum >/dev/null 2>&1; then
  got="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
else
  got="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
fi
[ "$got" = "$expected" ] || skip "checksum mismatch for $asset (got $got, expected $expected); skipping rtk install"

tar -xzf "$tmp/$asset" -C "$tmp" || skip "extract failed; skipping rtk install"
[ -f "$tmp/rtk" ] || skip "no rtk binary in $asset; skipping rtk install"

mkdir -p "$BIN_DIR"
chmod +x "$tmp/rtk"
mv -f "$tmp/rtk" "$BIN_DIR/rtk" || skip "could not install into $BIN_DIR; skipping rtk install"

log "rtk installed -> $BIN_DIR/rtk ($("$BIN_DIR/rtk" --version 2>/dev/null || echo unknown))"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) log "note: $BIN_DIR is not on PATH — add it so the PreToolUse hook can find rtk" ;;
esac
exit 0
