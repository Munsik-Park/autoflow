# Reduced fixture — issue #134 cycle-1 Phase B, `## Acceptance criteria` (issue #138)

Reduced replay fixture for the AC-authority reconciliation channel's replay half
(dispatch obligation 3, `.autoflow/issue-138-dispatch.md` item 3; verification
design row `ac-diff-input-is-the-real-witness`). Reduced under the AC-id-column
schema this cycle introduces (feature design > *The acceptance-criterion list
becomes one addressable artifact*) from the four issue-stated acceptance
criteria recorded in the archived
`$AUTOFLOW_ARCHIVE_ROOT/Munsik-Park__autoflow/issue-134-2026-08-23/issue-134-phase-b.md`
> Acceptance criteria (checkable). The archive predates the `AC id` column, so
the ids below (`AC1`..`AC4`) are assigned in the archive's own listed order —
the same order `.autoflow/issue-138-phase-b.md`'s own narrative (case 1) uses
when it names "AC1" for the duplicate-run-ac criterion.

## Acceptance criteria

| AC id | criterion | source |
|---|---|---|
| AC1 | If, within one cycle, the same run-set (identical md5) is executed two or more times against the same tree, the ledger must carry a recorded reason (`run-reasons`) for the repeat; a repeat with no recorded reason causes VALIDATE to FAIL. | issue-134-phase-b.md > Acceptance criteria (checkable), bullet 1 |
| AC2 | Developer AI transcripts/reports contain no invocation of `run-suites.sh --all` (verified via one pilot cycle). | issue-134-phase-b.md > Acceptance criteria (checkable), bullet 2 |
| AC3 | There is a record (ledger entry field, or hook log) from which it can be re-derived that the capture-point run, REFINE step 2, and the VALIDATE sweep were each executed in the foreground. | issue-134-phase-b.md > Acceptance criteria (checkable), bullet 3 |
| AC4 | During acceptance runs, `green-tree` registration rejections caused by a teammate commit mid-run (the O5 pattern) occur zero times in the pilot cycle. | issue-134-phase-b.md > Acceptance criteria (checkable), bullet 4 |
