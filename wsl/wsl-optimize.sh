#!/usr/bin/env bash
set -euo pipefail
# wsl-optimize.sh: opt-in tuning for a WSL2 dev sandbox. run it directly, or via
# `./install.sh --wsl-tweaks`. it prints every change and asks before doing anything.
#
# changes service/boot config inside the distro via sudo; never the Windows host
# (that's the corporate-managed boundary: EDR/firewall/patching live there).
#
# why disable ufw/AppArmor: in a NAT'd WSL2 sandbox they're largely ineffective
# (the host firewall is the real control) and they get in the way of container/dev
# work. this is usability, not weakening the boundary. unattended-upgrades stays on.
# patch this distro yourself: `sudo apt update && sudo apt full-upgrade`, or rebuild.

ASSUME_YES=0; [ "${1:-}" = "--yes" ] && ASSUME_YES=1

cat <<'BANNER'
=== WSL2 dev-sandbox tuning (sudo) ===
This will change THIS WSL2 distro:
  • /etc/wsl.conf    -> systemd=true; drop inherited Windows PATH; automount metadata
  • disable ufw      -> NAT'd WSL firewall is ineffective; Windows Firewall is the boundary
  • disable AppArmor -> partial in WSL2; interferes with Docker/podman dev work
  • disable motd-news-> cosmetic; removes a network call on shell start
  • remove snap      -> barely functions in WSL2 (dev cruft)
It does NOT disable unattended-upgrades (security patching stays on).
It does NOT change anything on the Windows host.
BANNER

if [ "$ASSUME_YES" != 1 ]; then
  if [ -t 0 ]; then
    printf "Proceed with these changes? [y/N] "
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "aborted; no changes made."; exit 0 ;; esac
  else
    echo "non-interactive run: refusing to change system services without consent." >&2
    echo "  pass --yes, or run via:  ./install.sh --wsl-tweaks" >&2
    exit 1
  fi
fi

echo ""
echo "[1/4] /etc/wsl.conf"
# appendWindowsPath=false: don't inherit the Windows PATH into WSL. two reasons:
#  (1) speed  - every Windows PATH entry is a /mnt/c 9p path; scanning them on every
#               completion / command-not-found makes the shell laggy.
#  (2) collisions - Windows .exe shims (node.exe, kubectl.exe, python.exe, ...) would
#               shadow the mise-managed Linux tools; dropping them lets the shims win.
# trade-off: this also drops powershell.exe, which Claude Code needs to read a
# Windows-clipboard image. common.sh re-adds just that one dir back (not the whole
# Windows PATH) so image paste works without re-introducing (1)/(2).
sudo tee /etc/wsl.conf > /dev/null << 'EOF'
[boot]
systemd=true

[interop]
appendWindowsPath=false

[automount]
options=metadata
EOF
echo "  done (systemd on, Windows PATH dropped, automount metadata)."

echo ""
echo "[2/4] Disabling WSL-ineffective / dev-interfering services"
sudo systemctl disable --now ufw 2>/dev/null && echo "  disabled ufw" || echo "  ufw already off"
sudo systemctl disable --now motd-news.timer 2>/dev/null && echo "  disabled motd-news" || echo "  motd-news already off"
sudo systemctl disable --now apparmor 2>/dev/null && echo "  disabled apparmor" || echo "  apparmor already off"
# NOTE: unattended-upgrades is intentionally left ENABLED. If you disable it for
# build stability, patch this distro yourself: sudo apt update && sudo apt full-upgrade

echo ""
echo "[3/4] Removing snap (dev cruft in WSL2)"
if command -v snap &> /dev/null; then
    echo "  installed snaps (will be removed):"
    snap list 2>/dev/null | sed 's/^/    /'
    sudo systemctl stop snapd snapd.socket snapd.seeded 2>/dev/null || true
    sudo systemctl disable snapd snapd.socket snapd.seeded 2>/dev/null || true
    for snap_name in $(snap list 2>/dev/null | awk 'NR>1 {print $1}'); do
        echo "  removing snap: $snap_name"
        sudo snap remove --purge "$snap_name" 2>/dev/null || true
    done
    sudo apt purge -y snapd 2>/dev/null || true
    sudo rm -rf /snap /var/snap /var/lib/snapd ~/snap
    sudo tee /etc/apt/preferences.d/no-snap << 'SNAPEOF' >/dev/null
Package: snapd
Pin: release a=*
Pin-Priority: -10
SNAPEOF
    echo "  snap removed and pinned off."
else
    echo "  snap not installed, skipping."
fi

echo ""
echo "[4/4] apt autoremove"
sudo apt autoremove -y 2>/dev/null || true
echo "  done."

echo ""
echo "=== Done. Restart WSL for changes to take effect: ==="
echo "  From PowerShell:  wsl --shutdown   (then reopen your terminal)"
