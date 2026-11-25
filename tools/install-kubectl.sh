#!/usr/bin/env bash
# Custom source-build workaround until vendor kubectl embeds patched Go.
# Kubernetes needs its staging modules, so plain `go install ...@version` cannot build it.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version=v1.37.3
commit=f81a9c5f95912fd97b7c8aa4966301aeae84a253
sha256=74ed8d8592cc955897d033ed15023e123038d2b2bc4e63702b248929ffacea73
dest="${1:-$HOME/.local/share/dotfiles/kubectl}"
bindir="${2:-$HOME/.local/bin}"
go_bin="${DOTFILES_GO_BIN:-$(command -v go)}"
bash "$repo/tools/check-go.sh" "$go_bin" "$go_bin" >/dev/null
compiler="$("$go_bin" env GOVERSION)"
target="$dest/$version-$compiler-net0.62.0-text0.43.0-otel1.47.0/kubectl"
if [ ! -x "$target" ] || ! bash "$repo/tools/check-go.sh" "$go_bin" "$target" >/dev/null 2>&1 \
  || [ "$("$target" version --client -o yaml | awk '$1=="gitVersion:" {print $2}')" != "$version" ]; then
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  curl -q -fLsS --proto '=https' "https://codeload.github.com/kubernetes/kubernetes/tar.gz/$commit" -o "$stage/source.tgz"
  actual="$(openssl dgst -sha256 "$stage/source.tgz" | awk '{print $NF}')"
  [ "$actual" = "$sha256" ] || { echo 'kubectl source checksum mismatch' >&2; exit 1; }
  mkdir "$stage/source"
  tar -xzf "$stage/source.tgz" -C "$stage/source" --strip-components=1
  (
    cd "$stage/source"
    # Keep upstream staging modules, with exact fixes for x/net and x/text.
    unset GOROOT
    export GOTOOLCHAIN=local GOWORK="$PWD/go.work" GOSUMDB=sum.golang.org GOPROXY=https://proxy.golang.org GOTELEMETRY=off
    export GONOSUMDB='' GONOPROXY='' GOPRIVATE='' GOINSECURE='' GOFLAGS=''
    "$go_bin" mod edit -require=golang.org/x/net@v0.62.0 -require=golang.org/x/text@v0.43.0 \
      -require=go.opentelemetry.io/otel@v1.47.0 -require=go.opentelemetry.io/otel/trace@v1.47.0
    "$go_bin" work vendor
    # The refreshed vendor tree is used without network during compilation.
    env -u GOROOT GOTOOLCHAIN=local GOWORK="$PWD/go.work" GOFLAGS= CGO_ENABLED=0 "$go_bin" build -mod=vendor -trimpath \
      -ldflags="-X k8s.io/component-base/version.gitVersion=$version -X k8s.io/component-base/version.gitCommit=$commit -X k8s.io/component-base/version.gitTreeState=clean" \
      -o "$stage/kubectl" ./cmd/kubectl
  )
  bash "$repo/tools/check-go.sh" "$go_bin" "$stage/kubectl"
  "$stage/kubectl" version --client
  [ "$("$stage/kubectl" version --client -o yaml | awk '$1=="gitVersion:" {print $2}')" = "$version" ]
  mkdir -p "$(dirname "$target")"
  install -m 755 "$stage/kubectl" "$target"
fi
bash "$repo/tools/check-go.sh" "$go_bin" "$target"
mkdir -p "$bindir"
ln -sfn "$target" "$bindir/kubectl"
