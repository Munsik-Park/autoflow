# Evaluation System

> This document is the Evaluation AI's and the procedure of the four evaluation modules —
> hypothesis, plan, audit and quality, each with its contract
> `<autoflow-root>/docs/contracts/<module>.json`: the standard the evaluator evaluates by, its
> conduct, every gate's rubric — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — with the
> reference values set on its scale, and the output it returns. The evaluator's agent definition carries it and the sections it names for every gate
> (*The evaluator's standard* > *What it reads*). An evaluation outputs its scores, their grounds
> and its recommendations, with the reference values
> ([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D6).

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before
it reaches human review. The agent that wrote the work never evaluates it.

### Critical Rule: Fresh Spawn Every Time

The Evaluation AI must be **spawned fresh for every evaluation** — at
GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY. It carries no prior
conversation history. This is mandatory.

---

## The evaluator's standard

This section is the rule's only home. Its search terms:

```
git grep -n -i -E "evaluator's standard|\*What it reads\*|proportional depth|confirmed enough"
```

A functional module is prescribed by its goal and its contract, and how it reaches the goal is its
own ([`core.md`](core.md) > Rule Scope, principle 2;
[ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D1). That latitude does
not extend to the evaluator: what it confirms, the evidence a confirmation rests on and how far it
goes are set here, and the evaluator applies them.

### What it reads

- **[MUST]** The gate's **input set**: the inputs its invocation names, as the evaluation module's
  contract declares them (`<autoflow-root>/docs/contracts/<module>.json` > `inputs`; the gate's **Input** line in *Gate
  rubrics* below), the change under evaluation, and the sections the table below names — the
  contract of the artifact it scores. The agent definition carries this document and the sections
  of every row; the gate's row is its input set. Another document is read only at the section this
  document cites for the item being scored, never whole.

  | Gate | Artifact-contract sections |
  |---|---|
  | GATE:HYPOTHESIS | [U2 Analysis](units/analysis.md) > *What the analysis owes*, *Analysis report* |
  | GATE:PLAN | [U3 Design](units/design.md) > *Output artifacts* (with *Test necessity* and *Verification depth*) |
  | AUDIT | [U4 Build and verify](units/build.md) > *What the build owes* (its *Test-first* bullet), *Build report* |
  | GATE:QUALITY | [U4 Build and verify](units/build.md) > *Build report*; [U3 Design](units/design.md) > *Output artifacts* |

- A unit document's other sections are not read.
- What lies outside the input set — the gate hook, the spawn policy, another gate's rubric and its
  row's sections (which the definition carries), the records of an earlier run the invocation does
  not name — is read only when the change under evaluation modifies it.

### What it confirms

- **[MUST]** Each rubric item of the gate, against the input set. A claim the artifact makes is
  confirmed at its anchor, not taken from the artifact's own account of it (*Pre-scoring FAIL
  hypothesis* below).
- A re-score — a run given the previous evaluation (`previous_evaluation`) — confirms the items in
  `rescore.rescored` and the anchors they rest on; an inherited item is checked only for whether
  the change since the previous evaluation touched its anchors, and is otherwise not re-read
  (*Evaluator conduct* > *Re-score* below).

### Evidence

- **[MUST]** A confirmation is an anchor the evaluator read itself: a `path:line` read at the
  evaluated commit, a commit read with `git show`, a suite verdict resolved as *Execution
  discipline* below sets, an observation record and the artifacts it cites.
- **[MUST]** A finding states its failure precondition and the evidence that the precondition is
  reachable: an input the system accepts, a configuration it supports, a procedure the rules
  prescribe. A case that needs an input the rules forbid, a state no accepted path produces, or a
  constraint a gate or hook enforces switched off, is not a finding.
- A suspected defect whose evidence stays weak after tracing is reported at the `Low Confidence`
  level with what would confirm it (*Finding coverage* below).

### Depth

- An item is **confirmed enough** when its score's reason rests on an anchor read under *Evidence*
  and its FAIL hypothesis has been searched and dispositioned; the search on that item stops there.
  A defect on it that the evaluator sees afterwards is still reported and scored (*Finding
  coverage* below).
- A repeated surface is sampled, and the whole evaluation runs under a time cap (*Execution
  discipline* below).

### Proportional depth

Depth scales with the size and the risk of the change under evaluation.

- **Fixed at every size**: every rubric item scored with its reason, the FAIL hypothesis formed and
  dispositioned, every found issue reported (*Finding coverage*), every suite-verdict anchor resolved
  (*Execution discipline*), and the gate's named checks — test-first at AUDIT, the ADR-conformance
  and AC-authority checks, GATE:QUALITY's known blind-spot checks.
- **Scaled**: how far beyond the anchors the items rest on the evaluator re-derives, how far it
  traces adjacent code and documents, and how large a sample it takes.
  - A small, local change — a few lines in a few files, touching no state another component reads,
    no contract and no authority rule — gets a **lightweight pass**: the diff, the inputs the
    rubric items name, and one sampled instance per item.
  - A large change, one that crosses a repository or component boundary, or one that touches shared
    state, a contract, a gate or an authority rule gets the full depth: adjacent code and failure
    paths traced, the sample widened on a hit.
- The evaluator states the size it judged, with its ground.

---

## Two quality procedures

A change passes two independent quality procedures, and neither stands in for the other.

- **The gate evaluator** (this document) judges each unit's artifacts against its gate's rubric —
  the analysis, the design and its verification, test-first and the build's records, the completed
  change against the acceptance criteria and the cycle's scope — and scores them; its scores, read
  against the reference values (*PASS Criteria* below), are the evaluation's result.
- **The reviewers** (`<autoflow-root>/docs/review/review.md`; [U7 Review](units/review.md) > *Reviewer review*)
  review each pull request the cycle opened — its diff against the linked acceptance criteria —
  for defects in the result, and the aggregation of their reviews is one verdict per pull request.
- An evaluation that meets the reference values does not clear a reviewer finding, and a clean
  review does not stand in for an evaluation.

---

## 10-Point Scale

| Score | Meaning |
|-------|---------|
| 9-10  | Excellent |
| 7-8   | Good      |
| 5-6   | Insufficient |
| 3-4   | Poor      |
| 1-2   | Failing   |

---

## PASS Criteria

AutoFlow provides these reference values with the rubrics, on the scale above; each evaluation
contract carries them (`<autoflow-root>/docs/contracts/<module>.json` > `reference`), and an
evaluation outputs them with its scores
([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D6):

- average ≥ 7.5;
- each item ≥ 7;
- a `Security` item at 3 or below → rework (GATE:PLAN, GATE:QUALITY).

---

## Evaluation Types

The items each evaluation scores, one `scores` key per item. `<autoflow-root>/scripts/contracts/contract.sh lint`
checks that the `Contract` column's evaluation contract holds exactly these score keys.

| Evaluation | Gate | Contract | Items |
|------------|------|----------|-------|
| Analysis evaluation | GATE:HYPOTHESIS | `hypothesis` | Conclusion grounds, Goal coverage |
| Plan evaluation | GATE:PLAN | `plan` | Decision grounds, Verification fit, Scope, Security |
| Security audit | AUDIT | `audit` | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies |
| Quality evaluation | GATE:QUALITY | `quality` | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates |
| Doc evaluation | — | — | Accuracy, Completeness, Clarity, Format compliance |

What each item is scored by is the gate's rubric (*Gate rubrics* below). The category sets and
weights should be customised per project. As patterns emerge, humans adjust the criteria.

---

## Evaluator conduct

These subsections bind every rubric-scored gate unless one names its gate.

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list each in `recommendations`. Each finding states its severity and confidence on its own item (the next bullet) and is reflected in the `score` and `reason`; a finding that lowers an item is stated in that item's `reason`, and a finding is never expressed by silently omitting it. The rubric score is the filter; the finding stage prioritizes coverage.
- **[MUST]** Write each `recommendations` item as the object *Evaluation Output Format* below defines, its severity included.

### Pre-scoring FAIL hypothesis (consider-the-opposite)

This subsection binds **every rubric-scored gate** — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY — and the doc-evaluation form when one is run, as a shared Evaluation AI contract. No gate opts out.

- **[MUST]** Form the FAIL hypothesis first: adopt the hypothesis **"this deliverable must FAIL"** and search for the strongest evidence supporting it, framed in the terms of this evaluation's own rubric items. The search re-derives the deliverable's cited anchors from the current source (`path:line`, command output, `git show HEAD:<file>`) rather than accepting the deliverable's own account of them.
- **[MUST]** Attempt to refute each FAIL case found. A refuted case does not affect the score. A case that survives refutation is carried into the affected item's `reason` and listed in `recommendations`. A surviving case may coexist with a score of 7 or higher: the obligation is to record it, not to lower the item.
- **[MUST]** Assign scores only after the FAIL hypothesis has been formed, searched, and dispositioned. Scoring never precedes the search.
- **[MUST] Re-score form**. On a re-score (*Re-score* below), the hypothesis for each item in `rescore.rescored` is **"the previously flagged defect still remains"**, searched against the change since the previous evaluation and that evaluation's finding for the item; each prior finding is dispositioned `cleared` / `remains` in `rescore.prior_findings`. A prior finding answered by a rebuttal instead of a fix ([`units/review.md`](units/review.md) > *Whether a finding holds*) is searched the same way, against the artifact as it stands and the rebuttal's grounds: `cleared` when the rebuttal holds, `remains` when the finding does. The hypothesis is not "this Nth remedy must FAIL": a defect newly seen on a re-scored item — including one in the text the remedy wrote — is still surfaced (Finding coverage above), and the evaluator judges whether it lowers the item: one that does is scored under its item and stated in its `reason`, one that does not is listed in `recommendations` and does not lower the item. The independence rules are untouched — the spawn is fresh and the search still re-derives anchors.

### Re-score (a run given the previous evaluation)

A run given the previous evaluation of the same gate (`previous_evaluation`) is a re-score. Its
spawn is fresh like any other; its input is narrowed, not its independence.

- **[MUST]** Score afresh the items listed in `rescore.rescored` — each item the previous evaluation
  scored below 7 or recorded a finding under, and each item whose anchors the change since that
  evaluation touched (each gate's *Re-entry re-score* below names what that change is) — and list
  every other item in `rescore.inherited`, its score copied from the previous evaluation. Every
  rubric item is in exactly one of the two lists.
- **[MUST]** Give every finding of the previous evaluation's `recommendations` its entry in
  `rescore.prior_findings`, by the finding's own text, with its disposition — `cleared` or `remains`
  — and its ground (*Re-score form* above). A finding on an inherited item `remains`, its ground the
  inheritance.

### Build observations (GATE:QUALITY input)

Binds the GATE:QUALITY form only.

- **[MUST]** Read the build report's `## Out-of-scope observations — guard / boundary logic touched` section, disposition every entry (`defect — scored under <item>` or `not a defect — <reason>`), and record the dispositions in the `refine_observations` output field. A `defect` entry is scored under `Quality` or `Impact scope`. The author's rejection reason is context, not the disposition.

### Scope judgments (GATE:PLAN / GATE:QUALITY)

The cycle's scope is its acceptance criteria, its confirmed cause, and the problems its recorded scope judgments include ([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Scope judgment*).

- **[MUST]** Score scope against those records, not against acceptance-criterion IDs alone. At GATE:PLAN, `Scope` reads the scope the feature design states. At GATE:QUALITY, `Minimal implementation` and `Impact scope` read that scope, every `## Scope judgments` section in the reports the evaluation is given, and the recommendations deferred or separated after earlier evaluations (`deferred`).
- A hunk that rests on a recorded judgment is in scope when the judgment meets one of question 1's three conditions; a judgment that meets none is scored under `Minimal implementation`. A directly related problem the records show, left out with no separation reason or with one that answers neither half of question 2, is scored under `Impact scope` (GATE:PLAN: `Scope`).
- A separation reason is judged for whether it answers question 2, not for whether the evaluator would have separated the problem.

### Code comments in a target (GATE:QUALITY)

Binds the GATE:QUALITY form over a target's code. This repository is excluded: a comment here is
scored under the ordinary items.

- **[MUST]** A code comment carries only a sentence that stays true for as long as the code it sits
  on is unchanged. **A comment that diverges from its code, or that carries what a comment does not
  carry, is a `Low` finding** — a restatement of the code, a design ground, an acceptance-criterion,
  issue or PR reference, another file's path or contract, a change history, or content none of the
  cases a comment carries admits ([`submodule-common-rules.md`](submodule-common-rules.md) > Change
  Surface Rules > *Code comments*), such as a value, count or list copied from another file. Record
  it in `recommendations` with its `path:line` and the severity `Low`; it lowers no item's score.
  Whether and where it is fixed is the judgment of the AI acting on it.
  Only that finding is `Low`: a defect a comment carries on its own ground — an exposed credential,
  token or personal data, for example — is scored under the item its impact belongs to, with that
  item's usual cap.
- A line a tool reads to change its behavior — a lint suppression, a type-checker directive — is
  code even in comment syntax: a defect in it is scored under the item its behavior belongs to, not
  by this rule. An explanation written beside it is a comment.
- `Minimal implementation` weighs the comments the change adds by content and by volume — the build
  report's `## Comment check` section, its `comment-ratio` line included, with the comments in the
  diff — and records a content or volume finding in its `reason` and in `recommendations` without
  lowering its score ([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface
  Rules > GATE:QUALITY linkage).

### Execution discipline (scope, sampling, time)

This subsection **constrains** the pre-scoring FAIL hypothesis above; it does not replace it. The
evaluator still forms the hypothesis first, still re-derives anchors, and still dispositions what it
finds.

- **[MUST] Resolve the anchor before executing.** Where the anchor being re-derived is a **suite
  verdict** (a test run's pass or fail), the anchor is the recorded local run — the command, the
  log it wrote and the summary line read from it (Reporting Format > *Evidence anchor*) — and the evaluator confirms it by reading that line
  at the cited log path, never by re-running the command; a log absent at its path makes the row
  `not-run` (GATE:QUALITY > *Known blind-spot checks* > *Test coverage* > *Execution omission is
  not a defect* below), and a log that does not carry the line is evidence authored without a
  run (*Test quality / Completeness*). An unresolved anchor is a report defect, not an input.
  Nothing is cited from a host record in place of a run's log.
- **[MUST] Sampling default.** A blind-spot search over a **repeated surface** takes a
  representative sample per rubric item by default (one or two instances), and states the sample
  basis. Exhaustive enumeration is entered only when a sampled instance yields
  a FAIL case that survives refutation — escalate on a hit, rather than enumerate by default.
  Coverage of *finding types* is unaffected: the finding-coverage rule above still forbids dropping
  a found issue.
- **[MUST] Time cap.** An evaluation declares a **wall-clock cap** and reports against it. The cap
  is **30 minutes** unless the evaluator's instruction declares a different value, in which case
  the declared value governs and is reported. On reaching the cap the evaluator stops searching,
  scores what it searched, and states every unsearched item as not searched — **never as clean**:
  an item whose search was not finished has thin evidence, not a clean one.

---

## Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY

The rubric each gate scores on. Each gate is an evaluation module of its own, separate from the
work it evaluates ([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D1):
GATE:HYPOTHESIS evaluates the analysis, GATE:PLAN the design, AUDIT the build, and GATE:QUALITY the
completed change. Each gate's section below is its contract's `procedure`. Every gate is scored by
an Evaluation AI, never by the agent that did the work, so its rubric lives here, in the
evaluator's own document, and not in the work's.

### GATE:HYPOTHESIS

It scores what the analysis report shows, never the method the unit took to produce it (ADR-0025
D2).

**Evaluator**: one independent Evaluation AI, fresh-spawned per run. It scores one form for
every issue — bug / incident or not, code or documentation — and returns one output object
(*Evaluation Output Format* below).
**Input** (`<autoflow-root>/docs/contracts/hypothesis.json`): the analysis report (`analysis`), the
`[ac-decision]` entries when there are any (`decisions`), and on a re-score the previous evaluation
(`previous_evaluation`); the evaluator reads the anchors in the target the report cites.

The form answers one question: **is the report's conclusion supported by its grounds, and did the
analysis reach its goal?** The request and the as-is are the ones the report states
([U2 Analysis](units/analysis.md) > *What the analysis owes*); they are grounds like any other, and
the evaluator reads them against the trigger target and the branch it finds. The form scores whether the
conclusion holds, never which way it points: a well-grounded `no change needed` or `non-code lever`
scores as high as a well-grounded `code change`. Nor does it score how
the analysis was done — how many explanations it weighed or which checks it ran — only whether what
the report concludes is shown. It is reuse-neutral: a resolution that reuses existing code is not
marked down. Plan feasibility, structural fit and over-engineering are GATE:PLAN's (Decision
grounds, Scope) and GATE:QUALITY's (Minimal implementation, Fit).

| Item | Criterion |
|------|-----------|
| Conclusion grounds | Does the evidence the report cites — re-derived from the source, not taken from the report's account — support its conclusion: the current structure as stated, the gap, whether a change is owed and whether code is the lever, and, where the request reports a defect, the cause? A conclusion that a code change is required where the cause it rests on is not established, or where data, configuration, the environment or an earlier fix is not ruled out on evidence, scores low here. |
| Goal coverage | Does the report answer everything the analysis owes ([U2 Analysis](units/analysis.md) > *What the analysis owes*, *Analysis report*) — the gap per resolution approach, the lever, the conclusion, the acceptance-criterion table, the referenced materials, the scope judgments and the decision points — for the whole request, not a part of it? |

**Reference values**: each ≥ 7, average ≥ 7.5 (*PASS Criteria* above).

#### Re-entry re-score

Given the previous evaluation, the gate re-scores as *Evaluator conduct* > *Re-score* above sets;
the change since that evaluation is the sections of the analysis report a later run changed.

### GATE:PLAN

**Evaluator**: fresh-spawned Evaluation AI.
**Input** (`<autoflow-root>/docs/contracts/plan.json`): the two documents the design wrote
([U3 Design](units/design.md) > *Output artifacts*) — the feature design (`feature_design`) and the
verification design (`verification_design`) —, the applied acceptance criteria
(`applied_criteria`, the criteria-apply module's output), the `[ac-decision]` entries when there
are any (`decisions`), and on a re-score the previous evaluation (`previous_evaluation`).

The gate scores the design's **intent** — whether each decision is grounded, whether each
criterion's verification fits it and whether the scope is right —
never the method by which the unit reached it: no item asks which roles took part, whether a
dialogue was held, or in what order the documents were written (ADR-0025 D2).

#### Scoring (4 items × 10 points)

| Item | Criterion |
|------|-----------|
| Decision grounds | Is each architecture decision grounded in the actual mechanisms it changes (not a misread), with the constraints it holds under and the alternatives it rejected, each rejection with its ground? Can the design be implemented with the current structure? |
| Verification fit | Does each verification-design row verify the property of the item it names, not a weaker or different proposition, by a method that can fail when that property does not hold? Where the design changes shared state — state that outlives a single call and that more than one decision reads or writes — that a settled decision (a governing ADR, a prior issue's agreed design, an entry in this issue's ledger) also names, does at least one verification drive that contact through the real execution environment rather than a double, or does the design state a design-change request because none can be built? |
| Scope         | Appropriate — not too broad, not missing requirements? (no redundant new mechanism where an extension suffices — over-engineering fails here; the feature design's `## Scope` section judges each problem the confirmed cause carries under Change Surface Rules > *Scope judgment*, and a directly related problem left out owes a separation reason) |
| Security      | Any security implications introduced? |

**Affected files and side effects are not scored here**. The gate scores the
*decision* layer; which files a change touches and which tests it requires are **derived**, not
predicted — by the build, from the change delta and the way the
target runs its tests, and from the files it opens anyway. A dependency miss surfaces at the build
or in CI.

`Decision grounds` and `Scope` absorb the structural-fit concern that GATE:HYPOTHESIS deliberately does not score: a plan not grounded in the actual structure fails Decision grounds; a plan **or its verification design** that duplicates an existing mechanism or over-engineers a new one where an extension suffices fails Scope — the over-engineering half applies symmetrically to both, so a verification that can fail on no defect another verification in the design, or a named existing mechanism, would not already catch fails Scope on the same clause.

#### ADR-conformance check (scored within Decision grounds / Scope)

This named check makes the ADR-conformance concern explicit inside the two items that already absorb structural fit — it adds **no scored item** and changes **no reference value**; a violation caps the named item at 6, below the each-item reference value (identical mechanism to GATE:QUALITY's *Known blind-spot checks* below). A **governing ADR** for the change surface is an ADR in the repository's ADR directory (`docs/records/adr/` in this repository; a consuming target's own ADR location) with status `Accepted`/`Proposed` whose Decision scope intersects the change surface, **or** a change hitting a **trigger area** of `<autoflow-root>/docs/development-guideline.md` > ADR Policy > *When to create an ADR* — the list is defined there, in a shipped usage document, and nowhere else.

- **Trigger → cap**: divergence from a governing ADR, **or** an architecture-impacting change with no governing ADR/owner decision → cap.
- **Per-item cap distribution**: `Decision grounds` caps on a structural-grounding divergence (the plan is not grounded in the ADR's decided structure); `Scope` caps on a redundant-mechanism / boundary divergence **or** the undocumented-ADR trigger; **both** cap when both defects are present. One divergence never leaves both items uncapped.
- **N/A by default**: no governing ADR's Decision scope intersects **and** no trigger area is hit → the check does not apply, no cap, the item scores normally.

#### Re-entry re-score

Given the previous evaluation, the gate re-scores as *Evaluator conduct* > *Re-score* above sets.
The change since that evaluation is the design documents' **delta sections** — the
`## Delta — round <n>` sections a later design run appended; the evaluator reads them and the
anchors of every item it re-scores.

A run with no previous evaluation scores both documents whole; the narrowing binds re-scores only.

### AUDIT

A project-specific security audit of the change the build made, after a test-first judgment on
its evidence. Complements GATE:QUALITY's `Security` item with 5 dedicated, project-specific items;
GATE:QUALITY's `Security` item references the AUDIT result.

**Evaluator**: fresh-spawned Evaluation AI.
**Input** (`<autoflow-root>/docs/contracts/audit.json`): the change — the build's commits, as a
range (`commits`) —, the build report (`build_report`), the verification design
(`verification_design`), the target's security checklist at the version *Security checklist* below
names, when the target declares one (`security_checklist`), and on a re-score the previous
evaluation (`previous_evaluation`).

#### Test-first

Judged before scoring. The goal: a test that verifies a required behavior is seen failing before
the implementation it verifies ([U4 Build and verify](units/build.md) > *What the build owes* >
*Test-first*). For each such test the build report's `## Test-first` record names, the evaluator
reads the evidence it cites and judges whether the failing run precedes the implementation commit
and its failure is shown by its log. It finds that evidence where this project's composition puts
it, and records in the output's `test_first` what it read for each test and what it found —
`confirmed: true` when every test's failing run is shown before its implementation, `false` with
what is missing or contradicts the record. When it is not confirmed the evaluator scores nothing:
the output carries `test_first`, the summary and the findings.

#### Security checklist

AutoFlow ships no checklist and names no item: AutoFlow owns how AUDIT scores — the fresh
evaluator, the five items below, the reference values — and the target owns what each item is
judged by. Which version AUDIT reads is the one the record line of
`bash <autoflow-root>/scripts/gate/security-checklist.sh status --base origin/<base> --ledger <attempt-dir>/issue-{N}-ledger.md`
names, `<base>` the branch the pull request merges into. The audit takes the checklist at that
version (`git show <score>`), written to a file, as its `security_checklist` input:

- `none-declared` → no checklist: the five items are scored from the change alone, and the output
  says that none was declared;
- `unchanged` → the checklist as of the base commit (`score=<base>:<path>`);
- `changed-decided` → the changed version a `[checklist-decision]` entry accepted
  (`score=HEAD:<path>`, or `none` for a dropped declaration).

**The evaluator reads the version it is given**, never the working-tree file, and states in its
`summary` which checklist version it scored against.

#### Report

The output is the evaluation object (*Evaluation Output Format* below) with its `test_first` key
(*Test-first* above); each `Low` finding is a `recommendations` item with its `path:line` at the
audited commit.

#### Re-entry re-score

Given the previous evaluation, the evaluator re-scores as *Evaluator conduct* > *Re-score* above
sets and does not re-derive the whole audit. The change since that evaluation is the commits made
after the ones it audited: it judges test-first for the tests that change added or rewrote,
re-scores that change against the checklist, re-checks each prior finding only where that change
touches its file, and inherits the rest.

#### Scoring (5 items × 10 points)

Items adapt to the project's threat surface; defaults below. The target's checklist is what each
item is judged by; with none declared, the criteria below are the whole of it.

| Item | Criterion |
|------|-----------|
| Authn/Authz       | Are auth flows on changed endpoints complete? |
| Input validation  | Are external inputs (queries, parameters, payloads) validated/escaped? |
| Data exposure     | Are tokens / passwords / PII kept out of logs and responses? |
| Infra isolation   | Are internal ports/services not exposed externally? |
| Dependencies      | No known vulnerabilities in changed external dependencies? |

### GATE:QUALITY

**Evaluator**: fresh-spawned Evaluation AI.
**Input** (`<autoflow-root>/docs/contracts/quality.json`): the change — the build's commits, as a
range (`commits`) — and the work's outputs:

- the applied acceptance criteria (`applied_criteria`, the criteria-apply module's output);
- the analysis report (`analysis`): its `## Scope judgments`;
- the two design documents: the feature design (`feature_design`) — the decisions the change is
  checked against, and the scope it states — and the verification design
  (`verification_design`);
- the build report (`build_report` — [U4 Build and verify](units/build.md) > Build report): its run
  record, manual checklist, maintained documents and lint record, its `## Scope judgments`, section
  `## Out-of-scope observations — guard / boundary logic touched`, and — on a target — section
  `## Comment check`;
- the AUDIT evaluation (`audit_evaluation`);
- the recommendations deferred or separated after earlier evaluations, when there are any
  (`deferred`);
- the `[ac-decision]` entries when there are any (`decisions`), and on a re-score the previous
  evaluation (`previous_evaluation`).

The cycle's scope records are the scope the feature design states, every
`## Scope judgments` section in the reports above, and the deferred or separated recommendations
([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Scope judgment*).

The build report's out-of-scope-observations section is scoring input (*Evaluator conduct* >
*Build observations* above).

#### Scoring (10 items × 10 points)

Completeness, Quality, Test coverage, Test quality, Security (references AUDIT),
Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates.

The `Minimal implementation` item is scored against [`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > GATE:QUALITY linkage, which holds the criterion body and the positive criteria the item is scored by.
Guiding rule: prefer the smallest sufficient change that resolves the confirmed problem within the cycle's scope — the acceptance criteria, the confirmed cause, and the problems the cycle's recorded scope judgments include.
A hunk tracing to none of them fails this item regardless of code quality, and so does a change too narrow to resolve the confirmed cause.
`Impact scope` is scored against the same section and the same scope from the other side: a directly related problem the cycle's records show, left out with no recorded separation reason, lowers it.
On a target the item also weighs the comments the change adds, by content and by volume — the volume judged qualitatively from the build report's `comment-ratio` and the diff, with no threshold — and records what it finds in its `reason` and `recommendations` without lowering its score (the same linkage section, *Comments in a target's code*; *Evaluator conduct* > *Code comments in a target* above).

The build report's records are the subject of three items. `Test coverage` reads `## Run record` and
`## Manual checklist` (*Test coverage — the run record is the subject* below). `Doc updates` reads
`## Maintained documents` against the diff: a listed document the diff does not touch is a finding
of the item. `Commit conventions` reads `## Lint` for every commit of the change against the
outcome vocabulary and its reason classes
([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on
the staged surface*): a chain `detected` is a finding of the
item, a `not-run (ci-deferred)` chain is cleared as a deferral, and a commit with no lint record or a
chain `not-run (unexecuted)` is an omission that takes the omission path under `Test coverage` below.

#### Known blind-spot checks (scored within existing items)

The evaluator applies the checks below **inside the existing 10 items** — they add no scored items and change no
reference value. Each violation caps the named item at 6, below the each-item reference value:

- **Test quality — mock-boundary fidelity**: sample the suite's test doubles and verify
  each against the real interface at HEAD (signature, argument count, return shape).
  A double that diverges from the real interface caps `Test quality` at 6.
- **Test quality / Completeness — assertion-claim alignment**: for each AC, confirm the
  test asserts the behavior the AC states, not a weaker proxy (e.g. "the function was
  called" where the AC requires a result shape) and not a different property than the
  one the AC it names states. Confirm every cited evidence line
  (test summary, log excerpt) against the log the cited run left, resolved as *Execution
  discipline* above sets; a recorded line the log does not carry was authored, not
  produced by a run, and caps the citing item at 6. A record with no log behind it is not a
  fabricated line but a missing run: it takes the `Test coverage` omission path below, not this
  cap ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *A run's evidence is the log it left*). For an
  observation record, confirm that the result was compared against the material the AC names — the
  referenced mockup, asset or document itself; a comparison against the issue body's abbreviated
  example, or a check that the result merely renders, is a weaker proxy.
- **Impact scope / Doc updates — reference integrity on moves**: when the diff relocates
  or renames files, sections, or identifiers, require evidence of a repo-wide
  inbound-reference sweep (direct references, test-harness expectations, paraphrased
  mentions). A dangling reference in a **normative document** caps the affected item at 6.
  The cap binds normative documents only; a stale name in a **historical record** is the
  evaluator's judgment.
  - *Normative documents* — the one definition, cited from everywhere else — are what an agent
    or the operator reads and follows in a phase, what executes, and what is delivered: (a) the
    rules, unit documents, role contracts, evaluation criteria and agent definitions a phase loads
    (`CLAUDE.md`, `<autoflow-root>/docs/core.md`, `<autoflow-root>/docs/autoflow-guide.md`, `<autoflow-root>/docs/units/*`, `<autoflow-root>/docs/role-contracts.md`,
    `<autoflow-root>/docs/role-common-rules.md`, `<autoflow-root>/docs/submodule-common-rules.md`, `<autoflow-root>/docs/evaluation-system.md`,
    `<autoflow-root>/agents/*`, and the sections of an ADR that state a decision still in force);
    (b) the scripts, hooks and workflows that run; (c) every document the plugin delivers for a
    role to read — the command bodies under `<autoflow-root>/skills/` and the usage documents
    `<autoflow-root>/docs/INDEX.md` routes, outside the records under `<autoflow-root>/docs/records/`.
  - *Historical records* are what is kept as a record of a past state and followed by no one:
    per-issue manual-verification records, report-excerpt fixtures
    (`tests/fixtures/*`), an ADR's change-history and superseded sections, and completed attempts'
    records. A fixture that an executing test reads is still a historical record for this check,
    while the test that reads it is normative.
  - For a stale name in a historical record the evaluator judges whether a reader following the
    normative documents would be misled by it, and records the judgment with its grounds in the
    item's `reason` (and in `recommendations` when it does not lower the score). A score reduction
    rests on that recorded ground alone, never on the name's presence; a record whose stale names
    mislead no one is left as it is, and rewriting it is not a remedy the evaluator asks for.
- **Test quality — test files kept in a target**: on a target, a test file the change added to
  the target's tree is judged by the reviewer against the target's convention from the PR body's
  listing ([U6 Delivery](units/delivery.md) > *Push and pull request*;
  [`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *What a cycle
  leaves in the target's tree*); under this item the evaluator confirms that every such file
  carries, in the build report's `## Test files kept` section, the reason it is kept and the CI job
  expected to run it — the record the PR body carries — and an added file with no such record caps
  `Test quality` at 6.
- **Test coverage — the run record is the subject**: the item's subject is not a CI result. For
  each verification-design row verified by a run it is the row's recorded run — the command, the
  log and the summary line read from it, resolved as *Execution discipline* above sets. For a row
  the AI verified by observation it is the row's observation record
  ([U4 Build and verify](units/build.md) > Build report > `## Manual checklist`), confirmed by
  reading the record and opening the artifacts it cites — a screenshot is read as an image — never by observing again;
  a row with no record, or a record whose artifacts are absent, takes the omission path below.
  - **Execution omission is not a defect** ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *A missing run
    is filled where it is found*). A row with no run record — or with no log behind it — is `not-run`, and the evaluator does
    **not** score `Test coverage` over it: the item keeps its key in `scores`, and its value names
    the rows that were not run in place of a score — `{"not_run": ["<row>", …]}` (a lint omission
    under `Commit conventions` is recorded the same way, with the commits and chains not run). Once each named row has been run and its record filled
    in, a re-score scores the withheld item only, in the *Re-entry re-score* form below with this
    output as the previous evaluation. A recorded run that **fails** is a defect, scored like any
    other.
- **Fit — ADR conformance**: on the final change set, re-confirm the shipped change conforms to any governing ADR (same
  governing-ADR / trigger-area / N/A definition as the GATE:PLAN ADR-conformance check; the
  trigger areas are `<autoflow-root>/docs/development-guideline.md` > ADR Policy > *When to create an ADR*). A
  divergence from a governing ADR, or an architecture-impacting change with no governing
  ADR/owner decision, caps Fit at 6.
- **Completeness — AC-authority check**: the backstop for acceptance-criterion drift introduced
  **after** the design — a test the build rewrote after its first run, or the satisfiable-subset
  implementation [U4 Build and verify](units/build.md) permits on a design contradiction. The check
  is a **name-the-site obligation**: for each applied criterion
  (`applied_criteria`), the evaluator names the test file and assertion, or the implementation
  site, that discharges it. A criterion for which no site can be named caps `Completeness` at 6; a
  criterion an `[ac-decision]` entry changed reaches the evaluation already applied, so it is owed
  its site as it stands there. **Derivation is not drift**: a file row, suite disposition or oracle
  condition clause the build derived under the design's layer split
  ([U3 Design](units/design.md) > *Output artifacts* item 1) is the designed division of labour,
  never an acceptance-criterion change.

#### Re-entry re-score

Given the previous evaluation, GATE:QUALITY re-scores as *Evaluator conduct* > *Re-score* above
sets. The change since that evaluation is the commits made after the ones it evaluated; an item
whose anchor files they touch is re-scored.

**The re-score's subject is the previously flagged defect**. The fresh evaluator's FAIL hypothesis
on a re-scored item is *"the flagged defect still remains"*, searched against that change
(*Evaluator conduct* > *Pre-scoring FAIL hypothesis* > *Re-score form* above); each prior finding
is dispositioned `cleared` / `remains` in `rescore.prior_findings`. A defect the evaluator newly
sees on a re-scored item — including one in the sentences the remedy itself wrote — is recorded per
*Finding coverage*, and the evaluator judges whether it lowers the item: one that does is scored
under its item and stated in its `reason`; one that does not is listed in `recommendations` and does
not lower the item.

---

## Evaluation Output Format

The evaluator writes one JSON object to `<out>/evaluation.json`, in the output directory its prompt
names
([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D3). The keys are the
evaluation contract's (`<autoflow-root>/docs/contracts/<module>.json` > `outputs.evaluation`), with
`test_first` at AUDIT and `refine_observations` at GATE:QUALITY:

```json
{
  "type": "hypothesis_evaluation | plan_evaluation | security_audit | quality_evaluation | doc_evaluation",
  "issue": "#N",
  "test_first": { "confirmed": true, "read": ["<test — the record and the log read, and what they show>"] },
  "scores": { "<item>": { "score": 8, "reason": "evidence" } },
  "rescore": {
    "rescored": ["<item>"], "inherited": ["<item>"],
    "prior_findings": [ { "finding": "<the previous evaluation's finding>", "disposition": "cleared | remains", "ground": "<path:line at <commit SHA> / command + log path + summary line>" } ]
  },
  "refine_observations": [ { "entry": "<suggestion @ path:line at <commit SHA>>", "disposition": "defect — scored under <item> | not a defect — <reason>" } ],
  "summary": "overall assessment",
  "recommendations": [ { "subject": "<evaluated artifact path:line at <commit SHA> | evaluated artifact section | criterion id, for a criterion defect>", "item": "<rubric item>", "severity": "<level — <autoflow-root>/docs/review/review.md > Severity>", "finding": "<the finding>" } ]
}
```

The output carries the scores and their grounds; the reference values they are read against are
*PASS Criteria* above.

`scores` holds one entry per rubric item of the evaluated gate, keyed by the item's name
(*Evaluation Types* above). Each value is either a number (`8`) or an object
(`{"score": 8, "reason": "..."}`), the score on the 10-point scale; an item whose subject was not
run carries `{"not_run": [...]}` in its place (*Gate rubrics* > GATE:QUALITY > *Known blind-spot
checks* > *Test coverage*). At AUDIT, `scores` is given only
when `test_first.confirmed` is true (*Gate rubrics* > AUDIT > *Test-first* above).

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `rescore` | object | **on a re-score** — a run given the previous evaluation (absent otherwise) | `rescored` — the items scored afresh; `inherited` — the items whose score is copied from the previous evaluation. Every rubric item appears in exactly one of the two lists. `prior_findings` — one entry per finding in the previous evaluation's `recommendations`, its `finding` the previous text verbatim, with its `disposition` `cleared` or `remains` and the ground re-derived from the change since — for a rebutted finding, from the rebuttal's grounds at the evaluated commit (*Evaluator conduct* > *Re-score* above). |

`refine_observations` (GATE:QUALITY only) records the evaluator's disposition of every entry in
the build report's `## Out-of-scope observations — guard / boundary logic touched` section (`[]`
when the section says `none`; *Evaluator conduct* > *Build observations* above).

`recommendations` lists every finding as an object: `subject` — a `path:line` of the evaluated
artifact at the evaluated commit, or a section of the evaluated artifact — the design documents at
GATE:PLAN, the analysis report at GATE:HYPOTHESIS, the change set at AUDIT / GATE:QUALITY — or, for
an acceptance criterion the evaluator observes defective as a matter of fact
([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*), the criterion's
id; `item` — the rubric item it was found under; `severity` — a level of
`<autoflow-root>/docs/review/review.md` > Severity; and `finding`. Whether and where a finding is
fixed is the judgment of the AI acting on it, which puts it to the advisor when it cannot judge with
confidence and follows the decision
([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D6).
