# ADR-0030: The criterion review is the first stage of an attempt's cycle, inside U1

## Status

Accepted (operator decisions 2026-10-18, issue #465 > 운영자 결정: the criterion review is a stage
of the AutoFlow cycle, not a separate operation, and its records belong to the attempt; operator
decision 2026-10-19: `/autoflow:criterion-review` is kept for a review by itself; operator decision
2026-10-19, PR #475: the script reports facts and the session judges the way on, and AutoFlow does
not consider compaction (D9); the criteria as
settled by the attempt's own criterion review, entry O1). Supersedes ADR-0029 D3 (the criterion
review creates the attempt) and, in D4, the `not-ready` and `new` entries and "`/autoflow:cycle
<N>` never creates an attempt (A6)". Its item 3's `unit=U1…U6` argument retired by ADR-0032 (issue #464): a unit session is
`/autoflow:cycle-u1` … `/autoflow:cycle-u6`. Amends ADR-0027 D2's command list: `/autoflow:cycle` takes
`new`, and `/autoflow:criterion-review <N>` runs the cycle's criterion review stage alone instead
of starting a review outside a cycle.

## Context

Up to 0.3.2 the criterion review (#430) was a procedure outside the cycle: the operator ran
`/autoflow:criterion-review <N>` in a session of its own, which created the attempt
(`autoflow-records new`) and recorded `[criterion-ready]` in the attempt's ledger, and
`/autoflow:cycle <N>` stopped on `entry: new` or `entry: not-ready` until it had. ADR-0029 (#466)
already moved every record, the criterion review's included, into the attempt's record directory
outside the checkout, so the record-location problems issue #465 first described are gone; what is
left is the separate command and session itself, and the rule that the cycle never creates an
attempt (issue #465 > 사전검토 반영).

The review fixed constraints the design has to meet (issue #465 AC1–AC6; the review record's
`## Cause reach and rule conflict`):

- PREFLIGHT's stops that come before an attempt is entered — in-tree records, another active attempt
  of the checkout (PR Wait Rule), a dirty tree, a failed fetch, an undetermined or unusable record
  root — are still reported, and no attempt is made, before the stage (RC1).
- `entry: new` meant "no candidate", not "no attempt": a paused attempt or one whose review was
  unfinished, not checked out, also gave `new` (RC2). Creating an attempt there would start a new
  attempt beside them with no request — what *Modes* forbids ("never a silent restart").
- Readiness counts the attempt's own record only (RC3), and the body-hash check stays (AC3).
- `criterion-ready.sh` reports an attempt with a state file `NOT READY`: the entry comes before the
  state file.

## Decision

**D1 — The stage is CRITERION-REVIEW, inside U1 Preparation.** It runs in PREFLIGHT after the entry
`cycle-status.sh` prints and the stops that precede it, and before the stop conditions and the
state file; its exit is the attempt's `[criterion-ready]` entry for the current issue body. It is
not a separate unit:

1. The order AC1 fixes — PREFLIGHT's stops, then the stage, then the rest of PREFLIGHT — places the
   stage inside PREFLIGHT's own sequence; a unit of its own would split PREFLIGHT across two units,
   each running part of the same checks.
2. U1 has no unit agent: PREFLIGHT is the orchestrator's own work, as the review's stage 1 is the
   session's own work, with its three spawns (ADR-0025 D1).
3. The six units of ADR-0025 D1, the `unit=U1…U6` argument, the core's unit table, the generator and
   the per-unit split #464 builds on stay as they are; only U1's row names the stage.
4. The name is the one the ledger heading `(cycle 0, CRITERION-REVIEW)` and the advisor procedure
   already carry (`docs/decision-ledger.md`, `docs/role-contracts.md` > Advisor).

**D2 — The cycle creates the attempt.** On `entry: new` the orchestrator runs `autoflow-records new
--issue <N>` before the stage writes anything — the record directory exists before any write — and
the stage reviews that attempt. The command and its refusals are unchanged (clean tree, no active
attempt of the checkout, fetch, remote-tracking ref, record root). The state file is still written
last, so the `[criterion-ready]` entry still precedes it and `criterion-ready.sh` keeps what it
counts: the attempt's own last entry, an `O` entry under `operator decision`, its record in the
attempt's directory, and the body hash.

**D3 — Entries.** `cycle-status.sh --issue <N>` prints, after its unchanged stops:

- `criterion-review <key>` in place of `not-ready` — the attempt's stage runs on it. An attempt of
  this checkout still in its stage, not checked out, is a candidate like one ready to `start` or
  with an open PR; its dev branch is checked out first.
- `none-to-enter <key>:<kind> …` when attempts of N are still here but none of those — paused, or
  with a fact that could not be read (exit `3`): each is named, none is entered by the entry.
- `new` only when no attempt of N is left in this checkout, or every one is cleared.

**D4 — A new attempt beside the ones still here is the operator's explicit request.** `/autoflow:cycle
<N> new` asks for it; the script takes no such argument and prints the same facts. This is the rule
the change keeps: it binds authority (Rule Scope, principle 1) — no new attempt is made without the
request while an attempt of N is still in the checkout.

**D5 — `/autoflow:criterion-review <N> [new]` runs the stage alone** (operator decision
2026-10-19). It is entered from the same facts — `new`, or the operator's `new` request, creates the
attempt, `criterion-review` enters the one named, otherwise the session reports — and ends at the `[criterion-ready]` entry with
no state file; `/autoflow:cycle <N>` then enters that attempt as `start`.

**D6 — The hook is unchanged in behavior.** While the stage runs, no state file of the attempt
exists, so the hook's Section 2 lets the call through as it did for a review outside the cycle, and
its ledger check admits the `O` entry from the main session only — the `/autoflow:cycle` session as
it did the review session.

**D7 — A stage in progress does not hold its checkout.** The PR Wait Rule's signal stays `active`
in the state file, which the stage does not have: another issue's `new` in the same checkout
switches the branch away, on a clean tree only, and the stage's records stay in its attempt
directory, from which `criterion-review` re-enters it later. Counting an attempt with no state file
as active would let an unfinished review left for good hold the checkout with nothing to clear. As
before this change, `autoflow-records new` refuses only beside an active state file.

**D8 — The session that settled the criteria also makes the first in-cycle judgment on a criterion
defect** (the review's RC4, left to the cycle). This is accepted. The authority rule places that
judgment with the orchestrator and does not require that it took no part in the review
(`docs/core.md` > Flow Control > *Any unit*; `docs/decision-ledger.md` > *A criterion can be
wrong*). What checks the criteria inside the cycle does not share the stage's context: DIAGNOSE is
an `autoflow-unit-analysis` spawn that reads the review record as "an input, not a verdict"
(`docs/units/analysis.md` > *Criterion review record*); each gate is a fresh evaluator; and the
advisor, where the orchestrator is not confident, is a fresh spawn
(`docs/role-contracts.md` > Advisor > *Independence*).

**D9 — The script reports facts; the way on is the session's judgment** (operator decision
2026-10-19, PR #475: "규칙이 규칙을 다시 만든 상황입니다 … 규칙으로 상태를 true, false라고 규정하면서
그것을 지키기 위한 코드와 그것이 유지되기 위한 코드를 계속 생성하고 있어요"). Whether a `new` in the
arguments is a request still to carry out or one the conversation already carried out, what to do with a fact that could not be read, with a `claim:`
line or with a dirty tree, is judged by the session and recorded with its grounds in the attempt's
ledger (Rule Scope, principle 2). Earlier revisions of this PR fixed them as script verdicts — a
`--new` flag with a "spent" rule, `stop unreadable`, `paused` / `stop paused`, `stop dirty-tree`
and a suppressed `claim:` line; each verdict needed a further rule for its own gap, and none binds
authority, so they are removed. The "spent" rule was put in for a re-invocation after a
compaction; AutoFlow requires idle compaction off and does not consider compaction — auto
compaction cannot be defended against — so no verdict, state or check is kept for it (operator
decision 2026-10-19; ADR-0031).

## Alternatives Considered

- **A separate unit (U0, or a renumbered U1)** — rejected on D1's grounds 1–3: it splits PREFLIGHT's
  checks and changes the unit set every document, the generator and #464 are built on, for a stage
  that has no unit agent of its own.
- **The state file written before the stage** — rejected: `criterion-ready.sh` and the hook read a
  state file as a cycle past PREFLIGHT (an attempt with one takes no `[criterion-ready]` entry, and
  the hook gates its spawns), so AC3's check and the stage's spawns would change with it.
- **Creating an attempt on every `new` of the old evaluation** — rejected (RC2): a paused or
  unfinished attempt not checked out also gave `new`.
- **The new-attempt request only through `/autoflow:criterion-review`** — rejected: the separate
  command would stay the only route to a new attempt, which AC1 and AC6 ask the cycle to take.
- **Removing `/autoflow:criterion-review`** — not taken: the operator kept it (2026-10-19).

## Consequences

### Positive

- One `/autoflow:cycle <N>` session takes an issue from its criterion review to its pull request; a
  unit session `unit=U1` does the same for U1.
- A paused attempt, an open PR or an unfinished review is never passed over by a new attempt without
  the operator's request.

### Negative

- The cycle session carries the review's stage 1 context into DIAGNOSE and on, and a session that
  ends inside the stage re-enters it from `criterion-review`.
- Two sessions in one checkout can switch a stage's branch away (D7); the stage resumes from its
  records.

### Neutral / Trade-Offs

- `cycle 0` still marks an entry written before the state file.
- The readiness check PREFLIGHT runs before the state file reads the stage's exit again; it is the
  same script, run twice on one attempt.

## Related Issues / PRs

- #465 (this decision), #430, #466 (ADR-0029), #464, #467.

## Notes

- The criterion review's content and method (#434, #439, #442, #445) and the authority over
  acceptance-criterion content are unchanged (issue #465 > 바뀌지 않는 것).
