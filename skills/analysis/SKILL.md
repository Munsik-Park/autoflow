---
name: analysis
description: >-
  Run the AutoFlow analysis module once on an invocation file — the analysis
  report, each conclusion with its grounds. Use when the operator runs the
  analysis module (/autoflow:analysis <invocation.json>).
argument-hint: "<invocation.json>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the attempt's record directory the invocation names (`records`). Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: the invocation file) — one run of the analysis module (`<autoflow-root>/docs/contracts/analysis.json`) on that invocation: `bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>` first — a refused input ends the run with its report —, then the work, which ends when its outputs reach the module's goal and writes them and `<out>/tool-requests.json` (`[]` when the run lacked nothing, *Tools* below) — a run that does not reach the goal writes `<out>/failure.md` in place of its outputs —, then `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json`; the run ends with the report its procedure owes. The work is one `autoflow-unit-analysis` spawn on the model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-analysis` names (`<autoflow-root>/docs/units/analysis.md` > Unit spawn, below). The invocation's `records` is the attempt's record directory, where earlier runs left their work. Every `Agent` spawn the run makes takes its model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` — the advisor's key is `advisor` (*Spawn Model*, below).

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that the analysis module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle: Push and PR creation; Development Lifecycle > Module procedures: criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, criteria-apply, hypothesis, design, plan, build, audit, quality, delivery, ci, review; Development Lifecycle > Module references: criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, criteria-apply, hypothesis, design, plan, build, audit, quality, delivery, ci, review; Project Information: In a project whose information names sub-repos; Team Structure: Build module.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/analysis.md`; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; `<autoflow-root>/docs/units/completion-evaluation.md` > Recommendation triage; `<autoflow-root>/docs/units/review.md` > Review triage > Whether a finding holds; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules > Scope judgment; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

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

**AutoFlow is a set of modules.** A module is an input, the work it does, and an output; its contract, `<autoflow-root>/docs/contracts/<module>.json`, declares its parameters, its inputs and where each comes from, and its outputs with the form each must meet (`ADR-0038` D1). The modules are functional — the criterion review's four, analysis, design, build, delivery, ci, review —, evaluation — hypothesis, plan, audit, quality — and deterministic — criteria-apply. AutoFlow defines the modules: each one's contract, its procedure and the checks of its inputs and outputs (ADR-0038 D2). A module takes everything it works on from its invocation, the branch and the attempt's record directory included (D4).

**A module runs once, on its invocation.** An invocation file names the module's parameters, its inputs, its output directory, for a functional module the attempt's record directory and, when it has any, its `instructions` (the invocation's form: `<autoflow-root>/scripts/contracts/contract.sh`, header). The module checks its inputs' form first (`bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>`) and does not run when one fails; where an input came from is not checked. It does its work once, writes its outputs into its output directory, and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json` — `accepted`, `refused`, or `failed` when the module wrote the failure output its contract declares (`ADR-0039` D3) —, the outputs, the defects, the tool requests and the AutoFlow that ran the module (its version and root). Check-in and check-out see the form of an input or an output only, each file read alone: nothing in git, on GitHub or in another input is read to check it (`ADR-0040` D2).

**A module's procedure states the goal of its work.** It says what the work must achieve; the AI judges how to meet it, and when the output it has made reaches the goal, the run ends. A run that does not reach its goal writes, in place of its expected output, its contract's failure output — what it did and why it did not reach the goal — and ends (ADR-0040 D1). Whether the output is right, and what is done with it, are for the side that runs the module (ADR-0038 D2). The applied criteria every module after the analysis takes are criteria-apply's output, computed from the analysis report's table and the `[ac-decision]` entries (`<autoflow-root>/docs/decision-ledger.md` > *Acceptance-criterion decisions*); the issue's criteria are first reviewed against the target's code and policy by the criterion review's modules (`<autoflow-root>/docs/criterion-review.md`).

**Where an output goes.** Each output has a default — what its contract and its procedure state: a file in the output directory, and for some modules beyond it, a push, a pull request, a comment, a pull request's body. The invocation's `instructions` change where an output goes or its form, and the module follows them; the authority rules hold under any instruction (ADR-0040 D5).

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
| `delivery` | `/autoflow:delivery` | `<autoflow-root>/docs/units/delivery.md` | the session itself |
| `ci` | `/autoflow:ci` | `<autoflow-root>/docs/units/delivery.md` | the session itself |
| `review` | `/autoflow:review` | `<autoflow-root>/docs/units/review.md` | the session, which runs the reviewers; the round's reviews are aggregated by an `autoflow-analyzer` spawn (`handoff-review-triage`) |

A module's command takes the module's invocation file (`/autoflow:<module> <invocation.json>`) and runs the module once on it. Each module runs in a session of its own, and one session can run modules one after another: every input is a file the invocation names. An evaluation's spawn writes its report to `<out>/evaluation.json` and returns the path (`<autoflow-root>/docs/role-contracts.md` > Evaluation AI). The phase and gate names stay as identifiers: the spawn-policy keys and the documents' headings carry them.

The **reference values** an evaluation's scores are read against (each item ≥ 7, average ≥ 7.5, a `Security` item at 3 or below → rework) are kept with the rubrics (`<autoflow-root>/docs/evaluation-system.md` > PASS Criteria) and carried in each evaluation contract's `reference`. An evaluation outputs its scores and their grounds, with the reference values (ADR-0038 D6).

```
analysis              — the analysis report: current structure, the gap to the request, whether a change is owed and code is the lever (the conclusion), the cause where a defect is reported, acceptance-criterion table, scope judgments, affected docs, decision points — each conclusion with its grounds, its method (how far and by what means a cause is pursued included) its own
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every module: a module's command body carries the parts of this core its module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and the documents the module uses with them (*Module references* below, *Context Injection*).

The rubric of every evaluation — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the work's: it lives in `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics*, the procedure of each evaluation contract.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in `<autoflow-root>/docs/evaluation-system.md`; how the evaluator is spawned and prompted is `<autoflow-root>/docs/role-contracts.md` > Evaluation AI.

### Module references

| Module | Its command body also carries |
|------|------|
| analysis | the procedure: `<autoflow-root>/docs/units/analysis.md`; unit agent: `autoflow-unit-analysis`, contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; recommendation triage: `<autoflow-root>/docs/units/completion-evaluation.md` > Recommendation triage; whether a finding holds: `<autoflow-root>/docs/units/review.md` > Whether a finding holds; including or separating a problem: `<autoflow-root>/docs/submodule-common-rules.md` > Scope judgment |

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
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): how far the work goes — the analysis, the design, the build's execution, how the delivery shows the change working — is the working AI's judgment, recorded with its grounds in the output its run produces. What no module does is judge its own output: each evaluation is a module of its own, scored by a fresh Evaluation AI that never saw the work done, and CI (its verdict on the pull request's head — where the target's CI does not run for it, that fact, a verdict apart from green) and the aggregated review stand outside the work as well.
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
- A cross-service change is made by each scope's module run, and the pull requests it takes across the scopes are the delivery module's (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*).

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states the AI establishes from the repository itself where it can — its remotes, its `.gitmodules` — and otherwise records as a tool request: the missing fact, and the file that would state it.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

### Evaluation AI — contract: `<autoflow-root>/docs/evaluation-system.md`; spawn and prompt: `<autoflow-root>/docs/role-contracts.md` > Evaluation AI
### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor
### Functional-unit agents (analysis, design, build) — contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents

## Records and the hook

**Record directory.** Every record of an attempt lives in the attempt's record directory `<attempt-dir>`, under the record root — outside every checkout's tree, `autoflow-records root` (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`) —, which each invocation names as `records`. Each run writes into its own subdirectory, `<attempt-dir>/<module>-<n>` (`<module>-<qualifier>-<n>` for one module run on several items in a round, `n` counting that module's runs from 1), so nothing is renamed or overwritten; a functional module reads what earlier runs left in the directory, and an evaluation module keeps to its declared inputs (ADR-0038 D4). The ledger is `<attempt-dir>/issue-{N}-ledger.md`, the name the hook's ledger check reads.

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger; an `Agent` spawn without an explicit `model`; and a backgrounded `run-suites.sh`. With no `jq` it reads the other denies from the raw input; the ledger check reads the write with `jq`, and with no `jq` it passes the write unchecked.

## Evaluation System
→ `<autoflow-root>/docs/evaluation-system.md`

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

<!-- From <autoflow-root>/docs/units/analysis.md -->

# U2 Analysis — DIAGNOSE and GATE:HYPOTHESIS

> The procedure of the analysis module, and the spawn of the hypothesis module. [`core.md`](<autoflow-root>/docs/core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) >
> Modules.

U2 Analysis is two modules: the analysis module, whose contract is
`<autoflow-root>/docs/contracts/analysis.json` and whose procedure is this file, and the hypothesis
evaluation module that scores its report (`<autoflow-root>/docs/contracts/hypothesis.json`,
[`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:HYPOTHESIS;
[`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D1). This file states
the analysis's goal, what it owes, the cautions it is asked to heed and the report it writes. How the
module reaches the goal — what else it reads and in what order, whether it spawns helpers and what it
gives each, how it keeps the cautions — is its own, recorded with its grounds in its report
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

- **Goal**: the request understood well enough to be evaluated — the affected structure as it
  stands, the gap between it and the requested behavior, whether a change is owed and whether code
  is the lever, and the decision points, each conclusion with its grounds.
- **Output**: the analysis report (*Analysis report* below), and the run's tool requests
  ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Tools*).
- **Evaluation**: the hypothesis module — a fresh Evaluation AI scores the report on one form for
  every issue: whether the report's conclusion is supported by its grounds and whether the analysis
  met its goal (*Evaluation — GATE:HYPOTHESIS* below). The module never scores its own report.
- **Result owed**: the report's path and a one-line summary that names any decision point it
  recorded ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Reporting Format).

## Unit spawn

- **The spawn.** One `autoflow-unit-analysis` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-analysis` names) runs the
  module. Its prompt states the goal, names the inputs the invocation gives by path — the issue
  (`params.issue`), the criterion review record, the decision ledger's
  `[ac-decision]` entries, the target's documents, and on a re-run the previous report and its
  evaluation, or the findings it answers (a quality evaluation's or a review's) — the attempt's
  record directory, where earlier runs left their work, and the output directory the report goes to.
- **What the run is for is read from its inputs.** Given the criterion review record, the run
  analyzes the issue the record reviewed (*Criterion review record* below). Given the previous
  report and its evaluation, it brings that report up to date on the evaluation's findings, and
  what else it reuses from the earlier runs in the record directory is its own, recorded under
  `## Method`.
- **Documents.** The unit's agent definition carries the documents the analysis needs (this file, and the
  rubric it is scored on, [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* >
  GATE:HYPOTHESIS) with the rest of its guidance ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection);
  the prompt copies none of them, and the module reads anything further by its own judgment.

## What the analysis owes

The analysis is asked for four things, each conclusion with its grounds:

- the affected structure as it currently is, stated as fact;
- the gap between that structure and the behavior the request asks for — and, where the request
  reports a defect, the cause the gap comes from;
- whether a change is owed and, if so, whether a code change is the lever that closes the gap, or
  data, configuration or operations are;
- the decision points — the judgments that settle what follows the analysis, each with its decision.

How far the analysis pursues a cause, and by what means — how many explanations it weighs, which
ones, what it checks and with which tool — is the module's judgment, recorded with its grounds under
`## Method` and `## Cause`.

The request is the trigger target — the issue, a review comment or thread, or the finding a
re-run is for — and the as-is is the state it is measured against, which the module judges from
its inputs and records under `## Method`. The question is whether the as-is already
satisfies the request.

**Cautions.** Each names a bias the analysis is to avoid:

- Describe the current structure as fact, apart from the issue's defect hypothesis — do not read the
  structure to fit the hypothesis.
- A conclusion that a code change is required rests on evidence that the gap is not closed by
  data, configuration, the environment or an earlier fix; a cause that was not established is not
  presented as one.
- The necessity judgment is reuse-neutral: a resolution that uses existing code is not marked down
  for it. Structural fit and over-engineering are GATE:PLAN's and GATE:QUALITY's.
- Open every material the issue body or an acceptance criterion references — a design mockup, an
  asset, an external document — yourself; one that cannot be opened is recorded with the reason.

How the module guards against these biases — whether it separates the structure reading from the
issue reading, in what order it reads, what it gives or withholds from a helper — is its own,
recorded with its grounds under `## Method`.

The rules below are the ones other documents cite; everything else about the work is the module's.

- **Acceptance criteria.** The report's `## Acceptance criteria` table restates the issue's
  criteria faithfully, as the issue body states them; it is the table
  `<autoflow-root>/scripts/contracts/criteria-apply.sh` reads, and its output — the applied criteria
  — is what every later module takes. A re-run carries the table forward unchanged: a change to a
  criterion stands only as an `[ac-decision]` entry, which criteria-apply applies, and the table is
  not edited to match it ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion
  decisions*; `<autoflow-root>/docs/core.md` > Decision Ledger).
- **Criterion review record.** The issue's criteria were reviewed against the code and policy by
  the criterion review's modules: the record criterion-reconcile wrote holds the decisions, with
  the body they were made on by its sha256, and a decision on a criterion's
  content is an `[ac-decision]` entry ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)); the record
  is an input, not a verdict. An issue body that differs from the one the record names is a
  criterion change made outside the review, which the analysis puts to the advisor. The analysis
  reads its findings as an
  earlier reading of the code and policy at the commits its `## Inputs` names: a finding the
  analysis builds on — a confirmed cause, a policy it cites — is checked at the commit the run starts
  from, and a difference from the record is recorded with its grounds. The record changes nothing
  about how the criteria are taken: the `## Acceptance criteria` table restates the issue's criteria
  as the body the record names states them, the analysis does not run the
  review again (issue #291: the analysis takes the criteria as written), and a defect it observes as
  a fact it puts to the advisor ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
  Decision-point entries > *A criterion can be wrong*). The record's dispositions hold each
  item the review decided, with its grounds; `## Screening` lists each case a criterion applies to
  with the code that decides it, and `## Cause reach and rule conflict` where a confirmed cause
  reaches beyond the reported points or a required behavior meets a rule in force, each read like
  the findings as an earlier reading; `## Reconciliation` records, per stage 2 finding and per
  in-depth case, whether it was applied, rejected or left unresolved. The record's `## Unchecked`
  items, and each case left `unresolved`, are findings the analysis may close with its own checks
  (*Checking a finding* below). How the record was used is recorded under `## Method`.
- **Referenced materials.** Each material is recorded under `## Referenced materials` — what it is,
  where it is, how it was opened, and what it shows for the criterion that names it; the material,
  not an abbreviated example in the body, is what the criterion means. A material that cannot be
  opened is recorded `not opened: <reason>` and as a tool request — what is missing, and what the
  analysis concluded without it — and the run goes on to its end ([`core.md`](<autoflow-root>/docs/core.md) >
  Development Lifecycle > *Tools*; [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) >
  Verification and Tools > *The tools the work needs*).
- **Checking a finding.** A finding the analysis checks is checked with what the environment and the
  target's documents and scripts provide — API calls, queries, service status, logs — and those tools
  are looked for before a finding is left unchecked; a tool that is off is started by the target's
  own procedure, and one that needs the operator is recorded as a tool request (*The tools the work
  needs*). The report records each tool a conclusion rests on and whether it was usable; a finding left unchecked
  names the tool it needed.
- **Scope judgments.** Beyond the acceptance criteria, the analysis names the problems the confirmed
  cause carries — its other sites, and what fixing it will expose — with the scope judgment for each
  and its grounds ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface
  Rules > *Scope judgment*). The design module reads them and settles the scope in the feature
  design; the analysis does not decide it alone.
- **Decision points.** The analysis decides each judgment that settles what follows it, and records
  it under `## Decision points` with its grounds: a planning, design or ADR prerequisite clearly
  required before the issue can be implemented (when in doubt, none); a request the as-is already
  satisfies; on a reviewer finding, one that repeats an earlier round's complaint with a different
  witness case ([U7 Review](<autoflow-root>/docs/units/review.md) > *A repeated complaint*). A gap or a cause whose lever is not
  code, and — on a re-run that answers the hypothesis evaluation — a judgment that no report will meet
  what the evaluation asks, it puts to the advisor, as any point it doubts, and records the advisor's
  decision with its ledger entry ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor). A suggested
  split of the issue stays a suggestion in the report; an issue is filed through a draft and
  `<autoflow-root>/scripts/issue/create-issue.sh` ([`issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md)).

## Analysis report

`<out>/issue-analysis.md`. The first run writes it whole; a re-run, given the previous report, brings it
up to date rather than rewriting it, its `## Acceptance criteria` table unchanged. It records what
the table below lists, for the readers it names; the headings and the form are the module's, and a
matter with nothing to record is said to have none — except the `## Acceptance criteria` table,
whose heading and columns criteria-apply reads.

| Section | Holds | Read by |
|---|---|---|
| `## Method` | how the analysis was done — the reading order, any helper spawn and what it was given — and how each caution was kept, with grounds | GATE:HYPOTHESIS |
| `## Current structure` | the affected area as it stands — its structure, design intent and data flow — stated as fact | GATE:HYPOTHESIS |
| `## Request` | the concrete cases the request names, the problem type they share, and the resolution approaches it calls for | GATE:HYPOTHESIS |
| `## Acceptance criteria` | a table with the fixed columns `AC id \| criterion \| source`: `AC id` a short readable name unique within the issue, `criterion` the issue's criterion restated faithfully, `source` its place in the issue body | criteria-apply |
| `## Referenced materials` | each material the issue or a criterion references, as *What the analysis owes* says, or `none` | the design module |
| `## Necessity` | whether the issue is a bug / incident; per resolution approach, the behavior gap and whether code is the lever, with grounds; and the conclusion, exactly one of `no change needed` (the as-is already satisfies the request, or nothing is left to do), `non-code lever` (a real gap whose lever is data / configuration / operations) or `code change` | GATE:HYPOTHESIS |
| `## Cause` | where the request reports a defect, the cause the analysis established and the evidence for it, how far the cause was pursued and why — or, where it is not established, what is known and what was left unchecked; otherwise `none` with the reason | GATE:HYPOTHESIS |
| `## Scope judgments` | each scope judgment, as *What the analysis owes* says | the design module; GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Affected documents` | the documents the change is expected to update | the design and build modules |
| `## Decision points` | each decision point with its decision and grounds — for one put to the advisor, the advisor's decision and its ledger entry — or `none` | the design module |

Anything else the module records is its own, written where it judges useful.

## Evaluation — GATE:HYPOTHESIS

The hypothesis module scores the report: one independent Evaluation AI (`autoflow-evaluator`),
fresh-spawned per run on the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-hypothesis` names, on the
rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:HYPOTHESIS — one
form for every issue. Its agent definition carries that document, and its output is the scores and
their grounds with its recommendations.

## Spot-check & escalation discipline (incomplete-output guard)

A spot-check is a read that confirms a finding of a module's output — the analysis report or any
other — before it feeds a decision, a blocker, or a harness-level block. A Claude
Code behavior produces a **false "absent / stub" reading**:

- **Read-dedup stub.** A re-read of an unchanged file returns a 1-line stub ("file
  unchanged … refer to that earlier tool_result"), and the dedup ledger is not reset on a
  rewind (or a compaction). The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags this
  at runtime — these rules are the procedure it points to.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a decision or a
  harness-level block**. A single read is never sufficient grounds.
- **[MUST]** A blocker-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool.
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged`). It is a harness stub, not
  data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after the spawn has returned**, as single
  sequential commands. Another
  directory is addressed with `git -C <path>` + absolute paths rather than a
  `cd`-prefixed compound, which can raise a permission prompt.

<!-- From <autoflow-root>/docs/role-contracts.md > Functional-unit agents -->

## Functional-unit agents (U2 / U3 / U4)

Three functional modules run their work as a unit agent, prescribed by the module's goal, its output
and its evaluation ([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D1); the
evaluation of each is a module of its own. The criterion review's agents are *Spawn mode by role
lifetime* above; criterion-screen, delivery, ci and review are the work of the session that runs them, and
criteria-apply is a script.

| Unit agent (`subagent_type`) | Module (unit) | Its evaluation module |
|---|---|---|
| `autoflow-unit-analysis` | analysis (U2 Analysis) | hypothesis |
| `autoflow-unit-design` | design (U3 Design) | plan |
| `autoflow-unit-build` | build (U4 Build and verify) | audit, which judges test-first |

- **Method is the unit's.** How the unit reaches its goal — what else it reads, whether it spawns helpers
  or holds a dialogue, how it designs the issue's own verification — is the unit agent's, recorded
  with its grounds in the unit's artifact ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).
  The definitions (`<autoflow-root>/agents/autoflow-unit-*.md`) name the goal, the output and the
  evaluation, and nothing else of their own; below that they carry the unit's guidance, generated
  ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection).
- **The run ends at its goal.** The unit judges when its output reaches the goal, and ends there; a
  unit that does not reach it writes `<out>/failure.md` in place of its expected output — what it
  did and why it did not reach the goal ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle;
  [ADR-0040](<autoflow-root>/docs/records/adr/0040-a-module-ends-at-its-goal.md) D1).
- **The authority rules hold** (ADR-0025 D3): a unit agent never scores its own artifact, never
  pushes, merges or files an issue, and a decision of the kinds the advisor makes, or one it doubts,
  it puts to the advisor and follows (*Advisor* above).
- **Model and effort** come from the policy rows `unit-analysis`, `unit-design` and `unit-build`,
  held at the values of the phase rows each unit replaced (DIAGNOSE; ARCHITECT; RED /
  GREEN). The helpers a U4 unit spawns when it divides its work take theirs from the rows
  `unit-build-area`, `unit-build-verify` and `unit-build-observe`: each is spawned as
  `general-purpose` with the row's model and with the row's effort passed as the `Agent` tool's
  `effort` parameter, omitted when the row reads out the inherit sentinel
  ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *Dividing the work*). A helper receives in its prompt
  the AutoFlow root and the text of the rules its work follows
  ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *What crosses a boundary*).

---

<!-- From <autoflow-root>/docs/units/completion-evaluation.md > Recommendation triage -->

## Recommendation triage

An evaluation's `recommendations` — at GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY alike —
are findings the evaluator recorded, each with its subject, the item it was found under, its severity
and the finding ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format). They
are disposed of as a reviewer's findings are: whether each holds is weighed first
([U7 Review](<autoflow-root>/docs/units/review.md) > *Whether a finding holds*), and every one leaves with a disposition and its
grounds. Where a fix is made is the judgment of the AI acting on the finding
([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D6). The severity is information for that
judgment, and no rule branches on it.

- **Fixed.** The fix is made where the change it needs belongs — the analysis report, the design,
  the build — or, for a fix no module owns, in a commit of its own. The
  recommending evaluation's re-score judges it: the finding's `rescore.prior_findings` entry is
  `cleared` or `remains`.
- **Does not hold.** It is rebutted with the grounds that show it, and the recommending
  evaluation's re-score judges the rebuttal (*Whether a finding holds*).
- **Deferred.** It is left for later and stated on the pull request: the issue that takes it, or
  the gap stated in a line ([`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) > *한계와 known gaps*). A known
  gap worth fixing becomes an issue.
- **Separated.** Not directly related — none of question 1's three conditions of
  [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment* holds —, it is separated with its ground and a separate issue as the follow-up path.
- **A criterion defect is decided.** A recommendation that records an acceptance criterion
  defective — the evaluator records one as a fact, the criterion as its subject
  ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format) — or one whose fix
  could keep a criterion's letter only by adding a rule the criterion did not state
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), is neither
  fixed, separated nor deferred as it stands: the module acting on it puts the change to the advisor,
  whose decision is recorded as `[ac-decision]` entries ([U3 Design](<autoflow-root>/docs/units/design.md) > *Report routing* >
  *An acceptance-criterion change shown later*).
- **A fact below the decision layer** ([U3 Design](<autoflow-root>/docs/units/design.md) > *Output artifacts* item 1) that an
  evaluation of the analysis or the design records is not a defect of the artifact it scores; it is
  taken up where the build derives it, and judged with that work at GATE:QUALITY.

The AI acting on a recommendation puts it to the advisor, and follows the decision
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor), when (a) the fix needs a contract or
acceptance-criterion change; (b) the fix direction is
ambiguous, or a directly related recommendation looks undesirable to fix in this change (question 2)
and would be left; (c) a re-score keeps the previous finding `remains` after its fix — the same
complaint answered twice — and the re-score's grounds do not settle the next fix.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) >
Documentation Policy). Its search terms:

```
git grep -n -i -E 'recommendation triage|recommendations triaged|deferred or separated|disposed of as a reviewer'
```

<!-- From <autoflow-root>/docs/units/review.md > Review triage > Whether a finding holds -->

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and records a finding that does not hold, or holds in part, with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A module acting on a finding that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file and the comment, and counted toward no verdict ([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)). A finding that the module acting on it finds does not hold is a rebuttal: it is posted with its grounds on the PR, and the next round's reviews and aggregation judge it — a round of its own also when it only rebuts and changes no code. A gate recommendation's rebuttal is judged by the recommending evaluation's re-score. One that holds in part is fixed for the real problem it points to. When a rebutted finding is kept and the two sides still disagree, the module acting on it puts it to the advisor and follows the decision ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; [`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module*); no count decides when.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Change Surface Rules > Scope judgment -->

### Scope judgment
A role that meets a problem the acceptance criteria do not name answers two questions and records the answers with their grounds, under a `## Scope judgments` heading in the report or artifact its run already produces ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

1. **Is it directly related to this issue?** It is when any one of these holds:
   - it comes from the same confirmed cause;
   - this change created it or exposed it;
   - unless it is fixed, the behavior an acceptance criterion promises does not hold in actual use.
2. **Is fixing it in this change desirable?** It is when it lies in the same module, is confirmed by the same verification, and fixing it separately would reopen the same code. It is not when it needs a design decision of its own, touches another ownership scope, or carries more risk than this issue.

| Judgment | Disposition |
|---|---|
| Directly related, fixing it here desirable | fixed in this change; the recorded judgment is the trace of its hunks |
| Directly related, fixing it here not desirable | separated, with its **separation reason** recorded |
| Not directly related | separated — reported in one line with its `path:line`; a separate issue is the follow-up path |

- **The default follows the first question.** A directly related problem is included unless a separation reason is recorded. A problem noticed in passing — a style inconsistency, pre-existing dead code, a refactor opportunity — meets none of the three conditions and stays out (**Surrounding code**, **Refactor scope**).
- **A record line** names the problem (its `path:line` at the report's commit, or the design section), the condition of question 1 it meets or that none does, the answer to question 2 with its ground, and the disposition.
- **An inclusion is verified like the rest of the scope.** In the design it is named in the feature design's scope and disposed of in the verification design (`<autoflow-root>/docs/units/design.md` > Output artifacts); found later, the role that fixes it runs the tests it judges the fix requires and records the run (Verification and Tools > *Local verification*).
- **Criterion defects.** From the design on, beside the two questions the role weighs whether what it met shows a criterion defective ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*). A same-cause problem reaching past what the criteria name may mean the issue drew the problem too narrowly — and then whether the approach itself must change is the question, not only whether to include the rest; an item a criterion names that turns out to be a problem separate from this issue may mean it drew too wide. Including a problem does not change a criterion, and a criterion is not carried out merely because it names an item: a defect so judged is recorded here, and the role puts the change — the criterion, the proposed change and the fact that shows it — to the advisor and follows the decision ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*; [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor).
- A role that doubts a scope judgment, or whose inclusion would change a design decision, puts it to the advisor and follows the decision ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module*).
- **Where it is applied**: the analysis report's `## Scope judgments` and the scope the feature design states set the change's scope; the build judges what it meets during the work; and the evaluations' recommendations are disposed of as a reviewer's findings are, where the same two questions decide which recommendation is not the issue's (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

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
