# Git Workflow

> Standard git procedures for projects using the AutoFlow methodology.

---

## Branch Strategy

| Type | Pattern | Purpose | Base |
|------|---------|---------|------|
| Feature  | `feature/<issue>-<desc>`  | New functionality | `main` |
| Fix      | `fix/<issue>-<desc>`      | Bug fixes | `main` |
| Refactor | `refactor/<issue>-<desc>` | Code improvements | `main` |
| Docs     | `docs/<issue>-<desc>`     | Documentation updates | `main` |
| Chore    | `chore/<issue>-<desc>`    | Maintenance tasks | `main` |

Examples:

```
feature/42-add-user-authentication
fix/87-resolve-memory-leak
docs/55-update-api-reference
```

---

## Commit Messages

### Format

```
<type>(#<issue>): <description>

Next: <next action>
```

`type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`.

The `Next:` line names the action the next session continues from (see
[`role-common-rules.md`](role-common-rules.md#session-protocol)).

---

## Git Clean Check

The conditions PREFLIGHT starts from ([`units/preparation.md`](units/preparation.md) > *What is asked*).
`<autoflow-root>/scripts/preflight/cycle-status.sh` reports the working tree and the default branch against its
remote-tracking ref; bringing them to this state is the orchestrator's.

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch --prune origin
# An attempt's start: its dev branch dev-<date>-<time>-issue-<N>, made at its base's latest commit
# when the cycle created the attempt (autoflow-records new) and with no commit of its own yet, is
# checked out and fast-forwarded to its base's latest commit — `autoflow-records base` prints the
# base; an attempt made at a named commit (git config branch.<dev branch>.autoflow-start) stays there
git switch dev-<date>-<time>-issue-<N>
git merge --ff-only origin/<base>
# A review-response: the dev branch matches its remote branch
git log HEAD..origin/dev-<date>-<time>-issue-<N> --oneline   # must be empty (or handled)
# In a project with sub-repos, each submodule is at the commit the host's pointer names
# after the host is synced (the orchestrator's work item; nothing checks it).
```

Nothing here checks out or updates the local base: a worktree whose base is checked out in
another worktree cannot (`git checkout <base>` and `git fetch origin <base>:<base>` both refuse
there), and a checkout on any other branch needs no more than `origin/<base>`.

If any check fails:

- Uncommitted changes → `git stash`, `git commit`, or discard with the user's
  approval (PREFLIGHT).
- Remote has new commits ahead of a review-response branch → `git pull --rebase` and re-run.
- A dev branch that does not fast-forward → stop and report; it is not reset.

If the working tree cannot be made clean, **stop** and report. PREFLIGHT does
not advance to DIAGNOSE on a dirty tree.

---

## Pull Request Process

### Creating a PR (SHIP)

1. Verify all commits are clean and well-described.
2. Push the branch to remote (`git push -u origin <branch>`).
3. Create the PR using the template below.

```markdown
## Summary
[1-3 sentences describing the change]

## Changes
- [Bullet list of key changes]

## Issue
Closes #<issue-number>

## AutoFlow Evaluation
- Score: [X/10]
- Report: [link or inline]

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] No existing tests broken
```

### PR Review Checklist (Human Reviewers)

- Changes match the described issue.
- Code is readable and follows project conventions.
- Tests are adequate.
- No security concerns.
- AutoFlow evaluation score is acceptable.

---

## Merge Strategy

### Recommended: Squash and Merge

- PR description becomes the commit body.

### When to Use Regular Merge

- Large features whose individual commits tell an important story.
- Multi-phase implementations where history matters.

### Merge Sequencing (external review)

A host PR with no sub-repo dependency is promoted and merged by the external reviewer directly. A
host PR that depends on a sub-repo PR merges after it: the sub-repo PR merges, the host is reconciled
to its merge commit, the operator confirms the host pointer equals that merge commit, and the host PR
is then promoted and merged. AutoFlow reports this order at the end of a cycle. The rule AutoFlow
keeps for the host's pointer, and its cautions, are [`units/delivery.md`](units/delivery.md) >
*Multi-repo delivery*; the reviewer- and operator-facing guide is
[`external-review-sequencing.md`](external-review-sequencing.md).

---

## Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once an attempt's PR is observed merged
or closed (or by the live session if it observes the decision first). Apply it
to **every** resolved attempt of this checkout — one whose record directory's
`checkout` file names this checkout — that `cycle-status.sh` reports on a
`cleanup:` line; `<branch>` is its dev branch. An attempt of another checkout
still there (`owner=other`), an attempt whose checkout is gone (`owner=gone`)
until a checkout takes it over, and a dev branch with no attempt record
(`record=none`) are reported and not touched, locally or on the remote
([`units/preparation.md`](units/preparation.md) > *What is asked*):

```bash
git switch --detach origin/<default> # only when <branch> is the checked-out branch
git branch -D <branch>               # the local dev branch
<autoflow-root>/scripts/cleanup/cleanup-issue.sh <branch>  # delete its issue-<N>-local/disposable/, then mark the attempt completed (accepts several branches)
```

**Nothing on the remote is changed.** The remote dev branch and the pull request are left as
they are — they are the record the attempt left for whoever reads the attempts together, and
deleting a remote branch is a push. Cleanup reads the pull request's state and changes no label,
comment or state on it. `git branch -D` is used because the PR's merge (a squash, a rebase) or its
closing leaves the branch unmerged into any local branch; the observed merged or closed PR is the
ground, and the remote branch keeps the commits.

**Delete the reserved path, mark the rest.** Cleanup deletes the attempt's reserved path
`<attempt-dir>/issue-{N}-local/disposable/` — the reproducible output its cycle assets wrote there
([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *How a test is
run is the target's practice*) — and then writes the mark `<attempt-dir>/completed`. Nothing is
moved or archived: the record directory is under the record root, outside every checkout's tree,
from the start, and everything outside the reserved path stays in it — the management files (state
JSON, decision ledger, criterion review, design docs, reports) **and the rest of its cycle-layer
store `issue-{N}-local/`**. A completed attempt is no longer listed as an attempt and is never
entered again. A deletion that fails leaves that attempt unmarked and exits non-zero; re-run
cleanup once the path is removable. A store that is itself a symbolic link keeps its target
untouched.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path and takes only an attempt's dev branch, checked against the shape
`dev-YYYY-MM-DD-HHMMSS-issue-<N>` (`dev/…` for an attempt made before issue #490) before it becomes the record directory's name
`<record-root>/<repo-key>/<YYYY-MM-DD-HHMMSS>-issue-<N>/` (repo-key = `<org>__<repo>` derived from
`origin` — `<autoflow-root>/scripts/lib/records.sh`), and it refuses an attempt whose `checkout` file
names another checkout. Its one deletion is that reserved path, `issue-<N>-local/disposable`, removed
without following a symbolic link. Allow-list the wrapper
by its absolute path — `Bash(<the AutoFlow root>/scripts/cleanup/cleanup-issue.sh:*)`, the root as `autoflow-root` prints it.

---

## Protected Branch Rules

### `main`

- No direct pushes.
- Require PR with at least 1 approval.
- Require CI checks to pass.
- Require AutoFlow evaluation PASS (enforced by `<autoflow-root>/hooks/check-autoflow-gate.sh`).

---

## Issue Auto-Close

A cycle that changes no sub-repo opens one PR, and that PR carries `Closes #N`.

*Secondary (multi-repo):* when the cycle changes a sub-repo, it opens a PR there too — the host PR carries the close keyword and merges last, each sub-repo PR references only and merges first:

```
# Host PR (merges last — closes the issue)
Closes #N

# Sub-repo PR (merges first — references only, does NOT close)
Part of <host-owner>/<host-name>#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- **[MUST]** Sub-repo PRs do NOT use `Closes`.
- The host PR carries `Closes #N`; composing the PR body is the orchestrator's, and nothing checks the line ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).
- **[MUST]** PR bodies generated from `.github/pull_request_template.md` never inline a plain-text close-keyword token in the template itself. The template uses the marker `<!-- HOST-CLOSE-LINE -->`; the orchestrator replaces the marker with the active `Closes #N` line when it writes the host PR body. Templates / docs / design notes that **describe** the close-keyword pattern must wrap the example in backticks or code-fences.
