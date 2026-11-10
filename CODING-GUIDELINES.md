# Coding guidelines

The source of truth for how code is written in this repository, for everyone: contributors,
reviewers and AI assistants. They are adapted from Holzmann's Power of Ten and common SOLID/DDD
practice, and favour short, linear, reviewable units, explicit contracts and static analyzability.

**MUST** = enforce with tooling where the stack allows it; a violation is a defect.
**SHOULD** = review judgment; deviate with a stated reason.
This codebase has legacy code, so the rules apply to **new and changed code** (a ratchet), not to a
rewrite of what you did not touch.

What checks each rule today, and what is review-only, is listed per stack in
[`docs/dev/php.md`](docs/dev/php.md) and [`docs/dev/mobile.md`](docs/dev/mobile.md).
Those tables, not this file, say whether a rule is actually enforced.

## MUST

1. **Simple, linear control flow.** Guard clauses and early returns. Nesting <= 3 levels,
   cyclomatic complexity <= 10. Recursion only when clearly bounded and justified.
2. **Bounded work.** Anything that can run away has a limit: I/O, retries, polling, queues,
   queries. Use pagination, `Take`/`LIMIT`, counters, max attempts with backoff, cancellation.
   Long-running work is cancellable. (A loop over an in-memory list is already bounded.)
3. **Timeouts on every external call** (HTTP, DB, queue, subprocess).
4. **Validate at boundaries** (API, UI input, external calls). Inside methods, guard clauses or
   assertions for invariants. Fail fast with a clear message.
5. **No silent failures.** Never swallow an exception or ignore a return value. Use structured
   errors (Result, Problem Details, typed exceptions) for expected failures, not silent nulls or
   empty defaults. Pick **one primary mechanism per stack** (e.g. Result for expected failures,
   exceptions for bugs) and do not mix them.
6. **Strict typing.** Enable strict/nullable modes. No `any`, raw types or `dynamic` where a real
   type exists. Explicit types on public surfaces.
7. **Zero warnings in CI.** Compiler, linter and analyzer warnings are errors; run static analysis
   on every change.
8. **Release resources.** Dispose/close/`using`/`finally`; honour cancellation.
9. **No secrets and no PII in code or logs.** Treat all external input as untrusted.
10. **No dead code and no commented-out code.**
11. **Every bug fix lands with a regression test.**

## SHOULD

- **Short units.** Backend methods about <= 40-50 lines, <= 5 parameters. React components
  <= 150-200 lines (and few hooks/effects). One responsibility; extract helpers freely.
- **Smallest scope, immutable by default.** Declare near use; prefer records/readonly/const;
  minimise shared mutable state. State the rule for async and locking when shared state is unavoidable.
- **Small, honest interfaces** (Interface Segregation, Liskov). Interfaces only at external
  boundaries (I/O, clock, network, third parties); concrete types and records elsewhere. Do not
  add an interface or abstract class "just in case". Constructor injection for dependencies.
- **Limit magic.** No heavy reflection, dynamic invocation or metaprogramming in business logic.
  Build-time generation over runtime magic. Accepted exceptions: the DI container, the ORM and
  the serializer.
- **Lightweight DDD.** Ubiquitous language in names, clear module boundaries, value objects that
  carry validation, thin application services. Full tactical DDD only when domain complexity
  clearly outweighs the indirection.
- **Reviewability over cleverness.** A human or AI reviewer should follow the code without deep
  context: obvious structure, named values, small pure helpers. Comments explain *why*, not *what*.

## Enforcement

Each MUST maps to a tool where one exists. Where none does, the rule is checked in review, and the
stack docs above say so plainly. Do not claim a rule is enforced when no tool checks it.
