#!/usr/bin/env bash
# Exercise trust-bundle rebuilding without changing HOME or the OS trust store.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
builder="$repo/shell/.config/shell/ca-bundle.sh"
mkdir -p "$td/extra roots" "$td/bin" "$td/empty"

for name in public corporate; do
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$name.test" \
    -keyout "$td/$name.key" -out "$td/$name.pem" >/dev/null 2>&1
done
# Windows-exported PEMs may use CRLF or omit the final newline.
awk '{printf "%s\r\n", $0}' "$td/corporate.pem" > "$td/extra roots/corporate.pem"
awk 'NR > 1 {printf "\n"} {printf "%s", $0}' "$td/public.pem" > "$td/base.pem"

# Any attempt to resolve Python via mise or download something is a regression.
for name in python python3 pip pip3 mise curl wget; do
  cat > "$td/bin/$name" <<'STUB'
#!/usr/bin/env bash
echo "unexpected external command: $0" >> "$CA_TEST_EXTERNAL_CALLS"
exit 99
STUB
  chmod +x "$td/bin/$name"
done
export CA_TEST_EXTERNAL_CALLS="$td/external-calls"
export PATH="$td/bin:$PATH"

bash "$builder" "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
openssl crl2pkcs7 -nocrl -certfile "$td/bundle.pem" \
  | openssl pkcs7 -print_certs -noout > "$td/subjects"
grep -q 'public.test' "$td/subjects"
grep -q 'corporate.test' "$td/subjects"
[ "$(grep -c '^-----BEGIN CERTIFICATE-----' "$td/bundle.pem")" -eq 2 ]
[ "$(grep -c '^-----BEGIN CERTIFICATE-----' "$td/bundle.extra.pem")" -eq 1 ]
! openssl crl2pkcs7 -nocrl -certfile "$td/bundle.extra.pem" | openssl pkcs7 -print_certs -noout | grep -q public.test
cp "$td/bundle.pem" "$td/previous.pem"

bash "$builder" "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
cmp "$td/previous.pem" "$td/bundle.pem"

# Exercise OS-path discovery too, without writing to the actual user bundle.
bash "$builder" "$td/extra roots" "$td/os-bundle.pem"
openssl crl2pkcs7 -nocrl -certfile "$td/os-bundle.pem" \
  | openssl pkcs7 -print_certs -noout > "$td/os-subjects"
grep -q 'corporate.test' "$td/os-subjects"
[ "$(grep -c '^-----BEGIN CERTIFICATE-----' "$td/os-bundle.pem")" -gt 1 ]

expect_failure() {
  if bash "$builder" "$@" > "$td/failure.log" 2>&1; then
    echo "FAIL: rebuild unexpectedly succeeded: $*" >&2
    exit 1
  fi
  cmp "$td/previous.pem" "$td/bundle.pem"
}
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/missing.pem"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/bundle.pem"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'invalid' '-----END CERTIFICATE-----' \
  > "$td/extra roots/broken.pem"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
rm "$td/extra roots/broken.pem"

# A read/write failure after validation must not truncate the active bundle.
printf '\n' >> "$td/base.pem" # invalidate the refresh fingerprint
cat > "$td/bin/cat" <<'STUB'
#!/usr/bin/env bash
printf 'partial write\n'
exit 99
STUB
chmod +x "$td/bin/cat"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
for leftover in "$td"/bundle.pem.tmp.*; do
  [ ! -e "$leftover" ]
done
rm "$td/bin/cat"

# Removed extras retire the generated file; a later install starts from OS roots.
bash "$builder" "$td/empty" "$td/bundle.pem" "$td/base.pem"
[ ! -e "$td/bundle.pem" ] && [ ! -e "$td/bundle.extra.pem" ] && [ ! -e "$td/bundle.pem.inputs.sha256" ]
bash "$builder" "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
cp "$td/corporate.pem" "$td/base.pem"
bash "$builder" "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
! openssl crl2pkcs7 -nocrl -certfile "$td/bundle.pem" | openssl pkcs7 -print_certs -noout | grep -q public.test

# Shell refresh clears only its own overrides and preserves the last valid file
# on malformed input. It does not need to execute the rest of common.sh.
source /dev/stdin <<< "$(sed -n '/^_ca_refresh() {/,/^}/p' "$repo/shell/.config/shell/common.sh")"
_ca_refresh "$td/bundle.pem" "$td/extra roots" "$builder" "$td/base.pem"
[ "$NODE_EXTRA_CA_CERTS" = "$td/bundle.extra.pem" ]
cp "$td/bundle.pem" "$td/valid-refresh.pem"
printf 'invalid\n' > "$td/extra roots/invalid.pem"
if _ca_refresh "$td/bundle.pem" "$td/extra roots" "$builder" "$td/base.pem" 2>/dev/null; then exit 1; fi
[ -z "${SSL_CERT_FILE:-}" ] && [ -z "${NODE_EXTRA_CA_CERTS:-}" ]
cmp "$td/valid-refresh.pem" "$td/bundle.pem"
rm "$td/extra roots/invalid.pem"
export SSL_CERT_FILE="$td/bundle.pem" CURL_CA_BUNDLE="$td/unrelated.pem"
_ca_refresh "$td/bundle.pem" "$td/empty" "$builder" "$td/base.pem"
[ -z "${SSL_CERT_FILE:-}" ] && [ "$CURL_CA_BUNDLE" = "$td/unrelated.pem" ]

# System-store reconciliation is tested against an isolated directory and a stub.
cat > "$td/bin/update-ca-certificates" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$td/bin/update-ca-certificates"
mkdir "$td/system"
cp "$td/public.pem" "$td/system/other-admin.crt"
cp "$td/corporate.pem" "$td/system/extra-root-1.crt"
bash "$repo/shell/.config/shell/ca-system-roots.sh" "$td/extra roots" "$td/system"
[ ! -e "$td/system/extra-root-1.crt" ] && [ -e "$td/system/other-admin.crt" ]
count=0; for cert in "$td/system"/dotfiles-extra-*.crt; do [ -f "$cert" ] && count=$((count+1)); done
[ "$count" = 1 ]
printf 'invalid\n' > "$td/extra roots/invalid.pem"
if bash "$repo/shell/.config/shell/ca-system-roots.sh" "$td/extra roots" "$td/system" 2>/dev/null; then exit 1; fi
[ -e "$td/system/other-admin.crt" ]
count=0; for cert in "$td/system"/dotfiles-extra-*.crt; do [ -f "$cert" ] && count=$((count+1)); done
[ "$count" = 1 ]
rm "$td/extra roots/invalid.pem"
bash "$repo/shell/.config/shell/ca-system-roots.sh" "$td/empty" "$td/system"
for cert in "$td/system"/dotfiles-extra-*.crt; do [ ! -e "$cert" ]; done
[ -e "$td/system/other-admin.crt" ]
[ ! -e "$CA_TEST_EXTERNAL_CALLS" ]
echo "PASS: refresh/removal, failure preservation, shell overrides, scoped system-root reconciliation, no network/Python"
