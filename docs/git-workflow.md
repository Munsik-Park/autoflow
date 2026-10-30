# Git Workflow

> How a pull request closes an issue. A target's own practice and an invocation's `instructions` come first.

---

## Post-Merge Cleanup

Merging, and what follows a merge or a close, are outside AutoFlow.

---

## Issue Auto-Close

A change that touches no sub-repo is delivered on one PR, and that PR carries `Closes #N`.

*Secondary (multi-repo):* when the delivery module opens a PR in a sub-repo too, the host PR carries the close keyword, each sub-repo PR references only:

```
# Host PR (closes the issue)
Closes #N

# Sub-repo PR (references only, does NOT close)
Part of <host-owner>/<host-name>#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- A sub-repo PR does not use `Closes`.
- The host PR carries `Closes #N`; composing the PR body is the delivery module's, and nothing checks the line ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).
- A pull-request template does not inline a plain-text close keyword: this repository's `.github/pull_request_template.md` uses the marker `<!-- HOST-CLOSE-LINE -->`, which the host PR's body replaces with the `Closes #N` line. A template, document or design note that describes the pattern wraps the example in backticks or a code fence.
