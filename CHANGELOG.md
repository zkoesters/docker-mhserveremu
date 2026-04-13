# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.1] - 2026-04-13

### Added

- MHServerEmu 1.0.1 Docker image (Debian and Alpine).
- `EnableLiveTuningEvents` and `AutoRefreshLiveTuning` config options (`[GameData]`),
  controllable via `GAMEDATA_ENABLE_LIVE_TUNING_EVENTS` and `GAMEDATA_AUTO_REFRESH_LIVE_TUNING`.
- `HEALTHCHECK` instruction in all Dockerfiles (Debian and Alpine).
- Kubernetes `readinessProbe` and `livenessProbe` for the mhserveremu container.
- Kubernetes `securityContext` (pod-level and container-level) for both mhserveremu and
  nginx containers.
- Consolidated parameterized `Dockerfile` and `Dockerfile.alpine` at repo root,
  and switched CI/Makefile to use them as the primary build path.
- Reusable GitHub Actions workflow (`.github/workflows/docker-build-push.yml`).
- Input validation for environment variables (port ranges, booleans, numbers).
- `.editorconfig` for consistent formatting across editors.
- `CONTRIBUTING.md` with build, test, and contribution instructions.
- SQLite database connectivity smoke test (previously commented out).
- In-pipeline SQLInterop source build (`scripts/build-sqlinterop.sh`) with pinned
  source version and SHA256 verification.
- Build-stage architecture verification for SQLInterop artifacts (`amd64`/`arm64`).
- Buildx GitHub Actions cache integration (`cache-from`/`cache-to`) for Docker builds.

### Changed

- `MaxLoginQueueClients` default updated to `8192` (upstream changed from `10000`).
- `docker-entrypoint.sh` rewritten as table-driven: a single `ENV_VARS` table defines
  all environment variables (primary name, legacy alias, default). Adding a new variable
  is now a one-line change.
- Template substitution uses `awk gsub()` instead of `sed` for safer escaping.
- CI workflow trigger paths expanded to include `docker-entrypoint.sh`, `start-server`,
  `Config.ini.template`, and `Makefile`.
- CI callers (`docker-image.yml`, `docker-image-nightly.yml`) simplified to thin
  wrappers around the reusable workflow.
- Disabled directory listing in nginx (`autoindex off`) and Apache (removed `Indexes`
  from `Options`).
- Standardized shebang to `#!/usr/bin/env bash` in all scripts.
- Replaced third-party prebuilt SQLInterop binary downloads with source-built
  artifacts in both `Dockerfile` and `Dockerfile.alpine`.

### Fixed

- Makefile `test-version` define used `$(version)` instead of `$1`, causing all test
  targets to test the last version in the list.
- `CertificateRequestPolicy` referenced `my-cluster-issuer` instead of
  `mhserveremu-selfsigned-cluster-issuer`.
- Stale `0.8.0` image tags in `docker-compose.yaml` and `values.yaml` updated to
  `1.0.1`.
- Legacy `AUTH_ADDRESS` env var in deployment examples replaced with
  `WEBFRONTEND_ADDRESS`.
- SQLInterop build now fails fast with explicit errors for invalid source version,
  checksum mismatch, and architecture mismatch.

### Removed

- Support for MHServerEmu 0.8.1 (Docker image, CI matrix, config template).
- `vim` from all production images (reduces attack surface and image size).
- `apt-cache showpkg` debugging line from Debian Dockerfiles.

## [1.0.0] - 2025-03-22

### Added

- MHServerEmu 1.0.0 Docker image (Debian and Alpine).
- `[Leaderboards]` configuration section in `Config.ini.template`.
- `EnableTownPlayerLimit`, `EnableCreditChestConversion`,
  `CreditChestConversionMultiplier`, `DisableMissionXPBonuses`,
  `EnableUltimatePrestige` config options.
- SBOM and provenance attestation in CI builds.
- Section-prefixed environment variable names (e.g. `MTXSTORE_HOME_PAGE_URL`).
- Legacy-to-preferred variable name mapping with backward compatibility.

### Changed

- Default `MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS` from `5000` to `10000`.
- Startup now fails fast on unresolved template placeholders in `Config.ini`.

## [0.8.1] - 2025-01-15

### Added

- MHServerEmu 0.8.1 Docker image (Debian and Alpine).
- Chat tips configuration (`EnableChatTips`, `ChatTipFileName`,
  `ChatTipIntervalMinutes`, `ChatTipShuffle`).
- Autosave interval configuration (`AutosaveIntervalMinutes`).

### Changed

- Updated .NET SDK and runtime to 8.0 series.

## [0.8.0] - 2024-11-01

### Added

- MHServerEmu 0.8.0 Docker image (Debian and Alpine).
- In-game store (MTXStore) configuration via environment variables.

### Removed

- MHServerEmu 0.6.0 images.

## [0.7.0] - 2024-09-01

### Added

- Docker Compose examples (Caddy, Nginx, Apache, Traefik reverse proxies).
- Kubernetes deployment examples (Traefik, Nginx, Contour ingress controllers).
- Helm chart values.
- Automated CI/CD with GitHub Actions.
- Self-signed TLS certificate generation script.

## [0.6.0] - 2024-07-01

### Added

- Initial Docker image for MHServerEmu (Debian).
- Alpine variant.
- Basic `docker-entrypoint.sh` with environment variable substitution.
- Nightly build tracking upstream `master` branch.
