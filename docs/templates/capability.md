# <Capability name>

Owner domain: `<context>` · Status: live | partial | planned

<!--
Living document: describes the capability as it is TODAY. Rewrite it in every PR that changes
behaviour; never record history here (git keeps it). Requirement IDs are never reused; a removed
requirement is deleted from this file, and the PR that removes it says so.
Requirements: ISO/IEC/IEEE 29148, written in EARS, one behaviour per requirement.
Quality: ISO/IEC 25010. Verification methods: Test, Demonstration, Inspection, Analysis.
Priority: MoSCoW. Each fact has one home in this file; refer to it, don't repeat it.
Workflow: the spec-driven-development skill.
-->

## 1. Purpose
What this capability does for whom, and why it exists. 2-4 sentences.

## 2. Actors and scope
- **Actors:** member, coordinator, teacher, admin, system ...
- **In scope:** ...
- **Out of scope:** ...

## 3. Requirements (current behaviour)
| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| <CAP>-R1 | WHEN ... THEN the system SHALL ... | ... | Must | Test: `<file>` `<test name>` |
| <CAP>-R2 | IF ... THEN the system SHALL ... | ... | Must | Test: none yet (see section 9) |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| <CAP>-Q1 | Security | ... | ... | Must | Inspection: `<file>` |

## 5. Rules and permissions
Permissions (`access`) and scopes (e.g. gender). Limits live in their requirement; do not repeat them here.

## 6. Interfaces
- **Screens:** ...
- **API:** routes (contract tests in `spec/tests/`)
- **Events:** publishes / consumes ...

## 7. Data
Tables owned · PII classification · retention, and what happens on account deletion.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| <CAP>-D1 | ... | ... |

## 9. Known limitations, gaps and open questions
- **Test gaps:** requirements whose method is Test but which have no test yet.
- **Open questions:** ...
