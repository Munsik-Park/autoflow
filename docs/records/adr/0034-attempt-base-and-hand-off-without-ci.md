# ADR-0034: An attempt starts from the base the operator names, and a pull request no CI runs for is handed off with that recorded

## Status

Accepted (issue #490; the criteria settled by the attempt's criterion review, entry O1, with the
advisor decisions A1 — the pull request's base when the operator names a commit — and A2 — a pull
request no CI runs for). Amends ADR-0029 D2 (the dev branch's name) and D3, and ADR-0030 D2 (where
`autoflow-records new` makes the dev branch, and its options); amends ADR-0024 D4 and D5 (what the
hand-off is bound to — Amendment note (issue #490) there).

## Context

An attempt began at the remote default branch and nowhere else. `autoflow-records new` took no
option but `--issue` and switched to `dev/<stamp>-issue-<N>` at `origin/<default>`; PREFLIGHT's start
fast-forwarded that branch to `origin/<default>` again; the pull request was opened with no
`--base`, so GitHub's default branch took it. The places that read "this attempt's change" took the
default branch or wrote `main` outright: the conflict resolution and the push-rejection rebase
(`origin/main`), INTEGRATE's `git merge-base HEAD main`, the commit-time lint trust boundary
(baseline `main`), the multi-repo reconcile (the default branch), the AUDIT security-checklist base
(`origin/HEAD`). The hook denied a push to the default branch only.

The operator asked for a cycle that works from a branch of any name, `dev` among them, or from a
commit, to the same end — a reviewed, open pull request (issue #490 > 상황).

The dev branch's name put every attempt under the ref directory `dev/`, and git keeps `dev` and
`dev/…` apart in one repository. Observed in a local bare repository (git 2.50.1): with a remote
`dev`, the push of `dev/…` is `[remote rejected] … (failed to update ref)`; a clone that still has a
remote-tracking `origin/dev/…` from a deleted branch fails `git fetch origin` once the remote has
`dev` (`cannot lock ref 'refs/remotes/origin/dev'`), and `git fetch --prune origin` succeeds; with
the default branch named `dev`, the hook's `\b` after the branch name denied `git push -u origin
dev/…` (the criterion review's reconciliation, by the same expression).

The hand-off was bound to CI green: HANDOFF → REVIEW required it, and `confirm-ci-green.sh` exit `11`
— no check published within the bound — was not green, so the cycle stopped at the operator after
its retries. A target's CI may not run for a pull request at all: a `pull_request` trigger filtered
by base branch or path, a job condition, or no workflow. A pull request into a named base is one such
case and not the only one (A2).

## Decision

**D1 — The base is named when the attempt is made.** `autoflow-records new --issue <N> [--base
<branch>] [--commit <commit>]`. The attempt's base — the branch its pull request merges into — is
`--base`, or the remote default branch. The dev branch starts at `--commit`, or at the base's latest
commit on `origin`. Both are kept on the dev branch in the checkout's git configuration: the base as
`branch.<dev branch>.gh-merge-base`, which `gh pr create` reads when no `--base` is given, and a named
commit as `branch.<dev branch>.autoflow-start`. `autoflow-records base` prints the base, and the
remote default branch for a branch with none (an attempt made before this change). PREFLIGHT's start
fast-forwards the dev branch to `origin/<base>` unless `autoflow-start` is set. The operator names
them with the request (`/autoflow:cycle <N> new --base <branch>`, `--commit <commit>`).

With no name given the base is the remote default branch, as before; it is now read once, at the
attempt's creation, and kept with the branch. A commit with no `--base` has the remote default branch
as its base (A1). A commit that is not in the base's history makes the pull request carry the
commits between them (a pull request holds what follows the merge-base); `git log origin/<base>..HEAD`
shows that before the pull request is opened, and whether to stop and report or to proceed with the
fact stated is the cycle's judgment (A1).

Why the git configuration: `gh pr create` reads it; the hook reads it with one `git config` before
any state is read (D3); a deleted branch takes its section with it. It lives in the checkout's
repository: an attempt taken over (`autoflow-records claim`) from another clone has no
`gh-merge-base` there and reads the remote default branch, and its open pull request still names its
base.

**D2 — The base stands where the default branch or `main` stood for this attempt's change.** The
start's fast-forward, the pull request's base, the conflict resolution and the push-rejection
rebase, INTEGRATE's predicate (`git merge-base HEAD origin/<base>`), the lint trust boundary's
baseline, the multi-repo reconcile, the security checklist's default base, and the commit the
criterion review reads (the attempt's start). Left as they are: `cycle-status.sh`'s default-branch
line (a fact about the repository), the cleanup's `git switch --detach origin/<default>` (any commit
would do), `tests/lib/base-ref.sh` (this repository's own suite selection) and the Branch Strategy
table of `docs/git-workflow.md` (a naming convention, not an attempt's base).

**D3 — AutoFlow does not push to the base.** In a dev-branch session the hook's state-independent
push deny (Section 1, and Section 0 with no `jq`) covers the dev branch's `gh-merge-base` beside the
default branch — the authority rule that keeps a change from reaching a branch without its pull
request and review (`docs/core.md` > Rule Scope, principle 1). A branch name matches as a whole name:
it ends where a character no branch name has there follows, not at `\b`, so a default branch or base
`dev` does not deny `dev-…`.

**D4 — The dev branch is `dev-<stamp>-issue-<N>`.** No `/`: no branch the operator names, `dev`
included, shares a ref directory with it. The attempt key stays `<stamp>-issue-<N>`; `af_attempt_key`
also takes `dev/<stamp>-issue-<N>`, so an attempt made before this change continues on its branch,
and the record directory holds a file `branch` naming the dev branch (`af_attempt_branch`; a
directory without one is an attempt made before, `dev/<key>`). `autoflow-records new`, the start sync
and the criterion review's entry fetch with `--prune`, so a stale `origin/dev/…` does not keep a
remote `dev` out.

**D5 — A pull request no CI runs for goes on to the review, recorded as such** (A2). At exit `11` the
orchestrator judges whether the target's CI does not run for the pull request — no workflow, or a
trigger, path filter or condition that excludes it — or is only late, which a push again (a
`synchronize` event) settles. When it does not run, the pull request's body records that and the
ground, what CI was to run for it (a `ci-deferred` lint chain, an added test file) is listed as not
run, and the cycle goes on to U7; U7's end takes the same. "No check published" stays not green:
nothing reads exit `11` as a pass, and no text on the pull request says CI passed. Exits `10`, `12`,
`13` and `14` route as before; the merge and the draft's promotion stay the operator's. This holds
for every pull request of a cycle, a named base being one of the cases.

## Consequences

- GitHub links a pull request to an issue by its close keyword only when the pull request is into
  the default branch; one into another base does not close the issue when it merges. Closing an
  issue is outside AutoFlow's authority; the pull request's body still names the issue and checks its
  criteria.
- An attempt made before this change keeps `dev/<stamp>-issue-<N>` and the remote default branch as
  its base.
- Not observed: GitHub's answer to a push of `dev/…` while the remote has `dev` (it needs a branch
  written to a remote); D4 removes the dependence on it.

## Rejected

- **The base in the state file.** The state file is written after the criterion review, which
  already needs the base; and the hook's closed-world schema of that file would change for a value
  git already keeps for `gh`.
- **Refusing a base whose name collides with the dev branch's.** The criteria ask for any name
  (criterion 1, which took the earlier criterion 4 in).
- **Changing a target's workflow so that its CI runs.** That is the target's configuration and one
  repository's case, not the general problem (the operator's decision in the criterion review).
