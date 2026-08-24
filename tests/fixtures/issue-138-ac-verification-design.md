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

| Issue AC | Acceptance criterion | Type | Kind | Method | Reason |
|---|---|---|---|---|---|
| AC1 | duplicate-run-ac | **not carried as a criterion** | — | no layer. The ledger branch is refused on re-derived grounds and the offered replacement is an identity, so no verifiable content remains | — |
| AC2 | dev-sweep-ban | automated | driving | `AC-2g` mirror diff over `.claude/agents/autoflow-implementer.md` | — |
| AC3 | foreground-record | automated | driving | `BG_SCAN` hook coverage (the sweep-fits-the-tool-ceiling residual is the design-added manual row below) | — |
| — | foreground-record — sweep-fits-the-tool-ceiling residual | manual | — | `tests/manual/issue-134-manual-scenarios.md` sweep-fits-the-tool-ceiling scenario | — |
| AC4 | **parallel-suite-option** | **deferred — not verified in this cycle** | — | precondition unmet: `run-suites.sh` executes every suite as `(cd "$root" && bash "$suite")` against the shared repository root (`scripts/test/run-suites.sh:171,184`); no per-suite sandbox exists | verifying a parallel option without isolation would certify the contamination the issue cites |

The `Type` / `Kind` / `Reason` columns follow the issue #153 grammar
(`docs/autoflow-guide.md` > ARCHITECT > Output artifacts > *Test necessity*).
AC1 is the `dropped` arm — the row states a disposition but carries no `Issue AC`
join for the criterion's own content. AC4 is a **reasoned** reduction: it states
its reason, so under the narrowed finding set it is NOT a finding — it is the
deliberation exercising tier 1, carried to the PR body for the reviewer.

AC1's disposition is the archive's `duplicate-run-ac (issue criterion 1)` row
(`issue-134-c1-verification-design.md:237`): *"not carried as a criterion"*.
AC4's disposition is the archive's `parallel-suite-option (issue criterion 4)`
row (`:238`): *"deferred — not verified in this cycle"*. Both are re-derived,
not invented, from the archived artifact.
