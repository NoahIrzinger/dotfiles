#!/usr/bin/env bash
# Re-link the stow packages only (no tool installs). For quick iteration after
# adding a new file or package.
#
#   ./link.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v stow >/dev/null 2>&1 || { echo "stow not installed"; exit 1; }
PACKAGES="$(cat "$REPO/packages")"

fail=0
for pkg in $PACKAGES; do
  if [ ! -d "$REPO/$pkg" ]; then
    echo "   skip missing package: $pkg"
    continue
  fi
  # `if stow` keeps a conflict in one package from aborting the rest (set -e).
  # link.sh does no backups, so on a collision point at install.sh, which does.
  if stow -d "$REPO" -t "$HOME" --restow "$pkg"; then
    echo "   relinked $pkg"
  else
    echo "   ✗ $pkg has a conflict; run ./install.sh to back up colliding files and relink"
    fail=1
  fi
done
exit $fail
