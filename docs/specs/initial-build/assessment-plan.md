# Assessment: batch plan and decisions (12 Nov 2026)

The 43 assessment operations of `operations.csv`, in six batches. Each batch: build (Sonnet `developer`), one unanchored review, fixes test-first, a full re-run by the main thread, a report, then Asif's go-ahead.

| Batch | Operations | What | Budget (subagent tokens) | State |
|---|---|---|---|---|
| A1 | 9 | a member takes a quiz and reads scores | 500k | built, commit cc83a55 (`assessment-a1-notes.md`) |
| A2 | 12 | a teacher or class admin manages a class's quizzes: list, create, edit, deactivate, standard MCQs, copy | 600k | building |
| A3 | 5 | scores, offline answers, the printable sheet (PDF through platform's `ReportExport`/Gotenberg), publish | 450k | |
| A4 | 8 | MCQ summary and adherence reports with CSV, xlsx and PDF | 450k | |
| A5 | 2 | standard MCQ sources and update | 250k | |
| A6 | 7 | quiz competition admin (settings, download, winners, publish, reset) | 700k plus a design | |

## Decisions (Asif, 12 Nov 2026)

1. **Publishing a quiz (A3).** PHP inserts a notification, fans it out to each student's inbox and queues a push message. Assessment calls a published command of `notifications` (and of `platform` for the outbound message row, if PHP's row is kept) on its own transaction and sends nothing itself. No push goes out until the notifications worker exists.
2. **The eight MCQ reports (A4) move to the `classes` domain.** They reuse its report machinery (`ReportScope`: gender lock, reach filter, demo class) and its adherence query; classes reads assessment through `v_*` views. `operations.csv` changes their domain to `classes`.
3. **Google Sheets (A5, A6).** Standard MCQ update reads one sheet; the quiz competition admin reads two and writes one. They are built behind one interface at the external boundary with a fake for tests. They cannot be parity-tested against PHP (neither stack has credentials); they are proven against real Sheets later with credentials Asif supplies.
4. **Quiz competition state (A6).** PHP keeps settings, participants, scoreboard and winners in JSON files on disk. Here: one small table in `assessment` holding the same JSON documents (a new migration), so more than one API instance works.

## PHP looseness copied so far, to decide later

A1: one throwaway submission returns the whole answer key; a student who scored 0 can read the questions again; by-code tells a non-member whether a code exists; students of a closed class can still take an open quiz; a child removed from a class still passes the parent's check.
