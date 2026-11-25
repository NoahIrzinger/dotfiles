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

- `mise.toml` and `mise.lock` define the toolset; re-run `./install.sh` to converge. Refresh the lock after pin changes with `mise lock --platform linux-x64,linux-arm64,macos-arm64,macos-x64`.
- drop one: comment it in `mise.toml`, re-run. skip locally: `--skip`, or `MISE_DISABLE_TOOLS=` in `~/.shell.local`.

## Updates

- interactive shells check `origin/master` in the background once a day; a one-line nudge shows if behind.
- `dotfiles-update` pulls + re-runs the installer, then clears the nudge.
- Renovate opens a PR per pinned tool in `mise.toml`; merge to bump. self-updating CLIs (claude) drift past the pin on their own.

## Configs

- each top-level dir is a stow package mirroring `$HOME` (`nvim/.config/nvim/` -> `~/.config/nvim/`).
- packages listed in `packages`.
- `.bashrc`/`.zshrc` are thin; both source `~/.config/shell/common.sh` (aliases, env, PATH, mise, zoxide).
- machine-local: `cp shell.local.example ~/.shell.local` (sourced by `common.sh`, gitignored).
- pi: `tools/install-pi.sh` installs the checksum-verified upstream package using `tools/pi/package-lock.json`. The custom packaging step removes upstream shrinkwrap so the pinned Undici and minimatch overrides take effect. Refresh with `bash tools/install-pi.sh --lock` using the pinned Node. The stock vim/subagents extensions use this locked prefix; only their stock settings entries are migrated. Other packages, providers, auth and sessions remain machine-local. Skip with `--skip pi`.

## WSL

- `win32yank` installed automatically (pinned + checksum-verified).
- `wsl/wsl-optimize.sh` is opt-in (`--wsl-tweaks`): systemd on, drop Windows PATH, automount metadata, remove snap, disable ufw/AppArmor; leaves `unattended-upgrades` on.
- `wsl --shutdown` after, for `wsl.conf` to apply.
- patch the distro yourself: `sudo apt update && sudo apt full-upgrade`.
- icons/pills need a Nerd Font ([releases](https://github.com/ryanoasis/nerd-fonts/releases), the bar targets 0xProto Nerd Font). on WSL the glyphs render with the *Windows* font: install the `.ttf` on Windows (right-click -> Install for all users), then set your terminal font face to `0xProto Nerd Font`. nothing inside WSL affects it.

## Custom CA certs

- behind an inspecting proxy: drop CA PEMs in `~/.config/certs/extra-roots/`, run `ca-rebuild`.
- builds offline from the OS public roots plus your PEMs; no Python/pip download is needed. On Ubuntu/WSL the base is `/etc/ssl/certs/ca-certificates.crt` (from `ca-certificates`); on macOS it is `/etc/ssl/cert.pem`.
- shell startup refreshes the bundle when OS roots or extra PEM contents change. Validation failure preserves the last valid file but disables generated environment overrides. Removing all extra PEMs retires the generated bundle and its overrides.
- Node receives only the extra PEMs through `NODE_EXTRA_CA_CERTS`; its built-in public trust store stays authoritative. Other clients receive the refreshed combined bundle.
- rerun `./install.sh` after removing Linux system roots: it reconciles only `dotfiles-extra-<sha256>.crt` and legacy `extra-root-<number>.crt` files, leaving other administrators' roots untouched. `ca-rebuild` refreshes the user bundle; it cannot remove sudo-owned OS roots.

## Security

- downloads pinned + checksum-verified (mise, Android platform-tools, win32yank, TPM); tool versions in `mise.toml`.
- Go clients and editor tools use mise's native Go backend with Go `1.27.4`. `tools/check-go.sh` verifies embedded runtimes and dependency security floors. Where upstream dependencies remain vulnerable, the custom `tools/patch-go.sh` rebuilds the pinned module with exact overrides from `tools/go-overrides.txt`, verified through Go's checksum database. The K9s build substitutes the [sbomify archive-reader fix](https://github.com/sbomify/ar/commit/4e0f3d6ee7e13b3a9d540f26dd28cbafd0527fbf) for the unpatched upstream reader (GO-2026-6905).
- kubectl uses the custom `tools/install-kubectl.sh` because Kubernetes requires its staging workspace. Its source commit and archive checksum are pinned there; the build refreshes vendored `x/net`, `x/text`, and OpenTelemetry to fixed versions. Source builds add compilation time. Retire these workarounds when upstream binaries and dependencies pass the same checks.
- Pi `0.99.2` uses `tools/pi/package-lock.json` with Undici `8.12.3` and minimatch `11.0.9`. `tools/install-pi.sh` verifies the upstream tarball, removes its bundled shrinkwrap and installs the locked graph without lifecycle scripts. The original shrinkwrap prevents a normal npm override from replacing vulnerable Undici. Stock extension entries migrate to the locally locked packages; other settings stay intact.
- secrets in `~/.shell.local` (gitignored).
