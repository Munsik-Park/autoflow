---
name: ci-failure
description: >-
  Run the AutoFlow ci-failure module once on an invocation file — what each
  failed CI check shows and where its fix is made. Use when the operator runs
  the ci-failure module (/autoflow:ci-failure <invocation.json>).
argument-hint: "<invocation.json>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the attempt's record directory the invocation names (`records`). Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: the invocation file) — one run of the ci-failure module (`<autoflow-root>/docs/contracts/ci-failure.json`) on that invocation: `bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>` first — a refused input ends the run with its report —, then the work, which writes the outputs and `<out>/tool-requests.json` (`[]` when the run lacked nothing, *Tools* below), then `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json`; the run ends with the report its procedure owes. The work is one `autoflow-analyzer` spawn on the model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names, given the failed checks the invocation names and the output directory (`<autoflow-root>/docs/units/delivery.md` > CI failure, below). The invocation's `records` is the attempt's record directory, where earlier runs left their work. Every `Agent` spawn the run makes takes its model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` — the advisor's key is `advisor` (*Spawn Model*, below).

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that the ci-failure module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle: Push and PR creation; Development Lifecycle > Module procedures: The reference values, criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, integration, delivery, ci, review, The rubric of every evaluation, The evaluation contract; Development Lifecycle > Module references: criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, integration, delivery, ci, review; Project Information: In a project whose information names sub-repos; Team Structure: Evaluation AI, Build module, Functional-unit agents; Evaluation System.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/delivery.md`; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The merge prohibition, the separation of a module's work from its evaluation, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the reference pass values AutoFlow keeps with the rubrics are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the output its run already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by the evaluation modules, by CI and by the external reviewer. The working AI decides what it can decide, and the run goes on unless a call is blocked at the harness level.
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a run leaves in the target's tree — are `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Development Lifecycle — AutoFlow

**AutoFlow is a set of modules.** A module is an input, the work it does, and an output; its contract, `<autoflow-root>/docs/contracts/<module>.json`, declares its parameters, its inputs and where each comes from, and its outputs with the form each must meet (`ADR-0038` D1). The modules are functional — the criterion review's four, analysis, design, build, the delivery's four (integration, delivery, ci, ci-failure), review —, evaluation — hypothesis, plan, audit, quality — and deterministic — criteria-apply. AutoFlow defines the modules: each one's contract, its procedure and the checks of its inputs and outputs (ADR-0038 D2). A module takes everything it works on from its invocation, the branch and the attempt's record directory included (D4).

**A module runs once, on its invocation.** An invocation file names the module's parameters, its inputs, its output directory and, for a functional module, the attempt's record directory (the invocation's form: `<autoflow-root>/scripts/contracts/contract.sh`, header). The module checks its inputs' form first (`bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>`) and does not run when one fails; where an input came from is not checked. It does its work once, writes its outputs into its output directory, and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json` — `accepted`, `refused`, or `failed` when the module wrote the failure output its contract declares because it could not reach its expected output (`ADR-0039` D3) —, the outputs, the defects, the tool requests and the AutoFlow that ran the module (its version and root).

**A module's procedure states the goal of its work.** It says what the work must achieve, and the AI judges how to meet it; the output disposes of every item the work owes — each applied acceptance criterion, each scope item the design includes —, which the evaluations judge; the contract checks the inputs and the facts of the output (ADR-0038 D1). The applied criteria every module after the analysis takes are criteria-apply's output, computed from the analysis report's table and the `[ac-decision]` entries (`<autoflow-root>/docs/decision-ledger.md` > *Acceptance-criterion decisions*); the issue's criteria are first reviewed against the target's code and policy by the criterion review's modules (`<autoflow-root>/docs/criterion-review.md`).

**Decisions within a module.** The working AI decides what it can and records each decision with its grounds in its output (Rule Scope, principle 2). The decisions AutoFlow puts to the advisor — a change to an acceptance criterion's content, a root cause or lever that is not code, a hypothesis PASS judged unreachable, a design point not agreed, a finding whose fix cannot be placed with confidence, an item the criterion review could not decide, every change to the target's security checklist — and any other point the AI doubts, the module puts to a fresh `autoflow-advisor` it spawns, and it follows the advisor's decision. The advisor records the decision with its grounds as an entry in the ledger of the record directory the invocation names, and the module's output names each decision it followed by the entry's identifier (`<autoflow-root>/docs/role-contracts.md` > Advisor). The run goes on; a call blocked at the harness level — a permission denial — is recorded in the output, and a tool the environment does not provide is a tool request (*Tools* below).

**Tools.** A tool the work needs is used. One the environment lacks — or what using a tool the environment has lacks, or a material an acceptance criterion or the issue body references that cannot be opened — is recorded as a tool request: what is missing, and what the run did instead, including each verification it left unrun for the lack. The run does what it can without it and ends; the requests go in `<out>/tool-requests.json` — which every run writes, `[]` when it lacked nothing — and the run's report, and the delivery module states them in the pull request for the operator (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ADR-0038 D1).

**Scripts**: a script AutoFlow ships reads and reports, or writes the files its own contract names (`contract.sh`, `criteria-apply.sh`); it changes nothing in git or on GitHub. A push, a pull request and a comment are a module's own commands.

### Module procedures

**[MUST]** A module's run follows its contract's `procedure` — its document for a functional module, the gate's section of `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* for an evaluation module — which the module's command body or the role's agent definition carries after the core (*Context Injection*). The procedure is the source of truth for the module's work; this core file does not restate it. Do not run a module from memory of a prior run — the body is the document of the installed version.

| Module | Command | Procedure | The work is done by |
|------|------|------|------|
| `criterion-screen` | `/autoflow:criterion-screen` | `<autoflow-root>/docs/criterion-review.md` | the session itself, on the model and effort the procedure's *The four modules* names |
| `criterion-trace` | `/autoflow:criterion-trace` | `<autoflow-root>/docs/criterion-review.md` | an `autoflow-criterion-tracer` spawn (spawn-policy key `criterion-trace`) |
| `criterion-in-depth` | `/autoflow:criterion-in-depth` | `<autoflow-root>/docs/criterion-review.md` | an `autoflow-criterion-analyzer` spawn (`criterion-in-depth`) |
| `criterion-reconcile` | `/autoflow:criterion-reconcile` | `<autoflow-root>/docs/criterion-review.md` | an `autoflow-criterion-reconciler` spawn (`criterion-reconciliation`) |
| `analysis` | `/autoflow:analysis` | `<autoflow-root>/docs/units/analysis.md` | an `autoflow-unit-analysis` spawn (`unit-analysis`) |
| `criteria-apply` | `/autoflow:criteria-apply` | `<autoflow-root>/scripts/contracts/criteria-apply.sh`, a script with no procedure document | the script |
| `hypothesis` | `/autoflow:hypothesis` | `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* > GATE:HYPOTHESIS | an `autoflow-evaluator` spawn (`gate-hypothesis`) |
| `design` | `/autoflow:design` | `<autoflow-root>/docs/units/design.md` | an `autoflow-unit-design` spawn (`unit-design`) |
| `plan` | `/autoflow:plan` | `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* > GATE:PLAN | an `autoflow-evaluator` spawn (`gate-plan`) |
| `build` | `/autoflow:build` | `<autoflow-root>/docs/units/build.md` | an `autoflow-unit-build` spawn (`unit-build`) |
| `audit` | `/autoflow:audit` | `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* > AUDIT | an `autoflow-evaluator` spawn (`audit`) |
| `quality` | `/autoflow:quality` | `<autoflow-root>/docs/units/completion-evaluation.md` and `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics* > GATE:QUALITY | an `autoflow-evaluator` spawn (`gate-quality`) |
| `integration` | `/autoflow:integration` | `<autoflow-root>/docs/units/delivery.md` | the session itself |
| `delivery` | `/autoflow:delivery` | `<autoflow-root>/docs/units/delivery.md` | the session itself |
| `ci` | `/autoflow:ci` | `<autoflow-root>/docs/units/delivery.md` | the session itself; a script reads and reports CI |
| `ci-failure` | `/autoflow:ci-failure` | `<autoflow-root>/docs/units/delivery.md` | an `autoflow-analyzer` spawn (`handoff-review-triage`) |
| `review` | `/autoflow:review` | `<autoflow-root>/docs/units/review.md` | the session, which runs the reviewers; the round's reviews are aggregated by an `autoflow-analyzer` spawn (`handoff-review-triage`) |

A module's command takes the module's invocation file (`/autoflow:<module> <invocation.json>`) and runs the module once on it. Each module runs in a session of its own, and one session can run modules one after another: every input is a file the invocation names. An evaluation's spawn writes its report to `<out>/evaluation.json` and returns the path (`<autoflow-root>/docs/role-contracts.md` > Evaluation AI). The phase and gate names stay as identifiers: the spawn-policy keys and the documents' headings carry them.

```
ci-failure            — what each failed CI check shows and where its fix is made
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every module: a module's command body carries the parts of this core its module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and the documents the module uses with them (*Module references* below, *Context Injection*).

### Module references

| Module | Its command body also carries |
|------|------|
| ci-failure | the procedure: `<autoflow-root>/docs/units/delivery.md` |

## Cost Control

These rules apply to every run.

- **[MUST] Context discipline**: two rows are fixed (Rule Scope, principle 1): (1) **the work never scores itself** — the full read-and-score of a module's output is an evaluation module's fresh Evaluation AI (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and a read of that output by the session that produced it informs a spot-check, never a score; (2) **a spawn returns an anchor and a one-line summary, not its body** — the analysis, design and build spawns return only their artifact paths and a one-line summary. A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the session judges the read necessary, and its report names what was read and why. The Reporting Format (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format) applies to every direct/ad-hoc `Agent` spawn — the spawn writes its body to the run's output directory and returns only an anchor + one-line summary (e.g. the analysis spawn writes `<out>/issue-analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the session's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; how a **decision** is framed for its reader — an advisor request or answer, a harness-level block — follows *Execution Principles > Human-decision presentation* (situation-first), and the body a person reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md` in the record directory the invocation names, fixes settled decisions — the entries that settle what a module cannot settle itself. What an entry records, its identifier grammar, and the decision-point entries (`[ac-decision]`, `[checklist-decision]`) are `<autoflow-root>/docs/decision-ledger.md`.

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled decision is likewise not overturned by re-reading the issue body. One exception: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** The ledger is append-only: entries are never edited or deleted, and a write never changes text already in the ledger — enforced by the gate hook (*Records and the hook* below). A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and names the entry it supersedes on a `- Supersedes:` line.
- The ledger is outside every module's output; a module's output names, by identifier, the entries its run followed (what the ledger holds: `<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` reports a duplicated identifier or an unidentified level-2 heading (exit 1; 2 on a usage error). A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **[MUST] Human-decision presentation**: in every advisor request and advisor answer record (`<autoflow-root>/docs/role-contracts.md` > Advisor), and in a run's record of a harness-level block or a tool or referenced-material request, the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format), which is anchor-first. The body a person reads is written in this same situation-first order — *Context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a decision is **framed**.
- **Verify role-spawn claims before acting on them**: every role-spawn report's Evidence anchor (see `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format > *Evidence anchor*) is verified before the report is accepted — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not act on a single AI's unverified claim.
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

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly. Enforced by the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied in every session — research and evaluation spawns included. The main session's own model follows the user's session settings (outside this policy).

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior run: `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**Spawn role declaration**: an AutoFlow role is spawned as its dedicated `subagent_type` — `autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, the criterion-review agents `autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `<autoflow-root>/agents/` —, so that it carries its guidance from the start (*Context Injection*); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) are used as they are. `subagent_type` is the one declaration channel. The spawn prompt is never used to infer the spawn's role. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning runs: each run spawns its role fresh, hands it the paths of its inputs and of its output directory, and takes its result as the spawn's return value. Each role's mode and per-call scope are `<autoflow-root>/docs/role-contracts.md` > Spawn mode by role lifetime.

A lower-tier evaluation's PASS, or a lower-tier role spawn's claim, materially contradicted by a later run reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are `<autoflow-root>/docs/role-contracts.md` > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

A spawn prompt names the run's inputs by path — the inputs the invocation names, the attempt's record directory for a module that reads it, and the target's files — and the output directory, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the session that runs a module spawns each role with a `subagent_type`, and the spawn's **return
value is its report**.

- The session spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to the run's output directory and returns an anchor and a short summary (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not a channel between a session and its role spawns — the session resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The main session's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- A cross-service change is made by each scope's module run, and what crosses the scopes is the delivery module's (`<autoflow-root>/docs/units/delivery.md` > *Multi-repo delivery*).

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states the AI establishes from the repository itself where it can — its remotes, its `.gitmodules` — and otherwise records as a tool request: the missing fact, and the file that would state it.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor

## Records and the hook

**Record directory.** Every record of an attempt lives in the attempt's record directory `<attempt-dir>`, under the record root — outside every checkout's tree, `autoflow-records root` (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`) —, which each invocation names as `records`. Each run writes into its own subdirectory, `<attempt-dir>/<module>-<n>` (`<module>-<qualifier>-<n>` for one module run on several items in a round, `n` counting that module's runs from 1), so nothing is renamed or overwritten; a functional module reads what earlier runs left in the directory, and an evaluation module keeps to its declared inputs (ADR-0038 D4). The ledger is `<attempt-dir>/issue-{N}-ledger.md`, the name the hook's ledger check reads.

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger; an `Agent` spawn without an explicit `model`; and a backgrounded `run-suites.sh`. With no `jq` it reads the other denies from the raw input; the ledger check reads the write with `jq`, and with no `jq` it passes the write unchecked.

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

<!-- From <autoflow-root>/docs/units/delivery.md -->

# U6 Delivery — INTEGRATE, DELIVER and HANDOFF

> The procedure of the four delivery modules. [`core.md`](<autoflow-root>/docs/core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) >
> Modules.

AutoFlow's mission ends by handing off an open pull request — opened, with CI read, by the modules below, and reviewed by [U7 Review](<autoflow-root>/docs/units/review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

## The four modules

U6 Delivery is four modules, each with its contract under `<autoflow-root>/docs/contracts/` and
this file as its procedure ([`ADR-0039`](<autoflow-root>/docs/records/adr/0039-delivery-as-four-modules.md)). Each
runs alone on its invocation; whether a module runs, in which order, on which pull request, and what
follows its result — a failed integration check, a red CI, a sub-repo's pull request — are not this
document's ([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D2).

| Module | Expected output | The work is done by | `timeout` not given |
|---|---|---|---|
| `integration` | `<out>/integration.md`: the change shown working above its own tests, every check passed or a stated no-op (*Integration*) | the session itself | 3600 s |
| `delivery` | `<out>/delivery.json`: the branches pushed at their heads and, unless `pull_request` is `none`, each one's draft pull request open (*Push and pull request*) | the session itself | 900 s |
| `ci` | `<out>/ci.json`: CI green on each pull request's head, or its not running recorded on it, and the body's CI part stating it (*CI*) | the session itself; a script reads and reports CI | 900 s |
| `ci-failure` | `<out>/ci-failure.md`: what each failed check shows and where its fix is made (*CI failure*) | an `autoflow-analyzer` spawn (`handoff-review-triage`) | 900 s |

## What every delivery module owes

- **Inputs.** A module works from its params and the inputs its invocation gives. The record
  directory (`records`) is where earlier runs left their working files and where the ledger is; it
  does not stand in for an input. An input the work needs and was not given is named as such in the
  failure output, and the run does not go on from a guess.
- **The end of a run.** A run ends when its expected output is reached, or when it judges it cannot
  be reached or its `timeout` (seconds) runs out. A run that cannot reach it writes
  `<out>/failure.md` instead — what it did, what it observed, and why it did not reach the expected
  output — and check-out writes its result as `failed` (`<autoflow-root>/scripts/contracts/contract.sh`,
  header). A failure output is a result, not a defect: its reader learns from it alone what
  happened.
- **Inside a run** the steps are the AI's: it designs them from what it finds, repeats what it needs
  within the run, and checks before ending whether the expected output stands. A repetition inside
  one run is not a re-run.
- **Checks.** Each module's check-out confirms the facts its output names, by the judgment the
  module itself uses — a branch at its head, a pull request open at its head, CI green on the head
  by the same script (*CI*); what the PR body states for the operator is the review's to judge. The
  integration checks and CI stand outside the module's own claim; a CI that did not run is
  recorded as not run, never read as green.

## Integration

INTEGRATE looks at the change as the system runs it, beyond what the build verified per item — on
the branch, before anything is pushed.

- **Expected output**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks
  that takes, and how they are run, is the module's, the way the target runs them
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools).
  `<out>/integration.md` has one line per check — its command and the summary line read from its
  log, the log kept under `<out>/local/` — or the no-op line below. A check that was not run is
  `not-run`, never `passed`.
- **Failure output**: a check that fails is recorded in `<out>/integration.md` with its output, and
  `<out>/failure.md` names it — the change is not shown working. A fix of what failed is the build's.

Cautions:

- A project with no integration layer records `INTEGRATE: no-op (no integration suite)`. That is
  a stated no-op, not a skipped check.
- In a project with sub-repos the system is built in the dev environment and what crosses sub-repos
  is what is verified: each affected sub-repo builds (for example
  `docker compose -f docker-compose.dev.yml up -d --build <services>`), each service's health check
  passes, the functional integration tests pass, and the cross-cutting concerns the change touches
  (auth, network ingress) are looked at.

### Deploy/CI-path conditional verification

A **diff-path-conditional** requirement keyed on the class of surface being integrated. It applies to every project; a class the project does not ship resolves to a defined no-op.

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD origin/<base>`, `<base>` the invocation's `base`). The condition **fires** iff any changed path matches the trigger glob set:

| Class | Glob(s) |
|---|---|
| Submodule layout | `.gitmodules` |
| CI config | `.github/workflows/**`, `**/Jenkinsfile`, `Jenkinsfile` |
| Deploy scripts | `deploy-*.sh`, `**/deploy-*.sh` |
| Env / build-arg | `.env`, `.env.*`, `**/.env`, `**/.env.*` |

Stated as one command (the frozen predicate):

```
git diff --name-only <base>...HEAD \
  | grep -E '(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
```

Non-empty ⇒ the verification bundle below is owed, each item PASS or FAIL. Empty ⇒ record `INTEGRATE deploy/CI-path: no-op (diff touched no deploy/CI-path surface)` — a defined no-op, not a discretionary skip.

**Verification bundle** (owed only when the predicate's output is non-empty; each item is itself a defined no-op when the target ships no such surface):

- **(a) Deploy-script dry-run, incl. recursive submodule init** — the target's `deploy-*.sh` in dry-run (`--dry-run` / read-only) with `git submodule update --init --recursive`, confirming the deploy path resolves the current submodule pointers. *No-op* when the target ships no deploy script.
- **(b) CI-config static validation** — a lint / schema check of the changed CI file itself (`.github/workflows/*` via `actionlint` / YAML-schema; `Jenkinsfile` via the target's `jenkins declarative-linter` or equivalent). *No-op* when no CI file changed.
- **(c) Landing/host routing smoke check** — a smoke request against the built host / landing route (health / routing reachability). *No-op* when the target exposes no host / landing route.

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is a failing integration check (*Integration* above).

## Push and pull request

**DELIVER.** One run pushes and opens the pull requests: the branch the invocation names
(`params.branch`) goes to the remote at the last commit of the build's range (`commits`), and each
pushed branch gets its draft pull request — or, when it already has an open one, the push updates
it and its body is brought up to the inputs the run was given. With `pull_request: none` the run
pushes and opens or updates no pull request. The change it delivers is the one whose local tests the
build report records green; a build report that does not is a failure output, and nothing is
pushed. Which remote, which flags and when are the module's.

These rules hold on every push and every pull request the module makes. Everything they do not
name — the title, how the body is composed, when the push happens — is the module's.

- **Pushing and opening a pull request are the module's own commands.** `git push …` and
  `gh pr create …` are issued as those commands, never through a script or a wrapper
  (`<autoflow-root>/docs/core.md` > Scripts).
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch; the hook denies
  them. Merging is owned entirely by the external review process.
- **Every pull request the module opens is a draft** (`gh pr create --draft …`), on the base the
  invocation names (`params.base`), or the remote's default branch when it names none.

The body lets the operator decide on the pull request. It states:

- each applied acceptance criterion with its outcome and where its evidence is;
- what the work verified other than by an executable test, and how — the reviewer reads it
  (`<autoflow-root>/docs/review/review.md` > Before Reviewing) —, and, given the integration
  record, how the change was shown working above its own tests;
- what the work could not verify, and why: the tool requests in each run's file the invocation
  gives (`tool_requests`) — the criterion review's runs as much as the last ones —, so the operator
  decides on them;
- what the change leaves undone: the problems it separated and the recommendations deferred
  (`deferred`);
- CI's result, in the body's CI part, which is the ci module's (*CI*): a pull request this run
  opens says CI is not yet confirmed, and a body this run updates keeps the CI part as it stands.

The host PR closes the issue (`Closes #N`); a sub-repo PR references it and closes nothing
(*Multi-repo delivery* below). The title and the body's form are the module's, with
[`title-guide.md`](<autoflow-root>/docs/title-guide.md) and [`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) to draw on.

**Expected output**: `<out>/delivery.json` —
`{pushed: [{repo, branch, head, path}], pull_requests: [{pr, url, head, path, opened}], pointers: [{path, commit}], not_delivered: [{path, why}]}`:
each pushed branch with its repository (`<owner>/<name>`) and head, `path` the host's `.` or the
sub-repo's directory; each pull request as `<owner>/<name>#<N>` — the form the review takes as its
`pr` — with its head and `opened: true` when this run opened it; each pointer the host's branch
sets; and each changed sub-repo the invocation does not name, which is not pushed. Check-out reads
each branch and pull request on GitHub at the head the file names.

**Failure output**: a push refused, a pull request that cannot be opened, a pointer that cannot be
set (*Multi-repo delivery*), local tests the build report does not record green, or the `timeout`
reached — `<out>/failure.md` states what was pushed and opened before it, and why the rest was not.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — the sub-repos the invocation names
(`sub_repos`) are delivered on their own pull requests and the host follows each by its pointer.
AutoFlow does not classify the project; what the sub-repos are, where each one's pull request goes
(a fork, the upstream) and where issues are filed are read from the project's own information
([`core.md`](<autoflow-root>/docs/core.md) > Project Information).

What follows a sub-repo pull request's merge is outside AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) >
Post-Merge Cleanup).

For each sub-repo the invocation names:

- its branch is pushed and, unless `pull_request` is `none`, its pull request opened by the module's
  own commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` —, as a draft, on
  the host's terms (*Push and pull request*). A sub-repo pull request references the host issue
  (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the host pull request is the
  one that closes the issue;
- unless its entry says `pointer: false`, the host's pointer is set to the sub-repo commit the
  change delivers, in a host commit pushed with the host branch, so the host review reads the
  pointer and the sub-repo review reads the code behind it ([U7 Review](<autoflow-root>/docs/units/review.md) > *Review
  triage*).

Cautions:

- A conflict on the pointer is settled by setting it to the delivered commit, read back
  (`git ls-tree HEAD <sub-repo>`) before the push.
- Another change may have moved the base's pointer since this branch forked. When the delivered
  sub-repo commit does not contain that pointer — the base is ahead of it, or the two have
  diverged — setting it would move the host's pointer backwards or across histories: the
  module does not push the host, and its failure output states it, situation-first.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.

## CI

The ci module confirms CI on each pull request it is given (`pull_requests`, each with the head it
is to be confirmed on: the delivery's output, or a file the invocation writes,
`{pull_requests: [{pr, head}]}`) with one script, called once for each pull request:

```
CI_POLL_TIMEOUT_SECS=<seconds> bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <N> --repo <owner/name>
```

The module's `timeout` bounds the whole run, not one call: with several pull requests no call is
given all of it, and each call's `CI_POLL_TIMEOUT_SECS` is the module's choice from the time that
remains.

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name.
Green is what the script judges green (its header): one representative per check identity, a
superseded run's cancelled rows not counted, at least one present and every one green, on a PR whose
mergeable state was confirmed. Check-out judges by the same script, read once (`--once`), on the
head the output names. Every exit but `0` ends with a stderr line of what it read
(`observed: reads=… checks_seen=… mergeable=… merge_state=…`), which the output carries.

| Exit | What was read | `verdict` |
|---|---|---|
| `0` | green | `green` |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read; CI was not waited on | `conflict` |
| `11` | mergeable, and no check published on the head on any well-formed read within the bound | `not-run`, or the run's failure (below) |
| `12` | a check concluded and is not green | `failed` |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line) | `pending` |
| `14` | the mergeable state, or any read of the checks, could not be confirmed — a `gh` transport, auth or parse failure, or a merge state that never settled | `unread` |
| `64` | usage | — |

**Expected output**: `<out>/ci.json` — `{prs: [{pr, head, verdict, exit, observed, failing}]}`, every
pull request `green` or `not-run` — and each pull request's body carrying its CI part:

- the CI result, and the head it was read on; a later result on a head replaces an earlier one, and
  a `green` body carries no `CI: not run` line;
- **CI not run.** On exit `11`, whether the target's CI does not run for this pull request — no
  workflow, or a trigger, path filter or condition that excludes it — or is late is the module's
  judgment, recorded with its ground (ADR-0034 D5). Not running: the body carries the line
  `CI: not run`, alone on its line, with the ground below it, and what CI was to run for it (a
  `ci-deferred` lint chain, an added test file) is listed as not run; the verdict is `not-run`;
- **Added test files.** On `green`, each test file the change added to the target's tree (the build
  report's `## Test files kept`) is confirmed to have actually run in the PR head's CI. The criterion
  is execution visible in a job's log: a workflow that only registers the file, or a job that only
  prints its path, did not run it, and a log that could not be read shows neither. Beside each file
  the PR body's `## Verification dispositions` records the job that ran it, or that no job ran it,
  listed for the reviewer as not run by CI; `no CI; local run only` where the target has no CI. How
  it is confirmed is the module's judgment. A change that added no test file has nothing to confirm.

The output is judged on the pull request as it stands once the body is written: a check the body's
edit itself starts is read like any other.

**Failure output**: a pull request that is `conflict`, `failed`, `pending` or `unread`, or `11` judged
late — `<out>/ci.json` carries every pull request's verdict, `failing` names each failed check and
its URL, the body's CI part states the result, and `<out>/failure.md` says which pull request did not
reach green and what the script observed.

Cautions:

- The module does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.

### CI failure

The ci-failure module reads what each failed check shows (`ci`: the pull requests whose verdict is
`failed`, with their failing checks). The session does not read the failure log itself (Cost
Control): an anonymous direct subagent — `subagent_type: autoflow-analyzer`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names — reads
the failing check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`<out>/ci-failure.md` with the failing check, the first failing assertion or error, where the fix
that clears it is made — the implementation, a test asset, a document, or the design when clearing
it would discard or change a decision the design settled — and the grounds for that judgment, and
returns the path and a one-line summary. Where it cannot judge with confidence, it puts the judgment
to the advisor and records the advisor's decision with its ledger entry
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; [`core.md`](<autoflow-root>/docs/core.md) >
Development Lifecycle > *Decisions within a module*).

**Failure output**: a failure output it cannot obtain is a tool request ([`core.md`](<autoflow-root>/docs/core.md) >
Development Lifecycle > *Tools*); a check whose output could not be read is named in
`<out>/failure.md`, with what was tried.

<!-- From <autoflow-root>/docs/decision-ledger.md -->

# Decision Ledger

The per-attempt decision ledger, `<attempt-dir>/issue-{N}-ledger.md` in the record directory the
invocation names: what an entry records, how it is identified, and the grammar of the entries a
decision point produces. The ledger holds decisions: entries that settle what a module cannot settle
itself ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D8). The ledger's
standing constraints — append-only, no re-litigation without a new verified fact, and identifier
allocation — are [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger.

## Entries

- Each entry records the decision (one line) and its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence). An entry written before this grammar may carry an `- Authority:` line, which settles nothing, and may name the entry it replaces on an `- Overrides:` line, read as a `- Supersedes:` line.
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the correction is **decided as the decision was** — a decision recorded in the feature design, not the ledger, by a design run naming its heading there, and a ledger entry by a fresh advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor); (3) the correction records the reproducing command and its summary line in the grounds form above and names what it supersedes — for a ledger entry, in the superseding entry's grounds, by the superseded entry's identifier; for a feature-design decision, in the design run's delta item, as `supersedes <heading>` ([`units/design.md`](<autoflow-root>/docs/units/design.md)). A change of preference or a re-interpretation of the same material is not an error and stays barred.

**What the ledger holds.** The advisor's decisions, each with its answer file
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor); the `[ac-decision]` entries that record a change
to an acceptance criterion, the criterion review's included (*Acceptance-criterion decisions* below).
A module's own decisions and records are its own outputs
([`units/design.md`](<autoflow-root>/docs/units/design.md), [`units/build.md`](<autoflow-root>/docs/units/build.md) > Build report), which name
the ledger entries the run followed. An evaluation's result, a count of re-runs and the checks of the
environment are not ledger entries (*ibid.* D8).

## Entry identifier

A settled-decision entry is headed `## A<n> — <title>`, where `A<n>` is the letter `A` followed by a
serial; an entry of a kind that has a marker ends its heading with it — `## A<n> — <title> [<marker>]`.
The heading names no cycle or phase. A ledger written before this grammar may carry identifiers of
other letters (`O`, `E`, `F`), each with a serial of its own; a reader reads an identifier of any of
these letters as it is. Such a ledger may also carry `(cycle <C>, <PHASE>)` after a heading's title and
level-3 record headings with no identifier; no reader reads either.

- **Allocation**. `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger>` issues every identifier, called immediately before that entry's own append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). It takes the next serial above both the highest in the file and the highest already reserved, and reserves it before printing it — an empty directory `issue-{N}-ledger.ids/<ID>` beside the ledger, which one caller alone can create. Writers that call it concurrently — two advisors spawned together, each allocating before the other has appended — therefore receive distinct identifiers. A reserved identifier that is never appended (the append denied, the writer stopped) leaves a gap in the serial; a gap is not a defect, and `check` does not report one. A writer whose append must be retried keeps the identifier it was issued.
- **Identifier collision**. Two entries can share an identifier — entries written before this protocol or before `next` reserved what it issued, or a heading appended in error; they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair. A reader that resolves a supersession by identifier (`<autoflow-root>/scripts/gate/security-checklist.sh`) displaces every earlier entry it counts that the named identifier matches, so the re-deriving entry is the one that stands.

## Decision-point entries

**Advisor decisions.** A decision a module puts to the advisor
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor) is recorded as one entry per decision, carrying a
`- Record:` line to where the advisor's answer is, and the
marker and fields its kind requires below.

**Replacement is explicit.** An entry is never edited to change a decision — the gate hook keeps the
ledger append-only ([`core.md`](<autoflow-root>/docs/core.md) > Records and the hook). A later entry replaces an earlier
one only by naming it on a `- Supersedes: <id>` line, on a new verified fact or the verified-error
exception. Two standing entries on the same subject whose conclusions disagree, with neither naming
the other, are a **conflict**: neither is applied, nothing is settled by recency, and the conflict is
resolved by a new entry — the advisor's — that names the entries it resolves. The same conclusion
recorded twice is not a conflict. An identifier two entries already share is read as *Identifier
collision* above says, never repaired by editing either entry.

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is
never a module's to apply. A change the work shows a criterion needs — in the analysis, the design or
the build, or in an evaluation's recommendation that a later module takes — is decided by the advisor
the module spawns, and the module follows the decision ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) >
Advisor); the criterion review's dispositions that change a criterion are recorded as entries of the
same grammar ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). The change stands only as
the entries below ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1); choosing how a criterion is
*verified* is the design's, provided the row states its reason, which the reviewers then judge at
REVIEW (the three-tier guard — [`units/design.md`](<autoflow-root>/docs/units/design.md) > *Report routing*). The change
excludes, revises or splits a criterion, or adds one. An added criterion's text is changed by
superseding the entry that added it with a new `added` entry. The decision is recorded as one entry per
decided AC, in the same trailing-marker grammar: the heading `## A<n> — <title> [ac-decision]`,
followed by the entry's own `- AC: <ac id>` line (for an added criterion, the id it takes), a
`- Disposition:` line valued `excluded` / `revised` / `split` / `added`, the criterion's text as
decided — `- Text: <text>` for `revised` and `added`, and for `split` one `- Into: <id> — <text>` line
per criterion it makes, in order —, and the ordinary Decision and Grounds lines; an advisor's entry
adds its `- Record:` line:

```markdown
## A4 — split AC2 [ac-decision]
- AC: AC2
- Disposition: split
- Into: AC2a — <the first criterion's text>
- Into: AC2b — <the second criterion's text>
- Decision: <the decision, one line>
- Grounds: <the grounds>
- Record: <where the advisor's answer is>
```

`<autoflow-root>/scripts/contracts/criteria-apply.sh` applies the entries, in ledger order, to the
analysis report's acceptance-criterion table, and its output — the applied criteria — is what every
later module takes ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D8); the
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
split: `split` / `excluded`). A defect so judged is put to the advisor by the module whose work shows
it — an evaluation records it as a recommendation, which the module that takes it puts to the advisor;
it is never resolved by keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the unit documents and agent definitions cite it.

The marker sits at the **end** of the heading, and an entry is located by it. Entries for one AC whose
conclusions disagree, neither naming the other, are a conflict (*Replacement is explicit* above). A
criterion the entries add or change is owed its verification-design row and its discharging site like
any other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and AUDIT reads it as of the attempt's base commit ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1).
Changing it within the attempt — the file, or the declaration that points at it — is never the
attempt's own to accept: when `<autoflow-root>/scripts/gate/security-checklist.sh status` reports the
change, the module whose work made it puts the change to the advisor, and the decision is recorded in
the same trailing-marker grammar: the heading `## A<n> — <title> [checklist-decision]`, followed by a
`- Checklist:` line (the declared path at HEAD, or `none` when the declaration is dropped), a `- Blob:`
line (the `git rev-parse HEAD:<path>` of the approved version, or `none`), a `- Disposition:` line
valued `accepted` / `rejected`, the ordinary Decision and Grounds lines and the `- Record:` line, plus
the `- Supersedes:` line when it replaces an entry. The script counts an entry only when its Decision
and Grounds lines are non-empty and its Disposition is `accepted` or `rejected`, and only while its
Checklist and Blob equal HEAD's, so a later edit to the checklist is a new change owed its own
decision. An entry stands unless a later counted entry replaces it by name (*Replacement is explicit*
above). The standing entries decide only when they agree: all `accepted` → the change is covered; all
`rejected` → it is not, and the change is reverted before AUDIT reads it; both → a conflict, reported as
`conflict=<ids>` on an undecided (exit `3`) record and resolved by a new entry, never by recency.

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

Filing is not readiness: each attempt of the issue reviews its acceptance criteria in its own
criterion review, and the analysis takes the criteria as that review's record settles them
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

## Advisor (decisions a module puts to it)

ADR-0025 D7 made a dedicated advisor the first judgment at a decision point; the module whose work
meets the decision spawns it and follows its decision. This section is the procedure's single home;
[`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module* routes to it, and the module documents cite it.

### Decisions the advisor makes

- **The working AI decides what it can**, and records each decision with its grounds in its output
  ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2): a planning, design or ADR prerequisite the
  analysis records, a finding that repeats an earlier complaint, the scope a problem belongs to.
- **The module puts to the advisor**, and follows the advisor's decision:
  - a change to an acceptance criterion's content that the work after the criterion review shows
    (`[ac-decision]`; [`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*);
  - a root cause, or a lever, that is not code — the analysis's `non-code lever` conclusion;
  - a hypothesis PASS the module judges unreachable — an analysis re-run that judges no report will
    meet what the hypothesis evaluation asks;
  - a design point not agreed — one the design cannot settle on the grounds at hand, or one two areas
    of a build meet differently;
  - a finding whose fix the AI acting on it cannot place with confidence, and a rebuttal the
    re-score or the reviewer keeps while the two sides still disagree;
  - an item the criterion review could not decide with confidence
    ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*);
  - every change to the target's security checklist (`[checklist-decision]`;
    [`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Security-checklist decisions*);
  - any other point the module doubts ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module*).
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial). The run records it in its output situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Execution
  Principles > Human-decision presentation) and goes on with the work that does not depend on it. A
  tool, credential, installation or material the environment does not provide — for a tool it has,
  what using it lacks (access, a purpose and permitted scope, a permission setting) — is a tool
  request: the run does what it can without it and ends ([`core.md`](<autoflow-root>/docs/core.md) > Development
  Lifecycle > *Tools*).

### Procedure

1. **Request.** The module writes `<out>/advisor-request-<k>.md` for a fresh `autoflow-advisor`
   (anonymous; model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model advisor`):
   the situation, the decisions it asks for, its own reading and the point where that reading stops.
   Decisions that depend on each other's answers go in one request; a decision that stands apart
   goes in its own. The prompt names the request file, the ledger — `issue-{N}-ledger.md` in the
   record directory the invocation names — and the issue.
2. **Decide and record.** The advisor answers the decisions the request asks for, writes its answer
   beside the request, in the module's output directory, and records each decision as its own ledger entry
   with its grounds and a `- Record:` line to the answer file ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)).
   A decision it finds the request needs but does not ask for, it names in its answer for the module
   to put in a request of its own. Each identifier comes from
   `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger>`, called immediately before the
   append; the ledger is append-only, which the gate hook keeps (*Independence* below).
3. **Follow.** The module follows each decision in its work and names its entry in its output. An
   advisor that reports a decision blocked at the harness level turns it into a harness-level block.

### Independence

The advisor is never the author of what it judges: it is a fresh spawn per request, not the agent
or session whose work raised the point, and its record carries its own grounds. The record stays as
written:

- **Append-only — the gate hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`, *Section 1e*,
  state-independent): a `Write` / `Edit` / `MultiEdit` to an `issue-*-ledger.md` is applied to the
  file on disk and must keep the whole prior content as its prefix, so no entry is rewritten or
  removed. A decision changes only by a new entry that names the one it replaces
  (`<autoflow-root>/docs/decision-ledger.md` > *Replacement is explicit*).
- **The record convention**: a consumer lets an entry replace another only by an explicit
  `- Supersedes:` line (`<autoflow-root>/scripts/gate/security-checklist.sh`,
  `<autoflow-root>/scripts/contracts/criteria-apply.sh`, which locates an entry by its `[ac-decision]`
  marker).

The threat the hook answers is an agent overstepping in routine work — rewriting a ledger it meant to
append to — not a determined evasion (the same model as `<autoflow-root>/docs/issue-proposal.md`).
Outside the hook's surface: a shell write to a ledger (redirect, `tee`, `sed -i`, a script), and text
that only imitates an entry (a heading-less field line, a malformed heading).

### Claude Code's advisor tool (`advisorModel`)

Distinct from the advisor sub-agent above: Claude Code's advisor tool
(<https://code.claude.com/docs/en/advisor>) lets the session's model consult a stronger model
mid-task. AutoFlow's decisions go to the sub-agent: the tool's model is configurable and its effort
is not, and Claude decides when to call it, so the decisions above are the sub-agent's (ADR-0025 D7).

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

When a role spawn reports to the session that spawned it, the report is the spawn's return value:

1. **The body goes to the run's output directory.** The report points at it — record files, source files and commits by path and hash — and does not carry it.
2. **Evidence anchor**: a claim that something is done, passes or is fixed carries an anchor its reader can confirm — whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the run's **log** — the file its output was written to (Testing Standards item 7), cited by path under the run's `<out>/local/` — with the command that produced it and the exact `Tests: N passed, N total` (or equivalent) summary line read from that log. The log is the evidence and the summary line is the value read from it; a line no log carries is not evidence (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, plus the verbatim content of that line (a line number is read only at that commit — [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger)
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under the run's `<out>/local/`, with its result line (`observation: match` / `observation: mismatch — …`) read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the committing role identified, followed by the grounds of the identification — where it looked (the documents, scripts and CI files read) and each CI lint step it did not count as a chain with the condition that excludes it — the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked, its source (document section, script definition or workflow `path:line` and step name) and the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*), the reason, and the unexecuted chain's identity (its command and source, or the workflow `path:line` and step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this pull request — the workflow's `on: pull_request` entry, either no `paths:` filter or one whose patterns match a staged file, and a job and step condition that admits this pull request; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-covered` → the chain and the file set it covers; `not-applicable` → that word alone, with the grounds naming where the committing role looked. A report citing one chain where the committing role identified several is malformed, not compliant.

   Anchors must be deterministically confirmable by their reader — the session that spawned the role, an evaluator — against what produced them (`git show <SHA>` / the summary line read in the cited log / `git show <SHA>:<file>`); a test-pass anchor is confirmed by reading, not by re-running — the command is re-run only when the log is absent or does not carry the line, and the run is then `not-run` and run in place. Reports without an anchor are rejected, not interpreted. This item's line-number forms are for the report; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.
3. **Short**: the report holds what its reader needs to act and to confirm, and no more.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Verification and Tools -->

## Verification and Tools

This section applies to every actor of a module's run — the session that runs it and every role it spawns.

**Local verification** (the instance of [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2 the modules cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every test it authored or changed and every check the verification design runs before delivery — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format > *Evidence anchor*). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is the pull request's CI — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to (Testing Standards item 7's `$LOG`), cited by path under the run's `<out>/local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the spawning session's acceptance of a role-spawn report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Verify role-spawn claims*), AUDIT's test-first judgment, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the build unit, or a helper it spawns — finds, in the target checkout it works in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **run's own check** — a test the target's tree does not keep, a check run before delivery, a manual checklist — lives in the run's store `<out>/local/`, under the record root outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's absolute path in the store** and is run from the target checkout's root: the asset finds the tree it checks from its working directory (`git rev-parse --show-toplevel`), never from its own location, which is outside every tree. The verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A run that wants one command for several assets writes that driver *as* an asset in the same store. Such an asset is never committed, and stays with the attempt's other records, where a later run reads it. An asset writes its reproducible output — a build result, a copy of a source tree or of another original: an output re-creatable from inputs its record already names, such as a commit and a command — only under the store's reserved path `<out>/local/disposable/`, the one path that can be deleted with nothing the records cite lost; its deletion is outside AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). Nothing a run record, an observation record or a report cites ever goes there — not a log, a record file, the artifacts an observation left, or the asset itself, whose path the recorded command names — even when it is re-creatable. Whether an output is reproducible and uncited is the writer's judgment; where such an output goes is not. Only the store's top-level `disposable/` is reserved — a `disposable` deeper in the store is kept like any other path — and reproducible output left outside it is a deviation, kept with the rest of the store.

**The tools the work needs are found and used; what is missing is requested, and the run still ends**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the main session ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Background execution is the main session's only*), and stopped once the run no longer needs it. A tool that cannot be used has something missing: the tool itself when this environment does not have it — an installation, enabling an MCP server or a browser extension — or, for a tool it has, what using it lacks — access, the purpose and permitted scope of the host or service it reaches, a credential, a permission setting. Providing any of these is outside the assigned scope ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); using a tool the environment already provides is not. What is missing is recorded as a **tool request** — `{missing, instead}` in `<out>/tool-requests.json` and in the run's report: what is missing, named as what is missing and not as the output the tool would give, and what the run did instead, each verification it left unrun or ran on a mock or a person's observation for the lack included. The run does what it can without it — a mock, an observation, a verification left not run, by its own judgment — and ends; the delivery module states every request in the pull request, and the operator decides on it ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Tools*). A purpose or permitted scope is a project fact, and its request asks that the operator record it in the project's information ([`core.md`](<autoflow-root>/docs/core.md) > Project Information). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened is a tool request the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under the run's `<out>/local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each module does this: `<autoflow-root>/docs/units/analysis.md`, `<autoflow-root>/docs/units/design.md` > *Tools* and `<autoflow-root>/docs/units/build.md` > What the build owes.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — a later module given the record, GATE:QUALITY's `Test coverage` or `Commit conventions` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL; a run that fails is recorded as its module's procedure says.

**What a change leaves in the target's tree is not classified by AutoFlow**. A change adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the change does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI*, *Added test files*), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->
