# BUILD — U4 Build and verify unit

> Phase playbook for BUILD. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

BUILD and AUDIT are one functional unit, U4 Build and verify
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed by
four things only — its goal, its artifact contract, its verification and its loop cap (D2) — and
this file states them. How the unit reaches the goal — what it reads, whether it spawns helpers, how
it divides test and implementation work, how it runs its checks and when it stops iterating — is the
unit agent's, recorded with its grounds in its artifact ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope,
principle 2).

- **Goal**: the design that passed GATE:PLAN, implemented within the cycle's scope, with every
  acceptance criterion verified as the verification design says.
- **Artifact contract**: the commits on the cycle's branch and the build report (*Build report*
  below).
- **Verification**: AUDIT — a fresh Evaluation AI ([AUDIT](audit.md)) that judges test-first from
  the build report and git, then scores the change; the unit never scores its own artifact. U4 ends
  when `audit` PASSes.
- **Loop cap**: a test-first finding or an AUDIT FAIL re-runs the unit with its findings and the
  previous artifacts (*Re-entry* below), max 2× together — the AUDIT FAIL cap
  (`CLAUDE.md` > Flow Control > Regressions).

## Unit spawn

1. **Spawn** one `autoflow-unit-build` (`Agent`, anonymous, no `name`, the model
   `bash scripts/spawn-policy/spawn-policy.sh model unit-build` names) once GATE:PLAN has PASSed. The
   prompt states the goal and names the inputs by path — the two design documents
   (`.autoflow/issue-{N}-feature-design.md`, `.autoflow/issue-{N}-verification-design.md`), the
   acceptance-criterion list (`.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`), the
   decision ledger, the cycle-layer store `.autoflow/issue-{N}-local/`, and each recommendation a
   gate's triage deferred to the build with its subject and finding
   ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) — and the build report's path. On a
   re-entry it also names what the re-entry is for and the material that carries it (*Re-entry*
   below).
2. **Documents.** Injection stays role-minimal and routed via `docs/INDEX.md`: the prompt carries a
   documents line naming the documents the build needs (this file, the affected docs DIAGNOSE
   identified); the unit reads anything further by its own judgment.
3. **Return.** The unit returns the build report's path, the commit SHAs and a one-line summary
   ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format). The orchestrator
   does not receive the report's body.
4. **Route** the return (*Report routing* below).

## What the build owes

These are the rules other documents cite; everything else about the work is the unit's.

- **Scope.** The unit implements every issue acceptance criterion within the cycle's scope — the
  feature design with its `## Scope` section, and the verification design. An AC whose disposition
  is not `automated` ([ARCHITECT](architect.md) > *Test necessity*) is still implemented; only its
  evidence differs. A problem met during the work that the scope does not name is judged under
  [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment* and recorded under `## Scope judgments`. Tests verify correctness; they do not define the
  solution — no hard-coding to test inputs, no special-casing an assertion.
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
  run precedes the implementation commit, and its failure is shown by its log ([AUDIT](audit.md) >
  *Test-first*).
- **Where a test lives.** A `cycle` row's test, a `delivery-check`, a `manual` scenario document and
  an observation record live under `.autoflow/issue-{N}-local/` and are run by their path
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools). A test file
  goes into the target's tree only as the exception: in this repository a `standing` row
  (`automated / standing: <token>`); on a target, a file the unit judges the target should keep,
  listed under `## Test files kept` with its reason and the CI job expected to run it — HANDOFF
  carries that list into the PR body and matches each file against the CI job logs
  ([HANDOFF](handoff.md) > *CI* > *Added test files*). Such a file
  is wired into the target's CI discovery in the same commit.
- **Running tests.** Locally and once, the tests the change requires, the way the target runs them
  (*How a test is run is the target's practice*, *Local verification*); no whole-tree run. A row
  verified with a tool (`manual`, executor `AI: <tool>`) is looked at with that tool and its
  observation record written under the store, ending in one result line — `observation: match` or
  `observation: mismatch — <what differs>` (*The tools the work needs*). A tool neither this
  environment nor the target's procedures provide is reported, never acquired.
- **Comment check.** Before the unit's last commit it reads the comment lines the cycle's diff adds
  (`git diff <base>...HEAD`) against [`submodule-common-rules.md`](../submodule-common-rules.md) >
  Change Surface Rules > *Code comments* — the classes a pattern finds (an issue / PR reference, a
  review round, an acceptance-criterion identifier, another file's path, a change-history marker) and
  those found by reading (a restatement of the code, design discussion, another file's contract,
  commented-out code) — disposes of every hit (removed, rewritten, or kept with the reason the match
  is not the class) and records the result under `## Comment check`. The check is a signal, not a
  gate.
- **Design contradiction.** When the acceptance criteria are themselves mutually unsatisfiable — the
  implementation and the tests each faithful to the design — the unit implements the satisfiable
  subset and records the contradiction in `.autoflow/issue-{N}-green-blocker.md`: the conflicting AC
  IDs, the measurement that reproduces the conflict, and `path:line` anchors at the cycle's commit.
- **Acceptance-criterion change.** Work that shows a criterion defective ([`decision-ledger.md`](../decision-ledger.md)
  > *Acceptance-criterion decisions*) is raised in the report with the criterion, the proposed change
  and the fact that shows the need — never worked around by keeping the criterion's letter
  ([ARCHITECT](architect.md) > *Report routing* > *An acceptance-criterion change raised later in the
  cycle*).
- **Commits.** Every commit follows `CLAUDE.md` > Commit Rules, the lint chain over its staged files
  included, and a manifest-registered source regenerates `setup/manifest.json` in the same commit
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > Derived
  artifacts). The unit does not push.

## Build report

`.autoflow/issue-{N}-build-report.md`. The unit writes it whole on its first run and brings it up to
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

- **The unit's return** → AUDIT ([AUDIT](audit.md)), whose evaluator judges test-first before it
  scores.
- **A `green-blocker` record** → an ARCHITECT unit re-run naming it ([ARCHITECT](architect.md) >
  *Re-entry*), then GATE:PLAN's re-entry re-score and a U4 re-run; consumes the ARCHITECT re-entry
  counter.
- **An acceptance-criterion change** → the advisor ([`role-contracts.md`](../role-contracts.md) >
  Advisor); where the cycle re-enters on its `[ac-decision]` entries is the orchestrator's judgment
  ([ARCHITECT](architect.md) > *Report routing*). No counter.
- **A tool reported missing** → the tool request pause ([`CLAUDE.md`](../../CLAUDE.md) > Flow Control).
- **A lint chain reported `not-run (unexecuted)`** because it is not executable in this checkout and
  no pull-request CI job covering it can be named → a harness-level block: the cycle pauses for the
  operator (`active:false`, `phase:"awaiting-user"`), presented situation-first
  ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > *Human-decision presentation*).

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
| HANDOFF review-triage thin route (`test` / `impl`) | the finding row in the PR's findings file | the auto-resolution window (max 7×) |
| advisor answer or operator override that reaches the build | the `A` / `O` entries | none |

An INTEGRATE failure names the failing check and its output; a HANDOFF CI failure routed `test` /
`impl` names `.autoflow/issue-{N}-ci-failure.md`. The unit fixes what failed, and the cycle runs
forward again to the INTEGRATE check or the CI that failed.

A re-entry passes through AUDIT and GATE:QUALITY on their narrowed re-scores
([AUDIT](audit.md) > *Review-response re-score*; [GATE:QUALITY](gate-quality.md) > *Re-entry
re-score*). A HANDOFF thin route fixes the finding on its own surface and returns to the reviewer
re-review; it does not bring the build report up to date.

The unit reads and writes no `.autoflow/issue-{N}.json` state file, so every counter above is the
orchestrator's own accounting.

## Header contract

Opted-in targets only; this repository does not opt in. Every executable spec under `tests/**`
declares, in a column-1 comment header, what it is and what it costs — at creation, not
retroactively. The grammar's single definition site is `scripts/test/suite-manifest.sh`, and
`scripts/test/check-suite-manifest.sh` enforces it.

  ```
  # ci-subject: <path-or-glob> [<path-or-glob> ...]
  # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
  ```

- `ci-subject` — the trigger surface. It is a coverage declaration and the selector's input: `scripts/test/select-suites.sh` consumes it to decide which suites a change requires.
- **The grammar is those two fields and nothing else.** The lint admits no other field.
- `budget-secs` — the wall-clock ceiling for one run, **derived from the suite's own CI step duration**, never from local wall-clock. A suite with no CI-measured duration yet declares `SUITE_BUDGET_CEILING_SECS` verbatim. The workflow step's `timeout-minutes` must equal `ceil(budget-secs / 60)`.

**Adopting the contract over existing suites**. *At creation, not retroactively* fixes what a **cycle** owes: no cycle is deficient for a suite it did not create. It does not exempt a suite from selection — `scripts/test/select-suites.sh` BLOCKs every selection while any enumerated suite lacks a usable `ci-subject` header — so a target that opted into the suite plane and whose `tests/**` held suites before it did migrates them once, as target-owned work outside any cycle, before its first BUILD. drift-check D7 names each one at install and at PREFLIGHT, and `bash scripts/test/select-suites.sh --check-headers` lists them on demand. For each listed file:

1. **Suite or helper** — every `*.sh` / `*.bats` under `tests/**` is enumerated, and the runner executes it. A file other suites source is not a spec: it moves under `tests/lib/`, the one exclusion (`suite_is_excluded`), and needs no header.
2. **`ci-subject`** — every path whose change can move the suite's verdict: the scripts it executes, the files it reads or greps, the configuration it parses. The suite's own path is matched without being listed. An uncertain subject takes a directory token (`scripts/`) or a glob (`src/**`) rather than a guess at single files; `**` selects the suite on every change.
3. **`budget-secs`** — `ceil(measured CI step duration × SUITE_BUDGET_HEADROOM_PERCENT / 100)` when the suite already has a CI step duration, otherwise `SUITE_BUDGET_CEILING_SECS` verbatim; a local wall-clock figure is never the source.
4. **CI steps** — where the target's CI runs these suites, `check-suite-manifest.sh` requires one step per suite behind a `select` step that runs `select-suites.sh`, each carrying `id: s-<basename>`, the guard `if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/<file> ')` and `timeout-minutes` equal to `ceil(budget-secs / 60)`. A step that runs several suites is split into one step per suite.

The fields go in the file's leading comment block at column 1, before its first non-comment line. The migration is complete when `select-suites.sh --check-headers` exits `0`, `check-suite-manifest.sh` reports OK and drift-check reports `PASS: D7`.

**Naming**: a committed test is subject-named; an issue number does not belong in its file name. A one-shot check is not a committed file, so no naming rule reaches it.

**Leaf rule**: a suite executes its subject, not another suite. Enforced by `scripts/test/check-suite-leaf.sh`.

**Admission**: before creating a suite file at all, answer these two questions.

- Does an existing standing lint already hold the property tree-wide? If so the check is that lint's, not a new arm's.
- Does the defect the check catches surface only *before* deployment — one local run settles it, or it is pinned to this cycle's landed diff? Then it is a `cycle` artifact under `.autoflow/issue-{N}-local/` (a `delivery-check`, or a default `automated` row), not a suite file (in this repository the `standing` categories are ADR-0024 D1's closed list, and on a target the default is to add no file at all).
