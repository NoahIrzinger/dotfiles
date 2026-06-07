#!/usr/bin/env bash
# Reverse what install.sh linked: remove this repo's symlinks, then restore the
# most recent backup it made.
#
#   ./uninstall.sh
#
# Does NOT remove mise tools or brew/apt packages (non-destructive, shared).
# Remove tools yourself with `mise uninstall` if desired.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v stow >/dev/null 2>&1 || { echo "stow not installed"; exit 1; }
PACKAGES="$(cat "$REPO/packages")"
log(){ printf '\033[1;34m==>\033[0m %s\n' "$*"; }

log "Unlinking packages"
for pkg in $PACKAGES; do
  [ -d "$REPO/$pkg" ] || continue
  stow -D -d "$REPO" -t "$HOME" "$pkg" 2>/dev/null && echo "   unstowed $pkg" || echo "   (nothing to unstow for $pkg)"
done

BK="$(ls -dt "$HOME"/.dotfiles-backup/*/ 2>/dev/null | head -1 || true)"
if [ -n "${BK:-}" ] && [ -d "$BK" ]; then
  log "Restoring previous files from $BK"
  ( cd "$BK" && find . -mindepth 1 -depth -print | while IFS= read -r p; do
      rel="${p#./}"; tgt="$HOME/$rel"
      if [ -d "$p" ] && [ ! -e "$tgt" ]; then mkdir -p "$tgt"
      elif [ -f "$p" ] && [ ! -e "$tgt" ]; then mkdir -p "$(dirname "$tgt")"; cp -a "$p" "$tgt"; echo "   restored $tgt"
      fi
    done )
  echo "   (backup left in place at $BK; delete it when satisfied)"
else
  log "No backup found to restore."
fi

log "Done. Restart your shell."
