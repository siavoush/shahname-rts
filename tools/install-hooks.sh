#!/usr/bin/env bash
# install-hooks.sh — install the project's git hooks from tools/git-hooks/.
#
# Run once after cloning the repo:
#   bash tools/install-hooks.sh
#
# What it does:
#   - Copies tools/git-hooks/pre-commit to .git/hooks/pre-commit
#   - Makes the hook executable
#   - If .git/hooks/pre-commit already exists and differs, backs it up first
#
# Git hooks live in .git/hooks/ which is local to each clone (not committed).
# This script is the bridge: the committed canonical hook lives at
# tools/git-hooks/pre-commit; this installer puts it where git expects it.
#
# Owner: qa-engineer (Manifesto Principle 9 — Automated Enforcement)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_SRC="${REPO_ROOT}/tools/git-hooks"
HOOKS_DST="${REPO_ROOT}/.git/hooks"

if [[ ! -d "${HOOKS_DST}" ]]; then
  echo "ERROR: ${HOOKS_DST} does not exist. Are you in a git repository?" >&2
  exit 1
fi

install_hook() {
  local name="$1"
  local src="${HOOKS_SRC}/${name}"
  local dst="${HOOKS_DST}/${name}"

  if [[ ! -f "${src}" ]]; then
    echo "SKIP: ${src} does not exist"
    return
  fi

  if [[ -f "${dst}" ]] && ! diff -q "${src}" "${dst}" >/dev/null 2>&1; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    echo "BACKUP: existing ${dst} -> ${backup}"
    cp "${dst}" "${backup}"
  fi

  cp "${src}" "${dst}"
  chmod +x "${dst}"
  echo "INSTALLED: ${dst}"
}

install_hook "pre-commit"

echo ""
echo "Git hooks installed. Requirements:"
echo "  ripgrep: brew install ripgrep"
echo "  Godot 4: brew install --cask godot  (or set GODOT=/path/to/godot)"
