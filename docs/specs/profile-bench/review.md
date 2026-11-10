# Profile benchmark: fairness review (Story 4, 2026-11-09)

Scope: `results.md` checked against `bench/raw-clean/`, the bench scripts, the four implementations and the container logs. Read-only. Nothing was re-run.
Severity: **blocking** = changes a conclusion in results.md; **major** = biases a number by a meaningful, known direction; **minor** = wording or bookkeeping.

## Summary
The tables are transcribed correctly. Four findings change conclusions:
1. The "after 10 idle minutes" test compared never-used C#, PHP and Go processes with warmed Python processes.
2. C# logs four Information lines per request; the other stacks log one line or none.
3. Python B's 45 ms stall is a launcher bug (no `TCP_NODELAY`, and uvloop silently not used). It holds at every VU level, not only at 1 and 10.
4. Go's tail and throughput numbers measure a four-service split under per-service CPU quotas, not Go. No single-process Go build was measured.

On top of that, the host is a fanless MacBook Air with 4 performance and 6 efficiency cores, and the stacks ran in a fixed order.

---

## 1. Do the tables match the raw data?
Yes. I checked 15 rows against `result-*.json`, all with the median and min-max of r1-r3:

| Cell | Raw r1 / r2 / r3 | Table | OK |
|---|---|---|---|
| PHP /me 1 VU p50, p95, p99, req/s, err | 0.8/0.9/0.9; 3.6/3.1/3.8; 4.4/4.5/4.8; 829/788/742; max 0.01% | 0.9 (0.8-0.9), 3.6 (3.1-3.8), 4.5 (4.4-4.8), 788, 0.01% | yes |
| PHP /me 10 VU p95, err | 76.5/76.2/77.3; max 0.10% | 76.5 (76.2-77.3), 0.10% | yes |
| PHP /me 50 VU p50 | 100/194/205.8 | 194.0 (100.0-205.8) | yes |
| C# /me 10 VU req/s | 2067/1770/1950 | 1950 (1770-2067) | yes |
| C# /me 50 VU req/s | 2260/2023/2430 | 2260 (2023-2430) | yes |
| Go (a) /me 10 and 50 VU req/s | 2250/2310/2171; 2255/2050/1911 | 2250, 2050 | yes |
| Go (b) /me 10 VU req/s | 1689/1071/1107 | 1107 (1071-1689) | yes |
| Go (b) /me/perm 50 VU req/s, p99 | 570/1387/1384; 341/62/63 | 1384 (570-1387), 62.7 (61.8-341.4) | yes |
| Python A /me 10 and 50 VU req/s | 1438/1336/1267; 1401/1469/1464 | 1336, 1464 | yes |
| Python B /me 1 VU p50; /me/perm 1 VU p50 | 52.8/52.9/52.9; 31.8/40.0/34.6 | 52.9, 34.6 | yes |
| C# /me/perm 50 VU req/s | 2295/2265/2265 | 2265 | yes |
| Go (a) /me/perm 1 VU req/s | 663/579/660 | 660 (579-663) | yes |
| Cold first OK request, C# / Go / PHP | 151/156/157; 9.3/11.3/13.2; 75/66/66 ms (`cold.txt`) | 156.1, 11.3, 66.3 | yes |
| Idle request 1 | `idle.txt`: 106/165/23/7.9/6.9 ms | same | yes |
| After-load RSS | `afterload.txt`: 96.1/116.2/48.2/135.3/142.6 | same | yes |

Bookkeeping errors (all minor, see M-list): req/s is undercounted by about 8%, the "request 2" column is mislabelled, the "load start-end" column is min/max rather than first/last, and the stats interval is about 4 s, not 7 s.

---

## 2. Like-for-like check, item by item
| Item | Verdict | Bias |
|---|---|---|
| SQL text and count | Same 11 statements per route (results.md, from the general log). Checked on one request at rest only. | Unproven under load (J4) |
| Prepare style | C# uses native prepares with a claimed cache (unverified after reset). Go re-prepares every statement. Python binds client-side. | Against Go, about 10 extra round trips per request (B4, J7) |
| Auth stub | Same in every stack: Bearer = uid, email `<uid>@bench.invalid` (`stack/auth-stub.php:12`, `StubAuthenticator.cs:29`, `identity/main.go:96`, `stub_auth.py:28`). The UPDATE uses the row's own email in all of them. | None |
| CPU and memory limits | 2 CPUs and 512 MB each. Go's are split per service (0.4/0.6/0.6/0.4). | Against Go (stranded capacity, throttling) (B4) |
| Workers, threads, GOMAXPROCS | Python A has 2 workers. Python B has 2 threads on a broken launcher. Go's GOMAXPROCS is probably 2 per capped service (unverified). C# uses defaults. | Python B invalid (B3). Against Go (B4) |
| Pool sizes | C# 100, Python 2×50, Go 3×24. None binds at 50 VUs. | None under load. Idle eviction differs (B1) |
| Timeouts | Present in every stack. | None |
| Logging | C# writes 4 Information lines per request, PHP 1 access line, Go and Python none. | Against C# (B2) |
| Release or optimised builds | Yes for all (m10). C# has no ReadyToRun or AOT. | C# cold start (J6) |
| JSON serialisation | Comparable (m9). | None |
| k6 placement | Same network for every stack, but unpinned and sharing the 4 P-cores with the apps and the DB. | Slightly against the faster stacks. Adds noise (J2) |
| Order and hardware | Fixed order, fanless Air, P and E cores. | Unknown direction: Go (b) worst hit (J2) |

## 5. Claims in results.md stronger than the data
| Claim | Problem | Finding |
|---|---|---|
| "C# and PHP still pay 100+ ms for the first request after idle ... Python and Go do not" | The C# and PHP processes had never served a request. | B1 |
| The earlier C# run was "disturbed by a busy host" | Go (a) and PHP did not move between runs. C# logging is the likelier cause. | B2 |
| Python B's "stall is hidden" at 50 VUs | Little's law matches the stall exactly. | B3 |
| "p95 at 50 VUs: C# 31 ms ... Go (a) 57 ms" | A per-service quota artefact. | B4, J1 |
| "C# and Go are close (within about 15%)" | A shared ceiling, and Go was measured as microservices. | B4, J3 |
| Go (b) is slower because of "four processes ... with GOMAXPROCS 10" competing | Not separated from heat and E-core placement. | J2 |
| "Python ran about 2 hours after the others" | It ran 13 minutes after Go (b) ended. | J2 |
| "Python's idle floor is about 5 to 15 times that of the others" | Depends on the worker count. About 1.2x after load. | J5 |
| PHP is "limited by PHP itself", with the DB "nearly idle" | DB work per request differs 4-7x for the same SQL. | J4 |
| "Python uses asyncmy ... unlike PHP, C# and Go" (listed as a threat) | The direction is backwards. | J7 |
| "a Nagle/delayed-ACK stall" | Partly right. The code confirms no nodelay, but `/me/permissions` stalls under 40 ms. | B3 |

## Blocking findings

### B1. The idle test compared never-used C#, PHP and Go processes with warm Python processes
**Evidence**
- At 07:05:02-03 UTC (12:35 IST), the restore step at `driver.sh:18` ran `compose up -d` without the nolimit file, which recreated all four Go containers. Their "listening" lines and the gateway `Created=07:05:02Z` show this. The same step ran `docker start` on PHP and C#, which `stop_php` and `stop_cs` had stopped earlier.
- **Proven from the logs (C# and PHP):** `docker logs -t` shows **no requests** to C# or PHP between that start and the idle probe at 07:18:15Z.
  - The C# log goes straight from "Application started" to `Request finished ... /me - 200 ... 142.8418ms` at 07:18:15.
  - The first PHP access-log line is at 07:18:15.
- **Inferred (Go and Python write no request log):** Go was never used, because it was recreated at 07:05:02Z and the idle probe was its next traffic. Python was warmed: its images were rebuilt at 12:36 IST and its containers recreated at 07:06:31 and 07:06:49Z, and its request 1 after idle took 7-8 ms against about 32 ms cold. That points to a contract run after the rebuild. The finding stands on the C# and PHP evidence alone.
- C# after idle was 165 ms and C# cold was 156 ms. That is the same event: the first JIT compile plus the first DB connection.

**Effect**
- "C# and PHP still pay 100+ ms for the first request after idle ... Python and Go do not" (results.md, idle section and "What this says") is not supported.
- The stated mechanism is also wrong. .NET does not discard JIT-compiled code after idle, and opcache does not expire in 10 minutes.
- What 10 idle minutes can really do is evict pooled connections:
  - Go: `SetConnMaxIdleTime(2m)` (`go/internal/common/common.go:55`) and the HTTP `IdleConnTimeout` of 90 s (`common.go:108`).
  - MySqlConnector: default `ConnectionIdleTimeout` of 180 s (from the library docs; verify).
  - asyncmy: whatever its pool does by default (verify).
  - Each reconnect costs a few ms, not 100+.
- For the language decision, the idle comparison is currently empty.

**Fix or experiment**
1. Warm every stack with the same 100 requests.
2. Leave all stacks idle for 10 min, 1 h and 9 h (the last is past MariaDB's default `wait_timeout` of 28,800 s).
3. Then send one request per stack, with at least 5 samples per interval.
4. Record request 1 latency **and errors**. A dead pooled connection after `wait_timeout` is the real risk for a rarely-used API.
5. Use keep-alive and a fresh-connection variant.

### B2. C# logs every request at Information level; the other stacks log one line or none
**Evidence**
- `csharp/src/Host/` has no `appsettings*.json`, and `Program.cs` sets no log level, so the default minimum level is Information.
- `docker logs tsr-bench-csharp-csharp-1` shows four entries per request: `EndpointMiddleware` Executing and Executed, and `Hosting.Diagnostics` Request starting and Request finished.
- The others:
  - Go writes no per-request log (`grep log. cmd internal`: errors only).
  - Python runs `--no-access-log`, and `access_log=False` in `python/Dockerfile:18` and `threaded.py:26`.
  - PHP writes one Apache access-log line per request.
- At 2,260 req/s, that is about 9,000 console lines per second from C#, through the Docker json-file driver and OrbStack, on the same cores.

**Effect**
- This penalises C# throughput and CPU per request. In ASP.NET, console logging at this volume usually costs tens of percent; the exact size is unmeasured here.
- The console logger's queue can also back up when the log consumer is slow. That is the more likely cause of C#'s 2.6x swing between runs (10 VUs: 661 and 845 req/s in `raw/` against 1,770-2,067 in `raw-clean/`).
- The "busy host" explanation in results.md does not fit:
  - Go (a) barely moved between the two runs (2,318 vs 2,250), and neither did PHP (629 vs 582).
  - The memory log shows the same low free-page floors in both runs (`raw/mem.log` min 5,339; `raw-clean/mem.log` min 5,039 pages).
  - A busy host would have hit every stack, not only C#.
- In the earlier run, C# used about 2.2 ms of CPU per request against 0.77 ms in the clean run. That points to something inside C#, not to host load.

**Fix**
- Set `Logging__LogLevel__Default=Warning` (and `Microsoft.AspNetCore=Warning`), or disable console logging in the bench.
- Optionally turn off PHP's access log as well.
- Re-run C# with at least 5 reps, interleaved with Go.

### B3. Python B's stall is a launcher bug, and it limits B at every VU level
**Evidence**
- `python/bench/threaded.py:22` creates the listener with `socket.socket(AF_INET, SOCK_STREAM)`, so `proto` is 0.
- `socket.accept()` copies `self.proto` (CPython `socket.py:299`), so every accepted socket also has proto 0.
- asyncio only sets `TCP_NODELAY` when `sock.proto == IPPROTO_TCP` (`asyncio/base_events.py:192-196`, called from `selector_events.py:948`). So B's connections run with Nagle on.
- Nagle plus the client's delayed ACK (40 ms minimum on Linux) fits the observed shape:
  - A fresh connection is fast, because Linux uses quick-ACK mode at connection start.
  - Every later request on a kept-alive connection stalls by about 40-50 ms.
  - The fit is only partial: `/me/permissions` at 1 VU has p50 31.8-40.0 ms, which is below a 40 ms delayed-ACK floor. The missing nodelay and the bypassed uvloop are confirmed from the code, but the stall size is only partly explained. `ss -tni` inside the container, or a re-run after the fix, settles it.
- `threaded.py:27` runs `asyncio.run(uvicorn.Server(config).serve(...))`. uvicorn only applies `loop="uvloop"` in `Server.run()` (`uvicorn/server.py:77`, checked on the locally cached uvicorn 0.52.1; the lock pins 0.54.0, so re-check there: `asyncio_run(..., loop_factory=self.config.get_loop_factory())`). So B also runs on the stdlib asyncio loop, not uvloop.
- Variant A runs the `uvicorn` CLI, which takes the `run()` path with uvloop, and uvloop sets nodelay itself. That is why A does not stall even though `config.bind_socket()` also creates a proto-0 socket.
- results.md says the stall "is hidden by the many parallel connections" at 50 VUs. Little's law disagrees:
  - /me r3: 50 VUs ÷ 72.4 ms mean = 690 req/s, and the measured count is 41,422 requests in 60 s = 690 req/s. That is an exact match (the reported 637 is low because of m1).
  - /me/permissions r3: 50 ÷ 48.1 ms mean = 1,040 req/s, and 62,384 in 60 s = 1,040 req/s.
  - B is still latency-bound by the stall at 50 VUs. Its 65-100% CPU (of 200%) confirms it is idle-waiting.

**Effect**
- Every Python B number from k6 is invalid, not just the 1 and 10 VU rows. "At 50 VUs it does 640 req/s" says nothing about free-threaded CPython.
- B's cold and idle numbers (3 ms) look fine only because `lat.sh` opens a fresh curl connection per request.
- In Dokploy, Traefik keeps upstream connections alive, so B as built would stall in production.

**Fix**
1. Create the socket with `proto=socket.IPPROTO_TCP`, or set `TCP_NODELAY` explicitly on the listener.
2. Call `uvicorn.Server(config).run(sockets=[sock])`, or pass `loop_factory=uvloop.new_event_loop`, so B actually uses uvloop.
3. Re-run B.
4. Verify with `ss -tni` inside the container (look for `nodelay`) and by checking the event-loop type.

### B4. The Go numbers measure a 4-service split under per-service CPU quotas, not Go
**Evidence**
- Architecture: Go is a gateway plus 3 services, with 3 internal HTTP hops per request (`go/NOTES.md`, "Hops per request"). C# and Python are in-process monoliths.
- Per-service CPU caps: 0.4/0.6/0.6/0.4 (`go/docker-compose.yml:21,34,47,58`).
  - In `stats-go-a_me-v50-r1.txt`, classes runs at 40.9-43.2% against its 40% cap, and identity and access at 55% against their 60% caps.
  - The gateway uses 25% of its 40% cap.
  - So throughput is set by the tightest slice of a static split. Total Go CPU is 179% of 200%, which leaves capacity stranded.
- The Go (a) tail looks like CFS throttling:
  - At 50 VUs, p50 is 15 ms but p95 is 57 ms and p99 63 ms.
  - Go (b) has no caps and a *lower* p95 (41.7 ms) despite less throughput.
  - The same signature appears in PHP at 10 VUs (finding J1).
- GOMAXPROCS: Go 1.25+ derives it from the cgroup quota, rounded up with a floor of 2. So each capped service most likely ran GOMAXPROCS=2 against a 0.4-0.6 CPU quota, which is a recipe for quota bursts and throttling. results.md's "about 1 per service" is unverified. Log `runtime.GOMAXPROCS(0)` to confirm.
- Prepares: Go runs with `interpolateParams` off (`common.go:44`) and calls `QueryContext` with args (`identity/main.go:51`, `access/main.go:99,205`, `classes/main.go:31`). With go-sql-driver this means prepare + execute + close for every parameterised statement: about 10 extra DB round trips per request compared with Python, which binds client-side.

**Effect**
- These conclusions are architecture and configuration results, not language results:
  - "p95 at 50 VUs: C# 31 ms ... Go (a) 57 ms"
  - "C# and Go are close (within about 15%)"
  - "C# 2,260 vs Go (a) 2,050 at 50 VUs"
  - Go's 878 LOC (it includes 3 `main` packages and HTTP client code)
- A Go monolith on the same 2 CPUs would very likely beat Go (a) on throughput and tail latency, and quite possibly C#. That is unmeasured.

**Fix (the missing control)**
1. Build a single-process Go monolith with the same handlers called in-process: one container, 2 CPUs, GOMAXPROCS=2, and `interpolateParams=true` or cached prepares.
2. Run it interleaved with C# and Python A.
3. Read `cpu.stat` (`nr_throttled`, `throttled_usec`) before and after each run for every container.

---

## Major findings

### J1. PHP's p95 tail at 10 VUs is not explained in results.md; CFS throttling is the likely cause
- **Evidence:** p50 is 4.9 ms while p95 is 76.2-77.5 ms and p99 80.6-83.0 ms, nearly constant across all 3 reps and both routes. App CPU is 213-215% against a 2-CPU cap.
  - A fixed tail of about 75-80 ms below a 100 ms CFS period is the classic quota-exhaustion signature: about 10 prefork processes on 10 vCPUs burn the 200 ms quota in about 20 ms, then wait out the rest of the period.
- **Effect:** It only concerns the baseline. The same mechanism probably inflates Go (a)'s tail (B4) and C#'s p99 at 50 VUs (C# runs at 196% of 200%).
- **Experiment:** Read `/sys/fs/cgroup/cpu.stat` before and after a 10-VU run. If `nr_throttled` rises by thousands, this is confirmed.

### J2. Fanless MacBook Air with P and E cores, and the stacks ran in a fixed order
- **Evidence:** `system_profiler` reports a MacBook Air (Mac16,13), Apple M4, 10 cores: 4 performance and 6 efficiency.
- `loadavg.log`, `stats-*.ts` and the file times give a fixed sequence:
  - Go (a) at 11:11, then PHP, then C#.
  - Go (b) last, ending 12:35, at load averages of 9-14.
  - After a 13-minute gap, Python A and B from 12:48 to 13:30 at load 2-7.
  - So results.md's "Python ran about 2 hours after the others" is wrong.
- **Demand vs P-cores:** Each 10/50-VU run needs about 2 app cores, plus a DB using 2.2-4.4 cores, plus k6, plus `docker stats`. That exceeds the 4 P-cores, so work spills onto E-cores in a way nobody controls.
- **Effect:**
  - "CPU ms per request" is not comparable between runs. More runnable threads land on more E-cores, and E-core CPU-ms buy less work.
  - That alone can produce Go (b)'s "3x CPU per request": 40 Ps across 4 processes spread onto E-cores.
  - Go (b) also ran hottest, after about 80 minutes of sustained all-core load on a fanless chassis, and its reps drift (/me 10 VUs: r1 1,689, then 1,071 and 1,107 req/s).
  - So results.md's Go (b) explanation (GOMAXPROCS 10 contention) is plausible but not separated from thermal throttling and E-core placement.
  - Go (b) is also slower at 1 VU (1.5 vs 1.1 ms p50), where there is no contention, which fits a frequency or core-placement effect.
- **Fix:**
  - Interleave the order (A B C A B C...), or randomise it per rep.
  - Use at least 5 reps and cool-down gaps.
  - Log `pmset -g therm` (or `powermetrics`) during the run.
  - Better: run on a Linux box that looks like prod (the Dokploy server class), with k6 on a separate machine or pinned cores.

### J3. C# and Go (a) at 50 VUs probably hit a shared ceiling
- **Evidence:** C# and Go (a) both plateau at 2,050-2,260 req/s while using very different app CPU. All load comes from only 4 users, so the per-request `UPDATE users ... WHERE email` contends for 4 rows. The DB (uncapped, 300-440%) and k6 share the cores.
- **Effect:** The 50-VU tier cannot rank C# against Go. The "about 15%" noise statement in results.md is right, but the cause is shared contention, not just noise.
- **Fix:** Use at least 200 synthetic users. Report DB-side counters (`SHOW GLOBAL STATUS` deltas: `Com_*`, `Innodb_row_lock_waits`, `Innodb_os_log_fsyncs`) per 1,000 requests.

### J4. DB work per request is 4-7x lower for PHP, so steady-state SQL parity is unproven
- **Evidence:** At 1 VU, DB CPU is:
  - PHP: 12% at 788 req/s (about 0.15 ms per request).
  - C#: 61% at 560 req/s (1.1 ms).
  - Go (a): 65% at 745 req/s (0.9 ms).
  - Python A: 51% at 590 req/s (0.9 ms).
  - At 10 VUs: PHP 19% at 582 req/s against C# 306% at 1,950.

  SQL parity (results.md, "SQL parity") was checked on **one request per route**, at rest.
- **Two further gaps:**
  - k6 checks only `status 200` (`bench/load.js` `hit()`), never the body.
  - PHP `resolve()` (and Go access, per its NOTES) turns DB errors into an empty result with 200. Under load, a 200 with an empty permission list would count as success.
  - PHP's UPDATE errors are caught and only `error_log`'d (`tsr-account/web/api/mobile/lib/auth.php:270-299`).
- **Effect:** Either PHP does less DB work under load than the trace shows, or the DB CPU numbers are not usable, which also undercuts "the DB compresses the gaps". It mainly concerns the baseline, but it is a correctness hole in the harness for all stacks.
- **Fix:**
  - Add a body-length or hash check to `load.js`.
  - Grep PHP's stderr for `login tracking failed` and PDO errors.
  - Compare `Com_select`, `Com_update`, `Com_stmt_prepare` and `Handler_read_*` deltas per 1,000 requests per stack.

### J5. The Python A worker count shapes both its footprint and its cold-start results
- **Evidence:** `WEB_CONCURRENCY=2` (`python/docker-compose.yml:15`) gives 3 interpreters (the supervisor plus 2 workers), which accounts for the 103 MiB idle. The 25 ms "request 2" (`cold.txt`: pyA rep1 and rep3 `after-first req2`) is the second worker's own first request.
- **Effect:**
  - "Python's idle floor is about 5 to 15 times that of the others" depends on configuration.
  - After load, the gap shrinks: Python A 135 vs C# 116 MiB, about 1.2x (`afterload.txt`).
  - A 1-worker Python, which is enough for a rarely-used API, was not measured.
- **Fix:** Measure Python A with 1 worker (RSS and the 1/10-VU latency), and C# with `DOTNET_GCConserveMemory` or workstation GC, at the same point (after traffic, then idle 10+ min).

### J6. Cold start is the wrong metric for this deployment model, and NativeAOT/ReadyToRun was not tried
- **Evidence:** Dokploy on Docker Swarm keeps replicas running and has no scale-to-zero. So cold start only happens on deploy, restart or crash, and Traefik routes no traffic until the container is ready.
- **Effect:**
  - Cold start ranking (C# 156 ms first request, Python 0.9-1.2 s to start) has little weight for "rarely used". Long-idle behaviour (B1) is the metric that matters, and it is currently unmeasured.
  - If cold start does matter, C# was measured with its slowest option: plain JIT, no ReadyToRun (`csharp/Dockerfile:6`, `-c Release` only).
- **Fix:** Re-measure cold start for C# with `PublishReadyToRun=true` and with NativeAOT (Kestrel minimal APIs and MySqlConnector support it). Expect the 156 ms to drop to tens of ms; unmeasured.

### J7. The Python threat note gets the prepared-statement direction backwards
- **Evidence:** results.md lists asyncmy's client-side binding as a threat to validity. But client-side binding is 1 round trip per statement.
  - Go re-prepares every statement (B4), which is 2 round trips per statement.
  - C# claims a per-connection prepared-statement cache (`csharp/NOTES.md`, Settings). MySqlConnector resets the connection on pool reuse, so whether the cache survives is unverified. Count `Prepare` lines per request in the general log.
- **Effect:** Python's setup is not handicapped; Go's is.

---

## Minor findings
- **m1. Every req/s figure is about 7.7% low.** k6's `http_reqs` rate divides by the whole test time (5 s warm-up scenario + 60 s), not by the 60 measured seconds. Example: `k6-php_me-v50-r2.log` has 17,140 requests, which is 263 req/s over 65 s but 286 over 60 s. The bias is the same for every stack.
- **m2. Cold-table columns are off by one.** "request 2/10/100" are `lat.sh`'s req2/req10/req100, which run *after* the first OK request, so they are really the 3rd, 11th and 101st requests. The actual 2nd request (`after-first req1`: C# 8.5-9.0 ms) is not shown.
- **m3. Two method statements do not match the scripts.** The "load start-end" column is min-start/max-end across reps (`an2.py:21`), not first/last. `docker stats` sampled about every 4 s (17 samples per 65 s in `stats-*.ts`), not every 7 s.
- **m4. Go's start time includes `docker compose` CLI overhead** for four containers (`cold.sh` `startit`), while the others use one `docker start`. This slightly penalises Go.
- **m5. Closed-loop, no-sleep k6** makes "1 VU req/s" just 1/latency, and it hides queueing (coordinated omission). An open-model run (`constant-arrival-rate`) at realistic rates would be more honest.
- **m6. Stale notes.** `contract/CONTRACT.md:159` and `csharp/NOTES.md` still call `users.email` unindexed and the dominant cost. `idx_users_email` was applied before the clean run (results.md, "DB fixes").
- **m7. Idle and cold-start probes go through the OrbStack host port-forward** with a new TCP connection per request, unlike k6. This adds about 1-2 ms to every number and hides keep-alive effects (B3).
- **m8. The per-request deletion check (`lower(contact_email) = lower(?)`) cannot use `idx_contact_email`.** It costs the same for every stack, so it is not a fairness issue, but it inflates DB load.
- **m9. JSON serialisers are comparable:** C# `Utf8JsonWriter`, Go `encoding/json`, Python stdlib `json.dumps` with no pydantic models. This is fair. Python could gain a little with orjson.
- **m10. Images are all Release or optimised builds:** C# `-c Release`, Go `-trimpath -ldflags=-s -w` with CGO off, PHP opcache on. Timeouts are present in every stack. The pool sizes differ (C# 100, Python 2×50, Go 3×24) but never bind at 50 VUs. No fairness issue.

---

## What is missing that could change the language decision
1. **A single-process Go monolith** (2 CPUs, GOMAXPROCS=2), the like-for-like control for C# and Python. See B4.
2. **C# with Warning-level logging**, interleaved with Go and Python, at least 5 reps. See B2.
3. **Python B with the launcher fixed** (nodelay plus uvloop), and **Python A with 1 and with 4 workers**. See B3 and J5.
4. **A real long-idle test** (10 min, 1 h, past `wait_timeout`) on processes known to be warm, with first-request latency and error rate. See B1.
5. **Realistic production load.** Most endpoints are lightly used, so an open-model test at 1-20 req/s with p50/p99 tells you more than 50 closed-loop VUs. At that load all three stacks are about 1-2 ms server-side, and the decision will be made on other grounds.
6. **NativeAOT or ReadyToRun C#** for cold start and RSS. See J6.
7. **A run on Linux hardware like the prod server**, with k6 off-box and the stack order randomised. See J2.
8. **Throttling counters** (`cpu.stat`) and **DB counters** per run, so that tail and CPU attributions are measured rather than inferred.

---

## Conclusions that survive
- **At low load all three candidates are fast enough and close.** At 1 VU, p50 is Go (a) 1.1 ms, C# 1.5 ms and Python A 1.5 ms, with p95 1.7-2.2 ms. At the load most of these APIs will see, users cannot tell them apart, so performance alone should not decide between Python, C# and Go.
- **C#'s first request after a fresh process start costs about 150 ms** (JIT plus first DB connection). This is n=3 with a tight spread (151-157 ms) and confirmed by the server log (142.8 ms). It goes away with warm-up, and probably with ReadyToRun or AOT. In Swarm it is a per-deploy cost, not a per-idle cost.
- **The footprint ordering holds: Go < C# < Python.**
  - Fresh-start RSS: Go 6 MiB, C# 15 MiB, Python 74-103 MiB.
  - After load: Go 48, C# 116, Python 135-143 MiB.
  - Images: Go 36.5 MB, C# 133 MB, Python 216-279 MB.
  - On a single server the absolute sizes are small, and the Python gap is mostly the worker count.
- **Python takes the longest to start** (0.9-1.2 s against 0.3-0.4 s). This only matters at deploy or restart.
- **Python A (GIL, 2 workers) reaches about 60-70% of the C# and Go throughput** under heavy closed-loop load on 2 CPUs. That ratio may move once B2 and B4 are fixed: C# and Go would likely pull further ahead.
- **PHP is CPU-bound at 2 CPUs from 10 VUs**, with a throttling-shaped tail. The baseline is the weakest under load, as expected.
- **Python ships the fewest lines** (538, against 686 for C#). The Go LOC is inflated by its service glue and is not comparable.

## Verification of blocking findings (fresh agents, read-only, 2026-11-09)

| Finding | Verdict | Evidence in short |
|---|---|---|
| B1 idle test | CONFIRMED for C# and PHP; Python unproven | Both restarted 07:05:03Z by driver.sh restore, first request 07:18:15Z (the idle probe). C# 165 ms includes "Creating new connection pool 1" and the JIT. Python logs no requests. |
| B2 C# logging | PARTLY | Default Information, 4 entries per request (about 713k lines logged). Estimated 5-15% throughput cost, not measured. The "2.6x run-to-run spread" is not in raw-clean: C# within-cell spread is at most 1.14x (Go-a 1.18x, PHP 1.46x). |
| B3 Python B stall | CONFIRMED (mechanism) | No TCP_NODELAY anywhere in python/. Keep-alive takes 41-44 ms vs 0.45-0.9 ms with Connection: close. uvloop IS used (threaded.py:26), so the review was wrong on that. All B load numbers are invalid. |
| B4 Go architecture | PARTLY | 3 internal HTTP hops per route vs 0 in the monoliths, which understates Go vs a monolith. The per-query prepare is NOT Go-specific: C# also prepares per query (RequestDb.cs:69); Python binds client-side. |
