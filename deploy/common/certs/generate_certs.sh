#!/usr/bin/env bash
# generate_certs.sh — Generate a self-signed TLS certificate for local development.
#
# Creates server.crt and server.key in the same directory as this script,
# with SANs for mhserveremu.localdev and static.mhserveremu.localdev.
#
# Usage:
#   ./generate_certs.sh
#
# Prerequisites:
#   - openssl
set -euo pipefail

cd "$(dirname "$0")"

CRT="server.crt"
KEY="server.key"

if ! command -v openssl >/dev/null 2>&1; then
    echo "OpenSSL not found. Please install openssl and re-run." >&2
    exit 1
fi

echo "Generating key and certificate in $(pwd) ..."

cat > san.cnf <<'EOF'
[req]
distinguished_name=req_distinguished_name
prompt = no
default_bits = 2048
default_md = sha256
req_extensions = v3_req

[req_distinguished_name]
CN = mhserveremu.localdev
O = mhserveremu local
OU = local
L = Internet
ST = NA
C = XX

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = mhserveremu.localdev
DNS.2 = static.mhserveremu.localdev
EOF

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$KEY" -out "$CRT" -config san.cnf -extensions v3_req

rm -f san.cnf

echo "Done. Created:"
ls -l "$CRT" "$KEY"

echo
echo "Import $CRT into your OS/browser trust store if you want to suppress warnings."
