# Verification design — clean fixture (issue #166)

## 1. Risk line

If this is wrong, the operator re-runs a deliberation that already converged.

## 2. Acceptance criteria

| Issue AC | Acceptance criterion | Type | Kind | Method | Reason |
|---|---|---|---|---|---|
| AC1 | the checker reports a register section | automated | driving | suite | — |

The turn-based rule pairs each turn with its predecessor; the register the script holds is the record.
Evidence: the harness scenario names the closed list, checked by grep over the rendered prompt.
