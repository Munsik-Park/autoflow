# External Review -- Merge Sequencing

> Audience: the external reviewer who merges AutoFlow PRs, and the operator who bootstraps the host repository. AutoFlow ends at PR creation; this document covers what happens after.

> **Transition note (issue #91 → services nesting)** — This document was originally authored under the assumption that sub-repo PRs target the upstream repository (`danny-avila/LibreChat:main`). Issue #91 established that sub-repo PRs target the **host-operated fork** (`{{REPO_SUBMODULE}}:main`). The services-nesting refactor (2026-06-27) further updated the host topology: the host's direct submodule is now `services` = **`{{REPO_SERVICE_HOST}}`** (host-operated nesting repo). Nested `librechat` (`{{REPO_SUBMODULE}}` fork) and `librechat-deploy` are submodules **inside llmroute**; their PR validation is llmroute's internal procedure and is outside host handoff scope. The merge-sequencing steps in this document all refer to the **llmroute PR** — the host's direct submodule. **As of #798 (2026-07) `claude-autoflow` carries zero submodules and is single-repo — the `services` submodule was detached; the merge-sequencing procedure below is a historical/generalized record that applies only to a multi-repo consumer operating such a host-private fork.** The authoritative submodule URL & pointer policy is [`submodule-common-rules.md`](submodule-common-rules.md) > **Submodule URL & Pointer Policy**.

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

The `blocked-by-review` gate label is a **per-PR** review gate: it is attached to **every** PR opened for a cycle — the host PR (by `scripts/handoff/create-host-pr.sh`) **and each sub-repo PR** (the orchestrator's `gh pr create … --label blocked-by-review`) — and is removed by the Codex reviewer on **that same PR** (`scripts/review/codex-review-pr.sh --pr <N> [--repo <owner/name>]`, per `.codex/review.md`) only when **that PR's** review finds zero `Critical`/`High`/`Medium` findings. Each PR is reviewed on **its own diff**, so the review scope is each repo's actual code — for a multi-repo change the host PR's diff is only the `services` submodule-pointer bump (pointing to llmroute), so the host review never substitutes for the sub-repo review. The label must therefore exist **in each sub-repo too**, not only the host — create it there with the same `gh label create blocked-by-review …` command but `--repo <sub-repo>`. This is distinct from `blocked-by-subrepo`, which is **host-only** and gates merge **order**, not review. Its removal is **not** a required status check — it is an advisory, human-honoured signal. The merge actor still performs promotion and merge manually.

### Merge-order clearance (operator)

Merge-order clearance is operator-performed. Once every sub-repo merge for the cycle is complete (the llmroute PR merged into `{{REPO_SERVICE_HOST}}:main`) and the host pointer reconcile is confirmed, the operator removes the `blocked-by-subrepo` label from the host PR — that removal is the merge-order gate the merge actor honours.

The confirmation is the operator's manual check that the host PR's `services` submodule pointer equals the llmroute PR's merge commit (see Reconcile preflight below). An automated workflow formerly published this confirmation as a machine status check; that status-check machinery was retired in issue #795 (per ADR-0015 D3, which found the signal was advisory-only and never an enforceable required check) — the merge-order gate is now the operator's `blocked-by-subrepo` label removal alone.

This clearance sits alongside the protections the reviewer verifies before merging (PR review >= 1, CI green) — the same enforcement model as every other check on this repo (see [`teammate-contracts.md`](teammate-contracts.md) > Verification scenarios).

## Per-issue procedure

After the reviewer merges the sub-repo PR(s), the merge-order sequence is a manual operator procedure.

### Host-only cycle (target-centric — the default)

For an issue cycle with **no** sub-repo change, AutoFlow's HANDOFF opens a single host PR with `--no-subrepo-dep`, so it carries **no** `blocked-by-subrepo` label and no merge-order gate. The reviewer promotes the draft to "Ready for review" and merges it directly. There is no sub-repo merge, pointer reconcile, or label to clear.

### Multi-repo cycle (sub-repo change present)

*Secondary (multi-repo):* when the host contains a submodule, the cycle's host PR depends on a sub-repo PR and the reviewer runs the sub-repo→pointer→host merge sequence below.

For an issue cycle whose host PR depends on a sub-repo PR:

1. AutoFlow's HANDOFF has already created the sub-repo PR(s) and the host PR (the latter as `--draft` with the `blocked-by-subrepo` label).
2. Review and merge the sub-repo PR into `{{REPO_SERVICE_HOST}}:main` (the host's direct submodule). Record the merge commit SHA from the llmroute PR page (URL fragment after `/commits/`). Note: nested `librechat` (`{{REPO_SUBMODULE}}`) and `librechat-deploy` PRs are llmroute's internal concern and must be merged inside llmroute before the llmroute PR itself is merged — that sequencing is outside host handoff scope.
3. Update the submodule pointer in the host PR's dev branch to the upstream merge commit, then push (or ask the original branch owner to push). See issue #91 for stale-pointer risk; this step prevents the pointer from regressing to the pre-merge commit. When this step is **delegated to AutoFlow**, follow [**Reconcile preflight**](#reconcile-preflight-concurrent-cycle-gitlink-guard) below first — it guards the concurrent-cycle gitlink conflict that otherwise leaves the host PR `CONFLICTING` and fails the Jenkins `pr-merge` build `NOT_MERGEABLE` (so GitHub records no clean status).

   > **Propagation batching (why the host pointer may not have moved yet):** during review-response, the host `services` pointer bump is deferred until the sub-repo PR's `blocked-by-review` clears, then bumped once at that clean point — so a reviewer seeing an un-bumped host pointer mid-review is observing the batching norm, not a missed step. Full norm: [`autoflow-guide.md`](autoflow-guide.md) HANDOFF step 6.5 (source of truth; this is a one-line cross-ref, not a duplicate).
4. **Operator verifies the merge-order gate is cleared.** Confirm manually that (a) the host PR is open and carries `blocked-by-subrepo`, (b) the upstream sub-repo (llmroute) PR is merged, and (c) the host PR's `services` submodule pointer equals the recorded llmroute merge commit (`git ls-tree HEAD services` == the merge commit; this is the pointer-equality requirement of the Reconcile preflight's post-reconcile gate). Once all three hold, remove the `blocked-by-subrepo` label manually: `gh pr edit <host-pr> --remove-label blocked-by-subrepo`.
5. Promote the host PR draft -> "Ready for review" (manual click).
6. Merge the host PR. The literal close-keyword line in the body closes the issue.

### Reconcile preflight (concurrent-cycle gitlink guard)

When step 3's pointer update is delegated to AutoFlow on explicit request, the dev branch may have forked *before* one or more **other** cycles' host PRs merged. Because every host-PR merge advances `main` and reconciles the `services` pointer (operator merges run one at a time), a naive pointer bump + push then leaves the host PR `CONFLICTING` and Jenkins' `pr-merge` build fails `NOT_MERGEABLE` (GitHub records no clean status). This is the frequent failure when several cycles sit in external review at once. Guard it:

**Preflight** — before bumping, fetch and compare three pointers:

- `BASE` — the dev branch's merge-base-with-`main` pointer: `git ls-tree $(git merge-base origin/main HEAD) services`.
- `MAIN` — the current `origin/main` pointer (after `git fetch origin main`): `git ls-tree origin/main services`.
- `TARGET` — this issue's sub-repo `merge_commit_sha` (the commit the host pointer must equal).

If `MAIN == BASE`, no concurrent reconcile happened — bump to `TARGET` and push as before. If `MAIN != BASE`, a concurrent cycle already reconciled the pointer; resolve by **fork ancestry** (run `git -C services fetch origin main` first, then `git -C services merge-base --is-ancestor <a> <b>`). Note: `TARGET` is the llmroute PR's merge commit; nested librechat/deploy pointer reconcile inside llmroute is llmroute's internal concern.

| Relationship on the fork | Resolution |
|---|---|
| `TARGET` is a **descendant** of `MAIN` (fork `main` moved forward; `TARGET` already contains `MAIN`) | **Put `TARGET` on the dev gitlink first, *then* merge** — `git -C services checkout <TARGET>` → `git add services && git commit` → `git merge --no-edit origin/main`. With the dev pointer already at `TARGET` (⊇ `MAIN`), the submodule **stays at `TARGET`** and only non-gitlink files merge (`Fast-forwarding submodule services …` confirms a clean gitlink). **[MUST]** A bare `git merge origin/main` with the dev pointer still at `BASE` resolves the gitlink to **`MAIN`, not `TARGET`** (the 3-way gitlink merge takes *theirs* when *ours == base*) and leaves the host pointer wrong — so the pointer must be set to `TARGET` either before or after the merge, and verified (see the post-reconcile gate). |
| `MAIN` is a **descendant** of `TARGET` (host PRs merged out of fork-merge order; bumping to `TARGET` would **regress** the live pointer) | Do **not** push. **Escalate to the operator** — the merge order on host `main` diverged from the fork merge order. |
| `TARGET` and `MAIN` **diverge** (neither is an ancestor of the other) | Fork history diverged — **escalate to the operator**. |

**Post-reconcile gate** — before/after pushing, confirm **all three**, and do not report "reconciled" until all hold:

- **Pointer == `TARGET`**: `git ls-tree HEAD services` equals `TARGET` — the merge-order gate's pointer-equality requirement the operator verifies before removing `blocked-by-subrepo`. Verify this *before* pushing.
- `gh pr view <host-PR> --json mergeable,mergeStateStatus` returns `mergeable: MERGEABLE` and `mergeStateStatus: CLEAN` (no longer `CONFLICTING`/`DIRTY`).
- The Jenkins rebuild on the new head commit is `result: SUCCESS`, queried via the **authenticated** API (the environment provides `JENKINS_URL` / `JENKINS_USER` / `JENKINS_API_TOKEN`):
  ```bash
  curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" \
    "https://jk.example.internal/job/claude-autoflow/job/PR-<n>/lastBuild/api/json?tree=number,result"
  ```
  **[MUST]** An **unauthenticated** call returns `403`/empty body — do **not** read that as "Jenkins unreachable / down". A host PR that reads `mergeable: CLEAN` but whose latest Jenkins build is `result: FAILURE` with a console `NOT_MERGEABLE` ran on the **pre-resolution (conflicted)** commit; re-verify after the post-push rebuild settles.

**Sequencing** — perform the reconcile against a **freshly-synced `main`**: run [Post-Merge Cleanup](git-workflow.md#post-merge-cleanup) for any prior cycles the operator has already merged (so `origin/main` and its pointer reflect the latest merge) *before* reconciling the current issue. This keeps `BASE ≈ MAIN` and turns most concurrent-cycle conflicts into a clean fast-forward.

## Why this exists

See [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF > Merge Sequencing (the orchestrator-facing phase body; `CLAUDE.md` routes there via its Phase Playbook Loading Contract), `design-rationale.md`, and issue #82 cycles 1-3 for the incident history that drove this design.
