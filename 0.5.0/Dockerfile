FROM mcr.microsoft.com/dotnet/sdk:8.0.412-bookworm-slim AS build-stage

WORKDIR /tmp/MHServerEmu

RUN set -eux \
    \
    && git clone --depth 1 --branch 0.5.0 https://github.com/Crypto137/MHServerEmu.git /tmp/MHServerEmu \
    && dotnet restore MHServerEmu.sln \
    && dotnet build MHServerEmu.sln --no-restore --configuration Release \
    && dotnet test MHServerEmu.sln --no-build --no-restore --configuration Release

COPY ["Calligraphy.sip","mu_cdata.sip","/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0/Data/Game/"]

FROM mcr.microsoft.com/dotnet/runtime:8.0.18-bookworm-slim

COPY --from=build-stage --chown=$APP_UID:$APP_UID ["/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0", "/usr/share/mhserveremu"]

RUN apt-get update \
    && apt-cache showpkg sqlite3 vim \
    && apt-get install -y --no-install-recommends \
        sqlite3 \
        vim \
    && rm -rf /var/lib/apt/lists/* \
    \
    && ln -s /usr/share/mhserveremu/MHServerEmu /usr/bin/MHServerEmu \
    \
    && install -d -o "$APP_UID" -g "$APP_UID" /data

COPY 0.5.0/Config.ini.template /usr/share/mhserveremu/Config.ini.template
COPY ["docker-entrypoint.sh", "start-server", "/usr/local/bin/"]

VOLUME ["/data"]

USER $APP_UID

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["start-server"]