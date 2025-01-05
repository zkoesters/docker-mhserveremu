#!/bin/bash
set -e

image="$1"

export FRONTEND_BIND_IP='0.0.0.0'
export AUTH_ADDRESS='*'

cname="mhserveremu-container-$RANDOM-$RANDOM"
nname="mhserveremu-network-$RANDOM-$RANDOM"
vname="mhserveremu-data-$RANDOM-$RANDOM"
docker volume create "$vname"
nid="$(docker network create "$nname")"
cid="$(docker run -d --network "$nname" -e FRONTEND_BIND_IP -e AUTH_ADDRESS -v $vname:/data --name "$cname" "$image")"
trap "docker rm -vf $cid > /dev/null && docker volume rm -f $vname > /dev/null && docker network rm -f $nid" EXIT

docker_curl() {
  docker run --rm -i \
    --network "$nname" \
    --entrypoint curl \
    "curlimages/curl:8.11.1" \
    --silent --show-error --fail --output /dev/null --write-out "%{http_code}" \
    "$@"
}

docker_sqlite3() {
  docker run --rm -i \
    --volume "$vname":/data \
    --entrypoint sqlite3 \
    "keinos/sqlite3:3.47.2" \
    "/data/Account.db" \
    "$@"
}

tries=10
while ! docker_curl "http://$cname:8080/ServerStatus?outputFormat=Json" &> /dev/null; do
	(( tries-- ))
	if [ $tries -le 0 ]; then
		echo >&2 'server failed to accept connections in a reasonable amount of time!'
		docker_curl "http://$cname:8080/ServerStatus?outputFormat=Json" # to hopefully get a useful error message
		false
	fi
	sleep 2
done

[ "$(docker_curl "http://$cname:8080/ServerStatus?outputFormat=Json")" = 200 ]

tries=10
while ! docker_sqlite3 "SELECT 1;" &> /dev/null; do
	(( tries-- ))
	if [ $tries -le 0 ]; then
		echo >&2 'sqlite db failed to accept connections in a reasonable amount of time!'
		echo docker_sqlite3 "SELECT 1;"
		false
	fi
	sleep 2
done

[ "$(docker_sqlite3 "SELECT PlayerName FROM main.Account WHERE PlayerName = 'Player1';")" = Player1 ]
