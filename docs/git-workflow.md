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

The conditions PREFLIGHT starts from ([`phases/preflight.md`](phases/preflight.md) > *What is asked*).
`scripts/preflight/cycle-status.sh` reports the working tree and the default branch against its
remote-tracking ref; bringing them to this state is the orchestrator's.

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch origin
git log HEAD..origin/main --oneline   # must be empty (or handled)
# In a project with sub-repos, each submodule is at the commit the host's pointer names
# after the host is synced (the orchestrator's work item; nothing checks it).

# 3. Branch is from the latest main (a new issue; an AutoFlow cycle's dev branch is dev/<date>-issue-<N>)
git checkout -b <branch> main
```

If any check fails:

- Uncommitted changes → `git stash`, `git commit`, or discard with the user's
  approval (PREFLIGHT).
- Remote has new commits ahead → `git pull --rebase` and re-run.
- Wrong base → re-branch from latest main.

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
host PR that depends on a sub-repo PR carries `blocked-by-subrepo` and merges after it: the sub-repo
PR merges, the host is reconciled to its merge commit, the operator confirms the host pointer equals
that merge commit and removes the label, and the host PR is then promoted and merged. The rule AutoFlow
keeps for the host's pointer, and its cautions, are [`phases/handoff.md`](phases/handoff.md) >
*Multi-repo delivery*; the reviewer- and operator-facing guide is
[`external-review-sequencing.md`](external-review-sequencing.md).

---

## Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once the prior PR is observed merged
or closed (or by the live session if it observes the decision first). Apply it
to **every** resolved cycle found during prior-cycle resolution, including ones
from earlier cycles:

```bash
git checkout main
git pull origin main                # with sub-repos: each submodule follows the host's pointer
git branch -d <branch>             # local branch
git push origin --delete <branch>  # remote branch (if not auto-deleted)
scripts/cleanup/cleanup-issue.sh <N>  # delete the resolved issue's issue-<N>-local/disposable/, then archive its .autoflow/issue-<N>.* + issue-<N>-* files and the rest of its issue-<N>-local/ store to $AUTOFLOW_ARCHIVE_ROOT/<repo-key>/ (accepts multiple Ns)
```

The remote-branch deletion is a push: the hook admits it only while no cycle is
active, so it comes before the next cycle's state file is created
([`phases/preflight.md`](phases/preflight.md) > *What is asked*).

**Delete the reserved path, archive the rest.** Cleanup first deletes the resolved issue's reserved
path `.autoflow/issue-{N}-local/disposable/` — the reproducible output its cycle assets wrote there
([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *How a test is
run is the target's practice*) — and then **archives** (moves) its `.autoflow/issue-{N}*` management
files (state JSON, decision ledger, design docs, reports) **and the rest of its cycle-layer store
`.autoflow/issue-{N}-local/`** (the uncommitted `automated` / `delivery-check` / `manual` assets of
that cycle; the directory moves with its name preserved) to
`$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-{N}-<date>/` at cleanup via
`scripts/cleanup/cleanup-issue.sh <N>` (pass one or more `N`). Nothing outside the reserved path is
deleted: whatever lies outside it is archived, whatever its name or size. The report line states the
deletion apart from the archived count. A deletion that fails leaves that issue in place, with
nothing archived, and exits non-zero; re-run cleanup once the path is removable. A store that is
itself a symbolic link is archived as the link, and nothing under its target is deleted.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path and archives only the resolved issue's files and store on an **exact number boundary** —
`issue-<N>.*`, `issue-<N>-*` and the directory `issue-<N>-local` (NOT a bare `issue-<N>*` glob) — with a
digits-only `N` guard, a scoped `mv` to
`$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-<N>-<date>/` (default `~/.autoflow`;
repo-key = `<org>__<repo>` derived from `origin`) within `.autoflow/` at
`maxdepth 1` (the store is one such entry, moved less its reserved path). Its one deletion is that
reserved path, `issue-<N>-local/disposable`, removed without following a symbolic link. Allow-list the wrapper
(`Bash(./scripts/cleanup/cleanup-issue.sh:*)`).

---

## Protected Branch Rules

### `main`

- No direct pushes.
- Require PR with at least 1 approval.
- Require CI checks to pass.
- Require AutoFlow evaluation PASS (enforced by `.claude/hooks/check-autoflow-gate.sh`).

---

## Issue Auto-Close

In the target-centric default, the cycle's single (host) PR carries `Closes #N` directly.

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
- The host PR carries `Closes #N`; composing the PR body is the orchestrator's, and nothing checks the line ([`phases/handoff.md`](phases/handoff.md) > *Push and pull request*).
- **[MUST]** PR bodies generated from `.github/pull_request_template.md` never inline a plain-text close-keyword token in the template itself. The template uses the marker `<!-- HOST-CLOSE-LINE -->`; the orchestrator replaces the marker with the active `Closes #N` line when it writes the host PR body. Templates / docs / design notes that **describe** the close-keyword pattern must wrap the example in backticks or code-fences.
