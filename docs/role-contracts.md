# Role Contracts

> This document defines the role contracts for the role spawns AutoFlow's modules make: **Evaluation AI**, the **advisor**, the **functional-unit agents**, and the **build unit in a target scope**. What the Coordinator does, outside AutoFlow, is [`core.md`](core.md) > Team Structure. Per-phase spawn model policy: see [`core.md`](core.md) > Spawn Model — Phase-by-Phase.

---

## Role Vocabulary and Spawn Mode

**Role vocabulary.** The usage documents (`CLAUDE.md`, `<autoflow-root>/docs/*.md`, `<autoflow-root>/docs/units/*.md`, `<autoflow-root>/agents/*.md`) name the current roles with two terms and no others. A **role** is a work assignment filled by spawning — by the session that runs a module, or, for the advisor, by the Coordinator — Evaluation AI, the advisor, a functional-unit agent, the criterion-review agents, and the review and delivery analysis spawns. A **role spawn** is one anonymous direct `Agent` invocation filling a role (`subagent_type: autoflow-<role>`), whose return value is its report (*Spawn mode by role lifetime* below).

### Spawn mode by role lifetime

Every role is an anonymous direct spawn ([`core.md`](core.md) > Spawn Model — Phase-by-Phase); each role's mode and per-call scope:

| Role (where it occurs) | Spawn mode | Per-call scope |
|---|---|---|
| Evaluation AI (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY) | anonymous direct | single-shot — scores once and returns; a fresh agent is spawned every call |
| Review aggregator ([`units/review.md`](units/review.md) > *Review aggregation*) and CI-failure reader ([`units/delivery.md`](units/delivery.md) > *CI failure*) | anonymous direct (`subagent_type: autoflow-analyzer`) | single-shot — aggregates a pull request's reviews into one comment and its findings file, or reads the failing check's output and records where its fix is made with its grounds, and returns |
| Criterion-review tracer, in-depth analyzer and reconciler (the criterion-trace, criterion-in-depth and criterion-reconcile modules — [`criterion-review.md`](criterion-review.md) > *Cause reach and rule conflict (stage 2)*, *In-depth analysis and reconciliation*) | anonymous direct (`subagent_type: autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`) | single-shot — the tracer judges stage 2 from the issue body and the stage 1 record and writes its trace; the analyzer examines one criterion's screened cases from its target file and writes its in-depth file; the reconciler settles the review record against the trace and every in-depth file; each is spawned fresh for its module's run |
| Advisor (a decision point in any module's work — *Advisor* below) | anonymous direct (`subagent_type: autoflow-advisor`) | single-shot — answers one decision from its request file, writes its answer record and its `A`-namespace ledger entry, and returns the identifier and the answer in one line; a fresh advisor is spawned for every decision |
| Functional-unit agents (*Functional-unit agents* below) | anonymous direct (`subagent_type: autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`) | one spawn per run of its module — analysis, design or build —, prescribed by the module's goal, its output and its evaluation; a re-run is a fresh spawn given the previous outputs and the findings it answers |

The other modules have no role spawn of their own: criterion-screen is the work of the session that runs it ([`criterion-review.md`](criterion-review.md) > *The four modules*); the delivery and review modules are run by their session, which spawns the CI-failure reader and the review aggregator on the model per `.claude/autoflow/spawn-policy.json`, key `handoff-review-triage`; the review's reviewers are scripts, not role spawns ([`reviewer-backend.md`](reviewer-backend.md)); criteria-apply is a script. The tracer, in-depth analyzer and reconciler run on the model per keys `criterion-trace`, `criterion-in-depth` and `criterion-reconciliation`.

### Model tier revert

A phase whose lower-tier result is materially contradicted on the same attempt runs on the higher tier, `.claude/autoflow/spawn-policy.json` updated in the same commit. The result is an evaluation's PASS — its scores read against the reference values — or a lower-tier **role spawn**'s claim that its outputs are done; the contradicting signal is a later finding on the same surface that the result's rubric or claim covers: an audit's test-first finding or a `Security` score at 3 or below, a quality evaluation's finding, or a review `Medium`+ finding. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert. Seeing the contradiction and making the revert are the Coordinator's ([ADR-0038](records/adr/0038-contract-modules-run-by-the-coordinator.md) D2).

A change to the per-phase assignment follows the same grounds.

---

## Evaluation AI (subagent)

This section is the side of the session that runs an evaluation module: how the Evaluation AI is
spawned, prompted and its result recorded. What the evaluator does — its standard, its conduct, every gate's rubric and its
output — is [`evaluation-system.md`](evaluation-system.md), the one document its agent definition carries with the sections it names.

- Independent evaluator that does not participate in planning or implementation.
- A fresh agent is spawned every call.
- Spawn model: resolved from the spawn policy, never restated here — `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` for the rubric-scored gates (`gate-hypothesis`, `gate-plan`, `audit`, `gate-quality`). Source: `.claude/autoflow/spawn-policy.json`; revert conditions: *Model tier revert* above.
- Spawn mode: **anonymous direct** — `Agent(subagent_type: "autoflow-evaluator", model: "…")` — never a named team spawn. The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores (`<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). Contract: *Spawn mode by role lifetime* above.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type and the path of each input the invocation names (`<autoflow-root>/docs/contracts/<module>.json` > `inputs`) — at GATE:PLAN and GATE:QUALITY the **applied acceptance criteria** (`applied_criteria`, criteria-apply's output) and the ledger's `[ac-decision]` entries (`decisions`) among them. The applied criteria are what the evaluation checks the work against ([`evaluation-system.md`](evaluation-system.md) > GATE:QUALITY > *Completeness — AC-authority check*): an **input the evaluator reads**, never one it may reinterpret, rewrite or judge the merit of. A criterion the evaluator observes defective as a matter of fact — a fact it presumes that does not hold, or a scope that does not fit the problem ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*) — is recorded as a recommendation ([`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format); whether it changes is decided as `[ac-decision]` entries.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — the agent definition carries `<autoflow-root>/docs/evaluation-system.md` and the sections it names ([`core.md`](core.md) > Context Injection), and the prompt names the input files by path. The same principle (file-path-only references to the inputs) applies to every role spawn; see [`core.md`](core.md#cost-control) > Cost Control.
3. **[MUST]** The portion the spawning session writes is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").
5. **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Let it report all findings and let the score rank them ([`evaluation-system.md`](evaluation-system.md) > *Finding coverage*).

### Recording the result

The Evaluation AI returns one JSON object, and the session that runs the evaluation module writes it,
verbatim, to `<out>/evaluation.json` — its scores, their grounds and its recommendations, and no
verdict ([`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format). The module's
check-out checks it against the contract (`<autoflow-root>/docs/contracts/<module>.json` >
`outputs.evaluation`). Reading the scores against the reference values is the Coordinator's
([ADR-0038](records/adr/0038-contract-modules-run-by-the-coordinator.md) D6).

---

## Build unit in a target scope

The build unit (`autoflow-unit-build`; *Functional-unit agents* below) works in the target scope its
invocation names — the target repository, or in a project with sub-repos one sub-repo's directory
([`core.md`](core.md) > Cross-Project Boundary Rules). What it owes the build is
[`units/build.md`](units/build.md) > *What the build owes*; what it owes the scope is below.

- Works directly in the target repository and commits to the branch its invocation names
  (`params.branch`). It does not push: the push and the pull request are the delivery module's
  ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).
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
- Uses the tools its work needs; one that neither this environment nor the target's procedures
  provide is recorded as a tool request, never acquired, and the run does what it can without it
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *The tools the
  work needs*).
- Common rules: [`submodule-common-rules.md`](submodule-common-rules.md).

*Secondary (multi-repo):* in a project with sub-repos (see [`core.md`](core.md) > Project
Information), a changed sub-repo is a target scope of its own: the unit commits there on that
sub-repo's branch, which the delivery module pushes and opens its pull request for
([`units/delivery.md`](units/delivery.md) > *Multi-repo delivery*).

---

## Advisor (first judgment at a decision point)

ADR-0025 D7 moves the first judgment at a decision point from the operator to a dedicated advisor.
This section is the procedure's single home; [`core.md`](core.md) > Development Lifecycle >
*A decision that is not the module's own* routes to it and the module documents cite it.

### Decision points and harness-level blocks

- **A decision point** is a decision the working AI cannot settle on the grounds at hand, or is not
  confident of ([`core.md`](core.md) > Rule Scope, principle 3). An acceptance-criterion
  change, a non-code root cause or a non-code lever, a planning / design / ADR prerequisite the
  analysis records, a finding that repeats an earlier complaint, and a hypothesis evaluation whose
  PASS looks unreachable are where such a decision arises, not decision points by their kind: the
  Coordinator judges each first, and where the grounds the raising report, finding or evaluation
  carries settle it, it decides and records the decision with those grounds in an `O` ledger entry
  under `orchestrator decision` — for an acceptance-criterion change, its `[ac-decision]` entries
  ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*). An un-agreed
  design point, a finding whose fix the AI acting on it cannot place with confidence, and a rebuttal
  the re-score or the reviewer keeps while the two sides still disagree are already decisions the
  working AI could not settle; the module states each in its output as the question for the
  advisor. A security-checklist change (`[checklist-decision]`) is the one decision point by its
  kind: `<autoflow-root>/scripts/gate/security-checklist.sh` counts only an advisor or an operator
  entry ([`decision-ledger.md`](decision-ledger.md) > *Security-checklist decisions*). In the
  criterion review, an item the review could not decide with confidence is one as well, its
  question stated in the item's `## Dispositions` row ([`criterion-review.md`](criterion-review.md) >
  *Authority*). Each decision point is answered by the advisor first.
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial). It is reported to the operator situation-first ([`core.md`](core.md) > Execution
  Principles > Human-decision presentation). A tool, credential, installation or material the
  environment does not provide — for a tool it has, what using it lacks (access, a purpose and
  permitted scope, a permission setting) — is a tool request: the run does what it can without it
  and ends ([`core.md`](core.md) > Development Lifecycle > *Tools*). What follows a decision that
  can end the work — a non-code lever or cause, a prerequisite that comes first, a hypothesis PASS
  not reachable, the last closing the issue only on the operator's confirmation — is the
  Coordinator's. The reference values and the caps are not decision points
  ([`core.md`](core.md) > Rule Scope, principle 1).

### Procedure

1. **Request.** The Coordinator writes `<attempt-dir>/issue-{N}-advisor-request-<k>.md`
   situation-first: the situation in domain terms, the decision asked with each option and what it
   changes, the reading of the module that raised it — the option it leans to, its grounds, and the
   point where those grounds stop settling it — and the anchors (the output paths, the report or
   finding the decision surfaced in). The advisor starts from that reading rather than gathering the
   material anew.
2. **Spawn.** One fresh `autoflow-advisor` per decision, anonymous, model from
   `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model advisor` (its effort is the definition's
   `effort:` line). The prompt names the request file, the ledger and the issue. Where two or more
   decisions are open and none depends on another's answer, their advisors may be spawned together,
   and a decision that depends on another's answer is spawned after that answer is recorded; whether
   to spawn them together or one after another is the Coordinator's judgment, within the
   concurrent-spawn limit (`<autoflow-root>/docs/core.md` > Cost Control).
3. **Answer and record.** The advisor weighs the material itself, writes its answer to
   `<attempt-dir>/issue-{N}-advisor-<ID>.md` in the same situation-first order, and appends one
   `A`-namespace entry per decision to the ledger under the authority `advisor decision`, carrying a
   `- Record:` line to the answer file and the marker and fields the decision's kind requires
   ([`decision-ledger.md`](decision-ledger.md)). Its identifier comes from
   `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> A`, called immediately before the append; the
   call reserves the identifier, so advisors spawned together receive distinct ones
   ([`decision-ledger.md`](decision-ledger.md) > Entry identifier > *Allocation*). It appends with `Edit`, which the gate hook applies to
   the file on disk and checks (*Independence* below), so the prior content is never re-written. It
   returns the identifier and the answer in one line.
4. **Apply.** The Coordinator verifies the anchor — the ledger heading and the record file exist —
   and applies the answer; which module runs next on it is its own
   ([ADR-0038](records/adr/0038-contract-modules-run-by-the-coordinator.md) D2). An advisor that
   reports the decision blocked at the harness level turns it into a harness-level block.

### Independence

The advisor is never the author of what it judges: it is a fresh spawn per decision, not the unit
agent, role spawn or Coordinator whose work raised the point, and its record carries its own grounds.
Its authority is worth only that separation, and the operator's override only its own — so each
is written by its own writer alone and stays as written. Three locks:

- **Authorship — the gate hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`, *Section 1e*,
  state-independent): text a `Write` / `Edit` / `MultiEdit` adds to an `issue-*-ledger.md` that carries an `advisor decision`
  authority or an `A<n>` heading is denied unless the caller's `agent_type` is `autoflow-advisor`;
  text carrying an `operator decision` authority or an `O<n>` heading is denied unless the caller is
  the main session (no `agent_type` — the Coordinator's session, recording its own decision, an
  operator override or instruction, or the criterion review's `[criterion-ready]` entry); the advisor
  adds no `operator decision` and no `O` / `F` / `E` heading.
- **Append-only — the same hook section**: a `Write` / `Edit` / `MultiEdit` is applied to the file
  on disk and must keep the whole prior content as its prefix, so no entry is rewritten or removed.
  A decision changes only by a new entry that names the one it replaces
  (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **The record convention**: a consumer counts `advisor decision` only on an `A<n>` entry and
  `operator decision` only on an `O<n>` entry, and lets an entry replace another only by an explicit
  `- Supersedes:` / `- Overrides:` line (`<autoflow-root>/scripts/gate/security-checklist.sh`,
  `<autoflow-root>/scripts/contracts/criteria-apply.sh`, which locates an entry by its `[ac-decision]`
  marker and reads the authority as recorded).

The threat these locks answer is an agent overstepping in routine work — rewriting a ledger it
meant to append to, or writing an authority that is not its own — not a determined evasion (the
same model as `<autoflow-root>/docs/issue-proposal.md`). Outside the hook's surface: a shell write to a ledger
(redirect, `tee`, `sed -i`, a script), and text that only imitates an entry (a heading-less field
line, a malformed heading, a variant spelling of an authority).

### Operator override

An operator override of an advisor decision is recorded by the Coordinator's main session as an `O`
entry under the authority `operator decision`, with the marker of the entry it overrides and a line
naming that `A` identifier. It supersedes the advisor's entry without a new verified fact — the
override is the authority ([`decision-ledger.md`](decision-ledger.md) > *Advisor decisions and
operator overrides*). Which module runs again on it is the Coordinator's.

### Claude Code's advisor tool (`advisorModel`)

Distinct from the advisor sub-agent above: Claude Code's advisor tool
(<https://code.claude.com/docs/en/advisor>) lets the session's model consult a stronger model
mid-task. AutoFlow neither enables it nor directs its use. It cannot carry a
decision point: its model is configurable and its effort is not, and Claude decides when to call it,
which is why the first judgment is the sub-agent's (ADR-0025 D7).

---

## Functional-unit agents (U2 / U3 / U4)

Three functional modules run their work as a unit agent, prescribed by the module's goal, its output
and its evaluation ([ADR-0038](records/adr/0038-contract-modules-run-by-the-coordinator.md) D1); the
evaluation of each is a module of its own. The criterion review's agents are *Spawn mode by role
lifetime* above; criterion-screen, delivery and review are the work of the session that runs them,
and criteria-apply is a script.

| Unit agent (`subagent_type`) | Module (unit) | Its evaluation module |
|---|---|---|
| `autoflow-unit-analysis` | analysis (U2 Analysis) | hypothesis |
| `autoflow-unit-design` | design (U3 Design) | plan |
| `autoflow-unit-build` | build (U4 Build and verify) | audit, which judges test-first |

- **Method is the unit's.** How the unit reaches its goal — what else it reads, whether it spawns helpers
  or holds a dialogue, how it designs the issue's own verification — is the unit agent's, recorded
  with its grounds in the unit's artifact ([`core.md`](core.md) > Rule Scope, principle 2).
  The definitions (`<autoflow-root>/agents/autoflow-unit-*.md`) name the goal, the output and the
  evaluation, and nothing else of their own; below that they carry the unit's guidance, generated
  ([`core.md`](core.md) > Context Injection).
- **The authority rules hold** (ADR-0025 D3): a unit agent never scores its own artifact, never writes
  the ledger, never pushes, merges or files an issue, and a decision point it meets is stated in its
  output as the question for the advisor.
- **Model and effort** come from the policy rows `unit-analysis`, `unit-design` and `unit-build`,
  held at the values of the phase rows each unit replaced (DIAGNOSE; ARCHITECT; RED /
  GREEN). The helpers a U4 unit spawns when it divides its work take theirs from the rows
  `unit-build-area`, `unit-build-verify` and `unit-build-observe`: each is spawned as
  `general-purpose` with the row's model and with the row's effort passed as the `Agent` tool's
  `effort` parameter, omitted when the row reads out the inherit sentinel
  ([U4 Build and verify](units/build.md) > *Dividing the work*). A helper receives in its prompt
  the AutoFlow root and the text of the rules its work follows
  ([U4 Build and verify](units/build.md) > *What crosses a boundary*).

---

## Evaluation System

The 10-point scale, the reference pass values (PASS Criteria), the evaluation types and the output format have one home —
[`evaluation-system.md`](evaluation-system.md) — and are not copied here. A report in any other shape
than its *Evaluation Output Format* fails the evaluation module's check-out; a re-run is the
Coordinator's.
