# The one API image, in two builds of the same project (issue 108). Build context is the repo root (see docker-compose.dev.yml), because the
# host compiles shared/ and every domains/*/api module it loads. .dockerignore keeps the Flutter packages and build output out of the context.
#   target native (the last stage, so the default): the API, --workers and --load-content as one NativeAOT binary; no .NET runtime in the image.
#   target migrate: the JIT build (PublishAot=false), only for the one-off --migrate job, which needs Entity Framework. The native binary refuses --migrate.

FROM mcr.microsoft.com/dotnet/sdk:11.0 AS src
WORKDIR /src
COPY .editorconfig Directory.Build.props Directory.Packages.props ./
COPY shared/api/ shared/api/
COPY domains/ domains/
COPY hosts/api/ hosts/api/

FROM src AS build-migrate
RUN dotnet publish hosts/api/Tsr.Host.Api.csproj -c Release -o /out -p:PublishAot=false

FROM mcr.microsoft.com/dotnet/aspnet:11.0 AS migrate
WORKDIR /app
COPY --from=build-migrate /out .
USER app
ENTRYPOINT ["dotnet", "Tsr.Host.Api.dll"]

# The native compiler links with clang. TrimmerSingleWarn=false prints every trim or AOT warning at its call site, not one line per assembly.
FROM src AS build-native
RUN apt-get update && apt-get install -y --no-install-recommends clang zlib1g-dev && rm -rf /var/lib/apt/lists/*
RUN dotnet publish hosts/api/Tsr.Host.Api.csproj -c Release -o /out -p:TrimmerSingleWarn=false

# Chiseled: no shell and no package manager. The -extra variant carries the time zone data the class schedules need.
FROM mcr.microsoft.com/dotnet/runtime-deps:11.0-resolute-chiseled-extra AS native
WORKDIR /app
COPY --from=build-native /out/Tsr.Host.Api .
# The published content the Library reads (TSR_CONTENT_DIR in docker-compose.yml). The publication files (content/downloads/) are not copied: the API does not read them, the site image carries them. Copied files keep the repository's modes (644 and 755), so the user "app" can read them.
COPY content/articles/ /var/tsr/content/articles/
COPY content/categories/ /var/tsr/content/categories/
COPY content/pages/ /var/tsr/content/pages/
ENV ASPNETCORE_HTTP_PORTS=8080
USER app
ENTRYPOINT ["/app/Tsr.Host.Api"]
