# Evaluation System

> The AutoFlow evaluation system provides quantified quality assessment at the
> three gates (`GATE:HYPOTHESIS`, `GATE:PLAN`, `GATE:QUALITY`) and at `AUDIT`,
> ensuring consistent standards across all changes.
>
> **상세 기준은** [`teammate-contracts.md`](teammate-contracts.md) > Evaluation System **을 참조한다.** 본 문서는 평가 시스템의 설계 의도, 훅 신뢰 경계, 상태 파일 연동 등 운영 컨텍스트를 다룬다.

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before
it reaches human review. This separation keeps judgment objective — the agent
that wrote the work never evaluates it.

### Critical Rule: Fresh Spawn Every Time

The Evaluation AI must be **spawned fresh for every evaluation** — at
GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY. It carries no prior
conversation history. This is mandatory.

**Why**: when the same agent creates a plan and evaluates it, it struggles to
reject its own work. A freshly spawned agent sees only the deliverable — it has
no investment in the process. Bias elimination takes priority over token cost.
See [`design-rationale.md`](design-rationale.md#decision-2-evaluation-ai-is-spawned-fresh-every-time).

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

### Why these thresholds are strict

Lenient criteria create a pattern of "scoring high on easy items to raise the
average while passing weak items." The per-item minimum (≥ 7) prevents this
gaming. Security ≤ 3 triggers mandatory rework because security failures cannot
be diluted by averaging.

---

## Evaluation Types

| Type | Items (count) | Retry |
|------|---------------|-------|
| Structure evaluation (GATE:HYPOTHESIS — structure form, runs in DIAGNOSE 3-Phase) | Behavior gap, Code-change necessity (2) | none — PASS/FAIL single verdict; reuse-neutral 2-item necessity gate. FAIL on gap-low (already satisfied) → review-response: reply + active:false (awaiting-external-review, no close); new-issue: auto-closed + terminated. FAIL on Code-change-necessity-low (non-code lever) → report to user + pause. No retry loop. (Canonical: [`phases/analysis.md`](phases/analysis.md)) |
| Hypothesis evaluation (GATE:HYPOTHESIS — cause form, bug/incident only) | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× → DIAGNOSE |
| Plan evaluation (GATE:PLAN) | Feasibility, Dependencies, Scope, Security, Test plan (5) — Feasibility/Scope absorb the structural-fit & over-engineering concern the DIAGNOSE structure gate deliberately does not score — over-engineering is scored symmetrically across the plan and its verification design, so an unjustified verification layer fails Scope — and carry the embedded ADR-conformance check (divergence from a governing ADR, or an architecture-impacting change with no governing ADR/owner decision, caps the named item at 6; N/A by default) and the embedded AC-authority check (a verification-design difference against the issue's acceptance-criteria table that no `[ac-decision]` ledger entry covers caps Scope at 6) | max 3× → ARCHITECT |
| Security audit (AUDIT) | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation (GATE:QUALITY) | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) — Fit also carries the embedded ADR-conformance regression re-confirmation (caps Fit at 6; same trigger as GATE:PLAN), and Completeness carries the embedded AC-authority check for post-ARCHITECT drift (a carried verification-design row for which no test assertion or implementation site can be named, and which no `[ac-decision]` ledger entry covers, caps Completeness at 6) | max 3× → re-entry by `remedy_class` (doc commit / RED / GREEN / ARCHITECT; `operator` → pause) |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

The category sets and weights should be customised per project. They reflect
"what actually matters in this project," not universal standards. As patterns
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
  "inherited_verdicts": [
    { "suite": "tests/<path>.sh", "source": "<green-tree entry heading>", "head": "<hash>", "result": "<summary line>" }
  ],
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "remedy_class": { "<failed item>": "doc | test | impl | design | operator" },
  "rescore": { "source": "<prior report path>", "rescored": ["item"], "inherited": ["item"] },
  "refine_observations": [ { "entry": "<suggestion @ path:line>", "disposition": "defect — scored under <item> | not a defect — <reason>" } ],
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": ["items 5-6"]
}
```

The `scores` object is what the gate hook reads. Each item is either a number
(`8`) or an object (`{"score": 8, "reason": "..."}`). The hook accepts both.

`fail_hypothesis` records the pre-scoring consider-the-opposite search required by
[`teammate-contracts.md`](teammate-contracts.md) > Evaluation AI > Pre-scoring FAIL
hypothesis. It is narrative/audit material: nothing reads it programmatically and no
gate consumes it. It is placed before `scores` because the ordering is the procedure —
the search precedes scoring.

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `case` | string, non-empty | always | The strongest FAIL argument found. With `disposition: "none_found"` it states **what was searched** (which items, which anchors re-derived), so the record is evidence of the search rather than a blank. |
| `disposition` | enum `refuted` \| `survived` \| `none_found` | always | Outcome of the refutation attempt. |
| `reflected_in` | array of rubric item names | always present (`[]` when `disposition != "survived"`) | Which scored item(s) recorded the surviving case — the join between the narrative record and the numeric `scores`. "Recorded" does not imply "scored down": an item listed here may still score ≥ 7. |

`remedy_class` (GATE:QUALITY only) maps **each failed item** (score < 7) to the kind of change that
clears it; the orchestrator routes the FAIL's re-entry from it ([`autoflow-guide.md`](autoflow-guide.md)
> GATE:QUALITY > FAIL routing). It is report material the orchestrator acts on; the hook does not
read it from the report (it reads the routed class the orchestrator records in state).

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `remedy_class` | object, one entry per failed item | **on every FAIL** (`{}` on a PASS) | Value enum `doc` \| `test` \| `impl` \| `design` \| `operator`. A failed item with no entry is a contract violation — reject + re-spawn, as for a missing `fail_hypothesis`. `operator` means "not classifiable with confidence" and pauses the cycle for the operator. |
| `rescore` | object | **on a re-entry evaluation** (absent on a first evaluation) | `source` — the prior report's path; `rescored` — the items scored afresh (the failed items plus any inherited item whose anchor files the re-entry diff touched); `inherited` — the items whose score is copied from `source`. Every rubric item appears in exactly one of the two lists. |

`refine_observations` (GATE:QUALITY only; issue #135) records the evaluator's disposition of every
entry in the REFINE report's `## Out-of-scope observations — guard / boundary logic touched`
section. Always present on a GATE:QUALITY report (`[]` when the section says `none`); a report that
omits it or leaves an entry undispositioned is rejected and re-spawned. `rescore` is also the field
a review-response AUDIT uses for its narrowed re-score ([`autoflow-guide.md`](autoflow-guide.md) > AUDIT).

`inherited_verdicts` carries the citation for every suite verdict the evaluator took from the host's
own record instead of re-executing, per [`teammate-contracts.md`](teammate-contracts.md) >
Evaluation AI > *Host-record citation-inheritance*. It is the evaluator's report artifact, not the
gate state file.

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `inherited_verdicts` | array of objects | **always present** (`[]` when the evaluator executed everything) | The same always-present discipline `reflected_in` carries: its absence is a defect, not a silence. Each member is `{ "suite", "source", "head", "result" }` — the repo-relative suite path, the `green-tree` entry heading it was cited from, that entry's `head` hash, and its `result` summary line. A prose citation is not sufficient: "I inherited" is itself an anchor a reader re-derives. |

**[DENY]** `inherited_verdicts` is never written to `.autoflow/issue-{N}.json`. That file's
`top_level_keys` are closed-world (`tests/fixtures/gate-schema.json`), so an additive top-level key
is MALFORMED and fails `git push` / `gh pr create` closed for the whole cycle — the identical
footgun this document already records for `fail_hypothesis`. Should a state-resident copy ever be
wanted, the only admissible placement is a sibling of `evaluator` and `scores` **inside** the phase
object; the report is the durable record and no such copy is asked for.

---

## Hook Trust Boundary

`check-autoflow-gate.sh` does **not** read the AI's `pass`, `avg`, or `min`
fields. It computes them from raw `scores`. The trust chain stops at the script
level — see [`design-rationale.md`](design-rationale.md#decision-3-the-hook-does-not-trust-ais-pass-judgment).

---

## State File Linkage

While AutoFlow is in progress, `.autoflow/issue-{N}.json` records the score
sets per phase. The hook reads from this file at gate points to allow or block
Agent spawns and `git push`/`gh pr create` actions.

The phase keys recorded in the state file are below. The hook **gates** only the
four cause/plan/audit/quality keys; `gate_hypothesis_structure` is recorded in
state but **not gated** by the hook (DIAGNOSE 3-Phase structure evaluation —
orchestrator-judged against the CLAUDE.md thresholds, not enforced at a hook gate
point), matching `docs/security-checklist.md` and the `gated_phase_keys`
allow-list in `tests/fixtures/gate-schema.json`, which both omit it:

- `gate_hypothesis_structure` — DIAGNOSE 3-Phase structure evaluation (recorded in state, **not gated** by the hook — orchestrator-judged)
- `gate_hypothesis_cause` — GATE:HYPOTHESIS cause analysis (hook-gated)
- `gate_plan` — GATE:PLAN (hook-gated)
- `audit` — AUDIT (hook-gated)
- `gate_quality` — GATE:QUALITY (hook-gated)

- **[MUST]** When an evaluation's `fail_hypothesis` is recorded in state, it is written at `phases.<phase_key>.fail_hypothesis` — a sibling of `evaluator` and `scores` inside the phase object. **[DENY]** Never at the state file's top level and never as an entry inside `scores`: the hook's state-file validator is closed-world at top level and score-shaped inside `scores`, so either placement makes it fail closed (MALFORMED, exit 2) and deadlocks `git push` / `gh pr create` for the whole cycle. Recording is permitted, not required — the durable record is the evaluator's report.

See [`CLAUDE.md`](../CLAUDE.md#autoflow-state-tracking-hook-integration) for the
full schema.
