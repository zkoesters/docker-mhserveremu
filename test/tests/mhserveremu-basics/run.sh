#!/bin/bash
set -e

image="$1"

export FRONTEND_BIND_IP='0.0.0.0'

cname="mhserveremu-container-$RANDOM-$RANDOM"
vname="mhserveremu-data-$RANDOM-$RANDOM"
cid="$(docker run -d -e FRONTEND_BIND_IP -v $vname:/data --name "$cname" "$image")"
trap "docker rm -vf $cid > /dev/null && docker volume rm -f $vname > /dev/null" EXIT

docker_sqlite3() {
  docker run --rm -i \
    --volume "$vname":/data \
    --entrypoint sqlite3 \
    "keinos/sqlite3:3.47.2" \
    "/data/Account.db" \
    "$@"
}

tries=10
while ! echo 'SELECT 1;' | docker_sqlite3 &> /dev/null; do
	(( tries-- ))
	if [ $tries -le 0 ]; then
		echo >&2 'sqlite db failed to accept connections in a reasonable amount of time!'
		echo 'SELECT 1;' | docker_sqlite3 # to hopefully get a useful error message
		false
	fi
	sleep 2
done

[ "$(echo 'SELECT PlayerName FROM main.Account WHERE PlayerName = '\'Player1\''' | docker_sqlite3)" = Player1 ]
