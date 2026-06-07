#!/usr/bin/env bash
# Re-link the stow packages only (no tool installs). For quick iteration after
# adding a new file or package.
#
#   ./link.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v stow >/dev/null 2>&1 || { echo "stow not installed"; exit 1; }
PACKAGES="$(cat "$REPO/packages")"

for pkg in $PACKAGES; do
  [ -d "$REPO/$pkg" ] && stow -d "$REPO" -t "$HOME" --restow "$pkg" && echo "relinked $pkg"
done
