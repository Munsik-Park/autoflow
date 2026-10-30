---
name: delivery
description: >-
  Run the AutoFlow delivery module once on an invocation file — the change
  the build made delivered for the operator to decide on: each criterion's
  outcome and evidence, how it was shown working, what was not verified and
  what is left. Use when the operator runs the delivery module
  (/autoflow:delivery <invocation.json>).
argument-hint: "<invocation.json>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the attempt's record directory the invocation names (`records`). Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: the invocation file) — one run of the delivery module (`<autoflow-root>/docs/contracts/delivery.json`) on that invocation: `bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>` first — a refused input ends the run with its report —, then the work, which writes its outputs — what the module's goal asks for, or, when the run does not reach the goal, `<out>/failure.md`: what it did and why — and `<out>/tool-requests.json` (`[]` when the run lacked nothing, *Tools* below), then `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json`; the run ends with the report its procedure owes. The session does the work itself, as `<autoflow-root>/docs/units/delivery.md` (below) states it. The invocation's `records` is the attempt's record directory, where earlier runs left their work. Every `Agent` spawn the run makes takes its model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` — the advisor's key is `advisor` (*Spawn Model*, below).

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that the delivery module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle > Module procedures: The reference values, criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, ci, review, The rubric of every evaluation, The evaluation contract; Development Lifecycle > Module references: criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, ci, review; Team Structure: Evaluation AI, Build module, Functional-unit agents; Evaluation System.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/delivery.md` > U6 Delivery > *AutoFlow's mission ends*; `<autoflow-root>/docs/units/delivery.md` > The two modules; `<autoflow-root>/docs/units/delivery.md` > What both modules owe; `<autoflow-root>/docs/units/delivery.md` > Authority rules; `<autoflow-root>/docs/units/delivery.md` > Push and pull request; `<autoflow-root>/docs/pr-body-guide.md`; `<autoflow-root>/docs/title-guide.md`; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

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

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a run leaves in the target's tree — are `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Development Lifecycle — AutoFlow

**AutoFlow is a set of modules.** A module is an input, the work it does, and an output; its contract, `<autoflow-root>/docs/contracts/<module>.json`, declares its parameters, its inputs and where each comes from, and its outputs with the form each must meet (`ADR-0038` D1). The modules are functional — the criterion review's four, analysis, design, build, delivery, ci, review —, evaluation — hypothesis, plan, audit, quality — and deterministic — criteria-apply. AutoFlow defines the modules: each one's contract, its procedure and the checks of its inputs and outputs (ADR-0038 D2). A module takes everything it works on from its invocation, the branch and the attempt's record directory included (D4).

**A module runs once, on its invocation.** An invocation file names the module's parameters, its inputs, its output directory, for a functional module the attempt's record directory and, when it has any, its `instructions` (the invocation's form: `<autoflow-root>/scripts/contracts/contract.sh`, header). The module checks its inputs' form first (`bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>`) and does not run when one fails; where an input came from is not checked. It does its work once, writes its outputs into its output directory, and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json` — `accepted`, `refused`, or `failed` when the module wrote the failure output its contract declares (`ADR-0039` D3) —, the outputs, the defects, the tool requests and the AutoFlow that ran the module (its version and root). Check-in and check-out see the form of an input or an output only, each file read alone (`ADR-0040` D2).

**A module's procedure states the goal of its work.** It says what the work must achieve, and the AI judges how to meet it; the output disposes of every item the work owes — each applied acceptance criterion, each scope item the design includes —, which the evaluations judge (ADR-0038 D1). The output a run makes of its inputs is one of two: what the goal asks for, when the AI that did the work judges it has reached the goal, or what it did and why it did not reach the goal, in the failure output its contract declares; either ends the run (ADR-0040 D1). Whether the output is right, and what is done with it, are for the side that runs the module (ADR-0038 D2). The applied criteria every module after the analysis takes are criteria-apply's output, computed from the analysis report's table and the `[ac-decision]` entries (`<autoflow-root>/docs/decision-ledger.md` > *Acceptance-criterion decisions*); the issue's criteria are first reviewed against the target's code and policy by the criterion review's modules (`<autoflow-root>/docs/criterion-review.md`).

**Inputs, outputs and default.** A module is defined by its inputs, its outputs and its default, each stated in its contract. Its outputs are the files it writes in its output directory, by the names and in the forms its contract gives; check-out checks that form. Its default is what it does with its result unless the invocation says otherwise — its contract's `default`, which its procedure states. The invocation's `instructions` override the default and never the outputs. The AI that does the module's work — the session, or the spawn the work is given to — receives the instructions with the inputs and follows them; the authority rules hold under any instruction (ADR-0040 D5).

**Decisions within a module.** The working AI decides what it can and records each decision with its grounds in its output (Rule Scope, principle 2). The decisions AutoFlow puts to the advisor — a change to an acceptance criterion's content, a root cause or lever that is not code, a hypothesis PASS judged unreachable, a design point not agreed, a finding whose fix cannot be placed with confidence, an item the criterion review could not decide, every change to the target's security checklist — and any other point the AI doubts, the module puts to a fresh `autoflow-advisor` it spawns, and it follows the advisor's decision. The advisor records the decision with its grounds as an entry in the ledger of the record directory the invocation names, and the module's output names each decision it followed by the entry's identifier (`<autoflow-root>/docs/role-contracts.md` > Advisor). The run goes on; a call blocked at the harness level — a permission denial — is recorded in the output, and a tool the environment does not provide is a tool request (*Tools* below).

**Tools.** A tool the work needs is used. One the environment lacks — or what using a tool the environment has lacks, or a material an acceptance criterion or the issue body references that cannot be opened — is recorded as a tool request: what is missing, and what the run did instead, including each verification it left unrun for the lack. The run does what it can without it and ends; the requests go in `<out>/tool-requests.json` — which every run writes, `[]` when it lacked nothing —, and the delivery module states them in the pull request for the operator (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ADR-0038 D1).

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

A module's command takes the module's invocation file (`/autoflow:<module> <invocation.json>`) and runs the module once on it. Each module runs in a session of its own, and one session can run modules one after another: every input is a file the invocation names. An evaluation's spawn writes its report to `<out>/evaluation.json` and returns the path (`<autoflow-root>/docs/role-contracts.md` > Evaluation AI). The phase and gate names stay as identifiers: the spawn-policy keys and the documents' headings carry them.

```
delivery              — the change the build made delivered for the operator to decide on: each applied criterion's outcome and evidence, how the change was shown working, what was not verified and why, what is left undone
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every module: a module's command body carries the parts of this core its module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and the documents the module uses with them (*Module references* below, *Context Injection*).

### Module references

| Module | Its command body also carries |
|------|------|
| delivery | the procedure: `<autoflow-root>/docs/units/delivery.md` (The two modules, What both modules owe, Authority rules, Push and pull request); PR body: `<autoflow-root>/docs/pr-body-guide.md`; PR title: `<autoflow-root>/docs/title-guide.md`; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules |

## Cost Control

This rule applies to every run.

- **[MUST] Context discipline**: **the work never scores itself** (Rule Scope, principle 1) — the full read-and-score of a module's output is an evaluation module's fresh Evaluation AI (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and a read of that output by the session that produced it informs a spot-check, never a score.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md` in the record directory the invocation names, fixes settled decisions — the entries that settle what a module cannot settle itself. What an entry records, its identifier grammar, and the decision-point entries (`[ac-decision]`, `[checklist-decision]`) are `<autoflow-root>/docs/decision-ledger.md`.

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled decision is likewise not overturned by re-reading the issue body. One exception: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** The ledger is append-only: entries are never edited or deleted, and a write never changes text already in the ledger — enforced by the gate hook (*Records and the hook* below). A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and names the entry it supersedes on a `- Supersedes:` line.
- The ledger is outside every module's output; a module's output names, by identifier, the entries its run followed (what the ledger holds: `<autoflow-root>/docs/decision-ledger.md` > Entries).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` reports a duplicated identifier or an unidentified level-2 heading (exit 1; 2 on a usage error). A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **Verify role-spawn claims before acting on them**: a role spawn's claim is confirmed by reading what it points at (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format > *Evidence anchor*). Do not act on a single AI's unverified claim.
- **Safety first**: accurate execution beats fast response. Accuracy over speed.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): how far the work goes — the analysis, the design, the build's execution, how the delivery shows the change working — is the working AI's judgment, recorded with its grounds in the output its run produces. What no module does is judge its own output: each evaluation is a module of its own, scored by a fresh Evaluation AI that never saw the work done, and CI (its verdict on the pull request's head — where the target's CI does not run for it, that fact, a verdict apart from green) and the aggregated review stand outside the work as well.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document (`<autoflow-root>/docs/units/analysis.md` > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per `<autoflow-root>/docs/issue-proposal.md` and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.

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

No role holds a lifetime spanning runs: each run spawns its role fresh, hands it the paths of its inputs and of its output directory, and takes its result as the spawn's return value. Each role's per-call scope is `<autoflow-root>/docs/role-contracts.md` > Per-call scope by role.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

A spawn prompt names the run's inputs by path — the inputs the invocation names, the attempt's record directory for a module that reads it, and the target's files — and the output directory, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the session that runs a module spawns each role with a `subagent_type`, and the spawn's **return
value is its report**.

- The session spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`.
- A spawn writes any body to the run's output directory and returns where it is and what its reader needs to act on (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format).
- A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The main session's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- A cross-service change is made by each scope's module run, and the pull requests it takes across the scopes are the delivery module's (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*).

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states the AI establishes from the repository itself where it can — its remotes, its `.gitmodules` — and otherwise records as a tool request: the missing fact, and the file that would state it.

In a project whose information names sub-repos, which pull requests a change takes, a sub-repo's included, is the delivery module's judgment from those facts: `<autoflow-root>/docs/units/delivery.md` > *Push and pull request*.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor

## Records and the hook

**Record directory.** Every record of an attempt lives in the attempt's record directory `<attempt-dir>`, under the record root — outside every checkout's tree, `autoflow-records root` (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`) —, which each invocation names as `records`. Each run writes into its own subdirectory, `<attempt-dir>/<module>-<n>` (`<module>-<qualifier>-<n>` for one module run on several items in a round, `n` counting that module's runs from 1), so nothing is renamed or overwritten; a functional module reads what earlier runs left in the directory, and an evaluation module keeps to its declared inputs (ADR-0038 D4). The ledger is `<attempt-dir>/issue-{N}-ledger.md`, the name the hook's ledger check reads.

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger; an `Agent` spawn without an explicit `model`; and a backgrounded `run-suites.sh`. With no `jq` it reads the other denies from the raw input; the ledger check reads the write with `jq`, and with no `jq` it passes the write unchecked.

## Git Workflow — Rules

> **Issue closing**: `<autoflow-root>/docs/git-workflow.md`

### Commit Rules

```
<type>(#<issue>): <description>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

Attribution lines (such as `Co-Authored-By`) are not part of the AutoFlow commit format; whether a commit or PR carries one follows the execution environment (harness) and the operator's settings.

- Before committing, the committing role — every role that commits, the main session included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. The rule (execution trust boundary, scoping, evidence anchor): `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules > *Lint chain on the staged surface*.

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
- **Issue closing**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/units/delivery.md > U6 Delivery > AutoFlow's mission ends -->

AutoFlow's mission ends by handing off an open pull request — opened, with CI read, by the modules below, and reviewed by [U7 Review](<autoflow-root>/docs/units/review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

<!-- From <autoflow-root>/docs/units/delivery.md > The two modules -->

## The two modules

U6 Delivery is two modules, each with its contract under `<autoflow-root>/docs/contracts/` and this
file as its procedure ([`ADR-0039`](<autoflow-root>/docs/records/adr/0039-delivery-and-ci-modules.md)). Each runs
alone on its invocation. A module is given the kinds of its inputs, the kind and form of its output,
its tools and the authority rules below; how many of a thing it makes, which steps it takes in which
order and what it checks are the AI's, judged from the inputs it is given.

| Module | Output | Default | `timeout` not given |
|---|---|---|---|
| `delivery` | `<out>/delivery.json` (*Push and pull request*) | a sub-repo's pointer commit, the push and the draft pull requests with their bodies | 900 s |
| `ci` | `<out>/ci.json` (*CI*) | the verdict in each pull request's body, its CI part | 900 s |

<!-- From <autoflow-root>/docs/units/delivery.md > What both modules owe -->

## What both modules owe

- **Inputs.** A module works from its params and the inputs its invocation gives. The record
  directory (`records`) is where earlier runs left their working files and where the ledger is; it
  does not stand in for an input. An input the work needs and was not given is named as such in the
  failure output.
- **Failure output.** A run that does not reach its goal, or reaches its `timeout` (seconds), writes
  `<out>/failure.md`: what it did, and why it did not reach the goal. Check-out then writes its
  result as `failed` (`<autoflow-root>/scripts/contracts/contract.sh`, header).
- **Check-out** checks the output's form: the file is there and reads in the form its contract
  gives.

<!-- From <autoflow-root>/docs/units/delivery.md > Authority rules -->

## Authority rules

These hold on every push, every pull request and every pull-request body either module makes.

- Pushing, opening a pull request and editing its body are the module's own commands, never run
  through a script or a wrapper (`<autoflow-root>/docs/core.md` > Scripts).

<!-- From <autoflow-root>/docs/units/delivery.md > Push and pull request -->

## Push and pull request

**DELIVER, INTEGRATE.** The delivery module delivers the change the build made for the operator to
see and decide on: each applied acceptance criterion with its outcome and its evidence, how the
change was shown working, what the work could not verify and why, and what the change leaves
undone.

- **Inputs**: what the build produced and worked from — its commits (`commits`), its report
  (`build_report`), the applied criteria and the verification design —, and the records the
  pull-request body carries: the quality evaluation, the feature design, the tool requests of every
  run (`tool_requests`) and the recommendations deferred or separated (`deferred`).
- **Params**: `base`, the branch the pull requests merge into (not given, the remote's default
  branch); `timeout`.
- **What the AI judges**: how many pull requests the change takes, in which repositories and on which
  branches — a sub-repo's included, read from the project's own information
  ([`core.md`](<autoflow-root>/docs/core.md) > Project Information) —, and how the pull requests show the change
  working.
- **The change delivered** is one whose local tests the build report records green.
- **The body** states each applied acceptance criterion with its outcome and where its evidence is;
  what the work verified other than by an executable test, and how the change was shown working; what
  the work could not verify, and why — the tool requests, so the operator decides on them; and what
  the change leaves undone — the problems it separated and the recommendations deferred. The pull
  request in the repository the issue is filed in closes it (`Closes #N`); any other references it
  and closes nothing ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Issue Auto-Close). The title and the
  body's form are the module's, with [`title-guide.md`](<autoflow-root>/docs/title-guide.md) and
  [`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) to draw on.
- **Tools**: `git` and `gh`, as the module's own commands.
- **Output**: `<out>/delivery.json` — `{pull_requests: [{repo, branch, head, pr}]}`: each branch
  pushed, with its repository (`<owner>/<name>`), its head commit and its pull request as
  `<owner>/<name>#<N>` — the form the review and the ci module take —, `null` for a branch pushed
  with no pull request.
- **Default**: a sub-repo's pointer commit where the change takes one, the branches pushed and the
  draft pull requests opened on the base, with the bodies above; the invocation's `instructions`
  override it ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Inputs, outputs and default*).
- **Failure output**: `<out>/failure.md` (*What both modules owe*) — among what the run did, what it
  pushed and opened.

<!-- From <autoflow-root>/docs/pr-body-guide.md -->

# PR Body Authoring Guide

PR body 작성 시 참고하는 가이드. delivery module, ci module과 수동 PR 작성자 모두 대상.

## Principles

### 1. Claim의 정확도

PR이 body에서 약속하는 동작 / 검증 / 보호 범위는 실제로 구현하는 것과 정확히
일치해야 한다.

- 강한 표현 (machine-verified, fully enforced, idempotent, atomic, race-free
  등) 은 실제로 그 수준을 충족할 때만 사용.
- 부분적 보장은 부분적으로 명시 — "X는 machine-verified, Y는 reviewer-attested"
  처럼 분리 가능하면 분리.

### 2. 거부된 대안의 노출

implementation을 결정하는 과정에서 고려했으나 거부한 대안이 있다면, 거부
사유와 함께 body에 노출한다.

- 거부 사유는 정확하게: "architectural boundary 위반"인지 "비용 trade-off"인지
  분명히 구분.
- 간단한 PR (typo fix 등) 에는 적용되지 않을 수 있다.

### 3. 한계와 known gaps

이 PR이 cover하지 않는 path / 잔존 risk / 후속 작업이 필요한 항목을 명시.

- "이 PR이 다루지 않는 것" 섹션 또는 body 본문에 단락으로.
- 후속 issue 번호가 있다면 cross-reference.

### 4. 판단 근거의 명시적 링크 (PR-reachability)

리뷰어는 PR에서 출발해 판단 근거에 도달할 수 있어야 한다. 문서가 저장소에
존재하는 것만으로는 부족하다 — PR이 어떤 ADR / design note / architecture
context / AC 를 판단 근거로 삼았는지 `path > section` 형태로 명시한다.

- ADR / design note / architecture context 를 명시적으로 링크. ADR 불필요 시
  사유 한 줄 ("ADR not required: ...").
- linked issue 의 AC 를 PR 에서 도달 가능하게 (이슈 링크 + AC 섹션, 또는 body 에 명시).
- 기록 폴더(`<attempt-dir>/*`)의 scratch 는 리뷰 입력으로 링크하지 않고, 리뷰어가 봐야 할 근거는
  linked issue 나 commit 된 문서, 또는 PR body 로 옮긴다.

정책: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

### 5. Verification dispositions (검증 처분의 노출)

AutoFlow가 연 host PR은 검증 처분이 읽히게 한다 — verification design이
실행 가능한 test가 아닌 방법으로 검증하는 모든 항목(applied criterion과 feature design이 범위에 포함한
항목)을, 검증 방법과 사유와 함께 적는다. 처분을 부르는 말은 design의 것이다.

- 운영자 주도 PR(AutoFlow 모듈 밖에서 운영자가 진행한 작업의 PR)에는 이 내용을 요구하지 않는다.
  verification design이 없기 때문이다. 수용 기준의 충족은 *6. 수용 기준 대조*로 보인다.
- 이 내용은 3단 acceptance-criterion guard의 두 번째 tier다: design module이 검증
  방법의 축소를 결정하고, review module의 reviewer가 그 reason의 타당성을 판단하며,
  criterion의 **내용**이 바뀔 때는 그 변경을 보인 모듈이 advisor를 spawn해 정하고 그 결정을 따른다
  ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor). 규칙 본문은 [U3 Design](<autoflow-root>/docs/units/design.md) >
  *Test necessity* 와 *Report routing*.
- 예시 형식은 항목 id + 검증 방법 + reason 한 줄이다.
- target 트리에 남지 않는 한 번 실행한 test는 같은 섹션에 그 항목의 **run record** — build
  report에 기록된 command와 summary line — 를 한 줄로 싣는다
  ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *Push and pull request*).
- AI가 도구로 관찰해 검증한 항목은 같은 섹션에 실행 주체, observation record의 경로와 결과를
  한 줄로 싣는다. 사람의 관찰이나 mock으로 검증한 항목은 reason에 그 이유를 싣고, 도구가 없어서라면
  그 도구 요청을 *7. 도구 요청*에 적는다 ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) >
  Verification and Tools > *The tools the work needs*; [U3 Design](<autoflow-root>/docs/units/design.md) > *Tools*).
- 변경이 target 트리에 **추가한 테스트 파일**은 같은 섹션에 파일별로 나열한다 — 경로,
  남겨 두는 이유, 그리고 ci module이 확인한, 그 파일을 실제로 실행한 CI job(실행한 job이 없으면 그
  사실, target에 CI가 없으면 `no CI; local run only`). 추가한 파일이 없으면 그 사실을 한 줄로 적는다
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *What a change leaves in the target's tree*;
  [U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *CI*, *Added test files*).

예:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` 가 동일 property를
  build마다 검사한다.
- AC4 — none: 값이 사용자가 편집하는 sample 파일에 있어, 첫 편집에서 검증 대상이
  사라진다. 부재 비용 0.
- AC1 — one-shot test: `bash <attempt-dir>/build-1/local/ac1-retry.sh` → `PASS 3/3`
- AC3 — AI observation (browser): `<attempt-dir>/build-1/local/ac3-observation.md` →
  일치 — 렌더링된 목록 화면을 이슈가 링크한 시안과 대조.
- Added test files: `tests/retry-backoff.test.ts` — 재시도 간격은 배포 후 설정값에
  따라 달라지므로 target의 회귀 대상; CI job `unit (ubuntu-latest)`에서 실행 확인.
```

### 6. 수용 기준 대조

운영자 주도 PR과 AutoFlow PR 모두, PR body에 linked issue의 수용 기준을 대조해 두면
리뷰어가 기준별 충족 여부를 바로 읽을 수 있다.

- 절 머리에 결과가 어느 commit 기준인지 밝힌다: "`<sha>` 시점의 결과".
- 기준마다 한 줄로 쓴다: 기준 번호(AutoFlow PR은 applied criteria의 id),
  충족 여부, 확인한 commit, 근거 위치(`path` > section, `path:line`, 실행 기록의 summary line 등).
- 충족하지 못했거나 일부만 충족한 기준은 그렇게 적고 사유를 같은 줄에 붙인다. 후속 처리는
  *3. 한계와 known gaps*에 적는다.
- 이 절은 AutoFlow PR의 *5. Verification dispositions*를 대신하지 않는다. dispositions는 검증 방법의
  처분이고, 이 절은 기준의 충족 여부다.
- 항목은 제시만 한다. 이 형식을 검사하는 장치는 없다.

예:

```
## 수용 기준 대조 (#42)

`a1b2c3d` 시점의 결과.

- 1 — 충족 · `a1b2c3d` · `src/retry.ts:40-58`, `<attempt-dir>/build-1/local/ac1-retry.log` → `PASS 3/3`
- 2 — 충족 · `9f8e7d6` · `docs/retry.md` > Backoff
- 3 — 일부 충족: 설정 파일 경로만 반영, 환경변수 경로는 후속 #43 · `a1b2c3d` · `src/config.ts:12`
```

### 7. 도구 요청

AutoFlow PR body에는 작업의 도구 요청 — invocation이 주는 각 실행의 `tool-requests.json`
(`tool_requests`) — 을 적는다. 요청마다 없었던 것, 대신 한 것, 그 때문에 검증하지 못한 것을 한 줄로
적어, 운영자가 도구를 갖추고 다시 실행할지, PR을 닫고 도구를 따로 갖출지, merge하고 도구를 더할지
정할 수 있게 한다 ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *Push and pull request*).

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건).

<!-- From <autoflow-root>/docs/title-guide.md -->

# Issue & PR Title Guide

공통 접두어를 대괄호로 묶고, 나머지 설명은 자유롭게 기술한다.

## 형식

```
[type · epic-slice · #N]  자유 설명    ← epic 서브이슈 PR
[type · epic-slice]       자유 설명    ← epic 서브이슈 (이슈 생성 시 번호 미정)
[type · #N]               자유 설명    ← 독립 이슈 / epic 트래커 / 독립 이슈 PR
```

| 항목 | 설명 |
|------|------|
| `type` | `feat` / `fix` / `chore` / `docs` — 아래 표 참고 |
| `epic-slice` | Epic 번호와 슬라이스 코드 (`#73-S3f`, `#72-S5a` 등). epic 서브이슈에만 사용 |
| `#N` | GitHub 이슈 번호. 이슈 제목에는 생략 가능, PR 제목에는 권장 |
| 자유 설명 | 길이·언어 제한 없음 |

## type 값

| type | 언제 |
|------|------|
| `feat` | 새 기능 구현 |
| `fix` | 버그 수정 |
| `chore` | 설정·인프라·자동화 |
| `docs` | 문서 단독 변경 |

## 예시

### 이슈 제목

```
[feat · #73-S3f]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a]  멤버 관리 테이블 프론트엔드
[feat · #224]     Enterprise 멤버 활동 감사 로그 구현
[fix  · #200]     YouTube 자막 취득 실패
[chore · #43]     PAT rotation 문서화
```

### PR 제목

```
[feat · #73-S3f · #231]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a · #217]  멤버 관리 테이블 프론트엔드
[feat · #224]             Enterprise 멤버 활동 감사 로그
[fix  · #200]             YouTube 자막 취득 실패
[chore · #43]             PAT rotation 문서화
```

## 접두어 구성 원리

`epic-slice`와 `#N`은 역할이 다르다.

| 참조 | 의미 | 이슈 | PR |
|------|------|------|----|
| `epic-slice` (`#73-S3f`) | 어느 Epic의 몇 번째 슬라이스인가 | ✅ | ✅ |
| `#N` (이슈 번호) | 어떤 GitHub 이슈를 닫는가 | 생략 가능 | 권장 |

epic 서브이슈가 아닌 경우(독립 이슈, epic 트래커)는 `epic-slice` 없이 `#N`만 사용한다.

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Change Surface Rules -->

## Change Surface Rules

Every changed line traces to the change's scope: the applied acceptance criteria, the confirmed cause the analysis recorded, the design, and each problem a recorded scope judgment includes (**Scope judgment** below). What belongs to the change is decided by that judgment, not by whether an acceptance criterion names the line. How small the change stays inside that scope is governed by **Trace rule**, **Surrounding code** and the **Over-engineering guard** below.

### Scope judgment
A role that meets a problem the acceptance criteria do not name answers two questions and records the answers with their grounds in the report or artifact its run already produces ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

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
- **An inclusion is verified like the rest of the scope.** In the design it is named in the feature design's scope and disposed of in the verification design (`<autoflow-root>/docs/units/design.md` > Output artifacts); found later, the role that fixes it runs the tests it judges the fix requires and records the run (Verification and Tools > *Local verification*).
- **Criterion defects.** From the design on, beside the two questions the role weighs whether what it met shows a criterion defective ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*). A same-cause problem reaching past what the criteria name may mean the issue drew the problem too narrowly — and then whether the approach itself must change is the question, not only whether to include the rest; an item a criterion names that turns out to be a problem separate from this issue may mean it drew too wide. Including a problem does not change a criterion, and a criterion is not carried out merely because it names an item: a defect so judged is recorded here, and the role puts the change — the criterion, the proposed change and the fact that shows it — to the advisor and follows the decision ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*; [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor).
- A role that doubts a scope judgment, or whose inclusion would change a design decision, puts it to the advisor and follows the decision ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module*).
- **Where it is applied**: the analysis report's scope judgments and the scope the feature design states set the change's scope; the build judges what it meets during the work.

### Trace rule
- Each touched file/line answers the question: "which acceptance criterion, confirmed cause, plan item or recorded scope judgment requires this?" If the answer is "none — I noticed it while I was here", revert that line.

### Surrounding code
- Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- Leave adjacent code, comments, formatting, and import order untouched unless an AC or a recorded scope judgment requires the change. A comment attached to code this change modifies is not adjacent — it is part of the change (**Code comments** > *Changing commented code*).

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the change's scope needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the change's scope (**Scope judgment**). A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. What a comment on changed code may carry is **Code comments** below.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Code comments
The rule governs every comment in code a change writes or modifies — implementation and test files, in a target and in this repository. Existing comments on code the change leaves untouched stay as they are (**Surrounding code**).

- **The test**: a comment carries only a sentence that stays true for as long as the code it sits on is unchanged — however much time passes, and whatever changes in other files.
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
- **Where that content goes**: a decision and its grounds → the repository's decision record (in this repository, `docs/records/adr/` and `docs/records/design-rationale.md`); change history → the commit message and the PR body; discussion → the attempt's design documents in its record directory and the issue. The only reference a comment carries is at most one ADR identifier (`ADR-0024`).
- **Test files**: a test's intent is stated in its name and its assertion messages. A comment in a test file carries only the reason for a fixture that the fixture does not make evident.
- **Changing commented code**: a comment attached to code this change modifies is updated or deleted in the same commit. When it is uncertain whether the comment is still true, delete it.
- **Directives are code**: a line a tool reads to change its behavior is code even when written in comment syntax — a lint suppression or a type-checker directive, for example — and this rule does not govern it; an explanation written beside it is a comment and does. Which lines are directives is the working AI's judgment in that target; no list is kept.

The build checks the change's diff against this rule (`<autoflow-root>/docs/units/build.md` > What the build owes, *Comment check*). In a target's code, a comment that diverges from its code or carries what this rule sends out of a comment is a `Low` finding for the reviewer and the evaluator; a defect a comment carries on its own ground, such as an exposed credential, takes the severity its impact sets (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*).

### Orphans from this change
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC or a recorded scope judgment requires it.

### Lint chain on the staged surface
- **[MUST]** Before a commit is made, the committing role runs every lint chain of the target repository that covers at least one staged file over the staged files, and confirms zero errors attributable to them. Auto-fixable formatting is applied and staged in the same commit.

**Which chains exist, and how each runs, is the target's practice.** AutoFlow prescribes no lint command and no discovery order to a target. The committing role finds, at the location it commits in, how that target lints a change; the judgment and its grounds go into the report (**Evidence anchor** below).

**Execution trust boundary** — **[MUST]** the command run at commit time is one the baseline — the base the branch is to merge into, at its merge-base with `HEAD` (`git merge-base HEAD origin/<base>`; the remote's default branch unless the invocation names another, `params.base`) — already carries. Before running it, the committing role confirms that the command's text at its source — the document entry, the script definition or the CI step body it was taken from — and any script file that text invokes by path are unchanged versus the baseline. A command this branch altered or added is not executed, whichever source it came from, and the report says so. A command is run exactly as its source states it — a read-only check, not licence to run any other step, argument or command its source names.

**A chain that cannot run** in the working checkout, or that the trust boundary withholds, is reported with the reason. It imposes a reporting obligation, not a blocking one: the commit proceeds. Making a chain locally executable belongs to the target repository's ops and is outside this rule's authority; a tool the work needs is used, or requested, as Verification and Tools > *The tools the work needs* says.

**Scoping** — run the chain restricted to the staged files where the chain supports scoping. Where the chain only runs whole-tree, run it whole-tree and require that no reported error names a staged file; pre-existing errors on untouched files are not this change's surface (**Surrounding code**).

**What the report holds** — for each chain the committing role identified: whether it ran and what it reported, or why it did not run; or that the target has no lint chain. Findings attributable to the staged files that were not auto-fixed hold the commit until they are resolved. A chain that could not run names the pull-request CI job that runs the same chain over the staged files for this pull request, where one does. Such a deferral is discharged by the ci module's green verdict on the pull request ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI*); that verdict is over the rollup, not a per-job guarantee, so the citation of the job and the evidence that it runs for this pull request are what tie the deferral to it, and the evaluators re-derive them from the report. Where CI did not run, the deferral is not discharged and the chain is listed on the pull request as not run.

- **[MUST]** A chain that did not execute is never reported as having passed.

**Evidence anchor** — the committing role's report carries the lint outcome (Reporting Format > *Evidence anchor*): each chain it identified, followed by the grounds of the identification.

### Refactor scope
A refactor of the change's diff applies the same trace rule: refactor suggestions that touch code outside the change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. A refactor tool's findings are advisory, not licence to expand the change surface. A finding that describes a behavior defect rather than a refactor is not a refactor to apply: the build records its **Scope judgment**.

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` and `Impact scope` items are scored against this section, on one scope: prefer the smallest sufficient change that resolves the confirmed problem within the change's scope. The change's scope is the applied acceptance criteria, the confirmed cause the analysis report records, and the problems its recorded scope judgments include (**Scope judgment**) — a boundary, not a line count. A correctly scoped change is not scored down for being larger than a symptom patch. The evaluator reads the scope records for both items: the feature design's `## Scope` section, every scope judgment in the reports the evaluation is given, and the recommendations deferred or separated after earlier evaluations (`deferred`).

A high-scoring change:
- resolves the confirmed cause, not only the reported symptom
- stays inside the module or component that owns that cause
- includes the local cleanup the fix itself requires — the code and symbols this change renders unreachable or unused, removed in the same commit; cleanup merely noticed nearby does not qualify (**Surrounding code**), and **Orphans from this change** is the symbol-removal instance of this same test, not its limit
- fixes each directly related problem its scope judgments include, and leaves out a directly related problem only with a recorded separation reason
- leaves every surface outside the scope untouched — behavior, APIs, configuration, and documentation are examples of such a surface, not the boundary — and keeps, inside it, the existing behavior that neither the acceptance criteria, the confirmed cause nor a problem its scope judgments include asks to change, a protection or the order of checks included; recording such a change as a known gap does not bring it into scope

`Minimal implementation` asks whether each hunk is needed. The question is asked against the smallest change that satisfies the acceptance criteria, with the tests its verification design requires, and resolves the confirmed cause: a hunk beyond it stands only on its own recorded ground. It fails when a hunk traces to no acceptance criterion, confirmed cause or recorded scope judgment — "I noticed it while I was here" cleanup (**Surrounding code**) or depth creep beyond what the scope needs (**Over-engineering guard**) — regardless of code quality, and when a hunk rests on a scope judgment that meets none of question 1's three conditions. It fails symmetrically when the change is too narrow to resolve the confirmed cause: a change that leaves the confirmed cause in place is not sufficient, and does not score well for being small.

`Impact scope` asks the same question from the other side: whether the change reaches what its scope requires. A directly related problem that the attempt's own records show — a scope judgment, a build observation, an earlier evaluation's recommendation — and that the change leaves out with no separation reason recorded lowers it, as does a separation reason that answers neither half of question 2.

**Comments in a target's code.** The item also weighs the comments the change adds, by content and by volume, reading the build report's comment check (`<autoflow-root>/docs/units/build.md` > Build report) with the comments in the diff:
- *Content*: a comment that **Code comments** does not admit — a restatement of the code, a design ground, a reference or a history — is depth the AC does not need, as an unneeded hunk is.
- *Volume*: even where every comment is admitted, the evaluator judges whether their amount, absolute and relative to the code they sit on, exceeds what a reader of the changed code needs — a comment block larger than the logic it explains, for example. The judgment is qualitative, with no ratio threshold, and names the comment blocks it rests on.

The evaluator records each such finding in the item's `reason` and in `recommendations`, and does not lower the item's score for it: in a target a comment finding never fails the gate (`<autoflow-root>/docs/evaluation-system.md` > *Code comments in a target*, which also names the defects a comment can carry on their own ground and that this exclusion does not cover). In this repository the item is scored without this comment weighing.

---

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
  - a root cause, or a lever, that is not code — the analysis's conclusion that the lever is not code;
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
  denial). The run records it in its output and goes on with the work that does not depend on it. A
  tool, credential, installation or material the environment does not provide — for a tool it has,
  what using it lacks (access, a purpose and permitted scope, a permission setting) — is a tool
  request: the run does what it can without it and ends ([`core.md`](<autoflow-root>/docs/core.md) > Development
  Lifecycle > *Tools*).

### Procedure

1. **Request.** The module writes `<out>/advisor-request-<k>.md` for a fresh `autoflow-advisor`
   (model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model advisor`):
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

---

<!-- From <autoflow-root>/docs/role-common-rules.md > Communication > Result delivery path by spawn mode -->

### Result delivery path by spawn mode

A spawn's report to its caller is its return value; what carries it is the harness's.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Reporting Format -->

## Reporting Format

When a role spawn reports to the session that spawned it, the report is the spawn's return value:

1. **The body goes to the run's output directory.** The report points at it — record files, source files and commits by path and hash — and does not carry it.
2. **Evidence anchor**: a claim that something is done, passes or is fixed carries what its reader needs to confirm it by reading. Forms that serve, for reference:
   - code change → commit SHA
   - test pass → the run's log, cited by path under the run's `<out>/local/`, with the command that produced it and the summary line read from that log (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, with the content of that line
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under the run's `<out>/local/`, with its result read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → each chain the committing role identified, followed by the grounds of the identification — where it looked and each CI lint step it did not count as a chain, with the condition that excludes it — the enumeration as a whole standing as this item's one anchor. For a chain that ran: the command, its source and what it reported. For one that did not: which chain and why, and where a pull-request CI job runs it instead, that job and the evidence that it runs for this pull request.

   A line number is read at the commit it names; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.
3. **Short**: the report holds what its reader needs to act and to confirm, and no more.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Verification and Tools -->

## Verification and Tools

This section applies to every actor of a module's run — the session that runs it and every role it spawns.

**Local verification** (the instance of [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2 the modules cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every test it authored or changed and every check the verification design runs before delivery — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format > *Evidence anchor*). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is the pull request's CI — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to, cited by path under the run's `<out>/local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the spawning session's acceptance of a role-spawn report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Verify role-spawn claims*), AUDIT's test-first judgment, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the build unit, or a helper it spawns — finds, in the target checkout it works in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **run's own check** — a test the target's tree does not keep, a check run before delivery, a manual checklist — lives in the run's store `<out>/local/`, under the record root outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's absolute path in the store** and is run from the target checkout's root: the asset finds the tree it checks from its working directory (`git rev-parse --show-toplevel`), never from its own location, which is outside every tree. The verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A run that wants one command for several assets writes that driver *as* an asset in the same store. Such an asset is never committed, and stays with the attempt's other records, where a later run reads it. An asset writes its reproducible output — a build result, a copy of a source tree or of another original: an output re-creatable from inputs its record already names, such as a commit and a command — only under the store's reserved path `<out>/local/disposable/`, the one path that can be deleted with nothing the records cite lost; its deletion is outside AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). Nothing a run record, an observation record or a report cites ever goes there — not a log, a record file, the artifacts an observation left, or the asset itself, whose path the recorded command names — even when it is re-creatable. Whether an output is reproducible and uncited is the writer's judgment; where such an output goes is not. Only the store's top-level `disposable/` is reserved — a `disposable` deeper in the store is kept like any other path — and reproducible output left outside it is a deviation, kept with the rest of the store.

**The tools the work needs are found and used; what is missing is requested, and the run still ends**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the main session ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Background execution is the main session's only*), and stopped once the run no longer needs it. A tool that cannot be used has something missing: the tool itself when this environment does not have it — an installation, enabling an MCP server or a browser extension — or, for a tool it has, what using it lacks — access, the purpose and permitted scope of the host or service it reaches, a credential, a permission setting. Providing any of these is outside the assigned scope ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); using a tool the environment already provides is not. What is missing is recorded as a **tool request** — `{missing, instead}` in `<out>/tool-requests.json`: what is missing, named as what is missing and not as the output the tool would give, and what the run did instead, each verification it left unrun or ran on a mock or a person's observation for the lack included. The run does what it can without it — a mock, an observation, a verification left not run, by its own judgment — and ends; the delivery module states every request in the pull request, and the operator decides on it ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Tools*). A purpose or permitted scope is a project fact, and its request asks that the operator record it in the project's information ([`core.md`](<autoflow-root>/docs/core.md) > Project Information). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened is a tool request the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under the run's `<out>/local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each module does this: `<autoflow-root>/docs/units/analysis.md`, `<autoflow-root>/docs/units/design.md` > *Tools* and `<autoflow-root>/docs/units/build.md` > What the build owes.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — a later module given the record, GATE:QUALITY's `Test coverage` or `Commit conventions` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL; a run that fails is recorded as its module's procedure says.

**What a change leaves in the target's tree is not classified by AutoFlow**. A change adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the change does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI*, *Added test files*), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->
