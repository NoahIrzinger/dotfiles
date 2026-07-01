#!/usr/bin/env bash
# Bootstrap this dotfiles repo on a fresh machine.
#
#   ./install.sh                      # install everything
#   ./install.sh --skip gradle,java   # everything except those tools
#   ./install.sh --configs-only       # stow configs, don't install tools
#   ./install.sh --wsl-tweaks         # also apply the opt-in WSL system tweaks
#   ./install.sh --dry-run            # show what would happen, change nothing
#   ./install.sh --verbose            # trace every command (set -x)
#
# tools come from mise (mise.toml); configs from stow (packages list).

# re-exec under bash if started via `sh install.sh`; dash lacks the arrays /
# pipefail this uses and dies with an opaque "syntax error: newline".
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIMS="$HOME/.local/share/mise/shims"
REPO_URL="https://github.com/NoahIrzinger/dotfiles"

# ---- logging: tee to a per-user private log (not /tmp; set -x can echo secrets).
#      on failure the ERR trap prints the dead line/command + log path. ----
LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
( umask 077; mkdir -p "$LOGDIR" )
LOG="$LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
( umask 077; : > "$LOG" )
exec > >(tee -a "$LOG") 2>&1
trap 'rc=$?; printf "\033[1;31m✗ install failed (exit %s) at line %s:\033[0m %s\n   full log: %s\n" "$rc" "$LINENO" "$BASH_COMMAND" "$LOG" >&2' ERR

# ---- args ----
DRY=0; SKIP=""; CONFIGS_ONLY=0; VERBOSE=0; WSL_TWEAKS=0; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --configs-only) CONFIGS_ONLY=1 ;;
    --skip) SKIP="$2"; shift ;;
    --skip=*) SKIP="${1#--skip=}" ;;
    -v|--verbose) VERBOSE=1 ;;
    --wsl-tweaks) WSL_TWEAKS=1 ;;   # opt in to the sudo system changes in wsl/wsl-optimize.sh
    --check|doctor) CHECK=1 ;;      # health-check the install, change nothing
    -*) echo "unknown flag: $1"; exit 1 ;;
    *) echo "unexpected arg: $1 (profiles were removed; use --skip <tools>)"; exit 1 ;;
  esac
  shift
done
export MISE_DISABLE_TOOLS="$SKIP"
# --verbose: trace every command, and make mise itself chatty
[ "$VERBOSE" = 1 ] && { export MISE_VERBOSE=1; set -x; }

# ---- platform ----
OS=linux; [ "$(uname -s)" = Darwin ] && OS=macos
IS_WSL=false; grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true
SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

log(){ printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
plan(){ printf '   [dry-run] %s\n' "$*"; }
sha256_of(){  # portable sha256 of a file -> bare hex
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# end-of-run summary: lists every tool (with version) and config plus health,
# driven off the final system state + the log so it can't drift from what ran.
report(){
  set +eu   # never let a diagnostic command abort the report
  local g=$'\033[1;32m' y=$'\033[1;33m' r=$'\033[1;31m' dim=$'\033[2m' b=$'\033[1m' nc=$'\033[0m'
  local rule="────────────────────────────────────────────────────"
  local warns=0 fails=0 nok=0
  local ca="${CA_BUNDLE:-$HOME/.config/certs/cacert.pem}" mver ncerts ncfg nplug p
  mver="$(mise --version 2>/dev/null | awk '{print $1}')"
  ncerts=0; [ -f "$ca" ] && ncerts="$(grep -c 'BEGIN CERT' "$ca" 2>/dev/null)"
  nplug="$(ls -1d "$HOME/.local/share/nvim/lazy/"*/ 2>/dev/null | wc -l | tr -d ' ')"
  ncfg=0; for p in ${PACKAGES:-}; do [ -d "$REPO/$p" ] && ncfg=$((ncfg+1)); done

  printf "\n  ${b}dotfiles${nc}${dim} · install summary${nc}\n  ${dim}%s${nc}\n" "$rule"

  # every tool, with version, in a 3-wide grid
  printf "\n  ${b}tools${nc}\n"
  local cells=() cell st nm ver ic col i=0
  while read -r nm ver _; do [ -n "$nm" ] && { cells+=("ok|${nm##*/}|$ver"); nok=$((nok+1)); }; done < <(mise ls --installed 2>/dev/null | sort)
  while read -r nm _;      do [ -n "$nm" ] && { cells+=("fail|${nm##*/}|missing"); fails=$((fails+1)); }; done < <(mise ls --missing 2>/dev/null | awk 'NF')
  for st in $(printf '%s' "${MISE_DISABLE_TOOLS:-}" | tr ',' ' '); do [ -n "$st" ] && cells+=("skip|$st|skipped"); done
  for cell in "${cells[@]}"; do
    st="${cell%%|*}"; nm="${cell#*|}"; ver="${nm#*|}"; nm="${nm%%|*}"
    case "$st" in ok) ic="✔" col="$g" ;; fail) ic="✘" col="$r" ;; *) ic="·" col="$dim" ;; esac
    [ $((i % 3)) -eq 0 ] && printf "  "
    printf " ${col}%s${nc} %-10.10s ${dim}%-11.11s${nc}" "$ic" "$nm" "$ver"
    i=$((i + 1)); [ $((i % 3)) -eq 0 ] && printf "\n"
  done
  [ $((i % 3)) -ne 0 ] && printf "\n"

  # configs (every package) + health rows
  printf "\n  ${b}configs${nc}  ${dim}%s${nc}\n\n" "${PACKAGES:-}"
  stat(){ local s="$1" l="$2" v="$3" ic col
    case "$s" in ok) ic="✔" col="$g" ;; warn) ic="⚠" col="$y"; warns=$((warns+1)) ;; fail) ic="✘" col="$r"; fails=$((fails+1)) ;; *) ic="·" col="$dim" ;; esac
    printf "  ${col}%s${nc} %-9s ${dim}%s${nc}\n" "$ic" "$l" "$v"; }
  [ -n "$mver" ] && stat ok "mise" "$mver" || stat fail "mise" "not installed"
  [ "${ncerts:-0}" -gt 0 ] && stat ok "certs" "$ncerts trusted" || stat skip "certs" "none"
  stat ok "configs" "$ncfg stowed"
  [ "${nplug:-0}" -gt 0 ] && stat ok "neovim" "$nplug plugins" || stat warn "neovim" "no plugins"
  [ -d "$HOME/.local/share/tmux/plugins/tpm" ] && stat ok "tmux" "plugins ok" || stat warn "tmux" "TPM missing"
  [ -x "$HOME/.local/share/android/platform-tools/adb" ] && stat ok "adb" "platform-tools"
  stat ok "theme" "$(cat "$REPO/themes/active" 2>/dev/null || echo dark)"
  if [ "${IS_WSL:-false}" = true ]; then
    [ "${WSL_TWEAKS:-0}" = 1 ] && stat ok "wsl" "tweaks applied" || stat skip "wsl" "tweaks skipped"
  fi

  # footer
  local flagged fcol="$g"; flagged="$(grep -ciE 'error|failed|mismatch|UNABLE_TO|not a working' "$LOG" 2>/dev/null)"
  [ "${warns:-0}" -gt 0 ] && fcol="$y"; [ "${fails:-0}" -gt 0 ] && fcol="$r"
  printf "\n  ${dim}%s${nc}\n" "$rule"
  printf "  ${fcol}●${nc} ${b}%s tools${nc} · %s configs · %s warn · %s fail   ${dim}%s flagged${nc}\n" \
    "$nok" "$ncfg" "$warns" "$fails" "${flagged:-0}"
  printf "  ${dim}log: %s${nc}\n\n" "$LOG"
}
to(){  # to <secs> <cmd...>: run capped; exits 124 (timeout) / 142 (perl alarm) on timeout
  if   command -v timeout  >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  elif command -v perl     >/dev/null 2>&1; then local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"
  else shift; "$@"; fi
}

# `./install.sh --check`: actively verify the install (loads nvim, parses tmux,
# times shell startup) and report. changes nothing.
doctor(){
  set +e
  # mise tools are shims, not on PATH in a non-login shell (e.g. CI), so checks like
  # `command -v nvim` would silently skip. put the shims on PATH first.
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
  local g=$'\033[1;32m' y=$'\033[1;33m' r=$'\033[1;31m' dim=$'\033[2m' bl=$'\033[1;36m' nc=$'\033[0m'
  local warns=0 fails=0 rc out
  row(){ local ic col; case "$1" in
      ok)   ic="✔" col="$g" ;;
      warn) ic="⚠" col="$y"; warns=$((warns+1)) ;;
      fail) ic="✘" col="$r"; fails=$((fails+1)) ;;
      *)    ic="·" col="$dim" ;;
    esac; printf "   ${col}%s${nc} %-16s ${dim}%s${nc}\n" "$ic" "$2" "${3:-}"; }
  printf "\n${bl}  ━━ dotfiles doctor ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}\n"

  local miss; miss="$(mise ls --missing 2>/dev/null | awk 'NF{print $1}' | paste -sd, - 2>/dev/null)"
  [ -z "$miss" ] && row ok "tools" "all present" || row warn "tools" "missing: $miss"

  if [ -L "$HOME/.config/nvim" ] && [ -f "$HOME/.config/shell/common.sh" ]; then row ok "configs linked"
  else row warn "configs linked" "run ./link.sh"; fi

  local ca="$HOME/.config/certs/cacert.pem"
  if [ -f "$ca" ]; then grep -q 'BEGIN CERT' "$ca" 2>/dev/null \
      && row ok "CA bundle" "$(grep -c 'BEGIN CERT' "$ca") certs" || row fail "CA bundle" "no certs in file"
  else row skip "CA bundle" "none"; fi

  if command -v nvim >/dev/null 2>&1; then
    out="$(to 40 nvim --headless +qa 2>&1)"; rc=$?
    # match genuine nvim error signatures only (Error detected / E123:), not the
    # substring "error" in unrelated stderr noise (e.g. a mise remote-fetch WARN).
    if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -qE 'Error detected|E[0-9]{2,}:'; then
      row ok "neovim loads"
    else
      row fail "neovim loads" "errors on startup (nvim --headless +qa)"
      printf '%s\n' "$out" | grep -E 'Error detected|E[0-9]{2,}:' | head -3 | sed 's/^/         /'
    fi
    out="$(to 40 nvim --headless '+lua local missing={}; for _,c in ipairs({"fd","rg","fzf","tree-sitter","node"}) do if vim.fn.executable(c)==0 then table.insert(missing,c) end end; if #missing>0 then error("missing nvim PATH tools: "..table.concat(missing,",")) end' +qa 2>&1)"; rc=$?
    [ "$rc" = 0 ] && row ok "nvim PATH" "fd rg fzf tree-sitter node" || { row fail "nvim PATH" "mise tools unavailable inside nvim"; printf '%s\n' "$out" | tail -3 | sed 's/^/         /'; }
    out="$(to 50 nvim --headless '+checkhealth fff' '+w! /tmp/dotfiles-fff-health.txt' +qa >/dev/null 2>&1; cat /tmp/dotfiles-fff-health.txt 2>/dev/null)"; rc=$?
    printf '%s' "$out" | grep -q 'Binary loaded successfully' && row ok "fff.nvim" "binary loaded" || row warn "fff.nvim" "binary not loaded; run :Lazy build fff.nvim"
  fi

  if command -v dlv >/dev/null 2>&1; then
    out="$(dlv version 2>/dev/null | awk '/Version:/ {print $2; exit}')"
    case "$out" in 1.26.*|1.27.*|1.28.*|1.29.*) row ok "delve" "$out" ;; *) row warn "delve" "old version: ${out:-unknown}; run mise install" ;; esac
  fi

  if command -v tmux >/dev/null 2>&1; then
    local sock="doc$$"
    to 10 tmux -L "$sock" -f "$HOME/.config/tmux/tmux.conf" new-session -d 2>/dev/null \
      && { row ok "tmux config"; tmux -L "$sock" kill-server 2>/dev/null; } || row fail "tmux config" "parse error"
  fi

  # LLM CLIs: a shim can exist while the binary is broken (npm-backed claude/opencode
  # skip the postinstall that fetches the native binary, so it errors "native binary
  # not installed"). actually run each present one rather than trust the shim.
  local t llm_seen="" llm_bad=""
  for t in claude codex opencode; do
    command -v "$t" >/dev/null 2>&1 || continue
    llm_seen=1
    out="$(to 15 "$t" --version 2>&1)"; rc=$?
    { [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -qiE 'native binary not installed|postinstall'; } \
      || llm_bad="$llm_bad $t"
  done
  if [ -n "$llm_bad" ]; then row fail "llm clis" "broken:${llm_bad}; run dotfiles-update"
  elif [ -n "$llm_seen" ]; then row ok "llm clis" "claude codex opencode run"; fi

  to 8 bash -lic 'exit' >/dev/null 2>&1; rc=$?
  case "$rc" in 124|142) row warn "shell startup" "slow/hang (>8s)" ;; *) row ok "shell startup" "no hang" ;; esac

  printf "${bl}  ──────────────────────────────────────────────${nc}\n"
  printf "   ${dim}%s warning(s) · %s failure(s)${nc}\n\n" "$warns" "$fails"
  [ "$fails" -gt 0 ] && return 1 || return 0
}
[ "$CHECK" = 1 ] && { doctor; exit $?; }

log "install log: $LOG"

# mise from a pinned GitHub release, verified against a repo-reviewed SHA256.
# not `curl mise.run | sh`: behind an inspecting proxy that domain returns an HTML block page
# that pipes into sh as "syntax error: newline". github releases are allowlisted.
# tampered release / MITM / block page all fail the hash instead of running.
# bump = update MISE_VERSION + the 4 hashes (from SHASUMS256.txt) in one commit.
MISE_VERSION="v2026.6.1"
mise_expected_sha(){  # $1 = <os>-<arch>
  case "$1" in
    linux-x64)   echo 7de295b32bc9d4dd894effe487d76ca46cd8cecbc588a76863e97d6b53c314be ;;
    linux-arm64) echo 7ba3ec4fe52d24a22a51deaeca1da615b8a39176ac9965a6e820a6759da87881 ;;
    macos-arm64) echo ac95cf406b8c350dd7e7ac074a9b64c1802c052fa9337820ec18e4b5acc405f7 ;;
    macos-x64)   echo 5a5bd62cc27c15c029a77724e2a6949e2f2bfc73b0ac1946d8afed79132b6aa5 ;;
  esac
}
install_mise(){
  local os arch plat asset url td tmp want got
  os=linux; [ "$OS" = macos ] && os=macos
  case "$(uname -m)" in
    x86_64|amd64)  arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "unsupported arch $(uname -m); install mise manually: https://github.com/jdx/mise/releases" >&2; exit 1 ;;
  esac
  plat="$os-$arch"; want="$(mise_expected_sha "$plat")"
  [ -n "$want" ] || { echo "no pinned mise hash for $plat; refusing to install unverified" >&2; exit 1; }
  log "Installing mise $MISE_VERSION ($plat, checksum-pinned)"
  asset="mise-${MISE_VERSION}-${plat}"
  url="https://github.com/jdx/mise/releases/download/${MISE_VERSION}/${asset}"
  # stage as a file named `mise`: the binary dispatches on its own argv[0].
  td="$(mktemp -d)"; tmp="$td/mise"
  curl -fsSL "$url" -o "$tmp" || { echo "  download failed: $url" >&2; rm -rf "$td"; exit 1; }
  got="$(sha256_of "$tmp")"
  if [ "$got" != "$want" ]; then
    echo "  ✗ mise checksum mismatch for $asset; not installing." >&2
    echo "      expected $want" >&2
    echo "      got      $got" >&2
    echo "    cause: tampered release, MITM, or a proxy block page." >&2
    rm -rf "$td"; exit 1
  fi
  chmod +x "$tmp"
  "$tmp" --version >/dev/null 2>&1 || { echo "  pinned mise binary won't run on this host" >&2; rm -rf "$td"; exit 1; }
  mkdir -p "$HOME/.local/bin"
  cp "$tmp" "$HOME/.local/bin/mise" && chmod 755 "$HOME/.local/bin/mise"
  rm -rf "$td"
}

# ---- self-clone when run via `curl | bash` ----
if [ ! -f "$REPO/mise.toml" ]; then
  log "Bootstrapping from $REPO_URL"
  if ! have git; then
    if [ "$OS" = macos ]; then
      have brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      brew install git
    else
      $SUDO apt-get update -qq && $SUDO apt-get install -y git
    fi
  fi
  DEST="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if [ -d "$DEST/.git" ]; then
    # FORCE the clone to latest origin/master so re-running the one-liner always runs
    # the newest installer, even if the tree drifted. the repo is the source of truth;
    # machine-local values live in ~/.shell.local, not here, so a hard reset is safe
    # and is what makes "just re-run the one-liner" reliably fix things.
    log "Syncing $DEST to latest origin/master"
    git -C "$DEST" fetch -q origin master || log "  fetch failed (offline?); using $DEST as-is"
    git -C "$DEST" reset --hard -q origin/master 2>/dev/null \
      || git -C "$DEST" reset --hard -q FETCH_HEAD 2>/dev/null || true
  else
    git clone "$REPO_URL" "$DEST"
  fi
  args=(); [ "$DRY" = 1 ] && args+=(--dry-run); [ "$CONFIGS_ONLY" = 1 ] && args+=(--configs-only); [ -n "$SKIP" ] && args+=(--skip "$SKIP")
  [ "$WSL_TWEAKS" = 1 ] && args+=(--wsl-tweaks); [ "$VERBOSE" = 1 ] && args+=(--verbose)
  exec bash "$DEST/install.sh" "${args[@]}"
fi

PACKAGES="$(cat "$REPO/packages")"
log "os=$OS  wsl=$IS_WSL  dry-run=$DRY  configs-only=$CONFIGS_ONLY${SKIP:+  skip=$SKIP}"

if [ "$CONFIGS_ONLY" = 0 ]; then
  # ---- 1. base prerequisites ----
  log "Base prerequisites (git, stow, build tools)"
  if [ "$DRY" = 1 ]; then
    plan "$([ "$OS" = macos ] && echo 'brew install git stow' || echo 'apt-get install git stow build-essential unzip')"
  elif [ "$OS" = macos ]; then
    have brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install git stow
  else
    # tolerate a flaky/blocked third-party apt repo (e.g. a proxy serving an HTML page
    # for a custom source, "Clearsigned file isn't valid, got NOSPLIT"). the base
    # packages come from the main archives, so a failed index refresh must not abort.
    $SUDO apt-get update -qq || log "  apt update had errors (a third-party repo may be blocked); continuing"
    $SUDO apt-get install -y git stow curl ca-certificates build-essential pkg-config cmake unzip
  fi

  # dtach: ad-hoc session-detach util, NOT on the critical path. keep it out of the
  # batch above and install it non-fatally: it's Debian main but Ubuntu `universe`
  # (absent on minimal images), and under `set -e` a single unlocatable package would
  # fail the whole apt-get call and abort the bootstrap. degrade to "skipped" instead.
  if [ "$DRY" = 1 ]; then
    plan "$([ "$OS" = macos ] && echo 'brew install dtach' || echo 'apt-get install dtach') (optional, non-fatal)"
  elif [ "$OS" = macos ]; then
    brew install dtach || log "  dtach unavailable via brew; skipping"
  else
    $SUDO apt-get install -y dtach || log "  dtach unavailable (Ubuntu needs 'universe'); skipping"
  fi

  # ---- 1.5 corporate CA trust ----
  # build + export the CA bundle BEFORE installing tools, so npm/pip/codex don't die
  # on UNABLE_TO_GET_ISSUER_CERT_LOCALLY behind an SSL-inspecting proxy. drop the
  # proxy's root/intermediate PEMs in ~/.config/certs/extra-roots/ first.
  CERT_DIR="$HOME/.config/certs/extra-roots"; CA_BUNDLE="$HOME/.config/certs/cacert.pem"
  if [ "$DRY" = 1 ]; then
    plan "CA: build $CA_BUNDLE from $CERT_DIR + certifi (if any), export NODE_EXTRA_CA_CERTS etc."
  else
    mkdir -p "$CERT_DIR"
    if ls "$CERT_DIR"/*.pem >/dev/null 2>&1; then
      log "CA: building trust bundle from $CERT_DIR + certifi"
      base="$(python3 -m certifi 2>/dev/null || true)"
      if [ -z "$base" ]; then                    # certifi missing: try to bootstrap pip
        cat "$CERT_DIR"/*.pem > "$CA_BUNDLE"
        PIP_CERT="$CA_BUNDLE" SSL_CERT_FILE="$CA_BUNDLE" python3 -m pip install --user -q certifi 2>/dev/null || true
        base="$(python3 -m certifi 2>/dev/null || true)"
      fi
      { if [ -n "$base" ]; then cat "$base"; fi; cat "$CERT_DIR"/*.pem; } > "$CA_BUNDLE"
      export SSL_CERT_FILE="$CA_BUNDLE" REQUESTS_CA_BUNDLE="$CA_BUNDLE" PIP_CERT="$CA_BUNDLE" \
             CURL_CA_BUNDLE="$CA_BUNDLE" NODE_EXTRA_CA_CERTS="$CA_BUNDLE" GIT_SSL_CAINFO="$CA_BUNDLE"
      log "  trusting $(grep -c 'BEGIN CERT' "$CA_BUNDLE" 2>/dev/null || echo '?') CA certs in the bundle"
      # also add to the OS trust store (Debian) so tools that read it but ignore the
      # env vars (mise's Rust client, apt) trust the proxy too. needs sudo (have it for apt).
      if [ "$OS" = linux ] && command -v update-ca-certificates >/dev/null 2>&1 \
         && { [ -n "$SUDO" ] || [ "$(id -u)" = 0 ]; }; then
        ci=0
        for c in "$CERT_DIR"/*.pem; do
          [ -e "$c" ] || continue; ci=$((ci+1))
          $SUDO cp "$c" "/usr/local/share/ca-certificates/extra-root-$ci.crt"
        done
        $SUDO update-ca-certificates >/dev/null 2>&1 && log "  added $ci cert(s) to the OS trust store"
      fi
    else
      log "CA: none in $CERT_DIR (fine off-VPN; behind a proxy, drop your PEMs there and re-run)"
    fi
  fi

  # ---- 2. mise ----
  if [ "$DRY" = 1 ]; then plan "ensure mise installed (GitHub release binary)"
  elif ! have mise; then install_mise; fi
  export PATH="$HOME/.local/bin:$PATH"

  # ---- 3. tools via mise (respects --skip via MISE_DISABLE_TOOLS) ----
  log "Tools via mise${SKIP:+ (skipping: $SKIP)}"
  if [ "$DRY" = 1 ]; then
    if have mise; then ( cd "$REPO"
      MISE_TRUSTED_CONFIG_PATHS="$REPO" mise ls --missing  2>/dev/null | sed 's/^/   would install: /'
      MISE_TRUSTED_CONFIG_PATHS="$REPO" mise ls --prunable 2>/dev/null | awk 'NF{print "   would remove:  "$1" "$2}' )
    else plan "install mise, then the tools"; fi
  else
    ( cd "$REPO" && mise trust >/dev/null 2>&1 || true )
    # node first so npm-backend tools (codex) have an interpreter on a fresh box
    if grep -q '^node' "$REPO/mise.toml"; then
      log "Installing node (runtime for npm-backend tools)"
      ( cd "$REPO" && mise install -y node ) || log "node install had issues; see $LOG"
    fi
    log "Installing all tools"
    # non-fatal: one bad tool shouldn't abort the bootstrap; report what's missing
    if ! ( cd "$REPO" && mise install -y ); then
      log "some tools did not install; continuing (full output in $LOG):"
      ( cd "$REPO" && mise ls --missing 2>/dev/null | sed 's/^/   still missing: /' ) || true
    fi
    # uninstall tools dropped from the config (commented out / --skip'd)
    prunable="$(mise ls --prunable 2>/dev/null | awk 'NF{print $1}' | sort -u | tr '\n' ' ')"
    [ -n "$prunable" ] && { log "Removing tools no longer in config: $prunable"; mise prune >/dev/null 2>&1 || true; }
    mise reshim >/dev/null 2>&1 || true
    export PATH="$SHIMS:$PATH"
  fi

  # ---- 3.5 android platform-tools (adb/fastboot) from Google's official release ----
  # not the distro adb (protocol skews against the device's adb server). decoupled
  # from the heavy SDK so device work always has a current adb. skipped when
  # android-sdk is (--skip android-sdk), e.g. on lean boxes / CI.
  PLATFORM_TOOLS_VERSION="37.0.0"
  platform_tools_expected_sha(){  # $1 = linux|darwin
    case "$1" in
      linux)  echo 198ae156ab285fa555987219af237b31102fefe8b9d2bc274708a8d4f2865a07 ;;
      darwin) echo 094a1395683c509fd4d48667da0d8b5ef4d42b2abfcd29f2e8149e2f989357c7 ;;
    esac
  }
  case ",${MISE_DISABLE_TOOLS:-}," in
    *,android-sdk,*) : ;;
    *)
      ptos=linux; [ "$OS" = macos ] && ptos=darwin
      ptprops="$HOME/.local/share/android/platform-tools/source.properties"
      if [ "$DRY" = 1 ]; then plan "install Google platform-tools $PLATFORM_TOOLS_VERSION (checksum-verified)"
      elif ! [ -x "$HOME/.local/share/android/platform-tools/adb" ] \
        || ! grep -q "^Pkg.Revision=$PLATFORM_TOOLS_VERSION$" "$ptprops" 2>/dev/null; then
        log "Installing Android platform-tools $PLATFORM_TOOLS_VERSION (checksum-verified)"
        ptmp="$(mktemp -d)"
        pturl="https://dl.google.com/android/repository/platform-tools_r${PLATFORM_TOOLS_VERSION}-${ptos}.zip"
        ptwant="$(platform_tools_expected_sha "$ptos")"
        if curl -fsSL -o "$ptmp/pt.zip" "$pturl"; then
          ptgot="$(sha256_of "$ptmp/pt.zip")"
          if [ "$ptgot" = "$ptwant" ]; then
            mkdir -p "$HOME/.local/share/android"
            unzip -o -q "$ptmp/pt.zip" -d "$HOME/.local/share/android" \
              && log "  adb -> ~/.local/share/android/platform-tools"
          else
            log "  platform-tools checksum mismatch; skipping"
            log "    expected $ptwant"
            log "    got      $ptgot"
          fi
        else log "  platform-tools download failed (proxy?); skipping"; fi
        rm -rf "$ptmp"
      fi
      ;;
  esac
else
  log "configs-only: skipping tool install"
  export PATH="$SHIMS:$HOME/.local/bin:$PATH"
fi

# ---- 3.6 claude: satisfy `/doctor` and the native `claude install` path check ----
# claude is mise-managed (pinned in mise.toml, self-update off), so the official
# installer's location ~/.local/bin/claude is empty and `claude /doctor` reports
# "command missing or broken". point it at the mise shim (stable across version
# bumps, unlike the versioned install dir) so the check passes. resolution is
# unaffected: the mise install dir + shims already precede ~/.local/bin on PATH.
if [ "$DRY" = 1 ]; then
  plan "link ~/.local/bin/claude -> mise shim (silence claude /doctor)"
elif [ -e "$SHIMS/claude" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$SHIMS/claude" "$HOME/.local/bin/claude" \
    && log "Linked ~/.local/bin/claude -> mise shim"
fi

# ---- make the repo's toolset the GLOBAL mise config (tools active in every dir,
#      not just inside the repo) ----
BK="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
MISE_GLOBAL="$HOME/.config/mise/config.toml"
if [ "$DRY" = 1 ]; then
  if [ -e "$MISE_GLOBAL" ] || [ -L "$MISE_GLOBAL" ]; then plan "back up $MISE_GLOBAL if it is not this repo's symlink"; fi
  plan "link ~/.config/mise/config.toml -> repo mise.toml"
else
  mkdir -p "$HOME/.config/mise"
  if { [ -e "$MISE_GLOBAL" ] || [ -L "$MISE_GLOBAL" ]; } \
     && ! { [ -L "$MISE_GLOBAL" ] && [ "$(readlink "$MISE_GLOBAL")" = "$REPO/mise.toml" ]; }; then
    mkdir -p "$(dirname "$BK/.config/mise/config.toml")"
    mv "$MISE_GLOBAL" "$BK/.config/mise/config.toml"
    echo "   backed up $MISE_GLOBAL"
  fi
  ln -sf "$REPO/mise.toml" "$MISE_GLOBAL"
fi

# ---- Linux desktop / WSL env: GUI-launched apps do not read .bashrc/.zshrc. ----
# Neovim also bootstraps PATH internally, but exporting this through systemd user
# makes terminals, launchers, and editor integrations see mise/mason tools too.
if [ "$OS" = linux ]; then
  ENV_DIR="$HOME/.config/environment.d"
  ENV_FILE="$ENV_DIR/10-dotfiles-path.conf"
  ENV_PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$HOME/.local/share/nvim/mason/bin:$HOME/go/bin:$HOME/.dotfiles/themes:${PATH}"
  if [ "$DRY" = 1 ]; then
    plan "write $ENV_FILE with mise/mason/dotfiles PATH for GUI apps"
  else
    mkdir -p "$ENV_DIR"
    printf 'PATH=%s\n' "$ENV_PATH" > "$ENV_FILE"
    command -v systemctl >/dev/null 2>&1 && systemctl --user import-environment PATH >/dev/null 2>&1 || true
  fi
fi

# ---- 4. stow configs (directory-level backup of anything that would collide) ----
log "Linking configs with stow"

backup_target(){  # $1 = absolute target; back up only a real, not-yet-stowed file/dir
  local tgt="$1" rel="${1#"$HOME"/}" pdir
  [ -e "$tgt" ] && [ ! -L "$tgt" ] || return 0
  # skip if it already resolves into the repo (already stowed via a parent symlink)
  pdir="$(cd "$(dirname "$tgt")" 2>/dev/null && pwd -P || true)"
  case "$pdir/" in "$REPO"/*) return 0 ;; esac
  if [ "$DRY" = 1 ]; then plan "back up $tgt -> $BK/$rel"; return 0; fi
  mkdir -p "$(dirname "$BK/$rel")"; mv "$tgt" "$BK/$rel"; echo "   backed up $tgt"
}

stow_one(){  # $1 = package
  local pkg="$1" sub name
  case "$pkg" in
    tmux) backup_target "$HOME/.tmux.conf" ;;   # legacy non-XDG path shadows ~/.config/tmux
  esac
  if [ -d "$REPO/$pkg/.config" ]; then
    for sub in "$REPO/$pkg/.config"/*/; do
      name="$(basename "$sub")"
      case "$name" in systemd) continue ;; esac
      backup_target "$HOME/.config/$name"
    done
  fi
  local src rel
  while IFS= read -r src; do
    rel="${src#"$REPO/$pkg/"}"
    backup_target "$HOME/$rel"
  done < <(find "$REPO/$pkg" -type f)
  if [ "$DRY" = 1 ]; then
    if have stow; then
      local out; out="$(stow -n -v -d "$REPO" -t "$HOME" --restow "$pkg" 2>&1 || true)"
      if printf '%s' "$out" | grep -qi conflict; then echo "   would link $pkg (after backing up the items above)"
      else printf '%s\n' "$out" | grep -E 'LINK|MKDIR' | sed 's/^/   /' || echo "   would link $pkg"; fi
    else plan "stow $pkg (stow gets installed in step 1)"; fi
  else
    stow -d "$REPO" -t "$HOME" --restow "$pkg" && echo "   stowed $pkg"
  fi
}

for pkg in $PACKAGES; do
  if [ -d "$REPO/$pkg" ]; then
    # `|| echo` keeps set -e from aborting the whole install when one package
    # has a conflict; we report it and move on. stow_one ends in `stow && echo`
    # so a failed link actually propagates here instead of being masked.
    stow_one "$pkg" || echo "   ✗ $pkg failed to link (see log); continuing"
  else
    echo "   skip missing package: $pkg"
  fi
done
[ "$DRY" = 0 ] && [ -d "$BK" ] && log "Backed up pre-existing files to $BK" || true

# ---- 5. per-tool config fetch ----
if [ "$DRY" = 1 ]; then
  plan "nvim: Lazy sync;  tmux: clone TPM + install plugins;  theme: generate active palette"
else
  # `restore` pins plugins to the committed lazy-lock.json; `sync` would rewrite the
  # lock and dirty the tree (blocking auto-pull). bump via `:Lazy sync` + commit.
  if have nvim; then log "Installing Neovim plugins (to committed lockfile)"; nvim --headless "+Lazy! restore" +qa 2>/dev/null || true; fi
  if have tmux; then
    log "Installing tmux plugins (TPM)"
    # must match TMUX_PLUGIN_MANAGER_PATH in tmux/.config/tmux/tmux.conf
    TPM_DIR="$HOME/.local/share/tmux/plugins"
    TPM="$TPM_DIR/tpm"
    TPM_COMMIT="e261deb1b47614eed3400089ce7197dc68acc4eb"   # pinned; bump intentionally
    [ -d "$TPM/.git" ] || git clone -q https://github.com/tmux-plugins/tpm "$TPM"
    # pin to the reviewed commit; fail closed (only run TPM's installer if we got
    # there, else we'd run whatever HEAD is and the pin means nothing)
    if git -C "$TPM" checkout -q "$TPM_COMMIT" 2>/dev/null \
       || { git -C "$TPM" fetch -q origin "$TPM_COMMIT" 2>/dev/null && git -C "$TPM" checkout -q "$TPM_COMMIT" 2>/dev/null; }; then
      TMUX_PLUGIN_MANAGER_PATH="$TPM_DIR/" "$TPM/bin/install_plugins" >/dev/null 2>&1 || true
    else
      log "TPM not at pinned commit $TPM_COMMIT; skipping plugin install (won't run unpinned code)"
    fi
  fi
  # generate the active theme's tmux palette (nvim reads themes/ directly)
  if [ -x "$REPO/themes/theme" ]; then
    log "Generating active theme palette"
    "$REPO/themes/theme" set "$(cat "$REPO/themes/active" 2>/dev/null || echo dark)" >/dev/null 2>&1 || true
  fi
fi

# ---- 6. WSL-only setup ----
# win32yank (clipboard bridge): pinned + checksum-verified. the wsl-optimize.sh
# system tweaks change services via sudo, so they're opt-in (--wsl-tweaks), never
# silent. see wsl/wsl-optimize.sh and README "WSL" for what they change and why.
WIN32YANK_VERSION="v0.1.1"
WIN32YANK_SHA256="247c9a05b94387a884b49d3db13f806b1677dfc38020f955f719be6902260cd6"
if $IS_WSL && [ "$CONFIGS_ONLY" = 0 ]; then
  if [ "$DRY" = 1 ]; then
    plan "install win32yank $WIN32YANK_VERSION (checksum-verified)"
    [ "$WSL_TWEAKS" = 1 ] && plan "run wsl/wsl-optimize.sh (sudo system changes)" \
                          || plan "skip wsl-optimize.sh (pass --wsl-tweaks to apply)"
  else
    if [ ! -x "$HOME/.local/bin/win32yank.exe" ]; then
      log "Installing win32yank $WIN32YANK_VERSION (checksum-verified)"
      tmp="$(mktemp -d)"
      if curl -fsSL -o "$tmp/w.zip" \
           "https://github.com/equalsraf/win32yank/releases/download/$WIN32YANK_VERSION/win32yank-x64.zip" \
         && [ "$(sha256_of "$tmp/w.zip")" = "$WIN32YANK_SHA256" ]; then
        unzip -o -q "$tmp/w.zip" -d "$tmp" 2>/dev/null \
          && install -m755 "$tmp/win32yank.exe" "$HOME/.local/bin/win32yank.exe" 2>/dev/null || true
      else
        log "  win32yank download failed or checksum mismatch; skipping (clipboard bridge off)"
      fi
      rm -rf "$tmp"
    fi
    if [ "$WSL_TWEAKS" = 1 ]; then
      log "Applying WSL system tweaks (--wsl-tweaks): see wsl/wsl-optimize.sh"
      bash "$REPO/wsl/wsl-optimize.sh" --yes || true
    else
      log "WSL system tweaks skipped. To apply (changes host services via sudo):"
      log "    ./install.sh --wsl-tweaks    # review wsl/wsl-optimize.sh first"
    fi
  fi
fi

# ---- 7. machine-local override stub ----
if [ "$DRY" = 1 ]; then plan "create ~/.shell.local from shell.local.example if absent"
else [ -f "$HOME/.shell.local" ] || cp "$REPO/shell.local.example" "$HOME/.shell.local"; fi

if [ "$DRY" = 1 ]; then
  log "Dry run complete. Nothing was changed."
else
  report
  echo "  - Restart your shell (or: exec \$SHELL)."
  echo "  - Put machine-local settings in ~/.shell.local"
  $IS_WSL && echo "  - WSL: run 'wsl --shutdown' from PowerShell for wsl.conf to take effect."
  echo "  - Reverse with: ./uninstall.sh"
fi
