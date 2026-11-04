# Git Workflow

> How a pull request closes an issue.

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
