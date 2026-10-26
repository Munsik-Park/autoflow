# Module Usage

How each AutoFlow module is run, and how one module's output becomes another's input. Which modules
are run, and in what order, is the user's ([`ADR-0038`](records/adr/0038-contract-modules-with-no-state-file.md)
D2); this document says what each module takes and gives.

## Running a module

- A module runs once on an invocation file: `/autoflow:<module> <invocation.json>`. The invocation
  names the module's `params`, its `inputs` by path, its output directory `out`, and, for a module
  given the record directory, `records` — the attempt's record directory, where the ledger
  `issue-<N>-ledger.md` and every earlier run's output directory are. Each run has its own `out`
  inside it: `<module>-<n>`, or `<module>-<qualifier>-<n>` for a module run once per item
  (`criterion-in-depth-AC2-1`).
- The run writes its outputs and `<out>/tool-requests.json` (`[]` when it lacked nothing), and its
  check-out writes `<out>/result.json`: `status` (`accepted` or `refused`), `outputs` (each output's
  path; the build's commits as `{branch, from, to}`; the delivery's pull request as `{url, number,
  head}`), `defects`, `tool_requests`, and the AutoFlow that ran it. A run refused at check-in has
  done no work; a run refused at check-out leaves its outputs, and a later module's check-in reads an
  input by its form, not by the result of the run that made it.
- The form of each invocation: `<autoflow-root>/scripts/contracts/contract.sh`, header. The checks
  each module's outputs meet: its contract, `<autoflow-root>/docs/contracts/<module>.json`.

## Connecting modules

- An input names where it comes from (the tables below): another module's output, given by its path
  (the build's commits by the range its `result.json` records); ledger entries, given as the ledger
  file; a document of the target; or a file the invocation gives. The review's `pr` is
  `<owner>/<name>#<N>`, the pull request the delivery's `result.json` records.
- A re-run takes its previous output and the findings it answers, the inputs named `previous_…` and
  `findings`.
- The acceptance criteria every module after the analysis takes are criteria-apply's output: the
  analysis report's criteria with the ledger's `[ac-decision]` entries applied. A run whose output
  names an `[ac-decision]` entry it followed has changed the criteria, and a criteria-apply run on the
  ledger gives the changed ones.
- An evaluation module writes `<out>/evaluation.json`: its scores, their grounds and its
  recommendations; the reference values the scores are set against are its contract's `reference`.

<!-- Generated below from docs/contracts/*.json by scripts/contracts/gen-module-usage.sh — edit the contracts, then regenerate. -->

## Modules

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

```json
{"contract":1,"module":"criterion-screen","params":{"issue":"<issue-number>"},"inputs":{},"records":"<record directory>","out":"<record directory>/criterion-screen-<n>"}
```

### `criterion-trace`

- Kind: functional; given the record directory (`records`)
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

```json
{"contract":1,"module":"criterion-trace","params":{"issue":"<issue-number>"},"inputs":{"review_record":"<path>"},"records":"<record directory>","out":"<record directory>/criterion-trace-<n>"}
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
| `report` | `<out>/analysis.md` |

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
- Goal: Scores of whether the analysis report's conclusion is supported by its grounds and whether the analysis reached its goal — never the method by which it was reached.
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
| `decisions` | no | the ledger: `[ac-decision]`, `[design-point]` entries |
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

```json
{"contract":1,"module":"design","params":{"issue":"<issue-number>"},"inputs":{"applied_criteria":"<path>","analysis":"<path>","hypothesis_evaluation":"<path>"},"records":"<record directory>","out":"<record directory>/design-<n>"}
```

### `plan`

- Kind: evaluation; given its declared inputs only
- Goal: Scores of the design's intent — whether each decision is grounded, whether each criterion's verification fits it and whether the scope is right — never the method by which the design was reached.
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

```json
{"contract":1,"module":"plan","params":{"issue":"<issue-number>"},"inputs":{"feature_design":"<path>","verification_design":"<path>","applied_criteria":"<path>"},"out":"<record directory>/plan-<n>"}
```

### `build`

- Kind: functional; given the record directory (`records`)
- Goal: The design implemented within the cycle's scope on the cycle's branch, and every item of the verification design verified as it says — or, where it cannot be, the reason recorded.
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
| `commits` | git |
| `report` | `<out>/build-report.md` |
| `green_blocker` | `<out>/green-blocker.md` |

```json
{"contract":1,"module":"build","params":{"issue":"<issue-number>","branch":"<string>"},"inputs":{"applied_criteria":"<path>","feature_design":"<path>","verification_design":"<path>"},"records":"<record directory>","out":"<record directory>/build-<n>"}
```

### `audit`

- Kind: evaluation; given its declared inputs only
- Goal: A judgment of whether the build's tests failed before the implementation where they were meant to, and scores of the change on the project's security items.
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

```json
{"contract":1,"module":"audit","params":{"issue":"<issue-number>"},"inputs":{"commits":"<path>","build_report":"<path>","verification_design":"<path>"},"out":"<record directory>/audit-<n>"}
```

### `quality`

- Kind: evaluation; given its declared inputs only
- Goal: Scores of the built change against the acceptance criteria, the design and the build's own records — complete, correct, verified, within the cycle's scope, committed and documented.
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

```json
{"contract":1,"module":"quality","params":{"issue":"<issue-number>"},"inputs":{"commits":"<path>","applied_criteria":"<path>","analysis":"<path>","feature_design":"<path>","verification_design":"<path>","build_report":"<path>","audit_evaluation":"<path>"},"out":"<record directory>/quality-<n>"}
```

### `delivery`

- Kind: functional; given the record directory (`records`)
- Goal: The branch on the remote at the commit the quality evaluation scored, the change shown working above its own tests, and a draft pull request open with CI green on its head — or CI's not running recorded on it — whose body lets the operator decide on it.
- Procedure: `<autoflow-root>/docs/units/delivery.md`

| Param | Required | Form |
|---|---|---|
| `issue` | yes | issue-number |
| `branch` | yes | string |
| `base` | no | string |

| Input | Required | From |
|---|---|---|
| `commits` | yes | `build` → `commits` |
| `applied_criteria` | yes | `criteria-apply` → `applied_criteria` |
| `feature_design` | yes | `design` → `feature_design` |
| `verification_design` | yes | `design` → `verification_design` |
| `build_report` | yes | `build` → `report` |
| `quality_evaluation` | yes | `quality` → `evaluation` |
| `tool_requests` | no | the `tool-requests.json` of earlier runs |
| `deferred` | no | a file the invocation gives |

| Output | File |
|---|---|
| `pull_request` | pull-request |
| `integration` | `<out>/integration.md` |
| `ci_failure` | `<out>/ci-failure.md` |

```json
{"contract":1,"module":"delivery","params":{"issue":"<issue-number>","branch":"<string>"},"inputs":{"commits":"<path>","applied_criteria":"<path>","feature_design":"<path>","verification_design":"<path>","build_report":"<path>","quality_evaluation":"<path>"},"records":"<record directory>","out":"<record directory>/delivery-<n>"}
```

### `review`

- Kind: functional; given the record directory (`records`)
- Goal: The pull request reviewed by every configured reviewer, and one aggregated verdict over their reviews posted on it: each finding once, with its severity and whether it holds.
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
| `findings` | `<out>/findings.md` |
| `comment` | `<out>/comment.md` |

```json
{"contract":1,"module":"review","params":{"issue":"<issue-number>","pr":"<string>","round":"<integer>"},"inputs":{},"records":"<record directory>","out":"<record directory>/review-<n>"}
```
