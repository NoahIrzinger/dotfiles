#!/usr/bin/env bash
# Custom packaging workaround: upstream shrinkwrap defeats npm overrides.
# Verify upstream, discard only its lock metadata, then use our audited npm lock.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_only=0
if [ "${1:-}" = --lock ]; then lock_only=1; shift; fi
dest="${1:-$HOME/.local/share/dotfiles/pi}"
bindir="${2:-$HOME/.local/bin}"
node_bin="${DOTFILES_NODE_BIN:-$(command -v node)}"
npm_cli="$(dirname "$node_bin")/../lib/node_modules/npm/bin/npm-cli.js"
"$node_bin" -e 'const [a,b,c]=process.versions.node.split(".").map(Number); if(a!==24 || b<22 || (b===22 && c<3)) throw Error("Pi requires the patched Node 24.22.3+ release line")'
if [ "$lock_only" = 1 ]; then
  stage="$(mktemp -d)"
else
  digest="$(cat "$repo/tools/pi/package.json" "$repo/tools/pi/package-lock.json" "$repo/tools/pi/upstream.json" | openssl dgst -sha256 | awk '{print $NF}')"
  target="$dest/$digest"
  mkdir -p "$dest" "$bindir"
  stage="$(mktemp -d "$dest/.install.XXXXXX")"
fi
trap 'rm -rf "$stage"' EXIT
if [ "$lock_only" = 1 ] || [ ! -f "$target/.complete" ]; then
  url="$("$node_bin" -p 'require(process.argv[1]).url' "$repo/tools/pi/upstream.json")"
  curl -q -fLsS --proto '=https' "$url" -o "$stage/upstream.tgz"
  "$node_bin" --input-type=module - "$repo/tools/pi/upstream.json" "$stage/upstream.tgz" <<'JS'
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const metadata=JSON.parse(readFileSync(process.argv[2]));
const actual='sha512-'+createHash('sha512').update(readFileSync(process.argv[3])).digest('base64');
if(actual!==metadata.integrity) throw new Error('Pi upstream integrity mismatch');
JS
  mkdir "$stage/runtime"
  tar -xzf "$stage/upstream.tgz" -C "$stage/runtime" --strip-components=1
  rm -f "$stage/runtime/npm-shrinkwrap.json"
  cp "$repo/tools/pi/package.json" "$stage/"
  : > "$stage/.npmrc-empty"
  npm_args=(--install-links --legacy-peer-deps --ignore-scripts --no-audit --no-fund
    --registry=https://registry.npmjs.org --userconfig=/dev/null --globalconfig="$stage/.npmrc-empty"
    --cache="${DOTFILES_NPM_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/npm}")
  if [ "$lock_only" = 1 ]; then
    ( cd "$stage" && "$node_bin" "$npm_cli" install --package-lock-only "${npm_args[@]}" )
    cp "$stage/package-lock.json" "$repo/tools/pi/package-lock.json"
    exit 0
  fi
  cp "$repo/tools/pi/package-lock.json" "$stage/"
  ( cd "$stage" && "$node_bin" "$npm_cli" ci "${npm_args[@]}" )
  "$node_bin" --input-type=module - "$stage" <<'JS'
import {createRequire} from 'node:module';
const require=createRequire(process.argv[2]+'/node_modules/@earendil-works/pi-coding-agent/package.json');
for (const [name,version] of Object.entries(require(process.argv[2]+'/package.json').overrides)) {
  if (require(name+'/package.json').version !== version) throw new Error('Unexpected '+name+' version');
}
JS
  touch "$stage/.complete"
  [ ! -e "$target" ] || { echo "Incomplete Pi target already exists: $target" >&2; exit 1; }
  mv "$stage" "$target"
fi
# Refresh after Node upgrades even when the dependency graph has not changed.
printf '#!/usr/bin/env bash\nexec %q %q "$@"\n' "$node_bin" \
  "$target/node_modules/@earendil-works/pi-coding-agent/dist/cli.js" > "$target/pi.tmp"
chmod 755 "$target/pi.tmp"
mv "$target/pi.tmp" "$target/pi"
ln -sfn "$target" "$dest/current"
ln -sfn "$dest/current/pi" "$bindir/pi"
