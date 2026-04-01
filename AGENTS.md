# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

Docker image packaging for [MHServerEmu](https://github.com/Crypto137/MHServerEmu), a
Marvel Heroes private server emulator. The repo contains two consolidated, parameterized
Dockerfiles (Debian and Alpine), a table-driven entrypoint script, version-specific
`Config.ini.template` files, and Makefile-based build/test automation.

Primary languages: Bash, Dockerfile, YAML, INI templates.

## Build commands

```bash
# Build all versions (default + alpine variants)
make build

# Build a specific version
make build VERSION=1.0.0

# Build only the alpine variant of a version
make build VERSION=1.0.0 VARIANT=alpine

# Build then test (full pipeline)
make all
```

Supported versions are inferred from directories containing a `Config.ini.template`
(currently `0.8.1`, `1.0.0`, `nightly`). The `nightly` version tracks the `dev`
branch upstream; all others track a branch matching the directory name.

## Test commands

```bash
# Run tests for all versions
make test

# Run tests for a single version (fastest single-target test)
make test VERSION=1.0.0

# Run tests for a single version + variant
make test VERSION=1.0.0 VARIANT=alpine
```

Tests use the [docker-library/official-images](https://github.com/docker-library/official-images)
framework, auto-cloned to `~/official-images` on first run. The test config lives in
`test/mhserveremu-config.sh`. Tests require `Calligraphy.sip` and `mu_cdata.sip` in the
repo root (private game data files, not committed).

## Lint commands

ShellCheck and Hadolint run in CI (`test.yml`). To run locally:

```bash
# Lint shell scripts
shellcheck docker-entrypoint.sh start-server scripts/build-sqlinterop.sh

# Lint Dockerfiles
hadolint Dockerfile
hadolint Dockerfile.alpine

# Check EditorConfig compliance
editorconfig-checker
```

Hadolint ignores `DL3008` (apt pin) and `DL3018` (apk pin) — see `.hadolint.yaml` for
rationale. Do not suppress other rules without a documented reason.

## Code style

### Formatting (enforced by `.editorconfig`)

- Indent: 4 spaces everywhere except `Makefile` (tabs), YAML/JSON (2 spaces).
- Line endings: LF.
- Charset: UTF-8.
- Trailing whitespace trimmed; final newline required.
- Markdown: trailing whitespace allowed (for line breaks).

### Shell scripts

- Shebang: `#!/usr/bin/env bash`.
- New scripts should open with `set -Eeo pipefail` (entrypoint) or `set -Eeuo pipefail`
  (build scripts). Prefer this pattern when updating existing scripts. Use `-E` so ERR
  traps fire in subshells and functions.
- All scripts must pass ShellCheck without warnings.
- Use `local` for all function-scoped variables.
- Use `printf` instead of `echo` for portable output.
- Prefer `[ ... ]` for simple POSIX-compatible tests; `[[ ... ]]` is also used in this
  repo for Bash conditionals and is required for regex (`=~`) or advanced pattern matching.
- Error messages go to stderr: `printf '%s\n' "Error: ..." >&2`.
- Fatal errors via a `die()` helper that writes to stderr and exits 1.
- Use `trap cleanup EXIT` for resource cleanup; never rely on the happy path.

### Data-driven patterns

`docker-entrypoint.sh` uses pipe-delimited heredoc tables instead of long if/case
chains. Follow the same pattern when adding new environment variables or validations —
add a single line to the relevant table (`ENV_VARS`, `VALIDATIONS`, `LEGACY_REEXPORTS`),
not new imperative code.

### Dockerfiles

- Use multi-stage builds. Stage names: `sqlinterop-build`, `build-stage`, final (unnamed).
- `RUN` instructions use `set -eux` and chain commands with `&&`.
- `apt-get install` always includes `--no-install-recommends`; follow with
  `rm -rf /var/lib/apt/lists/*` in the same layer.
- `apk add` always includes `--no-cache`.
- Validate `TARGETARCH` early; fail fast with a descriptive message for unsupported values.
- Pin base image tags (e.g. `8.0.419-bookworm-slim`) — do not use `latest` or
  unversioned tags. Renovate manages these updates.
- `ARG` before `FROM` when the arg is used in the `FROM` line.

### Config templates

- Placeholders use `%%UPPER_SNAKE_CASE%%` format matching the primary env var name.
- Legacy placeholder names (deprecated aliases) are substituted in addition to primary
  names for backward compatibility.

### Naming conventions

- Environment variables: `UPPER_SNAKE_CASE`, namespaced by component
  (e.g. `FRONTEND_PORT`, `WEBFRONTEND_ADDRESS`, `CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS`).
- Shell functions: `lower_snake_case`.
- Make targets: `lower-kebab-case` (e.g. `build-1.0.0`, `test-prepare`).

### Comments

- Comment the *why*, not the *what*. Reserve inline comments for non-obvious logic,
  I/O choices, and intentional ShellCheck suppressions.
- ShellCheck suppressions require a `# shellcheck disable=SCxxxx  # reason` comment on
  the same or preceding line.
- Section headers in long scripts use `# ── Description ───` style (em-dash rulers).

### Error handling

- Validate inputs early; fail with a specific, actionable message.
- Never silently swallow errors. If a non-fatal failure is acceptable, document why
  (e.g. `strip "$dll_path" >/dev/null 2>&1 || true` — strip is best-effort).
- SHA256 checksums must be verified for any downloaded artifact before use.

## Adding a new environment variable

1. Add a `PRIMARY_VAR|LEGACY_VAR_OR_EMPTY|default_value` line to `ENV_VARS` in
   `docker-entrypoint.sh`.
2. Add a `VAR_NAME|type` line to `VALIDATIONS` (types: `port`, `bool`, `int`, `number`,
   `url`).
3. Add `%%PRIMARY_VAR%%` to each affected `Config.ini.template`.
4. Update the configuration table in `README.md`.
5. If a legacy alias needs re-exporting, add it to `LEGACY_REEXPORTS`.

## Commit message style

Uses [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`.
Keep the subject line under 72 characters, imperative mood, no trailing period.

## Pull request guidelines

- One logical change per PR.
- Run `make test VERSION=<affected-version>` before submitting.
- Update `README.md` and `CHANGELOG.md` for user-facing behavior changes.
- Both Dockerfiles (`Dockerfile` and `Dockerfile.alpine`) must be kept in sync for any
  change that affects the build pipeline (base image pins, build args, `RUN` layers).
