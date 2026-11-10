# The one API process. Build context is the repo root (see docker-compose.dev.yml), because the
# host compiles shared/ and every domains/*/api module it loads. .dockerignore keeps the Flutter
# packages and build output out of the context.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Directory.Build.props Directory.Packages.props ./
COPY shared/api/ shared/api/
COPY domains/ domains/
COPY hosts/api/ hosts/api/
RUN dotnet publish hosts/api/Tsr.Host.Api.csproj -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_HTTP_PORTS=8080
USER app
ENTRYPOINT ["dotnet", "Tsr.Host.Api.dll"]
