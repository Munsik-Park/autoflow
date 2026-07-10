# Issue #795 — Manual Verification Scenarios (delegated to operator)

These acceptance criteria are **environment-dependent** and cannot run in the
bash harness (`tests/test-issue-795-handoff-removal.sh`). They are delegated
per the verification design (`.autoflow/issue-795-verification-design.md`
§2 AC-VALID / AC-E2E).

- **AC-VALID**: after `.github/workflows/handoff-sequence.yml` is deleted, the
  surviving workflow set under `.github/workflows/` must still be valid YAML
  (`actionlint`-clean). Trivial by construction — a deletion cannot introduce
  a YAML error in another file — but `actionlint` is absent from the AutoFlow
  runtime (same constraint as issue #495 AC6), so this is opportunistic-only,
  run at INTEGRATE, not a blocking RED/GREEN gate.
- **AC-E2E**: a real multi-repo handoff completes via the operator
  `blocked-by-subrepo` label gate + manual pointer reconcile, with the
  `subrepo-merged` status check gone, confirming the removed automation was
  advisory-only (ADR-0015 `:150-151`) and its absence does not block the
  merge-order procedure. Requires a live PR + operator; not reproducible in
  RED/GREEN.

---

## AC-VALID — remaining workflows still valid YAML

**Why not automated:** `actionlint` is absent in the AutoFlow runtime
(verification design §0/§2).

**When to run:** after the host PR deleting `handoff-sequence.yml` is merged
to `main`, on a machine where `actionlint` is available.

**Steps:**

1. Fetch the updated default branch:
   ```bash
   git fetch origin main
   git checkout main
   ```

2. Confirm the file is gone:
   ```bash
   test ! -f .github/workflows/handoff-sequence.yml && echo "deleted OK"
   ```

3. Run actionlint over the surviving workflow set:
   ```bash
   actionlint .github/workflows/*.yml
   ```
   Expected: exits 0, no errors — no new invalidity introduced by the
   deletion.

**Pass condition:** `actionlint` exits 0 over the surviving workflow files.

---

## AC-E2E — handoff completes without the machine (operator runbook)

**Why not automated:** requires a live multi-repo cycle with an open host PR
carrying `blocked-by-subrepo`, a merged sub-repo (llmroute) PR, and an
operator performing the manual pointer reconcile + label removal. None of
these can be provided in a unit harness.

**When to run:** the next multi-repo cycle handoff after this issue's PR is
merged to `main`.

**Steps:**

1. Confirm the host PR for the cycle carries the `blocked-by-subrepo` label
   (applied by `scripts/handoff/create-host-pr.sh`, unchanged label logic —
   feature C2) and **no** `subrepo-merged` status check appears on the PR's
   Checks tab (the workflow that published it no longer exists).

2. Merge the sub-repo (llmroute) PR per the normal sub-repo cycle close-out
   (`docs/submodule-common-rules.md` > Sub-repo cycle close-out).

3. Reconcile the host PR's `services` submodule pointer to the sub-repo
   merge commit (`docs/external-review-sequencing.md` > Reconcile preflight),
   verifying `git ls-tree HEAD services` equals the sub-repo merge commit
   (`TARGET`) — this is the same pointer-equality requirement the retired
   `subrepo-merged` status check used to verify by machine; it is now the
   operator's manual confirmation.

4. Once (2) and (3) are confirmed, remove the `blocked-by-subrepo` label
   manually: `gh pr edit <host-pr> --remove-label blocked-by-subrepo`.

5. Merge the host PR.

**Pass condition:** the cycle completes end-to-end — sub-repo merge, pointer
reconcile, label removal, host PR merge — with no `subrepo-merged` status
check anywhere in the sequence, confirming the automation's absence does not
block the merge-order procedure.
