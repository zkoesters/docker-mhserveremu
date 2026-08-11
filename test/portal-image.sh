#!/usr/bin/env bash
set -Eeuo pipefail

temporary_directory=

run_runtime_contract() {
    local image="$1"
    local secret_file
    local readonly_options=(
        --read-only
        --tmpfs "/tmp:rw,nosuid,nodev,noexec,mode=1777"
        --tmpfs "/run/mhserveremu:rw,nosuid,nodev,noexec,uid=1654,gid=1654,mode=0700"
    )

    temporary_directory="$(mktemp -d)"
    secret_file="${temporary_directory}/portal-hmac"
    trap 'rm -rf -- "$temporary_directory"' EXIT
    chmod 0755 "$temporary_directory"
    printf '%s\n' 'portal-runtime-contract-hmac' > "$secret_file"
    chmod 0444 "$secret_file"

    if docker run --rm "${readonly_options[@]}" \
        --mount "type=bind,source=${temporary_directory},target=/portal-secret,readonly" \
        -e PORTALBRIDGE_ENABLED=true \
        -e PORTALBRIDGE_SECRET_FILE=/portal-secret \
        -e PORTALBRIDGE_SERVER_INSTANCE_ID=123e4567-e89b-12d3-a456-426614174000 \
        -e MHSERVEREMU_RUNTIME_DIRECTORY=/tmp/mhserveremu/runtime \
        "$image"; then
        printf '%s\n' 'Error: PORTALBRIDGE_SECRET_FILE accepted a readable directory' >&2
        exit 1
    fi

    docker run --rm "${readonly_options[@]}" \
        --mount "type=bind,source=${secret_file},target=/portal-hmac,readonly" \
        -e PORTALBRIDGE_ENABLED=true \
        -e PORTALBRIDGE_SECRET_FILE=/portal-hmac \
        -e PORTALBRIDGE_SERVER_INSTANCE_ID=123e4567-e89b-12d3-a456-426614174000 \
        -e MHSERVEREMU_RUNTIME_DIRECTORY=/tmp/mhserveremu/runtime \
        "$image" sh -c 'test -f "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini" \
            && test -f "$MHSERVEREMU_CONFIG_DIRECTORY/ConfigOverride.ini" \
            && ! grep -Fq "portal-runtime-contract-hmac" "$MHSERVEREMU_CONFIG_DIRECTORY/Config.ini"'
}

if [ "$#" -eq 1 ]; then
    run_runtime_contract "$1"
    exit 0
fi

if [ "$#" -ne 0 ]; then
    printf '%s\n' 'Usage: test/portal-image.sh [config-test-image]' >&2
    exit 2
fi

workflow=.github/workflows/test.yml

grep -Fq 'run: test/portal-image.sh' "$workflow"
grep -Fq 'config-test' "$workflow"
grep -Fq 'MHSERVEREMU_VERSION=nightly' "$workflow"
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'test/portal-image.sh ${{ matrix.image }}' "$workflow"

for dockerfile in Dockerfile Dockerfile.alpine; do
    grep -Fq 'ARG MHSERVEREMU_REPOSITORY=https://github.com/Crypto137/MHServerEmu.git' "$dockerfile"
    grep -Fq 'ARG MHSERVEREMU_REF=1.0.1' "$dockerfile"
    grep -Fq 'ARG MHSERVEREMU_COMMIT=' "$dockerfile"
    grep -Fq 'ARG MHSERVEREMU_BRANCH=1.0.1' "$dockerfile"
    grep -Fq "if [ \"\$MHSERVEREMU_REF\" = \"1.0.1\" ] && [ -n \"\$MHSERVEREMU_BRANCH\" ]; then" "$dockerfile"
    grep -Fq "MHSERVEREMU_EFFECTIVE_REF=\"\$MHSERVEREMU_BRANCH\"" "$dockerfile"
    grep -Fq "git fetch --depth=1 origin \"\$MHSERVEREMU_EFFECTIVE_REF\"" "$dockerfile"
    grep -Fq "git fetch --depth=1 origin \"\$MHSERVEREMU_COMMIT\"" "$dockerfile"
    grep -Fq 'git checkout --detach FETCH_HEAD' "$dockerfile"
    grep -Fq 'git rev-parse HEAD' "$dockerfile"
    grep -Fq "org.opencontainers.image.source=\"\$MHSERVEREMU_REPOSITORY\"" "$dockerfile"
    grep -Fq "org.opencontainers.image.revision=\"\$MHSERVEREMU_COMMIT\"" "$dockerfile"
    grep -Fq "io.mhserveremu.portal.ref=\"\$MHSERVEREMU_REF\"" "$dockerfile"
done

grep -Fq -- "--build-arg MHSERVEREMU_REF=\$(call branch,\$1)" Makefile
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'MHSERVEREMU_REF=${{ matrix.branch }}' .github/workflows/docker-build-push.yml

for template in 1.0.1/Config.ini.template nightly/Config.ini.template; do
    grep -Fq '[PortalBridge]' "$template"
    grep -Fq 'Enabled=%%PORTALBRIDGE_ENABLED%%' "$template"
    grep -Fq 'SecretFile=%%PORTALBRIDGE_SECRET_FILE%%' "$template"
done

grep -Fq 'PORTALBRIDGE_ENABLED||false' docker-entrypoint.sh
grep -Fq 'PORTALBRIDGE_SECRET_FILE||' docker-entrypoint.sh
grep -Fq 'MHSERVEREMU_CONFIG_DIRECTORY' docker-entrypoint.sh
grep -Fq 'MHSERVEREMU_RUNTIME_DIRECTORY' docker-entrypoint.sh
