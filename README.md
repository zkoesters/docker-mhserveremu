# zkoesters/mhserveremu

The `zkoesters/mhserveremu` image provides tags for running [MHServerEmu](https://github.com/Crypto137/MHServerEmu).

# Versions ( 2025-11-15 )

Recommended version for the new users: `zkoesters/mhserveremu:0.7.0`

### Debian based:

| DockerHub image                                                                                                   | Dockerfile                                                                                 | OS              | dotnet | MHServerEmu |
|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|-----------------|--------|-------------|
| [zkoesters/mhserveremu:0.6.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.6.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.6.0/Dockerfile)   | debian:bookworm | 8.0.22 | 0.6.0       |
| [zkoesters/mhserveremu:0.7.0](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.7.0)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.7.0/Dockerfile)   | debian:bookworm | 8.0.22 | 0.7.0       |
| [zkoesters/mhserveremu:nightly](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/nightly/Dockerfile) | debian:bookworm | 8.0.22 | master      |

### Alpine based:

| DockerHub image                                                                                                                 | Dockerfile                                                                                        | OS          | dotnet | MHServerEmu |
|---------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|-------------|--------|-------------|
| [zkoesters/mhserveremu:0.6.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.6.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.6.0/alpine/Dockerfile)   | alpine:3.22 | 8.0.22 | 0.6.0       |
| [zkoesters/mhserveremu:0.7.0-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=0.7.0-alpine)     | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/0.7.0/alpine/Dockerfile)   | alpine:3.22 | 8.0.22 | 0.7.0       |
| [zkoesters/mhserveremu:nightly-alpine](https://registry.hub.docker.com/r/zkoesters/mhserveremu/tags?page=1&name=nightly-alpine) | [Dockerfile](https://github.com/zkoesters/docker-mhserveremu/blob/main/nightly/alpine/Dockerfile) | alpine:3.22 | 8.0.22 | master      |

## Configuration

The images expose environment variables to generate `Config.ini` at container start. The set differs between releases. The table below lists all variables and the versions that support them.

| Environment Variable                             | Default                                    | 0.6.0              | 0.7.0              | Nightly            |
|--------------------------------------------------|--------------------------------------------|--------------------|--------------------|--------------------|
| `FRONTEND_BIND_IP`                               | `127.0.0.1`                                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `FRONTEND_PORT`                                  | `4306`                                     | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `FRONTEND_PUBLIC_ADDRESS`                        | `127.0.0.1`                                | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `AUTH_ADDRESS`                                   | `localhost`                                | :white_check_mark: | :white_check_mark: |                    |
| `AUTH_PORT`                                      | `8080`                                     | :white_check_mark: | :white_check_mark: |                    |
| `WEBFRONTEND_ADDRESS`                            | `localhost`                                |                    |                    | :white_check_mark: |
| `WEBFRONTEND_PORT`                               | `8080`                                     |                    |                    | :white_check_mark: |
| `WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT`           | `false`                                    |                    |                    | :white_check_mark: |
| `USE_JSON_DB_MANAGER`                            | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `PLAYERMANAGER_USE_JSON_DB_MANAGER`              | `false`                                    |                    |                    | :white_check_mark: |
| `NEWS_URL`                                       | `http://localhost/news`                    | :white_check_mark: | :white_check_mark: |                    |
| `PLAYERMANAGER_NEWS_URL`                         | `http://localhost/news`                    |                    |                    | :white_check_mark: |
| `MAX_BACKUP_NUMBER`                              | `5`                                        | :white_check_mark: | :white_check_mark: |                    |
| `BACKUP_INTERVAL_MINUTES`                        | `15`                                       | :white_check_mark: | :white_check_mark: |                    |
| `LOAD_ALL_PROTOTYPES`                            | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `USE_EQUIPMENT_SLOT_TABLE_CACHE`                 | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `GAMEDATA_LOAD_ALL_PROTOTYPES`                   | `false`                                    |                    |                    | :white_check_mark: |
| `GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE`        | `false`                                    |                    |                    | :white_check_mark: |
| `AUTO_UNLOCK_AVATARS`                            | `true`                                     | :white_check_mark: | :white_check_mark: |                    |
| `AUTO_UNLOCK_TEAMUPS`                            | `true`                                     | :white_check_mark: | :white_check_mark: |                    |
| `ALLOW_SAME_GROUP_TALENTS`                       | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `DISABLE_INSTANCED_LOOT`                         | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `DISABLE_ACCOUNT_BINDING`                        | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `DISABLE_CHARACTER_BINDING`                      | `true`                                     | :white_check_mark: | :white_check_mark: |                    |
| `USE_PRESTIGE_LOOT_TABLE`                        | `false`                                    | :white_check_mark: | :white_check_mark: |                    |
| `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS`          | `true`                                     |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS`          | `true`                                     |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS`     | `false`                                    |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT`       | `false`                                    |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING`      | `false`                                    |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING`    | `true`                                     |                    |                    | :white_check_mark: |
| `CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE`      | `false`                                    |                    |                    | :white_check_mark: |
| `GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS`          | `5000`                                     | :white_check_mark: | :white_check_mark: |                    |
| `ES_TO_GAZILLIONITE_CONVERSION_RATIO`            | `2.25`                                     | :white_check_mark: | :white_check_mark: |                    |
| `MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` | `10000`                                    |                    |                    | :white_check_mark: |
| `MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO`   | `2.25`                                     |                    |                    | :white_check_mark: |
| `MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP`    | `4`                                        |                    |                    | :white_check_mark: |
| `MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED`          | `0`                                        |                    |                    | :white_check_mark: |
| `MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED`       | `0`                                        |                    |                    | :white_check_mark: |
| `STORE_HOME_PAGE_URL`                            | `http://localhost/store`                   | :white_check_mark: | :white_check_mark: |                    |
| `STORE_HOME_BANNER_PAGE_URL`                     | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_HEROES_BANNER_PAGE_URL`                   | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_COSTUMES_BANNER_PAGE_URL`                 | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_BOOSTS_BANNER_PAGE_URL`                   | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_CHESTS_BANNER_PAGE_URL`                   | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_SPECIALS_BANNER_PAGE_URL`                 | `http://localhost/store/images/banner.png` | :white_check_mark: | :white_check_mark: |                    |
| `STORE_REAL_MONEY_URL`                           | `http://localhost/store/gs-bundles.html`   | :white_check_mark: | :white_check_mark: |                    |
| `MTXSTORE_HOME_PAGE_URL`                         | `http://localhost/store`                   |                    |                    | :white_check_mark: |
| `MTXSTORE_HOME_BANNER_PAGE_URL`                  | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_HEROES_BANNER_PAGE_URL`                | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_COSTUMES_BANNER_PAGE_URL`              | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_BOOSTS_BANNER_PAGE_URL`                | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_CHESTS_BANNER_PAGE_URL`                | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_SPECIALS_BANNER_PAGE_URL`              | `http://localhost/store/images/banner.png` |                    |                    | :white_check_mark: |
| `MTXSTORE_REAL_MONEY_URL`                        | `https://localhost/MTXStore/AddG`          |                    |                    | :white_check_mark: |
| `MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS`          | `true`                                     |                    |                    | :white_check_mark: |
| `MTXSTORE_BUNDLE_INFO_URL`                       | `http://localhost/bundles/`                |                    |                    | :white_check_mark: |
| `MTXSTORE_BUNDLE_IMAGE_URL`                      | `http://localhost/bundles/images/`         |                    |                    | :white_check_mark: |

Note: Nightly renamed many variables to reflect new config sections; use the nightly-specific names when running `:nightly` images.
