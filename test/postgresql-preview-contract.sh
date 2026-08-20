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
