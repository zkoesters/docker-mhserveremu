# PostgreSQL Preview Image Design

**Status:** Approved

## Objective

Add manually published Debian and Alpine preview images that build the PostgreSQL-capable MHServerEmu feature branch. Keep each image runtime-configurable so SQLite remains the default and operators can opt into PostgreSQL without a separate Dockerfile. Provide an optional Docker Compose PostgreSQL stack and verify the complete container-to-database path.

## Scope

This change adds:

- `zkoesters/mhserveremu:postgresql-preview` and `zkoesters/mhserveremu:postgresql-preview-alpine`.
- Runtime backend and PostgreSQL connection-string configuration for the preview images.
- Direct environment-variable and file-based secret input for the Npgsql connection string.
- An optional local-development Docker Compose PostgreSQL overlay.
- Entrypoint contract tests and an end-to-end PostgreSQL image smoke test.
- Preview image, configuration, deployment, and security documentation.

This change does not:

- Add PostgreSQL support to released `1.0.0` or `1.0.1` application sources.
- Change the existing stable or nightly image defaults or publication schedules.
- Install PostgreSQL client packages in the MHServerEmu runtime image.
- Move leaderboards or runtime files from `/data` into PostgreSQL.
- Add application-level database creation, startup retry, backup, or multi-replica support.
- Define the long-term release tag that will replace the preview after the feature reaches upstream `dev`.

## Image Architecture

Add `postgresql-preview/Config.ini.template` as a version target discovered by the existing Makefile. Both variants continue to use the repository's consolidated `Dockerfile` and `Dockerfile.alpine`; no PostgreSQL-specific Dockerfile is introduced.

The preview target builds:

- Repository: `https://github.com/zkoesters/MHServerEmu.git`
- Ref: `feat/postgresql-database-support`
- Debian tag: `postgresql-preview`
- Alpine tag: `postgresql-preview-alpine`

Makefile source resolution must support a repository and ref override for this version without changing source selection for stable or nightly targets. SQLite remains the preview image default, allowing the existing SQLite smoke test to run unchanged.

Npgsql, its managed dependencies, and PostgreSQL migrations are already included in MHServerEmu build output. The image therefore does not need `psql`, `libpq`, or another PostgreSQL client at runtime.

## Runtime Configuration

The entrypoint adds these preview-only configuration inputs:

| Variable | Default | Purpose |
|---|---|---|
| `PLAYERMANAGER_DATABASE_TYPE` | `SQLite` | Selects `SQLite`, `PostgreSQL`, or `Json`, case-insensitively. |
| `POSTGRESQL_CONNECTION_STRING` | empty | Supplies the Npgsql connection string directly. |
| `POSTGRESQL_CONNECTION_STRING_FILE` | empty | Supplies an absolute path containing the Npgsql connection string. |

The preview template renders:

```ini
[PlayerManager]
DatabaseType=%%PLAYERMANAGER_DATABASE_TYPE%%

[PostgreSQLDBManager]
ConnectionString=%%POSTGRESQL_CONNECTION_STRING%%
```

The existing `PLAYERMANAGER_USE_JSON_DB_MANAGER` compatibility switch remains available. Its application behavior is unchanged: it can select JSON when the resolved database type is SQLite, but it does not override an explicit PostgreSQL selection.

The entrypoint keeps ordinary values in its table-driven variable flow. Connection-string secret resolution uses a small table-driven secret mapping rather than placing file contents in the exported variable table. This prevents a value read from a secret file from being added to the executed process environment.

Secret resolution follows these rules:

1. Setting both connection-string variables is an error.
2. The file path must be absolute and reference a readable regular file.
3. The file must contain a nonempty, single-line connection string. A terminal line ending is removed; embedded line endings are rejected.
4. Selecting PostgreSQL without a resolved connection string is an error.
5. Selecting PostgreSQL against a template without PostgreSQL placeholders is an unsupported-version error rather than a silent fallback.
6. Validation messages never print the connection string or file contents.

The generated configuration directory remains mode `0700`. Generated `Config.ini` and `ConfigOverride.ini` files are mode `0600` because the preview's generated base configuration contains a credential. Template substitution must continue to escape literal backslashes and ampersands correctly.

## Publication

Add a dedicated, manual-only GitHub Actions caller for the two preview tags. It calls the existing reusable multi-platform publication workflow with the fork repository and feature ref. There is no `push` or `schedule` trigger.

The images remain mutable previews and publish for `linux/amd64` and `linux/arm64`, with the existing SBOM, provenance, OCI labels, and Buildx caching. Documentation identifies the source branch and warns that the tags may change whenever manually republished.

Once PostgreSQL support reaches upstream `dev`, a separate follow-up will move the template/configuration into nightly and retire or redirect the preview workflow. That transition is intentionally outside this change.

## Docker Compose Deployment

Add `deploy/docker/compose/docker-compose.postgresql.yaml` as an optional overlay on the existing base Compose file. The overlay:

- Replaces the app image with `zkoesters/mhserveremu:postgresql-preview`.
- Sets `PLAYERMANAGER_DATABASE_TYPE=PostgreSQL`.
- Supplies the app connection string through `POSTGRESQL_CONNECTION_STRING`.
- Adds a PostgreSQL service using a Renovate-managed, pinned PostgreSQL 16 Alpine tag.
- Keeps PostgreSQL port 5432 private to the Compose network.
- Persists PostgreSQL data in a dedicated named volume.
- Uses `pg_isready` for the database health check.
- Starts MHServerEmu only after PostgreSQL is healthy.
- Retains the base app's `/data` volume, published game ports, restart policy, and interactive stdin behavior.

The example uses obvious local-development defaults:

- Database: `mhserveremu`
- User: `mhserveremu`
- Password: `mhserveremu-localdev`

The values may be overridden through the existing local `.env` workflow, including a complete `POSTGRESQL_CONNECTION_STRING` when needed. The Compose guide must state that these defaults are unsuitable for remote or production deployment and that environment values are visible through container metadata.

The guide documents layered startup, status, logs, normal shutdown, and destructive `down -v` cleanup commands. It also explains that external PostgreSQL deployments need their own readiness/restart handling because MHServerEmu performs a single initialization attempt.

## Operational Constraints

The preview documentation must call out these application constraints:

- A fresh PostgreSQL schema is seeded with five known upstream test accounts. Do not expose a fresh deployment publicly without replacing or addressing those credentials.
- Only one MHServerEmu process may use a PostgreSQL database.
- PostgreSQL backups are an operator responsibility and should use external tools such as `pg_dump`.
- SQLite-to-PostgreSQL import is not provided.
- Leaderboards remain SQLite-backed, so the app's `/data` volume stays required and writable.
- The database must already exist; MHServerEmu creates and migrates its tables, not the database itself.

## Verification

### Entrypoint Contracts

Config-level tests cover:

- SQLite default behavior in the preview template.
- Explicit `PostgreSQL` and `Json` selections.
- Direct connection-string substitution.
- File-based connection-string substitution without exporting or printing file contents.
- Failure when direct and file inputs are both set.
- Failure when PostgreSQL is selected without a connection string.
- Failure for an unreadable, relative, empty, or multiline secret file.
- Failure for an invalid backend name.
- Failure when PostgreSQL is selected for an unsupported stable template.
- No unresolved placeholders in generated preview configuration.

Existing stable/nightly configuration and PortalBridge contract tests remain green.

### Image Smoke Tests

The existing official-images smoke test continues to validate that the preview image starts with SQLite by default and creates `/data/Account.db`.

A PostgreSQL-specific smoke test must:

1. Create uniquely named containers, network, data volumes, and a temporary connection-string file.
2. Start a pinned PostgreSQL 16 Alpine container with isolated test credentials.
3. Wait for PostgreSQL readiness.
4. Start the preview image with PostgreSQL selected and mount the connection string through `POSTGRESQL_CONNECTION_STRING_FILE`.
5. Wait for HTTP 200 from `/ServerStatus`.
6. Query PostgreSQL from the database container to verify schema metadata and seeded account initialization.
7. Remove all containers, network, volumes, and temporary files through an exit trap, including on failure.

Both Debian and Alpine preview variants run the PostgreSQL smoke test. PR CI adds the preview target to relevant image/config checks and includes all new workflow, template, Compose, test, and documentation paths in trigger filters.

## Documentation

Update:

- `README.md` with preview tags, source/ref status, preview-only variables, security warnings, and a link to Compose instructions.
- `deploy/docker/compose/README.md` with the PostgreSQL overlay lifecycle and external database notes.
- `deploy/docker/compose/.env.example` with commented preview/PostgreSQL overrides and local-development warnings.
- `CHANGELOG.md` under `Unreleased`.
- Repository contribution/testing guidance where needed so maintainers can build and test `VERSION=postgresql-preview`.

No real credentials, externally reachable database endpoint, or production secret example is committed.
