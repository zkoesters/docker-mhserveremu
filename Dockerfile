# Parameterized Dockerfile for MHServerEmu (Debian)
#
# Build args:
#   MHSERVEREMU_BRANCH  - git branch or tag to clone (e.g. "1.0.0", "dev")
#   MHSERVEREMU_VERSION - directory containing Config.ini.template (e.g. "1.0.0", "nightly")
#   SQLITE_INTEROP_VERSION         - System.Data.SQLite source version (default: 1.0.118.0)
#   SQLITE_SOURCE_ARCHIVE_SHA256   - SHA256 for sqlite source archive
#   APP_UID             - runtime user/group ID (default: 1654)
#   DOTNET_SDK_TAG      - .NET SDK image tag (default: 8.0.419-bookworm-slim)
#   DOTNET_RUNTIME_TAG  - .NET runtime image tag (default: 8.0.25-bookworm-slim)
#
# Multi-arch: supports linux/amd64 and linux/arm64 via TARGETARCH.

ARG DOTNET_SDK_TAG=8.0.419-bookworm-slim
ARG DOTNET_RUNTIME_TAG=8.0.25-bookworm-slim

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_TAG} AS sqlinterop-build

ARG TARGETARCH
ARG SQLITE_INTEROP_VERSION=1.0.118.0
ARG SQLITE_SOURCE_ARCHIVE_SHA256=bb599fa265088abb8a7d4af6218cae97df8b9c8ed6f04fb940a5d564920ee6a1

COPY scripts/build-sqlinterop.sh /usr/local/bin/build-sqlinterop.sh

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        binutils \
        ca-certificates \
        curl \
        g++ \
        gcc \
        libc6-dev \
        make \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in amd64|arm64) ;; *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; esac \
    && SQLITE_INTEROP_VERSION="$SQLITE_INTEROP_VERSION" \
       SQLITE_SOURCE_ARCHIVE_SHA256="$SQLITE_SOURCE_ARCHIVE_SHA256" \
       TARGETARCH="$TARGETARCH" \
       OUTPUT_DIR=/out \
       WORK_DIR=/tmp/sqlinterop-build \
       /usr/local/bin/build-sqlinterop.sh \
    && test -s /out/SQLite.Interop.dll

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_TAG} AS build-stage

ARG MHSERVEREMU_BRANCH=1.0.0
ARG TARGETARCH

WORKDIR /tmp/MHServerEmu

COPY --from=sqlinterop-build /out/SQLite.Interop.dll /tmp/SQLite.Interop.dll

# Validate TARGETARCH (amd64/arm64),
# then clone, inject the source-built native library, build, and test.
#
# The csproj hard-codes Interop/linux-x64/ as the source path on Linux,
# so we write to that path regardless of architecture.
# Upstream test projects are x64-targeted, so arm64 build-stage testing is
# currently skipped until upstream publishes arm64-compatible test targets.
RUN set -eux \
    && case "$TARGETARCH" in \
        amd64|arm64) ;; \
        *)     echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
        esac \
    && git clone --depth 1 --branch "${MHSERVEREMU_BRANCH}" \
        https://github.com/Crypto137/MHServerEmu.git /tmp/MHServerEmu \
    && cp /tmp/SQLite.Interop.dll \
        /tmp/MHServerEmu/src/MHServerEmu.DatabaseAccess/Interop/linux-x64/SQLite.Interop.dll \
    && dotnet restore MHServerEmu.sln \
    && dotnet build MHServerEmu.sln --no-restore --configuration Release \
    && if [ "$TARGETARCH" = "amd64" ]; then \
        dotnet test MHServerEmu.sln --no-build --no-restore --configuration Release; \
    else \
        echo "Skipping dotnet test on $TARGETARCH (upstream tests are x64-targeted)."; \
    fi

COPY ["Calligraphy.sip", "mu_cdata.sip", \
    "/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0/Data/Game/"]

FROM mcr.microsoft.com/dotnet/runtime:${DOTNET_RUNTIME_TAG}

ARG MHSERVEREMU_VERSION=1.0.0
ARG APP_UID=1654

COPY --from=build-stage --chown=$APP_UID:$APP_UID \
    ["/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0", "/usr/share/mhserveremu"]

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        sqlite3 \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/share/mhserveremu/MHServerEmu /usr/bin/MHServerEmu \
    && install -d -o "$APP_UID" -g "$APP_UID" /data

COPY ${MHSERVEREMU_VERSION}/Config.ini.template /usr/share/mhserveremu/Config.ini.template
COPY ["docker-entrypoint.sh", "start-server", "/usr/local/bin/"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -qO /dev/null http://localhost:8080/ServerStatus || exit 1

VOLUME ["/data"]

USER $APP_UID

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["start-server"]
