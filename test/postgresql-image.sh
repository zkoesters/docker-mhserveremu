#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 1 ]; then
    printf '%s\n' 'Usage: test/postgresql-image.sh <mhserveremu-image>' >&2
    exit 2
fi

MHSERVEREMU_IMAGE="$1"
POSTGRES_IMAGE="postgres:16.14-alpine3.23"
CURL_IMAGE="curlimages/curl:8.17.0"
suffix="$RANDOM-$RANDOM"
app_name="mhserveremu-postgresql-app-${suffix}"
postgres_name="mhserveremu-postgresql-db-${suffix}"
network_name="mhserveremu-postgresql-network-${suffix}"
app_volume="mhserveremu-postgresql-app-${suffix}"
postgres_volume="mhserveremu-postgresql-data-${suffix}"
temporary_directory="$(mktemp -d)"
connection_file="${temporary_directory}/connection-string"

cleanup() {
    docker rm -f "$app_name" "$postgres_name" >/dev/null 2>&1 || true
    docker volume rm -f "$app_volume" "$postgres_volume" >/dev/null 2>&1 || true
    docker network rm "$network_name" >/dev/null 2>&1 || true
    rm -rf -- "$temporary_directory"
}
trap cleanup EXIT

chmod 0755 "$temporary_directory"
printf '%s\n' 'Host=postgresql;Port=5432;Database=mhserveremu;Username=mhserveremu;Password=image-test-password' > "$connection_file"
chmod 0444 "$connection_file"
docker network create "$network_name" >/dev/null
docker volume create "$app_volume" >/dev/null
docker volume create "$postgres_volume" >/dev/null

docker run --detach \
    --network "$network_name" \
    --network-alias postgresql \
    --name "$postgres_name" \
    --env POSTGRES_DB=mhserveremu \
    --env POSTGRES_USER=mhserveremu \
    --env POSTGRES_PASSWORD=image-test-password \
    --volume "${postgres_volume}:/var/lib/postgresql/data" \
    "$POSTGRES_IMAGE" >/dev/null

for _ in $(seq 1 30); do
    if docker exec "$postgres_name" pg_isready --username mhserveremu --dbname mhserveremu >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "$postgres_name" pg_isready --username mhserveremu --dbname mhserveremu >/dev/null

docker run --detach --interactive --tty \
    --network "$network_name" \
    --name "$app_name" \
    --env FRONTEND_BIND_IP=0.0.0.0 \
    --env WEBFRONTEND_ADDRESS='*' \
    --env PLAYERMANAGER_DATABASE_TYPE=PostgreSQL \
    --env POSTGRESQL_CONNECTION_STRING_FILE=/run/secrets/postgresql \
    --mount "type=bind,source=${connection_file},target=/run/secrets/postgresql,readonly" \
    --volume "${app_volume}:/data" \
    "$MHSERVEREMU_IMAGE" >/dev/null

for _ in $(seq 1 30); do
    if docker run --rm --network "$network_name" --entrypoint curl "$CURL_IMAGE" \
        --silent --fail --output /dev/null "http://${app_name}:8080/ServerStatus"; then
        break
    fi
    sleep 2
done

status="$(docker run --rm --network "$network_name" --entrypoint curl "$CURL_IMAGE" \
    --silent --show-error --output /dev/null --write-out '%{http_code}' \
    "http://${app_name}:8080/ServerStatus")"
[ "$status" = 200 ]
[ "$(docker exec "$postgres_name" psql --username mhserveremu --dbname mhserveremu --tuples-only --no-align \
    --command 'SELECT version FROM mhserveremu_schema WHERE id = 1;')" = 7 ]
[ "$(docker exec "$postgres_name" psql --username mhserveremu --dbname mhserveremu --tuples-only --no-align \
    --command 'SELECT count(*) FROM account;')" = 5 ]
