#!/usr/bin/env bash
set -Eeuo pipefail

template=postgresql-preview/Config.ini.template

test -f "$template"
grep -Fq 'DatabaseType=%%PLAYERMANAGER_DATABASE_TYPE%%' "$template"
grep -Fq '[PostgreSQLDBManager]' "$template"
grep -Fq 'ConnectionString=%%POSTGRESQL_CONNECTION_STRING%%' "$template"

dry_run="$(make --dry-run build-postgresql-preview)"
[ "$(grep -Fc 'MHSERVEREMU_REPOSITORY=https://github.com/zkoesters/MHServerEmu.git' <<< "$dry_run")" -eq 2 ]
[ "$(grep -Fc 'MHSERVEREMU_REF=feat/postgresql-database-support' <<< "$dry_run")" -eq 2 ]
grep -Fq 'zkoesters/mhserveremu:postgresql-preview ' <<< "$dry_run"
grep -Fq 'zkoesters/mhserveremu:postgresql-preview-alpine ' <<< "$dry_run"

compose=deploy/docker/compose/docker-compose.postgresql.yaml
docker compose \
    -f deploy/docker/compose/docker-compose.yaml \
    -f "$compose" config --quiet

ruby -ryaml - "$compose" <<'RUBY'
compose = YAML.load_file(ARGV.fetch(0))
app = compose.dig("services", "mhserveremu")
postgres = compose.dig("services", "postgresql")

abort "Preview image is not selected" unless app["image"] == "zkoesters/mhserveremu:postgresql-preview"
abort "PostgreSQL backend is not selected" unless app.dig("environment", "PLAYERMANAGER_DATABASE_TYPE") == "PostgreSQL"
abort "Connection string is missing" unless app.dig("environment", "POSTGRESQL_CONNECTION_STRING").include?("Host=postgresql")
abort "App does not wait for database health" unless app.dig("depends_on", "postgresql", "condition") == "service_healthy"
abort "Unexpected PostgreSQL image" unless postgres["image"] == "postgres:16.14-alpine3.23"
abort "PostgreSQL port must remain private" unless postgres.fetch("ports", []).empty?
abort "PostgreSQL health check is missing" unless postgres.dig("healthcheck", "test")&.join(" ")&.include?("pg_isready")
abort "PostgreSQL volume is missing" unless postgres.fetch("volumes").any? { |value| value.to_s.include?("/var/lib/postgresql/data") }
RUBY

grep -Fq 'POSTGRESQL_TEST_VERSIONS=postgresql-preview' Makefile
# shellcheck disable=SC2016 # Intentional literal Make syntax.
grep -Fq 'test/postgresql-image.sh $(REPO_NAME)/$(IMAGE_NAME):$1' Makefile
# shellcheck disable=SC2016 # Intentional literal Make syntax.
grep -Fq 'test/postgresql-image.sh $(REPO_NAME)/$(IMAGE_NAME):$1-alpine' Makefile

workflow=.github/workflows/test.yml

ruby -ryaml - "$workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
trigger = workflow.key?(true) ? workflow.fetch(true) : workflow.fetch("on")
paths = trigger.fetch("pull_request").fetch("paths")
expected_paths = [
  "deploy/docker/compose/docker-compose.postgresql.yaml",
  ".github/workflows/docker-image-postgresql-preview.yml"
]
abort "Test workflow does not run for PostgreSQL preview changes" unless (expected_paths - paths).empty?

jobs = workflow.fetch("jobs")
lint_steps = jobs.dig("lint", "steps")
abort "PostgreSQL preview static contract is not linted" unless lint_steps.any? { |step| step["run"] == "test/postgresql-preview-contract.sh" }

image_versions = jobs.dig("test", "strategy", "matrix", "include").map { |entry| entry["version"] }
abort "PostgreSQL preview image is not tested" unless image_versions.include?("postgresql-preview")
RUBY

grep -Fq 'MHSERVEREMU_VERSION=nightly' "$workflow"
grep -Fq 'MHSERVEREMU_VERSION=postgresql-preview' "$workflow"
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'test/portal-image.sh ${{ matrix.image }}' "$workflow"
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'test/postgresql-preview-config.sh ${{ matrix.image }}-postgresql-preview ${{ matrix.image }}' "$workflow"

workflow=.github/workflows/docker-image-postgresql-preview.yml

test -f "$workflow"
grep -Fq 'workflow_dispatch:' "$workflow"
if grep -Eq '^[[:space:]]*(push|pull_request|pull_request_target|schedule|workflow_call):' "$workflow"; then
    exit 1
fi
grep -Fq 'uses: ./.github/workflows/docker-build-push.yml' "$workflow"
grep -Fq 'secrets: inherit' "$workflow"

ruby -rjson -ryaml - "$workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
matrix = JSON.parse(workflow.dig("jobs", "build", "with", "matrix"))
expected = [
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "feat/postgresql-database-support", "commit" => "", "version_dir" => "postgresql-preview", "tag" => "postgresql-preview", "dockerfile" => "Dockerfile"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "feat/postgresql-database-support", "commit" => "", "version_dir" => "postgresql-preview", "tag" => "postgresql-preview-alpine", "dockerfile" => "Dockerfile.alpine"}
]

abort "PostgreSQL preview image matrix does not match the expected source mappings" unless matrix == expected
RUBY

grep -Fq 'zkoesters/mhserveremu:postgresql-preview' README.md
grep -Fq 'zkoesters/mhserveremu:postgresql-preview-alpine' README.md
grep -Fq 'manually published, mutable preview tags' README.md
grep -Fq 'https://github.com/zkoesters/MHServerEmu.git' README.md
grep -Fq 'feat/postgresql-database-support' README.md
grep -Fq 'POSTGRESQL_CONNECTION_STRING` is suitable only for short-lived local' README.md
grep -Fq 'POSTGRESQL_CONNECTION_STRING_FILE' README.md
grep -Fq 'Do not put credentials in the repository or an `.env` file.' README.md
grep -Fq 'requires a reachable PostgreSQL database before the server starts' README.md
grep -Fq 'database port private' README.md
grep -Fq 'POSTGRESQL_CONNECTION_STRING_FILE' deploy/docker/compose/README.md
grep -Fq 'down --volumes' deploy/docker/compose/README.md
grep -Fq 'not suitable for an external database' deploy/docker/compose/README.md
grep -Fq '# POSTGRESQL_CONNECTION_STRING=' deploy/docker/compose/.env.example
grep -Fq '# POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql-connection-string' deploy/docker/compose/.env.example
grep -Fq 'PostgreSQL preview images' CHANGELOG.md

if grep -Eni 'password=[^[:space:]#]+' README.md deploy/docker/compose/README.md deploy/docker/compose/.env.example; then
    printf '%s\n' 'Error: PostgreSQL documentation must not include a password value' >&2
    exit 1
fi
