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
            && test "$(readlink /usr/share/mhserveremu/Config.ini)" = "/run/mhserveremu/config/Config.ini" \
            && test "$(readlink /usr/share/mhserveremu/ConfigOverride.ini)" = "/run/mhserveremu/config/ConfigOverride.ini" \
            && grep -Fq "Enabled=true" /usr/share/mhserveremu/Config.ini \
            && test -f /usr/share/mhserveremu/ConfigOverride.ini \
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

compose=deploy/docker/compose/docker-compose.yaml

ruby -ryaml - "$compose" <<'RUBY'
compose = YAML.load_file(ARGV.fetch(0))
service = compose.dig("services", "mhserveremu")

def portal_bridge_port_published?(port)
  case port
  when Hash
    port["published"].to_s == "8090"
  else
    mapping = port.to_s.split("/", 2).first
    mapping = mapping.sub(/\A\[[^\]]+\]:/, "")
    parts = mapping.split(":")
    parts.length >= 2 && parts[-2] == "8090"
  end
end

abort "Generic Compose must not enable a read-only root filesystem" if service.key?("read_only")
abort "Generic Compose must not configure PortalBridge tmpfs mounts" if service.key?("tmpfs")
abort "Compose must not publish PortalBridge port 8090" if service.fetch("ports", []).any? { |port| portal_bridge_port_published?(port) }
abort "Compose must not configure PortalBridge secrets" if service.fetch("environment", {}).keys.any? { |key| key.start_with?("PORTALBRIDGE_") }
abort "Compose must not configure PortalBridge secrets" if service.key?("secrets")
abort "Compose port detection must reject short-form published port 8090" unless portal_bridge_port_published?("8090:8090")
abort "Compose port detection must reject long-form published port 8090" unless portal_bridge_port_published?({"target" => 4306, "published" => 8090})
RUBY

grep -Fq 'zkoesters/mhserveremu:portal-master-89b02d6f39c0' README.md
grep -Fq 'zkoesters/mhserveremu@sha256:<published-manifest-digest>' README.md
grep -Fq 'PORTALBRIDGE_SECRET_FILE' README.md
grep -Fq 'must not be published' README.md
# shellcheck disable=SC2016 # Literal Markdown code span.
grep -Fq 'operator-set `read_only: true`' README.md
grep -Fq '/tmp:uid=1654,gid=1654,mode=1777' README.md
grep -Fq '/run/mhserveremu:uid=1654,gid=1654,mode=0700' README.md

workflow=.github/workflows/test.yml

ruby -ryaml - "$workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
paths = workflow.fetch(true).fetch("pull_request").fetch("paths")
expected = [
  "README.md",
  "deploy/docker/compose/docker-compose.yaml",
  ".github/workflows/docker-build-push.yml",
  ".github/workflows/docker-image-portal.yml"
]

abort "Test workflow must run for portal deployment, Compose, and build workflow changes" unless (expected - paths).empty?
RUBY

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
    [ "$(grep -Fc 'ln -s /run/mhserveremu/config/Config.ini /usr/share/mhserveremu/Config.ini' "$dockerfile")" -eq 2 ]
    [ "$(grep -Fc 'ln -s /run/mhserveremu/config/ConfigOverride.ini /usr/share/mhserveremu/ConfigOverride.ini' "$dockerfile")" -eq 2 ]
done

workflow=.github/workflows/docker-image-portal.yml

grep -Fq 'workflow_dispatch:' "$workflow"
if grep -Eq '^[[:space:]]*(push|pull_request|pull_request_target|schedule|workflow_call):' "$workflow"; then
    exit 1
fi
grep -Fq 'secrets: inherit' "$workflow"
ruby -rjson -ryaml - "$workflow" <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
matrix = JSON.parse(workflow.dig("jobs", "build", "with", "matrix"))
expected = [
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "portal-master", "commit" => "89b02d6f39c0b403c581c71cc5e052c0575775fe", "version_dir" => "nightly", "tag" => "portal-master-89b02d6f39c0", "dockerfile" => "Dockerfile"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "portal-master", "commit" => "89b02d6f39c0b403c581c71cc5e052c0575775fe", "version_dir" => "nightly", "tag" => "portal-master-89b02d6f39c0-alpine", "dockerfile" => "Dockerfile.alpine"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "portal-1.0.1", "commit" => "bc4a37ea2e2a0e570fcaebc90011c201d6225a7e", "version_dir" => "1.0.1", "tag" => "portal-1.0.1-bc4a37ea2e2a", "dockerfile" => "Dockerfile"},
  {"repository" => "https://github.com/zkoesters/MHServerEmu.git", "ref" => "portal-1.0.1", "commit" => "bc4a37ea2e2a0e570fcaebc90011c201d6225a7e", "version_dir" => "1.0.1", "tag" => "portal-1.0.1-bc4a37ea2e2a-alpine", "dockerfile" => "Dockerfile.alpine"}
]

abort "Portal image matrix does not match the pinned source mappings" unless matrix == expected
RUBY
# shellcheck disable=SC2016 # Literals intentionally include GitHub expression.
grep -Fq 'MHSERVEREMU_COMMIT=${{ matrix.commit }}' .github/workflows/docker-build-push.yml
# shellcheck disable=SC2016 # Literals intentionally include GitHub expression.
grep -Fq 'labels: ${{ steps.meta.outputs.labels }}' .github/workflows/docker-build-push.yml

ruby -ryaml - .github/workflows/docker-build-push.yml <<'RUBY'
workflow = YAML.load_file(ARGV.fetch(0))
metadata = workflow.dig("jobs", "docker", "steps").find { |step| step["id"] == "meta" }
labels = metadata&.dig("with", "labels")
expected = [
  "org.opencontainers.image.source=${{ matrix.repository }}",
  "org.opencontainers.image.revision=${{ matrix.commit }}",
  "io.mhserveremu.portal.ref=${{ matrix.ref }}"
]

abort "Metadata labels are not explicitly derived from the build matrix" unless labels&.lines(chomp: true)&.reject(&:empty?) == expected
RUBY

grep -Fq 'MHSERVEREMU_REPOSITORY ?= https://github.com/Crypto137/MHServerEmu.git' Makefile
# shellcheck disable=SC2016 # Make syntax is intentionally literal.
grep -Fq 'MHSERVEREMU_REF ?= $(call branch,$(VERSION))' Makefile
grep -Fq 'MHSERVEREMU_COMMIT ?=' Makefile
for build_arg in MHSERVEREMU_REPOSITORY MHSERVEREMU_REF MHSERVEREMU_COMMIT; do
    [ "$(grep -Fc -- "--build-arg ${build_arg}=" Makefile)" -eq 2 ]
done
# shellcheck disable=SC2016 # Make syntax is intentionally literal.
grep -Fq -- '--build-arg MHSERVEREMU_REF=$(or $(MHSERVEREMU_REF),$(call branch,$1))' Makefile
# shellcheck disable=SC2016 # Intentional literal GitHub Actions expression.
grep -Fq 'MHSERVEREMU_REF=${{ matrix.ref }}' .github/workflows/docker-build-push.yml
if grep -Fq 'matrix.branch' .github/workflows/docker-build-push.yml; then
    exit 1
fi
if grep -Eq 'matrix\.version([^_[:alnum:]]|$)' .github/workflows/docker-build-push.yml; then
    exit 1
fi

for template in 1.0.1/Config.ini.template nightly/Config.ini.template; do
    grep -Fq '[PortalBridge]' "$template"
    grep -Fq 'Enabled=%%PORTALBRIDGE_ENABLED%%' "$template"
    grep -Fq 'SecretFile=%%PORTALBRIDGE_SECRET_FILE%%' "$template"
done

grep -Fq 'PORTALBRIDGE_ENABLED||false' docker-entrypoint.sh
grep -Fq 'PORTALBRIDGE_SECRET_FILE||' docker-entrypoint.sh
grep -Fq 'MHSERVEREMU_CONFIG_DIRECTORY' docker-entrypoint.sh
grep -Fq 'MHSERVEREMU_RUNTIME_DIRECTORY' docker-entrypoint.sh
