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
| Plan evaluation (GATE:PLAN) | Feasibility, Dependencies, Scope, Security, Test plan (5) — Feasibility/Scope absorb the structural-fit & over-engineering concern the DIAGNOSE structure gate deliberately does not score, and carry the embedded ADR-conformance check (divergence from a governing ADR, or an architecture-impacting change with no governing ADR/owner decision, caps the named item at 6; N/A by default) | max 3× → ARCHITECT |
| Security audit (AUDIT) | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation (GATE:QUALITY) | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) — Fit also carries the embedded ADR-conformance regression re-confirmation (caps Fit at 6; same trigger as GATE:PLAN) | max 3× → RED |
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
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": ["items 5-6"]
}
```

The `scores` object is what the gate hook reads. Each item is either a number
(`8`) or an object (`{"score": 8, "reason": "..."}`). The hook accepts both.

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

See [`CLAUDE.md`](../CLAUDE.md#autoflow-state-tracking-hook-integration) for the
full schema.
