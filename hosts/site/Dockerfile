# The static site generator as a one-off job (docker-compose.yml "site-build"): it reads the running API and writes the pages into
# /site, a volume the "site" server serves. Build context is the repo root, as for hosts/api/Dockerfile.

FROM mcr.microsoft.com/dotnet/sdk:11.0 AS build
WORKDIR /src
COPY .editorconfig Directory.Build.props Directory.Packages.props ./
COPY shared/site/ shared/site/
COPY domains/ domains/
COPY hosts/site/ hosts/site/
RUN dotnet publish hosts/site/Tsr.Host.Site.csproj -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:11.0
WORKDIR /app
COPY --from=build /out .
USER app
ENTRYPOINT ["dotnet", "Tsr.Host.Site.dll"]
CMD ["/site"]
