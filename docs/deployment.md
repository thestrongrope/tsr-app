# Deployment

The production stack is `docker-compose.yml` at the repo root. The deployment tool (Dokploy) builds the images from the repository
and runs the file. It holds no secret and publishes no port; `hosts/api/tests/ProductionStackTests.cs` fails when that stops being true.

## Services

| Service | What it is | Runs |
|---|---|---|
| `db` | PostgreSQL 18; data in the volume `db-data` | always |
| `db-role` | creates the API's limited role `tsr_app` and sets its password | once per start |
| `migrate` | the API's JIT build (`hosts/api/Dockerfile` target `migrate`; Entity Framework cannot be native) with `--migrate`: applies the migrations not applied yet | once per start |
| `content-load` | the native API image with `--load-content`: copies the published content baked into the image (`/var/tsr/content`) into the database, then stops; exit 1 when it could not (the last set is kept) | once per start, after `migrate`; retried up to five times |
| `api` | the API, the native image (`hosts/api/Dockerfile` target `native`: one binary on a chiseled base: no .NET runtime, no shell and no package manager, so `docker exec ... sh` does not work; it opens one database connection before it listens); port 8080 | always |
| `workers` | the native API image with `--workers`: runs the workers named in `TSR_WORKERS` | always |
| `gotenberg` | PDF rendering for report downloads | always |
| `elasticsearch` | the search index; data in the volume `es-data` | always |
| `site-build` | the static site generator (`hosts/site`): reads the API, writes the pages into the volume `site-data` with the publication files (`content/downloads/`, about 187 MB, copied into the site-build image and from it into the volume at `/site/downloads/`) | once per start, after `content-load` has succeeded and `api` has started; retried up to five times |
| `site` | nginx serving `site-data`, read-only; port 80. It forwards nothing. Its image is the stock one with our configuration file baked in (`hosts/site/nginx.conf`, see "The site server and the old addresses"): an address the site does not publish answers 404 with the site's own `404.html` | always |
| `app` | the web copy of the member app (`hosts/app/Dockerfile`): Flutter Web as a release build served by nginx, port 80. It forwards nothing; the browser calls the API at the address compiled in (`TSR_APP_API_BASE_URL`). The image takes minutes to build | always |

Three services are reached from outside. Attach the API's host name to `api`, port 8080, the site's host name to `site`, port 80, and the app's host name to `app`, port 80. The server's proxy (Traefik) is the
only proxy: the nginx gateway in `hosts/gateway/` belongs to the dev and test stacks.

## Settings

Set these in the deployment tool. A missing required setting stops the start and names itself.

| Name | Required | Notes |
|---|---|---|
| `TSR_DB_OWNER_PASSWORD` | yes | the owner role: migrations only. Fixed once the database volume exists |
| `TSR_APP_DB_PASSWORD` | yes | the API's role. Letters and digits only (it sits inside a connection string). Changing it takes effect at the next start |
| `TSR_ELASTICSEARCH_PASSWORD` | yes | fixed once the index volume exists |
| `TSR_FIREBASE_PROJECT_ID` | yes | the Firebase project whose sign-ins the API accepts |
| `TSR_APP_API_BASE_URL` | no | the API's public address as a browser reaches it, compiled into the web app at build time (no trailing slash; changing it needs a rebuild). Empty: `https://api.thestrongrope.com`. For the web app to work, also name the app's origin in `TSR_CORS_ORIGINS` and add the app's host name to the Firebase project's authorized domains |
| `TSR_WORKERS` | no | comma-separated worker names. Empty runs none: a deploy alone sends nothing. `push-drain` and `class-schedules` send to members' phones |
| `TSR_GOOGLE_SERVICE_ACCOUNT_B64` | no | a service account key in base64: push, Firebase account deletion, sheet reads |
| `TSR_PUBLIC_WEB_BASE` | no | the base of share links |
| `TSR_CORS_ORIGINS` | no | the browser origins that may call the API, comma-separated (for a web build of the app, e.g. `https://app.thestrongrope.com`). Empty allows none. An entry with a path, a trailing slash or a wildcard stops the start |
| `TSR_QUIZ_SETTINGS_SHEET_ID`, `TSR_NOTIFIER_URL` | no | each empty switches its feature off |
| `TSR_YOUTUBE_CHANNEL_ID` | no | not in the stack: the API reads the channel in the code. Do not set it empty, that switches the Home videos off |
| `TSR_CONTENT_DIR` | fixed | `/var/tsr/content` in `docker-compose.yml`: the published text content (`articles/`, `categories/`, `pages/`) copied into the image from `content/`; the publication files are not in the API image. Not a setting to change |

Not wired yet: the app-version catalog file (`TSR_APP_VERSIONS_FILE`; without it the version check allows every build).

## First start and later starts

A first start on an empty host creates the database, the limited role and every schema, then starts the API. The database is empty:
no member exists. Real data arrives by a separate load (`docs/specs/repo-structure.md` section 3.3).

A later start keeps both volumes and applies only new migrations. **Removing the volume `db-data` removes every member's data.**

## The static site

The site is rebuilt at every start of the stack, from what the API answers at that moment. A build that fails keeps the pages built
before. It writes a `robots.txt` that keeps crawlers out (`TSR_SITE_NO_CRAWL` in `docker-compose.yml`). It starts only after `content-load` has succeeded, so it is built from the content of the deployed version; when the load fails the pages built before stay.
The content is part of the API image: a change of content reaches production only by a deploy. Until the first build has finished, `site` answers 403 and is reported unhealthy. A load that fails also makes the deploy command report a failure; `api`, `workers` and `site` still start on the new version and serve the content and pages they had.

### The site server and the old addresses

The server's configuration is the file `hosts/site/nginx.conf`, copied into the image by `hosts/site/Dockerfile.server`. It serves the pages, answers an unknown address with `404.html`, and forwards nothing. Every redirect is relative (`absolute_redirect off`), and no host name is written in the file. The link file `/.well-known/apple-app-site-association` is served as `application/json`. The files of the old website that the new site still serves (the app link files, `duas/`, `uploads/`, the dark icons) are in `hosts/site/wwwroot/`.

| Old address | Answer |
|---|---|
| `/tag/<slug>` | 301 to `/articles/?tag=<slug>` |
| `/category/<slug>` | 301 to `/articles/?category=<slug>` |
| `/YYYY/MM/DD/<slug>`, `/YYYY/MM/<slug>` | 301 to `/articles/<slug>/` |
| `/feed`, `/feed/...` | 302 to `/articles/` |
| `/author/...`, `/page/<n>` | 301 to `/articles/` |
| `/home` | 301 to `/` |
| `/articles/importance-reality-awaiting-intezaar-imam-mahdi` | 301 to `/articles/importance-virtue-awaiting-intezaar-imam-mahdi/` |
| `/<slug>` that is no file or folder of the site, when `/articles/<slug>/` exists | 301 to `/articles/<slug>/` |

The old `/join/` and `/mcq/` addresses are not redirected: they need the address of another system.

## Not covered here

Backups and restore, the host names and certificates, moving members' data, and proving the outside services with real calls.
Each is its own issue under the epic "The store apps run on the new API".
