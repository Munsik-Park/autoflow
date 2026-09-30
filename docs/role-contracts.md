# Role Contracts

> This document defines the role contracts for the role spawns that the AI Orchestrator dispatches in AutoFlow: **Evaluation AI**, the **advisor**, the **functional-unit agents**, and the **build unit in a target scope**. The Orchestrator's own coordination responsibilities remain in [`CLAUDE.md`](../CLAUDE.md) > Team Structure. Per-phase spawn model policy: see [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase.

---

## Role Vocabulary and Spawn Mode

**Role vocabulary.** The usage documents (`CLAUDE.md`, `docs/*.md`, `docs/phases/*.md`, `.claude/agents/*.md`) name the current roles with two terms and no others. A **role** is a work assignment the orchestrator fills by spawning — Evaluation AI, the advisor, a functional-unit agent, and the HANDOFF analysis spawns. A **role spawn** is one anonymous direct `Agent` invocation filling a role (`subagent_type: autoflow-<role>`), whose return value is its report (*Spawn mode by role lifetime* below).

### Spawn mode by role lifetime

Every role is an anonymous direct spawn ([`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase); each role's mode and per-call scope:

| Role (where it occurs) | Spawn mode | Per-call scope |
|---|---|---|
| Evaluation AI (GATE:HYPOTHESIS structure/cause, GATE:PLAN, AUDIT, GATE:QUALITY) | anonymous direct | single-shot — scores once and returns; a fresh agent is spawned every call |
| HANDOFF review-triage subagent (finding ingestion and weighing — *Review triage*) and CI-failure classifier (*CI-failure re-entry*) | anonymous direct (`subagent_type: autoflow-analyzer`) | single-shot — ingests the reviewer comment or the failing check's output, records the class and its grounds, and returns; the re-entry it feeds runs through the unit rows |
| Advisor (a decision point in any phase — *Advisor* below) | anonymous direct (`subagent_type: autoflow-advisor`) | single-shot — answers one decision from its request file, writes its answer record and its `A`-namespace ledger entry, and returns the identifier and the answer in one line; a fresh advisor is spawned for every decision |
| Functional-unit agents U2 / U3 / U4 (*Functional-unit agents* below) | anonymous direct (`subagent_type: autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`) | one spawn per unit entry, prescribed by the unit's goal, artifact contract and verification (ADR-0025 D2); a FAIL returns its findings and the previous artifacts to a fresh unit spawn. Defined in the common frame (#372) and wired into the lifecycle by each unit's migration step (ADR-0025 D9): U2 runs DIAGNOSE, U3 runs ARCHITECT and U4 runs BUILD |

Other phases either have no role spawn or are run by the orchestrator: PREFLIGHT (orchestrator, `scripts/preflight/preflight.sh`), BUILD's exit check (orchestrator, `scripts/gate/build-exit-check.sh`), DELIVER / INTEGRATE (orchestrator); HANDOFF is orchestrator-run except its review-triage finding-ingestion / Low-judgment subagent and its CI-failure classifier — both on the model per `.claude/autoflow/spawn-policy.json`, key `handoff-review-triage`.

### Model tier revert

**[MUST]** Revert a phase to the higher tier — updating `.claude/autoflow/spawn-policy.json` in the same commit — when a lower-tier gate's PASS is materially contradicted within the same cycle: a defect that gate's rubric covers surfaces through a BUILD exit-check defect, an AUDIT block, or a reviewer-review Medium+ finding on the same surface. A lower-tier **role spawn** is covered on the same terms: the exit claim it returns — a unit's artifacts done — stands where a gate's PASS stands, and the contradicting signal is the next check's finding on what it produced in the same cycle (the BUILD exit check, AUDIT, GATE:QUALITY), or a reviewer-review Medium+ finding on that artifact. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert.

A change to the per-phase assignment follows the revert rule above.

---

## Evaluation AI (subagent)
- Independent evaluator that does not participate in planning or implementation.
- A fresh agent is spawned every call.
- Spawn model: resolved from the spawn policy, never restated here — `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` for the rubric-scored gates (`gate-hypothesis`, `gate-plan`, `audit`, `gate-quality`). Source: `.claude/autoflow/spawn-policy.json`; revert conditions: *Model tier revert* above.
- Spawn mode: **anonymous direct** — `Agent(subagent_type: "autoflow-evaluator", model: "…")` — never a named team spawn. The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores (`docs/role-common-rules.md` > Result delivery path by spawn mode). Contract: *Spawn mode by role lifetime* above.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `docs/role-contracts.md`, target file paths, and — for GATE:PLAN and GATE:QUALITY — the path of the issue's **acceptance-criterion list** (`.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`) together with the issue decision ledger (`.autoflow/issue-{N}-ledger.md`). Those two are the declared source the AC-authority check diffs against. The list is an **input the evaluator reads**, never one it may reinterpret, rewrite or judge the merit of. A criterion the evaluator observes defective as a matter of fact — a fact it presumes that does not hold, or a scope that does not fit the problem ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*) — is recorded as a recommendation ([`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format); whether it changes is the operator's.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — instruct the AI to read `docs/role-contracts.md > [section]` or `.autoflow/*` file paths directly. The same principle (file-path-only references) applies to every role spawn; see [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list them in `recommendations` (or `blocking_issues` when score-blocking). Each finding states its severity and confidence on its own item (the next bullet) and is reflected in the `score` and `reason`; a finding is never expressed by silently omitting it. The rubric score is the filter; the finding stage prioritizes coverage.
- **[MUST]** Write each `recommendations` item as the object [`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format defines, which also says what an item missing a field costs; a `Medium`+ item's `remedy_class` follows *Remedy class* below. After a PASS the orchestrator triages the list ([`phases/gate-quality.md`](phases/gate-quality.md) > *Recommendation triage*).
- **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Let it report all findings and let the score rank them.

### Pre-scoring FAIL hypothesis (consider-the-opposite)

This subsection binds **every rubric-scored gate** — GATE:HYPOTHESIS (both the structure and cause forms), GATE:PLAN, AUDIT, GATE:QUALITY — and the doc-evaluation form when one is run, as a shared Evaluation AI contract. No gate opts out.

- **[MUST]** Form the FAIL hypothesis first: adopt the hypothesis **"this deliverable must FAIL"** and search for the strongest evidence supporting it, framed in the terms of this evaluation's own rubric items. The search re-derives the deliverable's cited anchors from the current source (`path:line`, command output, `git show HEAD:<file>`) rather than accepting the deliverable's own account of them.
- **[MUST]** Attempt to refute each FAIL case found. A refuted case does not affect the score. A case that survives refutation is carried into the affected item's `reason` and listed in `recommendations` (or `blocking_issues` when score-blocking). A surviving case may coexist with a score of 7 or higher: the routing obligation is to record it, not to lower the item.
- **[MUST]** Assign scores only after the FAIL hypothesis has been formed, searched, and dispositioned. Scoring never precedes the search.
- **[MUST] Re-entry form**. On a re-entry evaluation — one carrying a `rescore` field — the hypothesis for each item in `rescore.rescored` is **"the previously flagged defect still remains"**, searched against the re-entry diff and the prior report's finding for that item; each prior finding is dispositioned `cleared` / `remains` in `rescore.prior_findings`. A prior finding answered by a rebuttal instead of a fix ([`phases/handoff.md`](phases/handoff.md) > *Whether a finding holds*) is searched the same way, against the artifact as it stands and the rebuttal's grounds: `cleared` when the rebuttal holds, `remains` when the finding does. The hypothesis is not "this Nth remedy must FAIL": a defect newly seen on a re-scored item — including one in the text the remedy wrote — is still surfaced (Finding coverage above), and the evaluator judges whether it blocks, recording the judgment and its ground in `rescore.new_findings`; a blocking finding is scored under its item, a non-blocking one is listed in `recommendations` and does not lower the item. The independence rules are untouched — the spawn is fresh and the search still re-derives anchors.
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
from this field ([`phases/gate-quality.md`](phases/gate-quality.md) > FAIL routing, >
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
  `operator` entry stops routing and the advisor decides the class (*Advisor* below).
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: the
  orchestrator rejects it and re-spawns a fresh Evaluation AI, with the same cap (max 2) and the same
  escalation as an empty `fail_hypothesis`.
- **[MUST]** On a re-entry evaluation, score afresh only the items listed in `rescore.rescored` — the
  previously failed items plus any inherited item whose anchor files the re-entry diff touched — and
  copy the rest from the cited prior report (`rescore.source`). The fresh-spawn rule is unchanged;
  the input is narrowed, not the independence. The re-score's subject is the flagged defect: the
  FAIL hypothesis takes its *re-entry form* (above), and `rescore.prior_findings` /
  `rescore.new_findings` carry the dispositions ([`phases/gate-quality.md`](phases/gate-quality.md) >
  Re-entry re-score).

### Code comments in a target (GATE:QUALITY)

Binds the GATE:QUALITY form over a target's code. This repository is excluded: a comment here is
scored under the ordinary items, the `doc` class included.

- **[MUST]** A code comment carries only a sentence that stays true for as long as the code it sits
  on is unchanged. **A comment that diverges from its code, or that carries what a comment does not
  carry, is a `Low` finding** — a restatement of the code, a design ground, an acceptance-criterion,
  issue or PR reference, another file's path or contract, or a change history. Record it in
  `recommendations` with its `path:line` and the severity `Low`; it lowers no item's score, so it is
  never a failed item and carries no `remedy_class`; whether it is fixed is the orchestrator's
  judgment, and the fix is its direct commit ([`phases/gate-quality.md`](phases/gate-quality.md) > *Code comments in a target*).
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
  `not-run` ([`phases/gate-quality.md`](phases/gate-quality.md) > *Test coverage* > *Execution
  omission is not a defect*), and a log that does not carry the line is evidence authored without a
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

## Build unit in a target scope

The U4 build unit (`autoflow-unit-build`; *Functional-unit agents* below) works in the target scope the
orchestrator assigns it — the target repository, or in a multi-repo host one sub-repo's directory
([`CLAUDE.md`](../CLAUDE.md) > Cross-Project Boundary Rules). What it owes the build is
[`phases/build.md`](phases/build.md) > *What the build owes*; what it owes the scope is below.

- Works directly in the target repository and commits to the cycle's branch. It does not push: the
  push is the orchestrator's, at DELIVER ([`phases/deliver.md`](phases/deliver.md)), as is PR
  creation.
- Has read access to other sub-repos; modifications stay within the assigned scope.
- **[MUST]** Runs the target repository's lint chain over the staged files before each commit,
  confirms zero errors attributable to them, and records one outcome word per chain it identified,
  with the grounds of the identification, as the commit's lint-outcome evidence anchor
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on
  the staged surface*); the build report's `## Lint` table carries it.
- **[MUST]** Writes and changes comments under [`submodule-common-rules.md`](submodule-common-rules.md)
  > Change Surface Rules > *Code comments* — a comment attached to code it modifies is updated or
  deleted in the same commit, and deleted when it is uncertain whether it is still true.
- **[MUST]** Runs every Bash command in the **foreground**; never uses `run_in_background`
  ([`role-common-rules.md`](role-common-rules.md) > Bash Execution Mode).
- Uses the tools its work needs; a tool that neither this environment nor the target's procedures
  provide is reported to the orchestrator, never acquired
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *The tools the
  work needs*).
- Common rules: [`submodule-common-rules.md`](submodule-common-rules.md).

*Secondary (multi-repo):* when the host contains submodules (see
[`CLAUDE.md`](../CLAUDE.md#deployment-topology) > Deployment Topology), each affected sub-repo gets
its own build unit, the branch is that sub-repo's fork branch (in the fork-and-PR model), which the
orchestrator pushes to the fork at DELIVER, and PR creation remains the orchestrator's.

---

## Advisor (first judgment at a decision point)

ADR-0025 D7 moves the first judgment at a decision point from the operator to a dedicated advisor, and
the operator's judgment from the forward path to the retry stage. This section is the procedure's
single home; [`CLAUDE.md`](../CLAUDE.md) > Flow Control routes to it and the playbooks cite it.

### Decision points and harness-level blocks

- **A decision point** is any point that pauses for a decision the working AI is not the one to make:
  an acceptance-criterion change (`[ac-decision]`), a security-checklist change
  (`[checklist-decision]`), a non-code root cause or a non-code lever, a planning / design / ADR prerequisite the analysis records,
  a reviewer finding that repeats the previous attempt's complaint, an un-agreed design point, a `remedy_class: operator`, and a
  recommendation or finding the orchestrator cannot route with confidence (a pause criterion, a
  rebuttal the re-score or the reviewer keeps while the two sides still disagree). Each is answered
  by the advisor first.
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial), or a tool, credential, installation or material the environment does not provide. Only
  such a block stops the cycle for the operator on the forward path — situation-first, `active:false`,
  `phase:"awaiting-user"` ([`CLAUDE.md`](../CLAUDE.md) > Execution Principles > Human-decision
  presentation). PREFLIGHT's readiness conditions, the gate thresholds and the caps are not decision
  points and are unchanged ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 1).

### Procedure

1. **Request.** The orchestrator writes `.autoflow/issue-{N}-advisor-request-<k>.md` situation-first:
   the situation in domain terms, the decision asked with each option and what it changes, and the
   anchors (the artifact paths, the report or finding the decision surfaced in). It is the body the
   operator would have been shown; the orchestrator does not weigh the options itself.
2. **Spawn.** One fresh `autoflow-advisor` per decision, anonymous, model from
   `bash scripts/spawn-policy/spawn-policy.sh model advisor` (its effort is the definition's
   `effort:` line). The prompt names the request file, the ledger, the issue, the cycle and the
   phase. The spawn is never score-gated.
3. **Answer and record.** The advisor weighs the material itself, writes its answer to
   `.autoflow/issue-{N}-advisor-<ID>.md` in the same situation-first order, and appends one
   `A`-namespace entry per decision to the ledger under the authority `advisor decision`, carrying a
   `- Record:` line to the answer file and the marker and fields the decision's kind requires
   ([`decision-ledger.md`](decision-ledger.md)). It returns the identifier and the answer in one line.
4. **Apply.** The orchestrator verifies the anchor — the ledger heading and the record file exist —
   and routes the cycle as the operator's answer to that point would have been routed: the
   Flow Control row the point sits on names the route. The cycle does not pause. An advisor that
   reports the decision blocked at the harness level turns it into a harness-level block.

### Independence

The advisor is never the author of what it judges: it is a fresh spawn per decision, not the unit
agent, role spawn or orchestrator whose work raised the point, and its record carries its own grounds.
Its authority is worth only that separation, and the operator's override only its own — so each
is written by its own writer alone and stays as written. Three locks:

- **Authorship — the gate hook** (`.claude/hooks/check-autoflow-gate.sh`, *Section 1e*,
  state-independent): text a `Write` / `Edit` / `MultiEdit` adds to an `issue-*-ledger.md` that carries an `advisor decision`
  authority or an `A<n>` heading is denied unless the caller's `agent_type` is `autoflow-advisor`;
  text carrying an `operator decision` authority or an `O<n>` heading is denied unless the caller is
  the main session (no `agent_type` — the orchestrator recording the operator's answer); the advisor
  adds no `operator decision` and no `O` / `F` / `E` heading.
- **Append-only — the same hook section**: a `Write` / `Edit` / `MultiEdit` is applied to the file
  on disk and must keep the whole prior content as its prefix, so no entry is rewritten or removed.
  A decision changes only by a new entry that names the one it replaces
  (`docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **The record convention**: a consumer counts `advisor decision` only on an `A<n>` entry and
  `operator decision` only on an `O<n>` entry, and lets an entry replace another only by an explicit
  `- Supersedes:` / `- Overrides:` line (`scripts/gate/security-checklist.sh`; the gate backstops
  match the `[ac-decision]` marker and read the authority as recorded).

The threat these locks answer is an agent overstepping in routine work — rewriting a ledger it
meant to append to, or writing an authority that is not its own — not a determined evasion (the
same model as `docs/issue-proposal.md`). Outside the hook's surface: a shell write to a ledger
(redirect, `tee`, `sed -i`, a script), and text that only imitates an entry (a heading-less field
line, a malformed heading, a variant spelling of an authority).

### Operator review at the retry stage

The operator's judgment joins at the retry stage — a unit loop or gate FAIL, a re-entry opening, a
cap reached:

- **At a FAIL or a re-entry** the orchestrator's report of that event lists the `advisor decision`
  entries recorded since its previous such report — identifier, the one-line answer, the record path.
  The cycle continues; the operator's prompts reach the orchestrator between turns, and an override
  given there is applied at once.
- **At a cap reached** the cycle stops for the operator as before ([`CLAUDE.md`](../CLAUDE.md) >
  Flow Control > *Human escalation*), and the escalation report carries the same list.
- **An override** is recorded by the orchestrator as an `O` entry under the authority
  `operator decision`, with the marker of the entry it overrides and a line naming that `A`
  identifier. It supersedes the advisor's entry without a new verified fact — the override is the
  authority ([`decision-ledger.md`](decision-ledger.md) > *Advisor decisions and operator
  overrides*) — and the cycle re-enters where the overridden answer's route reaches, consuming no
  re-entry budget.

### Claude Code's advisor tool (`advisorModel`)

Distinct from the advisor sub-agent above: Claude Code's advisor tool
(<https://code.claude.com/docs/en/advisor>) lets the session's model consult a stronger model
mid-task. It is enabled for in-task consultation, and it is set in the **operator's user settings**
(`~/.claude/settings.json`, `advisorModel`), not in the repository — the grounds and the setting are
`setup/SETUP-GUIDE.md` > *Advisor tool (`advisorModel`)*. It cannot carry a
decision point: its model is configurable and its effort is not, and Claude decides when to call it,
which is why the first judgment is the sub-agent's (ADR-0025 D7).

---

## Functional-unit agents (U2 / U3 / U4)

ADR-0025 D1 replaces the sixteen phases with six functional units as the unit of prescription; D2
prescribes a unit by its goal, its artifact contract, its verification and its loop cap only. The
three unit agents that run a unit's work are defined here; U1, U5 and U6 have none (the fixed steps of U1 and U6 are
scripts the orchestrator runs, D8; U5 is the gate itself).

| Unit agent (`subagent_type`) | Unit | Gate class (hook) | Exit |
|---|---|---|---|
| `autoflow-unit-analysis` | U2 Analysis (DIAGNOSE, GATE:HYPOTHESIS) | analysis — no score gate | `gate_hypothesis_cause`, or the `skipped (non-bug issue)` verdict |
| `autoflow-unit-design` | U3 Design (ARCHITECT, GATE:PLAN) | planning — GATE:HYPOTHESIS pass, or a `skipped` verdict | `gate_plan` |
| `autoflow-unit-build` | U4 Build and verify (BUILD, AUDIT) | implementation — GATE:PLAN pass | `scripts/gate/build-exit-check.sh` and `audit` |

- **Method is the unit's.** How the unit reaches its goal — what it reads, whether it spawns helpers
  or holds a dialogue, how it designs the issue's own verification — is the unit agent's, recorded
  with its grounds in the unit's artifact ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 2).
  The definitions (`.claude/agents/autoflow-unit-*.md`) name the goal, the artifact contract and the
  verification, and nothing else.
- **A unit agent's spawns inherit its gate class.** The hook admits a spawn whose caller
  (`agent_type`) is a unit agent without a role declaration and judges it by the unit's class; a
  declared role that has a gate of its own keeps that gate too, so an existing role type is never
  judged more loosely because a unit spawned it (`docs/gate-matching-standard.md`
  > P3). The caller is the immediate one: a helper's own spawn is judged by its own declaration.
- **The authority rules hold** (ADR-0025 D3): a unit agent never scores its own artifact, never writes
  the state file or the ledger, never pushes, merges or files an issue, and a decision point it meets
  goes to the advisor.
- **Model and effort** come from the policy rows `unit-analysis`, `unit-design` and `unit-build`,
  held at the values of the phase rows each unit replaces (DIAGNOSE; ARCHITECT; RED /
  GREEN), so each migration step's measurement against the baseline isolates the method change.

---

## Evaluation System

### Scoring (10-point scale)

| Score | Meaning | Action |
|------|------|------|
| 9-10 | Excellent | Proceed |
| 7-8  | Good      | Proceed |
| 5-6  | Insufficient | Rework recommended |
| 3-4  | Poor      | Rework required |
| 1-2  | Failing   | Redesign or human decision |

### PASS Criteria

- **[MUST]** Average ≥ 7.5
- **[MUST]** Each item ≥ 7
- **[MUST]** Security ≤ 3 → automatic rework

### Evaluation Types

| Type | Items | Retry |
|------|-------|-------|
| Structure evaluation | Type 1: Behavior gap, Code-change necessity (2) — Type 2: Content gap, Consistency impact, Propagation scope (3) | none (PASS/FAIL single verdict; reuse-neutral; gap-low → close/reply, non-code lever → the advisor decides; no retry. Canonical: [`phases/gate-hypothesis.md`](phases/gate-hypothesis.md) > *Structure form*) |
| Hypothesis evaluation | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× |
| Plan evaluation | Decision grounds, Verification fit, Scope, Tools, Security (5) — the design's intent, never its method; affected files / side effects are derived at BUILD, not scored here; Decision grounds/Scope carry structural-fit & over-engineering across the plan and its verification design (not scored at DIAGNOSE; interpretation and embedded checks: [`phases/gate-plan.md`](phases/gate-plan.md)); a re-entry re-scores the design documents' delta only | max 3× |
| Security audit | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) | max 3× |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

### Evaluation Output Format

The format has one home — [`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format —
and is not copied here: `fail_hypothesis` before `scores`, `remedy_class` per failed item, `rescore`
on a re-entry, `refine_observations` at GATE:QUALITY, and `recommendations` as a list of objects
(subject, item, severity, finding, `remedy_class` on `Medium` and above — *Finding coverage* above).
A report in any other shape is rejected and the evaluator re-spawned, as that section says.
