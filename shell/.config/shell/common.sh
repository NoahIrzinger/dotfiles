# ~/.config/shell/common.sh
# Shared by bash and zsh. Portable config only; machine-local values go in ~/.shell.local.

# --- detect current shell (for shell-specific tool init) ---
if [ -n "${ZSH_VERSION:-}" ]; then _sh=zsh
elif [ -n "${BASH_VERSION:-}" ]; then _sh=bash
else _sh=sh; fi

# --- aliases ---
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias k='kubectl'
command -v kubecolor >/dev/null 2>&1 && alias kubectl='kubecolor'

# --- env ---
export TZ=UTC
export EDITOR=nvim
export KUBE_EDITOR=nvim

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"                    # mise shims + user bins
export PATH="$PATH:$HOME/go/bin"                         # `go install` targets
export PATH="$PATH:$HOME/.local/share/nvim/mason/bin"    # nvim Mason tools
export PATH="$PATH:$HOME/.dotfiles/themes"               # `theme` color-theme switcher

# --- corporate CA trust ---
# behind an SSL-inspecting proxy, tools with their own trust store (node, python,
# curl) fail with UNABLE_TO_GET_ISSUER_CERT_LOCALLY. drop the proxy's root/intermediate
# PEMs in ~/.config/certs/extra-roots/, run `ca-rebuild`, and every tool below trusts
# the combined bundle. no-op off-VPN (no bundle -> nothing exported).
if [ -f "$HOME/.config/certs/cacert.pem" ]; then
  export SSL_CERT_FILE="$HOME/.config/certs/cacert.pem"
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"   # python / requests
  export PIP_CERT="$SSL_CERT_FILE"             # pip
  export CURL_CA_BUNDLE="$SSL_CERT_FILE"       # curl
  export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"  # node / npm / codex
  export GIT_SSL_CAINFO="$SSL_CERT_FILE"       # git
fi
ca-rebuild() {  # combine certifi's public roots + your drop-in certs -> cacert.pem
  local d="$HOME/.config/certs/extra-roots" out="$HOME/.config/certs/cacert.pem" base
  ls "$d"/*.pem >/dev/null 2>&1 || { echo "no certs in $d" >&2; return 1; }
  base="$(python3 -m certifi 2>/dev/null)"
  if [ -z "$base" ]; then           # certifi missing: bootstrap pip through the proxy
    cat "$d"/*.pem > "$out"
    PIP_CERT="$out" SSL_CERT_FILE="$out" python3 -m pip install --user -q certifi 2>/dev/null
    base="$(python3 -m certifi 2>/dev/null)"
  fi
  { [ -n "$base" ] && cat "$base"; cat "$d"/*.pem; } > "$out"
  echo "rebuilt $out ($(grep -c 'BEGIN CERT' "$out") certs); open a new shell to pick it up"
}

# --- vi mode on the command line (works in bash and zsh) ---
set -o vi 2>/dev/null || true

# A hung tool-init must NEVER brick the shell. `eval "$(tool init)"` blocks forever
# if the tool stalls (e.g. mise resolving a tool over a proxy that swallows the
# connection). `_init` hard-caps each at 5s when a timeout binary exists; on timeout
# we just drop into the shell without that tool instead of a blinking caret.
_init() {  # $@ = command; eval its stdout, hard-capped at 5s
  local out
  if   command -v timeout  >/dev/null 2>&1; then out="$(timeout 5 "$@" 2>/dev/null)"
  elif command -v gtimeout >/dev/null 2>&1; then out="$(gtimeout 5 "$@" 2>/dev/null)"
  elif command -v perl     >/dev/null 2>&1; then out="$(perl -e 'alarm 5; exec @ARGV' "$@" 2>/dev/null)"
  else out="$("$@" 2>/dev/null)"; fi          # no timeout tool available: best effort
  eval "$out" 2>/dev/null || true
}

# --- homebrew (macOS or Linuxbrew); before mise so mise-managed tools take precedence ---
[ -x /opt/homebrew/bin/brew ] && _init /opt/homebrew/bin/brew shellenv
[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && _init /home/linuxbrew/.linuxbrew/bin/brew shellenv

# --- mise: language/tool version manager ---
command -v mise >/dev/null 2>&1 && _init mise activate "$_sh"

# --- zoxide ---
command -v zoxide >/dev/null 2>&1 && _init zoxide init "$_sh"

# --- android ---
# adb/fastboot from Google's standalone platform-tools release (not the distro adb,
# which skews against the device's adb server). ANDROID_HOME (mise android-sdk) is
# for sdkmanager/builds.
[ -d "$HOME/.local/share/android/platform-tools" ] && export PATH="$PATH:$HOME/.local/share/android/platform-tools"
[ -z "${ANDROID_HOME:-}" ] && [ -n "${ANDROID_SDK_ROOT:-}" ] && export ANDROID_HOME="$ANDROID_SDK_ROOT"
if [ -n "${ANDROID_HOME:-}" ]; then
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  for _d in cmdline-tools/latest/bin emulator; do
    [ -d "$ANDROID_HOME/$_d" ] && export PATH="$PATH:$ANDROID_HOME/$_d"
  done
  unset _d
fi
# WSL: adb can't see USB devices directly. point it at a Windows adb server if you
# run one there (set WIN_ADB_HOST in ~/.shell.local, e.g. the host IP).
[ -n "${WIN_ADB_HOST:-}" ] && export ADB_SERVER_SOCKET="tcp:${WIN_ADB_HOST}:5037"

# --- machine-local overrides (untracked) ---
[ -f "$HOME/.shell.local" ] && . "$HOME/.shell.local"

unset _sh
