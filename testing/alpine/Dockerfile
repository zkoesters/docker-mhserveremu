FROM mcr.microsoft.com/dotnet/sdk:8.0.407-alpine3.20 AS build-stage

ADD https://github.com/rhubarb-geek-nz/SQLite.Interop/releases/download/1.0.118.0/SQLite.Interop-1.0.118.0-alpine.3.20.zip /tmp/SQLite.Interop.zip

WORKDIR /tmp/MHServerEmu

RUN set -eux \
    \
    && git clone --depth 1 --branch feature/postges-support-and-fluentmigrator https://github.com/zkoesters/MHServerEmu.git /tmp/MHServerEmu \
    \
    && unzip -p /tmp/SQLite.Interop.zip runtimes/alpine.3.20-x64/native/SQLite.Interop.dll \
        > /tmp/MHServerEmu/src/MHServerEmu.DatabaseAccess/Interop/linux-x64/SQLite.Interop.dll \
    \
    && dotnet restore MHServerEmu.sln \
    && dotnet build MHServerEmu.sln --no-restore --configuration Release \
    && dotnet test MHServerEmu.sln --no-build --no-restore --configuration Release

COPY ["Calligraphy.sip","mu_cdata.sip","/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0/Data/Game/"]

FROM mcr.microsoft.com/dotnet/runtime:8.0.14-alpine3.20

COPY --from=build-stage --chown=$APP_UID:$APP_UID ["/tmp/MHServerEmu/src/MHServerEmu/bin/x64/Release/net8.0", "/usr/share/mhserveremu"]

RUN set -eux \
    \
    && apk add --no-cache \
        bash \
        postgresql16-client \
        sqlite \
        vim \
    \
    && ln -s /usr/share/mhserveremu/MHServerEmu /usr/bin/MHServerEmu \
    \
    && install -d -o "$APP_UID" -g "$APP_UID" /data

COPY testing/Config.ini.template /usr/share/mhserveremu/Config.ini.template
COPY ["docker-entrypoint.sh", "start-server", "/usr/local/bin/"]

VOLUME ["/data"]

USER $APP_UID

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["start-server"]