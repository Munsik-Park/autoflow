# ADR-0033: The review is its own unit, U7, run by script reviewers the operator file names

## Status

Accepted (operator decisions recorded in issue #485 > 운영자 결정, 범위, 설계 입력 추가
(2026-10-21) and #479에서 옮긴 내용 (2026-10-21); criteria settled by the attempt's criterion
review). Amends ADR-0025 D1 (the unit table) and D4 (where the external verification layer runs),
ADR-0026 D1 and D4 (the built-in review spawn and the `blocked-by-review` label), ADR-0028 D2, D4
and D5 (the target source, the default, the readout), and ADR-0032 D1 for U7's command.

## Context

The review ran inside U6 Delivery's HANDOFF: the reviewers, the aggregation, the triage and the end
of the cycle (`docs/units/delivery.md` at `bbe3b99`, *Reviewer review*, *Review triage*, *End*), and
U6's exit was "CI green, the aggregated review below Medium". ADR-0025 D4 classes the review as the
external verification layer; it ran inside the cycle's last unit all the same.

The reviewers were not one kind. The built-in review was an `autoflow-reviewer` spawn; `codex` was a
script; both read the one rule file `.codex/review.md`, and nothing let a reviewer, or a target, add
to it. The resolver rejected `claude` as a reviewer name and knew no name but `codex`.

The reviewers came from the target's `.claude/autoflow.local.json` `.review` before the operator's
`~/.autoflow/config.json` (ADR-0028), and the file the SessionStart hook creates holds
`"reviewers": []` — "external review off". On the opensre comparison run (issue #485 > 설계 입력
추가) that file was the operator's, the target had no `.review`, and the aggregated comment read
"reviewers: none". Review bots that a target runs on its own pull requests were never read.

Two labels carried state for the merge actor: `blocked-by-review`, put on by the orchestrator and
taken off by the aggregator, and `blocked-by-subrepo`, which the hook kept the AI from removing.
AutoFlow's own routing read neither — it reads the findings file — and both had to exist in every
target repository beforehand. In the llmroute run of 2026-10-20 the operator merged seven pull
requests in the order the session reported, with no label, without a problem.

## Decision

**D1 — U7 Review.** The review leaves U6. U6 Delivery is DELIVER, INTEGRATE and HANDOFF, HANDOFF
being PR creation and CI; its exit is every pull request open with CI green. U7 Review is the phase
REVIEW: the reviewers, the aggregation, the triage and the end — `active:false`,
`phase:"awaiting-external-review"`. The `Medium`+ routing by `remedy_class` and the auto-resolution
cap of 7 move to U7 unchanged; a route's fix is pushed and its CI confirmed as in U6. Its document is
`docs/units/review.md`.

**D2 — U7's command takes the issue number or nothing.** `/autoflow:cycle-u7 [<N>]` reads where the
cycle stands from the current state (`cycle-status.sh`, with `--issue <N>` when given, the
attempt's records, the pull requests) and runs U7 from there. It has no entry check that stops the
session; the order of units and which of them run is the orchestrator's, or the coordinating
session's. The other units' commands keep ADR-0032 D1.

**D3 — Every reviewer is a script.** Each reviewer has its own wrapper, `scripts/review/<name>-review-pr.sh`,
whose environment fits its CLI; no two reviewers share one. `claude` runs `claude -p` in the
reviewed repository's working directory with read-only tools and the `gh` reads the review needs,
every tool neither those nor the operator's own settings allow denied without a prompt, and the
reviewed repository's own settings not loaded; it reads the cycle's design artifacts in the
attempt's record directory the wrapper names; `codex` keeps its wrapper. The `autoflow-reviewer`
agent and its spawn-policy row are retired. The aggregation contract — the review records of a
pull request and round into one comment and one findings file (ADR-0026 D2, D3) — does not change
with the number or kind of reviewers. A review a system on the target's side runs on the pull
request by itself is a review of the round: the aggregator reads it from the pull request and names
its author as the source.

**D4 — A rule file per reviewer.** The rules every reviewer applies are
`docs/review/review.md` (formerly `.codex/review.md`); each reviewer's rule file,
`docs/review/review-<name>.md` beside it, names what that reviewer reads. Per reviewer, the
configuration may name another rule file (`.review.<name>.rules`) and a file of further review
lenses (`.review.<name>.lenses`) — the path by which the defect axes a reviewer applies are added
to. A relative path is read from the root of the checkout the wrapper runs in.

**D5 — The operator file alone names the reviewers, and names the defaults when it names none.**
A target's `.claude/autoflow.local.json` is not read for reviewers. `.review.reviewers` lists the
reviewers that run; absent, `null` or `[]`, the default reviewers — `claude` and `codex` — run, and
so do they when the file is absent. The hook's default content is unchanged. An unreadable operator
file keeps ADR-0028 D3: nothing in it applies, and the operator is asked.

**D6 — No label.** `blocked-by-review` and `blocked-by-subrepo` are retired, with the hook's deny on
removing `blocked-by-subrepo`. The end report names the order in which the cycle's pull requests
merge — a sub-repo pull request before the host pull request whose pointer depends on it, the host
reconciled to its merge commit in between. The merge prohibition is unchanged.

## Alternatives Considered

- **Keep HANDOFF as the review's phase and move PR creation and CI to DELIVER** — not taken: the
  operator's ground was that the review is separated from the hand-off, and U6 keeps HANDOFF's CI
  rows (retry, CI-failure re-entry) where they are.
- **One wrapper for every reviewer** — not taken: the CLIs differ in how they take a prompt, sandbox
  their tools and load instructions from the tree (issue #485 > #479에서 옮긴 내용).
- **Tell a hook-created `[]` from an operator's `[]`** — not taken: no operator choice of "no
  reviewer" is on record, and a review is an independent check that is never skipped.
- **Keep the labels as advisory signals** — not taken: AutoFlow's routing reads the findings file,
  and the labels asked every target repository for set-up the plugin cannot assume.

## Consequences

### Positive

- The review can run, and be re-run, as a session of its own on whatever stands, without an issue
  number.
- Every target gets reviewed by the same reviewers with no target set-up; a reviewer is added by a
  name, a wrapper and a rule file.

### Negative

- With no reviewer named, the `claude` review runs on the operator's Claude allowance once per pull
  request and round, as the built-in review did.
- A rule edit that every reviewer should apply goes into `docs/review/review.md`; one meant for a
  single reviewer goes into its own file, and the two can drift apart by intent.

### Neutral / Trade-Offs

- `docs/assets/render-lifecycle-svg.py` and its SVGs still draw the lifecycle as it was before
  ADR-0025's units; this decision does not redraw them.

## Related Issues / PRs

- #485, #479 (closed into #485), #483 (C1: the comment rule's home), #411 (ADR-0026), #463
  (ADR-0028), #464 (ADR-0032), #369 (ADR-0025).
