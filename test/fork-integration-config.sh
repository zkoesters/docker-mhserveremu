#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: test/fork-integration-config.sh <fork-image> <integration-image>' >&2
    exit 2
fi

temporary_directory="$(mktemp -d)"
mounted_config_volumes=()
cleanup() {
    local status=$?
    local mounted_config_volume

    for mounted_config_volume in "${mounted_config_volumes[@]}"; do
        if ! docker volume rm -f "$mounted_config_volume" >/dev/null 2>&1; then
            printf 'Warning: failed to remove Docker volume %s\n' "$mounted_config_volume" >&2
        fi
    done
    if ! rm -rf -- "$temporary_directory"; then
        printf 'Warning: failed to remove temporary directory %s\n' "$temporary_directory" >&2
    fi
    return "$status"
}
trap cleanup EXIT
chmod 0755 "$temporary_directory"

connection_string='Host=postgresql;Port=5432;Database=mhserveremu;Username=mhserveremu;Password=config-contract-secret'
connection_string_with_token="${connection_string};Application Name=%%FOO%%"
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
mkdir "$directory_file" "$awk_directory"
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'printf '\''%s\n'\'' "$@" >> /tmp/awk-arguments' \
    'env >> /tmp/awk-environment' \
    'exec /usr/bin/awk "$@"' > "${awk_directory}/awk"
chmod 0444 "$secret_file" "$empty_file" "$multiline_file" "$carriage_return_file"
chmod 000 "$unreadable_file"
chmod 0755 "${awk_directory}/awk"

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

assert_database_type() {
    local section="$1"
    local expected="$2"
    shift 2

    docker run --rm "$@" sh -c '
        awk -v section="$1" -v expected="$2" '\''
            $0 == "[" section "]" { in_section = 1; next }
            /^\[/ { in_section = 0 }
            in_section && $0 == "DatabaseType=" expected { found = 1 }
            END { exit !found }
        '\'' "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"
    ' sh "$section" "$expected"
}

test_image() {
    local image="$1"
    local image_index="$2"
    local mounted_config_volume

    mounted_config_volume="mhserveremu-config-contract-$(basename "$temporary_directory")-${image_index}"

    chmod u+w "$secret_file"
    printf '%s\n' "$connection_string" > "$secret_file"
    chmod 0444 "$secret_file"

    mounted_config_volumes+=("$mounted_config_volume")
    docker volume create "$mounted_config_volume" >/dev/null
    docker run --rm --user 0 --entrypoint sh \
        --mount "type=volume,source=${mounted_config_volume},target=/mounted-config" \
        "$image" -c 'printf "%s\\n" "PreserveThisOverride=true" > /mounted-config/ConfigOverride.ini && chown -R 1654:1654 /mounted-config && chmod 0755 /mounted-config && chmod 0644 /mounted-config/ConfigOverride.ini'

    docker run --rm "$image" sh -c '
        grep -Fxq "LeaderboardsEnabled=false" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
            && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY")" = 700 \
            && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini")" = 600 \
            && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini")" = 600 \
            && ! grep -Eq "%%[A-Z0-9_]+%%" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"
    '
    assert_database_type PlayerManager SQLite "$image"
    assert_database_type Leaderboards SQLite "$image"

    docker run --rm \
        -e PLAYERMANAGER_DATABASE_TYPE=jSoN \
        "$image" sh -c 'grep -Fxq "DatabaseType=jSoN" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

    docker run --rm \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
        "$image" sh -c 'grep -Fxq "ConnectionString=$POSTGRESQL_CONNECTION_STRING" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

    docker run --rm \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string_with_token" \
        "$image" sh -c 'grep -Fxq "ConnectionString=$POSTGRESQL_CONNECTION_STRING" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

    docker run --rm \
        --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
        --mount "type=bind,source=${awk_directory},target=/awk-bin,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql \
        -e PATH=/awk-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        "$image" sh -c '
            grep -Fxq "ConnectionString=$1" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
                && ! env | grep -Fq "$1" \
                && ! grep -Fq "$1" /tmp/awk-arguments /tmp/awk-environment
        ' sh "$connection_string"

    chmod u+w "$secret_file"
    printf '%s\n' "$connection_string_with_token" > "$secret_file"
    docker run --rm \
        --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql \
        "$image" sh -c 'grep -Fxq "ConnectionString=$1" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"' sh "$connection_string_with_token"

    for _ in 1 2; do
        docker run --rm \
            --mount "type=volume,source=${mounted_config_volume},target=/run/mhserveremu/config" \
            "$image" sh -c '
                grep -Fxq "PreserveThisOverride=true" "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini" \
                    && test "$(stat -c %a "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini")" = 600
            '
    done

    expect_failure missing-connection '' \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL "$image"
    expect_failure direct-carriage-return "$connection_string" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string_with_carriage_return" "$image"
    expect_failure direct-line-feed "$connection_string" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string_with_line_feed" "$image"
    expect_failure conflicting-inputs "$connection_string" \
        --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure conflicting-empty-direct "$connection_string" \
        --mount "type=bind,source=${secret_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING= \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure relative-file '' \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=relative/path "$image"
    expect_failure unreadable-file '' \
        --mount "type=bind,source=${unreadable_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure directory-file '' \
        --mount "type=bind,source=${directory_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure missing-file '' \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/missing "$image"
    expect_failure empty-file '' \
        --mount "type=bind,source=${empty_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure multiline-file 'Database=mhserveremu' \
        --mount "type=bind,source=${multiline_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure carriage-return-file '' \
        --mount "type=bind,source=${carriage_return_file},target=/run/secrets/postgresql,readonly" \
        -e PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql "$image"
    expect_failure invalid-backend '' \
        -e PLAYERMANAGER_DATABASE_TYPE=Oracle "$image"
    expect_failure invalid-leaderboard-backend '' \
        -e LEADERBOARDS_DATABASE_TYPE=Json "$image"
    expect_failure invalid-leaderboards-enabled '' \
        -e GAMEOPTIONS_LEADERBOARDS_ENABLED=invalid "$image"
    expect_failure missing-leaderboard-connection '' \
        -e LEADERBOARDS_DATABASE_TYPE=PostgreSQL "$image"

    docker run --rm \
        -e GAMEOPTIONS_LEADERBOARDS_ENABLED=true \
        "$image" sh -c 'grep -Fxq "LeaderboardsEnabled=true" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'

    assert_database_type Leaderboards PostgreSQL \
        -e LEADERBOARDS_DATABASE_TYPE=PostgreSQL \
        -e POSTGRESQL_CONNECTION_STRING="$connection_string" \
        "$image"
}

image_index=1
for image in "$@"; do
    test_image "$image" "$image_index"
    image_index=$((image_index + 1))
done
