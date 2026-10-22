# Design review: input/output-contract modules

**Status**: working draft on the branch `design/io-contract-modules`, from `main` at `a2ff109`
(plugin 0.3.12). Not normative: no rule in `docs/` changes by this document. The decisions it
reaches go into an ADR that supersedes the ones listed under *Decisions this supersedes*.

**How the work runs**: outside AutoFlow — no attempt, no state file, no `/autoflow:cycle` — in
sessions handed off one to the next. A session in this repository runs the installed plugin;
the working tree's rules run only under `claude --plugin-dir .` (`CLAUDE.md`). Each session
appends to *Handoff log* before it ends.

## 1. The concept (operator's statement)

- AutoFlow's plugin is a set of **modules**. Each module declares, in a YAML contract, the
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
| **Move to the Coordinator** | route selection by `remedy_class`, recommendation triage, the attempt caps | `scripts/gate/remedy-route.sh`; [units/completion-evaluation.md](../../units/completion-evaluation.md) > Recommendation triage, FAIL routing; `review-gate.sh` cap |
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
- **Evaluation modules** take artifacts and produce an evaluation report (scores,
  `remedy_class`, findings): hypothesis, plan, audit, quality.
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

What follows the four — putting an open question to the advisor, editing the issue body to the
settled decisions, and the `[criterion-ready]` entry (an `O` entry the main session writes,
*Confirmation*) — is the Coordinator's, being decisions and their record (Q4). Whether the issue-body
edit becomes a deterministic module like criteria-apply is left to the contracts of sub-issue 2.

This split is the one ADR-0037 D2 already names ("functional and evaluation modules"). It also
closes a gap the survey found: only AUDIT's report has a fixed path
(`<attempt-dir>/issue-{N}-audit.md`, [evaluation-system.md](../../evaluation-system.md) > AUDIT >
Report). GATE:HYPOTHESIS, GATE:PLAN and GATE:QUALITY reports have none, yet
[units/design.md](../../units/design.md) > Unit spawn names "the GATE:HYPOTHESIS reports" as an
input. As module outputs, every evaluation report gets a declared path and format.

`/autoflow:cycle` and the abbreviated path ([abbreviated-path.md](../../abbreviated-path.md))
stop being paths the plugin defines. They become two ways of composing the modules.

## 5. Contract format and module invocation

§5.1–5.2 *proposed — pending the operator's confirmation*; §5.3 **accepted** by the operator, 2026-10-23 ("3 수용"). Drafts that follow it: the design module
([`docs/contracts/design.yaml`](../../contracts/design.yaml)) and the plan evaluation module
([`docs/contracts/plan.yaml`](../../contracts/plan.yaml)). No device reads them yet.

### 5.1 Where contracts live, and how they are read

- **One file per module**, `docs/contracts/<module>.yaml`. `CLAUDE.md` > Writing AutoFlow
  Documents writes an AutoFlow path as `<autoflow-root>/docs/…` or `<autoflow-root>/scripts/…`; a
  contract under `docs/` keeps that convention and adds no top-level plugin component (ADR-0027 D1
  lists them).
- **Authored in YAML, read as JSON.** The README's prerequisites are Claude Code, `jq` and `gh`
  (`README.md`, **Prerequisites**); jq does not read YAML, and Python's standard library has no YAML
  parser (`python3 -c 'import yaml'` fails on this machine). A generator writes each contract's
  JSON beside it and is checked for equality with the committed copy, on the pattern of
  `scripts/skills/gen-skill-bodies.sh` and `tests/plugin/verify-skill-bodies.sh`. The YAML parser
  is then a development-time tool only: `yq` (mikefarah) v4 — v4.53.3 here, and 4.54.1 on the
  Ubuntu 24.04 runner image (`actions/runner-images` > `images/ubuntu/Ubuntu2404-Readme.md`), the
  image `ubuntu-latest` the workflows run on. The runtime prerequisites do not change.
- **A `.yaml` file carries an inline SPDX header.** `REUSE.toml` bulk-covers Markdown, JSON, JSONL
  and plain text and leaves the header-bearing types (`.sh`, `.py`, `.yml`, …) to inline headers.

### 5.2 What a contract carries

| Key | Holds |
|---|---|
| `contract` | the format version, `1` |
| `module`, `kind` | the module's name; `functional`, `evaluation` or `deterministic` (§4) |
| `goal` | one paragraph: what the output is for |
| `procedure` | the document the module follows (today's unit document, or the rubric) |
| `params` | scalar inputs the Coordinator passes: name, type, required, enum |
| `inputs` | file inputs: name, `required`, and `from` — where such an input comes from: `{module, output}` (another module's output, whose schema the validator then applies), `{ledger: [<marker>…]}` (a decision entry, Q4), or `{path: target}` (a document of the target the Coordinator names) |
| `outputs` | each output: `file` (its name inside the output directory), `format` and its schema |
| `reference` | values AutoFlow provides with the output for the Coordinator to apply (Q2) |

**Output schemas**, by the forms today's artifacts already take:

| `format` | Schema keys | Today's example |
|---|---|---|
| `markdown` | `sections`: each `heading`, `required`, `empty` (the word an empty section says, `none`); a section may hold `lines` (what each line holds, and a value list). `tables` for a table: `locate` (under a heading, or by its header row), `columns`, per-column `enum` / `pattern` / `required_when`, and `coverage`. `first_line` for a line before the first heading. `forbids` for content the output must not carry | the analysis report's ten sections; the verification design's AC table and `## Tools` |
| `json` | `keys`: each `type`, `required` / `required_when`, `enum`; `forbidden` keys | the evaluation report ([evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format) |
| `ledger-entry` | `marker`, `namespace`, `fields` | `[criterion-ready]` ([criterion-review.md](../../criterion-review.md) > Confirmation) |
| `validator` | a script that accepts or refuses the file | the findings file, refused by `review-gate.sh` exit `2` |

**Every rule says who checks it**: `check: mechanical` (the contract validator) or
`check: evaluation` (the evaluation module that scores the output). The split exists today: the
orchestrator checks that the design documents carry `## Decision requests` and `## Tools`
([units/design.md](../../units/design.md) > Unit spawn), while whether a `Failure mode` cell can be
told apart from another's is GATE:PLAN's Scope deduction ([evaluation-system.md](../../evaluation-system.md)
> GATE:PLAN > Scoring). A contract names both, so the validator never claims what only an
evaluation can judge.

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

- **The module checks its inputs first**: `autoflow-contract check-in <invocation.json>` — every
  required input given, every given input conforms to the schema its `from` names. On a refusal it
  writes nothing but the result file and stops.
- **It writes each output to `<out>/<file>`** and ends with `autoflow-contract check-out
  <invocation.json>`, which checks the outputs against the contract and writes
  `<out>/result.json`: the module, `accepted` or `refused`, each output's path, and each defect
  found. The Coordinator reads that file to decide the next run (Q3).
- **The output directory is the Coordinator's.** A re-run gets a new directory and names the
  previous outputs as inputs, so nothing is renamed or overwritten.
- **A module does not know which run it is.** What a re-run's output owes because it is a re-run is
  derived from its inputs: the design's `## Delta — round <n>` takes `n` from the number of delta
  sections in the previous document it is given, plus one (`docs/contracts/design.yaml` > `rules`).
- **The existing commands stay until sub-issue 3**: `/autoflow:cycle-u1` … `cycle-u7` keep their
  current behaviour on this branch, and sub-issue 3 replaces them with the module commands.

Open within the format, for sub-issue 2: the name `autoflow-contract` and whether it lives in
`bin/` beside `autoflow-records`; and who writes an evaluation module's output, since the evaluator
agent has no Write tool (`agents/autoflow-evaluator.md` > `tools: Read, Glob, Grep, Bash`) — the
draft names the invoking session, writing the returned report verbatim (`docs/contracts/plan.yaml`
> `outputs.evaluation.writer`).

## 6. Open decisions

| # | Decision | Status |
|---|---|---|
| Q1 | Where the evaluation gate lives | **Withdrawn** (operator, 2026-10-23). The question assumed an actor that pushes or opens a PR outside the module whose output that is — the current model's premise, where one orchestrator holds every tool and the hook reads the command it issues (ADR-0025 D8). In this model push and PR are the delivery module's output and no other module produces them; how modules are run is the Coordinator's composition. The hook's push, PR and U3/U4 spawn gates go (§3). Whether delivery takes an evaluation output is settled in its contract by what its output needs: the PR body's known gaps carry the recommendations deferred or separated at triage ([units/delivery.md](../../units/delivery.md) > Push and pull request), so the quality evaluation's triage result is a content input, not an admission condition. |
| Q2 | Where the pass threshold lives | **Settled** (operator, 2026-10-23): AutoFlow provides the reference values with the evaluation output; applying them is the Coordinator's. The evaluation module outputs scores, grounds and `remedy_class` and no `verdict` — as today, where the evaluator scores and the hook computes PASS ([core.md](../../core.md) > Flow Control; [evaluation-system.md](../../evaluation-system.md) > Evaluation Output Format). The reference values are today's PASS Criteria (avg ≥ 7.5, each item ≥ 7, security ≤ 3 → rework; [evaluation-system.md](../../evaluation-system.md) > PASS Criteria), kept with the rubric whose scale they are set on. Where in the output or the contract they sit is fixed when the evaluation contracts are drafted. |
| Q3 | The line between a module's own repetition and an external loop | **Settled** (operator, 2026-10-23): an output that falls short of its format is re-run by the Coordinator; a module runs once and does not loop. Re-running on an evaluation result is the Coordinator's as well. Today's re-spawn on a missing report section is already the orchestrator's ([units/analysis.md](../../units/analysis.md) > Unit spawn), so it moves to the Coordinator with the rest of the orchestrator's routing. The criterion review's stages: four modules, accepted (§4). |
| Q4 | The ledger's standing | **Settled** (operator, 2026-10-23): the ledger holds only decisions — entries that settle what a module cannot settle itself (`[criterion-ready]`, `[ac-decision]`, `[checklist-decision]`, a design point), under their authority: `operator decision` and the main session's own decision in the `O` namespace, `advisor decision` in the `A` namespace ([decision-ledger.md](../../decision-ledger.md) > Entry identifier). In this model the main session that writes `O` is the Coordinator's. A module contract may name such an entry as an input ("the ledger decision with marker X"). What a module can produce itself is its own output file. The orchestrator's entries leave the ledger: the attempt records counted for the caps (`[gate-autofix]`, `[review-autofix]`), the cap-window reset (`[reentry-decision]`) and `[rebuttal]` are the Coordinator's records; the gate verdict entries ([decision-ledger.md](../../decision-ledger.md) > Entries, *Writers*) are replaced by the evaluation output files. The hook's append-only and authorship denies stay as they are and keep guarding these entries. The contradiction between [state-tracking.md](../../state-tracking.md) ("the ledger is not a gate input") and the REVIEW cap counted from `[review-autofix]` entries goes with both: the first document is removed, the count moves to the Coordinator. |
| Q5 | How an acceptance-criterion change is applied | **Settled** (operator, 2026-10-23): the applied criteria are an output of their own. A deterministic script computes them from the analysis report's first AC table and the `[ac-decision]` entries; every later module takes that output as its input. The request is already a module output (the design's `## Decision requests`, the build report, an evaluation recommendation — [units/design.md](../../units/design.md) > Report routing) and the decision a ledger entry (Q4); only the edit the orchestrator makes today to the analysis report's table ([units/analysis.md](../../units/analysis.md) > Re-entry) is replaced. It needs the `[ac-decision]` grammar ([decision-ledger.md](../../decision-ledger.md) > Decision-point entries, *Acceptance-criterion decisions*) to carry the criterion's new text for `revised`, `split` and `added` — today the entry has `- AC:`, `- Disposition:` and one Decision line, which a script cannot apply. Rejected: re-running analysis on the entries (a full analysis run for a table edit, and other content may move); each consuming module applying the entries itself (one application in five places). |

Operator's words:

- Q1: "생각해보면 이 질문이 조금 이상한 것이 각 단계는 자기가 실행을 하는 범위가 있어요. 입력이 있고 출력의 형식이 있죠. 근데 그 출력의 형식을 무시하고 직접 푸시나 PR을 생성한다라는 가정을 하는 거잖아요. 이 지금 질문이 맞아요?"
- Q2: "C 형태가 맞는 것 같아요. 기본적으로 출력 값에 레퍼런스 루브릭 값을 제공하는 것은 오토플로우에서 제공하는 것이 맞고, 그것을 실제로 적용하는 것은 외부에서 적용하는 것이 현재 설정입니다."
- Q3: "참고로 추가하면 현재 만약에 출력의 형식이 부족하다라고 하면 조율자가 다시 실행을 시킬 거예요. 즉 루프로 재실행하는 구조로 만들면 이 문제는 해결이 됩니다."
- Q4: "c" (option C: the ledger holds only decisions).
- Q5: "B로 진행하세요." (option B: the applied criteria as an output of their own, computed by a script).

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
   (`agents/autoflow-evaluator.md`, `tools: Read, Glob, Grep, Bash`).
10. The unit commands' entry check ("confirm from cycle-status.sh that the cycle stands at Uk's
    entry", `skills/cycle-u3/SKILL.md`) has no definition, because `cycle-status.sh` names no phase
    ([units/preparation.md](../../units/preparation.md) > Resume).

## 8. New work

- One YAML contract per module: inputs, outputs, each output's schema.
- One contract validator: input check at module start, output check at module end.
- A check that the contracts and the documents agree, on the `core-units.tsv` →
  `verify-skill-bodies.sh` pattern.
- A script that computes the applied acceptance criteria from the analysis report's table and the
  `[ac-decision]` entries, and the grammar field it needs (Q5).
- An ADR that supersedes the decisions below.

## 9. Decisions this supersedes

| ADR | Decision | Why |
|---|---|---|
| [0025](../adr/0025-outcome-gated-functional-units.md) | D5 (the orchestrator sequences units, records scores, routes) | sequencing and routing move to the Coordinator |
| 0025 | D6 (the four gated state keys stay as unit exit gates) | the state file is removed |
| 0025 | D1 (a unit ends at a recorded gate) | work and gate split into separate modules |
| [0029](../adr/0029-attempt-records-under-one-record-root.md) | D4 (entry is a fact, printed by `cycle-status.sh`), D6 (the hook gates per checkout) | no entry evaluation, no state gates |
| [0036](../adr/0036-the-abbreviated-path-beside-the-full-cycle.md) | D6 (`cycle-status.sh` reports an attempt with no state file), D7 (which checks bind which path) | the paths become compositions |
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
  lines are the SPDX header; the two new `.yaml` files are counted compliant. Not investigated: the
  file is not touched by this work.

## Handoff log

| Session | Date | What was done | Next |
|---|---|---|---|
| 1 | 2026-10-23 | Surveyed `main` at `a2ff109`; created and pushed the branch; wrote this document; filed the epic #507 and its sub-issue 1, #508. Settled with the operator: Q1 withdrawn, Q2–Q5 settled (§6). Then, the operator away and proposals taken on the recommended option by the operator's instruction: the criterion review as four modules (§4), the contract format and invocation (§5), the drafts `docs/contracts/design.yaml` and `docs/contracts/plan.yaml`. The committed checks pass locally (the `run:` steps of `contract-suites.yml`, `plugin-package.yml`, `e2e-dummy-target.yml`). | The operator confirms or changes the proposals marked *pending* (§4, §5); then sub-issue 2. |
