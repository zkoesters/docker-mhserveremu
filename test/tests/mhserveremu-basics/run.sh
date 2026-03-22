#!/usr/bin/env bash
# run.sh — Basic smoke tests for the mhserveremu Docker image.
#
# Validates that the container starts, the web frontend responds on /ServerStatus,
# and the SQLite database is created and accessible.
#
# Usage (called by the docker-library/official-images test framework):
#   ./run.sh <image>
set -e

image="$1"

# Test helper images — update these when newer versions are available.
# Managed automatically by Renovate via regex manager (see renovate.json).
CURL_IMAGE="curlimages/curl:8.17.0"
SQLITE3_IMAGE="keinos/sqlite3:3.51.0"
# Match the app container UID so sqlite can open /data/Account.db when mounted
# from the named volume (DB file is owned by UID 1654 in the image).
SQLITE3_USER="1654:1654"

export FRONTEND_BIND_IP='0.0.0.0'
export AUTH_ADDRESS='*'
export WEBFRONTEND_ADDRESS='*'

cname="mhserveremu-container-$RANDOM-$RANDOM"
nname="mhserveremu-network-$RANDOM-$RANDOM"
vname="mhserveremu-data-$RANDOM-$RANDOM"
docker volume create "$vname"
nid="$(docker network create "$nname")"
cid="$(docker run -itd --network "$nname" -e FRONTEND_BIND_IP -e AUTH_ADDRESS -e WEBFRONTEND_ADDRESS -v "$vname":/data --name "$cname" "$image")"
# shellcheck disable=SC2064  # Intentional early expansion: capture IDs at trap-set time
trap "docker rm -vf '$cid' > /dev/null && docker volume rm -f '$vname' > /dev/null && docker network rm -f '$nid'" EXIT

docker_curl() {
    docker run --rm -i \
        --network "$nname" \
        --entrypoint curl \
        "$CURL_IMAGE" \
        --silent --show-error --fail --output /dev/null --write-out "%{http_code}" \
        "$@"
}

docker_sqlite3() {
    docker run --rm -i \
        --user "$SQLITE3_USER" \
        --volume "$vname":/data \
        --entrypoint sqlite3 \
        "$SQLITE3_IMAGE" \
        "/data/Account.db" \
        "$@"
}

tries=10
while ! docker_curl "http://$cname:8080/ServerStatus" &> /dev/null; do
    (( tries-- ))
    if [ $tries -le 0 ]; then
        echo >&2 'server failed to accept connections in a reasonable amount of time!'
        docker_curl "http://$cname:8080/ServerStatus" # to hopefully get a useful error message
        false
    fi
    sleep 2
done

[ "$(docker_curl "http://$cname:8080/ServerStatus")" = 200 ]

# Validate SQLite database was created and is accessible
tries=10
while ! docker_sqlite3 "SELECT 1;" &> /dev/null; do
    (( tries-- ))
    if [ $tries -le 0 ]; then
        echo >&2 'sqlite db failed to accept connections in a reasonable amount of time!'
        docker_sqlite3 "SELECT 1;"   # get a useful error message
        false
    fi
    sleep 2
done

[ "$(docker_sqlite3 "SELECT 1;")" = 1 ]
