# External Review -- Merge Sequencing

> Audience: the external reviewer who merges AutoFlow PRs, and the operator who bootstraps the host repository. AutoFlow ends at PR creation; this document covers what happens after.

Sub-repo PRs target the **host-operated fork**. The merge-sequencing steps in this document refer to the PR of the host's direct submodule; a submodule nested inside it is merged and reconciled by that sub-repo's own procedure, outside host handoff scope. The authoritative submodule URL & pointer policy is [`submodule-common-rules.md`](submodule-common-rules.md) > **Submodule URL & Pointer Policy**.

## Operator prerequisites

Out-of-AutoFlow administration. Run once per host repo before the per-issue procedure can be exercised: create the `blocked-by-subrepo` and `blocked-by-review` gate labels below. These are advisory, human-honoured signals — neither is a required status check.

### Label

```bash
gh label create blocked-by-subrepo \
  --color b60205 \
  --description "Host PR depends on a sub-repo PR not yet merged; do not promote draft to ready" \
  --repo Munsik-Park/autoflow

gh label create blocked-by-review \
  --color b60205 \
  --description "Codex review has unresolved Critical/High/Medium findings; do not promote draft to ready" \
  --repo Munsik-Park/autoflow
```

The `blocked-by-review` gate label is a **per-PR** review gate: it is attached to **every** PR opened for a cycle — the host PR (by `scripts/handoff/create-host-pr.sh`) **and each sub-repo PR** (the orchestrator's `gh pr create … --label blocked-by-review`) — and is removed by the Codex reviewer on **that same PR** (`scripts/review/codex-review-pr.sh --pr <N> [--repo <owner/name>]`, per `.codex/review.md`) only when **that PR's** review finds zero `Critical`/`High`/`Medium` findings. Each PR is reviewed on **its own diff** — the host review never substitutes for the sub-repo review. The label must therefore exist **in each sub-repo too**, not only the host — create it there with the same `gh label create blocked-by-review …` command but `--repo <sub-repo>`. This is distinct from `blocked-by-subrepo`, which is **host-only** and gates merge **order**, not review. Its removal is **not** a required status check — it is an advisory, human-honoured signal. The merge actor still performs promotion and merge manually.

Its lifecycle has **three** actions — attach, remove, and **re-attach**: (1) **attach** at PR creation, on every PR of the cycle; (2) **remove** by the reviewer on that PR when its review confirms zero `Critical`/`High`/`Medium` findings; (3) **re-attach** by the reviewer when a *later* review of the same PR confirms a `Critical`/`High`/`Medium` finding while the label is absent. Attach and remove are mutually exclusive on any single review (zero findings versus at least one), and authority over the label is directional: the reviewer is the **sole** authority for **removal** (the orchestrator is hook-denied), while **attach** is **reviewer-primary with an orchestrator backstop** — the orchestrator re-attaches at HANDOFF step 6.5 ([`phases/handoff.md`](phases/handoff.md)) only when the reviewer's own attach did not land, and an attach made in error is undone by a reviewer re-review, never by the orchestrator. All three actions require the label to exist in the target repo — creation stays operator-owned, per the prerequisites above.

### Merge-order clearance (operator)

Merge-order clearance is operator-performed. Once every sub-repo merge for the cycle is complete (the sub-repo PR merged into `{{REPO_SERVICE_HOST}}:main`) and the host pointer reconcile is confirmed, the operator removes the `blocked-by-subrepo` label from the host PR — that removal is the merge-order gate the merge actor honours.

The confirmation is the operator's manual check that the host PR's submodule pointer equals the sub-repo PR's merge commit (see Reconcile preflight below). The merge-order gate is the operator's `blocked-by-subrepo` label removal alone; a machine status check for this signal is advisory-only, never an enforceable required check.

This clearance sits alongside the protections the reviewer verifies before merging (PR review >= 1, CI green; see [`role-contracts.md`](role-contracts.md) > Verification scenarios).

## Per-issue procedure

After the reviewer merges the sub-repo PR(s), the merge-order sequence is a manual operator procedure.

### Host-only cycle (target-centric — the default)

For an issue cycle with **no** sub-repo change, AutoFlow's HANDOFF opens a single host PR with `--no-subrepo-dep`, so it carries **no** `blocked-by-subrepo` label and no merge-order gate. The reviewer promotes the draft to "Ready for review" and merges it directly. There is no sub-repo merge, pointer reconcile, or label to clear.

### Multi-repo cycle (sub-repo change present)

*Secondary (multi-repo):* when the host contains a submodule, the cycle's host PR depends on a sub-repo PR and the reviewer runs the sub-repo→pointer→host merge sequence below.

For an issue cycle whose host PR depends on a sub-repo PR:

1. AutoFlow's HANDOFF has already created the sub-repo PR(s) and the host PR (the latter as `--draft` with the `blocked-by-subrepo` label).
2. Review and merge the sub-repo PR into `{{REPO_SERVICE_HOST}}:main` (the host's direct submodule). Record the merge commit SHA from the sub-repo PR page (URL fragment after `/commits/`).
3. Update the submodule pointer in the host PR's dev branch to the upstream merge commit, then push (or ask the original branch owner to push). When this step is **delegated to AutoFlow**, follow [**Reconcile preflight**](#reconcile-preflight-concurrent-cycle-gitlink-guard) below first.

   > **Propagation batching (why the host pointer may not have moved yet):** during review-response, the host submodule pointer bump is deferred until the sub-repo PR's `blocked-by-review` clears, then bumped once at that clean point — so a reviewer seeing an un-bumped host pointer mid-review is observing the batching norm, not a missed step. Full norm: [`phases/handoff.md`](phases/handoff.md) step 6.5 (source of truth).
4. **Operator verifies the merge-order gate is cleared.** Confirm manually that (a) the host PR is open and carries `blocked-by-subrepo`, (b) the sub-repo PR is merged, and (c) the host PR's submodule pointer equals the recorded sub-repo merge commit (`git ls-tree HEAD <submodule>` == the merge commit; this is the pointer-equality requirement of the Reconcile preflight's post-reconcile gate). Once all three hold, remove the `blocked-by-subrepo` label manually: `gh pr edit <host-pr> --remove-label blocked-by-subrepo`.
5. Promote the host PR draft -> "Ready for review" (manual click).
6. Merge the host PR. The literal close-keyword line in the body closes the issue.

### Reconcile preflight (concurrent-cycle gitlink guard)

When step 3's pointer update is delegated to AutoFlow on explicit request, the dev branch may have forked *before* one or more **other** cycles' host PRs merged. Guard it:

**Preflight** — before bumping, fetch and compare three pointers:

- `BASE` — the dev branch's merge-base-with-`main` pointer: `git ls-tree $(git merge-base origin/main HEAD) <submodule>`.
- `MAIN` — the current `origin/main` pointer (after `git fetch origin main`): `git ls-tree origin/main <submodule>`.
- `TARGET` — this issue's sub-repo `merge_commit_sha` (the commit the host pointer must equal).

If `MAIN == BASE`, no concurrent reconcile happened — bump to `TARGET` and push. If `MAIN != BASE`, a concurrent cycle already reconciled the pointer; resolve by **fork ancestry** (run `git -C <submodule> fetch origin main` first, then `git -C <submodule> merge-base --is-ancestor <a> <b>`).

| Relationship on the fork | Resolution |
|---|---|
| `TARGET` is a **descendant** of `MAIN` (fork `main` moved forward; `TARGET` already contains `MAIN`) | **Put `TARGET` on the dev gitlink first, *then* merge** — `git -C <submodule> checkout <TARGET>` → `git add <submodule> && git commit` → `git merge --no-edit origin/main`. With the dev pointer already at `TARGET` (⊇ `MAIN`), the submodule **stays at `TARGET`** and only non-gitlink files merge (`Fast-forwarding submodule <submodule> …` confirms a clean gitlink). **[MUST]** A bare `git merge origin/main` with the dev pointer still at `BASE` resolves the gitlink to **`MAIN`, not `TARGET`** and leaves the host pointer wrong — so the pointer must be set to `TARGET` either before or after the merge, and verified (see the post-reconcile gate). |
| `MAIN` is a **descendant** of `TARGET` (host PRs merged out of fork-merge order) | Do **not** push. **Escalate to the operator** — the merge order on host `main` diverged from the fork merge order. |
| `TARGET` and `MAIN` **diverge** (neither is an ancestor of the other) | Fork history diverged — **escalate to the operator**. |

**Post-reconcile gate** — before/after pushing, confirm **all three**, and do not report "reconciled" until all hold:

- **Pointer == `TARGET`**: `git ls-tree HEAD <submodule>` equals `TARGET` — the merge-order gate's pointer-equality requirement the operator verifies before removing `blocked-by-subrepo`. Verify this *before* pushing.
- The generic mergeable + check-rollup confirmation runs `scripts/handoff/confirm-ci-green.sh --pr <host-PR>` (the shared step-5 helper), which asserts a confirmed-mergeable read — `mergeable: MERGEABLE` with a settled (non-`UNKNOWN`) `mergeStateStatus` (not `CONFLICTING`/`DIRTY`) and a green GitHub-surfaced check rollup. The pointer-equality bullet above and the head-commit check bullet below are this doc's own gitlink **superset** additions.
- The CI checks on the **new head commit** are all `completed` / `success`, read by commit SHA rather than by job name or check name:
  ```bash
  gh api repos/{owner}/{repo}/commits/<head-sha>/check-runs \
    --jq '.check_runs[] | "\(.name) \(.status) \(.conclusion)"'
  ```
  **[MUST]** Read the checks of the post-reconcile head SHA, never the PR's latest build in general; re-verify after the post-push run on the new head settles.

**Sequencing** — perform the reconcile against a **freshly-synced `main`**: run [Post-Merge Cleanup](git-workflow.md#post-merge-cleanup) for any prior cycles the operator has already merged *before* reconciling the current issue.
