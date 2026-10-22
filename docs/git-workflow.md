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

## Post-Merge Cleanup

**Merging, and what follows it, are outside AutoFlow.** Whether and when a pull request is merged,
in what sequence beside the pull requests it depends on, by what method, and what is confirmed
before it — the sub-repo pointer included — are the external review's. What follows a merge or a
close — how a host pointer is brought up after a sub-repo pull request merges, what becomes of the
attempt's dev branches on either side, and what is cleaned up, when and how, the record function
below included — is the Coordinator's. AutoFlow defines no step, order or
timing for either, and none of its steps waits on them.

The **Coordinator** is the role outside AutoFlow that assembles AutoFlow's functional and
evaluation modules — each takes an input, such as a work branch or an issue number, and produces a
result — into a pipeline. AutoFlow's text names it the owner of what follows a merge or a close,
and of nothing else: that work varies by repository and environment, so it is not AutoFlow's.
Merging stays the external review's, and one party may hold both roles. It is a role's name only:
AutoFlow names no person, session or repository that holds it, defines no step, order or timing for
it, and makes no link that reads its procedure. It is not the orchestrator, AutoFlow's own role,
which runs a cycle and ends at the hand-off.

What AutoFlow keeps there:

- It merges nothing, promotes no draft, and pushes to neither the default branch nor the attempt's
  base; every pull request it opens is a draft ([`units/delivery.md`](units/delivery.md) > *Push
  and pull request*; [`units/review.md`](units/review.md) > *End*).
- The entry sets aside an attempt of this checkout that is not active and whose pull request is
  merged or closed, by those observed facts alone, and `cycle-status.sh` names it on a `cleanup:`
  line ([`units/preparation.md`](units/preparation.md) > *What is asked*, *Modes*).
- Its own steps change nothing on the remote: PREFLIGHT reads the pull request's state and fetches,
  the record function below reads neither, and neither deletes a remote branch, pushes, or closes,
  labels or comments on a pull request.

**The record function.** `<autoflow-root>/scripts/cleanup/cleanup-issue.sh <dev branch> [<dev
branch> …]` marks an attempt that is over. Its precondition is an attempt of this checkout — one
whose record directory's `checkout` file names this checkout — that is not active (it has no state
file, or its state file's `active` is not `true`) and whose pull request is merged or closed: the
attempt `cycle-status.sh` names on a `cleanup:` line. The mark ends the attempt for the gate hook
too — the hook passes over a record directory marked `completed` when it looks for this checkout's
active attempt — so an attempt still running is not marked, even when its pull request was merged
or closed out of band. The script does not read the state file itself. An attempt of another
checkout still there (`owner=other`), or one whose checkout is gone (`owner=gone`) until a checkout
takes it over, is not this checkout's to mark, and the script refuses it; a dev branch with no
attempt record (`record=none`) has no attempt to mark.

It deletes the attempt's reserved path `<attempt-dir>/issue-{N}-local/disposable/` — the
reproducible output its cycle assets wrote there
([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *How a test is
run is the target's practice*) — and then writes the mark `<attempt-dir>/completed`. Nothing is
moved or archived: the record directory is under the record root, outside every checkout's tree,
from the start, and everything outside the reserved path stays in it — the management files (state
JSON, decision ledger, criterion review, design docs, reports) **and the rest of its cycle-layer
store `issue-{N}-local/`**. A completed attempt is no longer listed as an attempt and is never
entered again. A deletion that fails leaves that attempt unmarked and exits non-zero; re-run it
once the path is removable. A store that is itself a symbolic link keeps its target untouched. It
touches no git ref.

Whether and when it runs is the Coordinator's. An attempt left unmarked:

1. stays listed by `cycle-status.sh`;
2. has its pull request looked up on every `cycle-status.sh` run. A lookup that fails is a fact not
   read: the run exits `3`, and the entry for the requested issue, read from the attempt's other
   facts, can name it unread until a run reads the lookup — `none-to-enter <key>:unread`, or
   `stop unreadable <key>` on its checked-out dev branch, for example
   ([`units/preparation.md`](units/preparation.md) > *Modes*);
3. keeps its `issue-{N}-local/disposable/` on disk.

While its pull request can be read, it changes no other issue's entry and no exit code.

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

*Secondary (multi-repo):* when the cycle changes a sub-repo, it opens a PR there too — the host PR carries the close keyword, each sub-repo PR references only:

```
# Host PR (closes the issue)
Closes #N

# Sub-repo PR (references only, does NOT close)
Part of <host-owner>/<host-name>#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- **[MUST]** Sub-repo PRs do NOT use `Closes`.
- The host PR carries `Closes #N`; composing the PR body is the orchestrator's, and nothing checks the line ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).
- **[MUST]** PR bodies generated from `.github/pull_request_template.md` never inline a plain-text close-keyword token in the template itself. The template uses the marker `<!-- HOST-CLOSE-LINE -->`; the orchestrator replaces the marker with the active `Closes #N` line when it writes the host PR body. Templates / docs / design notes that **describe** the close-keyword pattern must wrap the example in backticks or code-fences.
