# AutoFlow Guide — Modules and Their Contracts

> AutoFlow is a set of modules for AI-assisted software engineering with Claude Code, each with a
> contract, run by the Coordinator ([`ADR-0038`](records/adr/0038-contract-modules-run-by-the-coordinator.md)).
> This guide is the **index of the modules**: each module's goal, what its work owes, its output
> and its cautions live in its procedure document (*Modules* below), and its inputs and outputs in
> its contract, `<autoflow-root>/docs/contracts/<module>.json`. What crosses modules — the
> authority rules, how a module runs, the Execution Principles, the records and the hook — lives in
> [`core.md`](core.md).

---

## Overview

A module is an input, the work it does, and an output. It runs once, on the invocation the
Coordinator writes: it checks its inputs' form, does its work, writes its outputs, and checks them
against its contract ([`core.md`](core.md) > Development Lifecycle). Which module runs next, on which
inputs, how many times, and what follows an evaluation's scores are the Coordinator's; AutoFlow
defines no step, order or timing for them. Its terminal output is an open, reviewed pull request;
merging is performed by an external review process, and AutoFlow does not merge.

Key principles:

- **The work's method is its own; the independent checks are not** — how far a module's work goes
  is the working AI's judgment, recorded with its grounds in its output, and no module judges its
  own output ([`core.md`](core.md) > Rule Scope, principles 1–3; > Execution Principles).
- **Multi-agent separation** — the work and its evaluation are separate modules, and each
  evaluation is a fresh Evaluation AI.
- **Quantified quality** — 10-point evaluation, with the reference pass values kept with the
  rubrics ([`evaluation-system.md`](evaluation-system.md) > PASS Criteria) and applied by the
  Coordinator.
- **Per-phase model selection** — every role spawn and subagent spawn declares the model the per-phase policy names for that phase. The values live in one machine-readable source, `.claude/autoflow/spawn-policy.json`, resolved by `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` and never restated in prose; the rule that governs it is [`core.md`](core.md) > Spawn Model — Phase-by-Phase.

The phase names stay as identifiers — the spawn-policy keys and the documents' headings carry
them. They generalize upstream's numeric `STEP 0~9` identifiers, with upstream's STEP 4–5.5 merged
into one BUILD (ADR-0025):

| upstream | phase | module |
|----------|-------|--------|
| STEP 0 | PREFLIGHT | — (the Coordinator's worktree, branch and record directory, ADR-0038 D4) |
| STEP 1 | DIAGNOSE | analysis |
| STEP 1.5 | GATE:HYPOTHESIS | hypothesis |
| STEP 2 | ARCHITECT | design |
| STEP 3 | GATE:PLAN | plan |
| STEP 4, 5a–5d, 5.5 | BUILD | build |
| STEP 5.7 | AUDIT | audit |
| STEP 6 | GATE:QUALITY | quality |
| STEP 7–8 | DELIVER, INTEGRATE | delivery |
| STEP 9 | HANDOFF, REVIEW | delivery, review |

---

## Modules

Each module's contract names the outputs of other modules it takes; that is the only order between
them AutoFlow states. The table reads the contracts: an input with no producer named is a file
outside the modules — the target's documents, a ledger entry, or a file the Coordinator writes.

| Module | Kind | Procedure | Takes (required) | Gives |
|--------|------|-----------|------------------|-------|
| criterion-screen | functional | [`criterion-review.md`](criterion-review.md) | the issue | the review record, a target file per criterion |
| criterion-trace | functional | [`criterion-review.md`](criterion-review.md) | the screen's record | the trace |
| criterion-in-depth | functional | [`criterion-review.md`](criterion-review.md) | one target file | the in-depth file |
| criterion-reconcile | functional | [`criterion-review.md`](criterion-review.md) | the screen's record, the trace | the review record, settled |
| analysis | functional | [`units/analysis.md`](units/analysis.md) | the issue | the analysis report |
| criteria-apply | deterministic | `<autoflow-root>/scripts/contracts/criteria-apply.sh` | the analysis report | the applied acceptance criteria |
| hypothesis | evaluation | [`evaluation-system.md`](evaluation-system.md) > GATE:HYPOTHESIS | the analysis report | an evaluation |
| design | functional | [`units/design.md`](units/design.md) | the applied criteria, the analysis report, its evaluation | the feature design, the verification design |
| plan | evaluation | [`evaluation-system.md`](evaluation-system.md) > GATE:PLAN | the two designs, the applied criteria | an evaluation |
| build | functional | [`units/build.md`](units/build.md) | the applied criteria, the two designs | the commits, the build report |
| audit | evaluation | [`evaluation-system.md`](evaluation-system.md) > AUDIT | the commits, the build report, the verification design | an evaluation |
| quality | evaluation | [`units/completion-evaluation.md`](units/completion-evaluation.md), [`evaluation-system.md`](evaluation-system.md) > GATE:QUALITY | the commits, the analysis, the designs, the build report, the audit's evaluation | an evaluation |
| delivery | functional | [`units/delivery.md`](units/delivery.md) | the commits, the designs, the build report, the quality evaluation | the pull request, the integration record |
| review | functional | [`units/review.md`](units/review.md) | the pull request (`params.pr`) | the reviews, the findings file, the posted comment |

A re-run takes, besides these, the outputs of the run before it and the findings it answers, as
each contract's optional inputs name. The seven unit documents group the modules as the unit
commands still do ([`core.md`](core.md) > Unit Document Loading Contract): U1 the criterion review's
four, U2 analysis and hypothesis, U3 design and plan, U4 build and audit, U5 quality, U6 delivery,
U7 review.

The rubrics of all four evaluations — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — are the
evaluator's and live in [`evaluation-system.md`](evaluation-system.md) > *Gate rubrics*.

---

## Execution Principles

→ Single source of truth: [`core.md`](core.md) > Execution Principles — among them Safety first,
Verify role-spawn claims before acting on them (every report's Evidence anchor is verified before it
is accepted — an anchor-less report is rejected, not interpreted), The route is the AI's judgment
(the independent checks are not), Role-spawn idle handling, and Stop on error.

---

## See Also

- [`core.md`](core.md) — the authority rules, how a module runs, the Execution Principles, the records and the hook.
- *Modules* above — the procedure documents and the contracts.
- [`evaluation-system.md`](evaluation-system.md) — the evaluator's standard, scoring, the reference pass values and the rubrics of all four evaluations.
- [`submodule-common-rules.md`](submodule-common-rules.md) — sub-repo rules, verification and reporting.
- [`repo-boundary-rules.md`](repo-boundary-rules.md) — cross-repo coordination.
- [`git-workflow.md`](git-workflow.md) — bash procedures, branch structure.
