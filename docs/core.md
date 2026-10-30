# AutoFlow Core

<!-- The source of the module command bodies (/autoflow:<module>): scripts/skills/gen-skill-bodies.sh generates skills/<module>/SKILL.md from this file (ADR-0027 D2, ADR-0038 D9), a module's body by the classification scripts/skills/core-units.tsv, and the parts scripts/skills/role-docs.tsv names into the agent definitions (ADR-0035). Edit this file — and the classification, for a part added or one whose modules change — then regenerate. -->

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.
- What these documents state is the default. A target's own practice and an invocation's `instructions` come first; the authority rules and a module's outputs hold under any instruction.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The merge prohibition, the separation of a module's work from its evaluation, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the reference pass values AutoFlow keeps with the rubrics are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the output its run already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by the evaluation modules, by CI and by the external reviewer. The working AI decides what it can decide, and the run goes on unless a call is blocked at the harness level.
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a run leaves in the target's tree — are [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools.

## Development Lifecycle — AutoFlow

**AutoFlow is a set of modules.** A module is an input, the work it does, and an output; its contract, `<autoflow-root>/docs/contracts/<module>.json`, declares its parameters, its inputs and where each comes from, and its outputs with the form each must meet ([`ADR-0038`](records/adr/0038-contract-modules-with-no-state-file.md) D1). The modules are functional — the criterion review's four, analysis, design, build, delivery, ci, review —, evaluation — hypothesis, plan, audit, quality — and deterministic — criteria-apply. AutoFlow defines the modules: each one's contract, its procedure and the checks of its inputs and outputs (ADR-0038 D2). A module takes everything it works on from its invocation, the branch and the attempt's record directory included (D4).

**A module runs once, on its invocation.** An invocation file names the module's parameters, its inputs, its output directory, for a functional module the attempt's record directory and, when it has any, its `instructions` (the invocation's form: `<autoflow-root>/scripts/contracts/contract.sh`, header). The module checks its inputs' form first (`bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>`) and does not run when one fails; where an input came from is not checked. It does its work once, writes its outputs into its output directory, and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json` — `accepted`, `refused`, or `failed` when the module wrote the failure output its contract declares ([`ADR-0039`](records/adr/0039-delivery-and-ci-modules.md) D3) —, the outputs, the defects, the tool requests and the AutoFlow that ran the module (its version and root). Check-in and check-out see the form of an input or an output only, each file read alone ([`ADR-0040`](records/adr/0040-a-module-ends-at-its-goal.md) D2).

**A module's procedure states the goal of its work.** It says what the work must achieve, and the AI judges how to meet it; the output disposes of every item the work owes — each applied acceptance criterion, each scope item the design includes —, which the evaluations judge (ADR-0038 D1). The output a run makes of its inputs is one of two: what the goal asks for, when the AI that did the work judges it has reached the goal, or what it did and why it did not reach the goal, in the failure output its contract declares; either ends the run (ADR-0040 D1). Whether the output is right, and what is done with it, are for the side that runs the module (ADR-0038 D2). The applied criteria every module after the analysis takes are criteria-apply's output, computed from the analysis report's table and the `[ac-decision]` entries ([`<autoflow-root>/docs/decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*); the issue's criteria are first reviewed against the target's code and policy by the criterion review's modules ([`<autoflow-root>/docs/criterion-review.md`](criterion-review.md)).

**Inputs, outputs and default.** A module is defined by its inputs, its outputs and its default, each stated in its contract. Its outputs are the files it writes in its output directory, by the names and in the forms its contract gives; check-out checks that form. Its default is what it does with its result unless the invocation says otherwise — its contract's `default`, which its procedure states. The invocation's `instructions` override the default and never the outputs. The AI that does the module's work — the session, or the spawn the work is given to — receives the instructions with the inputs and follows them; the authority rules hold under any instruction (ADR-0040 D5).

**Decisions within a module.** The working AI decides what it can and records each decision with its grounds in its output (Rule Scope, principle 2). The decisions AutoFlow puts to the advisor — a change to an acceptance criterion's content, a root cause or lever that is not code, a hypothesis PASS judged unreachable, a design point not agreed, a finding whose fix cannot be placed with confidence, an item the criterion review could not decide, every change to the target's security checklist — and any other point the AI doubts, the module puts to a fresh `autoflow-advisor` it spawns, and it follows the advisor's decision. The advisor records the decision with its grounds as an entry in the ledger of the record directory the invocation names, and the module's output names each decision it followed by the entry's identifier ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Advisor). The run goes on; a call blocked at the harness level — a permission denial — is recorded in the output, and a tool the environment does not provide is a tool request (*Tools* below).

**Tools.** A tool the work needs is used. One the environment lacks — or what using a tool the environment has lacks, or a material an acceptance criterion or the issue body references that cannot be opened — is recorded as a tool request: what is missing, and what the run did instead, including each verification it left unrun for the lack. The run does what it can without it and ends; the requests go in `<out>/tool-requests.json` — which every run writes, `[]` when it lacked nothing —, and the delivery module states them in the pull request for the operator ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *The tools the work needs*; ADR-0038 D1).

**Scripts**: a script AutoFlow ships reads and reports, or writes the files its own contract names (`contract.sh`, `criteria-apply.sh`); it changes nothing in git or on GitHub. A push, a pull request and a comment are a module's own commands.

**Push and PR creation**: the delivery module's goal is the change the build made delivered for the operator to see and decide on; its default commits a sub-repo's pointer where the change takes one, pushes the branch and opens each pull request as a draft, with its own `git push` / `gh pr create`; the ci module's goal is CI's verdict on each pull request's head with its ground — where the target's CI does not run for it, that fact, a verdict apart from green. What the PR body carries, the host PR's `Closes #N` included, is the delivery module's, its CI part the ci module's default (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*, *CI*). Merging is external; AutoFlow does not merge, and the hook denies `gh pr merge` and a push to the default branch (*Records and the hook* below).

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
| `review` | `/autoflow:review` | `<autoflow-root>/docs/units/review.md` | the session, which runs the reviewers and aggregates their reviews into one report |

A module's command takes the module's invocation file (`/autoflow:<module> <invocation.json>`) and runs the module once on it. Each module runs in a session of its own, and one session can run modules one after another: every input is a file the invocation names. An evaluation's spawn writes its report to `<out>/evaluation.json` and returns the path ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI). The phase and gate names stay as identifiers: the spawn-policy keys and the documents' headings carry them.

The **reference values** an evaluation's scores are read against (each item ≥ 7, average ≥ 7.5, a `Security` item at 3 or below → rework) are kept with the rubrics ([`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > PASS Criteria) and carried in each evaluation contract's `reference`. An evaluation outputs its scores and their grounds, with the reference values (ADR-0038 D6).

```
criterion-screen      — the review items and the screening: the review record and one target file per criterion with an in-depth target (`<autoflow-root>/docs/criterion-review.md`)
criterion-trace       — each confirmed cause's reach and each required behavior's conflict with the rules in force
criterion-in-depth    — one run per criterion with an in-depth target, on that target alone
criterion-reconcile   — the record settled against the trace and the in-depth verdicts, each item disposed of with its grounds
analysis              — the analysis report: current structure, the gap to the request, whether a change is owed and code is the lever (the conclusion), the cause where a defect is reported, acceptance-criterion table, scope judgments, affected docs, decision points — each conclusion with its grounds, its method (how far and by what means a cause is pursued included) its own
criteria-apply        — the applied acceptance criteria: the analysis report's table with the standing `[ac-decision]` entries applied
hypothesis            — one Evaluation AI, one form for every issue (2 items × 10 points — the conclusion's grounds and the goal's coverage)
design                — the architecture decision layer + verification design, its method its own (file rows / suite dispositions / oracle clauses are derived at BUILD, not written here)
plan                  — one Evaluation AI (4 items × 10 points)
build                 — the design implemented and verified (test-first, run records, manual checklist, maintained docs, lint), its method its own
audit                 — an independent Evaluation AI judges test-first from the build report and git, then scores 5 items × 10 points, against the target's own security checklist at the version its input gives (none declared → the rubric alone)
quality               — one Evaluation AI (10 items × 10 points)
delivery              — the change the build made delivered for the operator to decide on: each applied criterion's outcome and evidence, how the change was shown working, what was not verified and why, what is left undone
ci                    — CI's verdict on each pull request's head, with its ground — green, or recorded as not run
review                — the reviewers the operator's configuration names, each run by its own script, and their reviews aggregated into one report
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every module: a module's command body carries the parts of this core its module uses, by the classification [`<autoflow-root>/scripts/skills/core-units.tsv`](../scripts/skills/core-units.tsv), and the documents the module uses with them (*Module references* below, *Context Injection*).

The rubric of every evaluation — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the work's: it lives in [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > *Gate rubrics*, the procedure of each evaluation contract.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md); how the evaluator is spawned and prompted is [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI.

### Module references

| Module | Its command body also carries |
|------|------|
| criterion-screen | the criterion review: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md) |
| criterion-trace | the criterion review: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md) |
| criterion-in-depth | the criterion review: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md) |
| criterion-reconcile | the criterion review: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md) |
| analysis | the procedure: [`<autoflow-root>/docs/units/analysis.md`](units/analysis.md); unit agent: `autoflow-unit-analysis`, contract: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Functional-unit agents; whether a finding holds: [`<autoflow-root>/docs/units/review.md`](units/review.md) > Whether a finding holds; including or separating a problem: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Scope judgment |
| criteria-apply | none beyond every command body's |
| hypothesis | the spawn: [`<autoflow-root>/docs/units/analysis.md`](units/analysis.md) > Evaluation — GATE:HYPOTHESIS; the evaluator's spawn and prompt: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI |
| design | the procedure: [`<autoflow-root>/docs/units/design.md`](units/design.md); unit agent: `autoflow-unit-design`, contract: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Functional-unit agents; whether a finding holds: [`<autoflow-root>/docs/units/review.md`](units/review.md) > Whether a finding holds; including or separating a problem: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Scope judgment |
| plan | the spawn: [`<autoflow-root>/docs/units/design.md`](units/design.md) > Evaluation — GATE:PLAN; the evaluator's spawn and prompt: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI |
| build | the procedure: [`<autoflow-root>/docs/units/build.md`](units/build.md); unit agent: `autoflow-unit-build`, contract: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Functional-unit agents; change surface: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules; normative documents: [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > Impact scope / Doc updates — reference integrity on moves; whether a finding holds: [`<autoflow-root>/docs/units/review.md`](units/review.md) > Whether a finding holds |
| audit | the spawn: [`<autoflow-root>/docs/units/build.md`](units/build.md) > Evaluation — AUDIT; the evaluator's spawn and prompt: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI; checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `<autoflow-root>/scripts/gate/security-checklist.sh` |
| quality | the procedure: [`<autoflow-root>/docs/units/completion-evaluation.md`](units/completion-evaluation.md); the evaluator's spawn and prompt: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI; change surface: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules; normative documents: [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > Impact scope / Doc updates — reference integrity on moves; whether a finding holds: [`<autoflow-root>/docs/units/review.md`](units/review.md) > Whether a finding holds |
| delivery | the procedure: [`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) (The two modules, What both modules owe, Authority rules, Push and pull request); PR body: [`<autoflow-root>/docs/pr-body-guide.md`](pr-body-guide.md); PR title: [`<autoflow-root>/docs/title-guide.md`](title-guide.md); change surface: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules |
| ci | the procedure: [`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) (The two modules, What both modules owe, Authority rules, CI); PR body: [`<autoflow-root>/docs/pr-body-guide.md`](pr-body-guide.md) > 5. Verification dispositions |
| review | the procedure: [`<autoflow-root>/docs/units/review.md`](units/review.md); reviewers: [`<autoflow-root>/docs/reviewer-backend.md`](reviewer-backend.md); change surface: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules; comments in a target: [`<autoflow-root>/docs/units/completion-evaluation.md`](units/completion-evaluation.md) > Code comments in a target |

## Cost Control

This rule applies to every run.

- **[MUST] Context discipline**: **the work never scores itself** (Rule Scope, principle 1) — the full read-and-score of a module's output is an evaluation module's fresh Evaluation AI (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and a read of that output by the session that produced it informs a spot-check, never a score.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md` in the record directory the invocation names, fixes settled decisions — the entries that settle what a module cannot settle itself. What an entry records, its identifier grammar, and the decision-point entries (`[ac-decision]`, `[checklist-decision]`) are [`<autoflow-root>/docs/decision-ledger.md`](decision-ledger.md).

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled decision is likewise not overturned by re-reading the issue body. One exception: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** The ledger is append-only: entries are never edited or deleted, and a write never changes text already in the ledger — enforced by the gate hook (*Records and the hook* below). A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and names the entry it supersedes on a `- Supersedes:` line.
- The ledger is outside every module's output; a module's output names, by identifier, the entries its run followed (what the ledger holds: `<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` reports a duplicated identifier or an unidentified level-2 heading (exit 1; 2 on a usage error). A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **Verify role-spawn claims before acting on them**: a role spawn's claim is confirmed by reading what it points at ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format > *Evidence anchor*). Do not act on a single AI's unverified claim.
- **Safety first**: accurate execution beats fast response. Accuracy over speed.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): how far the work goes — the analysis, the design, the build's execution, how the delivery shows the change working — is the working AI's judgment, recorded with its grounds in the output its run produces. What no module does is judge its own output: each evaluation is a module of its own, scored by a fresh Evaluation AI that never saw the work done, and CI (its verdict on the pull request's head — where the target's CI does not run for it, that fact, a verdict apart from green) and the aggregated review stand outside the work as well.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document ([`<autoflow-root>/docs/units/analysis.md`](units/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per [`<autoflow-root>/docs/issue-proposal.md`](issue-proposal.md) and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.

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

The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior run: `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**Spawn role declaration**: an AutoFlow role is spawned as its dedicated `subagent_type` — `autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, the criterion-review agents `autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `<autoflow-root>/agents/` —, so that it carries its guidance from the start (*Context Injection*); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) are used as they are. `subagent_type` is the one declaration channel. The spawn prompt is never used to infer the spawn's role.

No role holds a lifetime spanning runs: each run spawns its role fresh, hands it the paths of its inputs and of its output directory, and takes its result as the spawn's return value. Each role's per-call scope is [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Per-call scope by role.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by [`<autoflow-root>/scripts/skills/core-units.tsv`](../scripts/skills/core-units.tsv), and every carrier's documents, an agent definition's core parts with them, by [`<autoflow-root>/scripts/skills/role-docs.tsv`](../scripts/skills/role-docs.tsv) — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

A spawn prompt names the run's inputs by path — the inputs the invocation names, the attempt's record directory for a module that reads it, and the target's files — and the output directory, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the session that runs a module spawns each role with a `subagent_type`, and the spawn's **return
value is its report**.

- The session spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to the run's output directory and returns where it is and what its reader needs to act on ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format).
- A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The main session's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- A cross-service change is made by each scope's module run, and the pull requests it takes across the scopes are the delivery module's ([`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) > *Push and pull request*).

For details, see [`<autoflow-root>/docs/repo-boundary-rules.md`](repo-boundary-rules.md).

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states the AI establishes from the repository itself where it can — its remotes, its `.gitmodules` — and otherwise records as a tool request: the missing fact, and the file that would state it.

In a project whose information names sub-repos, which pull requests a change takes, a sub-repo's included, is the delivery module's judgment from those facts: [`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) > *Push and pull request*.

## Team Structure

각 역할의 상세 계약은 [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md)를 참조한다.

### Evaluation AI — contract: `<autoflow-root>/docs/evaluation-system.md`; spawn and prompt: `<autoflow-root>/docs/role-contracts.md` > Evaluation AI
### Build module — contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; in a target scope: `<autoflow-root>/docs/role-contracts.md` > Build unit in a target scope
### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor
### Functional-unit agents (analysis, design, build) — contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents

## Records and the hook

**Record directory.** Every record of an attempt lives in the attempt's record directory `<attempt-dir>`, under the record root — outside every checkout's tree, `autoflow-records root` (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`) —, which each invocation names as `records`. Each run writes into its own subdirectory, `<attempt-dir>/<module>-<n>` (`<module>-<qualifier>-<n>` for one module run on several items in a round, `n` counting that module's runs from 1), so nothing is renamed or overwritten; a functional module reads what earlier runs left in the directory, and an evaluation module keeps to its declared inputs (ADR-0038 D4). The ledger is `<attempt-dir>/issue-{N}-ledger.md`, the name the hook's ledger check reads.

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger; an `Agent` spawn without an explicit `model`; and a backgrounded `run-suites.sh`. With no `jq` it reads the other denies from the raw input; the ledger check reads the write with `jq`, and with no `jq` it passes the write unchecked.

## Evaluation System
→ [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md)

## Git Workflow — Rules

> **Issue closing**: [`<autoflow-root>/docs/git-workflow.md`](git-workflow.md)

### Commit Rules

```
<type>(#<issue>): <description>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

Attribution lines (such as `Co-Authored-By`) are not part of the AutoFlow commit format; whether a commit or PR carries one follows the execution environment (harness) and the operator's settings.

- Before committing, the committing role — every role that commits, the main session included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. The rule (execution trust boundary, scoping, evidence anchor): [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation and tests, sub-repo) | the build module of that scope | the delivery module |
| Sub-repo pointer (gitlink) commit | the delivery module | the delivery module |

## Reference Documents

- **AutoFlow phase guide**: [`<autoflow-root>/docs/autoflow-guide.md`](autoflow-guide.md)
- **Role contracts**: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md)
- **Evaluation system**: [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md)
- **Module contracts**: `<autoflow-root>/docs/contracts/<module>.json`, checked by `<autoflow-root>/scripts/contracts/contract.sh`
- **Criterion review (the four criterion modules)**: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md)
- **Issue closing**: [`<autoflow-root>/docs/git-workflow.md`](git-workflow.md)
- **Repo boundary rules**: [`<autoflow-root>/docs/repo-boundary-rules.md`](repo-boundary-rules.md)
- **Sub-repo common rules**: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md)
