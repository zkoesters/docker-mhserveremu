# zkoesters/mhserveremu

The `zkoesters/mhserveremu` image provides tags for running [MHServerEmu](https://github.com/Crypto137/MHServerEmu).

# Versions ( 2025-09-29 )

Recommended version for the new users: `zkoesters/mhserveremu:0.7.0`

### Debian based:

| DockerHub image                                                                                                   | Dockerfile                                                                                 | OS              | dotnet | MHServerEmu |
|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|-----------------|--------|-------------|
| [zkoesters/mhserveremu:0.4.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.4.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.4.0/Dockerfile)   | debian:bookworm | 8.0.15 | 0.4.0       |
| [zkoesters/mhserveremu:0.5.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.5.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.5.0/Dockerfile)   | debian:bookworm | 8.0.15 | 0.5.0       |
| [zkoesters/mhserveremu:0.6.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.6.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.6.0/Dockerfile)   | debian:bookworm | 8.0.15 | 0.6.0       |
| [zkoesters/mhserveremu:0.7.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.7.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.7.0/Dockerfile)   | debian:bookworm | 8.0.15 | 0.7.0       |
| [zkoesters/mhserveremu:nightly](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/nightly/Dockerfile) | debian:bookworm | 8.0.15 | master      |

### Alpine based:

| DockerHub image                                                                                                                 | Dockerfile                                                                                        | OS          | dotnet | MHServerEmu |
|---------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|-------------|--------|-------------|
| [zkoesters/mhserveremu:0.4.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.4.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.4.0/alpine/Dockerfile)   | alpine:3.20 | 8.0.15 | 0.4.0       |
| [zkoesters/mhserveremu:0.5.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.5.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.5.0/alpine/Dockerfile)   | alpine:3.20 | 8.0.15 | 0.5.0       |
| [zkoesters/mhserveremu:0.6.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.6.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.6.0/alpine/Dockerfile)   | alpine:3.20 | 8.0.15 | 0.6.0       |
| [zkoesters/mhserveremu:0.7.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.7.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.7.0/alpine/Dockerfile)   | alpine:3.20 | 8.0.15 | 0.7.0       |
| [zkoesters/mhserveremu:nightly-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly-alpine) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/nightly/alpine/Dockerfile) | alpine:3.20 | 8.0.15 | master      |

## Configuration

| Environment Variable                    | Default                                    |
|-----------------------------------------|--------------------------------------------|
| `FRONTEND_BIND_IP`                      | `127.0.0.1 `                               |
| `FRONTEND_PORT`                         | `4306`                                     |
| `FRONTEND_PUBLIC_ADDRESS`               | `127.0.0.1`                                |
| `AUTH_ADDRESS`                          | `localhost`                                |
| `AUTH_PORT`                             | `8080`                                     |
| `USE_JSON_DB_MANAGER`                   | `false`                                    |
| `NEWS_URL`                              | `http://localhost/news`                    |
| `MAX_BACKUP_NUMBER`                     | `5`                                        |
| `BACKUP_INTERVAL_MINUTES`               | `15`                                       |
| `LOAD_ALL_PROTOTYPES`                   | `false`                                    |
| `USE_EQUIPMENT_SLOT_TABLE_CACHE`        | `false`                                    |
| `AUTO_UNLOCK_AVATARS`                   | `true`                                     |
| `AUTO_UNLOCK_TEAMUPS`                   | `true`                                     |
| `ALLOW_SAME_GROUP_TALENTS`              | `false`                                    |
| `DISABLE_INSTANCED_LOOT`                | `false`                                    |
| `DISABLE_ACCOUNT_BINDING`               | `false`                                    |
| `DISABLE_CHARACTER_BINDING`             | `true`                                     |
| `USE_PRESTIGE_LOOT_TABLE`               | `false`                                    |
| `GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` | `5000`                                     |
| `ES_TO_GAZILLIONITE_CONVERSION_RATIO`   | `2.25`                                     |
| `STORE_HOME_BANNER_PAGE_URL`            | `http://localhost/store/images/banner.png` |
| `STORE_HEROES_BANNER_PAGE_URL`          | `http://localhost/store/images/banner.png` |
| `STORE_COSTUMES_BANNER_PAGE_URL`        | `http://localhost/store/images/banner.png` |
| `STORE_BOOSTS_BANNER_PAGE_URL`          | `http://localhost/store/images/banner.png` |
| `STORE_CHESTS_BANNER_PAGE_URL`          | `http://localhost/store/images/banner.png` |
| `STORE_SPECIALS_BANNER_PAGE_URL`        | `http://localhost/store/images/banner.png` |
| `STORE_REAL_MONEY_URL`                  | `http://localhost/store/gs-bundles.html`   |
