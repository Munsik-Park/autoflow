---
name: cycle-u7
description: >-
  Run unit U7 (Review — REVIEW) of an AutoFlow cycle alone, or the review of
  an attempt with no state file on the abbreviated path, in a session of its
  own, with the parts of the core U7 uses. Use only when the operator starts a
  U7 session (/autoflow:cycle-u7 [<N>]).
argument-hint: "[<issue-number>]"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: `<N>`, or nothing) — unit U7, Review (REVIEW), of a cycle alone: read where the cycle stands from the current state — `bash <autoflow-root>/scripts/preflight/cycle-status.sh`, with `--issue <N>` when given — run U7 from there to its exit transition, and end the session with the report the invoking prompt asks for.

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that U7 uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle > Unit Document Loading Contract: The reference values, U1 Criterion review, U2 Analysis, U3 Design, U4 Build and verify, U5 Completion eval, U6 Delivery, The rubric of every evaluation, The evaluation contract; Development Lifecycle > Unit references: U1 Criterion review, U2 Analysis, U3 Design, U4 Build and verify, U5 Completion evaluation, U6 Delivery; Team Structure: Evaluation AI, Build unit (U4), Functional-unit agents; Evaluation System.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/review.md`; `<autoflow-root>/docs/reviewer-backend.md`; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/units/completion-evaluation.md` > Code comments in a target; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The merge prohibition, the separation of a module's work from its evaluation, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the reference pass values AutoFlow keeps with the rubrics are rules of this kind. Applying the reference values, and every cap on re-runs, is the Coordinator's (`ADR-0038` D2, D6).
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the output its run already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by the evaluation modules, by CI and by the external reviewer. When the AI is not confident, or the choice is not its own to make, it states the question for the advisor with its grounds; the advisor's answer is recorded and applied, and the operator is asked only when a call is blocked at the harness level (`<autoflow-root>/docs/role-contracts.md` > Advisor).
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a run leaves in the target's tree — are `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Development Lifecycle — AutoFlow

**AutoFlow is a set of modules, run by the Coordinator.** A module is an input, the work it does, and an output; its contract, `<autoflow-root>/docs/contracts/<module>.json`, declares its parameters, its inputs and where each comes from, and its outputs with the form each must meet (`ADR-0038` D1). The modules are functional — the criterion review's four, analysis, design, build, delivery, review —, evaluation — hypothesis, plan, audit, quality — and deterministic — criteria-apply. The Coordinator, the role outside AutoFlow that composes them (ADR-0037 D2, widened by ADR-0038 D2), decides which module runs next and on which inputs, whether an output is re-run and how many times, what follows an evaluation's scores, and where an attempt runs: it builds the worktree, the branch and the attempt's record directory and names them in each invocation (D4). AutoFlow defines no step, order or timing for any of it.

**A module runs once, on its invocation.** The Coordinator writes an invocation file naming the module's parameters, its inputs, its output directory and, for a functional module, the attempt's record directory (the invocation's form: `<autoflow-root>/scripts/contracts/contract.sh`, header). The module checks its inputs' form first (`bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>`) and does not run when one fails; where an input came from is not checked. It does its work once — an output short of its form is re-run by the Coordinator, not by a loop inside the module —, writes its outputs into its output directory, and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json`.

**A module's procedure states the goal of its work.** It says what the work must achieve, and the AI judges how to meet it; the contract checks the inputs and that the output disposes of every item the work owes — each applied acceptance criterion, each scope item the design includes (ADR-0038 D1). The applied criteria every module after the analysis takes are criteria-apply's output, computed from the analysis report's table and the `[ac-decision]` entries (`<autoflow-root>/docs/decision-ledger.md` > *Acceptance-criterion decisions*); the issue's criteria are first reviewed against the target's code and policy by the criterion review's modules (`<autoflow-root>/docs/criterion-review.md`).

**A decision that is not the module's own.** A change to an acceptance criterion's content, a design point the module is not confident to settle, a change to the target's security checklist, a finding whose fix it cannot place: the module states it in its output with its grounds, as the question for the advisor, and goes on with what it can do. A fresh `autoflow-advisor` answers it as an `A` ledger entry and the answer is applied; an operator override of a recorded decision is an `O` entry under `operator decision` (`<autoflow-root>/docs/role-contracts.md` > Advisor). Putting the question to the advisor and recording a decision are the Coordinator's (ADR-0038 D2, D8).

**Tools.** A tool the work needs is used. One the environment lacks — or what using a tool the environment has lacks, or a material an acceptance criterion or the issue body references that cannot be opened — is recorded as a tool request: what is missing, and what the run did instead, including each verification it left unrun for the lack. The run does what it can without it and ends; the requests go in `<out>/tool-requests.json` and the run's report, and the delivery module states them in the pull request for the operator (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ADR-0038 D1).

**Scripts**: a script AutoFlow ships reads and reports, or writes the files its own contract names (`contract.sh`, `criteria-apply.sh`); it changes nothing in git or on GitHub. A push, a pull request and a comment are a module's own commands, which the hook sees.

**Push and PR creation**: the delivery module pushes the branch and opens each pull request as a draft with its own `git push` / `gh pr create`, and confirms CI is green, or records on the pull request that CI did not run, never reading that as green. What the PR body carries, the host PR's `Closes #N` included, is the module's (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*). Merging is external; AutoFlow does not merge, and the hook denies `gh pr merge` and a push to the default branch (*Records and the hook* below).

### Unit Document Loading Contract

**[MUST]** A module's run follows its contract's `procedure` — the unit document below for a functional module, the gate's section of `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* for an evaluation module — which the session's command body or the role's agent definition carries after the core (*Context Injection*). The procedure is the source of truth for the module's work; this core file does not restate it. Do not run a module from memory of a prior run — the body is the document of the installed version.

| Unit | Phases | Unit document | Modules |
|------|--------|------|------|
| U1 Criterion review | CRITERION-REVIEW | `<autoflow-root>/docs/criterion-review.md` | `criterion-screen`, `criterion-trace`, `criterion-in-depth`, `criterion-reconcile` |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | `<autoflow-root>/docs/units/analysis.md` | `analysis`, `hypothesis` |
| U3 Design | ARCHITECT, GATE:PLAN | `<autoflow-root>/docs/units/design.md` | `design`, `plan` |
| U4 Build and verify | BUILD, AUDIT | `<autoflow-root>/docs/units/build.md` | `build`, `audit` |
| U5 Completion evaluation | GATE:QUALITY | `<autoflow-root>/docs/units/completion-evaluation.md` | `quality` |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | `<autoflow-root>/docs/units/delivery.md` | `delivery` |
| U7 Review | REVIEW | `<autoflow-root>/docs/units/review.md` | `review` |

What each module does, and what else a unit's body carries: the module list and *Unit references* below, and *Context Injection*. The deterministic module `criteria-apply` is a script, `bash <autoflow-root>/scripts/contracts/criteria-apply.sh`, with no procedure document.

Seven units carry the modules until the module commands replace the unit commands (ADR-0038 D9): a unit's command body carries the procedures of its modules. The phase and gate names stay as identifiers: the spawn-policy keys, the commands and the documents' headings carry them.

```
U7 Review              REVIEW          — the review module: the reviewers the operator's configuration names, each run by its own script, and the reviews the target's side leaves on the PR, aggregated into one verdict — each finding once, with its severity and whether it holds — posted as the round's comment; external review merges out of band
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

### Unit references

| Unit | Also on entry |
|------|------|
| U7 Review | reviewers: `<autoflow-root>/docs/reviewer-backend.md`; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; comments in a target: `<autoflow-root>/docs/units/completion-evaluation.md` > Code comments in a target |

## Cost Control

These rules apply to every run.

- **[MUST] Context discipline**: two rows are fixed (Rule Scope, principle 1): (1) **the work never scores itself** — the full read-and-score of a module's output is an evaluation module's fresh Evaluation AI (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and a read of that output by the session that produced it, or by the Coordinator, informs a spot-check, never a score; (2) **a spawn returns an anchor and a one-line summary, not its body** — the analysis, design and build spawns return only their artifact paths and a one-line summary. A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the session judges the read necessary, and its report names what was read and why. The Reporting Format (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format) applies to every direct/ad-hoc `Agent` spawn — the spawn writes its body to the run's output directory and returns only an anchor + one-line summary (e.g. the analysis spawn writes `<out>/analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the session's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a question for the operator follows *Execution Principles > Human-decision presentation* (situation-first), and the body the operator reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md`, fixes settled decisions — the entries that settle what a module cannot settle itself. What an entry records, its identifier grammar, and the decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`, `[criterion-ready]`) — are `<autoflow-root>/docs/decision-ledger.md`.

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled decision is likewise not overturned by re-reading the issue body. Two exceptions: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries), and an operator's override of an advisor decision, whose ground is the operator's authority (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every module's output — it is written only by the main session, which is the Coordinator's, and by the advisor (what each appends: `<autoflow-root>/docs/decision-ledger.md` > Entries > *Writers*). **[MUST]** Only the advisor adds the authority `advisor decision` or an `A<n>` entry; only the main session adds `operator decision` or an `O<n>` entry; the advisor never adds an `O` / `F` / `E` entry; and a write never changes text already in the ledger — enforced by the gate hook (*Records and the hook* below).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers of one namespace that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` reports a duplicated identifier or an unidentified level-2 heading (exit 1; 2 on a usage error). A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **[MUST] Human-decision presentation**: when a run asks the human for a decision or answer — `AskUserQuestion`, or a report that names a harness-level block such as a tool or referenced-material request — and in every advisor request and advisor answer record (`<autoflow-root>/docs/role-contracts.md` > Advisor), the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format), which is anchor-first. The body the human is pointed to is written in this same situation-first order — *Context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.
- **Verify role-spawn claims before acting on them**: every role-spawn report's Evidence anchor (see `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format item 5) is verified before the report is accepted — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not act on a single AI's unverified claim.
- **Safety first**: accurate execution beats fast response. Accuracy over speed.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): how far the work goes — the analysis, the design, the build's execution, the integration bundle — is the working AI's judgment, recorded with its grounds in the output its run produces. What no module does is judge its own output: each evaluation is a module of its own, scored by a fresh Evaluation AI that never saw the work done, and CI (its result as it is: green, or, where the target's CI does not run for the pull request, that recorded on it — never read as green) and the aggregated review stand outside the work as well.
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is the main session's only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the session that runs the module (the main loop), and every role spawn's Bash runs foreground-only; the binding rule lives in `<autoflow-root>/docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (main session)**: the session waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — a foreground `sleep` loop polling for a result — is not used. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. One timer is admitted beside that wait, the **cache keep-alive wake**: a running task keeps its own prompt cache warm through its own requests, while the session sends none, so a wait longer than the prompt-cache TTL expires the session's cached context and its first turn after the notification re-writes all of it. While a tracked task runs, the session therefore may arm one backgrounded `sleep` shorter than that TTL (`run_in_background`; 50 minutes at the 1-hour TTL) and end its turn. The turn the timer wakes is not a poll: it reads no transcript or output file of the task — only a cheap anchor-check (a log's modification time, `git log -1`) — re-arms the timer and ends the turn, and the timer is stopped once the task's notification arrives. What the wake observes about the task's progress, and any decision drawn from it, is the session's judgment, recorded with its grounds in the output its run produces. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to its spawner. A spawn prompt states the delivery action as "return … as your report", naming no carrier: the harness picks the carrier by permission mode, and in auto mode a spawn's final plain text is not delivered. There is one delivery path, and it is the return value; what carries a spawn's report is `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document (`<autoflow-root>/docs/units/analysis.md` > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per `<autoflow-root>/docs/issue-proposal.md` and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the work's tracking hub), and carry that confirmation into the proposal's grounds.

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

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Enforced by the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied in every session — research and evaluation spawns included. The main session's own model follows the user's session settings (outside this policy).

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior run: `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**Spawn role declaration**: an AutoFlow role is spawned as its dedicated `subagent_type` — `autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, the criterion-review agents `autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `<autoflow-root>/agents/` —, so that it carries its guidance from the start (*Context Injection*); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) are used as they are. `subagent_type` is the one declaration channel, and the hook's ledger check reads it: only an `autoflow-advisor` spawn writes the `advisor decision` authority. The spawn prompt is never used to infer the spawn's role. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning runs: each run spawns its role fresh, hands it the paths of its inputs and of its output directory, and takes its result as the spawn's return value. Each role's mode and per-call scope are `<autoflow-root>/docs/role-contracts.md` > Spawn mode by role lifetime.

A lower-tier evaluation's PASS, or a lower-tier role spawn's claim, materially contradicted by a later run reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; seeing the contradiction and making the revert are the Coordinator's (ADR-0038 D2), and the contradicting signals and their evidence anchor are `<autoflow-root>/docs/role-contracts.md` > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

A spawn prompt names the run's inputs by path — the inputs the invocation names, the attempt's record directory for a module that reads it, and the target's files — and the output directory, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the session that runs a module spawns each role with a `subagent_type`, and the spawn's **return
value is its report**.

- The session spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to the run's output directory and returns an anchor + one-line summary (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not a channel between a session and its role spawns — the session resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The main session's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- A cross-service change is made by each scope's module run, and what crosses the scopes is the delivery module's (`<autoflow-root>/docs/units/delivery.md` > *Multi-repo delivery*); the runs per scope are the Coordinator's.

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states is asked of the operator in conversation, with the request that the operator create the file or record the fact in it.

A project whose information names sub-repos delivers each changed sub-repo on its own pull request, and the host pull request's pointer names the commit it delivers: `<autoflow-root>/docs/units/delivery.md` > *Multi-repo delivery*.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

### Coordinator (outside AutoFlow)
- Runs the modules and judges their results: which module runs next and on which inputs, a re-run and how many, applying the reference values, where a finding's fix is made, putting a question to the advisor, recording a decision in the ledger, editing the issue body to the criterion review's dispositions, the worktree, the branch and the record directory (`ADR-0038` D2, D4).
- A fix no module owns — a documentation fix, the fix of a comment's divergence or disallowed content in a target's code (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*) — is the Coordinator's: run as a one-off session, or made by its own judgment (ADR-0038 D6).

### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor

## Records and the hook

**Record directory.** Every record of an attempt lives in the attempt's record directory `<attempt-dir>`, which the Coordinator builds under the record root — outside every checkout's tree, `autoflow-records root` (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`) — and names in each invocation as `records`. Each run writes into its own subdirectory, `<attempt-dir>/<module>-<n>` (`<module>-<qualifier>-<n>` for one module run on several items in a round, `n` counting that module's runs from 1), so nothing is renamed or overwritten; a functional module reads what earlier runs left in the directory, and an evaluation module keeps to its declared inputs (ADR-0038 D4). The ledger is `<attempt-dir>/issue-{N}-ledger.md`, the name the hook's ledger check reads.

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger, an `A` entry or the `advisor decision` authority written by anything but an `autoflow-advisor` spawn, and an `O` / `F` / `E` entry or the `operator decision` authority written by a spawn rather than the main session; an `Agent` spawn without an explicit `model`; and a backgrounded `run-suites.sh`. With no `jq` it reads the same denies from the raw input.

## Git Workflow — Rules

> **Procedural details (bash, branch structure)**: `<autoflow-root>/docs/git-workflow.md`

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
- **[MUST]** Before committing, the committing role — every role that commits, the main session included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (identifying the chains, execution trust boundary, scoping, outcome vocabulary, evidence anchor): `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation and tests, sub-repo) | the build module of that scope | the delivery module |
| Rules / config / infra / bulk docs | the Coordinator, or a one-off session it runs | the delivery module, or that session |
| Comment divergence fix (target code) | the Coordinator, or a one-off session it runs (sub-repo: the build module of that scope) | — (the branch's open pull request) |
| Sub-repo pointer (gitlink) commit | the delivery module | the delivery module |

## Reference Documents

- **AutoFlow phase guide**: `<autoflow-root>/docs/autoflow-guide.md`
- **Role contracts**: `<autoflow-root>/docs/role-contracts.md`
- **Evaluation system**: `<autoflow-root>/docs/evaluation-system.md`
- **Module contracts**: `<autoflow-root>/docs/contracts/<module>.json`, checked by `<autoflow-root>/scripts/contracts/contract.sh`
- **Criterion review (the four criterion modules)**: `<autoflow-root>/docs/criterion-review.md`
- **Git procedures**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/units/review.md -->

# U7 Review — REVIEW

> Unit document for U7. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

U7 Review is one module, the review module, whose contract is
`<autoflow-root>/docs/contracts/review.json` and whose procedure is this file
([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D1,
[`ADR-0033`](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)): one round of a pull request's
review. It has no unit agent: the session that runs it runs the reviewers, and the aggregation of the
round's reviews into one verdict is made by a spawned role. A script only reads and reports.

- **Goal**: the pull request reviewed by every configured reviewer, and one aggregated verdict over
  their reviews posted on it: each finding once, with its severity and whether it holds.
- **Inputs**: the pull request (`params.pr`) and the round (`params.round`); on a later round, the
  previous round's findings file; the attempt's record directory, where the earlier rounds' records
  and the work's records are.
- **Output**: each reviewer's review record (*Reviewer review*), the findings file and the round's
  comment, posted on the pull request (*Review aggregation*).
- **What a script reads and reports**: a reviewer run's start check (*Reviewer review*; the run
  itself is the reviewer's wrapper), by exit code.
- **Checks**: check-out confirms the findings file's `pr:` and `max_severity:` lines and that the
  comment is posted on the pull request (`review.json`); the reviews and their aggregation stand
  outside the work they review.
- **Result owed**: the report of *End* below.

## Reviewer review

A run reviews the one pull request its invocation names (`params.pr`, `<owner>/<name>#<N>`), on its
own diff; each pull request of a change — the host PR and each sub-repo PR alike — is reviewed by a
run of its own, and a sub-repo PR's review is required, not optional. A run is one round of that
PR's review (`params.round`, from `1`): it runs every reviewer, and their records go to one
aggregation (*Review aggregation* below), which posts the round's comment
([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)).

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Config
location*). Each runs as its own script, launched in the background:

```
bash <autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>] [--records <attempt-dir>]
bash <autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>]
bash <autoflow-root>/scripts/review/review-start-check.sh --pr <N> --reviewer <name> [--repo <owner/name>] [--log <the run's captured output>]
```

Each wrapper stops when the PR it is given is not that OPEN PR on that head branch, then runs its
reviewer over the PR with that reviewer's rule file and, where one is configured, its lenses file
([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Rule files*), on the model and effort the same
file names; the reviewer writes its review and nothing else. `--records` names the attempt's record
directory the invocation gives (`records`), where the `claude` reviewer reads the earlier runs'
work — the analysis report, the design documents, the decision ledger and the build report.
`<record>` is the review record's absolute path below; nothing a wrapper or its reviewer writes
stays in the target's tree.

The run is made in a checkout of the repository — the same origin — whose checked-out branch is the
pull request's head branch at its head: the `claude` reviewer reads that working tree beside the
pull request's diff.

**The reviews of the target's side.** A review a system on the target's side runs on the pull
request by itself — a review bot's review or review comment — is a review of the round too. It is
not launched and leaves no record: the aggregator reads it from the pull request (*Review
aggregation*). Whether to wait for one that has not yet arrived is the module's judgment.

**An unreadable operator file.** When the operator's `~/.autoflow/config.json` cannot be read as
configured, `check-review-backend.sh` exits `6` and each wrapper starts no reviewer and exits `6`;
each prints the marker line `user-config: UNREADABLE <path> — <error>`, which
`review-start-check.sh` reports as exit `4`. The session asks the operator, situation-first,
with the path and the error, whether to proceed without those reviewers. Proceeding runs the round
on the reviews of the target's side alone, and the aggregation names the missing reviewers with
that reason. Stopping pauses the round until the operator has fixed the file; the step then runs
again and reads it anew.

Each review lands in a **review record**, `<out>/reviews/<reviewer>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`).

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker:

| Exit | Meaning | What follows |
|---|---|---|
| `0` | started, or already completed with exit 0 | the session ends its turn and waits for the run's completion notification ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Wait discipline*) |
| `1` | no signal within the window (30 s) | the review is launched again, or the reviewer is named unavailable for the round with the reason — the module's judgment |
| `3` | the wrapper completed with a non-zero exit — the review run failed or left no record | the same |
| `4` | the wrapper's output carries `user-config: UNREADABLE …` — no reviewer started | the operator is asked (*An unreadable operator file* above); no relaunch |

A reviewer that is unavailable for a round — its CLI absent (`check-review-backend.sh` reports it),
its run failing, or the operator's choice to proceed past an unreadable operator file — does not
hold the round: the aggregation runs on the reviews that exist, and its comment names the reviewer
that is missing and why. A round in which no configured reviewer left a record, other than by that
choice of the operator's, does not go on: it is a review-infrastructure failure, a harness-level
block the run states in its result for the operator, situation-first ([`core.md`](<autoflow-root>/docs/core.md) >
Execution Principles > *Human-decision presentation*).

Cautions:

- A review that started is left to finish on its own clock, however long that takes; it is not
  relaunched because it is slow.
- Every round runs every reviewer on the pull request's current head
  (`gh pr view <N> --json headRefOid`).
- The reviewers of a round may run at once, and runs on the host PR and each sub-repo PR alongside
  each other; each review is confirmed with its own `--pr` and, for a sub-repo PR, `--repo`.

## Review triage

Per reviewed PR, after its round's reviews complete.

### Review aggregation

**1. The reviews are aggregated by a spawned analysis role.** The session does not read the
review records or the comment body itself (Cost Control). An anonymous direct subagent —
`subagent_type: autoflow-analyzer`, on the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names — is
the aggregator. Its prompt names the PR as `<owner>/<name>#<N>`, the round, the record paths, any
reviewer unavailable for the round with the reason, the decision ledger, the earlier rounds'
findings files and comments in the record directory, and, for a PR whose repository has
submodules, their paths (its `.gitmodules`) — the locations outside that review's target. It also
reads the reviews of the target's side from the pull request itself and names each one's author as
its source.

Its purpose is one verdict over every review of the PR. How it groups duplicates, settles a
severity the reviews disagree on, and weighs each finding (*Whether a finding holds*) is its own; what
it leaves behind is fixed:

- **One PR comment**, in Korean, per round: each finding once, with the reviewers that raised it;
  a finding only one reviewer raised kept like any other; each rejected finding listed apart with the
  grounds it does not hold; a reviewer unavailable for the round named with the reason. Its body is kept as
  `<out>/comment.md`.
- **The findings file** (below).

It returns `{max_severity, findings}`.

- **[MUST] One findings file per round.** Each run's aggregation writes `<out>/findings.md` for the reviewed PR `<owner>/<name>#<pr>`; a later round writes its own in its own run directory. The file carries a `pr: <owner>/<name>#<N>` line naming the reviewed PR, exactly one `max_severity: <level>` line — the highest level among the findings that hold, `Low Confidence` included, in colon notation, `max_severity: None` when none remains (never an omitted line) — and one table row per finding, `| <Severity> | <path>:<line> | <finding> | <source> | <disposition> |` — severity first, location second (a path relative to the reviewed PR's repository root), `<source>` the names of the reviewers that raised it (`claude`, `codex`, a review bot's login), and `<disposition>` empty, or `rejected` for a finding that does not hold — always the row's last cell, so a `|` quoted in the finding cell moves no other cell. A `rejected` row is a record: it counts toward no verdict. Where the fix of a finding that holds is made is not the aggregator's to state: it is the judgment of the AI acting on the finding ([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D6).
- **[MUST] A PR's review covers its own repository.** A review's target is what the reviewed PR's repository tracks directly — every file of its tree, a submodule's pointer included, never a submodule's contents (`<autoflow-root>/docs/review/review.md` > Before Reviewing). Every finding therefore belongs to the reviewed PR, and its `max_severity` rests on that PR's own findings alone. A host PR whose diff is a submodule pointer is reviewed over the host repository like any other PR; the sub-repo code behind the pointer is judged by the sub-repo PR's review. A finding a review raises inside a submodule misreads that target: the aggregator rejects it as a finding that does not hold.

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A module acting on a finding that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file and the comment, and counted toward no verdict ([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)). A finding that the module acting on it finds does not hold is a rebuttal: it is posted with its grounds on the PR, and the next round's reviews and aggregation judge it — a round of its own also when it only rebuts and changes no code. A gate recommendation's rebuttal is judged by the recommending evaluation's re-score. One that holds in part is fixed for the real problem it points to. When a rebutted finding is kept and the two sides still disagree, the question goes to the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3); no count decides when.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A change can loop: each fix answers the case a reviewer — or an evaluation's recommendation — named
while the property it asserts stays unmet, and the next review or re-score names another case. No
spawn checks for this on every round. Whoever reads the finding — the aggregator here, the analysis
module, or the module acting on an evaluation's recommendation — and sees that it repeats an earlier
complaint (the same property asserted, a different witness case; the earlier rounds' findings files
and comments, and the earlier evaluations in the record directory, are what it compares against)
says so where it writes the finding: in the finding's cell of the findings file, under the analysis
report's `## Decision points`, or in its own report. What follows — restating the acceptance
criterion as one rule over the whole input, a further case-specific change, or leaving the property
a known gap — is the Coordinator's, the advisor's where the grounds do not settle it
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor); a redefined criterion is recorded as
`[ac-decision]` entries. A complaint already decided is not decided again without a new verified
fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case.

## End

The run ends when its round's comment is posted. Its report names the pull request's URL and head
commit, the highest severity among the findings that hold (the findings file's `max_severity:`), the
findings file and the comment, and the round `k` — with the rework count `k − 1` — and, for a host
pull request whose pointer names a sub-repo pull request's commit, that dependency. What follows a
verdict — another round of work, or handing the pull request to external review — is the
Coordinator's.

**[MUST]** AutoFlow merges nothing and promotes no draft. The hook denies `gh pr merge` and a push
to the default branch.

What follows an external merge or close — the attempt's branches and records included — is outside
AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).

<!-- From <autoflow-root>/docs/reviewer-backend.md -->

# Reviewer Contract

REVIEW reviews every pull request a cycle opens with the reviewers the operator's
configuration names and aggregates their reviews into one verdict
([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md),
[ADR-0033](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)). This document
is the single home for the reviewers — who reviews, on what input, what each one
leaves, their configuration, and their start-confirmation oracle. How a round
runs and how its reviews are aggregated is
[`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review* and *Review
aggregation*.

## Reviewers

Every reviewer is run by its own script, in the reviewed repository's working
directory, with an environment fitted to its CLI; no two reviewers share one.

| Reviewer | Input | Runtime |
|----------|-------|---------|
| `claude` | the PR (diff, body, linked issue), its rule file, and the cycle's design artifacts in the attempt's record directory `--records` names — analysis report, feature design, verification design, decision ledger, build report | `<autoflow-root>/scripts/review/claude-review-pr.sh` — `claude -p` with Read, Grep and Glob (on any path), the `gh` reads the review needs, the commands Claude Code itself treats as read-only, and whatever the operator's own `~/.claude/settings.json` allows — every other tool and every write denied without a prompt (`--permission-mode dontAsk`); the reviewed repository's own `.claude/` settings and `CLAUDE.md` are not loaded (`--setting-sources user`), since in a trusted checkout its permission rules would add tools; the prompt carries the rule file's text, and the final message is the review |
| `codex` | the PR (diff, body, linked issue), its rule file | `<autoflow-root>/scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, which loads that tree's `AGENTS.md` itself; the prompt carries the rule file's text |
| the target's side | what that system reads | a review a system on the target's side runs on the pull request by itself — a review bot — read by the aggregator from the pull request ([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Review aggregation*) |

A new reviewer is a name the resolver supports
(`<autoflow-root>/scripts/review/lib/review-config.sh`), its wrapper and its
rule file.

## Rule files

The review rules every reviewer applies — posture, severity levels, method,
lenses and Output Format — are
`<autoflow-root>/docs/review/review.md`. Each reviewer's own rule file, beside
it, names what that reviewer reads and where its review goes:
`<autoflow-root>/docs/review/review-claude.md`,
`<autoflow-root>/docs/review/review-codex.md`, each of which carries the review
rules (`<autoflow-root>/docs/core.md` > Context Injection). The wrapper's prompt
carries the rule file's text, and states what `<autoflow-root>` is.

Per reviewer, two keys of the configuration (*Config location*) replace or add
to these:

- `.review.<reviewer>.rules` — another rule file in place of
  `<autoflow-root>/docs/review/review-<reviewer>.md`; the prompt carries that file alone, so it carries
  or cites the rules and Output Format its reviewer applies. A wrapper whose rule file is absent
  stops (exit `2`) before the reviewer starts.
- `.review.<reviewer>.lenses` — a file of further review lenses (the defect
  axes `<autoflow-root>/docs/review/review.md` > Review Lenses lists), which the prompt carries
  beside the rule file. Absent from a repository, it is left out of that
  repository's review, with a line on stderr.

A relative path is read from the root of the checkout the wrapper runs in, so
one entry can name each target's own file.

## Contract

```
Contract: reviewer
  Output : one review record per reviewer, PR and round —
           <attempt-dir>/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md —
           in the <autoflow-root>/docs/review/review.md Output Format, in Korean.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (<autoflow-root>/docs/units/review.md > Review aggregation)
  Input  : every review record of the PR and round, and the reviews the
           target's side left on the PR.
  Output : one PR comment; the PR's findings file (source and disposition per
           finding). A finding the aggregator rejects is recorded with its
           grounds and counts toward no verdict.
```

Each wrapper takes the record path:

```
<autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>] [--records <attempt-dir>]
<autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>]
```

Each stops (exit `3`) when the PR is not that OPEN PR on that head branch, and
treats a run that leaves no record as failed (exit `5`).

## Config location

The reviewers are configured in one file, the operator's
`~/.autoflow/config.json` (`$HOME/.autoflow/config.json`), created once by the
plugin's SessionStart hook (*Operator file* below). A target's
`.claude/autoflow.local.json` is not read for reviewers: the reviewers AutoFlow
runs are the same in every project
([ADR-0033](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)).

```json
{ "review": { "reviewers": ["claude", "codex"] } }
```

The file is read by `<autoflow-root>/scripts/review/lib/review-config.sh`,
type-aware (the key's JSON type first, then its value). `.review.reviewers`
lists the reviewers that run. When it is absent, `null` or `[]` it names none of
its own, and the default reviewers run — `claude` and `codex`; so do they when
the file is absent. Each reviewer's model, effort, rule file and lenses file
come from the same file (*Rule files*, *Model and effort*).

The file **cannot be read as configured** when it is present while `jq` is not
on PATH, is not valid JSON, has a non-object `.review`, a `reviewers` value that
is not an array of supported names, or a per-reviewer value *Model and effort*
or *Rule files* rejects. It never fails closed. It is checked whole — every
condition above, the list and every supported reviewer's settings — on every
run, so every consumer reaches the same verdict on the same file. When it
cannot be read, nothing in it applies and no reviewer runs: the readout names
it (`source: user <path>`), and every consumer prints the fixed marker line
`user-config: UNREADABLE <path> — <error>` and exits `6` — distinct from success,
from exit `2` and from every exit below; no wrapper starts its reviewer. The
orchestrator asks the operator whether to proceed without those reviewers
([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D4,
[`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*): proceeding runs the
round on the reviews of the target's side alone; stopping leaves the operator
to fix the file and run the step again, which reads it anew.

### Operator file

The plugin's SessionStart hook, `<autoflow-root>/hooks/ensure-user-config.sh`,
runs at every session start in every project the plugin is enabled in. When
`~/.autoflow/config.json` is absent it creates it, outside the target's tree,
with

```json
{ "review": { "reviewers": [] } }
```

— no reviewer named, so the default reviewers run until the operator lists them
there — and only then tells the operator where it is and what it holds. An
existing file is never changed, broken or not. Concurrent session starts create
it once: the content is written to a temporary file and published with a hard
link, which fails when the file exists, so a file another session created is
never overwritten, only the creating session notifies, and no reader sees a
partial file. The same file holds the operator's other AutoFlow values — the
record root, `record_root` ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > *Record
location*). Each key is read and validated by its own reader: an error in
`.review` does not touch the record root, and an error in `record_root` does not
touch the reviewers; a file that is not valid JSON, or no `jq`, leaves both
unreadable.

## Model and effort

Each reviewer's model and reasoning effort can be pinned in the operator file
(*Config location*). Every key is optional:

```json
{
  "review": {
    "reviewers": ["claude", "codex"],
    "codex": { "model": "gpt-6-sol", "effort": "high" }
  }
}
```

**Single source of truth.** `<autoflow-root>/scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by the live wrappers (`claude-review-pr.sh`, `codex-review-pr.sh`)
and `check-review-backend.sh` (presence path and `--probe`) from the plugin
root. It alone reads the file; no consumer reads it on its own.

**Flag mapping** (`build_review_backend_args`, the only place it is written):

| Reviewer | model | effort |
|----------|-------|--------|
| `claude` | `claude --model <model>` | `claude --effort <effort>` |
| `codex` | `codex exec --model <model>` | `codex exec -c model_reasoning_effort=<effort>` |

**Precedence** (per value, most specific first):

| Value | Order |
|-------|-------|
| model | `.review.<reviewer>.model` → the reviewer's default (`claude`: `opus`; `codex`: `gpt-6-sol`) |
| effort | `.review.<reviewer>.effort` → **inherit** |

**Inherit means no flag.** When the effort key is absent (or JSON `null`) the
wrapper passes none, and the CLI applies its own configuration (`claude`: its
settings; `codex`: `~/.codex/config.toml`, `model_reasoning_effort`). The model
default lives in the resolver so that a file that pins nothing still reviews on
it.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated):

| Reviewer | Accepted `effort` | Source |
|----------|-------------------|--------|
| `claude` | `low` `medium` `high` `xhigh` `max` | `claude --help` > `--effort` (Claude Code 2.1.304). |
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs`. |

**Rejected values** — part of "cannot be read as configured" (*Config
location*: the `UNREADABLE` result), always **before the reviewer launches**:

- `.review.<reviewer>` is present but not an object;
- `.review.<reviewer>.model`, `.effort`, `.rules` or `.lenses` is present but
  empty (`""`) or not a string;
- `.review.<reviewer>.effort` is a string outside that reviewer's vocabulary.

**Readout lines.** Every consumer prints where the configuration came from and
the operator file's state, in the same form:

```
source: user <path> | none
user-config: absent [<path>] | ok <path> | UNREADABLE <path> — <error>
```

Every diagnostic and remedy names the operator file.

**Start marker.** A wrapper's marker names the reviewer and the effective
model and effort — `[codex-review] starting codex for PR #<N>
(model=gpt-6-sol effort=high) at …`, or `effort=inherit` when none is pinned —
and prints nothing else from the environment (no credentials, no unrelated
variables). `--probe` prints the same summary as
`[check-review-backend] --probe: <reviewer> (model=… effort=…)` before its
round-trip, and passes the identical flags.

**Orchestrator vs. reviewer.** These pins govern only the reviewer subprocess;
the orchestrating session's own model and effort follow the user's session
settings, and the aggregator's the `handoff-review-triage` row of
`.claude/autoflow/spawn-policy.json`. None of them reads another.

## Availability (PREFLIGHT, advisory)

`<autoflow-root>/scripts/preflight/check-review-backend.sh` resolves the
reviewers through the shared resolver, prints them as one
`reviewers: <names|none>` line on stdout — the readout REVIEW runs them from
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*) — followed by the
`source:` and `user-config:` lines (*Model and effort* > Readout lines), and
probes each reviewer's CLI **presence only** (`command -v`):

| Exit | Meaning |
|------|---------|
| `0` | every configured reviewer's CLI is present |
| `1` | a configured reviewer's CLI is absent — named on stderr with its remedies (install it, or list the reviewers to run without it in the operator file) |
| `2` | usage error |
| `6` | the operator file cannot be read as configured — the marker line `user-config: UNREADABLE <path> — <error>`; no reviewer is checked |

PREFLIGHT records the result in the `preflight-review-config` record entry
([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D4). An absent
CLI does **not** stop the cycle: REVIEW runs the other reviewers without it and
the aggregated comment names the omission
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*). An unreadable
operator file (exit `6`) is put to the operator, who chooses between proceeding
without those reviewers and fixing the file. Auth is **not** probed here: a
present-but-unauthenticated reviewer passes and its auth failure surfaces at the
REVIEW run, where it counts as a failed run.

## On-demand auth probe (`--probe`)

`<autoflow-root>/scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured reviewer — the same model-API connection a `claude -p` or a
`codex exec` opens.

**Triggers — on-demand only:** the operator runs it after writing or changing
the reviewer configuration. It is **not** run per-cycle, is **not** wired into
PREFLIGHT, and **no hook consumes it** — a probe failure is narrated, never used
to gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded for every configured reviewer. |
| `1` | A configured reviewer's CLI is **absent** (no round-trip is attempted for it). |
| `2` | Usage error. |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | A reviewer's CLI is **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at the REVIEW run. |
| `6` | The operator file cannot be read as configured (*Config location*); no round-trip is attempted. The probe's report goes to the operator who ran it. |

## Start-confirmation oracle

`<autoflow-root>/scripts/review/review-start-check.sh --pr <N> [--reviewer <name>] [--repo <owner/name>] [--log <the run's output>]`
reads these signals for a reviewer's run and reports the first one it finds
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*): a running process
of that reviewer's CLI (`--reviewer`; reviewers run side by side on one PR) whose prompt names
`pull request #<N>`, or, for `codex`, a session rollout under
`~/.codex/sessions/` written since the launch whose prompt does; an advancing
rollout `mtime` is codex's long-run health signal, and the review runs in the
background to completion. Each wrapper closes its CLI's stdin (`< /dev/null`)
and prints the completion marker `[review] <reviewer> completed for PR #<N>
(exit=…)` when the subprocess returns; a non-zero exit means the run failed or
left no record. A wrapper that stopped on an unreadable operator file prints the
marker line `user-config: UNREADABLE …` instead and no completion marker;
`review-start-check.sh --log` reports it as exit `4`.

## Trade-offs

- **Two vendors, two inputs.** The `claude` review reads the cycle's design
  artifacts; the `codex` review reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The `claude` review runs on the same account allowance
  as the orchestrator, once per pull request and round.

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Change Surface Rules -->

## Change Surface Rules

Every changed line traces to the cycle's scope: the issue's acceptance criteria, the confirmed cause recorded in DIAGNOSE, the agreed plan, and each problem a recorded scope judgment includes (**Scope judgment** below). What belongs to the cycle is decided by that judgment, not by whether an acceptance criterion names the line. How small the change stays inside that scope is governed by **Trace rule**, **Surrounding code** and the **Over-engineering guard** below.

### Scope judgment
A role that meets a problem the acceptance criteria do not name answers two questions and records the answers with their grounds, under a `## Scope judgments` heading in the report or artifact its phase already produces ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

1. **Is it directly related to this issue?** It is when any one of these holds:
   - it comes from the same confirmed cause;
   - this change created it or exposed it;
   - unless it is fixed, the behavior an acceptance criterion promises does not hold in actual use.
2. **Is fixing it in this cycle desirable?** It is when it lies in the same module, is confirmed by the same verification, and fixing it separately would reopen the same code. It is not when it needs a design decision of its own, touches another ownership scope, or carries more risk than this issue.

| Judgment | Disposition |
|---|---|
| Directly related, fixing it here desirable | fixed in this cycle; the recorded judgment is the trace of its hunks |
| Directly related, fixing it here not desirable | separated, with its **separation reason** recorded |
| Not directly related | separated — reported in one line with its `path:line`; a separate issue is the follow-up path |

- **The default follows the first question.** A directly related problem is included unless a separation reason is recorded. A problem noticed in passing — a style inconsistency, pre-existing dead code, a refactor opportunity — meets none of the three conditions and stays out (**Surrounding code**, **Refactor scope**).
- **A record line** names the problem (its `path:line` at the report's commit, or the design section), the condition of question 1 it meets or that none does, the answer to question 2 with its ground, and the disposition.
- **An inclusion is verified like the rest of the scope.** At ARCHITECT it gets a verification-design row whose `Issue AC` is `—`; found later, the role that fixes it runs the tests it judges the fix requires and records the run (Verification and Tools > *Local verification*).
- **Criterion defects.** From ARCHITECT on, beside the two questions the role weighs whether what it met shows a criterion defective ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*). A same-cause problem reaching past what the criteria name may mean the issue drew the problem too narrowly — and then whether the approach itself must change is the question, not only whether to include the rest; an item a criterion names that turns out to be a problem separate from this issue may mean it drew too wide. Including a problem does not change a criterion, and a criterion is not carried out merely because it names an item: a defect so judged is recorded here and raised in the report with the criterion, the proposed change and the fact that shows it, and the orchestrator decides it, putting it to the advisor where those grounds do not settle it ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*).
- A role that is not confident, or whose inclusion would change a design decision, raises the question instead of deciding it (principle 3).
- **Where it is applied**: DIAGNOSE's scope judgments (the analysis report's `## Scope judgments`) and the ARCHITECT feature design's `## Scope` section set the cycle's scope; the BUILD unit judges what it meets during the work; and the gates' recommendations are triaged by the reviewer-finding procedure, where the same two questions decide which recommendation is not the issue's and ground the `Low` judgment (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which acceptance criterion, confirmed cause, plan item or recorded scope judgment requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk whose rationale names none of them is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC or a recorded scope judgment requires the change. A comment attached to code this change modifies is not adjacent — it is part of the change (**Code comments** > *Changing commented code*).
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing — which **Scope judgment** does not make directly related — are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the cycle's scope needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the cycle's scope (**Scope judgment**). A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. What a comment on changed code may carry is **Code comments** below.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Code comments
The rule governs every comment in code a cycle writes or modifies — implementation and test files, in a target and in this repository. Existing comments on code the cycle leaves untouched stay as they are (**Surrounding code**).

- **[MUST] The test**: a comment carries only a sentence that stays true for as long as the code it sits on is unchanged — however much time passes, and whatever changes in other files.
- **What a comment carries** — only what a reader cannot recover from the code, and only in one of these cases, each about the code the comment sits on:
  - an external constraint: the behavior of a runtime, a tool, or a protocol the code depends on;
  - an invariant that the code does not make evident;
  - what breaks if the code is written otherwise, in a line or two;
  - a function's contract — its arguments, return value, and exit codes — in one line.
- **What a comment does not carry**:
  - a restatement of what the code does;
  - design discussion and rejected alternatives;
  - change history — what the code did before, what it no longer does, what an earlier version wrote;
  - an issue, PR, review-round, or acceptance-criterion identifier;
  - the path or the contract of another file;
  - commented-out code.
- **Where that content goes**: a decision and its grounds → the repository's decision record (in this repository, `docs/records/adr/` and `docs/records/design-rationale.md`); change history → the commit message and the PR body; discussion → the cycle's `<attempt-dir>/*` design documents and the issue. The only reference a comment carries is at most one ADR identifier (`ADR-0024`).
- **Test files**: a test's intent is stated in its name and its assertion messages. A comment in a test file carries only the reason for a fixture that the fixture does not make evident.
- **Changing commented code**: **[MUST]** a comment attached to code this change modifies is updated or deleted in the same commit. When it is uncertain whether the comment is still true, delete it.
- **Directives are code**: a line a tool reads to change its behavior is code even when written in comment syntax — a lint suppression or a type-checker directive, for example — and this rule does not govern it; an explanation written beside it is a comment and does. Which lines are directives is the working AI's judgment in that target; no list is kept.

The BUILD unit checks the cycle's diff against this rule (`<autoflow-root>/docs/units/build.md` > What the build owes, *Comment check*). In a target's code, a comment that diverges from its code or carries what this rule sends out of a comment is a `Low` finding for the reviewer and the evaluator, and its fix is the orchestrator's direct commit; a defect a comment carries on its own ground, such as an exposed credential, takes the severity and route its impact sets (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*).

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC or a recorded scope judgment requires it.

### Lint chain on the staged surface
This section is the rule's only home. Its search terms:

```
git grep -n -i -E 'lint[- ]chain|lint-outcome|lint outcome|ci-deferred|unexecuted|not-covered|modified-in-branch'
```

- **[MUST]** Before a commit is made, the committing role runs every lint chain of the target repository that covers at least one staged file over the staged files, and confirms zero errors attributable to them. Auto-fixable formatting is applied and staged in the same commit.

**Which chains exist, and how each runs, is the target's practice.** AutoFlow prescribes no lint command and no discovery order to a target. The committing role finds, at the location it commits in, how that target lints a change: its documents (`CLAUDE.md` > Development Commands, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a commit hook) and its pull-request CI. From them it judges which chains exist, the command that runs each in the working checkout, the files each covers, and which CI lint steps gate this pull request. A CI step that does not run for this pull request — its trigger, path filter, or job or step condition excludes it — gates nothing here and is not counted as a chain; the condition that excludes it is recorded as the ground. Where a CI step and a local command both stand for one chain, the local command run is one that selects and checks the files the step does. The judgment and its grounds go into the report (**Evidence anchor** below).

**Execution trust boundary** — **[MUST]** the command run at commit time is one the baseline — the attempt's base (`autoflow-records base`) at its merge-base with `HEAD` — already carries. Before running it, the committing role confirms that the command's text at its source — the document entry, the script definition or the CI step body it was taken from — and any script file that text invokes by path are unchanged versus the baseline. A command this branch altered or added is not executed: the chain is reported `not-run` with the reason `modified-in-branch`, whichever source it came from. A command is run exactly as its source states it — a read-only check, not licence to run any other step, argument or command its source names.

**Not executable in the checkout** — a chain the committing role cannot run in the working checkout (a CI step whose work is a third-party action reference with no local command that does the same, a tool the environment lacks) is reported `not-run` naming the step or command and the reason. A chain that cannot be run imposes a reporting obligation, not a blocking one: the commit proceeds. Not blocking the commit is not clearing the gate — GATE:QUALITY's `Commit conventions` clears the chain only by its reason class (**`not-run` reason classes** below). Making a chain locally executable belongs to the target repository's ops and is outside this rule's authority; a tool the work needs is secured as Verification and Tools > *The tools the work needs* says.

**Scoping** — run the chain restricted to the staged files where the chain supports scoping. Where the chain only runs whole-tree, run it whole-tree and require that no reported error names a staged file; pre-existing errors on untouched files are not this cycle's surface (**Surrounding code**).

**Outcome vocabulary** — the report carries one word per chain the committing role identified, and the word set is total over the reachable states:

- `clean` — the chain ran and reported nothing attributable to the staged files;
- `fixed-and-staged` — the chain ran and reported fixable findings, and the fixes are in this commit;
- `detected` — the chain ran and reported findings attributable to the staged files that were not auto-fixed; the commit does not proceed until they are resolved;
- `not-run` — the chain covers a staged file but did not execute; the word attaches to the fact of non-execution, regardless of why it did not execute, and the report names the chain, the reason, and exactly one reason class from **`not-run` reason classes** below;
- `not-covered` — the chain exists and no staged file is in the set of files it covers;
- `not-applicable` — the committing role found no lint chain in the target; the report carries this word once, in place of any per-chain line.

**`not-run` reason classes** — **[MUST]** every `not-run` line carries exactly one of two classes. The class, not the word, decides whether the lint record's reader — GATE:QUALITY's `Commit conventions` ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:QUALITY) — clears the chain:

- `ci-deferred` — the chain cannot run at the commit boundary (**Not executable in the checkout** because no local command does what its CI step does, or withheld by the **Execution trust boundary** as `modified-in-branch`) **and** a named pull-request CI job runs that same chain over the staged files for this pull request. It is cleared as a deferral;
- `unexecuted` — anything else: executable but not run, a tool the environment lacks, or no covering pull-request job can be named. It is not cleared: it is an omission, filled where it is found (Verification and Tools > *A missing run is filled where it is found*).

- **[MUST]** Fail-closed default: a chain whose reason class cannot be established is `unexecuted`. The permissive class is the one earned by evidence; the absence of evidence yields the blocking one.

A `ci-deferred` deferral is discharged at HANDOFF's CI confirmation, which confirms the PR's check rollup is green — at least one check present and every element green (`<autoflow-root>/scripts/handoff/confirm-ci-green.sh`). That confirmation is over the rollup, not a per-job execution guarantee: nothing in it re-checks that the named covering job appears in the rollup, so the producer's covering-job citation and trigger evidence (Reporting Format item 5) are what tie the deferral to a job that actually runs, and the evaluators re-derive them from the report. When no CI runs for the pull request (`confirm-ci-green.sh` exit `11` judged not run), the deferral is not discharged: the chain is listed on the pull request as not run ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI*).

- **[MUST]** A chain that did not execute is reported `not-run`, never `clean`.

**Evidence anchor** — the committing role's report carries the lint outcome as an anchor class of Reporting Format item 5, whose single-anchor requirement it satisfies as a per-chain enumeration followed by the grounds of the identification (form and cardinality there).

### Refactor scope
A refactor of the cycle's diff applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. A refactor tool's findings are advisory, not licence to expand the change surface. A finding that describes a behavior defect rather than a refactor is not a refactor to apply: the BUILD unit records its **Scope judgment**, and one judged directly related goes to the build report's out-of-scope-observations section for the evaluator to dispose of (`<autoflow-root>/docs/units/build.md` > Build report).

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` and `Impact scope` items are scored against this section, on one scope: prefer the smallest sufficient change that resolves the confirmed problem within the cycle's scope. The cycle's scope is the acceptance criteria, the confirmed cause recorded in DIAGNOSE (`<attempt-dir>/issue-{N}-analysis.md`), and the problems the cycle's recorded scope judgments include (**Scope judgment**) — a boundary, not a line count. A correctly scoped change is not scored down for being larger than a symptom patch. The evaluator reads the scope records for both items: the feature design's `## Scope` section and every `## Scope judgments` section in the cycle's `<attempt-dir>/issue-{N}-*.md` reports, with the ledger's `[gate-autofix]` entries and gate verdict entries (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

A high-scoring change:
- resolves the confirmed cause, not only the reported symptom
- stays inside the module or component that owns that cause
- includes the local cleanup the fix itself requires — the code and symbols this change renders unreachable or unused, removed in the same commit; cleanup merely noticed nearby does not qualify (**Surrounding code**), and **Orphans from this cycle** is the symbol-removal instance of this same test, not its limit
- fixes each directly related problem its scope judgments include, and leaves out a directly related problem only with a recorded separation reason
- leaves every surface outside the scope untouched — behavior, APIs, configuration, and documentation are examples of such a surface, not the boundary — and keeps, inside it, the existing behavior that neither the acceptance criteria, the confirmed cause nor a problem its scope judgments include asks to change, a protection or the order of checks included; recording such a change as a known gap does not bring it into scope

`Minimal implementation` asks whether each hunk is needed. The question is asked against the smallest change that satisfies the acceptance criteria, with the tests its verification design requires, and resolves the confirmed cause: a hunk beyond it stands only on its own recorded ground. It fails when a hunk traces to no acceptance criterion, confirmed cause or recorded scope judgment — "I noticed it while I was here" cleanup (**Surrounding code**) or depth creep beyond what the scope needs (**Over-engineering guard**) — regardless of code quality, and when a hunk rests on a scope judgment that meets none of question 1's three conditions. It fails symmetrically when the change is too narrow to resolve the confirmed cause: a change that leaves the confirmed cause in place is not sufficient, and does not score well for being small.

`Impact scope` asks the same question from the other side: whether the change reaches what its scope requires. A directly related problem that the cycle's own records show — a scope judgment, a build observation, an earlier gate's recommendation — and that the change leaves out with no separation reason recorded lowers it, as does a separation reason that answers neither half of question 2.

**Comments in a target's code.** The item also weighs the comments the change adds, by content and by volume, reading the build report's `## Comment check` section (`<autoflow-root>/docs/units/build.md` > Build report) — its `comment-ratio` line and its hits — with the comments in the diff:
- *Content*: a comment that **Code comments** does not admit — a restatement of the code, a design ground, a reference or a history — is depth the AC does not need, as an unneeded hunk is.
- *Volume*: even where every comment is admitted, the evaluator judges whether their amount, absolute and relative to the code they sit on, exceeds what a reader of the changed code needs — a comment block larger than the logic it explains, for example. The judgment is qualitative, with no ratio threshold, and names the comment blocks it rests on.

The evaluator records each such finding in the item's `reason` and in `recommendations`, and does not lower the item's score for it: in a target a comment finding never fails the gate (`<autoflow-root>/docs/evaluation-system.md` > *Code comments in a target*, which also names the defects a comment can carry on their own ground and that this exclusion does not cover). In this repository the item is scored without this comment weighing.

---

<!-- From <autoflow-root>/docs/units/completion-evaluation.md > Code comments in a target -->

## Code comments in a target

A comment in a target's code that diverges from its code, or that carries what a comment does not
carry, never routes the cycle.

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never raises a review's verdict above `Low`
  (`<autoflow-root>/docs/review/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Code comments in a target*). It is
  therefore never the cause of a low score on any item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity its impact sets, as any finding does.
- **Fix — a commit no module owns.** Whether a comment surfaced by this evaluation's
  `recommendations`, the build report's `## Comment check` or a reviewer's finding is fixed is
  the Coordinator's judgment, and the fix is made by the Coordinator or a one-off session it runs
  ([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D6). A fix is one
  commit that deletes comment lines or corrects their sentences and changes nothing else, and it
  ends there: no re-run, no re-score, and no review round. The commit still runs the lint chain over its staged files
  ([`core.md`](<autoflow-root>/docs/core.md) > Commit Rules); one made after the delivery module's push is pushed, and
  CI is confirmed on the new head. A comment whose correct wording is uncertain is deleted, not
  rewritten (*Code comments* > *Changing commented code*). A fix that changes any line other than a
  comment, or that removes a defect of its own ground (above), is not this fix.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity of the behavior it
  changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged, and its
  fix is made like any other change.
- *Secondary (multi-repo):* a comment in a sub-repo is outside the main session's scope
  ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); the build module of that scope makes
  the same single commit on the same terms.

<!-- From <autoflow-root>/docs/decision-ledger.md -->

# Decision Ledger

The per-attempt decision ledger, `<attempt-dir>/issue-{N}-ledger.md`: what an entry records, how it is
identified, and the grammar of the entries a decision point produces — the advisor's first judgment
and the operator's override. The ledger holds decisions: entries that settle what a module cannot
settle itself, under their authority ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D8). The ledger's standing constraints —
append-only, no re-litigation without a new verified fact, host ownership, and identifier
allocation — are [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger.

## Entries

- Each entry records: the decision (one line), its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence), its **authority** (what settled it — `orchestrator decision`, `advisor decision`, `operator decision`).
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the re-opening is **judged by the decision's original authority** — a design decision — recorded in the feature design, not the ledger — by a design run naming its heading there, an advisor decision by a fresh advisor, an operator decision by the operator — and when that authority cannot say with confidence that the error changes the decision, it asks the advisor ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3); (3) the correction records the reproducing command and its summary line in the grounds form above and names what it supersedes — for a ledger entry, in the superseding entry's grounds, by the superseded entry's identifier; for a feature-design decision, in the design run's delta item, as `supersedes <heading>` ([`units/design.md`](<autoflow-root>/docs/units/design.md)). A change of preference or a re-interpretation of the same material is not an error and stays barred.

**Writers**. The advisor appends its answer to a decision point under the authority `advisor decision`, and it alone writes that authority (*Advisor decisions and operator overrides* below); a module appends nothing — its decisions and records are its own outputs ([`units/design.md`](<autoflow-root>/docs/units/design.md), [`units/build.md`](<autoflow-root>/docs/units/build.md) > Build report); the main session — the Coordinator's ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D2) — appends its own decision at a point it settles without the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Decision points and harness-level blocks*; an acceptance-criterion change: *Acceptance-criterion decisions* below), an operator override of an advisor decision when the operator gives one, and the `[criterion-ready]` entry recording the criterion review's settled decisions (*Criterion-readiness confirmations* below). The Coordinator's own records — an evaluation's result, the attempts it counts for a cap and the reset of that count, a rebuttal round, the checks it runs when it builds the environment — are not ledger entries (*ibid.* D8).

## Entry identifier

A settled-decision entry is headed `## <ID> — <title>`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only; an entry of a kind that has a marker ends its heading with it — `## <ID> — <title> [<marker>]`. The heading names no cycle or phase. A heading written before this grammar may carry `(cycle <C>, <PHASE>)` after its title, and a ledger written before it may carry level-3 record headings with no identifier; no reader reads either.

| Writer | Namespace |
|---|---|
| Main session (the Coordinator's) | `O` |
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
override an advisor's entry: the main session — the
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
never the design's or a module's to apply: the **main session** decides it first, on the grounds the
raising report or recommendation carries, and puts it to the **advisor** only where those grounds
do not settle it or it is not confident ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*); the **operator** may override. The change stands only
as the entries below ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1); choosing how a
criterion is *verified* is the design's, provided the row states its reason, which the
reviewers then judge at REVIEW (the three-tier guard — [`units/design.md`](<autoflow-root>/docs/units/design.md) >
*Report routing*). A content change reaches the main session from wherever it surfaces: the design's
`## Decision requests` section; a problem the build meets and raises in its report; or an
evaluation recommendation that records a criterion defect ([`units/design.md`](<autoflow-root>/docs/units/design.md) >
*Report routing*). The change excludes, revises or splits a criterion, or adds one. The
decision is recorded as one entry per decided AC, in the same trailing-marker grammar:
the heading `## O<n> — <title> [ac-decision]` (the advisor's: `## A<n> — …`; an override: `## O<n> — …`),
followed by the entry's own `- AC: <ac id>` line (for an added criterion, the id it takes), a
`- Disposition:` line valued `excluded` / `revised` / `split` / `added`, the criterion's text as
decided — `- Text: <text>` for `revised` and `added`, and for `split` one `- Into: <id> — <text>`
line per criterion it makes, in order —, and the ordinary Decision / Grounds / Authority lines with
the authority value `orchestrator decision` (the advisor's: `advisor decision`; an override:
`operator decision`):

```markdown
## O4 — split AC2 [ac-decision]
- AC: AC2
- Disposition: split
- Into: AC2a — <the first criterion's text>
- Into: AC2b — <the second criterion's text>
- Decision: <the decision, one line>
- Grounds: <the grounds>
- Authority: orchestrator decision
```

`<autoflow-root>/scripts/contracts/criteria-apply.sh` applies the entries, in ledger order, to the
analysis report's acceptance-criterion table, and its output — the applied criteria — is what every
later module takes ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D8); the
analysis report's table is not edited.

**A criterion can be wrong; from the design on, the work tests it**. The analysis takes the criteria as written — it
analyzes the problem as the issue states it and runs no test of the criteria of its own. That says how
the analysis works, not when a defect may be raised: a defect observed as a fact is raised wherever it is
observed, an evaluation before the design included. From the design on — the design, the build
and every evaluation after them — a criterion is a hypothesis the work tests, not a truth the
work is bent to fit: wherever the work and a criterion disagree, *is the criterion wrong?* is one of the
answers the judgment weighs, beside *how is it satisfied?* A criterion is **defective** when (a) a fact
it presumes does not hold — a device, a phase or a state it takes for granted; or (b) the scope it draws does not fit the problem — too
narrow, when the same cause reaches past what it names, and the question is then whether the issue saw
the problem as local and the approach itself must change, not only whether to include the rest (a
widening: `revised` / `added`); or too wide, when it binds in a problem separate from this issue (a
split: `split` / `excluded`). A defect so judged is raised for a decision — the main session's first, the advisor's where it cannot settle it;
it is never resolved by keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the unit documents and agent definitions cite it.

The marker sits at the **end** of the heading. The authority over an acceptance criterion maps to
these literals and nothing else: the entry's authority **value** is `advisor decision` on an `A<n>`
entry, or `orchestrator decision` or `operator decision` on an `O<n>` entry, and the entry is **located** by the `[ac-decision]`
heading marker. When the entries for one AC disagree, an `operator decision` entry wins. A criterion
the entries add or change is owed its verification-design row and its discharging site like any
other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and AUDIT reads it as of the attempt's base commit ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). Changing it within the attempt — the file, or the
declaration that points at it — is never the attempt's own to accept: the **advisor** decides first
and the **operator** may override. When `<autoflow-root>/scripts/gate/security-checklist.sh status` reports the
change, the question is put to the advisor, and the answer is recorded in the same
trailing-marker grammar: the heading `## A<n> — <title> [checklist-decision]` (an
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
`rejected` → it is not, and the change is reverted before AUDIT reads it; both → a conflict, reported as
`conflict=<ids>` on an undecided (exit `3`) record and resolved by a new entry, never by recency.

**Criterion-readiness confirmations** (`[criterion-ready]`). The attempt's criterion review checks
the issue's acceptance criteria and the decisions the review settles are recorded ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). The review session
judges and records its dispositions, a point it cannot settle is decided by the advisor as at any
decision point — the answer is itself the decision and does not wait on the operator's review —
and the operator overrides either when they choose. Once every decision is settled, the review
session records them in one entry, with no operator confirmation asked: the entry is the record of
the decisions made under the policy the operator set for the review, under the authority
`operator decision` — the same authority over acceptance content as an override
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). It is recorded in the trailing-marker grammar: the heading
`## O<n> — <title> [criterion-ready]`, followed by a `- Decision:`
line, a `- Record:` line (the review record's file name in the attempt's own record directory, by name
alone), an
`- Issue body sha256:` line (the value `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints
for the body the entry records), and the ordinary Grounds and Authority lines with the authority value
`operator decision`. No `A<n>` entry carries the marker. `<autoflow-root>/scripts/preflight/criterion-ready.sh
status` reads the **last** entry carrying the marker in the attempt's own ledger — never another
attempt's — and counts it only when it is an `O` entry
under `operator decision`, its record exists and its sha256 equals the issue body's now; an edit to
the body is confirmed by a new entry, never by editing this one. A criterion change after the
review is an `[ac-decision]`.

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
