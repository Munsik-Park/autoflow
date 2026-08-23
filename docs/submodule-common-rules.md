# Sub-Repository Common Rules

> Shared rules that apply to all sub-repositories in a multi-repo AutoFlow project.

---

## Applicability

These rules apply to every sub-repository (e.g., backend, frontend, infra, docs) that participates in the AutoFlow lifecycle under a central orchestrator.

---

## Required Files

Every sub-repository **must** contain:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Sub-repo operating manual |
| `.gitignore` | Must include `.autoflow/issue-*.json` |
| `README.md` | Project-specific documentation |

---

## AutoFlow State Ownership

AutoFlow state lives in the host (orchestrator) repository under `.autoflow/issue-{N}.json` — one file per issue. Sub-repos do not own AutoFlow state. A sub-repo that finds an `.autoflow/` directory locally should treat it as residual from a misconfigured run; the canonical state is in the host repo.

The host's hook (`.claude/hooks/check-autoflow-gate.sh`) reads the state file and computes pass/fail directly from raw `scores`. Sub-repo AIs do not write to the state file — they receive instructions through `SendMessage` from the orchestrator.

---

## Submodule URL & Pointer Policy

Applies to host repositories that operate a **host-private fork** as the submodule source — i.e., the fork carries host-private changes that are **not** bound for the upstream repository. The host repo's submodule pointer therefore lives in fork commits, not upstream commits.

In a multi-repo instance of this framework, the host's direct submodule is `services` = **`<org>/<service-host>`** (host-operated nesting repo). Nested `librechat` (`<org>/<submodule>` fork) and `librechat-deploy` are submodules **inside llmroute**; they follow the same host-operated fork model but at the llmroute level. (`claude-autoflow` itself no longer nests `services` — it was detached in #798 and is now single-repo; the example is illustrative of a multi-repo consumer.)

### URL — `.gitmodules` fixed to the host-operated fork

```
.gitmodules submodule.<name>.url → <host-operated fork URL>   (e.g., <org>/<service-host>)
```

- `.gitmodules` is **never modified** in a PR. PR diffs must not touch `.gitmodules` (URL is fixed at framework init).
- Local fork URL override is unnecessary: the URL is the fork to begin with.
- `setup/init.sh` substitutes the URL when the framework is propagated to another project, so each operator inherits the same model with their own fork.

### Pointer SHA — host main reachability

```
host main HEAD's submodule pointer SHA  →  reachable in the host-operated fork
```

- A commit that exists only on a fork **feature branch** (not yet merged into the fork's `main`) **must not** appear as the submodule pointer on host `main`. Fork feature branches can be deleted or force-pushed at any time; relying on them is a stale-pointer footgun.
- **Dev branch exception**: while a host PR's dev branch is open, the submodule pointer may temporarily reference a fork feature-branch SHA (this is normal for in-progress work). Reachability against fork `main` is enforced at host-`main`-merge time.

### Multi-developer concurrent work

- `.gitmodules` is **never** modified — URL stays fixed.
- Each developer commits **only the submodule pointer** for their issue's dev branch.
  - The "developer" who commits that pointer on the host dev branch is the **orchestrator** — the host `services` gitlink is a host-file change it owns (see [`CLAUDE.md`](../CLAUDE.md) > Commit Ownership > Submodule pointer bump); the two rules name the same actor, not two.
- No per-developer local URL override is required (the URL is already the fork).

### Sub-repo cycle close-out

When a sub-repo work cycle is complete:

1. Merge the fork feature branch (e.g., `feat/<issue>-<topic>`) into the fork's `main`.
2. Reconcile the host's submodule pointer to this cycle's sub-repo merge commit on fork `main` (in the host PR's dev branch, before host PR merge). **[MUST]** When several cycles are in external review at once, reconcile **against the current `origin/main`**, not the branch's stale fork point: host-PR merges (one at a time) advance `main`'s pointer, so a stale-base bump leaves the host PR `CONFLICTING` and fails the Jenkins `pr-merge` build `NOT_MERGEABLE`. Resolve by fork ancestry — if this cycle's merge commit (`TARGET`, the llmroute PR's merge commit; nested librechat/deploy pointer reconcile inside llmroute is llmroute's internal concern) is a **descendant** of the current `main` pointer, set the dev gitlink to `TARGET` first (`git -C services checkout <TARGET>; git add services; git commit`) **then** merge `origin/main` (with the dev pointer at `TARGET` ⊇ `MAIN`, the submodule stays at `TARGET`, no content conflict); if `main`'s pointer is a descendant (a regression) or the two diverge, **escalate to the operator**. **[MUST]** The end-state pointer must equal `TARGET` — verify `git ls-tree HEAD services == TARGET` before pushing (a bare `git merge origin/main` from a `BASE` dev pointer resolves the gitlink to `MAIN`, failing the operator's pointer-equality reconcile check). Full procedure + the post-reconcile mergeable/Jenkins gate: [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight.
3. The fork feature branch may then be deleted; the pointer SHA is preserved on fork `main`.

This is the lifecycle that makes the **Pointer SHA — host main reachability** rule hold without requiring branch-protection rules on every fork feature branch.

### Framework propagation

Operators initializing this framework on a different project run `setup/init.sh`, which substitutes the submodule URL to point at the operator's own fork (same model — host-operated fork, host-private changes allowed). The Pointer SHA rule is unchanged: host `main` always points at a commit reachable in the operator's fork.

### Transition note (issue #91)

The original wording in `docs/autoflow-guide.md > HANDOFF > Merge Sequencing` / `docs/external-review-sequencing.md` was authored under issue #92 cycle 4 with an "upstream merge" framing (i.e., sub-repo PR → `danny-avila/LibreChat:main`). The services-nesting refactor (2026-06-27) updated the host-level sub-repo identity: the host's direct submodule is now `services` = `<org>/<service-host>`. `docs/external-review-sequencing.md` has been reconciled to reflect llmroute as the `SUBREPO` target. This section remains the authoritative pointer URL & pointer SHA policy. **As of #798 (2026-07) `claude-autoflow` carries zero submodules and is single-repo — the `services` submodule was detached; the present-tense wording above is a historical record of the pre-#798 nesting era and applies to a multi-repo consumer operating such a host-private fork.**

---

## CLAUDE.md Requirements

Each sub-repo's `CLAUDE.md` must define:

### 1. Repo Identity
```markdown
## This Repository
- **Name**: <repo-name>
- **Role**: [backend / frontend / infra / docs / ...]
- **Orchestrator**: <org>/<host-repo>
```

### 2. Tech Stack & Commands
```markdown
## Development Commands
- **Build**: `<build command>`
- **Test**: `<test command>`
- **Lint**: `<lint command>`
- **Format**: `<format command>`
```

### 3. Scope Boundaries
```markdown
## Scope
This AI agent may only modify files within this repository.
For cross-repo changes, raise a Discussion to the Orchestrator.
```

### 4. AutoFlow Reference
```markdown
## AutoFlow
This repository follows the AutoFlow lifecycle defined in:
<org>/<host-repo>/CLAUDE.md

All AutoFlow phases, evaluation criteria, and gate rules apply.
```

---

## Agent Behavior Rules

### DO
- Follow the AutoFlow phases in order
- Run tests before marking the TDD cycle complete
- Use the Discussion Protocol for ambiguities
- Reference the orchestrator's CLAUDE.md for process questions

### DO NOT
- Skip the evaluation gate (GATE:QUALITY)
- Modify files in other repositories
- Push directly to `main`
- Ignore evaluation feedback during revision (REVISION)
- Inline document body, full file text, or raw verbose test output in reports — see Reporting Format below

---

## Change Surface Rules

Every changed line must trace to the issue's acceptance criteria or the agreed plan. The scope of a cycle is exactly what the issue asked for — adjacent improvements belong to a separate issue.

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which AC or plan item requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk without an AC ID in its rationale is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC requires the change.
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the current AC needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the AC. A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. Comment only where the logic isn't self-evident.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC explicitly requires it.

### Derived artifacts
- **[MUST]** `setup/manifest.json` is a **derived member of the change surface**
  whenever the surface includes a manifest-registered source. If
  `git diff --name-only <base>...HEAD` intersects
  `jq -r '.artifacts[].source' setup/manifest.json` on any path other than
  `setup/manifest.json` itself, the manifest must be regenerated
  (`setup/gen-manifest-hashes.sh`) and staged in the **same commit** — its
  updated `sha256` rows trace to that same edit, so they do not violate the
  trace rule. CI `AC2e` (`tests/plugin/verify-install-into-target.sh`) fails the
  PR otherwise (#798/#799/#800 precedent).

### Lint chain on the staged surface
- **[MUST]** When the staged change surface contains at least one file covered by the target repository's lint chain, the committing role runs that chain over the staged files and confirms zero errors attributable to them **before** the commit is made — for every chain the discovery order below converts into a command. Auto-fixable formatting is applied and staged in the same commit: the fix traces to the same edit, so it does not violate the trace rule (identical reasoning to **Derived artifacts**).

**Chain discovery** — deterministic order, first hit wins. Each route must yield a command string the committing role can invoke in the working checkout; a route that names a lint but yields no such command is not a hit, and discovery continues.

1. the target repo's `CLAUDE.md` > Development Commands `Lint` / `Format` entries — the entry *is* the command;
2. the target repo's pull-request CI lint steps, restricted to steps that carry a `run:` body — the `run:` body is the command, taken verbatim and executed from the repository root.

**Execution trust boundary** — **[MUST]** before running a route-2 command, the committing role confirms the `run:` body is unchanged versus the baseline branch (`main` / the merge-base) for the current branch; a body altered in this branch is not executed — report `not-run` naming the step and the reason `modified-in-branch`, deferring the unreviewed change to code review rather than running it sight-unseen. `modified-in-branch` classifies as `ci-deferred` when a covering pull-request job can be named — the `pull_request` run executes this branch's own workflow body, which is the body under review — and as `unexecuted` when none can (**`not-run` reason classes** below). Route 2 grants execution of the discovered lint/check command exactly as written — a read-only check, not licence to run any other step, argument, or command it happens to name.

**Conversion limit** — a CI lint step whose work is performed by a third-party action reference (`uses:` with no `run:` body) yields no local command and is therefore not convertible. "Not a hit" in **Chain discovery** governs which route supplies the command, not whether the step is reported: discovery moves on to the next route, and the rejected step remains a discovered chain the report must dispose of. A discovered chain the conversion limit rejects imposes no blocking requirement, only a reporting one: when every discovered lint is non-convertible the committing role does not block the commit, it reports `not-run` naming the non-convertible step, so the unexecuted check stays visible instead of silently passing. The commit-time and gate-time obligations are separate, and not blocking the commit is not clearing the gate: the rejection yields the reason class `ci-deferred` where a covering pull-request job can be named and `unexecuted` where none can, and VALIDATE clears only the former (**`not-run` reason classes** below). Making an action-only chain locally executable belongs to the target repository's ops and is outside this rule's authority.

**Scoping** — run the chain restricted to the staged files where the chain supports scoping. Where the chain only runs whole-tree, run it whole-tree and require that no reported error names a staged file; pre-existing errors on untouched files are not this cycle's surface (**Surrounding code**).

**Outcome vocabulary** — the report carries one word per discovered chain, and the word set is total over the reachable states:

- `clean` — the chain ran and reported nothing attributable to the staged files;
- `fixed-and-staged` — the chain ran and reported fixable findings, and the fixes are in this commit;
- `detected` — the chain ran and reported findings attributable to the staged files that were not auto-fixed; the commit does not proceed until they are resolved;
- `not-run` — a covered file was staged and a chain was discovered, but the chain did not execute; the word attaches to the fact of non-execution, regardless of why it did not execute, and the report names the chain, the reason, and exactly one reason class from **`not-run` reason classes** below;
- `not-applicable` — discovery found no lint chain by either route, or no staged file is covered by any discovered chain.

**`not-run` reason classes** — **[MUST]** every `not-run` line carries exactly one of two classes. The class, not the word, decides whether VALIDATE's lint-chain step clears the chain:

- `ci-deferred` — the chain is not executable at the commit boundary by rule (non-convertible under the **Conversion limit**, or withheld by the **Execution trust boundary** as `modified-in-branch`) **and** a named pull-request CI job runs that same chain over the staged files. VALIDATE clears it as a deferral;
- `unexecuted` — anything else: convertible but not run, unavailable in the checkout, or no covering pull-request job can be named. VALIDATE does not clear it.

- **[MUST]** Fail-closed default: a chain whose reason class cannot be established is `unexecuted`. The permissive class is the one earned by evidence; the absence of evidence yields the blocking one.

A `ci-deferred` deferral is discharged at HANDOFF step 5, which confirms the PR's check rollup is green — at least one check present and every element green (`scripts/handoff/confirm-ci-green.sh`). That confirmation is over the rollup, not a per-job execution guarantee: nothing in it re-checks that the named covering job appears in the rollup, so the producer's covering-job citation and trigger evidence (Reporting Format item 5) are what tie the deferral to a job that actually runs, and VALIDATE re-derives them before clearing.

- **[MUST]** A chain that did not execute is reported `not-run`, never `clean` — a chain the committing role did not run is not evidence that the staged files are clean, and reporting it as such is the exact claim this rule exists to make re-derivable.

**Evidence anchor** — the committing role's report carries the lint outcome as an anchor class of Reporting Format item 5, whose single-anchor requirement it satisfies as a per-chain enumeration (form and cardinality there).

### REFINE scope
REFINE applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. The refactor tool's findings are advisory, not licence to expand the change surface.

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` item is scored against this section: prefer the smallest sufficient change that resolves the confirmed problem within the diagnosed scope. The diagnosed scope is the cycle's acceptance criteria plus the confirmed cause recorded in DIAGNOSE (`.autoflow/issue-{N}-phase-*.md`) — a boundary, not a line count. A correctly scoped change is not scored down for being larger than a symptom patch.

A high-scoring change:
- resolves the confirmed cause, not only the reported symptom
- stays inside the module or component that owns that cause
- includes the local cleanup the fix itself requires — the code and symbols this change renders unreachable or unused, removed in the same commit, because the fix is what makes them necessary and they answer "which AC or plan item requires this?"; cleanup merely noticed nearby does not qualify (**Surrounding code**), and **Orphans from this cycle** is the symbol-removal instance of this same test, not its limit
- leaves every surface outside the issue untouched — behavior, APIs, configuration, and documentation are examples of such a surface, not the boundary

The item fails when a hunk traces to neither an AC nor the confirmed cause — "I noticed it while I was here" cleanup (**Surrounding code**) or depth creep beyond what the AC needs (**Over-engineering guard**) — regardless of code quality. It fails symmetrically when the change is too narrow to resolve the confirmed cause: a change that leaves the confirmed cause in place is not sufficient, and does not score well for being small.

---

## Reporting Format

When a teammate reports to the orchestrator (or to another teammate via `SendMessage`), the message must follow this shape to keep token cost bounded (see host [`CLAUDE.md`](../CLAUDE.md) > Cost Control). This format governs **AI↔AI / AI↔orchestrator** messages, whose audience is an AI that re-derives anchors deterministically. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in host [`CLAUDE.md`](../CLAUDE.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite `.autoflow/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report jest summary line (e.g., "Tests: 147 passed, 147 total") + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time — stale working-memory snapshots are a known incident pattern.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the exact `Tests: N passed, N total` (or equivalent) summary line, with the command that produced it
   - file state → `path:line` plus the verbatim content of that line
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the discovery order found, the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked plus the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*) and the unexecuted step's identity (`path:line` of the workflow file and the step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this diff — the workflow's `on: pull_request` entry, and either no `paths:` filter or one whose patterns match a staged file; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-applicable` → that word alone, naming which discovery routes came up empty. A report citing one chain where discovery found several is malformed, not compliant.
   - inherited Green (the step did not execute some or all of the suite set) → the **register-entry citation** in place of a self-produced suite summary, **per inherited suite**: the suite's repo-relative path plus the source `green-tree` entry's heading (cycle and `runner`) and that entry's `head` and `result`. Since inheritance is now decided per suite, one citation for a whole set is malformed the same way one lint-chain line is where discovery found several — the enumeration as a whole stands as this item's one anchor. The reported outcome word is `inherited` when nothing executed and `mixed` when some suites inherited and the rest executed and passed, never `passed`; a re-typed summary line on an inherited suite is a contract violation. See [`autoflow-guide.md`](autoflow-guide.md) > VERIFY > *Green-tree register*.

   Anchors must be deterministically re-derivable by the orchestrator (`git show <SHA>` / re-running the test command / `git show HEAD:<file>`). Reports without an anchor are rejected, not interpreted.

6. **Facilitator return (deliberation phases)**: the facilitation `Workflow` returns one structured result, specific to the phase — ARCHITECT: `{ verdict: CONVERGED|AC_CHANGE|ESCALATE, acReason, acChange, artifact paths, ledger, summary }`; VERIFY: `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI, ledger, summary }`. It carries no round-by-round messages and no duplicate dual reports. Shape and rationale: [host `CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation and [`teammate-contracts.md`](teammate-contracts.md) > Facilitator > Return Contract.

---

## Testing Standards

Every sub-repo must maintain:

1. **Unit tests** for business logic
2. **Integration tests** for API endpoints / component interactions
3. **No broken tests on `main`** — all tests must pass before merge
4. **Test commands documented** in `CLAUDE.md` so Test AI can run them
5. **Cost-aware execution**: invoke jest with `--silent --reporters=summary` when running for a teammate report (verbose output is for local debugging only). Coverage reports use the summary reporter; per-file HTML reports stay on disk and are referenced by path, not pasted.
6. **SIGPIPE-safe assertion pipes**: under `set -o pipefail`, do not pipe a *streaming/context* producer (`grep -A/-B/-C`, and awk/section-extractor functions whose buffered output is still flushing when the consumer exits, and other producers that keep writing past the match) directly into a *short-circuiting* consumer (`grep -q`, `grep -m`, `head`) when the pipeline's exit status is the assertion verdict. The consumer's early exit can send the producer `SIGPIPE` (exit 141), which `pipefail` promotes to a pipeline failure — flipping a logically-passing assertion to a flaky FAIL (`grep: write error: Broken pipe`). Capture the producer first, then feed the captured string to the consumer **without a pipe** — `ctx=$(<producer>); grep -q <pattern> <<<"$ctx"` — or drop `-q` so the consumer reads to EOF. The capture and the here-string remove two different producers, and both removals are needed: capturing removes the *streaming* producer, but a `printf` of the captured string piped into a short-circuiting consumer is itself a producer writing into a pipe whose reader may exit first, so that form is not a repair (issue #114). The governing condition is unwritten producer bytes at consumer exit, not any particular pipe-capacity threshold — and the capacity a given pipe was granted is an environment property no suite observes, so the pipe goes at every such site regardless of payload size. When the assertion chains `grep` checks with `&&`, capture once and reuse `$ctx` across every branch — do not re-split the capture per branch (a bare `;` drops the `&&` ordering and silently weakens the assertion). (issues #964, #973, #114)

### Running the bash suite tree

**[MUST]** Bash suites under `tests/**` are run through `scripts/test/run-suites.sh`, not by ad-hoc enumeration. Selection has one owner — `scripts/test/select-suites.sh` — and both CI and the local runner consume it, so what a phase run executes and what CI executes are decided by the same predicate rather than by two lists that drift.

- `bash scripts/test/run-suites.sh` — the suites this change requires, selected from each suite's own `# ci-subject:` header against the resolved delta. A `push` event, or an empty delta from a resolved base, selects the full set; an unresolvable base is a visible `BLOCK` and a non-zero exit, never a silent empty selection.
- `bash scripts/test/run-suites.sh --all` — the whole enumerated tree. This is what VALIDATE step 1 runs, unconditionally, as the cycle's coverage floor.
- `bash scripts/test/run-suites.sh --list` — the selected set without running it.
- `bash scripts/test/run-suites.sh --selected <path>` — an explicit plan file, one repo-relative path per line, produced by `scripts/test/suite-coverage.sh`. Every line must be an enumerated suite and `--all` may not accompany it; either violation is usage exit `2` with nothing executed, so `0 suite(s) selected` can only ever mean *everything inherited*.

**The phase-step idiom** (GREEN step 5, VERIFY step 1, REFINE step 2 — the interim capture points, which accept on the selection-derived set):

```
bash scripts/test/suite-coverage.sh --ledger .autoflow/issue-<N>-ledger.md --cycle <C> \
  > .autoflow/issue-<N>-run-set.txt || { echo "suite-coverage BLOCK — running the enumerated set" >&2; }
bash scripts/test/run-suites.sh --selected .autoflow/issue-<N>-run-set.txt
```

**[MUST]** Keep the `|| { … }` between the two commands. The resolver's non-zero exit is otherwise invisible to the second command, and an unread BLOCK would present as a clean `0 suite(s) selected` / exit `0` — the inverse of *degrades to executing, never to skipping*. There is deliberately no stdin form of `--selected`: a pipe would make exactly that composition representable, and the runner's own `pipefail` is an option of the runner's shell, not of the shell composing the two commands.

The runner de-duplicates by resolved path, so a suite cannot execute twice in one pass; arms a wall-clock bound of `<effective local ceiling>` around each suite — via `timeout`, `gtimeout`, or a detached sleep-and-kill watchdog when neither binary exists on the host — and reports an overrun as a distinct `TIMEOUT`; and prints one result line with elapsed time per suite, so cost drift is visible long before it reds. Each suite's output is captured while it runs: a `PASS` discards the capture, while a `FAIL` or `TIMEOUT` replays it in full between framing lines directly under that suite's result line — the runner is the only driver for the tree, so a failure is diagnosable from the run that produced it without re-running the suite by hand (issue #108).

**The two clocks are not the same clock.** `budget-secs` is a **CI-clock** quantity — derived from the suite's own CI step duration, bounded by `SUITE_BUDGET_CEILING_SECS`, and spent by CI through that step's `timeout-minutes`. A local run spends a **local allowance** derived from it by one tree-wide ratio:

    effective local ceiling = budget-secs × SUITE_LOCAL_SLOWDOWN_FACTOR

Both constants live in `scripts/test/suite-manifest.sh`, and the factor is deliberately not environment-settable. The separation is measured, not stylistic: the same suite runs 89 s in CI against 594 s locally, so spending a CI-derived number on the local clock is a unit error, and deriving the budget *more* accurately makes the local failure worse rather than better.

**A local `TIMEOUT` is not a budget signal.** At this size the local gate is a hang detector, not a seconds-level cost gate, so an overrun is a hang or an order-of-magnitude regression. **Investigate the suite — do not bump `budget-secs`**, which carries a CI number that a local overrun is no evidence about. Cost is governed where the numbers are derived: on the CI clock, by `timeout-minutes`.

A suite executes its subject, not another suite (`scripts/test/check-suite-leaf.sh`). Confirming that a sibling has not regressed is its own CI step's job.

### Bash execution mode

> Canonical: docs/teammate-common-rules.md > Bash Execution Mode.

- **[MUST]** A spawned teammate runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- **Why (lifecycle contract):** the harness's background-task contract — *re-invoke the owning agent when the task completes* — holds only for an agent that has a future turn. A spawned subagent terminates with its final response, so any still-pending background process is **reaped at teardown**: its output is lost and no completion notification is ever delivered, stalling the orchestrator on a report that never arrives (issue #952 — 71-minute orchestrator deadlock, 2026-07-07). A background CPU-heavy process can also starve the agent's own foreground verification and distort the pass/fail verdict (issue #287). The background + completion-notification pattern is therefore **orchestrator-only** (the main loop is the sole actor with future turns).
- **Enforced at the tool boundary for suite runs (issue #134):** a backgrounded invocation of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the orchestrator included; the orchestrator-only background pattern above never extends to a suite run, whose result must stay keyed to the capture-point tree (`docs/autoflow-guide.md` > VERIFY > Green-tree register; `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

---

## Dependency Management

### Internal Dependencies (Between Repos)
- Use **versioned APIs** or **published packages** — never import directly from sibling repos
- Document dependency versions in a central tracking document
- Coordinate version bumps through the Orchestrator

### External Dependencies
- Pin major versions to prevent breaking changes
- Run vulnerability scans as part of CI
- Document any known CVE exceptions with rationale

---

## Shared Conventions

To maintain consistency across all sub-repos:

### Code Style
- Follow the language-specific style guide chosen for the project
- Use automated formatters (Prettier, Black, gofmt, etc.)
- Enforce via CI — no style debates in reviews

### Documentation
- Update docs when changing public interfaces
- Keep README.md current
- API changes require updating the API documentation

### Error Handling
- Use consistent error formats across repos
- Log errors with enough context to diagnose
- Don't swallow errors silently

---

## CI/CD Integration

Each sub-repo should have CI that:

1. Runs on every PR
2. Executes: lint → build → test
3. Reports results back to the PR
4. Blocks merge on failure

### AutoFlow Gate Integration
The `check-autoflow-gate.sh` hook can be integrated into CI to verify:
- Evaluation score meets threshold
- All AutoFlow phases completed in order
- State files are consistent
