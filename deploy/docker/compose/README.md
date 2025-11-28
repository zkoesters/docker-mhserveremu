## Hostname resolution

For the examples below to work, the `*.localdev` names must resolve to the machine
running the containers.

Quick method (hosts file):

- Linux/macOS: edit `/etc/hosts` (requires sudo) and add:

  ```text
  127.0.0.1 mhserveremu.localdev fe.mhserveremu.localdev static.mhserveremu.localdev
  ::1       mhserveremu.localdev fe.mhserveremu.localdev static.mhserveremu.localdev
  ```

- Windows: edit `C:\Windows\System32\drivers\etc\hosts` as Administrator and add:

  ```text
  127.0.0.1 mhserveremu.localdev fe.mhserveremu.localdev static.mhserveremu.localdev
  ```

If the containers run on a different machine, replace `127.0.0.1` with that
machine's IP (e.g., `192.168.1.50`).

Optional: wildcard setup for all `*.localdev` (useful if you expect to add more
names):

- Linux (dnsmasq): install `dnsmasq` and add in a config file (e.g.,
  `/etc/dnsmasq.d/localdev.conf`):

  ```text
  address=/.localdev/127.0.0.1
  ```

  Then restart dnsmasq and point your system to use it as a resolver (often
  automatic on local systems). For IPv6 add `address=/.localdev/::1` as well.

- macOS (dnsmasq via Homebrew):
    1) `brew install dnsmasq`
    2) Add `address=/.localdev/127.0.0.1` to `/opt/homebrew/etc/dnsmasq.conf`
    3) `sudo brew services start dnsmasq`
    4) Create resolver file `/etc/resolver/localdev` with:

       ```text
       nameserver 127.0.0.1
       ```

Notes:

- After changing DNS/hosts, you may need to flush DNS.
    - macOS: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
    - Windows: `ipconfig /flushdns`
    - Most Linux distros: `systemd-resolve --flush-caches` or restart `nscd`.

---

## TLS certificates for local use

For local setups you can generate a self-signed certificate that covers
`mhserveremu.localdev` and `static.mhserveremu.localdev`.

Use the helper script:

```bash
cd deploy/common/certs
./generate_certs.sh
```

This creates `server.crt` and `server.key` in that folder. The Nginx/Apache/
Traefik examples below will mount and use these files. Your browser will warn
about the self-signed certificate — you can proceed for local testing or import
`server.crt` into your OS/browser trust store.

Notes:
- The Caddy example does not require you to generate certs. It uses Caddy's
internal CA to issue a local certificate automatically.

---

## Caddy

Provided files:

- `deploy/docker/compose/docker-compose.caddy.yaml`
- `deploy/docker/compose/caddy/Caddyfile`

Run:

```bash
docker compose \
  -f deploy/docker/compose/docker-compose.yaml \
  -f deploy/docker/compose/docker-compose.caddy.yaml up -d
```

---

## Nginx

Provided files:

- `deploy/docker/compose/docker-compose.nginx.yaml`
- `deploy/docker/compose/nginx/conf.d/mhserveremu.conf`

Run:

```bash
docker compose \
  -f deploy/docker/compose/docker-compose.yaml \
  -f deploy/docker/compose/docker-compose.nginx.yaml up -d
```

---

## Apache

Provided files:

- `deploy/docker/compose/docker-compose.apache.yaml`
- `deploy/docker/compose/apache/httpd.conf`

Run:

```bash
docker compose \
  -f deploy/docker/compose/docker-compose.yaml \
  -f deploy/docker/compose/docker-compose.apache.yaml up -d
```

---

## Traefik

Provided files:

- `deploy/docker/compose/docker-compose.traefik.yaml`
- `deploy/docker/compose/traefik/dynamic/tls.yaml`

Run:

```bash
docker compose \
  -f deploy/docker/compose/docker-compose.yaml \
  -f deploy/docker/compose/docker-compose.traefik.yaml up -d
```

---

## Notes

- In these examples, web traffic is served on 443 and proxied to `mhserveremu:8080` and game traffic 4306/tcp and
  4306/udp remains published directly from `mhserveremu`.
- Use `docker compose config` to verify that your overrides merge as expected.
- Ensure your DNS points both `mhserveremu.localdev` (HTTPS on 443) and
  `fe.mhserveremu.localdev` (game port 4306 TCP/UDP) to the host running these services.
- When publishing both TCP and UDP on the same port, make sure your firewall allows both protocols.