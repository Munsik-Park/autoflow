# U4 Build and verify — BUILD and AUDIT

> Unit document for U4. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

BUILD and AUDIT are one functional unit, U4 Build and verify
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed by
four things only — its goal, its artifact contract, its verification and its loop cap (D2) — and
this file states them, with the cautions the build is asked to heed and the result it owes. How the
unit reaches the goal — what else it reads, whether it spawns helpers, how it divides test and
implementation work, how it runs its checks and when it stops iterating — is the unit agent's,
recorded with its grounds in its artifact ([`core.md`](../core.md) > Rule Scope,
principle 2).

- **Goal**: the design that passed GATE:PLAN, implemented within the cycle's scope, with every
  acceptance criterion verified as the verification design says.
- **Artifact contract**: the commits on the cycle's branch and the build report (*Build report*
  below).
- **Verification**: AUDIT — a fresh Evaluation AI that judges test-first from the build report and
  git, then scores the change on the rubric of [`evaluation-system.md`](../evaluation-system.md) >
  *Gate rubrics* > AUDIT; the unit never scores its own artifact. U4 ends when `audit` PASSes
  (*Verification — AUDIT* below).
- **Loop cap**: a test-first finding or an AUDIT FAIL re-runs the unit with its findings and the
  previous artifacts (*Re-entry* below), max 2× together — the AUDIT FAIL cap
  (`<autoflow-root>/docs/core.md` > Flow Control > Regressions).
- **Result owed**: the build report's path, the commit SHAs and a one-line summary
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format). The orchestrator
  does not receive the report's body.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](../core.md) > Flow Control.

| Transition | Condition |
|------|------|
| BUILD → AUDIT | the unit returned (`<autoflow-root>/docs/units/build.md` > *Report routing*) |
| AUDIT (test-first) → BUILD | the AUDIT evaluator does not confirm that a `driving` / `regression` test's Red run precedes its implementation commit with its failure shown in its log → it scores nothing, and a unit re-run takes its `## Test-first` section; consumes the AUDIT FAIL counter (Regressions below) (`<autoflow-root>/docs/evaluation-system.md` > AUDIT > *Test-first*; `<autoflow-root>/docs/units/build.md` > *Verification — AUDIT*) |
| BUILD → ARCHITECT | design contradiction — implementation and tests each faithful to the design while the acceptance criteria are mutually unsatisfiable, reproduced by measurement and recorded in `<attempt-dir>/issue-{N}-green-blocker.md` → ARCHITECT unit re-run → GATE:PLAN re-evaluation → BUILD re-entry (cap: Regressions below) |
| BUILD → user | a harness-level block — a lint chain covering a staged file stays `not-run (unexecuted)` because it is neither executable in this checkout nor covered by a nameable pull-request CI job → report situation-first + pause (`active:false`, `phase:"awaiting-user"`) |
| AUDIT entry (security-checklist change) → advisor | `<autoflow-root>/scripts/gate/security-checklist.sh status` exits `3` (the cycle changed the target's declared security checklist and no `[checklist-decision]` entry covers the committed version) → AUDIT is **not** spawned until the advisor's `[checklist-decision]` entry is recorded and the status re-run; `rejected` → the change is reverted first; consumes no re-entry budget (`<autoflow-root>/docs/units/build.md` > *Security checklist*) |
| AUDIT → GATE:QUALITY | security audit PASS + its recommendations triaged (no attempt open) |

## Unit spawn

- **The spawn.** One `autoflow-unit-build` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-build` names) once GATE:PLAN has PASSed. The
  prompt states the goal and names the inputs by path — the two design documents
  (`<attempt-dir>/issue-{N}-feature-design.md`, `<attempt-dir>/issue-{N}-verification-design.md`), the
  acceptance-criterion list (`<attempt-dir>/issue-{N}-analysis.md` > `## Acceptance criteria`), the
  decision ledger, the cycle-layer store `<attempt-dir>/issue-{N}-local/`, and each recommendation a
  gate's triage deferred to the build with its subject and finding
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) — and the build report's path. On a
  re-entry it also names what the re-entry is for and the material that carries it (*Re-entry*
  below).
- **Documents.** The unit's agent definition carries this file with the rest of its guidance
  ([`core.md`](../core.md) > Context Injection); the prompt names the affected docs DIAGNOSE
  identified by path, and the unit reads anything further by its own judgment. The return is routed
  (*Report routing* below).

## What the build owes

These are the rules other documents cite; everything else about the work is the unit's.

- **Scope.** The unit implements every issue acceptance criterion within the cycle's scope — the
  feature design with its `## Scope` section, and the verification design. An AC whose disposition
  is not `automated` ([U3 Design](design.md) > *Test necessity*) is still implemented; only its
  evidence differs. A problem met during the work that the scope does not name is judged under
  [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment* and recorded under `## Scope judgments`. Tests verify correctness; they do not define the
  solution — no hard-coding to test inputs, no special-casing an assertion. Once the scope is
  implemented and verified, a further change the unit judges useful beyond the scope and the problems
  its scope judgments include is recorded under `## Scope judgments`, not made.
- **Test-first (TDD).** Every `driving` and `regression` row's test is written before the
  implementation it verifies and seen failing; a `characterization` test may pass from the start. The
  order of the work — a failing run in the working tree first, or a test commit first — is the
  unit's. The result owed is the Red run's evidence (*Build report* > `## Test-first`). Cautions:
  - A test that passes from the start is not Red evidence. Look again at whether it checks the
    required behavior, and record that judgment in the report.
  - The Red run's failure is readable in its log, the exit status included.
  - `## Run record` holds one row per verification row — its latest run. The Red run goes in
    `## Test-first` only.

  ADR-0025 D3's test-first rule is judged by the AUDIT evaluator from this report and git: the Red
  run precedes the implementation commit, and its failure is shown by its log
  ([`evaluation-system.md`](../evaluation-system.md) > AUDIT > *Test-first*).
- **Where a test lives.** A `cycle` row's test, a `delivery-check`, a `manual` scenario document and
  an observation record live under `<attempt-dir>/issue-{N}-local/` and are run by their path
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools). A test file
  goes into the target's tree only as the exception: in this repository a `standing` row
  (`automated / standing: <token>`); on a target, a file the unit judges the target should keep,
  listed under `## Test files kept` with its reason and the CI job expected to run it — HANDOFF
  carries that list into the PR body with the CI job that actually ran each file
  ([U6 Delivery](delivery.md) > *CI* > *Added test files*). Such a file
  is wired into the target's CI discovery in the same commit.
- **Running tests.** Locally and once, the tests the change requires, the way the target runs them
  (*How a test is run is the target's practice*, *Local verification*); no whole-tree run. A row
  verified with a tool (`manual`, executor `AI: <tool>`) is looked at with that tool and its
  observation record written under the store, ending in one result line — `observation: match` or
  `observation: mismatch — <what differs>` (*The tools the work needs*). A tool neither this
  environment nor the target's procedures provide, or what using a tool the environment has lacks, is
  reported — naming what is missing, not the output the tool would give — and never acquired.
- **Comment check.** Before the unit's last commit it reads the comment lines the cycle's diff adds
  (`git diff <base>...HEAD`) against [`submodule-common-rules.md`](../submodule-common-rules.md) >
  Change Surface Rules > *Code comments* — the classes a pattern finds (an issue / PR reference, a
  review round, an acceptance-criterion identifier, another file's path, a change-history marker) and
  those found by reading (a restatement of the code, design discussion, another file's contract,
  commented-out code, and content none of the cases under *What a comment carries* admits, such as a
  value, count or list copied from another file) — disposes of every hit (removed, rewritten, or
  kept with the reason the match is not the class) and records the result under `## Comment check`.
  The check is a signal, not a gate.
- **Design contradiction.** When the acceptance criteria are themselves mutually unsatisfiable — the
  implementation and the tests each faithful to the design — the unit implements the satisfiable
  subset and records the contradiction in `<attempt-dir>/issue-{N}-green-blocker.md`: the conflicting AC
  IDs, the measurement that reproduces the conflict, and `path:line` anchors at the cycle's commit.
- **Acceptance-criterion change.** Work that shows a criterion defective ([`decision-ledger.md`](../decision-ledger.md)
  > *Acceptance-criterion decisions*) is raised in the report with the criterion, the proposed change
  and the fact that shows the need — never worked around by keeping the criterion's letter
  ([U3 Design](design.md) > *Report routing* > *An acceptance-criterion change raised later in the
  cycle*).
- **Commits.** Every commit follows `<autoflow-root>/docs/core.md` > Commit Rules, the lint chain over its staged files
  included. The unit does not push.

## Dividing the work

A recommendation, not a rule: whether the unit divides its work, and how, stays its own, and the
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
  own definition —
  `<autoflow-root>/docs/core.md` > Commit Rules, `<autoflow-root>/docs/submodule-common-rules.md` >
  Change Surface Rules > *Lint chain on the staged surface* and `<autoflow-root>/docs/role-common-rules.md` >
  Bash Execution Mode — since a `general-purpose` helper has no AutoFlow definition of its own
  (`<autoflow-root>/docs/core.md` > Context Injection). Requirements of two areas that
  cannot both hold take the design-contradiction path above; a design point two areas meet
  differently is a decision point.
- **A deterministic run is a command, not a context.** Running tests, lint and builds, and
  committing, take no judgment; what they cost is their output carried in the context that reads
  it. A run goes through a command that bounds its time, keeps the full output in a log under the
  cycle-layer store, and prints the exit status, the summary line, the names of failing tests, the
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

`<attempt-dir>/issue-{N}-build-report.md`. The unit writes it whole on its first run and brings it up to
date on a re-entry that passes through AUDIT and GATE:QUALITY (*Re-entry* below). Every section
below is present; a section with nothing to record says `none`.
The five record sections are tables, one row per item, in any column order; the column a reader
needs is named below.

| Section | Holds | Read by |
|---|---|---|
| `## Test-first` | one row per `driving` / `regression` test: `Issue AC`, `Test` (its path), `Red at` (the commit the failing run was made at), `Red log`, `Red line` (the summary line read from that log), `Red exit` (the run's non-zero exit status, shown in its log), `Impl commit` (the commit that makes it pass) | AUDIT (*Test-first*) |
| `## Run record` | one row per `automated` or `delivery-check` verification row, its latest run: `Issue AC`, `Command`, `Log`, `Summary line`, `Result` (`pass` / `fail`) | GATE:QUALITY `Test coverage`; HANDOFF (PR body) |
| `## Manual checklist` | one row per `manual` row: `Issue AC`, `Executor` (`AI: <tool>` or `person`), `Record` (the observation record's path, or `delegated to user`) | GATE:QUALITY `Test coverage`; HANDOFF (PR body) |
| `## Maintained documents` | one line per document the change updated, ``- `<path>` — <what changed>``, or `- none — <reason>` | GATE:QUALITY `Doc updates` |
| `## Lint` | one row per chain per commit this cycle makes on the branch: `Commit` (≥ 7 hex), `Chain`, `Outcome` (the lint outcome word, a `not-run` with its reason class in parentheses); a commit another actor makes on the branch adds its own rows | GATE:QUALITY `Commit conventions` |
| `## Scope judgments` | each scope judgment the work made ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment*) | GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Out-of-scope observations — guard / boundary logic touched` | each behavior-changing suggestion the unit rejected whose subject is validation, a guard, path / root resolution, an input or output boundary or error handling, and each one it judged directly related — its `path:line` and the behavior it would change | GATE:QUALITY (`refine_observations`) |
| `## Comment check` | the line `comment-ratio: <added comment lines>/<added lines> (<percent>)`, then one line per hit — `path:line`, class, disposition | GATE:QUALITY (*Code comments in a target*) |
| `## Test files kept` | each test file added to the target's tree, its reason and the CI job expected to run it | GATE:QUALITY `Test quality`; HANDOFF (PR body; *Added test files*) |

Anything else the unit records — how it divided the work, the checks it chose to run and what they
found — is its own, written where it judges useful.

## Report routing

- **The unit's return** → AUDIT (*Verification — AUDIT* below), whose evaluator judges test-first
  before it scores.
- **A `green-blocker` record** → an ARCHITECT unit re-run naming it ([U3 Design](design.md) >
  *Re-entry*), then GATE:PLAN's re-entry re-score and a U4 re-run; consumes the ARCHITECT re-entry
  counter.
- **An acceptance-criterion change** → the orchestrator's decision, the advisor's where the
  report's grounds do not settle it; where the cycle re-enters on its `[ac-decision]` entries is the orchestrator's judgment
  ([U3 Design](design.md) > *Report routing*). No counter.
- **A tool, or what using one lacks, reported missing** → the tool request pause ([`core.md`](../core.md) > Flow Control).
- **A lint chain reported `not-run (unexecuted)`** because it is not executable in this checkout and
  no pull-request CI job covering it can be named → a harness-level block: the cycle pauses for the
  operator (`active:false`, `phase:"awaiting-user"`), presented situation-first
  ([`core.md`](../core.md) > Execution Principles > *Human-decision presentation*).

## Verification — AUDIT

One fresh Evaluation AI (`autoflow-evaluator`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model audit` names) judges test-first and scores the
change on the rubric of [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > AUDIT.
Its agent definition carries that document. Its spawn prompt carries the security-checklist record
line (*Security checklist* below).

- **Test-first not confirmed** → the evaluator scores nothing and returns its `## Test-first`
  section. The orchestrator does not re-spawn the evaluator: a BUILD unit re-run takes the section
  (*Re-entry* below), consuming the AUDIT FAIL counter.
- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → immediate block) → recommendation triage
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) → GATE:QUALITY.
- **FAIL** → a BUILD unit re-run with the report's failed items (*Re-entry* below), then a
  re-evaluation (max 2×, the counter shared with test-first findings). Third FAIL → human.

### Security checklist

The target's own: AutoFlow ships no checklist and names no item. A target declares its checklist
in the target-owned scaffold `.claude/autoflow.local.json`
(`{"audit":{"security_checklist":"<repository-relative path>"}}`). At AUDIT entry the orchestrator
runs `bash <autoflow-root>/scripts/gate/security-checklist.sh status --ledger <attempt-dir>/issue-{N}-ledger.md` and
acts on its one record line:

| Exit | Verdict | What follows |
|------|---------|-------------|
| 0 | `none-declared` | AUDIT is spawned; no checklist — the five items are scored from the change alone |
| 0 | `unchanged` | AUDIT is spawned; it reads the checklist as of the cycle's base commit (`score=<base>:<path>`) |
| 0 | `changed-decided` | AUDIT is spawned; it reads the changed version a `[checklist-decision]` entry accepted (`score=HEAD:<path>`, or `none` for a dropped declaration) |
| 3 | `changed-undecided` | **[MUST]** AUDIT is not spawned: the orchestrator hands the change to the advisor with a request written situation-first ([`role-contracts.md`](../role-contracts.md) > Advisor) and re-runs the status on its answer |
| 2 | — | nothing — a malformed declaration, a declared file not committed, an uncommitted edit to the declaration or the checklist, or no resolvable base; repair it and re-run |

**A change the cycle makes to its checklist.** A change to the file, or to the declaration that
points at it, has no effect on that cycle's AUDIT until it is accepted — by the advisor first, and
by the operator's override, recorded as an entry that names the advisor's (`- Overrides: A<n>`).
Standing entries that disagree with neither naming the other are a conflict: the record is
undecided with `conflict=<ids>`, and a new entry resolves it. The answer is a `[checklist-decision]`
ledger entry ([`decision-ledger.md`](../decision-ledger.md) > *Security-checklist decisions*):
`accepted`, carrying the committed version's blob and non-empty Decision and Grounds lines under
the authority `advisor decision` on an `A<n>` entry (an override: `operator decision` on an `O<n>`
entry) → the status re-run reports `changed-decided`;
`rejected` → the change is reverted and the status re-run. The decision consumes no re-entry budget.

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-build` by *Unit
spawn* above, whose prompt names what the re-entry is for, the material that carries it, and the
build report so far. On a re-entry that passes through AUDIT and GATE:QUALITY, the report is
brought up to date, not rewritten: a row a re-entry supersedes is replaced, a new commit adds its lint
rows, and the sections GATE:QUALITY reads carry the current state.

| Re-entry | Material named | Counter |
|---|---|---|
| AUDIT test-first finding | the AUDIT report's `## Test-first` section | AUDIT FAIL (max 2×, shared) |
| AUDIT FAIL | the AUDIT report and its failed items | AUDIT FAIL (max 2×, shared) |
| GATE:QUALITY FAIL routed `test` / `impl` | the evaluation report and its failed items | GATE:QUALITY FAIL (max 3×) |
| a `test` / `impl` recommendation attempt at AUDIT or GATE:QUALITY | the recommendation's subject and finding | the attempt window (max 7×) |
| REVIEW review-triage thin route (`test` / `impl`) | the finding row in the PR's findings file | the auto-resolution window (max 7×) |
| advisor answer or operator override that reaches the build | the `A` / `O` entries | none |

An INTEGRATE failure names the failing check and its output; a HANDOFF CI failure routed `test` /
`impl` names `<attempt-dir>/issue-{N}-ci-failure.md`. The unit fixes what failed, and the cycle runs
forward again to the INTEGRATE check or the CI that failed.

A re-entry passes through AUDIT and GATE:QUALITY on their narrowed re-scores
([`evaluation-system.md`](../evaluation-system.md) > AUDIT > *Review-response re-score*; > GATE:QUALITY > *Re-entry re-score*). A REVIEW thin route fixes the finding on its own surface and returns to the reviewer
re-review; it does not bring the build report up to date.

The unit reads and writes no `<attempt-dir>/issue-{N}.json` state file, so every counter above is the
orchestrator's own accounting.

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

**Adopting the contract over existing suites**. *At creation, not retroactively* fixes what a **cycle** owes: no cycle is deficient for a suite it did not create. It does not exempt a suite from selection — `<autoflow-root>/scripts/test/select-suites.sh` BLOCKs every selection while any enumerated suite lacks a usable `ci-subject` header — so a target that opted into the suite plane and whose `tests/**` held suites before it did migrates them once, as target-owned work outside any cycle, before its first BUILD. The PREFLIGHT target check (`<autoflow-root>/scripts/preflight/target-check.sh`, leg D7) names each one, and `bash <autoflow-root>/scripts/test/select-suites.sh --check-headers` lists them on demand. For each listed file:

1. **Suite or helper** — every `*.sh` / `*.bats` under `tests/**` is enumerated, and the runner executes it. A file other suites source is not a spec: it moves under `tests/lib/`, the one exclusion (`suite_is_excluded`), and needs no header.
2. **`ci-subject`** — every path whose change can move the suite's verdict: the scripts it executes, the files it reads or greps, the configuration it parses. The suite's own path is matched without being listed. An uncertain subject takes a directory token (`scripts/`) or a glob (`src/**`) rather than a guess at single files; `**` selects the suite on every change.
3. **`budget-secs`** — `ceil(measured CI step duration × SUITE_BUDGET_HEADROOM_PERCENT / 100)` when the suite already has a CI step duration, otherwise `SUITE_BUDGET_CEILING_SECS` verbatim; a local wall-clock figure is never the source.
4. **CI steps** — where the target's CI runs these suites, `check-suite-manifest.sh` requires one step per suite behind a `select` step that runs `select-suites.sh`, each carrying `id: s-<basename>`, the guard `if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/<file> ')` and `timeout-minutes` equal to `ceil(budget-secs / 60)`. A step that runs several suites is split into one step per suite.

The fields go in the file's leading comment block at column 1, before its first non-comment line. The migration is complete when `select-suites.sh --check-headers` exits `0`, `check-suite-manifest.sh` reports OK and the target check reports `PASS: D7`.

**Naming**: a committed test is subject-named; an issue number does not belong in its file name. A one-shot check is not a committed file, so no naming rule reaches it.

**Leaf rule**: a suite executes its subject, not another suite. Enforced by `<autoflow-root>/scripts/test/check-suite-leaf.sh`.

**Admission**: before creating a suite file at all, answer these two questions.

- Does an existing standing lint already hold the property tree-wide? If so the check is that lint's, not a new arm's.
- Does the defect the check catches surface only *before* deployment — one local run settles it, or it is pinned to this cycle's landed diff? Then it is a `cycle` artifact under `<attempt-dir>/issue-{N}-local/` (a `delivery-check`, or a default `automated` row), not a suite file (in this repository the `standing` categories are ADR-0024 D1's closed list, and on a target the default is to add no file at all).
