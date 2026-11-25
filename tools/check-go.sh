#!/usr/bin/env bash
# Check embedded runtimes and audited dependency floors without executing binaries.
set -euo pipefail
go_bin="${1:?Go executable required}"; shift
rules="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failed=0
for binary in "$@"; do
  metadata="$(GOTOOLCHAIN=local "$go_bin" version -m "$binary" 2>/dev/null)" || metadata=""
  version="$(printf '%s\n' "$metadata" | awk 'NR==1 {print $NF}')"
  if [[ "$version" =~ ^go1\.([0-9]+)\.([0-9]+)$ ]]; then
    minor="${BASH_REMATCH[1]}"; patch="${BASH_REMATCH[2]}"
    if [ "$minor" -gt 27 ] || { [ "$minor" = 27 ] && [ "$patch" -ge 4 ]; } \
       || { [ "$minor" = 26 ] && [ "$patch" -ge 11 ]; }; then
      if updates="$(awk -f "$rules/go-updates.awk" "$rules/go-overrides.txt" - <<< "$metadata")" && [ -z "$updates" ]; then
        printf '%s: %s; dependency floors passed\n' "$binary" "$version"
      else
        printf '%s: dependency validation failed\n%s\n' "$binary" "$updates" >&2
        failed=1
      fi
      continue
    fi
  fi
  printf '%s: %s; requires Go 1.26.11 / 1.27.4 or newer\n' "$binary" "${version:-unreadable}" >&2
  failed=1
done
exit "$failed"
