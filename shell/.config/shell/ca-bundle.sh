#!/usr/bin/env bash
# Build offline from the OS public roots plus the user's corporate CA PEMs.
# Called by install.sh and the ca-rebuild shell function; no Python/mise/pip.
# Usage: bash ca-bundle.sh [extra-roots-dir] [output-file] [base-bundle]
set -euo pipefail

cert_dir="${1:-$HOME/.config/certs/extra-roots}"
out="${2:-$HOME/.config/certs/cacert.pem}"
base="${3:-}"

shopt -s nullglob
certs=("$cert_dir"/*.pem)
if [ "${#certs[@]}" -eq 0 ]; then
  echo "CA: no PEM certificates in $cert_dir; existing bundle unchanged" >&2
  exit 1
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
trap 'rm -f "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for cert in "$base" "${certs[@]}"; do
  cat "$cert" >> "$tmp"
  printf '\n' >> "$tmp"   # PEM files need not have a final newline.
done
openssl crl2pkcs7 -nocrl -certfile "$tmp" -out /dev/null
count="$(grep -c '^-----BEGIN CERTIFICATE-----' "$tmp")"
chmod 644 "$tmp"
mv -f "$tmp" "$out"
echo "CA: rebuilt $out ($count certs)"
