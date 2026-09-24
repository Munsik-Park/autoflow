# Evaluation System

> The AutoFlow evaluation system provides quantified quality assessment at the
> three gates (`GATE:HYPOTHESIS`, `GATE:PLAN`, `GATE:QUALITY`) and at `AUDIT`.
>
> **상세 기준은** [`role-contracts.md`](role-contracts.md) > Evaluation System **을 참조한다.**

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before
it reaches human review. The agent that wrote the work never evaluates it.

### Critical Rule: Fresh Spawn Every Time

The Evaluation AI must be **spawned fresh for every evaluation** — at
GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY. It carries no prior
conversation history. This is mandatory.

---

## 10-Point Scale

| Score | Meaning | Action |
|-------|---------|--------|
| 9-10  | Excellent | Proceed |
| 7-8   | Good      | Proceed |
| 5-6   | Insufficient | Rework recommended |
| 3-4   | Poor      | Rework required |
| 1-2   | Failing   | Redesign or human decision |

---

## PASS Criteria

A change passes evaluation when **all** of the following hold:

- **[MUST]** Average ≥ 7.5
- **[MUST]** Each item ≥ 7
- **[MUST]** Security ≤ 3 → automatic rework

If any condition fails, the change fails.

---

## Evaluation Types

| Type | Items (count) | Retry |
|------|---------------|-------|
| Structure evaluation (GATE:HYPOTHESIS — structure form, runs in DIAGNOSE 3-Phase) | Behavior gap, Code-change necessity (2) | none — PASS/FAIL single verdict; reuse-neutral 2-item necessity gate. FAIL on gap-low (already satisfied) → review-response: reply + active:false (awaiting-external-review, no close); new-issue: auto-closed + terminated. FAIL on Code-change-necessity-low (non-code lever) → report to user + pause. No retry loop. (Canonical: [`phases/analysis.md`](phases/analysis.md)) |
| Hypothesis evaluation (GATE:HYPOTHESIS — cause form, bug/incident only) | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× → DIAGNOSE |
| Plan evaluation (GATE:PLAN) | Feasibility, Scope, Security, Test plan (4) — affected files and side effects are derived at RED/GREEN entry by the execution roles, not predicted and scored here. Feasibility/Scope absorb the structural-fit & over-engineering concern the DIAGNOSE structure gate does not score — over-engineering is scored symmetrically across the plan and its verification design, so an unjustified verification layer fails Scope — and carry the embedded ADR-conformance check (divergence from a governing ADR, or an architecture-impacting change with no governing ADR/owner decision, caps the named item at 6; N/A by default) and the embedded AC-authority check (a verification-design difference against the issue's acceptance-criteria table that no `[ac-decision]` ledger entry covers caps Scope at 6); the interpretive paragraph and both checks are at [`phases/gate-plan.md`](phases/gate-plan.md). Re-entry re-scores the decision document's delta section plus every inherited item whose anchor it touched, reported in `rescore` | max 3× → ARCHITECT |
| Security audit (AUDIT) | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation (GATE:QUALITY) | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) — Test coverage's subject is the recorded local run for each `cycle` row and the committed asset for each `standing` row, never a CI result; Test quality carries the layer-violation check (a committed asset on a `cycle` row, an uncommitted one on a `standing` row, or a `standing:` token outside ADR-0024 D1's closed list caps it at 6); Fit also carries the embedded ADR-conformance regression re-confirmation (caps Fit at 6; same trigger as GATE:PLAN), and Completeness carries the embedded AC-authority check for post-ARCHITECT drift (a carried verification-design row for which no test assertion or implementation site can be named, and which no `[ac-decision]` ledger entry covers, caps Completeness at 6) | max 3× → re-entry by `remedy_class` (doc commit / RED / GREEN / ARCHITECT; `operator` → pause) |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

The category sets and weights should be customised per project. As patterns
emerge, humans adjust the criteria.

---

## Evaluation Output Format

```json
{
  "type": "hypothesis_evaluation | plan_evaluation | security_audit | quality_evaluation | doc_evaluation",
  "target": "scope name",
  "issue": "#N",
  "fail_hypothesis": {
    "case": "strongest rubric-framed reason this deliverable should FAIL",
    "disposition": "refuted | survived | none_found",
    "reflected_in": ["rubric item name"]
  },
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "remedy_class": { "<failed item>": "doc | test | impl | design | operator" },
  "rescore": {
    "source": "<prior report path>", "rescored": ["item"], "inherited": ["item"],
    "prior_findings": [ { "item": "item", "finding": "<the prior report's finding>", "status": "cleared | remains", "ground": "<path:line at <commit SHA> / command + log path + summary line>" } ],
    "new_findings": [ { "item": "item", "finding": "<defect newly seen on a re-scored item>", "disposition": "blocking — scored under <item> | recommendation", "ground": "<why it blocks, or why it does not>" } ]
  },
  "refine_observations": [ { "entry": "<suggestion @ path:line at <commit SHA>>", "disposition": "defect — scored under <item> | not a defect — <reason>" } ],
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": [ { "subject": "<evaluated artifact path:line at <commit SHA> | evaluated artifact section | AC id, for a criterion defect>", "item": "<rubric item>", "severity": "Critical | High | Medium | Low | Low Confidence", "finding": "<the finding>", "remedy_class": "<doc | test | impl | design | operator — on Medium and above>" } ]
}
```

The `scores` object is what the gate hook reads. Each item is either a number
(`8`) or an object (`{"score": 8, "reason": "..."}`). The hook accepts both.

`fail_hypothesis` records the pre-scoring consider-the-opposite search required by
[`role-contracts.md`](role-contracts.md) > Evaluation AI > Pre-scoring FAIL
hypothesis. It is narrative/audit material: nothing reads it programmatically and no
gate consumes it. It is placed before `scores`.

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `case` | string, non-empty | always | The strongest FAIL argument found. With `disposition: "none_found"` it states **what was searched** (which items, which anchors re-derived). |
| `disposition` | enum `refuted` \| `survived` \| `none_found` | always | Outcome of the refutation attempt. |
| `reflected_in` | array of rubric item names | always present (`[]` when `disposition != "survived"`) | Which scored item(s) recorded the surviving case — the join between the narrative record and the numeric `scores`. "Recorded" does not imply "scored down": an item listed here may still score ≥ 7. |

`remedy_class` (GATE:QUALITY only) maps **each failed item** (score < 7) to the kind of change that
clears it; the orchestrator routes the FAIL's re-entry from it ([`phases/gate-quality.md`](phases/gate-quality.md)
> FAIL routing). It is report material the orchestrator acts on; the hook does not
read it from the report (it reads the routed class the orchestrator records in state).

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `remedy_class` | object, one entry per failed item | **on every FAIL** (`{}` on a PASS) | Value enum `doc` \| `test` \| `impl` \| `design` \| `operator`. A failed item with no entry is a contract violation — reject + re-spawn, as for a missing `fail_hypothesis`. `operator` means "not classifiable with confidence" and pauses the cycle for the operator. |
| `rescore` | object | **on a re-entry evaluation** — after a FAIL's re-entry, or after a recommendation attempt or rebuttal ([`phases/gate-quality.md`](phases/gate-quality.md) > *Recommendation triage*; [`phases/handoff.md`](phases/handoff.md) > step 6.5 > *Whether a finding holds*) (absent on a first evaluation) | `source` — the prior report's path; `rescored` — the items scored afresh (the failed items — after a recommendation fix or rebuttal, the items the routed or rebutted recommendations were listed under — plus any inherited item whose anchor the re-entry touched — the re-entry diff at GATE:QUALITY / AUDIT, the decision document's delta section at GATE:PLAN, the amended DIAGNOSE artifact at GATE:HYPOTHESIS); `inherited` — the items whose score is copied from `source`. Every rubric item appears in exactly one of the two lists. `prior_findings` — one entry per finding the prior report recorded on a re-scored item, with `status` `cleared` or `remains` and the ground re-derived from the re-entry diff — for a rebutted finding, from the rebuttal's grounds at the evaluated commit (the re-score's FAIL hypothesis is "the flagged defect still remains", [`role-contracts.md`](role-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis > *Re-entry form*); a prior finding with no entry is a report defect — reject + re-spawn, as for a missing `fail_hypothesis`. `new_findings` — one entry per defect newly seen on a re-scored item (`[]` when none), each with the evaluator's `disposition` — `blocking — scored under <item>`, or `recommendation` (also listed in `recommendations`, and the item's score is not lowered for it) — and its ground. Both lists are report material the orchestrator reads; the hook reads neither. |

`refine_observations` (GATE:QUALITY only) records the evaluator's disposition of every
entry in the REFINE report's `## Out-of-scope observations — guard / boundary logic touched`
section. Always present on a GATE:QUALITY report (`[]` when the section says `none`); a report that
omits it or leaves an entry undispositioned is rejected and re-spawned. `rescore` is also the field
a review-response AUDIT uses for its narrowed re-score ([`phases/audit.md`](phases/audit.md)).

`recommendations` lists every non-blocking finding as an object: `subject` — a `path:line` of the
evaluated artifact at the evaluated commit, or a section of the evaluated artifact — the design
documents at GATE:PLAN, the DIAGNOSE analysis files (`.autoflow/issue-{N}-phase-*.md`) at
GATE:HYPOTHESIS, the change set at AUDIT / GATE:QUALITY — or, for an acceptance criterion the evaluator
observes defective as a matter of fact ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion
decisions*), the criterion's row in `.autoflow/issue-{N}-phase-b.md` > `## Acceptance criteria`, whose
`remedy_class` on `Medium`+ is `operator`; `item` — the rubric item it was found under;
`severity` — the reviewer's vocabulary (`Critical` / `High` / `Medium` / `Low`, or `Low Confidence`
for a finding the evaluator could not confirm); `finding`; and, on `Medium` and above,
`remedy_class` from the same enum as the failed-item field, by the same classifying question HANDOFF
step 6.5 asks of a reviewer finding. After the PASS of any rubric-scored gate the orchestrator
triages the list ([`phases/gate-quality.md`](phases/gate-quality.md) > *Recommendation
triage*). The hook reads none of the list; it reads the routed class the
orchestrator records in state while an attempt is open. A `Medium`+ item with no `remedy_class`, or
any item missing a field, is a contract violation — reject + re-spawn, as for a missing
`fail_hypothesis`.

A suite verdict the evaluator re-derives is the recorded local run — its summary line read in the
log the run left, the command re-run only when that log is absent (the row is then `not-run`).

---

## Hook Trust Boundary

`check-autoflow-gate.sh` does **not** read the AI's `pass`, `avg`, or `min`
fields. It computes them from raw `scores`.

---

## State File Linkage

While AutoFlow is in progress, `.autoflow/issue-{N}.json` records the score
sets per phase. The hook reads from this file at gate points to allow or block
Agent spawns and `git push`/`gh pr create` actions.

The phase keys recorded in the state file are below. The hook **gates** only the
four cause/plan/audit/quality keys; `gate_hypothesis_structure` is recorded in
state but **not gated** by the hook (DIAGNOSE 3-Phase structure evaluation —
orchestrator-judged against the CLAUDE.md thresholds, not enforced at a hook gate
point), matching the `gated_phase_keys` allow-list in
`tests/fixtures/gate-schema.json`, which omits it:

- `gate_hypothesis_structure` — DIAGNOSE 3-Phase structure evaluation (recorded in state, **not gated** by the hook — orchestrator-judged)
- `gate_hypothesis_cause` — GATE:HYPOTHESIS cause analysis (hook-gated)
- `gate_plan` — GATE:PLAN (hook-gated)
- `audit` — AUDIT (hook-gated)
- `gate_quality` — GATE:QUALITY (hook-gated)

- **[MUST]** When an evaluation's `fail_hypothesis` is recorded in state, it is written at `phases.<phase_key>.fail_hypothesis` — a sibling of `evaluator` and `scores` inside the phase object. **[DENY]** Never at the state file's top level and never as an entry inside `scores`. Recording is permitted, not required.

See [`CLAUDE.md`](../CLAUDE.md#autoflow-state-tracking-hook-integration) for the
full schema.
