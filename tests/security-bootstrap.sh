#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT

# Exercise the version gate without sourcing or running the installer.
source /dev/stdin <<< "$(sed -n '/^mise_is_current(){/,/^}/p' "$repo/install.sh")"
# Consumed by the sourced gate.
# shellcheck disable=SC2034
MISE_VERSION=v2026.10.21
mise(){ printf '%s test-platform\n' "$fake_version"; }
for fake_version in 2026.6.0 2026.10.0 2026.10.20 unknown 2026.10.21-dev; do
  if mise_is_current; then echo "FAIL: accepted mise $fake_version" >&2; exit 1; fi
done
for fake_version in 2026.10.21 2026.10.22 2027.1.0; do mise_is_current; done
unset -f mise
echo "PASS: mise gate rejects old and unparseable versions, accepts fixed/newer releases"

# Check the installed-binary gate against representative build metadata.
cat > "$td/go" <<'SH'
#!/usr/bin/env bash
cat "$3"
SH
chmod +x "$td/go"
printf 'fixture: go1.27.4\n\tdep\tgolang.org/x/net\tv0.62.0\n' > "$td/buildinfo"
bash "$repo/tools/check-go.sh" "$td/go" "$td/buildinfo" >/dev/null
printf 'fixture: go1.27.3\n' > "$td/buildinfo"
if bash "$repo/tools/check-go.sh" "$td/go" "$td/buildinfo" >/dev/null 2>&1; then
  echo 'FAIL: accepted an outdated embedded Go runtime' >&2; exit 1
fi
printf 'fixture: go1.27.4\n\tdep\tgolang.org/x/net\tv0.60.0\n' > "$td/buildinfo"
if bash "$repo/tools/check-go.sh" "$td/go" "$td/buildinfo" >/dev/null 2>&1; then
  echo 'FAIL: accepted a vulnerable dependency despite a patched compiler' >&2; exit 1
fi
printf 'fixture: go1.27.4\n\tdep\tgolang.org/x/text\tv0.42.0\n' > "$td/buildinfo"
bash "$repo/tools/check-go.sh" "$td/go" "$td/buildinfo" >/dev/null
echo 'PASS: binary gate checks runtime and dependency floors independently'

# Use a disposable local Git fixture; no network and no live plugin directories.
source /dev/stdin <<< "$(sed -n '/^install_tmux_plugins(){/,/^}/p' "$repo/install.sh")"
git init -q -b master "$td/source"
printf 'pinned\n' > "$td/source/plugin.tmux"
git -C "$td/source" add plugin.tmux
git -C "$td/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm pinned
pin="$(git -C "$td/source" rev-parse HEAD)"
printf 'moving-head\n' > "$td/source/plugin.tmux"
git -C "$td/source" add plugin.tmux
git -C "$td/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm newer
REPO="$td/config"
mkdir -p "$REPO/tmux/.config/tmux" "$td/plugins"
printf "set -g @plugin 'fixture/plugin#%s'\n" "$pin" > "$REPO/tmux/.config/tmux/tmux.conf"
git(){
  if [ "$1" = clone ]; then
    command git clone -q --no-checkout --no-hardlinks "$td/source" "${@: -1}"
  elif [ "$1" = -C ] && [ "$3" = fetch ]; then
    echo 'unexpected network fetch in offline test' >&2; return 99
  else command git "$@"; fi
}
install_tmux_plugins "$td/plugins" >/dev/null 2>&1
[ "$(command git -C "$td/plugins/plugin" rev-parse HEAD)" = "$pin" ]
printf 'local-edit\n' > "$td/plugins/plugin/plugin.tmux"
if install_tmux_plugins "$td/plugins" >/dev/null 2>&1; then
  echo 'FAIL: dirty tmux plugin was accepted' >&2; exit 1
fi
[ "$(cat "$td/plugins/plugin/plugin.tmux")" = local-edit ]
printf "set -g @plugin 'fixture/plugin#master'\n" > "$REPO/tmux/.config/tmux/tmux.conf"
if install_tmux_plugins "$td/plugins" >/dev/null 2>&1; then
  echo 'FAIL: mutable tmux plugin ref was accepted' >&2; exit 1
fi
unset -f git
echo "PASS: tmux checks out the pinned commit; dirty trees and mutable refs are rejected"

# Isolate bootstrap ordering: unverified code must never reach require('lazy').
cat > "$td/lazy.lua" <<'LUA'
local native = vim
local source = native.env.TEST_REPO .. "/nvim/.config/nvim/lua/config/lazy.lua"
local commit = string.rep("a", 40)
local function scenario(exists, dirty, fetch_fails)
  local events = {}
  local checked_out, loaded = false, false
  _G.vim = {
    uv = { fs_stat = function() return exists and {} or nil end },
    v = { shell_error = 0 },
    fn = {
      stdpath = function(kind) return "/fixture/" .. kind end,
      readfile = function() return { native.json.encode({ ["lazy.nvim"] = { commit = commit } }) } end,
      system = function(args)
        local cmd = table.concat(args, " ")
        table.insert(events, cmd)
        vim.v.shell_error = 0
        if cmd:find(" status ", 1, true) then return dirty and " M lua/lazy/init.lua" or "" end
        if cmd:find(" rev-parse ", 1, true) then return string.rep("b", 40) end
        if cmd:find(" fetch ", 1, true) and fetch_fails then
          vim.v.shell_error = 1
          return "fixture fetch failure"
        end
        if cmd:find(" checkout ", 1, true) then
          assert(args[#args] == commit and args[#args-1] == "--detach")
          checked_out = true
        end
        return ""
      end,
    },
    json = native.json,
    trim = native.trim,
    validate = native.validate,
    opt = { rtp = { prepend = function() assert(checked_out) end } },
    g = {},
  }
  package.loaded.lazy = nil
  package.preload.lazy = function()
    assert(checked_out, "executed plugin manager before pinned checkout")
    loaded = true
    return { setup = function() end }
  end
  local ok, err = pcall(dofile, source)
  _G.vim = native
  if dirty or fetch_fails then
    assert(not ok and not loaded, "unsafe bootstrap did not fail closed")
  else
    assert(ok and loaded, err)
  end
  if not exists then assert(events[1]:find("--no-checkout", 1, true)) end
end
scenario(false, false, false)
scenario(true, false, false)
scenario(true, true, false)
scenario(false, false, true)
print("PASS: fresh/existing lazy bootstrap pins before execution; dirty/failed fetch refuses execution")
LUA
TEST_REPO="$repo" NVIM_LOG_FILE="$td/nvim.log" nvim --clean -i NONE -l "$td/lazy.lua"
