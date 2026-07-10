# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A private repository that generalizes the AutoFlow methodology from `ontology-platform` into a reusable framework. The generalization is intentionally narrow:

1. **Name generalization** — upstream's numeric `STEP 0~9` (and sub-step `5a/5b/5c/5d/5.5/5.7`) identifiers are replaced by semantic phase names (`PREFLIGHT`, `DIAGNOSE`, `GATE:HYPOTHESIS`, `ARCHITECT`, `GATE:PLAN`, `DISPATCH`, `RED`, `GREEN`, `VERIFY`, `REFINE`, `VALIDATE`, `AUDIT`, `GATE:QUALITY`, `DELIVER`, `INTEGRATE`, `HANDOFF`). Each generalized name maps 1:1 to an upstream STEP; the terminal phase additionally narrows its scope (`HANDOFF` ends by handing off an open PR — after PR creation, CI, configured-reviewer review, and resolved review triage; merge/close/deploy stay outside AutoFlow's authority — see Development Lifecycle).
2. **Identifier placeholders** — service-specific names like `ontology-api`, `saiso`, organization `my-service-org`, etc. are written as `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders in the methodology docs — a generalized-identifier notation the operator reads as its own service's value (derived at session time from the target's Git remote, `origin/HEAD`, per #943), not a token an installer substitutes.

Rules, retry caps, evaluation categories, score thresholds, and regression paths follow upstream, with one deliberate divergence: AutoFlow hands off at an open PR (`HANDOFF`, after CI + configured-reviewer review + resolved review triage) instead of upstream's merge-and-close terminal step — merge/close/deploy are outside AutoFlow's authority and an external review process performs the merge. Aside from this, the methodology tracks `ontology-platform`.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…"). Recent Claude models follow instructions more literally and are more responsive to the system prompt, so stacked emphasis over-triggers rather than strengthens a rule.
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* when the host contains submodules, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`. The generalized form lists the orchestrator scope by placeholder; see the Repo Structure section below.
- A teammate's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* when the host contains submodules, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated through Agent Teams (`SendMessage`).

For details, see [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md).

## Deployment Topology

"Single-repo" and "multi-repo" classify a project by **submodule count**, independent of repository count or the scope of any individual change.

- **single-repo** = the host repository contains **zero submodules**. The Submodule AI operates as the Developer AI in the orchestrator's own repository, fork/upstream handling is omitted, and the orchestrator commits code changes directly.
- **multi-repo** = the host repository contains **one or more submodules**. One submodule and N submodules follow the identical contract: full fork-and-PR mechanics apply, sub-repo AIs own their directories, and the orchestrator coordinates and opens PRs.

Classification is determined solely by submodule count, evaluated at PREFLIGHT and re-confirmed at HANDOFF. A multi-repo project applies the multi-repo procedure to every issue, including issues whose changes land only in host files: change scope decides which steps execute, while topology decides which procedure governs them.

This project: host repository with **zero submodules** → **single-repo** (the `services` product submodule was detached in #798 / S11a; `claude-autoflow` is now a pure versioned-tool source).

## Team Structure

각 역할의 상세 계약은 [`docs/teammate-contracts.md`](docs/teammate-contracts.md)를 참조한다.

### AI Orchestrator (host repo)
- Does not write code directly; coordinates teammates.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly.

### Evaluation AI — contract: `docs/teammate-contracts.md` > Evaluation AI
### Test AI — contract: `docs/teammate-contracts.md` > Test AI
### Submodule AI — contract: `docs/teammate-contracts.md` > Submodule AI

## Spawn Model — Phase-by-Phase

AutoFlow teammate and subagent spawns choose the model by phase work type rather than inheriting the host session model (currently Opus 4.8). Rationale: (a) cost efficiency on rubric- or classification-bound phases (Sonnet 5 input/output = 60% of Opus 4.8 per M tokens; 40% during introductory pricing through 2026-08-31), (b) Anthropic's official guidance (Opus = "long-horizon agentic, complex reasoning"; Sonnet = "frontier intelligence at scale, agentic tool use"), (c) confining long-session degradation exposure to the phases that genuinely need Opus (`anthropics/claude-code#54991`, `#56367`, `#53459`, all OPEN as of 2026-04~05).

| Phase | Model | Work type |
|---|---|---|
| DIAGNOSE Phase A (structure) | `sonnet` | factual code-structure description (issue-isolated) |
| DIAGNOSE Phase B (issue) | `sonnet` | text classification + logical inference (no code) |
| DIAGNOSE Phase 3 (necessity) | `sonnet` | necessity scoring (Behavior gap + Code-change lever; reuse-neutral) |
| GATE:HYPOTHESIS | `sonnet` | rubric, 3 items × 10 points |
| ARCHITECT | `opus` | multi-turn design discussion, devil's advocate (Developer AI + Test AI) |
| ARCHITECT / VERIFY facilitator | `opus` | isolated `Workflow` whose in-script Developer-AI/Test-AI sub-agents run on `opus` (ARCHITECT design discussion; VERIFY self-check) — see Deliberation Isolation |
| GATE:PLAN | `opus` | rubric, 5 items × 10 points — reverted from `sonnet` per the revert rule below (issue #287 cycle 1: sonnet PASS avg 8.8 contradicted by same-cycle Codex Medium findings its rubric covers — `useSearchEnabled` mechanism misread [Feasibility], `/d/library` blast radius [Dependencies/Scope]; evidence: Munsik-Park/autoflow#905 · LibreChat #268 review comments) |
| RED | `sonnet` | acceptance criteria → test code (complex tests fall back to `opus`, with rationale in the Test AI report) |
| GREEN | `opus` | minimum implementation that passes the tests |
| VERIFY | `opus` | self-check + arbitration (sycophancy-risk surface) |
| REFINE | `sonnet` | mechanical `/simplify` application |
| AUDIT | `sonnet` | security rubric, 5 items × 10 points |
| GATE:QUALITY | `opus` | rubric, 10 items × 10 points — reverted from `sonnet` per the revert rule below (issue #287 cycle 1: sonnet PASS avg 8.9 contradicted by a same-cycle Codex Medium finding its rubric covers — Test coverage/quality missed that the spec seeds `search.enabled: true` directly, masking the missing `useSearchEnabled` wiring; evidence: LibreChat #268 review comment) |
| HANDOFF review-triage (finding ingestion + Low judgment) | `sonnet` | reviewer-comment ingestion (severity classification) + Low-finding impact judgment; the auto-resolution itself reuses the RED/GREEN/… rows above |

Other phases either have no teammate spawn or are run by the orchestrator: PREFLIGHT (orchestrator), DISPATCH (`TaskCreate` + `SendMessage` only), VALIDATE (automatic gate), DELIVER / INTEGRATE (orchestrator); HANDOFF is orchestrator-run except its review-triage finding-ingestion / Low-judgment subagent (see table).

**[MUST]** Every `Agent` spawn (in either `subagent_type` or `team_name` form) declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Without it the host session model is inherited and this per-phase policy is bypassed. Enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy). Note: `SendMessage` is not a spawn — it delivers to an existing teammate — and therefore carries no `model` parameter.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — direct spawns use a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator`, defined in `.claude/agents/`); team spawns carry a role prefix on the teammate `name` (`analysis-` / `plan-` / `impl-` or `dev-` / `test-` / `eval-`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. On a team spawn the name prefix decides ALONE (`subagent_type` is not consulted — a mixed payload must not reclassify an `impl-*` teammate as research). The hook owns the role→gate mapping (analysis / evaluation / research pass; planning → GATE:HYPOTHESIS; implementation / testing → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class — prompt-keyword inference both over-blocked benign spawns (which were then re-worded to slip past, training evasion) and let keyword-free implementation spawns bypass GATE:PLAN. A spawn declares **who it is**; it never declares which gate applies to it. See `docs/gate-matching-standard.md` > P3.

**[MUST]** On the VERIFY → REFINE transition the Developer AI lifetime is shut down and a fresh `sonnet` teammate is spawned at REFINE entry. Mid-lifetime model switching is not supported by the runtime, so the model change requires a phase-boundary respawn (mirrors the DISPATCH-entry respawn in [Cost Control](#cost-control)).

**[MUST]** Revert a phase to `opus` — updating this table in the same commit — when a `sonnet`-assigned gate's PASS is materially contradicted within the same cycle: a defect that gate's rubric covers surfaces through a VERIFY failure, an AUDIT block, or a reviewer-review Medium+ finding on the same surface. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert.

**Rollout status**: the per-phase assignment above is settled (pilot complete); changes follow the revert rule above.

**Sources**:
- Anthropic model selection guide: https://docs.claude.com/en/docs/about-claude/models/choosing-a-model
- Sonnet 5 release notes: https://www.anthropic.com/news/claude-sonnet-5
- Opus 4.8 release notes: https://www.anthropic.com/news/claude-opus-4-8
- Long-session degradation user reports: `anthropics/claude-code` issues #54991, #56367, #53459, #34685, #62144 (all OPEN, 2026-04~05)

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

**[MUST]** Role-scoped injection does not break DIAGNOSE context separation: the structure-analysis path (Phase A) and the issue-analysis path (Phase B) receive disjoint document sets. The per-role injection whitelist — which baseline/review/ADR doc is allowed into which DIAGNOSE phase — is the DIAGNOSE playbook's body ([`docs/phases/analysis.md`](docs/phases/analysis.md)). ARCHITECT-onward injection guidance lives in [`docs/autoflow-guide.md`](docs/autoflow-guide.md) and preserves role-minimal injection and [Deliberation Isolation](#deliberation-isolation-delegated-facilitation).

## Communication — Agent Teams

Communication with teammates uses **Agent Teams**.

- The Lead (orchestrator) runs `TeamCreate`, then spawns Teammates via `Agent` with `team_name` and `name`.
- Teammates communicate via `SendMessage` (push-based delivery).
- `SendMessage(to: "*")` broadcasts.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Cost Control

These rules apply to every cycle to prevent token-cost blow-up. Background: Claude Code's `TeammateIdle` hook cannot cancel orchestrator turns and there is no native `agentTeams.skipIdleTurns` setting (per [agent-teams docs](https://code.claude.com/docs/en/agent-teams.md) and [costs docs](https://code.claude.com/docs/en/costs.md)), so cost control is enforced at the codebase level.

- **Phase-boundary respawn**: ARCHITECT runs as a self-contained `Workflow` that ends when it returns (no persistent facilitator/teammates to shut down). At DISPATCH entry the orchestrator spawns fresh agents for RED/GREEN, passing `.autoflow/issue-{N}-*.md` paths only — discussion history is not carried into implementation phases.
- **Teammate report format**: reports must reference `.autoflow/*` or source file paths and include a one-line summary. Do not inline document body content or full file text in messages. See [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format.
- **[MUST] Orchestrator context discipline**: the orchestrator holds only anchors, summaries, verdicts, and decisions — never raw material. It does not read a full artifact (whole design docs, full source files) to judge it, nor run multi-step investigations in its own context; that absorption is **delegated** to a subagent or teammate that writes any body to `.autoflow/*` and returns only an anchor + one-line summary. This extends *Teammate report format* to (a) the orchestrator's own reads and (b) every direct/ad-hoc `Agent` spawn, scripted-phase or not (e.g. DIAGNOSE Phase A/B/3 write `.autoflow/issue-N-phase-*.md` and return a summary, not the body). Cheap anchor-checks stay in-context — a `git show <SHA>`, a one-line command re-run, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify teammate claims). Full body enters orchestrator context only when strictly required (e.g. evaluator scores). Multi-teammate **deliberation** is absorbed the same way — a discussion is delegated to a facilitator sub-context, not run in the orchestrator's turn stream (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation)). The "anchor + one-line summary" rule bounds what the orchestrator **retains**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `.autoflow/*` body the user reads is written in that order.
- **jest output**: run with `--silent --reporters=summary`. Never paste raw verbose jest output (per-case lines, full coverage report) into a teammate message or report. See [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Testing Standards.
- **Team size**: keep ≤ 5 teammates per Agent Teams session. Use Agent Teams only when cross-AI coordination is required — single-AI tasks should use a direct `Agent` spawn instead.

### Deliberation Isolation (delegated facilitation)

Multi-teammate deliberation phases (ARCHITECT; the Developer-AI ↔ Test-AI cause-branch exchange in VERIFY) run inside an **isolated facilitation sub-context**, not in the orchestrator's own turn stream. This is a structural rule, not a cost optimization — see [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 8.

**Why** — a teammate→lead `SendMessage` is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator is the discussion lead, every round of Developer-AI ↔ Test-AI cross-talk lands in its context, and the two teammates' near-duplicate convergence reports (e.g. dev `Full mutual ACCEPT` + test `MUTUAL ACCEPT reached`) load the same information twice. Beyond token cost, this contaminates judgment: retracted claims, wrong oracles, and reversed scopes accumulate in the orchestrator's working context and it oscillates on decisions it had already settled (observed in issue #189). A cheaper or summarized round (file-pull, checkpoint summary) does not fix this — the orchestrator still receives the round and the duplicate accumulation. Removing the contamination requires removing the orchestrator from the loop, not shrinking each message.

- **[MUST]** The orchestrator delegates a multi-teammate deliberation to a **facilitator** realized as an isolated **`Workflow`** (Claude Code v2.1.154+), **not** as a nested Agent Team — a spawned teammate cannot create its own team and a team's lead is fixed for its lifetime, so a nested-team facilitator is not executable; and a peer-teammate facilitator is not a documented isolation boundary. The workflow runs the Developer-AI and Test-AI sub-agents in-script ("intermediate results stay in script variables instead of landing in Claude's context"), drives convergence under the Discussion Protocol, writes the converged artifacts to `.autoflow/*`, appends settled decisions to the decision ledger, and returns to the orchestrator **only** one structured result (per-phase — see [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator > Return Contract): ARCHITECT returns `{ verdict: CONVERGED|ESCALATE, artifact paths, summary }`; VERIFY returns `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI }`. The orchestrator never receives the round-by-round messages or the duplicate dual reports. Reference scripts: `.claude/workflows/{architect-deliberation,verify-cause-branch}.js`.
- **[MUST] Isolation is for deliberation, not verification.** Delegated facilitation removes the orchestrator's exposure to round-by-round prose — it does **not** remove the orchestrator's verification job. After the result returns, the orchestrator does **not** read the design docs cover-to-cover to judge them (that full read-and-score is GATE:PLAN's fresh Evaluation AI); it **spot-checks targeted excerpts** — pulling the specific `path:line` a returned decision rests on and re-deriving the cited fact (`git show`, command re-run, `git show HEAD:<file>`). The catches that justify the orchestrator's role come from these targeted facts, not from reading deliberation prose; that leverage is preserved.
- **Termination** (per [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 7): the facilitated discussion carries an explicit cap — ARCHITECT max **6 rounds** (a round = one Developer-AI ↔ Test-AI exchange cycle) → `ESCALATE` on no mutual ACCEPT; VERIFY is a **single** self-check round (deterministic `next_action`, no internal loop). A facilitated deliberation never loops without a termination condition.
- **Respawn / lifecycle**: each facilitation is a self-contained workflow run — it ends when it returns its result (no long-lived teammate to shut down). At DISPATCH entry the implementation teammates (RED/GREEN) are spawned fresh, carrying only `.autoflow/*` paths (see *Phase-boundary respawn* above).

#### Decision Ledger

A per-issue append-only record, `.autoflow/issue-{N}-ledger.md`, fixes settled decisions so an enlarged context cannot silently re-open them.

- Each entry records: the decision (one line), its **grounds** (evidence / artifact `path:line`), its **authority** (what settled it — `ARCHITECT mutual ACCEPT`, `GATE:PLAN PASS (avg 8.2)`, `VERIFY Evaluation-AI arbitration`), and the cycle/phase.
- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content), not a re-reading or re-interpretation of material already on the record. This caps oscillation-driven round explosion and aligns with the GATE-verdict-outranks-rereading rule (a settled gate verdict is not overturned by re-reading the issue body).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact and references the entry it supersedes.
- The ledger is outside every teammate's scope — it is host-owned, written only by the orchestrator and its facilitator delegate: the facilitator appends entries during deliberation; the orchestrator appends each gate's verdict after the gate, records a loop-check observation (complaint class, witness, prior-change shape, cycle) on **every** review-response DIAGNOSE entry to seed the next cycle's baseline, and — when a match pauses for the user — appends the user's re-entry decision as a separate entry after they answer.

### Discussion Protocol

→ Single source of truth: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Discussion Protocol

The orchestrator and teammates follow the same rules. Core: UNDERSTAND → VERIFY → EVALUATE → RESPOND (ACCEPT / COUNTER / PARTIAL / ESCALATE). No groundless agreement, no evaluation without reading the relevant files, devil's advocate required on the first exchange.

## Development Lifecycle — AutoFlow

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

**PREFLIGHT cannot be skipped.** If PREFLIGHT's completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the blocking condition first and report.

```
PREFLIGHT       : Pre-Work          — prior-cycle resolution (cleanup after external merge/close), Git clean check, remote sync, dev branch creation
DIAGNOSE        : Issue Analysis    — intake readiness triage (new-issue: planning/design/ADR pre-req filter), affected scope, hypothesis classification, lightweight verification, task decomposition, affected docs
GATE:HYPOTHESIS : Hypothesis Eval   — Evaluation AI (3 items × 10 points), bug/incident issues only
ARCHITECT       : Plan Synthesis    — isolated Workflow facilitation (Developer AI + Test AI sub-agents), feature design + verification design
GATE:PLAN       : Plan Evaluation   — Evaluation AI (5 items × 10 points)
DISPATCH        : Task Assignment   — TaskCreate + SendMessage to Test AI and Developer AI (acceptance criteria + verification design)
RED             : Test Writing      — Test AI writes tests from acceptance criteria; Red confirmation
GREEN           : Implementation    — Developer AI writes minimum code that passes the tests
VERIFY          : Test Run + Check  — Green confirmation; on failure, branch by cause; minimal-implementation check
REFINE          : Refactor          — Developer AI cleanup; Test AI re-confirms Green
VALIDATE        : Verification Done — automated tests all PASS + manual checklist itemized + maintained docs updated
AUDIT           : Security Audit    — independent Evaluation AI (5 items × 10 points), project-specific security checklist
GATE:QUALITY    : Completion Eval   — Evaluation AI (10 items × 10 points)
DELIVER         : Sub-Repo Push     — each Submodule AI pushes its fork branch; Teammate shutdown
INTEGRATE       : Integration Test  — system build, health check, functional test (single-repo: project-level integration test)
HANDOFF         : PR + Hand-off     — push dev branch → sub-repo PRs → host PR (Closes #N) → CI green → configured-reviewer review → review-triage (auto-resolve Medium+ / judge Low) → state inactive once review is clean; external review merges out of band
```

### Flow Control

| Transition | Condition |
|------|------|
| PREFLIGHT → DIAGNOSE | Git clean, remote sync done |
| DIAGNOSE (intake readiness triage) → user | `mode=new-issue` only. A planning/design/ADR prerequisite is clearly required first → write reason + suggested issue-split draft to `.autoflow/issue-{N}-triage.md`, present situation-first (the user-visible problem + suggested split in domain terms; the file is the drill-down anchor — see Execution Principles > Human-decision presentation), pause (`active:false`, `phase:"awaiting-user"`). No auto issue creation; ambiguous → PASS to structure analysis. |
| DIAGNOSE (intake readiness triage) → structure analysis | triage PASS (no clear prerequisite) → Phase A/B fan-out begins |
| DIAGNOSE (structure eval) → close / reply / user | GATE:HYPOTHESIS structure FAIL → gap-item-low (already satisfied): mode=new-issue → issue auto-closed + terminated, mode=review-response → reply on PR + active:false (awaiting-external-review), no close. Gap real but Code-change-necessity low (non-code lever) → report to user + pause |
| DIAGNOSE (review-response loop check) → user | trigger comment repeats the immediately-prior review-response cycle's complaint class with a new witness case → reply on PR + await the user's re-entry decision (`phase: awaiting-user`) |
| DIAGNOSE (structure eval) → DIAGNOSE (cause) | GATE:HYPOTHESIS structure PASS (code change required) |
| DIAGNOSE → GATE:HYPOTHESIS (cause) | hypothesis classification + lightweight verification done (bug/incident issues) |
| DIAGNOSE → ARCHITECT | affected scope identified (feat issues — skip GATE:HYPOTHESIS cause) |
| GATE:HYPOTHESIS → ARCHITECT | cause analysis PASS + code change required |
| GATE:HYPOTHESIS → user | non-code root cause confirmed → report to user |
| ARCHITECT → GATE:PLAN | feature design + verification design agreed |
| GATE:PLAN → DISPATCH | plan evaluation PASS |
| DISPATCH → RED | task instructions delivered (Test AI starts first) |
| RED → GREEN | tests written + Red confirmed (all fail) |
| GREEN → VERIFY | implementation done |
| VERIFY → REFINE | all tests PASS + minimal-implementation and mock-boundary fidelity checks pass |
| REFINE → VALIDATE | refactor done + Green re-confirmed |
| VERIFY → GREEN | implementation issue → Developer AI re-implements |
| VERIFY → RED | test issue → Test AI fixes test → re-Red → GREEN re-entry |
| VERIFY → Evaluation AI | deadlock (both claim "no problem") → Evaluation AI arbitrates |
| VALIDATE → AUDIT | automated tests all PASS + manual checklist itemized |
| AUDIT → GATE:QUALITY | security audit PASS |
| GATE:QUALITY → DELIVER | completion evaluation PASS |
| DELIVER → INTEGRATE | sub-repo push + Teammate shutdown done |
| INTEGRATE → HANDOFF | integration tests pass |
| HANDOFF (review-triage) → review-response (auto) | after the configured-reviewer review the verdict is `max_severity ≥ Medium` (label present as expected) → auto-enter a review-response cycle in-session with the reviewer comment as the DIAGNOSE trigger; the orchestrator never removes the label — the reviewer re-review clears it |
| HANDOFF (review-triage) → reviewer re-review / operator | label present but `max_severity < Medium` (or no verdict) → label-clear / review-infra failure, not a code finding → re-run the step-6 configured-reviewer review; still stuck → escalate (`active:false`, `phase:"awaiting-user"`). Does not consume the 7-attempt cap |
| HANDOFF (review-triage) → user | auto-resolution hits a user-decision criterion (contract/AC change, ambiguous fix, `Low Confidence` item, loop-check match) or the 7-attempt cap → `active:false`, `phase:"awaiting-user"` |
| HANDOFF → end | all PRs cleared of `blocked-by-review` (no Medium+) + Low triage resolved + CI green (host PR carries `Closes #N`) → state `active:false` → AutoFlow ends; external review reviews and merges out of band |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF → RED | CI failure (code issue) → fix tests/implementation and re-flow |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS cause FAIL → DIAGNOSE (max 2×). GATE:PLAN FAIL → ARCHITECT (max 3×). VERIFY FAIL → cause-branched fix (max 3 round-trips). REFINE FAIL → Developer AI fixes and re-runs (max 2×; on second failure, abandon refactor and proceed to VALIDATE with the Green state). AUDIT FAIL → fix and re-evaluate (max 2×). GATE:QUALITY FAIL → RED (max 3×). INTEGRATE FAIL → RED. HANDOFF failure → cause classification: code issue → RED; environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at HANDOFF) → review-response (max 7×; on the 7th consecutive (per the count window in `docs/autoflow-guide.md` step 6.5) without the `blocked-by-review` label clearing, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total). VERIFY deadlock unresolved by Evaluation AI arbitration → human. HANDOFF internal retry exhausted → human.
**PR creation**: at HANDOFF, the orchestrator opens the PR(s), places `Closes #N` on the host PR, and confirms CI is green. Merging is external; AutoFlow does not merge.

### Phase Playbook Loading Contract

Each phase's procedure body — its numbered steps, scoring rubric, and phase-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **playbook**, not in this core file. This file retains only what every phase needs to *route*: the cross-phase invariants (above), the router (the phase list and Flow Control table above), the regression / escalation caps (above), the Execution Principles (below), and the state schema (below).

**[MUST]** On entering a phase, Read its playbook below **before** acting in that phase. The playbook is the source of truth for that phase's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the playbook each cycle (the playbook may have changed, and the gate verdicts depend on its current rubric).

| Phase | Playbook to Read on entry |
|-------|---------------------------|
| PREFLIGHT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT; git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| DIAGNOSE | [`docs/phases/analysis.md`](docs/phases/analysis.md) — intake readiness triage (new-issue), 3-Phase A/B/3 analysis, per-role injection whitelist, issue-type scoring rubric, FAIL disposition, bias prevention |
| GATE:HYPOTHESIS | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:HYPOTHESIS |
| ARCHITECT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > ARCHITECT; facilitator contract: [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator; isolation rationale: this file > Deliberation Isolation |
| GATE:PLAN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:PLAN |
| DISPATCH | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > DISPATCH |
| RED | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > RED |
| GREEN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GREEN; change surface: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules |
| VERIFY | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY |
| REFINE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > REFINE |
| VALIDATE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VALIDATE; affected docs: [`docs/maintained-docs.md`](docs/maintained-docs.md) |
| AUDIT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > AUDIT; checklist: [`docs/security-checklist.md`](docs/security-checklist.md) |
| GATE:QUALITY | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:QUALITY |
| DELIVER | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > DELIVER |
| INTEGRATE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > INTEGRATE |
| HANDOFF | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > HANDOFF (incl. Merge Sequencing); reviewer/operator guide: [`docs/external-review-sequencing.md`](docs/external-review-sequencing.md); PR body: [`docs/pr-body-guide.md`](docs/pr-body-guide.md) |

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above and are enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`) — the per-gate playbooks restate each gate's rubric items but not these thresholds. The evaluation contract (fresh-spawn Evaluation AI, the 10-point scale, the output format) lives in [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Evaluation System and [`docs/evaluation-system.md`](docs/evaluation-system.md).

### Execution Principles

- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **Every phase is mandatory**: no skipping based on perceived simplicity.
- **Teammate idle handling**: idle notifications (`{"type":"idle_notification",...}`) signal teammate availability; they do not require a response. Continue work when (a) a teammate sends an actionable report via SendMessage, (b) a Bash result you initiated returns, or (c) the user types a new prompt. A spawned subagent has no future turn to receive a background-completion notification, so when a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `.autoflow/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop, which has future turns to receive the notification). A spawned teammate is reaped at its final response, so a pending background task is lost — teammates run foreground-only; the binding rule lives in `docs/teammate-common-rules.md` > Bash Execution Mode.
- **Verify teammate claims before dispatch**: every teammate report's Evidence anchor (see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, re-running the cited command for a test-summary anchor, `git show HEAD:<file>` for a file-state anchor. **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim — stale snapshots in working memory or hash confabulation can cause noop redo dispatches.
- **Incomplete output is never ground truth**: a 1-line tool result — a Read-dedup stub (`file unchanged … refer to that earlier tool_result`; the dedup ledger is not reset on compaction, `anthropics/claude-code#46749`) or a `Cancelled: parallel tool call … errored` — is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`, which bypasses the dedup ledger) and reproduce the finding before acting. Do not batch parallel `cd`-prefixed Bash — use `git -C <path>` + absolute paths. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the DIAGNOSE playbook ([`docs/phases/analysis.md`](docs/phases/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.
- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (DIAGNOSE intake-triage FAIL, structure-gate non-code lever, GATE:HYPOTHESIS non-code root cause, review-response loop-check match, HANDOFF review-triage user pause) — the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ code anchors (`path:line` / SHA) demoted to supporting evidence for drill-down, never the lead. This register is distinct from the machine **Reporting Format** ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format), which is anchor-first because its audience is an AI that re-derives the anchor deterministically; a human exercises design / context judgment and needs the situation, so the format follows the audience's verification mode. The `.autoflow/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what the orchestrator **retains**, not how a human decision is **framed**.

### AutoFlow State Tracking (Hook integration)

While AutoFlow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

**File naming**: `.autoflow/issue-{N}.json`

**Companion artifact**: `.autoflow/issue-{N}-ledger.md` — the append-only decision ledger (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation) > Decision Ledger). Created at the first settled decision; retained alongside the state file and archived with it (moved to the external store) at prior-cycle cleanup once the PR is merged/closed (see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT). The hook does not read it (it is a methodology artifact, not a gate input).

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

**`cycle` field**: starts at `1` on Creation. PREFLIGHT increments it on review-response entry (target issue's PR is open) and resets `phases` to the empty Creation template (preserving the `verdict` rule). The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; PREFLIGHT sets `"review-response"` on review-response entry (target issue's PR is open). The DIAGNOSE structure-gate disposition reads `mode` rather than re-deriving the PR state — a single persisted source of the cycle classification. The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF triages the configured-reviewer review result (auto-resolving Medium+ findings or judging Low findings before handoff); `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no `blocked-by-review` label remains) and at a structure-gate no-work review-response exit (both hand the open PR to external review); `"awaiting-user"` at a non-code-lever / non-code-root-cause pause, at a review-response loop-check match awaiting the user's re-entry decision, or at a HANDOFF review-triage user-decision / 7-attempt-cap / label-clear-failure escalation pause. A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**`verdict` rule** (gate_hypothesis_cause only):

| Issue type | When | `verdict` value |
|------------|------|-----------------|
| Bug / incident | Created at PREFLIGHT | `"pending"` |
| Bug / incident | After GATE:HYPOTHESIS evaluation | `"evaluated"` |
| Feat | Set at DIAGNOSE | `"skipped (feat issue)"` |

If `verdict` is empty or contains `skip`, the gate is not triggered for the cause-analysis form. Bug issues must be initialised as `"pending"` so the gate fires.

**Score recording**: write the Evaluation AI's `scores` verbatim (score + reason format).

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type, role-prefixed teammate name, or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (role `planning`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` contains `skip` (feat).
- `Agent` (role `testing`) → GATE:PLAN pass required.
- `Agent` (role `implementation`) → GATE:PLAN pass required.
- `Agent` (role `analysis` / `evaluation` / research types) → not score-gated (evaluation must stay spawnable — it produces the gate scores).
- `git push` → AUDIT + GATE:QUALITY pass required.
- `gh pr create` → AUDIT + GATE:QUALITY pass required.
- `gh pr merge`, and any push to the default branch (`main`) → **denied while a state file has `active:true`**. AutoFlow never merges; merging is external.

These gates are wired via PreToolUse on both `Bash` (git / gh commands) and `Write|Edit|MultiEdit`.

**Completion**: at HANDOFF, once the configured-reviewer review is clean (no PR retains the `blocked-by-review` label — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. The file serves as the in-flight handoff record while its PR awaits the external decision — PREFLIGHT's prior-cycle resolution reads it (review-response mode). Once the PR is observed merged or closed, prior-cycle resolution **archives** the issue's `.autoflow/issue-{N}*` files (moves them to `$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/`, outside the repo tree) as cleanup, keeping each later PREFLIGHT focused on live cycles. The durable record lives in the GitHub PR/issue and commit log; the full cycle artifacts persist in the external archive, and the live `.autoflow` files remain gitignored scratch.
**Forced termination**: also set `active` to `false`.

## Evaluation System
→ [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Evaluation System

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: [`docs/git-workflow.md`](docs/git-workflow.md)

### PR Wait Rule

The PR Wait Rule is the **PREFLIGHT-entry readiness check** that clears the requested issue to start. Its source of truth is AutoFlow's own `.autoflow/issue-*.json` **state files**: read the `active` flag there to decide readiness. It resolves two questions in order — (1) is any **other** issue mid-cycle? (2) at what stage is the **requested** issue's own state? — and proceeds once both are answered.

**[MUST]** Use the `active` flag as the single start signal: begin a new cycle once every **other** issue's state file reads `active:false`. One issue runs at a time — when another issue reads `active:true`, finish or resolve that cycle first, then start the next. The hook applies the same signal: it admits `git push` / `gh pr create` while every state file reads `active:false`.

**[MUST]** Read an `active:false` state file (`phase: awaiting-external-review`) as **cleared and handed off**: its PR belongs to external review, which merges on its own schedule. Tie readiness to the `active` flag alone, so each issue starts as soon as the prior cycle reaches HANDOFF — while external review merges the open PR on its own timeline.

For the **requested** issue, read its own state file to choose the mode: `active:true` → resume the in-progress cycle (see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT > Resume procedure); `active:false` with an open PR → enter review-response mode (PR-review stage); **`active:false` with `phase:"awaiting-user"` and no PR → the cycle is paused on a human decision (not cleared): re-entry is driven by the user's new decision, not an automatic mode — surface the pending decision and its `.autoflow/issue-{N}-*.md` context, and do not silently restart**; absent → start as a new issue.

### Git Clean Check

Used at PREFLIGHT (entry, including prior-cycle resolution). → see `docs/git-workflow.md` > Git Clean Check.

### Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once the prior PR is observed merged or closed (or by the live session if it observes the decision first). → see `docs/git-workflow.md` > Post-Merge Cleanup.

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

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation, sub-repo) | Submodule AI                     | Orchestrator |
| Feature (tests, sub-repo)          | Test AI (sub-repo)                | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |
| Submodule pointer bump (`services` gitlink) | Orchestrator               | Orchestrator |

### PR Flow

**Feature (host-only — target-centric, the default)**: orchestrator commit → push → PR created with `Closes #N`. AutoFlow ends; external review merges.
*Secondary (multi-repo):* **Feature (sub-repo change included)**: Submodule AI commit → push to fork → sub-repo PR created. Host PR created with `Closes #N`. AutoFlow ends; external review merges (sub-repo → pointer → host sequencing is external).
**Rules / infrastructure**: orchestrator direct commit → push → PR created. AutoFlow ends; external review merges.

### PR Issue Auto-Close

In the target-centric default, the cycle's single (host) PR carries `Closes #N` directly, so the external merge closes the issue automatically.

*Secondary (multi-repo):* when the host contains a submodule, the cycle splits into two PRs — the host PR carries the close keyword and merges last, each sub-repo PR references only and merges first:

```
# Host PR (merges last — closes the issue)
Closes #N

# Sub-repo PR (merges first — references only, does NOT close)
Part of Munsik-Park/autoflow#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- **[MUST]** Sub-repo PRs do NOT use `Closes` — sub-repo PRs merge first, so `Closes` would prematurely close the issue.
- **[MUST]** Only the host PR uses `Closes #N`.
- **[MUST]** PR bodies generated from `.github/pull_request_template.md` never inline a plain-text close-keyword token in the template itself. The template uses the marker `<!-- HOST-CLOSE-LINE -->`; the orchestrator's HANDOFF renderer substitutes the marker with the active `Closes #N` line in the rendered host PR body. Templates / docs / design notes that **describe** the close-keyword pattern must wrap the example in backticks or code-fences. This prevents the issue #82 footgun where prose-describing-the-pattern accidentally triggered an active close.

### Issue Management

- Tracker placement follows each repo's composition (D4, settled in S12 #800): AutoFlow-framework work items are filed in this host repository (`Munsik-Park/autoflow`). *Secondary (multi-repo, where no service-host tracker is designated):* a target scope hosts no tracker of its own; its work items are filed against its host repository.
- The orchestrator routes each work item to the scope that will execute it (dispatch by role).
- Issue labels: `ai:<agent>` (automation target, e.g. `ai:claude`), sub-repo name, priority.
- Forks do not host issues.

### Document Rules

- Code/policy: English.
- Markdown docs: English (source of truth).
- HTML docs: Korean (translation), if maintained.
- MD↔HTML pairs are kept in sync.
- Cross-project docs: a dedicated `services/<docs-repo>` (or analogue), if used.
- Per-sub-repo docs: each sub-repo's `docs/`.
- Numbering convention: `00N-<name>` within the cross-project docs repo.

## Reference Documents

- **AutoFlow phase guide**: [`docs/autoflow-guide.md`](docs/autoflow-guide.md)
- **Teammate contracts**: [`docs/teammate-contracts.md`](docs/teammate-contracts.md)
- **Evaluation system**: [`docs/evaluation-system.md`](docs/evaluation-system.md)
- **Design rationale (why every rule exists)**: [`docs/design-rationale.md`](docs/design-rationale.md)
- **Git procedures**: [`docs/git-workflow.md`](docs/git-workflow.md)
- **Repo boundary rules**: [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md)
- **Sub-repo common rules**: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md)
- **Maintained docs registry**: [`docs/maintained-docs.md`](docs/maintained-docs.md)
- **Security checklist**: [`docs/security-checklist.md`](docs/security-checklist.md)
