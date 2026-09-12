# Evaluator Execution Discipline — Manual Verification Scenario

Companion to `docs/teammate-contracts.md` > Evaluation AI > *Sampling default* and
*Time cap* (the two `[MUST]`s; governing record: ADR-0024 > *Evaluator execution
discipline*). Re-homed from `tests/manual/issue-112-manual-scenarios.md` steps 4–5
when that document was retired with #228 (ADR-0024 D6: the anchor, sampling and
wall-clock obligations survive the Green-tree register's retirement).

**Why manual**: the contract text is a rule document and the report field
(`fail_hypothesis`, `docs/evaluation-system.md` > Evaluation Output Format) is a
schema; whether an evaluator *actually* stopped at its cap and *actually* sampled
rather than enumerated is a property of the run, visible only in the evaluator's
own report and tool-call record — no repository artifact records it.

## E1 — cap-and-sample-honoured: the gate evaluator honours the wall-clock cap and the representative-sample default

### Fixed inputs

- One gate evaluation run (GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY)
  spawned by a live cycle.
- The evaluator's own report JSON for that run (`.autoflow/issue-{N}-*-report.md`
  or `-audit.md`), and its spawn prompt (for a declared cap other than the default).

### Steps

1. Confirm the report's `fail_hypothesis` records a declared wall-clock cap — the
   30-minute default, or the value the spawn prompt declared — and, if the cap was
   reached, that every unsearched item is recorded `not-searched` rather than
   omitted or scored clean.
2. Confirm blind-spot search breadth: a representative sample (1–2 instances) per
   rubric item by default, with exhaustive enumeration entered only after a sampled
   FAIL case survives refutation (`fail_hypothesis.case` / `disposition`).
3. Record the outcome — `passed` (both properties hold) or `deviation` (name which)
   — with the report path as the evidence anchor.

### Expected outcome

The cap is declared and honoured with truthful `not-searched` recording, and the
blind-spot search defaults to a representative sample.
