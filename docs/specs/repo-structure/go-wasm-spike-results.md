# Go + wazero spike: POST /feedback (results)

Throwaway, in `spikes/go-wasm/`. Scope was reduced mid-run by Asif's coordinator: the cross-stack latency
benchmark moves to a different endpoint (user profile, Go/C#/PHP), so the 500-request runs and the
instantiate-vs-pool comparison for feedback were skipped. Start-time and cold C# build were not measured.

## What was built
- `rules/`: Go module, `GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared` (reactor, `_initialize`).
  `rules.go` is pure Go (ClientId + FeedbackText), `export_wasip1.go` holds the `//go:wasmexport alloc/validate` functions.
- Boundary: exported functions over linear memory, JSON in and JSON out (host calls `alloc`, writes body, calls
  `validate`, reads packed ptr/len). Chosen over stdin/stdout because it needs no per-call WASI plumbing and
  allows instance reuse; JSON keeps the types loose and the contract simple.
- `host/`: stdlib `net/http`, wazero v1.12.0, go-sql-driver/mysql v1.10.1. Embeds `rules.wasm` (4.4 MB), compiles once,
  pool of 8 instances (env `WASM_MODE=pool|instantiate`). Does X-Dev-Token auth, permission check, idempotent
  insert (1062 handled), outbox in same tx, 3 s DB timeouts, graceful shutdown, `/host -healthcheck` flag.
- `Dockerfile` (3 stages, distroless static nonroot), `compose.yml` (project `tsr-go-spike`, :8090, external network `tsr-app-dev_default`).
- `bench/` throwaway load tool (used only for the incidental numbers below).

## Measurements
| | Go + wazero (:8090) | C# (tsr-app-dev-api-1) |
|---|---|---|
| Contract tests | 7/7 pass | 7/7 pass (via gateway :8088) |
| Image size | 16.1 MB | 263 MB |
| Idle RSS (fresh restart, then 6 s) | 92.7 MiB | 83.3 MiB (running for a while) |
| Idle RSS after ~1,100 requests | 106.9 MiB | 85.0 MiB |
| Go modules (non-self) | 4 total: 2 direct (wazero, mysql), 2 transitive (x/sys, edwards25519) | n/a (NuGet not counted) |
| Cold build (`--no-cache`, base images cached) | 12.5 s | not measured |

Incidental, not the scoped benchmark: wazero call in-process (Apple M4, 300 iterations) 1.53 ms instantiate-per-call
(8.5 MB allocated per call) vs 14 us pooled. End to end 500 sequential requests were about 1.8 ms mean for Go
:8090 and 1.9 to 2.2 ms for C# via the nginx gateway (noisy, extra hop, not like for like). Treat as indicative only.
Native-binary end to end (before the scope cut): instantiate mode 4.1-4.3 ms mean vs pool 1.4 ms; first 201 after 774 ms in instantiate mode (includes compile).
The RSS is high for Go because 8 pooled Go-compiled wasm instances each carry their own Go runtime heap; fewer
instances lowers it.

Contract tests ran with the SDK at `/usr/local/share/dotnet/dotnet` (10.0.401, arm64); the `dotnet` on PATH is not
the problem once that directory is first on PATH. Command:
`TSR_BASE_URL=http://localhost:8090 dotnet test domains/platform/spec/tests`.
Outbox row verified in DB: `platform.feedback_submitted` with `{"feedbackId","submittedAt","userId"}`.

## Friction
- Debugging across the boundary: a panic in the guest surfaces as a wazero error with a wasm stack trace, no
  debugger, no `dlv`. Logging from the guest needs WASI stdout wiring.
- Sharing types: none shared. `Input`/`Output` are defined in the guest and re-declared in the host (`Result`);
  drift is caught only by the in-Wasm test. Contract is hand-written JSON.
- Testing: the rules are pure Go, so `go test` runs them natively (fast, normal tooling). A second test
  (`host/wasm_test.go`) runs vectors through wazero to prove the .wasm behaves the same. Running `go test`
  itself inside wasip1 needs an external runner (not installed), so was not done.
- Binary weight: standard Go wasm is 4.4 MB for two trivial rules (TinyGo not allowed here); compile at startup
  is the slow part of start-up.
- Pooling is required in practice (100x faster than instantiating), which adds state to manage: guest memory
  reset (`alloc` resets), pool size, and a poisoned-instance policy that the spike does not have.
- Honest read: for these two rules the Wasm layer adds machinery and no isolation benefit that the C# value
  objects lack; the gain would only appear for rules that must be shared across hosts or sandboxed.

## Hacked or skipped
- No govulncheck, no start time, no cold C# build, no instantiate-vs-pool end to end (scope cut).
- Invalid JSON body returns 400 `Invalid request body`/guest 422; the C# behaviour for malformed JSON is not matched and untested.
- Auth is the dev X-Dev-Token path only. Outbox `submittedAt` is RFC3339 UTC, not .NET's `+00:00` format.
- No pool recovery on guest trap; no 403 contract case (the 7 tests do not cover it).
- Synthetic rows written to dev DB (user 900001's member, clientIds random).

## Stop
`docker compose -p tsr-go-spike down` (from `spikes/go-wasm/`; stack is currently running on :8090).
