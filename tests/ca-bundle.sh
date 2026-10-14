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
expect_failure "$td/empty" "$td/bundle.pem" "$td/base.pem"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/missing.pem"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/bundle.pem"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'invalid' '-----END CERTIFICATE-----' \
  > "$td/extra roots/broken.pem"
expect_failure "$td/extra roots" "$td/bundle.pem" "$td/base.pem"
rm "$td/extra roots/broken.pem"

# A read/write failure after validation must not truncate the active bundle.
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
[ ! -e "$CA_TEST_EXTERNAL_CALLS" ]
echo "PASS: public + corporate roots, OS discovery, CRLF/missing newline, repeat rebuild, failure preservation, no network/Python"
