# Issue #103 — Manual Verification Scenarios

Companion: `.autoflow/issue-103-verification-design.md`. Covers the two
acceptance criteria not automatable as a gate: **AC-full-tree-cost-improvement**
(manual) and the human-checked half of **AC-budget-derivation-source**
(environment-dependent — the automated half, the ceiling-or-integer grammar,
is covered by `tests/test-issue-103-suite-manifest.sh`).

## M1 — AC-full-tree-cost-improvement: the full-tree run cost actually falls

**Why manual**: wall-clock on a developer host is not a reproducible oracle —
this repository's own recorded measurement (`.autoflow/issue-103-phase-b.md`,
*Local vs CI runtime gap*) shows wide local variance under contention. The
automatable half of the underlying claim is `AC-runtime-ceiling-enforced`
(`tests/test-issue-103-central-runner.sh`), which proves the ceiling gates a
real overrun; this scenario proves the aggregate cost improvement the ceiling
alone cannot measure.

**Procedure**:

1. On the same host, with no other CPU-heavy process running (check
   `.claude/hooks` / `local-suite-contention` guidance — the tree's own memory
   records checkout contention as a confound), record the wall-clock of a
   full-tree run **before** this cycle's change. `git stash` does not apply
   here — `tests/issue-59-full-sweep-driver.sh` is a committed deletion on
   this branch, not an uncommitted change, so stashing restores nothing.
   Instead, in a separate worktree or checkout of the merge-base commit
   (`git merge-base HEAD origin/main`), run whatever full-sweep mechanism
   existed there — at the branch point that is
   `time bash tests/issue-59-full-sweep-driver.sh`, the suite this cycle's
   own `scripts/test/run-suites.sh --all` (step 2) supersedes.
2. Record the wall-clock of the post-change full-tree run:
   `time bash scripts/test/run-suites.sh --all`.
3. Record the wall-clock of a **narrow-delta** run — a change touching one
   suite's own subject, none other:
   `time bash scripts/test/run-suites.sh` (default selection, no `--all`),
   against a branch with a single-file delta.
4. State the host, the contention conditions (idle vs. concurrent checkouts),
   and the three wall-clock figures in the cycle's VALIDATE notes.

**Pass condition**: the narrow-delta run (step 3) is materially faster than
the full-tree run (step 2), and the full-tree run (step 2) is not slower than
the pre-change baseline (step 1) by more than the stated selection-machinery
overhead.

## M2 — AC-budget-derivation-source: human-checked derivation note per numeric budget

**Why environment-dependent, not fully automated**: budgets must be derived
from **CI-measured** step durations at the branch point, never local
wall-clock (`.autoflow/issue-103-phase-b.md`, *Local vs CI runtime gap*; the
preceding cycle's watchdog distortion). The automated half —
`check-suite-manifest.sh` accepting either the `SUITE_BUDGET_CEILING_SECS`
symbol verbatim or a positive integer within the ceiling — is covered by
`tests/test-issue-103-suite-manifest.sh` (`AC-budget-derivation-source
automated half`). This scenario is the human check that each **numeric**
budget's derivation note actually points at a real CI-measured duration
rather than an unstated guess.

**Procedure**: for every suite header carrying a numeric `budget-secs` (not
the `SUITE_BUDGET_CEILING_SECS` symbol), confirm the commit or PR description
that introduced the value states the source workflow run URL or job name the
duration was read from, and that the declared value carries the stated
headroom factor over the measured figure.

**Pass condition**: every numeric `budget-secs` in the tree traces to a
recorded CI measurement; no numeric budget is present without a derivation
note.

## M3 — AC-real-sweep-clears-the-straddling-suite: the real local sweep clears

**Why environment-dependent, not fully automated**: the contradiction this
criterion resolves (`.autoflow/issue-103-budget-green-blocker.md`) was only
ever observable against a real suite's real wall-clock — no fixture carries
a real ten-minute suite. The margin criterion (the effective local ceiling,
`SUITE_BUDGET_CEILING_SECS × SUITE_LOCAL_SLOWDOWN_FACTOR`, must exceed this
repository's worst recorded local suite runtime) is checked arithmetically
by `tests/test-issue-103-central-runner.sh`; this scenario is the real-sweep
witness the margin criterion exists to back up structurally rather than rest
on alone.

**Procedure**:

1. On the post-change tree, run `bash scripts/test/run-suites.sh --all` on
   the same host used for M1, both uncontended and under the contention
   conditions M1 records.
2. Confirm the run reports **no** `TIMEOUT` record, and specifically none
   for `tests/test-push-context-base-ref.sh` (the suite whose 594–601s local
   wall-clock straddled the pre-revision ceiling — arbitration
   `.autoflow/issue-103-verify-arbitration.md` M1–M3).
3. Record the wall-clock and any `TIMEOUT` output verbatim in the cycle's
   VALIDATE notes.

**Pass condition**: `run-suites: <N> passed, 0 failed, 0 timed out, of <N>
executed`, on both an uncontended and a contended run.
