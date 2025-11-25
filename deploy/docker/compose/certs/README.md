### Self‑signed certificates for local use

This directory contains helper scripts to generate self‑signed TLS certificates
for the example reverse proxy configurations. These are intended for local/demo
use only. Do NOT use self‑signed certificates in production.

Generated files (by default):
- server.crt — PEM certificate covering:
  - static.mhserveremu.localdev
  - mhserveremu.localdev
- server.key — PEM private key for the above certificate

How to generate:
```bash
cd deploy/docker/compose/certs
./generate_certs.sh
```

Then (re)start your chosen reverse proxy compose stack. Your browser will warn
about the self‑signed certificate; you can proceed for local testing or import
`server.crt` into your system trust store if desired.

Regenerate with a different host list by editing the SANs in the script.
