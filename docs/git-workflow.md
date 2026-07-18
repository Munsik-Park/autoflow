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

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`.

The `Next:` line lets the next session pick up where this one left off (see
[`teammate-common-rules.md`](teammate-common-rules.md#session-protocol)).

---

## Git Clean Check

Used at PREFLIGHT (entry, including prior-cycle resolution).

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch origin
git log HEAD..origin/main --oneline   # must be empty (or handled)

# 3. Branch is from the latest main (PREFLIGHT only)
git checkout -b <type>/<issue>-<desc> main
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

- Keeps `main` history clean.
- Each feature/fix becomes a single commit.
- PR description becomes the commit body.

### When to Use Regular Merge

- Large features whose individual commits tell an important story.
- Multi-phase implementations where history matters.

### Merge Sequencing (external review)

In a single-repo deployment (target-centric — the post-reversal default; zero submodules, see `CLAUDE.md` > Deployment Topology), the cycle produces a single host PR and there is no sub-repo merge-order constraint: the host PR carries no `blocked-by-subrepo` label, and the external reviewer promotes the draft to ready and merges it directly.

In a multi-repo deployment (host PR with sub-repo dependencies), the merge order is sub-repo → pointer bump → host. The host PR is created as a draft with the `blocked-by-subrepo` label at HANDOFF. An automation (`.github/workflows/handoff-sequence.yml`) formerly machine-verified the upstream merge and submodule-pointer alignment and published a `subrepo-merged` status check as machine evidence; that machinery was **retired and physically removed** in issue #795 (per ADR-0015 D3, which found the signal was advisory-only and never an enforceable required check). Merge-order clearance is operator-performed: once the sub-repo merge and pointer reconcile are confirmed complete, the operator removes the `blocked-by-subrepo` label at merge time (a single dispatch cannot safely gate N concurrent sub-repo cycles automatically; see `docs/external-review-sequencing.md` > Merge-order clearance). Pointer alignment now rests on the operator's **manual** `git ls-tree HEAD services` check as the only remaining stale-pointer defense.

Full reviewer-facing procedure: [`external-review-sequencing.md`](external-review-sequencing.md).

See also: issue #91 (stale-pointer risk), [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF > Merge Sequencing (external review).

### Pointer reconciliation — concurrent-cycle gitlink guard

In a single-repo deployment (target-centric — the default; zero submodules), this step does not exist: with no `services` submodule there is no gitlink to reconcile. This is an active N/A — the guard below applies **only** to a multi-repo deployment, and a single-repo instance skips it entirely rather than silently omitting it.

When a **reconcile request** (pointer bump after the sub-repo PR merges) is delegated to AutoFlow and several cycles are in external review at once, the dev branch may have forked before another cycle's host PR merged and reconciled the `services` pointer. A naive bump + push then leaves the host PR `CONFLICTING` and Jenkins' `pr-merge` build fails `NOT_MERGEABLE` — the recurring "second push not recognized" symptom. Before bumping, compare `BASE` (dev's merge-base pointer), `MAIN` (current `origin/main` pointer), and `TARGET` (this issue's `merge_commit_sha`); if `MAIN != BASE`, resolve by fork ancestry:

```bash
git fetch origin main && git -C services fetch origin main
# TARGET descendant of MAIN: put TARGET on the dev gitlink FIRST, then merge main.
# A bare `git merge origin/main` with the dev pointer still at BASE resolves the
# gitlink to MAIN (3-way merge takes theirs when ours==base), NOT TARGET.
# Note: TARGET here is the llmroute (services) PR merge commit; nested
# librechat/deploy pointer reconcile inside llmroute is llmroute's internal concern.
if git -C services merge-base --is-ancestor <MAIN> <TARGET>; then
  git -C services checkout <TARGET>
  git add services && git commit -m "chore(#<N>): reconcile services pointer to <TARGET>"
  git merge --no-edit origin/main          # dev gitlink TARGET ⊇ MAIN -> submodule stays at TARGET
  test "$(git ls-tree HEAD services | awk '{print $3}')" = "<TARGET>" || echo "POINTER != TARGET — fix before push"
fi
# MAIN descendant of TARGET (would regress the pointer) OR divergent -> do NOT push; escalate to operator
```

Before/after pushing, verify **all three**: (1) `git ls-tree HEAD services` == `TARGET` (manual pointer-equality check — the machine status check that formerly asserted this was retired in #795 / ADR-0015 D3); (2) the generic mergeable + check-rollup confirmation via `scripts/handoff/confirm-ci-green.sh --pr <PR>` (the shared HANDOFF step-5 helper — issue #25; see [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF step 5 and [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight — not restated here); (3) the Jenkins rebuild `result: SUCCESS` via the authenticated API (`curl -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/job/claude-autoflow/job/PR-<n>/lastBuild/api/json?tree=result"`). **[MUST]** An unauthenticated Jenkins call returns `403`/empty — never read that as "Jenkins down". Run the reconcile against a freshly-synced `main` (Post-Merge Cleanup of prior merges first) so `BASE ≈ MAIN`. Full procedure: [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight.

---

## Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once the prior PR is observed merged
or closed (or by the live session if it observes the decision first). Apply it
to **every** resolved cycle found during prior-cycle resolution, including ones
from earlier cycles:

```bash
git checkout main
git pull origin main
git branch -d <branch>             # local branch
git push origin --delete <branch>  # remote branch (if not auto-deleted)
scripts/cleanup/cleanup-issue.sh <N>  # archive the resolved issue's .autoflow/issue-<N>.* + issue-<N>-* files to $AUTOFLOW_ARCHIVE_ROOT/<repo-key>/ (rm-deny-safe wrapper; accepts multiple Ns)
```

**Archive** (move, not delete) the resolved issue's `.autoflow/issue-{N}*` management files (state
JSON, decision ledger, design docs, reports) to
`$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-{N}-<date>/` at cleanup via
`scripts/cleanup/cleanup-issue.sh <N>` (pass one or more `N`), so each later
PREFLIGHT reads only live cycles while the resolved cycle's full artifacts are
retained outside the tree. They are gitignored working scratch; the
durable record lives in the GitHub PR/issue and commit history.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path, so the Bash command carries no `rm` token, and it archives (moves, never
deletes) only the resolved issue's files on an **exact number boundary** —
`issue-<N>.*` and `issue-<N>-*` (NOT a bare `issue-<N>*` glob, which would also
match `issue-<N>3` / a prefix-collision sibling like `123` for `N=12`) — with a
digits-only `N` guard, a scoped `mv` to
`$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-<N>-<date>/` (default `~/.autoflow`;
repo-key = `<org>__<repo>` derived from `origin`) within `.autoflow/` at
`maxdepth 1`. This keeps cleanup working under a broad `rm`
permission deny: Claude Code precedence is **deny > allow**, so an `rm`
allow-exception cannot override a broad `Bash(rm:*)` deny — only a non-`rm`
wrapper survives it. Allow-list the wrapper
(`Bash(./scripts/cleanup/cleanup-issue.sh:*)`) so it never prompts.

---

## Protected Branch Rules

### `main`

- No direct pushes.
- Require PR with at least 1 approval.
- Require CI checks to pass.
- Require AutoFlow evaluation PASS (enforced by `.claude/hooks/check-autoflow-gate.sh`).

---

## Issue Auto-Close

The PR body includes a close keyword so that merging closes the issue
automatically.

```
Closes #<issue-number>
```

*Secondary (multi-repo):* in a multi-repo deployment only the host PR uses `Closes`; each sub-repo PR uses `Part of Munsik-Park/autoflow#N` — see [`CLAUDE.md`](../CLAUDE.md) > PR Issue Auto-Close.

Recognised keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
