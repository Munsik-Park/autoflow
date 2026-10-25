---
name: cycle-u1
description: >-
  Run unit U1 (Criterion review — CRITERION-REVIEW) of an AutoFlow cycle
  alone, in a session of its own, with the parts of the core U1 uses. Use only
  when the operator starts a U1 session (/autoflow:cycle-u1 <N> [new]).
argument-hint: "<issue-number> [new [--base <branch>] [--commit <commit>]]"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt, `--base <branch>` / `--commit <commit>` its base and start commit for `autoflow-records new`) — unit U1, Criterion review (CRITERION-REVIEW), of issue #N's cycle alone: confirm from the attempt's records that the cycle stands at U1's entry (otherwise report the situation and stop), run U1 from its entry to its exit transition, and end the session with the report the invoking prompt asks for.

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that U1 uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle: Push and PR creation; Development Lifecycle > Unit Document Loading Contract: The reference values, U2 Analysis, U3 Design, U4 Build and verify, U5 Completion eval, U6 Delivery, U7 Review, The rubric of every evaluation, The evaluation contract; Development Lifecycle > Unit references: U2 Analysis, U3 Design, U4 Build and verify, U5 Completion evaluation, U6 Delivery, U7 Review; Project Information: A project whose information names sub-repos; Team Structure: Evaluation AI, Build unit (U4), Functional-unit agents; Evaluation System; Git Workflow — Rules: Commit Ownership.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/criterion-review.md`; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

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
U1 Criterion review    CRITERION-REVIEW — the criterion review's four modules: criterion-screen (the review items and the screening; the review record and one target file per criterion), criterion-trace (each confirmed cause's reach and each required behavior's conflict with the rules in force), criterion-in-depth (one run per criterion with an in-depth target, on that target alone) and criterion-reconcile (the record settled against the trace and the in-depth verdicts), each item disposed of with its grounds (`<autoflow-root>/docs/criterion-review.md`)
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

### Unit references

| Unit | Also on entry |
|------|------|
| U1 Criterion review | the criterion review: `<autoflow-root>/docs/criterion-review.md` |

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

## Reference Documents

- **AutoFlow phase guide**: `<autoflow-root>/docs/autoflow-guide.md`
- **Role contracts**: `<autoflow-root>/docs/role-contracts.md`
- **Evaluation system**: `<autoflow-root>/docs/evaluation-system.md`
- **Module contracts**: `<autoflow-root>/docs/contracts/<module>.json`, checked by `<autoflow-root>/scripts/contracts/contract.sh`
- **Criterion review (the four criterion modules)**: `<autoflow-root>/docs/criterion-review.md`
- **Git procedures**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/criterion-review.md -->

# Criterion Review

An issue's acceptance criteria are reviewed against the target's code and policy before the analysis
takes them, by each attempt for itself: an attempt — one run of the issue, on its own branch and
record directory — begins with its own criterion review and stays independent of every other
attempt from that review to its pull request. The review is four modules — criterion-screen,
criterion-trace, criterion-in-depth and criterion-reconcile, each with its contract
(`<autoflow-root>/docs/contracts/criterion-*.json`), this document the procedure of all four — and
it disposes of every item it finds, with its grounds. What follows the four — the advisor's answer
to an item the review could not decide with confidence, the `[ac-decision]` entries, the edit of the
issue body to the dispositions and the `[criterion-ready]` entry that records them — is the
Coordinator's ([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D2, D8;
*Authority* below). This is the Definition of Ready of backlog refinement: a criterion that presumes
a fact that does not hold, that conflicts with a policy already in force, or that leaves a term
undefined is found while it is still cheap to change — before a re-run, a re-score and an advisor
spawn each find it one at a time in the later work.

The review does not replace the later path for a criterion defect: the analysis still takes the
criteria as written, and from the design on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## The four modules

- **criterion-screen** — stage 1: the review items and the screening (*Review items*, *Screening*
  below). It writes the review record, `<out>/criterion-review.md`, and one target file per
  criterion with an in-depth target, `<out>/targets/<criterion>.md`. It is run by a session of its
  own, which reads what it judges the review needs — which code, documents and materials, the
  order, how far it follows a cause or an effect, which tool checks a fact — and records under the
  record's `## Inputs` what it read and why, and what it left out and why (Rule Scope, principle 2
  — [`core.md`](<autoflow-root>/docs/core.md)).
- **criterion-trace** — stage 2, an `autoflow-criterion-tracer` agent on the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model criterion-trace` names: each
  confirmed cause's reach and each required behavior's conflict with the rules in force
  (*Cause reach and rule conflict* below). It writes `<out>/trace.md`.
- **criterion-in-depth** — one run per criterion with an in-depth target, an
  `autoflow-criterion-analyzer` agent on the model `… model criterion-in-depth` names, given that
  criterion's target file and nothing else (*In-depth analysis and reconciliation* below). It writes
  `<out>/in-depth.md`.
- **criterion-reconcile** — an `autoflow-criterion-reconciler` agent on the model
  `… model criterion-reconciliation` names, given the review record, the trace and every in-depth
  file: it settles in the code each case where they differ and writes the updated record,
  `<out>/criterion-review.md`.

- **Reference model and effort.** The session that runs criterion-screen runs on Opus 5.5
  (`claude-opus-5-5`) at effort `high`; another model or effort may be used. The setting for that
  session lives here because the screen is a session's own work, not an `Agent` spawn. The agents
  take theirs from `.claude/autoflow/spawn-policy.json` like every other spawn
  ([`core.md`](<autoflow-root>/docs/core.md) > Spawn Model), the effort the one each agent definition carries. The
  record's `## Inputs` names the model and effort each module ran on.
- **What a review module never does.** It never edits the issue body or a criterion, never writes
  the ledger, and never asks the operator to confirm, approve or re-check a disposition or waits on
  the operator for one (*Authority* below).
- **Result owed**: the record's path and a one-line summary naming each item the module could not
  decide with confidence.

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the commit the
  attempt's branch starts from unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`core.md`](<autoflow-root>/docs/core.md) > Project Information), and the documents of the
  sub-repos the issue reaches.

## Purpose and scope

The review's **purpose** is to find, before the work commits to the criteria, a criterion that would
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
module's own (*The four modules* above); the record's `## Inputs` states that scope.

**What the review leaves to the later work.** The review judges the criteria against the code and policy
as they stand; it does not set how the change will be made. What shows only once an approach
exists — the change's effect on other functions, the reuse of existing code, where a
responsibility is placed, an approach that meets a rule in force — is the later work's: the design
is the design module's ([U3 Design](<autoflow-root>/docs/units/design.md)), and a change's side effects are derived at
BUILD, not predicted at design ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:PLAN: "Affected files
and side effects are not scored here"). A criterion defect found there takes the path
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be
wrong*). A choice of how to make the change is neither asked here nor written into a criterion;
what a criterion keeps is the behavior a user, a caller or an operator observes.

## Stages of the review

**Stage 1** — criterion-screen — checks the criteria on the review items and screens the cases
each criterion applies to, selecting the ones for in-depth analysis. **Stage 2** — criterion-trace —
starts from what stage 1 confirmed — each cause the code shows and the behavior each criterion
requires — and asks how far they reach, assuming no fix (*Cause reach and rule conflict (stage 2)*
below). The **in-depth analysis** — criterion-in-depth — examines the selected cases, criterion by
criterion, and the **reconciliation** — criterion-reconcile — settles where a stage 2 finding or an
in-depth verdict differs from the record. Stage 2, the in-depth analysis and the reconciliation
each run in a fresh context.

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
Each module's inputs are what keeps it independent; when each runs is the Coordinator's — stage 2
and a criterion's in-depth analysis can run once the screen's record is written, alongside each
other, and the reconciliation needs both.

## Review items (stage 1)

Each criterion is checked on the items below — *Actual and expected behavior* and *Size and
separation* once for the issue as a whole; an item that does not apply to a criterion says so.
Each finding carries its grounds: a commit SHA with `path:line` for a fact of the code, or the
document, its section heading and a quoted sentence for a provision of a policy document.

| Item | The question |
|---|---|
| Code and policy fit | Does the code behave as the criterion presumes, and does the criterion agree with the policies in force (an ADR, a rule document)? A criterion that presumes a behavior the code does not have, or one that a standing policy contradicts, is a finding. |
| Cause | Where the issue reports a defect, does the criterion address only the direct cause — the point where the failure shows — or also the root cause that produces it? A criterion narrower than the cause the code shows is a finding, recorded with which of the two it covers. Establishing the cause is the analysis module's work ([U2 Analysis](<autoflow-root>/docs/units/analysis.md)); the review judges what the criterion covers against the cause the code shows. |
| Actual and expected behavior | Set side by side, does the state the criteria describe as done cover the behavior the issue reports as it actually occurs? A criterion set that covers only part of the actual behavior is a finding, recorded with the part left uncovered. |
| Contradiction | Can every criterion hold at once? Two criteria that cannot both be met, or one that undoes another, is a finding. |
| Terms and scope | Is every term a test would turn on defined — a threshold ("exceeds"), a surface ("the conversation screen"), a set ("every page")? An undefined term, or a scope with no stated bound, is a finding. |
| Size and separation | Is the issue one piece of work a single change can carry to done, or does it bundle areas that are each complete on their own — separate surfaces, separate causes, criteria that share no code or test? Several independently completable areas in one issue is a finding, recorded with the areas and a proposed split (`split`). |
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

The criterion-trace module runs as an `autoflow-criterion-tracer` agent — a fresh context that
carries none of the screen's conversation — given the issue and the review record the screen wrote.
Starting from each cause the record confirms in the code and the behavior each criterion requires,
it judges two questions:

| Question | What it judges |
|---|---|
| Cause reach | Does a confirmed cause operate beyond the points the issue reports — the same defect showing at another point, surface or element the cause reaches? A point where it does that no criterion covers is a finding. |
| Rule conflict | Does the behavior a criterion requires agree with the rules and behaviors the code already has, in every case the criterion applies to? A rule or behavior in force that keeps the required behavior from holding is a finding, recorded with the rule and the case. |

How the change will be made is not yet set, and stage 2 assumes no fix: an effect that would follow
only from a particular approach is outside it (*Purpose and scope* > *What the review leaves to the
later work*). Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it
(`new`), and carries its grounds as the review items' findings do. It writes `<out>/trace.md` and returns that path and a one-line
summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: the criterion-in-depth module, an `autoflow-criterion-analyzer` agent, which carries
none of the screen's conversation. It is given one target file, the screen's
`targets/<criterion>.md`, holding only the issue body, the criterion's text, the target cases, each
case's code locations (`path:line`) and the commit they were read at — no verdict, grounds or
conclusion. The verdict rests on the code that decides whether and how the required behavior occurs
and the condition applied there, never on the point where it shows alone. Where the behavior occurs
only under a condition, the analysis checks whether a situation that does not meet the condition
actually arises — from which input, state or usage flow; where one does, the behavior does not hold
in that situation. It writes `<out>/in-depth.md` — per case the verdict, the deciding code and
condition, and the grounds — and returns that path and a one-line summary.

**Reconciliation.** The criterion-reconcile module, an `autoflow-criterion-reconciler` agent —
again a fresh context — is given the review record, the trace and the in-depth files. Where a stage
2 finding or an in-depth verdict differs from the record, it confirms in the code which one holds and
settles it. A criterion that does not hold in a case it applies to is a finding for that case,
recorded with the rule or condition that prevents it — never summarized as holding conditionally. It
updates `## Findings`, `## Screening` and `## Dispositions` to match, writes
`## Cause reach and rule conflict` and `## Reconciliation`, writes the record to
`<out>/criterion-review.md`, and returns its path and a one-line summary.

**What the procedure fixes.** The artifacts — the screening, the stage 2 findings, the in-depth
verdicts and the reconciliation record — and the independence of the fresh contexts: stage 2
receives the issue and the stage 1 record and none of the screen's conversation, and the
in-depth context receives the target file and nothing of the review's verdicts or grounds. Each
context's agent definition carries its part of this document ([`core.md`](<autoflow-root>/docs/core.md) >
Context Injection); what else it reads, in what order and with which tool, is its own (Rule Scope,
principle 2 — [`core.md`](<autoflow-root>/docs/core.md)). Each agent is spawned as its `subagent_type` on the model its
policy row names ([`core.md`](<autoflow-root>/docs/core.md) > Spawn Model), at most five are in flight at once
([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Concurrent spawns*), and its prompt states the delivery as
"return … as your report".

## Review record

`<out>/criterion-review.md`, written by criterion-screen and, updated, by criterion-reconcile, each
in its own run directory. It carries the line `Issue body sha256: <sha256>` — the issue body
reviewed, as `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints it — on a
line of its own, and every section below; a section with nothing to record says `none`.

| Section | Holds |
|---|---|
| `## Inputs` | the scope the review set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort each module ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Screening` | stage 1 — per criterion, each case it applies to: where the required behavior shows and the code that decides it (`path:line`), the verdict (`finding` / `holds` / `unconfirmed`), the reach of its grounds (`shows` / `decides`), and whether it is an in-depth target; a criterion with no target says so |
| `## Cause reach and rule conflict` | stage 2 — each finding, by question (cause reach / rule conflict), marked `stage 1` or `new`, with its grounds, as the reconciliation settled it — or `none` |
| `## Reconciliation` | per stage 2 finding and per in-depth case: its verdict, how the reconciliation took it — `applied`, `rejected` or `unresolved` — and the grounds, with the file it came from |
| `## Dispositions` | a table whose first column is `Item`: one row per item the review found — each criterion, and each problem found beyond the criteria — with the disposition the review decided, its grounds and where the item came from (`stage 1`, `stage 2` or `in-depth`). A criterion is kept, revised (with its text as revised), split (with the criteria it becomes), or excluded; one is established or added where the issue states none or lacks it; a problem found is included in this issue or separated from it. An item the module could not decide with confidence says so in its row and states the question for the advisor — the behavior it concerns, why the code and policy do not settle it, and each option with what it changes in the criteria. How the change will be made is never an item here (*Purpose and scope* > *What the review leaves to the later work*) |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |

The record is situation-first where the operator reads it — to follow what was decided and to
override any of it ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Human-decision presentation*):
what each finding means for the issue's behavior comes before its anchors.

## Authority

The review follows the same authority over acceptance-criterion content as the rest of the work,
under the policy the operator set for it: the review disposes of every item, the advisor decides an
item the review could not decide with confidence, and the operator overrides when they choose
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principles 1 and 3). An item the code or a policy settles, or one
the review can reasonably choose, the review decides and records with its grounds; there is no
second list of questions besides the dispositions.

The Coordinator puts each item the review could not decide to a fresh advisor, by the advisor's
procedure ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor); the answer is an `A` entry, an answer
that decides a criterion's content an `[ac-decision]` entry
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), and it is applied as
recorded without waiting on the operator's review. An operator override of an advisor answer or of a
disposition is recorded as any override is ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor
decisions and operator overrides*).

Once every item is decided — each disposition, each advisor answer and each operator decision
given — the Coordinator records each disposition that changes a criterion as its `[ac-decision]`
entry, edits the issue body to match, and records the `[criterion-ready]` entry (*Confirmation*
below), without waiting on an operator response or confirmation. The operator is asked only for a
harness-level block ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Decision points and
harness-level blocks*). The criteria the later work starts from are therefore the issue body as
those decisions left it, and the review record is the evidence they were made on.

## Confirmation

The confirmation — the `[criterion-ready]` entry — is the record of the decisions made under the
policy the operator set (*Authority* above), written by the Coordinator once every decision is
settled, as a decision-ledger entry in the attempt's ledger `<attempt-dir>/issue-{N}-ledger.md` —
an `O<n>` entry under the authority `operator decision`, which the gate hook admits from the main
session only ([`core.md`](<autoflow-root>/docs/core.md) > Records and the hook; grammar:
[`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *Criterion-readiness
confirmations*):

```markdown
## O<n> — criteria settled [criterion-ready]
- Decision: the acceptance criteria of #N, as the issue body now states them, are settled
- Record: <the review record's path in the attempt's record directory: criterion-reconcile-<n>/criterion-review.md>
- Issue body sha256: <criterion-ready.sh hash --issue N, run after the last edit>
- Grounds: the decisions recorded — the dispositions, the advisor answers (their A entries), any operator decision
- Authority: operator decision
```

The identifier comes from `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> O`, called
immediately before the append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger).

**The confirmation is bound to the attempt and to the body.** `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue N --records <attempt-dir>`
reads the last `[criterion-ready]` entry in the attempt's own ledger — never another attempt's —
and reports `READY` only when the entry is an `O` entry under `operator decision`, its record
exists, and its `- Issue body sha256:` equals the sha256 of the issue body read from GitHub now. Any
edit to the body after the entry leaves the attempt not ready until its review runs again and a new
entry records the edited body. Whether the review runs again, and over what (in whole, the changed
criteria only, or not at all), when the body an entry records differs from the one the record read,
is the Coordinator's judgment, recorded with its grounds in the new entry's grounds.

## What reads it

- **The analysis module** — the review record is one of its inputs
  ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > *Criterion review record*), and the `[criterion-ready]` entry
  for the current body another.
- **The Coordinator** — the dispositions, as the decisions it records and the issue edit it makes.

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue filed without a
`[criterion-ready]` entry is reviewed on its turn, when an attempt of it is next begun, and the
review's decisions are recorded once they are settled. An issue taken up again after an earlier
attempt is reviewed again by the new attempt, whatever the earlier one left: every attempt begins
with its own review.

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
line, a `- Record:` line (the review record's path relative to the attempt's record directory — the
criterion-reconcile run's `criterion-reconcile-<n>/criterion-review.md` —, never an absolute path or
one with a `.` or `..` component), an
`- Issue body sha256:` line (the value `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints
for the body the entry records), and the ordinary Grounds and Authority lines with the authority value
`operator decision`. No `A<n>` entry carries the marker. `<autoflow-root>/scripts/preflight/criterion-ready.sh
status --issue N --records <attempt-dir>` reads the **last** entry carrying the marker in the attempt's own ledger — never another
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
This section is the procedure's single home; [`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle >
*A decision that is not the module's own* routes to it and the module documents cite it.

### Decision points and harness-level blocks

- **A decision point** is a decision the working AI cannot settle on the grounds at hand, or is not
  confident of ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3). An acceptance-criterion
  change, a non-code root cause or a non-code lever, a planning / design / ADR prerequisite the
  analysis records, a finding that repeats an earlier complaint, and a hypothesis evaluation whose
  PASS looks unreachable are where such a decision arises, not decision points by their kind: the
  Coordinator judges each first, and where the grounds the raising report, finding or evaluation
  carries settle it, it decides and records the decision with those grounds in an `O` ledger entry
  under `orchestrator decision` — for an acceptance-criterion change, its `[ac-decision]` entries
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*). An un-agreed
  design point, a finding whose fix the AI acting on it cannot place with confidence, and a rebuttal
  the re-score or the reviewer keeps while the two sides still disagree are already decisions the
  working AI could not settle; the module states each in its output as the question for the
  advisor. A security-checklist change (`[checklist-decision]`) is the one decision point by its
  kind: `<autoflow-root>/scripts/gate/security-checklist.sh` counts only an advisor or an operator
  entry ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Security-checklist decisions*). In the
  criterion review, an item the review could not decide with confidence is one as well, its
  question stated in the item's `## Dispositions` row ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) >
  *Authority*). Each decision point is answered by the advisor first.
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial). It is reported to the operator situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Execution
  Principles > Human-decision presentation). A tool, credential, installation or material the
  environment does not provide — for a tool it has, what using it lacks (access, a purpose and
  permitted scope, a permission setting) — is a tool request: the run does what it can without it
  and ends ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Tools*). What follows a decision that
  can end the work — a non-code lever or cause, a prerequisite that comes first, a hypothesis PASS
  not reachable, the last closing the issue only on the operator's confirmation — is the
  Coordinator's. The reference values and the caps are not decision points
  ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1).

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
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)). Its identifier comes from
   `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> A`, called immediately before the append; the
   call reserves the identifier, so advisors spawned together receive distinct ones
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entry identifier > *Allocation*). It appends with `Edit`, which the gate hook applies to
   the file on disk and checks (*Independence* below), so the prior content is never re-written. It
   returns the identifier and the answer in one line.
4. **Apply.** The Coordinator verifies the anchor — the ledger heading and the record file exist —
   and applies the answer; which module runs next on it is its own
   ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-run-by-the-coordinator.md) D2). An advisor that
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
override is the authority ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor decisions and
operator overrides*). Which module runs again on it is the Coordinator's.

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

The hand-back carries exactly what the final text carries in the other modes — the anchor + one-line summary — never the body, whatever the harness's own tool description says of a "full report" ([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Context discipline*, row 2).

| Spawn mode | Where the report arrives | Required delivery action |
|---|---|---|
| anonymous direct (`subagent_type`) — the only mode | auto: the hand-back frame, beside a pointer task notification; otherwise: the return value (sync) or the task notification's `result` (background) | auto: the hand-back call the harness instructs; otherwise none. Write the body to the run's output directory and report an anchor + one-line summary |

A spawn carries no `name`: its role is its `subagent_type` ([`core.md`](<autoflow-root>/docs/core.md) > Communication).

The single mode applies to every role; the per-role table is [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Spawn mode by role lifetime.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Reporting Format -->

## Reporting Format

When a role spawn reports to the session that spawned it — the report is the spawn's return value, with any body written to the run's output directory and an anchor plus a one-line summary returned — it must follow this shape (see [`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Context discipline*). This format governs **AI↔AI** reporting: the returned report, and what a unit agent's helpers report to it. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in [`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite record files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report the test runner's summary line (e.g., "Tests: 147 passed, 147 total"), read from the run's log (item 5), + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the run's **log** — the file its output was written to (Testing Standards item 7), cited by path under the run's `<out>/local/` — with the command that produced it and the exact `Tests: N passed, N total` (or equivalent) summary line read from that log. The log is the evidence and the summary line is the value read from it; a line no log carries is not evidence (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, plus the verbatim content of that line (a line number is read only at that commit — [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger)
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under the run's `<out>/local/`, with its result line (`observation: match` / `observation: mismatch — …`) read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the committing role identified, followed by the grounds of the identification — where it looked (the documents, scripts and CI files read) and each CI lint step it did not count as a chain with the condition that excludes it — the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked, its source (document section, script definition or workflow `path:line` and step name) and the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*), the reason, and the unexecuted chain's identity (its command and source, or the workflow `path:line` and step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this pull request — the workflow's `on: pull_request` entry, either no `paths:` filter or one whose patterns match a staged file, and a job and step condition that admits this pull request; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-covered` → the chain and the file set it covers; `not-applicable` → that word alone, with the grounds naming where the committing role looked. A report citing one chain where the committing role identified several is malformed, not compliant.

   Anchors must be deterministically confirmable by their reader — the session that spawned the role, an evaluator, the Coordinator — against what produced them (`git show <SHA>` / the summary line read in the cited log / `git show <SHA>:<file>`); a test-pass anchor is confirmed by reading, not by re-running — the command is re-run only when the log is absent or does not carry the line, and the run is then `not-run` and run in place. Reports without an anchor are rejected, not interpreted. This item's line-number forms are for the report; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.


---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Verification and Tools -->

## Verification and Tools

This section applies to every actor of a module's run — the session that runs it and every role it spawns.

**Local verification** (the instance of [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2 the modules cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every test it authored or changed and every check the verification design runs before delivery — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format item 5). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is the pull request's CI — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to (Testing Standards item 7's `$LOG`), cited by path under the run's `<out>/local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the spawning session's acceptance of a role-spawn report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Verify role-spawn claims*), AUDIT's test-first judgment, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the build unit, or a helper it spawns — finds, in the target checkout it works in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **run's own check** — a test the target's tree does not keep, a check run before delivery, a manual checklist — lives in the run's store `<out>/local/`, under the record root outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's absolute path in the store** and is run from the target checkout's root: the asset finds the tree it checks from its working directory (`git rev-parse --show-toplevel`), never from its own location, which is outside every tree. The verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A run that wants one command for several assets writes that driver *as* an asset in the same store. Such an asset is never committed, and stays with the attempt's other records, where a later run reads it. An asset writes its reproducible output — a build result, a copy of a source tree or of another original: an output re-creatable from inputs its record already names, such as a commit and a command — only under the store's reserved path `<out>/local/disposable/`, the one path that can be deleted with nothing the records cite lost; whether and when it is deleted is the Coordinator's ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). Nothing a run record, an observation record or a report cites ever goes there — not a log, a record file, the artifacts an observation left, or the asset itself, whose path the recorded command names — even when it is re-creatable. Whether an output is reproducible and uncited is the writer's judgment; where such an output goes is not. Only the store's top-level `disposable/` is reserved — a `disposable` deeper in the store is kept like any other path — and reproducible output left outside it is a deviation, kept with the rest of the store.

**The tools the work needs are found and used; what is missing is requested, and the run still ends**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the main session ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Background execution is the main session's only*), and stopped once the run no longer needs it. A tool that cannot be used has something missing: the tool itself when this environment does not have it — an installation, enabling an MCP server or a browser extension — or, for a tool it has, what using it lacks — access, the purpose and permitted scope of the host or service it reaches, a credential, a permission setting. Providing any of these is outside the assigned scope ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); using a tool the environment already provides is not. What is missing is recorded as a **tool request** — `{missing, instead}` in `<out>/tool-requests.json` and in the run's report: what is missing, named as what is missing and not as the output the tool would give, and what the run did instead, each verification it left unrun or ran on a mock or a person's observation for the lack included. The run does what it can without it — a mock, an observation, a verification left not run, by its own judgment — and ends; the delivery module states every request in the pull request, and the operator decides on it ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Tools*). A purpose or permitted scope is a project fact, and its request asks that the operator record it in the project's information ([`core.md`](<autoflow-root>/docs/core.md) > Project Information). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened is a tool request the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under the run's `<out>/local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each module does this: `<autoflow-root>/docs/units/analysis.md`, `<autoflow-root>/docs/units/design.md` > *Tools* and `<autoflow-root>/docs/units/build.md` > What the build owes.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — a later module given the record, GATE:QUALITY's `Test coverage` or `Commit conventions` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL; a run that fails is recorded as its module's procedure says, and what follows it is the Coordinator's.

**What a change leaves in the target's tree is not classified by AutoFlow**. A change adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the change does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI* > *Added test files*), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->
