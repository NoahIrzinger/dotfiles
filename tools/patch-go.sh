#!/usr/bin/env bash
# Custom dependency rebuild for pinned mise Go tools. No upstream source edits.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
go_bin="${1:?Go executable required}"
binary="${2:?Installed binary required}"
if bash "$repo/tools/check-go.sh" "$go_bin" "$binary"; then exit 0; fi
metadata="$("$go_bin" version -m "$binary")"
module="$(printf '%s\n' "$metadata" | awk '$1=="mod" {print $2}')"
version="$(printf '%s\n' "$metadata" | awk '$1=="mod" {print $3}')"
package="$(printf '%s\n' "$metadata" | awk '$1=="path" {print $2}')"
case "$module" in
  github.com/air-verse/air|golang.org/x/tools/gopls|github.com/incu6us/goimports-reviser/v3|github.com/kubecolor/kubecolor|helm.sh/helm/v4|github.com/derailed/k9s) ;;
  *) echo "No reviewed dependency rebuild for $module" >&2; exit 1 ;;
esac
[[ "$version" = v* ]] || { echo 'Reinstall the pinned mise tool before rebuilding' >&2; exit 1; }
unset GOROOT
export GOTOOLCHAIN=local GOWORK=off GOSUMDB=sum.golang.org GOPROXY=https://proxy.golang.org GOTELEMETRY=off
export GONOSUMDB='' GONOPROXY='' GOPRIVATE='' GOINSECURE='' GOFLAGS=''
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
# Go verifies module archive hashes against the public checksum database.
source_dir="$(cd "$stage" && "$go_bin" mod download -json "$module@$version" | jq -er .Dir)"
cp -R "$source_dir/." "$stage/source"
chmod -R u+w "$stage/source"
updates="$(awk -f "$repo/tools/go-updates.awk" "$repo/tools/go-overrides.txt" - <<< "$metadata")"
ldflags=""
compiler="$("$go_bin" env GOVERSION)"
case "$module" in
  helm.sh/helm/v4) ldflags="-X helm.sh/helm/v4/internal/version.version=$version" ;;
  github.com/derailed/k9s) ldflags="-X github.com/derailed/k9s/cmd.version=$version" ;;
  github.com/air-verse/air) ldflags="-X main.airVersion=$version+dotfiles -X main.goVersion=$compiler" ;;
  github.com/kubecolor/kubecolor) ldflags="-X main.Version=$version+dotfiles" ;;
  github.com/incu6us/goimports-reviser/v3) ldflags="-X main.Tag=$version+dotfiles -X main.GoVersion=$compiler" ;;
esac
(
  cd "$stage/source"
  set --
  while read -r operation value; do
    case "$operation" in
      replace) "$go_bin" mod edit "-replace=$value" ;;
      require) set -- "$@" "$value" ;;
      '') ;;
      *) exit 1 ;;
    esac
  done <<< "$updates"
  if [ "$#" -gt 0 ]; then "$go_bin" get "$@"; fi
  "$go_bin" mod verify
  GOFLAGS='' "$go_bin" build -mod=readonly -trimpath -ldflags="$ldflags" -o "$stage/tool" "./${package#"$module"}"
)
bash "$repo/tools/check-go.sh" "$go_bin" "$stage/tool"
# Replace only the exact mise-owned executable supplied by the installer.
install -m 755 "$stage/tool" "$binary.security-new"
mv -f "$binary.security-new" "$binary"
