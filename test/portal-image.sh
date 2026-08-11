#!/usr/bin/env bash
set -Eeuo pipefail

for dockerfile in Dockerfile Dockerfile.alpine; do
    grep -Fq 'ARG MHSERVEREMU_REPOSITORY=https://github.com/Crypto137/MHServerEmu.git' "$dockerfile"
    grep -Fq 'ARG MHSERVEREMU_REF=1.0.1' "$dockerfile"
    grep -Fq 'ARG MHSERVEREMU_COMMIT=' "$dockerfile"
    grep -Fq 'git fetch --depth=1 origin "$MHSERVEREMU_COMMIT"' "$dockerfile"
    grep -Fq 'git checkout --detach FETCH_HEAD' "$dockerfile"
    grep -Fq 'git rev-parse HEAD' "$dockerfile"
done
