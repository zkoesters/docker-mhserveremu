### Self‑signed certificates for local use

This directory provides a helper script to generate self‑signed TLS certificates
for local/demo use across both Docker and Kubernetes examples. Do NOT use
self‑signed certificates in production.

Generated files (by default):
- `server.crt` — PEM certificate covering:
  - `static.mhserveremu.localdev`
  - `mhserveremu.localdev`
- `server.key` — PEM private key for the above certificate

How to generate:
```bash
cd deploy/common/certs
./generate_certs.sh
```

Usage:
- Docker examples: the reverse proxy compose files mount this directory and use
  `server.crt`/`server.key` inside the containers.
- Kubernetes examples: create a TLS secret from these files, e.g.:
  ```bash
  kubectl -n mhserveremu create secret tls mhserveremu-tls \
    --cert=deploy/common/certs/server.crt \
    --key=deploy/common/certs/server.key
  ```

Your browser will warn about the self‑signed certificate; you can proceed for
local testing or import `server.crt` into your system trust store if desired.

To change the host list, edit the SANs in `generate_certs.sh` and re‑run it.
