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
done
