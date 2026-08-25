#!/usr/bin/env bash
set -Eeuo pipefail

fork_template=1.0.1-fork/Config.ini.template
integration_template=integration-master/Config.ini.template

for template in "$fork_template" "$integration_template"; do
    test -f "$template"
    grep -Fq 'DatabaseType=%%PLAYERMANAGER_DATABASE_TYPE%%' "$template"
    grep -Fq '[PostgreSQLDBManager]' "$template"
    grep -Fq 'ConnectionString=%%POSTGRESQL_CONNECTION_STRING%%' "$template"
    grep -Fq 'LeaderboardsEnabled=%%GAMEOPTIONS_LEADERBOARDS_ENABLED%%' "$template"
    grep -Fq 'DatabaseType=%%LEADERBOARDS_DATABASE_TYPE%%' "$template"
done

grep -Fq 'LoadLocaleFiles=false' "$integration_template"
test ! -e postgresql-preview/Config.ini.template

dry_run="$(make --dry-run build-1.0.1-fork)"
[ "$(grep -Fc 'MHSERVEREMU_REPOSITORY=https://github.com/zkoesters/MHServerEmu.git' <<< "$dry_run")" -eq 2 ]
[ "$(grep -Fc 'MHSERVEREMU_REF=1.0.1-fork.2' <<< "$dry_run")" -eq 2 ]
[ "$(grep -Fc 'MHSERVEREMU_VERSION=1.0.1-fork' <<< "$dry_run")" -eq 2 ]
grep -Fq 'zkoesters/mhserveremu:1.0.1-fork ' <<< "$dry_run"
grep -Fq 'zkoesters/mhserveremu:1.0.1-fork-alpine ' <<< "$dry_run"

dry_run="$(make --dry-run build-integration-master)"
[ "$(grep -Fc 'MHSERVEREMU_REPOSITORY=https://github.com/zkoesters/MHServerEmu.git' <<< "$dry_run")" -eq 2 ]
[ "$(grep -Fc 'MHSERVEREMU_REF=integration/master' <<< "$dry_run")" -eq 2 ]
[ "$(grep -Fc 'MHSERVEREMU_VERSION=integration-master' <<< "$dry_run")" -eq 2 ]
grep -Fq 'zkoesters/mhserveremu:integration-master ' <<< "$dry_run"
grep -Fq 'zkoesters/mhserveremu:integration-master-alpine ' <<< "$dry_run"

compose=deploy/docker/compose/docker-compose.postgresql.yaml
docker compose \
    -f deploy/docker/compose/docker-compose.yaml \
    -f "$compose" config --quiet

ruby -ryaml - "$compose" <<'RUBY'
compose = YAML.load_file(ARGV.fetch(0))
app = compose.dig("services", "mhserveremu")
postgres = compose.dig("services", "postgresql")

abort "Integration image is not selected" unless app["image"] == "zkoesters/mhserveremu:integration-master"
abort "PostgreSQL account/player backend is not selected" unless app.dig("environment", "PLAYERMANAGER_DATABASE_TYPE") == "PostgreSQL"
abort "Leaderboards are not enabled" unless app.dig("environment", "GAMEOPTIONS_LEADERBOARDS_ENABLED") == true
abort "PostgreSQL leaderboard backend is not selected" unless app.dig("environment", "LEADERBOARDS_DATABASE_TYPE") == "PostgreSQL"
connection_string = app.dig("environment", "POSTGRESQL_CONNECTION_STRING")
abort "Connection string is missing" unless connection_string.is_a?(String)
abort "Connection string is missing" unless connection_string.include?("Host=postgresql")
abort "Connection string must use fixed local defaults" unless connection_string == "Host=postgresql;Port=5432;Database=mhserveremu;Username=mhserveremu;Password=mhserveremu-localdev"
abort "App does not wait for database health" unless app.dig("depends_on", "postgresql", "condition") == "service_healthy"
abort "Unexpected PostgreSQL image" unless postgres["image"] == "postgres:16.14-alpine3.23"
abort "PostgreSQL database must use fixed local defaults" unless postgres.dig("environment", "POSTGRES_DB") == "mhserveremu"
abort "PostgreSQL user must use fixed local defaults" unless postgres.dig("environment", "POSTGRES_USER") == "mhserveremu"
abort "PostgreSQL password must use fixed local defaults" unless postgres.dig("environment", "POSTGRES_PASSWORD") == "mhserveremu-localdev"
abort "PostgreSQL port must remain private" unless postgres.fetch("ports", []).empty?
abort "PostgreSQL health check is missing" unless postgres.dig("healthcheck", "test")&.join(" ")&.include?("pg_isready")
abort "PostgreSQL volume is missing" unless postgres.fetch("volumes").any? { |value| value.to_s.include?("/var/lib/postgresql/data") }
RUBY

if grep -Fq 'POSTGRESQL_CONNECTION_STRING_FILE' "$compose"; then
    printf '%s\n' 'Error: PostgreSQL overlay must not imply file-backed secret support' >&2
    exit 1
fi

grep -Fxq 'POSTGRESQL_TEST_VERSIONS=integration-master' Makefile
grep -Fxq 'repository_1.0.1-fork=https://github.com/zkoesters/MHServerEmu.git' Makefile
grep -Fxq 'branch_1.0.1-fork=1.0.1-fork.2' Makefile
grep -Fxq 'repository_integration-master=https://github.com/zkoesters/MHServerEmu.git' Makefile
grep -Fxq 'branch_integration-master=integration/master' Makefile
if grep -Fq 'postgresql-preview' Makefile; then
    printf '%s\n' 'Error: Makefile must not retain PostgreSQL preview mappings' >&2
    exit 1
fi
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
  "deploy/docker/compose/README.md",
  "deploy/docker/compose/.env.example",
  "CHANGELOG.md",
  ".github/workflows/docker-image-1.0.1-fork.yml",
  ".github/workflows/docker-image-integration.yml"
]
abort "Test workflow does not run for fork and integration changes" unless (expected_paths - paths).empty?
obsolete_paths = [
  ".github/workflows/docker-image-portal.yml",
  ".github/workflows/docker-image-postgresql-preview.yml"
]
abort "Test workflow retains obsolete publication paths" unless (obsolete_paths & paths).empty?

jobs = workflow.fetch("jobs")
lint_steps = jobs.dig("lint", "steps")
lint_runs = lint_steps.filter_map { |step| step["run"] }
abort "Fork/integration static contract is not linted" unless lint_runs.include?("test/fork-integration-contract.sh")
abort "Test workflow retains the PostgreSQL preview static contract" if lint_runs.include?("test/postgresql-preview-contract.sh")

image_versions = jobs.dig("test", "strategy", "matrix", "include").map { |entry| entry["version"] }
expected_versions = ["1.0.0", "1.0.1", "nightly", "1.0.1-fork", "integration-master"]
abort "Image test matrix does not match the expected version set" unless image_versions == expected_versions
RUBY

grep -Fq 'MHSERVEREMU_VERSION=1.0.1-fork' "$workflow"
grep -Fq 'MHSERVEREMU_VERSION=integration-master' "$workflow"
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'test/fork-integration-config.sh ${{ matrix.image }}-1.0.1-fork ${{ matrix.image }}-integration-master' "$workflow"

if grep -Eq 'portal-image|postgresql-preview' "$workflow"; then
    printf '%s\n' 'Error: test workflow must not retain obsolete image contracts' >&2
    exit 1
fi

assert_manual_workflow() {
    local publication_workflow=$1

    test -f "$publication_workflow"
    ruby -ryaml - "$publication_workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
trigger = workflow.key?(true) ? workflow.fetch(true) : workflow.fetch("on")
abort "Publication workflow must only use workflow_dispatch" unless trigger.is_a?(Hash) && trigger.keys == ["workflow_dispatch"]
RUBY
    grep -Fq 'uses: ./.github/workflows/docker-build-push.yml' "$publication_workflow"
    grep -Fq 'secrets: inherit' "$publication_workflow"
}

fork_workflow=.github/workflows/docker-image-1.0.1-fork.yml
integration_workflow=.github/workflows/docker-image-integration.yml

assert_manual_workflow "$fork_workflow"
assert_manual_workflow "$integration_workflow"
test ! -e .github/workflows/docker-image-portal.yml
test ! -e .github/workflows/docker-image-postgresql-preview.yml
grep -Fxq 'name: 1.0.1 Fork Docker Images' "$fork_workflow"
grep -Fxq 'name: Integration Docker Images' "$integration_workflow"

ruby -rjson -ryaml - "$fork_workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
matrix = JSON.parse(workflow.dig("jobs", "build", "with", "matrix"))
expected = [
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "1.0.1-fork.2", "commit" => "738b0881fdfa9dc9983301f4fddd727dd34bceaa", "version_dir" => "1.0.1-fork", "tag" => "1.0.1-fork.2", "dockerfile" => "Dockerfile"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "1.0.1-fork.2", "commit" => "738b0881fdfa9dc9983301f4fddd727dd34bceaa", "version_dir" => "1.0.1-fork", "tag" => "1.0.1-fork.2-alpine", "dockerfile" => "Dockerfile.alpine"}
]

abort "1.0.1 fork image matrix does not match the expected source mappings" unless matrix == expected
RUBY

ruby -rjson -ryaml - "$integration_workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
matrix = JSON.parse(workflow.dig("jobs", "build", "with", "matrix"))
expected = [
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "integration/master", "commit" => "", "version_dir" => "integration-master", "tag" => "integration-master", "dockerfile" => "Dockerfile"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "integration/master", "commit" => "", "version_dir" => "integration-master", "tag" => "integration-master-alpine", "dockerfile" => "Dockerfile.alpine"}
]

abort "Integration image matrix does not match the expected source mappings" unless matrix == expected
RUBY

grep -Fq 'zkoesters/mhserveremu:1.0.1-fork.2' README.md
grep -Fq 'zkoesters/mhserveremu:1.0.1-fork.2-alpine' README.md
grep -Fq 'zkoesters/mhserveremu:integration-master' README.md
grep -Fq 'zkoesters/mhserveremu:integration-master-alpine' README.md
grep -Fq 'pinned to the published fork release' README.md
grep -Fq 'integration-master` is mutable' README.md
grep -Fq 'https://github.com/zkoesters/MHServerEmu.git' README.md
grep -Fq '1.0.1-fork.2' README.md
grep -Fq 'integration/master' README.md
# shellcheck disable=SC2016 # Intentional literal GitHub Markdown expression.
grep -Fq 'independent `PLAYERMANAGER_DATABASE_TYPE` and `LEADERBOARDS_DATABASE_TYPE` selectors' README.md
grep -Fq 'POSTGRESQL_CONNECTION_STRING` is suitable only for short-lived local' README.md
grep -Fq 'POSTGRESQL_CONNECTION_STRING_FILE' README.md
# shellcheck disable=SC2016 # Intentional literal GitHub Markdown expression.
grep -Fq 'Do not put credentials in the repository or an `.env` file.' README.md
ruby -e 'contents = File.read(ARGV.fetch(0)); abort "README must document the shared PostgreSQL connection string" unless contents.match?(/Either PostgreSQL\s+selection requires the shared connection string/)' README.md
grep -Fq 'database port private' README.md
grep -Fq "five known test accounts with the password \`123\`" README.md
grep -Fq 'secure or replace those accounts before any public exposure' README.md
grep -Fq 'fixed, coordinated local defaults' README.md
grep -Fq 'separate, reviewed Compose override' README.md
grep -Fq 'PostgreSQL integration' deploy/docker/compose/README.md
grep -Fq 'integration-master' deploy/docker/compose/README.md
grep -Fq 'both account/player and leaderboard persistence' deploy/docker/compose/README.md
grep -Fq 'down --volumes' deploy/docker/compose/README.md
grep -Fq 'not suitable for an external database' deploy/docker/compose/README.md
grep -Fq "five known test accounts with the password \`123\`" deploy/docker/compose/README.md
grep -Fq 'secure or replace those accounts before any public exposure' deploy/docker/compose/README.md
grep -Fq 'fixed, coordinated local defaults' deploy/docker/compose/README.md
grep -Fq 'Use a separate, reviewed' deploy/docker/compose/README.md
grep -Fq 'Compose override' deploy/docker/compose/README.md
grep -Fq 'PostgreSQL integration overlay has fixed, coordinated local defaults' deploy/docker/compose/.env.example
if grep -Fq 'POSTGRESQL_CONNECTION_STRING_FILE' deploy/docker/compose/.env.example; then
    printf '%s\n' '.env.example must not imply file-backed PostgreSQL secret support' >&2
    exit 1
fi
if grep -Eq '^# POSTGRES_(DB|USER)=' deploy/docker/compose/.env.example; then
    printf '%s\n' '.env.example must not expose independently overridable PostgreSQL defaults' >&2
    exit 1
fi
grep -Fq '1.0.1 fork release images' CHANGELOG.md
grep -Fq 'integration images' CHANGELOG.md
grep -Fq 'independent PostgreSQL account/player and leaderboard persistence' CHANGELOG.md

if grep -Eni 'password=[^[:space:]#]+' README.md deploy/docker/compose/README.md deploy/docker/compose/.env.example; then
    printf '%s\n' 'Error: PostgreSQL documentation must not include a password value' >&2
    exit 1
fi
