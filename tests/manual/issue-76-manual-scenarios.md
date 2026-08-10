# Issue #76 — Manual Verification Scenarios

Per `.autoflow/issue-76-verification-design.md` > "Untestable items and their
alternatives" and the AC table's manual legs. Each item below has no
predicate that can hold it — judgment or a live-environment observation is
required.

## M1 — §5 disposition "basis" prose truthfulness (AC-a-1 manual leg)

For every §5 disposition row this cycle adds to
`docs/doc-invariant-registry.md`, a human (or an Evaluation AI acting as a
proxy at GATE:QUALITY/AUDIT) reads the row's stated basis and confirms:

1. The basis accurately describes WHY the guarded condition no longer needs
   a live carrier (e.g. "the condition it guarded cannot recur because X",
   not a placeholder).
2. A `dropped — cycle-local` classification is not a convenient label
   applied to an assertion nobody wanted to migrate — cross-check against
   the assertion's own suite comment/header for any statement that the
   assertion was intended as a permanent invariant.

**Pass condition**: every new §5 row's basis withstands independent reading
against the deleted suite's original assertion text (`git show <base
ref>:<suite path>`).

## M2 — `gh run` log observation (AC-b-1, AC-c-4)

Environment-dependent; requires the real CI service, run once this cycle's
PR triggers the new workflow.

1. After the PR pushes, run:
   `gh run list --branch dev/2026-08-10-issue-76 --limit 5`
   and `gh run view --log <run-id>` for the newest run of the new workflow.
2. AC-b-1: `grep` each newly registered suite's name in the log; every one
   must show a PASS/exit-0 line.
3. AC-c-4: confirm every workflow (`e2e-dummy-target.yml`,
   `host-purity-delta.yml`, `plugin-package.yml`, `schema-hook-contract.yml`,
   the new workflow) is green on the head commit — `gh pr checks`.

**Pass condition**: every named suite's execution is present and green in
the real log; no workflow run is red or missing.

## M3 — full-tree sweep against the base ref (AC-d)

`tests/issue-59-full-sweep-driver.sh` is a VERIFY-time driver with a ≥600s
wall-clock budget contract; a shorter timeout reports INCONCLUSIVE, never
PASSED, per its own header.

1. Run once, after stage 3 of the feature design's sequencing (the sweep
   driver's `NAMED_SUITES` and enumeration-glob edit must already be in the
   tree):
   `bash tests/issue-59-full-sweep-driver.sh <base-ref-sha>`
2. Confirm the driver's own reported budget was met (not cut short).
3. Read the output: any suite reported `NEW AT HEAD` (regression outside the
   design's declared change surface) is a blocker; a suite in
   `NAMED_SUITES` reporting `ALREADY RED` is expected churn, not a
   regression.

**Pass condition**: zero unnamed regressions; the run completed within
budget (not INCONCLUSIVE).

## M4 — manifest regen-clean lint drives, specificity leg (AC-g)

`tests/test-issue-76-standing-lints.sh` automates the two FAIL drives
(bundle-registration lane, fixed-point lane) and the green-on-unmodified-
tree specificity check. This entry records the residual manual judgment:
that the FAIL message text each drive prints correctly attributes the
failure to ITS OWN lane (not a generic "manifest differs" message that
would leave AC-g's two-lane-in-one-drive risk unresolved even though the
automated suite's `grep -qi` check passed).

**Pass condition**: a human reads `/tmp/issue76-regen-drive1.out` and
`/tmp/issue76-regen-drive2.out` (or their CI-run equivalents) and confirms
each names its own lane distinctly from the other.
