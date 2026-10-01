# Evaluation System

> The AutoFlow evaluation system provides quantified quality assessment at the
> three gates (`GATE:HYPOTHESIS`, `GATE:PLAN`, `GATE:QUALITY`) and at `AUDIT`.
>
> **상세 기준은** [`role-contracts.md`](role-contracts.md) > Evaluation System **을 참조한다.**
> The rubrics of GATE:HYPOTHESIS, GATE:PLAN and AUDIT are *Gate rubrics* below; GATE:QUALITY's is
> [U5 Completion evaluation](units/completion-evaluation.md).

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before
it reaches human review. The agent that wrote the work never evaluates it.

### Critical Rule: Fresh Spawn Every Time

The Evaluation AI must be **spawned fresh for every evaluation** — at
GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY. It carries no prior
conversation history. This is mandatory.

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

## Gate rubrics — GATE:HYPOTHESIS, GATE:PLAN, AUDIT

The rubric each of these gates scores on. Each gate is the verification of one functional unit —
GATE:HYPOTHESIS of U2 Analysis, GATE:PLAN of U3 Design, AUDIT of U4 Build and verify
([`ADR-0025`](records/adr/0025-outcome-gated-functional-units.md) D1) — and is scored by an
Evaluation AI, never by the unit agent, so its rubric lives here, in the evaluator's own document,
and not in the unit's. What the orchestrator does with a gate's result — the PASS route, the FAIL
route and its cap — is the unit document's: [U2 Analysis](units/analysis.md),
[U3 Design](units/design.md), [U4 Build and verify](units/build.md). GATE:QUALITY is the gate that
is itself a unit (U5); its rubric is [U5 Completion evaluation](units/completion-evaluation.md).

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

This named check makes the ADR-conformance concern explicit inside the two items that already absorb structural fit — it adds **no scored item** and changes **no PASS threshold**; a violation caps the named item at 6, failing via the each-item ≥ 7 rule (identical mechanism to GATE:QUALITY's [Known blind-spot checks](units/completion-evaluation.md)). A **governing ADR** for the change surface is an ADR in the repository's ADR directory (`docs/records/adr/` in this repository; a consuming target's own ADR location) with status `Accepted`/`Proposed` whose Decision scope intersects the change surface, **or** a change hitting a **trigger area** of `docs/development-guideline.md` > ADR Policy > *When to create an ADR* — the list is defined there, in a shipped usage document, and nowhere else.

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
  authorized to make ([U3 Design](units/design.md) > *Report routing*), and its **reason quality** is
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
GATE:QUALITY's re-entry re-score states. The evaluator reads the design documents' **delta sections** for this round ([U3 Design](units/design.md) > *Re-entry*)
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

The `scores` object is what the gate hook reads. Each item is either a number
(`8`) or an object (`{"score": 8, "reason": "..."}`). The hook accepts both.

`fail_hypothesis` records the pre-scoring consider-the-opposite search required by
[`role-contracts.md`](role-contracts.md) > Evaluation AI > Pre-scoring FAIL
hypothesis. It is narrative/audit material: nothing reads it programmatically and no
gate consumes it. It is placed before `scores`.

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `case` | string, non-empty | always | The strongest FAIL argument found. With `disposition: "none_found"` it states **what was searched** (which items, which anchors re-derived). |
| `disposition` | enum `refuted` \| `survived` \| `none_found` | always | Outcome of the refutation attempt. |
| `reflected_in` | array of rubric item names | always present (`[]` when `disposition != "survived"`) | Which scored item(s) recorded the surviving case — the join between the narrative record and the numeric `scores`. "Recorded" does not imply "scored down": an item listed here may still score ≥ 7. |

`remedy_class` (GATE:QUALITY only) maps **each failed item** (score < 7) to the kind of change that
clears it; the orchestrator routes the FAIL's re-entry from it
([U5 Completion evaluation](units/completion-evaluation.md) > *FAIL routing*). It is report material the orchestrator acts on; the hook does not
read it from the report (it reads the routed class the orchestrator records in state).

| Key | Type | Required | Meaning |
|-----|------|----------|---------|
| `remedy_class` | object, one entry per failed item | **on every FAIL** (`{}` on a PASS) | Value enum `doc` \| `test` \| `impl` \| `design` \| `operator`. A failed item with no entry is a contract violation — reject + re-spawn, as for a missing `fail_hypothesis`. `operator` means "not classifiable with confidence" and pauses the cycle for the operator. |
| `rescore` | object | **on a re-entry evaluation** — after a FAIL's re-entry, or after a recommendation attempt or rebuttal ([U5 Completion evaluation](units/completion-evaluation.md) > *Recommendation triage*; [U6 Delivery](units/delivery.md) > *Whether a finding holds*) (absent on a first evaluation) | `source` — the prior report's path; `rescored` — the items scored afresh (the failed items — after a recommendation fix or rebuttal, the items the routed or rebutted recommendations were listed under — plus any inherited item whose anchor the re-entry touched — the re-entry diff at GATE:QUALITY / AUDIT, the decision document's delta section at GATE:PLAN, the amended DIAGNOSE artifact at GATE:HYPOTHESIS); `inherited` — the items whose score is copied from `source`. Every rubric item appears in exactly one of the two lists. `prior_findings` — one entry per finding the prior report recorded on a re-scored item, with `status` `cleared` or `remains` and the ground re-derived from the re-entry diff — for a rebutted finding, from the rebuttal's grounds at the evaluated commit (the re-score's FAIL hypothesis is "the flagged defect still remains", [`role-contracts.md`](role-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis > *Re-entry form*); a prior finding with no entry is a report defect — reject + re-spawn, as for a missing `fail_hypothesis`. `new_findings` — one entry per defect newly seen on a re-scored item (`[]` when none), each with the evaluator's `disposition` — `blocking — scored under <item>`, or `recommendation` (also listed in `recommendations`, and the item's score is not lowered for it) — and its ground. Both lists are report material the orchestrator reads; the hook reads neither. |

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

---

## Hook Trust Boundary

`check-autoflow-gate.sh` does **not** read the AI's `pass`, `avg`, or `min`
fields. It computes them from raw `scores`.

---

## State File Linkage

While AutoFlow is in progress, `.autoflow/issue-{N}.json` records the score
sets per phase. The hook reads from this file at gate points to allow or block
Agent spawns and `git push`/`gh pr create` actions.

The phase keys recorded in the state file are below. The hook **gates** only the
four cause/plan/audit/quality keys; `gate_hypothesis_structure` is recorded in
state but **not gated** by the hook (GATE:HYPOTHESIS structure form —
orchestrator-judged against the structure form's PASS line — *Gate rubrics* >
GATE:HYPOTHESIS > *Structure form* — not enforced at a hook gate point), matching the `gated_phase_keys` allow-list in
`tests/fixtures/gate-schema.json`, which omits it:

- `gate_hypothesis_structure` — GATE:HYPOTHESIS structure form (recorded in state, **not gated** by the hook — orchestrator-judged)
- `gate_hypothesis_cause` — GATE:HYPOTHESIS cause analysis (hook-gated)
- `gate_plan` — GATE:PLAN (hook-gated)
- `audit` — AUDIT (hook-gated)
- `gate_quality` — GATE:QUALITY (hook-gated)

- **[MUST]** When an evaluation's `fail_hypothesis` is recorded in state, it is written at `phases.<phase_key>.fail_hypothesis` — a sibling of `evaluator` and `scores` inside the phase object. **[DENY]** Never at the state file's top level and never as an entry inside `scores`. Recording is permitted, not required.

See [`CLAUDE.md`](../CLAUDE.md#autoflow-state-tracking-hook-integration) for the
full schema.
