# GATE:HYPOTHESIS — Hypothesis Evaluation (bug/incident issues only)

> Phase playbook for GATE:HYPOTHESIS. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

Feat issues skip this gate.

**Evaluator**: independent Evaluation AI, fresh-spawned per call.
**Input**: hypothesis list + lightweight-verification results + verdict notes.

## Scoring (3 items × 10 points)

| Item | Criterion |
|------|-----------|
| Hypothesis diversity | Are non-code causes (data, environment, already-fixed) sufficiently considered? |
| Verification sufficiency | Was lightweight verification actually performed? Are unverified items justified? |
| Verdict evidence | Is the conclusion (code change required / not required) logically supported? |

- **PASS** → recommendation triage ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) → ARCHITECT. The
  structure form's PASS is triaged the same way before DIAGNOSE continues.
- **FAIL** → DIAGNOSE (max 2×). Third FAIL → human decision.
- **Non-code root cause confirmed** → report to user (situation-first — [`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation), pause AutoFlow.
