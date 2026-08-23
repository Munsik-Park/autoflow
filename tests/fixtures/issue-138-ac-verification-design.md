# Reduced fixture — issue #134 cycle-1 converged verification design, disposition rows (issue #138)

Companion to `tests/fixtures/issue-138-ac-phase-b.md`. Reduced from the archived
`issue-134-2026-08-23/issue-134-c1-verification-design.md` disposition table
(the rows cited by `.autoflow/issue-138-phase-b.md` case 4 and by
`issue-134-gate-plan-3.md` Scope, both re-derived this cycle from the archive).
The `Issue AC` column is this cycle's own addition (feature design > *The
verification design joins on the id*) — the archive predates it; the values
below key each row to `tests/fixtures/issue-138-ac-phase-b.md`'s `AC id`
column by the archive's own criterion numbering.

## Acceptance criteria → verification type → method

| Issue AC | Acceptance criterion | Verification type | Method |
|---|---|---|---|
| AC1 | duplicate-run-ac | **not carried as a criterion** | no layer. The ledger branch is refused on re-derived grounds and the offered replacement is an identity, so no verifiable content remains |
| AC2 | dev-sweep-ban | automated | `AC-2g` mirror diff over `.claude/agents/autoflow-implementer.md` |
| AC3 | foreground-record | automated + manual | `BG_SCAN` hook coverage + `tests/manual/issue-134-manual-scenarios.md` sweep-fits-the-tool-ceiling scenario |
| AC4 | **parallel-suite-option** | **deferred — not verified in this cycle** | precondition unmet: `run-suites.sh` executes every suite as `(cd "$root" && bash "$suite")` against the shared repository root (`scripts/test/run-suites.sh:171,184`); no per-suite sandbox exists. Verifying a parallel option without isolation would certify the contamination the issue cites |

AC1's disposition is the archive's `duplicate-run-ac (issue criterion 1)` row
(`issue-134-c1-verification-design.md:237`): *"not carried as a criterion"*.
AC4's disposition is the archive's `parallel-suite-option (issue criterion 4)`
row (`:238`): *"deferred — not verified in this cycle"*. Both are re-derived,
not invented, from the archived artifact.
