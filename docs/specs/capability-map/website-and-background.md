# Capability map: the public website and the background work

Read on 15 Nov 2026 from two other repositories (code, compose files and docs only). Nothing was run.

## 1. Summary

- **Website** (`tsr-web/web`): one Next.js 16 app (standalone output) that reads Markdown files from `web/content` (articles, pages, categories, authors, YouTube video notes) straight off disk. There is no relational database. Pages are mostly static with timed revalidation; search, the lecture library and the JSON API are dynamic.
- It runs with two helper services: Elasticsearch (articles index, lectures index, search analytics index; all rebuildable) and a small Python embedding service (query vectors for optional semantic lecture search, off by default).
- **Deployment**: Dokploy, as a Docker Swarm stack behind Traefik; settings are entered in the Dokploy UI. The docs disagree on the trigger: the repo's `CLAUDE.md` says merging to `main` deploys, `DEPLOYMENT.md` says deploys are manual. Unsure which is current. After a deploy the lecture index is empty until a reindex route is called by hand.
- **Website background work**: nothing scheduled. Content arrives by git commit (by hand, by the Decap CMS, or by laptop pipelines); indexes are built at image build or by a manual reindex call; the YouTube feed is fetched on request and cached in memory.
- **Background work in production** (`tsr-account`): a `scheduler` container runs cron with six jobs: every minute the push drain, the search drain, the due WhatsApp reminders check and the due class notifications check; every two minutes the WhatsApp drain; nightly at 03:00 (Asia/Kolkata) the search reconcile. A `notifier` container (Node, a WhatsApp Web session) does the actual WhatsApp sending when called over HTTP; it has no timer of its own.
- All of that work uses the PHP application's MariaDB. Redis is in the compose file but, per that repo's docs, nothing uses it yet.
- **Not read**: any `.env`, `.secrets`, key file, `backups/`, `DB/`, `logs/`, `state/`, `cache/`, WhatsApp session data, data exports; individual articles; `web/src/components` in full; `tsr-web` folders `analysis`, `archive`, `captions`, `docs`, `reference`, `review`, `translations`; `tsr-account` `docs/` (one grep only), `mobile/`, `tests/`, `workbench/`, `security/`; the Go migration tool beyond one file's header; the body of most scripts (headers only). Environment values in compose files were not read.

## 2. Table A: Website

"ISR" below means a page built as static HTML and rebuilt after a set time.

| Area | Capability (verb phrase) | Page or API route | Static or dynamic (and why) | Data source (content files, YouTube feed, search index, other) | Notes (max 15 words) |
|---|---|---|---|---|---|
| Home | See the home page: accreditation cards, category cards, latest articles, latest videos | `/` | Static, ISR 1 hour | Content files; YouTube feed | Thumbnails load from YouTube's image host. |
| Home | Start a lecture search from the home page | `/` (form, GET to `/lectures`) | Static form; result page is dynamic | None | Plain HTML form, no script needed. |
| Articles | Browse the article list, filter by category | `/articles`, `/articles?category=` | Dynamic (reads the query string) | Content files | Also takes `?tag=` from old redirects; tag handling unsure. |
| Articles | Search articles as you type | `/articles` (client calls `/api/v1/search`) | Dynamic, client side | Search index (Elasticsearch), Fuse.js fallback; `/search-index.json` | Debounced 300 ms; exact client fallback rule unsure. |
| Articles | Read an article (reading time, right-to-left text, canonical link, related articles) | `/articles/[slug]` | Static, ISR 1 hour | Content files | Related articles computed from content. |
| Pages | Read a content page (accreditation, privacy policy, book chapters, announcements) | `/[slug]` | Static, ISR 1 day | Content files (`content/pages`) | Privacy policy is linked from app store listings. |
| Pages | Be redirected from a bare slug to its article | `/[slug]` | Static with redirect (301) | Content files | Four retired WordPress slugs redirect to home. |
| Pages | Browse the index of books, resources and about pages | `/pages` | Static (no dynamic input seen) | Content files | Grouped by page type. |
| Pages | Read the About page | `/about` | Static, ISR 1 hour | Unsure (page body not read) | |
| Publications | Browse publications in tabs and download PDFs | `/tsr-publications` | Static (no dynamic input seen) | Content file `tsr-publications.md`; PDFs in `public/downloads` | PDF summaries are written by a pipeline script. |
| Lectures | Browse the lecture library newest first | `/lectures` | Dynamic (query string; client fetch) | Search index (lectures) | Empty after a deploy until reindexed. |
| Lectures | Search lectures by keyword, filter by language | `/lectures?q=` (client calls `/api/v1/lectures/search`) | Dynamic | Search index; embedding service when semantic weight is on | Results link out to YouTube; no embedded player. |
| Self-reflection | Fill in the self-reflection sheet in three languages, with automatic scores | `/self-reflection/[lang]` (`/self-reflection` redirects to `en`) | Static shell, client-side form | Translations in code; browser local storage | Answers never leave the browser; reset button. |
| Donate | See the donation QR code and bank details | `/donate` | Static | Image and text in the page | No payment form; no data submitted. |
| API docs | Read the API documentation (Swagger UI) | `/docs`; `/api/docs` redirects to it | Client side | `/api/swagger` | |
| API | Get the OpenAPI document | `GET /api/swagger` | Dynamic (built from code comments) | Route source comments; `public/swagger.json` exists too | Which one production serves: unsure. |
| API | List articles | `GET /api/v1/articles` | Dynamic | Content files | **ported** |
| API | Get one article | `GET /api/v1/articles/{slug}` | Dynamic | Content files | **ported** |
| API | List categories | `GET /api/v1/taxonomies/categories` | Dynamic | Content files | **ported** |
| API | List tags | `GET /api/v1/taxonomies/tags` | Dynamic | Content files | **ported** |
| API | List publications | `GET /api/v1/publications` | Dynamic | Content file `tsr-publications.md` | **ported** |
| API | List latest YouTube videos | `GET /api/v1/youtube` | Dynamic, in-memory cache, serves stale on failure | YouTube channel RSS feed | **ported** |
| API | List the articles of one category | `GET /api/v1/taxonomies/categories/{slug}/articles` | Dynamic, ETag and 304 | Content files | Not among the six ported routes. |
| API | Search articles | `GET /api/v1/search` | Dynamic, rate limited (60 a minute per client by default) | Search index (Elasticsearch), Fuse.js fallback | Logs an anonymous search event. |
| API | Search or browse lectures | `GET /api/v1/lectures/search` | Dynamic, rate limited | Search index; embedding service (optional) | BM25, fuzzy retry, optional rank fusion with vectors. |
| API | Record an anonymous search-click event | `POST /api/v1/events` | Dynamic, rate limited, strict validation | Writes to the analytics index | No IP, cookie or user agent stored. |
| API (legacy) | List articles, old shape | `GET /api/articles` | Dynamic | Content files | Legacy; no caller found. |
| API (legacy) | Get one article, old shape | `GET /api/articles/{slug}` | Dynamic | Content files | Plain JSON, no envelope. |
| Admin | Rebuild the articles search index | `POST /api/admin/reindex` | Dynamic, shared secret header | Content files to search index | By hand after a deploy; 503 if secret unset. |
| Admin | Rebuild the lectures search index | `POST /api/admin/reindex-lectures` | Dynamic, shared secret header | `content/lectures/lectures.ndjson` to search index | Required after every deploy that changes lectures. |
| Admin | Read the search analytics report (top queries, zero-result queries, clicks) | `GET /api/admin/analytics` | Dynamic, shared secret, rate limited | Analytics index | JSON only; no page for it. |
| CMS | Edit articles, pages, categories, authors, video notes and site settings | `/admin` (Decap CMS, rewritten to `/admin/index.html`; `/config.yml`) | Static page, client app | The website's GitHub repository (editorial workflow, branch `main`) | An edit is a commit; publishing needs a deploy. |
| CMS | Sign the editor in with GitHub | `GET /api/auth`, `GET /api/callback` | Dynamic (OAuth redirect and token exchange) | GitHub OAuth | Asks for `repo` and `user` scope. |
| Analytics | Count page views | every page (layout) | Client script | Google Analytics | No consent banner; the privacy policy says so. |
| App links | Open join and quiz links in the mobile app | `/.well-known/apple-app-site-association`, `/.well-known/assetlinks.json` | Static files (one content-type header rule) | Files in `public/.well-known` | iOS file lists `/mcq/*`; `/join` there: unsure. |
| App links | Send the web version of a join or quiz link to the account site | `/join/:code`, `/mcq/:code` | Redirect (temporary) | None | Fallback when the app is not installed. |
| Redirects | Keep old WordPress links working (tag, category, dated permalinks, author, pagination) | `/tag/:slug`, `/category/:slug`, `/:year/:month[/:day]/:slug`, `/author/:slug`, `/page/:num` | Redirect (permanent) | None | One article-to-article 301 is also hard-coded. |
| Redirects | Send feed requests to the article list | `/feed`, `/feed/:type` | Redirect (temporary) | None | There is no RSS feed. |
| Redirects | Turn away WordPress attack paths | `/wp-admin`, `/wp-login.php`, `/xmlrpc.php` | Redirect to a 404 path | None | |
| Redirects | Repair malformed URLs with a comma in the path | any path (middleware) | Dynamic (middleware, 301) | None | From bad indexing of old URLs. |
| API | Allow any origin to call the API (CORS, preflight) | `/api/*` (middleware) | Dynamic (middleware) | None | `Access-Control-Allow-Origin: *`. |
| Static files | Download book PDFs, view uploaded images, open two standalone dua pages | `/downloads/...`, `/uploads/...`, `/duas/*.html` | Static files | `public/` | Who links to the dua pages: unsure. |
| Theme | Switch between light and dark theme | every page | Client side | Browser | |
| SEO | Sitemap, robots file | none found | n/a | n/a | No `sitemap` or `robots` file found in `src` or `public`. |
| Forms | Contact, newsletter or registration form | none found | n/a | n/a | The only forms: search boxes and the self-reflection sheet. |

## 3. Table B: Background and scheduled work

"MariaDB" is the PHP application's database in `tsr-account`. "Queue" is its `outbound_messages` table.

| Job (verb phrase) | Where it lives (service, file) | Trigger (schedule or event) | Reads | Sends or writes (WhatsApp, push, email, Sheets, database, index, none) | Which database it uses | Notes (max 15 words) |
|---|---|---|---|---|---|---|
| Send queued push notifications | `scheduler`, `web/cli/drain_push.php` | Cron, every minute | Queue rows on the `push` channel | Push (FCM); marks queue rows | MariaDB | Claim, retry with backoff, dead after five; overlap-safe. |
| Send queued WhatsApp messages | `scheduler`, `web/cli/drain_whatsapp.php` (calls notifier `POST /send`) | Cron, every 2 minutes, gents channel only | Queue rows on the `whatsapp:gents` channel; notifier link status | WhatsApp; marks queue rows | MariaDB | I found no code that queues WhatsApp rows; unsure it carries traffic. |
| Bring the search index in line with changed records | `scheduler`, `web/cli/drain_search.php` | Cron, every minute | Queue rows on the `search` channel; the changed records | Index (Elasticsearch) | MariaDB | Claims nothing unless Elasticsearch answers. |
| Rebuild and reconcile the search index | `scheduler`, `web/cli/reindex_search.php` | Cron, nightly 03:00 Asia/Kolkata | Every record the index should hold | Index (Elasticsearch) | MariaDB | Needed because many pages write without queueing an event. |
| Start the WhatsApp reminders that are due | `scheduler`, `web/cli/run_due_reminders.php` (calls notifier `POST /run-weekly`) | Cron, every minute; acts when a reminder's weekday and time slot is due | Reminder schedules (`notifier_reminders`), past runs | None itself; starts a notifier run | MariaDB | Never replays a slot older than two hours. |
| Queue the class notifications that are due (one-off, weekly, reminder) | `scheduler`, `web/cli/run_due_class_notifications.php` | Cron, every minute | Scheduled class notifications, class state, creator's rights, device rows | Database (push rows on the queue) | MariaDB | Per-class hourly and daily limits; two-hour deadline. |
| Send a reminder run: pending C-form messages to teachers | `notifier`, `weekly-job.js` (`POST /run-weekly`) | Event: the due-reminders cron job, or an admin pressing Run (also dry run) | The reminder row; the webapp's conduction report endpoint (API key) | WhatsApp to teachers; database (`notifier_runs`, `notifier_sent_messages`) | MariaDB | One message per number per day; 2 seconds apart; one run at a time. |
| Send one queued WhatsApp message | `notifier`, `server.js` (`POST /send`) | Event: called by the WhatsApp drain | Request body | WhatsApp | None | Status code tells the drain whether to burn an attempt. |
| Send a test WhatsApp message | `notifier`, `server.js` (`POST /send-test`) | Event: admin action on the WhatsApp admin page | Request body | WhatsApp; database (a run and a message row) | MariaDB | Body of the handler read only in part. |
| Keep the WhatsApp session linked (QR, relink, logout, reconnect) | `notifier`, `baileys-manager.js` (`/status`, `/qr`, `/relink`, `/logout`) | Event: admin action; reconnect timer after a drop | Session files on its own volume (not read by me) | None (session state on a volume) | None | The crontab notes this session drops repeatedly. |
| Serve and change reminder settings and run history | `notifier`, `server.js` (`/reminders`, `/last-run`, `/recent-runs`, `/runs/:id`, `/runs/:id/messages`) | Event: the WhatsApp admin page | `notifier_reminders`, `notifier_runs`, `notifier_sent_messages` | Database (reminder settings) | MariaDB | The notifier writes the PHP database directly. |
| Queue a push when a quiz is published or an admin sends a notification | `webapp` and `mobileapi`, `queue_message()` in `web/functions.php` | Event: quiz publish, send-notification page, quiz admin action | Device rows of the recipients | Database (queue rows) | MariaDB | Producer only; the push drain delivers. |
| Queue a search update when a record changes | `webapp` and `mobileapi`, `web/models/searchoutbox.php` | Event: a write that goes through the outbox | The changed record's key | Database (queue rows) | MariaDB | Not every write does; hence the nightly reconcile. |
| Apply database migrations | `webapp` container start, `.docker/entrypoint.sh` running `tools/migrate` | Event: container start (each deploy) | `migrations/` | Database (schema); on failure a push alert row for one member (per `alert.go` header) | MariaDB | The app starts anyway if migrations fail. |
| Remove expired contact details from account deletion requests | `webapp`, `web/models/accountdeletion.php` | Event: the deletion requests admin page loads, or a request is completed | Deletion request rows | Database | MariaDB | Not on cron: runs only when an admin opens the page. |
| Check a service account can reach every Google Sheet | `web/cli/verify_sheets_access.php` | By hand, at the start of a quiz cycle | Sheet list in code or settings | None by default (read only) | Unsure | Operator tool, not a job. |
| Reload the GeoNames reference data | `tools/geonames/load.php` | By hand, yearly (`--force`) | GeoNames files | Database | MariaDB | |
| Import the old notifier's run history | `notifier/scripts/import-history.js` | One-off, by hand | Old report backups | Database (`notifier_runs`, `notifier_sent_messages`) | MariaDB | Already done or not: unsure. |
| Refresh the roadmap calendar's data from the issue tracker | `scripts/refresh-calendar.sh` | By hand | GitHub issues | A pull request on the calendar repository | None | Never merges by itself. |
| Smoke-test the deployed web app and mobile API | `scripts/smoke-prod.sh` | By hand, after a release | Production or UAT over HTTP | None | None | |
| Rebuild the website's article and lecture indexes | website `web`, `POST /api/admin/reindex`, `/api/admin/reindex-lectures` | By hand, after a deploy | Content files, `lectures.ndjson` | Index (website Elasticsearch) | None (no database) | Nothing triggers it automatically. |
| Refresh the website's latest-videos list | website `web`, `src/lib/markdown.ts`, `/api/v1/youtube` | Event: a request after the cache expires; page revalidation | YouTube channel RSS feed | None (memory cache) | None | Serves the stale list if YouTube fails. |
| Record anonymous search and click events | website `web`, `api/lib/analytics-service.ts` | Event: each first-page search and each result click | The request | Index (analytics, website Elasticsearch) | None | Fire and forget; never fails the request. |
| Check that every indexed lecture is still public on YouTube | website, `web/scripts/check-lecture-availability.ts` | By hand, before a deploy and now and then | `lectures.ndjson`; YouTube | None (exit code) | None | Private or deleted videos stay searchable otherwise. |

## 4. Content and data pipelines

Website (`tsr-web`); all run by hand on a laptop, and their output reaches production by git commit and image build:

- `web/scripts/build-search-index.ts`: at build, writes `public/search-index.json` from the published articles.
- `web/scripts/index-to-elasticsearch.ts`, `create-es-index.ts`: create and fill the articles index (the build tries it and skips if Elasticsearch is unreachable).
- `web/scripts/generate-swagger.ts`: at build, writes `public/swagger.json` from route comments.
- `web/scripts/build-lectures-data.ts`: turns the lecture pipeline's `videos.ndjson` into `content/lectures/lectures.ndjson` (public videos only, with exclusion lists).
- `web/scripts/embed-lectures-data.ts`: adds a vector to each lecture document by calling the running embedding service.
- `web/scripts/check-lecture-availability.ts`: checks each indexed lecture is still public.
- `lecture-pipeline/scripts/update_lectures.py`: the one command that refreshes the lecture corpus end to end.
- `lecture-pipeline/scripts/youtube_api.py`: channel inventory and caption download (YouTube Data API).
- `lecture-pipeline/scripts/parse_captions.py`: caption files to clean timestamped chunks.
- `lecture-pipeline/scripts/transcribe_audio.py`, `transcripts_to_chunks.py`: transcribe videos with no captions (Gemini) and chunk the transcripts.
- `lecture-pipeline/scripts/backfill_empty_captions.py`: corrects inventory records whose caption file is empty.
- `lecture-pipeline/scripts/translate_chunks.py`: translates chunks to English (Gemini).
- `lecture-pipeline/scripts/enrich_videos.py`: per video summary, chapters, key points, tags, search phrases (Gemini).
- `lecture-pipeline/scripts/build_index.py`: builds static client-side search assets; whether the site still uses them: unsure.
- `lecture-pipeline/scripts/usage_log.py`, `usage_report.py`: log and report model usage and cost.
- `embeddings/app.py`, `warmup.py`: the embedding service; the model is baked into its image at build.
- `scripts/translate_captions.py`: translates caption files to English (Gemini).
- `scripts/analyze_transcripts.py`: plans articles and video notes from translated transcripts.
- `scripts/create_manifest.py`: writes the manifest and summary of planned articles for review.
- `scripts/generate_articles.py`: generates article drafts from the analysed transcripts.
- `scripts/docx_to_article.py`: turns a Word document into an article with front matter (Gemini).
- `scripts/summarize_publications.py`: writes one-paragraph summaries into `tsr-publications.md` (Gemini).
- `sync-wp-articles.js`, `update-articles.js`: one-off WordPress import and HTML-to-Markdown update of the legacy articles.
- Decap CMS at `/admin`: editors commit content to the repository through GitHub.

Application (`tsr-account`):

- `web/cli/reindex_search.php` and `drain_search.php`: fill the application's search index from MariaDB (Table B).
- `tools/geonames/load.php`: loads location reference data.
- `tools/synthetic-data/`: builds synthetic members for development (not production).
- `tools/api-contract/generate_openapi.py`: generates the mobile API's OpenAPI document from the contract file.

## 5. Production services

Website (`tsr-web/docker-compose.yml`):

- `web`: the Next.js site and its API.
- `embeddings`: turns a search query (and, offline, each lecture) into a vector.
- `elasticsearch`: holds the articles index, the lectures index and the search analytics index.

Application (`tsr-account/docker-compose.yml`):

- `mysql`: the MariaDB database of the PHP application.
- `webapp`: the PHP web application (admin and member pages); applies migrations at start.
- `mobileapi`: the same image serving the mobile API site.
- `scheduler`: the same image running cron with the six jobs of Table B.
- `elasticsearch`: the application's search index.
- `redis`: present, with an append-only file; the repo's infra doc says nothing uses it yet.
- `notifier`: the Node service that holds the WhatsApp session and sends messages on request.

The development compose file adds tools that are not production services (database admin page, certificate helper, synthetic data build, Firebase emulator, security scanners).
