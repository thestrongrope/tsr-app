# The web copy of the member app: Flutter Web built here, served by the stock nginx image with our own configuration file
# (hosts/app/nginx.conf). Build context: the repo root (the app is a member of the root pub workspace), with its own ignore
# file, hosts/app/Dockerfile.dockerignore, because the root .dockerignore leaves every Flutter folder out.
#
# The API address is compiled into the app, so one image serves one stack:
#   docker build -f hosts/app/Dockerfile --build-arg TSR_API_BASE_URL=http://localhost:8089 .
# TSR_AUTH_EMULATOR_HOST (host:port as the BROWSER reaches it) is for a local stack only. The app refuses that setting in a
# release build, so naming it makes this a profile build; without it the build is a release build.

FROM debian:bookworm-slim AS build
# The Flutter SDK at the version the repo is developed with (flutter --version). The Flutter tool needs git, curl, unzip and xz.
ARG FLUTTER_VERSION=3.47.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter \
 && flutter config --no-analytics --no-cli-animations \
 && flutter precache --web

WORKDIR /src
# The workspace manifests first, so the packages are downloaded again only when a manifest changes.
COPY pubspec.yaml pubspec.lock ./
COPY hosts/app/pubspec.yaml hosts/app/pubspec.yaml
COPY shared/app/pubspec.yaml shared/app/pubspec.yaml
COPY domains/platform/app/pubspec.yaml domains/platform/app/pubspec.yaml
RUN flutter pub get --enforce-lockfile

COPY hosts/app hosts/app
COPY shared/app shared/app
COPY domains/platform/app domains/platform/app

ARG TSR_API_BASE_URL
ARG TSR_AUTH_EMULATOR_HOST=""
WORKDIR /src/hosts/app
RUN test -n "$TSR_API_BASE_URL" || { echo "TSR_API_BASE_URL is required (--build-arg)" >&2; exit 1; }; \
    if [ -n "$TSR_AUTH_EMULATOR_HOST" ]; then \
      flutter build web --profile \
        --dart-define=TSR_API_BASE_URL="$TSR_API_BASE_URL" \
        --dart-define=TSR_AUTH_EMULATOR_HOST="$TSR_AUTH_EMULATOR_HOST"; \
    else \
      flutter build web --release \
        --dart-define=TSR_API_BASE_URL="$TSR_API_BASE_URL"; \
    fi

FROM nginx:1.27-alpine
COPY hosts/app/nginx.conf /etc/nginx/conf.d/default.conf
RUN nginx -t
COPY --from=build /src/hosts/app/build/web /usr/share/nginx/html
