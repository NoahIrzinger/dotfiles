# dotfiles

Linux / WSL / macOS. Configs via [stow](https://www.gnu.org/software/stow/), tools via [mise](https://mise.jdx.dev) (`mise.toml`).

## Quick start

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/NoahIrzinger/dotfiles/master/install.sh)
# or
git clone https://github.com/NoahIrzinger/dotfiles ~/.dotfiles && ~/.dotfiles/install.sh
```

```sh
./install.sh                    # tools + link configs
./install.sh --skip gradle,java # skip tools
./install.sh --configs-only     # link configs only
./install.sh --wsl-tweaks       # opt-in WSL system tweaks (sudo)
./install.sh --dry-run          # show, change nothing
./install.sh --verbose          # set -x
./link.sh                       # re-link configs
./uninstall.sh                  # unlink, restore last backup
```

## Tools

- `mise.toml` is desired state; re-run `./install.sh` to converge (installs listed, prunes removed).
- drop one: comment it in `mise.toml`, re-run. skip locally: `--skip`, or `MISE_DISABLE_TOOLS=` in `~/.shell.local`.

## Configs

- each top-level dir is a stow package mirroring `$HOME` (`nvim/.config/nvim/` -> `~/.config/nvim/`).
- packages listed in `packages`.
- `.bashrc`/`.zshrc` are thin; both source `~/.config/shell/common.sh` (aliases, env, PATH, mise, zoxide).
- machine-local: `cp shell.local.example ~/.shell.local` (sourced by `common.sh`, gitignored).

## WSL

- `win32yank` installed automatically (pinned + checksum-verified).
- `wsl/wsl-optimize.sh` is opt-in (`--wsl-tweaks`): systemd on, drop Windows PATH, automount metadata, remove snap, disable ufw/AppArmor; leaves `unattended-upgrades` on.
- `wsl --shutdown` after, for `wsl.conf` to apply.
- patch the distro yourself: `sudo apt update && sudo apt full-upgrade`.

## Custom CA certs

- behind an inspecting proxy: drop CA PEMs in `~/.config/certs/extra-roots/`, run `ca-rebuild`.
- sets `SSL_CERT_FILE` etc. in `common.sh` + `install.sh`. no-op when empty.

## Security

- downloads pinned + checksum-verified (mise, win32yank, TPM); versions in `mise.toml`.
- secrets in `~/.shell.local` (gitignored).
