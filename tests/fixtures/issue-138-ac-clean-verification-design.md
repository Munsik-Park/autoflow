# Clean-convergence fixture — verification design rows, no drift (issue #138)

Companion to `issue-138-ac-clean-phase-b.md`. Every `Issue AC` id from that
table is carried here, `verified`, with a method naming an executable
artifact — the honest-convergence input the false-positive-arm layer
(`clean-fixture-yields-no-findings`) must NOT fire a finding against.

## Acceptance criteria → verification type → method

| Issue AC | Acceptance criterion | Verification type | Method |
|---|---|---|---|
| AC1 | ac-change-verdict-returns | automated | `test/workflows/run.mjs` — "an unauthorized ac-diff finding returns AC_CHANGE" |
| AC2 | no-gate-plan-after-ac-change | automated (doc-invariant) + manual | `tests/fixtures/doc-invariants.json` entry `138-claude-flowcontrol-ac-change` + `tests/manual/issue-138-manual-scenarios.md` |
