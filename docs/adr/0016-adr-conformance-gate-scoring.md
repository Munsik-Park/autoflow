# ADR-0016: ADR-conformance scoring at ARCHITECT / GATE:PLAN / GATE:QUALITY

## Status

Accepted

Owner approval: 2026-07-08 (operator, PR #960 merge + session instruction)

## Context

`docs/development-guideline.md:41-47` §4 ADR Policy requires that
"Architecture-impacting changes require an ADR or a documented owner decision
before merge." AutoFlow's gates, however, never inspect that conformance:
neither GATE:PLAN's five scored items (`docs/autoflow-guide.md:289-295`) nor
GATE:QUALITY's ten items (`docs/autoflow-guide.md:474`) name ADR conformance,
and the hook (`.claude/hooks/check-autoflow-gate.sh:284-311`) computes only
average / minimum / security over whatever `scores` keys exist. A plan that
diverges from a governing ADR — or an architecture-impacting change made with
no governing ADR at all — therefore passes both gates without any evaluator
being told to check the decided architecture. GATE:HYPOTHESIS structure scored
this gap PASS (8/7/8, `.autoflow/issue-818.json`) and DIAGNOSE Phase 3 scored
its necessity PASS (8/7/8, avg 7.67).

This is a self-referential change to AutoFlow's own gate policy — an area
`docs/adr/README.md:22` ("Agent workflow gates, evaluation policy, or merge
authority") names as an ADR trigger — so the decision is recorded as an ADR
rather than an inline rubric edit. The deliverable of this cycle is the
decision only; the rubric-prose wiring is split to a follow-up implementation
issue (see `#### Follow-up scope`).

### Case collection

Search for concrete ADR-divergence incidents beyond the structural gap, to
test whether the decision rests on observed failures or on the structural gap
alone:

- **Scope**: repository history and the issue tracker.
- **Query**: `git log --all --grep=ADR -i` (commit history) and
  `gh issue list` (open + closed issues).
- **Result count**: **0** divergence incidents. `git log --all --grep=ADR -i`
  surfaces only normal ADR-*creation* work (0008/0009/0014/0015 and similar);
  no commit records a plan or change that contradicted a governing ADR.
  `gh issue list` shows no prior issue on ADR-conformance gating — only #818
  itself. The single prior mention is one 2026-06-29 work-note (Phase B §1
  item 6), which flags the gap prospectively, not a realized incident.
- **Go / no-go**: **go, on the structural gap alone.** Per AC-5, a count of 0
  means the decision proceeds on the structural policy gap
  (`development-guideline.md:41-47` unenforced by any gate) rather than on an
  incident record. Because the empirical base is weak, the ADR is set
  `Proposed` (not `Accepted`) so the owner confirms before the follow-up
  implements the rubric wiring.

## Decision

Decision: adopt

Introduce ADR-conformance checking at the design-and-evaluation surfaces as an
explicit **named check inside existing rubric items and the existing ARCHITECT
devil's-advocate axis** — **not** as new scored rubric items.

### Rationale

Each link of the reasoning is grounded in a repository anchor:

- **The gap is real and policy-backed.** `development-guideline.md:41-47`
  mandates an ADR or documented owner decision for architecture-impacting
  changes, yet no gate rubric names ADR conformance and the hook never
  inspects it (`check-autoflow-gate.sh:284-311`). The enforcement surface for
  a written policy is simply absent.
- **Implicit absorption is the wrong shape.** Leaving ADR conformance to be
  *implicitly* covered by the existing `Feasibility` / `Scope` items reproduces
  the exact failure the #287 revert precedent records (`CLAUDE.md` > Spawn
  Model): a Sonnet PASS on `Feasibility` / `Scope`, where an existing item was
  *implicitly* expected to absorb the concern, was contradicted by a same-cycle
  Codex Medium finding the rubric was meant to cover. An implicit expectation
  is not a check. The evaluator must be *told* to run the check and told what
  caps the score.
- **But "explicit" does not require a new scored item.** The codebase already
  has the precise pattern for making a specific checkable concern explicit
  without adding an item: GATE:QUALITY's "Known blind-spot checks (scored
  within existing items)" (`autoflow-guide.md:479-500`) — three named checks
  (mock-boundary fidelity, assertion-claim alignment, reference integrity on
  moves), each of which caps a named existing item at 6 on violation while
  adding no scored items and changing no PASS threshold. ADR conformance is the
  same species of concern and takes the same mechanism.
- **This answers both of the issue's named risks.** Risk 1 (a new item forcing
  a recalculation of the `avg ≥ 7.5` / `each ≥ 7` denominators) is eliminated
  because no item is added. The over-engineering objection is avoided because
  the issue's Recommended Direction #3 already frames ADR conformance as the
  *명시화* of an existing approach-check axis, not a new axis
  (`autoflow-guide.md:292` casts the ARCHITECT devil's-advocate as the "first
  approach check") — the blind-spot pattern is the GATE-side analogue of that
  same "extend, don't add" stance.

### Placement

The check is placed at three surfaces in primary → regression order (mirroring
the issue's Recommended Direction #1/#2: GATE:PLAN as the 1차 차단점,
GATE:QUALITY as the 회귀-방지 재확인):

| Surface | Form | Trigger / cap |
|---|---|---|
| **ARCHITECT** (1st, non-scored) | Explicit axis of the existing devil's-advocate "first approach check" (facilitator contract + Discussion Protocol) | Before mutual ACCEPT, one exchange must verify the resolution conforms to any governing ADR; a divergence is a COUNTER, not an ACCEPT. No score. |
| **GATE:PLAN** (2nd, primary gate) | Named check inside **Feasibility** and **Scope** | Divergence from a governing Accepted/Proposed ADR, **or** an architecture-impacting change with no governing ADR / owner decision → caps the named item at 6 (fails via the each-item ≥ 7 rule). Cheapest block point, before implementation. |
| **GATE:QUALITY** (3rd, regression) | Named check inside **Fit** | Same trigger, re-confirmed on the final change set; caps **Fit** at 6. Regression backstop only (FAIL → RED, max 3× is expensive), consistent with the existing blind-spot checks' role. |

**Per-item cap distribution for the two-item GATE:PLAN check.** When the
GATE:PLAN check names two items, the cap lands on:

- **Feasibility** — when the plan is not grounded in the governing ADR's
  decided structure (a structural-grounding divergence);
- **Scope** — when the plan duplicates or contradicts a decided-architecture
  boundary (a redundant-mechanism / boundary divergence), **or** on the
  undocumented-ADR trigger (an architecture-impacting change with no governing
  ADR / owner decision — a scope-completeness gap);
- **both** — when both defects are present.

One divergence never leaves both items uncapped.

The ARCHITECT axis is first because injection without a consensus criterion is
skippable: `autoflow-guide.md:245` permits `docs/adr/*` injection at ARCHITECT,
but the mutual-ACCEPT criterion (`autoflow-guide.md:274-276`) does not name
conformance. Making it an explicit axis closes that specific hole.

### Item form

The form at both scored surfaces is a blind-spot-style **embedded check that
caps the named item at 6** on violation — it is explicitly
**not a new scored item**. No `scores` key is added; the cap is recorded in the existing item's
`{ score, reason }` entry, exactly as the three existing blind-spot checks do
(`autoflow-guide.md:479-500`). Because no item is added, the each-item ≥ 7
rule turns a capped-at-6 item into a gate FAIL through the pre-existing
threshold — no new arithmetic, no new denominator.

### N/A convention

A **governing ADR** for a change surface is an ADR in `docs/adr/` with status
`Accepted` or `Proposed` whose Decision scope intersects the change surface,
**or** a change that hits one of the `docs/adr/README.md:16-23` "When to Create
an ADR" trigger areas (host/submodule boundary, deployment/CI-CD authority,
tenant isolation / accounting / file-visibility / access-control, secret/config
management, agent workflow gates / evaluation policy / merge authority,
external service dependencies).

The check has three outcomes:

- **Conforms** — a governing ADR exists and the resolution aligns with its
  Decision → the item scores on its normal criteria, **no cap**.
- **Diverges / undocumented** — a governing ADR exists and the resolution
  contradicts it, **or** the change hits a trigger area with no governing ADR
  or documented owner decision → **cap at 6**.
- **N/A** — no Accepted/Proposed ADR's Decision scope intersects the change
  surface **and** the change hits no trigger area → the check does not apply,
  **no cap**, the item scores normally.

**N/A is the default** for a change touching no ADR-decision surface — the
common everyday issue. This bounds Risk 2 (over-FAIL on routine issues): the
cap fires only on a *positively identified* governing ADR or trigger area, the
same evidentiary discipline the existing blind-spot checks use (they cap only
on a *found* mock divergence / weaker assertion / dangling reference, never on
the mere absence of proof).

## Alternatives Considered

- **New scored rubric item ("ADR conformance", 1–10) at GATE:PLAN and
  GATE:QUALITY** — rejected. Adding an item enlarges the averaging denominator:
  GATE:PLAN would score 6 items and GATE:QUALITY 11, so `avg = sum / N` would
  divide over N+1 items and the `avg ≥ 7.5` threshold would need to be
  re-reasoned against the new item count. This is the item-count → average
  recalculation risk the issue names as Risk 1. It also adds a distinct axis
  where Recommended Direction #3 asks only to make an existing approach-check
  explicit — depth creep where the blind-spot extension already suffices. (Note
  that even this rejected form would need no hook edit — the hook is
  item-count-agnostic; the objection is the threshold re-reasoning and the
  scope creep, not a hook change.)
- **Implicit absorption into `Feasibility` / `Scope` with no named check** —
  rejected. This is the #287 failure mode (`CLAUDE.md` > Spawn Model): a PASS on
  an item that was only *implicitly* expected to cover the concern, contradicted
  by a same-cycle finding the rubric should have caught. An implicit expectation
  is not enforceable and not auditable.
- **A new hook gate that parses ADRs mechanically** — rejected. ADR conformance
  is a judgment (does this plan align with a decided architecture?), not a
  scriptable predicate; forcing it into the hook would be both infeasible and a
  merge-authority expansion beyond the gate's computed-score contract.

## Consequences

### Positive

- The written ADR Policy (`development-guideline.md:41-47`) gains an enforcement
  surface at the cheapest block point (GATE:PLAN, pre-implementation) with a
  regression backstop (GATE:QUALITY).
- The mechanism reuses an established, already-audited pattern (blind-spot
  checks), so evaluators need no new scoring model.

### Negative

- The check adds evaluator judgment load at two gates and one deliberation
  surface. The N/A default keeps that load near zero for routine issues, but a
  mis-scoped N/A call could let a real divergence pass — mitigated by the
  ARCHITECT-first placement and the GATE:QUALITY regression re-confirmation.

### Neutral / Trade-Offs

#### Threshold & hook cascade

The chosen cap-inside-existing-item form is a no-op for the hook and the
thresholds — verified, not asserted:

- **No new `scores` key.** The cap is written into the existing item's
  `{ score, reason }` entry; no `phases.*` key and no `scores` key is added to
  any state object.
- **No hook edit.** `check_scores` (`check-autoflow-gate.sh:284-311`) computes
  `avg` via `add / length` over `(to_entries | map(.value.score))` — it is
  item-count-agnostic — and reads the security value by key name
  (`.["security"] // .["보안"]`), not by position. Adding no key leaves that
  computation untouched.
- **No threshold recompute.** No item added ⇒ the `avg ≥ 7.5` / `each ≥ 7`
  denominators are unchanged. A capped-at-6 item produces a FAIL through the
  pre-existing `$min < 7` branch, exactly as the three existing blind-spot
  checks do (`autoflow-guide.md:486-487`).

The state schema (`.autoflow/issue-{N}.json`) and the Evaluation AI contract
(fresh-spawn evaluator, 10-point scale, output format) are likewise unchanged;
only the scoring-criteria prose for the named items gains the check, and that
edit is a follow-up (below).

#### DIAGNOSE consistency

This decision does not contradict DIAGNOSE's `[DENY]` on injecting ADR-candidate
docs into the analysis roles (`docs/phases/analysis.md:126`, whitelist row at
`analysis.md:120`). That `[DENY]` is a bias-prevention rule for the Phase A/B/3
roles, which must judge the current-state gap without seeing
recommended-direction / ADR-priority wording. All three placements above sit
**strictly downstream of DIAGNOSE**, at or after ARCHITECT — the one surface
where `docs/adr/*` injection is *already* permitted (`autoflow-guide.md:245`).
The check therefore does not reintroduce ADR into DIAGNOSE; it **assigns the
verification responsibility that DIAGNOSE's exclusion deliberately defers**.

The responsibility boundary against DIAGNOSE intake-triage's *ADR-prerequisite*
filter (`analysis.md:20-23`) is also clean: intake triage asks "must a
*separate* ADR exist *first*?" (a sequencing question); this new check asks
"does the *resolution* conform to a governing ADR?" (a conformance question) —
disjoint questions at disjoint phases.

#### Follow-up scope

The rubric-prose wiring is deferred to a follow-up implementation issue and is
**not** touched in this cycle. That issue will:

- `docs/autoflow-guide.md` — add the ADR-conformance named check to the
  GATE:PLAN section (`Feasibility` / `Scope`, ~289-297) and to GATE:QUALITY's
  "Known blind-spot checks" list (`Fit`, 479-500); add the ADR-conformance axis
  to the ARCHITECT devil's-advocate description (~245, 274-276).
- `docs/evaluation-system.md` — restate the check under the GATE:PLAN /
  GATE:QUALITY rubric entries (67, 69), consistent with autoflow-guide.
- `docs/teammate-contracts.md` — Facilitator contract: name ADR conformance as
  a first-exchange devil's-advocate axis.
- **No hook change** (see `#### Threshold & hook cascade`).
- The executable cap-6 → FAIL guard (feed a `scores` object with one item = 6,
  assert the hook returns FAIL) exercises pre-existing hook behavior and only
  becomes meaningful once the rubric prose introduces the cap, so it too belongs
  to the follow-up, not this decision cycle.

## Related Issues / PRs

- Issue #818 — this decision.
- Follow-up implementation issue #961 (PR #962) — wires the check into rubric
  prose; see `#### Follow-up scope`.
- Precedent: `docs/autoflow-guide.md:479-500` (GATE:QUALITY blind-spot checks);
  `CLAUDE.md` > Spawn Model (#287 revert precedent).

## Notes

- Numbering: 0016 is the next free integer, contiguous after 0015.
- Policy anchor: `docs/development-guideline.md:41-47` §4 ADR Policy.
- The ADR was drafted `Proposed` because the empirical base is the structural
  gap alone (case collection = 0 incidents); it was promoted to `Accepted` on
  the owner's confirmation (see `## Status` for the approval record), gating
  the follow-up rubric-prose wiring.
