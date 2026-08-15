# Issue #99 — Manual/Environment-Dependent Verification Scenarios

`.autoflow/issue-99-verification-design.md` > Testability assessment names one criterion
that cannot be discharged by an automated wall-clock bound: `AC-step-time`.

---

## M1 — CI step time is no longer dominated by subject runtimes (Tier 3, environment-dependent)

**Source AC:** `AC-step-time` (verification design > Acceptance criteria → verification type
→ method) — "the standing suite's CI step time is no longer dominated by subject runtimes
and no longer grows with subject count."

**Why not automated:** the verification design's Testability assessment states this directly:
runner variance makes a wall-time threshold non-deterministic, so no automated bound is
proposed, and wall-clock step time is not an intersecting identifier of the composition
oracle's `T ∩ S` (`.autoflow/issue-99-verification-design.md` > Composition oracle
determination), so the clause does not narrow this either. `AC-benefit-empty-delta-real-tree`
and `AC-benefit-proper-subset-real-tree` (both automated, both clock-free) bind the *shape*
of the reduction on the real tree; this scenario is the *end-to-end wall-clock corroboration*
on the hosted runner, which only a real CI run of the rewritten suite can produce.

**Baseline:** the job/step telemetry cited in the feature design (`.autoflow/issue-99-feature-design.md`
§2, "Job/step timings for the run cited in the issue re-read from `gh run view 31737309889`") —
the pre-#99 whole-subject-sweep step, whose cost is the sum of the derived subjects' runtimes and
therefore grows with the derived subject count.

**Setup:** after this cycle's host PR is merged externally (AutoFlow does not merge; `CLAUDE.md` >
Development Lifecycle), locate the resulting push-triggered `contract-suites.yml` run for the merge
commit.

**Procedure:**

1. Open the push-triggered `contract-suites.yml` run for the merge commit and find the
   `tests/test-push-context-base-ref.sh` step.
2. Compare that step's wall-clock duration against the `gh run view 31737309889` baseline cited
   above. Expect the merge-commit run's delta to be **empty** (a push-to-main event, per
   `AC-benefit-empty-delta-real-tree`) — the step's own subject-execution phase should therefore
   complete near-instantly (selection only, no subject re-run), with the remaining time dominated
   by the resolver-topology / native-coverage-premise / mutation-teeth fixture legs, which are all
   constant-cost by design.
3. On a **later** PR that touches exactly one or a few derived subjects, open its `pull_request`-
   triggered run of the same step and confirm the step's duration scales with the touched-subject
   count, not with the full 17-subject derived set — i.e. it does not regress to the pre-#99
   whole-subject-sweep cost.
4. If either observation contradicts the expectation (the merge-commit run still executes the full
   derived set, or a small-delta PR run still costs the whole-sweep time), file a follow-up issue
   citing the specific run URL and step duration — this is the observable the cycle's benefit
   claim rests on, and a contradiction here means the benefit did not land even though every
   automated criterion passed.

**Disposition:** record the observation (PASS/FAIL + run URL) in the VALIDATE checklist for this
cycle. A FAIL here does not fail this cycle's automated tests — it flags a follow-up.
