# GATE:HYPOTHESIS — Analysis Evaluation

> Phase playbook for GATE:HYPOTHESIS. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

GATE:HYPOTHESIS is the verification of the U2 Analysis unit ([DIAGNOSE](analysis.md)). It scores
what the analysis report shows, never the method the unit took to produce it (ADR-0025 D2).

**Evaluator**: one independent Evaluation AI, fresh-spawned per entry (the model
`bash scripts/spawn-policy/spawn-policy.sh model gate-hypothesis` names). It scores the structure
form for every issue and, for a bug / incident issue, the cause form, and reports both score sets;
the orchestrator records them under `phases.gate_hypothesis_structure` and
`phases.gate_hypothesis_cause` in `.autoflow/issue-{N}.json`.
**Input**: the analysis report (`.autoflow/issue-{N}-analysis.md`), the trigger target (the issue,
or the reviewer comment / thread of a review-response cycle) and the decision ledger.

## Structure form (every issue)

The form answers one question: **does the as-is already satisfy the request, and if not, is a code
change the lever?** The request is the cycle's trigger target and the as-is the dev branch's HEAD
([DIAGNOSE](analysis.md) > *What the analysis owes*). It is a necessity gate and reuse-neutral: a
resolution that reuses existing code scores high, not low. Plan feasibility, structural fit and
over-engineering are GATE:PLAN's (Decision grounds, Scope) and GATE:QUALITY's (Minimal
implementation, Fit).

The rubric follows the issue type the report records under `## Necessity`: Type 1 (code change —
bug fix, new feature, script change, pattern extension, hook change) or Type 2 (documentation /
consistency — content sync, doc update, cross-file consistency); mixed or unclear is Type 1.

Type 1 (2 items × 10 points):

| Item | Criterion |
|------|-----------|
| Behavior gap          | Per the report's `## Current structure`, does the as-is NOT yet produce the required behavior? (high = real gap → change needed; already produced / already fixed → low) |
| Code-change necessity | Is a *code* change the lever, not data / config / ops? (high = code change needed; resolvable by config / data / ops → low) |

Type 2 (3 items × 10 points):

| Item | Criterion |
|------|-----------|
| Content gap        | Is there an actual content gap or inconsistency? (high = gap exists) |
| Consistency impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
| Propagation scope  | Is the change scope appropriate — not too broad, not missing targets? (high = appropriate scope) |

**PASS**: each ≥ 7 — and, for the 3-item Type 2 rubric, also avg ≥ 7.5. The hook records but
**does not gate** `gate_hypothesis_structure`; the orchestrator judges it against these thresholds
(`CLAUDE.md` > AutoFlow State Tracking).

- **PASS** → recommendation triage ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) →
  the cause form (bug / incident), or ARCHITECT with the verdict `skipped (non-bug issue)` (non-bug).
- **FAIL** → disposition by the failing item — never a bare composite; a real code gap is never
  auto-closed. No retry loop.
  - **Gap item low** (the as-is already satisfies the request) → no change needed. Branch on the
    cycle's `mode` recorded at PREFLIGHT (a PR state change mid-cycle is re-classified at the next
    PREFLIGHT, not re-derived here):
    - `mode = review-response` → reply on the PR with the finding; do not close the issue or the PR;
      set `active: false`, `phase: "awaiting-external-review"`.
    - `mode = new-issue` → the issue is closed with `gh issue close` and the cycle ends
      (`active: false`). **Pre-close verification** (the hook does not gate `gh issue close`): the
      orchestrator first confirms the recorded `phases.gate_hypothesis_structure` scores meet this
      FAIL condition (gap item < 7). The close comment records those scores and a summary of the
      existing mechanism. Re-filing or reopening is the re-entry path.
  - **Gap item high, Code-change necessity low** (a real gap whose lever is data / config / ops) →
    the advisor decides ([`role-contracts.md`](../role-contracts.md) > Advisor). **A code change is
    still owed** → the cycle continues as on a PASS; **the lever is non-code** → report the finding
    situation-first ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision
    presentation) — in a `mode = review-response` cycle, as the PR reply — and end the cycle with
    `active: false`, `phase: "awaiting-user"`.

## Cause form (bug / incident issues only)

Non-bug issues (feat, chore, docs, refactor, …) skip this form. The form reads the report's
`## Hypotheses`.

| Item | Criterion |
|------|-----------|
| Hypothesis diversity | Are non-code causes (data, environment, already fixed) sufficiently considered? |
| Verification sufficiency | Was lightweight verification actually performed? Are unverified items justified? |
| Verdict evidence | Is the conclusion (code change required / not required) logically supported? |

- **PASS** → recommendation triage ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) →
  ARCHITECT.
- **FAIL** → a U2 unit re-run with this report's findings and the previous analysis report
  ([DIAGNOSE](analysis.md) > *Re-entry*), max 2×. Third FAIL → human decision.
- **Non-code root cause confirmed** → the advisor decides ([`role-contracts.md`](../role-contracts.md) > Advisor): a code change is still owed → ARCHITECT; the cause is non-code → report it (situation-first — [`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation) and end the cycle (`active: false`, `phase: "awaiting-user"`).

## Re-entry re-score

After a U2 re-run the gate re-scores the form that sent the cycle back — the cause form after a
cause-form FAIL, the recommending form after a recommendation attempt — and the other form only
where the re-run changed a section it reads (the structure form: `## Current structure`,
`## Request`, `## Necessity`; the cause form: `## Hypotheses`); the rest is inherited and reported
in `rescore` ([`evaluation-system.md`](../evaluation-system.md) > Evaluation
Output Format).
