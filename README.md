# zkoesters/mhserveremu

The `zkoesters/mhserveremu` image provides tags for running [MHServerEmu](https://github.com/Crypto137/MHServerEmu).

# Versions ( 2026-03-22 )

Recommended version for the new users: `zkoesters/mhserveremu:1.0.0`

### Debian based:

| DockerHub image                                                                                                   | Dockerfile                                                                                 | OS              | dotnet | MHServerEmu |
|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|-----------------|--------|-------------|
| [zkoesters/mhserveremu:0.8.1](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.8.1)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile)         | debian:bookworm | 8.0.25 | 0.8.1       |
| [zkoesters/mhserveremu:1.0.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=1.0.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile)         | debian:bookworm | 8.0.25 | 1.0.0       |
| [zkoesters/mhserveremu:nightly](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile)         | debian:bookworm | 8.0.25 | master      |

### Alpine based:

| DockerHub image                                                                                                                 | Dockerfile                                                                                       | OS          | dotnet | MHServerEmu |
|---------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|-------------|--------|-------------|
| [zkoesters/mhserveremu:0.8.1-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.8.1-alpine)     | [Dockerfile.alpine](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile.alpine) | alpine:3.23 | 8.0.25 | 0.8.1       |
| [zkoesters/mhserveremu:1.0.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=1.0.0-alpine)     | [Dockerfile.alpine](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile.alpine) | alpine:3.23 | 8.0.25 | 1.0.0       |
| [zkoesters/mhserveremu:nightly-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly-alpine) | [Dockerfile.alpine](https://github.com/zkoesters/docker-mhserveremu/blob/main/Dockerfile.alpine) | alpine:3.23 | 8.0.25 | master      |

## Build internals: SQLInterop

`SQLite.Interop.dll` is built from pinned `System.Data.SQLite` source during image
builds (Debian and Alpine), instead of downloading third-party prebuilt binaries.

### Why this approach

- Better supply-chain control (pinned version + checksum verification).
- Better reproducibility across architectures (`linux/amd64`, `linux/arm64`).
- Better maintainability (single in-repo build script used by both Dockerfiles).

### Where it is implemented

- `scripts/build-sqlinterop.sh`: source download, checksum verification, build,
  and architecture verification.
- `Dockerfile` / `Dockerfile.alpine`: `sqlinterop-build` stage compiles and exports
  `/out/SQLite.Interop.dll`, then `build-stage` injects it into MHServerEmu.

### Pinned inputs

- `SQLITE_INTEROP_VERSION`
- `SQLITE_SOURCE_ARCHIVE_SHA256`

These are exposed as Docker build args and are intentionally explicit for review.

### Troubleshooting quick reference

- `SHA256 mismatch for ...`: verify `SQLITE_SOURCE_ARCHIVE_SHA256` for the selected
  `SQLITE_INTEROP_VERSION`.
- `Failed to download source archive ...`: verify version exists upstream and URL is
  reachable from the builder.
- `Unexpected SQLite.Interop.dll architecture ...`: verify `TARGETARCH` is
  correctly set by the build platform (`amd64` or `arm64`).

## Configuration

The images expose environment variables to generate `Config.ini` at container start.

Supported variable set (`0.8.1`, `1.0.0`, and `nightly`):

| Environment Variable                                  | Default                                    | 0.8.1              | 1.0.0              | Nightly            |
|-------------------------------------------------------|--------------------------------------------|--------------------|--------------------|--------------------|
| `FRONTEND_BIND_IP`                                    | `127.0.0.1`                                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `FRONTEND_PORT`                                       | `4306`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `FRONTEND_PUBLIC_ADDRESS`                             | `127.0.0.1`                                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `WEBFRONTEND_ADDRESS`                                 | `localhost`                                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `WEBFRONTEND_PORT`                                    | `8080`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT`                 | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT`                | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `PLAYERMANAGER_USE_JSON_DB_MANAGER`                   | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `PLAYERMANAGER_NEWS_URL`                              | `http://localhost/news`                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `DBMANAGER_MAX_BACKUP_NUMBER`                         | `5`                                        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `DBMANAGER_BACKUP_INTERVAL_MINUTES`                   | `15`                                       | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `GAMEDATA_LOAD_ALL_PROTOTYPES`                        | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE`             | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS`               | `true`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS`               | `true`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS`          | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT`            | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING`           | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING`         | `true`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE`           | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS` | `false`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS`      | `10000`                                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO`        | `2.25`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP`         | `4`                                        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED`               | `0`                                        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED`            | `0`                                        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_HOME_PAGE_URL`                              | `http://localhost/store`                   | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_HOME_BANNER_PAGE_URL`                       | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_HEROES_BANNER_PAGE_URL`                     | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_COSTUMES_BANNER_PAGE_URL`                   | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_BOOSTS_BANNER_PAGE_URL`                     | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_CHESTS_BANNER_PAGE_URL`                     | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_SPECIALS_BANNER_PAGE_URL`                   | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_REAL_MONEY_URL`                             | `https://localhost/MTXStore/AddG`          | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS`               | `true`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_BUNDLE_INFO_URL`                            | `http://localhost/bundles/`                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `MTXSTORE_BUNDLE_IMAGE_URL`                           | `http://localhost/bundles/images/`         | :white_check_mark: | :white_check_mark: | :white_check_mark: |

Temporary compatibility aliases (accepted by `0.8.1`, `1.0.0`, and `nightly`, but use the preferred names above in new deployments):

| Legacy variable                         | Preferred variable                               |
|-----------------------------------------|--------------------------------------------------|
| `AUTH_ADDRESS`                          | `WEBFRONTEND_ADDRESS`                            |
| `AUTH_PORT`                             | `WEBFRONTEND_PORT`                               |
| `USE_JSON_DB_MANAGER`                   | `PLAYERMANAGER_USE_JSON_DB_MANAGER`              |
| `NEWS_URL`                              | `PLAYERMANAGER_NEWS_URL`                         |
| `MAX_BACKUP_NUMBER`                     | `DBMANAGER_MAX_BACKUP_NUMBER`                    |
| `BACKUP_INTERVAL_MINUTES`               | `DBMANAGER_BACKUP_INTERVAL_MINUTES`              |
| `LOAD_ALL_PROTOTYPES`                   | `GAMEDATA_LOAD_ALL_PROTOTYPES`                   |
| `USE_EQUIPMENT_SLOT_TABLE_CACHE`        | `GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE`        |
| `AUTO_UNLOCK_AVATARS`                   | `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS`          |
| `AUTO_UNLOCK_TEAMUPS`                   | `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS`          |
| `ALLOW_SAME_GROUP_TALENTS`              | `CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS`     |
| `DISABLE_INSTANCED_LOOT`                | `CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT`       |
| `DISABLE_ACCOUNT_BINDING`               | `CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING`      |
| `DISABLE_CHARACTER_BINDING`             | `CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING`    |
| `USE_PRESTIGE_LOOT_TABLE`               | `CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE`      |
| `GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` | `MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` |
| `ES_TO_GAZILLIONITE_CONVERSION_RATIO`   | `MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO`   |
| `STORE_HOME_PAGE_URL`                   | `MTXSTORE_HOME_PAGE_URL`                         |
| `STORE_HOME_BANNER_PAGE_URL`            | `MTXSTORE_HOME_BANNER_PAGE_URL`                  |
| `STORE_HEROES_BANNER_PAGE_URL`          | `MTXSTORE_HEROES_BANNER_PAGE_URL`                |
| `STORE_COSTUMES_BANNER_PAGE_URL`        | `MTXSTORE_COSTUMES_BANNER_PAGE_URL`              |
| `STORE_BOOSTS_BANNER_PAGE_URL`          | `MTXSTORE_BOOSTS_BANNER_PAGE_URL`                |
| `STORE_CHESTS_BANNER_PAGE_URL`          | `MTXSTORE_CHESTS_BANNER_PAGE_URL`                |
| `STORE_SPECIALS_BANNER_PAGE_URL`        | `MTXSTORE_SPECIALS_BANNER_PAGE_URL`              |
| `STORE_REAL_MONEY_URL`                  | `MTXSTORE_REAL_MONEY_URL`                        |

## Migration: `0.7.0` -> `1.0.0`

1. Update image tags to `zkoesters/mhserveremu:1.0.0` (or `1.0.0-alpine`).
2. Replace legacy environment variable names with section-prefixed names.
3. Start the container and confirm `Config.ini` is generated without unresolved `%%...%%` placeholders.
4. Run smoke checks: login, world entry, web frontend access, and persistence to `/data/Account.db`.

### Renamed environment variables

- Use the legacy-to-preferred mapping table above; all listed `Legacy variable` names are renamed forms.
- Legacy names are currently accepted as compatibility aliases, but new deployments should only use preferred names.

### Removed environment variables

- No legacy variables are hard-removed in the current entrypoint; legacy names are still mapped to preferred names for compatibility.
- Treat legacy names as deprecated and migrate now to avoid future breaking changes.

### Changed defaults and behavior

- `MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` default is `10000` in `1.0.0` (older `0.7.0` default was `5000`).
- Store URL default uses `MTXSTORE_REAL_MONEY_URL=https://localhost/MTXStore/AddG`.
- Startup now fails fast if unresolved template placeholders remain in generated `Config.ini`.
- `1.0.0` includes additional config options from upstream (for example `EnableTownPlayerLimit` and credit chest conversion settings) in the generated template.
