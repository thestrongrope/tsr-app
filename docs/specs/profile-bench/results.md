# Profile benchmark results: PHP vs C# vs Go (2026-11-09)

## FrankenPHP (1 rep, 2026-11-09)
tsr-account's PHP API under FrankenPHP 1.13.5 / PHP 8.5.12, classic and worker mode, same contract and k6 script. Contract 20/20 on both; worker-mode state-leak check (about 97k mixed-user requests) found 0 mismatches. `/me` req/s at 10 and 50 VUs: classic 1109 / 443, worker 1479 / 1468 (Apache PHP 582 / 263). Classic is limited by ephemeral-port exhaustion from per-request DB connections, which probably also depresses the Apache PHP numbers above; worker mode needed persistent PDO connections and 5 other spike-copy changes. Full report: `spikes/profile-bench/frankenphp/RESULTS.md`.

## C# follow-up: raw vs EF Core vs file-based (1 rep)
Run 2026-11-09, one rep only (the main report uses 3). With 1 rep, differences under about 20-30% are noise. Raw data and script: `spikes/profile-bench/bench/raw-csharp/` (`bench/csharp-e3.sh`). Same machine, k6 settings, token set and 60 s runs (5 s ramp, 30 s warm-up at 10 VUs per route) as the main run; each stack ran alone (the other two C# app containers stopped, DB and non-C# stacks left up, idle). The 1 VU level was not run. Contract: 20 passed, 0 failed on 4106, 4111 and 4112.

Stacks: raw C# (`csharp`, MySqlConnector, 2 CPU / 512 MB), EF Core (`csef`, hand-written SQL via `Database.SqlQuery`, AsNoTracking, Oracle MySql.EntityFrameworkCore 10 on the **MySql.Data** driver), file-based (`csfile`, one `app.cs`, NativeAOT, MySqlConnector).

**Confound:** EF uses a different driver (MySql.Data, not MySqlConnector), because Pomelo has no EF Core 10 release. The EF gap therefore includes the driver change and cannot be attributed to EF Core alone.

Load, req/s and latency in ms (p50 / p95 / p99), 0 errors in every run:

| Route, VUs | raw C# | EF Core | file-based AOT |
|---|---|---|---|
| `/me`, 10 | 2165 req/s, 4.1 / 5.5 / 6.6 | 1298, 6.7 / 9.7 / 16.4 | 1891, 4.7 / 6.3 / 7.3 |
| `/me`, 50 | 2893, 14.9 / 25.9 / 32.6 | 1713, 21.8 / 50.0 / 55.3 | 2441, 16.4 / 36.0 / 41.6 |
| `/me/permissions`, 10 | 1948, 4.5 / 6.6 / 8.7 | 1281, 6.3 / 12.3 / 24.5 | 1885, 4.7 / 6.1 / 7.2 |
| `/me/permissions`, 50 | 2546, 17.1 / 28.1 / 37.8 | 1628, 21.8 / 54.8 / 60.5 | 2440, 16.6 / 35.0 / 40.3 |

Cold start (3 tries each; `docker compose restart` until the first 200, polled every 20 ms) and sequential `/me` latency afterwards. The "request 1" below is the request after the polling one, so the true first request is already included in the restart time.

| | raw C# | EF Core | file-based AOT |
|---|---|---|---|
| Restart to first 200 (s) | 0.477 / 0.462 / 0.458 | 0.664 / 0.668 / 0.697 | 0.277 / 0.291 / 0.292 |
| Req 1, 2, 10, 100 (ms), try 1 | 6.3, 5.2, 4.0, 3.4 | 7.5, 6.7, 5.1, 5.6 | 3.7, 3.1, 3.5, 2.7 |
| Req 1 (ms), tries 2 / 3 | 6.5 / 7.3 | 15.7 / 7.5 | 2.9 / 2.5 |

Memory and size:

| | raw C# | EF Core | file-based AOT |
|---|---|---|---|
| Idle RSS, 12 s after restart, no load (MiB) | 14.9 | 14.5 | 9.5 |
| RSS right after the load run (MiB) | 106.0 | 172.7 | 86.6 |
| Image size | 133 MB | 147 MB | 29.4 MB |
| Non-blank LOC (from the stack notes) | 686 | 635 | 470 |

Reading: EF Core (on MySql.Data) is the slowest, about 40% below raw C# on throughput at 50 VUs; file-based AOT is about 15-20% below raw C# at 50 VUs (near the noise band at 10 VUs on `/me/permissions`), with the fastest start, the smallest image and the lowest memory. Memory after load is a single sample taken straight after the last run, so it also reflects GC timing.

Status: complete. This is the clean re-run: PHP, C#, Go (a), Go (b), Python A and Python B, both routes, 1, 10 and 50 VUs, 3 reps each, one stack's app containers up at a time, on a quiet host (Python ran about 2 hours after the others, same method) (other VMs and apps closed). An earlier 2-rep run on a busier host is kept in Appendix A; where they disagree, trust this one. Raw data: `spikes/profile-bench/bench/raw-clean/` (earlier run: `raw/`). Analysis script: `bench/an2.py`.

## Method
- Machine: Apple M4, 10 cores, 32 GB, OrbStack (Docker VM: 10 CPUs, 15.7 GB). One machine, nothing else tuned.
- Stacks: Python A (CPython 3.13, FastAPI, uvicorn 2 worker processes, asyncmy, 2 CPU / 512 MB) and Python B (free-threaded CPython 3.14, 1 process, 2 threads each with its own uvicorn loop, 2 CPU / 512 MB), see `python/NOTES.md`; PHP (Apache mod_php 8.5, 2 CPU / 512 MB), C# (2 CPU / 512 MB), Go 4 services (gateway .4, identity .6, access .6, classes .4 CPU = 2 CPU total; 480 MB total). One shared MariaDB 11.4 (`tsr_synth`, ~26k users, buffer pool 128 MB, max_connections 151, no CPU limit).
- k6 (grafana/k6 image) runs inside the `tsr-bench_default` network against the container names, the same way for all stacks (no host port-forward in the path). Script: `spikes/profile-bench/bench/load.js` (copy of the contract script; it needed always-true thresholds on the duration and request metrics, otherwise k6 could not build the summary).
- Per stack and route: 30 s warm-up at 10 VUs, then 1, 10, 50 VUs, 60 s each (5 s ramp excluded), constant VUs, no sleep, three repetitions, median and (min-max) reported. Users: the four 200-OK synthetic users (member, teacher, assigned, admin). The two others (pending delete only works on `/me`; token 0 gives 403) would count as errors, so they were left out.
- `docker stats` sampled about every 7 s (slow: each call takes seconds). CPU% is in cores x 100 (200% = 2 cores). Scripts: `spikes/profile-bench/bench/`.
- Go variant (b), CPU limits removed (memory kept): `spikes/profile-bench/go/docker-compose.nolimit.yml`; verified `NanoCpus=0` on all four containers. Variant (a) runs and (b) runs happen with the other two stacks' app containers stopped; the DB stays up.
- Only the 5 s ramp, not the 30 s warm-up, precedes each level; one 30 s warm-up at 10 VUs ran per stack and route.

## DB fixes applied (bench DB only)
The synthetic schema had only PK plus a few keys. Applied from tsr-account/migrations, unchanged:
- `2026_10_28_users_email_index.sql` (`idx_users_email`)
- `2026_10_28_class_students_class_id_index.sql` (`idx_cls_class`)
- `2026_10_28_class_students_token_no_index.sql` (`idx_cls_token_no`)
Compared and found already present: users firebase_uid and token, account_deletion_requests (token, contact_email, status), role_permissions, user_permissions, permissions. No migration exists for `classes.teacher` or `class_access.token`, so those stay unindexed (as in tsr-account). Contract test after: 20 passed, 0 failed on 4105, 4106 and 4107.

## SQL parity (user 20250, one request per route, general log filtered by client IP)
All three run 11 statements per route, same SQL text (only literal quoting differs: PHP sends strings in quotes, C#/Go send some ints bare). PHP also opens about 7 connections (7 `SET NAMES`), the others one pooled connection per service.

| # | Statement | PHP | C# | Go |
|---|---|---|---|---|
| 1 | deletion check (completed, by email) | 1 | 1 | 1 |
| 2 | `SELECT * FROM users WHERE firebase_uid` | 2 | 2 | 2 |
| 3 | deletion gate by token | 3 | 3 | 3 |
| 4 | `UPDATE users ... WHERE email` | 4 | 4 | 4 |
| 5 | users id/token/roleid | 5 (6 on `/me`) | same | same (5) |
| 6-9 | taught, flagged, assigned, enrolled | 6-9 | 6-9 | 6-9 |
| 10 | stored permissions union | 10 | 10 | 10 |
| 11 | catalog `select name from permissions` | 11 on `/me/permissions`; 5 on `/me` (first) | same as PHP | last on both routes |

Difference: on `/me`, Go runs the catalog query last, not first (known deviation in its NOTES). Counts are equal. Go spreads the statements over three services (identity 4, classes 4, access 3 on `/me`).

## Results (clean run, median and (min-max) of 3 reps)
Latency ms. App CPU = summed app containers, cores x 100 (200 = 2 cores); RSS = peak summed MiB; DB = MariaDB CPU%. err = worst rep. "load" = macOS load average at the start of the first rep and the end of the last (it includes the benchmark itself and the Docker VM, so it rises with VUs; it was 1.2 before the run began and 3 to 14 during).

### GET /me
| Stack | VUs | p50 | p95 | p99 | req/s | err | App CPU% | RSS MiB | DB CPU% | load start-end |
|---|---|---|---|---|---|---|---|---|---|---|
| PHP | 1 | 0.9 (0.8-0.9) | 3.6 (3.1-3.8) | 4.5 (4.4-4.8) | 788 (742-829) | 0.01% | 93 (89-93) | 79 (48-88) | 12 (8-13) | 3.5-3.2 |
| PHP | 10 | 4.9 (4.9-5.1) | 76.5 (76.2-77.3) | 80.9 (80.6-81.4) | 582 (552-587) | 0.10% | 215 (213-215) | 55 (49-58) | 19 (16-19) | 2.6-3.8 |
| PHP | 50 | 194.0 (100.0-205.8) | 383.2 (305.9-390.3) | 459.3 (396.6-479.1) | 263 (233-340) | 0.33% | 212 (210-214) | 136 (131-158) | 38 (25-67) | 3.0-4.8 |
| C# | 1 | 1.5 (1.5-1.6) | 2.2 (2.0-2.2) | 2.7 (2.6-2.9) | 560 (516-579) | 0.00% | 98 (95-118) | 70 (63-71) | 61 (59-64) | 4.8-5.1 |
| C# | 10 | 4.6 (4.3-4.9) | 6.1 (5.8-7.0) | 7.3 (7.2-9.7) | 1950 (1770-2067) | 0.00% | 150 (146-154) | 76 (71-84) | 306 (304-309) | 3.8-5.9 |
| C# | 50 | 19.4 (18.5-21.8) | 31.0 (26.8-33.4) | 39.0 (31.7-43.2) | 2260 (2023-2430) | 0.00% | 196 (192-198) | 123 (120-126) | 441 (424-448) | 5.3-7.8 |
| Go (a) | 1 | 1.1 (1.0-1.1) | 1.7 (1.6-1.8) | 5.2 (5.2-5.3) | 745 (735-746) | 0.00% | 50 (50-53) | 46 (40-58) | 65 (63-66) | 3.2-4.7 |
| Go (a) | 10 | 3.8 (3.8-4.0) | 6.5 (6.2-6.8) | 8.6 (8.1-9.4) | 2250 (2170-2310) | 0.00% | 163 (161-168) | 49 (41-55) | 263 (259-266) | 2.6-5.6 |
| Go (a) | 50 | 15.1 (14.2-16.5) | 56.7 (53.4-57.7) | 63.2 (60.6-66.3) | 2050 (1910-2255) | 0.00% | 179 (176-179) | 61 (57-64) | 303 (298-304) | 4.8-8.2 |
| Go (b) | 1 | 1.5 (1.2-1.7) | 2.9 (1.8-5.2) | 5.7 (4.8-8.4) | 525 (401-690) | 0.00% | 60 (57-63) | 64 (55-64) | 64 (64-65) | 9.5-6.9 |
| Go (b) | 10 | 7.9 (5.0-8.1) | 12.6 (9.1-13.2) | 15.5 (11.6-16.5) | 1107 (1071-1689) | 0.00% | 223 (212-233) | 63 (55-64) | 223 (222-233) | 4.5-7.0 |
| Go (b) | 50 | 26.8 (23.0-29.2) | 41.7 (40.8-47.6) | 63.2 (48.4-72.6) | 1660 (1491-1760) | 0.00% | 325 (316-330) | 71 (70-73) | 370 (357-383) | 5.4-11.8 |
| Python A | 1 | 1.5 (1.5-1.6) | 1.9 (1.8-2.0) | 2.6 (2.5-2.7) | 590 (561-600) | 0.00% | 50 (49-50) | 121 (115-122) | 51 (50-52) | 4.2-3.8 |
| Python A | 10 | 6.7 (6.2-7.1) | 10.1 (9.4-10.7) | 12.0 (11.6-12.9) | 1336 (1267-1438) | 0.00% | 184 (181-184) | 121 (114-122) | 208 (207-210) | 3.2-6.4 |
| Python A | 50 | 31.1 (30.6-31.8) | 43.4 (40.2-44.0) | 50.1 (45.7-53.1) | 1464 (1401-1469) | 0.00% | 195 (195-196) | 123 (123-125) | 244 (242-249) | 4.5-7.4 |
| Python B | 1 | 52.9 (52.8-52.9) | 60.0 (59.4-60.5) | 63.5 (63.2-64.1) | 17 (17-17) | 0.00% | 13 (13-13) | 136 (98-138) | 9 (9-9) | 3.4-3.9 |
| Python B | 10 | 52.6 (50.3-54.8) | 69.2 (59.9-69.8) | 78.8 (66.7-80.3) | 170 (165-181) | 0.00% | 36 (32-47) | 127 (100-128) | 26 (24-36) | 2.5-3.7 |
| Python B | 50 | 72.4 (65.1-73.5) | 97.2 (93.2-98.7) | 113.0 (106.9-114.0) | 637 (625-693) | 0.00% | 65 (64-68) | 145 (136-145) | 63 (62-64) | 2.9-3.9 |

### GET /me/permissions
| Stack | VUs | p50 | p95 | p99 | req/s | err | App CPU% | RSS MiB | DB CPU% | load start-end |
|---|---|---|---|---|---|---|---|---|---|---|
| PHP | 1 | 0.9 (0.9-0.9) | 2.9 (2.9-4.1) | 4.9 (4.7-5.7) | 746 (678-781) | 0.00% | 84 (83-94) | 78 (44-84) | 20 (17-22) | 4.1-3.6 |
| PHP | 10 | 5.2 (4.8-5.3) | 77.5 (76.2-77.5) | 82.4 (81.2-83.0) | 547 (541-586) | 0.00% | 214 (213-215) | 51 (50-65) | 39 (23-40) | 3.2-4.4 |
| PHP | 50 | 210.4 (208.3-210.6) | 397.0 (392.2-402.0) | 502.5 (498.2-617.0) | 218 (211-222) | 0.00% | 214 (209-214) | 142 (135-155) | 65 (63-68) | 3.5-4.8 |
| C# | 1 | 1.5 (1.5-1.7) | 2.2 (2.2-2.3) | 2.8 (2.6-3.2) | 548 (508-554) | 0.00% | 107 (99-118) | 77 (71-78) | 62 (60-63) | 7.4-4.7 |
| C# | 10 | 4.5 (4.5-4.8) | 6.1 (6.0-6.7) | 7.4 (7.0-8.7) | 1937 (1835-1981) | 0.00% | 160 (147-162) | 82 (80-84) | 318 (305-318) | 4.3-5.9 |
| C# | 50 | 19.4 (18.6-19.7) | 29.4 (29.2-32.7) | 37.4 (35.8-44.9) | 2265 (2265-2295) | 0.00% | 197 (190-199) | 114 (114-123) | 441 (434-442) | 4.8-9.1 |
| Go (a) | 1 | 1.2 (1.1-1.3) | 2.5 (2.3-2.8) | 5.6 (5.5-6.0) | 660 (579-663) | 0.00% | 51 (50-53) | 50 (46-55) | 67 (65-67) | 6.4-4.7 |
| Go (a) | 10 | 5.0 (5.0-5.6) | 8.4 (8.3-10.0) | 12.4 (11.0-14.1) | 1729 (1515-1734) | 0.00% | 166 (160-174) | 48 (48-50) | 262 (246-276) | 4.2-6.2 |
| Go (a) | 50 | 16.5 (15.9-17.7) | 57.6 (56.1-61.5) | 64.4 (62.8-71.0) | 1920 (1728-1998) | 0.00% | 177 (176-177) | 59 (54-59) | 308 (301-310) | 5.2-7.3 |
| Go (b) | 1 | 1.7 (1.4-2.7) | 4.9 (2.6-7.2) | 8.6 (5.4-12.8) | 404 (257-561) | 0.00% | 62 (60-63) | 65 (62-65) | 65 (64-65) | 9.4-7.8 |
| Go (b) | 10 | 8.4 (7.7-13.4) | 14.3 (12.6-21.6) | 17.9 (15.5-28.1) | 1030 (643-1124) | 0.00% | 225 (221-235) | 60 (57-60) | 231 (225-247) | 5.0-9.0 |
| Go (b) | 50 | 31.8 (31.7-66.8) | 50.9 (50.8-163.4) | 62.7 (61.8-341.4) | 1384 (570-1387) | 0.00% | 326 (318-345) | 69 (69-71) | 359 (357-387) | 6.9-14.2 |
| Python A | 1 | 1.5 (1.5-1.6) | 2.0 (1.9-2.0) | 2.7 (2.4-2.8) | 577 (574-603) | 0.00% | 52 (51-52) | 123 (122-124) | 52 (51-52) | 6.6-4.9 |
| Python A | 10 | 7.0 (6.8-8.5) | 10.4 (9.8-12.0) | 12.8 (12.0-14.2) | 1242 (1144-1304) | 0.00% | 188 (152-190) | 124 (123-124) | 211 (170-214) | 3.9-6.7 |
| Python A | 50 | 32.0 (32.0-32.8) | 43.6 (41.4-45.4) | 51.3 (47.5-51.5) | 1409 (1368-1430) | 0.00% | 194 (188-195) | 124 (124-126) | 238 (231-239) | 4.8-7.0 |
| Python B | 1 | 34.6 (31.8-40.0) | 52.5 (52.4-52.6) | 56.4 (56.1-57.3) | 32 (32-32) | 0.00% | 16 (16-17) | 134 (124-143) | 11 (11-11) | 2.5-3.5 |
| Python B | 10 | 40.1 (39.4-40.5) | 52.8 (52.4-53.3) | 58.9 (58.4-59.3) | 340 (335-340) | 0.00% | 41 (41-41) | 132 (126-132) | 31 (31-31) | 2.2-2.6 |
| Python B | 50 | 49.1 (49.0-50.8) | 87.7 (85.4-87.7) | 102.2 (100.6-102.5) | 959 (917-968) | 0.00% | 99 (93-103) | 148 (147-151) | 104 (99-105) | 2.4-3.8 |


### Python B at low concurrency
Python B (free-threaded, 1 process, 2 threads) takes about 50 ms per request on a kept-alive connection at 1 and 10 VUs (17 req/s at 1 VU on `/me`, p50 53 ms), while it takes 3 ms on a fresh connection (curl, one request per connection). A reproduction with curl over one kept-alive connection shows the same 45 ms from the second request on. Python A does 2 to 3 ms in the same test. The 40 ms size suggests a Nagle/delayed-ACK stall on keep-alive connections in the threaded launcher (not diagnosed, not fixed). It matters for real clients, which keep connections alive; at 50 VUs the stall is hidden by the many parallel connections. Treat B's 1 and 10 VU numbers as a setup defect, not as free-threading cost.

## Go (a) vs (b): is (b) DB-bound or noisy?
Neither mainly. With the CPU caps removed, Go got slower on every level, and consistently (3 reps, `/me` 10 VUs: 1,071 to 1,689 req/s vs 2,170 to 2,310 for (a)).
- Not DB-bound: DB CPU is lower under (b) at 10 VUs (223% vs 263%) and the DB has spare cores (10 available, 370% at most).
- The apps burn more CPU per request: at 10 VUs `/me`, (a) uses 163% for 2,250 req/s (about 0.7 ms CPU per request); (b) uses 223% for 1,107 req/s (about 2.0 ms). At 50 VUs: 0.9 ms vs 2.0 ms.
- Likely cause (inferred, not profiled): four processes each seeing 10 CPUs (GOMAXPROCS 10, vs about 1 per service under the cgroup caps) compete, spin and migrate threads; the capped version keeps each service on about one thread. Variance is also higher in (b) (`/me/permissions` 50 VUs: 570 to 1,387 req/s), so it is partly noisy too.

## Rarely-used APIs: cold start, idle, memory, code size
Method: all numbers are from the host through the published ports, `GET /me` as the member user, sequential requests. "Start to first 200" is a `docker start` (the container was stopped first) until the first 200 response, polled every 20 ms (the stop time is not included; Go starts its four containers together). Median (min-max) of 3 fresh starts. The other stacks stay up and idle. Raw: `bench/raw-clean/cold.txt`, `idle.txt`, `afterload.txt`; scripts `bench/cold.sh`, `idle.sh`, `afterload.sh`.

### Cold start (3 fresh starts)
| Stack | start to first 200 (s) | first OK request (ms) | request 2 | request 10 | request 100 | idle RSS, 12 s after start (MiB) | RSS after 100 requests (MiB) |
|---|---|---|---|---|---|---|---|
| PHP | 0.28 (0.27-0.29) | 66.3 (65.6-75.2) | 4.7 (4.6-4.7) | 3.9 (3.6-4.1) | 4.0 (3.7-5.6) | 13.3 (12.2-24.0) | 29.5 (29.4-30.8) |
| C# | 0.37 (0.37-0.38) | 156.1 (151.1-156.6) | 6.4 (6.3-7.6) | 4.0 (3.9-4.3) | 4.5 (3.5-4.7) | 14.7 (14.4-14.8) | 36.6 (34.9-37.3) |
| Go (4 services) | 0.37 (0.37-0.40) | 11.3 (9.3-13.2) | 4.0 (2.9-4.4) | 3.1 (2.9-3.3) | 3.0 (3.0-3.3) | 6.1 (5.9-12.4) | 19.9 (19.7-19.9) |
| Python A | 1.18 (1.17-1.20) | 32.0 (29.2-32.5) | 25.3 (3.0-26.3) | 2.9 (2.7-4.6) | 2.8 (2.6-3.7) | 103.3 (103.2-103.8) | 113.0 (112.7-113.2) |
| Python B | 0.88 (0.86-0.90) | 31.8 (30.5-32.9) | 3.4 (3.0-4.2) | 3.0 (3.0-3.4) | 3.6 (3.3-3.7) | 74.1 (73.7-74.9) | 79.2 (78.0-82.2) |

- "First OK request" is the latency of the first successful request, included in the start time. Cold costs: C# 156 ms (JIT, first DB connection), PHP 66 ms (first opcache compile and DB connect), Python 32 ms, Go 11 ms.
- Python A's request 2 is 25 ms: the second uvicorn worker process serves its first request there. With N workers each worker pays its own warm-up.
- By request 10 every stack is at 3 to 4 ms. Python takes the longest to start (A 1.2 s, B 0.9 s, mostly imports); the other three start in 0.3 to 0.4 s.

### After 10 minutes with no traffic (all stacks up, single sample each, one request per stack in turn)
| Stack | request 1 (ms) | request 2 | request 10 |
|---|---|---|---|
| PHP | 106 | 6.7 | 4.4 |
| C# | 165 | 6.5 | 3.8 |
| Go (4 services) | 23 | 4.9 | 3.1 |
| Python A | 7.9 | 3.0 | 3.2 |
| Python B | 6.9 | 3.3 | 3.2 |
Each stack had served requests earlier in the day (contract runs), so this is "warm process, idle 10 minutes", not a cold process; C# and PHP still pay 100+ ms for the first request after idle (JIT tiers, opcache and connection pools going cold or reconnecting), Python and Go do not. Host load average at the start of the idle window was about 3 and at the end 2.1. One sample: the PHP/C# difference from the cold-start table (66 and 156 ms) says the same thing.

### Memory of the whole stack (sum over containers, MiB)
| Stack | Idle, 12 s after fresh start | After 100 requests | Peak under load (50 VUs, from the run tables) | Idle again after 30 s at 50 VUs + 10 s |
|---|---|---|---|---|
| PHP | 13 | 30 | 136 to 142 | 96 |
| C# | 15 | 37 | 114 to 123 | 116 |
| Go (4 services) | 6 | 20 | 59 to 61 | 48 |
| Python A | 103 | 113 | 123 to 124 | 135 |
| Python B | 74 | 79 | 145 to 148 | 143 |
Python's idle floor is about 5 to 15 times that of the others (imports plus two interpreters or an interpreter with two pools). Go (a) has the smallest footprint at every stage. Images: PHP 992 MB, C# 133 MB, Python A 216 MB, Python B 279 MB, Go 36.5 MB total.

### Lines of code (non-blank, no tests, same counting for all: `grep -cv '^\s*$'` over source files)
| Slice | C# | Go | Python (A and B share the code) |
|---|---|---|---|
| identity (stub auth, users lookup, `/me` shape, `/me`) | 280 | 306 | 162 |
| access (permission resolver, `/me/permissions`) | 180 | 283 | 139 |
| classes (four class lookups) | 49 | 99 | 45 |
| shared (contracts, DB helper, JSON) + host/gateway | 177 | 190 (common 156 + gateway 34) | 156 (shared 106 + main 50) |
| B-only threaded launcher | | | 35 |
| Total | 686 | 878 | 538 (503 without the launcher) |
PHP is not counted (the existing routes sit in larger shared files). Go's earlier NOTES number (964) counted differently; 878 is by this method. The Go total includes the three service `main` packages and HTTP client code for the hops between services.

## Static numbers
| | PHP | C# | Go (4 services) | Python A | Python B |
|---|---|---|---|---|---|
| Image size | 992 MB | 133 MB | 36.5 MB | 216 MB | 279 MB |
| Idle RSS, fresh start | 13 MiB | 15 MiB | 6 MiB | 103 MiB | 74 MiB |
| Start to first 200 | 0.28 s | 0.37 s | 0.37 s | 1.18 s | 0.88 s |
| LOC | not counted | 686 | 878 | 538 | 538 |

## Threats to validity
- Python A and B were run about two hours after the other stacks (same method, same host state as far as known); the earlier session's lesson is that results move with host load.
- Python uses asyncmy, which escapes parameters client-side (no server-side prepared statements), unlike PHP, C# and Go; MySQL parses each statement text each time.
- Python B's keep-alive stall (see above) is a setup defect that makes its 1 and 10 VU numbers unrepresentative of free-threaded CPython; B has not been tuned.
- Cold and idle numbers: only 3 cold starts and one idle sample per stack; host-side curl timing adds the OrbStack port-forward (about 1 to 2 ms) to every number; the idle test was not a true cold process.
- Python A runs 2 worker processes; the number of workers and B's thread count were not tuned.
- Single machine (M4, 10 cores, OrbStack VM); k6 and all stacks share the same cores. The DB is unlimited and took 220 to 400% CPU under C# and Go load, so at 10 and 50 VUs the DB competes with the apps for CPU.
- Run-to-run spread: now small for PHP, C# and Go (a) (mostly within 10%) and large for Go (b) (up to 2x). The earlier 2-rep run had C# at 750 req/s (10 VUs) and 1,114 (50 VUs); in the clean run it is 1,950 and 2,260. That run was disturbed by a busy host (memory pressure, other VMs), which is a warning: this benchmark is sensitive to what else the Mac is doing. n=3 is still small.
- The DB is shared and unconstrained: C# and Go push it to 300 to 440% CPU, so at 50 VUs the DB, k6 and the apps all compete for the 10 cores. A C# vs Go (a) gap of under about 15% is inside the noise.
- Go hop overhead: `/me` is gateway then identity then access then classes (3 internal HTTP calls). Go (a) hit about 170 to 180% of its 200% cap at 10 and 50 VUs, so it is CPU-capped.
- Go CPU split is static (.4/.6/.6/.4). Go (b) removed the caps and was slower, not faster (see the section above). It is a limit of this setup (four processes sharing 10 cores with GOMAXPROCS 10 each), not a general Go result.
- PHP has 0.01 to 0.33% failed requests on `/me` at 1, 10 and 50 VUs (the clean run too) (cause not investigated; possibly Apache/MariaDB connection limits: MariaDB max_connections is 151 and PHP opens about 7 per request).
- Only 4 users, so at 50 VUs the per-user UPDATE row lock serialises some requests, the same for every stack.
- Unknown-uid deviation: PHP creates a user, C#/Go return 404; not exercised.
- Emoji and html-decode deviations (C# escapes non-BMP and uses HTML4 HtmlDecode; Go not checked): not in the synthetic data.
- C# caches prepared statements per pooled connection and uses one connection per request; PHP reconnects about 7 times per request. This favours C#.
- Smoke baseline 29 Oct (`tsr-account/tools/perf/k6/baseline.json`): PHP `/me` p50 2.8 ms at 1 VU, 5 iterations, other apps running, ten index migrations. This run: PHP `/me` p50 0.9 ms at 1 VU, 60 s. Same order of magnitude; the smoke is 5 samples and not comparable beyond that.
- `docker stats` sampled about every 7 s; the first two samples per run are dropped.
- The DB is MariaDB 11.4 with a 128 MB buffer pool, no tuning. Prod differs.

## What this says
Facts only; the choice is left to the reviewers.
- **Busy API (throughput).** At 10 VUs on `/me`: Go (a) 2,250 req/s, C# 1,950, Python A 1,340, PHP 580, Python B 170 (keep-alive stall). At 50 VUs: C# 2,260, Go (a) 2,050, Python A 1,460, Go (b) 1,660, Python B 640, PHP 263. p95 at 50 VUs: C# 31 ms, Python A 43 ms, Go (a) 57 ms, PHP 383 ms. `/me/permissions` is similar. Python A is about 60 to 70% of C# and Go (a) at 10 and 50 VUs, and about 2.3 to 5.6 times PHP on /me. C# and Go are close (within about 15%); the DB is shared and uses 200 to 440% CPU, which compresses the gaps.
- **Rarely-used API (cold start, idle).** First request after a cold start: Go 11 ms, Python 32 ms, PHP 66 ms, C# 156 ms. After 10 idle minutes (already warm processes): Python 7 to 8 ms, Go 23 ms, PHP 106 ms, C# 165 ms. By the tenth request all are 3 to 4 ms. Python takes the longest to start (0.9 to 1.2 s vs 0.3 to 0.4 s).
- **Footprint.** Whole-stack idle memory: Go 6 MiB, PHP 13, C# 15, Python B 74, Python A 103. After load: Go 48, PHP 96, C# 116, Python A 135, Python B 143. Images: Go 36 MB, C# 133, Python 216 to 279, PHP 992.
- **Code size.** For the same two routes: Python 538 lines, C# 686, Go 878 (Go's total includes the HTTP hops between its services).
- **Go (b)** (CPU caps removed) is slower than Go (a), not DB-bound; it uses about 3 times the CPU per request. **Python B** has a 40 to 50 ms keep-alive stall in this setup and is not a fair read of free-threaded CPython; at 50 VUs it does 640 req/s with 65 to 100% CPU, so it has not saturated its 2 CPUs.
- **PHP** hits its 2-CPU ceiling at 10 VUs (the DB is nearly idle) and starts to fail a few requests at 50 VUs.
- Differences within about 15% (C# vs Go (a) throughput) are inside the noise of one machine with a shared DB; the cold-start gaps (11 vs 156 ms) are larger than the noise but rest on 3 starts.

## Appendix A: earlier run (noisy, 2 reps), kept for reference
Latency ms, median of 2 reps (mean of the two, since n=2). CPU = summed app containers, cores x 100 (200 = 2 cores); RSS = peak summed MiB; DB = MariaDB CPU%. "err" = k6 failed-request rate.
Run-to-run spread is large (see "Threats"); individual reps are in the raw JSON.

#### GET /me
| Stack | VUs | p50 | p95 | p99 | req/s | err | App CPU% | RSS MiB | DB CPU% |
|---|---|---|---|---|---|---|---|---|---|
| PHP | 1 | 0.8 | 3.4 | 4.7 | 776 | 0 | 96 | 67 | 9 |
| PHP | 10 | 4.5 | 75.5 | 80.0 | 629 | 0.05% | 214 | 50 | 5 |
| PHP | 50 | 110 | 304 | 396 | 329 | 0.27% | 214 | 134 | 32 |
| C# | 1 | 2.5 | 4.9 | 8.5 | 314 | 0 | 92 | 74 | 60 |
| C# | 10 | 9.8 | 23.3 | 42.8 | 753 | 0 | 163 | 85 | 274 |
| C# | 50 | 43.0 | 77.9 | 107 | 1114 | 0 | 202 | 131 | 388 |
| Go (a) as built | 1 | 1.0 | 1.5 | 4.9 | 765 | 0 | 52 | 48 | 66 |
| Go (a) | 10 | 3.7 | 6.3 | 8.6 | 2318 | 0 | 168 | 50 | 268 |
| Go (a) | 50 | 14.4 | 55.3 | 61.9 | 2155 | 0 | 179 | 63 | 313 |
| Go (b) no CPU limit | 1 | 1.3 | 3.2 | 6.0 | 573 | 0 | 61 | 60 | 64 |
| Go (b) | 10 | 7.8 | 14.1 | 19.4 | 1100 | 0 | 224 | 60 | 223 |
| Go (b) | 50 | 32.2 | 57.1 | 80.2 | 1344 | 0 | 318 | 71 | 355 |

#### GET /me/permissions
| Stack | VUs | p50 | p95 | p99 | req/s | err | App CPU% | RSS MiB | DB CPU% |
|---|---|---|---|---|---|---|---|---|---|
| PHP | 1 | 1.0 | 4.3 | 5.7 | 622 | 0 | 87 | 63 | 6 |
| PHP | 10 | 8.7 | 92.5 | 192 | 377 | 0 | 211 | 60 | 30 |
| PHP | 50 | 246 | 495 | 860 | 199 | 0 | 216 | 144 | 64 |
| C# | 1 | 3.1 | 7.7 | 13.3 | 282 | 0 | 91 | 80 | 59 |
| C# | 10 | 13.3 | 27.9 | 45.7 | 617 | 0 | 165 | 93 | 268 |
| C# | 50 | 38.2 | 78.6 | 133 | 1181 | 0 | 203 | 126 | 401 |
| Go (a) | 1 | 1.0 | 1.6 | 5.2 | 761 | 0 | 52 | 53 | 66 |
| Go (a) | 10 | 4.0 | 6.9 | 9.2 | 2128 (rep 1 only) | 0 | 169 | 51 | 268 |
| Go (a) | 50 | 14.4 | 55.2 | 62.2 | 2160 | 0 | 175 | 60 | 303 |
| Go (b) | 1 | 1.3 | 3.0 | 5.8 | 593 | 0 | 60 | 63 | 65 |
| Go (b) | 10 | 8.1 | 15.2 | 21.8 | 1030 | 0 | 222 | 61 | 234 |
| Go (b) | 50 | 35.2 | 75.5 | 134 | 1164 | 0 | 320 | 73 | 369 |

Go (a) `/me/permissions` at 10 VUs: rep 2 came from the run that was interrupted by the Docker hang (10 req/s) and is discarded; only rep 1 is shown.
The PHP 10-VU DB CPU of 5 to 30% versus 223 to 274% for C#/Go means the PHP rows were limited by PHP itself (2 CPUs, one process per request), not by the DB.


## Fix round: stopped by Asif, 2026-11-09 15:07 (incomplete)
- F1 done: C# logging set to Warning (no per-request logs); Python B gets TCP_NODELAY (the 40-45 ms keep-alive
  stall is gone, GIL still off). Both pass the contract 20/20. Not re-measured under load.
- F2 done: Go monolith (`spikes/profile-bench/go-mono/`, :4110). Contract 20/20; image 9.1 MB; idle RSS 2.6 MiB
  (9.9 after smoke); 724 LOC; GOMAXPROCS 2; DB pool 64. Not measured under load.
- F3 not run: the real long-idle test and the interleaved load re-run were stopped during the first idle warm-up.
  Still open: C# cost after a long idle (review B1); Python B and Go monolith throughput; pool-size parity.
- So the load tables above stand with review.md's caveats (C# had Information logging, Python B invalid,
  Go measured as microservices only).
