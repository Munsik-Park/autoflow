# Evaluation System

> This document is the Evaluation AI's: the standard it evaluates by, its conduct, every gate's
> rubric — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — and the output it returns. The
> evaluator reads it and the sections it names for the gate (*The evaluator's standard* > *What it
> reads*). How the orchestrator spawns and prompts the evaluator is
> [`role-contracts.md`](role-contracts.md) > Evaluation AI; what it does with the result is the
> unit document of the gate's unit.

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

A functional unit is prescribed by its goal, its artifact contract, its verification and its loop
cap, and how it reaches the goal is its own ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 2).
That latitude does not extend to the evaluator: what it confirms, the
evidence a confirmation rests on and how far it goes are set here, and the evaluator applies them.

### What it reads

- **[MUST]** The gate's **input set**: the artifacts the gate's **Input** line names (*Gate
  rubrics* below), the change under evaluation, and the sections the table below names — the
  contract of the artifact it scores. Another document is read only at the section this document
  cites for the item being scored, never whole.

  | Gate | Artifact-contract sections |
  |---|---|
  | GATE:HYPOTHESIS | [U2 Analysis](units/analysis.md) > *What the analysis owes*, *Analysis report* |
  | GATE:PLAN | [U3 Design](units/design.md) > *Output artifacts* (with *Test necessity*, *Verification depth* and *Tools*) |
  | AUDIT | [U4 Build and verify](units/build.md) > *What the build owes* (its *Test-first* bullet), *Build report*; [U3 Design](units/design.md) > *Output artifacts* > *Test necessity* (the `Kind` vocabulary) |
  | GATE:QUALITY | [U4 Build and verify](units/build.md) > *Build report*; [U3 Design](units/design.md) > *Output artifacts* (the verification design's columns, with the `Type` and `Kind` vocabularies of *Test necessity*) |

- A unit document's other sections — its spawn, its routing, its verification and its re-entry —
  are the orchestrator's and are not read. A rubric's citation of one of them names the
  orchestrator's handling of the result and asks no read of the evaluator.
- What lies outside the input set — the gate hook, the state file and its keys, the spawn policy,
  another gate's rubric, an earlier cycle's artifacts the Input line does not name — is read only
  when the change under evaluation modifies it.

### What it confirms

- **[MUST]** Each rubric item of the gate, against the input set. A claim the artifact makes is
  confirmed at its anchor, not taken from the artifact's own account of it (*Pre-scoring FAIL
  hypothesis* below).
- A re-score confirms the items in `rescore.rescored` and the anchors they rest on; an inherited
  item is checked only for whether the re-entry touched its anchors, and is otherwise not re-read.

### Evidence

- **[MUST]** A confirmation is an anchor the evaluator read itself: a `path:line` read at the
  evaluated commit, a commit read with `git show`, a run's summary line read in the log the run left
  (never by re-running its command — *Execution discipline* below), an observation record and the
  artifacts it cites.
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
  recorded, every found issue reported (*Finding coverage*), the evidence read of every cited run,
  and the gate's named checks — test-first at AUDIT, the ADR-conformance and AC-authority checks,
  GATE:QUALITY's known blind-spot checks.
- **Scaled**: how far beyond the anchors the items rest on the evaluator re-derives, how far it
  traces adjacent code and documents, and how large a sample it takes.
  - A small, local change — a few lines in a few files, touching no state another component reads,
    no contract and no authority rule — gets a **lightweight pass**: the diff, the inputs the
    rubric items name, and one sampled instance per item.
  - A large change, one that crosses a repository or component boundary, or one that touches shared
    state, a contract, a gate or an authority rule gets the full depth: adjacent code and failure
    paths traced, the sample widened on a hit.
- The evaluator states the size it judged, with its ground, in `fail_hypothesis.case`.

---

## Two quality procedures

A change passes two independent quality procedures, and neither stands in for the other.

- **The gate evaluator** (this document) judges each unit's artifacts against its gate's rubric —
  the analysis, the design and its verification, test-first and the build's records, the completed
  change against the acceptance criteria and the cycle's scope — and holds the gate's authority:
  its scores decide PASS, and a FAIL routes the re-entry.
- **The configured reviewer** (`.codex/review.md`; [U6 Delivery](units/delivery.md) >
  *Reviewer review*) reviews each pull request the cycle opened — its diff against the linked
  acceptance criteria — for defects in the result, and is the sole authority to clear the
  `blocked-by-review` label.
- A gate PASS does not clear a reviewer finding, and a clean review does not stand in for a gate.
  Each procedure's findings are routed by its own triage ([U5 Completion
  evaluation](units/completion-evaluation.md) > *Recommendation triage*; [U6
  Delivery](units/delivery.md) > *Review triage*).

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

---

## Evaluation Types

| Type | Items (count) | Retry |
|------|---------------|-------|
| Structure evaluation (GATE:HYPOTHESIS — structure form, every issue, scored on the DIAGNOSE analysis report) | Behavior gap, Code-change necessity (2) | none — PASS/FAIL single verdict; reuse-neutral 2-item necessity gate. FAIL on gap-low (already satisfied) → review-response: reply + active:false (awaiting-external-review, no close); new-issue: auto-closed + terminated. FAIL on Code-change-necessity-low (non-code lever) → the advisor decides (code owed → continue; non-code → the cycle ends with its report). No retry loop. (Canonical: *Gate rubrics* > GATE:HYPOTHESIS > *Structure form* below; the dispositions: [U2 Analysis](units/analysis.md) > *Verification — GATE:HYPOTHESIS*) |
| Hypothesis evaluation (GATE:HYPOTHESIS — cause form, bug/incident only) | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× → a U2 unit re-run |
| Plan evaluation (GATE:PLAN) | Decision grounds, Verification fit, Scope, Tools, Security (5) — the design's intent, never its method (ADR-0025 D2); affected files and side effects are derived at BUILD by the build unit, not predicted and scored here. Decision grounds/Scope absorb the structural-fit & over-engineering concern the DIAGNOSE structure gate does not score — over-engineering is scored symmetrically across the plan and its verification design, so an unjustified verification layer fails Scope — and carry the embedded ADR-conformance check (divergence from a governing ADR, or an architecture-impacting change with no governing ADR/owner decision, caps the named item at 6; N/A by default) and the embedded AC-authority check (a verification-design difference against the issue's acceptance-criteria table that no `[ac-decision]` ledger entry covers caps Scope at 6); the interpretive paragraph and both checks are at *Gate rubrics* > GATE:PLAN below. Re-entry re-scores the design documents' delta sections plus every inherited item whose anchor it touched, reported in `rescore` | max 3× → ARCHITECT |
| Security audit (AUDIT) | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation (GATE:QUALITY) | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) — Test coverage's subject is the recorded local run for each `cycle` row and the committed asset for each `standing` row, never a CI result; Test quality carries the layer-violation check (a committed asset on a `cycle` row, an uncommitted one on a `standing` row, or a `standing:` token outside ADR-0024 D1's closed list caps it at 6); Fit also carries the embedded ADR-conformance regression re-confirmation (caps Fit at 6; same trigger as GATE:PLAN), and Completeness carries the embedded AC-authority check for post-ARCHITECT drift (a carried verification-design row for which no test assertion or implementation site can be named, and which no `[ac-decision]` ledger entry covers, caps Completeness at 6) | max 3× → re-entry by `remedy_class` (doc commit / BUILD / ARCHITECT; `operator` → the advisor) |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

The category sets and weights should be customised per project. As patterns
emerge, humans adjust the criteria.

---

## Evaluator conduct

These subsections bind every rubric-scored gate unless one names its gate.

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list them in `recommendations` (or `blocking_issues` when score-blocking). Each finding states its severity and confidence on its own item (the next bullet) and is reflected in the `score` and `reason`; a finding is never expressed by silently omitting it. The rubric score is the filter; the finding stage prioritizes coverage.
- **[MUST]** Write each `recommendations` item as the object *Evaluation Output Format* below defines, which also says what an item missing a field costs; a `Medium`+ item's `remedy_class` follows *Remedy class* below. After a PASS the orchestrator triages the list ([`units/completion-evaluation.md`](units/completion-evaluation.md) > *Recommendation triage*).

### Pre-scoring FAIL hypothesis (consider-the-opposite)

This subsection binds **every rubric-scored gate** — GATE:HYPOTHESIS (both the structure and cause forms), GATE:PLAN, AUDIT, GATE:QUALITY — and the doc-evaluation form when one is run, as a shared Evaluation AI contract. No gate opts out.

- **[MUST]** Form the FAIL hypothesis first: adopt the hypothesis **"this deliverable must FAIL"** and search for the strongest evidence supporting it, framed in the terms of this evaluation's own rubric items. The search re-derives the deliverable's cited anchors from the current source (`path:line`, command output, `git show HEAD:<file>`) rather than accepting the deliverable's own account of them.
- **[MUST]** Attempt to refute each FAIL case found. A refuted case does not affect the score. A case that survives refutation is carried into the affected item's `reason` and listed in `recommendations` (or `blocking_issues` when score-blocking). A surviving case may coexist with a score of 7 or higher: the routing obligation is to record it, not to lower the item.
- **[MUST]** Assign scores only after the FAIL hypothesis has been formed, searched, and dispositioned. Scoring never precedes the search.
- **[MUST] Re-entry form**. On a re-entry evaluation — one carrying a `rescore` field — the hypothesis for each item in `rescore.rescored` is **"the previously flagged defect still remains"**, searched against the re-entry diff and the prior report's finding for that item; each prior finding is dispositioned `cleared` / `remains` in `rescore.prior_findings`. A prior finding answered by a rebuttal instead of a fix ([`units/delivery.md`](units/delivery.md) > *Whether a finding holds*) is searched the same way, against the artifact as it stands and the rebuttal's grounds: `cleared` when the rebuttal holds, `remains` when the finding does. The hypothesis is not "this Nth remedy must FAIL": a defect newly seen on a re-scored item — including one in the text the remedy wrote — is still surfaced (Finding coverage above), and the evaluator judges whether it blocks, recording the judgment and its ground in `rescore.new_findings`; a blocking finding is scored under its item, a non-blocking one is listed in `recommendations` and does not lower the item. The independence rules are untouched — the spawn is fresh and the search still re-derives anchors.
- **[MUST]** Record the search in the `fail_hypothesis` output field, including the case that finding nothing was the outcome. An empty or omitted `fail_hypothesis` is a contract violation: the orchestrator **rejects** such an evaluation report and re-spawns a fresh Evaluation AI, exactly as it rejects an anchor-less role-spawn report (`CLAUDE.md` > Execution Principles > *Verify role-spawn claims*). The re-spawn is capped (max 2) — on a third consecutive report whose `fail_hypothesis` is empty or omitted, stop re-spawning and escalate to the user. No machine validator enforces this — the hook reads only `scores` — so the orchestrator's acceptance is the enforcement point.

### Build observations (GATE:QUALITY input)

Binds the GATE:QUALITY form only.

- **[MUST]** Read the build report's (`.autoflow/issue-{N}-build-report.md`) `## Out-of-scope observations — guard / boundary logic touched` section, disposition every entry (`defect — scored under <item>` or `not a defect — <reason>`), and record the dispositions in the `refine_observations` output field. A `defect` entry is scored under `Quality` or `Impact scope`. The author's rejection reason is context, not the disposition.
- **[MUST]** A report whose `refine_observations` is absent, or that does not account for every entry in the section, is rejected and the evaluator re-spawned, with the same cap (max 2) and escalation as an empty `fail_hypothesis`.

### Scope judgments (GATE:PLAN / GATE:QUALITY)

The cycle's scope is its acceptance criteria, its confirmed cause, and the problems its recorded scope judgments include ([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Scope judgment*).

- **[MUST]** Score scope against those records, not against acceptance-criterion IDs alone. At GATE:PLAN, `Scope` reads the feature design's `## Scope` section. At GATE:QUALITY, `Minimal implementation` and `Impact scope` read the `## Scope` section, every `## Scope judgments` section in the cycle's `.autoflow/issue-{N}-*.md` reports, and the ledger's `[gate-autofix]` entries and gate verdict entries recording how earlier gates' recommendations were triaged (Change Surface Rules > GATE:QUALITY linkage).
- A hunk that rests on a recorded judgment is in scope when the judgment meets one of question 1's three conditions; a judgment that meets none is scored under `Minimal implementation`. A directly related problem the records show, left out with no separation reason or with one that answers neither half of question 2, is scored under `Impact scope` (GATE:PLAN: `Scope`).
- A separation reason is judged for whether it answers question 2, not for whether the evaluator would have separated the problem.

### Remedy class (GATE:QUALITY FAIL routing; `Medium`+ recommendations at every gate)

The failed-item rule binds the GATE:QUALITY form only; the recommendation rule binds every
rubric-scored gate. The orchestrator routes a FAIL's re-entry and a `Medium`+ recommendation's fix
from this field ([`units/completion-evaluation.md`](units/completion-evaluation.md) > FAIL routing, >
*Recommendation triage*); the evaluator is the classifying authority and the implementing roles do
not re-classify.

- **[MUST]** On a FAIL, tag every item scored below 7 with a `remedy_class` — `doc` (documentation,
  no behavior change; in this repository comment text too — a target comment's divergence or
  disallowed content is never a failed item, while a defect a comment carries on its own ground is
  classed like any other, *Code comments in a target* below), `test` (test assets), `impl`
  (implementation), `design` (the
  agreed design itself) — starting from the default per item (`scripts/gate/remedy-route.sh
  default-class <item>`) and overriding it with a stated reason when the default misreads the
  defect (a `Doc updates` cap caused by a prompt string or a hook message is `impl`).
- **[MUST]** Tag every `recommendations` item of severity `Medium` or above with a `remedy_class`
  from the same vocabulary, at every rubric-scored gate, by the question HANDOFF's review triage asks of a
  reviewer finding — *does clearing this discard or change a decision the design settled?*
  Yes → `design`; no → the kind of change that clears it. An item below `Medium` carries none.
- **[MUST]** Write `operator` when the class cannot be stated with confidence. Do not guess: an
  `operator` entry stops routing and the advisor decides the class ([`role-contracts.md`](role-contracts.md) > Advisor).
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: the
  orchestrator rejects it and re-spawns a fresh Evaluation AI, with the same cap (max 2) and the same
  escalation as an empty `fail_hypothesis`.
- **[MUST]** On a re-entry evaluation, score afresh only the items listed in `rescore.rescored` — the
  previously failed items plus any inherited item whose anchor files the re-entry diff touched — and
  copy the rest from the cited prior report (`rescore.source`). The fresh-spawn rule is unchanged;
  the input is narrowed, not the independence. The re-score's subject is the flagged defect: the
  FAIL hypothesis takes its *re-entry form* (above), and `rescore.prior_findings` /
  `rescore.new_findings` carry the dispositions (*Gate rubrics* > GATE:QUALITY > *Re-entry
  re-score* below).

### Code comments in a target (GATE:QUALITY)

Binds the GATE:QUALITY form over a target's code. This repository is excluded: a comment here is
scored under the ordinary items, the `doc` class included.

- **[MUST]** A code comment carries only a sentence that stays true for as long as the code it sits
  on is unchanged. **A comment that diverges from its code, or that carries what a comment does not
  carry, is a `Low` finding** — a restatement of the code, a design ground, an acceptance-criterion,
  issue or PR reference, another file's path or contract, or a change history. Record it in
  `recommendations` with its `path:line` and the severity `Low`; it lowers no item's score, so it is
  never a failed item and carries no `remedy_class`; whether it is fixed is the orchestrator's
  judgment, and the fix is its direct commit ([`units/completion-evaluation.md`](units/completion-evaluation.md) > *Code comments in a target*).
  Only that finding is `Low`: a defect a comment carries on its own ground — an exposed credential,
  token or personal data, for example — is scored under the item its impact belongs to, with that
  item's usual cap and class.
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
evaluator still forms the hypothesis first, still re-derives anchors, still records the search in
`fail_hypothesis`.

- **[MUST] Resolve the anchor before executing.** Where the anchor being re-derived is a **suite
  verdict**, the anchor is the recorded local run — the command, the log it wrote and the summary
  line read from it (Reporting Format item 5) — and the evaluator confirms it by reading that line
  at the cited log path, never by re-running the command; a log absent at its path makes the row
  `not-run` (GATE:QUALITY > *Known blind-spot checks* > *Test coverage* > *Execution omission is
  not a defect* below), and a log that does not carry the line is evidence authored without a
  run (*Test quality / Completeness*). An unresolved anchor is a report defect, not an input.
  Nothing is cited from a host record in place of a run's log.
- **[MUST] Sampling default.** A blind-spot search over a **repeated surface** takes a
  representative sample per rubric item by default (one or two instances), and states the sample
  basis in `fail_hypothesis`. Exhaustive enumeration is entered only when a sampled instance yields
  a FAIL case that survives refutation — escalate on a hit, rather than enumerate by default.
  Coverage of *finding types* is unaffected: the finding-coverage rule above still forbids dropping
  a found issue.
- **[MUST] Time cap.** An evaluation declares a **wall-clock cap** and reports against it. The cap
  is **30 minutes** unless the spawning orchestrator declares a different value in the spawn prompt,
  in which case the declared value governs and is reported. On reaching the cap the evaluator stops
  searching, scores what it searched, and records every unsearched item as `not-searched` in
  `fail_hypothesis` — **never as clean**. A cap reached with unsearched items is a
  signal to the orchestrator that the rubric item's evidence is thin, not a pass.

---

## Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY

The rubric each gate scores on. Each gate is the verification of one functional unit —
GATE:HYPOTHESIS of U2 Analysis, GATE:PLAN of U3 Design, AUDIT of U4 Build and verify
([`ADR-0025`](records/adr/0025-outcome-gated-functional-units.md) D1) — and GATE:QUALITY is itself
the unit U5 Completion evaluation. Every gate is scored by an Evaluation AI, never by a unit agent,
so its rubric lives here, in the evaluator's own document, and not in the unit's. What the
orchestrator does with a gate's result — the PASS route, the FAIL route and its cap — is the unit
document's: [U2 Analysis](units/analysis.md), [U3 Design](units/design.md),
[U4 Build and verify](units/build.md), [U5 Completion evaluation](units/completion-evaluation.md).

### GATE:HYPOTHESIS

It scores what the analysis report shows, never the method the unit took to produce it (ADR-0025
D2).

**Evaluator**: one independent Evaluation AI, fresh-spawned per entry. It scores the structure
form for every issue and, for a bug / incident issue, the cause form. Each form's result is written
separately — one output object per form (*Evaluation Output Format* below) — and the orchestrator
records each under its own key, `phases.gate_hypothesis_structure` and
`phases.gate_hypothesis_cause` in `.autoflow/issue-{N}.json`; the two are never nested under one
key.
**Input**: the analysis report (`.autoflow/issue-{N}-analysis.md`), the trigger target (the issue,
or the reviewer comment / thread of a review-response cycle) and the decision ledger.

#### Structure form (every issue)

The form answers one question: **does the as-is already satisfy the request, and if not, is a code
change the lever?** The request is the cycle's trigger target and the as-is the dev branch's HEAD
([U2 Analysis](units/analysis.md) > *What the analysis owes*). It is a necessity gate and
reuse-neutral: a resolution that reuses existing code scores high, not low. Plan feasibility,
structural fit and over-engineering are GATE:PLAN's (Decision grounds, Scope) and GATE:QUALITY's
(Minimal implementation, Fit).

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
**does not gate** `gate_hypothesis_structure`; the orchestrator judges it against these thresholds,
and a FAIL is disposed of by its failing item, never by a bare composite
([U2 Analysis](units/analysis.md) > *Verification — GATE:HYPOTHESIS*).

#### Cause form (bug / incident issues only)

Non-bug issues (feat, chore, docs, refactor, …) skip this form. The form reads the report's
`## Hypotheses`.

| Item | Criterion |
|------|-----------|
| Hypothesis diversity | Are non-code causes (data, environment, already fixed) sufficiently considered? |
| Verification sufficiency | Was lightweight verification actually performed? Are unverified items justified? |
| Verdict evidence | Is the conclusion (code change required / not required) logically supported? |

#### Re-entry re-score

After a U2 re-run the gate re-scores the form that sent the cycle back — the cause form after a
cause-form FAIL, the recommending form after a recommendation attempt — and the other form only
where the re-run changed a section it reads (the structure form: `## Current structure`,
`## Request`, `## Necessity`; the cause form: `## Hypotheses`); the rest is inherited and reported
in `rescore` (*Evaluation Output Format* below).

### GATE:PLAN

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: the two documents the U3 Design unit wrote ([U3 Design](units/design.md) > *Output
artifacts*) — the feature design and the verification design — the issue's acceptance-criterion
list (`.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`), and the issue decision ledger
(`.autoflow/issue-{N}-ledger.md`).

The gate scores the design's **intent** — whether each decision is grounded, whether each
criterion's verification fits it, whether the scope is right and whether the tools are secured —
never the method by which the unit reached it: no item asks which roles took part, whether a
dialogue was held, or in what order the documents were written (ADR-0025 D2).

#### Scoring (5 items × 10 points)

| Item | Criterion |
|------|-----------|
| Decision grounds | Is each architecture decision grounded in the actual mechanisms it changes (not a misread), with the constraints it holds under and the alternatives it rejected, each rejection with its ground? Can the design be implemented with the current structure? |
| Verification fit | Does each verification-design row verify the property the AC it names states, not a weaker or different proposition, by a method that can fail on the defect its `Failure mode` cell names? Where the design changes shared state — state that outlives a single call and that more than one decision reads or writes — that a settled decision (a governing ADR, a prior issue's agreed design, an entry in this issue's ledger) also names, does at least one verification drive that contact through the real execution environment rather than a double, or does the design state a design-change request because none can be built? |
| Scope         | Appropriate — not too broad, not missing requirements? (no redundant new mechanism where an extension suffices — over-engineering fails here; the feature design's `## Scope` section judges each problem the confirmed cause carries under Change Surface Rules > *Scope judgment*, and a directly related problem left out owes a separation reason) |
| Tools         | Does the `## Tools` section name, for each row that needs one, the tool, its availability and the ground for it — and does each `manual` row executed by a person, and each row resolved to a mock, state in its `Reason` why no tool could be secured ([U3 Design](units/design.md) > *Tools*)? |
| Security      | Any security implications introduced? |

**Affected files and side effects are not scored here**. The gate scores the
*decision* layer; which files a change touches and which tests it requires are **derived**, not
predicted — by the build unit at BUILD, from the change delta and the way the
target runs its tests, and from the files it opens anyway. A dependency miss surfaces at BUILD
or HANDOFF's CI and routes by the class rules, consuming no ARCHITECT re-entry.

`Decision grounds` and `Scope` absorb the structural-fit concern that the GATE:HYPOTHESIS structure form deliberately does not score: a plan not grounded in the actual structure fails Decision grounds; a plan **or its verification design** that duplicates an existing mechanism or over-engineers a new one where an extension suffices fails Scope — the over-engineering half applies symmetrically to both, so a verification that carries no unique failure mode fails Scope on the same clause. On a row that owes the `Failure mode` cell ([U3 Design](units/design.md) > *Output artifacts*, the column's bullet), the cell fails Scope when it is empty — `—` on such a row counts as empty — or when it cannot be told apart from the cell of another distinct verification anywhere in the design, or from a named existing mechanism; rows that share a `Method` label are one verification and are not compared with each other. The deduction rides this clause and adds no scored item, cap or `scores` key.

#### ADR-conformance check (scored within Decision grounds / Scope)

This named check makes the ADR-conformance concern explicit inside the two items that already absorb structural fit — it adds **no scored item** and changes **no PASS threshold**; a violation caps the named item at 6, failing via the each-item ≥ 7 rule (identical mechanism to GATE:QUALITY's *Known blind-spot checks* below). A **governing ADR** for the change surface is an ADR in the repository's ADR directory (`docs/records/adr/` in this repository; a consuming target's own ADR location) with status `Accepted`/`Proposed` whose Decision scope intersects the change surface, **or** a change hitting a **trigger area** of `docs/development-guideline.md` > ADR Policy > *When to create an ADR* — the list is defined there, in a shipped usage document, and nowhere else.

- **Trigger → cap**: divergence from a governing ADR, **or** an architecture-impacting change with no governing ADR/owner decision → cap.
- **Per-item cap distribution**: `Decision grounds` caps on a structural-grounding divergence (the plan is not grounded in the ADR's decided structure); `Scope` caps on a redundant-mechanism / boundary divergence **or** the undocumented-ADR trigger; **both** cap when both defects are present. One divergence never leaves both items uncapped.
- **N/A by default**: no governing ADR's Decision scope intersects **and** no trigger area is hit → the check does not apply, no cap, the item scores normally.

#### AC-authority check (scored within Scope)

Same mechanism as the ADR-conformance check above: **no added scored item, no threshold change**; a
violation caps `Scope` at 6, which fails the gate through the each-item ≥ 7 rule.

- **The comparison** is a key join, both sides keyed: every `AC id` in the issue's
  `## Acceptance criteria` table against the `Issue AC` column of the verification design's
  acceptance-criteria table. A **difference** is one of exactly two states: the design carries no row for the criterion
  (`dropped`); or it carries the
  criterion with a disposition other than `automated` and states no reason (`unreasoned`). A row
  whose proposition differs from the issue's is **not** a difference here — that is a semantic
  reading, scored under `Verification fit`. A reduced disposition **with**
  a stated reason is not a difference — it is a verification-method choice the design is
  authorized to make ([U3 Design](units/design.md) > *Output artifacts*, the `Issue AC` bullet), and its **reason quality** is
  scored by `Scope` under the existing verification-depth clause ([U3 Design](units/design.md) > *Verification depth*), adding no scored item.
- **Trigger → cap**: any difference **not** covered by a `[ac-decision]`-marked ledger entry whose
  `- AC:` line names that same id caps `Scope` at 6. The marker is what the gate matches on;
  `advisor decision` or `operator decision` is that entry's authority **value** and is not itself the
  match key. An entry
  whose `- Disposition:` is `added` covers nothing: the criterion it adds is owed its row like any
  other ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*).
- **An unresolvable check also caps.** An absent, empty or unparseable `## Acceptance criteria`
  table caps `Scope` at 6.
- **N/A by default** applies only to the difference set, never to the source: no difference and a
  readable AC table → no cap, the item scores normally.

#### Re-entry re-score

A re-entry's re-score is a **fresh spawn with a narrowed input**, on the same rule
GATE:QUALITY's re-entry re-score states. The evaluator reads the design documents' **delta sections** for this round — the `## Delta — round <n>` sections the re-entry appended —
plus every previously-passing item whose anchor the delta touched, and re-scores exactly those; the
remaining items inherit their prior score by citation. The report states the re-scored item list
and the inheritance source (the prior report's path) in its `rescore` field
(*Evaluation Output Format* below). The state file still
receives all five scores, inherited ones copied
verbatim from the cited report. An inherited item whose anchor the delta touched and which is
missing from the re-scored list is a report defect: reject and re-spawn.

A first evaluation of a cycle (no prior report to inherit from) scores both documents whole;
the narrowing binds re-entries only.

### AUDIT

A project-specific security audit of the change the BUILD unit returned, after a test-first
judgment on its evidence. Complements GATE:QUALITY's `Security` item with 5 dedicated,
project-specific items; GATE:QUALITY's `Security` item references the AUDIT result.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: the U4 artifact set — the change diff with the cycle's commits, the build report
(`.autoflow/issue-{N}-build-report.md`) and the verification design
(`.autoflow/issue-{N}-verification-design.md`) — + the target's security checklist at the version the
checklist status names (*Security checklist* below), or none when none is declared. In a **review-response cycle**,
additionally the previous cycle's AUDIT report (`.autoflow/issue-{N}-c{C-1}-audit.md`, preserved at
PREFLIGHT) — its `## Low findings` list is the re-score's starting set.

#### Test-first

Judged before scoring. For each `driving` / `regression` row of the verification
design, the evaluator reads the build report's `## Test-first` row and the evidence it cites, and
judges whether the Red run precedes the implementation commit and its failure is shown by its log
([U4 Build and verify](units/build.md) > *What the build owes* > *Test-first*). It finds that evidence where this
project's composition puts it, and records in its report, under `## Test-first`, what it read for
each row and its verdict — `confirmed`, or `not confirmed` with what is missing or contradicts the
record. On any `not confirmed` row it scores nothing and returns that section. That return is a
routed result, not a report defect ([U4 Build and verify](units/build.md) > *Verification —
AUDIT*).

#### Security checklist

AutoFlow ships no checklist and names no item: AutoFlow owns how AUDIT scores — the fresh
evaluator, the five items below, the PASS thresholds — and the target owns what each item is judged
by. Which version AUDIT reads is the record line of
`bash scripts/gate/security-checklist.sh status --ledger .autoflow/issue-{N}-ledger.md`, which the
orchestrator runs at AUDIT entry ([U4 Build and verify](units/build.md) > *Security checklist*):

- `none-declared` → no checklist: the five items are scored from the change alone, and the report
  records that none was declared;
- `unchanged` → the checklist as of the cycle's base commit (`score=<base>:<path>`);
- `changed-decided` → the changed version a `[checklist-decision]` entry accepted
  (`score=HEAD:<path>`, or `none` for a dropped declaration).

**The evaluator reads the named version.** The spawn prompt carries the record line; the evaluator
re-runs the same status (it only reads), reads the checklist at the `score=` spec with `git show`,
never the working-tree file, and copies the line into its report. A report whose line differs from
the one the orchestrator recorded is a report defect: reject and re-spawn.

#### Report

The evaluator's report is written to `.autoflow/issue-{N}-audit.md` and carries a
`## Test-first` section (*Test-first* above), a `## Security checklist` section (the status record
line) and a
`## Low findings` section (each Low item with `path:line` at the audited commit and a one-line claim; `none` when empty).
The state file keeps only the scores.

#### Review-response re-score

The fresh evaluator does not re-derive the whole audit.
It judges test-first for the rows this cycle added or rewrote, re-scores **the change surface of this
cycle** (the review-response diff) against the checklist,
re-checks each prior Low finding only where that diff touches its file, and inherits the rest by
citation — the same narrowed-input rule as GATE:QUALITY's re-entry re-score, using the same
`rescore` output field. Fresh spawn is unchanged; the input is.

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
**Input**: the change set — the cycle's commits — and the cycle's artifacts:

- the analysis report (`.autoflow/issue-{N}-analysis.md`): its `## Acceptance criteria` table, the
  issue's acceptance-criterion list, and its `## Scope judgments`;
- the two design documents: the feature design (`.autoflow/issue-{N}-feature-design.md`) — the
  decisions the change is checked against, and its `## Scope` section — and the verification
  design (`.autoflow/issue-{N}-verification-design.md`);
- the build report (`.autoflow/issue-{N}-build-report.md` — [U4 Build and verify](units/build.md) >
  Build report): its run record, manual checklist, maintained documents and lint record, its
  `## Scope judgments`, section `## Out-of-scope observations — guard / boundary logic touched`,
  and — on a target — section `## Comment check`;
- the AUDIT result: its scores and its report (`.autoflow/issue-{N}-audit.md`);
- the issue decision ledger (`.autoflow/issue-{N}-ledger.md`), with the `[gate-autofix]` entries
  and gate verdict entries that record how earlier gates' recommendations were triaged.

The cycle's scope records are the feature design's `## Scope` section, every `## Scope judgments`
section in the cycle's `.autoflow/issue-{N}-*.md` reports, and those ledger entries
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
of the item. `Commit conventions` reads `## Lint` for every commit this cycle made against the
outcome vocabulary and its reason classes
([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on
the staged surface*): a chain `detected` is a finding of the
item, a `not-run (ci-deferred)` chain is cleared as a deferral, and a commit with no lint record or a
chain `not-run (unexecuted)` is an omission that takes the omission path under `Test coverage` below.

#### Known blind-spot checks (scored within existing items)

The evaluator applies the checks below **inside the existing 10 items** — they add no scored items and change no
PASS threshold. Each violation caps the named item at 6, which fails the gate via the
each-item ≥ 7 criterion:

- **Test quality — mock-boundary fidelity**: sample the suite's test doubles and verify
  each against the real interface at HEAD (signature, argument count, return shape).
  A double that diverges from the real interface caps `Test quality` at 6.
- **Test quality / Completeness — assertion-claim alignment**: for each AC, confirm the
  test asserts the behavior the AC states, not a weaker proxy (e.g. "the function was
  called" where the AC requires a result shape) and not a different property than the
  one the AC it names states. Confirm every cited evidence line
  (test summary, log excerpt) against the log the cited run left, read at the cited path —
  never by re-running the command; a recorded line the log does not carry was authored, not
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
    (`CLAUDE.md`, `docs/autoflow-guide.md`, `docs/units/*`, `docs/role-contracts.md`,
    `docs/role-common-rules.md`, `docs/submodule-common-rules.md`, `docs/evaluation-system.md`,
    `.claude/agents/*`, and the sections of an ADR that state a decision still in force);
    (b) the scripts, hooks and workflows that run; (c) every document delivered to a target — the
    boundary of (c) is the manifest generator's markdown-link closure of `CLAUDE.md` +
    `docs/INDEX.md` plus its other artifact rows (`setup/gen-manifest-hashes.sh` >
    `compute_doc_closure`).
  - *Historical records* are what is kept as a record of a past state and followed by no one:
    per-issue manual-verification records, report-excerpt fixtures
    (`tests/fixtures/*`), an ADR's change-history and superseded sections, and archived cycle
    artifacts. A fixture that an executing test reads is still a historical record for this check,
    while the test that reads it is normative.
  - For a stale name in a historical record the evaluator judges whether a reader following the
    normative documents would be misled by it, and records the judgment with its grounds in the
    item's `reason` (and in `recommendations` when it does not lower the score). A score reduction
    rests on that recorded ground alone, never on the name's presence; a record whose stale names
    mislead no one is left as it is, and rewriting it is not a remedy the evaluator asks for.
- **Test quality — layer violation** (**this repository only**): for each
  verification-design row, the asset matches the layer its `Type` cell declares — a `cycle` row
  (no `standing:` token) has no committed test file; a `standing` row has its committed file,
  CI-registered; and every `standing:` token is one of ADR-0024 D1's closed list. A committed asset
  on a `cycle` row, an uncommitted asset on a `standing` row, or a token outside the list caps
  `Test quality` at 6. The token check is a set relation, not a judgment, and it is performed
  **by the device**: the evaluator runs
  `bash scripts/gate/verification-layer-check.sh .autoflow/issue-{N}-verification-design.md` and
  attaches its output — a non-zero exit is a token outside D1's closed list and caps the item; the
  device's second output, the row↔asset pairing report, is input to this check and to
  `Test coverage`, never a verdict. The device is not delivered to targets and the check does not
  run there: on a target, a test file the cycle added is judged by the reviewer against the target's
  convention from the PR body's listing ([U6 Delivery](units/delivery.md) > *Push and pull request*), not by a token ([`submodule-common-rules.md`](submodule-common-rules.md) >
  Verification and Tools > *What a cycle leaves in the target's tree*); under this item the evaluator confirms
  that every test file the cycle added to the target's tree carries, in the build report's
  `## Test files kept` section, the reason it is kept and the CI job expected to run it — the record HANDOFF carries into
  the PR body — and an added file with no such record caps
  `Test quality` at 6.
- **Test coverage — the run record is the subject**: the item's subject is not a CI result. For
  each `automated` / `delivery-check` row
  it is the row's recorded run — the command, the log and the summary line read from it, confirmed
  by reading the line at the cited log path rather than by re-running; in this repository a
  `standing` row's subject is additionally the committed asset's realisability — the file exists,
  runs, and is CI-registered. For a `manual` row executed by the AI it is the row's observation
  record ([U4 Build and verify](units/build.md) > Build report > `## Manual checklist`), confirmed by reading the record and opening the artifacts it cites — a
  screenshot is read as an image — never by observing again; a row with no record, or
  a record whose artifacts are absent, takes the omission path below.
  - **Execution omission is not a defect** ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *A missing run
    is filled where it is found*). A row with no run record — or with no log behind it — is `not-run`, and the evaluator does
    **not** score `Test coverage` over it: the report names each such row under `Test coverage` as
    `not-run: <rows>` and withholds that item's score (a lint omission under `Commit conventions`
    is named and withheld the same way). Such a report is not a verdict — it is not
    recorded in the state file, consumes no FAIL of the `max 3×` cap, and carries no `remedy_class`
    for the omission. The orchestrator has each named row run in place — a cycle-layer asset by its
    path (the orchestrator itself may run it), a test in the target's tree by a BUILD unit re-run
    the way the target runs its tests — and its record filled in, then spawns a fresh evaluator that
    re-scores the withheld item only, in the *Re-entry re-score* form below with the withheld report
    as the inheritance source. A lint chain that still cannot be run, and that no pull-request CI job
    covers, is the harness-level block of [U4 Build and verify](units/build.md) > *Report routing*. A recorded run that
    **fails** is a defect, scored and classed like any other.
- **Fit — ADR conformance**: on the final change set, re-confirm the shipped change conforms to any governing ADR (same
  governing-ADR / trigger-area / N/A definition as the GATE:PLAN ADR-conformance check; the
  trigger areas are `docs/development-guideline.md` > ADR Policy > *When to create an ADR*). A
  divergence from a governing ADR, or an architecture-impacting change with no governing
  ADR/owner decision, caps Fit at 6.
- **Completeness — AC-authority check**: the backstop for acceptance-criterion drift introduced **after** ARCHITECT — a test the
  build rewrote after its first run, or the satisfiable-subset implementation [U4 Build and verify](units/build.md) permits on a design contradiction.
  The check is a **name-the-site obligation**, not the GATE:PLAN key join: for each
  verification-design row whose `Issue AC` is not `—`, the evaluator names the test file and
  assertion, or the implementation site, that discharges it. A row for which no
  site can be named, and which no `[ac-decision]`-marked ledger entry covers, caps `Completeness`
  at 6 (an `added` entry covers nothing: the criterion it adds is owed its row and its site).
  **Derivation is not drift**: a file row, suite disposition or oracle condition clause
  BUILD derived under the ARCHITECT layer split ([U3 Design](units/design.md) > *Output artifacts* item 1)
  is the designed division of labour, never a post-ARCHITECT AC change.
  The check binds a verification-design row whose `Issue AC` is not `—` and for which no
  discharging site can be named.

#### Re-entry re-score

After any class's re-entry, GATE:QUALITY runs again as a **fresh spawn with a narrowed input**: it
re-scores the items that failed plus every previously-passing item whose anchor files the re-entry
diff touched; the remaining items inherit their prior score by citation. The report states the
re-scored item list and the inheritance source (the prior report's path) in its `rescore` field
(*Evaluation Output Format* below). The state file still
receives all ten scores, inherited ones copied
verbatim from the cited report. An inherited item whose anchor file appears in the re-entry diff
and is missing from the re-scored list is a report defect: reject and re-spawn.

**The re-score's subject is the previously flagged defect**. The fresh evaluator's FAIL hypothesis
on a re-scored item is *"the flagged defect still remains"*, searched against the re-entry diff
(*Evaluator conduct* > *Pre-scoring FAIL hypothesis* > *Re-entry form* above); each prior finding is dispositioned `cleared` / `remains` in
`rescore.prior_findings`. A defect the evaluator newly sees on a re-scored item — including one in
the sentences the remedy itself wrote — is recorded per *Finding coverage*, and the evaluator
judges whether it blocks: a blocking finding is scored under its item and listed in
`rescore.new_findings` with its ground; one that does not block goes to `recommendations` and does
not lower the item.

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
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "remedy_class": { "<failed item>": "doc | test | impl | design | operator" },
  "rescore": {
    "source": "<prior report path>", "rescored": ["item"], "inherited": ["item"],
    "prior_findings": [ { "item": "item", "finding": "<the prior report's finding>", "status": "cleared | remains", "ground": "<path:line at <commit SHA> / command + log path + summary line>" } ],
    "new_findings": [ { "item": "item", "finding": "<defect newly seen on a re-scored item>", "disposition": "blocking — scored under <item> | recommendation", "ground": "<why it blocks, or why it does not>" } ]
  },
  "refine_observations": [ { "entry": "<suggestion @ path:line at <commit SHA>>", "disposition": "defect — scored under <item> | not a defect — <reason>" } ],
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": [ { "subject": "<evaluated artifact path:line at <commit SHA> | evaluated artifact section | AC id, for a criterion defect>", "item": "<rubric item>", "severity": "<level — .codex/review.md > Severity>", "finding": "<the finding>", "remedy_class": "<doc | test | impl | design | operator — on Medium and above>" } ]
}
```

`scores` holds one entry per rubric item of the evaluated gate, keyed by the item's
name. Each value is either a number (`8`) or an object (`{"score": 8, "reason": "..."}`),
the score on the 10-point scale.

`fail_hypothesis` records the pre-scoring consider-the-opposite search required by
*Evaluator conduct* > *Pre-scoring FAIL hypothesis* above. It is narrative/audit material: nothing reads it programmatically and no
gate consumes it. It is placed before `scores`.

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `case` | string, non-empty | always | The strongest FAIL argument found. With `disposition: "none_found"` it states **what was searched** (which items, which anchors re-derived). It also states the change size the evaluator judged and its ground (*Proportional depth* above). |
| `disposition` | enum `refuted` \| `survived` \| `none_found` | always | Outcome of the refutation attempt. |
| `reflected_in` | array of rubric item names | always present (`[]` when `disposition != "survived"`) | Which scored item(s) recorded the surviving case — the join between the narrative record and the numeric `scores`. "Recorded" does not imply "scored down": an item listed here may still score ≥ 7. |

`remedy_class` (GATE:QUALITY only) maps **each failed item** (score < 7) to the kind of change that
clears it; the orchestrator routes the FAIL's re-entry from it
([U5 Completion evaluation](units/completion-evaluation.md) > *FAIL routing*). It is report material the orchestrator acts on; the hook does not
read it from the report (it reads the routed class the orchestrator records in state).

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `remedy_class` | object, one entry per failed item | **on every FAIL** (`{}` on a PASS) | Value enum `doc` \| `test` \| `impl` \| `design` \| `operator`. A failed item with no entry is a contract violation — reject + re-spawn, as for a missing `fail_hypothesis`. `operator` means "not classifiable with confidence" and pauses the cycle for the operator. |
| `rescore` | object | **on a re-entry evaluation** — after a FAIL's re-entry, or after a recommendation attempt or rebuttal ([U5 Completion evaluation](units/completion-evaluation.md) > *Recommendation triage*; [U6 Delivery](units/delivery.md) > *Whether a finding holds*) (absent on a first evaluation) | `source` — the prior report's path; `rescored` — the items scored afresh (the failed items — after a recommendation fix or rebuttal, the items the routed or rebutted recommendations were listed under — plus any inherited item whose anchor the re-entry touched — the re-entry diff at GATE:QUALITY / AUDIT, the decision document's delta section at GATE:PLAN, the amended DIAGNOSE artifact at GATE:HYPOTHESIS); `inherited` — the items whose score is copied from `source`. Every rubric item appears in exactly one of the two lists. `prior_findings` — one entry per finding the prior report recorded on a re-scored item, with `status` `cleared` or `remains` and the ground re-derived from the re-entry diff — for a rebutted finding, from the rebuttal's grounds at the evaluated commit (the re-score's FAIL hypothesis is "the flagged defect still remains", *Evaluator conduct* > *Pre-scoring FAIL hypothesis* > *Re-entry form* above); a prior finding with no entry is a report defect — reject + re-spawn, as for a missing `fail_hypothesis`. `new_findings` — one entry per defect newly seen on a re-scored item (`[]` when none), each with the evaluator's `disposition` — `blocking — scored under <item>`, or `recommendation` (also listed in `recommendations`, and the item's score is not lowered for it) — and its ground. Both lists are report material the orchestrator reads; the hook reads neither. |

`refine_observations` (GATE:QUALITY only) records the evaluator's disposition of every
entry in the build report's (`.autoflow/issue-{N}-build-report.md`) `## Out-of-scope observations — guard / boundary logic touched`
section. Always present on a GATE:QUALITY report (`[]` when the section says `none`); a report that
omits it or leaves an entry undispositioned is rejected and re-spawned. `rescore` is also the field
a review-response AUDIT uses for its narrowed re-score (*Gate rubrics* > AUDIT > *Review-response re-score* above).

`recommendations` lists every non-blocking finding as an object: `subject` — a `path:line` of the
evaluated artifact at the evaluated commit, or a section of the evaluated artifact — the design
documents at GATE:PLAN, the DIAGNOSE analysis report (`.autoflow/issue-{N}-analysis.md`) at
GATE:HYPOTHESIS, the change set at AUDIT / GATE:QUALITY — or, for an acceptance criterion the evaluator
observes defective as a matter of fact ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion
decisions*), the criterion's row in `.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`, whose
`remedy_class` on `Medium`+ is `operator`; `item` — the rubric item it was found under;
`severity` — a level of `.codex/review.md` > Severity; `finding`; and, on `Medium` and above,
`remedy_class` from the same enum as the failed-item field, by the same classifying question HANDOFF
review triage asks of a reviewer finding. After the PASS of any rubric-scored gate the orchestrator
triages the list ([U5 Completion evaluation](units/completion-evaluation.md) > *Recommendation
triage*). The hook reads none of the list; it reads the routed class the
orchestrator records in state while an attempt is open. A `Medium`+ item with no `remedy_class`, or
any item missing a field, is a contract violation — reject + re-spawn, as for a missing
`fail_hypothesis`.

A suite verdict the evaluator re-derives is the recorded local run — its summary line read in the
log the run left, the command re-run only when that log is absent (the row is then `not-run`).
