# zkoesters/mhserveremu

The `zkoesters/mhserveremu` image provides tags for running [MHServerEmu](https://github.com/Crypto137/MHServerEmu).

# Versions ( 2025-01-01 )

Recommended version for the new users: `zkoesters/mhserveremu:0.4.0`

### Debian based:

| DockerHub image                                                                                                   | Dockerfile                                                                                 | OS              | dotnet | MHServerEmu |
|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|-----------------|--------|-------------|
| [zkoesters/mhserveremu:0.4.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.4.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.4.0/Dockerfile)   | debian:bookworm | 8.0.11 | 0.4.0       |
| [zkoesters/mhserveremu:nightly](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/nightly/Dockerfile) | debian:bookworm | 8.0.11 | master      |

## Configuration

| Environment Variable           | Default   |
|--------------------------------|-----------|
| FRONTEND_BIND_IP               | 127.0.0.1 |
| FRONTEND_PORT                  | 4306      |
| FRONTEND_PUBLIC_ADDRESS        | 127.0.0.1 |
| AUTH_ADDRESS                   | localhost |
| AUTH_PORT                      | 8080      |
| USE_JSON_DB_MANAGER            | false     |
| MAX_BACKUP_NUMBER              | 5         |
| BACKUP_INTERVAL_MINUTES        | 15        |
| LOAD_ALL_PROTOTYPES            | false     |
| USE_EQUIPMENT_SLOT_TABLE_CACHE | false     |
