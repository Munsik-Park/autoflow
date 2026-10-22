# ADR-0036: The abbreviated path — criterion review, work outside a cycle, review — beside the full cycle

## Status

Accepted (operator decision 2026-10-22, issue #493 > 운영자 결정 2026-10-22, 정리 1–5; the
criteria settled by the attempt's criterion review, entry O4, with the advisor decisions A2 — the
path's end carries the pull request's CI result — and A3 — the review run alone returns it; the
operator decisions O5 and O6 — no automatic rework cap on the path, continuing is the operator's
call). Amends ADR-0030 D5 (`/autoflow:criterion-review` also enters the path) and ADR-0033 D1–D2
(U7 also runs alone on an attempt with no state file), and extends ADR-0030 D3 and ADR-0029 D4 (the
entry `abbreviated` and the pull request read for an attempt with no state file). ADR-0025 D3–D4
stand for the full cycle (*Relation to other decisions* below). D6 amended by ADR-0037 (issue
#500): the `cleanup:` line stands, naming an attempt that is not active and whose pull request is
merged or closed; what is done on it is the operator's practice, not Post-Merge Cleanup at PREFLIGHT.

## Context

The documents defined one way an attempt goes on after its criterion review: the full cycle, which
writes the attempt's state file at PREFLIGHT and reaches REVIEW through every unit and gate. A second
way had been run in practice — the criterion review alone, then work outside an AutoFlow cycle,
then the reviewers, then rework and review again until the pull request was clean — with no
document defining it. The operator decided that this second way is an official path beside the
full cycle, which stays as it is: criterion review → work (AutoFlow 없이, the coordinating session
directing the work session) → review → `Medium` 미만이면 종료 / `Medium` 이상이면 재작업 → 리뷰,
with the environment-dependent operation — launching and watching sessions, runbooks, round
materials — kept machine-local.

What the documents and devices assumed did not hold on that path:

- `/autoflow:criterion-review` was defined as the cycle's stage alone, "`/autoflow:cycle <N>` then
  continues that attempt's cycle" (ADR-0030 D5); U7 was defined as a cycle unit whose procedure
  writes the state file, routes a `Medium`+ finding to a BUILD unit or ARCHITECT and caps the
  auto-resolution at 7 `[review-autofix]` entries (ADR-0033 D1).
- `cycle-status.sh` looked up a pull request only for an attempt whose state file was not active.
  An attempt with no state file was reported `start` while its pull request was open — the entry a
  full cycle would start from, over that pull request — and got no `cleanup:` line once it was
  merged, so Post-Merge Cleanup never reached it.
- The core named the push gate and the gate score thresholds among the authority rules and among
  what is never skipped, without saying which path they bind (`docs/core.md` > Rule Scope,
  principle 1; > Execution Principles — "What is never skipped is an independent check").

## Decision

**D1 — The path has one home, a usage document; the core names the two paths and cites it.**
`docs/abbreviated-path.md` states what the path is (an attempt that, after its criterion review
recorded `[criterion-ready]` for the current body, goes on outside an AutoFlow cycle and never has a
state file), its composition, the work's one constraint, the review, the end condition and the
rework rule, what the coordinating session — the session that runs the path — reads and decides,
how a criterion changes on it, which independent checks bind it, how its attempt is reported and
cleared, and that launching and watching sessions, runbooks and round materials are not AutoFlow's.
`docs/core.md` > Development Lifecycle opens with one block naming the two paths, classified `U1 U7`
in `scripts/skills/core-units.tsv`; no carrier carries the new document whole — the coordinating
session starts with no AutoFlow carrier, and the sessions AutoFlow does start on the path carry the
part that binds them through the documents they already carry.

**D2 — The review run alone is U7 itself.** `docs/units/review.md` gains a section for an attempt
with no state file whose pull request is open, entered by `/autoflow:cycle-u7 <N>`: *Reviewer review*,
*Review aggregation* unchanged — every `Medium`+ row that holds tagged with its `remedy_class`, which
the unchanged `review-gate.sh` requires — with the earlier rounds named to the aggregator, and *The
case*, whose `case:` line is the verdict. No state file is created, read or required; the class
routes nothing (no `remedy-route.sh`, no BUILD unit, no ARCHITECT, no `[review-autofix]` entry); no
attempt cap. The review runs in a checkout of the same origin whose checked-out branch is the
attempt's dev branch at the pull request's head, which need not be the owning checkout. It returns
the pull request's URL and head commit, the verdict, the findings file and the comment, the CI
result as read and the round count.

**D3 — The rework count is the review round; no automatic cap; continuation is the operator's.**
The count returned is the pull request's review round `k`, which every review record's name already
carries, and the rework count `k − 1`. A `Medium`+ verdict or CI red sends the work back; whether
rework goes on is the operator's decision, the count its input.

**D4 — CI is read by the review and returned as it is; the end needs it green or its not running
recorded.** `confirm-ci-green.sh --pr <P>`: green, red, no check published (with whether the pull
request records that CI does not run for it), no verdict, not mergeable or inconclusive; nothing is
read as green. The path ends only when the verdict is below `Medium` and CI is green or its not
running is recorded on the pull request. On exit `11` the judgment "not running or late" and the
record are the coordinating session's, in the form `docs/units/delivery.md` > *CI* states.

**D5 — `/autoflow:criterion-review <N>` is the path's entry; the work runs on the attempt's dev
branch; a criterion changes by the attempt's own review.** A `READY` attempt goes on by
`/autoflow:cycle <N>` or on the path; the stage's behavior (attempt creation, records,
`[criterion-ready]`) is unchanged. The work's commits are on the attempt's dev branch and its pull
request is opened from it, since the record directory, the pull request lookup, `review-gate.sh`
and the cleanup key on that branch. A criterion found defective on the path changes by an issue
edit and the attempt's criterion review run again, with a new `[criterion-ready]` entry — the route
an attempt with no state file already has — not by an `[ac-decision]`, whose gate backstops do not
run there.

**D6 — `cycle-status.sh` reports an attempt with no state file by its pull request.** The pull
request lookup covers an attempt with no state file under the same ownership condition (this
checkout's attempts, and every attempt of the requested issue): its `pr:` line is printed, and a
merged or closed pull request of this checkout's attempt gives its `cleanup:` line. Its entry is
evaluated in order: merged or closed → cleared; `[criterion-ready]` not valid for the current body
→ `criterion-review`; `READY` with an open pull request → the new kind `abbreviated`; `READY` with
no pull request → `start`; a lookup that failed, or readiness that could not be read → unread. On the
checked-out branch the entry is `abbreviated <key>`; among this checkout's other attempts it is
named `none-to-enter <key>:abbreviated`. Nothing enters it. A gone owner's `claim:` line stays
beside it, as ADR-0030 D9 keeps the claim line unsuppressed: taking the attempt over makes this
checkout its owner, which is what its later `cleanup:` line needs.

**D7 — Which checks bind which path.** The full cycle keeps every check it has. The path's
independent checks are the attempt's `[criterion-ready]` entry for the current body, CI as it is
and the aggregated review and its verdict; the merge prohibition binds both, enforced by the hook
whatever the state, as do the hook's other state-independent denies — a push to the default branch
or the dev branch's base, `gh issue create`, the ledger's authorship check. The gate score
thresholds, the score-gated `git push` / `gh pr create` gate and the auto-resolution caps are the
full cycle's. Rule Scope principle 1 says each rule binds the path
that carries it, principle 3 names the gates for the full cycle, and the never-skipped list is the
full cycle's and cites the path's.

## Alternatives Considered

- **The definition as a section of `docs/core.md`, or split across the criterion review and U7
  documents.** The core holds what crosses a unit's boundary for the cycle and every whole-cycle
  body carries it; split, the end condition, the rework rule and the coordinating session's part
  have no single home.
- **A new command for the review alone, e.g. `/autoflow:review <N>`.** A second review definition
  and carrier for what U7's command already runs without an entry check (ADR-0033 D2); the review's
  exit would differ from U7's (A3).
- **A state file for the path's attempt (a mode such as `abbreviated`).** The criteria forbid
  creating or requiring one; with one, the hook would gate the path's push and pull request on
  scores it never earns, and `criterion-ready.sh` would read the attempt as started.
- **`[review-autofix]` entries on the path, counted by `review-gate.sh`.** That puts the path's
  rework under the 7-attempt cap the operator rejected (O6).
- **The aggregator leaves `remedy_class` empty on the path and `review-gate.sh` accepts it where no
  state file exists.** A state-dependent branch in a script that reads no state file, and a change
  to the findings-file contract the full cycle's routing reads.
- **A marker the coordinating session writes to flag the path.** A rule to keep for what the pull
  request already shows, and the pull request is looked up for the cleanup anyway.
- **Keep the entry `start` and leave the open pull request to the session.** `start` on an attempt
  with an open pull request is false on its premise — a dev branch with no commit of its own — and
  leads `/autoflow:cycle <N>` to write a state file over the path's pull request.
- **An open pull request before readiness in the entry order.** After a body edit the attempt would
  be `abbreviated`, and the criterion review — entered on `new` and `criterion-review` — would not
  re-run on it.
- **Bring a check onto the path**, e.g. the push gate keyed to `[criterion-ready]`. Not in the
  operator's composition, and it changes the hook the full cycle keeps as it is.

## Consequences

### Positive

- The path is defined where AutoFlow's rules are, with its end condition, rework rule and checks,
  and the full cycle's stages, gates and devices are unchanged: no hook, readiness check, review
  count or CI script, route, reviewer wrapper, records library, cleanup, rubric, U2–U6 document,
  state schema or spawn policy changes.
- An attempt on the path is no longer reported as a `start` over its pull request, and a merged one
  is offered to Post-Merge Cleanup.

### Negative

- A pull request lookup now also runs for an attempt with no state file, so a failed lookup for one
  is exit `3`; a `READY` attempt whose lookup failed is unread, never `start` — the full cycle's
  start now also rests on that read, as it already rested on the issue body's.

### Neutral / Trade-Offs

- An attempt whose path work has committed on its dev branch but opened no pull request yet is still
  reported `start`; whether such an attempt may still be taken into the full cycle needs a decision
  of its own and is not taken up here.
- Two pieces of work in one checkout — another issue's full cycle beside the path — stay outside
  this decision (operator decision O5 (3)).

## Relation to other decisions

- **ADR-0030 D3 (*Entries*)** — extended: the entry set gains `abbreviated <key>` and the kind
  `none-to-enter <key>:abbreviated`. The new kind is a printed fact the session judges, as D9 has
  it. A `READY` attempt with no state file whose pull request lookup failed is `stop unreadable
  <key>` on its checked-out branch — the entry `cycle-status.sh` prints for an attempt on that
  branch with a fact it could not read — and `none-to-enter <key>:unread` off it, with exit `3`.
  D9 lists `stop unreadable` among the verdicts its PR's earlier revisions removed; the script
  prints it as that entry, a fact under D9's rule that the session judges the way on.
- **ADR-0030 D5** — amended: `/autoflow:criterion-review <N>` also enters the abbreviated path;
  "`/autoflow:cycle <N>` then enters that attempt as `start`" holds for the full cycle.
- **ADR-0029 D4 (*Entry is a fact, printed*)** — extended: the pull request the entries are read
  from is looked up for an attempt with no state file too. D5's cleanup is unchanged and reaches a
  path attempt through its `cleanup:` line.
- **ADR-0033 D1–D2** — amended: U7 also runs alone on an attempt with no state file, without the
  state write, the routes or the cap; `/autoflow:cycle-u7 <N>` is its command, with no entry check.
- **ADR-0025 D3–D4** — unchanged for the full cycle. On the path no unit or gate runs: D4's external
  layer (CI and the reviewer) and the operator's oversight are its checks, and D3's merge
  prohibition holds.
- **ADR-0027 D2 and ADR-0032's amendments** — unchanged: the coordinating session's launching
  procedure stays machine-local; this decision defines what the path is, not how its sessions start.

## Related Issues / PRs

- Issue #493.

## Notes

- The path's definition is `docs/abbreviated-path.md`; the review run alone is
  `docs/units/review.md` > *An attempt with no state file*; the entry and the report are
  `docs/units/preparation.md` > *What is asked*, *Modes*.
