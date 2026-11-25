#!/usr/bin/env bash
# Run as root from install.sh. Own only dotfiles-extra-<sha256>.crt and the
# previous installer's exact extra-root-<number>.crt names. Never prune other CAs.
set -euo pipefail
roots="${1:?extra-roots directory required}"
dest="${2:-/usr/local/share/ca-certificates}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
shopt -s nullglob
mkdir -p "$stage/input" "$stage/ready"

# Stage and validate everything before touching the system store. Debian expects
# one certificate per .crt file, even when a user-supplied PEM contains a chain.
i=0
for src in "$roots"/*.pem; do
  i=$((i + 1))
  cp "$src" "$stage/input/$i.pem"
  openssl crl2pkcs7 -nocrl -certfile "$stage/input/$i.pem" -out /dev/null
  grep -q '^-----BEGIN CERTIFICATE-----' "$stage/input/$i.pem"
  awk -v prefix="$stage/input/$i-" '
    /^-----BEGIN CERTIFICATE-----/ { n++; output=prefix n ".crt" }
    output != "" { print > output }
    /^-----END CERTIFICATE-----/ { close(output); output="" }
  ' "$stage/input/$i.pem"
done
for cert in "$stage/input"/*.crt; do
  # Canonical PEM also normalizes CRLF and validates every individual certificate.
  openssl x509 -in "$cert" -out "$stage/cert.pem"
  digest="$(openssl x509 -in "$stage/cert.pem" -outform DER | openssl dgst -sha256 | awk '{print $NF}')"
  [[ "$digest" =~ ^[a-f0-9]{64}$ ]]
  cp "$stage/cert.pem" "$stage/ready/dotfiles-extra-$digest.crt"
done
mkdir -p "$dest"
for cert in "$stage/ready"/*.crt; do install -m 644 "$cert" "$dest/${cert##*/}"; done
for cert in "$dest"/*.crt; do
  name="${cert##*/}"
  if [[ "$name" =~ ^extra-root-[0-9]+\.crt$ ]] \
     || { [[ "$name" =~ ^dotfiles-extra-[a-f0-9]{64}\.crt$ ]] && [ ! -e "$stage/ready/$name" ]; }; then
    rm -f -- "$cert"
  fi
done
update-ca-certificates
