#!/usr/bin/env bash
# Build offline from the OS public roots plus the user's corporate CA PEMs.
# Called by install.sh and the ca-rebuild shell function; no Python/mise/pip.
# Usage: bash ca-bundle.sh [extra-roots-dir] [output-file] [base-bundle]
set -euo pipefail

cert_dir="${1:-$HOME/.config/certs/extra-roots}"
out="${2:-$HOME/.config/certs/cacert.pem}"
base="${3:-}"
stamp="${out}.inputs.sha256"
extra="${out%.pem}.extra.pem"

shopt -s nullglob
certs=("$cert_dir"/*.pem)
if [ "${#certs[@]}" -eq 0 ]; then
  rm -f -- "$out" "$extra" "$stamp"
  echo "CA: no extra roots; retired generated bundle"
  exit 0
fi

if [ -z "$base" ]; then
  for candidate in /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem \
                   /etc/pki/tls/certs/ca-bundle.crt; do
    if [ -f "$candidate" ] && [ -r "$candidate" ] && [ -s "$candidate" ]; then
      base="$candidate"
      break
    fi
  done
fi
if [ -z "$base" ] || [ ! -f "$base" ] || [ ! -r "$base" ] || [ ! -s "$base" ]; then
  echo "CA: no readable OS CA bundle; install/repair ca-certificates first. Existing bundle unchanged." >&2
  exit 1
fi
if [ "$base" -ef "$out" ]; then
  echo "CA: the base bundle must differ from the output; existing bundle unchanged" >&2
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "CA: openssl is required to validate certificates; existing bundle unchanged" >&2
  exit 1
fi

# Refresh on content changes, including removal and an OS trust-store update.
# Do not reparse hundreds of certificates on every interactive shell startup.
fingerprint="$(
  for cert in "$base" "${certs[@]}"; do
    printf '%s\n' "$cert"
    openssl dgst -sha256 "$cert" || exit 1
  done | openssl dgst -sha256
)"
if [ -s "$out" ] && [ -s "$extra" ] && [ -f "$stamp" ] && [ "$(< "$stamp")" = "$fingerprint" ]; then
  exit 0
fi

for cert in "$base" "${certs[@]}"; do
  if [ ! -f "$cert" ] || [ ! -r "$cert" ] \
     || ! grep -q '^-----BEGIN CERTIFICATE-----' "$cert" \
     || ! openssl crl2pkcs7 -nocrl -certfile "$cert" -out /dev/null; then
    echo "CA: invalid or unreadable PEM bundle: $cert; existing bundle unchanged" >&2
    exit 1
  fi
done

echo "CA: using public roots from $base (offline)"
mkdir -p "$(dirname "$out")"
tmp="$(mktemp "${out}.tmp.XXXXXX")"
stamp_tmp="$(mktemp "${stamp}.tmp.XXXXXX")"
extra_tmp="$(mktemp "${extra}.tmp.XXXXXX")"
trap 'rm -f "$tmp" "$stamp_tmp" "$extra_tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for cert in "$base" "${certs[@]}"; do
  cat "$cert" >> "$tmp"
  printf '\n' >> "$tmp"   # PEM files need not have a final newline.
done
openssl crl2pkcs7 -nocrl -certfile "$tmp" -out /dev/null
for cert in "${certs[@]}"; do cat "$cert" >> "$extra_tmp"; printf '\n' >> "$extra_tmp"; done
openssl crl2pkcs7 -nocrl -certfile "$extra_tmp" -out /dev/null
count="$(grep -c '^-----BEGIN CERTIFICATE-----' "$tmp")"
chmod 644 "$tmp"
chmod 644 "$extra_tmp"
printf '%s\n' "$fingerprint" > "$stamp_tmp"
mv -f "$tmp" "$out"
mv -f "$extra_tmp" "$extra"
mv -f "$stamp_tmp" "$stamp"
echo "CA: rebuilt $out ($count certs)"
