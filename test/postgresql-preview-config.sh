#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: test/postgresql-preview-config.sh <preview-image> <stable-image>' >&2
    exit 2
fi

preview_image="$1"
stable_image="$2"
temporary_directory="$(mktemp -d)"
mounted_config_volume=""
cleanup() {
    if [ -n "$mounted_config_volume" ]; then
        docker volume rm -f "$mounted_config_volume" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$temporary_directory"
}
trap cleanup EXIT
chmod 0755 "$temporary_directory"

connection_string='Host=postgresql;Port=5432;Database=mhserveremu;Username=mhserveremu;Password=config-contract-secret'
connection_string_with_carriage_return="${connection_string}"$'\r'
connection_string_with_line_feed="${connection_string}"$'\n'
secret_file="${temporary_directory}/connection-string"
empty_file="${temporary_directory}/empty"
multiline_file="${temporary_directory}/multiline"
carriage_return_file="${temporary_directory}/carriage-return"
unreadable_file="${temporary_directory}/unreadable"
directory_file="${temporary_directory}/directory"
awk_directory="${temporary_directory}/awk"
printf '%s\n' "$connection_string" > "$secret_file"
: > "$empty_file"
printf 'Host=postgresql\nDatabase=mhserveremu\n' > "$multiline_file"
printf 'Host=postgresql\r' > "$carriage_return_file"
printf '%s\n' "$connection_string" > "$unreadable_file"
mkdir "$directory_file"
mkdir "$awk_directory"
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'printf '\''%s\n'\'' "$@" >> /tmp/awk-arguments' \
    'env >> /tmp/awk-environment' \
    'exec /usr/bin/awk "$@"' > "${awk_directory}/awk"
chmod 0444 "$secret_file" "$empty_file" "$multiline_file" "$carriage_return_file"
chmod 000 "$unreadable_file"
chmod 0755 "${awk_directory}/awk"

mounted_config_volume="mhserveremu-config-contract-$(basename "$temporary_directory")"
docker volume create "$mounted_config_volume" >/dev/null
docker run --rm --user 0 --entrypoint sh \
    --mount "type=volume,source=${mounted_config_volume},target=/mounted-config" \
    "$preview_image" -c 'printf "%s\\n" "PreserveThisOverride=true" > /mounted-config/ConfigOverride.ini && chown -R 1654:1654 /mounted-config && chmod 0755 /mounted-config && chmod 0644 /mounted-config/ConfigOverride.ini'

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
    --mount "type=bind,source=${awk_directory},target=/awk-bin,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql \
    -e PATH=/awk-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$preview_image" sh -c '
        grep -Fxq "ConnectionString=$1" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
            && ! env | grep -Fq "$1" \
            && ! grep -Fq "$1" /tmp/awk-arguments /tmp/awk-environment
    ' sh "$connection_string"

for _ in 1 2; do
    docker run --rm \
        --mount "type=volume,source=${mounted_config_volume},target=/run/mhserveremu/config" \
        "$preview_image" sh -c '
            grep -Fxq "PreserveThisOverride=true" "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini" \
                && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini")" = 600
        '
done

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
expect_failure direct-carriage-return "$connection_string" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string_with_carriage_return" "$preview_image"
expect_failure direct-line-feed "$connection_string" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string_with_line_feed" "$preview_image"
expect_failure conflicting-inputs "$connection_string" \
    --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
    -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$preview_image"
expect_failure conflicting-empty-direct "$connection_string" \
    --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
    -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    -e POSTGRESQL_CONNECTION_STRING= \
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
