#!/usr/bin/env bash
set -Eeuo pipefail

workflow=.github/workflows/test.yml

grep -Fq 'run: test/portal-image.sh' "$workflow"

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
