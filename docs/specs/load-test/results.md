# Load test of the built API (14 Nov 2026)

The first load test of the built C# API (.NET 11, PostgreSQL 18) on synthetic data of production size. Complete. One laptop, one evening, at most two
repetitions: read "Threats to validity" before quoting any number.
Raw data: `docs/specs/load-test/raw/` (k6 summary `<label>.json`, docker stats `<label>.stats.tsv`, CPU quota counters `<label>.cpustat`, `runs.log` with the host load average after each run).
Scripts: `tools/load/` (`run.sh` the runner, `load.js` the k6 script, `callers.sql`, `callers-php.sql`, `probe.sh`, `summarize.py` which prints every table below from the raw files).

## What this says (short)

- **The API saturates its 2 CPUs at about 10 concurrent users.** The app-opening mix (5 calls) served 287 req/s at 10 users (p95 77 ms), 358 req/s at 50 (p95 255 ms) and fell to 177 req/s at 100 (p95 1.4 s, with 22 errors). 20 users for 15 minutes: 437 req/s, p95 96 ms, no error.
- **A signed-in request costs the API about 6 to 9 ms of CPU**, whatever the route: 7 SQL commands at least (4 for sign-in, 2 for permissions, 1 or more of its own), one HTTP call to the Auth emulator, and 16 or more log entries (about 5 KB of text).
- **Logging is the largest single cost found.** With the log level at Warning and nothing else changed, the mix served 466 req/s at 10 users and 592 at 50 (plus 62% and 65%; one repetition). The image has no logging configuration, so it logs every request and every SQL command at Information, in any environment.
- **The slowest routes** (p95 at 10 users): the registrations report 195 ms, search 151 ms, the class list as a coordinator 142 ms, this week 118 ms, the class list as a super admin 113 ms. The registrations report returns 577 KB of JSON with no paging and takes 4 database cores at 10 users.
- **PDF downloads do not survive 5 at once:** 5 of 100 answered 504 after the gateway's 30 s limit; one alone took 1.5 s at the median and 25 s at worst.
- **Memory is steady:** 320 to 335 MiB over the soak (limit 512), no growth. The registrations report at 50 users pushed it to 386 MiB.
- **The PHP comparison is not valid** and no ratio should be quoted from it (see "PHP comparison").
- **Token verification was not production's.** In emulator mode the API calls the emulator over HTTP on every request; with real Firebase it checks a signature in process. Every signed-in number here includes that call.

## Setup

| Item | Value |
|---|---|
| Machine | MacBook Air (Mac16,13), Apple M4, 10 cores (4 performance, 6 efficiency), 32 GB, fanless, on mains power. OrbStack VM: 10 CPUs, 15.7 GiB. A laptop. |
| Also running | Dev stack, default test stack, lanes 1 to 4, the PHP parity stack, tsr-account's local stack, three more Elasticsearch nodes and others: about 60 containers holding 8.8 GiB before the test, nearly all idle (`raw/host-before.txt`). Host load average 4.3 to 4.9 before the test. None was stopped. The coordinator reported the machine otherwise idle from about half way through. |
| Stack | Lane 5 (`TSR_STACK=5 TSR_LANE_WORKERS=search-feed tools/test-stack.sh up`), branch `dotnet-11` at 49ad475, gateway :8105. Its own Elasticsearch 9.2.3 and the `search-feed` worker; no sending worker. |
| Limits | **api: 2 CPUs, 512 MB** (no swap), set by `tools/load/run.sh limits` through `build/test-5/load.override.yml`. **gateway, db, firebase-emulator, gotenberg, elasticsearch, workers: no limit** (`docker inspect`: NanoCpus 0, Memory 0). |
| API | Image 327 MB (the 9 Nov prototype: 133 MB). .NET 11.0.0, `ASPNETCORE_ENVIRONMENT=Development` (the emulator needs it), no logging setting: default level Information. |
| Database | PostgreSQL 18.6, `shared_buffers` 128 MB, `max_connections` 100, database size 130 MB (all of it fits in memory). |
| Gateway | nginx 1.27, `hosts/gateway/default.conf`: no upstream keep-alive, so one new TCP connection to the API per request (the API logs `HTTP/1.0`). |
| Load generator | k6 v2.3.0 (`grafana/k6`, already on the machine), one container per run inside the lane's network, calling `http://gateway:8080`. Closed model, no think time. Not pinned to cores and not limited. |
| Logging in timed runs | The API's own level (Information). SQL commands were counted on separate single requests (`tools/load/probe.sh`, `raw/sql-probe.tsv`). |

### Data

`tsr_synth_s2` from the parity MariaDB (the generated synthetic set with the two 2026_11_08 migrations; `tsr_synth` itself lacks two tables the load needs), moved with `tools/data-load/load.sh --truncate`; result "every exported row was loaded" (`raw/report-20261114T142146Z.txt`). Read-only on the MariaDB side.

| Table | Rows |
|---|---|
| identity.users (and member profiles) | 26,244 |
| classes.classes | 376 (220 active) |
| classes.class_students (enrolments) | 3,731 (2,571 active) |
| classes.class_sessions | 24,400 |
| classes.class_attendance | 228,000 |
| membership.class_registrations | 4,276 |
| notifications.notifications / user_notifications | 157 / 1,680 |
| assessment.spot_quiz_responses | 237,000 |
| platform.outbound_messages | 709 |
| search index | 24,916 documents (fed after the load) |
| published articles | 12 (the synthetic Library files, loaded by one tick of `content-refresh`) |

The users, sessions and attendance are at production size. The article count is not (12), and 1,680 inbox rows over 1,176 members is thin.

### Callers

482 distinct generated members (`tools/load/callers.sql`, list in `build/test-5/load-callers.json`, git-ignored): 300 enrolled members, 100 teachers, 40 coordinators, 32 gender admins, 50 super admins.
The generated set has one super admin and one admin per gender, so **80 generated members with no class were given an admin role in lane 5's database** (50 super, 15 per gender). Coordinators were not added: the 40 generated ones were used.
k6 signs every caller in at the lane's Auth emulator in `setup()` of each run, so a token is at most 16 minutes old and none is written to disk.

### What token verification costs here, and in production

Confirmed from the code, not assumed:
- **Emulator mode (this test):** emulator tokens are unsigned. The API checks the token's shape, then **POSTs it to the emulator's `accounts:lookup` on every request** (`domains/identity/api/FirebaseVerifier.cs:163-170`, 2 s timeout at :19) to learn the email. PHP does the same against its emulator.
- **Real Firebase:** ASP.NET's JWT bearer handler verifies the RS256 signature in process against Google's keys, fetched once and cached (`FirebaseVerifier.cs:61`, `options.Authority`); the email comes from the token's claims (`FromClaims`, :143). No call per request.
- So this test has an HTTP hop production does not have, and lacks the RS256 check production has. The hop alone: the emulator serves 2,142 lookups/s at 1 user (p50 0.2 ms), 1,749 at 10 (p50 4 ms) and 994 at 50 (p50 30 ms, p95 144 ms) (`raw/control-emulator-lookup-v*.json`). The emulator used 0.5 to 0.8 of a core during signed-in runs and is one Node thread. At 50 users and above it produced the 401 answers listed under "Errors". An RS256 check costs well under 0.1 ms of CPU (not measured here).

## Scenario 1: per route, steady

60 s after a 15 s warm-up, constant users, no think time. Latency in ms. **1 user: one repetition. 10 and 50 users: two** (the third was cut: one pass of 33 runs took 59 minutes); the first figure is the mean of the two, both values in brackets. Repetition 2 ran the routes in reverse order.
CPU% is cores x 100 (the API's limit is 200), the median of samples taken every 4 to 5 s; RSS is the peak. req/s counts the 60 measured seconds only.

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| article | 1 | 1 | 1.1 | 4.0 | 6.9 | 587 | 0.00% | 84 | 163 | 32 | 0 |
| article | 10 | 2 | 9.6 (7.5-11.6) | 36.8 (18.4-55.1) | 114.7 (30.8-198.6) | 771 (436-1105) | 0.00% | 144 (116-171) | 199 (184-215) | 97 (80-114) | 0 (0-0) |
| article | 50 | 2 | 30.9 (27.1-34.6) | 91.3 (75.1-107.6) | 177.6 (131.8-223.5) | 1288 (1085-1490) | 0.00% | 175 (143-208) | 266 (263-270) | 154 (132-176) | 0 (0-0) |
| articles | 1 | 1 | 1.3 | 4.2 | 7.0 | 517 | 0.00% | 88 | 160 | 27 | 0 |
| articles | 10 | 2 | 8.7 (8.6-8.9) | 23.8 (22.5-25.1) | 43.8 (39.0-48.6) | 879 (858-900) | 0.00% | 155 (136-175) | 201 (184-218) | 94 (74-113) | 0 (0-0) |
| articles | 50 | 2 | 40.2 (34.9-45.5) | 108.0 (92.3-123.7) | 201.5 (169.5-233.6) | 1029 (914-1144) | 0.00% | 192 (175-209) | 256 (240-272) | 114 (111-116) | 0 (0-0) |
| class_detail | 1 | 1 | 9.0 | 15.3 | 23.4 | 98 | 0.34% (400: 24) | 58 | 144 | 33 | 14 |
| class_detail | 10 | 2 | 32.9 (30.4-35.5) | 69.2 (59.2-79.3) | 114.9 (89.0-140.9) | 266 (239-293) | 0.34% (400: 127) | 140 (135-145) | 212 (189-234) | 161 (160-163) | 46 (44-47) |
| class_detail | 50 | 2 | 147.3 (128.1-166.5) | 384.8 (297.1-472.5) | 1301.4 (532.6-2070.2) | 274 (218-331) | 0.33% (400: 138, 401: 1) | 191 (177-206) | 259 (249-269) | 249 (247-251) | 65 (65-65) |
| classes_coordinator | 1 | 1 | 14.7 | 30.9 | 62.0 | 56 | 0.00% short bodies: 184 | 61 | 155 | 39 | 11 |
| classes_coordinator | 10 | 2 | 41.6 (32.6-50.6) | 142.2 (112.9-171.4) | 471.9 (191.4-752.3) | 144 (118-170) | 0.03% (401: 2) short bodies: 1119 | 151 (150-151) | 217 (194-241) | 175 (169-182) | 35 (32-37) |
| classes_coordinator | 50 | 2 | 217.9 (207.8-228.1) | 655.2 (518.1-792.4) | 2196.7 (727.5-3665.9) | 170 (141-199) | 0.04% (401: 3) short bodies: 1222 | 214 (207-222) | 255 (244-267) | 253 (250-256) | 56 (55-56) |
| classes_super | 1 | 1 | 12.9 | 20.2 | 30.3 | 71 | 0.00% | 57 | 145 | 43 | 10 |
| classes_super | 10 | 2 | 53.2 (52.1-54.3) | 112.6 (106.8-118.3) | 186.7 (170.1-203.2) | 163 (158-169) | 0.00% | 149 (142-156) | 241 (219-263) | 191 (190-192) | 33 (31-34) |
| classes_super | 50 | 2 | 288.4 (215.8-361.0) | 775.5 (438.7-1112.3) | 2196.0 (631.0-3761.1) | 151 (94-209) | 0.64% (401: 36) | 211 (204-217) | 261 (253-269) | 266 (262-269) | 41 (38-44) |
| me | 1 | 1 | 11.4 | 28.7 | 57.2 | 65 | 0.00% | 60 | 141 | 28 | 15 |
| me | 10 | 2 | 27.8 (20.2-35.4) | 78.0 (50.7-105.2) | 135.5 (93.5-177.5) | 300 (215-384) | 0.00% | 141 (135-147) | 211 (188-234) | 131 (128-134) | 46 (43-48) |
| me | 50 | 2 | 235.0 (153.8-316.1) | 732.6 (522.9-942.3) | 1528.4 (1293.8-1763.1) | 179 (125-233) | 0.00% | 226 (217-235) | 253 (242-264) | 189 (184-194) | 75 (67-82) |
| notifications | 1 | 1 | 8.5 | 15.1 | 24.0 | 104 | 0.00% | 58 | 153 | 28 | 15 |
| notifications | 10 | 2 | 30.5 (29.6-31.4) | 72.6 (71.5-73.7) | 135.5 (126.1-144.8) | 269 (264-274) | 0.00% | 148 (145-151) | 210 (192-229) | 139 (134-144) | 49 (49-50) |
| notifications | 50 | 2 | 119.0 (102.4-135.5) | 317.9 (269.3-366.4) | 622.7 (588.2-657.2) | 341 (297-384) | 0.00% | 195 (193-197) | 256 (247-266) | 225 (221-228) | 65 (64-67) |
| permissions | 1 | 1 | 8.7 | 18.1 | 29.5 | 95 | 0.00% | 55 | 150 | 27 | 17 |
| permissions | 10 | 2 | 24.5 (19.7-29.3) | 59.4 (50.8-67.9) | 102.5 (91.1-113.9) | 338 (280-396) | 0.00% | 132 (127-138) | 208 (183-232) | 118 (116-119) | 51 (50-52) |
| permissions | 50 | 2 | 120.5 (108.4-132.7) | 373.0 (313.3-432.8) | 861.7 (554.0-1169.5) | 306 (256-356) | 0.00% | 199 (198-201) | 254 (243-265) | 184 (175-193) | 80 (75-85) |
| registrations | 1 | 1 | 28.3 | 44.8 | 62.8 | 33 | 0.00% | 35 | 186 | 76 | 5 |
| registrations | 10 | 2 | 105.8 (99.9-111.7) | 195.0 (180.1-209.9) | 272.8 (253.4-292.3) | 85 (81-90) | 0.00% | 121 (121-122) | 250 (225-275) | 413 (405-422) | 20 (20-20) |
| registrations | 50 | 2 | 534.6 (419.8-649.5) | 1119.5 (783.0-1455.9) | 1935.3 (1037.4-2833.2) | 90 (68-113) | 0.00% | 153 (147-159) | 345 (304-386) | 524 (507-541) | 24 (24-25) |
| search | 1 | 1 | 20.6 | 39.1 | 54.0 | 43 | 2.46% (400: 70) | 38 | 177 | 25 | 9 |
| search | 10 | 2 | 65.7 (62.6-68.7) | 150.8 (148.8-152.9) | 248.8 (244.3-253.3) | 130 (129-131) | 2.42% (400: 444) | 124 (123-125) | 222 (205-239) | 137 (136-138) | 30 (29-31) |
| search | 50 | 2 | 241.9 (219.8-263.9) | 513.5 (470.9-556.0) | 823.8 (783.7-863.9) | 183 (165-201) | 2.45% (400: 608) | 165 (162-169) | 264 (253-274) | 207 (201-212) | 43 (43-43) |
| this_week | 1 | 1 | 13.3 | 22.9 | 40.8 | 65 | 0.00% | 55 | 142 | 44 | 11 |
| this_week | 10 | 2 | 53.7 (49.8-57.6) | 118.1 (96.5-139.6) | 180.8 (142.5-219.1) | 162 (145-178) | 0.00% | 140 (140-140) | 222 (199-244) | 205 (202-208) | 34 (32-35) |
| this_week | 50 | 2 | 241.0 (189.1-292.9) | 557.5 (383.8-731.1) | 908.9 (661.5-1156.2) | 190 (146-234) | 0.00% | 196 (181-211) | 261 (251-270) | 307 (301-313) | 44 (44-45) |

Routes: `me` GET /me (all 482 callers); `permissions` GET /me/permissions; `classes_coordinator` and `classes_super` GET /classes?include=managed; `class_detail` GET /classes/{id} as an enrolled member; `this_week` GET /reports/this-week (admins); `notifications` GET /user/notifications?limit=20 (the inbox call the app makes); `search` GET /search?q=fe (admins: a member's search of this data finds nothing); `registrations` GET /reports/registrations (admins); `articles` and `article` GET /api/v1/articles and one article (public, no sign-in).

Reading:
- From 1 to 10 users throughput rises 2.5 to 5 times; from 10 to 50 it does not rise, and latency grows 4 to 5 times. The API is at its CPU limit (200%) at 50 users; the cgroup counters show the quota stopping it in 253 of 788 periods during `me` at 50 users (`raw/route-me-v50-r2.cpustat`).
- At 1 user the API uses 0.55 to 0.6 of a core for 65 to 104 req/s: 6 to 9 ms of API CPU per signed-in request. The public article routes cost about 1.5 ms.
- The two repetitions differ by up to 1.8 times (`me` at 10 users: 215 and 384 req/s). Treat any difference under a factor of 2 between routes as unproven.

## Scenario 2: the app-opening mix

One member per iteration calls, in order, GET /me, /me/permissions, /classes?include=managed, /user/notifications?limit=20, /user/notifications/unread-count (what the app calls on opening: tsr-account `tools/perf/k6/smoke.js` STARTUP). 300 members, 3 minutes per level after a 15 s warm-up, one repetition. req/s is requests, not app openings (divide by 5).

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | 10 | 1 | 25.8 | 77.2 | 177.8 | 287 | 0.00% | 155 | 228 | 135 | 53 |
| - me | 10 | 1 | 27.0 | 79.7 | 181.0 | 57 | 0.00% | 155 | 228 | 135 | 53 |
| - permissions | 10 | 1 | 21.8 | 64.8 | 161.6 | 57 | 0.00% | 155 | 228 | 135 | 53 |
| - classes_member | 10 | 1 | 30.5 | 87.8 | 199.1 | 57 | 0.00% | 155 | 228 | 135 | 53 |
| - notifications | 10 | 1 | 26.9 | 78.8 | 182.0 | 57 | 0.00% | 155 | 228 | 135 | 53 |
| - unread_count | 10 | 1 | 23.5 | 70.7 | 158.2 | 57 | 0.00% | 155 | 228 | 135 | 53 |
| mixed | 50 | 1 | 123.8 | 255.3 | 385.0 | 358 | 0.00% | 210 | 269 | 200 | 72 |
| - me | 50 | 1 | 130.6 | 262.9 | 397.2 | 72 | 0.00% | 210 | 269 | 200 | 72 |
| - permissions | 50 | 1 | 103.5 | 214.3 | 334.0 | 72 | 0.00% | 210 | 269 | 200 | 72 |
| - classes_member | 50 | 1 | 142.7 | 283.5 | 425.4 | 72 | 0.00% | 210 | 269 | 200 | 72 |
| - notifications | 50 | 1 | 131.2 | 266.1 | 397.1 | 72 | 0.00% | 210 | 269 | 200 | 72 |
| - unread_count | 50 | 1 | 112.5 | 229.6 | 352.0 | 72 | 0.00% | 210 | 269 | 200 | 72 |
| mixed | 100 | 1 | 398.0 | 1413.3 | 3063.2 | 177 | 0.06% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |
| - me | 100 | 1 | 420.9 | 1488.2 | 3321.5 | 35 | 0.06% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |
| - permissions | 100 | 1 | 318.8 | 1183.7 | 2601.6 | 35 | 0.03% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |
| - classes_member | 100 | 1 | 455.1 | 1540.5 | 3192.8 | 35 | 0.08% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |
| - notifications | 100 | 1 | 420.8 | 1462.5 | 3402.9 | 35 | 0.09% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |
| - unread_count | 100 | 1 | 368.4 | 1318.9 | 2892.3 | 35 | 0.05% (401: 20, 500: 2) | 229 | 284 | 209 | 75 |

## Scenario 3: heavy routes, 1 and 5 users, 20 requests each

No warm-up; no req/s (the runs are too short). One super admin pool for the reports; with 20 requests p95 is the second slowest request.

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mis | 1 | 1 | 192.7 | 771.0 | 1169.3 | n/a | 0.00% | 41 | 306 | 7 | 14 |
| mis | 5 | 1 | 92.4 | 262.5 | 362.4 | n/a | 0.00% | 126 | 372 | 113 | 71 |
| pdf | 1 | 1 | 1531.6 | 7139.0 | 21756.9 | n/a | 0.00% | 1 | 330 | 7 | 1 |
| pdf | 5 | 1 | 5980.7 | 15634.2 | 30086.4 | n/a | 5.00% (504: 5) | 2 | 372 | 11 | 1 |
| write | 1 | 1 | 92.1 | 908.7 | 1298.5 | n/a | 0.00% | 14 | 325 | 1 | 0 |
| write | 5 | 1 | 66.9 | 147.4 | 173.8 | n/a | 0.00% | 218 | 372 | 132 | 41 |
| xlsx | 1 | 1 | 385.7 | 1289.0 | 4793.9 | n/a | 0.00% | 163 | 332 | 29 | 1 |
| xlsx | 5 | 1 | 602.7 | 1210.4 | 1957.7 | n/a | 0.00% | 220 | 379 | 44 | 3 |

| Route | What | min / p50 / p95 / max at 1 user (ms) | at 5 users (ms) |
|---|---|---|---|
| xlsx | GET /reports/registrations/download?format=xlsx (136 KB) | 195 / 386 / 1,289 / 5,670 | 128 / 603 / 1,210 / 1,975 |
| pdf | the same with format=pdf (436 KB, rendered by Gotenberg) | 990 / 1,532 / 7,139 / 25,411 | 1,786 / 5,981 / 15,634 / 30,089, **five 504** |
| mis | GET /reports/tsr (the MIS report, default dates, 36 KB) | 99 / 193 / 771 / 1,269 | 31 / 92 / 262 / 378 |
| write | PATCH /me with a city, by a teacher | 42 / 92 / 909 / 1,396 | 34 / 67 / 147 / 179 |

The 1-user runs started seconds after the 100-user mix and are slower than the 5-user runs that followed; their tails are suspect. The medians are usable, the 1-user p95 and max are not.
**Left behind by the write:** 6 teachers in lane 5 have the city "Load Test City". No outbox row was written.

## Scenario 4: soak, the mix at 20 users for 15 minutes

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | 20 | 1 | 35.8 | 95.8 | 194.7 | 437 | 0.00% | 161 | 344 | 191 | 58 |
| - me | 20 | 1 | 37.3 | 99.3 | 203.6 | 87 | 0.00% | 161 | 344 | 191 | 58 |
| - permissions | 20 | 1 | 30.2 | 81.4 | 166.9 | 87 | 0.00% | 161 | 344 | 191 | 58 |
| - classes_member | 20 | 1 | 41.5 | 106.3 | 212.6 | 87 | 0.00% | 161 | 344 | 191 | 58 |
| - notifications | 20 | 1 | 37.4 | 99.1 | 202.5 | 87 | 0.00% | 161 | 344 | 191 | 58 |
| - unread_count | 20 | 1 | 32.7 | 88.2 | 183.1 | 87 | 0.00% | 161 | 344 | 191 | 58 |

| Time (UTC) | API memory | Connections of the API's database role |
|---|---|---|
| 16:38:23 | 373MiB / 512MiB | 85 total, 0 active |
| 16:41:25 | 334.8MiB / 512MiB | 27 total, 2 active |
| 16:44:27 | 333.8MiB / 512MiB | 20 total, 4 active |
| 16:47:29 | 321.2MiB / 512MiB | 21 total, 1 active |
| 16:50:31 | 318.4MiB / 512MiB | 21 total, 6 active |
| 16:53:33 | 324.8MiB / 512MiB | 20 total, 6 active |
| 16:53:47 | 319.4MiB / 512MiB | 20 total, 0 active |

393,145 requests, no error. API memory did not grow (373 MiB at the start was left by the 100-user and heavy runs just before; 319 MiB at the end). Connections settled at 20 to 21 for 20 users. The 85 at the start are the pool left open by the 100-user run: the pool's default ceiling is 100 and PostgreSQL's `max_connections` is also 100, shared with the workers container.
The Auth emulator's memory grew from 171 to 419 MiB during the soak (it is a test tool, not part of production).

## Controls

### Logging at Warning (one repetition, API limits unchanged)

`LOAD_LOG_LEVEL=Warning tools/load/run.sh limits` sets `Logging__LogLevel__Default=Warning` and recreates the API; no code change.

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | 10 | 1 | 18.7 | 39.0 | 63.2 | 466 | 0.00% | 123 | 206 | 142 | 48 |
| mixed | 50 | 1 | 69.2 | 163.9 | 273.6 | 592 | 0.00% (401: 1) | 191 | 245 | 252 | 76 |

Against the same mix at the API's own level: 287 to 466 req/s at 10 users (p95 77 to 39 ms), 358 to 592 at 50 (p95 255 to 164 ms).
Four single routes were also run at Warning straight after the container was recreated (`raw/nolog-route-*`): `me` 295 req/s, `permissions` 339, `articles` 720, `notifications` 80 with two 401. They show no gain, and `notifications` is far below its normal 269. They ran on a process less than 7 minutes old, so they mix the logging change with a cold JIT; the cause of the `notifications` figure was not found. The mix ran after them and is the fairer reading, but it is one repetition.

### No CPU or memory limit on the API (one repetition, the API's own logging)

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | 10 | 1 | 20.5 | 52.0 | 97.4 | 391 | 0.00% (401: 1) | 140 | 218 | 129 | 51 |
| mixed | 50 | 1 | 87.2 | 186.6 | 296.6 | 504 | 0.00% | 244 | 276 | 234 | 73 |

Without the limit the mix gained 36% at 10 users and 41% at 50, and the API took 2.4 cores at most. Logging costs more than the limit does.

## After two fixes (one repetition, same lane, same limits, later on 14 Nov 2026)

Fixed in the code after the runs above: the API's default log levels (`hosts/api/HostLogging.cs`: the framework at Warning),
and the gateway's wait on the 21 report download routes (70 s, `hosts/gateway/default.conf`). Raw files: `raw/fixed-*`.

| Run | Before | After |
|---|---|---|
| mix, 10 users | 287 req/s, p95 77 ms | 293 req/s, p95 72 ms |
| mix, 50 users | 358 req/s, p95 255 ms | 419 req/s, p95 245 ms |
| PDF, 5 at once, 100 requests | 5 answers of 504 from the gateway at 30 s | 5 answers of 503 from the API at 30 to 34 s |

- **Logging:** the fix works (no SQL command line in the API's log during the run; 22 lines in all). The gain measured here is
  2% at 10 users and 17% at 50, far below the 60% of the control run above. Both are single runs on a machine whose
  repetitions differ by up to 1.8 times, so neither figure is established; the direction is.
- **PDF:** the gateway is no longer what gives up. The renderer itself answers 503 after its own 30 s limit (Gotenberg's
  default request timeout), below the API's 60 s. Five PDFs at once still queue behind one renderer, and 5 of 100 still fail.
  Open: raise the renderer's limit to match the API's, and decide how many renders may run at once.

### The renderer's limit raised to 60 s (one run, 15 Nov 2026)

`docker-compose.dev.yml` now starts Gotenberg with `--api-timeout=60s` (its default is 30 s). PDF, 5 at once, 100
requests (`raw/fixed2-heavy-pdf-v5.json`): **no failure**, p50 1.4 s, p95 2.6 s, slowest 7.7 s.

This run does not prove the new limit: no render came near 30 s, where the two earlier runs had medians of 6 and 11 s.
The same route on the same data was about eight times faster this time, so the earlier slowness had another cause that
was not found (the machine was busier then; a cold renderer is another candidate). What the change guarantees is only
that a render slower than 30 s is no longer refused by the renderer before the API's own 60 s limit.

## PHP comparison: made, not valid

The same k6 script ran against the PHP parity stack (`LOAD_TARGET=php`, inside its network, its own emulator, the parity lock held for one run at a time), with lane 5's API recreated without limits because the shared PHP container has none and `docker update` cannot take a limit off again without recreating it.

| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mixed | 10 | 1 | 203.5 | 569.4 | 818.0 | 39 | 0.00% | 19 | 43 | 134 | 7 |
| mixed | 50 | 1 | 1078.4 | 1414.9 | 3164.6 | 46 | 0.00% | 14 | 101 | 133 | 9 |

("API CPU%" here is the PHP container.) PHP served 39 to 46 req/s with its own container at 0.14 to 0.19 of a core and MariaDB at 1.3 cores. **This measures the parity database, not PHP:** `tsr_synth` is built from the generator's old schema and has no index on `users.email`, on `class_students` or on `classes.teacher` (checked in `information_schema.statistics`), indexes production has (tsr-account migrations of 28 Oct). PHP's per-request `UPDATE users ... WHERE email` scans 26,757 rows. The 9 Nov benchmark had to add these indexes to its own copy for the same reason. Adding them here means writing to the shared `tsr_synth`, which this task may not do.
Other differences: `tsr_synth` has 491 classes against 376 in lane 5 (contract fixtures were added since the copy), MariaDB against PostgreSQL, and admin pools drawn from contract fixtures on the PHP side.
The per-route PHP runs were not made: a shell mistake lost that loop, and after the result above they would have measured the same missing indexes.
**Side effect on the shared stack:** signing in made PHP stamp `firebase_uid` and the last sign-in on about 360 members of `tsr_synth` (300 generated members, the fixture admins) and created their accounts in the parity emulator's memory. Nothing else was written there, and no setting of the parity stack was changed.

## Findings: the slowest five routes

SQL commands are per request, counted from the API's log on one request each (`raw/sql-probe.tsv`). Every signed-in request starts with the same six: the deleted-account check, the member by uid, the live deletion request and the `UPDATE` of the last sign-in (`domains/identity/api/CallerMiddleware.cs:58-86`, `domain/MemberDirectory.cs:21,69,88`), then two for the permissions revision header (`domains/access/api/PermissionsRevisionHeader.cs:40`, `Permissions.cs:147`).

| # | Route | p95 at 10 / 50 users | SQL commands | Why (my reading) |
|---|---|---|---|---|
| F1 | GET /reports/registrations | 195 / 1,120 ms | 7 | One query (`domains/membership/api/domain/WaitingRegistrations.cs:54`) groups all 4,276 registrations by token with 14 `max()` columns, joins users, profiles and classes, and returns every waiting person of the gender: about 1,300 rows, **577 KB of JSON, no paging** (limit 5,000 at :20). 25 ms to execute and 5 ms to plan in the database, each time. At 10 users the database used 4.1 cores for 85 req/s, and at 50 the API reached 386 MiB. PHP returns the same list. |
| F2 | GET /search?q=fe | 151 / 514 ms | 6, plus Elasticsearch | No query of its own in PostgreSQL; the time is the six shared commands, up to five permission checks (`domains/search/api/features/search/Search.cs:58-76`) and the Elasticsearch call. A single request took 190 ms when the index was cold. 2.4% answered 400 "User gender not set": two generated admins have a non-numeric gender, as PHP would answer. |
| F3 | GET /classes?include=managed, coordinator | 142 / 655 ms | 14 | The most commands of any route measured: the class query (`domains/classes/api/features/classes-list/ClassesList.cs:84`), slots, details and tags (:49-51, :117, :130), and more reach lookups for a coordinator than for a member (10). Its answer is small (407 bytes); the cost is the count of round trips. Some of the 40 coordinators reach no class and get an empty list (the "short bodies" in the table; not errors). |
| F4 | GET /reports/this-week | 118 / 558 ms | 12 | Six queries of its own over every class in reach (`domains/classes/api/features/report-this-week/ReportThisWeek.cs:66-76`, SQL at :104, :119, :148, :169), 52 KB answer; the database used 2 cores at 10 users. |
| F5 | GET /classes?include=managed, super admin | 113 / 776 ms | 10 | The same slice as F3 returning all 220 active classes: 90 KB, no paging (limit 5,000, `ClassesList.cs:19`). At 50 users 36 requests answered 401 (the emulator's 2 s limit). |

Findings that are not one route:

- **F6. Logging at Information in every environment.** No `appsettings.json` and no level in `hosts/api/Program.cs`, so each request writes 2 hosting entries, 2 endpoint entries, 1 result entry, one per SQL command **with the full SQL text**, and 4 for the emulator call: 16 entries and 4.9 KB for the lightest signed-in route, 21 for a class detail. Parameter values are masked (`'?'`), so no member value is logged. Cost: about 40% of throughput (control above). At 300 req/s Docker's log rotation (5 files of 20 MB) keeps about two minutes of history, which is why the two 500 answers below could not be traced. The 9 Nov review found the same thing in the prototype (B2).
- **F7. Six SQL commands before any route runs**, one of them an `UPDATE` of the caller's row on every request (PHP does the same; it is copied behaviour). It is the floor of every signed-in route: `unread-count` is 7 commands for one count.
- **F8. PDF downloads queue behind one renderer and outlive the gateway.** The API waits up to 60 s for Gotenberg (`domains/platform/api/PlatformModule.cs:47`); the gateway gives up at 30 s (`hosts/gateway/default.conf:15`). Five at once: 5% 504, p50 6 s.
- **F9. Throughput falls past saturation.** 100 users got half the throughput of 50, with 401 and 500 answers. Nothing sheds load; the pool can take all 100 database connections.
- **F10. The gateway opens a new connection to the API per request** (no `proxy_http_version 1.1` and keep-alive in the upstream). Its cost was not isolated.

## Errors seen

| Where | Status | Count | Cause |
|---|---|---|---|
| `class_detail`, every level | 400 | 0.33% | Members whose stored gender is not numeric ("Male", "Female", empty): copied PHP behaviour, a property of the data. |
| `search`, every level | 400 | 2.4% | The same, for two of the 82 admin callers. |
| `classes_super` 50 users (36), `classes_coordinator` (5), `class_detail` (1), mix at 100 users (20), Warning-level runs (3), unlimited mix (1) | 401 | 66 in all | "Invalid auth token": the emulator lookup passed its 2 s limit while the host was saturated. An artefact of emulator mode; real Firebase has no such call. Inferred from the code path and the timing, not read from the log (rotated away). |
| Mix at 100 users | 500 | 2 | Not identified: the log had rotated. Candidates are the 5 s command timeout (`shared/api/DomainContexts.cs:20`) and connection exhaustion. |
| PDF at 5 users | 504 | 5 of 100 | F8. |
| `classes_coordinator` | none | "short bodies" | Not errors: coordinators who reach no class get an empty list, below the script's 50-byte check. |

No other failure in about 1.9 million measured requests (all runs, the controls and the PHP runs included).

## Cold start, idle memory

`tools/load/run.sh cold`, three restarts of the API container (`raw/cold.tsv`), measured from the host through the gateway's published port:

| | Try 1 | Try 2 | Try 3 |
|---|---|---|---|
| `docker restart` to the first 200 of GET /health (includes stopping the old process) | 0.92 s | 0.92 s | 1.01 s |
| First request that reads the database (GET /api/v1/articles) | 402 ms | 426 ms | 552 ms |
| Second, third | 20, 22 ms | 19, 25 ms | 18, 30 ms |
| Memory 12 s later, after those 4 requests | 77 MiB | 72 MiB | 72 MiB |

Not measured: memory of a process that has served nothing, the first signed-in request after a start, and a long idle. A process stays slower than a warm one for some minutes after a start (see the Warning-level route runs).

## Threats to validity

- **One fanless laptop, everything on it.** k6, the API, PostgreSQL, the emulator, the gateway and Elasticsearch share 4 performance and 6 efficiency cores with about 55 other containers. The host load average after a run averaged 7 at 1 user, 21 at 10 and 31 at 50, and peaked at 92. At 50 users and above the machine, not only the API, was saturated: those rows are a floor for latency and say little about the API alone. No thermal log was kept.
- **Two repetitions at most, one at 1 user and for every scenario after the first.** The two repetitions differ by up to 1.8 times. The "median" of two is their mean. Nothing here supports a claim finer than a factor of 2.
- **Other work on the machine changed during the test.** Other agents were active early on; the coordinator reported it idle later. Repetition 1 at 50 users ran at load averages of 21 to 43; repetition 2 was faster on most routes. One `docker logs` read of mine overlapped `articles` at 50 users in repetition 1.
- **The emulator is in every signed-in number** and is not production's verification (above). It is one thread and used up to 0.85 of a core; it caused the 401 answers.
- **Only the API is limited.** The database took up to 5.4 cores. A production server that gives PostgreSQL fewer cores will do worse on F1 and F4.
- **Closed-loop load with no think time.** "50 users" here means 50 requests always in flight, far more than 50 people with phones. Queueing is hidden (coordinated omission); an open-model run at a realistic arrival rate was not made.
- **Development environment.** The emulator needs `ASPNETCORE_ENVIRONMENT=Development`. The logging level is the same in Production (no configuration exists), but other Development-only costs, if any, were not looked for.
- **Data.** Generated, at production size for users, sessions and attendance; 12 articles and a thin inbox. 80 members were given admin roles. The database is 130 MB and never touches disk for reads. Real data has longer text and skew the generator lacks.
- **Callers.** 40 coordinators and 50 super admins at 50 users means two requests at a time for some rows, so the per-request `UPDATE` of the caller's row can wait on itself. Not measured apart.
- **docker stats** is sampled every 4 to 5 s and itself uses CPU; CPU% is a median of about 12 samples.
- **Heavy runs** are 20 or 100 requests with no warm-up, and the 1-user ones followed an overload.
- **The logging and no-limit controls are one repetition each**, on a recreated process. The direction (logging costs a lot) is clear from two levels agreeing; the size (about 60%) is not firm.
- **The PHP figures are invalid** as a comparison (missing indexes).
- **Not verified against a real service:** Firebase, FCM, Sheets, WhatsApp. Nothing that sends outward was run.

## What this says

1. On 2 CPUs the built API serves the app-opening mix at roughly 300 to 450 req/s (60 to 90 app openings a second) with p95 under 100 ms up to 20 users in flight, and holds that for 15 minutes with flat memory and no error. Beyond that it queues, and at 100 in flight it degrades instead of holding.
2. This is 5 to 8 times below the 9 Nov prototype's 1,950 to 2,260 req/s on `/me`. The two are not the same work: the prototype had stubbed auth, 11 raw statements and no EF; the built API has the emulator call, EF Core, the permissions header and full logging. This test does not say how much each contributes, except logging (about 40% of throughput).
3. The cheapest improvement the data points to is the log level (F6). The next candidates are the six commands before every route (F7), the unpaged registrations report (F1) and the PDF path (F8). None was changed here: this task measures.
4. Nothing here says whether the new API is faster or slower than PHP. That needs a PHP database with production's indexes.
5. For a service whose routes are mostly lightly used, the 1-user rows matter most: p50 8 to 15 ms and p95 15 to 31 ms for the app's calls, 28 ms and 45 ms for the largest report, through the gateway with the emulator call included.

## State left

- Lane 5 is up (`tsr-app-test-5`, gateway :8105), API at 2 CPUs and 512 MB with its own logging, synthetic data loaded, search index fed. `tools/test-stack.sh up` on lane 5 would drop the limit and the override; run `TSR_STACK=5 tools/load/run.sh limits` after it.
- Lane 5's database differs from the loaded set by: 80 admin roles, 6 teachers' city, sign-in stamps on the callers, 12 articles.
- The parity stack: the sign-in stamps described above; its lock is released.
- Nothing committed. New: `tools/load/`, `docs/specs/load-test/`. Git-ignored: `build/test-5/`, `build/parity-php/load-callers.json`, `build/load-*.log`.

## To repeat

```
TSR_STACK=5 TSR_LANE_WORKERS=search-feed tools/test-stack.sh up     # then load tsr_synth_s2 with tools/data-load (see tools/patrol-lane.sh reset)
TSR_STACK=5 tools/load/run.sh limits && TSR_STACK=5 tools/load/run.sh content && TSR_STACK=5 tools/load/run.sh callers
TSR_STACK=5 tools/load/run.sh routes 1        # also: mixed 1, heavy, soak, cold; one MODE ROUTE VUS LABEL [SECONDS]
uv run python tools/load/summarize.py
```
Run it from bash, and do not edit `run.sh` while it runs (bash reads the file as it goes).
