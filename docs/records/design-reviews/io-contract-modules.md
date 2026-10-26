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
  invalid; it makes its outputs meet the declared format. It does not know what runs after it; what
  ran before it, a functional module knows from its inputs and the attempt's record directory
  (revised by the operator, 2026-10-25 — Q20; the statement first read "It does not know which run
  it is, what ran before it or what runs after it").
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
| **Keep** | state-independent policy denies: `gh pr merge`, push to the default branch (the base: no longer, Q22), `gh issue create`, ledger append-only and authority, explicit `model` on a spawn, backgrounded suite runs | `hooks/check-autoflow-gate.sh` Sections 0, 1, 1b, 1e |

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

*Revised by Q25 (2026-10-26)*: the grounds above name the Coordinator as the party that orders and
re-runs the stages; AutoFlow no longer describes that party, and the split stands on each stage's
fixed inputs and outputs.

The review decides the disposition of every item it finds (Q18). What follows the four — putting
to the advisor an item the review could not decide with confidence, recording the dispositions as
`[ac-decision]` entries, editing the issue body to them, and the `[criterion-ready]` entry (an `O`
entry the main session writes, *Confirmation*) — is the Coordinator's, being decisions and their
record (Q4). The issue-body edit
stays the Coordinator's and does not become a deterministic module (Q9).

*Revised by Q25–Q27 (2026-10-26)*: an item a module of the review cannot decide with confidence, that
module puts to the advisor and decides as the advisor decided (Q27); the dispositions that change a
criterion are recorded as `[ac-decision]` entries and the review's decisions as its
`[criterion-ready]` entry, under no writer's authority (Q26); the issue-body edit is not described
(Q25).

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
| `reads_records` | whether the module reads the attempt's record directory (Q20): `true` for a functional module that builds on earlier runs, `false` for a module that judges from its declared inputs only |
| `inputs` | inputs: name, `required`, and `from` — where such an input comes from: `{module, output}` (another module's output, whose form check-in checks against that output's contract, Q19 — a file by its path, a `git` output by its commit range; a list when it may come from more than one), `{ledger: [<marker>…]}` (a decision entry, Q4), `{path: target}` (a document of the target the Coordinator names), `{path: coordinator}` (a record of the Coordinator's, such as the recommendations it deferred), or `{results: tool_requests}` (the tool requests of the run's earlier results, §5.3) |
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
| `markdown` | `section` (a `## <heading>` with a non-empty body — `none` when there is nothing), `line` (a line matching a pattern; `once`: exactly one; `equals_param`: its first group is a param's value), `rank` (a line's first group is the highest level of an order among the table rows whose last cell is not an excluded value), `table` (a table by its first header cell or its whole header, under a heading, outside the `## Delta — round <n>` sections; `rows_disposed`: every row carries something after its first cell; `unique_first`; `covers`: every id a source names is a first cell) | the verification design's `Item` table covering the applied criteria and the feature design's `## Scope` items |
| `json` | `keys` (per key: `type`, `required` / `required_when`, `const`, `pattern`, `keys_exactly`, `items_keys`), `forbidden_keys`, `unique`, `partition` (a key set split into two lists), `covers` (every id a source names has an entry, with its disposition) | an evaluation's scores, re-score and recommendations |
| `git` | `git_range`: the branch gained commits since check-in, or, with `absent_reason`, a section of another output states why it gained none (Q19) | the build's commits |
| `pull-request` | `pr_open` (open, a draft), `pr_checks` (every check on the head green, or the body's marker line that no CI ran); `pr_body_covers` (the body states every id a source names) was removed on PR #512's review — free text has no form an id can be found by | the delivery's pull request |
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
    "records": "<the attempt's record directory>",
    "out": "<the attempt's record directory>/design-1"
  }
  ```

  An input from a `git` output names its commit range instead of a path:
  `"commits": { "branch": "<branch>", "from": "<commit>", "to": "<commit>" }` — from the first build
  run's start to the last one's end when the build ran more than once (Q19).

- **The module checks its inputs first**: `bash <autoflow-root>/scripts/contracts/contract.sh check-in
  <invocation.json>` — every declared param and required input given, and each input of the form
  the contract asks (Q19): a file present and, when another module produces it, passing the checks
  of that module's output that need nothing but the file — a check that compares it with the
  producer's own inputs (`covers`, a `when` on an input) was the producer's check-out's; a commit
  range whose commits exist, `from` an ancestor of `to` and `to` on the branch. Whether the run
  that produced an input was accepted is not checked: an output short of its format is refused
  where it is used. On a refusal it writes nothing but the result file and stops.
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
- **The output directory is the Coordinator's, inside the attempt's record directory** (Q20). Each
  run gets a new subdirectory named `<module>-<n>` — `<module>-<qualifier>-<n>` when one module runs
  on several items in a round, as criterion-in-depth on each criterion — `n` counting that module's
  runs from 1, so nothing is renamed or overwritten. A re-run names the previous outputs its contract
  takes as inputs; a module whose contract `reads_records` is also given the directory
  (`records`) and reads what earlier runs left there, their working files included. A module that
  does not is given no `records`. check-in checks the name, and that `out` lies in `records` when it
  is given.
- **What a re-run's output owes because it is a re-run is derived from its inputs**: the design's
  `## Delta — round <n>` takes `n` from the number of delta sections in the previous document it is
  given, plus one (`docs/contracts/design.json` > `rules`).
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
| Q4 | The ledger's standing | **Settled** (operator, 2026-10-23): the ledger holds only decisions — entries that settle what a module cannot settle itself (`[criterion-ready]`, `[ac-decision]`, `[checklist-decision]`, a design point), under their authority: `operator decision` and the main session's own decision in the `O` namespace, `advisor decision` in the `A` namespace ([decision-ledger.md](../../decision-ledger.md) > Entry identifier). In this model the main session that writes `O` is the Coordinator's. A module contract may name such an entry as an input ("the ledger decision with marker X"). What a module can produce itself is its own output file. The orchestrator's entries leave the ledger: the attempt records counted for the caps (`[gate-autofix]`, `[review-autofix]`), the cap-window reset (`[reentry-decision]`) and `[rebuttal]` are the Coordinator's records; the gate verdict entries ([decision-ledger.md](../../decision-ledger.md) > Entries, *Writers*) are replaced by the evaluation output files. The hook's append-only and authorship denies stay as they are and keep guarding these entries. *Revised by Q26 (2026-10-26)*: no writer is distinguished — the authority values, the `O` / `A` namespaces and the hook's authorship deny go; an entry is a decision and its grounds, replaced only by a later entry that names it, append-only; *by Q25*: the Coordinator's records are not described. The contradiction between [state-tracking.md](../../state-tracking.md) ("the ledger is not a gate input") and the REVIEW cap counted from `[review-autofix]` entries goes with both: the first document is removed, the count moves to the Coordinator. |
| Q5 | How an acceptance-criterion change is applied | **Settled** (operator, 2026-10-23): the applied criteria are an output of their own. A deterministic script computes them from the analysis report's first AC table and the `[ac-decision]` entries; every later module takes that output as its input. The request is already a module output (the design's `## Decision requests`, the build report, an evaluation recommendation — [units/design.md](../../units/design.md) > Report routing) and the decision a ledger entry (Q4); only the edit the orchestrator makes today to the analysis report's table ([units/analysis.md](../../units/analysis.md) > Re-entry) is replaced. It needs the `[ac-decision]` grammar ([decision-ledger.md](../../decision-ledger.md) > Decision-point entries, *Acceptance-criterion decisions*) to carry the criterion's new text for `revised`, `split` and `added` — today the entry has `- AC:`, `- Disposition:` and one Decision line, which a script cannot apply. Rejected: re-running analysis on the entries (a full analysis run for a table edit, and other content may move); each consuming module applying the entries itself (one application in five places). |
| Q6 | Where the contract validator lives | **Settled by the existing rule** (2026-10-24): `scripts/contracts/contract.sh`, run as `bash <autoflow-root>/scripts/contracts/contract.sh check-in\|check-out <invocation.json>`. `bin/` is the plugin's component that is on the Bash `PATH` of every session and subagent ([ADR-0027](../adr/0027-plugin-only-delivery.md) > Context, M1; D1); its two entries are the commands a context with no root declaration must still run — `autoflow-root` prints the root (D3), `autoflow-records` names every record path (`bin/autoflow-records`, header). The validator's callers, a module's command body and its agent definition, carry the root declaration (D3), so it is a file a role runs by path, under `scripts/`. It would belong in `bin/` only if the Coordinator ran it with no root declaration; in §5.3 the Coordinator reads `result.json` and does not run it. The name follows `scripts/`' `<noun>.sh <subcommand>` form (`criterion-ready.sh status`, `spawn-policy.sh model`). |
| Q7 | Who writes an evaluation module's output | **Settled by the existing rule** (2026-10-24): the session that runs the evaluation module, writing the report the evaluator returns verbatim. "The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores" ([role-contracts.md](../../role-contracts.md) > Evaluation AI), and the spawning side records it verbatim (`agents/autoflow-evaluator.md`, Hard rules). Only the place changes: the state file's `scores` become `<out>/evaluation.json`. Giving the evaluator a Write tool would change that rule with no defect observed under it. This also names the writer §7 item 9 found missing for `issue-{N}-audit.md`. |
| Q8 | The verification design's table | **Settled** (operator, 2026-10-24): the classification is removed — `Type`, `Kind`, the per-column rules of `Reason` and `Failure mode`, and the `standing` token; what the table owes is a disposition for every applied criterion (§5.2, *No rule checks a classification*). The table is found by its header row's first cell (`Item`, Q14), outside every `## Delta — round <n>` section: a re-run appends a delta and leaves the first run's text as it stands ([units/design.md](../../units/design.md) > Re-entry), so no heading is fixed for it — issue #500's verification design carries two tables with the same header row, the second inside `## Delta — round 2`. The other columns are the module's. Removing the classification from the documents, rubrics and scripts that carry it is sub-issue 3's (§8, §9). |
| Q9 | Whether the issue-body edit becomes a deterministic module | **Settled** (operator, 2026-10-24): no. The edit stays the Coordinator's, as the review session's today ([criterion-review.md](../../criterion-review.md) > Authority, "the session edits the issue body to match"). A module, or a re-read of the edited body against the decisions, would guard against an edit that departs from the decisions; no such defect is on record (issue search "issue body": #467, #466, #305, none of them this), so neither is added. |
| Q10 | Tools | **Settled** (operator, 2026-10-24): a module uses the tools its work needs; when one is missing it finds what can be done without it, finishes the run, and records the missing tool as a request in its result and report, which the PR body states for the operator (§5.3). The verification design's `## Tools` section and its availability list go (`docs/contracts/design.json`), and with it GATE:PLAN's `Tools` item ([evaluation-system.md](../../evaluation-system.md) > GATE:PLAN > Scoring; `docs/contracts/plan.json`), removed by the operator on its own ground: it scored the form of the declaration — each tool, its availability and its ground, and a reason owed only by a row verified by a person or on a mock — not whether a tool fits the criterion, so declaring a tool scored safer than not; whether the verification, its tool included, fits the criterion is `Verification fit`'s. No run checks the tools: today's per-cycle `preflight.local_checks[]`, which stops the cycle on a failed check ([units/preparation.md](../../units/preparation.md) > Target-declared local checks), and the pause for a missing tool ([core.md](../../core.md) > Flow Control, "tool or referenced material → user") go in sub-issue 3. Withdrawn on the way: a module stopping on a missing tool with a `blocked` result, and AutoFlow naming one place for a project's tool declarations — the operator decides from the PR what to do about a missing tool. |
| Q11 | `remedy_class` | **Settled** (operator, 2026-10-24): no contract carries it. Today the evaluator tags each failed item, and each `Medium`+ recommendation, with one of `doc`, `test`, `impl`, `design` or `operator`, and `scripts/gate/remedy-route.sh` routes the re-entry from the tags ([units/completion-evaluation.md](../../units/completion-evaluation.md) > FAIL routing; [evaluation-system.md](../../evaluation-system.md) > Remedy class). A fix can be large or small, and where it is made cannot be fixed in advance: the AI acting on a finding judges at which stage it is made, and asks the advisor when it cannot. A contract states the least it can: it names no class and no destination, and the one way out of an uncertain judgment is to ask the advisor. This narrows Q2: the evaluation outputs scores and grounds, and no `remedy_class`. A fix no module owns — today's `doc` route, the orchestrator's own doc commit — needs no module either: the coordinating session runs it as a one-off session or judges it itself. *Revised by Q27 (2026-10-26)*: asking the advisor is the module spawning it and following its decision; *by Q25*: who makes a fix no module owns is not described. |
| Q12 | `fail_hypothesis` | **Settled** (operator, 2026-10-24): not an output contract's. It records the evaluator's pre-scoring search for the strongest FAIL case — the rule that, when everything reads as right, the opposite case is looked for first ([evaluation-system.md](../../evaluation-system.md) > Evaluator conduct > *Pre-scoring FAIL hypothesis*). That is the evaluation procedure, a rule of the rubric's evaluation, and stays binding there; as output, "nothing reads it programmatically and no gate consumes it" (*ibid.* > Evaluation Output Format). The plan contract drops the key and its `disposition` list. |
| Q13 | `rerun_reason` | **Settled** (operator, 2026-10-24): removed from the design contract, with its six values and the rule tying it to a previous document. Nothing reads it or branches on it: today it is the text in a delta heading's parentheses ([units/design.md](../../units/design.md) > Re-entry, the only place the list appears), and what a re-run works from reaches it as inputs of its own — the previous documents, the plan evaluation, the build's blocker, the failed items. A re-run is known by a previous document being given; the delta heading keeps `## Delta — round <n>`, which the table's locate reads (Q8). |
| Q14 | What a contract checks | **Settled** (operator, 2026-10-24): a module is input, the work it does, and output; its contract checks the inputs and that the output disposes of every item the work owes. Acceptance criteria are the required behaviour; an item the design adds or changes, once decided, is owed the same way. So the coverage check spans both: every applied criterion and every item the feature design's `## Scope` includes has a row with its disposition, the included items carrying an id the table names — today they are `—` rows that no check pairs with the `## Scope` section, though [units/design.md](../../units/design.md) > Output artifacts owes each a row. The verification design's risk line ([units/design.md](../../units/design.md) > Verification depth) and the feature design's `[DENY]` on content the build derives (*ibid.* > Output artifacts) are how the work is done, so they leave the contract and stay in the procedure, as `fail_hypothesis` did (Q12). |
| Q15 | The plan and design contracts' remaining rules | **Applied by Q11, Q12 and Q14** (2026-10-24; the operator asked that what the principles settle be applied, and only the rest be asked). `blocking_issues` goes: no reader is named for it, and its cap of three ([evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format, `"items ≤ 3"`) cut a list the rule "surface every issue found" (*ibid.* > Evaluator conduct) wants whole; each item's score and reason carries what blocks. A recommendation's `severity` leaves the contract's checks with `remedy_class` (Q11) — the levels and the procedure's rule that every finding states one stay: today it splits triage into the orchestrator's own judgment on `Low` and a class-routed attempt on `Medium`+ ([units/completion-evaluation.md](../../units/completion-evaluation.md) > Recommendation triage), and with routing the acting AI's judgment, nothing branches on it. The re-score keeps what it owes (Q14) — every rubric item scored afresh or inherited, and every prior finding dispositioned — and which items it scores afresh is the procedure's (Q12). The design's "never applies an acceptance-criterion change" goes: the applied criteria are criteria-apply's output and the design's input (Q5), so a change can only be requested. |
| Q16 | How a procedure is written | **Settled** (operator, 2026-10-24): a procedure gives the AI the goal of its work, and the AI judges how to meet it — for a review, "state the severity of every finding". It does not prescribe a form that must be present and then check that it is: that turns the work into a fixed procedure carried out mechanically instead of judged toward a goal. The contract checks inputs and dispositions (Q14); the procedure documents sub-issue 3 rewrites state goals. |
| Q17 | The contracts' format | **Settled** (operator, 2026-10-24): JSON, read with `jq`; this replaces §5.1's "authored in YAML, read as JSON" as accepted on 2026-10-23. Where the reader is a shell script with `jq` the usual practice is one JSON source; a YAML source with generated JSON is the less common case, for files people write at length and must comment, and it keeps two sources in step. Every file this repository's devices read is already JSON (§5.1). `yq` is not a runtime prerequisite (README > Prerequisites), is installed on its own where it is present (`/opt/homebrew/bin/yq` here, while `jq` is the system's `/usr/bin/jq`), and two different tools carry the name (`mikefarah/yq`, `kislyuk/yq`). The generator and its equality check leave #509's scope. |
| Q18 | What the criterion review returns | **Settled** (operator, 2026-10-25): every item the review finds, disposed of by the review itself, with its grounds — the work any issue analysis does: no criteria, so they are established; a criterion wrong, so it is revised; one missing, so it is added; a problem found beside them, so it is included in this issue or separated from it. The first run of criterion-screen on opensre#1 returned two revisions and three "open questions" ([criterion-review.md](../../criterion-review.md) > Review record, `## Open questions`, put to the advisor): which `<…>` are tags (a criterion the issue lacks), whether the gateway path is in scope (the body states it wrongly), and whether a raw `&` that drops text is (a problem found beside the criteria). Each is one of the dispositions above, so the review decides it. The criterion-screen and criterion-reconcile contracts require one `## Dispositions` table, an item and its disposition per row, in place of `## Proposed changes` and `## Open questions`; an item the module cannot decide with confidence says so and states the question for the advisor — the one way out (Q11), not a second list. *Revised by Q27 (2026-10-26)*: an item the module cannot decide with confidence it puts to the advisor and decides as the advisor decided; its row names the ledger entry. |
| Q19 | What check-in checks of an input, and the build's commits | **Settled** (operator, 2026-10-25): a module runs when its inputs are of the form its contract asks and does not run when they are not; making its outputs meet their format is the module's own rule, which check-out confirms. So check-in checks each input's form, and not where it came from: the rule that an input must come from a run whose result was accepted (§5.3 as written in #509) goes — an output short of its format is refused where it is used, by the same checks. The build's output is its commits, and an input from it is the commit range, checked for commits that exist; the opensre#1 run had named the build's `result.json` in its place (§11, *A `git` output has no path to hand on*). A build run that makes no commit is not refused for it: its report says why in a `## No commit` section (`absent_reason` on the `git_range` check). Checking that a range is the one the build produced is the Coordinator's, which reads the build's `result.json` to compose the next invocation. |
| Q20 | Earlier runs, and the record directory | **Settled** (operator, 2026-10-25): a module is one work session given a place to run, and the attempt's runs are connected work on one branch. A re-run comes after a result that fell short, and a run that cannot see how the previous one worked cannot improve on it: in the opensre#1 run the second build rebuilt the first build's td parser port and tests, which lay in the first build's output directory, undeclared and outside its instruction's reach (§11, *A re-run cannot reach the previous run's working files*). Keeping a run from earlier results serves only to keep a worker from judging its own work, and judging is a separate run. So the attempt has one record directory, each run a subdirectory named by a simple rule (§5.3), and a functional module reads the directory (`reads_records: true`). A module that judges keeps to its declared inputs (`reads_records: false`), so an earlier verdict does not lead it: the four evaluation modules, criterion-in-depth — whose analysis "never saw the review's earlier verdicts" (`agents/autoflow-criterion-analyzer.md`, description) — and criteria-apply, a script. §1's "does not know what ran before it" is revised to match. The review contract's `records` input — the four design artifacts, which the review run copied into a directory for the `claude` reviewer's `--records` (§11) — goes: the reviewer is given the record directory itself. |
| Q21 | Where PREFLIGHT's work goes | **Settled** (operator, 2026-10-26): no preparation module; the attempt is the Coordinator's worktree, branch and record directory. The coordinating session already builds a worktree per run from the base's latest commit and keeps a record directory per run, and the 27 module runs on opensre#1 ran on a branch and a record directory the Coordinator named (`test/io-contract-509-issue-1`, `~/.autoflow/io509-test/opensre-1/`) with no attempt made by `autoflow-records new`. So `autoflow-records new`, `claim`, `base` and `dir`, the `dev-<stamp>-issue-<N>` name, the record directory's `checkout` and `completed` files, one active attempt per checkout, `cleanup-issue.sh`, the git clean check and the start sync go; `root` and `drafts` stay. The cycle-layer store becomes each run's `<out>/local/` (Q20). The ledger keeps the name `issue-<N>-ledger.md`, which the hook's ledger check matches — on opensre#1 the ledger was `ledger.md`, so the check never ran. `target-check.sh` and `check-review-backend.sh` stay as checks the Coordinator runs when it builds the environment (§5.3), a condition of no module. |
| Q22 | Which push denies stay | **Settled** (operator, 2026-10-26): the push restrictions go, and the push to the default branch stays denied as part of the merge prohibition. A push to the default branch is a merge that skips the pull request and its review, and no remote device stops it on the targets in use: `gh api repos/<owner>/<repo>/branches/main/protection` answers "Branch not protected" for `Munsik-Park/autoflow` and `Munsik-Park/opensre`, and protection is not available on `connev-llm/llmroute`'s plan. The base-branch push deny (#490 AC4) goes with the dev-branch test it rests on (`hooks/check-autoflow-gate.sh`, `DEV_SESSION`) and the `gh-merge-base` that only `autoflow-records new` set. |
| Q23 | The run metrics | **Settled** (operator, 2026-10-26): `scripts/metrics/` finds an attempt by its state file only; it stays for the records made before this change and is documented so. Measuring module runs, whose `result.json` the Coordinator holds, is the Coordinator's. |
| Q24 | `docs/security-checklist.md` | **Settled** (operator, 2026-10-26): its first section names the hook's state validation and score computation, which go (Q22, §3). The file is "Maintainer: Human (never auto-edited)"; the change is drafted and the operator accepts its text before it is applied. |
| Q25 | Whether AutoFlow describes the party that runs the modules | **Settled** (operator, 2026-10-26): no. AutoFlow is composable modules: its documents, agent definitions and devices state each module's inputs, its work and its outputs, and a module takes what it needs as an input without naming who gives it. A verdict, a re-run, an order of modules, a cap and the application of the reference values are not written; an evaluation outputs its scores, their grounds and the reference values. What follows a merge or a close is outside AutoFlow, in one line (`docs/git-workflow.md` > Post-Merge Cleanup). The Coordinator — ADR-0037 D2's role, widened by the first draft of ADR-0038 D2 — leaves the documents, the agent definitions, the contracts' notes and the scripts' headers and messages; `target-check.sh` and `check-review-backend.sh` are scripts for setting up the environment; the README's lifecycle figure, which drew one order of phases, goes (ADR-0038 D2). §1, §5 and §8 name the Coordinator as this review read it before Q25, and keep their text. |
| Q26 | Whether the ledger distinguishes its writers | **Settled** (operator, 2026-10-26): no. One worker writes the ledger, and the writer's name changes with the environment; a rule about the writer asks for text the work does not need, and then for a check of that text. An entry is a decision and its grounds; a decision changes by a new entry that names the one it replaces (`- Supersedes:`); standing entries whose conclusions disagree, with neither naming the other, are a conflict and neither is applied; the ledger is append-only. The `- Authority:` values (`orchestrator decision`, `advisor decision`, `operator decision`) and the rules that require them, the operator override (`- Overrides:`, "an operator entry wins") and the writer namespaces go: an identifier is `A<n>` (`ledger-entry-id.sh next <ledger>`), and an earlier ledger's `O`, `E` and `F` identifiers are read as they are. The hook keeps the append-only check alone; `criterion-ready.sh` and `security-checklist.sh` drop their writer checks (ADR-0038 D8). `criteria-apply.sh` is aligned on #509's branch. |
| Q27 | Decisions within a module | **Settled** (operator, 2026-10-26): the working AI decides what it can decide. The decisions AutoFlow puts to the advisor — an acceptance-criterion change, a cause or lever that is not code, a hypothesis PASS judged unreachable, a design point not agreed, a finding whose fix cannot be placed with confidence, an item the criterion review could not decide, every security-checklist change — and any other point it doubts, the module puts to a fresh `autoflow-advisor` it spawns and follows the decision, which the advisor records with its grounds in the ledger of the record directory the invocation names; the module's output names each decision it followed. A module cannot put a question to the party that runs it, nor know who reads its output, and "write the question" makes the AI keep asking; the run goes on unless the harness blocks a call. The design's `## Decision requests` becomes `## Advisor decisions` (`docs/contracts/design.json`); the build report adds `## Advisor decisions`; the criterion review's row names the advisor's entry; Claude Code's advisor tool is not enabled (ADR-0038 D11). |
| Q28 | Who writes an evaluation module's output, revisited | **Settled** (operator, 2026-10-26, on the opensre#1 module run, §11 *An evaluator's report copied by hand*): the evaluator writes `<out>/evaluation.json` itself, keeps what it builds to check a finding under `<out>/local/`, and returns the file's path with a one-line summary; the session copies nothing. Q7 rested on the evaluator holding no Write tool; it holds Bash and wrote its probes into the session's scratchpad, and five sessions retyped 10–20 KB reports whose copy check-out cannot tell from the original. The evaluator writes only into its own output directory, so it scores a work it never changes. An evaluation module is given the paths of its declared inputs and no record directory; nothing stops it opening a file an input cites, and nothing in its prompt points it there. |
| Q29 | What a contract checks of an output's form | **Settled** (operator, 2026-10-26): a check stays where a script reads the output (the analysis report's acceptance-criteria table, criteria-apply's JSON), where it confirms the work disposed of every item it owes by id (Q14) — the id named, not where or how —, and where it confirms a fact (a commit, an open pull request, a posted comment, an evaluation's score keys and the absence of a verdict). A heading that must be present, a table's shape or cell, a line's pattern and a sentence that must appear verbatim go: the reader is an AI that finds what it needs however it is written, and a fixed form refused review-2 for grounds written beside `rejected` in the disposition cell. The procedures state what the output must hold, not its form; a contract's `evaluation` lines and notes say the same. New checks: `mentions` (each id a source names appears in the document) and `covers` with `count_only` (as many dispositions as the previous evaluation had findings). |
| Q30 | What one advisor decides | **Settled** (operator, 2026-10-26, on the opensre#1 run, §11 *One advisor, several decisions*): decisions that depend on each other's answers go to one advisor in one request, and a decision that stands apart to an advisor of its own; each decision is still its own ledger entry, so one can be superseded alone; the advisor answers what the request asks and names, for the module to request apart, any further decision it finds needed. The run's A4–A5 and A6–A8 were decisions of that kind — AC1 and AC3 read the classification AC2 decides —, while AC3's A2 → A3 → A7, one case at a time, and A2's change to an observation it was not asked about are what the grouping and the scoped answer address. The procedure states this as its goal (Q29). |

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
- Q19: "결과물 출력은 커밋으로 하고 입력도 커밋이 있는지 체크하면 될 것 같네요". On the module's conditions: "autoflow 는 입력 형식이 맞으면 실행한다 이고 입력이 맞지 않으면 실행되지 않는다는 조건 뿐이죠? 그리고 출력 형식에 맞게 출력해야 한다는 내부 실행 규칙이 있고요". Then: "통과한 실행에서 나왔는지 -> 볼 필요가 없어요 만약 출력 형식이 커밋을 요구한다면 잇어야 하고 없으면 없는 왜 없는지 처분 사유를 적으면 되요 검사기는 바꾸어야 하겠네요"
- Q20: "공통 기록 폴더가 있고 자신의 사이클 build-c1 build-c2 뭐 어떤 식이든 구별할수 있도록 간단한 규칙만 주면 이전 사이클도 다 알수 있지 않느냐 하는거에요". Then: "이전 결과물을 보지 말라는 것은 작업자가 평가를 하게 될때 자기 평가를 막는 목적외에는 보이지 않아요 지금은 평가는 독립 실행을 하니 그 문제도 없구요". On §1's statement: "고쳐야죠".
- Q10: "도구가 필요하면 쓴다. 없으면 요구해라. 반드시 기록해서 운영자한테 요구해라. 그리고 도구가 없더라도 할 수 있는 것을 방법을 찾아서 수행은 끝낸다." And: "매 사이트마다 검사하는 건 없앱니다." On GATE:PLAN's `Tools` item: "뺍니다."
- Q21: "워크트리로 작업이 변경됩니다.  브랜치 커밋 베이스 작업이 가능하음로 많은 것들이 간소화됩니다" (with the coordination runbook to be read).
- Q22: "브랜치의 푸시는 막을 사유가 줄었어요. 머지는 여전히 운영자 권한이고 푸시는 현재가지 운영상 보면 제한을 제거하도록 합니다 / 혹시 문제가 있나요?" Then, on the recommendation to keep the default branch denied: "수용".
- Q23: "수용". Q24: "권고 수용".
- Q25: "autoflow 에서 Coordinator를 볼수가 없습니다 autoflow 는 조립 가능한 모듈이에요 Coordinator 가 어떤 형태로 구성되어 동작하는지 기술하는 것이 가능한가요?"
- Q26: "결정을 뒤집는 것은 누구만 가능하다 -> 작업자는 혼자인데 그런 룰이 있죠 -> 이미 작업 룰이 있는데 검사가 필요해졌어요 -> 변경을 하려고 하니 충돌이 생겼어요 더군다나 그런 제한은 AI 에게 작업의 가이드가 되요 그 안에서만 결정을 하죠 그런데 정말 그 제한이 필요한가요?" Then: "orchestrator coordinator 역할 구분이 갈라지는 부분이 어디죠? 단어가 틀리고 환경이 바뀌었는데 그 문서를 작성하는 사람을 제한하는데 실제 그 제한이 필요하거나 구분할 필요가 있지 않아요 결국 불필요한 기술을 요구하니 검사가 생겨요"
- Q27: "조율 세션은 모듈 내부에서 작업 AI 가 결정하지 못하는 사항이나 의구심이 드는 문제를 advisor 호출하는 곳이 있어요 그리고 Coordinator에게 질문할 방법이 없어요 Coordinator 인지 운영자가 보고 잇는지 모릅니다 모듈이 질문을 적는다 라고 하면 의구심이 있을때 질문을 합니다 작업 AI 가 결정할수 잇는 문제는 결정 모를때는 advisor 결정 수용이 기본이에요 하네스가 막히는 수준이 아니면 진행입니다 질문을 적는다라고 적으면 계속 질문을 하게 됩니다" Then: "질문하지 않습니다 x -> 부정형 기술을 불필요하고 제한할 이유도 없음 작업 AI 가 결정 -> 정해진 일부 항목은 autoflow-advisor 가 호출해야 하는 룰이 있어요 클로드의 advisor 는 비활성이에요"
- Q28: "out 위치의 파일들인 산출물을 … 경로만 주는 대신 옮겨 적고 하지 않도록 파일로 쓰고 경로를 주면 되는 거죠?" With: "별도로 막지는 않지만 참조할수 있는 힌트나 문구를 주지 않습니다".
- Q29: "이런 부분이 형식을 룰로 강제하고 사소한 변경에도 불일치가 나는 문제입니다 … 해야할 사항을 제시하고 형식을 굳이 정하지 않아도 읽는 AI 는 해석이 가능한데 적는 방법을 강제하고 그곳에 있어야 한다는 룰을 제시하니 그것에 맞지 않는 케이스는 안되는 거에요". On the review aggregation's four goals: "간결하고 좋네요 이런 형식으로 개선하며 문제점이 보이면 문구를 개선합니다"; on the rest: "좋습니다 적용하죠".
- Q30: on the four ways weighed (one decision each; the whole list with the item named; grouping the dependent ones; a rule decided first, a consistency read last): "권고로 가 봅시다" — grouping the dependent decisions, each recorded apart, the answer kept to what was asked.

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
  (`scripts/contracts/markdown.jq`); its input check follows Q19 (an input's form, a commit range
  for the build's commits) and its run-directory check Q20.
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
  ([units/completion-evaluation.md](../../units/completion-evaluation.md) > FAIL routing),
  `scripts/gate/remedy-route.sh`, and the aggregator's tagging of every Medium+ finding
  ([units/review.md](../../units/review.md) > Review aggregation) with the findings-file check
  that refuses a Medium+ row without the tag (`scripts/handoff/review-gate.sh:162`).
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
- The module commands, in sub-issue 3: a functional module's command names the attempt's record
  directory as the place earlier runs left their work (Q20), and every module's command names where
  the model of a spawn it makes is read — `spawn-policy.sh model <phase-key>`
  ([core.md](../../core.md) > Spawn Model), which a module that carries only its procedure does not
  know (§11, *The model of a spawn the module makes*).
- Applied in sub-issue 3 from the principles above (2026-10-26, on the survey of every document,
  device and test that reads the state file or `remedy_class`; the survey's tables are one-shot,
  keyed to `c2c9b5e`, outside the repository):
  - the undeclared-spawn and teammate-`name` denies and the role-to-gate mapping go with the gates:
    only the gates read them, and made state-independent they would refuse ordinary spawns in every
    session the plugin is installed in; the ledger's authorship check reads `subagent_type` itself;
  - a referenced material that cannot be opened, and a lint chain that cannot run, are tool requests
    and the run ends (Q10), in place of the stop before leaving DIAGNOSE;
  - the test-first rule is stated as its goal, without the `Kind` it reads today (Q8, Q16);
  - the findings file's form checks in `review-gate.sh` move to the review contract's check-out (Q14,
    Q19);
  - the delivery contract's check on the deferred recommendations asks a disposition for each — an
    issue that takes it, or the gap stated — in place of the finding's text verbatim (Q14; the
    operator, 2026-10-25: a known gap worth fixing becomes an issue; §11, *Known gaps stated verbatim
    grow the PR body*);
  - [units/review.md](../../units/review.md) > *A repeated complaint* covers an evaluation's
    recommendations as well as a reviewer's findings (§11, *A gate that names one case after
    another*);
  - the counted retries inside a module (delivery's "max 2"), the model tier revert after a
    contradicted PASS and putting a question to the advisor are the Coordinator's (Q2, Q3, §4);
  - the ledger's PREFLIGHT records leave it, and an entry's heading names no cycle or phase (Q4);
  - `/autoflow:cycle`, `/autoflow:criterion-review` and [abbreviated-path.md](../../abbreviated-path.md)
    go with the unit commands (§4);
  - the rules [state-tracking.md](../../state-tracking.md) carries that stay — the policy denies, the
    record location, the hook with no `jq` — move to the documents that keep them.
- An ADR that supersedes the decisions below: [ADR-0038](../adr/0038-contract-modules-with-no-state-file.md),
  proposed 2026-10-26.

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
Checked in ADR-0038 > *Relation to other decisions*, which adds what this list missed: ADR-0025 D8
and the cap, loop and `remedy_class: operator` parts of D2–D4 and D7; ADR-0029 D2, D3, D5 and D8;
ADR-0030 D2, D3, D5–D7 and D9; ADR-0032 D1, D2 and D5; ADR-0033 D1–D2; all of ADR-0036; ADR-0037
K1's base clause, K2–K4, K6 and D3; ADR-0024 D4's class-routed re-entry; ADR-0034's start point
and base.

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
  *Settled by Q19*: the input is the commit range, and check-in checks that its commits exist.

- **A re-run cannot reach the previous run's working files** (same run). The build keeps its test
  scripts and run logs under its output directory (`local/`), which its contract does not declare
  as an output; the re-run, given the previous report and the audit's findings, recorded a tool
  request for the previous run's `local/` as an input. Its commit range is its own delta
  (`666c3c0a0 → f7c85e48e`), so an evaluation of the whole change needs every build run's range.
  *Settled by Q19 and Q20*: a functional module reads the attempt's record directory, and the range
  an evaluation takes runs from the first build run's start to the last one's end.
- **The re-score's dispositions checked** (same run). The audit re-score put all five items under
  `rescored`, gave the one previous finding the disposition `cleared`, and scored Input validation
  9 (was 6); the validator's `partition` and `covers` checks passed on it.

- **The review module, run after delivery** (opensre#1 module run, 2026-10-25, session 3). Accepted
  on its first run: `claude` and `codex` reviewed PR #25, the aggregation wrote the findings file
  and posted the round's comment, and the `pr_comment_posted` check passed — its first real run.
- **The review procedure brings `remedy_class` back** (same run). The findings file carries a
  `remedy_class` column and tags the Medium row `design`, as
  [units/review.md](../../units/review.md) > Review aggregation requires; the contract does not
  check the field (Q11), so the run was accepted. The same path as the design module's
  classification above; §8's Q11 item now names the review procedure and `review-gate.sh`.
- **A tool that takes a directory, given a set of files** (same run). The `claude` reviewer reads
  the attempt's records through `--records <dir>` (`scripts/review/claude-review-pr.sh`); the
  invocation names four record files. The module copied them into a scratchpad directory, passed
  that, and recorded a tool request. Of a kind with *A `git` output has no path to hand on*: how a
  module hands its inputs to a script whose interface predates the contracts. *Settled by Q20*: the
  directory the script takes is the attempt's record directory, which the review module is given.
- **The model of a spawn the module makes** (same run). The aggregation is a spawn, and the hook
  refuses a spawn without an explicit `model` ([core.md](../../core.md) > Spawn Model). The
  procedure says "on the model the policy names for `handoff-review-triage`" but not where the
  policy is read (`spawn-policy.sh model <phase-key>`, core.md > Spawn Model), and the module does
  not carry the core. After the refusal it searched the disk from `/` — macOS asked, on cmux's
  behalf, for access to other apps' data, not granted — then found
  `.claude/autoflow/spawn-policy.json` and spawned on `sonnet`. No contract names the model of the
  spawns a module makes, nor where the module reads it. Not a decision: the policy exists, and the
  module command names where it is read (§8, the module commands, in sub-issue 3).
- **A deferred recommendation raised again, with a measurement** (same run). audit-2's Low
  Confidence recommendation — the truncation reads the tags of the whole uncut input — was deferred
  by the Coordinator (`deferred.json`). Both reviewers raised it; the aggregation measured it
  (`"<b>x</b>" * 1_000_000`, `max_len=4096`: 1.63 s and 366 MB at `f7c85e48e`, 0.0015 s and
  0.02 MB at the base) and kept it at Medium. It rejected a Low Confidence finding with the parser
  source as grounds (td `decode_html_entity`, `end_pos - pos >= 10`).

- **A second round, re-entered from the review** (opensre#1 module run, round 2, 2026-10-25, on
  the Q19/Q20 validator). review-1's Medium moves design D1, so the Coordinator re-entered from
  design: design-2, plan-2, design-3, plan-3, build-3, audit-3, quality-2, delivery-2, review-2,
  on the same branch and PR #25. Eight were accepted; review-2 was refused by a validator defect
  (below). The operator kept PR #25 open across the round: the fork is neither merged nor synced.
- **Earlier runs read from the record directory** (same run; Q20). build-3 found build-2's td
  parser port, the td sources and the T0–T4 tests in `build-2/local/` and copied them unchanged,
  recording their sha256 — the second build of round 1 had rebuilt the same assets (*A re-run
  cannot reach the previous run's working files*). design-2 read the reviewers' own records and
  build-2's scope judgment that the finding overturned.
- **The commits as one range** (same run; Q19). audit-3, quality-2 and delivery-2 took
  `0c56f8823..f45ead6c0` — build-1's start to build-3's end — and check-in found the commits on the
  branch; the Coordinator composed the range from the build runs' `result.json`.
- **The spawn model, once named** (same run). review-2's instruction named
  `spawn-policy.sh model handoff-review-triage`, and the aggregation was spawned on `sonnet` at the
  first try, with no search of the disk (*The model of a spawn the module makes*).
- **A gate that names one case after another** (same run). plan-2 recorded a Medium: the time half
  of S2's bound had no verification that can fail. design-3 added two CPU-time checks, T7 and T8;
  plan-3 re-scored, gave the Medium "remains, narrowed" and recorded a new Medium for one more
  input shape T8 does not reach (the whitespace skip after `=`). The same property with a new
  witness each round is the loop [units/review.md](../../units/review.md) > *A repeated complaint*
  describes for reviews; here it came from a gate, and the design already bounds every search by
  its rule. The operator left it a known gap and sent the work on to build. plan-2 was not refused
  this time: its instruction gave the evaluator the contract's keys, where round 1's named the
  Evaluation Output Format and the rubric brought `Tools` back (*A refusal a re-run cannot fix*).
- **`pr_comment_posted` matched only the first comment** (same run). review-2 posted its comment,
  and check-out refused the run as "not posted". The check split the output of
  `gh api … --jq '.[].body + "\u0000"'` on NUL, and gh ends each value with a newline, so every
  comment after the first was compared with a leading newline; review-1's was the PR's first
  comment, so it passed. Fixed (`8aee794`): the bodies are read as one JSON array and compared with
  the file, whitespace at either end aside. The one-shot test's stub `gh` printed no such newline
  and now prints pages as `gh api --paginate` does. The run directory, re-checked on a copy with
  the fixed validator, is accepted; the record keeps the run's own result, refused.
- **Known gaps stated verbatim grow the PR body** (same run). delivery's `pr_body_covers` on the
  deferred recommendations checks that the body contains each finding's text
  (`docs/contracts/delivery.json`, ids `.[].finding`). With eleven deferred findings, each a
  paragraph with its measurements, PR #25's body reached 26,162 characters. The Coordinator also
  removed duplicates by hand: two of audit-3's Lows restated what quality-2 recorded. How the body
  states a known gap — the finding whole, a summary, or a reference to the evaluation — is left to
  settle.
- **The module commands, run module by module** (opensre#1, transition branch at `c673c52`/`5819d61`,
  2026-10-26, session 6; run record `~/.autoflow/coordination/opensre-1-2026-10-26-123404-832d5eb5/`,
  records `~/.autoflow/io-transition-test/opensre-1-2026-10-26-123404-832d5eb5/`). Twenty runs, each
  in a session of its own started as `/autoflow:<module> <invocation.json>` with the transition
  worktree as `--plugin-dir`: the criterion review's four (in-depth once per criterion), analysis,
  criteria-apply, hypothesis, design, plan, a design re-run on plan-1's Medium with criteria-apply and
  plan again, build, audit, quality, delivery (draft PR Munsik-Park/opensre#27) and review. Seventeen
  accepted. Advisor decisions A1–A8, A3–A5 from inside the reconciler's spawn and A6–A8 from inside
  the design unit's: a subagent's advisor spawn works (the open point d of session 4).
- **`tool-requests.json` was stated only in the validator's header** (same run). criterion-in-depth
  for AC1 was refused for its absence. The core's *Tools* and every command body now say every run
  writes it, `[]` when it lacked nothing (`c673c52`); the later runs wrote it.
- **"Its target file alone"** (same run). Two in-depth runs read the command body's "given the
  criterion's target file alone" as forbidding the checkout's path; the body now says it is given the
  target file and nothing of the review's verdicts, and reads the code in the checkout (`5819d61`).
- **An evaluator's report copied by hand** (same run; Q7). The evaluator returns its report and the
  session writes it to `<out>/evaluation.json`; the hand-back arrives indented, so each evaluation
  session retyped 10–20 KB of JSON, and check-out checks its form, not that it is the report
  returned. The evaluators also wrote probe scripts with Bash into the session's scratchpad and cited
  them as grounds, a place outside the record directory that no later reader can open.
- **One advisor, several decisions** (same run). One advisor spawn decided A4 and A5 on one answer
  file, and another A6–A8; role-contracts' "one fresh advisor per decision" does not say whether
  decisions that depend on each other are one decision.
- **The criteria change while the design runs** (same run). design-2's advisor decisions A6–A8
  changed the criteria the run had taken from criteria-apply-1; criteria-apply ran again before the
  plan re-score. Nothing in the design contract says its output follows criteria other than its input.
- **`## Advisor decisions` on a re-run** (same run). The design's re-run appends a delta and leaves
  the first text as it is, so the section still says `none` while the delta's own sub-section lists
  A6–A8.
- **A deferred design sentence the build does not follow** (same run). plan-2's Low on the design's
  attribute grammar went to the build as a known gap; the build followed the parser's source instead
  and added a check. Whether not following a deferred design sentence is a design point for the
  advisor is not written.
- **The PR identifier has no producer** (same run). review-1 was refused at check-in: its invocation
  named `pr` as `27`, where the contract asks `<owner>/<name>#<N>`. The delivery contract outputs no
  PR identifier, so nothing connects review's `pr` to the run that opened it; the reviewers' wrappers
  take `--pr <N> --repo <owner/name>`, and no document says the module converts.
- **The review posts before check-out** (same run). review-2's aggregation wrote a rejected row's
  grounds into the disposition cell (`rejected: …`), so check-out read a Medium that holds against
  `max_severity: Low` and refused the run, after the comment was posted. The session moved the
  grounds into the finding cell and a copy then passed; the run's own result stays refused, and a
  new run of the round would post a second comment. The aggregation's form is checked only after the
  posting the output requires (`pr_comment_posted`).
- **Smaller gaps the sessions reported** (same run): the contract's `result.summary` that no
  `result.json` carries; the criteria-apply note on `- Text:` / `- Into:` still in the future tense;
  the design contract's `[design-point]` marker that the ledger grammar lacks; a `decisions` input
  that names the whole ledger where the contract names markers; `reads_records: true` beside a note
  that says the trace takes the record alone; no invocation field for the target's documents; the
  audit's checklist input given by the invocation while the command body says `status` names it;
  the integration check failing on the environment alone (a local `codex` shim) with no rule for it;
  stopping the CI check, by the operator's word here, with no way to record it.

## Handoff log

| Session | Date | What was done | Next |
|---|---|---|---|
| 1 | 2026-10-23 | Surveyed `main` at `a2ff109`; created and pushed the branch; wrote this document; filed the epic #507 and its sub-issue 1, #508. Settled with the operator: Q1 withdrawn, Q2–Q5 settled (§6). Then, the operator away and proposals taken on the recommended option by the operator's instruction: the criterion review as four modules (§4), the contract format and invocation (§5), the drafts `docs/contracts/design.json` and `docs/contracts/plan.json`. The committed checks pass locally (the `run:` steps of `contract-suites.yml`, `plugin-package.yml`, `e2e-dummy-target.yml`). | Done after the row: #508 closed (its work committed on this branch directly, `d53ffa1`…`aba1d0f`, so it has no PR); sub-issue 2 filed as #509. | #509: branch off this branch, settle its four open points, then the contracts, the generator and checks, the validator and criteria-apply; PR into this branch. |
| 2 | 2026-10-24 – 25 | On `design/io-contract-modules-509` (local commits, not pushed): settled #509's four open points and, with the operator, Q6–Q18 (§6); narrowed the drafts to inputs and dispositions; wrote the twelve other contracts, then moved all fourteen to JSON (Q17); wrote `scripts/contracts/contract.sh` (check-in, check-out, lint — the contract–document check, a `contract-suites.yml` step), `markdown.jq` and `criteria-apply.sh`, each checked by a one-shot run (48 + 27 checks, scratchpad, not committed). Ran the modules on opensre#1 in a fresh session each, from criterion-screen to delivery: 17 runs, 16 accepted, plan refused on its rubric's `Tools`; draft PR Munsik-Park/opensre#25 opened. Observations in §11. | The run's report: Claude Docs "opensre#1 모듈 시험 보고서". The operator decides when the branch is pushed. | Push and open the PR into `design/io-contract-modules` when the operator says; sub-issue 3 takes the improvement items of §8 and §11. |
| 3 | 2026-10-25 | On `design/io-contract-modules-509` (local, not pushed): ran the review module on opensre#1 (accepted; §11). Settled with the operator Q19 (check-in checks an input's form, not where it came from; the build's commits as a range; no commit needs its reason) and Q20 (one record directory per attempt, runs named `<module>-<n>`, functional modules read it; §1's statement revised); applied both to the contracts and `contract.sh` (`aaf9238`). Ran a second round on opensre#1 from review-1's findings — design-2 … review-2, eight accepted — which found and fixed a `pr_comment_posted` defect (`8aee794`); observations in §11. The run's report: Claude Docs "opensre#1 모듈 시험 2회차 보고서". The operator decided: opensre is a test bed only (its issue is not a work target); a known gap worth fixing becomes an issue; repeated tool requests are listed as they come; sub-issue 3 goes on a branch stacked on this one, tested through its worktree with `--plugin-dir`, merged in order later. | The operator decides when this branch is pushed. | Sub-issue 3 on a stacked branch: survey and ADR draft first, then the documents to the contracts, the progression devices removed, the module commands, the tests and a step-by-step run. |
| 4 | 2026-10-26 | On `design/io-contract-modules-transition` (local, not pushed), after the earlier transition sessions' documents and device removal: applied the operator's Q25–Q27 (§6) — the Coordinator leaves the documents, agent definitions and devices; the ledger names no writer and the hook keeps append-only; a module spawns the advisor and follows it, the design's `## Decision requests` becoming `## Advisor decisions`. Also: every run's `result.json` records the AutoFlow that ran it, `criterion-ready.sh status` and `emit-phase-marker.sh` go, the README's lifecycle figure goes; ADR-0038 revised (file `0038-contract-modules-with-no-state-file.md`). One-shot runs: the hook's append-only cases, `security-checklist.sh` on ledgers of both grammars, and the #509 runs, `run-transition.sh` on a copy with the renamed section. | The operator decides when the branch is pushed. | The module commands (ADR-0038 D9). |
| 5 | 2026-10-26 | On `design/io-contract-modules-transition` (local, not pushed): the security checklist states the hook's policy denies and the ledger's append-only check, with the operator's acceptance (Q24; `4455f58`). The open points session 4 left, applied by the settled principles: the `[criterion-ready]` entry goes — the criterion review's decisions are criterion-reconcile's record, which names the body by its sha256 line, and the analysis takes it (Q4: what a module produces itself is its own output); a change to a criterion's content is the advisor's `[ac-decision]` (Q27); the issue body is not edited, the applied criteria being criteria-apply's output (Q5, Q25); identifiers stay `A<n>` (Q26); the contracts' `{path: coordinator}` becomes `{path: invocation}` (Q25), and who makes the checklist version file is not described; the nested advisor spawn needs no test, ADR-0023's measurement having recorded a subagent's spawns. ADR README rows of the ADRs ADR-0038 supersedes in part annotated. | Module commands (D9, §8), then the run module by module on the test target (§10). |
| 6 | 2026-10-26 | On `design/io-contract-modules-transition` (local, not pushed): the module commands (ADR-0038 D9, §8). `/autoflow:cycle`, `/autoflow:cycle-u1` … `cycle-u7` and `/autoflow:criterion-review` give way to one command per module, `/autoflow:<module> <invocation.json>` — fourteen, one per contract —, generated by `gen-skill-bodies.sh` from the core by `core-units.tsv`, now classified by module, and from the documents by `role-docs.tsv`. Each body names the contract, check-in and check-out, what does the work — the session, a role's spawn on the model `spawn-policy.sh model <phase-key>` names, or the script —, the record directory for a module that reads it, and the advisor's key. The core's unit tables become *Module procedures* and *Module references*; `verify-skill-bodies.sh` reads them by module and checks that every contract has a body; `abbreviated-path.md` is removed; CLAUDE.md, README, INDEX, the tool-delivery contract, the plugin manifests and the contracts' `status` follow. The committed checks and the one-shot runs (69, 30, 32) pass. | The run module by module on the test target (§10). |
| 7 | 2026-10-26 | The module commands run on the test target, module by module (§10, §11 *The module commands, run module by module* and the items after it): twenty runs on opensre#1, each in its own session, from the criterion review to the review of draft PR Munsik-Park/opensre#27; seventeen accepted; a subagent's advisor spawn works. Fixed during the run: every run writes `tool-requests.json` (`c673c52`), the in-depth spawn's inputs (`5819d61`). The merge review page: https://claude.ai/artifact/VArseNPJbyNyCfRYN3DkKd. | The observations above settled or left to the operator; sub-issue 3 filed; push, PRs and review. |
| 8 | 2026-10-26 | Q28 and Q29 (§6), on the opensre#1 run's observations: the evaluator writes its own `<out>/evaluation.json`; the contracts keep only the checks a script, an owed id or a fact needs (`mentions` and a count-only `covers` added; the section, table, line, rank and verbatim checks of the analysis, criterion review, design, build, review and delivery outputs go); the procedures state what each output holds instead of its form. Checked on copies of the run's outputs: design-2, plan-2, quality-1 and review-2 accepted (review-2 refused before), a design naming no AC2 and a re-score answering 2 of 7 findings refused. The one-shot validator suite's twelve form cases now pass where they refused, as intended. | The coordination improvements (`coordination/IMPROVEMENTS-opensre-1-2026-10-26.md`), led by the operator; sub-issue 3 filed; push, PRs and review. |
| 9 | 2026-10-26 | Q30 (§6): one advisor request holds the decisions that depend on each other, each recorded apart. A module usage document for whoever assembles the modules, at the operator's request ("이 부품들을 어떻게 사용할 수 있는지 … 문서를 만드는 것이 좋을 것 같아요"): `docs/autoflow-guide.md` — how a module is run and how one's output becomes another's input, by hand; each module's params, inputs with their sources, outputs and an invocation skeleton, generated from the contracts by `scripts/contracts/gen-module-usage.sh` in place of the guide's hand-kept module table, which `contract.sh lint` checks. Re-running criteria-apply after a run that changed the criteria is the assembler's, recorded in the coordination improvements (C8). | The remaining items: the small contract and document mismatches; whether a test kept in the target's tree is a goal; wording that sends a worker looking for grounds. |
