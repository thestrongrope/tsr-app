# Change-run brief (identical for every run; only the bracketed values differ)

Sent verbatim to a Sonnet `developer` agent, one run per side and task, each in its own fresh worktree.

---

Make this one change to the `access` domain in the worktree `[WORKTREE]`. Never commit, push or merge.
Work only in that worktree; use lane stack `[LANE]` only (`TSR_STACK=[LANE]`); never touch port 8088 or any other stack.

The change: [TASK TEXT, copied from plan.md "Change tasks"]

Where the code is: [SIDE A/B: `domains/access/` (C#), read `domains/CLAUDE.md` and `domains/access/CLAUDE.md` first |
SIDE C: `spikes/go-access/` (Go), read `spikes/go-access/README.md` or `docs/specs/go-spike/port-notes.md` first].

Test first: write the failing test, see it fail, then make it pass. Gate, all must pass before you report:
[SIDE A/B: `dotnet build TsrApp.slnx` with 0 warnings, `dotnet test domains/access/api/tests`, the access `db/tests`
(filter), and every access Hurl file plus the one you add, against lane [LANE] |
SIDE C: `go vet ./...`, `go test ./...`, and every access Hurl file plus the one you add, against lane [LANE]].

Report: files changed with line counts added and removed, the gate results, and how many times a gate failed
before it passed (rework rounds).
