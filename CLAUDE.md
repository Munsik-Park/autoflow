# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AutoFlow is a reusable framework for an evaluation-gated, role-separated development lifecycle (`PREFLIGHT` → `HANDOFF`) whose terminal phase hands off an open PR; merge, close and deploy stay outside AutoFlow's authority.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that acceptance-criterion content is never the working AI's — the advisor's first, the operator's by override at the retry stage (ADR-0025 D7) — and the auto-resolution attempt caps are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and by the gates. When the AI is not confident, or the choice is not its own to make, it asks the advisor, whose answer is recorded and applied; the operator is asked only when a call is blocked at the harness level, and reviews — and may override — the advisor's answers at the retry stage ([`docs/role-contracts.md`](docs/role-contracts.md) > Advisor).
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a cycle leaves in the target's tree — are [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Verification and Tools.

## Development Commands

- **Test**: a change's functional verification is a one-shot run of cycle-layer assets under `.autoflow/issue-{N}-local/`, each invoked by its path (`docs/submodule-common-rules.md` > Verification and Tools > *Local verification*). The committed checks are the deployment-level ones (`packaging`, `manifest`), each run directly by its path — the list is the `run:` steps of `.github/workflows/contract-suites.yml`, `plugin-package.yml` and `e2e-dummy-target.yml`.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

For details, see [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md).

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states is asked of the operator in conversation, with the request that the operator create the file or record the fact in it.

A project whose information names sub-repos delivers each changed sub-repo on its own pull request and keeps the host clean by its pointer: [`docs/units/delivery.md`](docs/units/delivery.md) > *Multi-repo delivery*.

## Team Structure

각 역할의 상세 계약은 [`docs/role-contracts.md`](docs/role-contracts.md)를 참조한다.

### AI Orchestrator (host repo)
- Does not write code directly; coordinates role spawns.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly, as may the fix of a comment's divergence or disallowed content in a target's code (`docs/units/completion-evaluation.md` > *Code comments in a target*).

### Evaluation AI — contract: `docs/evaluation-system.md`; spawn and prompt: `docs/role-contracts.md` > Evaluation AI
### Build unit (U4) — contract: `docs/role-contracts.md` > Functional-unit agents; in a target scope: `docs/role-contracts.md` > Build unit in a target scope
### Advisor — contract: `docs/role-contracts.md` > Advisor
### Functional-unit agents (U2 / U3 / U4) — contract: `docs/role-contracts.md` > Functional-unit agents

## Spawn Model — Phase-by-Phase

AutoFlow role spawns and every other subagent spawn choose the model by phase work type rather than inheriting the host session model.

The per-phase assignment itself — every phase's `model`, its `effort`, and the work type that
justifies it — lives in exactly ONE machine-readable place and is **not** restated here:

**`.claude/autoflow/spawn-policy.json`**, read through `scripts/spawn-policy/spawn-policy.sh`:

```
bash scripts/spawn-policy/spawn-policy.sh model  <phase-key>   # the model to declare on the spawn
bash scripts/spawn-policy/spawn-policy.sh effort <phase-key>   # the effort, or the config's own inherit sentinel
bash scripts/spawn-policy/spawn-policy.sh check                # validate the config
```

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy).

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior cycle: `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — every spawn uses a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `.claude/agents/`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. `subagent_type` is the sole declaration channel. The hook owns the role→gate mapping (analysis — `autoflow-unit-analysis` included — / evaluation / advisor / research pass; planning — `autoflow-unit-design`, the ARCHITECT unit → GATE:HYPOTHESIS; implementation — `autoflow-unit-build`, the BUILD unit → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class. A spawn declares **who it is**; it never declares which gate applies to it. See `docs/gate-matching-standard.md` > P3. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST] A unit agent's spawns inherit its gate class** (ADR-0025 D5): a spawn whose caller — the hook input's `agent_type` — is a functional-unit agent needs no role declaration and is judged by that unit's gate class; a declared role that has a gate of its own keeps it as well, so an existing role type is never judged more loosely because a unit spawned it. The caller is the immediate one. The explicit-`model` rule above holds for these spawns too. The unit agents and the advisor are defined in the common frame (#372); each unit is wired into the lifecycle by its own migration step (ADR-0025 D9) — U2 Analysis runs DIAGNOSE, U3 Design runs ARCHITECT, U4 Build and verify runs BUILD (`docs/role-contracts.md` > Functional-unit agents).

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `.autoflow/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope are [`docs/role-contracts.md`](docs/role-contracts.md) > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are [`docs/role-contracts.md`](docs/role-contracts.md) > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

Each unit spawn's documents line is set by its unit document — [`docs/units/analysis.md`](docs/units/analysis.md) > Unit spawn, [`docs/units/design.md`](docs/units/design.md) > Unit spawn, [`docs/units/build.md`](docs/units/build.md) > Unit spawn — and preserves role-minimal injection; what a unit reads beyond it is its own judgment. An Evaluation AI's documents line names one document, [`docs/evaluation-system.md`](docs/evaluation-system.md) — the evaluator's standard, its conduct and the rubrics of all four gates — and no unit document.

## Communication

Communication with a role spawn is the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`; at ARCHITECT that is one `autoflow-unit-design` spawn.
- A spawn writes any body to `.autoflow/*` and returns an anchor + one-line summary ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not an orchestrator channel — the orchestrator resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Cost Control

These rules apply to every cycle.

- **[MUST] Orchestrator context discipline**: what the orchestrator reads directly is its own judgment, recorded with its grounds in the report or ledger entry the phase already produces (Rule Scope, principle 2). A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why. Two rows are fixed (Rule Scope, principle 1): (1) **the orchestrator never scores what a gate scores** — the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and an orchestrator read of those artifacts informs a spot-check, never a verdict; (2) **the orchestrator never receives a unit's body** — the DIAGNOSE, ARCHITECT and BUILD units return only their artifact paths and a one-line summary. The Reporting Format ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format) applies to every direct/ad-hoc `Agent` spawn, scripted-phase or not — the spawn writes its body to `.autoflow/*` and returns only an anchor + one-line summary (e.g. the DIAGNOSE unit writes `.autoflow/issue-N-analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the orchestrator's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `.autoflow/*` body the user reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

### Decision Ledger

A per-issue append-only record, `.autoflow/issue-{N}-ledger.md`, fixes settled decisions. What an entry records, its identifier grammar, and the decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`) — are [`docs/decision-ledger.md`](docs/decision-ledger.md).

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled gate verdict is likewise not overturned by re-reading the issue body. Two exceptions: a verified error in the record itself (`docs/decision-ledger.md` > Entries), and an operator's override of an advisor decision, whose ground is the operator's authority (`docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every role spawn's scope — it is host-owned, written only by the orchestrator and the advisor (what each appends: `docs/decision-ledger.md` > Entries > *Writers*). **[MUST]** Only the advisor adds the authority `advisor decision` or an `A<n>` entry; only the main session adds `operator decision` or an `O<n>` entry; the advisor never adds an `O` / `F` / `E` entry; and a write never changes text already in the ledger — enforced by the gate hook (Hook gates below).
- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. The script holds no state: it derives the serial from the file on disk at call time.
- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh check <ledger>` runs after the appends, and every defect it reports is resolved before the writer returns. `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error. The gate hook runs the same check as a **non-gating advisory** over changed ledgers: it warns, and never denies a tool call over a ledger defect.

## Development Lifecycle — AutoFlow

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

**PREFLIGHT cannot be skipped.** If PREFLIGHT's completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the blocking condition first and report.

Six functional units carry the phases ([`ADR-0025`](docs/records/adr/0025-outcome-gated-functional-units.md) D1). A unit is the unit of prescription — its goal, artifact contract, verification and loop cap — and each has one document (*Unit Document Loading Contract* below). The phase and gate names stay: they are the identifiers the state keys, the ledger headings, the spawn-policy keys and the hook messages carry.

```
U1 Preparation         PREFLIGHT       — prior-cycle resolution (cleanup after external merge/close), Git clean check, remote sync, mode selection, target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op), dev branch and state file creation — the orchestrator's own work, decided from the facts `scripts/preflight/cycle-status.sh` reports
U2 Analysis            DIAGNOSE        — one `autoflow-unit-analysis` spawn writes the analysis report: current structure, the gap to the request, code-change necessity, cause hypotheses + lightweight verification (bug/incident), acceptance-criterion table, scope judgments, affected docs, decision points — its method its own
                       GATE:HYPOTHESIS — one Evaluation AI: structure form (2 or 3 items × 10 points, every issue) + cause form (3 items × 10 points, bug/incident issues only)
U3 Design              ARCHITECT       — one `autoflow-unit-design` spawn writes the architecture decision layer + verification design, its method its own (file rows / suite dispositions / oracle clauses are derived at BUILD, not written here)
                       GATE:PLAN       — Evaluation AI (5 items × 10 points)
U4 Build and verify    BUILD           — one `autoflow-unit-build` spawn implements and verifies the design (test-first, run records, manual checklist, maintained docs, lint), its method its own; then AUDIT
                       AUDIT           — independent Evaluation AI: test-first judged from the build report and git, then 5 items × 10 points, the target's own security checklist at the version `scripts/gate/security-checklist.sh` names (none declared → the rubric alone)
U5 Completion eval.    GATE:QUALITY    — Evaluation AI (10 items × 10 points); the gate is the unit
U6 Delivery            DELIVER         — the orchestrator's own `git push`, a command the hook gates (a changed sub-repo's branch too)
                       INTEGRATE       — the change shown working above its own tests: the system build, health check and functional test, or the project's integration suite
                       HANDOFF         — push and PR creation by the orchestrator's own commands → CI green → configured-reviewer review → review-triage (auto-resolve Medium+ / judge Low) → state inactive once review is clean; scripts read and report (CI, reviewer start, triage case), the orchestrator makes every change; external review merges out of band
```

### Flow Control

The transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

#### U1 Preparation — [`docs/units/preparation.md`](docs/units/preparation.md)

| Transition | Condition |
|------|------|
| PREFLIGHT → DIAGNOSE | earlier cycles resolved, Git clean, remote synced, the three stop conditions passed, and the state file written for `mode: new-issue` or `mode: review-response` (`docs/units/preparation.md` > *What is asked*, *Modes*) |
| PREFLIGHT → resume | the requested issue's own state reads `active:true` → the re-entry point is the orchestrator's judgment over the facts `scripts/preflight/cycle-status.sh --issue N` reports, recorded in the ledger; a gate with no recorded scores is run, never assumed passed (`docs/units/preparation.md` > *Resume*) |
| PREFLIGHT → user | another issue mid-cycle (hold), a pause for a human decision, a dirty tree (resolved only with the user's approval), a Git state that cannot be synced, or a fail-closed stop condition — bundle drift, reviewer-backend CLI absent, a target-declared local check that does not pass after its declared repair → report and stop; DIAGNOSE does not begin (`docs/units/preparation.md`) |

#### U2 Analysis — [`docs/units/analysis.md`](docs/units/analysis.md)

| Transition | Condition |
|------|------|
| DIAGNOSE (prerequisite) → advisor | `mode=new-issue` only. The analysis report's `## Decision points` records that a planning/design/ADR prerequisite is clearly required first → the advisor decides: proceed → GATE:HYPOTHESIS (after a U2 re-run where the analysis stopped at the prerequisite); the prerequisite comes first → the cycle ends with the analysis report (`active:false`, `phase:"awaiting-user"`) — a new issue is filed only on the operator's request; when in doubt, no prerequisite is recorded (`docs/units/analysis.md` > *Report routing*) |
| DIAGNOSE → GATE:HYPOTHESIS | the U2 unit returned, its analysis report carries every required section, and it records no prerequisite (`docs/units/analysis.md` > Unit spawn) |
| GATE:HYPOTHESIS (structure form) → close / reply / advisor | structure FAIL → gap-item-low (already satisfied): mode=new-issue → issue auto-closed + terminated, mode=review-response → reply on PR + active:false (awaiting-external-review), no close. Gap real but Code-change-necessity low (non-code lever) → the advisor decides: a code change is still owed → the cycle continues as on a structure PASS; the lever is non-code → the cycle ends with its report (`active:false`, `phase:"awaiting-user"`) (`docs/units/analysis.md` > *Verification — GATE:HYPOTHESIS*) |
| review-response (a repeated complaint) → advisor | whoever reads a reviewer finding — the HANDOFF triage subagent, or the DIAGNOSE unit — sees it repeat the previous attempt's complaint with a new witness case and records that → the advisor decides the re-entry (its depth, or none). No spawn checks for it on every attempt (`docs/units/delivery.md` > *A repeated complaint*) |
| GATE:HYPOTHESIS (structure form) → cause form / ARCHITECT | structure PASS (code change required) + its recommendations triaged (no attempt open) → bug/incident issues: the cause form's verdict routes; non-bug issues: `verdict` `skipped (non-bug issue)` → ARCHITECT |
| GATE:HYPOTHESIS → ARCHITECT | cause analysis PASS + code change required + its recommendations triaged (no attempt open) |
| GATE:HYPOTHESIS → advisor | non-code root cause confirmed → the advisor decides: a code change is still owed → ARCHITECT; the cause is non-code → the cycle ends with its report (`active:false`, `phase:"awaiting-user"`) |

#### U3 Design — [`docs/units/design.md`](docs/units/design.md)

| Transition | Condition |
|------|------|
| ARCHITECT → GATE:PLAN | the feature design's `## Decision requests` section says `none` (a reduced verification disposition carrying a stated reason is not a request — `docs/units/design.md` > *Report routing*), and the verification design's `## Tools` section carries no `operator` item |
| ARCHITECT (design point) → advisor | the `## Decision requests` section names a design point the unit did not settle → the advisor decides; the answer is an `A` entry, and the cycle continues to GATE:PLAN where it is the option the design took, otherwise to a unit re-run on the answer — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| ARCHITECT (acceptance-criterion content change) → advisor | the `## Decision requests` section proposes excluding, revising or splitting an issue acceptance criterion, or adding one → the advisor decides before GATE:PLAN is spawned; its answer is recorded as `[ac-decision]` entries (`docs/decision-ledger.md`) and the cycle continues to GATE:PLAN — or, where the answer differs from the proposal, to a unit re-run on the entries — consuming no re-entry budget |
| GATE:PLAN → BUILD | plan evaluation PASS + its recommendations triaged (no attempt open) |

#### U4 Build and verify — [`docs/units/build.md`](docs/units/build.md)

| Transition | Condition |
|------|------|
| BUILD → AUDIT | the unit returned (`docs/units/build.md` > *Report routing*) |
| AUDIT (test-first) → BUILD | the AUDIT evaluator does not confirm that a `driving` / `regression` test's Red run precedes its implementation commit with its failure shown in its log → it scores nothing, and a unit re-run takes its `## Test-first` section; consumes the AUDIT FAIL counter (Regressions below) (`docs/evaluation-system.md` > AUDIT > *Test-first*; `docs/units/build.md` > *Verification — AUDIT*) |
| BUILD → ARCHITECT | design contradiction — implementation and tests each faithful to the design while the acceptance criteria are mutually unsatisfiable, reproduced by measurement and recorded in `.autoflow/issue-{N}-green-blocker.md` → ARCHITECT unit re-run → GATE:PLAN re-evaluation → BUILD re-entry (cap: Regressions below) |
| BUILD → user | a harness-level block — a lint chain covering a staged file stays `not-run (unexecuted)` because it is neither executable in this checkout nor covered by a nameable pull-request CI job → report situation-first + pause (`active:false`, `phase:"awaiting-user"`) |
| AUDIT entry (security-checklist change) → advisor | `scripts/gate/security-checklist.sh status` exits `3` (the cycle changed the target's declared security checklist and no `[checklist-decision]` entry covers the committed version) → AUDIT is **not** spawned until the advisor's `[checklist-decision]` entry is recorded and the status re-run; `rejected` → the change is reverted first; consumes no re-entry budget (`docs/units/build.md` > *Security checklist*) |
| AUDIT → GATE:QUALITY | security audit PASS + its recommendations triaged (no attempt open) |

#### U5 Completion evaluation — [`docs/units/completion-evaluation.md`](docs/units/completion-evaluation.md)

| Transition | Condition |
|------|------|
| GATE:QUALITY → DELIVER | completion evaluation PASS + its recommendations triaged (no attempt open) |
| GATE:QUALITY (FAIL) → doc commit / BUILD / ARCHITECT | FAIL routed by each failed item's `remedy_class` (mixed → farthest: `design` > `impl` > `test` > `doc` — `scripts/gate/remedy-route.sh route`): `doc` → orchestrator doc commit → GATE:QUALITY re-score; `test` / `impl` → a BUILD unit re-run with the failed items → AUDIT; `design` → ARCHITECT (consumes the ARCHITECT re-entry counter). The doc route's sweep record and the re-score scope: `docs/units/completion-evaluation.md` > *FAIL routing* / *Re-entry re-score* |
| GATE:QUALITY (FAIL) → advisor | any failed item carries `remedy_class: operator` (the evaluator could not classify it with confidence) → the advisor's answer fixes the class and the cycle re-enters on that class's route. A FAIL report missing `remedy_class` on a failed item is rejected and the evaluator re-spawned (same disposition as a missing `fail_hypothesis`) |

#### U6 Delivery — [`docs/units/delivery.md`](docs/units/delivery.md)

| Transition | Condition |
|------|------|
| DELIVER → INTEGRATE | the cycle's branches pushed, a changed sub-repo's included |
| INTEGRATE → HANDOFF | integration tests pass |
| INTEGRATE → BUILD | integration / bundle failure — fixed `impl` class → a BUILD unit re-run with the failing check → AUDIT → … → INTEGRATE again |
| HANDOFF (review-triage) → thin route / review-response (auto) | the configured-reviewer verdict is `max_severity ≥ Medium` → each Medium+ finding is routed by its `remedy_class` (`scripts/gate/remedy-route.sh route`): `design` → a re-entry from DIAGNOSE or from ARCHITECT, the orchestrator's judgment recorded in the attempt's `[review-autofix]` ledger entry; `impl` / `test` / `doc` → the thin route; `operator` → the advisor fixes the class. A finding that does not hold is rebutted, not routed. The orchestrator never removes the label — the reviewer re-review clears it (`docs/units/delivery.md` > *Review triage*; the case is `scripts/handoff/review-gate.sh` exit `10`) |
| HANDOFF (review-triage) → reviewer re-review / operator | label present but `max_severity < Medium` → label-clear / review-infra failure, not a code finding (`review-gate.sh` exit `12`; a findings file with no readable verdict is exit `2`, and the triage subagent runs again) → re-run the configured-reviewer review; still stuck → escalate (`active:false`, `phase:"awaiting-user"`). Does not consume the 7-attempt cap |
| HANDOFF (review-triage) → advisor / user | auto-resolution hits an advisor criterion (`docs/units/delivery.md` > *Routing*), or a rebutted finding the reviewer keeps while the two sides still disagree → the advisor decides; the 7-attempt cap (`review-gate.sh` exit `11`) → `active:false`, `phase:"awaiting-user"` |
| HANDOFF → end | all PRs cleared of `blocked-by-review` (no Medium+) + Low triage resolved + CI green → the orchestrator sets the state `active:false`, `phase:"awaiting-external-review"` → AutoFlow ends; external review reviews and merges out of band (`docs/units/delivery.md` > *End*) |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF (CI failure) → doc commit / BUILD / ARCHITECT / advisor | `confirm-ci-green.sh` exit `12` → the failing check's `remedy_class`, recorded by an anonymous direct subagent in `.autoflow/issue-{N}-ci-failure.md`, routes as a GATE:QUALITY FAIL does; `operator` → the advisor fixes the class (`docs/units/delivery.md` > *CI-failure re-entry*) |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

#### Any unit

| Transition | Condition |
|------|------|
| BUILD / gate recommendation (acceptance-criterion content change) → advisor | the build report raises a change to an acceptance criterion's content, or a gate recommendation records a criterion defect (`docs/decision-ledger.md` > *A criterion can be wrong*) or its triage hits pause criterion (a) on one → the advisor decides. After its `[ac-decision]` entries the cycle re-enters where the orchestrator judges the decision reaches — ARCHITECT, BUILD, or the point the question arose at — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| any phase (tool or referenced material → user) | a harness-level block: the work needs a tool, or a material an acceptance criterion or the issue body references, that neither this environment nor a procedure in the target's documents or scripts can provide → report situation-first, `active:false`, `phase:"awaiting-user"`. The answer is an `O` ledger entry with the authority `operator decision`; the cycle resumes where it paused, or at an ARCHITECT unit re-run when a verification-design row must change, consuming no re-entry budget (`docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ARCHITECT > *Tools*) |
| GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY (PASS, a recommendation attempt) → doc commit / BUILD / ARCHITECT / DIAGNOSE → that gate's re-score, or → advisor / user | the PASS report's recommendation triage opens an attempt → the transition out of the gate waits until no attempt is open and no rebuttal awaits its re-score; a pause criterion, or a rebutted recommendation the re-score keeps while the two sides still disagree → the advisor decides; the attempt cap → user (`active:false`, `phase:"awaiting-user"`) (`docs/units/completion-evaluation.md` > *Recommendation triage*) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS cause FAIL → a U2 unit re-run (max 2×). GATE:PLAN FAIL → ARCHITECT (max 3×; a BUILD design contradiction re-run consumes this same counter, so ARCHITECT re-entries are capped at 3 per cycle regardless of which phase triggered them; a unit re-run on an advisor answer to the unit's own `## Decision requests` is not a re-entry and consumes no counter — an acceptance-criterion decision is an authority checkpoint inside the design, not a new one — and a return to ARCHITECT that an `[ac-decision]` raised after ARCHITECT calls for consumes none either, and neither does one that the operator's answer to a tool or referenced-material request, or an operator override of an advisor decision, calls for; a return to ARCHITECT to fix a gate recommendation does consume it). AUDIT test-first finding and AUDIT FAIL → a BUILD unit re-run (max 2×, one counter shared by both; how the unit iterates inside a run is its own and is recorded in its report). GATE:QUALITY FAIL → class-routed re-entry (doc commit / BUILD / ARCHITECT by `remedy_class`; max 3× — the cap counts FAILs, not the distance re-entered; a `design` route also consumes the ARCHITECT re-entry counter above). A recommendation attempt at any rubric-scored gate is not a FAIL and consumes no FAIL cap: max 7× on its own window, counted as `docs/units/completion-evaluation.md` > *Recommendation triage* says; a re-score that fails is an ordinary FAIL. INTEGRATE FAIL → BUILD (`impl`). HANDOFF failure → cause classification: CI failure → class-routed re-entry by `remedy_class` (a `design` route consumes the ARCHITECT re-entry counter); environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at HANDOFF) → class-routed re-entry, at the depth the route's recorded judgment names (max 7× — the cap counts attempts, not the distance re-entered, so a thin route consumes one exactly as a re-entry from DIAGNOSE does; on the 7th consecutive (per the count window in `docs/units/delivery.md` > *Routing*) without the `blocked-by-review` label clearing, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total). HANDOFF internal retry exhausted → human. A harness-level block → human.
**Advisor first, operator at the retry stage** (ADR-0025 D7): every row above that routes to the advisor is a decision point — a fresh `autoflow-advisor` answers, its answer is recorded as an `A` ledger entry and applied, and the cycle continues without pausing. The operator stops the forward path only at a harness-level block — a permission denial, or a tool, credential or material the environment does not provide (a review-infrastructure failure the reviewer re-run does not clear is one); PREFLIGHT's fail-closed readiness stop is an independent check, not a decision point, and is unchanged. The operator's judgment joins at the retry stage: at every FAIL and every re-entry the orchestrator's report lists the advisor entries recorded since its previous such report, and at a cap reached the escalation report carries them; the operator may override any of them, recorded as an `O` entry under `operator decision`. Procedure and independence: [`docs/role-contracts.md`](docs/role-contracts.md) > Advisor.
**Push and PR creation**: the orchestrator pushes and opens the PR(s) with its own `git push` / `gh pr create` — the commands the hook gates, never a script that would carry them past it — and confirms CI is green. A script AutoFlow ships for a phase reads and reports; it changes nothing in git, on GitHub or in the cycle's state (ADR-0025 D8). What the PR body carries, the host PR's `Closes #N` included, is the orchestrator's; nothing checks it (`docs/units/delivery.md` > *Push and pull request*). Merging is external; AutoFlow does not merge.

### Unit Document Loading Contract

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **unit document**, not in this core file. This file retains only what every unit needs to *route*: the cross-unit invariants (above), the router (the unit and phase list and the Flow Control table above), the regression / escalation caps (above), the Execution Principles (below), and the state schema (below).

**[MUST]** On entering a phase, Read the document of its unit below **before** acting in that phase. The unit document is the source of truth for that unit's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the unit document each cycle.

| Unit | Phases | Document to Read on entry |
|------|--------|---------------------------|
| U1 Preparation | PREFLIGHT | [`docs/units/preparation.md`](docs/units/preparation.md) (facts: `scripts/preflight/cycle-status.sh`); git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | [`docs/units/analysis.md`](docs/units/analysis.md); unit agent: `.claude/agents/autoflow-unit-analysis.md`; contract: [`docs/role-contracts.md`](docs/role-contracts.md) > Functional-unit agents |
| U3 Design | ARCHITECT, GATE:PLAN | [`docs/units/design.md`](docs/units/design.md); unit agent: `.claude/agents/autoflow-unit-design.md`; contract: [`docs/role-contracts.md`](docs/role-contracts.md) > Functional-unit agents |
| U4 Build and verify | BUILD, AUDIT | [`docs/units/build.md`](docs/units/build.md); unit agent: `.claude/agents/autoflow-unit-build.md`; change surface: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules; checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `scripts/gate/security-checklist.sh` |
| U5 Completion evaluation | GATE:QUALITY | [`docs/units/completion-evaluation.md`](docs/units/completion-evaluation.md) |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | [`docs/units/delivery.md`](docs/units/delivery.md) (incl. Merge Sequencing); reviewer/operator guide: [`docs/external-review-sequencing.md`](docs/external-review-sequencing.md); PR body: [`docs/pr-body-guide.md`](docs/pr-body-guide.md) |

The rubric of every gate — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the unit's: it lives in [`docs/evaluation-system.md`](docs/evaluation-system.md) > *Gate rubrics*, and the unit document routes the gate's result.

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above, and the unit documents and rubrics apply them. Who enforces what: the hook (`.claude/hooks/check-autoflow-gate.sh`) computes PASS from the recorded `scores` — for the score-gated role spawns, `git push` and `gh pr create` — and denies `git push` / `gh pr create` while the `audit` or `gate_quality` record carries `remedy_class`; it counts no FAIL. The FAIL and re-entry counts are the orchestrator's own accounting, and the HANDOFF auto-resolution count is `scripts/handoff/review-gate.sh`'s (exit `11` at 7). The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in [`docs/evaluation-system.md`](docs/evaluation-system.md); how the orchestrator spawns and prompts the evaluator is [`docs/role-contracts.md`](docs/role-contracts.md) > Evaluation AI.

### Execution Principles

- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's design, BUILD's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What is never skipped is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI, the configured-reviewer review and its `blocked-by-review` label, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate.
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `.autoflow/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop), and every role spawn's Bash runs foreground-only; the binding rule lives in `docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — a foreground `sleep` loop polling for a result — is not used. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. One timer is admitted beside that wait, the **cache keep-alive wake**: a running task keeps its own prompt cache warm through its own requests, while the orchestrator sends none, so a wait longer than the prompt-cache TTL expires the orchestrator's cached context and its first turn after the notification re-writes all of it. While a tracked task runs, the orchestrator therefore may arm one backgrounded `sleep` shorter than that TTL (`run_in_background`; 50 minutes at the 1-hour TTL) and end its turn. The turn the timer wakes is not a poll: it reads no transcript or output file of the task — only a cheap anchor-check (a log's modification time, `git log -1`) — re-arms the timer and ends the turn, and the timer is stopped once the task's notification arrives. What the wake observes about the task's progress, and any decision drawn from it, is the orchestrator's judgment, recorded with its grounds in the report or ledger entry the phase already produces. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your report", naming no carrier: the harness picks the carrier by permission mode, and in auto mode a spawn's final plain text is not delivered. There is one delivery path, and it is the return value; what carries a spawn's report is `docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Verify role-spawn claims before dispatch**: every role-spawn report's Evidence anchor (see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document ([`docs/units/analysis.md`](docs/units/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `.autoflow/<name>.md` per [`docs/issue-proposal.md`](docs/issue-proposal.md) and running `scripts/issue/create-issue.sh --draft .autoflow/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.
- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (a harness-level block such as a tool or referenced-material request, a cap reached, a cycle the advisor ended at DIAGNOSE or GATE:HYPOTHESIS) — and in every advisor request and advisor answer record ([`docs/role-contracts.md`](docs/role-contracts.md) > Advisor), the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format), which is anchor-first. The `.autoflow/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.

### AutoFlow State Tracking (Hook integration)

While AutoFlow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

**File naming**: `.autoflow/issue-{N}.json`

**Companion artifact**: `.autoflow/issue-{N}-ledger.md` — the append-only decision ledger ([Decision Ledger](#decision-ledger)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: by the orchestrator, at PREFLIGHT completion.

```json
{
  "active": true,
  "issue": "#N",
  "title": "Issue title",
  "date": "YYYY-MM-DD",
  "cycle": 1,
  "mode": "new-issue",
  "phase": "in-progress",
  "phases": {
    "gate_hypothesis_structure": { "evaluator": "", "scores": {} },
    "gate_hypothesis_cause":     { "evaluator": "", "scores": {}, "verdict": "pending" },
    "gate_plan":                 { "evaluator": "", "scores": {} },
    "audit":                     { "evaluator": "", "scores": {} },
    "gate_quality":              { "evaluator": "", "scores": {} }
  }
}
```

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry and on a HANDOFF review-triage `design` re-entry that starts at ARCHITECT; what each resets is `docs/units/preparation.md` > *Review-response setup* and `docs/units/delivery.md` > *Routing*. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; the review-response setup sets `"review-response"` (target issue's PR is open). The GATE:HYPOTHESIS structure-form disposition reads `mode` rather than re-deriving the PR state. The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF triages the configured-reviewer review result; `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no `blocked-by-review` label remains) and at a structure-gate no-work review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**`verdict` rule** (gate_hypothesis_cause only; when each value is set follows the Flow Control table):

| Issue type | `verdict` value |
|------------|-----------------|
| Bug / incident | `"pending"`, then `"evaluated"` once the cause form is scored |
| Non-bug (feat, chore, docs, refactor, …) | `"skipped (non-bug issue)"` |

The hook's state-file validator admits exactly these values, an empty or absent `verdict`, and `"skipped (feat issue)"` — the value a non-bug cycle recorded before `"skipped (non-bug issue)"`, admitted so such a state file stays valid and never written by a new cycle. Any other value makes the state file malformed, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until it is repaired. If `verdict` is empty or one of the two `skipped` values, the gate is not triggered for the cause-analysis form. Bug issues must be initialised as `"pending"`.

**Score recording**: the orchestrator copies the `scores` object of the Evaluation AI's report into the state file verbatim. The evaluator's own documents fix that object's shape ([`docs/evaluation-system.md`](docs/evaluation-system.md) > Evaluation Output Format), so an evaluator prompt does not restate it ([`docs/role-contracts.md`](docs/role-contracts.md) > Evaluation AI Prompt Rules, rule 2). Each item's score is a number in `0`–`10`, bare or as an object's `score` — shown below; the two shapes may be mixed within one gate. A prose string such as `"9 - reason"` is **not** a score: the hook's state-file validator rejects it, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until the file is repaired.

<!-- SCORE-SHAPE-EXAMPLE -->
```json
{ "decision_grounds": { "score": 9, "reason": "evidence" }, "scope": 8 }
```

This object is the value of `phases.<gate>.scores` in `.autoflow/issue-{N}.json`.

**Remedy class recording** (a GATE:QUALITY FAIL, and an open recommendation attempt at any gate — what opens one is `docs/units/completion-evaluation.md` > *Recommendation triage*): the orchestrator writes the routed class — the farthest of the classes the route was computed from, or `operator` — as `phases.<gate>.remedy_class` (a sibling of `evaluator` and `scores` inside the phase object, the one additive placement the validator admits; never top-level, never inside `scores`). The value is **removed** once the re-score PASSes and no attempt is left open, or is left behind by a later cycle's record of that gate. The hook reads `gate_quality`'s value for the `git commit` gate below, and the presence of a value at `audit` or `gate_quality` for the `git push` / `gh pr create` gates — an open re-entry is not pushed past (`docs/units/completion-evaluation.md` > *Recommendation triage*).

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (a spawn whose caller `agent_type` is a functional-unit agent) → no declaration required; judged by the unit's gate class, and a declared role's own gate also applies (see [Spawn Model](#spawn-model--phase-by-phase) > A unit agent's spawns inherit its gate class).
- `Agent` (role `planning` — `autoflow-unit-design`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` is a `skipped` value (non-bug issue).
- `Agent` (role `implementation` — `autoflow-unit-build`) → GATE:PLAN pass required.
- `Agent` (role `analysis` — `autoflow-analyzer`, `autoflow-unit-analysis` — / `evaluation` / `advisor` / research types) → not score-gated.
- `Write` / `Edit` / `MultiEdit` on an `issue-*-ledger.md` → **state-independently**: a write that changes or removes existing text is denied (append-only); adding an `advisor decision` authority or an `A<n>` entry is denied unless the caller `agent_type` is `autoflow-advisor`; adding `operator decision` or an `O<n>` entry is denied unless the caller is the main session; the advisor adding an `O` / `F` / `E` entry is denied ([`docs/role-contracts.md`](docs/role-contracts.md) > Advisor > *Independence*).
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `.autoflow/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch (`main`) → **denied while a state file has `active:true`**. AutoFlow never merges; merging is external.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`docs/issue-proposal.md`](docs/issue-proposal.md).
- A **backgrounded** run of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on `Bash` (git / gh commands), `Write|Edit|MultiEdit` and `Agent`.

**Completion**: at HANDOFF, once the configured-reviewer review is clean (no PR retains the `blocked-by-review` label — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-cycle resolution reads the file (review-response mode) and, once the PR is observed merged or closed, archives it with the issue's other artifacts (`docs/units/preparation.md` > *What is asked*).
**Forced termination**: also set `active` to `false`.

## Evaluation System
→ [`docs/evaluation-system.md`](docs/evaluation-system.md)

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: [`docs/git-workflow.md`](docs/git-workflow.md)

### PR Wait Rule

**[MUST]** Use the `active` flag as the single start signal: begin a new cycle once every **other** issue's state file reads `active:false`. One issue runs at a time — when another issue reads `active:true`, finish or resolve that cycle first, then start the next. The hook applies the same signal: it admits `git push` / `gh pr create` while every state file reads `active:false`. The hook fails closed on two or more active state files. The readiness check and the requested issue's mode selection are [`docs/units/preparation.md`](docs/units/preparation.md) > *PR Wait Rule* and *Modes*.

### Commit Rules

```
<type>(#<issue>): <description>

Next: <next action>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

Attribution lines (such as `Co-Authored-By`) are not part of the AutoFlow commit format; whether a commit or PR carries one follows the execution environment (harness) and the operator's settings.

- No direct commits to main — always branch + PR.
- No `feat`/`fix` commit while tests fail → use `wip`.
- `git status` before every commit.
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (identifying the chains, execution trust boundary, scoping, outcome vocabulary, evidence anchor): [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation and tests, sub-repo) | Build unit (U4) of that scope | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |
| Comment divergence fix (target code) | Orchestrator (sub-repo: the build unit of that scope) | Orchestrator |
| Sub-repo pointer (gitlink) commit or reconcile merge | Orchestrator  | Orchestrator |

## Reference Documents

- **AutoFlow phase guide**: [`docs/autoflow-guide.md`](docs/autoflow-guide.md)
- **Role contracts**: [`docs/role-contracts.md`](docs/role-contracts.md)
- **Evaluation system**: [`docs/evaluation-system.md`](docs/evaluation-system.md)
- **Git procedures**: [`docs/git-workflow.md`](docs/git-workflow.md)
- **Repo boundary rules**: [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md)
- **Sub-repo common rules**: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md)
