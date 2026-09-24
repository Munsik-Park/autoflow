# RED — Test Writing (Test First)

> Phase playbook for RED. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

The Test AI writes test code from the verification design.

**Derivation on entry**. ARCHITECT hands down decisions, not a change table: the file
rows, the per-suite disposition and each oracle's condition clause are **derived here**, by the
roles that open those files anyway. Before step 1 the Test AI finds how the target runs its tests
at the location it executes in — the target's documents (`CLAUDE.md`, a README, a contributing
guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace
structure (a per-package runner, a submodule's own tree) — finds how the target's CI selects tests
for a change (a changed-since selection, a path filter), and judges which of the target's tests
the change requires, recording the grounds and, for every run, the command, the log and its summary line in
its report ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *How a test is run is the target's
practice*); on an opted-in target `bash scripts/test/select-suites.sh`
answers which committed suites the change delta reaches, and a `BLOCK:` line it prints is carried into the report,
never worked around. A
suite the derivation names and the verification design did not anticipate is an ordinary RED input,
**not** a plan defect and **not** acceptance-criterion drift ([GATE:QUALITY](gate-quality.md) > *Completeness —
AC-authority check*); a design **decision** the derivation contradicts is the one thing that still
returns to ARCHITECT, through the existing routes.

```
1. Convert acceptance criteria → test code (only rows typed `automated`). A `cycle` row's test is
   written under `.autoflow/issue-{N}-local/`. A test file goes into the target's test tree only as
   the exception to the no-add default — in this repository, a `standing` row
   (`automated / standing: <token>`); on a target, a file the Test AI judges the target should keep,
   with the reason recorded in its report for the PR body. When adding such a file, check how the
   target's CI discovers tests (a glob in the workflow, an explicit list, a package script); if
   explicit registration is needed, wire it in the same commit, and record the CI job expected to
   run it — HANDOFF step 5 matches that expectation against the CI log.
   - Before committing a test file, the Test AI runs the comment check (REFINE step 1) over the
     lines it adds to that file and disposes of every hit, recording each in its report.
   - Rows typed `existing-coverage` / `none` produce no test.
   - Rows typed `delivery-check` produce a one-shot check under `.autoflow/issue-{N}-local/`, not a
     RED test; RED/GREEN semantics do not apply to them.
2. Run the new tests → every `driving` and `regression` test must FAIL (Red).
   - A `driving` or `regression` test that does not fail means the criterion is already met or the
     test is wrong → investigate.
   - A `characterization` test records existing behavior and may PASS from the start; a passing
     characterization test is the expected outcome, not an investigation trigger.
3. For rows typed `manual` (and `environment-dependent` rows resolved to a manual scenario) → write
   a manual verification scenario document under `.autoflow/issue-{N}-local/` (in this repository a
   `standing` scenario, `manual / standing: <token>`, is committed instead). The document names its
   executor; for an `AI: <tool>` row it states what is opened with the tool, the referenced material
   the result is compared against, and what counts as a match ([ARCHITECT](architect.md) > *Tools*).
4. Hand the test code + scenario document to the Developer AI.
```

**Header contract** (opted-in targets; this repository does not opt in): every executable spec under `tests/**` declares, in a column-1 comment header, what it is and what it costs — at creation, not retroactively. The grammar's single definition site is `scripts/test/suite-manifest.sh`, and `scripts/test/check-suite-manifest.sh` enforces it.

  ```
  # ci-subject: <path-or-glob> [<path-or-glob> ...]
  # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
  ```

- `ci-subject` — the trigger surface. It is a coverage declaration and the selector's input: `scripts/test/select-suites.sh` consumes it to decide which suites a change requires.
- **The grammar is those two fields and nothing else.** The lint admits no other field.
- `budget-secs` — the wall-clock ceiling for one run, **derived from the suite's own CI step duration**, never from local wall-clock. A suite with no CI-measured duration yet declares `SUITE_BUDGET_CEILING_SECS` verbatim. The workflow step's `timeout-minutes` must equal `ceil(budget-secs / 60)`.

**Adopting the contract over existing suites**. *At creation, not retroactively* fixes what a **cycle** owes: no cycle is deficient for a suite it did not create. It does not exempt a suite from selection — `scripts/test/select-suites.sh` BLOCKs every selection while any enumerated suite lacks a usable `ci-subject` header — so a target that opted into the suite plane and whose `tests/**` held suites before it did migrates them once, as target-owned work outside any cycle, before its first RED. drift-check D7 names each one at install and at PREFLIGHT, and `bash scripts/test/select-suites.sh --check-headers` lists them on demand. For each listed file:

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

**Completion**: every `driving` / `regression` test Red (a `characterization` test may be green) + every new committed spec conforming to the header contract above (opted-in targets) + manual scenarios written.
