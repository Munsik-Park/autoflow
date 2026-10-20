# External Review -- Merge Sequencing

> Audience: the external reviewer who merges AutoFlow PRs, and the operator. AutoFlow ends at the review's hand-off; this document covers what happens after.

A project's sub-repos, and where each one's pull request goes (a fork, the upstream), are the project's own information ([`core.md`](core.md) > Project Information). The merge order below concerns the PR of the host's direct sub-repo; a sub-repo nested inside it is merged and reconciled by that sub-repo's own procedure, outside host handoff scope. The rule AutoFlow keeps for a host that points at a sub-repo is [`units/delivery.md`](units/delivery.md) > *Multi-repo delivery*.

AutoFlow reports the merge order at the end of a cycle ([`units/review.md`](units/review.md) > *End*). Each PR is reviewed on **its own diff**, over **its own repository** — the host review never substitutes for the sub-repo review, and never judges a submodule's contents (`<autoflow-root>/docs/review/review.md` > Before Reviewing).

## Per-issue procedure

A host PR with no sub-repo dependency: the reviewer promotes the draft to "Ready for review" and merges it directly.

A host PR whose pointer depends on a sub-repo PR merges after it:

1. The sub-repo PR is reviewed and merged.
2. The host is reconciled to that merge commit — by whoever owns the host PR's branch, or by AutoFlow when the operator asks it to ([`units/delivery.md`](units/delivery.md) > *Multi-repo delivery*). A host pointer that has not moved while the sub-repo PR is still under review is not a missed step: the pointer is reconciled once the sub-repo PR has merged.
3. The operator confirms that the host PR's pointer for that sub-repo equals the merge commit (`git ls-tree HEAD <sub-repo>` on the host PR's head).
4. The host PR is promoted from draft to "Ready for review" (a manual click) and merged. The literal close-keyword line in its body closes the issue.
