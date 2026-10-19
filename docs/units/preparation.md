# U1 Preparation — PREFLIGHT and CRITERION-REVIEW

> Unit document for U1. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

PREFLIGHT is functional unit U1 Preparation
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1), and an attempt with no
state file passes its criterion review stage, CRITERION-REVIEW, inside it (issue #465,
[`ADR-0030`](../records/adr/0030-criterion-review-is-a-stage-of-the-cycle.md)). U1 has no unit
agent: it is the orchestrator's own work, the criterion review's stage 1 included. This file states what it is asked for, the cautions and the result
owed; the order of the work and the commands are the orchestrator's
([`core.md`](../core.md) > Rule Scope, principle 2). A script only reads and reports (D8):
every change — to git, to GitHub, to the cycle's state — is made by the orchestrator itself.

- **Goal**: the requested issue's attempt starts, or continues, on a clean tree synced with the
  remote, with every earlier attempt of this checkout whose pull request is merged or closed
  cleared away — an attempt that starts with its criteria settled by its own criterion review
  stage.
- **Artifact contract**: the state file `<attempt-dir>/issue-{N}.json` and the attempt's dev branch
  checked out (*What is asked*), the plugin record and the local-checks record in the ledger
  (*What is asked*, *Stop conditions*), and, for an attempt's start, its criterion review record and
  its `[criterion-ready]` entry (*The criterion review stage*).
- **Verification**: PREFLIGHT has no gate. Its readiness conditions are deterministic — the facts
  `<autoflow-root>/scripts/preflight/cycle-status.sh` reports, its `entry:` line among them, and the
  *Stop conditions* — and DIAGNOSE does not begin until they hold. The criteria are judged by the
  criterion review stage alone ([`criterion-review.md`](../criterion-review.md)); PREFLIGHT's
  readiness check never judges an issue's content: on an attempt not yet started it reads only
  whether the attempt's own review recorded its `[criterion-ready]` entry for the current body.
- **Loop cap**: A condition that does not hold stops the cycle and is reported; PREFLIGHT
  runs again once it is resolved.
- **Result owed**: the state file, the dev branch and the ledger records above. A resume also
  owes its re-entry point, recorded with grounds in the ledger (*Resume*).

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](../core.md) > Flow Control.

| Transition | Condition |
|------|------|
| PREFLIGHT → CRITERION-REVIEW | `entry: new`, or the operator's request for a new attempt the session judges still to carry out (*Modes*) — the attempt created first (`autoflow-records new --issue N`) — or `entry: criterion-review`, on the attempt's dev branch with the tree clean and `origin` fetched → the attempt's criterion review stage runs in this session (`<autoflow-root>/docs/units/preparation.md` > *The criterion review stage*) |
| CRITERION-REVIEW → PREFLIGHT | the stage's exit condition: the attempt's `[criterion-ready]` entry for the current issue body (`criterion-ready.sh status` `READY`) → PREFLIGHT continues at the stop conditions on that attempt, now `entry: start` |
| PREFLIGHT → DIAGNOSE | earlier attempts resolved, Git clean, remote synced, the stop conditions passed (criterion readiness included for an attempt's start), and the state file written for `entry: start` (`mode: new-issue`) or `entry: review-response` (`<autoflow-root>/docs/units/preparation.md` > *What is asked*, *Modes*) |
| PREFLIGHT → resume | `entry: resume` — this checkout's attempt of the issue reads `active:true` → the re-entry point is the orchestrator's judgment over the facts `<autoflow-root>/scripts/preflight/cycle-status.sh --issue N` reports, recorded in the ledger; a gate with no recorded scores is run, never assumed passed (`<autoflow-root>/docs/units/preparation.md` > *Resume*) |
| PREFLIGHT → user | another issue's attempt mid-cycle in this checkout (`entry: hold`), a pause for a human decision (`entry: paused`), an entry `cycle-status.sh` reports as a stop (`stop …`), a dirty tree (resolved only with the user's approval), a Git state that cannot be synced, an undetermined or unusable record root, or a fail-closed stop condition — a failed target check, an unreadable reviewer configuration, a target-declared local check that does not pass after its declared repair, a criterion review stage a harness-level block leaves without its `[criterion-ready]` entry → report and stop; DIAGNOSE does not begin (`<autoflow-root>/docs/units/preparation.md`) |

## What is asked

```
bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue {N}
```

prints the facts the work is decided from and changes nothing: the working tree, the default branch
against its remote-tracking ref, the AutoFlow this run uses (the root the script runs from, the
plugin name and version that root's `.claude-plugin/plugin.json` names, and, when the root is a git
work tree of its own, its `HEAD` and whether it is dirty), the record root and this checkout, any
state file left in the checkout's own `.autoflow/`, and — for every attempt of this repository not
marked completed — its owner (`this`, `other <path>` for a checkout still there, `gone <path>`), its
state (`active`, `phase`, `mode`, `cycle`, or `none` for an attempt with no state file yet — in its
criterion review stage, or ready to start), its dev branch with each side, and, for a state file that is not active, its pull
request. `cleanup:` lines name this checkout's attempts whose pull request is merged or closed; with
`--issue {N}`, `criterion:` lines give the readiness of each attempt of N this checkout could start,
a dev branch carrying N's number with no attempt record is reported `record=none`, and the last line
is the **entry** — which attempt the request enters, and how (*Modes*). Exit `3` means a fact could
not be read (a `gh` lookup, an unreadable state file, an unreadable `plugin.json`), exit `7` that the
record root is undetermined or unusable (its marker line says why — the operator fixes the file or
the directory, and PREFLIGHT runs again); the line says which. From those facts the orchestrator
brings about the following.

- **Earlier attempts are resolved.** An attempt of this checkout — its `checkout` file names this
  checkout — whose pull request is merged or closed (`cleanup:`) is cleared, whatever its issue:
  its local dev branch is deleted, and `<autoflow-root>/scripts/cleanup/cleanup-issue.sh
  <dev branch>` marks it completed ([`git-workflow.md`](../git-workflow.md) > Post-Merge Cleanup).
  Its remote branch and its pull request are left as they are, and its records stay where they
  are. An attempt paused with no pull request keeps its files in place, and its pending decision is
  reported.
- **Another checkout's attempt is reported, not touched.** An attempt whose checkout is still there
  (`owner=other`) is that checkout's: it is not entered, changed, marked or cleared from here, and
  its branch is not deleted on either side. An attempt whose checkout is gone (`owner=gone` — a
  removed worktree or clone; its records stay under the record root, its dev branch in the clone
  and, once pushed, on the remote) is reported the same way until a checkout takes it over: the one
  that checks its dev branch out and runs `/autoflow:cycle <N>` (`claim:` line; `autoflow-records
  claim`). From then on it is that checkout's, its cleanup included. A worktree deleted without
  `git worktree remove` keeps holding its branch in the clone until `git worktree prune`; until then
  git refuses that branch's checkout, and the takeover waits.
- **A dev branch with no attempt record is not an attempt.** A branch reported `record=none` — no
  record directory under the record root carries its name: another machine's attempt, a branch made
  by hand — is reported, and neither side of it is deleted (issue #433). It does not decide the
  entry, even checked out.
- **One attempt runs at a time in a checkout** (*PR Wait Rule*), and the request enters the attempt
  the `entry:` line names, in the mode it names (*Modes*).
- **The tree is clean and synced.** No uncommitted change or untracked file in the working area,
  and the branch the mode works on — the attempt's dev branch — is where the mode needs it: for a
  start, fast-forwarded to the remote default branch's latest commit (`git fetch origin`, then
  `git merge --ff-only origin/<default>` on the dev branch, which has no commit of its own yet); for
  a review-response, matching its remote branch ([`git-workflow.md`](../git-workflow.md) > Git
  Clean Check). This holds in a worktree whose default branch is checked out in another worktree
  and on any branch the checkout had: nothing here checks out or updates the local default branch.
  In a project with sub-repos, syncing the host also brings each submodule to the commit the host's
  pointer names; this is the orchestrator's work item, and no script checks it.
- **A new attempt is created, and an attempt with no state file passes its criterion review
  stage** (*The criterion review stage*), before the stop conditions.
- **The stop conditions pass** (*Stop conditions*): the target check, a readable reviewer
  configuration (or the operator's choice to proceed without external review when the operator
  file is unreadable), the target-declared local checks, and — for an attempt's start — criterion
  readiness.
- **The plugin record is written.** On a start and on review-response entry, before the state
  file is written, the orchestrator appends the AutoFlow values `cycle-status.sh` reported to the
  attempt's ledger as a record entry, `<C>` being the cycle the state file will carry:

  ```
  ### preflight-plugin | cycle: <C>
  - plugin: <name> <version>
  - root: <the root path>
  - git: <HEAD> clean | <HEAD> dirty (<n> path(s)) | not a git work tree
  ```
- **An attempt's start gets its state**: on its dev branch — made with the attempt when the cycle
  created it (`autoflow-records new`), `dev/YYYY-MM-DD-HHMMSS-issue-N` — the state file from the Creation template with that name
  in `branch`, `mode: "new-issue"` and `phase: "in-progress"`
  ([`state-tracking.md`](../state-tracking.md) > AutoFlow State Tracking). The name is the
  attempt's for its life: a review-response continues on it, and its record directory is named from
  it. A review-response gets *Review-response setup*.

Cautions:

- **A dirty tree is never resolved without the user.** What is stashed, committed or discarded is
  the user's to approve; PREFLIGHT does not reach DIAGNOSE on a dirty tree.
- **A branch that does not fast-forward, a fetch that fails, or a Git state that cannot be made
  clean is a hard stop**: report to the user. It is not worked around with a reset or a forced
  update.
- **Nothing on the remote is changed.** PREFLIGHT and the cleanup read pull-request state and fetch;
  they delete no remote branch, push nothing, and close, label or comment on no pull request.
- **The state file is created last.** A stop condition that fails, a hold or a pause leaves no
  state file behind; the attempt's dev branch and record directory, made when it was created,
  stay as they are — and so do the records of a criterion review stage left unfinished.
- **An attempt is cleared only on an observed merged or closed pull request.** Its pull request is
  looked up by its dev branch's name even when the branch is gone on both sides.

## PR Wait Rule

The readiness check that clears the requested attempt to start. Its source of truth is the state
files of this checkout's attempts, `<attempt-dir>/issue-{N}.json`; the start signal is
[`core.md`](../core.md) > PR Wait Rule.

- **[MUST]** An `active:false` state file (`phase: awaiting-external-review`) is **cleared and
  handed off**: its PR belongs to external review, which merges on its own schedule. Readiness is
  tied to the `active` flag alone.
- Another issue's `active:true` attempt in this checkout holds the requested one (`entry: hold`):
  report and hold, and finish or resolve that cycle first. Another checkout's attempts — of the same
  issue, another issue or another repository — never hold it.

## Modes

The requested issue's entry follows from this checkout's attempts' records — the `entry:` line
`cycle-status.sh --issue {N}` prints; none of these is a judgment. An attempt is identified by its dev branch and belongs
to the checkout that started it, or that took it over. Evaluated in order:

| This checkout's records | Entry |
|---|---|
| a state file in the checkout's own `.autoflow/` | `stop in-tree-records` — moved to the record root first ([`state-tracking.md`](../state-tracking.md) > *Record location*) |
| another issue's attempt reads `active:true` | `hold` (*PR Wait Rule*) |
| an attempt of N reads `active:true` | `resume` — the in-progress cycle continues (*Resume*); it is not restarted |
| the checked-out branch is an attempt of N whose checkout is still another one | `stop other-checkout` — reported, not entered (in one clone, git does not let the branch be checked out twice) |
| the checked-out branch is an attempt of N — taken over first (`claim:`) when its checkout is gone: | |
| — no state file, its `[criterion-ready]` entry valid for the current body | `start` — the attempt's cycle begins (*What is asked*) |
| — no state file, no valid entry (the review is not finished, or the body changed after it) | `criterion-review` — the attempt's criterion review stage runs on that branch (*The criterion review stage*) |
| — `active:false`, `phase` other than `awaiting-user`, an open PR | `review-response` (*Review-response setup*) |
| — `active:false` at `phase: "awaiting-user"` (a PR open or not), or with no open PR | `paused`: the cycle waits on a human decision and is not cleared. The pending decision and its `<attempt-dir>/issue-{N}-*.md` context are reported. Re-entry is driven by the user's new decision — never an automatic mode, never a silent restart: when the user decides to continue, the orchestrator sets `active: true` and continues where the pause was taken |
| otherwise, exactly one attempt of N is ready to start, still in its criterion review stage, or has an open PR (an attempt cleared at this PREFLIGHT aside) | that attempt's `start`, `criterion-review` or `review-response` — its dev branch is checked out first |
| otherwise, two or more | `stop candidates` — reported; checking one's dev branch out names it |
| otherwise, attempts of N still here, none of those — paused, or with a fact that could not be read (a `gh` lookup, an unreadable state file; exit `3`) | `none-to-enter` — each named with its kind; none is entered by the entry, and a paused one's re-entry is the user's decision |
| otherwise — no attempt of N in this checkout, or every one cleared | `new` — the cycle may create the attempt and run its criterion review stage (*The criterion review stage*) |

**A new attempt is the operator's request.** It is created only on the `new` entry or on the operator's explicit request
— `/autoflow:cycle <N> new` (or `/autoflow:criterion-review <N> new`). With an attempt of N still in
this checkout — an open PR, a paused one, one whose criterion review is not finished — no new
attempt is made without that request.

The entry is a fact, and so is every line above it. Where the facts leave the way on open — the
cases below — the way is the session's judgment, recorded with its grounds in the ledger of the
attempt it enters or creates (an `O` entry under `orchestrator decision`), or in its report when it
stops (Rule Scope, principle 2 — [`core.md`](../core.md)):

- **A `new` in the arguments.** Whether it is a request still to carry out, or one this conversation
  already carried out — an attempt it created — and how far that attempt has come, is the session's to judge from the attempts
  `cycle-status.sh` reports and from what the conversation holds. A request still to carry out creates
  the attempt whatever entry is printed beside it, under the conditions `autoflow-records new` applies.
- **A fact that could not be read** (exit `3`: `pr: lookup failed`, an unreadable state file, a
  `criterion:` line that could not be read): whether to run the script again, report and stop, or
  go on with the other facts.
- **A `claim:` line, a dirty tree, an other-checkout attempt**: whether to take the attempt over,
  ask the user about the tree (a dirty tree is never resolved without the user — *Cautions*), or
  report.

## The criterion review stage

CRITERION-REVIEW is the first stage of an attempt's cycle, inside PREFLIGHT: after the entry
`cycle-status.sh` prints and the conditions before it — no state file left in the tree, no other
attempt of this checkout active (*PR Wait Rule*), the record root determined and usable — and
before the stop conditions and the state file. It runs on the entries `new` and
`criterion-review`, and on the operator's request for a new attempt (*Modes*), in the session `/autoflow:cycle <N>` started; no other command or session is
needed, and `/autoflow:criterion-review <N>` runs this stage alone, from the same entries, ending at
its exit.

- **The attempt and its record directory come first.** On `new`, or on the request, the orchestrator creates the
  attempt before the stage writes anything: `autoflow-records new --issue {N}` — on a clean tree,
  with no active attempt in this checkout — fetches `origin`, makes the record directory under the
  record root with this checkout as its owner, and checks out a new dev branch
  `dev/<date>-<time>-issue-<N>` at the remote default branch's latest commit, local only and with no
  commit of its own until the state file is written. It refuses — and nothing is made — on a dirty
  tree, an active attempt of this checkout, a failed fetch, no remote-tracking ref of the default
  branch, or a record root that is undetermined or unusable (exit `7`); each is a stop reported to
  the user, as PREFLIGHT reports it. On `criterion-review`, the attempt named is checked out, and
  `git fetch origin` runs before the stage reads the code; a failed fetch is the same hard stop,
  and a dirty tree is resolved with the user first (*Cautions*).
- **The stage is the attempt's criterion review.** What it reads and judges, its stages — stage 1
  in this session, then the `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and
  `autoflow-criterion-reconciler` spawns — its record, its authority and its report are
  [`criterion-review.md`](../criterion-review.md). Every record of it is in the attempt's record
  directory `<attempt-dir>` (`autoflow-records dir`).
- **Exit.** The attempt's `[criterion-ready]` entry for the current issue body, which
  `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` reports `READY`; then
  PREFLIGHT continues at the stop conditions on that attempt. While a decision waits on a
  harness-level block, the entry is not written and the session reports it and stops.
- **Re-entry.** The stage writes no state file, so a session that ends in the middle of it
  re-enters it from `cycle-status.sh`'s `criterion-review` entry on the same attempt; what
  the stage already wrote is in `<attempt-dir>`, and how much of it the stage takes up again is its
  own judgment, recorded under the review record's `## Session decisions`.
- **One unit per session.** `/autoflow:cycle-u1 <N>` (`<N> new` for a new attempt)
  runs U1 — this stage included — from its entry (`new`, `criterion-review`,
  `start` or `review-response`) to PREFLIGHT → DIAGNOSE, and every stop above is reported the same
  way.
- **The stage does not hold its checkout.** No state file exists while it runs, so the PR Wait
  Rule's `active` signal does not see it: another issue's `new` in the same checkout switches the
  branch away — only on a clean tree, so no uncommitted work is lost, and the stage's records stay
  in its `<attempt-dir>`. The attempt left so is reported and re-entered later like any unfinished
  review (`criterion-review`). An attempt with no state file is not counted as active because an
  unfinished review left for good would otherwise hold the checkout with no state to clear.

## Review-response setup

For a cycle entered at PREFLIGHT in `review-response` mode. On the attempt's dev branch:

- **[MUST] The previous cycle's artifacts are preserved** before any phase of the new cycle writes:
  every `<attempt-dir>/issue-{N}-<artifact>.md` is renamed to `<attempt-dir>/issue-{N}-c{C}-<artifact>.md`,
  `C` being the previous cycle number. What spans cycles keeps its name — the ledger, the criterion
  review record, the advisor records its entries point at (`issue-{N}-advisor-*.md`), the state
  file and the cycle-layer store `issue-{N}-local/`.
- **The state file moves to the next cycle**: `mode: "review-response"`, `active: true`,
  `phase: "in-progress"`, `cycle` incremented, and `phases` reset to the Creation template (the
  `verdict` rule kept).
- The local checks run with the incremented cycle number, and the state is set only once they pass.
- The DIAGNOSE unit's prompt names the review comment or thread that triggered the cycle.

How much of the previous cycle's artifacts the new cycle reuses is the analysis and design units'
own ([U2 Analysis](analysis.md) > Unit spawn; [U3 Design](design.md) > *Re-entry*). The cycle-layer
store's retained set is reviewed, re-authored and re-executed at the new cycle's BUILD; a check that
did not execute is `not-run`, never `passed`.

## Resume

This checkout's attempt of the requested issue reads `active:true`: a cycle a session ended in the
middle of. `cycle-status.sh --issue {N}` reports what the resume is judged from — each gate's
recorded scores, `verdict` and `remedy_class`, the artifacts on disk, the ledger's last
`[gate-autofix]`, `[rebuttal]`, `[review-autofix]` and `[reentry-decision]` entries, and the last
local-checks record of the current cycle. It names no phase: **where the cycle re-enters is the
orchestrator's judgment over those facts**, recorded with its grounds in the ledger. Cautions:

- The cycle is continued, not restarted: a resume does not increment `cycle` and does not reset
  `phases`. It does not require a clean tree either — what the interrupted session left
  uncommitted belongs to the phase that re-enters.
- The attempt's dev branch — the one its record directory is named from and its state file's
  `branch` names — is checked out before any phase re-enters. A missing branch, or facts that do
  not fit together, are reported to the user.
- A last local-checks record of the current cycle that is not `none declared` or `PASS …
  worktree=clean` means the local checks run now, before any phase re-enters (*Stop conditions*).
- A gate with no recorded scores has not passed. It is run, never assumed — the cycle re-enters no
  later than the phase whose artifact that gate scores.
- A gate whose record carries `remedy_class` has an open re-entry: a passed gate's open
  recommendation attempt ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*), which resumes
  on the route its last `[gate-autofix]` entry names and not past the gate; or a failed gate's FAIL
  route.
- A `[rebuttal]` entry with no verdict entry of that gate after it resumes at that gate's re-score
  ([U6 Delivery](delivery.md) > *Whether a finding holds*).
- An artifact the next phase consumes that is absent is not written by the orchestrator: the phase
  that produces it runs again.

## Stop conditions

Each is a fail-closed hard stop, run by the orchestrator before the state file is created: DIAGNOSE does not begin until every one that applies passes — the first three in every mode that runs them, *Criterion readiness* on an attempt's start only.

**Target check.** PREFLIGHT runs `bash <autoflow-root>/scripts/preflight/target-check.sh` from the target; a non-zero exit stops the cycle. It runs from the AutoFlow root the session loads — the agent definitions, the readout, the selector and the default spawn policy beside it — and reads the target's files as data, executing none of them. **D6** — when the target keeps its own `.claude/autoflow/spawn-policy.json`, which overrides the plugin's default: `<autoflow-root>/scripts/spawn-policy/spawn-policy.sh check` over it against the loaded agent definitions, and its row set against the default `<autoflow-root>/.claude/autoflow/spawn-policy.json` — a `phases` / `workflow_sites` row the default carries and the target's copy lacks, or a `phases` row whose `agent_type` differs, is named. Model values and `workflow_sites` effort are the target's own and are never findings; a target with no policy of its own passes, its readouts answered by the default. **D7** — on a target that opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`, resolved through `<autoflow-root>/scripts/test/suite-manifest.sh`): every executable spec under the target's `tests/**` declares the usable `# ci-subject:` header the selector requires (the selector's own `--check-headers` stage). A target that has not opted in passes without the selector being consulted, and a declaration file that is present but unreadable is a FAIL. Remedies: D6 → edit the target's policy — set each named row to the loaded definition's values and add each missing row from the default — or delete it to take the default; D7 → back-fill each named suite's header per [U4 Build and verify](build.md) > Header contract > *Adopting the contract over existing suites*, or repair the unreadable `.claude/autoflow.local.json`. The AutoFlow version is not a stop condition: a newer release reaches the operator through Claude Code's plugin update.

**Reviewer configuration.** PREFLIGHT runs `<autoflow-root>/scripts/preflight/check-review-backend.sh`, which resolves the external reviewers HANDOFF runs beside the built-in review — from the target's `.claude/autoflow.local.json` at its repository root when it has `.review`, else from the operator's `~/.autoflow/config.json`, else none ([`reviewer-backend.md`](../reviewer-backend.md) > *Config location*) — prints the `reviewers:`, `source:` and `user-config:` readout lines, and probes each reviewer's CLI presence-only (`command -v`; auth is not probed). Exit `2` — the target file cannot be read as configured — stops the cycle until it is fixed. Exit `1` — a configured reviewer's CLI absent — does not: HANDOFF runs the built-in review without that reviewer and names it on the aggregated comment. Exit `6` with the marker line `user-config: UNREADABLE <path> — <error>` — the operator file is the source (`source: user <path>`) and cannot be read as configured, so nothing in it applies — is put to the operator, situation-first, with the path and the error: proceed without external review (the cycle continues and HANDOFF runs the built-in review alone), or stop (no state file is written; the operator fixes the file and PREFLIGHT runs again, reading it anew). A `user-config: WARNING …` line — a broken operator file while the target's `.review` decides — changes nothing and asks nothing. On exit `0`, `1` and `6` — on `6` once the operator has answered — the orchestrator appends the result to the issue's ledger as a record entry, `<C>` being the cycle the state file will carry, each line copied from the readout:

```
### preflight-review-config | cycle: <C>
- reviewers: <names|none>
- source: local <path> | user <path> | none
- user-config: absent [<path>] | ok <path> | WARNING <path> — <error> | UNREADABLE <path> — <error>
- exit: 0 | 1 | 6
- operator: proceed without external review | stop
```

The `operator:` line is written only on exit `6`. See [`reviewer-backend.md`](../reviewer-backend.md) > *Availability*.

**Target-declared local checks.** PREFLIGHT runs the target repository's **own** readiness procedure through `<autoflow-root>/scripts/preflight/local-checks.sh --ledger <attempt-dir>/issue-{N}-ledger.md --cycle <C>` — after prior-attempt resolution and before the state file is created; `<C>` is the cycle the state file will carry (`1` on a new issue, the incremented value on review-response entry). The target declares that procedure in the target-owned scaffold `.claude/autoflow.local.json` under `preflight.local_checks[]` — one entry per step, each `{ "name", "check", "repair"? }`, where `check` is the command run (exit 0 = ready) and the optional `repair` is run once on a failed `check`, followed by a re-check whose exit is the verdict. A target whose docs name a per-clone setup step (a commit-hook installer, a generated config, a toolchain probe) declares it here; the framework knows **no specific tool** — it runs what is declared and reads only the exit status. **Absent declaration ⇒ no-op**: the record is the single line `PREFLIGHT local checks: none declared`. A declared check that does not pass (after repair, when one is declared) is exit `1` and stops the cycle: run the declared repair, or fix the declaration, then run PREFLIGHT again. A declaration that cannot be read as declared (malformed JSON, wrong types, an entry without a string `check`) is exit `2` and also stops — never a silent no-op. A passing run additionally asserts `git status --porcelain` is empty afterwards: a dirty tree is exit `3` — not a failed check, but the clean-tree condition already broken — so it is resolved with the user's approval and PREFLIGHT is run again. The outcome is written **only** as a ledger record — a level-3 heading `### preflight-local-checks | cycle: <C>` with one `- result:` line whose verdict token is `none declared`, `PASS <name>=PASS[(repaired)] … worktree=clean`, `DIRTY <name>=PASS[(repaired)] … worktree=dirty(<n>)` or `FAIL <name>=FAIL[(…)] … worktree=n/a` (`PASS` is written only when the run passed and the tree is clean) — an identifier-free record entry; the state file is untouched, and the gate hook reads the ledger advisorily only. The commit-time lint-chain obligation (`submodule-common-rules.md` > *Lint chain on the staged surface*) applies on its own: a declared check that installs the lint chain does not replace running it.

**Criterion readiness** (an attempt's start only; issues #430, #466, #465). The criterion review stage's exit condition, read again here: before the state file is created, PREFLIGHT runs `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` on the attempt's dev branch (`--branch` names another), which reads one fact: whether **that attempt's** ledger carries its criterion review's `[criterion-ready]` entry — the record of its settled decisions — for the issue body as GitHub holds it now ([`criterion-review.md`](../criterion-review.md) > *Confirmation*). Another attempt's entry — an earlier attempt of this checkout, or one of another checkout under the same record root — never makes it ready, and another attempt's state file or records under the record root are never a reason for `NOT READY`. It does not judge the review's content, the criteria, or whether the review was thorough — those are the review's: the session's judgment, the advisor's answers and any operator override. Exit `0` (`READY`) passes. Exit `1` (`NOT READY` — no entry, a malformed one, a missing review record, a body edited after the entry, or an attempt that has already started) and exit `3` (the issue body could not be read) leave no state file behind: on exit `1` the attempt's criterion review stage runs again on its dev branch (`entry: criterion-review`) — for a body edited after the entry, the stage's judgment on the edit and a new entry in that attempt's ledger ([`criterion-review.md`](../criterion-review.md) > *Confirmation*), which the session records once the decisions are settled; neither is an operator confirmation. Exit `3` stops the cycle and is reported situation-first; PREFLIGHT runs again once the body can be read. A `review-response` entry, a resume and a paused cycle do not run this check: their criteria were fixed when the attempt began, and a change to them inside a cycle is an `[ac-decision]` ([`decision-ledger.md`](../decision-ledger.md)). An issue filed before this condition existed is reviewed on its turn, with no exemption by filing date ([`criterion-review.md`](../criterion-review.md) > *Issues filed before this procedure*).
