# Manual verification scenarios — issue #138 (AC-authority reconciliation)

Source: `.autoflow/issue-138-verification-design.md` (rows typed `manual` or
`automated + manual`) and `.autoflow/issue-138-dispatch.md` obligation 3.
These properties are exhibited only by a live agent (a real DIAGNOSE Phase B
run, a real orchestrator, a real Evaluation AI, a real `ac-diff` channel) and
have no automated layer that can drive them — see verification design >
Verification depth determination > *Manual scenarios*.

**Effective from.** Every check below binds only a cycle whose DIAGNOSE
authored its `## Acceptance criteria` table under this cycle's clause — the
same *Effective from* convention the composition-oracle and
verification-depth ledger clauses already use (feature design > *The two gate
backstops* > *Effective from*). This verification design (and this scenario
document) is itself authored **before** the GREEN implementation lands, so
none of the scenarios below are executable until GREEN + the doc edits merge;
they are the acceptance checklist for that state, not a check against the
current (pre-#138) tree. A cycle already past DIAGNOSE when #138 lands is not
retroactively deficient for lacking the table.

---

## M1 — AC4: an `[ac-decision]` ledger entry lifts the GATE:PLAN / GATE:QUALITY cap (operator-entry-lifts-the-cap)

**Verifies**: AC4 — "When an operator-decision ledger entry is present, the
same input is evaluated with no cap applied."

**Method**: run the *same* design input through a real, fresh-spawned
Evaluation AI (GATE:PLAN role) twice, changing only the ledger:

1. Input A — `tests/fixtures/issue-138-ac-phase-b.md` +
   `tests/fixtures/issue-138-ac-verification-design.md` +
   `tests/fixtures/issue-138-ac-ledger-no-decision.md` (no `[ac-decision]`
   entry covers AC1's `not carried as a criterion` disposition).
2. Input B — the same two design documents +
   `tests/fixtures/issue-138-ac-ledger-with-decision.md` (an `[ac-decision]`
   entry for AC1 is present).

**Outcome→verdict mapping, fixed before the run** (per verification design row
`operator-entry-lifts-the-cap`, no automated layer can assert what a model
scores):

- Input A → the evaluator's `Scope` item is capped at **6** (`AC-authority
  check`, `docs/autoflow-guide.md` > GATE:PLAN), citing the AC1 difference
  with no covering `[ac-decision]` entry.
- Input B → `Scope` is scored on the rubric with **no cap applied** from the
  AC-authority check — the `[ac-decision]` entry for AC1 discharges it.

A run that caps Input B, or that fails to cap Input A, is a FAIL of this
scenario and is reported to the team lead — it does not silently pass.

---

## M2 — AC3 replay: the #134 cycle-1 `gate-plan-3` input re-evaluated under the amended rubric (unauthorized-drift-caps-scope / -completeness)

**Verifies**: AC3 — "For a design/change set with an AC difference that has
no operator-decision ledger entry, GATE:PLAN `Scope` and GATE:QUALITY
`Completeness` are recorded at 6 or below," verified per the issue's own
stated method: *"Re-evaluate the #134 cycle 1 `gate-plan-3` input and confirm
the verdict flips from PASS to FAIL."*

**Input**: `tests/fixtures/issue-138-gate-plan-3-excerpt.md` (the reduced,
verbatim `gate-plan-3.md` Scope score — historically **8**, no cap) together
with `tests/fixtures/issue-138-ac-phase-b.md`,
`tests/fixtures/issue-138-ac-verification-design.md`, and — per the
no-decision/with-decision pairing M1 uses — first
`tests/fixtures/issue-138-ac-ledger-no-decision.md`, then
`tests/fixtures/issue-138-ac-ledger-with-decision.md`.

**Method**: spawn a real, fresh Evaluation AI under the amended GATE:PLAN
rubric text (post-GREEN `docs/autoflow-guide.md` > GATE:PLAN > `AC-authority
check`) against the excerpt plus the no-decision ledger variant. Confirm:

- the AC-authority check identifies the AC1 (`duplicate-run-ac`) difference
  between the Phase B table (AC1: carried) and the verification design (AC1:
  not carried as a criterion) as uncovered by any `[ac-decision]` entry;
- `Scope` is recorded at **6 or below** (flipping the historical PASS —
  Scope 8, avg above the GATE:PLAN threshold — toward FAIL on this item);
- re-running the same excerpt against `issue-138-ac-ledger-with-decision.md`
  restores the uncapped score, confirming the cap is keyed to ledger coverage
  and not to the excerpt's content alone.

A run that does not flip is reported to the team lead, not silently accepted
as compliant — this is the incident's own reproduction case, and the point of
GREEN is that it must now flip.

---

## M3 — AC2 (orchestrator behaviour): a live `AC_CHANGE` return halts before GATE:PLAN

**Verifies**: AC2's residual not covered by the doc-invariant entries
(`138-claude-flowcontrol-ac-change` etc.) — that a live orchestrator, on
receiving an `AC_CHANGE` verdict from `architect-deliberation`, actually
follows the documented row (`CLAUDE.md` > Flow Control:
`ARCHITECT (AC_CHANGE) → user`) instead of merely having the row present in
prose.

**Method**: drive a real ARCHITECT deliberation whose converged verification
design carries a dropped AC (reuse `tests/fixtures/issue-138-ac-phase-b.md` /
`issue-138-ac-verification-design.md` as the Draft-stage seed materials, or a
fresh design with the same shape). Confirm the orchestrator:

- does not spawn a GATE:PLAN evaluator on that run;
- reports situation-first (`CLAUDE.md` > Execution Principles >
  Human-decision presentation) naming the dropped/substituted/deferred AC(s)
  and the operator's three options (exclude / revise / split);
- sets `active: false`, `phase: "awaiting-user"` in `.autoflow/issue-{N}.json`.

---

## M4 — ac-table-survives-review-response: a review-response Phase B carries the AC table forward

**Verifies**: feature design > *Authored once per issue* — a review-response
cycle's Phase B does not regenerate the `## Acceptance criteria` table (which
would silently empty the join key and route every downstream check to the
`ac list absent` sentinel).

**Method**: take an issue whose `mode = new-issue` DIAGNOSE already authored a
`## Acceptance criteria` table in `.autoflow/issue-{N}-phase-b.md`. Trigger a
review-response cycle on that same issue (an external reviewer comment).
Confirm the resulting review-response Phase B artifact carries the **same**
AC table (same ids, same criterion text, same source column) forward
unchanged — the review-response Phase B targets the reviewer comment, not the
issue body, per `docs/phases/analysis.md:92`, and a reviewer comment never
edits the AC list; only an operator decision does.

---

## M5 — Transcription fidelity: the real `ac-diff` channel reads the declared grammar, faithfully

**Verifies**: the two model-reading residuals the verification design states
explicitly are NOT asserted by any automated layer — `ac-diff-input-is-the-
real-witness` (replay half, transcription fidelity) and the ledger-grammar
half of the composition-oracle determination.

**Method**: drive a real ARCHITECT Reconcile phase (`label: 'ac-diff'`) over
`tests/fixtures/issue-138-ac-phase-b.md` +
`tests/fixtures/issue-138-ac-verification-design.md`, once against each ledger
fixture variant (`issue-138-ac-ledger-with-decision.md`,
`issue-138-ac-ledger-no-decision.md`). Confirm on the returned `AC_DIFF`
payload:

- **`ledger_ac_decisions` grammar.** Against the WITH-decision variant, the
  returned list contains exactly `AC1` — copied only from the level-2 heading
  ending in `[ac-decision]` and that entry's `- AC:` line — and excludes: a
  prose mention of AC1 elsewhere in the ledger (e.g. the O1 entry's
  `Decision:` line, which names "AC1 (duplicate-run-ac)" in prose, not under
  the `[ac-decision]` marker), and any `- AC:` line that might appear under a
  differently-marked or unmarked heading. Against the NO-decision variant, the
  returned list is empty — the O1 entry's prose mention of AC1 must not leak
  in.
- **`ac_rows` completeness and order.** The returned `ac_rows` carries **one
  row per AC id in `issue-138-ac-phase-b.md`, in that table's order** (AC1,
  AC2, AC3, AC4) — no omitted row, no reordering — with `disposition` and
  `reason_stated` read as the schema defines them from
  `issue-138-ac-verification-design.md`'s cells (AC1: `carried: false`,
  `disposition: 'absent'`; AC4: `carried: true`, `disposition: 'reduced'`,
  `reason_stated: true` — a reasoned reduction, so no finding under the issue
  #153 narrowed set; AC2/AC3: `carried: true`, `disposition: 'automated'`,
  `reason_stated: false` — an automated row owes no reason, and the field is
  read from the empty Reason cell, never inferred). The `AC_CHANGE` verdict for
  this fixture therefore rests on AC1's `dropped` finding alone. An omitted row is a
  silent convergence the script cannot detect on its own — this is the sole
  layer that can catch it, per verification design > Testability assessment >
  `script-has-no-filesystem`.
