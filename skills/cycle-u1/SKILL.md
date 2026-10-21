---
name: cycle-u1
description: >-
  Run unit U1 (Preparation — PREFLIGHT, CRITERION-REVIEW) of an AutoFlow
  cycle alone, in a session of its own, with the parts of the core U1 uses.
  Use only when the operator starts a U1 session (/autoflow:cycle-u1 <N>
  [new]).
argument-hint: "<issue-number> [new [--base <branch>] [--commit <commit>]]"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt, `--base <branch>` / `--commit <commit>` its base and start commit for `autoflow-records new`) — unit U1, Preparation (PREFLIGHT, CRITERION-REVIEW), of issue #N's cycle alone: confirm from `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` that the cycle stands at U1's entry (otherwise report the situation and stop), run U1 from its entry to its exit transition, and end the session with the report the invoking prompt asks for.

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that U1 uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle > Flow Control > Any unit: BUILD / gate recommendation, GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY, Regressions, Push and PR creation; Development Lifecycle > Unit Document Loading Contract: The gate PASS thresholds, U2 Analysis, U3 Design, U4 Build and verify, U5 Completion eval, U6 Delivery, U7 Review, The rubric of every gate, The evaluation contract; Development Lifecycle > Unit references: U2 Analysis, U3 Design, U4 Build and verify, U5 Completion evaluation, U6 Delivery, U7 Review; Spawn Model: A unit agent's spawns inherit its gate class; Project Information: A project whose information names sub-repos; Team Structure: Evaluation AI, Build unit (U4), Functional-unit agents; AutoFlow State Tracking: Score recording, This object is the value, Remedy class recording; Evaluation System; Git Workflow — Rules: Commit Ownership.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/preparation.md`; `<autoflow-root>/docs/criterion-review.md`; `<autoflow-root>/docs/git-workflow.md` > Git Clean Check; `<autoflow-root>/docs/git-workflow.md` > Post-Merge Cleanup; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/state-tracking.md`; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the auto-resolution attempt caps are rules of this kind. Each binds the path that carries it — the full cycle every one of them, the abbreviated path the ones its definition names (`<autoflow-root>/docs/abbreviated-path.md` > *The checks that bind it*).
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and, in the full cycle, by the gates. When the AI is not confident, or the choice is not its own to make, it asks the advisor, whose answer is recorded and applied; the operator is asked only when a call is blocked at the harness level (`<autoflow-root>/docs/role-contracts.md` > Advisor).
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a cycle leaves in the target's tree — are `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Development Lifecycle — AutoFlow

**An attempt goes on by one of two paths.** After its criterion review, an attempt — one run of an issue, keyed by its dev branch — goes on by the full cycle, which writes its state file at PREFLIGHT and which the rest of this section and every unit document describe, or by the abbreviated path — criterion review, work outside an AutoFlow cycle, review — which never writes a state file and is defined in `<autoflow-root>/docs/abbreviated-path.md`.

**PREFLIGHT cannot be skipped.** If its completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the block first and report.

**An attempt's criteria are settled before DIAGNOSE.** Each attempt's cycle begins with its own criterion review stage, against the target's code and policy; its `[criterion-ready]` ledger entry records the settled decisions, and PREFLIGHT reads only that entry for the current issue body (`<autoflow-root>/docs/criterion-review.md`).

### Flow Control

Each unit's rows are its unit document's `## Transitions` section, which the unit's body carries (the router table in *Unit Document Loading Contract* below); the rows that leave no single unit are *Any unit* below.

#### Any unit

| Transition | Condition |
|------|------|
| any phase (tool or referenced material → user) | a harness-level block: the work needs a tool, or a material an acceptance criterion or the issue body references, that neither this environment nor a procedure in the target's documents or scripts can provide — or needs, for a tool the environment has, what using it lacks (access, a purpose and permitted scope, a credential, a permission setting); the request names what is missing, never the tool's output → report situation-first, `active:false`, `phase:"awaiting-user"`. The answer is an `O` ledger entry with the authority `operator decision`; the cycle resumes where it paused, or at an ARCHITECT unit re-run when a verification-design row must change, consuming no re-entry budget (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ARCHITECT > *Tools*) |

**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total); GATE:HYPOTHESIS has no count cap — the recorded judgment that its PASS is not reachable is its escalation. HANDOFF internal retry exhausted → human. A harness-level block → human.
**Advisor at a decision point** (ADR-0025 D7): every Flow Control row that routes to the advisor — the rows above and each unit document's `## Transitions` rows — is a decision point — a fresh `autoflow-advisor` answers, its answer is recorded as an `A` ledger entry and applied, and the cycle continues without pausing. The operator stops the forward path only at a harness-level block — a permission denial, a tool, credential or material the environment does not provide, or what using a tool it has lacks (a review-infrastructure failure the reviewer re-run does not clear is one); PREFLIGHT's fail-closed readiness stop is an independent check, not a decision point. An operator override of a recorded decision is an `O` entry under `operator decision`. Procedure and independence: `<autoflow-root>/docs/role-contracts.md` > Advisor.
**Phase scripts** (ADR-0025 D8): a script AutoFlow ships for a phase reads and reports; it changes nothing in git, on GitHub or in the cycle's state — every such change is the orchestrator's own.

### Unit Document Loading Contract

**[MUST]** On entering a phase, act on the document of its unit below, which the session's command body carries after the core (*Context Injection*), **before** acting in that phase. The unit document is the source of truth for that unit's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — the body is the unit document of the installed version.

| Unit | Phases | Unit document | Exit |
|------|--------|------|------|
| U1 Preparation | PREFLIGHT, CRITERION-REVIEW | `<autoflow-root>/docs/units/preparation.md` | PREFLIGHT's readiness conditions |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | `<autoflow-root>/docs/units/analysis.md` | GATE:HYPOTHESIS |
| U3 Design | ARCHITECT, GATE:PLAN | `<autoflow-root>/docs/units/design.md` | GATE:PLAN |
| U4 Build and verify | BUILD, AUDIT | `<autoflow-root>/docs/units/build.md` | AUDIT |
| U5 Completion evaluation | GATE:QUALITY | `<autoflow-root>/docs/units/completion-evaluation.md` | GATE:QUALITY |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | `<autoflow-root>/docs/units/delivery.md` | HANDOFF: every pull request open, CI green or recorded as not run |
| U7 Review | REVIEW | `<autoflow-root>/docs/units/review.md` | REVIEW: the aggregated review below Medium, CI green or recorded as not run |

What each phase does, and what else a unit's body carries: the phase list and *Unit references* below, and *Context Injection*.

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

Seven functional units carry the phases (`ADR-0025` D1, `ADR-0033`). A unit is the unit of prescription — its goal, artifact contract, verification and loop cap — and each has one document (*Unit Document Loading Contract* above). The phase and gate names stay: they are the identifiers the state keys, the ledger headings, the spawn-policy keys and the hook messages carry.

```
U1 Preparation         PREFLIGHT       — prior-attempt resolution (cleanup after external merge/close), Git clean check, remote sync, the entry `cycle-status.sh` prints, the attempt's creation on a `new` entry (`autoflow-records new`), target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op), the attempt's criterion readiness (`<autoflow-root>/scripts/preflight/criterion-ready.sh`), the state file's creation — the orchestrator's own work, decided from the facts `<autoflow-root>/scripts/preflight/cycle-status.sh` reports
                       CRITERION-REVIEW — inside PREFLIGHT, after the entry and before the stop conditions, on an attempt with no state file: the attempt's criterion review — the session's own stage 1, then the tracer, analyzer and reconciler spawns — whose exit is the attempt's `[criterion-ready]` entry for the current issue body (`<autoflow-root>/docs/criterion-review.md`)
```

**Flow Control** — the transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in its **unit document**, not in this core file. This file retains what crosses a unit's boundary: the cross-unit invariants and authority rules, the router (the unit and phase list and the Flow Control table above, whose per-unit rows are each unit document's `## Transitions` section), the regression / escalation caps (above), the Execution Principles, and the state rules (below; the state file's schema and the hook gates are `<autoflow-root>/docs/state-tracking.md`). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

### Unit references

| Unit | Also on entry |
|------|------|
| U1 Preparation | facts: `<autoflow-root>/scripts/preflight/cycle-status.sh`; the criterion review stage: `<autoflow-root>/docs/criterion-review.md`; git procedures: `<autoflow-root>/docs/git-workflow.md` (Git Clean Check, Post-Merge Cleanup) |

## Cost Control

These rules apply to every cycle.

- **[MUST] Orchestrator context discipline**: two rows are fixed (Rule Scope, principle 1): (1) **the orchestrator never scores what a gate scores** — the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and an orchestrator read of those artifacts informs a spot-check, never a verdict; (2) **the orchestrator never receives a unit's body** — the DIAGNOSE, ARCHITECT and BUILD units return only their artifact paths and a one-line summary. What the orchestrator reads directly is its own judgment, recorded with its grounds in the report or ledger entry the phase already produces (Rule Scope, principle 2). A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why. The Reporting Format (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format) applies to every direct/ad-hoc `Agent` spawn, scripted-phase or not — the spawn writes its body to `<attempt-dir>/*` and returns only an anchor + one-line summary (e.g. the DIAGNOSE unit writes `<attempt-dir>/issue-N-analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the orchestrator's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `<attempt-dir>/*` body the user reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md`, fixes settled decisions. What an entry records, its identifier grammar, and the decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`) — are `<autoflow-root>/docs/decision-ledger.md`.

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled gate verdict is likewise not overturned by re-reading the issue body. Two exceptions: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries), and an operator's override of an advisor decision, whose ground is the operator's authority (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every role spawn's scope — it is host-owned, written only by the orchestrator and the advisor (what each appends: `<autoflow-root>/docs/decision-ledger.md` > Entries > *Writers*). **[MUST]** Only the advisor adds the authority `advisor decision` or an `A<n>` entry; only the main session adds `operator decision` or an `O<n>` entry; the advisor never adds an `O` / `F` / `E` entry; and a write never changes text already in the ledger — enforced by the gate hook (`<autoflow-root>/docs/state-tracking.md` > Hook gates).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers of one namespace that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- The gate hook runs `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` as a **non-gating advisory** over changed ledgers: `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error, and the hook warns — to the model as `additionalContext` on a call it admits — and never denies a tool call over a ledger defect. A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (a harness-level block such as a tool or referenced-material request, a cap reached, a cycle the advisor ended at DIAGNOSE or GATE:HYPOTHESIS) — and in every advisor request and advisor answer record (`<autoflow-root>/docs/role-contracts.md` > Advisor), the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format), which is anchor-first. The `<attempt-dir>/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.
- **Verify role-spawn claims before dispatch**: every role-spawn report's Evidence anchor (see `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim.
- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's design, BUILD's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What the full cycle never skips is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI (its result as it is: green, or, where the target's CI does not run for the pull request, that recorded on it — never read as green), the aggregated review and its verdict, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate. The abbreviated path's checks are its definition's (`<autoflow-root>/docs/abbreviated-path.md` > *The checks that bind it*).
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `<attempt-dir>/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop), and every role spawn's Bash runs foreground-only; the binding rule lives in `<autoflow-root>/docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — a foreground `sleep` loop polling for a result — is not used. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. One timer is admitted beside that wait, the **cache keep-alive wake**: a running task keeps its own prompt cache warm through its own requests, while the orchestrator sends none, so a wait longer than the prompt-cache TTL expires the orchestrator's cached context and its first turn after the notification re-writes all of it. While a tracked task runs, the orchestrator therefore may arm one backgrounded `sleep` shorter than that TTL (`run_in_background`; 50 minutes at the 1-hour TTL) and end its turn. The turn the timer wakes is not a poll: it reads no transcript or output file of the task — only a cheap anchor-check (a log's modification time, `git log -1`) — re-arms the timer and ends the turn, and the timer is stopped once the task's notification arrives. What the wake observes about the task's progress, and any decision drawn from it, is the orchestrator's judgment, recorded with its grounds in the report or ledger entry the phase already produces. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your report", naming no carrier: the harness picks the carrier by permission mode, and in auto mode a spawn's final plain text is not delivered. There is one delivery path, and it is the return value; what carries a spawn's report is `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document (`<autoflow-root>/docs/units/analysis.md` > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per `<autoflow-root>/docs/issue-proposal.md` and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.

## Spawn Model — Phase-by-Phase

AutoFlow role spawns and every other subagent spawn choose the model by phase work type rather than inheriting the host session model.

The per-phase assignment itself — every phase's `model`, its `effort`, and the work type that
justifies it — lives in exactly ONE machine-readable place and is **not** restated here:

**`.claude/autoflow/spawn-policy.json`**, read through `<autoflow-root>/scripts/spawn-policy/spawn-policy.sh`:

```
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model  <phase-key>   # the model to declare on the spawn
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh effort <phase-key>   # the effort, or the config's own inherit sentinel
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh check                # validate the config
```

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Enforced by the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy).

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior cycle: `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — every spawn uses a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, the criterion-review agents `autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `<autoflow-root>/agents/`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. `subagent_type` is the sole declaration channel. The hook owns the role→gate mapping (analysis — the criterion-review agents and `autoflow-unit-analysis` included — / evaluation / advisor / research pass; planning — `autoflow-unit-design`, the ARCHITECT unit → GATE:HYPOTHESIS; implementation — `autoflow-unit-build`, the BUILD unit → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class. A spawn declares **who it is**; it never declares which gate applies to it. See `<autoflow-root>/docs/gate-matching-standard.md` > P3. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `<attempt-dir>/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope are `<autoflow-root>/docs/role-contracts.md` > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are `<autoflow-root>/docs/role-contracts.md` > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

A spawn prompt names the cycle's inputs by path — the attempt's artifacts and the target's files — as its unit document's Unit spawn section says, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`; at ARCHITECT that is one `autoflow-unit-design` spawn.
- A spawn writes any body to `<attempt-dir>/*` and returns an anchor + one-line summary (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not an orchestrator channel — the orchestrator resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states is asked of the operator in conversation, with the request that the operator create the file or record the fact in it.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

### AI Orchestrator (host repo)
- Does not write code directly; coordinates role spawns.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly, as may the fix of a comment's divergence or disallowed content in a target's code (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*).

### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor

## AutoFlow State Tracking (Hook integration)

Every record of an attempt — one run of an issue, keyed by its dev branch — lives in the attempt's record directory `<attempt-dir>`, which `autoflow-records dir` prints for the checked-out dev branch: `<record-root>/<repo-key>/<stamp>-issue-<N>/`, under the record root outside every checkout's tree (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`). While the attempt runs, its state file is there; the hook computes pass/fail directly from `scores` to enforce gates.

The state file's naming, its schema and fields, the hook gates and the state at completion are `<autoflow-root>/docs/state-tracking.md`.

**`verdict` rule** (gate_hypothesis only; it carries the bug signal the hook reads — the form itself is the same for every issue; when each value is set follows the Flow Control table):

| Issue type | `verdict` value |
|------------|-----------------|
| Bug / incident | `"pending"`, then `"evaluated"` once the form is scored |
| Non-bug (feat, chore, docs, refactor, …) | `"skipped (non-bug issue)"` |

The hook's state-file validator admits exactly these values, an empty or absent `verdict`, and `"skipped (feat issue)"` — the value a non-bug cycle recorded before `"skipped (non-bug issue)"`, admitted so such a state file stays valid and never written by a new cycle. Any other value makes the state file malformed, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until it is repaired. If `verdict` is empty or one of the two `skipped` values, the hook does not gate the ARCHITECT spawn on the `gate_hypothesis` scores; the orchestrator still judges the PASS. Bug issues must be initialised as `"pending"`.

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: `<autoflow-root>/docs/git-workflow.md`

### PR Wait Rule

**[MUST]** Use the `active` flag as the single start signal, per checkout: begin a new cycle once every **other** attempt of this checkout reads `active:false`. One attempt runs at a time in a checkout — when another of its attempts reads `active:true`, finish or resolve that cycle first, then start the next; another checkout's attempts, of the same issue or any other, neither hold nor are held. The hook applies the same signal to this checkout's attempts only: it admits `git push` / `gh pr create` while every one of their state files reads `active:false`, and fails closed on two or more active. The readiness check and the requested issue's mode selection are `<autoflow-root>/docs/units/preparation.md` > *PR Wait Rule* and *Modes*.

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
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (identifying the chains, execution trust boundary, scoping, outcome vocabulary, evidence anchor): `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules > *Lint chain on the staged surface*.

## Reference Documents

- **AutoFlow phase guide**: `<autoflow-root>/docs/autoflow-guide.md`
- **Role contracts**: `<autoflow-root>/docs/role-contracts.md`
- **Evaluation system**: `<autoflow-root>/docs/evaluation-system.md`
- **Criterion review (an attempt's first stage, in U1)**: `<autoflow-root>/docs/criterion-review.md`
- **Git procedures**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/units/preparation.md -->

# U1 Preparation — PREFLIGHT and CRITERION-REVIEW

> Unit document for U1. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

PREFLIGHT is functional unit U1 Preparation
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1), and an attempt with no
state file passes its criterion review stage, CRITERION-REVIEW, inside it (issue #465,
[`ADR-0030`](<autoflow-root>/docs/records/adr/0030-criterion-review-is-a-stage-of-the-cycle.md)). U1 has no unit
agent: it is the orchestrator's own work, the criterion review's stage 1 included. This file states what it is asked for, the cautions and the result
owed; the order of the work and the commands are the orchestrator's
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2). A script only reads and reports (D8):
every change — to git, to GitHub, to the cycle's state — is made by the orchestrator itself.

- **Goal**: the requested issue's attempt starts, or continues, on a clean tree synced with the
  remote, with every earlier attempt of this checkout whose pull request is merged or closed
  cleared away — an attempt that starts with its criteria settled by its own criterion review
  stage.
- **Artifact contract**: the state file `<attempt-dir>/issue-{N}.json` and the attempt's dev branch
  checked out (*What is asked*), the plugin record and the local-checks record in the ledger
  (*What is asked*, *Stop conditions*), and, for an attempt's start, its criterion review record and
  its `[criterion-ready]` entry (*The criterion review stage*).
- **Verification**: PREFLIGHT has no gate. Its readiness conditions are deterministic — the facts
  `<autoflow-root>/scripts/preflight/cycle-status.sh` reports, its `entry:` line among them, and the
  *Stop conditions* — and DIAGNOSE does not begin until they hold. The criteria are judged by the
  criterion review stage alone ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)); PREFLIGHT's
  readiness check never judges an issue's content: on an attempt not yet started it reads only
  whether the attempt's own review recorded its `[criterion-ready]` entry for the current body.
- **Loop cap**: A condition that does not hold stops the cycle and is reported; PREFLIGHT
  runs again once it is resolved.
- **Result owed**: the state file, the dev branch and the ledger records above. A resume also
  owes its re-entry point, recorded with grounds in the ledger (*Resume*).

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| PREFLIGHT → CRITERION-REVIEW | `entry: new`, or the operator's request for a new attempt the session judges still to carry out (*Modes*) — the attempt created first (`autoflow-records new --issue N`) — or `entry: criterion-review`, on the attempt's dev branch with the tree clean and `origin` fetched → the attempt's criterion review stage runs in this session (`<autoflow-root>/docs/units/preparation.md` > *The criterion review stage*) |
| CRITERION-REVIEW → PREFLIGHT | the stage's exit condition: the attempt's `[criterion-ready]` entry for the current issue body (`criterion-ready.sh status` `READY`) → PREFLIGHT continues at the stop conditions on that attempt, now `entry: start`; an attempt whose pull request is open is `entry: abbreviated` instead, and the session reports and stops |
| PREFLIGHT → DIAGNOSE | earlier attempts resolved, Git clean, remote synced, the stop conditions passed (criterion readiness included for an attempt's start), and the state file written for `entry: start` (`mode: new-issue`) or `entry: review-response` (`<autoflow-root>/docs/units/preparation.md` > *What is asked*, *Modes*) |
| PREFLIGHT → resume | `entry: resume` — this checkout's attempt of the issue reads `active:true` → the re-entry point is the orchestrator's judgment over the facts `<autoflow-root>/scripts/preflight/cycle-status.sh --issue N` reports, recorded in the ledger; a gate with no recorded scores is run, never assumed passed (`<autoflow-root>/docs/units/preparation.md` > *Resume*) |
| PREFLIGHT → user | another issue's attempt mid-cycle in this checkout (`entry: hold`), a pause for a human decision (`entry: paused`), an attempt on the abbreviated path (`entry: abbreviated`), an entry `cycle-status.sh` reports as a stop (`stop …`), a dirty tree (resolved only with the user's approval), a Git state that cannot be synced, an undetermined or unusable record root, or a fail-closed stop condition — a failed target check, an unreadable reviewer configuration the operator does not proceed past, a target-declared local check that does not pass after its declared repair, a criterion review stage a harness-level block leaves without its `[criterion-ready]` entry → report and stop; DIAGNOSE does not begin (`<autoflow-root>/docs/units/preparation.md`) |

## What is asked

```
bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue {N}
```

prints the facts the work is decided from and changes nothing: the working tree, the default branch
against its remote-tracking ref, the AutoFlow this run uses (the root the script runs from, the
plugin name and version that root's `.claude-plugin/plugin.json` names, and, when the root is a git
work tree of its own, its `HEAD` and whether it is dirty), the record root and this checkout, any
state file left in the checkout's own `.autoflow/`, and — for every attempt of this repository not
marked completed — its owner (`this`, `other <path>` for a checkout still there, `gone <path>`), its
state (`active`, `phase`, `mode`, `cycle`, or `none` for an attempt with no state file — in its
criterion review stage, ready to start, or on the abbreviated path
([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md))), its dev branch with each side, and, for a state
file that is not active or no state file, its pull request. `cleanup:` lines name this checkout's attempts whose pull request is merged or closed; with
`--issue {N}`, `criterion:` lines give the readiness of each attempt of N this checkout could start,
a dev branch carrying N's number with no attempt record is reported `record=none`, and the last line
is the **entry** — which attempt the request enters, and how (*Modes*). Exit `3` means a fact could
not be read (a `gh` lookup, an unreadable state file, an unreadable `plugin.json`), exit `7` that the
record root is undetermined or unusable (its marker line says why — the operator fixes the file or
the directory, and PREFLIGHT runs again); the line says which. From those facts the orchestrator
brings about the following.

- **Earlier attempts are resolved.** An attempt of this checkout — its `checkout` file names this
  checkout — whose pull request is merged or closed (`cleanup:`) is cleared, whatever its issue:
  its local dev branch is deleted, and `<autoflow-root>/scripts/cleanup/cleanup-issue.sh
  <dev branch>` marks it completed ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).
  Its remote branch and its pull request are left as they are, and its records stay where they
  are. An attempt paused with no pull request keeps its files in place, and its pending decision is
  reported.
- **Another checkout's attempt is reported, not touched.** An attempt whose checkout is still there
  (`owner=other`) is that checkout's: it is not entered, changed, marked or cleared from here, and
  its branch is not deleted on either side. An attempt whose checkout is gone (`owner=gone` — a
  removed worktree or clone; its records stay under the record root, its dev branch in the clone
  and, once pushed, on the remote) is reported the same way until a checkout takes it over: the one
  that checks its dev branch out and runs `/autoflow:cycle <N>` or `/autoflow:cycle-u1 <N>` (`claim:` line; `autoflow-records
  claim`). From then on it is that checkout's, its cleanup included. A worktree deleted without
  `git worktree remove` keeps holding its branch in the clone until `git worktree prune`; until then
  git refuses that branch's checkout, and the takeover waits.
- **A dev branch with no attempt record is not an attempt.** A branch reported `record=none` — no
  record directory under the record root carries its name: another machine's attempt, a branch made
  by hand — is reported, and neither side of it is deleted (issue #433). It does not decide the
  entry, even checked out.
- **One attempt runs at a time in a checkout** (*PR Wait Rule*), and the request enters the attempt
  the `entry:` line names, in the mode it names (*Modes*).
- **The tree is clean and synced.** No uncommitted change or untracked file in the working area,
  and the branch the mode works on — the attempt's dev branch — is where the mode needs it: for a
  start, fast-forwarded to its base's latest commit (`git fetch --prune origin`, then
  `git merge --ff-only origin/<base>` on the dev branch, which has no commit of its own yet; `<base>`
  is what `autoflow-records base` prints), unless the attempt was made at a commit the operator named
  — `git config branch.<dev branch>.autoflow-start` prints it — and stays there; for
  a review-response, matching its remote branch ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Git
  Clean Check). This holds in a worktree whose default branch is checked out in another worktree
  and on any branch the checkout had: nothing here checks out or updates the local default branch.
  In a project with sub-repos, syncing the host also brings each submodule to the commit the host's
  pointer names; this is the orchestrator's work item, and no script checks it.
- **A new attempt is created, and an attempt with no state file passes its criterion review
  stage** (*The criterion review stage*), before the stop conditions.
- **The stop conditions pass** (*Stop conditions*): the target check, a readable reviewer
  configuration (or the operator's choice to proceed without those reviewers when the operator
  file is unreadable), the target-declared local checks, and — for an attempt's start — criterion
  readiness.
- **The plugin record is written.** On a start and on review-response entry, before the state
  file is written, the orchestrator appends the AutoFlow values `cycle-status.sh` reported to the
  attempt's ledger as a record entry, `<C>` being the cycle the state file will carry:

  ```
  ### preflight-plugin | cycle: <C>
  - plugin: <name> <version>
  - root: <the root path>
  - git: <HEAD> clean | <HEAD> dirty (<n> path(s)) | not a git work tree
  ```
- **An attempt's start gets its state**: on its dev branch — made with the attempt when the cycle
  created it (`autoflow-records new`), `dev-YYYY-MM-DD-HHMMSS-issue-N` — the state file from the Creation template with that name
  in `branch`, `mode: "new-issue"` and `phase: "in-progress"`
  ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > AutoFlow State Tracking). The name is the
  attempt's for its life: a review-response continues on it, and its record directory is named from
  it. A review-response gets *Review-response setup*.

Cautions:

- **A dirty tree is never resolved without the user.** What is stashed, committed or discarded is
  the user's to approve; PREFLIGHT does not reach DIAGNOSE on a dirty tree.
- **A branch that does not fast-forward, a fetch that fails, or a Git state that cannot be made
  clean is a hard stop**: report to the user. It is not worked around with a reset or a forced
  update.
- **Nothing on the remote is changed.** PREFLIGHT and the cleanup read pull-request state and fetch;
  they delete no remote branch, push nothing, and close, label or comment on no pull request.
- **The state file is created last.** A stop condition that fails, a hold or a pause leaves no
  state file behind; the attempt's dev branch and record directory, made when it was created,
  stay as they are — and so do the records of a criterion review stage left unfinished.
- **An attempt is cleared only on an observed merged or closed pull request.** Its pull request is
  looked up by its dev branch's name even when the branch is gone on both sides.

## PR Wait Rule

The readiness check that clears the requested attempt to start. Its source of truth is the state
files of this checkout's attempts, `<attempt-dir>/issue-{N}.json`; the start signal is
[`core.md`](<autoflow-root>/docs/core.md) > PR Wait Rule.

- **[MUST]** An `active:false` state file (`phase: awaiting-external-review`) is **cleared and
  handed off**: its PR belongs to external review, which merges on its own schedule. Readiness is
  tied to the `active` flag alone.
- Another issue's `active:true` attempt in this checkout holds the requested one (`entry: hold`):
  report and hold, and finish or resolve that cycle first. Another checkout's attempts — of the same
  issue, another issue or another repository — never hold it.

## Modes

The requested issue's entry follows from this checkout's attempts' records — the `entry:` line
`cycle-status.sh --issue {N}` prints; none of these is a judgment. An attempt is identified by its dev branch and belongs
to the checkout that started it, or that took it over. Evaluated in order:

| This checkout's records | Entry |
|---|---|
| a state file in the checkout's own `.autoflow/` | `stop in-tree-records` — moved to the record root first ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > *Record location*) |
| another issue's attempt reads `active:true` | `hold` (*PR Wait Rule*) |
| an attempt of N reads `active:true` | `resume` — the in-progress cycle continues (*Resume*); it is not restarted |
| the checked-out branch is an attempt of N whose checkout is still another one | `stop other-checkout` — reported, not entered (in one clone, git does not let the branch be checked out twice) |
| the checked-out branch is an attempt of N — taken over first (`claim:`) when its checkout is gone: | |
| — no state file, its pull request merged or closed | cleared (`cleanup:`), as any attempt is, and set aside: the *otherwise* rows below give the entry |
| — no state file, no valid entry (the review is not finished, or the body changed after it), a pull request open or none | `criterion-review` — the attempt's criterion review stage runs on that branch (*The criterion review stage*) |
| — no state file, its `[criterion-ready]` entry valid for the current body, an open pull request | `abbreviated` — the attempt is on the abbreviated path ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)): reported, not entered; a full cycle of N beside it is a new attempt (*A new attempt is the operator's request*) |
| — no state file, its `[criterion-ready]` entry valid for the current body, no pull request | `start` — the attempt's cycle begins (*What is asked*) |
| — `active:false`, `phase` other than `awaiting-user`, an open PR | `review-response` (*Review-response setup*) |
| — `active:false` at `phase: "awaiting-user"` (a PR open or not), or with no open PR | `paused`: the cycle waits on a human decision and is not cleared. The pending decision and its `<attempt-dir>/issue-{N}-*.md` context are reported. Re-entry is driven by the user's new decision — never an automatic mode, never a silent restart: when the user decides to continue, the orchestrator sets `active: true` and continues where the pause was taken |
| otherwise, exactly one attempt of N is ready to start, still in its criterion review stage, or has a state file and an open PR (an attempt cleared at this PREFLIGHT aside) | that attempt's `start`, `criterion-review` or `review-response` — its dev branch is checked out first |
| otherwise, two or more | `stop candidates` — reported; checking one's dev branch out names it |
| otherwise, attempts of N still here, none of those — paused, on the abbreviated path (`abbreviated`), or with a fact that could not be read (a `gh` lookup, an unreadable state file; exit `3`) | `none-to-enter` — each named with its kind; none is entered by the entry, and a paused one's re-entry is the user's decision |
| otherwise — no attempt of N in this checkout, or every one cleared | `new` — the cycle may create the attempt and run its criterion review stage (*The criterion review stage*) |

**A new attempt is the operator's request.** It is created only on the `new` entry or on the operator's explicit request
— `/autoflow:cycle <N> new`, `/autoflow:cycle-u1 <N> new` or `/autoflow:criterion-review <N> new`. With an attempt of N still in
this checkout — an open PR, a paused one, one whose criterion review is not finished — no new
attempt is made without that request.

The entry is a fact, and so is every line above it. Where the facts leave the way on open — the
cases below — the way is the session's judgment, recorded with its grounds in the ledger of the
attempt it enters or creates (an `O` entry under `orchestrator decision`), or in its report when it
stops (Rule Scope, principle 2 — [`core.md`](<autoflow-root>/docs/core.md)):

- **A `new` in the arguments.** Whether it is a request still to carry out, or one this conversation
  already carried out — an attempt it created — and how far that attempt has come, is the session's to judge from the attempts
  `cycle-status.sh` reports and from what the conversation holds. A request still to carry out creates
  the attempt whatever entry is printed beside it, under the conditions `autoflow-records new` applies.
- **A fact that could not be read** (exit `3`: `pr: lookup failed`, an unreadable state file, a
  `criterion:` line that could not be read): whether to run the script again, report and stop, or
  go on with the other facts.
- **A `claim:` line, a dirty tree, an other-checkout attempt**: whether to take the attempt over,
  ask the user about the tree (a dirty tree is never resolved without the user — *Cautions*), or
  report.

## The criterion review stage

CRITERION-REVIEW is the first stage of an attempt's cycle, inside PREFLIGHT: after the entry
`cycle-status.sh` prints and the conditions before it — no state file left in the tree, no other
attempt of this checkout active (*PR Wait Rule*), the record root determined and usable — and
before the stop conditions and the state file. It runs on the entries `new` and
`criterion-review`, and on the operator's request for a new attempt (*Modes*), in the session `/autoflow:cycle <N>` or `/autoflow:cycle-u1 <N>` started; no other command or session is
needed, and `/autoflow:criterion-review <N>` runs this stage alone, from the same entries, ending at
its exit — the entry of the abbreviated path as well ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)):
a `READY` attempt goes on by `/autoflow:cycle <N>` or on that path.

- **The attempt and its record directory come first.** On `new`, or on the request, the orchestrator creates the
  attempt before the stage writes anything: `autoflow-records new --issue {N}` — on a clean tree,
  with no active attempt in this checkout — fetches `origin`, makes the record directory under the
  record root with this checkout as its owner, and checks out a new dev branch
  `dev-<date>-<time>-issue-<N>` at its base's latest commit, local only and, in the full cycle, with
  no commit of its own until the state file is written. The base — the branch the attempt's pull request merges into —
  is the remote default branch, or the branch the operator names for the attempt
  (`autoflow-records new --issue {N} --base <branch>`); an operator who names a commit
  (`--commit <commit>`, with or without `--base`) has the dev branch made at that commit. The
  operator names them with the request (`/autoflow:cycle <N> new --base <branch>`, …). A named
  commit with commits its base does not have is reported (`not-in-base: <n>` — the pull request
  would carry them); whether to stop and report or go on with that stated is the orchestrator's
  judgment, recorded with its grounds (ADR-0034 D1). It refuses —
  and nothing is made — on a dirty tree, an active attempt of this checkout, a failed fetch, no
  remote-tracking ref of the base, a commit not in the checkout, or a record root that is undetermined or unusable (exit `7`); each is a stop reported to
  the user, as PREFLIGHT reports it. On `criterion-review`, the attempt named is checked out, and
  `git fetch --prune origin` runs before the stage reads the code; a failed fetch is the same hard stop,
  and a dirty tree is resolved with the user first (*Cautions*).
- **The stage is the attempt's criterion review.** What it reads and judges, its stages — stage 1
  in this session, then the `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and
  `autoflow-criterion-reconciler` spawns — its record, its authority and its report are
  [`criterion-review.md`](<autoflow-root>/docs/criterion-review.md). Every record of it is in the attempt's record
  directory `<attempt-dir>` (`autoflow-records dir`).
- **Exit.** The attempt's `[criterion-ready]` entry for the current issue body, which
  `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` reports `READY`; then
  PREFLIGHT continues at the stop conditions on that attempt. While a decision waits on a
  harness-level block, the entry is not written and the session reports it and stops.
- **Re-entry.** The stage writes no state file, so a session that ends in the middle of it
  re-enters it from `cycle-status.sh`'s `criterion-review` entry on the same attempt; what
  the stage already wrote is in `<attempt-dir>`, and how much of it the stage takes up again is its
  own judgment, recorded under the review record's `## Session decisions`.
- **One unit per session.** `/autoflow:cycle-u1 <N>` (`<N> new` for a new attempt)
  runs U1 — this stage included — from its entry (`new`, `criterion-review`,
  `start` or `review-response`) to PREFLIGHT → DIAGNOSE, and every stop above is reported the same
  way.
- **The stage does not hold its checkout.** No state file exists while it runs, so the PR Wait
  Rule's `active` signal does not see it: another issue's `new` in the same checkout switches the
  branch away — only on a clean tree, so no uncommitted work is lost, and the stage's records stay
  in its `<attempt-dir>`. The attempt left so is reported and re-entered later like any unfinished
  review (`criterion-review`). An attempt with no state file is not counted as active because an
  unfinished review left for good would otherwise hold the checkout with no state to clear.

## Review-response setup

For a cycle entered at PREFLIGHT in `review-response` mode. On the attempt's dev branch:

- **[MUST] The previous cycle's artifacts are preserved** before any phase of the new cycle writes:
  every `<attempt-dir>/issue-{N}-<artifact>.md` is renamed to `<attempt-dir>/issue-{N}-c{C}-<artifact>.md`,
  `C` being the previous cycle number. What spans cycles keeps its name — the ledger, the criterion
  review record, the advisor records its entries point at (`issue-{N}-advisor-*.md`), the state
  file and the cycle-layer store `issue-{N}-local/`.
- **The state file moves to the next cycle**: `mode: "review-response"`, `active: true`,
  `phase: "in-progress"`, `cycle` incremented, and `phases` reset to the Creation template (the
  `verdict` rule kept).
- The local checks run with the incremented cycle number, and the state is set only once they pass.
- The DIAGNOSE unit's prompt names the review comment or thread that triggered the cycle.

How much of the previous cycle's artifacts the new cycle reuses is the analysis and design units'
own ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > Unit spawn; [U3 Design](<autoflow-root>/docs/units/design.md) > *Re-entry*). The cycle-layer
store's retained set is reviewed, re-authored and re-executed at the new cycle's BUILD; a check that
did not execute is `not-run`, never `passed`.

## Resume

This checkout's attempt of the requested issue reads `active:true`: a cycle a session ended in the
middle of. `cycle-status.sh --issue {N}` reports what the resume is judged from — each gate's
recorded scores, `verdict` and `remedy_class`, the artifacts on disk, the ledger's last
`[gate-autofix]`, `[rebuttal]`, `[review-autofix]` and `[reentry-decision]` entries, and the last
local-checks record of the current cycle. It names no phase: **where the cycle re-enters is the
orchestrator's judgment over those facts**, recorded with its grounds in the ledger. Cautions:

- The cycle is continued, not restarted: a resume does not increment `cycle` and does not reset
  `phases`. It does not require a clean tree either — what the interrupted session left
  uncommitted belongs to the phase that re-enters.
- The attempt's dev branch — the one its record directory is named from and its state file's
  `branch` names — is checked out before any phase re-enters. A missing branch, or facts that do
  not fit together, are reported to the user.
- A last local-checks record of the current cycle that is not `none declared` or `PASS …
  worktree=clean` means the local checks run now, before any phase re-enters (*Stop conditions*).
- A gate with no recorded scores has not passed. It is run, never assumed — the cycle re-enters no
  later than the phase whose artifact that gate scores.
- A gate whose record carries `remedy_class` has an open re-entry: a passed gate's open
  recommendation attempt ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*), which resumes
  on the route its last `[gate-autofix]` entry names and not past the gate; or a failed gate's FAIL
  route.
- A `[rebuttal]` entry with no verdict entry of that gate after it resumes at that gate's re-score
  ([U7 Review](<autoflow-root>/docs/units/review.md) > *Whether a finding holds*).
- An artifact the next phase consumes that is absent is not written by the orchestrator: the phase
  that produces it runs again.

## Stop conditions

Each is a fail-closed hard stop, run by the orchestrator before the state file is created: DIAGNOSE does not begin until every one that applies passes — the first three in every mode that runs them, *Criterion readiness* on an attempt's start only.

**Target check.** PREFLIGHT runs `bash <autoflow-root>/scripts/preflight/target-check.sh` from the target; a non-zero exit stops the cycle. It runs from the AutoFlow root the session loads — the agent definitions, the readout, the selector and the default spawn policy beside it — and reads the target's files as data, executing none of them. **D6** — when the target keeps its own `.claude/autoflow/spawn-policy.json`, which overrides the plugin's default: `<autoflow-root>/scripts/spawn-policy/spawn-policy.sh check` over it against the loaded agent definitions, and its row set against the default `<autoflow-root>/.claude/autoflow/spawn-policy.json` — a `phases` / `workflow_sites` row the default carries and the target's copy lacks, or a `phases` row whose `agent_type` differs, is named. Model values and `workflow_sites` effort are the target's own and are never findings; a target with no policy of its own passes, its readouts answered by the default. **D7** — on a target that opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`, resolved through `<autoflow-root>/scripts/test/suite-manifest.sh`): every executable spec under the target's `tests/**` declares the usable `# ci-subject:` header the selector requires (the selector's own `--check-headers` stage). A target that has not opted in passes without the selector being consulted, and a declaration file that is present but unreadable is a FAIL. Remedies: D6 → edit the target's policy — set each named row to the loaded definition's values and add each missing row from the default — or delete it to take the default; D7 → back-fill each named suite's header per [U4 Build and verify](<autoflow-root>/docs/units/build.md) > Header contract > *Adopting the contract over existing suites*, or repair the unreadable `.claude/autoflow.local.json`. The AutoFlow version is not a stop condition: a newer release reaches the operator through Claude Code's plugin update.

**Reviewer configuration.** PREFLIGHT runs `<autoflow-root>/scripts/preflight/check-review-backend.sh`, which resolves the reviewers REVIEW runs — from the operator's `~/.autoflow/config.json`, and the default reviewers when it names none ([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Config location*) — prints the `reviewers:`, `source:` and `user-config:` readout lines, and probes each reviewer's CLI presence-only (`command -v`; auth is not probed). Exit `1` — a configured reviewer's CLI absent — does not stop the cycle: REVIEW runs the other reviewers without it and names it on the aggregated comment. Exit `6` with the marker line `user-config: UNREADABLE <path> — <error>` — the operator file cannot be read as configured, so nothing in it applies — is put to the operator, situation-first, with the path and the error: proceed without those reviewers (the cycle continues and REVIEW runs on the reviews of the target's side alone), or stop (no state file is written; the operator fixes the file and PREFLIGHT runs again, reading it anew). On exit `0`, `1` and `6` — on `6` once the operator has answered — the orchestrator appends the result to the issue's ledger as a record entry, `<C>` being the cycle the state file will carry, each line copied from the readout:

```
### preflight-review-config | cycle: <C>
- reviewers: <names|none>
- source: user <path> | none
- user-config: absent [<path>] | ok <path> | UNREADABLE <path> — <error>
- exit: 0 | 1 | 6
- operator: proceed without those reviewers | stop
```

The `operator:` line is written only on exit `6`. See [`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Availability*.

**Target-declared local checks.** PREFLIGHT runs the target repository's **own** readiness procedure through `<autoflow-root>/scripts/preflight/local-checks.sh --ledger <attempt-dir>/issue-{N}-ledger.md --cycle <C>` — after prior-attempt resolution and before the state file is created; `<C>` is the cycle the state file will carry (`1` on a new issue, the incremented value on review-response entry). The target declares that procedure in the target-owned scaffold `.claude/autoflow.local.json` under `preflight.local_checks[]` — one entry per step, each `{ "name", "check", "repair"? }`, where `check` is the command run (exit 0 = ready) and the optional `repair` is run once on a failed `check`, followed by a re-check whose exit is the verdict. A target whose docs name a per-clone setup step (a commit-hook installer, a generated config, a toolchain probe) declares it here; the framework knows **no specific tool** — it runs what is declared and reads only the exit status. **Absent declaration ⇒ no-op**: the record is the single line `PREFLIGHT local checks: none declared`. A declared check that does not pass (after repair, when one is declared) is exit `1` and stops the cycle: run the declared repair, or fix the declaration, then run PREFLIGHT again. A declaration that cannot be read as declared (malformed JSON, wrong types, an entry without a string `check`) is exit `2` and also stops — never a silent no-op. A passing run additionally asserts `git status --porcelain` is empty afterwards: a dirty tree is exit `3` — not a failed check, but the clean-tree condition already broken — so it is resolved with the user's approval and PREFLIGHT is run again. The outcome is written **only** as a ledger record — a level-3 heading `### preflight-local-checks | cycle: <C>` with one `- result:` line whose verdict token is `none declared`, `PASS <name>=PASS[(repaired)] … worktree=clean`, `DIRTY <name>=PASS[(repaired)] … worktree=dirty(<n>)` or `FAIL <name>=FAIL[(…)] … worktree=n/a` (`PASS` is written only when the run passed and the tree is clean) — an identifier-free record entry; the state file is untouched, and the gate hook reads the ledger advisorily only. The commit-time lint-chain obligation (`submodule-common-rules.md` > *Lint chain on the staged surface*) applies on its own: a declared check that installs the lint chain does not replace running it.

**Criterion readiness** (an attempt's start only; issues #430, #466, #465). The criterion review stage's exit condition, read again here: before the state file is created, PREFLIGHT runs `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` on the attempt's dev branch (`--branch` names another), which reads one fact: whether **that attempt's** ledger carries its criterion review's `[criterion-ready]` entry — the record of its settled decisions — for the issue body as GitHub holds it now ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Confirmation*). Another attempt's entry — an earlier attempt of this checkout, or one of another checkout under the same record root — never makes it ready, and another attempt's state file or records under the record root are never a reason for `NOT READY`. It does not judge the review's content, the criteria, or whether the review was thorough — those are the review's: the session's judgment, the advisor's answers and any operator override. Exit `0` (`READY`) passes. Exit `1` (`NOT READY` — no entry, a malformed one, a missing review record, a body edited after the entry, or an attempt that has already started) and exit `3` (the issue body could not be read) leave no state file behind: on exit `1` the attempt's criterion review stage runs again on its dev branch (`entry: criterion-review`) — for a body edited after the entry, the stage's judgment on the edit and a new entry in that attempt's ledger ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Confirmation*), which the session records once the decisions are settled; neither is an operator confirmation. Exit `3` stops the cycle and is reported situation-first; PREFLIGHT runs again once the body can be read. A `review-response` entry, a resume and a paused cycle do not run this check: their criteria were fixed when the attempt began, and a change to them inside a cycle is an `[ac-decision]` ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)). An issue filed before this condition existed is reviewed on its turn, with no exemption by filing date ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Issues filed before this procedure*).

<!-- From <autoflow-root>/docs/criterion-review.md -->

# Criterion Review — The First Stage of an Attempt's Cycle

An issue's acceptance criteria are reviewed against the target's code and policy in the **first
stage of the cycle**, CRITERION-REVIEW, before DIAGNOSE takes them, by each attempt for itself: an
attempt — one run of the issue, in one checkout — begins with its own criterion review and stays
independent of every other attempt from that review to its pull request. The session settles the
criteria under the policy the operator set (*Authority* below) and records the settled decisions
in a `[criterion-ready]` entry in the attempt's ledger — the stage's exit condition; PREFLIGHT
writes that attempt's state file only on that record
([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*, Stop conditions >
*Criterion readiness*). This is the
Definition of Ready of backlog refinement: a criterion that presumes a fact that does not hold, that
conflicts with a policy already in force, or that leaves a term undefined is found while it is
still cheap to change — before a unit re-run, a gate re-score and an advisor spawn each find it one
at a time inside the cycle.

The review does not replace the in-cycle path for a criterion defect: DIAGNOSE still takes the
criteria as written, and from ARCHITECT on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## When and by whom

- **When.** As the first stage of each attempt's cycle, inside PREFLIGHT before the attempt's state
  file — `/autoflow:cycle <N>`, or the U1 session `/autoflow:cycle-u1 <N>`, enters it on the entries `new` and `criterion-review` — and again, on
  that attempt's dev branch, after any edit to the issue body before the state file, since the
  `[criterion-ready]` entry is bound to the body it records (*Confirmation* below). Filing an issue
  ([`issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md)) does not make it ready. Run alone
  (`/autoflow:criterion-review <N>`), the stage is also the entry of the abbreviated path
  ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)): a `READY` attempt goes on by `/autoflow:cycle <N>`
  or on that path, and an attempt on that path, which never has a state file, changes a criterion by
  this review run again on its dev branch.
- **The cycle makes the attempt before the stage.** On `criterion-review` the stage reviews the
  attempt that entry names — this checkout's attempt of N with no state file: a re-review after a
  body edit, a review left unfinished — and adds its new entry to that attempt's ledger. On `new`
  the cycle creates a new attempt first, before the stage writes anything:
  `autoflow-records new --issue N` — on a clean tree, with no active attempt in this checkout — fetches
  `origin`, makes the attempt's record directory under the record root with this checkout as its
  owner, and checks out a new dev branch `dev-<date>-<time>-issue-<N>` at the latest commit of the
  attempt's base — the remote default branch, or the branch the operator names (`--base`) — or at
  the commit the operator names (`--commit`), local only and, in the full cycle, with no commit of its own until the
  attempt's state file is written. The attempt's key is that branch's name, and every record of the review — the review
  record, the stage 2 and in-depth files, the advisor records, the ledger with its
  `[criterion-ready]` entry — is in that directory, as the cycle's later records are. While an
  attempt of N with an open pull request, a paused one, or one whose review is unfinished is still
  in this checkout, the entry is that attempt's, and a new attempt is made only on the operator's
  explicit request (`/autoflow:cycle <N> new` or `/autoflow:cycle-u1 <N> new`; [U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *Modes*).
  An attempt that already has a state file takes no `[criterion-ready]` entry: a criterion change
  inside its cycle is an `[ac-decision]`. An attempt begun and then left is reported by PREFLIGHT
  like any other until the operator runs it or leaves it (its branch and records stay, as a paused
  attempt's do).
- **Reviewer.** The session that runs the stage: the `/autoflow:cycle <N>` session — or the U1
  session, `/autoflow:cycle-u1 <N>` — or a `/autoflow:criterion-review <N>` session, which runs this stage
  alone and ends at its exit; no other attempt of its checkout is active. The review is that
  session's own work, and the stage writes no state file. What it reads and how — which code, documents and materials, the order, how far it
  follows a cause or an effect, which tool checks a fact — is its own, recorded under the record's
  `## Inputs` with what it read and why, and what it left out and why (Rule Scope, principle 2 —
  [`core.md`](<autoflow-root>/docs/core.md)). The session carries stage 1 itself, the screening included; stage 2,
  the in-depth analysis and the reconciliation run in fresh contexts it spawns —
  `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and `autoflow-criterion-reconciler`
  (*Stages of the review*, *Cause reach and rule conflict (stage 2)* and *In-depth analysis and
  reconciliation* below).
- **Reference model and effort.** The review session runs on Opus 5.5 (`claude-opus-5-5`) at effort
  `high`; another model or effort may be used. The setting for the session lives here because the
  review is the session's own work, not an `Agent` spawn. Its spawns take theirs from
  `.claude/autoflow/spawn-policy.json` like every other spawn ([`core.md`](<autoflow-root>/docs/core.md) > Spawn
  Model): the model each declares is read with `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model
  criterion-trace`, `… model criterion-in-depth` or `… model criterion-reconciliation`, and the
  effort is the one its agent
  definition carries. The record's `## Inputs` names the model and effort the session and each
  spawn ran on.
- **What the reviewer never does.** It never edits the issue body or a criterion except to apply
  the settled decisions, never writes the `[criterion-ready]` entry while a decision is unsettled,
  and never asks the operator to confirm, approve or re-check a settled decision or waits on the
  operator for one (*Authority*, *Report to the operator* below).

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the commit the
  attempt's dev branch starts from unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`core.md`](<autoflow-root>/docs/core.md) > Project Information), and the documents of the
  sub-repos the issue reaches.

## Purpose and scope

The review's **purpose** is to find, before a cycle commits to the criteria, a criterion that would
lead the work wrong or short of done: one that presumes a fact that does not hold, conflicts with a
policy in force, leaves out part of where the cause reaches or of the behavior the issue reports,
stops at a direct cause where a root cause produces the defect, leaves a term undefined, or cannot
be shown met. Its **object** is the issue's acceptance criteria together with the behavior they
require, wherever in the code the reported cause and the required behavior reach — not only the
code a criterion names. The **quality characteristics** it evaluates are, in stage 1, the review
items below: fit with the code and policy, coverage of the reported behavior, depth of cause,
consistency, clarity, size, testability, and verified premises — and, in the screening, whether
each criterion holds in every case it applies to, judged on the code that decides the behavior;
and, in stage 2, the reach of each confirmed cause beyond the points the issue reports and the
agreement of each required behavior with the rules and behaviors the code already has.

Which code, documents and materials the review reads to judge them, and how far it reads, is the
reviewer's own (*When and by whom* > *Reviewer*); the record's `## Inputs` states that scope.

**What the review leaves to the cycle.** The review judges the criteria against the code and policy
as they stand; it does not set how the change will be made. What shows only once an approach
exists — the change's effect on other functions, the reuse of existing code, where a
responsibility is placed, an approach that meets a rule in force — is the cycle's: the design is
ARCHITECT's ([U3 Design](<autoflow-root>/docs/units/design.md)), and a change's side effects are derived at BUILD, not
predicted at design ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Types — Plan
evaluation (GATE:PLAN): "affected files and side effects are derived at BUILD by the build unit,
not predicted and scored here"). A criterion defect found there takes the in-cycle path
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be
wrong*). A choice of how to make the change is neither asked here nor written into a criterion;
what a criterion keeps is the behavior a user, a caller or an operator observes.

## Stages of the review

**Stage 1** checks the criteria on the review items and screens the cases each criterion applies
to, selecting the ones for in-depth analysis. **Stage 2** starts from what stage 1 confirmed — each
cause the code shows and the behavior each criterion requires — and asks how far they reach,
assuming no fix (*Cause reach and rule conflict (stage 2)* below). The **in-depth analysis**
examines the selected cases, criterion by criterion, and the **reconciliation** settles where a
stage 2 finding or an in-depth verdict differs from the record. Stage 2, the in-depth analysis and
the reconciliation each run in a fresh context.

The screening is wide — every case a criterion applies to, criterion by criterion; stage 2 crosses
the criteria — a cause one criterion's cases show may operate where another criterion, or none,
applies; the in-depth analysis is deep — the code that decides each selected case. A judgment made
early in a session is carried through the rest of it: a later sign against it in the same session —
or in a session handed its record — does not reliably overturn it. A single pass also leaves out
cases the issue does not report, and rests a verdict that a behavior already exists on the point
where it shows rather than on the code that decides it (issue #442). Stage 2 therefore runs apart
from the session that wrote stage 1, so the places that session looked do not bound where stage 2
looks; it is handed the record as its starting point, and asks a question the record did not. The
in-depth analysis receives the cases and their code locations but no earlier verdict or grounds.
Stage 2 may start once stage 1's record is written, and a criterion's in-depth analysis once the
screening has selected its cases; the two may run alongside each other. The reconciliation runs
after stage 2 and every in-depth analysis, since it applies both to the record.

## Review items (stage 1)

Each criterion is checked on the items below — *Actual and expected behavior* and *Size and
separation* once for the issue as a whole; an item that does not apply to a criterion says so.
Each finding carries its grounds: a commit SHA with `path:line` for a fact of the code, or the
document, its section heading and a quoted sentence for a provision of a policy document.

| Item | The question |
|---|---|
| Code and policy fit | Does the code behave as the criterion presumes, and does the criterion agree with the policies in force (an ADR, a rule document)? A criterion that presumes a behavior the code does not have, or one that a standing policy contradicts, is a finding. |
| Cause | Where the issue reports a defect, does the criterion address only the direct cause — the point where the failure shows — or also the root cause that produces it? A criterion narrower than the cause the code shows is a finding, recorded with which of the two it covers. Establishing the cause is DIAGNOSE's work inside the cycle ([U2 Analysis](<autoflow-root>/docs/units/analysis.md)); the review judges what the criterion covers against the cause the code shows. |
| Actual and expected behavior | Set side by side, does the state the criteria describe as done cover the behavior the issue reports as it actually occurs? A criterion set that covers only part of the actual behavior is a finding, recorded with the part left uncovered. |
| Contradiction | Can every criterion hold at once? Two criteria that cannot both be met, or one that undoes another, is a finding. |
| Terms and scope | Is every term a test would turn on defined — a threshold ("exceeds"), a surface ("the conversation screen"), a set ("every page")? An undefined term, or a scope with no stated bound, is a finding. |
| Size and separation | Is the issue one piece of work a single cycle can carry to done, or does it bundle areas that are each complete on their own — separate surfaces, separate causes, criteria that share no code or test? Several independently completable areas in one issue is a finding, recorded with the areas and a proposed split (`split`). |
| Testability | Can the criterion be shown met or unmet by an observation, and does the environment provide what that observation needs? A criterion no observation can settle is a finding. |
| Estimates verified | Is each estimate the body states as fact — a cause, a reproduction, an affected path — confirmed by the code or an observation? An estimate left unconfirmed is a finding, recorded as unconfirmed rather than as wrong. |

## Screening (stage 1)

After the review items, stage 1 screens the cases each criterion applies to:

- **Cases.** For each criterion, every case it applies to: the cases the issue reports, and every
  case in which the object or the state the criterion's words name varies — another surface the
  same cause operates on, or a path where a rule already in the code could prevent the required
  behavior.
- **Locations.** For each case, where the required behavior shows, and the code that decides
  whether and how it occurs — each as `path:line` at the commit read.
- **Verdicts.** For each criterion and case: `finding`, `holds` or `unconfirmed`, with its grounds
  and how far they reach — `shows` (the point where the behavior shows) or `decides` (the code that
  decides it and the condition applied there).
- **In-depth targets.** Every `finding`, and every `holds` or `unconfirmed` whose grounds do not
  reach `decides`. A criterion with no target is recorded as such, and has no in-depth analysis.

## Cause reach and rule conflict (stage 2)

Once stage 1's record is written, one `autoflow-criterion-tracer` spawn — a fresh context that
carries none of the session's conversation — receives the issue body and the stage 1 record.
Starting from each cause the record confirms in the code and the behavior each criterion requires,
it judges two questions:

| Question | What it judges |
|---|---|
| Cause reach | Does a confirmed cause operate beyond the points the issue reports — the same defect showing at another point, surface or element the cause reaches? A point where it does that no criterion covers is a finding. |
| Rule conflict | Does the behavior a criterion requires agree with the rules and behaviors the code already has, in every case the criterion applies to? A rule or behavior in force that keeps the required behavior from holding is a finding, recorded with the rule and the case. |

How the change will be made is not yet set, and stage 2 assumes no fix: an effect that would follow
only from a particular approach is outside it (*Purpose and scope* > *What the review leaves to the
cycle*). Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it
(`new`), and carries its grounds as the review items' findings do. It writes
`<attempt-dir>/issue-{N}-criterion-review-stage-2.md` and returns that path and a
one-line summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: an `autoflow-criterion-analyzer` spawn the review session makes, which carries none of
the session's conversation. The session hands it one target file,
`<attempt-dir>/issue-{N}-criterion-review-target-<criterion>.md`, holding only the
issue body, the criterion's text, the target cases, each case's code locations (`path:line`) and
the commit they were read at — no verdict, grounds or conclusion. The verdict rests on the code
that decides whether and how the required behavior occurs and the condition applied there, never
on the point where it shows alone. Where the behavior occurs only under a condition, the analysis
checks whether a situation that does not meet the condition actually arises — from which input,
state or usage flow; where one does, the behavior does not hold in that situation. It writes
`<attempt-dir>/issue-{N}-criterion-review-in-depth-<criterion>.md` — per case the
verdict, the deciding code and condition, and the grounds — and returns that path and a one-line
summary.

**Reconciliation.** After stage 2 and every in-depth analysis, one `autoflow-criterion-reconciler`
spawn — again a fresh context — receives the review record, the stage 2 file and the in-depth
files. Where a stage 2 finding or an in-depth verdict differs from the record, it confirms in the
code which one holds and settles it. A criterion that does not hold in a case it applies to is a
finding for that case, recorded with the rule or condition that prevents it — never summarized as
holding conditionally. It updates `## Findings`, `## Screening`, `## Proposed changes` and
`## Open questions` to match, writes `## Cause reach and rule conflict` and `## Reconciliation`,
and returns the record's path and a one-line summary.

**What the procedure fixes.** The artifacts — the screening, the stage 2 findings, the in-depth
verdicts and the reconciliation record — and the independence of the fresh contexts: stage 2
receives the issue body and the stage 1 record and none of the session's conversation, and the
in-depth context receives the target file and nothing of the session's verdicts or grounds. Each context's agent definition carries its part of this document ([`core.md`](<autoflow-root>/docs/core.md) >
Context Injection); what else it reads, in what order and with which tool, is its own (Rule Scope,
principle 2 — [`core.md`](<autoflow-root>/docs/core.md)). Each spawn
declares its role by its `subagent_type` and the model its policy row names
([`core.md`](<autoflow-root>/docs/core.md) > Spawn Model), at most five are in flight at once
([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Concurrent spawns*), and its prompt states the
delivery as "return … as your report".

## Review record

`<attempt-dir>/issue-{N}-criterion-review.md`, written by the reviewer in the
attempt's record directory (`autoflow-records dir` on its dev branch). Every section is present; a
section with nothing to record says `none`.

| Section | Holds |
|---|---|
| `## Inputs` | the issue body sha256 reviewed; the scope the reviewer set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort the session and each stage 2, in-depth analysis and reconciliation spawn ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Screening` | stage 1 — per criterion, each case it applies to: where the required behavior shows and the code that decides it (`path:line`), the verdict (`finding` / `holds` / `unconfirmed`), the reach of its grounds (`shows` / `decides`), and whether it is an in-depth target; a criterion with no target says so |
| `## Cause reach and rule conflict` | stage 2 — each finding, by question (cause reach / rule conflict), marked `stage 1` or `new`, with its grounds, as the reconciliation settled it — or `none` |
| `## Reconciliation` | per stage 2 finding and per in-depth case: its verdict, how the reconciliation took it — `applied`, `rejected` or `unresolved` — and the grounds, with the file it came from |
| `## Proposed changes` | per finding that calls for one, from either stage or the reconciliation: the criterion, the disposition (`excluded` / `revised` / `split` / `added`), the proposed text, the grounds and where the finding came from (`stage 1`, `stage 2` or `in-depth`) — or `none` |
| `## Open questions` | each point the review could not settle itself (what a term is meant to cover, which of two readings the issue intends) and put to the advisor (*Authority* below): the question, stated as the behavior it concerns, why the code and policy do not settle it, each option with what it changes in the criteria, and the advisor's answer with its ledger entry — or `none`. How the change will be made is never a question here (*Purpose and scope* > *What the review leaves to the cycle*) |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |
| `## Operator decisions` | each decision the operator gave when they chose to — an override of an advisor answer (with its `O` override entry) or of a disposition, or an instruction (a re-run and its scope, a text) — with what it changed; or `none`. It is not an item-by-item operator verdict on the dispositions and advisor answers, and the `[criterion-ready]` entry does not wait on it (*Authority* below) |
| `## Session decisions` | the session's own judgments after the review, apart from the operator's decisions: each detail an operator decision leaves open, with its grounds; whether the review was run again and over what scope when the body the entry records differs from the one `## Inputs` names, with its grounds (*Confirmation* below); and the issue edit that applied the decisions, with the edited body's sha256 — or `none` |

The record is situation-first where the operator reads it — to follow what was decided and to
override any of it ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Human-decision presentation*):
what each finding means for the issue's behavior comes before its anchors.

## Authority

The review follows the same authority over acceptance-criterion content as the cycle, under the
policy the operator set for it: the review session judges, the advisor decides a point the session
cannot settle or is not confident of, and the operator overrides when they choose
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principles 1 and 3). The reviewer judges
each finding and records its disposition with its grounds — a proposed change to the criterion, or
the criterion kept as written; a point the code or a policy settles, or that it can reasonably
choose, it settles and records. A point it cannot settle, or is not confident of, is a decision point: the review session
puts it to a fresh advisor by the advisor's procedure, taking the orchestrator's part, with
`cycle 0` and the phase `CRITERION-REVIEW` ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor);
an answer that decides a criterion's content is an `[ac-decision]` entry
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), and the record
carries it under `## Open questions`. The advisor's answer is itself the decision: it is applied
as recorded and does not wait on the operator's review.

The operator overrides an advisor answer or a disposition, or gives an instruction, when they
choose; it is recorded under `## Operator decisions`, an override of an advisor answer also as any
override is ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor decisions and operator
overrides*). A detail an operator decision does not itself settle — one that does not change the
decision — is the session's to judge: the session records it with its grounds under
`## Session decisions`, as its own judgment apart from the operator's decision. Such a detail is
not an item for an operator verdict and is not put back to the operator; a detail the session
cannot settle, or is not confident of, goes to the advisor first.

Once every decision is settled — each disposition, each advisor answer and each operator decision
given — the session edits the issue body to match and records the `[criterion-ready]` entry
(*Confirmation* below), without waiting on an operator response or confirmation. The condition for
the entry is that the decisions are settled, not an operator verdict on each of them. The operator
is asked only for a harness-level block ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*). The criteria a cycle starts from are therefore the
issue body as those decisions left it, and the review record is the evidence they were made on.

## Confirmation

The confirmation — the `[criterion-ready]` entry — is the record of the decisions made under the
policy the operator set (*Authority* above). The review session writes it once every decision is
settled, as a decision-ledger entry in the attempt's ledger
`<attempt-dir>/issue-{N}-ledger.md` — an `O<n>` entry under the authority
`operator decision`, which the gate hook admits from the main session only
([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > Hook gates; grammar: [`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
Decision-point entries > *Criterion-readiness confirmations*):

```markdown
## O<n> — criteria settled for a cycle (cycle 0, CRITERION-REVIEW) [criterion-ready]
- Decision: the acceptance criteria of #N, as the issue body now states them, are settled for a cycle
- Record: issue-<N>-criterion-review.md
- Issue body sha256: <criterion-ready.sh hash --issue N, run after the last edit>
- Grounds: the decisions recorded — the dispositions, the advisor answers (their A entries), any operator decision, the session decisions — and, when the body differs from the one ## Inputs names, the re-run judgment under ## Session decisions
- Authority: operator decision
```

The identifier comes from `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> O`, called
immediately before the append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). `cycle 0` marks an
entry written before the attempt's state file — in its criterion review stage, ahead of the cycle
number the state file starts at. `- Record:` names a file in the attempt's record
directory, by its name alone: a path to another attempt's record is not read.

**The confirmation is bound to the attempt and to the body.** `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue N`
reads the last `[criterion-ready]` entry in the ledger of the attempt on the checked-out dev branch
(`--branch` names another) — never another attempt's — and reports `READY` only when the attempt
has no state file yet, the entry is an `O` entry under `operator decision`, its record exists, and
its `- Issue body sha256:` equals the sha256 of the issue body read from GitHub now. Any edit to the
body after the entry leaves the attempt not ready until its own review runs again and a new entry
in its ledger records the edited body — another attempt's entry, of this checkout or another, never
stands in for it — written as the first one is: once the decisions are
settled — an operator override included — with no operator confirmation asked. When the body an
entry records differs from the body the record read (the sha256 under `## Inputs`) — an edit after
an entry, or a body edited before the first entry to apply the decisions — whether the review is run
again, and over what (in whole, the changed criteria only, or not at all), is the session's
judgment: it records the judgment with its grounds under `## Session decisions`, and the new entry's
grounds point to it. The session does not ask the operator for it. An operator instruction on the
re-run or its scope is the decision; a session that cannot settle it, or is not confident of it,
asks the advisor.

## Report to the operator

The review session's report to the operator is situation-first ([`core.md`](<autoflow-root>/docs/core.md) >
Execution Principles > *Human-decision presentation*) and tells what the session decided as
recorded — "recorded", not a request: the dispositions; each advisor answer with its `A` entry; each operator
decision applied; the session decisions — the details within an operator decision and the re-run
judgment; and the edited body's sha256 with the `[criterion-ready]` entry. The only thing it asks
the operator is a harness-level block ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*), and it asks for no other confirmation, approval or
review: an override is the operator's to give when they choose, not something the report requests.
`## Unchecked` is reported as fact and is put to the operator only where it is a harness-level
block. While a harness-level block leaves a decision unsettled, the entry is not written and the
report says which decision waits on it. A report after an operator override or instruction takes
the same form.

## What reads it

- **PREFLIGHT** — the stage's exit, read again on an attempt's start only, as a fail-closed
  condition before the state file is created: it reads the fact the script reports for that attempt
  and never judges the review's content ([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > Stop conditions >
  *Criterion readiness*). A `review-response`, a resume or a paused cycle does not run it.
- **DIAGNOSE** — the attempt's review record is one of the U2 unit's inputs in a `new-issue` cycle
  ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > *Criterion review record*).
- **The abbreviated path** — its start: an attempt goes on outside a cycle on its
  `[criterion-ready]` entry for the current body, and `cycle-status.sh` reports it
  `criterion-review` while the entry is not valid ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)).

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue filed without a
`[criterion-ready]` entry is reviewed on its turn, when an attempt of it is next begun — its cycle's
criterion review stage — and the review records the entry once its decisions are settled. An issue that already has a
state file — a cycle active, paused, or waiting on external review — is not affected, because those
modes do not run the check. An issue taken up again after an earlier attempt is reviewed again by
the new attempt, whatever the earlier one left: every attempt begins with its own review (*When and
by whom* > *The cycle makes the attempt before the stage*). A `[criterion-ready]` entry a target recorded inside its
tree before the record root (`.autoflow/<repo-key>-issue-<N>/`) belongs to no attempt and is not
read: a new attempt's own criterion review stage records its own.

<!-- From <autoflow-root>/docs/git-workflow.md > Git Clean Check -->

## Git Clean Check

The conditions PREFLIGHT starts from ([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*).
`<autoflow-root>/scripts/preflight/cycle-status.sh` reports the working tree and the default branch against its
remote-tracking ref; bringing them to this state is the orchestrator's.

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch --prune origin
# An attempt's start: its dev branch dev-<date>-<time>-issue-<N>, made at its base's latest commit
# when the cycle created the attempt (autoflow-records new) and with no commit of its own yet, is
# checked out and fast-forwarded to its base's latest commit — `autoflow-records base` prints the
# base; an attempt made at a named commit (git config branch.<dev branch>.autoflow-start) stays there
git switch dev-<date>-<time>-issue-<N>
git merge --ff-only origin/<base>
# A review-response: the dev branch matches its remote branch
git log HEAD..origin/dev-<date>-<time>-issue-<N> --oneline   # must be empty (or handled)
# In a project with sub-repos, each submodule is at the commit the host's pointer names
# after the host is synced (the orchestrator's work item; nothing checks it).
```

Nothing here checks out or updates the local base: a worktree whose base is checked out in
another worktree cannot (`git checkout <base>` and `git fetch origin <base>:<base>` both refuse
there), and a checkout on any other branch needs no more than `origin/<base>`.

If any check fails:

- Uncommitted changes → `git stash`, `git commit`, or discard with the user's
  approval (PREFLIGHT).
- Remote has new commits ahead of a review-response branch → `git pull --rebase` and re-run.
- A dev branch that does not fast-forward → stop and report; it is not reset.

If the working tree cannot be made clean, **stop** and report. PREFLIGHT does
not advance to DIAGNOSE on a dirty tree.

---

<!-- From <autoflow-root>/docs/git-workflow.md > Post-Merge Cleanup -->

## Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once an attempt's PR is observed merged
or closed (or by the live session if it observes the decision first). Apply it
to **every** resolved attempt of this checkout — one whose record directory's
`checkout` file names this checkout — that `cycle-status.sh` reports on a
`cleanup:` line; `<branch>` is its dev branch. An attempt of another checkout
still there (`owner=other`), an attempt whose checkout is gone (`owner=gone`)
until a checkout takes it over, and a dev branch with no attempt record
(`record=none`) are reported and not touched, locally or on the remote
([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*):

```bash
git switch --detach origin/<default> # only when <branch> is the checked-out branch
git branch -D <branch>               # the local dev branch
<autoflow-root>/scripts/cleanup/cleanup-issue.sh <branch>  # delete its issue-<N>-local/disposable/, then mark the attempt completed (accepts several branches)
```

**Nothing on the remote is changed.** The remote dev branch and the pull request are left as
they are — they are the record the attempt left for whoever reads the attempts together, and
deleting a remote branch is a push. Cleanup reads the pull request's state and changes no label,
comment or state on it. `git branch -D` is used because the PR's merge (a squash, a rebase) or its
closing leaves the branch unmerged into any local branch; the observed merged or closed PR is the
ground, and the remote branch keeps the commits.

**Delete the reserved path, mark the rest.** Cleanup deletes the attempt's reserved path
`<attempt-dir>/issue-{N}-local/disposable/` — the reproducible output its cycle assets wrote there
([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *How a test is
run is the target's practice*) — and then writes the mark `<attempt-dir>/completed`. Nothing is
moved or archived: the record directory is under the record root, outside every checkout's tree,
from the start, and everything outside the reserved path stays in it — the management files (state
JSON, decision ledger, criterion review, design docs, reports) **and the rest of its cycle-layer
store `issue-{N}-local/`**. A completed attempt is no longer listed as an attempt and is never
entered again. A deletion that fails leaves that attempt unmarked and exits non-zero; re-run
cleanup once the path is removable. A store that is itself a symbolic link keeps its target
untouched.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path and takes only an attempt's dev branch, checked against the shape
`dev-YYYY-MM-DD-HHMMSS-issue-<N>` (`dev/…` for an attempt made before issue #490) before it becomes the record directory's name
`<record-root>/<repo-key>/<YYYY-MM-DD-HHMMSS>-issue-<N>/` (repo-key = `<org>__<repo>` derived from
`origin` — `<autoflow-root>/scripts/lib/records.sh`), and it refuses an attempt whose `checkout` file
names another checkout. Its one deletion is that reserved path, `issue-<N>-local/disposable`, removed
without following a symbolic link. Allow-list the wrapper
by its absolute path — `Bash(<the AutoFlow root>/scripts/cleanup/cleanup-issue.sh:*)`, the root as `autoflow-root` prints it.

---

<!-- From <autoflow-root>/docs/decision-ledger.md -->

# Decision Ledger

The per-attempt decision ledger, `<attempt-dir>/issue-{N}-ledger.md`: what an entry records, how it is
identified, and the grammar of the entries a decision point produces — the advisor's first judgment
and the operator's override. The ledger's standing constraints —
append-only, no re-litigation without a new verified fact, host ownership, and identifier
allocation — are [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger.

## Entries

- Each entry records: the decision (one line), its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence), its **authority** (what settled it — `orchestrator decision`, `advisor decision`, `GATE:PLAN PASS (avg 8.2)`, `operator decision`), and the cycle/phase.
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the re-opening is **judged by the decision's original authority** — a gate verdict by a fresh Evaluation AI re-scoring that item, an ARCHITECT design decision — recorded in the feature design, not the ledger — by a U3 Design unit re-run naming its heading there (an ARCHITECT re-entry, consuming that counter, unless the design has not yet reached GATE:PLAN), an advisor decision by a fresh advisor, an operator decision by the operator — and when that authority cannot say with confidence that the error changes the decision, it asks the advisor ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3); (3) the correction records the reproducing command and its summary line in the grounds form above and names what it supersedes — for a ledger entry, in the superseding entry's grounds, by the superseded entry's identifier; for a feature-design decision, in the U3 re-run's delta item, as `supersedes <heading>` ([`units/design.md`](<autoflow-root>/docs/units/design.md) > *Re-entry*). A change of preference or a re-interpretation of the same material is not an error and stays barred.

**Writers**. The advisor appends its answer to a decision point under the authority `advisor decision`, and it alone writes that authority (*Advisor decisions and operator overrides* below); the ARCHITECT design unit and the BUILD unit append nothing — their decisions and records are their own artifacts ([`units/design.md`](<autoflow-root>/docs/units/design.md), [`units/build.md`](<autoflow-root>/docs/units/build.md) > Build report); the orchestrator appends each gate's verdict after the gate, each auto-resolution attempt and rebuttal round at a gate or at REVIEW, its own decision at a point it settles without the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Decision points and harness-level blocks*; an acceptance-criterion change: *Acceptance-criterion decisions* below), an operator override of an advisor decision when the operator gives one, and — before the issue's first cycle, by the criterion review session taking the orchestrator's part — the `[criterion-ready]` entry recording the review's settled decisions (*Criterion-readiness confirmations* below).

## Entry identifier

A settled-decision entry is headed `## <ID> — <title> (cycle <C>, <PHASE>)`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only. An auto-triggered review-response entry carries its REVIEW marker in the same grammar: `## O<n> — <title> (cycle <C>, REVIEW) [review-autofix]` — the marker stays at the end of the heading. The operator's decision to continue after an attempt-cap pause is an `O` entry under `operator decision` whose heading ends in `[reentry-decision]`; the attempt count restarts after it ([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Routing* > Attempt cap). An entry written before the attempt's state file — in its criterion review stage, the criterion-readiness confirmation included — carries `cycle 0`. Record entries (`preflight-plugin`, `preflight-local-checks`, `preflight-review-config` — [`units/preparation.md`](<autoflow-root>/docs/units/preparation.md)) are level-3 headings and carry no identifier.

| Writer | Namespace |
|---|---|
| Orchestrator | `O` |
| Advisor | `A` |
| Pre-protocol legacy entries (readable, never issued) | `E` |
| Legacy facilitator-delegate entries (readable, never issued) | `F` |

This table is the mapping's only documentary home; other documents cite it rather than restate it.

- **Allocation**. `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` issues every identifier, called immediately before that entry's own append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). It takes the next serial above both the highest in the file and the highest already reserved, and reserves it before printing it — an empty directory `issue-{N}-ledger.ids/<ID>` beside the ledger, which one caller alone can create. Writers of one namespace that call it concurrently — two advisors spawned together, each allocating before the other has appended — therefore receive distinct identifiers. A reserved identifier that is never appended (the append denied, the writer stopped) leaves a gap in the serial; a gap is not a defect, and `check` does not report one. A writer whose append must be retried keeps the identifier it was issued.
- **Identifier collision**. Two entries can share an identifier — entries written before this protocol or before `next` reserved what it issued, or a heading appended in error; they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair. A reader that resolves a supersession by identifier (`<autoflow-root>/scripts/gate/security-checklist.sh`) displaces every earlier entry it counts that the named identifier matches — never an operator entry by an advisor's — so a re-deriving entry written by the colliding entries' own authority is the one that stands.

## Decision-point entries

**Advisor decisions and operator overrides.** A decision point is answered first by the advisor
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor): an `A<n>` entry under the authority
`advisor decision`, carrying a `- Record:` line to the advisor's answer file
(`<attempt-dir>/issue-{N}-advisor-<ID>.md`) and the marker and fields its kind requires below. Only the
advisor writes that authority or an `A` heading, and the advisor never writes `operator decision` or
an `O` / `F` / `E` heading — the gate hook denies both
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*). The operator may
override an advisor's entry: the orchestrator — the main session, the
only writer the gate hook admits for an `O` entry or the `operator decision` authority — records the
override as an `O<n>` entry under the authority `operator decision`, with the same marker and fields
and an `- Overrides: A<n>` line. An override supersedes the advisor's entry without a new verified
fact — the operator's authority is the ground, the one supersession the no-re-litigation rule admits
besides the verified-error exception; an advisor never supersedes an operator entry.

**Replacement is explicit.** An entry is never edited to change a decision — the gate hook keeps the
ledger append-only ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*). A later
entry replaces an earlier one only by naming it: `- Supersedes: <id>` (the same authority, on a new
verified fact or the verified-error exception) or `- Overrides: A<n>` (the operator over the
advisor). Two standing entries on the same subject whose conclusions disagree, with neither naming
the other, are a **conflict**: nothing is settled by recency, and the conflict is resolved by a new
entry — the advisor's, naming the entries it resolves, unless an operator entry is among them, which
only the operator replaces. The same conclusion recorded twice is not a conflict. An identifier two entries
already share is read as *Identifier collision* above says, never repaired by editing either entry.

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is
never the design's or a unit's to apply: the **orchestrator** decides it first, on the grounds the
raising report or recommendation carries, and puts it to the **advisor** only where those grounds
do not settle it or it is not confident ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*); the **operator** may override. The change stands only
as the entries below ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1); choosing how a
criterion is *verified* is the design's, provided the row states its reason, which the
reviewers then judge at REVIEW (the three-tier guard — [`units/design.md`](<autoflow-root>/docs/units/design.md) >
*Report routing*). A content change reaches the orchestrator from wherever it surfaces: the ARCHITECT design
unit's `## Decision requests` section, before GATE:PLAN; a problem the BUILD unit meets and raises in
its report; or a gate recommendation that records a criterion defect, or whose
triage hits the acceptance-criterion pause criterion ([`units/design.md`](<autoflow-root>/docs/units/design.md) > *Report routing*,
[`units/completion-evaluation.md`](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*). The change excludes, revises or splits a criterion, or adds one. The
decision is recorded as one entry per decided AC, in the same trailing-marker grammar:
the heading `## O<n> — <title> (cycle <C>, <PHASE>) [ac-decision]` (the advisor's: `## A<n> — …`; an override: `## O<n> — …`),
`<PHASE>` being the phase the change surfaced in, followed by the entry's own `- AC: <ac id>` line (for
an added criterion, the id it takes), a `- Disposition:` line valued `excluded` / `revised` / `split` /
`added`, and the ordinary Decision / Grounds / Authority lines with the authority value
`orchestrator decision` (the advisor's: `advisor decision`; an override: `operator decision`).

**A criterion can be wrong; from ARCHITECT on, the work tests it**. DIAGNOSE takes the criteria as written — it
analyzes the problem as the issue states it and runs no test of the criteria of its own. That says how
DIAGNOSE works, not when a defect may be raised: a defect observed as a fact is raised wherever it is
observed, a gate before ARCHITECT included. From ARCHITECT on — the design, the build
and every gate after them — a criterion is a hypothesis the work tests, not a truth the
work is bent to fit: wherever the work and a criterion disagree, *is the criterion wrong?* is one of the
answers the judgment weighs, beside *how is it satisfied?* A criterion is **defective** when (a) a fact
it presumes does not hold — a device, a phase or a state it takes for granted; or (b) the scope it draws does not fit the problem — too
narrow, when the same cause reaches past what it names, and the question is then whether the issue saw
the problem as local and the approach itself must change, not only whether to include the rest (a
widening: `revised` / `added`); or too wide, when it binds in a problem separate from this issue (a
split: `split` / `excluded`). A defect so judged is raised for a decision — the orchestrator's first, the advisor's where it cannot settle it;
it is never resolved by keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the unit documents and agent definitions cite it.

The marker sits at the **end** of the heading. The authority over an acceptance criterion maps to
these literals and nothing else: the entry's authority **value** is `advisor decision` on an `A<n>`
entry, or `orchestrator decision` or `operator decision` on an `O<n>` entry, and the entry is **located** by the `[ac-decision]`
heading marker. The two gate backstops key on the marker. When the entries for one AC disagree, an `operator decision` entry wins. When the
disposition is `revised`, `split` or `added`, the analysis report's acceptance-criterion table
(`<attempt-dir>/issue-{N}-analysis.md`) is edited to
match before re-entry, and this entry is the record of who authorized the edit. An `added` entry
covers no difference in either gate backstop: the criterion it adds is owed its verification-design
row and its discharging site like any other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and a cycle's AUDIT reads it as of the cycle's base commit ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). Changing it inside a cycle — the file, or the
declaration that points at it — is never the cycle's own to accept: the **advisor** decides first
and the **operator** may override. When `<autoflow-root>/scripts/gate/security-checklist.sh status` reports the
change at AUDIT entry, the orchestrator spawns the advisor, and the answer is recorded in the same
trailing-marker grammar: the heading `## A<n> — <title> (cycle <C>, AUDIT) [checklist-decision]` (an
override: `## O<n> — …`), followed by a `- Checklist:` line (the declared path at HEAD, or `none` when
the declaration is dropped), a `- Blob:` line (the `git rev-parse HEAD:<path>` of the approved
version, or `none`), a `- Disposition:` line valued `accepted` / `rejected`, and the ordinary
Decision / Grounds / Authority lines with the authority value `advisor decision` (an override:
`operator decision`), plus the `- Supersedes:` / `- Overrides:` line when it replaces an entry. The
script counts an entry only when its Decision and Grounds lines are non-empty, its Disposition is
`accepted` or `rejected`, and its Authority matches its namespace (`advisor decision` on `A<n>`,
`operator decision` on `O<n>`), and only while its Checklist and Blob equal HEAD's, so a later edit to
the checklist is a new change owed its own decision. An entry stands unless a later counted entry
replaces it by name (*Replacement is explicit* above; an advisor entry never replaces an operator
entry). The standing entries decide only when they agree: all `accepted` → the change is covered; all
`rejected` → it is not, and the change is reverted before AUDIT; both → a conflict, reported as
`conflict=<ids>` on an undecided (exit `3`) record and resolved by a new entry, never by recency.

**Criterion-readiness confirmations** (`[criterion-ready]`). In the first stage of an attempt's
cycle, before its state file, the attempt's own review checks the issue's acceptance criteria and
the decisions the review settles are recorded ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). The review session
judges and records its dispositions, a point it cannot settle is decided by the advisor as at any
decision point — the answer is itself the decision and does not wait on the operator's review —
and the operator overrides either when they choose. Once every decision is settled, the review
session records them in one entry, with no operator confirmation asked: the entry is the record of
the decisions made under the policy the operator set for the review, under the authority
`operator decision` — the same authority over acceptance content as an override
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). It is recorded in the trailing-marker grammar: the heading
`## O<n> — <title> (cycle 0, CRITERION-REVIEW) [criterion-ready]`, followed by a `- Decision:`
line, a `- Record:` line (the review record's file name in the attempt's own record directory, by name
alone), an
`- Issue body sha256:` line (the value `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints
for the body the entry records), and the ordinary Grounds and Authority lines with the authority value
`operator decision`. No `A<n>` entry carries the marker, and an attempt that has a state file takes
none. `<autoflow-root>/scripts/preflight/criterion-ready.sh
status` reads the **last** entry carrying the marker in the attempt's own ledger — never another
attempt's — and counts it only when it is an `O` entry
under `operator decision`, its record exists and its sha256 equals the issue body's now; an edit to
the body is confirmed by a new entry, never by editing this one. The entry is the criterion review
stage's exit, and PREFLIGHT reads that status on the attempt's start
([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*, Stop conditions >
*Criterion readiness*); nothing after the state file reads the entry, and a criterion change from
then on stays an `[ac-decision]`.

<!-- From <autoflow-root>/docs/issue-proposal.md -->

# Issue Proposal — Draft Grammar and Filing Procedure

An issue is filed from a **draft on disk**, never from arguments typed at the
moment of filing. `gh issue create` is denied at the tool boundary
(`<autoflow-root>/hooks/check-autoflow-gate.sh` > Section 1); the only filing path is:

```bash
<autoflow-root>/scripts/issue/create-issue.sh --draft <path> [--repo <owner/name>] [--dry-run]
```

The wrapper derives search terms from the draft's **own title**, runs the query
itself, and then compares what that query returned against the candidates the
draft dispositioned. It never judges whether a disposition is *correct* — that
judgment is the operator's, at layer three. It refuses when the draft disposes of
nothing the wrapper found.

Three layers guard the path:

| Layer | Mechanism |
|-------|-----------|
| 1 | hook deny on `gh issue create` and its REST form |
| 2 | `<autoflow-root>/scripts/issue/create-issue.sh` re-runs the query and compares dispositions |
| 3 | the operator permission prompt on the wrapper |

Layer three works by **omission**: keep the wrapper off every allow list —
neither `"Bash(scripts/issue/create-issue.sh:*)"` nor a broad `Bash(scripts/*)` /
`Bash(scripts/issue/*)` goes into `.claude/settings.json` or
`.claude/settings.local.json`.

## Draft grammar

Write the draft **directly inside** the repository's draft directory under the record root,
`<record-root>/<repo-key>/drafts/` — the path `autoflow-records drafts` prints (and creates) —
outside the target's tree.

Four required level-2 sections, in **any order** — each runs from its own
heading to the next level-2 heading or to end of file:

```markdown
## Title
[feat] one line, exactly as the issue title should read

## Grounds
`<autoflow-root>/scripts/issue/create-issue.sh` > `has_section "Grounds"` — "a grounding anchor under '## Grounds'": the check runs here, not in the caller

## Duplicate check
searched: create-issue duplicate gate
candidates: none

## Body
The issue body, verbatim. Everything here — and nothing from the other
sections — becomes the created issue's body.
```

| Section | Content | Wrapper's check |
|---------|---------|-----------------|
| `## Title` | one line — the issue title | non-empty single line |
| `## Grounds` | why the issue is warranted | at least one anchor: a commit SHA, a URL, or a durable citation — a document, its section heading and a quoted sentence, written `` `<path>` > <heading> — "<fragment>" ``. A bare `path:line` is not an anchor here |
| `## Duplicate check` | a `searched:` line listing the query terms, then either `candidates: none` or one `#<number> — <disposition>` row per candidate | the `searched:` line is present and non-empty; its tokens feed the term derivation; the candidate rows are the set the disposition invariant compares against |
| `## Body` | the text from its heading to the next level-2 heading | non-empty; becomes the issue body |

A heading inside the body is written at level 3 or deeper (`### Background`),
never at level 2. A `## ` line ends the section above it wherever it sits — a
fenced code block included — so the text under a level-2 heading that names none
of the four sections belongs to no section. The wrapper refuses such a draft,
naming each such heading with its line, instead of filing the body cut short at
it.

## The two names of the artifact

| Stage | Path |
|-------|------|
| Before creation (draft) | `<record-root>/<repo-key>/drafts/issue-proposal-<slug>.md` |
| After creation | `<record-root>/<repo-key>/proposals/issue-<N>-proposal.md` |

Both are under the record root, outside every checkout's tree, and no cleanup touches either. An
unfiled draft stays until its author abandons it. Once the issue exists, the wrapper's rename binds
the record to the issue's number; it belongs to the issue, not to any one attempt of it.

## What the wrapper does

1. Refuses unless the draft is a regular file directly inside the repository's
   draft directory. The directory being **absent** is diagnosed separately from a
   misplaced draft, with a different message. The wrapper does not create the
   directory. A draft that is itself a symlink is refused rather than resolved.
2. Refuses a draft missing any required element, or carrying a level-2 heading
   outside the four sections, naming **every** such defect.
3. Derives title terms by a rule with no implementation freedom: strip a leading
   `[tag]`; lowercase the ASCII range only; split on whitespace and ASCII
   punctuation, with bytes outside ASCII never acting as separators, so a
   non-ASCII run survives as one token; keep a token of `[a-z0-9]` at ≥ 4
   codepoints and a token carrying non-ASCII at ≥ 2; deduplicate keeping first
   appearance; keep the first 8. Codepoints are counted **locale-free**.
4. Appends the `searched:` line's tokens under the same lowercase/separator rule,
   with no floor and no cap. Recorded terms are strictly **additive**: they can
   only lengthen the query.
5. Refuses if the title derives **no** term.
6. Runs **one query per term**, `--state all`, `--limit 100`. If any one term
   returns a full page → refuse, naming the term.
7. Refuses if any returned issue number is not already dispositioned in the
   draft, listing the undispositioned numbers.
8. On success — and only then — renames the draft to
   `<record-root>/<repo-key>/proposals/issue-<N>-proposal.md`, with `<N>` parsed from the URL `gh`
   returned and `<repo-key>` the repository the issue was filed in — the `--repo` value when one is
   named, the current origin otherwise — so a record for another repository's issue never shares a
   name with this repository's issue of the same number. A URL with no parsable trailing number is a failed bind: the draft
   stays put.

`--dry-run` runs every check and creates nothing, leaving the draft in place.

Filing is not readiness: a filed issue reaches DIAGNOSE only once its attempt's criterion review
stage has reviewed its acceptance criteria and recorded the `[criterion-ready]` entry
([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | created, or `--dry-run` passed every check |
| `64` | usage, or the draft is not directly inside the draft directory (including that directory being absent) |
| `7` | the record root is undetermined or unusable (its marker line says why) |
| `65` | refusal — missing section, a level-2 heading outside the four sections, no grounding anchor, no derivable term, an undispositioned candidate, or a query at its page limit |
| `70` | the issue was created but its number could not be bound |
| other | `gh`'s own exit, propagated |

The floors, the cap, the tag strip and their order are **fixed constants in the
script, not flags**; an unrecognised argument is a usage error.

## Accepted limits

Each limit below is an under-block, with layer three as the catch:

- The term cap drops terms on ordinary titles, so a duplicate reachable only
  through a dropped term is never surfaced, and the wrapper reports a clean
  check.
- A term is queried in the surface form the title wrote, so a duplicate phrased
  with a different inflection of the same word falls outside the candidate set.
- On a large tracker a common derived term can return a full page and trip the
  truncation refusal, leaving the agent unable to file until a human intervenes —
  the escape is the operator's, not the agent's.
- The REST-form deny matches any same-segment `POST` paired with a
  `repos/…/issues` path regardless of client, so the plain `curl -X POST
  https://api.github.com/repos/<o>/<r>/issues` form is denied too. The path is
  required to end at the issues collection, and it is taken to end at exactly
  two suffix delimiters — a query `?` and a fragment `#` — so
  `repos/<o>/<r>/issues?per_page=1` and `repos/<o>/<r>/issues#note` are denied
  as well, while `…/issues/12/comments` stays unmatched. No other delimiter is
  claimed: the trailing-slash form `…/issues/ --method POST` is **not** matched.
  What is not matched beyond that is a determined evasion — an obfuscated URL,
  a client invoked through a wrapper script, a quoted form (the hook's scan
  strips quoted substrings exactly as it does for every other Section 1 deny),
  or a command-substituted form (which the scan does *not* strip — it goes
  unmatched). The threat model is the routine self-authorized filing, not a
  determined evasion.

<!-- From <autoflow-root>/docs/role-contracts.md > Advisor -->

## Advisor (first judgment at a decision point)

ADR-0025 D7 moves the first judgment at a decision point from the operator to a dedicated advisor.
This section is the procedure's single home; [`core.md`](<autoflow-root>/docs/core.md) > Flow Control routes to
it and the unit documents cite it.

### Decision points and harness-level blocks

- **A decision point** is a decision the working AI cannot settle on the grounds at hand, or is not
  confident of ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3). An acceptance-criterion
  change, a non-code root cause or a non-code lever, a planning / design / ADR prerequisite the
  analysis records, a reviewer finding that repeats the previous attempt's complaint, and a
  GATE:HYPOTHESIS PASS the orchestrator judges unreachable are where such a decision arises, not
  decision points by their kind: the orchestrator judges each first, and where the grounds the
  raising report, finding or evaluation carries settle it, it decides and records the decision with
  those grounds in an `O` ledger entry under `orchestrator decision` — for an acceptance-criterion
  change, its `[ac-decision]` entries ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
  *Acceptance-criterion decisions*); for a repeated complaint, the attempt's `[review-autofix]`
  entry. An un-agreed design point, a `remedy_class: operator`, and a recommendation or finding the
  orchestrator cannot route with confidence (a pause criterion, a rebuttal the re-score or the
  reviewer keeps while the two sides still disagree) are already decisions the working AI could not
  settle. A security-checklist change (`[checklist-decision]`) is the one decision point by its
  kind: `<autoflow-root>/scripts/gate/security-checklist.sh` counts only an advisor or an operator entry
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Security-checklist decisions*). In U1's criterion
  review stage, a point the review cannot settle is one as well, put by the session running the
  stage — the orchestrator, or a `/autoflow:criterion-review` session taking its part — in the
  procedure below with `cycle 0` and the phase `CRITERION-REVIEW`
  ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). Each decision point is answered by
  the advisor first.
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial), or a tool, credential, installation or material the environment does not provide — for a
  tool it has, what using it lacks (access, a purpose and permitted scope, a permission setting). Only
  such a block stops the cycle for the operator on the forward path — situation-first, `active:false`,
  `phase:"awaiting-user"` ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision
  presentation). A decision at one of those points can end the cycle instead — a non-code lever or cause, a
  prerequisite that comes first, a GATE:HYPOTHESIS PASS not reachable; the last asks the operator to
  confirm closing the issue, the cycle not closing it itself ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) >
  *Verification — GATE:HYPOTHESIS*). PREFLIGHT's readiness conditions, the gate thresholds and the caps are not decision
  points and are unchanged ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1).

### Procedure

1. **Request.** The orchestrator writes `<attempt-dir>/issue-{N}-advisor-request-<k>.md` situation-first:
   the situation in domain terms, the decision asked with each option and what it changes, the
   orchestrator's own reading — the option it leans to, its grounds, and the point where those
   grounds stop settling it — and the anchors (the artifact paths, the report or finding the
   decision surfaced in). The advisor starts from that reading rather than gathering the material
   anew.
2. **Spawn.** One fresh `autoflow-advisor` per decision, anonymous, model from
   `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model advisor` (its effort is the definition's
   `effort:` line). The prompt names the request file, the ledger, the issue, the cycle and the
   phase. The spawn is never score-gated. Where two or more decisions are open and none depends on
   another's answer, their advisors may be spawned together, and a decision that depends on another's
   answer is spawned after that answer is recorded; whether to spawn them together or one after
   another is the orchestrator's judgment (`<autoflow-root>/docs/core.md` > Rule Scope, principle 2), within the
   concurrent-spawn limit (`<autoflow-root>/docs/core.md` > Cost Control).
3. **Answer and record.** The advisor weighs the material itself, writes its answer to
   `<attempt-dir>/issue-{N}-advisor-<ID>.md` in the same situation-first order, and appends one
   `A`-namespace entry per decision to the ledger under the authority `advisor decision`, carrying a
   `- Record:` line to the answer file and the marker and fields the decision's kind requires
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)). Its identifier comes from
   `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> A`, called immediately before the append; the
   call reserves the identifier, so advisors spawned together receive distinct ones
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entry identifier > *Allocation*). It appends with `Edit`, which the gate hook applies to
   the file on disk and checks (*Independence* below), so the prior content is never re-written. It
   returns the identifier and the answer in one line.
4. **Apply.** The orchestrator verifies the anchor — the ledger heading and the record file exist —
   and routes the cycle as the operator's answer to that point would have been routed: the
   Flow Control row the point sits on names the route. The cycle does not pause. An advisor that
   reports the decision blocked at the harness level turns it into a harness-level block.

### Independence

The advisor is never the author of what it judges: it is a fresh spawn per decision, not the unit
agent, role spawn or orchestrator whose work raised the point, and its record carries its own grounds.
Its authority is worth only that separation, and the operator's override only its own — so each
is written by its own writer alone and stays as written. Three locks:

- **Authorship — the gate hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`, *Section 1e*,
  state-independent): text a `Write` / `Edit` / `MultiEdit` adds to an `issue-*-ledger.md` that carries an `advisor decision`
  authority or an `A<n>` heading is denied unless the caller's `agent_type` is `autoflow-advisor`;
  text carrying an `operator decision` authority or an `O<n>` heading is denied unless the caller is
  the main session (no `agent_type` — the orchestrator, or a `/autoflow:criterion-review` session
  taking its part, recording its own decision, an operator override or instruction, or the review's
  `[criterion-ready]` entry); the advisor
  adds no `operator decision` and no `O` / `F` / `E` heading.
- **Append-only — the same hook section**: a `Write` / `Edit` / `MultiEdit` is applied to the file
  on disk and must keep the whole prior content as its prefix, so no entry is rewritten or removed.
  A decision changes only by a new entry that names the one it replaces
  (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **The record convention**: a consumer counts `advisor decision` only on an `A<n>` entry and
  `operator decision` only on an `O<n>` entry, and lets an entry replace another only by an explicit
  `- Supersedes:` / `- Overrides:` line (`<autoflow-root>/scripts/gate/security-checklist.sh`; the gate backstops
  match the `[ac-decision]` marker and read the authority as recorded).

The threat these locks answer is an agent overstepping in routine work — rewriting a ledger it
meant to append to, or writing an authority that is not its own — not a determined evasion (the
same model as `<autoflow-root>/docs/issue-proposal.md`). Outside the hook's surface: a shell write to a ledger
(redirect, `tee`, `sed -i`, a script), and text that only imitates an entry (a heading-less field
line, a malformed heading, a variant spelling of an authority).

### Operator override

An operator override of an advisor decision is recorded by the orchestrator as an `O` entry under
the authority `operator decision`, with the marker of the entry it overrides and a line naming that
`A` identifier. It supersedes the advisor's entry without a new verified fact — the override is the
authority ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor decisions and operator
overrides*) — and the cycle re-enters where the overridden answer's route reaches, consuming no
re-entry budget.

### Claude Code's advisor tool (`advisorModel`)

Distinct from the advisor sub-agent above: Claude Code's advisor tool
(<https://code.claude.com/docs/en/advisor>) lets the session's model consult a stronger model
mid-task. AutoFlow neither enables it nor directs its use. It cannot carry a
decision point: its model is configurable and its effort is not, and Claude decides when to call it,
which is why the first judgment is the sub-agent's (ADR-0025 D7).

---

<!-- From <autoflow-root>/docs/state-tracking.md -->

# AutoFlow State Tracking

The state file's detail — its naming, its schema and fields, the hook gates that read it, and its state at completion. The rules that write into it — the `verdict` rule, score recording and remedy class recording — are [`<autoflow-root>/docs/core.md`](<autoflow-root>/docs/core.md) > AutoFlow State Tracking (Hook integration).

**Record location**: an attempt — one run of an issue — keeps every file in its record directory `<attempt-dir>` = `<record-root>/<repo-key>/<stamp>-issue-{N}/`, named by its dev branch `dev-<stamp>-issue-{N}` (`<stamp>` = `YYYY-MM-DD-HHMMSS`; `dev/<stamp>-issue-{N}` for an attempt made before issue #490): the state file, the ledger, the criterion review record, the unit and gate reports, the review records and the cycle-layer store `issue-{N}-local/`. `autoflow-records dir` prints it for the checked-out dev branch (`--branch` for another), and every document, agent definition, script and hook names a record path through that command or the library it wraps, `<autoflow-root>/scripts/lib/records.sh`. Two repositories' issues of the same number never share a name, and two attempts of one issue — in one checkout, two worktrees or two clones — never share a directory. `{repo-key}` is `<owner>__<name>` derived from the checkout's `origin`.

- **The record root** is `record_root` in the operator's `~/.autoflow/config.json` — an absolute path; the file itself never moves with it. No file, no key, or a JSON `null` → the default `~/.autoflow`. A file that cannot be read as JSON (a syntax error, or no `jq`), or a `record_root` that is not an absolute path string (not a string, empty, relative), leaves the record root **undetermined**, never the default in its stead; an error in the same file's `.review` does not touch it. A record root inside the session's checkout, or one that cannot be created or written, is **unusable**. Either way every script that needs it writes nothing and stops with exit `7` and the marker line `record-root: UNDETERMINED <config path> — <error>` or `record-root: UNUSABLE <record root> — <error>`, asking nothing; the next run reads the file anew. Nothing else — no environment variable — names the root, the records or `_metrics/`.
- **The owner**: the file `checkout` in the record directory names the checkout the attempt belongs to — the one that started it, or the one that took it over (`autoflow-records claim`, once that checkout is gone). Entry, the hook's gates and cleanup read only this checkout's attempts ([`<autoflow-root>/docs/units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*).
- **Completed**: the file `completed` marks an attempt whose Post-Merge Cleanup has run; its records stay where they are ([`<autoflow-root>/docs/git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).
- **Records kept inside the tree before the record root** (`.autoflow/<repo-key>-issue-{N}/`, issues #423 to #465): a state file there is never passed over. The hook refuses the score-gated calls and PREFLIGHT stops (`entry: stop in-tree-records`) until `<autoflow-root>/scripts/migrate/migrate-in-tree-records.sh` moves each such directory whose state file names a dev branch `dev/<stamp>-issue-{N}` to that attempt's record directory, with this checkout as its owner; the cycle then continues from there. One naming no such branch is moved too when it reads `active: false` — to `<record-root>/<repo-key>/in-tree-<date>-<time>-issue-{N}/`, marked `completed`, kept as a record and never entered; when it reads `active: true` it is reported and left for the operator (name the branch in the attempt shape, or set `active: false`), and the script runs again. A directory with no state file (a proposal record, a criterion review of no attempt) is not a cycle and is left in place.

**Companion artifact**: `<attempt-dir>/issue-{N}-ledger.md` — the attempt's append-only decision ledger ([Decision Ledger](<autoflow-root>/docs/core.md)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: by the orchestrator, at PREFLIGHT completion, after the attempt's criterion review stage — the attempt's record directory and dev branch already exist, made when the cycle created the attempt (`autoflow-records new`; [`<autoflow-root>/docs/units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*).

```json
{
  "active": true,
  "issue": "#N",
  "title": "Issue title",
  "date": "YYYY-MM-DD",
  "branch": "dev-YYYY-MM-DD-HHMMSS-issue-N",
  "cycle": 1,
  "mode": "new-issue",
  "phase": "in-progress",
  "phases": {
    "gate_hypothesis": { "evaluator": "", "scores": {}, "verdict": "pending" },
    "gate_plan":       { "evaluator": "", "scores": {} },
    "audit":           { "evaluator": "", "scores": {} },
    "gate_quality":    { "evaluator": "", "scores": {} }
  }
}
```

**`branch` field**: the attempt's dev branch, named once when the cycle creates the attempt (`dev-YYYY-MM-DD-HHMMSS-issue-N`) and kept unchanged for the life of the state file — a review-response continues on it, and the record directory is named from it. The hook admits it as a string and does not read it.

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry; what that resets is `<autoflow-root>/docs/units/preparation.md` > *Review-response setup*. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; the review-response setup sets `"review-response"` (target issue's PR is open). The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while REVIEW aggregates and triages the review result; `"awaiting-external-review"` at the end of REVIEW (set only once the review is clean — no PR's verdict is Medium+) and at a GATE:HYPOTHESIS `no change needed` review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](<autoflow-root>/docs/core.md)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](<autoflow-root>/docs/core.md) > Spawn role declaration.
- `Agent` (a spawn whose caller `agent_type` is a functional-unit agent) → no declaration required; judged by the unit's gate class, and a declared role's own gate also applies (see [Spawn Model](<autoflow-root>/docs/core.md) > A unit agent's spawns inherit its gate class).
- `Agent` (role `planning` — `autoflow-unit-design`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` is a `skipped` value (non-bug issue).
- `Agent` (role `implementation` — `autoflow-unit-build`) → GATE:PLAN pass required.
- `Agent` (role `analysis` — `autoflow-analyzer`, `autoflow-criterion-tracer`, `autoflow-criterion-analyzer`, `autoflow-criterion-reconciler`, `autoflow-unit-analysis` — / `evaluation` / `advisor` / research types) → not score-gated.
- `Write` / `Edit` / `MultiEdit` on an `issue-*-ledger.md` → **state-independently**: a write that changes or removes existing text is denied (append-only); adding an `advisor decision` authority or an `A<n>` entry is denied unless the caller `agent_type` is `autoflow-advisor`; adding `operator decision` or an `O<n>` entry is denied unless the caller is the main session; the advisor adding an `O` / `F` / `E` entry is denied ([`<autoflow-root>/docs/role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*).
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- Which state gates: the state files of **this checkout's** attempts — the record directories whose `checkout` file names the session's checkout (`CLAUDE_PROJECT_DIR`), not marked `completed`. Another checkout's attempt never gates the session. Two or more active ones fail closed on the score-gated surface (`git push`, `gh pr create`, a spawn other than research or evaluation); so does a malformed one.
- In a session with an AutoFlow dev branch (`dev-…-issue-<N>`, or `dev/…-issue-<N>` made before issue #490) checked out — or being rebuilt by an interrupted rebase on a detached HEAD — a record root that is undetermined or unusable, a directory under it that cannot be read, or no `jq` (so neither the input nor the state can be read), refuses the same score-gated surface with the user file's path and error; reads, the writes that repair the file and research / evaluation spawns pass, and the next call reads the file anew. A session with no dev branch checked out can have no attempt in progress and is not refused for it. With no `jq`, the state-independent denies below still hold, read the same over-inclusive way from the raw input.
- A state file in the checkout's own `.autoflow/` (*Record location* above) refuses the score-gated surface until it is moved.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `<attempt-dir>/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch or — in a dev-branch session — to the dev branch's base (its `gh-merge-base`) → **denied state-independently**. AutoFlow never merges; merging is external.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `<autoflow-root>/scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`<autoflow-root>/docs/issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md).
- A **backgrounded** run of `<autoflow-root>/scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `<autoflow-root>/docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on `Bash` (git / gh commands), `Write|Edit|MultiEdit` and `Agent`.

**Completion**: at the end of REVIEW, once the aggregated review is clean (no PR's verdict is Medium+ — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-attempt resolution reads the file (review-response mode) and, once the PR is observed merged or closed, marks the attempt completed; its records stay in its record directory (`<autoflow-root>/docs/units/preparation.md` > *What is asked*).
**Forced termination**: also set `active` to `false`.

<!-- From <autoflow-root>/docs/role-common-rules.md > Communication > Result delivery path by spawn mode -->

### Result delivery path by spawn mode

Every role is an anonymous direct spawn, so there is exactly one delivery path — the spawn's report to its caller, which these rules call its return value — whether the spawn is answering its prompt or a later wake. What carries the report is the harness's, and it depends on the session's permission mode (Claude Code CHANGELOG, 2.1.271: "Changed auto mode so a subagent reports back to its caller through a dedicated hand-back call …"):

- **auto mode** — the spawn's `SubagentHandback` call, which the harness instructs every sub-agent to make; plain text the spawn writes at the end is not delivered. The caller receives two events, in either order: an `<agent-message from="<id>">` hand-back frame, which carries the report, and a task notification whose `result` only points to that frame. The pointer notification is not a spawn that produced no report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Role-spawn idle handling*) — the report is the frame, arriving before or after it.
- **any other mode** — the spawn's final text: the return value (sync) or the task notification's `result` (background).

The hand-back carries exactly what the final text carries in the other modes — the anchor + one-line summary — never the body, whatever the harness's own tool description says of a "full report" ([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Orchestrator context discipline*, row 2).

| Spawn mode | Where the report arrives | Required delivery action |
|---|---|---|
| anonymous direct (`subagent_type`) — the only mode | auto: the hand-back frame, beside a pointer task notification; otherwise: the return value (sync) or the task notification's `result` (background) | auto: the hand-back call the harness instructs; otherwise none. Write the body to `<attempt-dir>/*` and report an anchor + one-line summary |

A spawn carries no `name`: the gate hook keys the role→gate mapping on `subagent_type` alone and denies a `name`-carrying payload inside a cycle.

The single mode applies to every role; the per-role table is [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Spawn mode by role lifetime.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Reporting Format -->

## Reporting Format

When a role spawn reports to the orchestrator — the report is the spawn's return value, with any body written to `<attempt-dir>/*` and an anchor plus a one-line summary returned — it must follow this shape (see [`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Orchestrator context discipline*). This format governs **AI↔AI / AI↔orchestrator** reporting: the returned report, and what a unit agent's helpers report to it. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in [`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite `<attempt-dir>/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report the test runner's summary line (e.g., "Tests: 147 passed, 147 total"), read from the run's log (item 5), + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the run's **log** — the file its output was written to (Testing Standards item 7), cited by path under `<attempt-dir>/issue-{N}-local/` — with the command that produced it and the exact `Tests: N passed, N total` (or equivalent) summary line read from that log. The log is the evidence and the summary line is the value read from it; a line no log carries is not evidence (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, plus the verbatim content of that line (a line number is read only at that commit — [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger)
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under `<attempt-dir>/issue-{N}-local/`, with its result line (`observation: match` / `observation: mismatch — …`) read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the committing role identified, followed by the grounds of the identification — where it looked (the documents, scripts and CI files read) and each CI lint step it did not count as a chain with the condition that excludes it — the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked, its source (document section, script definition or workflow `path:line` and step name) and the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*), the reason, and the unexecuted chain's identity (its command and source, or the workflow `path:line` and step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this pull request — the workflow's `on: pull_request` entry, either no `paths:` filter or one whose patterns match a staged file, and a job and step condition that admits this pull request; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-covered` → the chain and the file set it covers; `not-applicable` → that word alone, with the grounds naming where the committing role looked. A report citing one chain where the committing role identified several is malformed, not compliant.

   Anchors must be deterministically confirmable by the orchestrator against what produced them (`git show <SHA>` / the summary line read in the cited log / `git show <SHA>:<file>`); a test-pass anchor is confirmed by reading, not by re-running — the command is re-run only when the log is absent or does not carry the line, and the run is then `not-run` and run in place. Reports without an anchor are rejected, not interpreted. This item's line-number forms are for the report; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.


---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Verification and Tools -->

## Verification and Tools

This section applies to every actor of a cycle — the orchestrator and every role.

**Local verification** (the instance of [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2 the phases cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every `automated` row this cycle authored or changed and every `delivery-check` row — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format item 5). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is HANDOFF's CI — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to (Testing Standards item 7's `$LOG`), cited by path under `<attempt-dir>/issue-{N}-local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the orchestrator's acceptance of a role-spawn report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Verify role-spawn claims*), AUDIT's test-first judgment, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the BUILD unit, or a helper it spawns — finds, in the target checkout it works in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **cycle-layer asset** — a default `automated` row's test, a `delivery-check`, a `manual` checklist — lives in the attempt's cycle-layer store `<attempt-dir>/issue-{N}-local/`, under the record root outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's absolute path in the store** and is run from the target checkout's root: the asset finds the tree it checks from its working directory (`git rev-parse --show-toplevel`), never from its own location, which is outside every tree. The verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A cycle that wants one command for several assets writes that driver *as* a cycle-layer asset in the same store. Such an asset is never committed, and stays with the attempt's other records. A cycle asset writes its reproducible output — a build result, a copy of a source tree or of another original: an output re-creatable from inputs its record already names, such as a commit and a command — only under the store's reserved path `<attempt-dir>/issue-{N}-local/disposable/`, which cleanup deletes — the one path it deletes ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). Nothing a run record, an observation record or a cycle report cites ever goes there — not a log, a record file, the artifacts an observation left, or the asset itself, whose path the recorded command names — even when it is re-creatable. Whether an output is reproducible and uncited is the writer's judgment; where such an output goes is not. Only the store's top-level `disposable/` is reserved — a `disposable` deeper in the store is kept like any other path — and reproducible output left outside it is a deviation, kept with the rest of the store.

**The tools the work needs are found and used; what a tool lacks is requested from the operator**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. The orchestrator pursues securing them. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the orchestrator ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Background execution is orchestrator-only*), and stopped once the cycle no longer needs it. A tool that cannot be used has something missing, and that is what is requested from the operator, situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Flow Control > *tool or referenced material → user*): the tool itself when this environment does not have it — an installation, enabling an MCP server or a browser extension — or, for a tool it has, what using it lacks — access, the purpose and permitted scope of the host or service it reaches, a credential, a permission setting. Providing any of these is outside the assigned scope ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); using a tool the environment already provides is not. A purpose or permitted scope is a project fact, asked with the request that the operator record it in the project's information ([`core.md`](<autoflow-root>/docs/core.md) > Project Information). The request names what is missing, not the output the tool would give: the output answers one cycle, and the next cycle that needs the same fact stops at the same point. A criterion falls back to a person's observation or a mock only when no tool can be secured: what is missing — the tool, or what using it lacks — was requested and the operator answers that it cannot be provided, or no tool exists that verifies the criterion (`<autoflow-root>/docs/units/design.md` > *Tools*). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened reaches the operator the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under `<attempt-dir>/issue-{N}-local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each phase does this: `<autoflow-root>/docs/units/analysis.md` (DIAGNOSE), `<autoflow-root>/docs/units/design.md` > *Tools* and `<autoflow-root>/docs/units/build.md` > What the build owes.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — a spawn prompt that hands the record to the next role, GATE:QUALITY's `Test coverage` or `Commit conventions` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL and routes nowhere; a run that fails routes as the phase's own rules say.

**What a cycle leaves in the target's tree is not classified by AutoFlow**. A cycle adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the cycle does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI* > *Added test files*), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->
