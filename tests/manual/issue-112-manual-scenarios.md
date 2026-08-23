# Issue #112 — Manual/Environment-Dependent Verification Scenarios

Two items in `.autoflow/issue-112-verification-design.md` > *Untestable items* have
no in-repo observer and are discharged here rather than by an automated layer:
the whole-tree run's once-per-cycle position, and the gate evaluator's actual
adherence to the wall-clock cap and the representative-sample default. Both
are agent-execution properties, not tree properties, and neither is a
triggered composition contact point (Composition-oracle determination finds no
`T ∩ S` row for either) — the reasons the verification design gives for why no
automated oracle exists. Every other automated criterion in the design is
discharged by `tests/test-suite-coverage-agreement.sh`
(`origin_issue`-untagged, new agreement suite), by
`tests/fixtures/doc-invariants.json` (`origin_issue: 112` entries), by the
resolver's own hermetic `--self-test` (once shipped), or by the existing
standing suites `tests/test-push-context-base-ref.sh` and
`tests/test-issue-103-central-runner.sh` (extended with new legs this cycle).

---

## AC one-offerable-full-run — the whole-tree run happens once per cycle, at VALIDATE, and no more

**Why not automated:** the record shape (a `green-tree` entry with `suites`
naming the enumerated set, `runner: VALIDATE step 1`) proves a full run
*happened and was registered*; nothing in the repository observes the
*absence* of an additional, unregistered whole-tree run elsewhere in the same
cycle — that is a property of a cycle's execution history, not of the tree at
any single capture point. The record-shape half is automated (register-entry
grammar with `suites`, `tests/fixtures/doc-invariants.json` entries
`112-validate-step1-all-unconditional` / `112-validate-step1-no-resolver`);
this scenario covers only the runtime-frequency half.

### Fixed inputs

- One full AutoFlow cycle carried through VALIDATE, on this repository, after
  the issue's implementation lands (post-GREEN/REFINE).
- The cycle's own `.autoflow/issue-{N}-ledger.md` `green-tree` /
  `green-tree-use` entries for the cycle.

### Steps

1. Walk the cycle's ledger entries in file order. Count how many
   `green-tree` entries carry `runner: VALIDATE step <S>` for this cycle.
2. Confirm exactly one such entry exists for the cycle, its capture point was
   clean (`worktree: clean`), and its `suites` field names the full enumerated
   set (`bash scripts/test/suite-manifest.sh` sourced, `suite_enumerate`, over
   the tree at that entry's `tree` hash — cross-check by count and by spot
   sample rather than a full re-listing).
3. Confirm no other `green-tree` entry of the cycle also carries the full
   enumerated set as its `suites` value outside the VALIDATE step (a second
   full run recorded elsewhere would indicate the floor moved from its named
   position, or that VALIDATE ran more than once without an intervening
   VERIFY/AUDIT/GATE:QUALITY FAIL routing it back through RED).
4. Record the outcome — `passed` (exactly one full run, at VALIDATE) or
   `deviation` (zero, or more than one, or misplaced) — with the ledger
   heading(s) inspected as the anchor.

### Expected outcome

Exactly one `green-tree` entry per cycle carries `runner: VALIDATE step <S>`
and names the full enumerated set; no other entry in the cycle does.

---

## AC evaluator-execution-discipline — the gate evaluator honours the wall-clock cap and the representative-sample default

**Why not automated:** agent execution time and search breadth leave no
artifact the repository can read. The contract text (the `[MUST]`s themselves)
and the report-schema key (`inherited_verdicts`, with its always-present
discipline) are both automated —
`tests/fixtures/doc-invariants.json` entries `112-evaluator-citation-inheritance-must`,
`112-evaluator-sampling-default`, `112-evaluator-time-cap`, and
`tests/test-suite-coverage-agreement.sh`'s evaluator-citation-carrier leg. Only
the runtime behaviour — did the evaluator actually stop at the cap, actually
sample rather than enumerate, actually cite rather than re-run — is manual.

### Fixed inputs

- One gate evaluation run (GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY)
  spawned after the issue's implementation lands, against a cycle whose host
  has at least one `green-tree` entry the evaluator's own capture point
  matches (so citation-inheritance has something real to exercise).
- The evaluator's own report JSON for that run.

### Steps

1. Read the evaluator's report JSON. Confirm `inherited_verdicts` is present
   (never absent) — `[]` only if the evaluator's own capture point matched
   nothing inheritable.
2. For each member of `inherited_verdicts`, confirm the cited `source` heading
   actually exists in the host's ledger and its `head` is an ancestor of the
   evaluator's own capture point (spot-check with
   `git merge-base --is-ancestor <head> <capture>`), i.e. the citation is not
   fabricated.
3. Confirm the evaluator did **not** independently re-execute a suite it cited
   as inherited — cross-check the evaluator's own run log / tool-call record
   against the `inherited_verdicts` list; a suite appearing in both is a
   contract violation.
4. Confirm the evaluation's `fail_hypothesis` records a declared wall-clock
   cap and, if the cap was reached, that every unsearched item is recorded
   `not-searched` rather than omitted or scored clean.
5. Confirm blind-spot search breadth: a representative sample (1-2 instances)
   per rubric item by default, with exhaustive enumeration entered only after
   a sampled FAIL survives refutation (`fail_hypothesis.case` / `disposition`).
6. Record the outcome — `passed` (all four properties hold) or `deviation`
   (name which) — with the evaluator's report-JSON path/anchor and the ledger
   heading(s) cross-checked as the evidence.

### Expected outcome

`inherited_verdicts` is present and its citations verify against the real
ledger; no cited-inherited suite was also re-executed; the wall-clock cap is
declared and honoured with truthful `not-searched` recording; blind-spot
search defaults to a representative sample.
