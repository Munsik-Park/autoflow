# U4 Build and verify — BUILD and AUDIT

> The procedure of the build module, and the spawn of the audit module. [`core.md`](../core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U4 Build and verify is two modules: the build module, whose contract is
`<autoflow-root>/docs/contracts/build.json` and whose procedure is this file, and the audit
evaluation module that judges test-first and audits the change
(`<autoflow-root>/docs/contracts/audit.json`, [`evaluation-system.md`](../evaluation-system.md) >
*Gate rubrics* > AUDIT; [`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md)
D1). This file states the build's goal, what it owes, the cautions it is asked to heed and the
report it writes. How the module reaches the goal — what else it reads, whether it spawns helpers,
how it divides test and implementation work, how it runs its checks and when it stops iterating
within its run — is its own, recorded with its grounds in its report ([`core.md`](../core.md) >
Rule Scope, principle 2).

- **Goal**: the design implemented within its scope on the branch the invocation names
  (`params.branch`), and every item of the verification design verified as it says — or, where it
  cannot be, the reason recorded.
- **Output**: the commits the run makes on the branch, the build report (*Build report* below), a
  green-blocker record when the design cannot be built as it stands, and the run's tool requests
  ([`core.md`](../core.md) > Development Lifecycle > *Tools*).
- **Evaluation**: the audit module — a fresh Evaluation AI that judges test-first from the build
  report and git, then scores the change on the rubric of
  [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > AUDIT; the module never
  scores its own change (*Evaluation — AUDIT* below).
- **Result owed**: the build report's path, the commit SHAs and a one-line summary
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format).

## Unit spawn

- **The spawn.** One `autoflow-unit-build` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-build` names) runs the
  module. Its prompt states the goal and names the inputs the invocation gives by path — the applied
  acceptance criteria (criteria-apply's output), the two design documents, the decision ledger's
  `[ac-decision]` entries, the recommendations deferred or separated (`deferred`),
  which the build leaves to their disposition, and on a re-run the previous report and the findings
  it answers (an audit's, a quality evaluation's or a review's) — the branch, the attempt's record
  directory, where earlier runs left their work and their `local/` stores, and the output directory.
- **Documents.** The unit's agent definition carries this file with the rest of its guidance
  ([`core.md`](../core.md) > Context Injection); the analysis report's `## Affected documents` and
  the target's documents are read by the module's own judgment.

## What the build owes

These are the rules other documents cite; everything else about the work is the module's.

- **Scope.** The module implements every applied acceptance criterion within the scope — the
  feature design with its `## Scope` section, and the verification design. An item the verification
  design verifies other than by an executable test ([U3 Design](design.md) > *Test necessity*) is
  still implemented; only its evidence differs. A problem met during the work that the scope does
  not name is judged under [`submodule-common-rules.md`](../submodule-common-rules.md) > Change
  Surface Rules > *Scope judgment* and recorded under `## Scope judgments`. Tests verify
  correctness; they do not define the solution — no hard-coding to test inputs, no special-casing
  an assertion. Once the scope is implemented and verified, a further change the module judges
  useful beyond the scope and the problems its scope judgments include is recorded under
  `## Scope judgments`, not made.
- **Test-first (TDD).** A test that verifies a required behavior — a behavior not yet implemented,
  or a defect reproduced before its fix — is seen failing on the code without the implementation it
  verifies and passing on the code with it, each run shown by its log. A test that records existing
  behavior the change must preserve may pass from the start. Which of its tests verify a required
  behavior, the order of the work, and how the failing run gets the code without the
  implementation — a test commit first, a run at an earlier commit, or the implementation set aside
  for that run only — are the module's. The failing run's log shows the failure, the exit status
  included, and the code it ran on: the commit, and the change set aside for that run if any. A
  recorded judgment stands in for no failing run. The failing run goes in `## Test-first` only;
  `## Run record` holds each item's latest run.

  The test-first rule (ADR-0038 D7) is judged by the audit module from this report and git: the
  failing run on the code without the implementation and the passing run on the code with it, each
  shown by its log ([`evaluation-system.md`](../evaluation-system.md) > AUDIT > *Test-first*).
- **Where a test lives.** A test the run writes for its own verification, a one-shot delivery
  check, an observation scenario and its record live under the run's `<out>/local/` and are run by
  their path ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools);
  a later run reads them there, in the record directory. A test file goes into the target's tree
  only as the exception: a file the module judges the target should keep — in this repository a
  deployment-level check of the kind it commits (`packaging`, `manifest`; ADR-0038 D7) —, listed
  under `## Test files kept` with its reason and the CI job expected to run it; the delivery module
  carries that list into the PR body with the CI job that actually ran each file
  ([U6 Delivery](delivery.md) > *CI* > *Added test files*). Such a file is wired into the target's
  CI discovery in the same commit.
- **Running tests.** Locally and once, the tests the change requires, the way the target runs them
  (*How a test is run is the target's practice*, *Local verification*); no whole-tree run. An item
  verified by observation with a tool is looked at with that tool and its observation record written
  under `<out>/local/`, ending in one result line — `observation: match` or
  `observation: mismatch — <what differs>` (*The tools the work needs*). A tool neither this
  environment nor the target's procedures provide, or what using a tool the environment has lacks,
  is recorded as a tool request — naming what is missing, not the output the tool would give, and
  what the run did instead — and never acquired.
- **Comment check.** Before the module's last commit it reads the comment lines the change's diff adds
  (`git diff <start>...HEAD`, `<start>` the commit the work on the branch started from) against [`submodule-common-rules.md`](../submodule-common-rules.md) >
  Change Surface Rules > *Code comments* — the classes a pattern finds (an issue / PR reference, a
  review round, an acceptance-criterion identifier, another file's path, a change-history marker) and
  those found by reading (a restatement of the code, design discussion, another file's contract,
  commented-out code, and content none of the cases under *What a comment carries* admits, such as a
  value, count or list copied from another file) — disposes of every hit (removed, rewritten, or
  kept with the reason the match is not the class) and records the result under `## Comment check`.
  The check is a signal, not a gate.
- **Design contradiction.** When the acceptance criteria are themselves mutually unsatisfiable — the
  implementation and the tests each faithful to the design — the module implements the satisfiable
  subset and records the contradiction in `<out>/green-blocker.md`: the conflicting criteria, the
  measurement that reproduces the conflict, and `path:line` anchors at the run's commit. The design
  module takes it as an input on its re-run.
- **Acceptance-criterion change.** A criterion the work shows defective ([`decision-ledger.md`](../decision-ledger.md)
  > *Acceptance-criterion decisions*) the module puts to the advisor with the proposed change and the
  fact that shows the need, and it follows the decision — never working around the defect by keeping
  the criterion's letter ([U3 Design](design.md) > *Report routing* > *An acceptance-criterion change
  shown later*).
- **Commits.** Every commit follows `<autoflow-root>/docs/core.md` > Commit Rules, the lint chain over its staged files
  included. A lint chain covering a staged file that cannot run in this checkout, and that no
  pull-request CI job covers, is recorded `not-run (unexecuted)` in `## Lint` and as a tool request.
  The module does not push; pushing is the delivery module's. A run that makes no commit says why in
  `## No commit`.

## Dividing the work

A recommendation, not a rule: whether the module divides its work, and how, stays its own, and the
division it chose and its grounds go in the build report. This section records what a division is
worth and where it loses.

- **What a boundary is worth.** A context's cost is what it carries times the requests that carry
  it: what was read for finished work is read again on every later request. A boundary pays when
  the context it drops, less what a new context takes in to start (the standing prompt and the
  handoff below), is large and many requests follow it. A boundary that drops little more than
  that, or that few requests follow, costs more than it saves.
- **Where to divide.** On a build whose design names several areas that share no code, two
  boundaries pay:
  - between areas — an area's code is not used by the next, so the next carries none of it;
  - after the last implementation commit — verification and integration read again what they
    need, which costs far less than carrying every area's context.

  Inside an area the Red→Green loop is not divided: the test, the implementation and the reading
  of a failure use the same code.
- **A layout.**

  | Context | Its work | Policy row |
  |---|---|---|
  | The unit itself | reads the design and the rules, assigns the areas, checks each return, spawns the observations | `unit-build` |
  | One per area | the area's Red→Green, its tests and lint, its commits | `unit-build-area` |
  | Verification and integration | the run record, each verification row's check, the follow-up of the observations, the comment check, the build report | `unit-build-verify` |
  | One per observation | the observation with its tool: running it, judging match or mismatch, probing a cause | `unit-build-observe` |

  A helper is spawned as `general-purpose` with the model and the effort its row reads out
  (`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <row>`, `… effort <row>`), the effort passed as
  the `Agent` tool's `effort` parameter — or the parameter omitted when the row reads out the
  inherit sentinel, which is the policy file's own value and never an argument (`effort_contract`).
- **What crosses a boundary.** To an area: its section of the feature design, the sections every
  area shares (`## Scope` and the common constraints the design names), its verification rows, a
  note of the repository's conventions (how its tests and lint run, its commit rules) the unit
  writes once, and the diff of a shared file an earlier area changed. From an area: its commits,
  its `## Test-first`, `## Run record` and `## Lint` rows, its scope judgments and out-of-scope
  observations, and what a later area needs to know of its changes. To every helper: the AutoFlow
  root (the unit's root declaration) and the text of the rules its work follows, from the unit's
  own definition — `<autoflow-root>/docs/core.md` > Instruction Conventions and Rule Scope, by
  which they are read, `<autoflow-root>/docs/core.md` > Commit Rules, `<autoflow-root>/docs/units/build.md` >
  What the build owes > *Test-first*, `<autoflow-root>/docs/submodule-common-rules.md` >
  Change Surface Rules > *Lint chain on the staged surface* and `<autoflow-root>/docs/role-common-rules.md` >
  Bash Execution Mode — since a `general-purpose` helper has no AutoFlow definition of its own
  (`<autoflow-root>/docs/core.md` > Context Injection). Requirements of two areas that
  cannot both hold take the design-contradiction path above; a design point two areas meet
  differently the unit puts to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor).
- **A deterministic run is a command, not a context.** Running tests, lint and builds, and
  committing, take no judgment; what they cost is their output carried in the context that reads
  it. A run goes through a command that bounds its time, keeps the full output in a log under
  `<out>/local/`, and prints the exit status, the summary line, the names of failing tests, the
  first error block and the log's path. That short result fills `## Run record` and `## Test-first`;
  the log stays the evidence. A run with no bound holds the context that started it, and every
  helper report waiting on that context. A model spawned for each run costs more than it saves:
  each spawn writes its standing prompt anew.
- **A judgment stays with the work it judges.** An observation's match or mismatch is judged by
  the context that ran it, which can probe a cause while the state is in front of it; a judging
  context split from the run reads the records and captures again and cannot probe. The comment
  check and the scope judgments belong to the context that holds the whole diff.
- **When a division loses.**
  - The areas share code: what each must read again of the others' code outweighs the context
    dropped.
  - The build is small: the context before a boundary is near what a new context starts with, or
    few requests follow it.
  - A model is spawned for each deterministic run.
  - The handoff is the whole design and every convention rather than the area's part: most of the
    saving is lost.

## Build report

`<out>/build-report.md`. The first run writes it whole; a re-run, given the previous report, brings
it up to date rather than rewriting it (*Re-entry* below). It records what the table below lists,
for the readers it names; the headings and the form are the module's, and a matter with nothing to
record is said to have none. A run that made no commit says why in a `## No commit` section, which
check-out reads (`build.json`).

| Section | Holds | Read by |
|---|---|---|
| `## Run record` | each applied criterion and each item of the verification design, with how it was verified — the command, its log and the summary line read from it, or the observation record — and its latest result, or why it was not verified | GATE:QUALITY `Test coverage`; the delivery module (PR body) |
| `## Test-first` | each test that verifies a required behavior: the test, the item it verifies, its failing run — the code it ran on (the commit, and the change set aside for that run if any), its log, and the summary line and the non-zero exit status shown in it — and its passing run on the code with the implementation, with that commit and its log | AUDIT (*Test-first*) |
| `## Manual checklist` | each item verified by observation: who observed it — the AI, with which tool, or a person — and its observation record, or that it was delegated to the operator | GATE:QUALITY `Test coverage`; the delivery module (PR body) |
| `## Maintained documents` | one line per document the change updated, ``- `<path>` — <what changed>``, or `- none — <reason>` | GATE:QUALITY `Doc updates` |
| `## Lint` | per commit the run makes on the branch (≥ 7 hex), per chain: the lint outcome word, a `not-run` with its reason class in parentheses; a commit another actor makes on the branch adds its own | GATE:QUALITY `Commit conventions` |
| `## Scope judgments` | each scope judgment the work made ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment*) | GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Out-of-scope observations — guard / boundary logic touched` | each behavior-changing suggestion the module rejected whose subject is validation, a guard, path / root resolution, an input or output boundary or error handling, and each one it judged directly related — its `path:line` and the behavior it would change | GATE:QUALITY (`refine_observations`) |
| `## Comment check` | the line `comment-ratio: <added comment lines>/<added lines> (<percent>)`, then one line per hit — `path:line`, class, disposition | GATE:QUALITY (*Code comments in a target*) |
| `## Test files kept` | each test file added to the target's tree, its reason and the CI job expected to run it | GATE:QUALITY `Test quality`; the delivery module (PR body; *Added test files*) |
| `## Tool requests` | each tool request of the run — what was missing, and what the run did instead — or `none` | the delivery module (PR body) |
| `## Advisor decisions` | each decision the run put to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor) — its ledger entry, the decision and how the run followed it — or `none` | GATE:QUALITY |
| `## No commit` | only when the run made no commit: why | check-out (`build.json`) |

Anything else the module records — how it divided the work, the checks it chose to run and what
they found — is its own, written where it judges useful.

## Evaluation — AUDIT

The audit module judges test-first and scores the change: one fresh Evaluation AI
(`autoflow-evaluator`, the model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model audit`
names), on the rubric of [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > AUDIT.
Its agent definition carries that document. When it does not confirm test-first it scores nothing
and records what is missing; its output is otherwise the scores and their grounds with its
recommendations.

### Security checklist

The target's own: AutoFlow ships no checklist and names no item. A target declares its checklist
in the target-owned scaffold `.claude/autoflow.local.json`
(`{"audit":{"security_checklist":"<repository-relative path>"}}`). Which version the audit reads is
the one the record line of
`bash <autoflow-root>/scripts/gate/security-checklist.sh status --base origin/<base> --ledger <attempt-dir>/issue-{N}-ledger.md`
names, `<base>` the branch the pull request merges into; the audit takes the checklist at that version, written to a file (`git show <score>`), as its
`security_checklist` input ([`evaluation-system.md`](../evaluation-system.md) > AUDIT > *Security checklist*):

| Exit | Verdict | The version the audit reads |
|------|---------|-------------|
| 0 | `none-declared` | none — the five items are scored from the change alone |
| 0 | `unchanged` | the checklist as of the base commit (`score=<base>:<path>`) |
| 0 | `changed-decided` | the changed version a `[checklist-decision]` entry accepted (`score=HEAD:<path>`, or `none` for a dropped declaration) |
| 3 | `changed-undecided` | none yet: the change is a decision for the advisor, which the module whose work made it spawns ([`role-contracts.md`](../role-contracts.md) > Advisor), and the status is run again on its answer |
| 2 | — | none — a malformed declaration, a declared file not committed, an uncommitted edit to the declaration or the checklist, or no resolvable base; it is repaired and the status run again |

**A change the work makes to the checklist.** A change to the file, or to the declaration that
points at it, has no effect on the audit of that change until the advisor accepts it: the build, whose
work made the change, runs the status and puts a `changed-undecided` change to the advisor
([`role-contracts.md`](../role-contracts.md) > Advisor). Standing entries that disagree with neither
naming the other are a conflict: the record is undecided with `conflict=<ids>`, and a new entry
resolves it. The answer is a `[checklist-decision]` ledger entry
([`decision-ledger.md`](../decision-ledger.md) > *Security-checklist decisions*): `accepted`, carrying
the committed version's blob and non-empty Decision and Grounds lines → the status re-run reports
`changed-decided`; `rejected` → the change is reverted and the status re-run.

## Re-entry

A re-run is a fresh `autoflow-unit-build` spawn by *Unit spawn* above, given the previous report and
the findings it answers. It fixes what the findings name, reads what earlier runs left in the record
directory — their reports and their `local/` stores — and brings the build report up to date, not
rewritten: a row the re-run supersedes is replaced, a new commit adds its lint rows, and the sections
GATE:QUALITY reads carry the current state.

## Header contract

Opted-in targets only; this repository does not opt in. Every executable spec under `tests/**`
declares, in a column-1 comment header, what it is and what it costs — at creation, not
retroactively. The grammar's single definition site is `<autoflow-root>/scripts/test/suite-manifest.sh`, and
`<autoflow-root>/scripts/test/check-suite-manifest.sh` enforces it.

  ```
  # ci-subject: <path-or-glob> [<path-or-glob> ...]
  # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
  ```

- `ci-subject` — the trigger surface. It is a coverage declaration and the selector's input: `<autoflow-root>/scripts/test/select-suites.sh` consumes it to decide which suites a change requires.
- **The grammar is those two fields and nothing else.** The lint admits no other field.
- `budget-secs` — the wall-clock ceiling for one run, **derived from the suite's own CI step duration**, never from local wall-clock. A suite with no CI-measured duration yet declares `SUITE_BUDGET_CEILING_SECS` verbatim. The workflow step's `timeout-minutes` must equal `ceil(budget-secs / 60)`.

**Adopting the contract over existing suites**. *At creation, not retroactively* fixes what a **cycle** owes: no cycle is deficient for a suite it did not create. It does not exempt a suite from selection — `<autoflow-root>/scripts/test/select-suites.sh` BLOCKs every selection while any enumerated suite lacks a usable `ci-subject` header — so a target that opted into the suite plane and whose `tests/**` held suites before it did migrates them once, as target-owned work outside any cycle, before its first BUILD. The target check, a script for setting up the environment (`<autoflow-root>/scripts/preflight/target-check.sh`, leg D7; ADR-0038 D4), names each one, and `bash <autoflow-root>/scripts/test/select-suites.sh --check-headers` lists them on demand. For each listed file:

1. **Suite or helper** — every `*.sh` / `*.bats` under `tests/**` is enumerated, and the runner executes it. A file other suites source is not a spec: it moves under `tests/lib/`, the one exclusion (`suite_is_excluded`), and needs no header.
2. **`ci-subject`** — every path whose change can move the suite's verdict: the scripts it executes, the files it reads or greps, the configuration it parses. The suite's own path is matched without being listed. An uncertain subject takes a directory token (`scripts/`) or a glob (`src/**`) rather than a guess at single files; `**` selects the suite on every change.
3. **`budget-secs`** — `ceil(measured CI step duration × SUITE_BUDGET_HEADROOM_PERCENT / 100)` when the suite already has a CI step duration, otherwise `SUITE_BUDGET_CEILING_SECS` verbatim; a local wall-clock figure is never the source.
4. **CI steps** — where the target's CI runs these suites, `check-suite-manifest.sh` requires one step per suite behind a `select` step that runs `select-suites.sh`, each carrying `id: s-<basename>`, the guard `if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/<file> ')` and `timeout-minutes` equal to `ceil(budget-secs / 60)`. A step that runs several suites is split into one step per suite.

The fields go in the file's leading comment block at column 1, before its first non-comment line. The migration is complete when `select-suites.sh --check-headers` exits `0`, `check-suite-manifest.sh` reports OK and the target check reports `PASS: D7`.

**Naming**: a committed test is subject-named; an issue number does not belong in its file name. A one-shot check is not a committed file, so no naming rule reaches it.

**Leaf rule**: a suite executes its subject, not another suite. Enforced by `<autoflow-root>/scripts/test/check-suite-leaf.sh`.

**Admission**: before creating a suite file at all, answer these two questions.

- Does an existing standing lint already hold the property tree-wide? If so the check is that lint's, not a new arm's.
- Does the defect the check catches surface only *before* deployment — one local run settles it, or it is pinned to this cycle's landed diff? Then it is a run's own check under `<out>/local/`, not a suite file (on a target the default is to add no file at all).
