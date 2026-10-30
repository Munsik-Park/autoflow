# AutoFlow Guide — Modules and Their Contracts

> AutoFlow is a set of modules for AI-assisted software engineering with Claude Code, each with a
> contract ([`ADR-0038`](records/adr/0038-contract-modules-with-no-state-file.md)).
> This guide is the **index of the modules**: each module's goal, what its work owes, its output,
> its default and its cautions live in its procedure document (*Modules* below), and its inputs, its
> outputs and its default in its contract, `<autoflow-root>/docs/contracts/<module>.json`. What crosses modules — the
> authority rules, how a module runs, the Execution Principles, the records and the hook — lives in
> [`core.md`](core.md).

---

## Overview

A module is defined by its inputs, its outputs and its default. It runs once, on its invocation: it
checks its inputs' form, does its work, writes its outputs, and checks them against its contract
([`core.md`](core.md) > Development Lifecycle). The terminal output of the modules is an open,
reviewed pull request; an external review process merges it.

Key principles:

- **The work's method is its own; the independent checks are not** — how far a module's work goes
  is the working AI's judgment, recorded with its grounds in its output, and no module judges its
  own output ([`core.md`](core.md) > Rule Scope, principles 1–3; > Execution Principles).
- **Multi-agent separation** — the work and its evaluation are separate modules, and each
  evaluation is a fresh Evaluation AI.
- **Quantified quality** — 10-point evaluation, with the reference pass values kept with the
  rubrics ([`evaluation-system.md`](evaluation-system.md) > PASS Criteria) and output with the
  scores.
- **Per-phase model selection** — every role spawn and subagent spawn declares the model the per-phase policy names for that phase. The values live in one machine-readable source, `.claude/autoflow/spawn-policy.json`, resolved by `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` and never restated in prose; the rule that governs it is [`core.md`](core.md) > Spawn Model — Phase-by-Phase.

The phase names stay as identifiers — the spawn-policy keys and the documents' headings carry
them. They generalize upstream's numeric `STEP 0~9` identifiers, with upstream's STEP 4–5.5 merged
into one BUILD (ADR-0025):

| upstream | phase | module |
|----------|-------|--------|
| STEP 0 | PREFLIGHT | — (the branch and the record directory a module's invocation names, ADR-0038 D4) |
| STEP 1 | DIAGNOSE | analysis |
| STEP 1.5 | GATE:HYPOTHESIS | hypothesis |
| STEP 2 | ARCHITECT | design |
| STEP 3 | GATE:PLAN | plan |
| STEP 4, 5a–5d, 5.5 | BUILD | build |
| STEP 5.7 | AUDIT | audit |
| STEP 6 | GATE:QUALITY | quality |
| STEP 7–8 | DELIVER, INTEGRATE | delivery |
| STEP 9 | HANDOFF, REVIEW | ci, review |

---

## Running a module

- A module runs in the target's checkout, the session's working directory; `issue` is an issue of
  the repository gh resolves there — in a checkout with more than one remote, set it with
  `gh repo set-default`.
- A module runs once on an invocation file: `/autoflow:<module> <invocation.json>`. The invocation
  names the module's `params`, its `inputs` by path, its output directory `out`, and, for a module
  given the record directory, `records` — the attempt's record directory, where the ledger
  `issue-<N>-ledger.md` and every earlier run's output directory are. Each run has its own `out`
  inside it: `<module>-<n>`, or `<module>-<qualifier>-<n>` for a module run once per item
  (`criterion-in-depth-AC2-1`). Its `instructions`, when given, reach the AI that does the work.
- A module's outputs are the files it writes in `out`, by the names and forms its contract gives.
  Its default is what it does with its result unless the invocation says otherwise, stated in its
  contract (`default`) and its procedure. The invocation's `instructions` override the default and
  never the outputs ([`core.md`](core.md) > Development Lifecycle > *Inputs, outputs and default*).
- A run's output is what the module's goal asks for or, when the run does not reach the goal, its
  contract's failure output, `<out>/failure.md`. The run writes its outputs and
  `<out>/tool-requests.json` (`[]` when it lacked nothing), and its
  check-out writes `<out>/result.json`: `status` (`accepted`, `refused`, or `failed` when the run
  wrote its contract's failure output — what it did and why it did not reach its goal),
  `outputs` (each output's path), `defects`,
  `tool_requests`, and the AutoFlow that ran it. A run refused at check-in has done no work; a run
  refused or failed at check-out leaves its outputs, and a later module's check-in reads an input by
  its form, not by the result of the run that made it.
- The form of each invocation: `<autoflow-root>/scripts/contracts/contract.sh`, header. The checks
  each module's outputs meet — their form, each file read alone: its contract,
  `<autoflow-root>/docs/contracts/<module>.json`.

## Connecting modules

- An input names where it comes from (the tables below): another module's output, given by its path
  (the build's commits as its `commits.json`, the range `{branch, from, to}`); ledger entries, given as the ledger
  file; a document of the target; or a file the invocation gives. The review's `pr` is
  `<owner>/<name>#<N>`, a pull request's `pr` in the delivery's `delivery.json`.
- An input given several files takes them as an array of paths.
- A re-run takes its previous output and the findings it answers, the inputs named `previous_…` and
  `findings`.
- The acceptance criteria every module after the analysis takes are criteria-apply's output: the
  analysis report's criteria with the ledger's `[ac-decision]` entries applied. A run whose output
  names an `[ac-decision]` entry it followed has changed the criteria, and a criteria-apply run on the
  ledger gives the changed ones.
- An evaluation module writes `<out>/evaluation.json`: its scores, their grounds and its
  recommendations; the reference values the scores are set against are its contract's `reference`.

## Modules

Each module's kind, goal, procedure, params, inputs with where each comes from, outputs and an
invocation skeleton, from its contract. The rubrics of all four evaluations — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — are the
evaluator's and live in [`evaluation-system.md`](evaluation-system.md) > *Gate rubrics*.

<!-- BEGIN generated from docs/contracts/*.json by scripts/contracts/gen-module-usage.sh — edit the contracts, then regenerate. -->

### `criterion-screen`

- Kind: functional; given the record directory (`records`)
- Goal: Each acceptance criterion of the issue reviewed against the target's code and policy — whether it holds, the cases it applies to and where the behaviour it requires is decided — and every item the review finds disposed of, with its grounds; the cases that need an in-depth look handed on without any verdict.
- Procedure: `<autoflow-root>/docs/criterion-review.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `target_documents` | no | a document of the target |

| Output | File |
|---|---|
| `review_record` | `<out>/criterion-review.md` |
| `targets` | `<out>/targets/*.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"criterion-screen","params":{"issue":"<issue-number>"},"inputs":{},"records":"<record directory>","out":"<record directory>/criterion-screen-<n>"}
```

### `criterion-trace`

- Kind: functional; given its declared inputs only
- Goal: How far each cause the review confirmed reaches beyond the points the issue reports, and whether each behaviour a criterion requires conflicts with the rules the code already has — assuming no fix.
- Procedure: `<autoflow-root>/docs/criterion-review.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `review_record` | yes | `criterion-screen` → `review_record` |

| Output | File |
|---|---|
| `trace` | `<out>/trace.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"criterion-trace","params":{"issue":"<issue-number>"},"inputs":{"review_record":"<path>"},"out":"<record directory>/criterion-trace-<n>"}
```

### `criterion-in-depth`

- Kind: functional; given its declared inputs only
- Goal: A verdict on each target case of one criterion, resting on the code that decides whether and how the required behaviour occurs and the condition applied there.
- Procedure: `<autoflow-root>/docs/criterion-review.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `criterion` | yes | string |

| Input | Required | From |
|---|---|---|
| `target` | yes | `criterion-screen` → `targets` |

| Output | File |
|---|---|
| `in_depth` | `<out>/in-depth.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"criterion-in-depth","params":{"issue":"<issue-number>","criterion":"<string>"},"inputs":{"target":"<path>"},"out":"<record directory>/criterion-in-depth-<n>"}
```

### `criterion-reconcile`

- Kind: functional; given the record directory (`records`)
- Goal: The review record reconciled with the trace and the in-depth verdicts: every case where they differ settled in the code, and the record's dispositions brought to match — the review's result, an item and its disposition each.
- Procedure: `<autoflow-root>/docs/criterion-review.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `review_record` | yes | `criterion-screen` → `review_record` |
| `trace` | yes | `criterion-trace` → `trace` |
| `in_depth` | no | `criterion-in-depth` → `in_depth` |

| Output | File |
|---|---|
| `review_record` | `<out>/criterion-review.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"criterion-reconcile","params":{"issue":"<issue-number>"},"inputs":{"review_record":"<path>","trace":"<path>"},"records":"<record directory>","out":"<record directory>/criterion-reconcile-<n>"}
```

### `analysis`

- Kind: functional; given the record directory (`records`)
- Goal: The request understood well enough to be evaluated: the affected structure as it stands, the gap between it and the requested behaviour, whether a change is owed and whether code is the lever, and the decision points, each conclusion with its grounds.
- Procedure: `<autoflow-root>/docs/units/analysis.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `criterion_review` | no | `criterion-reconcile` → `review_record` |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `target_documents` | no | a document of the target |
| `previous_report` | no | `analysis` → `report` |
| `hypothesis_evaluation` | no | `hypothesis` → `evaluation` |
| `findings` | no | `quality` → `evaluation`, or `review` → `findings` |

| Output | File |
|---|---|
| `report` | `<out>/issue-analysis.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"analysis","params":{"issue":"<issue-number>"},"inputs":{},"records":"<record directory>","out":"<record directory>/analysis-<n>"}
```

### `criteria-apply`

- Kind: deterministic; given its declared inputs only
- Goal: The acceptance criteria the cycle works to: the analysis report's criteria with every settled acceptance-criterion decision applied (Q5).
- Procedure: `<autoflow-root>/scripts/contracts/criteria-apply.sh`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `analysis` | yes | `analysis` → `report` |
| `decisions` | no | the ledger: `[ac-decision]` entries |

| Output | File |
|---|---|
| `applied_criteria` | `<out>/applied-criteria.json` |

```json
{"contract":1,"module":"criteria-apply","params":{"issue":"<issue-number>"},"inputs":{"analysis":"<path>"},"out":"<record directory>/criteria-apply-<n>"}
```

### `hypothesis`

- Kind: evaluation; given its declared inputs only
- Goal: Scores of whether the analysis report's conclusion is supported by its grounds and whether the analysis reached its goal — never the method by which it was reached. A re-score, given the previous evaluation, states which items it scored afresh and which it inherited.
- Procedure: `<autoflow-root>/docs/evaluation-system.md > Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY > GATE:HYPOTHESIS`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `analysis` | yes | `analysis` → `report` |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `previous_evaluation` | no | `hypothesis` → `evaluation` |

| Output | File |
|---|---|
| `evaluation` | `<out>/evaluation.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"hypothesis","params":{"issue":"<issue-number>"},"inputs":{"analysis":"<path>"},"out":"<record directory>/hypothesis-<n>"}
```

### `design`

- Kind: functional; given the record directory (`records`)
- Goal: A design the build module can implement and verify: the architecture decisions with the constraints they hold under and the alternatives rejected, and a verification design that says how each acceptance criterion is verified and which failure mode each verification catches.
- Procedure: `<autoflow-root>/docs/units/design.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `analysis` | yes | `analysis` → `report` |
| `hypothesis_evaluation` | yes | `hypothesis` → `evaluation` |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `target_documents` | no | a document of the target |
| `previous_feature_design` | no | `design` → `feature_design` |
| `previous_verification_design` | no | `design` → `verification_design` |
| `plan_evaluation` | no | `plan` → `evaluation` |
| `green_blocker` | no | `build` → `green_blocker` |
| `findings` | no | `quality` → `evaluation`, or `review` → `findings` |

| Output | File |
|---|---|
| `feature_design` | `<out>/feature-design.md` |
| `verification_design` | `<out>/verification-design.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"design","params":{"issue":"<issue-number>"},"inputs":{"applied_criteria":"<path>","analysis":"<path>","hypothesis_evaluation":"<path>"},"records":"<record directory>","out":"<record directory>/design-<n>"}
```

### `plan`

- Kind: evaluation; given its declared inputs only
- Goal: Scores of the design's intent — whether each decision is grounded, whether each criterion's verification fits it and whether the scope is right — never the method by which the design was reached. A re-score, given the previous evaluation, states which items it scored afresh and which it inherited.
- Procedure: `<autoflow-root>/docs/evaluation-system.md > Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY > GATE:PLAN`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `feature_design` | yes | `design` → `feature_design` |
| `verification_design` | yes | `design` → `verification_design` |
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `previous_evaluation` | no | `plan` → `evaluation` |

| Output | File |
|---|---|
| `evaluation` | `<out>/evaluation.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"plan","params":{"issue":"<issue-number>"},"inputs":{"feature_design":"<path>","verification_design":"<path>","applied_criteria":"<path>"},"out":"<record directory>/plan-<n>"}
```

### `build`

- Kind: functional; given the record directory (`records`)
- Goal: The design implemented within the cycle's scope on the cycle's branch, and every item of the verification design verified as it says — or, where it cannot be, the reason recorded. The output names the commits the run made, as a range on the branch.
- Procedure: `<autoflow-root>/docs/units/build.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `branch` | yes | string |
| `base` | no | string |

| Input | Required | From |
|---|---|---|
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `feature_design` | yes | `design` → `feature_design` |
| `verification_design` | yes | `design` → `verification_design` |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `previous_report` | no | `build` → `report` |
| `findings` | no | `audit` → `evaluation`, or `quality` → `evaluation`, or `review` → `findings` |
| `deferred` | no | a file the invocation gives |

| Output | File |
|---|---|
| `commits` | `<out>/commits.json` |
| `report` | `<out>/build-report.md` |
| `green_blocker` | `<out>/green-blocker.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"build","params":{"issue":"<issue-number>","branch":"<string>"},"inputs":{"applied_criteria":"<path>","feature_design":"<path>","verification_design":"<path>"},"records":"<record directory>","out":"<record directory>/build-<n>"}
```

### `audit`

- Kind: evaluation; given its declared inputs only
- Goal: A judgment of whether the build's tests meant to fail failed on the code without the implementation and passed on the code with it, and scores of the change on the project's security items. A re-score, given the previous evaluation, states which items it scored afresh and which it inherited.
- Procedure: `<autoflow-root>/docs/evaluation-system.md > Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY > AUDIT`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `commits` | yes | `build` → `commits` |
| `build_report` | yes | `build` → `report` |
| `verification_design` | yes | `design` → `verification_design` |
| `security_checklist` | no | a file the invocation gives |
| `previous_evaluation` | no | `audit` → `evaluation` |

| Output | File |
|---|---|
| `evaluation` | `<out>/evaluation.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"audit","params":{"issue":"<issue-number>"},"inputs":{"commits":"<path>","build_report":"<path>","verification_design":"<path>"},"out":"<record directory>/audit-<n>"}
```

### `quality`

- Kind: evaluation; given its declared inputs only
- Goal: Scores of the built change against the acceptance criteria, the design and the build's own records — complete, correct, verified, within the cycle's scope, committed and documented. A re-score, given the previous evaluation, states which items it scored afresh and which it inherited.
- Procedure: `<autoflow-root>/docs/evaluation-system.md > Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY > GATE:QUALITY`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |

| Input | Required | From |
|---|---|---|
| `commits` | yes | `build` → `commits` |
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `analysis` | yes | `analysis` → `report` |
| `feature_design` | yes | `design` → `feature_design` |
| `verification_design` | yes | `design` → `verification_design` |
| `build_report` | yes | `build` → `report` |
| `audit_evaluation` | yes | `audit` → `evaluation` |
| `deferred` | no | a file the invocation gives |
| `decisions` | no | the ledger: `[ac-decision]` entries |
| `previous_evaluation` | no | `quality` → `evaluation` |

| Output | File |
|---|---|
| `evaluation` | `<out>/evaluation.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"quality","params":{"issue":"<issue-number>"},"inputs":{"commits":"<path>","applied_criteria":"<path>","analysis":"<path>","feature_design":"<path>","verification_design":"<path>","build_report":"<path>","audit_evaluation":"<path>"},"out":"<record directory>/quality-<n>"}
```

### `delivery`

- Kind: functional; given the record directory (`records`)
- Goal: The change the build made, its local tests recorded green in the build report, delivered for the operator to see and decide on: each applied acceptance criterion with its outcome and its evidence, how the change was shown working, what the work could not verify and why, and what the change leaves undone.
- Procedure: `<autoflow-root>/docs/units/delivery.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `base` | no | string |
| `timeout` | no | integer |

| Input | Required | From |
|---|---|---|
| `commits` | yes | `build` → `commits` |
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `verification_design` | yes | `design` → `verification_design` |
| `build_report` | yes | `build` → `report` |
| `feature_design` | no | `design` → `feature_design` |
| `quality_evaluation` | no | `quality` → `evaluation` |
| `tool_requests` | no | the `tool-requests.json` of every earlier run |
| `deferred` | no | a file the invocation gives |

| Output | File |
|---|---|
| `delivered` | `<out>/delivery.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"delivery","params":{"issue":"<issue-number>"},"inputs":{"commits":"<path>","applied_criteria":"<path>","verification_design":"<path>","build_report":"<path>"},"records":"<record directory>","out":"<record directory>/delivery-<n>"}
```

### `ci`

- Kind: functional; given the record directory (`records`)
- Goal: For each pull request it is given, CI's verdict on its head with its ground — green, or, where the target's CI does not run for it, that fact and its ground, never read as green — with, given the build report, the CI job that ran each test file the change added.
- Procedure: `<autoflow-root>/docs/units/delivery.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `timeout` | no | integer |

| Input | Required | From |
|---|---|---|
| `pull_requests` | yes | `delivery` → `delivered`, or a file the invocation gives |
| `build_report` | no | `build` → `report` |

| Output | File |
|---|---|
| `ci` | `<out>/ci.json` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"ci","params":{"issue":"<issue-number>"},"inputs":{"pull_requests":"<path>"},"records":"<record directory>","out":"<record directory>/ci-<n>"}
```

### `review`

- Kind: functional; given the record directory (`records`)
- Goal: The pull request reviewed by every configured reviewer, and one aggregated verdict over their reviews: each finding once, with its severity and whether it holds.
- Procedure: `<autoflow-root>/docs/units/review.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `pr` | yes | `^[^/]+/[^#]+#[0-9]+$` |
| `round` | yes | integer |

| Input | Required | From |
|---|---|---|
| `previous_findings` | no | `review` → `findings` |

| Output | File |
|---|---|
| `reviews` | `<out>/reviews/*.md` |
| `findings` | `<out>/review-findings.md` |
| `comment` | `<out>/comment.md` |
| `failure` | `<out>/failure.md` |

```json
{"contract":1,"module":"review","params":{"issue":"<issue-number>","pr":"<string>","round":"<integer>"},"inputs":{},"records":"<record directory>","out":"<record directory>/review-<n>"}
```

<!-- END generated -->

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
- [`git-workflow.md`](git-workflow.md) — the commit format and issue closing.
