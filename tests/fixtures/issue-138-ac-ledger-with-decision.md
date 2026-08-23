# Reduced ledger fixture — variant WITH an `[ac-decision]` entry for AC1 (issue #138)

Companion to `tests/fixtures/issue-138-ac-phase-b.md` and
`issue-138-ac-verification-design.md`. Used by the manual replay scenario
(dispatch obligation 3) and by the ac-diff channel's ledger transcription
grammar (feature design > *`authorized` is computed in the script, from a
transcribed id list*). This variant carries one operator-decision entry
authorizing AC1's removal.

# Decision Ledger — issue #134 (reduced replay fixture)

## O1 — duplicate-run-ac not carried as a criterion (cycle 1, ARCHITECT)

- Decision: AC1 (duplicate-run-ac) is not carried as a criterion
- Grounds: the offered replacement is an identity (`mismatch-cause: none` ≡ `outcome: inherited`)
- Authority: ARCHITECT mutual ACCEPT
- Cycle/Phase: cycle 1, ARCHITECT

## O13 — AC1 excluded under operator authority (cycle 1, HANDOFF) [ac-decision]

- AC: AC1
- Disposition: excluded
- Decision / Grounds / Authority: operator decision / cycle 1, HANDOFF
