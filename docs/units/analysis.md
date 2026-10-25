# U2 Analysis — DIAGNOSE and GATE:HYPOTHESIS

> Unit document for U2. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U2 Analysis is two modules: the analysis module, whose contract is
`<autoflow-root>/docs/contracts/analysis.json` and whose procedure is this file, and the hypothesis
evaluation module that scores its report (`<autoflow-root>/docs/contracts/hypothesis.json`,
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:HYPOTHESIS;
[`ADR-0038`](../records/adr/0038-contract-modules-run-by-the-coordinator.md) D1). This file states
the analysis's goal, what it owes, the cautions it is asked to heed and the report it writes. How the
module reaches the goal — what else it reads and in what order, whether it spawns helpers and what it
gives each, how it keeps the cautions — is its own, recorded with its grounds in its report
([`core.md`](../core.md) > Rule Scope, principle 2).

- **Goal**: the request understood well enough to be evaluated — the affected structure as it
  stands, the gap between it and the requested behavior, whether a change is owed and whether code
  is the lever, and the decision points, each conclusion with its grounds.
- **Output**: the analysis report (*Analysis report* below), and the run's tool requests
  ([`core.md`](../core.md) > Development Lifecycle > *Tools*).
- **Evaluation**: the hypothesis module — a fresh Evaluation AI scores the report on one form for
  every issue: whether the report's conclusion is supported by its grounds and whether the analysis
  met its goal (*Evaluation — GATE:HYPOTHESIS* below). The module never scores its own report.
- **Result owed**: the report's path and a one-line summary that names any decision point it
  recorded ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format).

## Unit spawn

- **The spawn.** One `autoflow-unit-analysis` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-analysis` names) runs the
  module. Its prompt states the goal, names the inputs the invocation gives by path — the issue
  (`params.issue`), the criterion review record, the decision ledger's `[criterion-ready]` and
  `[ac-decision]` entries, the target's documents, and on a re-run the previous report and its
  evaluation, or the findings it answers (a quality evaluation's or a review's) — the attempt's
  record directory, where earlier runs left their work, and the output directory the report goes to.
- **What the run is for is read from its inputs.** Given the criterion review record, the run
  analyzes the issue the record reviewed (*Criterion review record* below). Given the previous
  report and its evaluation, it brings that report up to date on the evaluation's findings, and
  what else it reuses from the earlier runs in the record directory is its own, recorded under
  `## Method`.
- **Documents.** The unit's agent definition carries the documents the analysis needs (this file, and the
  rubric it is scored on, [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* >
  GATE:HYPOTHESIS) with the rest of its guidance ([`core.md`](../core.md) > Context Injection);
  the prompt copies none of them, and the module reads anything further by its own judgment.

## What the analysis owes

The analysis is asked for four things, each conclusion with its grounds:

- the affected structure as it currently is, stated as fact;
- the gap between that structure and the behavior the request asks for — and, where the request
  reports a defect, the cause the gap comes from;
- whether a change is owed and, if so, whether a code change is the lever that closes the gap, or
  data, configuration or operations are;
- the decision points — the judgments that settle what follows the analysis, each with its decision.

How far the analysis pursues a cause, and by what means — how many explanations it weighs, which
ones, what it checks and with which tool — is the module's judgment, recorded with its grounds under
`## Method` and `## Cause`.

The request is the trigger target — the issue, a review comment or thread, or the finding a
re-run is for — and the as-is is the state it is measured against, which the module judges from
its inputs and records under `## Method`. The question is whether the as-is already
satisfies the request.

**Cautions.** Each names a bias the analysis is to avoid:

- Describe the current structure as fact, apart from the issue's defect hypothesis — do not read the
  structure to fit the hypothesis.
- A conclusion that a code change is required rests on evidence that the gap is not closed by
  data, configuration, the environment or an earlier fix; a cause that was not established is not
  presented as one.
- The necessity judgment is reuse-neutral: a resolution that uses existing code is not marked down
  for it. Structural fit and over-engineering are GATE:PLAN's and GATE:QUALITY's.
- Open every material the issue body or an acceptance criterion references — a design mockup, an
  asset, an external document — yourself; one that cannot be opened is recorded with the reason.

How the module guards against these biases — whether it separates the structure reading from the
issue reading, in what order it reads, what it gives or withholds from a helper — is its own,
recorded with its grounds under `## Method`.

The rules below are the ones other documents cite; everything else about the work is the module's.

- **Acceptance criteria.** The report's `## Acceptance criteria` table restates the issue's
  criteria faithfully, as the issue body states them; it is the table
  `<autoflow-root>/scripts/contracts/criteria-apply.sh` reads, and its output — the applied criteria
  — is what every later module takes. A re-run carries the table forward unchanged: a change to a
  criterion stands only as an `[ac-decision]` entry, which criteria-apply applies, and the table is
  not edited to match it ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion
  decisions*; `<autoflow-root>/docs/core.md` > Decision Ledger).
- **Criterion review record.** The issue's criteria were reviewed against the code and policy by
  the criterion review's modules, and the decisions they led to are recorded in the ledger's
  `[criterion-ready]` and `[ac-decision]` entries ([`criterion-review.md`](../criterion-review.md));
  the record that review left is an input, not a verdict. The analysis reads its findings as an
  earlier reading of the code and policy at the commits its `## Inputs` names: a finding the
  analysis builds on — a confirmed cause, a policy it cites — is checked at the commit the run starts
  from, and a difference from the record is recorded with its grounds. The record changes nothing
  about how the criteria are taken: the `## Acceptance criteria` table restates the issue's criteria
  as the body the `[criterion-ready]` entry records states them, the analysis does not run the
  review again (issue #291: the analysis takes the criteria as written), and a defect it observes as
  a fact it puts to the advisor ([`decision-ledger.md`](../decision-ledger.md) >
  Decision-point entries > *A criterion can be wrong*). The record's `## Dispositions` holds each
  item the review decided, with its grounds; `## Screening` lists each case a criterion applies to
  with the code that decides it, and `## Cause reach and rule conflict` where a confirmed cause
  reaches beyond the reported points or a required behavior meets a rule in force, each read like
  the findings as an earlier reading; `## Reconciliation` records, per stage 2 finding and per
  in-depth case, whether it was applied, rejected or left unresolved. The record's `## Unchecked`
  items, and each case left `unresolved`, are findings the analysis may close with its own checks
  (*Checking a finding* below). How the record was used is recorded under `## Method`.
- **Referenced materials.** Each material is recorded under `## Referenced materials` — what it is,
  where it is, how it was opened, and what it shows for the criterion that names it; the material,
  not an abbreviated example in the body, is what the criterion means. A material that cannot be
  opened is recorded `not opened: <reason>` and as a tool request — what is missing, and what the
  analysis concluded without it — and the run goes on to its end ([`core.md`](../core.md) >
  Development Lifecycle > *Tools*; [`submodule-common-rules.md`](../submodule-common-rules.md) >
  Verification and Tools > *The tools the work needs*).
- **Checking a finding.** A finding the analysis checks is checked with what the environment and the
  target's documents and scripts provide — API calls, queries, service status, logs — and those tools
  are looked for before a finding is left unchecked; a tool that is off is started by the target's
  own procedure, and one that needs the operator is recorded as a tool request (*The tools the work
  needs*). The report records each tool a conclusion rests on and whether it was usable; a finding left unchecked
  names the tool it needed.
- **Scope judgments.** Beyond the acceptance criteria, the analysis names the problems the confirmed
  cause carries — its other sites, and what fixing it will expose — with the scope judgment for each
  and its grounds ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface
  Rules > *Scope judgment*). The design module reads them and settles the scope in the feature
  design's `## Scope` section; the analysis does not decide it alone.
- **Decision points.** The analysis decides each judgment that settles what follows it, and records
  it under `## Decision points` with its grounds: a planning, design or ADR prerequisite clearly
  required before the issue can be implemented (when in doubt, none); a request the as-is already
  satisfies; on a reviewer finding, one that repeats an earlier round's complaint with a different
  witness case ([U7 Review](review.md) > *A repeated complaint*). A gap or a cause whose lever is not
  code, and — on a re-run that answers the hypothesis evaluation — a judgment that no report will meet
  what the evaluation asks, it puts to the advisor, as any point it doubts, and records the advisor's
  decision with its ledger entry ([`role-contracts.md`](../role-contracts.md) > Advisor). A suggested
  split of the issue stays a suggestion in the report; an issue is filed through a draft and
  `<autoflow-root>/scripts/issue/create-issue.sh` ([`issue-proposal.md`](../issue-proposal.md)).

## Analysis report

`<out>/analysis.md`. The first run writes it whole; a re-run, given the previous report, brings it
up to date rather than rewriting it, its `## Acceptance criteria` table unchanged. Every section
below is present; a section with nothing to record says `none`.

| Section | Holds | Read by |
|---|---|---|
| `## Method` | how the analysis was done — the reading order, any helper spawn and what it was given — and how each caution was kept, with grounds | GATE:HYPOTHESIS |
| `## Current structure` | the affected area as it stands — its structure, design intent and data flow — stated as fact | GATE:HYPOTHESIS |
| `## Request` | the concrete cases the request names, the problem type they share, and the resolution approaches it calls for | GATE:HYPOTHESIS |
| `## Acceptance criteria` | a table with the fixed columns `AC id \| criterion \| source`: `AC id` a short readable name unique within the issue, `criterion` the issue's criterion restated faithfully, `source` its place in the issue body | criteria-apply |
| `## Referenced materials` | each material the issue or a criterion references, as *What the analysis owes* says, or `none` | the design module |
| `## Necessity` | whether the issue is a bug / incident; per resolution approach, the behavior gap and whether code is the lever, with grounds; and the conclusion, exactly one of `no change needed` (the as-is already satisfies the request, or nothing is left to do), `non-code lever` (a real gap whose lever is data / configuration / operations) or `code change` | GATE:HYPOTHESIS |
| `## Cause` | where the request reports a defect, the cause the analysis established and the evidence for it, how far the cause was pursued and why — or, where it is not established, what is known and what was left unchecked; otherwise `none` with the reason | GATE:HYPOTHESIS |
| `## Scope judgments` | each scope judgment, as *What the analysis owes* says | the design module; GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Affected documents` | the documents the change is expected to update | the design and build modules |
| `## Decision points` | each decision point with its decision and grounds — for one put to the advisor, the advisor's decision and its ledger entry — or `none` | the design module |

Anything else the module records is its own, written where it judges useful.

## Evaluation — GATE:HYPOTHESIS

The hypothesis module scores the report: one independent Evaluation AI (`autoflow-evaluator`),
fresh-spawned per run on the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-hypothesis` names, on the
rubric of [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:HYPOTHESIS — one
form for every issue. Its agent definition carries that document, and its output is the scores and
their grounds with its recommendations.

## Spot-check & escalation discipline (incomplete-output guard)

A spot-check is a read that confirms a finding of a module's output — the analysis report or any
other — before it feeds a decision, a blocker, or a harness-level block. A Claude
Code behavior produces a **false "absent / stub" reading**:

- **Read-dedup stub.** A re-read of an unchanged file returns a 1-line stub ("file
  unchanged … refer to that earlier tool_result"), and the dedup ledger is not reset on a
  rewind (or a compaction). The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags this
  at runtime — these rules are the procedure it points to.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a decision or a
  harness-level block**. A single read is never sufficient grounds.
- **[MUST]** A blocker-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool.
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged`). It is a harness stub, not
  data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after the spawn has returned**, as single
  sequential commands. Another
  directory is addressed with `git -C <path>` + absolute paths rather than a
  `cd`-prefixed compound, which can raise a permission prompt.
