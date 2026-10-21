# The Abbreviated Path — Criterion Review, Work Outside a Cycle, Review

An attempt — one run of an issue, keyed by its dev branch — goes on after its criterion review by
one of two paths. The **full cycle** writes the attempt's state file at PREFLIGHT and reaches REVIEW
through every unit and gate ([`core.md`](core.md) > Development Lifecycle and the unit documents).
The **abbreviated path**, defined here, goes on outside an AutoFlow cycle: the attempt's criterion
review, then work that no AutoFlow unit runs, then the review, and the review again after each
rework. An attempt on it never has a state file.

This document is the path's only home. Its search terms:

```
git grep -n -i -E 'abbreviated path|abbreviated <key>|:abbreviated|coordinating session'
```

## Composition

```
criterion review → work outside a cycle → review → end
                                            └→ rework → review
```

- **The criterion review is the entry.** `/autoflow:criterion-review <N> [new]` runs the attempt's
  criterion review stage alone, from the entries `new` and `criterion-review`
  ([`criterion-review.md`](criterion-review.md)). The path starts on the attempt's
  `[criterion-ready]` entry for the issue body as it stands; a `READY` attempt goes on either by
  `/autoflow:cycle <N>` — the full cycle — or on this path.
- **The work is outside AutoFlow.** No unit, gate or AutoFlow method runs it. The one constraint
  on it: its commits are on the attempt's dev branch and its pull request is opened from that
  branch. The attempt's record directory, its pull request lookup (`cycle-status.sh`), the review's
  verdict script (`review-gate.sh`) and the cleanup find the attempt by that branch; work on
  another branch is not this attempt's.
- **The review** is U7 run on an attempt with no state file, by `/autoflow:cycle-u7 <N>`
  ([U7 Review](units/review.md) > *An attempt with no state file*): the configured reviewers, one
  aggregated comment and the findings file per round, the verdict, the CI result as read, and the
  round count, returned to the coordinating session. It writes no state file and routes nothing to
  a unit.
- **The coordinating session** is the session that runs the path: it directs the work, has the
  review run, reads what the review returns and decides what follows. How it, the work and the
  review are started and watched — the sessions, the monitoring tools, the runbooks, the round
  materials, and which checkout each runs in — is machine-local and not AutoFlow's.

## End and rework

- **End.** The path ends when the review's verdict is below `Medium` — `review-gate.sh` reports
  `clean` or `low-only` — **and** the pull request's CI is green, or its not running is recorded on
  the pull request. Neither alone ends it. A `low-only` verdict's findings are the coordinating
  session's to weigh: fixed by a rework, or left.
- **CI.** The review returns CI as `confirm-ci-green.sh` reads it, never as green unless it is.
  On exit `11` (no check published) the judgment whether CI does not run for the pull request or
  is only late, and the record of its not running with the ground, are the coordinating session's
  — made or directed by it, in the form [U6 Delivery](units/delivery.md) > *CI* states for exit
  `11`. A red build, and any other result that is not green, is not an end.
- **Rework.** A `Medium`+ verdict (`case: resolve`), or CI red, sends the work back: the work
  changes the pull request on the dev branch, or rebuts a finding on the pull request with its
  grounds, and the review runs again — a new round. The class each `Medium`+ row carries is
  information for the work, not a route.
- **No automatic rework cap.** Whether rework goes on is the operator's decision, made as the work
  proceeds; the review's round count is that decision's input. The review's `[review-autofix]`
  count and its cap of 7 belong to the full cycle and do not count this path's rounds.

## A criterion change

A criterion the work shows defective changes the way it changes for any attempt with no state
file: once the issue body is edited, `cycle-status.sh` reports `criterion-review` for the attempt,
its criterion review runs again on its dev branch and decides as any criterion review does, and its
new `[criterion-ready]` entry records the decisions ([`criterion-review.md`](criterion-review.md) >
*When and by whom*, *Authority*, *Confirmation*). Neither the work nor the coordinating session
changes a criterion otherwise. The work goes on from the new entry.

## The checks that bind it

The path's independent checks are three: the attempt's `[criterion-ready]` entry for the current
issue body — its start, and the only way a criterion's content changes on it (*A criterion
change*); CI as it is (*End and rework*); and the aggregated review and its verdict.
The merge prohibition binds it as it binds every attempt: the hook denies `gh pr merge` whatever the
state, and merging is external. The gate score thresholds, the score-gated `git push` /
`gh pr create` gate and the auto-resolution attempt caps are the full cycle's; the path does not
carry them ([`core.md`](core.md) > Rule Scope, principle 1).

## How the attempt is reported and cleared

`cycle-status.sh --issue <N>` reads an attempt with no state file by its pull request
([U1 Preparation](units/preparation.md) > *What is asked*, *Modes*):

- its `pr:` line — in the checkout that owns the attempt, and with `--issue <N>` in any other;
- while the pull request is open, the entry `abbreviated <key>` on its checked-out dev branch; off
  it the attempt is no candidate, named `none-to-enter <key>:abbreviated` when no other attempt of
  the issue is to be entered. Nothing enters it: the full cycle does not start it, and a full cycle
  of the issue beside it is a new attempt, made only on the operator's request;
- once the pull request is merged or closed, a `cleanup:` line in the owning checkout, and the
  attempt is cleared like any other ([`git-workflow.md`](git-workflow.md) > Post-Merge Cleanup).
