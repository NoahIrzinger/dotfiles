# ~/.zshrc: zsh interactive shell. Portable bits only; shared config and
# machine-local overrides come from common.sh / ~/.shell.local.

# --- history ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# --- prompt ---
PS1='%~ %# '

# --- completion ---
autoload -Uz compinit && compinit

# --- shared cross-shell config (aliases, env, PATH, mise, zoxide) ---
[ -f "$HOME/.config/shell/common.sh" ] && source "$HOME/.config/shell/common.sh"
