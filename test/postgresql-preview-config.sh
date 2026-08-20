#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: test/postgresql-preview-config.sh <preview-image> <stable-image>' >&2
    exit 2
fi

preview_image="$1"
stable_image="$2"
temporary_directory="$(mktemp -d)"
trap 'rm -rf -- "$temporary_directory"' EXIT
chmod 0755 "$temporary_directory"

connection_string='Host=postgresql;Port=5432;Database=mhserveremu;Username=mhserveremu;Password=config-contract-secret'
secret_file="${temporary_directory}/connection-string"
empty_file="${temporary_directory}/empty"
multiline_file="${temporary_directory}/multiline"
carriage_return_file="${temporary_directory}/carriage-return"
unreadable_file="${temporary_directory}/unreadable"
directory_file="${temporary_directory}/directory"
printf '%s\n' "$connection_string" > "$secret_file"
: > "$empty_file"
printf 'Host=postgresql\nDatabase=mhserveremu\n' > "$multiline_file"
printf 'Host=postgresql\r' > "$carriage_return_file"
printf '%s\n' "$connection_string" > "$unreadable_file"
mkdir "$directory_file"
chmod 0444 "$secret_file" "$empty_file" "$multiline_file" "$carriage_return_file"
chmod 000 "$unreadable_file"

docker run --rm "$preview_image" sh -c '
    grep -Fxq "DatabaseType=SQLite" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
        && grep -Fxq "ConnectionString=" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
        && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY")" = 700 \
        && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini")" = 600 \
        && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini")" = 600 \
        && ! grep -Eq "%%[A-Z0-9_]+%%" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"
'

docker run --rm \
    -e PLAYERMANAGER_DATABASE_TYPE=jSoN \
    "$preview_image" sh -c 'grep -Fxq "DatabaseType=jSoN" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

docker run --rm \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
    "$preview_image" sh -c 'grep -Fxq "ConnectionString=$POSTGRESQL_CONNECTION_STRING" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

docker run --rm \
    --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql \
    "$preview_image" sh -c '
        grep -Fxq "ConnectionString=$1" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
            && ! env | grep -Fq "$1"
    ' sh "$connection_string"

expect_failure() {
    local label="$1"
    local forbidden="$2"
    shift 2
    local output

    if output="$(docker run --rm "$@" 2>&1)"; then
        printf 'Error: expected failure for %s\n' "$label" >&2
        exit 1
    fi
    if [ -n "$forbidden" ] && grep -Fq "$forbidden" <<< "$output"; then
        printf 'Error: %s leaked secret material\n' "$label" >&2
        exit 1
    fi
}

expect_failure missing-connection '' \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL "$preview_image"
expect_failure conflicting-inputs "$connection_string" \
    --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure relative-file '' \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=relative/path "$preview_image"
expect_failure unreadable-file '' \
    --mount "type=bind,source=${unreadable_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure directory-file '' \
    --mount "type=bind,source=${directory_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure missing-file '' \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/missing "$preview_image"
expect_failure empty-file '' \
    --mount "type=bind,source=${empty_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure multiline-file 'Database=mhserveremu' \
    --mount "type=bind,source=${multiline_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure carriage-return-file '' \
    --mount "type=bind,source=${carriage_return_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure invalid-backend '' \
    -e PLAYERMANAGER_DATABASE_TYPE=Oracle "$preview_image"
expect_failure unsupported-version "$connection_string" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string" "$stable_image"
