# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A private repository that generalizes the AutoFlow methodology from `ontology-platform` into a reusable framework. The generalization is intentionally narrow:

1. **Name generalization** — upstream's numeric `STEP 0~9` (and sub-step `5a/5b/5c/5d/5.5/5.7`) identifiers are replaced by semantic phase names (`PREFLIGHT`, `DIAGNOSE`, `GATE:HYPOTHESIS`, `ARCHITECT`, `GATE:PLAN`, `DISPATCH`, `RED`, `GREEN`, `VERIFY`, `REFINE`, `VALIDATE`, `AUDIT`, `GATE:QUALITY`, `DELIVER`, `INTEGRATE`, `HANDOFF`). Each generalized name maps 1:1 to an upstream STEP; the terminal phase additionally narrows its scope (`HANDOFF` ends by handing off an open PR — after PR creation, CI, configured-reviewer review, and resolved review triage; merge/close/deploy stay outside AutoFlow's authority — see Development Lifecycle).
2. **Identifier placeholders** — service-specific names like `ontology-api`, `saiso`, organization `my-service-org`, etc. are written as `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders in the methodology docs — a generalized-identifier notation the operator reads as its own service's value (derived at session time from the target's Git remote, `origin/HEAD`, per #943), not a token an installer substitutes.

Rules, retry caps, evaluation categories, score thresholds, and regression paths follow upstream, with two deliberate divergences: (1) AutoFlow hands off at an open PR (`HANDOFF`, after CI + configured-reviewer review + resolved review triage) instead of upstream's merge-and-close terminal step — merge/close/deploy are outside AutoFlow's authority and an external review process performs the merge; (2) a late-gate FAIL (GATE:QUALITY, VALIDATE, INTEGRATE) re-enters the cycle at the phase its cause names (`remedy_class`: doc commit / RED / GREEN / ARCHITECT) instead of upstream's unconditional return to RED — an operator decision recorded at `docs/design-rationale.md` > Decision 11 (issue #140); the caps are unchanged. Aside from these, the methodology tracks `ontology-platform`.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…"). Recent Claude models follow instructions more literally and are more responsive to the system prompt, so stacked emphasis over-triggers rather than strengthens a rule.
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* when the host contains submodules, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`. The generalized form lists the orchestrator scope by placeholder; see the Repo Structure section below.
- A teammate's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* when the host contains submodules, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

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

The per-phase assignment itself — every phase's `model`, its `effort`, and the work type that
justifies it — lives in exactly ONE machine-readable place and is **not** restated here:

**`.claude/autoflow/spawn-policy.json`**, read through `scripts/spawn-policy/spawn-policy.sh`:

```
bash scripts/spawn-policy/spawn-policy.sh model  <phase-key>   # the model to declare on the spawn
bash scripts/spawn-policy/spawn-policy.sh effort <phase-key>   # the effort, or the config's own inherit sentinel
bash scripts/spawn-policy/spawn-policy.sh check                # validate the config
```

That file is a **sample carrying the values currently applied, and it is target-owned**: it ships as
a `scaffold` artifact, so a stamp or re-stamp creates it only when absent and never overwrites it
(not even under `--force`), and each target is expected to configure it for its own runtime — its model
rows and its `workflow_sites` effort. A `phases[]` row's effort is **not** a target lever: the harness reads a
direct spawn's effort from the agent definition's `effort:` frontmatter (the Agent tool carries `model` per
call, no effort), and the definitions are versioned tool source a thin-root target loads from the plugin, so
that value is fixed per plugin version; the config row is the projection source at this repository and
`check` fails closed when it differs from the loaded definition, and a row on a harness research type — which ships no
definition — admits the inherit sentinel only (`effort_contract.phase_effort_ownership`). Its
`effort_contract` is the effort vocabulary `check` applies to it — a runtime with a different
vocabulary is accommodated by editing that contract, never by patching the checker — and the
`effort` readout prints the inherit sentinel that contract declares rather than a fixed literal. On
a version bump the operator's obligation is to run `check` and add any newly required row.

The same file carries the two Workflow facilitations' per-site values (`workflow_sites`), which the
deliberation scripts load at run time — no `model:` literal remains in
`.claude/workflows/*.js`. It also documents its own inheritance rule (`effort_contract`) and
declares any shipped agent type the policy governs no row for (`policy_unmapped_agent_types`).

**Revert history** (the evidence, not the tiers — the tier each was reverted *to* is read from the
config): GATE:PLAN and GATE:QUALITY were both reverted to the higher tier under the revert rule
below, on issue #287 cycle 1. GATE:PLAN — a lower-tier PASS (avg 8.8) contradicted by same-cycle
Codex Medium findings its own rubric covers: the `useSearchEnabled` mechanism misread
[Feasibility] and the `/d/library` blast radius [Dependencies/Scope] (evidence:
Munsik-Park/autoflow#905 · LibreChat #268 review comments). GATE:QUALITY — a lower-tier PASS
(avg 8.9) contradicted by a same-cycle Codex Medium finding its rubric covers: Test
coverage/quality missed that the spec seeds `search.enabled: true` directly, masking the missing
`useSearchEnabled` wiring (evidence: LibreChat #268 review comment). RED — reverted to the higher tier on issue
#180: across three consecutive cycles of llmroute #279 (one new-issue, two review-response) the Test AI's Red
confirmation was contradicted by VERIFY step 1, and the cause-branch workflow returned `test=fix_test,
impl=no_problem` all three times (Test AI defects 7 / 2 files / 1 — design-document, real-type and runtime-
environment mismatches, a fixture-precedence error, an arithmetic error; implementation defects 0; each
round-trip ≈ 1.1M tokens of cause-branch plus ≈ 0.36M of RED re-entry against a RED spawn of 0.25–0.35M).
A survey of the configured reviewer's findings across the four consuming repositories (856 reviewed PRs as
of 2026-09-05) adds the escaped half of the same defect class: 5 Medium findings where the suite did not
exercise the real contract or environment (those PRs averaged 4.75 review rounds), and 14 High findings
where the PR's own main path failed at runtime after VERIFY had confirmed Green (evidence: issue #180 and
its PR thread).

Other phases either have no role spawn or are run by the orchestrator: PREFLIGHT (orchestrator), DISPATCH (`TaskCreate` only), VALIDATE (automatic gate), DELIVER / INTEGRATE (orchestrator); HANDOFF is orchestrator-run except its review-triage finding-ingestion / Low-judgment subagent (model per `.claude/autoflow/spawn-policy.json`, key `handoff-review-triage`).

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Without it the host session model is inherited and this per-phase policy is bypassed. Enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy). **One carve-out, and only one**: the `policy-load` transcription sub-agent at the top of each deliberation Workflow omits `model`, because it cannot read its own model from the policy it is loading; the call is a verbatim file transcription under a closed schema, where model tier is not load-bearing.

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior cycle: `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — every spawn uses a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-loopcheck` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator`, defined in `.claude/agents/`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. `subagent_type` is the sole declaration channel — the teammate-name-prefix channel was removed jointly with the spawn-mode migration (ADR-0021; the removal itself is ADR-0017 Q3), since every role now spawns anonymously and directly. The hook owns the role→gate mapping (analysis / evaluation / research pass; planning → GATE:HYPOTHESIS; implementation / testing → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class — prompt-keyword inference both over-blocked benign spawns (which were then re-worded to slip past, training evasion) and let keyword-free implementation spawns bypass GATE:PLAN. A spawn declares **who it is**; it never declares which gate applies to it. See `docs/gate-matching-standard.md` > P3. Every role's spawn mode is fixed by *Spawn mode by role lifetime* below.

**[MUST]** REFINE entry spawns the Developer AI fresh, on the model the policy names for REFINE, carrying only `.autoflow/issue-{N}-*.md` paths. Every role is an anonymous direct spawn with no lifetime spanning phases (*Spawn mode by role lifetime* below), so each phase's spawn already resolves its own model from the config; the VERIFY → REFINE model change needs no separate teardown step. What the rule still forbids is carrying VERIFY's spawn into REFINE by reusing its context — the phase boundary is a fresh spawn, matching the DISPATCH-entry respawn in [Cost Control](#cost-control).

**[MUST]** Revert a phase to the higher tier — updating `.claude/autoflow/spawn-policy.json` in the same commit — when a lower-tier gate's PASS is materially contradicted within the same cycle: a defect that gate's rubric covers surfaces through a VERIFY failure, an AUDIT block, or a reviewer-review Medium+ finding on the same surface. A lower-tier **role spawn** is covered on the same terms (issue #180): the phase-exit claim it returns — RED's Red confirmation, GREEN's implementation-done — stands where a gate's PASS stands, and the contradicting signal is the VERIFY cause-branch verdict that attributes the failure to that role in the same cycle (`fix_test` for the Test AI, `fix_impl` for the Developer AI), or a reviewer-review Medium+ finding on the artifact that role produced. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert.

**Rollout status**: the per-phase assignment in the config is settled (pilot complete); changes follow the revert rule above.

**Sources**:
- Anthropic model selection guide: https://docs.claude.com/en/docs/about-claude/models/choosing-a-model
- Sonnet 5 release notes: https://www.anthropic.com/news/claude-sonnet-5
- Opus 4.8 release notes: https://www.anthropic.com/news/claude-opus-4-8
- Long-session degradation user reports: `anthropics/claude-code` issues #54991, #56367, #53459, #34685, #62144 (all OPEN, 2026-04~05)

### Spawn mode by role lifetime

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases: each phase spawns its role fresh, hands it `.autoflow/issue-{N}-*.md` paths, and takes its result as the spawn's return value.

| Role (where it occurs) | Spawn mode | Per-call scope |
|---|---|---|
| Evaluation AI (GATE:HYPOTHESIS structure/cause, GATE:PLAN, AUDIT, GATE:QUALITY, VERIFY arbitration) | anonymous direct | single-shot — scores once and returns; a fresh agent is spawned every call |
| DIAGNOSE (intake readiness triage, Phase A, Phase B, Phase 3, review-response loop check) | anonymous direct | single-shot — writes its body to `.autoflow/issue-{N}-*.md` and returns an anchor + one-line summary |
| HANDOFF review-triage subagent (finding ingestion + Low judgment, step 6.5) | anonymous direct | single-shot — ingests or serializes and returns; the auto-resolution it feeds re-enters through the Test AI / Developer AI rows |
| Test AI (RED, VERIFY self-check, REFINE Green re-confirmation) | anonymous direct | one spawn per phase entry; continuity across RED → VERIFY → REFINE is carried by the `.autoflow/*` artifacts, not by a retained context |
| Developer AI (GREEN, VERIFY self-check, REFINE) | anonymous direct | one spawn per phase entry; the same artifact-carried continuity, and each entry resolves its own model from the config |
| ARCHITECT relay participant — Developer AI side and Test AI side (ARCHITECT Discuss + Report) | anonymous direct, **resumed by agent ID** (`subagent_type: autoflow-planner`, no `name`) | one spawn per discussion, woken by `SendMessage` for each of its turns and once for its report; every turn is appended to `.autoflow/issue-{N}-architect-transcript.md` and the return is one line. The lifetime is inside ARCHITECT only — no role's lifetime spans a phase boundary (ADR-0023 D2, D3) |

The ARCHITECT discussion is an orchestrator relay of the two participants above (ADR-0023); the `Workflow` named `architect-deliberation` is its **Record** phase alone (scribe + ledger over the transcript file), and the VERIFY cause-branch remains a `Workflow` facilitation. Neither workflow is an `Agent` spawn: their sub-agents are in-script and their result returns through the Facilitator Return Contract (`docs/teammate-contracts.md` > Facilitator).

Why the single mode: the grounds are **cost and consistency, not delivery correctness**. A named spawn is a persistent, resumable teammate, and every wake of one re-writes context it had already read (#136: 16–43% of agent cost across two cycles, ADR-0017 > Notes > C8; the #168 probe re-wrote 53% of the prefix on a warm wake and 100% on a cold one), while the C7 pilot found no detection benefit to offset it (ADR-0021: the direct channel `EQUAL_OR_BETTER` on VERIFY steps 3 and 4). A direct spawn's return value *is* its report, so there is one delivery path and one declaration channel. The #40 final-text loss that first motivated the migration was re-measured on Claude Code 2.1.260 and did **not** reproduce — a named spawn's final text now arrives in its idle notification's `result` field (issue #168; record at `docs/teammate-common-rules.md` > Result delivery path by spawn mode) — so it is retained as the migration's history, not as a ground.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

**[MUST]** Role-scoped injection does not break DIAGNOSE context separation: the structure-analysis path (Phase A) and the issue-analysis path (Phase B) receive disjoint document sets. The per-role injection whitelist — which baseline/review/ADR doc is allowed into which DIAGNOSE phase — is the DIAGNOSE playbook's body ([`docs/phases/analysis.md`](docs/phases/analysis.md)). ARCHITECT-onward injection guidance lives in [`docs/autoflow-guide.md`](docs/autoflow-guide.md) and preserves role-minimal injection and [Deliberation Isolation](#deliberation-isolation-delegated-facilitation).

## Communication — Agent Teams

The Agent Teams channel is **retired**. Communication with teammates uses the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**. There is no team to create, no mailbox, and no persistent teammate.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to `.autoflow/*` and returns an anchor + one-line summary (see *Teammate report format* below).
- The team-creation call and the `team_name` + `name` spawn form are no longer used: ADR-0017 recorded the removal, ADR-0021 discharged the blocking pilot, and the migration is carried. `SendMessage` has exactly one use — waking an ARCHITECT relay participant by its agent ID for its next turn (ADR-0023 D2); it is never a report channel, and a participant's answer arrives as the task notification of that resumed spawn. A future multi-repo topology re-opens the cross-service coordination question through a new ADR rather than by reviving the channel.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Cost Control

These rules apply to every cycle to prevent token-cost blow-up. Background: Claude Code's `TeammateIdle` hook cannot cancel orchestrator turns and there is no native `agentTeams.skipIdleTurns` setting (per [agent-teams docs](https://code.claude.com/docs/en/agent-teams.md) and [costs docs](https://code.claude.com/docs/en/costs.md)), so cost control is enforced at the codebase level.

- **Phase-boundary respawn**: ARCHITECT's two relay participants live for one discussion and are not woken again once the Record `Workflow` has returned (ADR-0023 D2; there is no facilitator or teammate to shut down). At DISPATCH entry the orchestrator spawns fresh agents for RED/GREEN, passing `.autoflow/issue-{N}-*.md` paths only — discussion history is not carried into implementation phases.
- **Teammate report format**: reports must reference `.autoflow/*` or source file paths and include a one-line summary. Do not inline document body content or full file text in messages. See [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format.
- **[MUST] Orchestrator context discipline**: the orchestrator holds only anchors, summaries, verdicts, and decisions — never raw material. It does not read a full artifact (whole design docs, full source files) to judge it, nor run multi-step investigations in its own context; that absorption is **delegated** to a subagent or teammate that writes any body to `.autoflow/*` and returns only an anchor + one-line summary. This extends *Teammate report format* to (a) the orchestrator's own reads and (b) every direct/ad-hoc `Agent` spawn, scripted-phase or not (e.g. DIAGNOSE Phase A/B/3 write `.autoflow/issue-N-phase-*.md` and return a summary, not the body). Cheap anchor-checks stay in-context — a `git show <SHA>`, a one-line command re-run, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify teammate claims). Full body enters orchestrator context only when strictly required (e.g. evaluator scores). Multi-teammate **deliberation** is absorbed the same way — a discussion is delegated to a facilitator sub-context, not run in the orchestrator's turn stream (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation)). The "anchor + one-line summary" rule bounds what the orchestrator **retains**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `.autoflow/*` body the user reads is written in that order.
- **jest output**: run with `--silent --reporters=summary`. Never paste raw verbose jest output (per-case lines, full coverage report) into a teammate message or report. The shell-suite counterpart — runner output to a log file, `tail -n 20` into context, file re-reads by `sed -n` range — is fixed by `docs/submodule-common-rules.md` > Testing Standards item 7 and the `autoflow-tester` / `autoflow-implementer` agent definitions (issue #136: a Test AI carried 515K of context, 86% of it Bash output and file dumps, and re-read its own test file 22 times because the needed lines had scrolled out of reach). See [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Testing Standards.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once. Each spawn is anonymous and direct, so there is no session occupancy to manage — the cap bounds concurrent token burn, not team membership. The #136 cost measurement that motivated per-message discipline for named teammates (ADR-0017 > Notes > C8) is discharged structurally: with no named teammate there is no wake message, no HOLD, and no idle-notification turn to pay for.

### Deliberation Isolation (delegated facilitation)

Multi-teammate deliberation phases (ARCHITECT; the Developer-AI ↔ Test-AI cause-branch exchange in VERIFY) run inside an **isolated facilitation sub-context**, not in the orchestrator's own turn stream. This is a structural rule, not a cost optimization — see [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 8.

**Why** — a teammate→lead `SendMessage` is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator is the discussion lead, every round of Developer-AI ↔ Test-AI cross-talk lands in its context, and the two teammates' near-duplicate convergence reports (e.g. dev `Full mutual ACCEPT` + test `MUTUAL ACCEPT reached`) load the same information twice. Beyond token cost, this contaminates judgment: retracted claims, wrong oracles, and reversed scopes accumulate in the orchestrator's working context and it oscillates on decisions it had already settled (observed in issue #189). A cheaper or summarized round (file-pull, checkpoint summary) does not fix this — the orchestrator still receives the round and the duplicate accumulation. Removing the contamination requires removing the orchestrator from the loop, not shrinking each message.

- **[MUST]** A multi-teammate deliberation never runs in the orchestrator's own turn stream, and it is never a nested Agent Team — a spawned teammate cannot create its own team and a team's lead is fixed for its lifetime, so a nested-team facilitator is not executable; a peer-teammate facilitator is rejected on the ground recorded at [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 8, which cites the measurement in `tests/manual/issue-52-manual-scenarios.md` > M1. The realization is per phase (ADR-0023 D3):
  - **ARCHITECT — orchestrator relay of two persistent participants** (ADR-0023 D2). The orchestrator spawns the Developer AI and the Test AI once each (`subagent_type: autoflow-planner`, anonymous, model from the policy rows `architect-dev-participant` / `architect-test-participant`) and wakes them in alternation by agent ID (`SendMessage`), waiting for each answer by ending its turn (*Wait discipline*). Every turn is appended by its author to `.autoflow/issue-{N}-architect-transcript.md` and the participant returns **one line** (turn number, anything further); the orchestrator reads that line and `scripts/architect/relay-state.sh state`, which prints the next side and whether the discussion has ended — two consecutive turns marked `further: none` (issue #166, unchanged) — and never a turn body. Each participant then appends its report to the same file, and the **Record** `Workflow` (`architect-deliberation`) reads the file in-script: a scribe writes the artifacts to `.autoflow/*`, a ledger call appends the agreed conclusions, and the run returns **only** `{ report: { agreed, unagreed[] }, artifacts, transcript, ledger, summary, stopped }` ([`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator > Return Contract), which the orchestrator routes — a report with no un-agreed point goes to GATE:PLAN, an un-agreed point is one orchestrator judgment (discuss further with a `brief` appended to the transcript, or stop and ask the user), and a non-null `stopped` names an infrastructure failure to repair and re-run. Isolation holds by the participants' prompt (turn bodies go to the file, not the return) and is checked after the fact by `scripts/architect/isolation-check.sh`; the orchestrator never receives the round-by-round messages or the two reports' bodies.
  - **VERIFY cause-branch — an isolated `Workflow`** (Claude Code v2.1.154+): the Developer-AI and Test-AI self-checks run in-script ("intermediate results stay in script variables instead of landing in Claude's context") and the run returns `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI }`.
  Reference scripts: `.claude/workflows/{architect-deliberation,verify-cause-branch}.js`; relay state: `scripts/architect/relay-state.sh`.
- **[MUST] Isolation is for deliberation, not verification.** Delegated facilitation removes the orchestrator's exposure to round-by-round prose — it does **not** remove the orchestrator's verification job. After the result returns, the orchestrator does **not** read the design docs cover-to-cover to judge them (that full read-and-score is GATE:PLAN's fresh Evaluation AI); it **spot-checks targeted excerpts** — pulling the specific `path:line` a returned decision rests on and re-deriving the cited fact (`git show`, command re-run, `git show HEAD:<file>`). The catches that justify the orchestrator's role come from these targeted facts, not from reading deliberation prose; that leverage is preserved.
- **Termination** (per [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 7; issue #166): the ARCHITECT discussion ends at the participants' conclusion — the Developer AI and the Test AI alternate single-participant turns, each turn's heading marker saying whether it has anything further to raise, and the discussion ends when two consecutive turns both say it has nothing further; `relay-state.sh` computes that condition from the transcript file and the orchestrator obeys it (no cap, no judgment). Each participant then reports what was agreed and what it considers worth raising as un-agreed, and the orchestrator routes the Record workflow's report: no un-agreed point → GATE:PLAN; an un-agreed point → one orchestrator judgment, discuss further (append what the next discussion needs as a `brief` and re-wake the participants — the brief re-opens the end condition) or stop (report situation-first and ask the user). A non-null `stopped` is infrastructure — the record could not be carried out, so it is repaired and re-run; a participant that appends no turn after one re-wake is the relay's counterpart, handled in the ARCHITECT playbook. VERIFY is a **single** self-check round (deterministic `next_action`, no internal loop). The operator procedure is in [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > ARCHITECT > *Report routing*.
- **Respawn / lifecycle**: the ARCHITECT participants live for one discussion and are not woken after the Record workflow returns; the VERIFY facilitation is a self-contained workflow run that ends when it returns its result (no long-lived teammate to shut down in either case). At DISPATCH entry the implementation teammates (RED/GREEN) are spawned fresh, carrying only `.autoflow/*` paths (see *Phase-boundary respawn* above).

#### Decision Ledger

A per-issue append-only record, `.autoflow/issue-{N}-ledger.md`, fixes settled decisions so an enlarged context cannot silently re-open them.

- Each entry records: the decision (one line), its **grounds** (evidence / artifact `path:line`), its **authority** (what settled it — `ARCHITECT mutual ACCEPT`, `GATE:PLAN PASS (avg 8.2)`, `VERIFY Evaluation-AI arbitration`), and the cycle/phase.
- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content), not a re-reading or re-interpretation of material already on the record. This caps oscillation-driven round explosion and aligns with the GATE-verdict-outranks-rereading rule (a settled gate verdict is not overturned by re-reading the issue body).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact and references the entry it supersedes.
- **The Green-tree register spans two stores, and only one of them is this ledger.** A certificate is
  written both here and to a repo-scoped **shared store** outside the repository tree
  (`$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md`), by one writer, so a later issue can
  inherit a Green an earlier one certified at the same tree. That store is a **cache, not a ledger**:
  it carries no authority, it is not append-only (it is pruned), a malformed entry in it is skipped
  with one warning rather than treated as unreadable-and-therefore-blocking, and it is **not gate
  input** — no gate verdict, retry cap or phase transition reads it. Losing it costs re-runs and
  nothing else. Every rule in this section binds the ledger half only; see
  [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY > *Green-tree register* for the shared
  half's grammar and dispositions.
- The ledger is outside every teammate's scope — it is host-owned, written only by the orchestrator and its facilitator delegate: the facilitator appends the deliberation's agreed conclusions under the authority `ARCHITECT agreed`; the orchestrator appends each gate's verdict after the gate, records a loop-check observation (complaint class, witness, prior-change shape, cycle) on **every** review-response DIAGNOSE entry to seed the next cycle's baseline, appends the VERIFY detection record (the steps 3/4 outcomes, `verify-detection`-marked — a record, not a decision; see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY > *Detection record*) at VERIFY exit, appends the Green-tree register's `green-tree` entry (the offerable Green) and its `green-tree-use` entry (what the step's predicate evaluation did) at the exit of the phase whose step ran or inherited the suite — both records, not decisions; see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY > *Green-tree register* — and — when a match pauses for the user — appends the user's re-entry decision as a separate entry after they answer.

**Entry identifier**. A settled-decision entry is headed `## <ID> — <title> (cycle <C>, <PHASE>)`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only. An auto-triggered review-response entry carries its HANDOFF marker in the same grammar: `## O<n> — <title> (cycle <C>, HANDOFF) [review-autofix]` — the marker stays at the end of the heading, so the cap's count predicate ([`docs/autoflow-guide.md`](docs/autoflow-guide.md) > HANDOFF step 6.5) is unaffected by the identifier prefix. Record entries (`green-tree`, `green-tree-use`, `verify-detection`) are level-3 headings and carry no identifier.

| Writer | Namespace |
|---|---|
| Orchestrator | `O` |
| Facilitator delegate | `F` |
| Pre-protocol legacy entries (readable, never issued) | `E` |

This table is the mapping's only documentary home; other documents cite it rather than restate it.

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is the
**operator's** authority, never a deliberation's; choosing how a criterion is *verified* is the
deliberation's, provided the row states its reason, which the external reviewer then judges at
HANDOFF (the three-tier guard — [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > ARCHITECT >
*Report routing*). When an agreed conclusion of the ARCHITECT deliberation changes an acceptance
criterion's content — excluding, revising or splitting it — the orchestrator presents it to the
operator before GATE:PLAN, and the operator's answer is recorded as one entry per decided AC, in the
same trailing-marker grammar:
the heading `## O<n> — <title> (cycle <C>, ARCHITECT) [ac-decision]`, followed by the entry's own
`- AC: <ac id>` line, a `- Disposition:` line valued `excluded` / `revised` / `split`, and the
ordinary Decision / Grounds / Authority lines with the authority value `operator decision`.

The marker sits at the **end** of the heading, so HANDOFF's `[review-autofix]` count predicate is
unaffected — the same non-interference the `verify-detection` record declares. The issue text's
`authority: operator` maps to exactly two literals and nothing else: the entry's authority **value**
is `operator decision`, and the entry is **located** by the `[ac-decision]` heading marker. The
two gate backstops key on the marker; the ARCHITECT topic's seed sentence names `operator decision`
as settled, so a later discussion reads the operator's call rather than re-arguing it. When the
disposition is `revised` or `split`, the Phase B acceptance-criterion table is edited to match
before re-entry, and this entry is the record of who authorized the edit.

- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. The script holds no state: it derives the serial from the file on disk at call time, and that is precisely what keeps two writers who cannot see each other's in-flight appends from colliding. A batch that allocates once and counts up locally re-introduces the collision it was meant to prevent.
- **[MUST]** `bash scripts/ledger/ledger-entry-id.sh check <ledger>` runs after the appends, and every defect it reports is resolved before the writer returns. `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error. The gate hook runs the same check as a **non-gating advisory** over changed ledgers: it warns, and never denies a tool call over a ledger defect.
- **Legacy ambiguity**. Entries written before this protocol may already share an identifier, and repairing them would rewrite an append-only record — so they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair.

### Discussion Protocol

→ Single source of truth: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Discussion Protocol

The orchestrator and teammates follow the same rules. Core: UNDERSTAND → VERIFY → EVALUATE → RESPOND (ACCEPT / COUNTER / PARTIAL / ESCALATE). No groundless agreement, no evaluation without reading the relevant files, devil's advocate required on the first exchange.

## Development Lifecycle — AutoFlow

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

**PREFLIGHT cannot be skipped.** If PREFLIGHT's completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the blocking condition first and report.

```
PREFLIGHT       : Pre-Work          — prior-cycle resolution (cleanup after external merge/close), Git clean check, remote sync, dev branch creation, target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op)
DIAGNOSE        : Issue Analysis    — intake readiness triage (new-issue: planning/design/ADR pre-req filter), affected scope, hypothesis classification, lightweight verification, task decomposition, affected docs
GATE:HYPOTHESIS : Hypothesis Eval   — Evaluation AI (3 items × 10 points), bug/incident issues only
ARCHITECT       : Plan Synthesis    — orchestrator-relayed persistent participants (Developer AI + Test AI, ADR-0023) discuss on a transcript file; a Record Workflow writes the feature design + verification design
GATE:PLAN       : Plan Evaluation   — Evaluation AI (5 items × 10 points)
DISPATCH        : Task Assignment   — TaskCreate, then a direct Test AI / Developer AI spawn per phase entry (acceptance criteria + verification design)
RED             : Test Writing      — Test AI writes tests from acceptance criteria; Red confirmation
GREEN           : Implementation    — Developer AI writes minimum code that satisfies the in-scope acceptance criteria and passes the automated tests
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
| PREFLIGHT → user | a fail-closed stop condition fails — bundle drift, reviewer-backend CLI absent, or a target-declared local check (`scripts/preflight/local-checks.sh`, issue #181, PREFLIGHT Step 1a — run before the Git clean check and before the state file is created, so a failure leaves no `active:true` state and the next entry starts PREFLIGHT again) that does not pass after its declared repair → report and stop; DIAGNOSE does not begin. Checks that pass but leave the worktree dirty route to PREFLIGHT Step 4 (resolve, then re-run), not to the user. Absent declaration is a no-op recorded in the ledger, not a stop |
| PREFLIGHT (review-response) → DIAGNOSE bounded / full | the previous cycle's `.autoflow/issue-{N}-*.md` artifacts are preserved as `issue-{N}-c{C}-*.md`; `scope-bounded: true` in the findings file → bounded path (Phase A reused, ARCHITECT's brief states the bounded scope, AUDIT re-scores the prior Low list on the change surface); otherwise the full path. After GREEN, `scripts/review/scope-bounded.sh check-fix` — a fix that adds a file leaves the bounded path (ARCHITECT re-discussed with the full topic, no re-entry budget consumed). See `docs/autoflow-guide.md` > PREFLIGHT > Scope-bounded entry |
| DIAGNOSE (intake readiness triage) → user | `mode=new-issue` only. A planning/design/ADR prerequisite is clearly required first → write reason + suggested issue-split draft to `.autoflow/issue-{N}-triage.md`, present situation-first (the user-visible problem + suggested split in domain terms; the file is the drill-down anchor — see Execution Principles > Human-decision presentation), pause (`active:false`, `phase:"awaiting-user"`). No auto issue creation; ambiguous → PASS to structure analysis. |
| DIAGNOSE (intake readiness triage) → structure analysis | triage PASS (no clear prerequisite) → Phase A/B fan-out begins |
| DIAGNOSE (structure eval) → close / reply / user | GATE:HYPOTHESIS structure FAIL → gap-item-low (already satisfied): mode=new-issue → issue auto-closed + terminated, mode=review-response → reply on PR + active:false (awaiting-external-review), no close. Gap real but Code-change-necessity low (non-code lever) → report to user + pause |
| DIAGNOSE (review-response loop check) → user | trigger comment repeats the immediately-prior review-response cycle's complaint class with a new witness case → reply on PR + await the user's re-entry decision (`phase: awaiting-user`) |
| DIAGNOSE (structure eval) → DIAGNOSE (cause) | GATE:HYPOTHESIS structure PASS (code change required) |
| DIAGNOSE → GATE:HYPOTHESIS (cause) | hypothesis classification + lightweight verification done (bug/incident issues) |
| DIAGNOSE → ARCHITECT | affected scope identified (feat issues — skip GATE:HYPOTHESIS cause) |
| GATE:HYPOTHESIS → ARCHITECT | cause analysis PASS + code change required |
| GATE:HYPOTHESIS → user | non-code root cause confirmed → report to user |
| ARCHITECT → GATE:PLAN | the deliberation's report carries no un-agreed point, and no agreed conclusion changes an acceptance criterion's content — a reduced verification disposition carrying a stated reason is not one: it passes the three-tier guard (deliberation → external reviewer at HANDOFF → operator only for AC content changes) |
| ARCHITECT (un-agreed) → ARCHITECT / user | the report raises an un-agreed point → one orchestrator judgment. Discuss further: prepare what the next discussion needs — a narrowed topic, facts verified in the meantime, the prior report path, a different perspective for a participant to take — and re-run with that `brief`. Or stop: report situation-first, set `active:false`, `phase:"awaiting-user"`, and let the user's decision drive re-entry |
| ARCHITECT (acceptance-criterion content change) → user | an agreed conclusion excludes, revises or splits an issue acceptance criterion → report situation-first, set `active:false`, `phase:"awaiting-user"`, and do **not** spawn GATE:PLAN. The operator's answer is recorded as one `[ac-decision]` ledger entry per decided AC and the Phase B acceptance-criterion table is edited to match on `revised` / `split`; the cycle then continues to GATE:PLAN, consuming no re-entry budget |
| GATE:PLAN → DISPATCH | plan evaluation PASS |
| DISPATCH → RED | task instructions delivered (Test AI starts first) |
| RED → GREEN | tests written + Red confirmed — every `driving` / `regression` test fails; a `characterization` test may already pass |
| GREEN → VERIFY | implementation done (or, when the acceptance criteria are mutually unsatisfiable, the satisfiable subset implemented and the contradiction recorded — see GREEN playbook) |
| VERIFY → REFINE | all tests PASS + minimal-implementation and mock-boundary fidelity checks pass |
| REFINE → VALIDATE | refactor done + Green re-confirmed |
| VERIFY → GREEN | implementation issue → Developer AI re-implements |
| VERIFY → RED | test issue → Test AI fixes test → re-Red → GREEN re-entry |
| VERIFY → Evaluation AI | deadlock (both claim "no problem") → Evaluation AI arbitrates; its verdict routes to RED (test misreads an AC), GREEN (implementation misses an AC), or human (undecidable), and hands off to ARCHITECT when it finds the acceptance criteria themselves mutually unsatisfiable (design contradiction — row below) |
| VERIFY → ARCHITECT | design contradiction — the arbitration finds implementation and test each faithful to the design while the acceptance criteria are mutually unsatisfiable, reproduced by measurement and recorded in the GREEN blocker report `.autoflow/issue-{N}-*-green-blocker.md` → ARCHITECT re-deliberation → GATE:PLAN re-evaluation → RED re-entry (cap: see Regressions line below) |
| VALIDATE → AUDIT | automated tests all PASS + manual checklist itemized |
| VALIDATE → RED / GREEN | step-1 whole-tree sweep (`run-suites.sh --all`, unconditional — the cycle's coverage floor) fails → cause-branched by the first failing assertion's suite: a `ci-subject` that names only test assets (`tests/**`) → `test` → RED; any other subject → `impl` → GREEN (`scripts/gate/remedy-route.sh route`). Same branching as GATE:QUALITY FAIL below |
| VALIDATE → user | lint-chain check: a discovered chain covering a staged file is `not-run (unexecuted)` and is neither executable in this checkout nor covered by a nameable pull-request CI job → report situation-first + pause (`active:false`, `phase:"awaiting-user"`) |
| AUDIT → GATE:QUALITY | security audit PASS |
| GATE:QUALITY → DELIVER | completion evaluation PASS |
| GATE:QUALITY (FAIL) → doc commit / RED / GREEN / ARCHITECT | FAIL routed by the evaluator's per-failed-item `remedy_class` (`doc` / `test` / `impl` / `design`; mixed → farthest: `design` > `impl` > `test` > `doc` — `scripts/gate/remedy-route.sh route`): `doc` → orchestrator doc commit anchored on a repo-wide sweep record (`.autoflow/issue-{N}-remedy-sweep.md`, hook-gated) → selected suites → GATE:QUALITY re-score; `test` → RED; `impl` → GREEN → VERIFY step 1 → REFINE → VALIDATE; `design` → ARCHITECT (consumes the ARCHITECT re-entry counter). Re-entry re-scores only the failed items and any inherited item whose anchor files the re-entry diff touched (`docs/autoflow-guide.md` > GATE:QUALITY > FAIL routing) |
| GATE:QUALITY (FAIL) → user | any failed item carries `remedy_class: operator` (the evaluator could not classify it with confidence) → report situation-first, `active:false`, `phase:"awaiting-user"`; the operator's answer fixes the class and the cycle re-enters on that class's route. A FAIL report missing `remedy_class` on a failed item is rejected and the evaluator re-spawned (same disposition as a missing `fail_hypothesis`) |
| DELIVER → INTEGRATE | sub-repo push + Teammate shutdown done |
| INTEGRATE → HANDOFF | integration tests pass |
| INTEGRATE → GREEN | integration / bundle failure — fixed `impl` class → GREEN → VERIFY step 1 → REFINE → VALIDATE |
| HANDOFF (review-triage) → review-response (auto) | after the configured-reviewer review the verdict is `max_severity ≥ Medium` — the orchestrator first appends the `scope-bounded:` judgment (`scripts/review/scope-bounded.sh triage`: Medium+ finding files ⊆ PR diff files, a set relation, never a size estimate) to the findings file — label present as expected → auto-enter directly; label absent (the reviewer's own attach did not land) → orchestrator backstop attach first (step 6.5), then the same auto-entry. Either way, auto-enter a review-response cycle in-session with the reviewer comment as the DIAGNOSE trigger; the orchestrator never removes the label — the reviewer re-review clears it |
| HANDOFF (review-triage) → reviewer re-review / operator | label present but `max_severity < Medium` (or no verdict) → label-clear / review-infra failure, not a code finding → re-run the step-6 configured-reviewer review; still stuck → escalate (`active:false`, `phase:"awaiting-user"`). Does not consume the 7-attempt cap |
| HANDOFF (review-triage) → user | auto-resolution hits a user-decision criterion (contract/AC change, ambiguous fix, `Low Confidence` item, loop-check match) or the 7-attempt cap → `active:false`, `phase:"awaiting-user"` |
| HANDOFF → end | all PRs cleared of `blocked-by-review` (no Medium+) + Low triage resolved + CI green (host PR carries `Closes #N`) → state `active:false` → AutoFlow ends; external review reviews and merges out of band |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF → RED | CI failure (code issue) → fix tests/implementation and re-flow |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS cause FAIL → DIAGNOSE (max 2×). GATE:PLAN FAIL → ARCHITECT (max 3×; a VERIFY design contradiction re-deliberation consumes this same counter, so ARCHITECT re-entries are capped at 3 per cycle regardless of which phase triggered them; a re-discussion the orchestrator runs after an un-agreed report is not a re-entry and consumes no counter — it continues the deliberation already counted; an acceptance-criterion pause is likewise a human authority checkpoint inside that deliberation, not a new one). VERIFY FAIL → cause-branched fix (max 3 round-trips). REFINE FAIL → Developer AI fixes and re-runs (max 2×; on second failure, abandon refactor and proceed to VALIDATE with the Green state). AUDIT FAIL → fix and re-evaluate (max 2×). GATE:QUALITY FAIL → class-routed re-entry (doc commit / RED / GREEN / ARCHITECT by `remedy_class`; max 3× — the cap counts FAILs, not the distance re-entered; a `design` route also consumes the ARCHITECT re-entry counter above). VALIDATE step-1 whole-tree sweep FAIL → RED or GREEN by class (no new cap — the existing GREEN ↔ VERIFY round-trip rules apply). INTEGRATE FAIL → GREEN (`impl`). HANDOFF failure → cause classification: code issue → RED; environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at HANDOFF) → review-response (max 7×; on the 7th consecutive (per the count window in `docs/autoflow-guide.md` step 6.5) without the `blocked-by-review` label clearing, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total). VERIFY deadlock other than a design contradiction, unresolved by Evaluation AI arbitration → human. HANDOFF internal retry exhausted → human.
**PR creation**: at HANDOFF, the orchestrator opens the PR(s), places `Closes #N` on the host PR, and confirms CI is green. Merging is external; AutoFlow does not merge.

### Phase Playbook Loading Contract

Each phase's procedure body — its numbered steps, scoring rubric, and phase-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **playbook**, not in this core file. This file retains only what every phase needs to *route*: the cross-phase invariants (above), the router (the phase list and Flow Control table above), the regression / escalation caps (above), the Execution Principles (below), and the state schema (below).

**[MUST]** On entering a phase, Read its playbook below **before** acting in that phase. The playbook is the source of truth for that phase's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the playbook each cycle (the playbook may have changed, and the gate verdicts depend on its current rubric).

| Phase | Playbook to Read on entry |
|-------|---------------------------|
| PREFLIGHT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT; git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| DIAGNOSE | [`docs/phases/analysis.md`](docs/phases/analysis.md) — intake readiness triage (new-issue), 3-Phase A/B/3 analysis, per-role injection whitelist, issue-type scoring rubric, FAIL disposition, bias prevention |
| GATE:HYPOTHESIS | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:HYPOTHESIS |
| ARCHITECT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > ARCHITECT (the relay procedure); facilitator contract: [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator; participant prompt: `.claude/agents/autoflow-planner.md`; isolation rationale: this file > Deliberation Isolation; decision: `docs/adr/0023-deliberation-participant-lifetime.md` |
| GATE:PLAN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:PLAN |
| DISPATCH | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > DISPATCH |
| RED | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > RED |
| GREEN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GREEN; change surface: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules |
| VERIFY | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY |
| REFINE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > REFINE |
| VALIDATE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VALIDATE |
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
- **Teammate idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a teammate sends an actionable report — post-migration, that report is the spawn's return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. A spawned subagent has no future turn to receive a background-completion notification, so when a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `.autoflow/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop, which has future turns to receive the notification). A spawned teammate is reaped at its final response, so a pending background task is lost — teammates run foreground-only; the binding rule lives in `docs/teammate-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** is not used: the deprecated `TaskOutput` tool, or a foreground `sleep` loop polling for a result, returns only when its one target ends or its timeout fires, so every other completion notification and every user prompt queues behind it, and a timed-out agent wait dumps that agent's transcript tail into the orchestrator's context (issue #165: 77 `TaskOutput` blocks, 82% of an 8h session spent inside them, one user prompt never delivered, two transcript dumps of 16–27K tokens that the orchestrator then read as progress evidence — the raw-material intake *Orchestrator context discipline* forbids). `TaskOutput` is **denied at the tool boundary** by the hook, state-independently. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: every role is an anonymous direct spawn whose return value is its report, so a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your final message". This is the inverse of the pre-migration hazard and rests on the same measurement: under the named channel of that time the runtime discarded a spawn's final turn text, so the "final message" idiom mis-applied to a mailbox spawn induced the very loss it was meant to prevent (#40: 2 occurrences of the anonymous-direct idiom mis-applied to a mailbox spawn; the loss did not reproduce on 2.1.260 — issue #168). The migration removed the channel that made those two idioms divergent — there is now one delivery path, and it is the return value. What happens to a spawn's final text is `docs/teammate-common-rules.md` > Result delivery path by spawn mode; the pilot that cleared the migration is ADR-0021.
- **Non-delivery reading**: a direct spawn has no future turn, so it never sends a follow-up. When a spawn returns **Done** with no report — or returns nothing usable — do not wait: verify its `.autoflow/*` artifact by shell and proceed, or re-spawn. The pre-migration counterpart of this rule read a named teammate's idle notification for a `summary: "[to main] …"` field, whose absence meant *report not sent* rather than *still working*; that signal matched delivery across all 12 subagents of the #40 cycle, and it is retained as the measurement behind the migration, not as a live procedure — no notification channel remains to read it on. Recovery is now the shell-verification path in *Teammate idle handling* above, which was already the direct-spawn half of the same rule.
- **Verify teammate claims before dispatch**: every teammate report's Evidence anchor (see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, re-running the cited command for a test-summary anchor, `git show HEAD:<file>` for a file-state anchor. **An anchor-less report is rejected, not interpreted.** One discharge, and only one: a host-written `green-tree` register entry whose `tree` equals the current tree **discharges the test-summary re-run for that tree** — the entry is the orchestrator's own record of a run it executed, so re-running the cited command would re-derive what the host already wrote (see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY > *Green-tree register*); every other anchor class re-derives as above. Do not dispatch based on a single AI's unverified claim — stale snapshots in working memory or hash confabulation can cause noop redo dispatches.
- **Incomplete output is never ground truth**: a 1-line tool result — a Read-dedup stub (`file unchanged … refer to that earlier tool_result`; the dedup ledger is not reset on compaction, `anthropics/claude-code#46749`) or a `Cancelled: parallel tool call … errored` — is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`, which bypasses the dedup ledger) and reproduce the finding before acting. Do not batch parallel `cd`-prefixed Bash — use `git -C <path>` + absolute paths. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the DIAGNOSE playbook ([`docs/phases/analysis.md`](docs/phases/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `.autoflow/<name>.md` per [`docs/issue-proposal.md`](docs/issue-proposal.md) and running `scripts/issue/create-issue.sh --draft .autoflow/<name>.md`, which re-runs the duplicate search from the draft's own title. The check is therefore performed, not asserted — a report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list so its invocation still raises an operator prompt.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.
- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (DIAGNOSE intake-triage FAIL, structure-gate non-code lever, GATE:HYPOTHESIS non-code root cause, review-response loop-check match, HANDOFF review-triage user pause) — the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ code anchors (`path:line` / SHA) demoted to supporting evidence for drill-down, never the lead. This register is distinct from the machine **Reporting Format** ([`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Reporting Format), which is anchor-first because its audience is an AI that re-derives the anchor deterministically; a human exercises design / context judgment and needs the situation, so the format follows the audience's verification mode. The `.autoflow/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what the orchestrator **retains**, not how a human decision is **framed**.

### AutoFlow State Tracking (Hook integration)

While AutoFlow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

**File naming**: `.autoflow/issue-{N}.json`

**Companion artifact**: `.autoflow/issue-{N}-ledger.md` — the append-only decision ledger (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation) > Decision Ledger). Created at the first settled decision; retained alongside the state file and archived with it (moved to the external store) at prior-cycle cleanup once the PR is merged/closed (see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT). The hook reads it **advisorily only** — on a ledger whose content changed it runs the identifier check and may emit a warning, and it never denies a tool call on what it finds. The ledger is not a gate input: no gate verdict, retry cap or transition reads it.

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

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF triages the configured-reviewer review result (auto-resolving Medium+ findings or judging Low findings before handoff); `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no `blocked-by-review` label remains) and at a structure-gate no-work review-response exit (both hand the open PR to external review); `"awaiting-user"` at a non-code-lever / non-code-root-cause pause, at a review-response loop-check match awaiting the user's re-entry decision, at an ARCHITECT stop or an acceptance-criterion content change awaiting the operator, or at a HANDOFF review-triage user-decision / 7-attempt-cap / label-clear-failure escalation pause. A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**`verdict` rule** (gate_hypothesis_cause only):

| Issue type | When | `verdict` value |
|------------|------|-----------------|
| Bug / incident | Created at PREFLIGHT | `"pending"` |
| Bug / incident | After GATE:HYPOTHESIS evaluation | `"evaluated"` |
| Feat | Set at DIAGNOSE | `"skipped (feat issue)"` |

If `verdict` is empty or contains `skip`, the gate is not triggered for the cause-analysis form. Bug issues must be initialised as `"pending"` so the gate fires.

**Score recording**: write the Evaluation AI's `scores` verbatim, in the shape the hook validates — shown below. Each item's score is a number in `0`–`10`; the two shapes may be mixed within one gate. A prose string such as `"9 - reason"` is **not** a score: the hook's state-file validator rejects it, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until the file is repaired. Format source: [`docs/evaluation-system.md`](docs/evaluation-system.md) > Evaluation Output Format.

<!-- SCORE-SHAPE-EXAMPLE -->
```json
{ "feasibility": { "score": 9, "reason": "evidence" }, "scope": 8 }
```

This object is the value of `phases.<gate>.scores` in `.autoflow/issue-{N}.json`.

**Remedy class recording** (GATE:QUALITY FAIL only): the orchestrator writes the routed class — the farthest of the evaluator's per-failed-item classes, or `operator` — as `phases.gate_quality.remedy_class` (a sibling of `evaluator` and `scores` inside the phase object, the one additive placement the validator admits; never top-level, never inside `scores`). The value is removed, or left behind by a later cycle's `gate_quality` record, once the re-score PASSes. The hook reads it for the `git commit` gate above and nowhere else.

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (role `planning`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` contains `skip` (feat).
- `Agent` (role `testing`) → GATE:PLAN pass required.
- `Agent` (role `implementation`) → GATE:PLAN pass required.
- `Agent` (role `analysis` / `evaluation` / research types) → not score-gated (evaluation must stay spawnable — it produces the gate scores).
- `git push` → AUDIT + GATE:QUALITY pass required.
- `gh pr create` → AUDIT + GATE:QUALITY pass required.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `.autoflow/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch (`main`) → **denied while a state file has `active:true`**. AutoFlow never merges; merging is external.
- `TaskOutput` (any call) → **denied state-independently**, for every actor; a tracked task is awaited by ending the turn and taking its task notification — see Execution Principles > *Wait discipline* (issue #165).
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`docs/issue-proposal.md`](docs/issue-proposal.md).
- A **backgrounded** run of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground so their result is keyed to the capture-point tree (see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY > Green-tree register; matching rule: `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

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
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (chain discovery, conversion limit, scoping, outcome vocabulary, evidence anchor): [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.

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
- **Security checklist**: [`docs/security-checklist.md`](docs/security-checklist.md)
