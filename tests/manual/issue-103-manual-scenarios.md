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

## M4 — AC-real-pr-run-selects-rather-than-blocks (cycle 2, review-response)

**Companion**: `.autoflow/issue-103-verification-design.md` (cycle 2) §1. Covers
the two review findings' composition contact point — the shipped `select`
step text running under the real GitHub Actions shell and step-outcome
semantics — which no local replay can substitute for, since the environment
(base-ref resolution under the runner's actual fetched history) is the
subject.

**Why manual**: base-ref resolution depends on the history the runner
fetched under a specific event payload; no local layer can distinguish
"fail-closed and correct" from "fail-closed and now red on every PR", which
is the precise regression `capture-then-check` could introduce if
`fetch-depth-full-history` did not actually fix `schema-hook-contract.yml`'s
base resolution. The run log is the only witness.

**Stated expectation**: `resolve_base_ref` resolves `origin/$GITHUB_BASE_REF`
— the first non-override branch of its precedence chain
(`tests/lib/base-ref.sh:30-49`) — because `fetch-depth: 0` makes
`actions/checkout` fetch `+refs/heads/*:refs/remotes/origin/*`, so that
remote-tracking ref exists. Naming the expected branch is what turns the
witness into a comparison rather than "the log looks fine": resolution via a
later fallback in the chain would still produce a green run while leaving
the checkout change unproven.

**Procedure — first witness (success path)**:

1. On this PR's own `schema-hook-contract` Actions run (post-GREEN, after
   `fetch-depth-full-history` and `capture-then-check` land), open the
   `select suites for this change` step's log.
2. Confirm the step's report shows `SELECTED:` / `NOT-SELECTED:` lines, never
   a `BLOCK:` line, and that resolution reached `origin/$GITHUB_BASE_REF` as
   stated above (not a later fallback branch — check the report or add a
   temporary echo of the resolved ref if the log does not already show it).
3. Confirm the guarded `s-test-issue-223-schema-hook-contract` step's outcome
   is `success` (executed, not skipped).

**Procedure — second witness (fail-closed path in the real runner)**:

1. On a scratch branch off this PR, temporarily force `select-suites.sh` to
   exit non-zero (e.g. an early `exit 1` after a stderr `BLOCK:` line, or a
   forced-unresolvable base) and push a commit that triggers
   `schema-hook-contract.yml`.
2. Confirm the Actions run marks the `select` step `failure`, the job red,
   and the `BLOCK:` text present in the step's own log — not masked into a
   green run with an empty selection.
3. Revert the scratch forcing before merging; this witness is one-time, not a
   standing check (verification design §1 names the residual: after this
   cycle, the only standing assertion over the shipped step's *composed*
   behaviour is the local `bash -e` replay plus the text predicate in
   `tests/test-workflow-trigger-conformance.sh` — this manual witness is not
   re-run on every future change).

**Pass condition**: both witnesses observed on the real GitHub Actions
runner — the success-path run selects and executes the guarded suite via
`origin/$GITHUB_BASE_REF`, and the forced-BLOCK run reds the job with the
`BLOCK:` text visible in the step log.
