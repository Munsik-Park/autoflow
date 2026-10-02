# Role Contracts

> This document defines the role contracts for the role spawns that the AI Orchestrator dispatches in AutoFlow: **Evaluation AI**, the **advisor**, the **functional-unit agents**, and the **build unit in a target scope**. The Orchestrator's own coordination responsibilities remain in [`CLAUDE.md`](../CLAUDE.md) > Team Structure. Per-phase spawn model policy: see [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase.

---

## Role Vocabulary and Spawn Mode

**Role vocabulary.** The usage documents (`CLAUDE.md`, `docs/*.md`, `docs/units/*.md`, `.claude/agents/*.md`) name the current roles with two terms and no others. A **role** is a work assignment the orchestrator fills by spawning — Evaluation AI, the advisor, a functional-unit agent, and the HANDOFF analysis spawns. A **role spawn** is one anonymous direct `Agent` invocation filling a role (`subagent_type: autoflow-<role>`), whose return value is its report (*Spawn mode by role lifetime* below).

### Spawn mode by role lifetime

Every role is an anonymous direct spawn ([`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase); each role's mode and per-call scope:

| Role (where it occurs) | Spawn mode | Per-call scope |
|---|---|---|
| Evaluation AI (GATE:HYPOTHESIS structure/cause, GATE:PLAN, AUDIT, GATE:QUALITY) | anonymous direct | single-shot — scores once and returns; a fresh agent is spawned every call |
| HANDOFF review-triage subagent (finding ingestion and weighing — *Review triage*) and CI-failure classifier (*CI-failure re-entry*) | anonymous direct (`subagent_type: autoflow-analyzer`) | single-shot — ingests the reviewer comment or the failing check's output, records the class and its grounds, and returns; the re-entry it feeds runs through the unit rows |
| Advisor (a decision point in any phase — *Advisor* below) | anonymous direct (`subagent_type: autoflow-advisor`) | single-shot — answers one decision from its request file, writes its answer record and its `A`-namespace ledger entry, and returns the identifier and the answer in one line; a fresh advisor is spawned for every decision |
| Functional-unit agents U2 / U3 / U4 (*Functional-unit agents* below) | anonymous direct (`subagent_type: autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`) | one spawn per unit entry, prescribed by the unit's goal, artifact contract and verification (ADR-0025 D2); a FAIL returns its findings and the previous artifacts to a fresh unit spawn. Defined in the common frame (#372) and wired into the lifecycle by each unit's migration step (ADR-0025 D9): U2 runs DIAGNOSE, U3 runs ARCHITECT and U4 runs BUILD |

Other phases either have no role spawn or are run by the orchestrator: PREFLIGHT (orchestrator), DELIVER / INTEGRATE (orchestrator); HANDOFF is orchestrator-run except its review-triage finding-ingestion / Low-judgment subagent and its CI-failure classifier — both on the model per `.claude/autoflow/spawn-policy.json`, key `handoff-review-triage`.

### Model tier revert

**[MUST]** Revert a phase to the higher tier — updating `.claude/autoflow/spawn-policy.json` in the same commit — when a lower-tier gate's PASS is materially contradicted within the same cycle: a defect that gate's rubric covers surfaces through an AUDIT test-first finding, an AUDIT block, or a reviewer-review Medium+ finding on the same surface. A lower-tier **role spawn** is covered on the same terms: the exit claim it returns — a unit's artifacts done — stands where a gate's PASS stands, and the contradicting signal is the next check's finding on what it produced in the same cycle (AUDIT, GATE:QUALITY), or a reviewer-review Medium+ finding on that artifact. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert.

A change to the per-phase assignment follows the revert rule above.

---

## Evaluation AI (subagent)

This section is the orchestrator's side of the Evaluation AI: how it is spawned, prompted and its
result recorded. What the evaluator does — its standard, its conduct, every gate's rubric and its
output — is [`evaluation-system.md`](evaluation-system.md), the one document its spawn names.

- Independent evaluator that does not participate in planning or implementation.
- A fresh agent is spawned every call.
- Spawn model: resolved from the spawn policy, never restated here — `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` for the rubric-scored gates (`gate-hypothesis`, `gate-plan`, `audit`, `gate-quality`). Source: `.claude/autoflow/spawn-policy.json`; revert conditions: *Model tier revert* above.
- Spawn mode: **anonymous direct** — `Agent(subagent_type: "autoflow-evaluator", model: "…")` — never a named team spawn. The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores (`docs/role-common-rules.md` > Result delivery path by spawn mode). Contract: *Spawn mode by role lifetime* above.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `docs/evaluation-system.md`, target file paths, and — for GATE:PLAN and GATE:QUALITY — the path of the issue's **acceptance-criterion list** (`.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`) together with the issue decision ledger (`.autoflow/issue-{N}-ledger.md`). Those two are the declared source the AC-authority check diffs against. The list is an **input the evaluator reads**, never one it may reinterpret, rewrite or judge the merit of. A criterion the evaluator observes defective as a matter of fact — a fact it presumes that does not hold, or a scope that does not fit the problem ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*) — is recorded as a recommendation ([`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format); whether it changes is the operator's.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — instruct the AI to read `docs/evaluation-system.md > [section]` or `.autoflow/*` file paths directly. The same principle (file-path-only references) applies to every role spawn; see [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").
5. **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Let it report all findings and let the score rank them ([`evaluation-system.md`](evaluation-system.md) > *Finding coverage*).

### Recording the result

The hook does **not** read the evaluator's `pass`, `avg` or `min` fields: it computes them from the raw
`scores` the orchestrator records. The phase keys recorded in `.autoflow/issue-{N}.json` are below.
The hook **gates** only the four cause/plan/audit/quality keys; `gate_hypothesis_structure` is
recorded in state but **not gated** by the hook (GATE:HYPOTHESIS structure form — orchestrator-judged
against the structure form's PASS line, [`evaluation-system.md`](evaluation-system.md) > *Gate
rubrics* > GATE:HYPOTHESIS > *Structure form*), matching the `gated_phase_keys` allow-list in
`tests/fixtures/gate-schema.json`, which omits it:

- `gate_hypothesis_structure` — GATE:HYPOTHESIS structure form (recorded in state, **not gated** by the hook — orchestrator-judged)
- `gate_hypothesis_cause` — GATE:HYPOTHESIS cause analysis (hook-gated)
- `gate_plan` — GATE:PLAN (hook-gated)
- `audit` — AUDIT (hook-gated)
- `gate_quality` — GATE:QUALITY (hook-gated)

- **[MUST]** When an evaluation's `fail_hypothesis` is recorded in state, it is written at `phases.<phase_key>.fail_hypothesis` — a sibling of `evaluator` and `scores` inside the phase object. **[DENY]** Never at the state file's top level and never as an entry inside `scores`. Recording is permitted, not required.

See [`CLAUDE.md`](../CLAUDE.md#autoflow-state-tracking-hook-integration) for the full schema.


---

## Build unit in a target scope

The U4 build unit (`autoflow-unit-build`; *Functional-unit agents* below) works in the target scope the
orchestrator assigns it — the target repository, or in a project with sub-repos one sub-repo's directory
([`CLAUDE.md`](../CLAUDE.md) > Cross-Project Boundary Rules). What it owes the build is
[`units/build.md`](units/build.md) > *What the build owes*; what it owes the scope is below.

- Works directly in the target repository and commits to the cycle's branch. It does not push: the
  push is the orchestrator's, at DELIVER ([`units/delivery.md`](units/delivery.md) > *Push and pull request*), as is PR
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

*Secondary (multi-repo):* in a project with sub-repos (see [`CLAUDE.md`](../CLAUDE.md) > Project
Information), a changed sub-repo is a target scope of its own: the unit commits there on that
sub-repo's branch, which the orchestrator pushes at DELIVER, and PR creation remains the
orchestrator's ([`units/delivery.md`](units/delivery.md) > *Multi-repo delivery*).

---

## Advisor (first judgment at a decision point)

ADR-0025 D7 moves the first judgment at a decision point from the operator to a dedicated advisor, and
the operator's judgment from the forward path to the retry stage. This section is the procedure's
single home; [`CLAUDE.md`](../CLAUDE.md) > Flow Control routes to it and the unit documents cite it.

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
   ([`decision-ledger.md`](decision-ledger.md)). It appends with an `Edit` anchored on the ledger's
   last lines, which the gate hook applies to the file on disk and checks (*Independence* below), so
   the prior content is never reproduced. It returns the identifier and the answer in one line.
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
three unit agents that run a unit's work are defined here; U1, U5 and U6 have none (U1 and U6 are the orchestrator's
own work, with scripts that read and report, D8; U5 is the gate itself).

| Unit agent (`subagent_type`) | Unit | Gate class (hook) | Exit |
|---|---|---|---|
| `autoflow-unit-analysis` | U2 Analysis (DIAGNOSE, GATE:HYPOTHESIS) | analysis — no score gate | `gate_hypothesis_cause`, or the `skipped (non-bug issue)` verdict |
| `autoflow-unit-design` | U3 Design (ARCHITECT, GATE:PLAN) | planning — GATE:HYPOTHESIS pass, or a `skipped` verdict | `gate_plan` |
| `autoflow-unit-build` | U4 Build and verify (BUILD, AUDIT) | implementation — GATE:PLAN pass | `audit`, test-first judged by its evaluator |

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

The 10-point scale, the PASS criteria, the evaluation types and the output format have one home —
[`evaluation-system.md`](evaluation-system.md) — and are not copied here. A report in any other shape
than its *Evaluation Output Format* is rejected and the evaluator re-spawned, as that section says.
