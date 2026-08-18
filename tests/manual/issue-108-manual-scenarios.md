# Issue #108 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

## M1 — AC-skipped-step-key-is-retained: does a skipped governed step's `id`
survive in `toJSON(steps)`?

**Companion**: `.autoflow/issue-108-verification-design.md`, acceptance
criterion `AC-skipped-step-key-is-retained` (environment-dependent, deferred
to manual observation). Feature design §6 "steps-context premise
observation".

**Not a new premise — the same one, still open.** This is the identical
runner property `tests/manual/issue-103-manual-scenarios.md` M7
(`AC-a-skipped-governed-step-keeps-its-key`) already names as unobserved: a
governed step's `id:` remaining a key in the job's own `toJSON(steps)`
context object when that step's `if:` guard evaluates false and the step is
skipped. Issue #108 does not add a second dependency on it — arm A of the
cascade classification (`--job-status`) reads the job's own status, and arm
B reads outcome **values**, not key presence — so `hosted_here()`
(`scripts/test/check-step-reconciliation.sh`) keeps exactly the exposure it
already had. Closing the exposure is this criterion's subject; it is
restated here, against #108's own cycle, because #108 changes the code that
consumes the premise (the `selected`/`skipped` branch now grades a subset of
its former mismatches as `CASCADE-SKIP:`) and a fresh observation window is
owed against the shipped classifier rather than inherited silently from a
prior cycle's open item.

**Why manual, and not automatable**: unchanged from #103 M7 — no local
fixture can produce the GitHub Actions runner's own `steps` context; a
fixture asserting the assumed shape would confirm the assumption rather than
test it.

**Stakes, restated for the cascade classifier**: if the key is dropped when
a step skips, the same two failure branches #103 M7 named still apply
(narrowing misreads the suite as out-of-job, or the un-narrowed comparison
reads `outcome=absent`) — and #108 adds a third path to trace: whether the
id-less standing-lint-failure case (feature design §0 fact 1 — a failing
step with no `id:` contributing nothing to `toJSON(steps)`) is exactly why
arm A (`--job-status`) exists, so a run relying on arm A alone should not be
sensitive to this premise at all. Observing the key-present branch on a
cascading run is therefore additional evidence that arm A's rationale holds
in practice, not merely a re-check of #103's open item.

**Procedure**:

1. On the first post-`#108`-merge CI run (any of `contract-suites.yml`,
   `e2e-dummy-target.yml`, `host-purity-delta.yml`, `plugin-package.yml`, or
   `schema-hook-contract.yml`) whose delta is narrow enough that at least one
   governed step's `if:` guard evaluates false and the step is genuinely
   skipped, open the `reconcile selection against step outcomes` step's log.
2. Record: the run URL, the workflow/job name, the skipped step's `id:`
   value, the job's own `job.status` at that point in the run, and whether
   the reconcile step's output names that id — as a `CASCADE-SKIP:` line, an
   `OUT-OF-JOB:` line, a `MISMATCH:` line, or none of the three.
3. Compare against the expected resolution branches:
   - **Key present, ordinary skip (no failure upstream)** — `hosted_here()`
     returns true, the suite reconciles as an ordinary `MISMATCH:` (the
     wrongly-false-guard case) if genuinely selected-and-skipped with no
     failure signal, or as agreement if unselected. The cascade classifier
     plays no role here.
   - **Key present, skip downstream of a real failure** — the reconcile
     step's output should carry a `CASCADE-SKIP:` line for that suite (via
     arm A, `--job-status`, or arm B, an outcome-map failure value, or
     both), not a `MISMATCH:` line.
   - **Key absent** — the narrowing derivation degrades exactly as #103 M7
     describes; record the run and file a follow-up against the premise at
     `check-step-reconciliation.sh`'s `hosted_here()` if this branch is
     observed. Note whether arm A (`--job-status`) alone would have
     correctly classified the run even under this failure mode — if so, the
     premise's exposure is now bounded to arm B's cases only, which is
     evidence worth recording even on a FAIL branch.
4. Record the run URL, the branch observed, the raw step-outcome JSON (or
   the relevant excerpt), and the `job.status` value in the cycle's VALIDATE
   notes or the follow-up issue.

**Pass condition**: the key-present branch is observed and recorded — for
both an ordinary skip and, when a naturally-occurring run permits it, a
skip downstream of a real failure — with the reconcile step's output
matching the expected resolution branch above. A key-absent observation is
not a hard fail of this item; it is recorded per the procedure and routed to
a follow-up issue against the premise, per #103 M7's own disposition.

**Not carried automatically.** No suite under `tests/**` can discharge this
scenario itself, for the same reason #103 M7 stays manual: the runner's own
step context is not reproducible locally and not fakeable without the fake
becoming the thing under test.
