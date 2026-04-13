# Contributing to docker-mhserveremu

Thank you for your interest in contributing! This document covers the essentials
for building, testing, and submitting changes.

## Prerequisites

- Docker (with Buildx)
- GNU Make
- Git
- Two game data files in the repo root: `Calligraphy.sip` and `mu_cdata.sip`
  (not included in the repository; see the upstream
  [MHServerEmu](https://github.com/Crypto137/MHServerEmu) project for details)

## Building

```bash
# Build all versions (default + alpine variants)
make build

# Build a specific version
make build VERSION=1.0.0

# Build only the alpine variant
make build VERSION=1.0.0 VARIANT=alpine
```

The build uses two consolidated Dockerfiles at the repo root (`Dockerfile` for
Debian, `Dockerfile.alpine` for Alpine). Build args `MHSERVEREMU_BRANCH` and
`MHSERVEREMU_VERSION` are set automatically by the Makefile.

### SQLInterop build pipeline

`SQLite.Interop.dll` is built from pinned source during Docker builds via
`scripts/build-sqlinterop.sh` and the `sqlinterop-build` stage in each Dockerfile.

Security and reproducibility controls:

- Source archive version is pinned (`SQLITE_INTEROP_VERSION`).
- Archive integrity is pinned (`SQLITE_SOURCE_ARCHIVE_SHA256`).
- Build fails fast on checksum mismatch, missing archive, or architecture mismatch.

#### Bumping SQLInterop version

When upgrading `SQLite.Interop` source inputs:

1. Update `SQLITE_INTEROP_VERSION` in both `Dockerfile` and `Dockerfile.alpine`.
2. Update `SQLITE_SOURCE_ARCHIVE_SHA256` in both Dockerfiles.
3. Build both variants:

```bash
make build VERSION=1.0.0 VARIANT=default
make build VERSION=1.0.0 VARIANT=alpine
```

4. Run tests for both variants:

```bash
make test VERSION=1.0.0 VARIANT=default
make test VERSION=1.0.0 VARIANT=alpine
```

5. If CI cache is enabled, validate first-run populate and subsequent cache hits.
6. Update `README.md` and `CHANGELOG.md` if behavior/process changed.

#### Common SQLInterop failures

- `SHA256 mismatch for ...`
  - Check that the checksum matches the selected source archive version.
- `Failed to download source archive ...`
  - Check upstream version availability and network reachability.
- `Unexpected SQLite.Interop.dll architecture ...`
  - Ensure build platform/`TARGETARCH` is set correctly (`amd64` or `arm64`).

## Testing

```bash
# Run tests for all versions
make test

# Run tests for a specific version
make test VERSION=1.0.0
```

Tests use the [docker-library/official-images](https://github.com/docker-library/official-images)
test framework, which is automatically cloned to `~/official-images` on first run.

The test script (`test/tests/mhserveremu-basics/run.sh`) validates:

1. The container starts and the web frontend responds with HTTP 200 on `/ServerStatus`.
2. The SQLite database (`/data/Account.db`) is created and queryable.

## Adding a new environment variable

1. Add a line to the `ENV_VARS` table in `docker-entrypoint.sh`:
   ```
   NEW_VARIABLE_NAME|LEGACY_ALIAS_OR_EMPTY|default_value
   ```
2. Add the `%%NEW_VARIABLE_NAME%%` placeholder to the relevant
   `Config.ini.template` files.
3. Update the configuration table in `README.md`.
4. If the variable has a legacy alias that needs re-exporting, add a line to
   `LEGACY_REEXPORTS` in `docker-entrypoint.sh`.

## Project structure

```
.
├── Dockerfile              # Consolidated Debian Dockerfile (parameterized)
├── Dockerfile.alpine       # Consolidated Alpine Dockerfile (parameterized)
├── docker-entrypoint.sh    # Table-driven entrypoint (env resolution + Config.ini generation)
├── start-server            # Simple exec wrapper for MHServerEmu
├── Makefile                # Build and test automation
├── 1.0.0/                  # Version-specific Config.ini.template (+ legacy Dockerfiles)
├── 1.0.1/                  # Version-specific Config.ini.template
├── nightly/                # Nightly Config.ini.template (+ legacy Dockerfiles)
├── deploy/                 # Docker Compose and Kubernetes deployment examples
├── test/                   # Test configuration and scripts
└── .github/workflows/      # CI/CD pipelines
```

## Pull request guidelines

- One logical change per PR.
- Run `make test` locally before submitting (at minimum for the versions your
  change affects).
- Update documentation (`README.md`, `CHANGELOG.md`) if user-facing behavior
  changes.
- Follow the existing code style; see `.editorconfig` for formatting rules.
- Shell scripts must pass [ShellCheck](https://www.shellcheck.net/) without
  warnings.

## Commit message style

This project uses the [Conventional Commits](https://www.conventionalcommits.org/)
format:

```
type(scope): short description

Optional body with more detail.
```

Common types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`.
