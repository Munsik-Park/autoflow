# Issue #89 — Manual/Environment-Dependent Verification Scenarios

This carrier holds the rubric dry-run's fixed inputs and pass condition, per
the verification design (`.autoflow/issue-89-verification-design.md` Part 5)
and the feature design's §7 dry-run inputs. The dry-run oracle is an LLM
evaluator's judgment, which no repository test can observe — it is delegated
here so a re-run replays a fixed stimulus rather than an improvised one.

---

## AC-behavioral-effect — an evaluator prefers sufficient closure over textual smallness (Tier 3, manual, reproducible)

**Why not automated:** the rewritten criteria being literally present in the
target documents does not establish that an evaluator's *ranking* of
candidate diffs changes. That is a semantic effect on an LLM's judgment,
invisible to every text predicate in `tests/fixtures/doc-invariants.json`,
which reads only for the presence of words.

### Fixed inputs

**Scoring rule** given verbatim to the evaluator: the `### GATE:QUALITY
linkage` body as landed at `docs/submodule-common-rules.md` (feature design
§4.1). Nothing from the feature design, the issue body, or the ledger
accompanies it, and no hint of the preferred ordering is included — the
dry-run tests what the criterion text alone induces. A leading prompt would
produce the expected ranking from a criterion that changed nothing, which
would defeat the purpose of the scenario.

**Candidate diffs**, three synthetic variants against one synthetic module
and one synthetic defect statement, so the comparison is reproducible
byte-for-byte and depends on no repository history:

| Fixture | Content |
|---|---|
| `symptom-patch` | Guards the reported failing call site only; the shared helper producing the bad value is untouched; adds a test asserting the guarded call site. The narrowest of the three. |
| `cause-fix-with-required-cleanup` | Corrects the shared helper that is the confirmed cause, removes the now-unreachable guard branch and the one helper the correction renders unused, adds a test asserting the corrected helper. Larger, in lines and in files, than `symptom-patch`; every hunk traces to the confirmed cause or to a symbol/branch that hunk itself orphaned. |
| `unrelated-expansion` | The same shared-helper correction as `cause-fix-with-required-cleanup`, byte-identical in that half (so the untraceable hunks are the only variable), plus hunks that trace to neither the confirmed cause nor anything those hunks themselves rendered unreachable or unused: a renamed variable in an adjacent function, an added configuration option the defect statement does not ask for, and a docstring on code the diff does not otherwise change. The largest of the three. |

**Verbatim prompt shape**: the evaluator receives exactly three things —
(1) the §4.1 criterion body verbatim as the scoring rule, (2) the defect
statement and the three candidate diffs above, (3) the instruction to score
each candidate on `Minimal implementation` alone with a one-line reason. The
neutrality of the prompt (no preferred ordering hinted, no accompanying
design/issue/ledger material) is itself part of this scenario's pass
condition — a prompt that leaked the expected ranking would not test the
criterion text.

### Procedure

1. Spawn a fresh evaluator (no prior context of this issue or its design
   documents) with the verbatim prompt above.
2. Record the three scores and their one-line reasons.
3. Check the three conditions below. A tie between any two candidates is a
   **failure** of that condition, not a pass — under the as-is (pre-#89)
   criterion text a tie is the likeliest result, so treating a tie as a pass
   would make this scenario unable to detect an unchanged world.

### Expected outcome — all three conditions must hold

1. **`symptom-patch` fails** `Minimal implementation` (scores below the
   item's pass threshold), because it leaves the confirmed cause in place.
2. **`cause-fix-with-required-cleanup` scores strictly higher than
   `symptom-patch`**, despite being larger, and no part of it is charged as
   expansion.
3. **`unrelated-expansion` scores strictly lower than
   `cause-fix-with-required-cleanup`**, AND the stated reason names the
   hunks that trace to neither the confirmed cause nor anything the change
   orphaned. Both halves are required: `unrelated-expansion`'s cause-fix
   half is byte-identical to `cause-fix-with-required-cleanup`'s and it is
   the largest of the three, so a bare "it fails" oracle would also be
   satisfied by an evaluator applying the pre-#89 size bias — the exact
   world this cycle exists to end. The reason clause is what separates "the
   containment criterion worked" from "the evaluator disliked the largest
   diff".

Conditions 1 and 3 are the two directions the rewritten criterion asserts
(feature design D3, and §4.1's closing sentence). Reason for manual
delegation: the oracle is an LLM's judgment, which no repository test can
observe.

### Pass condition record

Record, in the cycle report:

- The three scores (`symptom-patch`, `cause-fix-with-required-cleanup`,
  `unrelated-expansion`) and their one-line reasons.
- Whether each of the three conditions above held.
- Confirmation that the prompt delivered to the evaluator carried no hint of
  the preferred ordering (neutrality check).

**Pass condition:** all three conditions hold and the neutrality check is
confirmed.
