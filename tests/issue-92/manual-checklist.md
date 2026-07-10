# Issue #92 — Manual Verification Checklist

Verification design BP1-BP4 (manual / environment / observational scenarios).
These are delegated to the user / operator; AutoFlow does not automate them
because each is an external-system concern (GitHub repo settings, human
behavior, or live cross-repo integration).

> **Note (issue #795):** the automated HANDOFF status-check dispatch workflow
> was retired — physically removed — per ADR-0015 D3, as an advisory-only
> signal that was never an enforceable required check. The former dispatch
> dry-run scenarios (old M1 / M4 / M4b / M4c / M5) are therefore obsolete and
> were removed with the machine. The surviving merge-order gate is the
> operator's `blocked-by-subrepo` label (M3 below) plus the manual pointer
> reconcile in `docs/external-review-sequencing.md` > Reconcile preflight.

## M2 — External reviewer follows the merge sequence (BP2)

Observational only. Over the next 1-2 real AutoFlow cycles, confirm that
the external reviewer follows the steps in
`docs/external-review-sequencing.md` (sub-repo merge → pointer reconcile →
operator pointer-equality verification → `blocked-by-subrepo` label removal →
promote → merge).

PASS criterion: at least one full cycle observed with steps performed in
order.

## M3 — `gh label create` bootstrap executed (BP3)

Verify the `blocked-by-subrepo` label exists in the host repo.

Command:

```bash
gh label list --repo Munsik-Park/autoflow | grep blocked-by-subrepo
```

Expected: one matching line; color and description match
`docs/external-review-sequencing.md` > Label section.

PASS criterion: command exits 0 with one matching line.

## M4 — Multi-repo merge-order gate honoured on a throwaway PR (BP4)

One-cycle live dry-run, recommended before the first production multi-repo
cycle. Exercises the operator merge-order gate now that the automated
status-check machinery is gone: the gate is the `blocked-by-subrepo` label +
the operator's manual pointer-equality confirmation.

Procedure:

1. Open a throwaway PR in `{{REPO_SERVICE_HOST}}` with any trivial change that
   does not affect production. (Nested `librechat` / `librechat-deploy` PRs
   are llmroute-internal concerns and fall outside host-level handoff scope.)
2. Open a throwaway host PR with the `services` submodule pointer updated to
   the sub-repo's branch tip commit SHA. Apply the `blocked-by-subrepo` label.
3. Confirm the host PR is draft + carries `blocked-by-subrepo`.
4. Merge the throwaway PR into `{{REPO_SERVICE_HOST}}:main`. Record the
   llmroute merge commit SHA from the PR page (URL fragment after `/commits/`).
5. Push a host PR commit that updates the `services` pointer to the recorded
   llmroute merge commit SHA.
6. Confirm manually (the operator's pointer-equality check) that
   `git ls-tree HEAD services` on the host PR head equals the recorded
   llmroute merge commit SHA.
7. Once (4) and (6) hold, remove the `blocked-by-subrepo` label manually
   (`gh pr edit <M> --remove-label blocked-by-subrepo`), promote the draft to
   ready, and merge.

PASS criterion: the cycle completes end-to-end — sub-repo merge, pointer
reconcile, operator pointer-equality confirmation, label removal, host PR
merge — with no automated status check anywhere in the sequence.
