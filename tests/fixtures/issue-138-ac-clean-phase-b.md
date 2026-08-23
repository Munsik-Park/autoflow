# Clean-convergence fixture — Phase B AC table, no drift (issue #138)

Negative control for the Risk line's false-positive arm (feature design > *The
false-positive arm has its own layer*; verification design row
`clean-fixture-yields-no-findings`). Every AC id here is carried by a
verification-design row with a `verified` disposition and an executable
method in `issue-138-ac-clean-verification-design.md` — the run over this
pair must return `CONVERGED` with no findings.

## Acceptance criteria

| AC id | criterion | source |
|---|---|---|
| AC1 | The `architect-deliberation` workflow returns `AC_CHANGE` instead of `CONVERGED` for a verification design that deletes, substitutes, or marks an AC row as NOT CARRIED. | .autoflow/issue-138-phase-b.md > Acceptance criteria |
| AC2 | On an `AC_CHANGE` return, the orchestrator does not spawn GATE:PLAN and instead halts with `phase:"awaiting-user"`. | .autoflow/issue-138-phase-b.md > Acceptance criteria |
