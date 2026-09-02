# Regression fixture — the #157 cycle-1 verification-design shape (issue #160)

One issue acceptance criterion verified by **two** rows, each stating the proposition its own
method checks. The AC's content is unchanged; the split is a verification-method choice. Under the
pre-#160 Reconcile the second row (`substituted`: "asserts a different property") paused the run
for the operator. Companion: `tests/fixtures/issue-160-ac-diff-split-rows.json` is the payload the
ac-diff transcription channel returns for this table — one `ac_rows` entry per AC id, each
`carried`, and no property comparison.

## Acceptance criteria → verification type → method

| Issue AC | Acceptance criterion | Type | Kind | Method | Reason |
|---|---|---|---|---|---|
| AC1 | Reconcile's finding kinds are `dropped` / `unreasoned` only, computed without semantic judgment | automated | driving | `AC_DIFF` schema carries no `substituted` list; `acKindOf` derives two kinds | — |
| AC1 | the ac-diff prompt carries no property-comparison instruction | automated | driving | prompt text scan in the turn harness (`issue-160-ac-diff-prompt-no-property-comparison`) | — |
| AC2 | a one-AC-two-rows design converges without an operator pause | automated | regression | harness scenario `issue-160-split-rows-no-pause` over this fixture's transcription | — |
