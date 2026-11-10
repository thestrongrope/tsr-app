---
name: Feature or change (spec)
about: What users need and why. No technical detail; the plan goes in the PR.
labels: feature
---

<!-- Spec: what and why only. If a sentence names a table, endpoint, function or library, it belongs in the PR plan. -->

## Problem / need
Who is affected, and why now.

## Outcome
What success looks like for users, and how it will be measured.

## Requirements
New, changed or retired requirements, in EARS, one behaviour each, with IDs from the capability document
(`domains/<context>/capabilities/<capability>.md`; new IDs continue its numbering, never reuse one).
Include at least one unwanted-behaviour requirement (`IF ... THEN the system SHALL ...`).

| ID | New / changed / retired | Requirement (EARS) | Rationale | Priority |
|---|---|---|---|---|
| <CAP>-R? | new | WHEN ... THEN the system SHALL ... | ... | Must |

## Out of scope

## Open questions
