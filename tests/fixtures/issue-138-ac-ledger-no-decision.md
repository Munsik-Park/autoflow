# Reduced ledger fixture — variant with NO `[ac-decision]` entry (issue #138)

Companion to `issue-138-ac-ledger-with-decision.md`. Byte-identical except the
`[ac-decision]` entry is absent — the shape the #134 incident actually shipped
with before the 13:33Z operator decision (`.autoflow/issue-138-body.md` case
1). Used by the manual replay scenario to exercise the `unauthorized-drift-
caps-scope` / `unauthorized-drift-caps-completeness` cap (no ledger entry
covers the AC1 difference, so the cap applies) against the WITH-decision
variant's cap-lifted control.

# Decision Ledger — issue #134 (reduced replay fixture)

## O1 — duplicate-run-ac not carried as a criterion (cycle 1, ARCHITECT)

- Decision: AC1 (duplicate-run-ac) is not carried as a criterion
- Grounds: the offered replacement is an identity (`mismatch-cause: none` ≡ `outcome: inherited`)
- Authority: ARCHITECT mutual ACCEPT
- Cycle/Phase: cycle 1, ARCHITECT
