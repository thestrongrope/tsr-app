# Deployment

The production stack is `docker-compose.yml` at the repo root. The deployment tool (Dokploy) builds the images from the repository
and runs the file. It holds no secret and publishes no port; `hosts/api/tests/ProductionStackTests.cs` fails when that stops being true.

## Services

| Service | What it is | Runs |
|---|---|---|
| `db` | PostgreSQL 18; data in the volume `db-data` | always |
| `db-role` | creates the API's limited role `tsr_app` and sets its password | once per start |
| `migrate` | the API image with `--migrate`: applies the migrations not applied yet | once per start |
| `api` | the API; port 8080 | always |
| `workers` | the API image with `--workers`: runs the workers named in `TSR_WORKERS` | always |
| `gotenberg` | PDF rendering for report downloads | always |
| `elasticsearch` | the search index; data in the volume `es-data` | always |
| `site-build` | the static site generator (`hosts/site`): reads the API, writes the pages into the volume `site-data` | once per start; retried up to five times while the API is not ready |
| `site` | nginx serving `site-data`, read-only; port 80. It forwards nothing. Its image is the stock one with one setting baked in (`hosts/site/Dockerfile.server`): an address the site does not publish answers 404 with the site's own `404.html` | always |

Two services are reached from outside. Attach the API's host name to `api`, port 8080, and the site's host name to `site`, port 80. The server's proxy (Traefik) is the
only proxy: the nginx gateway in `hosts/gateway/` belongs to the dev and test stacks.

## Settings

Set these in the deployment tool. A missing required setting stops the start and names itself.

| Name | Required | Notes |
|---|---|---|
| `TSR_DB_OWNER_PASSWORD` | yes | the owner role: migrations only. Fixed once the database volume exists |
| `TSR_APP_DB_PASSWORD` | yes | the API's role. Letters and digits only (it sits inside a connection string). Changing it takes effect at the next start |
| `TSR_ELASTICSEARCH_PASSWORD` | yes | fixed once the index volume exists |
| `TSR_FIREBASE_PROJECT_ID` | yes | the Firebase project whose sign-ins the API accepts |
| `TSR_WORKERS` | no | comma-separated worker names. Empty runs none: a deploy alone sends nothing. `push-drain` and `class-schedules` send to members' phones |
| `TSR_GOOGLE_SERVICE_ACCOUNT_B64` | no | a service account key in base64: push, Firebase account deletion, sheet reads |
| `TSR_PUBLIC_WEB_BASE` | no | the base of share links |
| `TSR_CORS_ORIGINS` | no | the browser origins that may call the API, comma-separated (for a web build of the app, e.g. `https://app.thestrongrope.com`). Empty allows none. An entry with a path, a trailing slash or a wildcard stops the start |
| `TSR_QUIZ_SETTINGS_SHEET_ID`, `TSR_YOUTUBE_CHANNEL_ID`, `TSR_NOTIFIER_URL` | no | each empty switches its feature off |

Not wired yet: the app-version catalog file (`TSR_APP_VERSIONS_FILE`; without it the version check allows every build) and the
Library's content files (`TSR_CONTENT_DIR`; without it the Library copy reads nothing).

## First start and later starts

A first start on an empty host creates the database, the limited role and every schema, then starts the API. The database is empty:
no member exists. Real data arrives by a separate load (`docs/specs/repo-structure.md` section 3.3).

A later start keeps both volumes and applies only new migrations. **Removing the volume `db-data` removes every member's data.**

## The static site

The site is rebuilt at every start of the stack, from what the API answers at that moment. A build that fails keeps the pages built
before. It writes a `robots.txt` that keeps crawlers out (`TSR_SITE_NO_CRAWL` in `docker-compose.yml`). A change of content does not
rebuild it: redeploy, or start `site-build` again. Until the first build has finished, `site` answers 403 and is reported unhealthy.

## Not covered here

Backups and restore, the host names and certificates, moving members' data, and proving the outside services with real calls.
Each is its own issue under the epic "The store apps run on the new API".
