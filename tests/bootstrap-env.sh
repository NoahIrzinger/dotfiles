#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT

# Load only the environment guard, without running the installer.
source /dev/stdin <<< "$(sed -n '/^bootstrap_tool_env(){/,/^}/p' "$repo/install.sh")"
mkdir -p "$td/mise/shims" "$td/custom/shims" "$td/native bin"
ln -s "$td/mise/shims" "$td/shim-alias"
for dir in "$td/mise/shims" "$td/custom/shims"; do
  printf '#!/bin/sh\nexit 99\n' > "$dir/python3"
  chmod +x "$dir/python3"
done
printf '#!/bin/sh\nprintf "system-python\\n"\n' > "$td/native bin/python3"
chmod +x "$td/native bin/python3"

(
  SHIMS="$td/mise/shims"
  export MISE_SHIMS_DIR="$td/custom/shims"
  export MISE_AUTO_INSTALL=1 MISE_NOT_FOUND_AUTO_INSTALL=1 MISE_EXEC_AUTO_INSTALL=1
  export PATH="$SHIMS/:$td/shim-alias:$MISE_SHIMS_DIR:$td/native bin:/usr/bin:/bin"
  bootstrap_tool_env
  [ "$PATH" = "$td/native bin:/usr/bin:/bin" ]
  [ "$MISE_AUTO_INSTALL" = 0 ]
  [ "$MISE_NOT_FOUND_AUTO_INSTALL" = 0 ]
  [ "$MISE_EXEC_AUTO_INSTALL" = 0 ]
  [ "$(python3)" = system-python ]
)
(
  SHIMS="$td/mise/shims"
  unset MISE_SHIMS_DIR
  export MISE_DATA_DIR="$td/custom"
  export PATH="$SHIMS:$MISE_DATA_DIR/shims"
  bootstrap_tool_env
  [ "$PATH" = /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin ]
)
echo "PASS: bootstrap bypasses default/custom/aliased Python shims and disables automatic installs"
