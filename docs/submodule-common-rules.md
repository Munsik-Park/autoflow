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

The host's hook (`.claude/hooks/check-autoflow-gate.sh`) reads the state file and computes pass/fail directly from raw `scores`. Sub-repo AIs do not write to the state file — they receive instructions in the spawn prompt the orchestrator issues.

---

## Submodule URL & Pointer Policy

Applies to host repositories that operate a **host-private fork** as the submodule source — i.e., the fork carries host-private changes that are **not** bound for the upstream repository. The host repo's submodule pointer therefore lives in fork commits, not upstream commits.

### URL — `.gitmodules` fixed to the host-operated fork

```
.gitmodules submodule.<name>.url → <host-operated fork URL>   (e.g., <org>/<service-host>)
```

- `.gitmodules` is **never modified** in a PR. PR diffs must not touch `.gitmodules`.
- Local fork URL override is unnecessary.
- `setup/init.sh` substitutes the URL when the framework is propagated to another project.

### Pointer SHA — host main reachability

```
host main HEAD's submodule pointer SHA  →  reachable in the host-operated fork
```

- A commit that exists only on a fork **feature branch** (not yet merged into the fork's `main`) **must not** appear as the submodule pointer on host `main`.
- **Dev branch exception**: while a host PR's dev branch is open, the submodule pointer may temporarily reference a fork feature-branch SHA. Reachability against fork `main` is enforced at host-`main`-merge time.

### Multi-developer concurrent work

- `.gitmodules` is **never** modified — URL stays fixed.
- Each developer commits **only the submodule pointer** for their issue's dev branch.
  - The "developer" who commits that pointer on the host dev branch is the **orchestrator** (see [`CLAUDE.md`](../CLAUDE.md) > Commit Ownership > Submodule pointer bump); the two rules name the same actor, not two.
- No per-developer local URL override is required.

### Sub-repo cycle close-out

When a sub-repo work cycle is complete:

1. Merge the fork feature branch (e.g., `feat/<issue>-<topic>`) into the fork's `main`.
2. Reconcile the host's submodule pointer to this cycle's sub-repo merge commit on fork `main` (in the host PR's dev branch, before host PR merge). **[MUST]** When several cycles are in external review at once, reconcile **against the current `origin/main`**, not the branch's stale fork point. Resolve by fork ancestry — if this cycle's merge commit (`TARGET`, the sub-repo PR's merge commit; a submodule nested inside the sub-repo is reconciled by the sub-repo itself) is a **descendant** of the current `main` pointer, set the dev gitlink to `TARGET` first (`git -C <submodule> checkout <TARGET>; git add <submodule>; git commit`) **then** merge `origin/main`; if `main`'s pointer is a descendant (a regression) or the two diverge, **escalate to the operator**. **[MUST]** The end-state pointer must equal `TARGET` — verify `git ls-tree HEAD <submodule> == TARGET` before pushing. Full procedure + the post-reconcile mergeable/head-commit check gate: [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight.
3. The fork feature branch may then be deleted.

### Framework propagation

Operators initializing this framework on a different project run `setup/init.sh`, which substitutes the submodule URL to point at the operator's own fork (same model — host-operated fork, host-private changes allowed). The Pointer SHA rule holds there: host `main` always points at a commit reachable in the operator's fork.

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

Every changed line traces to the cycle's scope: the issue's acceptance criteria, the confirmed cause recorded in DIAGNOSE, the agreed plan, and each problem a recorded scope judgment includes (**Scope judgment** below). What belongs to the cycle is decided by that judgment, not by whether an acceptance criterion names the line. How small the change stays inside that scope is governed by **Trace rule**, **Surrounding code** and the **Over-engineering guard** below.

### Scope judgment
A role that meets a problem the acceptance criteria do not name answers two questions and records the answers with their grounds, under a `## Scope judgments` heading in the report or artifact its phase already produces ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 2).

1. **Is it directly related to this issue?** It is when any one of these holds:
   - it comes from the same confirmed cause;
   - this change created it or exposed it;
   - unless it is fixed, the behavior an acceptance criterion promises does not hold in actual use.
2. **Is fixing it in this cycle desirable?** It is when it lies in the same module, is confirmed by the same verification, and fixing it separately would reopen the same code. It is not when it needs a design decision of its own, touches another ownership scope, or carries more risk than this issue.

| Judgment | Disposition |
|---|---|
| Directly related, fixing it here desirable | fixed in this cycle; the recorded judgment is the trace of its hunks |
| Directly related, fixing it here not desirable | separated, with its **separation reason** recorded |
| Not directly related | separated — reported in one line with its `path:line`; a separate issue is the follow-up path |

- **The default follows the first question.** A directly related problem is included unless a separation reason is recorded. A problem noticed in passing — a style inconsistency, pre-existing dead code, a refactor opportunity — meets none of the three conditions and stays out (**Surrounding code**, **REFINE scope**).
- **A record line** names the problem (its `path:line` at the report's commit, or the design section), the condition of question 1 it meets or that none does, the answer to question 2 with its ground, and the disposition.
- **An inclusion is verified like the rest of the scope.** At ARCHITECT it gets a verification-design row whose `Issue AC` is `—`; found later, the role that fixes it runs the tests it judges the fix requires and records the run (Verification and Tools > *Local verification*).
- **Criterion defects.** From ARCHITECT on, beside the two questions the role weighs whether what it met shows a criterion defective ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*). A same-cause problem reaching past what the criteria name may mean the issue drew the problem too narrowly — and then whether the approach itself must change is the question, not only whether to include the rest; an item a criterion names that turns out to be a problem separate from this issue may mean it drew too wide. Including a problem does not change a criterion, and a criterion is not carried out merely because it names an item: a defect so judged is recorded here and raised in the report with the criterion, the proposed change and the fact that shows it, and the orchestrator puts it to the operator.
- A role that is not confident, or whose inclusion would change a design decision, raises the question instead of deciding it (principle 3).
- **Where it is applied**: DIAGNOSE's task decomposition and the ARCHITECT feature design's `## Scope` section set the cycle's scope; GREEN, VERIFY step 3 and REFINE judge what they meet during the work; and the gates' recommendations are triaged by the reviewer-finding procedure, where the same two questions decide which recommendation is not the issue's and ground the `Low` judgment (`docs/phases/gate-quality.md` > *Recommendation triage*).

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which acceptance criterion, confirmed cause, plan item or recorded scope judgment requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk whose rationale names none of them is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC or a recorded scope judgment requires the change. A comment attached to code this change modifies is not adjacent — it is part of the change (**Code comments** > *Changing commented code*).
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing — which **Scope judgment** does not make directly related — are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the cycle's scope needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the cycle's scope (**Scope judgment**). A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. What a comment on changed code may carry is **Code comments** below.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Code comments
The rule governs every comment in code a cycle writes or modifies — implementation and test files, in a target and in this repository. Existing comments on code the cycle leaves untouched stay as they are (**Surrounding code**).

- **[MUST] The test**: a comment carries only a sentence that stays true for as long as the code it sits on is unchanged — however much time passes, and whatever changes in other files.
- **What a comment carries** — only what a reader cannot recover from the code:
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
- **Where that content goes**: a decision and its grounds → the repository's decision record (in this repository, `docs/records/adr/` and `docs/records/design-rationale.md`); change history → the commit message and the PR body; discussion → the cycle's `.autoflow/*` design documents and the issue. The only reference a comment carries is at most one ADR identifier (`ADR-0024`).
- **Test files**: a test's intent is stated in its name and its assertion messages. A comment in a test file carries only the reason for a fixture that the fixture does not make evident.
- **Changing commented code**: **[MUST]** a comment attached to code this change modifies is updated or deleted in the same commit. When it is uncertain whether the comment is still true, delete it.
- **Directives are code**: a line a tool reads to change its behavior is code even when written in comment syntax — a lint suppression or a type-checker directive, for example — and this rule does not govern it; an explanation written beside it is a comment and does. Which lines are directives is the working AI's judgment in that target; no list is kept.

REFINE checks the cycle's diff against this rule (`docs/phases/refine.md` > step 1, *Comment check*). In a target's code, a comment that diverges from its code or carries what this rule sends out of a comment is a `Low` finding for the reviewer and the evaluator, and its fix is the orchestrator's direct commit; a defect a comment carries on its own ground, such as an exposed credential, takes the severity and route its impact sets (`docs/phases/gate-quality.md` > *Code comments in a target*).

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC or a recorded scope judgment requires it.

### Derived artifacts
- **[MUST]** `setup/manifest.json` is a **derived member of the change surface**
  whenever the surface includes a manifest-registered source. If
  `git diff --name-only <base>...HEAD` intersects
  `jq -r '.artifacts[].source' setup/manifest.json` on any path other than
  `setup/manifest.json` itself, the manifest must be regenerated
  (`setup/gen-manifest-hashes.sh`) and staged in the **same commit**. CI
  (`tests/plugin/verify-install-into-target.sh`) fails the PR otherwise.

### Lint chain on the staged surface
- **[MUST]** When the staged change surface contains at least one file covered by the target repository's lint chain, the committing role runs that chain over the staged files and confirms zero errors attributable to them **before** the commit is made — for every chain the discovery order below converts into a command. Auto-fixable formatting is applied and staged in the same commit.

**Chain discovery** — deterministic order, first hit wins. Each route must yield a command string the committing role can invoke in the working checkout; a route that names a lint but yields no such command is not a hit, and discovery continues.

1. the target repo's `CLAUDE.md` > Development Commands `Lint` / `Format` entries — the entry *is* the command;
2. the target repo's pull-request CI lint steps, restricted to steps that carry a `run:` body — the `run:` body is the command, taken verbatim and executed from the repository root.

**Execution trust boundary** — **[MUST]** before running a route-2 command, the committing role confirms the `run:` body is unchanged versus the baseline branch (`main` / the merge-base) for the current branch; a body altered in this branch is not executed — report `not-run` naming the step and the reason `modified-in-branch`. `modified-in-branch` classifies as `ci-deferred` when a covering pull-request job can be named and as `unexecuted` when none can (**`not-run` reason classes** below). Route 2 grants execution of the discovered lint/check command exactly as written — a read-only check, not licence to run any other step, argument, or command it happens to name.

**Conversion limit** — a CI lint step whose work is performed by a third-party action reference (`uses:` with no `run:` body) yields no local command and is therefore not convertible. "Not a hit" in **Chain discovery** governs which route supplies the command, not whether the step is reported: discovery moves on to the next route, and the rejected step remains a discovered chain the report must dispose of. A discovered chain the conversion limit rejects imposes no blocking requirement, only a reporting one: when every discovered lint is non-convertible the committing role does not block the commit, it reports `not-run` naming the non-convertible step. The commit-time and gate-time obligations are separate, and not blocking the commit is not clearing the gate: the rejection yields the reason class `ci-deferred` where a covering pull-request job can be named and `unexecuted` where none can, and VALIDATE clears only the former (**`not-run` reason classes** below). Making an action-only chain locally executable belongs to the target repository's ops and is outside this rule's authority.

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

- **[MUST]** A chain that did not execute is reported `not-run`, never `clean`.

**Evidence anchor** — the committing role's report carries the lint outcome as an anchor class of Reporting Format item 5, whose single-anchor requirement it satisfies as a per-chain enumeration (form and cardinality there).

### REFINE scope
REFINE applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. The refactor tool's findings are advisory, not licence to expand the change surface. A finding that describes a behavior defect rather than a refactor is not REFINE's to apply: the Developer AI records its **Scope judgment**, and one judged directly related goes to the REFINE report's out-of-scope-observations section for the evaluator to dispose of (`docs/phases/refine.md` > REFINE report).

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` and `Impact scope` items are scored against this section, on one scope: prefer the smallest sufficient change that resolves the confirmed problem within the cycle's scope. The cycle's scope is the acceptance criteria, the confirmed cause recorded in DIAGNOSE (`.autoflow/issue-{N}-phase-*.md`), and the problems the cycle's recorded scope judgments include (**Scope judgment**) — a boundary, not a line count. A correctly scoped change is not scored down for being larger than a symptom patch. The evaluator reads the scope records for both items: the feature design's `## Scope` section and every `## Scope judgments` section in the cycle's `.autoflow/issue-{N}-*.md` reports, with the ledger's `[gate-autofix]` entries and gate verdict entries (`docs/phases/gate-quality.md` > *Recommendation triage*).

A high-scoring change:
- resolves the confirmed cause, not only the reported symptom
- stays inside the module or component that owns that cause
- includes the local cleanup the fix itself requires — the code and symbols this change renders unreachable or unused, removed in the same commit; cleanup merely noticed nearby does not qualify (**Surrounding code**), and **Orphans from this cycle** is the symbol-removal instance of this same test, not its limit
- fixes each directly related problem its scope judgments include, and leaves out a directly related problem only with a recorded separation reason
- leaves every surface outside the scope untouched — behavior, APIs, configuration, and documentation are examples of such a surface, not the boundary

`Minimal implementation` asks whether each hunk is needed. It fails when a hunk traces to no acceptance criterion, confirmed cause or recorded scope judgment — "I noticed it while I was here" cleanup (**Surrounding code**) or depth creep beyond what the scope needs (**Over-engineering guard**) — regardless of code quality, and when a hunk rests on a scope judgment that meets none of question 1's three conditions. It fails symmetrically when the change is too narrow to resolve the confirmed cause: a change that leaves the confirmed cause in place is not sufficient, and does not score well for being small.

`Impact scope` asks the same question from the other side: whether the change reaches what its scope requires. A directly related problem that the cycle's own records show — a scope judgment, a REFINE observation, an earlier gate's recommendation — and that the change leaves out with no separation reason recorded lowers it, as does a separation reason that answers neither half of question 2.

**Comments in a target's code.** The item also weighs the comments the change adds, by content and by volume, reading the REFINE report's `## Comment check` section (`docs/phases/refine.md` > REFINE report) — its `comment-ratio` line and its hits — with the comments in the diff:
- *Content*: a comment that **Code comments** does not admit — a restatement of the code, a design ground, a reference or a history — is depth the AC does not need, as an unneeded hunk is.
- *Volume*: even where every comment is admitted, the evaluator judges whether their amount, absolute and relative to the code they sit on, exceeds what a reader of the changed code needs — a comment block larger than the logic it explains, for example. The judgment is qualitative, with no ratio threshold, and names the comment blocks it rests on.

The evaluator records each such finding in the item's `reason` and in `recommendations`, and does not lower the item's score for it: in a target a comment finding never fails the gate (`docs/role-contracts.md` > Evaluation AI > *Code comments in a target*, which also names the defects a comment can carry on their own ground and that this exclusion does not cover). In this repository the item is scored without this comment weighing.

---

## Reporting Format

When a role spawn reports to the orchestrator — the report is the spawn's return value, with any body written to `.autoflow/*` and an anchor plus a one-line summary returned — it must follow this shape (see host [`CLAUDE.md`](../CLAUDE.md) > Cost Control > *Orchestrator context discipline*). This format governs **AI↔AI / AI↔orchestrator** reporting: the returned report, and the round-by-round exchange between the Developer-AI and Test-AI sub-agents inside a facilitation `Workflow`. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in host [`CLAUDE.md`](../CLAUDE.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite `.autoflow/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report the jest summary line (e.g., "Tests: 147 passed, 147 total"), read from the run's log (item 5), + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the run's **log** — the file its output was written to (Testing Standards item 7), cited by path under `.autoflow/issue-{N}-local/` — with the command that produced it and the exact `Tests: N passed, N total` (or equivalent) summary line read from that log. The log is the evidence and the summary line is the value read from it; a line no log carries is not evidence (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, plus the verbatim content of that line (a line number is read only at that commit — host [`CLAUDE.md`](../CLAUDE.md) > Decision Ledger)
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under `.autoflow/issue-{N}-local/`, with its result line (`observation: match` / `observation: mismatch — …`) read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the discovery order found, the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked plus the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*) and the unexecuted step's identity (`path:line` of the workflow file and the step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this diff — the workflow's `on: pull_request` entry, and either no `paths:` filter or one whose patterns match a staged file; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-applicable` → that word alone, naming which discovery routes came up empty. A report citing one chain where discovery found several is malformed, not compliant.

   Anchors must be deterministically confirmable by the orchestrator against what produced them (`git show <SHA>` / the summary line read in the cited log / `git show <SHA>:<file>`); a test-pass anchor is confirmed by reading, not by re-running — the command is re-run only when the log is absent or does not carry the line, and the run is then `not-run` and run in place. Reports without an anchor are rejected, not interpreted. This item's line-number forms are for the report; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.

6. **Facilitator return (deliberation phases)**: the facilitation `Workflow` returns one structured result, specific to the phase — ARCHITECT (the Record workflow over the relay transcript): `{ report: { agreed, unagreed[] }, artifacts, transcript, ledger, summary, stopped }`; VERIFY: `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI, ledger, summary }`. It carries no turn-by-turn messages and no duplicate dual reports; an ARCHITECT relay participant's own return is one line per turn. Shape: [host `CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation and [`role-contracts.md`](role-contracts.md) > Facilitator > Return Contract.

---

## Verification and Tools

This section applies to every actor of a cycle — the orchestrator and every role.

**Local verification** (the instance of [`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 2 the phases cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every `automated` row this cycle authored or changed and every `delivery-check` row — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format item 5). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is HANDOFF's CI (step 5) — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to (Testing Standards item 7's `$LOG`), cited by path under `.autoflow/issue-{N}-local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the orchestrator's acceptance of a role-spawn report ([`CLAUDE.md`](../CLAUDE.md) > Execution Principles > *Verify role-spawn claims*), VALIDATE step 1, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the Test AI at RED, the Developer AI at GREEN, either at VERIFY — finds, at the location it executes in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **cycle-layer asset** — a default `automated` row's test, a `delivery-check`, a `manual` checklist — lives under `.autoflow/issue-{N}-local/`, outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's path under the prefix**: the verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A cycle that wants one command for several assets writes that driver *as* a cycle-layer asset under the same prefix. Such an asset is never committed, and is archived with the issue's other artifacts.

**The tools the work needs are found, secured, and — outside the target's own procedures — requested from the operator**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. The orchestrator pursues securing them. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the orchestrator ([`CLAUDE.md`](../CLAUDE.md) > Execution Principles > *Background execution is orchestrator-only*), and stopped once the cycle no longer needs it. Anything else — an installation, a credential, a permission setting, enabling an MCP server or a browser extension — is outside the assigned scope ([`CLAUDE.md`](../CLAUDE.md) > Cross-Project Boundary Rules) and is requested from the operator, situation-first ([`CLAUDE.md`](../CLAUDE.md) > Flow Control > *tool or referenced material → user*). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened reaches the operator the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under `.autoflow/issue-{N}-local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each phase does this: `docs/phases/analysis.md` (DIAGNOSE), `docs/phases/architect.md` > *Tools* and `docs/phases/verify.md` > step 1.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — GREEN's entry run of the RED tests, VERIFY step 1, VALIDATE step 1, a spawn prompt that hands the record to the next role, GATE:QUALITY's `Test coverage` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL and routes nowhere; a run that fails routes as the phase's own rules say.

**What a cycle leaves in the target's tree is not classified by AutoFlow**. A cycle adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the cycle does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it (HANDOFF steps 4 and 5), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

## Testing Standards

Every sub-repo must maintain:

1. **Unit tests** for business logic
2. **Integration tests** for API endpoints / component interactions
3. **No broken tests on `main`** — all tests must pass before merge
4. **Test execution follows the target's practice** — Verification and Tools > *Local verification* and *How a test is run is the target's practice* above.
5. **jest output**: invoke jest with `--silent --reporters=summary` when running for a role spawn's report (verbose output is for local debugging only). Coverage reports use the summary reporter; per-file HTML reports stay on disk and are referenced by path, not pasted.
6. **SIGPIPE-safe assertion pipes**: under `set -o pipefail`, do not pipe a *streaming/context* producer (`grep -A/-B/-C`, and awk/section-extractor functions whose buffered output is still flushing when the consumer exits, and other producers that keep writing past the match) directly into a *short-circuiting* consumer (`grep -q`, `grep -m`, `head`) when the pipeline's exit status is the assertion verdict. Capture the producer first, then feed the captured string to the consumer **without a pipe** — `ctx=$(<producer>); grep -q <pattern> <<<"$ctx"` — or drop `-q` so the consumer reads to EOF. Both the capture and the here-string are needed: a `printf` of the captured string piped into a short-circuiting consumer is not a repair. The governing condition is unwritten producer bytes at consumer exit, not any particular pipe-capacity threshold, so the pipe goes at every such site regardless of payload size. When the assertion chains `grep` checks with `&&`, capture once and reuse `$ctx` across every branch, keeping the `&&` chain — do not re-split the capture per branch.
7. **Output hygiene for shell suites**: a suite runner's output never streams into an agent's context. Run it to a log file under `.autoflow/issue-{N}-local/` — that log is the run's evidence (Reporting Format item 5), cited by path — and read the tail — `bash scripts/test/run-suites.sh … > "$LOG" 2>&1; tail -n 20 "$LOG"` — and on a failure pull only the failing suite's block from the log (`grep -n`, then `sed -n 'A,Bp'`), never `cat` the log. Re-read a file you have already read by `sed -n 'A,Bp'` over the lines you need, never by a second whole-file read. Applies to every spawn mode.

### Running the bash suite tree (opted-in targets)

Where the target opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`), bash suites under `tests/**` are run through `scripts/test/run-suites.sh`, not by ad-hoc enumeration. Selection has one owner — `scripts/test/select-suites.sh` — and both CI and the local runner consume it. Which suites a change requires is the working AI's judgment, recorded with its grounds (host [`CLAUDE.md`](../CLAUDE.md) > Rule Scope); the selector is the device that answers it here. Elsewhere the target's tests run the way the target runs them.

- `bash scripts/test/run-suites.sh` — the suites this change requires, selected from each suite's own `# ci-subject:` header against the resolved delta. An unresolvable base, or an enumerated suite with no usable `# ci-subject:` header, is a visible `BLOCK` and a non-zero exit with nothing executed, never a silent empty selection — carry the `BLOCK:` lines into the report (`docs/phases/red.md` > Header contract > *Adopting the contract over existing suites*).
- `bash scripts/test/run-suites.sh --list` — the selected set without running it.

The runner de-duplicates by resolved path, so a suite cannot execute twice in one pass; arms a wall-clock bound of `<effective local ceiling>` around each suite — via `timeout`, `gtimeout`, or a detached sleep-and-kill watchdog when neither binary exists on the host — and reports an overrun as a distinct `TIMEOUT`; and prints one result line with elapsed time per suite. Each suite's output is captured while it runs: a `PASS` discards the capture, while a `FAIL` or `TIMEOUT` replays it in full between framing lines directly under that suite's result line.

**The two clocks are not the same clock.** `budget-secs` is a **CI-clock** quantity — derived from the suite's own CI step duration, bounded by `SUITE_BUDGET_CEILING_SECS`, and spent by CI through that step's `timeout-minutes`. A local run spends a **local allowance** derived from it by one tree-wide ratio:

    effective local ceiling = budget-secs × SUITE_LOCAL_SLOWDOWN_FACTOR

Both constants live in `scripts/test/suite-manifest.sh`, and the factor is not environment-settable.

**A local `TIMEOUT` is not a budget signal.** The local gate is a hang detector, not a seconds-level cost gate, so an overrun is a hang or an order-of-magnitude regression. **Investigate the suite — do not bump `budget-secs`**. Cost is governed where the numbers are derived: on the CI clock, by `timeout-minutes`.

A suite executes its subject, not another suite (`scripts/test/check-suite-leaf.sh`). Confirming that a sibling has not regressed is its own CI step's job.

### Bash execution mode

> Canonical: docs/role-common-rules.md > Bash Execution Mode.

- **[MUST]** A role spawn runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- The background + completion-notification pattern is **orchestrator-only**.
- **Enforced at the tool boundary for suite runs:** a backgrounded invocation of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the orchestrator included; the orchestrator-only background pattern above never extends to a suite run (`docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

---

## Dependency Management

### Internal Dependencies (Between Repos)
- Use **versioned APIs** or **published packages** — never import directly from sibling repos
- Document dependency versions in a central tracking document
- Coordinate version bumps through the Orchestrator

### External Dependencies
- Pin major versions
- Run vulnerability scans as part of CI
- Document any known CVE exceptions with rationale

---

## Shared Conventions

### Code Style
- Follow the language-specific style guide chosen for the project
- Use automated formatters (Prettier, Black, gofmt, etc.)
- Enforce via CI

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
