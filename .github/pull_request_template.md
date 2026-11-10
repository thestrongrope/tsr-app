Closes #<issue>

<!--
Plan: open this PR as a DRAFT before writing code; get the plan reviewed first.
Verification: test cases per ISO/IEC/IEEE 29119-3, steps in Gherkin. Every requirement ID in the issue
needs at least one test case. Workflow: the spec-driven-development skill.
-->

## Approach
A few lines: how, and why this way.

## Changes
Per domain / host / app: what changes and where (files or areas).

## Data and migrations
Expand-then-contract steps, or "none".

## API and event changes
Additive only? Any impact on store-live app builds?

## Risks and rollback

## Verification plan

### TC-<REQ-ID>-01: <title>
Covers: <REQ-ID> · Method: Test | Demonstration | Inspection | Analysis · Level: unit | API contract | UI
Automated in: `<file>` `<test name>` (or: manual, for Demonstration and Inspection)
Preconditions: ...
```gherkin
Given ...
When ...
Then ...
```
Result: ☐ pass

### Standard gates (the project's own commands: root `CLAUDE.md`)
- [ ] Build: 0 warnings (analyzers, AOT analyzers)
- [ ] AOT publish
- [ ] Unit tests
- [ ] Contract tests against the AOT image
- [ ] `flutter analyze` and app tests (if the app changed)

## Living document update
`domains/<context>/capabilities/<capability>.md`: sections rewritten; IDs added, changed or retired.
- [ ] Updated in this PR (or: no behaviour change)

## Tasks (only for multi-session or multi-agent work)
- [ ] ...
