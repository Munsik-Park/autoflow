# ADR-0029: An attempt's records live under one record root, outside every checkout

## Status

Accepted (operator decisions 2026-10-18, issue #466 > 운영자 결정, and the criterion review's
operator decisions O2, O3 and O5; advisor decisions A2, A5 and A6). Supersedes, for where records
live and how an issue is entered and cleared: issue #423's in-tree issue directory
(`docs/records/design-rationale.md` > Decision 41), ADR-0024 D2's in-tree prefix and its archival
step, and issue #433's `record=state-file` tie of a branch to "this checkout's `.autoflow/`".

Superseded in part 2026-10-19 by ADR-0030 (issue #465): D3 — the attempt is created by the cycle on
`entry: new`, before its criterion review stage, not by a review outside the cycle — and, in D4, the
`not-ready` and `new` entries and "`/autoflow:cycle <N>` never creates an attempt (A6)". The rest of
D3 and D4 stands. See *D3 > Superseding note (2026-10-19)*.

Amended 2026-10-21 by ADR-0034 (issue #490): D2's dev branch is `dev-<stamp>-issue-<N>` (`dev/…` for
an attempt made before), its record directory names it in a file `branch`, and the dev branch starts
at the attempt's base — the remote default branch, or the branch or commit the operator names — not
at `origin/<default>` alone.

Extended 2026-10-22 by ADR-0036 (issue #493): D4's pull request is looked up for an attempt with no
state file too — an attempt on the abbreviated path — so its `pr:` line is printed and, once its pull
request is merged or closed, D5's cleanup reaches it through its `cleanup:` line; D5 is unchanged.

Amended 2026-10-22 by ADR-0037 (issue #500): in D5, the local dev branch's deletion and the cleanup
as a PREFLIGHT step leave AutoFlow — what follows a merge or a close, and whether and when the
record function runs, are the operator's practice. `cleanup-issue.sh` and its guard stand, with its
precondition stated as ADR-0037 K6 states it: an attempt of this checkout that is not active and
whose pull request is merged or closed, not one whose pull request is merged or closed alone. "No
remote branch is deleted, no push is made and no PR is changed" stands for AutoFlow's own steps.

## Context

AI work, unlike a person's, tries one issue in several sessions and puts the results together; each
attempt runs in its own checkout — a clone or a worktree (issue #466 > 상황). Up to 0.3.1 the records
of a cycle lived in the checkout's own `.autoflow/<repo-key>-issue-<N>/`, one directory per issue,
and the mode followed from that one state file's PR. Observed on `Munsik-Park/orca-autoflow` #15 and
a worktree probe (2026-10-18):

- a new attempt in the same checkout was entered as the earlier attempt's review-response while its
  PR was open, and after it closed PREFLIGHT deleted the dev branch locally and on the remote — the
  branch kept for comparing attempts — and the remote deletion, a push, stopped the entry when the
  auto mode refused it (#433);
- a new worktree started with an empty `.autoflow/`, and `git worktree remove` deleted the ignored
  `.autoflow/` with no warning (rc 0);
- every target had to ignore `.autoflow/`, which nothing set up (`docs/tool-delivery-contract.md`);
- the archive was a separate move, and the hook read the session directory's `.autoflow/` and failed
  closed on two active state files in it.

## Decision

**D1 — One record root.** Every file AutoFlow writes lives under one record root: `record_root` in
the operator's `~/.autoflow/config.json` (an absolute path), default `~/.autoflow`; the file itself
never moves with it. No file, no key or a JSON `null` gives the default. A file that cannot be read
as JSON — a syntax error, or no `jq` — or a `record_root` that is not an absolute path string leaves
the root **undetermined**, never the default in its stead (A2); an error in the same file's
`.review` does not touch it. A root inside the session's checkout, or one that cannot be created or
written, is **unusable**. Every script that needs it then writes nothing and stops with exit `7` and
the fixed marker line `record-root: UNDETERMINED <config> — <error>` /
`record-root: UNUSABLE <root> — <error>`, asking nothing. The hook, PREFLIGHT, cleanup, HANDOFF and
the metrics all read this one root through `scripts/lib/records.sh` (`bin/autoflow-records`, on
the Bash `PATH`); `AUTOFLOW_ARCHIVE_ROOT` and the metrics' `--archive-root` / `--root` are removed.

**D2 — An attempt is the unit of record.** An attempt — one run of an issue — is keyed by its dev
branch `dev/<stamp>-issue-<N>`, and its record directory is `<record-root>/<repo-key>/<stamp>-issue-<N>/`:
the state file, the ledger, the criterion review, the reports, the review records and the
cycle-layer store. The file `checkout` names the checkout it belongs to — the one that started it, or
took it over — and `completed` marks one whose cleanup ran. Issue drafts are under
`<repo-key>/drafts/`, proposal records under `<repo-key>/proposals/`, the metrics under `_metrics/`,
the hook's cache at the root.

**D3 — Each attempt begins with its own criterion review** (O2, A6). `/autoflow:criterion-review <N>`
reviews the attempt on the checked-out branch when it is this checkout's attempt of N with no state
file, and otherwise creates a new one first: `autoflow-records new --issue <N>` — on a clean tree,
with no active attempt in the checkout — fetches, makes the record directory with this checkout as
owner, and checks out a new local dev branch at `origin/<default>`. Its `[criterion-ready]` entry is
in that attempt's ledger, and `criterion-ready.sh` reads only that ledger: another attempt's entry
never makes it ready, and another attempt's records are never a reason for `NOT READY`. An attempt
with a state file takes no such entry.

*Superseding note (2026-10-19).* ADR-0030 D2–D5: `/autoflow:cycle <N>` creates the attempt on
`entry: new` and runs its criterion review stage (CRITERION-REVIEW, inside U1); `not-ready` is
`criterion-review`, an unfinished attempt not checked out is a candidate, attempts left with no
entry to take are named (`none-to-enter`), and a new attempt beside the ones still here is the
operator's request (`new`). `/autoflow:criterion-review <N>` runs the stage alone.

**D4 — Entry is a fact, printed.** `cycle-status.sh --issue <N>` evaluates the entry from this
checkout's attempts and prints it (`entry:`): in-tree state first (`stop in-tree-records`), another
issue's active attempt (`hold`), two actives (`stop multiple-active`), the active attempt of N
(`resume`); then the checked-out branch's attempt of N — another live checkout's (`stop
other-checkout`), else, taken over first when its checkout is gone (`claim:`), `start`, `not-ready`,
`review-response` or `paused`; else the one candidate ready to start or with an open PR, two or more
(`stop candidates`), or none (`new` — `NOT READY`, the criterion review next). `/autoflow:cycle <N>`
never creates an attempt (A6).

**D5 — Cleanup is local and marks; nothing moves.** An attempt of this checkout whose PR is merged or
closed is cleared: its local dev branch is deleted (detached first when it is checked out — which
works in a worktree whose default branch is another worktree's), and `cleanup-issue.sh <dev
branch>` deletes the store's `disposable/` and writes `completed`. No remote branch is deleted, no
push is made and no PR is changed (AC5). An attempt whose checkout is gone is reported and not
touched until a checkout takes it over (A5).

**D6 — The hook gates per checkout.** The state files that gate a session are those of the attempts
whose `checkout` names the session's checkout (`CLAUDE_PROJECT_DIR`); one active per checkout, two
fail closed. In a session with a dev branch checked out, an undetermined or unusable root, or no
`jq`, or a directory under the root that cannot be read, refuses the score-gated surface (push, PR
creation, a spawn other than research or evaluation) with the user file's path and error — a
detached HEAD in the middle of a rebase of a dev branch counts as that branch; reads, repairing writes and research / evaluation
spawns pass. With no `jq` this check runs before any jq read, on the raw input: the hook used to
exit 127 there, a non-blocking status, so every gate failed open; the state-independent denies (merge,
issue filing, a default-branch push, the merge-order label, a backgrounded suite run, a spawn with no
model) are now read from the raw input there too, in every session. A state file left in the
checkout's own `.autoflow/` refuses the score-gated surface until it is moved (D8).

**D7 — Nothing stays in the target's tree.** codex's sandbox writes only inside the working tree, so
`codex-review-pr.sh` has codex write a scratch file at the repository root and moves it to the
record (an absolute path), removing the scratch on every exit. A cycle-layer asset is run by its
absolute path from the target checkout's root and finds the tree from its working directory.

**D8 — Migration of in-tree records.** `scripts/migrate/migrate-in-tree-records.sh` moves each
`.autoflow/<repo-key>-issue-<N>/` whose state file names a `dev/<stamp>-issue-<N>` branch to that
attempt's record directory, with this checkout as owner; one that names no such branch is moved as a
completed record when it reads `active: false`, and reported and left for the operator when it reads
`active: true`; a directory with no state file is not a cycle and is left. A legacy
issue-level `[criterion-ready]` entry belongs to no attempt: such an issue stops `NOT READY` until a
new attempt's review records its own.

**D9 — The `status:in-progress` label is no longer described** (O3, O5): the documents and the hook's
comment that put it on and took it off are removed; nothing reads it.

## Alternatives Considered

- **Criterion confirmation per issue, shared by attempts** (A1): overridden by O2 — each attempt runs
  independently from its criterion review to its pull request.
- **The default record root when the user file is broken**: a broken file would send the hook to a
  root without this checkout's state, which it passes — a fail-open the hook closes for corrupt and
  multiple-active state (A2).
- **The criterion review creating the branch without checking it out** (A6's grounds [1]): the
  review then touches no working tree, but a re-review of that attempt, and its start, would have to
  name the branch by hand; A6's own rule reviews the attempt "when the checked-out branch is" it.
- **Keeping the codex record in the tree**: the target would need the ignore rule AC6 removes.

## Consequences

### Positive

- Attempts of one issue run side by side in worktrees and clones; their records never mix, a removed
  worktree loses no record, and a target needs no ignore rule.
- Entry and cleanup never write to the remote, so the auto mode cannot stop them.

### Negative

- A new attempt needs a clean tree and a fetch at its criterion review.
- A worktree deleted with `rm -rf` keeps its branch until `git worktree prune`; until then git refuses
  the branch's checkout elsewhere, and the takeover waits.
- The hook reads one `checkout` file per attempt directory under the root on every call.

### Neutral / Trade-Offs

- The record root's own writability is a script's check; the hook only reads.
- Completed attempts stay under the root as records; nothing prunes them.

## Related Issues / PRs

- #466 (this decision), #423, #433, #463, #465, #2.

## Notes

- The pre-#466 archives `<repo-key>/issue-<N>-<stamp>/` stay under the default root as records; the
  metrics still read them as outcomes, and nothing else does.
