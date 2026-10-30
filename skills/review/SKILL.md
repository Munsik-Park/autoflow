---
name: review
description: >-
  Run the AutoFlow review module once on an invocation file — the given pull
  request reviewed by its configured reviewers, and their reviews aggregated
  into one report. Use when the operator runs the review module
  (/autoflow:review <invocation.json>).
argument-hint: "<invocation.json>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the attempt's record directory the invocation names (`records`). Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: the invocation file) — one run of the review module (`<autoflow-root>/docs/contracts/review.json`) on that invocation: `bash <autoflow-root>/scripts/contracts/contract.sh check-in <invocation.json>` first — a refused input ends the run with its report —, then the work, which writes its outputs — what the module's goal asks for, or, when the run does not reach the goal, `<out>/failure.md`: what it did and why — and `<out>/tool-requests.json` (`[]` when the run lacked nothing, *Tools* below), then `bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>`, which writes `<out>/result.json`; the run ends with the report its procedure owes. The session runs the reviewers and aggregates their reviews into one report, as `<autoflow-root>/docs/units/review.md` (below) states it. The invocation's `records` is the attempt's record directory, where earlier runs left their work. Every `Agent` spawn the run makes takes its model from `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` — the advisor's key is `advisor` (*Spawn Model*, below).

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that the review module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle > Module procedures: The reference values, criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, delivery, ci, The rubric of every evaluation, The evaluation contract; Development Lifecycle > Module references: criterion-screen, criterion-trace, criterion-in-depth, criterion-reconcile, analysis, criteria-apply, hypothesis, design, plan, build, audit, quality, delivery, ci; Team Structure: Evaluation AI, Build module, Functional-unit agents; Evaluation System.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/review.md`; `<autoflow-root>/docs/reviewer-backend.md`; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/units/completion-evaluation.md` > Code comments in a target; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.
- What these documents state is the default. A target's own practice and an invocation's `instructions` come first; the authority rules hold under any instruction.

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

**Inputs, outputs and default.** A module is defined by its inputs, its outputs and its default, each stated in its contract. Its outputs are the files it writes in its output directory, by the names and in the forms its contract gives; check-out checks that form. Its default is what it does with its result unless the invocation says otherwise — its contract's `default`, which its procedure states. The invocation's `instructions` override the default. The AI that does the module's work — the session, or the spawn the work is given to — receives the instructions with the inputs and follows them; the authority rules hold under any instruction (ADR-0040 D5).

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
review                — the reviewers the operator's configuration names, each run by its own script, and their reviews aggregated into one report
```

Each module's procedure — what its work owes, its output, its cautions and its module-local `[MUST]`/`[DENY]` constraints — lives in its document, not in this core file. This file retains what crosses modules: the authority rules, how a module runs, the Execution Principles, and the records and the hook (below). Not every part binds every module: a module's command body carries the parts of this core its module uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and the documents the module uses with them (*Module references* below, *Context Injection*).

### Module references

| Module | Its command body also carries |
|------|------|
| review | the procedure: `<autoflow-root>/docs/units/review.md`; reviewers: `<autoflow-root>/docs/reviewer-backend.md`; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; comments in a target: `<autoflow-root>/docs/units/completion-evaluation.md` > Code comments in a target |

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

**The hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`) keeps the policy denies, in every session and with no state (ADR-0038 D5): `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; a ledger write that changes text already in the ledger; and an `Agent` spawn without an explicit `model`. With no `jq` it reads the other denies from the raw input; the ledger check reads the write with `jq`, and with no `jq` it passes the write unchecked.

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

<!-- From <autoflow-root>/docs/units/review.md -->

# U7 Review — REVIEW

> The procedure of the review module. [`core.md`](<autoflow-root>/docs/core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) >
> Modules.

U7 Review is one module, the review module, whose contract is
`<autoflow-root>/docs/contracts/review.json` and whose procedure is this file
([`ADR-0038`](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D1,
[`ADR-0033`](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)): one pull request's review.

- **Goal**: the given pull request reviewed by its configured reviewers, and their reviews aggregated
  into one report.
- **Inputs**: the pull request (`params.pr`); on a later review, the previous report; the attempt's
  record directory, where the earlier reviews' records and the work's records are.
- **Output**: each reviewer's review record, `<out>/reviews/`, and the report,
  `<out>/review-findings.md`.
- **Default**: nothing beyond its outputs ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle >
  *Inputs, outputs and default*).

## Reviewer review

A run reviews the one pull request its invocation names (`params.pr`, `<owner>/<name>#<N>`). The
review rules are `<autoflow-root>/docs/review/review.md`.

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Config
location*). Each runs as its own script:

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

Each review lands in a **review record**, `<out>/reviews/<reviewer>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`).

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker, and reports by exit code (the script's header).

## Review triage

### Review aggregation

How the reviews become one report is the run's own judgment. An `autoflow-analyzer` spawn, on the
model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names, is available for it.

For reference, a report a later run can act on names the reviewed pull request and its head, and each
finding once — the reviewers that raised it, its severity
(`<autoflow-root>/docs/review/review.md` > Severity) and whether it holds, with the grounds of one that
does not — and the highest severity among the findings that hold.

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and records a finding that does not hold, or holds in part, with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A module acting on a finding that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file, and counted toward no verdict ([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)). A finding that the module acting on it finds does not hold is a rebuttal: it is posted with its grounds on the PR, and the next round's reviews and aggregation judge it — a round of its own also when it only rebuts and changes no code. A gate recommendation's rebuttal is judged by the recommending evaluation's re-score. One that holds in part is fixed for the real problem it points to. When a rebutted finding is kept and the two sides still disagree, the module acting on it puts it to the advisor and follows the decision ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; [`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle > *Decisions within a module*); no count decides when.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A change can loop: each fix answers the case a reviewer — or an evaluation's recommendation — named
while the property it asserts stays unmet, and the next review or re-score names another case. No
spawn checks for this on every round. Whoever reads the finding — the aggregator here, the analysis
module, or the module acting on an evaluation's recommendation — and sees that it repeats an earlier
complaint (the same property asserted, a different witness case; the earlier rounds' findings files, and the earlier evaluations in the record directory, are what it compares against)
says so where it writes the finding: with the finding in the findings file, under the analysis
report, or in its own report. What follows — restating the acceptance
criterion as one rule over the whole input, a further case-specific change, or leaving the property
a known gap — the module acting on the finding decides; a change to the criterion, and a choice it
doubts, it puts to the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor), and a
redefined criterion is recorded as `[ac-decision]` entries. A complaint already decided is not decided again without a new verified
fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case.

## End

The run ends with its output — the report its goal asks for, or the failure output when it does not reach the goal ([`core.md`](<autoflow-root>/docs/core.md) > Development Lifecycle).

What follows an external merge or close — the attempt's branches and records included — is outside
AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).

<!-- From <autoflow-root>/docs/reviewer-backend.md -->

# Reviewer Contract

The review module reviews every pull request the delivery module opens with the reviewers the operator's
configuration names and aggregates their reviews into one report
([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md),
[ADR-0033](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)). This document
is the single home for the reviewers — who reviews, on what input, what each one
leaves, their configuration, and their start-confirmation oracle. How a review
runs and how its reviews are aggregated is
[`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review* and *Review
aggregation*.

## Reviewers

Every reviewer is run by its own script, in the reviewed repository's working
directory, with an environment fitted to its CLI; no two reviewers share one.

| Reviewer | Input | Runtime |
|----------|-------|---------|
| `claude` | the PR (diff, body, linked issue), its rule file, and the attempt's design artifacts in the record directory `--records` names — analysis report, feature design, verification design, decision ledger, build report — wherever the earlier runs left them there | `<autoflow-root>/scripts/review/claude-review-pr.sh` — `claude -p` with Read, Grep and Glob (on any path), the `gh` reads the review needs, the commands Claude Code itself treats as read-only, and whatever the operator's own `~/.claude/settings.json` allows — every other tool and every write denied without a prompt (`--permission-mode dontAsk`); the reviewed repository's own `.claude/` settings and `CLAUDE.md` are not loaded (`--setting-sources user`), since in a trusted checkout its permission rules would add tools; the prompt carries the rule file's text, and the final message is the review |
| `codex` | the PR (diff, body, linked issue), its rule file | `<autoflow-root>/scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, which loads that tree's `AGENTS.md` itself; the prompt carries the rule file's text |

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
  Output : one review record per reviewer and PR —
           <out>/reviews/<reviewer>.md, in the review run's output directory —
           in the <autoflow-root>/docs/review/review.md Output Format.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (<autoflow-root>/docs/units/review.md > Review aggregation)
  Input  : every review record of the PR.
  Output : the report, the PR's findings file.
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
from exit `2` and from every exit below; no wrapper starts its reviewer. A fixed file is read
anew by the next run.

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
record root, `record_root` ([`core.md`](<autoflow-root>/docs/core.md) > Records and the hook). Each key is read and validated by its own reader: an error in
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

**Session vs. reviewer.** These pins govern only the reviewer subprocess;
the review module's session's own model and effort follow the user's session
settings, and the aggregator's the `handoff-review-triage` row of
`.claude/autoflow/spawn-policy.json`. None of them reads another.

## Availability (advisory)

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

It is a script for setting up the environment, and the review module reads its
`reviewers:` line; its result is no ledger entry
([ADR-0038](<autoflow-root>/docs/records/adr/0038-contract-modules-with-no-state-file.md) D4, D8). How a review goes on without a reviewer is the run's judgment. Auth is **not** probed here: a
present-but-unauthenticated reviewer passes and its auth failure surfaces at the
review run, where it counts as a failed run.

## On-demand auth probe (`--probe`)

`<autoflow-root>/scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured reviewer — the same model-API connection a `claude -p` or a
`codex exec` opens.

**Triggers — on-demand only:** the operator runs it after writing or changing
the reviewer configuration. It is **not** run per run, is **not** part of
building the environment, and **no hook consumes it** — a probe failure is narrated, never used
to gate a run.

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

- **Two vendors, two inputs.** The `claude` review reads the attempt's design
  artifacts; the `codex` review reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The `claude` review runs on the same account allowance
  as the session that runs the review, once per pull request and round.

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

<!-- From <autoflow-root>/docs/units/completion-evaluation.md > Code comments in a target -->

## Code comments in a target

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never raises a review's verdict above `Low`
  (`<autoflow-root>/docs/review/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Code comments in a target*). It is
  therefore never the cause of a low score on any item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity its impact sets, as any finding does.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity of the behavior it
  changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged.
- *Secondary (multi-repo):* a comment in a sub-repo is in that sub-repo's scope
  ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules).

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
