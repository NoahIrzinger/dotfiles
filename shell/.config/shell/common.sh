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
export DISABLE_AUTOUPDATER=1   # claude version is pinned in mise.toml; don't let it self-update past the pin

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

# --- vi mode on the command line ---
# vi editing at the prompt, with the niceties a hand setup adds: snappy Esc, jk to
# leave insert, block/beam cursor per mode (DECSCUSR \e[1 q / \e[5 q, honored by most
# emulators), and the muscle-memory ctrl binds kept in insert mode. bash uses readline,
# zsh uses ZLE, so the two need different code.
if [ "$_sh" = zsh ]; then
  bindkey -v
  KEYTIMEOUT=1                                   # 10ms, not the 400ms default: Esc is instant
  bindkey -M viins 'jk' vi-cmd-mode
  bindkey -M viins '^r' history-incremental-search-backward
  bindkey -M viins '^a' beginning-of-line
  bindkey -M viins '^e' end-of-line
  bindkey -M viins '^w' backward-kill-word
  bindkey -M viins '^?' backward-delete-char     # backspace still works after a cmd-mode trip
  _vi_cursor() { case $KEYMAP in (vicmd) printf '\e[1 q';; (*) printf '\e[5 q';; esac; }
  zle -N zle-keymap-select _vi_cursor            # block in normal, beam in insert
  _vi_cursor_init() { zle -K viins; printf '\e[5 q'; }
  zle -N zle-line-init _vi_cursor_init           # every new prompt starts in insert + beam
elif [ "$_sh" = bash ]; then
  set -o vi
  # readline 7+: show-mode-in-prompt drives the cursor via the per-mode strings (the
  # \1..\2 are zero-width markers). these no-op on old (macOS system) bash.
  bind 'set show-mode-in-prompt on' 2>/dev/null
  bind 'set vi-ins-mode-string "\1\e[5 q\2"' 2>/dev/null
  bind 'set vi-cmd-mode-string "\1\e[1 q\2"' 2>/dev/null
  bind -m vi-insert '"jk": vi-movement-mode' 2>/dev/null
  bind -m vi-insert '"\C-r": reverse-search-history' 2>/dev/null
  bind -m vi-insert '"\C-a": beginning-of-line' 2>/dev/null
  bind -m vi-insert '"\C-e": end-of-line' 2>/dev/null
  bind -m vi-insert '"\C-w": backward-kill-word' 2>/dev/null
else
  set -o vi 2>/dev/null || true
fi

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

_to() {  # _to SECS cmd...: run cmd under a hard timeout when one is available
  local s="$1"; shift
  if   command -v timeout  >/dev/null 2>&1; then timeout  "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  else "$@"; fi
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

# --- dotfiles update nudge ---
# Once a day on an interactive shell, fetch origin/master in the background and
# stash how many commits we're behind. The CURRENT shell never waits on the
# network: it only prints the PREVIOUS check's result, so a stalled fetch can't
# touch the prompt. Renovate's merged version bumps land as commits, so this one
# signal covers both config changes and tool updates. `dotfiles-update` applies.
_DOTS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

_dots_bg_check() {  # background: fetch + record commits behind (best effort)
  local dir="$HOME/.dotfiles"
  [ -d "$dir/.git" ] || return
  _to 20 git -C "$dir" fetch -q origin master 2>/dev/null || return
  git -C "$dir" rev-list --count HEAD..origin/master 2>/dev/null > "$_DOTS_STATE/update-status"
}

dotfiles-update() {  # pull + re-run the installer, then clear the nudge
  bash "$HOME/.dotfiles/install.sh" "$@" || return
  printf '0\n' > "$_DOTS_STATE/update-status" 2>/dev/null
  : > "$_DOTS_STATE/update-check" 2>/dev/null
}

case "$-" in *i*)  # interactive only: skip in scripts/CI
  if command -v git >/dev/null 2>&1; then
    mkdir -p "$_DOTS_STATE" 2>/dev/null
    # due if never checked or last check is over a day old
    if [ ! -e "$_DOTS_STATE/update-check" ] || find "$_DOTS_STATE/update-check" -mtime +0 2>/dev/null | grep -q .; then
      : > "$_DOTS_STATE/update-check"            # gate now, before fetch, so a failed fetch won't refire all day
      ( _dots_bg_check & ) >/dev/null 2>&1        # ( cmd & ) detaches with no job-control output
    fi
    _dots_n="$(cat "$_DOTS_STATE/update-status" 2>/dev/null)"
    case "$_dots_n" in ''|0|*[!0-9]*) ;; *)
      printf '\033[2mdotfiles: %s commit(s) behind \302\267 run \033[0m\033[1mdotfiles-update\033[0m\n' "$_dots_n" ;;
    esac
    unset _dots_n
  fi
;; esac

# --- machine-local overrides (untracked) ---
[ -f "$HOME/.shell.local" ] && . "$HOME/.shell.local"

unset _sh
