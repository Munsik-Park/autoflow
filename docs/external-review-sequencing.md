# External Review -- Merge Sequencing

> Audience: the external reviewer who merges AutoFlow PRs, and the operator who bootstraps the host repository. AutoFlow ends at PR creation; this document covers what happens after.

A project's sub-repos, and where each one's pull request goes (a fork, the upstream), are the project's own information ([`CLAUDE.md`](../CLAUDE.md) > Project Information). The merge order below concerns the PR of the host's direct sub-repo; a sub-repo nested inside it is merged and reconciled by that sub-repo's own procedure, outside host handoff scope. The rule AutoFlow keeps for a host that points at a sub-repo is [`phases/handoff.md`](phases/handoff.md) > *Multi-repo delivery*.

## Operator prerequisites

Out-of-AutoFlow administration. Run once per repository a cycle opens pull requests in, before the per-issue procedure can be exercised: create the `blocked-by-review` gate label in the host and in each sub-repo, and `blocked-by-subrepo` in the host. These are advisory, human-honoured signals — neither is a required status check.

### Label

```bash
gh label create blocked-by-subrepo \
  --color b60205 \
  --description "Host PR depends on a sub-repo PR not yet merged; do not promote draft to ready" \
  --repo <host-owner>/<host-name>

gh label create blocked-by-review \
  --color b60205 \
  --description "Codex review has unresolved Medium+ findings; do not promote draft to ready" \
  --repo <owner>/<name>      # the host, and each sub-repo
```

The `blocked-by-review` gate label is a **per-PR** review gate: it is attached to **every** PR opened for a cycle — the host PR **and each sub-repo PR** (the orchestrator's `gh pr create --draft --label blocked-by-review …`; [`phases/handoff.md`](phases/handoff.md) > *Push and pull request*) — and is removed by the Codex reviewer on **that same PR** (`scripts/review/codex-review-pr.sh --pr <N> [--repo <owner/name>]`, per `.codex/review.md`) only when **that PR's** review finds no `Medium`+ finding. Each PR is reviewed on **its own diff**, over **its own repository** — the host review never substitutes for the sub-repo review, and never judges a submodule's contents (see *Review gate and merge-order gate* below). The label must therefore exist **in each sub-repo too**, not only the host. This is distinct from `blocked-by-subrepo`, which is **host-only** and gates merge **order**, not review. Its removal is **not** a required status check — it is an advisory, human-honoured signal. The merge actor still performs promotion and merge manually.

Its lifecycle has **three** actions — attach, remove, and **re-attach**: (1) **attach** at PR creation, on every PR of the cycle; (2) **remove** by the reviewer on that PR when its review confirms no `Medium`+ finding; (3) **re-attach** by the reviewer when a *later* review of the same PR confirms a `Medium`+ finding while the label is absent. Attach and remove are mutually exclusive on any single review (zero findings versus at least one), and authority over the label is directional: the reviewer is the **sole** authority for **removal** (the orchestrator is hook-denied), while **attach** is **reviewer-primary with an orchestrator backstop** — the orchestrator re-attaches at HANDOFF review triage ([`phases/handoff.md`](phases/handoff.md) > *Review triage*) only when the reviewer's own attach did not land, and an attach made in error is undone by a reviewer re-review, never by the orchestrator. All three actions require the label to exist in the target repo — creation stays operator-owned, per the prerequisites above.

### Merge-order clearance (operator)

Merge-order clearance is operator-performed. Once every sub-repo PR the host PR depends on has merged and the host has been reconciled to its merge commit, the operator confirms that the host PR's pointer for that sub-repo equals the merge commit (`git ls-tree HEAD <sub-repo>` on the host PR's head) and removes the `blocked-by-subrepo` label from the host PR — that removal is the merge-order gate the merge actor honours. A machine status check for this signal is advisory-only, never an enforceable required check.

This clearance sits alongside the protections the reviewer verifies before merging (PR review >= 1, CI green; see [`role-contracts.md`](role-contracts.md) > Verification scenarios).

### Review gate and merge-order gate

A host PR that depends on a sub-repo PR carries two labels, and each guards one thing:

- `blocked-by-review` guards the host PR's **own review**. Its target is what the host repository tracks directly — the submodule pointer included, a submodule's contents excluded (`.codex/review.md` > Before Reviewing) — so the label reflects `Medium`+ findings in host-tracked files alone. A finding in sub-repo code keeps the sub-repo PR's label, never the host's.
- `blocked-by-subrepo` guards **merge order**: the host PR does not merge before the sub-repo PR its pointer depends on. The operator clears it (*Merge-order clearance* above).

The host PR differs from a sub-repo PR only in carrying `blocked-by-subrepo`; its review and review label follow the same per-PR rule. A host PR whose review label has cleared while its sub-repo PR's review is still open is held by `blocked-by-subrepo` alone — the intended gate, not a gap.

## Per-issue procedure

A host PR with no sub-repo dependency carries no `blocked-by-subrepo`: the reviewer promotes the draft to "Ready for review" and merges it directly.

A host PR that carries `blocked-by-subrepo` merges after its sub-repo PR:

1. The sub-repo PR is reviewed and merged.
2. The host is reconciled to that merge commit — by whoever owns the host PR's branch, or by AutoFlow when the operator asks it to ([`phases/handoff.md`](phases/handoff.md) > *Multi-repo delivery*). A host pointer that has not moved while the sub-repo PR is still under review is not a missed step: the pointer is reconciled once the sub-repo PR has merged.
3. The operator clears the merge-order gate (*Merge-order clearance* above).
4. The host PR is promoted from draft to "Ready for review" (a manual click) and merged. The literal close-keyword line in its body closes the issue.
