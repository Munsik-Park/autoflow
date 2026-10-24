# Design review: input/output-contract modules

**Status**: working draft on the branch `design/io-contract-modules`, from `main` at `a2ff109`
(plugin 0.3.12). Not normative: no rule in `docs/` changes by this document. The decisions it
reaches go into an ADR that supersedes the ones listed under *Decisions this supersedes*.

**How the work runs**: outside AutoFlow — no attempt, no state file, no `/autoflow:cycle` — in
sessions handed off one to the next. A session in this repository runs the installed plugin;
the working tree's rules run only under `claude --plugin-dir .` (`CLAUDE.md`). Each session
appends to *Handoff log* before it ends.

## 1. The concept (operator's statement)

- AutoFlow's plugin is a set of **modules**. Each module declares, in a contract, the
  inputs it needs and the outputs it produces, and the format each output must meet.
- A module validates its inputs when it starts and refuses to run when one is missing or
  invalid; it makes its outputs meet the declared format. It does not know which run it is, what
  ran before it or what runs after it.
- **The state file is removed entirely.** A module does not handle `active`, a lock or any
  other run state.
- The default assumption is that running the steps one at a time, in order, works.
- Running the modules and judging their results is the job of an external party, the
  **Coordinator**. Sequencing, loops, retry counts and caps belong to the Coordinator.

The Coordinator already exists by name in [ADR-0037](../adr/0037-autoflow-keeps-no-after-work-procedure.md)
D2: "the role outside AutoFlow that assembles AutoFlow's functional and evaluation modules —
each takes an input, such as a work branch or an issue number, and produces a result — into a
pipeline". There its scope is only what follows a merge or a close. This work widens that scope
to the whole lifecycle.

## 2. How progression is controlled today

Survey of `main` at `a2ff109`.

| Mechanism | What it controls | Where |
|---|---|---|
| State-file scores and verdict | U3 spawn (`gate_hypothesis` PASS or a `skipped` verdict), U4 spawn (`gate_plan` PASS), `git push` and `gh pr create` (`audit` + `gate_quality` PASS) | `hooks/check-autoflow-gate.sh:1377-1388`, `:1450-1463`; [state-tracking.md](../../state-tracking.md) > Hook gates |
| State-file `remedy_class` | "no attempt open" before leaving a gate; blocks push and PR while present | `hooks/check-autoflow-gate.sh:1453-1454`; [core.md](../../core.md) > AutoFlow State Tracking |
| Artifact presence and content | one check only: `issue-{N}-remedy-sweep.md` with non-empty `## Command` and `## Output` on a `doc` re-entry commit | `hooks/check-autoflow-gate.sh:1482-1486` |
| Ledger entries | `[criterion-ready]` (criterion readiness), `[checklist-decision]` (AUDIT admission), `[review-autofix]` count (REVIEW cap 7), `[gate-autofix]` count (recommendation cap 7) | `scripts/preflight/criterion-ready.sh`, `scripts/gate/security-checklist.sh`, `scripts/handoff/review-gate.sh`, [units/completion-evaluation.md](../../units/completion-evaluation.md) > Recommendation triage |
| Orchestrator judgment and counting | the ARCHITECT (3), AUDIT (2) and GATE:QUALITY (3) re-entry counters, the resume point, re-entry depth | [units/design.md](../../units/design.md) > Re-entry; [units/preparation.md](../../units/preparation.md) > Resume; [core.md](../../core.md) > Flow Control |
| Entry evaluation | `entry:` line (`start`, `resume`, `review-response`, `abbreviated`, …) from state files, PR state and criterion readiness | `scripts/preflight/cycle-status.sh` (`kind_of`) |

Facts the survey established:

- The hook enforces entry for U3, U4 and U6 only; U1, U2, U5 and U7 have no device-enforced
  entry condition.
- No script writes the state file; the orchestrator writes it.
- The only machine-readable state schema, `tests/fixtures/gate-schema.json`, is read by no
  code; the hook's own `jq` validator is what is enforced (`hooks/check-autoflow-gate.sh:1197-1202`).
- No unit declares its inputs in a machine-readable form. Inputs are prose in each unit's
  *Unit spawn* section; outputs are prose in each unit's *Artifact contract*.
- [ADR-0025](../adr/0025-outcome-gated-functional-units.md) D6 keeps the four gated state keys
  as the unit exit gates on purpose, so that the hook's validator and Resume carry over.

## 3. Reallocation

| Disposition | Item | Where today |
|---|---|---|
| **Remove** | the state file: schema, `active`, `cycle`, `mode`, `phase`, `phases.*` | [state-tracking.md](../../state-tracking.md); [core.md](../../core.md) > AutoFlow State Tracking |
| **Remove** | the hook's progression gates and the state lookup that serves them (checkout ownership, multi-active and malformed fail-closed, record-root fail-closed on a dev branch) | `hooks/check-autoflow-gate.sh` Section 2 and the progression gates, about 1092-1495 |
| **Remove** | entry evaluation | `scripts/preflight/cycle-status.sh` |
| **Remove** | in-tree state migration | `scripts/migrate/migrate-in-tree-records.sh` |
| **Move to the Coordinator** | the Flow Control table, the caps, the shared counters | [core.md](../../core.md) > Flow Control |
| **Move to the Coordinator** | every unit document's `## Transitions` and `## Re-entry` | `docs/units/*.md` |
| **Move to the Coordinator** | Modes, Review-response setup, Resume, PR Wait Rule | [units/preparation.md](../../units/preparation.md) |
| **Move to the Coordinator** | route selection (by `remedy_class` today; by the judgment of the AI acting on a finding, Q11), recommendation triage, the attempt caps | `scripts/gate/remedy-route.sh`; [units/completion-evaluation.md](../../units/completion-evaluation.md) > Recommendation triage, FAIL routing; `review-gate.sh` cap |
| **Move to the Coordinator** | the orchestrator role itself | ADR-0025 D5; [core.md](../../core.md) > Team Structure > AI Orchestrator |
| **Keep in the module, as contract** | the output formats: analysis report sections, design AC table and `## Tools`, build report sections, evaluator report JSON, findings file | [units/analysis.md](../../units/analysis.md) > Analysis report; [units/design.md](../../units/design.md) > Output artifacts; [units/build.md](../../units/build.md) > Build report; [evaluation-system.md](../../evaluation-system.md) (report JSON); [units/review.md](../../units/review.md) |
| **Keep in the module** | what each unit's work owes | each unit document's *What the … owes* |
| **Keep** | state-independent policy denies: `gh pr merge`, push to the default branch or the base, `gh issue create`, ledger append-only and authority, explicit `model` on a spawn, backgrounded suite runs | `hooks/check-autoflow-gate.sh` Sections 0, 1, 1b, 1e |

## 4. Module boundaries

A unit today bundles work with its gate: U2 = DIAGNOSE + GATE:HYPOTHESIS, U3 = ARCHITECT +
GATE:PLAN, U4 = BUILD + AUDIT. With judging moved outside, the work and the evaluation become
separate modules:

- **Functional modules** produce artifacts: the criterion review's four modules (below),
  analysis, design, build, delivery, review.
- **Evaluation modules** take artifacts and produce an evaluation report (scores and
  findings; no `remedy_class`, Q11): hypothesis, plan, audit, quality.
- **Deterministic modules** are scripts with no model: criteria-apply, which computes the applied
  acceptance criteria (Q5).

The criterion review is four modules (Q3 remainder, **accepted** by the operator, 2026-10-23: "1 수용"): criterion-screen (today's stage 1: the review items and the screening, writing the
review record and one target file per criterion), criterion-trace (stage 2), criterion-in-depth
(one run per criterion with an in-depth target) and criterion-reconcile. Grounds:

- Each stage already has fixed input and output files, and its independence is already an input
  restriction: stage 2 "receives the issue body and the stage 1 record and none of the session's
  conversation, and the in-depth context receives the target file and nothing of the session's
  verdicts or grounds" ([criterion-review.md](../../criterion-review.md) > In-depth analysis and
  reconciliation, *What the procedure fixes*). A contract states exactly that.
- Q3 puts every re-run with the Coordinator. As one module, a stage whose output falls short would
  either be re-run inside the module — a loop Q3 rules out — or force a re-run of the whole review.
  As four, the Coordinator re-runs the one stage.
- The order — stage 2 and the in-depth analyses alongside each other once stage 1 is written, the
  reconciliation after all of them ([criterion-review.md](../../criterion-review.md) > Stages of the
  review) — is run today by the session that spawns them, the part that becomes the Coordinator's.
- Stage 1 is carried today by that session itself (*When and by whom* > *Reviewer*); with the
  session becoming the Coordinator, stage 1 has to become a module of its own.

The review decides the disposition of every item it finds (Q18). What follows the four — putting
to the advisor an item the review could not decide with confidence, recording the dispositions as
`[ac-decision]` entries, editing the issue body to them, and the `[criterion-ready]` entry (an `O`
entry the main session writes, *Confirmation*) — is the Coordinator's, being decisions and their
record (Q4). The issue-body edit
stays the Coordinator's and does not become a deterministic module (Q9).

This split is the one ADR-0037 D2 already names ("functional and evaluation modules"). It also
closes a gap the survey found: only AUDIT's report has a fixed path
(`<attempt-dir>/issue-{N}-audit.md`, [evaluation-system.md](../../evaluation-system.md) > AUDIT >
Report). GATE:HYPOTHESIS, GATE:PLAN and GATE:QUALITY reports have none, yet
[units/design.md](../../units/design.md) > Unit spawn names "the GATE:HYPOTHESIS reports" as an
input. As module outputs, every evaluation report gets a declared path and format.

`/autoflow:cycle` and the abbreviated path ([abbreviated-path.md](../../abbreviated-path.md))
stop being paths the plugin defines. They become two ways of composing the modules.

## 5. Contract format and module invocation

**Accepted** by the operator, 2026-10-23: §5.3 ("3 수용"), then §5.1–5.2 ("2 수용") — the contract files' place and reading, not the run's input and output files, whose place is the Coordinator's (§5.3). Drafts that follow it: the design module
([`docs/contracts/design.json`](../../contracts/design.json)) and the plan evaluation module
([`docs/contracts/plan.json`](../../contracts/plan.json)), then, on Q6–Q16, the other twelve of
§4 (`docs/contracts/`: analysis, build, delivery, review, hypothesis, audit, quality, the four
criterion-review modules and criteria-apply). No device reads them yet.

### 5.1 Where contracts live, and how they are read

- **One file per module**, `docs/contracts/<module>.json`. `CLAUDE.md` > Writing AutoFlow
  Documents writes an AutoFlow path as `<autoflow-root>/docs/…` or `<autoflow-root>/scripts/…`; a
  contract under `docs/` keeps that convention and adds no top-level plugin component (ADR-0027 D1
  lists them).
- **Written in JSON, read with jq** (Q17). The README's prerequisites are Claude Code, `jq` and
  `gh` (`README.md`, **Prerequisites**), and every file this repository's devices read is JSON
  (`.claude-plugin/plugin.json`, `hooks/hooks.json`, `.claude/autoflow.local.json`,
  `.claude/autoflow/spawn-policy.json`, `tests/fixtures/gate-schema.json`). A contract has one
  source; no generator and no equality check. What a comment would carry goes in a `note` key, or
  in this document when it is history (why a rule was removed: §6).
- **No inline licence header.** `REUSE.toml` bulk-covers `**/*.json`.

### 5.2 What a contract carries

| Key | Holds |
|---|---|
| `contract` | the format version, `1` |
| `module`, `kind` | the module's name; `functional`, `evaluation` or `deterministic` (§4) |
| `goal` | one paragraph: what the output is for |
| `procedure` | the document the module follows (today's unit document, or the rubric) |
| `params` | scalar inputs the Coordinator passes: name, type, required, enum |
| `inputs` | file inputs: name, `required`, and `from` — where such an input comes from: `{module, output}` (another module's output, whose schema the validator then applies; a list when it may come from more than one), `{ledger: [<marker>…]}` (a decision entry, Q4), `{path: target}` (a document of the target the Coordinator names), `{path: coordinator}` (a record of the Coordinator's, such as the recommendations it deferred), or `{results: tool_requests}` (the tool requests of the run's earlier results, §5.3) |
| `outputs` | each output: `file` (its name inside the output directory), `format` and its schema |
| `reference` | values AutoFlow provides with the output for the Coordinator to apply (Q2) |

**Outputs.** Each output names its `format` and, for a file, its `file` inside the output
directory (`many` when it is a set of files, `required: false` when it may be absent). What the
validator checks is the output's `checks` list, each item a check of a fixed `type`; what only an
evaluation can judge is the output's `evaluation` list, prose the evaluation module reads and the
validator does not. `scripts/contracts/contract.sh` implements every type below; a type it does not
know is a defect, not a pass.

| `format` | Check types | Instance |
|---|---|---|
| `markdown` | `section` (a `## <heading>` with a non-empty body — `none` when there is nothing), `line` (a line matching a pattern), `table` (a table by its first header cell or its whole header, under a heading, outside the `## Delta — round <n>` sections; `rows_disposed`: every row carries something after its first cell; `unique_first`; `covers`: every id a source names is a first cell) | the verification design's `Item` table covering the applied criteria and the feature design's `## Scope` items |
| `json` | `keys` (per key: `type`, `required` / `required_when`, `const`, `pattern`, `keys_exactly`, `items_keys`), `forbidden_keys`, `unique`, `partition` (a key set split into two lists), `covers` (every id a source names has an entry, with its disposition) | an evaluation's scores, re-score and recommendations |
| `git` | `git_range`: the branch gained commits since check-in | the build's commits |
| `pull-request` | `pr_open` (open, a draft), `pr_body_covers` (the body states every id a source names), `pr_checks` (every check on the head green, or the body's marker line that no CI ran) | the delivery's pull request |
| `pull-request-comment` | `pr_comment_posted` (the kept comment file is posted) | the review's aggregated comment |

A `covers` source is an input's JSON at a jq path (`{input, ids}`), or the first column of a table
in an input or another output (`{input | output, table}`). A `when` limits a check to runs given a
named input, or to a key's value.

**Every check says who makes it**, by the list it is in: `checks` (the validator) or `evaluation`
(the evaluation module that scores the output). The split exists today: the orchestrator checks
that the design documents carry `## Decision requests` ([units/design.md](../../units/design.md) >
Unit spawn), while whether a verification fits its criterion is GATE:PLAN's `Verification fit`
([evaluation-system.md](../../evaluation-system.md) > GATE:PLAN > Scoring). A contract names both,
so the validator never claims what only an evaluation can judge.

**No rule checks a classification of a module's judgment** (Q8): a closed list of values the
module must pick its judgment from. A case the list does not fit is forced into the nearest value
or into `none`, and the judgment it stands for is lost without a trace. Today's verification design
is the instance: `Type` is "one of" six dispositions ([units/design.md](../../units/design.md) >
Output artifacts, Test necessity), `Kind` one of three, and a committed check names one of two
`standing` tokens ([ADR-0024](../adr/0024-two-layer-verification-and-target-owned-tests.md) D1),
while the same section says "Necessity is a **judgment**, not a classification". The only reader
that branches on these values mechanically is `scripts/gate/verification-layer-check.sh`, over the
`standing` token, in this repository only; the others are the AUDIT and GATE:QUALITY evaluators and
the PR body. What the verification design owes mechanically is that every item the work owes has a
disposition (`docs/contracts/design.json` > `outputs.verification_design.checks`).

**A contract is input, disposition, output** (Q14): it checks that the inputs are there, and that
the output disposes of every item the work owes — each applied acceptance criterion, and each item
the module itself added or changed once that is decided. How the work is done is the procedure's
(`procedure`), never the contract's.

### 5.3 Invocation

- **The Coordinator writes an invocation file** and starts the module on it:
  `/autoflow:<module> <invocation.json>` for a session, or the same path in an agent's prompt.

  ```json
  {
    "contract": 1,
    "module": "design",
    "params": { "issue": 507 },
    "inputs": { "applied_criteria": "<path>", "analysis": "<path>", "hypothesis_evaluation": "<path>" },
    "out": "<output directory>"
  }
  ```

- **The module checks its inputs first**: `bash <autoflow-root>/scripts/contracts/contract.sh check-in
  <invocation.json>` — every declared param and required input given, every input path present,
  and an input another module produced coming from a run whose `result.json` beside it says
  `accepted`: that run's check-out already applied the producer's schema, so it is not applied
  again. On a refusal it writes nothing but the result file and stops.
- **It writes each output to `<out>/<file>`** and ends with `bash <autoflow-root>/scripts/contracts/contract.sh check-out
  <invocation.json>`, which checks the outputs against the contract and writes
  `<out>/result.json`: the module, `accepted` or `refused`, each output's path, each defect
  found, and the module's tool requests — the `<out>/tool-requests.json` every run writes, a JSON
  array of `{missing, instead}`, `[]` when the run lacked nothing. The Coordinator reads that file to
  decide the next run (Q3).
- **A tool the work needs is used; a tool that is missing is requested, and the run still ends**
  (Q10). A module that lacks a tool does what can be done without it — a mock, a verification
  left not run, by its own judgment — and finishes. It records each missing tool as a tool request:
  what is missing, and what it did instead, including each verification that failed or did not run
  for the lack. The requests go in its result and its report (`none` when there are none); the
  delivery module states every request of the run in the pull-request body, so the operator sees
  them and decides — install the tool and re-run, close the PR and set up the tool apart, or merge
  and add the tool. Which file declares a project's tools, and when it is checked, is the target's
  environment setup, checked when the environment is built, not on every run.
- **The output directory is the Coordinator's.** A re-run gets a new directory and names the
  previous outputs as inputs, so nothing is renamed or overwritten.
- **A module does not know which run it is.** What a re-run's output owes because it is a re-run is
  derived from its inputs: the design's `## Delta — round <n>` takes `n` from the number of delta
  sections in the previous document it is given, plus one (`docs/contracts/design.json` > `rules`).
- **The existing commands stay until sub-issue 3**: `/autoflow:cycle-u1` … `cycle-u7` keep their
  current behaviour on this branch, and sub-issue 3 replaces them with the module commands.

The points this section left open for sub-issue 2 are settled as Q6–Q9 (§6): the validator's
place, the writer of an evaluation module's output, the verification design's table, and the
issue-body edit.

## 6. Open decisions

| # | Decision | Status |
|---|---|---|
| Q1 | Where the evaluation gate lives | **Withdrawn** (operator, 2026-10-23). The question assumed an actor that pushes or opens a PR outside the module whose output that is — the current model's premise, where one orchestrator holds every tool and the hook reads the command it issues (ADR-0025 D8). In this model push and PR are the delivery module's output and no other module produces them; how modules are run is the Coordinator's composition. The hook's push, PR and U3/U4 spawn gates go (§3). Whether delivery takes an evaluation output is settled in its contract by what its output needs: the PR body's known gaps carry the recommendations deferred or separated at triage ([units/delivery.md](../../units/delivery.md) > Push and pull request), so the quality evaluation's triage result is a content input, not an admission condition. |
| Q2 | Where the pass threshold lives | **Settled** (operator, 2026-10-23): AutoFlow provides the reference values with the evaluation output; applying them is the Coordinator's. The evaluation module outputs scores, grounds and `remedy_class` and no `verdict` — as today, where the evaluator scores and the hook computes PASS ([core.md](../../core.md) > Flow Control; [evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format). The reference values are today's PASS Criteria (avg ≥ 7.5, each item ≥ 7, security ≤ 3 → rework; [evaluation-system.md](../../evaluation-system.md) > PASS Criteria), kept with the rubric whose scale they are set on. Where in the output or the contract they sit is fixed when the evaluation contracts are drafted. |
| Q3 | The line between a module's own repetition and an external loop | **Settled** (operator, 2026-10-23): an output that falls short of its format is re-run by the Coordinator; a module runs once and does not loop. Re-running on an evaluation result is the Coordinator's as well. Today's re-spawn on a missing report section is already the orchestrator's ([units/analysis.md](../../units/analysis.md) > Unit spawn), so it moves to the Coordinator with the rest of the orchestrator's routing. The criterion review's stages: four modules, accepted (§4). |
| Q4 | The ledger's standing | **Settled** (operator, 2026-10-23): the ledger holds only decisions — entries that settle what a module cannot settle itself (`[criterion-ready]`, `[ac-decision]`, `[checklist-decision]`, a design point), under their authority: `operator decision` and the main session's own decision in the `O` namespace, `advisor decision` in the `A` namespace ([decision-ledger.md](../../decision-ledger.md) > Entry identifier). In this model the main session that writes `O` is the Coordinator's. A module contract may name such an entry as an input ("the ledger decision with marker X"). What a module can produce itself is its own output file. The orchestrator's entries leave the ledger: the attempt records counted for the caps (`[gate-autofix]`, `[review-autofix]`), the cap-window reset (`[reentry-decision]`) and `[rebuttal]` are the Coordinator's records; the gate verdict entries ([decision-ledger.md](../../decision-ledger.md) > Entries, *Writers*) are replaced by the evaluation output files. The hook's append-only and authorship denies stay as they are and keep guarding these entries. The contradiction between [state-tracking.md](../../state-tracking.md) ("the ledger is not a gate input") and the REVIEW cap counted from `[review-autofix]` entries goes with both: the first document is removed, the count moves to the Coordinator. |
| Q5 | How an acceptance-criterion change is applied | **Settled** (operator, 2026-10-23): the applied criteria are an output of their own. A deterministic script computes them from the analysis report's first AC table and the `[ac-decision]` entries; every later module takes that output as its input. The request is already a module output (the design's `## Decision requests`, the build report, an evaluation recommendation — [units/design.md](../../units/design.md) > Report routing) and the decision a ledger entry (Q4); only the edit the orchestrator makes today to the analysis report's table ([units/analysis.md](../../units/analysis.md) > Re-entry) is replaced. It needs the `[ac-decision]` grammar ([decision-ledger.md](../../decision-ledger.md) > Decision-point entries, *Acceptance-criterion decisions*) to carry the criterion's new text for `revised`, `split` and `added` — today the entry has `- AC:`, `- Disposition:` and one Decision line, which a script cannot apply. Rejected: re-running analysis on the entries (a full analysis run for a table edit, and other content may move); each consuming module applying the entries itself (one application in five places). |
| Q6 | Where the contract validator lives | **Settled by the existing rule** (2026-10-24): `scripts/contracts/contract.sh`, run as `bash <autoflow-root>/scripts/contracts/contract.sh check-in\|check-out <invocation.json>`. `bin/` is the plugin's component that is on the Bash `PATH` of every session and subagent ([ADR-0027](../adr/0027-plugin-only-delivery.md) > Context, M1; D1); its two entries are the commands a context with no root declaration must still run — `autoflow-root` prints the root (D3), `autoflow-records` names every record path (`bin/autoflow-records`, header). The validator's callers, a module's command body and its agent definition, carry the root declaration (D3), so it is a file a role runs by path, under `scripts/`. It would belong in `bin/` only if the Coordinator ran it with no root declaration; in §5.3 the Coordinator reads `result.json` and does not run it. The name follows `scripts/`' `<noun>.sh <subcommand>` form (`criterion-ready.sh status`, `spawn-policy.sh model`). |
| Q7 | Who writes an evaluation module's output | **Settled by the existing rule** (2026-10-24): the session that runs the evaluation module, writing the report the evaluator returns verbatim. "The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores" ([role-contracts.md](../../role-contracts.md) > Evaluation AI), and the spawning side records it verbatim (`agents/autoflow-evaluator.md`, Hard rules). Only the place changes: the state file's `scores` become `<out>/evaluation.json`. Giving the evaluator a Write tool would change that rule with no defect observed under it. This also names the writer §7 item 9 found missing for `issue-{N}-audit.md`. |
| Q8 | The verification design's table | **Settled** (operator, 2026-10-24): the classification is removed — `Type`, `Kind`, the per-column rules of `Reason` and `Failure mode`, and the `standing` token; what the table owes is a disposition for every applied criterion (§5.2, *No rule checks a classification*). The table is found by its header row's first cell (`Item`, Q14), outside every `## Delta — round <n>` section: a re-run appends a delta and leaves the first run's text as it stands ([units/design.md](../../units/design.md) > Re-entry), so no heading is fixed for it — issue #500's verification design carries two tables with the same header row, the second inside `## Delta — round 2`. The other columns are the module's. Removing the classification from the documents, rubrics and scripts that carry it is sub-issue 3's (§8, §9). |
| Q9 | Whether the issue-body edit becomes a deterministic module | **Settled** (operator, 2026-10-24): no. The edit stays the Coordinator's, as the review session's today ([criterion-review.md](../../criterion-review.md) > Authority, "the session edits the issue body to match"). A module, or a re-read of the edited body against the decisions, would guard against an edit that departs from the decisions; no such defect is on record (issue search "issue body": #467, #466, #305, none of them this), so neither is added. |
| Q10 | Tools | **Settled** (operator, 2026-10-24): a module uses the tools its work needs; when one is missing it finds what can be done without it, finishes the run, and records the missing tool as a request in its result and report, which the PR body states for the operator (§5.3). The verification design's `## Tools` section and its availability list go (`docs/contracts/design.json`), and with it GATE:PLAN's `Tools` item ([evaluation-system.md](../../evaluation-system.md) > GATE:PLAN > Scoring; `docs/contracts/plan.json`), removed by the operator on its own ground: it scored the form of the declaration — each tool, its availability and its ground, and a reason owed only by a row verified by a person or on a mock — not whether a tool fits the criterion, so declaring a tool scored safer than not; whether the verification, its tool included, fits the criterion is `Verification fit`'s. No run checks the tools: today's per-cycle `preflight.local_checks[]`, which stops the cycle on a failed check ([units/preparation.md](../../units/preparation.md) > Target-declared local checks), and the pause for a missing tool ([core.md](../../core.md) > Flow Control, "tool or referenced material → user") go in sub-issue 3. Withdrawn on the way: a module stopping on a missing tool with a `blocked` result, and AutoFlow naming one place for a project's tool declarations — the operator decides from the PR what to do about a missing tool. |
| Q11 | `remedy_class` | **Settled** (operator, 2026-10-24): no contract carries it. Today the evaluator tags each failed item, and each `Medium`+ recommendation, with one of `doc`, `test`, `impl`, `design` or `operator`, and `scripts/gate/remedy-route.sh` routes the re-entry from the tags ([units/completion-evaluation.md](../../units/completion-evaluation.md) > FAIL routing; [evaluation-system.md](../../evaluation-system.md) > Remedy class). A fix can be large or small, and where it is made cannot be fixed in advance: the AI acting on a finding judges at which stage it is made, and asks the advisor when it cannot. A contract states the least it can: it names no class and no destination, and the one way out of an uncertain judgment is to ask the advisor. This narrows Q2: the evaluation outputs scores and grounds, and no `remedy_class`. A fix no module owns — today's `doc` route, the orchestrator's own doc commit — needs no module either: the coordinating session runs it as a one-off session or judges it itself. |
| Q12 | `fail_hypothesis` | **Settled** (operator, 2026-10-24): not an output contract's. It records the evaluator's pre-scoring search for the strongest FAIL case — the rule that, when everything reads as right, the opposite case is looked for first ([evaluation-system.md](../../evaluation-system.md) > Evaluator conduct > *Pre-scoring FAIL hypothesis*). That is the evaluation procedure, a rule of the rubric's evaluation, and stays binding there; as output, "nothing reads it programmatically and no gate consumes it" (*ibid.* > Evaluation Output Format). The plan contract drops the key and its `disposition` list. |
| Q13 | `rerun_reason` | **Settled** (operator, 2026-10-24): removed from the design contract, with its six values and the rule tying it to a previous document. Nothing reads it or branches on it: today it is the text in a delta heading's parentheses ([units/design.md](../../units/design.md) > Re-entry, the only place the list appears), and what a re-run works from reaches it as inputs of its own — the previous documents, the plan evaluation, the build's blocker, the failed items. A re-run is known by a previous document being given; the delta heading keeps `## Delta — round <n>`, which the table's locate reads (Q8). |
| Q14 | What a contract checks | **Settled** (operator, 2026-10-24): a module is input, the work it does, and output; its contract checks the inputs and that the output disposes of every item the work owes. Acceptance criteria are the required behaviour; an item the design adds or changes, once decided, is owed the same way. So the coverage check spans both: every applied criterion and every item the feature design's `## Scope` includes has a row with its disposition, the included items carrying an id the table names — today they are `—` rows that no check pairs with the `## Scope` section, though [units/design.md](../../units/design.md) > Output artifacts owes each a row. The verification design's risk line ([units/design.md](../../units/design.md) > Verification depth) and the feature design's `[DENY]` on content the build derives (*ibid.* > Output artifacts) are how the work is done, so they leave the contract and stay in the procedure, as `fail_hypothesis` did (Q12). |
| Q15 | The plan and design contracts' remaining rules | **Applied by Q11, Q12 and Q14** (2026-10-24; the operator asked that what the principles settle be applied, and only the rest be asked). `blocking_issues` goes: no reader is named for it, and its cap of three ([evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format, `"items ≤ 3"`) cut a list the rule "surface every issue found" (*ibid.* > Evaluator conduct) wants whole; each item's score and reason carries what blocks. A recommendation's `severity` leaves the contract's checks with `remedy_class` (Q11) — the levels and the procedure's rule that every finding states one stay: today it splits triage into the orchestrator's own judgment on `Low` and a class-routed attempt on `Medium`+ ([units/completion-evaluation.md](../../units/completion-evaluation.md) > Recommendation triage), and with routing the acting AI's judgment, nothing branches on it. The re-score keeps what it owes (Q14) — every rubric item scored afresh or inherited, and every prior finding dispositioned — and which items it scores afresh is the procedure's (Q12). The design's "never applies an acceptance-criterion change" goes: the applied criteria are criteria-apply's output and the design's input (Q5), so a change can only be requested. |
| Q16 | How a procedure is written | **Settled** (operator, 2026-10-24): a procedure gives the AI the goal of its work, and the AI judges how to meet it — for a review, "state the severity of every finding". It does not prescribe a form that must be present and then check that it is: that turns the work into a fixed procedure carried out mechanically instead of judged toward a goal. The contract checks inputs and dispositions (Q14); the procedure documents sub-issue 3 rewrites state goals. |
| Q17 | The contracts' format | **Settled** (operator, 2026-10-24): JSON, read with `jq`; this replaces §5.1's "authored in YAML, read as JSON" as accepted on 2026-10-23. Where the reader is a shell script with `jq` the usual practice is one JSON source; a YAML source with generated JSON is the less common case, for files people write at length and must comment, and it keeps two sources in step. Every file this repository's devices read is already JSON (§5.1). `yq` is not a runtime prerequisite (README > Prerequisites), is installed on its own where it is present (`/opt/homebrew/bin/yq` here, while `jq` is the system's `/usr/bin/jq`), and two different tools carry the name (`mikefarah/yq`, `kislyuk/yq`). The generator and its equality check leave #509's scope. |
| Q18 | What the criterion review returns | **Settled** (operator, 2026-10-25): every item the review finds, disposed of by the review itself, with its grounds — the work any issue analysis does: no criteria, so they are established; a criterion wrong, so it is revised; one missing, so it is added; a problem found beside them, so it is included in this issue or separated from it. The first run of criterion-screen on opensre#1 returned two revisions and three "open questions" ([criterion-review.md](../../criterion-review.md) > Review record, `## Open questions`, put to the advisor): which `<…>` are tags (a criterion the issue lacks), whether the gateway path is in scope (the body states it wrongly), and whether a raw `&` that drops text is (a problem found beside the criteria). Each is one of the dispositions above, so the review decides it. The criterion-screen and criterion-reconcile contracts require one `## Dispositions` table, an item and its disposition per row, in place of `## Proposed changes` and `## Open questions`; an item the module cannot decide with confidence says so and states the question for the advisor — the one way out (Q11), not a second list. |

Operator's words:

- Q1: "생각해보면 이 질문이 조금 이상한 것이 각 단계는 자기가 실행을 하는 범위가 있어요. 입력이 있고 출력의 형식이 있죠. 근데 그 출력의 형식을 무시하고 직접 푸시나 PR을 생성한다라는 가정을 하는 거잖아요. 이 지금 질문이 맞아요?"
- Q2: "C 형태가 맞는 것 같아요. 기본적으로 출력 값에 레퍼런스 루브릭 값을 제공하는 것은 오토플로우에서 제공하는 것이 맞고, 그것을 실제로 적용하는 것은 외부에서 적용하는 것이 현재 설정입니다."
- Q3: "참고로 추가하면 현재 만약에 출력의 형식이 부족하다라고 하면 조율자가 다시 실행을 시킬 거예요. 즉 루프로 재실행하는 구조로 만들면 이 문제는 해결이 됩니다."
- Q4: "c" (option C: the ledger holds only decisions).
- Q5: "B로 진행하세요." (option B: the applied criteria as an output of their own, computed by a script).
- Q6: "그러면 1번은 선택할 문제인가요?" (the operator's question, on the place following from the existing split).
- Q8: "분류 체계는 AI의 작업을 제한하는 검사입니다. 다 걷어내야 돼요. 실제로 필요한 것은 AC가 있고 그 AC에 대한 처분이 있느냐 뿐입니다." Then: "시안 수정으로 합니다. 적용하세요."
- Q9: "문제가 발생한 적도 발생하지도 않았는데 룰을 추가하자는 것이죠?"
- Q18: "이슈를 분석하고 각 분석된 내용에 대해서 처분을 하고 출력을 각각 항목들에 대해서 검토 결과를 내는 것. 이게 목적인데 그 중간 과정을 AI가 지금 자율적으로 하도록 유도를 했는데 지금은 전부 다 질문으로 돌아왔단 말이죠. 이 부분이 개선이 돼야 될 것 같아요."
- Q17: "JSON으로 합니다."
- Q16: "목표는 리뷰를 하면 발견한 항목마다 심각도를 적는다 라는 목표를 주는 건데, 그러면 AI가 그 목표에 맞춰서 작업을 하겠죠." On the form-and-check way: "그것은 AI에게 작업의 목표를 주고 하도록 하는 그런 방식이 아니라 그냥 정해진 절차를 하게 하는 기계적인 행위를 유도해요."
- Q14: "모듈이라는 것은 입력이 있고 내부에 처리하는 프로세스가 있고 그 처리를 모두 한 이후에 출력이 있는가를 확인하는 거예요. 입력, 처분, 출력 단순합니다. AC는 기본적으로 요구되는 기능이고 설계나 아키텍트에서 추가하거나 변경한 것이 결정이 되면 그 사항들을 출력 형식에 맞게 처분하고 작업을 하는 거예요."
- Q13: "빼주세요."
- Q12: "실패 가설을 찾는 것은 계약, 출력 계약이 아니고 평가 절차죠. 평가 절차에서 다만 강제해야 되는 건 맞아요. … 루브릭의 루브릭 평가에서의 룰이죠."
- Q11: "계약으로 정할수 없어요, 계약으로 쓰는 것은 최소한이어야 합니다 … 일부 수정이 대형일수도 부분일수도 잇어요 미리 정할수 있나요? AI 는 충분히 어느 단계에서 할지 정하거나 어려울 경우 advisor 를 요청할수 있어요 … 탈출구가 어디라고 하는 것이 아니라 탈출하는 방법만 최소로 정하면 됩니다" On a fix no module owns: "조율 세션이 충분히 세션 실행해서 1회성 실행할수 있거나 판단할수 있어요 결정할 문제가 아닙니다"
- Q10: "도구가 필요하면 쓴다. 없으면 요구해라. 반드시 기록해서 운영자한테 요구해라. 그리고 도구가 없더라도 할 수 있는 것을 방법을 찾아서 수행은 끝낸다." And: "매 사이트마다 검사하는 건 없앱니다." On GATE:PLAN's `Tools` item: "뺍니다."

## 7. Couplings to resolve

Each is a place where one unit depends on another's internal state, or edits another's output,
rather than reading a declared output.

1. Gate verdicts live only in the state file; U3, U4 and U6 admission reads them (§2).
2. U7 writes U5's record: the REVIEW design route sets `phases.gate_quality.remedy_class`
   ([units/review.md](../../units/review.md) > Review triage).
3. "Recommendations triaged, no attempt open", a U5 rule, gates the exits of U2, U3 and U4
   ([core.md](../../core.md) > Flow Control).
4. The ARCHITECT counter is fed by U3, U4, U5, U6 and U7 and persisted nowhere
   ([units/design.md](../../units/design.md) > Re-entry).
5. U1 renames every artifact of U2..U7 and resets `phases`, `cycle` and `mode` on
   review-response ([units/preparation.md](../../units/preparation.md) > Review-response setup).
6. U2's behavior branches on the state field `mode` ([units/analysis.md](../../units/analysis.md)
   > Transitions, Unit spawn). In this model it is an input.
7. Deferred gate recommendations reach U4 through prompt text and a ledger verdict entry, not
   through an artifact ([units/completion-evaluation.md](../../units/completion-evaluation.md) >
   Recommendation triage; [units/build.md](../../units/build.md) > Unit spawn).
8. A U7 thin-route BUILD re-run does not bring the build report up to date
   ([units/build.md](../../units/build.md) > Re-entry), while U6's PR body and U7's reviewer
   read that report.
9. No writer is named for `issue-{N}-audit.md`: the evaluator has no Write tool
   (`agents/autoflow-evaluator.md`, `tools: Read, Glob, Grep, Bash`). Q7 names it for every
   evaluation output.
10. The unit commands' entry check ("confirm from cycle-status.sh that the cycle stands at Uk's
    entry", `skills/cycle-u3/SKILL.md`) has no definition, because `cycle-status.sh` names no phase
    ([units/preparation.md](../../units/preparation.md) > Resume).

## 8. New work

- One JSON contract per module: inputs, outputs, each output's schema (Q17).
- One contract validator, `scripts/contracts/contract.sh` (Q6): input check at module start, output
  check at module end — written in #509, with the markdown model it shares with criteria-apply
  (`scripts/contracts/markdown.jq`).
- A check that the contracts and the documents agree — written in #509 as `contract.sh lint`, a
  step of `contract-suites.yml` (a declared inventory agreeing with the tree it describes, the
  `manifest` kind that workflow carries): each contract's module and kind, its procedure and every
  source it cites resolving to a file and heading, every input from another module naming an output
  that module's contract has, and every format and check type one the validator implements. Not yet
  checked: that an evaluation contract's score keys equal its rubric's items — they differ on
  purpose until sub-issue 3 rewrites the rubrics (GATE:PLAN's `Tools`, Q10), and the check is added
  with that rewrite.
- A script that computes the applied acceptance criteria from the analysis report's table and the
  `[ac-decision]` entries (Q5) — written in #509 as `scripts/contracts/criteria-apply.sh`. It reads
  today's `- AC:` and `- Disposition:` lines and the two Q5 needs, `- Text: <text>` (revised,
  added) and `- Into: <id> — <text>` (split, one per criterion); sub-issue 3 adds the two to
  [decision-ledger.md](../../decision-ledger.md) > Decision-point entries.
- Removing the verification design's classification (Q8), in sub-issue 3: `Type`, `Kind` and the
  `standing` token in [units/design.md](../../units/design.md) > Output artifacts and Test
  necessity, ADR-0024 D1's closed list and its `Type`-cell declaration, the rubric items that read
  them ([evaluation-system.md](../../evaluation-system.md): AUDIT's test-first reads `Kind`,
  GATE:QUALITY's layer violation reads the token) and `scripts/gate/verification-layer-check.sh`.
- Replacing the tool checks by tool requests (Q10), in sub-issue 3: the verification design's
  `## Tools` and [units/design.md](../../units/design.md) > Tools, GATE:PLAN's `Tools` item,
  the per-cycle `preflight.local_checks[]` run and its stop, the Flow Control pause for a missing
  tool, and the PR body's place for the run's tool requests
  ([units/delivery.md](../../units/delivery.md) > Push and pull request).
- Removing `remedy_class` (Q11), in sub-issue 3: the evaluator's tagging rules
  ([evaluation-system.md](../../evaluation-system.md) > Remedy class), the FAIL routing table
  ([units/completion-evaluation.md](../../units/completion-evaluation.md) > FAIL routing) and
  `scripts/gate/remedy-route.sh`.
- The criterion review deciding its items (Q18), in sub-issue 3: [criterion-review.md](../../criterion-review.md)
  states the goal as every item disposed of with its grounds, its record carries `## Dispositions`
  in place of `## Proposed changes` and `## Open questions`, and the advisor is asked only for an
  item the review could not decide.
- Narrowing the evaluation output format (Q15), in sub-issue 3: `blocking_issues` leaves
  [evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format, and Recommendation
  triage ([units/completion-evaluation.md](../../units/completion-evaluation.md)) is worded without
  the `Low` / `Medium`+ split. The severity levels stay, and so does the procedure's rule that each
  finding states its severity (*ibid.* > Evaluator conduct): the contract stops checking the field,
  the evaluator still states it, and the AI acting on the finding reads it.
- Moving `fail_hypothesis` out of the output format (Q12), in sub-issue 3: the key leaves
  [evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format, and the search
  stays a [MUST] of *Evaluator conduct*, worded without the orchestrator's reject-and-re-spawn on
  an empty key.
- GATE:PLAN's rubric text, in sub-issue 3: `Tools` goes (Q10), and `Verification fit` and `Scope`
  are worded without the `Failure mode` column they read today
  ([evaluation-system.md](../../evaluation-system.md) > GATE:PLAN > Scoring, and the paragraph
  under it on the `Failure mode` cell; Q8).
- Rewriting the procedure documents as goals (Q16), in sub-issue 3: each rule a document keeps
  states what the work must achieve, not a form that must be present.
- An ADR that supersedes the decisions below.

## 9. Decisions this supersedes

| ADR | Decision | Why |
|---|---|---|
| [0025](../adr/0025-outcome-gated-functional-units.md) | D5 (the orchestrator sequences units, records scores, routes) | sequencing and routing move to the Coordinator |
| 0025 | D6 (the four gated state keys stay as unit exit gates) | the state file is removed |
| 0025 | D1 (a unit ends at a recorded gate) | work and gate split into separate modules |
| [0029](../adr/0029-attempt-records-under-one-record-root.md) | D4 (entry is a fact, printed by `cycle-status.sh`), D6 (the hook gates per checkout) | no entry evaluation, no state gates |
| [0036](../adr/0036-the-abbreviated-path-beside-the-full-cycle.md) | D6 (`cycle-status.sh` reports an attempt with no state file), D7 (which checks bind which path) | the paths become compositions |
| [0024](../adr/0024-two-layer-verification-and-target-owned-tests.md) | D1 (the closed `standing` list, declared in the `Type` cell) | the verification design carries no classification (Q8) |
| [0037](../adr/0037-autoflow-keeps-no-after-work-procedure.md) | D2's scope (the Coordinator owns what follows a merge or a close, "and of nothing else") | the Coordinator's scope widens to the whole lifecycle |

The list is the survey's reading; the ADR that supersedes them checks each against its text.

## 10. Tests affected

- `tests/plugin/verify-e2e-dummy-target.sh`: E2c pins the `cycle-status.sh` line and the state
  fixture; E3b pins push denied on an active state with empty scores.
- `tests/plugin/verify-installed-layout.sh`: R2 writes an active state fixture before asserting
  the policy denies.
- `tests/plugin/verify-skill-bodies.sh`: the generated command bodies follow every change to
  `docs/core.md` and the carried documents (`scripts/skills/gen-skill-bodies.sh`).

No test today exercises the score thresholds, the planning or implementation spawn gates,
`remedy_class` blocking, the remedy-sweep gate or the validator's enums.

## 11. Observations

- The hook's security rule reads the score key `security` or `보안` only
  (`hooks/check-autoflow-gate.sh:1305`), and GATE:PLAN's rubric item is named `Security`
  ([evaluation-system.md](../../evaluation-system.md) > GATE:PLAN > Scoring). A security score of 3
  or less therefore fails on the each-item ≥ 7 rule instead, with that rule's reason — the outcome
  is the same FAIL. It bears on Q2's reference values: `security_rework_at_or_below` is subsumed by
  `each_item_at_least` unless the Coordinator routes it differently.
- `reuse lint` run locally (`reuse[charset-normalizer]` through `uvx`) reports
  `scripts/resync-submodules.sh` as carrying no licensing information, though its second and third
  lines are the SPDX header; the contract files are counted compliant. Not investigated: the
  file is not touched by this work.

- **Tool requests left out when a module found a way round** (opensre#1 module run, 2026-10-25).
  criterion-trace and criterion-in-depth AC1 both judged whether Telegram accepts the truncated
  output by reading tdlib's `parse_html` (fetched with `gh api`) instead of sending through the Bot
  API. The trace recorded a tool request; the in-depth run recorded none, though its own notes say
  the stand-in checks tag structure only. The instruction said "a tool the work needed and did not
  have", which a module that found a stand-in reads as not needed. Being tried: the next runs'
  instructions mention the stand-in case in passing, and what the modules then record is observed
  before any document fixes a wording (the operator, 2026-10-25: "문구 보완과 같은 것은 룰처럼 강하게
  규정하는 방식은 지양하세요. 조금씩 개선해서 관찰하며 개선합니다").

- **The procedure documents bring the classification back** (opensre#1 module run, 2026-10-25).
  The design module's verification table met the contract — first column `Item`, a disposition
  per row, every applied criterion and scope item covered — and its other columns were today's
  `Type`, `Kind`, `Method`, `Failure mode`, `Reason`: the contract leaves those columns to the
  module, and the module took them from [units/design.md](../../units/design.md), its procedure.
  What Q8 removes from the contract comes back through the procedure until sub-issue 3 rewrites it.
- **Modules dispose of what they are given** (same run). The hypothesis evaluation recorded AC3's
  `&am` observation as a criterion defect (Low). With no hint in its instruction, the design
  module judged it non-discriminating rather than false — true before and after the fix — kept
  the criterion, and added inputs that split a reference to the verification; the Coordinator's
  own reading (revise AC3) was the weaker one.

- **A refusal a re-run cannot fix** (opensre#1 module run, 2026-10-25). The plan evaluation was
  refused: the evaluator scored the five items of today's GATE:PLAN rubric, `Tools` included, and
  the contract holds four (Q10). The evaluator's definition carries the rubric, so a re-run scores
  the same five; Q3's re-run does not reach a refusal whose cause is a procedure that disagrees with
  its contract. In the test the Coordinator recorded the refusal and its cause, read the scores
  (all ≥ 8 without `Tools`), and went on to build, whose inputs do not include the plan evaluation.
  Improvement items: the GATE:PLAN rubric loses `Tools` with the contract (sub-issue 3, §8), and
  how the Coordinator meets a refusal caused by such a disagreement is left open. Several of the
  ten Low recommendations read the formats Q8 and Q14 replaced (`Issue AC` for `Item`, `—` for a
  scope item, the `Kind` label) — the rubric text, like the procedure, brings them back.

- **A `git` output has no path to hand on** (same run). The audit, quality and delivery contracts
  take the build's `commits` as an input, and an invocation names inputs by path; the commits
  are recorded only as a range in the build's `result.json` (`outputs.commits`: branch, from, to).
  In the test the build's `result.json` was named as that input: it holds the range, and check-in's
  accepted-producer check reads it. How an input names a non-file output is left to settle.

- **A re-run cannot reach the previous run's working files** (same run). The build keeps its test
  scripts and run logs under its output directory (`local/`), which its contract does not declare
  as an output; the re-run, given the previous report and the audit's findings, recorded a tool
  request for the previous run's `local/` as an input. Its commit range is its own delta
  (`666c3c0a0 → f7c85e48e`), so an evaluation of the whole change needs every build run's range.
- **The re-score's dispositions checked** (same run). The audit re-score put all five items under
  `rescored`, gave the one previous finding the disposition `cleared`, and scored Input validation
  9 (was 6); the validator's `partition` and `covers` checks passed on it.

## Handoff log

| Session | Date | What was done | Next |
|---|---|---|---|
| 1 | 2026-10-23 | Surveyed `main` at `a2ff109`; created and pushed the branch; wrote this document; filed the epic #507 and its sub-issue 1, #508. Settled with the operator: Q1 withdrawn, Q2–Q5 settled (§6). Then, the operator away and proposals taken on the recommended option by the operator's instruction: the criterion review as four modules (§4), the contract format and invocation (§5), the drafts `docs/contracts/design.json` and `docs/contracts/plan.json`. The committed checks pass locally (the `run:` steps of `contract-suites.yml`, `plugin-package.yml`, `e2e-dummy-target.yml`). | Done after the row: #508 closed (its work committed on this branch directly, `d53ffa1`…`aba1d0f`, so it has no PR); sub-issue 2 filed as #509. | #509: branch off this branch, settle its four open points, then the contracts, the generator and checks, the validator and criteria-apply; PR into this branch. |
