# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AutoFlow is a reusable framework for an evaluation-gated, role-separated development lifecycle (`PREFLIGHT` → `HANDOFF`) whose terminal phase hands off an open PR; merge, close and deploy stay outside AutoFlow's authority. In the methodology documents, `{{REPO_*}}`/`{{GITHUB_ORG}}` are generalized identifiers the operator reads as its own service's value (derived at session time from the target's Git remote, `origin/HEAD`), not tokens an installer substitutes.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that acceptance-criterion content is the operator's, and the auto-resolution attempt caps are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and by the gates. When the AI is not confident, or the choice is the operator's to make, it asks the operator.
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a cycle leaves in the target's tree — are [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Verification and Tools.

## Development Commands

- **Test**: a change's functional verification is a one-shot run of cycle-layer assets under `.autoflow/issue-{N}-local/`, each invoked by its path (`docs/submodule-common-rules.md` > Verification and Tools > *Local verification*). The committed checks are the deployment-level ones (`packaging`, `manifest`), each run directly by its path — the list is the `run:` steps of `.github/workflows/contract-suites.yml`, `plugin-package.yml` and `e2e-dummy-target.yml`.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* when the host contains submodules, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* when the host contains submodules, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

For details, see [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md).

## Deployment Topology

"Single-repo" and "multi-repo" classify a project by **submodule count**, independent of repository count or the scope of any individual change.

- **single-repo** = the host repository contains **zero submodules**. The Submodule AI operates as the Developer AI in the orchestrator's own repository, fork/upstream handling is omitted, and the orchestrator commits code changes directly.
- **multi-repo** = the host repository contains **one or more submodules**. One submodule and N submodules follow the identical contract: full fork-and-PR mechanics apply, sub-repo AIs own their directories, and the orchestrator coordinates and opens PRs.

Classification is determined solely by submodule count, evaluated at PREFLIGHT and re-confirmed at HANDOFF. A multi-repo project applies the multi-repo procedure to every issue, including issues whose changes land only in host files: change scope decides which steps execute, while topology decides which procedure governs them.

This project: host repository with **zero submodules** → **single-repo**.

## Team Structure

각 역할의 상세 계약은 [`docs/role-contracts.md`](docs/role-contracts.md)를 참조한다.

### AI Orchestrator (host repo)
- Does not write code directly; coordinates role spawns.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly, as may the fix of a comment's divergence or disallowed content in a target's code (`docs/phases/gate-quality.md` > *Code comments in a target*).

### Evaluation AI — contract: `docs/role-contracts.md` > Evaluation AI
### Test AI — contract: `docs/role-contracts.md` > Test AI
### Submodule AI — contract: `docs/role-contracts.md` > Submodule AI

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

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy). **One carve-out, and only one**: the `policy-load` transcription sub-agent at the top of each deliberation Workflow omits `model`.

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior cycle: `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — every spawn uses a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-loopcheck` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator`, defined in `.claude/agents/`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. `subagent_type` is the sole declaration channel. The hook owns the role→gate mapping (analysis / evaluation / research pass; planning → GATE:HYPOTHESIS; implementation / testing → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class. A spawn declares **who it is**; it never declares which gate applies to it. See `docs/gate-matching-standard.md` > P3. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `.autoflow/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope — the ARCHITECT relay participants' resumption by agent ID included — are [`docs/role-contracts.md`](docs/role-contracts.md) > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are [`docs/role-contracts.md`](docs/role-contracts.md) > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

**[MUST]** Role-scoped injection does not break DIAGNOSE context separation: the structure-analysis path (Phase A) and the issue-analysis path (Phase B) receive disjoint document sets. The per-role injection whitelist — which baseline/review/ADR doc is allowed into which DIAGNOSE phase — is the DIAGNOSE playbook's body ([`docs/phases/analysis.md`](docs/phases/analysis.md)). ARCHITECT-onward injection guidance lives in [`docs/phases/architect.md`](docs/phases/architect.md) > Document injection (ARCHITECT onward) and preserves role-minimal injection and [Deliberation Isolation](#deliberation-isolation-delegated-facilitation).

## Communication

Communication with a role spawn is the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**. There is no team to create, no mailbox, and no persistent teammate.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to `.autoflow/*` and returns an anchor + one-line summary ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format).
- No team is created and no spawn carries `team_name` or `name`. `SendMessage` has exactly one use — waking an ARCHITECT relay participant by its agent ID for its next turn; it is never a report channel, and a participant's answer arrives as the task notification of that resumed spawn. A multi-repo topology that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Cost Control

These rules apply to every cycle.

- **[MUST] Orchestrator context discipline**: what the orchestrator reads directly is its own judgment, recorded with its grounds in the report or ledger entry the phase already produces (Rule Scope, principle 2). A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why. Two rows are fixed (Rule Scope, principle 1): (1) **the orchestrator never scores what a gate scores** — the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and an orchestrator read of those artifacts informs a spot-check, never a verdict; (2) **the orchestrator never receives a deliberation body** — an ARCHITECT transcript turn or a participant report reaches it only as the Record workflow's structured result and artifact paths (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation)). The Reporting Format ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format) applies to every direct/ad-hoc `Agent` spawn, scripted-phase or not — the spawn writes its body to `.autoflow/*` and returns only an anchor + one-line summary (e.g. DIAGNOSE Phase A/B/3 write `.autoflow/issue-N-phase-*.md` and return a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the orchestrator's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `.autoflow/*` body the user reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

### Deliberation Isolation (delegated facilitation)

Multi-participant deliberation phases (ARCHITECT; the Developer-AI ↔ Test-AI cause-branch exchange in VERIFY) run inside an **isolated facilitation sub-context**, not in the orchestrator's own turn stream.

- **[MUST]** A multi-participant deliberation never runs in the orchestrator's own turn stream, and it is never a nested Agent Team: ARCHITECT is an orchestrator relay of two persistent participants on `.autoflow/issue-{N}-architect-transcript.md`, closed by the `architect-deliberation` Record `Workflow`; the VERIFY cause-branch is the `verify-cause-branch` `Workflow` (Claude Code v2.1.154+). Their realization, return contract and the orchestrator-side verification (spot-checks of targeted excerpts, never a full read-and-score) are [`docs/role-contracts.md`](docs/role-contracts.md) > Facilitator; the relay procedure and its termination are [`docs/phases/architect.md`](docs/phases/architect.md). Reference scripts: `.claude/workflows/{architect-deliberation,verify-cause-branch}.js`; relay state: `scripts/architect/relay-state.sh`.

#### Decision Ledger

A per-issue append-only record, `.autoflow/issue-{N}-ledger.md`, fixes settled decisions. What an entry records, its identifier grammar, and the operator-decision entries (`[ac-decision]`, `[checklist-decision]`) are [`docs/decision-ledger.md`](docs/decision-ledger.md).

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled gate verdict is likewise not overturned by re-reading the issue body. The one exception — a verified error in the record itself — is `docs/decision-ledger.md` > Entries.
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every role spawn's scope — it is host-owned, written only by the orchestrator and its facilitator delegate (what each appends: `docs/decision-ledger.md` > Entries > *Writers*).
- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. The script holds no state: it derives the serial from the file on disk at call time.
- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh check <ledger>` runs after the appends, and every defect it reports is resolved before the writer returns. `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error. The gate hook runs the same check as a **non-gating advisory** over changed ledgers: it warns, and never denies a tool call over a ledger defect.

### Discussion Protocol

→ Single source of truth: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Discussion Protocol

The orchestrator and every role spawn follow the same rules. Core: UNDERSTAND → VERIFY → EVALUATE → RESPOND (ACCEPT / COUNTER / PARTIAL / ESCALATE). No groundless agreement, no evaluation without reading the relevant files, devil's advocate required on the first exchange.

## Development Lifecycle — AutoFlow

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

**PREFLIGHT cannot be skipped.** If PREFLIGHT's completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the blocking condition first and report.

```
PREFLIGHT       : Pre-Work          — prior-cycle resolution (cleanup after external merge/close), Git clean check, remote sync, dev branch creation, target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op)
DIAGNOSE        : Issue Analysis    — intake readiness triage (new-issue: planning/design/ADR pre-req filter), affected scope, hypothesis classification, lightweight verification, task decomposition, affected docs
GATE:HYPOTHESIS : Hypothesis Eval   — Evaluation AI (3 items × 10 points), bug/incident issues only
ARCHITECT       : Plan Synthesis    — orchestrator-relayed persistent participants (Developer AI + Test AI) discuss on a transcript file; a Record Workflow writes the architecture decision layer + verification design (file rows / suite dispositions / oracle clauses are derived at RED/GREEN, not written here)
GATE:PLAN       : Plan Evaluation   — Evaluation AI (5 items × 10 points)
DISPATCH        : Task Assignment   — each role's task delivered in its phase-entry direct spawn prompt, Test AI then Developer AI (acceptance criteria + verification design)
RED             : Test Writing      — Test AI writes tests from acceptance criteria; Red confirmation
GREEN           : Implementation    — Developer AI writes minimum code that satisfies the in-scope acceptance criteria and passes the automated tests
VERIFY          : Test Run + Check  — Green confirmation; on failure, branch by cause; minimal-implementation check
REFINE          : Refactor          — Developer AI cleanup; Test AI re-confirms Green
VALIDATE        : Verification Done — automated tests all PASS + manual checklist itemized + maintained docs updated
AUDIT           : Security Audit    — independent Evaluation AI (5 items × 10 points), the target's own security checklist at the version `scripts/gate/security-checklist.sh` names (none declared → the rubric alone)
GATE:QUALITY    : Completion Eval   — Evaluation AI (10 items × 10 points)
DELIVER         : Sub-Repo Push     — each Submodule AI pushes its fork branch; Submodule AI shutdown
INTEGRATE       : Integration Test  — system build, health check, functional test (single-repo: project-level integration test)
HANDOFF         : PR + Hand-off     — push dev branch → sub-repo PRs → host PR (Closes #N) → CI green → configured-reviewer review → review-triage (auto-resolve Medium+ / judge Low) → state inactive once review is clean; external review merges out of band
```

### Flow Control

| Transition | Condition |
|------|------|
| PREFLIGHT → DIAGNOSE | Git clean, remote sync done |
| PREFLIGHT → user | a fail-closed stop condition fails — bundle drift, reviewer-backend CLI absent, or a target-declared local check that does not pass after its declared repair → report and stop; DIAGNOSE does not begin (`docs/phases/preflight.md`) |
| PREFLIGHT (review-response) → DIAGNOSE bounded / full | `scripts/review/scope-bounded.sh entry` prints `scope-bounded: true` → bounded path; otherwise the full path (`docs/phases/preflight.md` > *Scope-bounded entry*) |
| DIAGNOSE (intake readiness triage) → user | `mode=new-issue` only. A planning/design/ADR prerequisite is clearly required first → `.autoflow/issue-{N}-triage.md`, presented situation-first, pause (`active:false`, `phase:"awaiting-user"`); ambiguous → PASS to structure analysis (`docs/phases/analysis.md`) |
| DIAGNOSE (intake readiness triage) → structure analysis | triage PASS (no clear prerequisite) → Phase A/B fan-out begins |
| DIAGNOSE (structure eval) → close / reply / user | GATE:HYPOTHESIS structure FAIL → gap-item-low (already satisfied): mode=new-issue → issue auto-closed + terminated, mode=review-response → reply on PR + active:false (awaiting-external-review), no close. Gap real but Code-change-necessity low (non-code lever) → report to user + pause |
| review-response loop check → user | the trigger comment repeats the immediately-prior review-response attempt's complaint class with a new witness case → reply on PR + await the user's re-entry decision (`phase: awaiting-user`). Runs once per review-response attempt, on every route (`docs/phases/analysis.md` > *Review-response loop check*) |
| DIAGNOSE (structure eval) → DIAGNOSE (cause) | GATE:HYPOTHESIS structure PASS (code change required) + its recommendations triaged (no attempt open) |
| DIAGNOSE → GATE:HYPOTHESIS (cause) | hypothesis classification + lightweight verification done (bug/incident issues) |
| DIAGNOSE → ARCHITECT | affected scope identified (feat issues — skip GATE:HYPOTHESIS cause) |
| GATE:HYPOTHESIS → ARCHITECT | cause analysis PASS + code change required + its recommendations triaged (no attempt open) |
| GATE:HYPOTHESIS → user | non-code root cause confirmed → report to user |
| ARCHITECT → GATE:PLAN | the deliberation's report carries no un-agreed point, no agreed conclusion changes an acceptance criterion's content (a reduced verification disposition carrying a stated reason is not one — `docs/phases/architect.md` > *Report routing*), and the verification design's `## Tools` section carries no `operator` item |
| ARCHITECT (un-agreed) → ARCHITECT / user | the report raises an un-agreed point → one orchestrator judgment: discuss further on a `brief`, or stop — report situation-first, `active:false`, `phase:"awaiting-user"` (ARCHITECT > *Report routing*) |
| ARCHITECT (acceptance-criterion content change) → user | an agreed conclusion excludes, revises or splits an issue acceptance criterion, or adds one → report situation-first, `active:false`, `phase:"awaiting-user"`; GATE:PLAN is **not** spawned. The answer is recorded as `[ac-decision]` entries (`docs/decision-ledger.md`); the cycle then continues to GATE:PLAN, consuming no re-entry budget |
| GREEN / VERIFY / REFINE / gate recommendation (acceptance-criterion content change) → user | a role's report raises a change to an acceptance criterion's content, or a gate recommendation records a criterion defect (`docs/decision-ledger.md` > *A criterion can be wrong*) or its triage hits pause criterion (a) on one → report situation-first, `active:false`, `phase:"awaiting-user"`. After the `[ac-decision]` entries the cycle re-enters where the orchestrator judges the decision reaches — ARCHITECT, GREEN, or the point it paused at — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| any phase (tool or referenced material → user) | the work needs a tool, or a material an acceptance criterion or the issue body references, that neither this environment nor a procedure in the target's documents or scripts can provide → report situation-first, `active:false`, `phase:"awaiting-user"`. The answer is an `O` ledger entry with the authority `operator decision`; the cycle resumes where it paused, or at ARCHITECT on a `brief` when a verification-design row must change, consuming no re-entry budget (`docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ARCHITECT > *Tools*) |
| GATE:PLAN → DISPATCH | plan evaluation PASS + its recommendations triaged (no attempt open) |
| DISPATCH → RED | task instructions delivered (Test AI starts first) |
| RED → GREEN | tests written + Red confirmed — every `driving` / `regression` test fails; a `characterization` test may already pass |
| GREEN → VERIFY | implementation done (or, when the acceptance criteria are mutually unsatisfiable, the satisfiable subset implemented and the contradiction recorded — see GREEN playbook) |
| VERIFY → REFINE | all tests PASS + minimal-implementation and mock-boundary fidelity checks pass |
| REFINE → VALIDATE | refactor done + Green re-confirmed |
| VERIFY → GREEN | implementation issue → Developer AI re-implements |
| VERIFY → RED | test issue → Test AI fixes test → re-Red → GREEN re-entry |
| VERIFY → Evaluation AI | deadlock (both claim "no problem") → Evaluation AI arbitrates; its verdict routes to RED (test misreads an AC), GREEN (implementation misses an AC), or human (undecidable), and hands off to ARCHITECT when it finds the acceptance criteria themselves mutually unsatisfiable (design contradiction — row below) |
| VERIFY → ARCHITECT | design contradiction — implementation and test each faithful to the design while the acceptance criteria are mutually unsatisfiable, reproduced by measurement and recorded in `.autoflow/issue-{N}-*-green-blocker.md` → ARCHITECT re-deliberation → GATE:PLAN re-evaluation → RED re-entry (cap: Regressions below) |
| VALIDATE → AUDIT | automated tests all PASS + manual checklist itemized |
| VALIDATE → user | lint-chain check: a discovered chain covering a staged file is `not-run (unexecuted)` and is neither executable in this checkout nor covered by a nameable pull-request CI job → report situation-first + pause (`active:false`, `phase:"awaiting-user"`) |
| AUDIT entry (security-checklist change) → user | `scripts/gate/security-checklist.sh status` exits `3` (the cycle changed the target's declared security checklist and no `[checklist-decision]` entry covers the committed version) → report situation-first, `active:false`, `phase:"awaiting-user"`; AUDIT is **not** spawned; consumes no re-entry budget (`docs/phases/audit.md`) |
| AUDIT → GATE:QUALITY | security audit PASS + its recommendations triaged (no attempt open) |
| GATE:QUALITY → DELIVER | completion evaluation PASS + its recommendations triaged (no attempt open) |
| GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY (PASS, a recommendation attempt) → doc commit / RED / GREEN / ARCHITECT / DIAGNOSE → that gate's re-score, or → user | the PASS report's recommendation triage opens an attempt → the transition out of the gate waits until no attempt is open and no rebuttal awaits its re-score; a pause criterion, the attempt cap, or a rebutted recommendation the re-score keeps while the two sides still disagree → user (`active:false`, `phase:"awaiting-user"`) (`docs/phases/gate-quality.md` > *Recommendation triage*) |
| GATE:QUALITY (FAIL) → doc commit / RED / GREEN / ARCHITECT | FAIL routed by each failed item's `remedy_class` (mixed → farthest: `design` > `impl` > `test` > `doc` — `scripts/gate/remedy-route.sh route`): `doc` → orchestrator doc commit → GATE:QUALITY re-score; `test` → RED; `impl` → GREEN → VERIFY step 1 → REFINE → VALIDATE; `design` → ARCHITECT (consumes the ARCHITECT re-entry counter). The doc route's sweep record and the re-score scope: `docs/phases/gate-quality.md` > *FAIL routing* / *Re-entry re-score* |
| GATE:QUALITY (FAIL) → user | any failed item carries `remedy_class: operator` (the evaluator could not classify it with confidence) → report situation-first, `active:false`, `phase:"awaiting-user"`; the operator's answer fixes the class and the cycle re-enters on that class's route. A FAIL report missing `remedy_class` on a failed item is rejected and the evaluator re-spawned (same disposition as a missing `fail_hypothesis`) |
| DELIVER → INTEGRATE | sub-repo push + Submodule AI shutdown done |
| INTEGRATE → HANDOFF | integration tests pass |
| INTEGRATE → GREEN | integration / bundle failure — fixed `impl` class → GREEN → VERIFY step 1 → REFINE → VALIDATE |
| HANDOFF (review-triage) → thin route / review-response (auto) | the configured-reviewer verdict is `max_severity ≥ Medium` → each Medium+ finding is routed by its `remedy_class` (`scripts/gate/remedy-route.sh route`): `design` → a re-entry from DIAGNOSE or from ARCHITECT, the orchestrator's judgment recorded in the attempt's `[review-autofix]` ledger entry; `impl` / `test` / `doc` → the thin route; `operator` → pause. A finding that does not hold is rebutted, not routed. The loop check runs on every route, and the orchestrator never removes the label — the reviewer re-review clears it (`docs/phases/handoff.md` > step 6.5) |
| HANDOFF (review-triage) → reviewer re-review / operator | label present but `max_severity < Medium` (or no verdict) → label-clear / review-infra failure, not a code finding → re-run the step-6 configured-reviewer review; still stuck → escalate (`active:false`, `phase:"awaiting-user"`). Does not consume the 7-attempt cap |
| HANDOFF (review-triage) → user | auto-resolution hits a user-decision criterion or the 7-attempt cap, or a rebutted finding the reviewer keeps while the two sides still disagree → `active:false`, `phase:"awaiting-user"` (HANDOFF step 6.5) |
| HANDOFF → end | all PRs cleared of `blocked-by-review` (no Medium+) + Low triage resolved + CI green (host PR carries `Closes #N`) → state `active:false` → AutoFlow ends; external review reviews and merges out of band |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF (CI failure) → doc commit / RED / GREEN / ARCHITECT / user | `confirm-ci-green.sh` exit `12` → the failing check's `remedy_class`, recorded by an anonymous direct subagent in `.autoflow/issue-{N}-ci-failure.md`, routes as a GATE:QUALITY FAIL does; `operator` → pause (`active:false`, `phase:"awaiting-user"`) (`docs/phases/handoff.md` > *CI-failure re-entry*) |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS cause FAIL → DIAGNOSE (max 2×). GATE:PLAN FAIL → ARCHITECT (max 3×; a VERIFY design contradiction re-deliberation consumes this same counter, so ARCHITECT re-entries are capped at 3 per cycle regardless of which phase triggered them; a re-discussion the orchestrator runs after an un-agreed report is not a re-entry and consumes no counter; an acceptance-criterion pause is likewise a human authority checkpoint inside that deliberation, not a new one, and a return to ARCHITECT that an `[ac-decision]` raised after ARCHITECT calls for consumes none either, and neither does one the operator's answer to a tool or referenced-material request calls for; a return to ARCHITECT to fix a gate recommendation does consume it). VERIFY FAIL → cause-branched fix (max 3 round-trips). REFINE FAIL → Developer AI fixes and re-runs (max 2×; on second failure, abandon refactor and proceed to VALIDATE with the Green state). AUDIT FAIL → fix and re-evaluate (max 2×). GATE:QUALITY FAIL → class-routed re-entry (doc commit / RED / GREEN / ARCHITECT by `remedy_class`; max 3× — the cap counts FAILs, not the distance re-entered; a `design` route also consumes the ARCHITECT re-entry counter above). A recommendation attempt at any rubric-scored gate is not a FAIL and consumes no FAIL cap: max 7× on its own window, counted as `docs/phases/gate-quality.md` > *Recommendation triage* says; a re-score that fails is an ordinary FAIL. INTEGRATE FAIL → GREEN (`impl`). HANDOFF failure → cause classification: CI failure → class-routed re-entry by `remedy_class` (the GREEN ↔ VERIFY round-trip and ARCHITECT re-entry caps apply); environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at HANDOFF) → class-routed re-entry, at the depth the route's recorded judgment names (max 7× — the cap counts attempts, not the distance re-entered, so a thin route consumes one exactly as a re-entry from DIAGNOSE does; on the 7th consecutive (per the count window in `docs/phases/handoff.md` step 6.5) without the `blocked-by-review` label clearing, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total). VERIFY deadlock other than a design contradiction, unresolved by Evaluation AI arbitration → human. HANDOFF internal retry exhausted → human.
**PR creation**: at HANDOFF, the orchestrator opens the PR(s), places `Closes #N` on the host PR, and confirms CI is green. Merging is external; AutoFlow does not merge.

### Phase Playbook Loading Contract

Each phase's procedure body — its numbered steps, scoring rubric, and phase-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **playbook**, not in this core file. This file retains only what every phase needs to *route*: the cross-phase invariants (above), the router (the phase list and Flow Control table above), the regression / escalation caps (above), the Execution Principles (below), and the state schema (below).

**[MUST]** On entering a phase, Read its playbook below **before** acting in that phase. The playbook is the source of truth for that phase's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the playbook each cycle.

| Phase | Playbook to Read on entry |
|-------|---------------------------|
| PREFLIGHT | [`docs/phases/preflight.md`](docs/phases/preflight.md); git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| DIAGNOSE | [`docs/phases/analysis.md`](docs/phases/analysis.md) — intake readiness triage (new-issue), 3-Phase A/B/3 analysis, per-role injection whitelist, issue-type scoring rubric, FAIL disposition, bias prevention |
| GATE:HYPOTHESIS | [`docs/phases/gate-hypothesis.md`](docs/phases/gate-hypothesis.md) |
| ARCHITECT | [`docs/phases/architect.md`](docs/phases/architect.md) (the relay procedure); facilitator contract: [`docs/role-contracts.md`](docs/role-contracts.md) > Facilitator; participant prompt: `.claude/agents/autoflow-planner.md`; isolation rules: this file > Deliberation Isolation |
| GATE:PLAN | [`docs/phases/gate-plan.md`](docs/phases/gate-plan.md) |
| DISPATCH | [`docs/phases/dispatch.md`](docs/phases/dispatch.md) |
| RED | [`docs/phases/red.md`](docs/phases/red.md) |
| GREEN | [`docs/phases/green.md`](docs/phases/green.md); change surface: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules |
| VERIFY | [`docs/phases/verify.md`](docs/phases/verify.md) |
| REFINE | [`docs/phases/refine.md`](docs/phases/refine.md) |
| VALIDATE | [`docs/phases/validate.md`](docs/phases/validate.md) |
| AUDIT | [`docs/phases/audit.md`](docs/phases/audit.md); checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `scripts/gate/security-checklist.sh` |
| GATE:QUALITY | [`docs/phases/gate-quality.md`](docs/phases/gate-quality.md) |
| DELIVER | [`docs/phases/deliver.md`](docs/phases/deliver.md) |
| INTEGRATE | [`docs/phases/integrate.md`](docs/phases/integrate.md) |
| HANDOFF | [`docs/phases/handoff.md`](docs/phases/handoff.md) (incl. Merge Sequencing); reviewer/operator guide: [`docs/external-review-sequencing.md`](docs/external-review-sequencing.md); PR body: [`docs/pr-body-guide.md`](docs/pr-body-guide.md) |

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above and are enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`) — the per-gate playbooks restate each gate's rubric items but not these thresholds. The evaluation contract (fresh-spawn Evaluation AI, the 10-point scale, the output format) lives in [`docs/role-contracts.md`](docs/role-contracts.md) > Evaluation System and [`docs/evaluation-system.md`](docs/evaluation-system.md).

### Execution Principles

- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's deliberation, RED / GREEN / VERIFY / REFINE's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What is never skipped is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI, the configured-reviewer review and its `blocked-by-review` label, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate.
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `.autoflow/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop). Role spawns run foreground-only; the binding rule lives in `docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — the deprecated `TaskOutput` tool, or a foreground `sleep` loop polling for a result — is not used. `TaskOutput` is **denied at the tool boundary** by the hook, state-independently. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your final message". There is one delivery path, and it is the return value; what happens to a spawn's final text is `docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Verify role-spawn claims before dispatch**: every role-spawn report's Evidence anchor (see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim.
- **Incomplete output is never ground truth**: a 1-line tool result — a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) or a `Cancelled: parallel tool call … errored` — is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Do not batch parallel `cd`-prefixed Bash — use `git -C <path>` + absolute paths. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the DIAGNOSE playbook ([`docs/phases/analysis.md`](docs/phases/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `.autoflow/<name>.md` per [`docs/issue-proposal.md`](docs/issue-proposal.md) and running `scripts/issue/create-issue.sh --draft .autoflow/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.
- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (DIAGNOSE intake-triage FAIL, structure-gate non-code lever, GATE:HYPOTHESIS non-code root cause, review-response loop-check match, a tool or referenced-material request, HANDOFF review-triage user pause) — the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format), which is anchor-first. The `.autoflow/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.

### AutoFlow State Tracking (Hook integration)

While AutoFlow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

**File naming**: `.autoflow/issue-{N}.json`

**Companion artifact**: `.autoflow/issue-{N}-ledger.md` — the append-only decision ledger ([Decision Ledger](#decision-ledger)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: at PREFLIGHT completion.

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

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry and on a HANDOFF step 6.5 `design` re-entry that starts at ARCHITECT; what each resets is `docs/phases/preflight.md` > *Review-response mode setup* and `docs/phases/handoff.md` > step 6.5. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; PREFLIGHT sets `"review-response"` on review-response entry (target issue's PR is open). The DIAGNOSE structure-gate disposition reads `mode` rather than re-deriving the PR state. The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF triages the configured-reviewer review result; `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no `blocked-by-review` label remains) and at a structure-gate no-work review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**`verdict` rule** (gate_hypothesis_cause only):

| Issue type | When | `verdict` value |
|------------|------|-----------------|
| Bug / incident | Created at PREFLIGHT | `"pending"` |
| Bug / incident | After GATE:HYPOTHESIS evaluation | `"evaluated"` |
| Feat | Set at DIAGNOSE | `"skipped (feat issue)"` |

If `verdict` is empty or contains `skip`, the gate is not triggered for the cause-analysis form. Bug issues must be initialised as `"pending"`.

**Score recording**: write the Evaluation AI's `scores` verbatim, in the shape the hook validates — shown below. Each item's score is a number in `0`–`10`; the two shapes may be mixed within one gate. A prose string such as `"9 - reason"` is **not** a score: the hook's state-file validator rejects it, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until the file is repaired. Format source: [`docs/evaluation-system.md`](docs/evaluation-system.md) > Evaluation Output Format.

<!-- SCORE-SHAPE-EXAMPLE -->
```json
{ "feasibility": { "score": 9, "reason": "evidence" }, "scope": 8 }
```

This object is the value of `phases.<gate>.scores` in `.autoflow/issue-{N}.json`.

**Remedy class recording** (a GATE:QUALITY FAIL, and an open recommendation attempt at any gate — what opens one is `docs/phases/gate-quality.md` > *Recommendation triage*): the orchestrator writes the routed class — the farthest of the classes the route was computed from, or `operator` — as `phases.<gate>.remedy_class` (a sibling of `evaluator` and `scores` inside the phase object, the one additive placement the validator admits; never top-level, never inside `scores`). The value is **removed** once the re-score PASSes and no attempt is left open, or is left behind by a later cycle's record of that gate. The hook reads `gate_quality`'s value for the `git commit` gate below, and the presence of a value at `audit` or `gate_quality` for the `git push` / `gh pr create` gates — an open re-entry is not pushed past (`docs/phases/gate-quality.md` > *Recommendation triage*).

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (role `planning`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` contains `skip` (feat).
- `Agent` (role `testing`) → GATE:PLAN pass required.
- `Agent` (role `implementation`) → GATE:PLAN pass required.
- `Agent` (role `analysis` / `evaluation` / research types) → not score-gated.
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `.autoflow/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch (`main`) → **denied while a state file has `active:true`**. AutoFlow never merges; merging is external.
- `TaskOutput` (any call) → **denied state-independently**, for every actor; a tracked task is awaited by ending the turn and taking its task notification — see Execution Principles > *Wait discipline*.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`docs/issue-proposal.md`](docs/issue-proposal.md).
- A **backgrounded** run of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on both `Bash` (git / gh commands) and `Write|Edit|MultiEdit`.

**Completion**: at HANDOFF, once the configured-reviewer review is clean (no PR retains the `blocked-by-review` label — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-cycle resolution reads the file (review-response mode) and, once the PR is observed merged or closed, archives it with the issue's other artifacts (`docs/phases/preflight.md` > step 1).
**Forced termination**: also set `active` to `false`.

## Evaluation System
→ [`docs/role-contracts.md`](docs/role-contracts.md) > Evaluation System

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: [`docs/git-workflow.md`](docs/git-workflow.md)

### PR Wait Rule

**[MUST]** Use the `active` flag as the single start signal: begin a new cycle once every **other** issue's state file reads `active:false`. One issue runs at a time — when another issue reads `active:true`, finish or resolve that cycle first, then start the next. The hook applies the same signal: it admits `git push` / `gh pr create` while every state file reads `active:false`. The hook fails closed on two or more active state files. The readiness check and the requested issue's mode selection are [`docs/phases/preflight.md`](docs/phases/preflight.md) > *PR Wait Rule*.

### Commit Rules

```
<type>(#<issue>): <description>

Next: <next action>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

- No direct commits to main — always branch + PR.
- No `feat`/`fix` commit while tests fail → use `wip`.
- `git status` before every commit.
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (chain discovery, conversion limit, scoping, outcome vocabulary, evidence anchor): [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation, sub-repo) | Submodule AI                     | Orchestrator |
| Feature (tests, sub-repo)          | Test AI (sub-repo)                | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |
| Comment divergence fix (target code) | Orchestrator (sub-repo: Submodule AI) | Orchestrator |
| Submodule pointer bump (gitlink)            | Orchestrator               | Orchestrator |

## Reference Documents

- **AutoFlow phase guide**: [`docs/autoflow-guide.md`](docs/autoflow-guide.md)
- **Role contracts**: [`docs/role-contracts.md`](docs/role-contracts.md)
- **Evaluation system**: [`docs/evaluation-system.md`](docs/evaluation-system.md)
- **Git procedures**: [`docs/git-workflow.md`](docs/git-workflow.md)
- **Repo boundary rules**: [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md)
- **Sub-repo common rules**: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md)
