# Issue #119 — Manual/Environment-Dependent Verification Scenarios

One acceptance criterion of this cycle is not covered by an automated arm, and
one derived value cannot be produced at RED or GREEN time. Both are delegated
here per `.autoflow/issue-119-verification-design.md` — the row
`AC-suite-runtime-reduced` (typed *environment-dependent*) and the
`# budget-secs:` conversion the feature design orders last (§2.7).

Everything else this cycle asserts is automated; see the RED report for the
arm-to-criterion map.

---

## AC-suite-runtime-reduced (wall clock) — the eleven-minute figure

**Why not automated:** the target is a **workflow-level** quantity — the
`contract-suites` job's own elapsed time on a GitHub-hosted runner — and no
per-suite header homes it. `scripts/test/run-suites.sh:230-233` states in the
tree's own words that a local elapsed figure is no evidence about a CI-clock
number, and `scripts/test/suite-manifest.sh:41-53` rules local wall-clock
inadmissible as the source of a derived budget. An arm asserting a local
stopwatch reading would therefore assert something the tree already declares
inadmissible, and an arm inlining an arithmetic sum of the six reduced bounds
would be a pin on a sum — the brittleness class this same cycle is relaxing at
*schema-pin-relax*.

The half of the criterion that **is** automated is the static one: that no
re-invocation of a sibling suite survives in the touched files. It is carried
by the `119-absent-*` entries in `tests/fixtures/doc-invariants.json` and runs
under `tests/run-doc-invariants.sh`.

**Steps** (at INTEGRATE / HANDOFF, on the PR's own run of record):

1. Open the PR's `contract-suites` workflow run.
2. Read the job's total elapsed time from the run summary.
3. Read the per-step duration of `tests/test-bounded-execution-fallback.sh`
   from the same run's step timings.
4. Compare against the pre-change baseline recorded in the issue (~19 min for
   the full run). Record both numbers in the PR body.

**Pass condition:** the `contract-suites` full run on the PR's run of record is
at or below roughly eleven minutes, and no step in the run reports a
`timeout-minutes` cancellation. A run that is faster but cancelled a step is a
fail, not a pass — the reduction must come from shorter waits, not from a
truncated job.

**On a miss:** report the measured figure rather than adjusting a bound to
chase the number. The per-drive floors (granularity `>= 8`, discovery
`bound >= 2x poll budget`) are asserted by
`tests/test-bounded-execution-fallback.sh` and are not negotiable against a
wall-clock target.

---

## `# budget-secs:` conversion — ordered last, and conditional

**Why not automated at RED or GREEN:** `budget-secs` is defined as
`ceil(measured CI step duration x SUITE_BUDGET_HEADROOM_PERCENT / 100)`
(`scripts/test/suite-manifest.sh:68-72`), **CI-clock only**. A suite with no
CI-measured duration must declare `SUITE_BUDGET_CEILING_SECS` verbatim, so a
guessed budget is not a representable state. The conversion therefore cannot
be performed from a local run at any point in this cycle's implementation
phases.

`tests/test-bounded-execution-fallback.sh` declares
`# budget-secs: SUITE_BUDGET_CEILING_SECS` today and its step declares
`timeout-minutes: 10` (`.github/workflows/contract-suites.yml`).

**Steps** (at HANDOFF only):

1. Read the bounded-execution step's measured duration from the PR's own run of
   record.
2. Compute `ceil(duration x SUITE_BUDGET_HEADROOM_PERCENT / 100)` using the
   constant as `scripts/test/suite-manifest.sh` defines it.
3. In **one** commit, set the suite's `# budget-secs:` to that integer and the
   step's `timeout-minutes` to `ceil(budget-secs / 60)`.
4. Run `scripts/test/check-suite-manifest.sh` and confirm it is green — it
   re-derives both relations from the real header and the real workflow step.

**Pass condition:** header and step agree under the standing lint, and the
declared budget is bounded by the ceiling.

**Skip condition:** if no CI-measured duration for that step is available, this
step does **not** run and the header keeps `SUITE_BUDGET_CEILING_SECS`
verbatim. Inventing a number is not a permitted outcome of this cycle.
