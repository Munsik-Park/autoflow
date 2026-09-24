# GATE:PLAN — Plan Evaluation

> Phase playbook for GATE:PLAN. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: the architecture decision document + verification design from ARCHITECT, the issue's
acceptance-criterion list (`.autoflow/issue-{N}-phase-b.md` > `## Acceptance criteria`), and the
issue decision ledger (`.autoflow/issue-{N}-ledger.md`).

## Scoring (4 items × 10 points)

| Item | Criterion |
|------|-----------|
| Feasibility   | Can this plan be implemented with the current structure? (grounded in the actual mechanisms, not a misread) |
| Scope         | Appropriate — not too broad, not missing requirements? (no redundant new mechanism where an extension suffices — over-engineering fails here; the feature design's `## Scope` section judges each problem the confirmed cause carries under Change Surface Rules > *Scope judgment*, and a directly related problem left out owes a separation reason) |
| Security      | Any security implications introduced? |
| Test plan     | Are acceptance criteria testable? — and does each verification-design row verify the property the AC it names states, not a weaker or different proposition? — and does each `manual` row executed by a person, and each row resolved to a mock, state in its `Reason` why the `## Tools` section secured no tool for it? |

**Affected files and side effects are not scored here**. The gate scores the
*decision* layer; which files a change touches and which tests it requires are **derived**, not
predicted — by the execution roles at RED/GREEN entry, from the change delta and the way the
target runs its tests, and from the files they open anyway. A dependency miss surfaces at RED,
VERIFY step 1 or HANDOFF's CI and routes by the class rules, consuming no ARCHITECT re-entry.

`Feasibility` and `Scope` absorb the structural-fit concern that the DIAGNOSE structure gate deliberately does not score: a plan not grounded in the actual structure fails Feasibility; a plan **or its verification design** that duplicates an existing mechanism or over-engineers a new one where an extension suffices fails Scope — the over-engineering half applies symmetrically to both, so a verification that carries no unique failure mode fails Scope on the same clause. On a row that owes the `Failure mode` cell ([ARCHITECT](architect.md) > Output artifacts, the column's bullet), the cell fails Scope when it is empty — `—` on such a row counts as empty — or when it cannot be told apart from the cell of another distinct verification anywhere in the design, or from a named existing mechanism; rows that share a `Method` label are one verification and are not compared with each other. The deduction rides this clause and adds no scored item, cap or `scores` key.

## ADR-conformance check (scored within Feasibility / Scope)

This named check makes the ADR-conformance concern explicit inside the two items that already absorb structural fit — it adds **no scored item** and changes **no PASS threshold**; a violation caps the named item at 6, failing via the each-item ≥ 7 rule (identical mechanism to the [GATE:QUALITY](gate-quality.md) "Known blind-spot checks"). A **governing ADR** for the change surface is an ADR in the repository's ADR directory (`docs/records/adr/` in this repository; a consuming target's own ADR location) with status `Accepted`/`Proposed` whose Decision scope intersects the change surface, **or** a change hitting a **trigger area** of `docs/development-guideline.md` > ADR Policy > *When to create an ADR* — the list is defined there, in a shipped usage document, and nowhere else.

- **Trigger → cap**: divergence from a governing ADR, **or** an architecture-impacting change with no governing ADR/owner decision → cap.
- **Per-item cap distribution**: `Feasibility` caps on a structural-grounding divergence (the plan is not grounded in the ADR's decided structure); `Scope` caps on a redundant-mechanism / boundary divergence **or** the undocumented-ADR trigger; **both** cap when both defects are present. One divergence never leaves both items uncapped.
- **N/A by default**: no governing ADR's Decision scope intersects **and** no trigger area is hit → the check does not apply, no cap, the item scores normally.

## AC-authority check (scored within Scope)

Same mechanism as the ADR-conformance check above: **no added scored item, no threshold change**; a
violation caps `Scope` at 6, which fails the gate through the each-item ≥ 7 rule.

- **The comparison** is a key join, both sides keyed: every `AC id` in the issue's
  `## Acceptance criteria` table against the `Issue AC` column of the verification design's
  acceptance-criteria table. A **difference** is one of exactly two states: the design carries no row for the criterion
  (`dropped`); or it carries the
  criterion with a disposition other than `automated` and states no reason (`unreasoned`). A row
  whose proposition differs from the issue's is **not** a difference here — that is a semantic
  reading, scored under `Test plan`. A reduced disposition **with**
  a stated reason is not a difference — it is a verification-method choice the deliberation is
  authorized to make ([ARCHITECT](architect.md) > *Report routing*), and its **reason quality** is
  scored by `Scope` under the existing verification-depth clause ([ARCHITECT](architect.md) > *Verification depth*), adding no scored item.
- **Trigger → cap**: any difference **not** covered by a `[ac-decision]`-marked ledger entry whose
  `- AC:` line names that same id caps `Scope` at 6. The marker is what the gate matches on;
  `operator decision` is that entry's authority **value** and is not itself the match key. An entry
  whose `- Disposition:` is `added` covers nothing: the criterion it adds is owed its row like any
  other ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*).
- **An unresolvable check also caps.** An absent, empty or unparseable `## Acceptance criteria`
  table caps `Scope` at 6.
- **N/A by default** applies only to the difference set, never to the source: no difference and a
  readable AC table → no cap, the item scores normally.

- **PASS** (avg ≥ 7.5, each ≥ 7) → recommendation triage ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*)
  → DISPATCH.
- **FAIL** → ARCHITECT (max 3×).

## Re-entry re-score

A re-deliberation's re-score is a **fresh spawn with a narrowed input**, on the same rule
GATE:QUALITY's re-entry re-score states. The evaluator reads the decision document's **delta section** for this round ([ARCHITECT](architect.md) > *Record*)
plus every previously-passing item whose anchor the delta touched, and re-scores exactly those; the
remaining items inherit their prior score by citation. The report states the re-scored item list
and the inheritance source (the prior report's path) in its `rescore` field
([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format). The state file still
receives all four scores, inherited ones copied
verbatim from the cited report. An inherited item whose anchor the delta touched and which is
missing from the re-scored list is a report defect: reject and re-spawn.

A first evaluation of a cycle (no prior report to inherit from) scores the whole decision document;
the narrowing binds re-entries only.
