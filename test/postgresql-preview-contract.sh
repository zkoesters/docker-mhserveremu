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
