# Clean-convergence fixture — verification design rows, no drift (issue #138)

Companion to `issue-138-ac-clean-phase-b.md`. Every `Issue AC` id from that
table is carried here, `automated`, with a method naming an executable
artifact — the honest-convergence input the false-positive-arm layer
(`clean-fixture-yields-no-findings`) must NOT fire a finding against.

## Acceptance criteria → verification type → method

| Issue AC | Acceptance criterion | Type | Kind | Method | Reason |
|---|---|---|---|---|---|
| AC1 | ac-change-verdict-returns | automated | driving | `test/workflows/run.mjs` — "an unauthorized ac-diff finding returns AC_CHANGE" | — |
| AC2 | no-gate-plan-after-ac-change | automated (doc-invariant) + manual | driving | `tests/fixtures/doc-invariants.json` entry `138-claude-flowcontrol-ac-change` + `tests/manual/issue-138-manual-scenarios.md` | — |
