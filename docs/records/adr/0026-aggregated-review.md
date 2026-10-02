# ADR-0026: The HANDOFF review is several reviews aggregated into one verdict

## Status

Accepted (operator decisions 2026-10-02, issue #411).

## Context

HANDOFF reviewed each pull request with one configured reviewer — `codex` by default, `claude` as
an opt-in — that read the diff and `.codex/review.md`, posted its own comment and set the
`blocked-by-review` label itself. The gate hook denied every `--remove-label blocked-by-review`
inside the Claude session, so that isolated subprocess was the label's sole clearer
(`docs/records/design-rationale.md` > Decision 9 — "The orchestrator never clears the label").

An operator-run comparison put a second review beside it on the same pull requests and heads: a
Claude review that also read the cycle's analysis, design, verification design, ledger and build
report (issue #411, *배경*).

- On 11 AutoFlow documentation PRs, the findings only one side raised and the operator adopted were
  29 for the design-referencing review and 1 for codex; rebutted findings were 0/30 against 3/5.
- On 10 connev-llm code PRs, reviewed retrospectively, the 7 not exposed to either review's output
  shared no finding: the design-referencing review found behavior defects and documentation-fact
  mismatches, codex found comment-rule violations. Over all 10, the `Medium` findings only the
  design-referencing review raised were 3, against 0–1 for codex.

Part of the difference is input, not model: the design-referencing review received the design
artifacts and not `.codex/review.md`, codex the reverse. Turning the existing `claude` backend on
beside codex would not reproduce it.

## Decision

**D1 — Reviewers.** Every pull request is reviewed by a built-in Claude review — an
`autoflow-reviewer` spawn that receives the pull request, `.codex/review.md` and the cycle's design
artifacts — and by each external reviewer the target configures (`.claude/autoflow.local.json` >
`.review.reviewers`; today `codex`, which receives the pull request and `.codex/review.md`). An
external reviewer is another vendor's model; the same model is not run twice under two settings,
so the `claude` backend (`claude -p` as an isolated subprocess) is removed. The earlier
`.review.backend: "codex"` reads as `["codex"]`; no configuration means the built-in review alone.

**D2 — Records, not comments.** A reviewer writes its review to a record under `.autoflow/`,
archived with the issue's other files. No reviewer posts to the pull request or changes a label,
codex included and outside HANDOFF as well; a review is posted only when the operator asks.

**D3 — Aggregation.** One aggregator per pull request and round — the HANDOFF analysis spawn —
reads every record and leaves one pull-request comment and the PR's findings file. Each
finding shows the reviewers that raised it, by name; a finding one reviewer raised is kept. A
finding the aggregator finds does not hold is rejected: it stays on the record with its grounds,
in a disposition column of the findings file and on the comment, and counts toward no verdict.

**D4 — Label.** The orchestrator puts `blocked-by-review` on the pull request when it runs a review
round, and the aggregator takes it off when the round is clean. The label is the review's signal to
the merge actor; AutoFlow's own routing reads the verdict in the findings file. The hook's deny of
`blocked-by-review` removal is deleted; the deny of `blocked-by-subrepo` removal stays, since
merge-order clearance remains the operator's.

**D5 — Unavailability.** An external reviewer whose CLI is absent, or whose run fails, does not
hold the round: the aggregation runs on the records that exist and names the missing reviewer.
PREFLIGHT reports an absent CLI without stopping; an unreadable review configuration still stops it.

**D6 — Every round, every PR.** Every round runs every reviewer on every pull request whose head
advanced. Models: the built-in review `opus` (`spawn-policy.json` key `handoff-review`), the
aggregator `sonnet` (key `handoff-review-triage`), codex `gpt-6-sol` as the resolver's default when
the target pins none.

## Alternatives Considered

- **The second review as advice only** — the configured reviewer keeps sole label authority and the
  second review's `Medium`+ findings only feed triage. Rejected: triage routes every `Medium`+
  finding in the findings file, so the second review would gate in effect while nothing verified its
  findings' resolution.
- **Both reviews as gates, each setting the label** — each reviewer keeps its own label step.
  Rejected: two reviewers acting on one label flap it by finishing order.
- **Each review posted as its own comment** — rejected for one comment per round carrying every
  finding with its source, which keeps a minority finding visible without two threads to reconcile.
- **The design-referencing review as an isolated `claude -p` subprocess** — rejected for the
  `Agent` spawn: the subprocess is sealed to `gh` and cannot read the `.autoflow/` design artifacts
  it exists to read.

## Consequences

### Positive

- A review that reads the design artifacts runs on every pull request, beside one that does not.
- One comment and one verdict per round; a finding's source and a rejected finding's grounds stay
  on the record.
- A third reviewer is a configuration entry plus its runtime.

### Negative

- The built-in review and the aggregator run inside the Claude session the orchestrator runs in, so
  the label is no longer set by a process outside it. What the gate rests on is the reviewers'
  records and the aggregator's recorded grounds, read after the fact.
- One built-in review costs about 10 minutes and 180k tokens per pull request and round (issue
  #411), on the same account allowance as the orchestrator.

### Neutral / Trade-Offs

- A finding a routed role later finds does not hold is posted as a rebuttal and judged by the next
  round's reviews and aggregation, not by the reviewer that raised it alone.

## Related Issues / PRs

- Issue #411 — this decision.
- Issue #979 — the backend-neutral reviewer this replaces.
- `docs/records/design-rationale.md` > Decision 9 — the label authority this supersedes in part.

## Notes

- Contracts: `docs/reviewer-backend.md`; `docs/units/delivery.md` > *Reviewer review*, *Review
  aggregation*.
