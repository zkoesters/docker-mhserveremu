<!-- Context: project-intelligence/technical-domain | Priority: critical | Version: 1.0 | Updated: 2026-03-31 -->

# Technical Domain

**Purpose**: Tech stack, architecture, and development patterns for docker-mhserveremu.
**Last Updated**: 2026-03-31

## Quick Reference
**Update Triggers**: Base image pin changes | New env vars | New build args | Pattern changes
**Audience**: Developers, AI agents

## Primary Stack
| Layer | Technology | Notes |
|-------|-----------|-------|
| Packaging | Docker (multi-stage) | Debian + Alpine variants kept in sync |
| Runtime | .NET 8 (`net8.0`) | Clones and builds upstream MHServerEmu during Docker image build; this repo defines the images/packaging |
| Config | Bash + INI templates | `%%UPPER_SNAKE_CASE%%` placeholders |
| Automation | GNU Make | Version/variant matrix via `define`/`foreach` |
| Base images | Pinned tags | Renovate manages updates — never use `latest` |

Supported versions inferred from `*/Config.ini.template` directories (`1.0.0`, `1.0.1`, `nightly`).
`nightly` tracks upstream `master`; all others track a branch matching the directory name.

## Code Patterns

### Adding an environment variable (data-driven, not imperative)
```bash
# 1. Add to ENV_VARS table in docker-entrypoint.sh:
#    PRIMARY_VAR|LEGACY_VAR_OR_EMPTY|default_value
FRONTEND_PORT||4306

# 2. Add validation to VALIDATIONS table:
#    VAR_NAME|TYPE  (types: port, bool, int, number, url)
FRONTEND_PORT|port

# 3. Add %%PRIMARY_VAR%% to each affected Config.ini.template

# 4. Update the env var configuration table in README.md

# 5. If legacy alias needs re-exporting, add to LEGACY_REEXPORTS:
#    ALIAS_NAME|SOURCE_VAR
MAX_BACKUP_NUMBER|DBMANAGER_MAX_BACKUP_NUMBER
```

### Shell function style
```bash
#!/usr/bin/env bash
set -Eeuo pipefail   # build scripts; entrypoint uses -Eeo

die() { log "[error] $*" >&2; exit 1; }

resolve_env_var() {
    local primary_var="$1"
    local legacy_var="$2"
    local default_value="$3"
    local resolved_value="${!primary_var:-}"
    # ... logic ...
    printf -v "$primary_var" "%s" "$resolved_value"
    # shellcheck disable=SC2163  # Intentional: exports variable named by $primary_var
    export "$primary_var"
}

trap cleanup EXIT
```

### Dockerfile pattern (multi-stage)
```dockerfile
ARG DOTNET_SDK_TAG=8.0.419-bookworm-slim   # ARG before FROM when used in FROM
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_TAG} AS sqlinterop-build
# Stage names: sqlinterop-build, build-stage, final (unnamed)

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends <pkgs> \
    && rm -rf /var/lib/apt/lists/*
# apk: always --no-cache (no separate rm needed)
```

### SHA256 verification (required for all downloaded artifacts)
```bash
curl --fail --location --proto '=https' --tlsv1.2 \
    --silent --show-error --output "$archive_path" "$url" \
    || die "Failed to download: $url"
verify_sha256 "$SQLITE_SOURCE_ARCHIVE_SHA256" "$archive_path"
```

## Naming Conventions
| Type | Convention | Example |
|------|-----------|---------|
| Env vars | `UPPER_SNAKE_CASE`, namespaced | `FRONTEND_PORT`, `DBMANAGER_MAX_BACKUP_NUMBER` |
| Config placeholders | `%%UPPER_SNAKE_CASE%%` | `%%FRONTEND_PORT%%` |
| Shell functions | `lower_snake_case` | `resolve_env_var`, `validate_work_dir` |
| Files | `kebab-case` | `docker-entrypoint.sh`, `build-sqlinterop.sh` |
| Make targets | `lower-kebab-case` | `build-1.0.0`, `test-prepare` |

## Code Standards
- All scripts pass ShellCheck without warnings; suppressions require `# shellcheck disable=SCxxxx  # reason`
- For new scripts (and when updating existing ones), prefer: entrypoints use `set -Eeo pipefail`; build scripts use `set -Eeuo pipefail`
- Use `printf` not `echo`; `local` for all function-scoped variables
- Prefer `[ ... ]` for simple POSIX-compatible tests; `[[ ... ]]` also used for Bash conditionals; required for regex (`=~`) or advanced pattern matching
- Errors to stderr: `printf '%s\n' "Error: ..." >&2`; fatal errors via `die()` helper
- Both `Dockerfile` and `Dockerfile.alpine` must be kept in sync
- `RUN` instructions use `set -eux` and chain with `&&`
- Hadolint ignores `DL3008`/`DL3018` (apt/apk pin) — see `.hadolint.yaml`; no other suppression without rationale
- Conventional Commits for commit messages (`feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`)

## Security Requirements
- SHA256 checksum every downloaded artifact before use
- Downloads use `--proto '=https' --tlsv1.2` (HTTPS only, TLS 1.2+)
- Validate `TARGETARCH` early with fast-fail (`amd64|arm64` only)
- Validate all env vars before template substitution (type-checked: port/bool/int/number/url)
- Fail fast with specific, actionable error messages — never silently swallow errors
- `strip` calls use `|| true` (best-effort, documented why)

## 📂 Codebase References
| File | Purpose |
|------|---------|
| `docker-entrypoint.sh` | ENV_VARS / VALIDATIONS / LEGACY_REEXPORTS tables; template substitution |
| `Dockerfile` | Debian multi-stage build (sqlinterop-build → build-stage → final) |
| `Dockerfile.alpine` | Alpine variant — kept in sync with `Dockerfile` |
| `scripts/build-sqlinterop.sh` | SHA256 verification, arch validation, cleanup trap patterns |
| `Makefile` | Version/variant matrix, `define`/`foreach` build targets |
| `*/Config.ini.template` | `%%PLACEHOLDER%%` format per supported version |
| `.hadolint.yaml` | Hadolint ignore rationale |
| `test/mhserveremu-config.sh` | docker-library test framework integration |

## Related Files
- `AGENTS.md` — authoritative coding standards for this repo
- `CONTRIBUTING.md` — PR and contribution guidelines
- `CHANGELOG.md` — version history
