# HANDOFF — Pull request and hand-off

> Phase playbook for HANDOFF. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

AutoFlow's mission ends by handing off an open PR — after PR creation, CI, the configured-reviewer review, and resolved review triage. Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

DELIVER, INTEGRATE and HANDOFF are one functional unit, U6 Delivery
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). What is fixed in it runs
as scripts the orchestrator calls (D8); pushing and opening the pull request are the orchestrator's
own commands; and the judgment left to AI is two readings, both made by a spawned analysis role —
what a reviewer finding is and where it routes, and what class a CI failure is.

- **Goal**: every pull request of the cycle is open with CI green on its head and the configured
  reviewer's review posted with no `Medium`+ finding left, and the state file is handed off.
- **What runs as a script**: CI confirmation and the added-test-file match (*CI*), the reviewer
  run and its start check (*Reviewer review*), the triage case, label backstop and attempt count
  (*Review triage*), the state transition (*End*). Each reports by exit code.
- **Verification**: CI green and the reviewer review clean — both outside the orchestrator's own
  claim.
- **Caps**: auto-resolution of reviewer findings, 7 attempts; HANDOFF internal retry, 2
  ([`CLAUDE.md`](../../CLAUDE.md) > Flow Control > Regressions).
- **Result owed**: the report line of *End*, with each PR's URL and head commit, the CI result and
  the review verdict behind it.

## Push and pull request

These rules hold on every push and every pull request the cycle makes. Everything they do not
name — the branch, the title, how the body is composed, when the push happens — is the
orchestrator's, and nothing checks for an item left out.

- **Pushing and opening a pull request are the orchestrator's own commands.** `git push …` and
  `gh pr create …` are issued as those commands, so the gate hook sees them: it admits them only on
  a recorded AUDIT and GATE:QUALITY PASS with no re-entry open
  ([`CLAUDE.md`](../../CLAUDE.md) > Hook gates). They are not issued through a script or a wrapper
  that would carry them past the hook.
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch (`main`); the hook
  denies both. Merging — including, for multi-repo changes, the sub-repo → pointer → host
  sequencing — is owned entirely by the external review process.
- **Every pull request the cycle opens is a draft carrying `blocked-by-review`**
  (`gh pr create --draft --label blocked-by-review …`): the review gate is per-PR, and the label is
  what the reviewer clears. A host PR that depends on a sub-repo PR also carries
  `blocked-by-subrepo`, the merge-order gate (`--label blocked-by-subrepo`; *Merge Sequencing*
  below).
- **[MUST]** The orchestrator never removes `blocked-by-review` or `blocked-by-subrepo`; the hook
  denies it. The first is cleared by the reviewer's own review, the second by the operator.

What a pull request of a cycle usually carries — offered as what to weigh, not as a checklist:

- a title in the [`title-guide.md`](../title-guide.md) convention and a body written to
  [`pr-body-guide.md`](../pr-body-guide.md);
- on the host PR, the close keyword for the issue (`Closes #N`); a sub-repo PR references the issue
  and carries no close keyword (*Multi-repo delivery* below);
- the `## Verification dispositions` list — the reviewer reads it (`.codex/review.md` > Before
  Reviewing): every issue acceptance criterion not verified by an automated test, with its
  disposition and one-line reason from its verification-design row; the run record of each
  cycle-layer `automated` row and the observation record of each AI-executed `manual` row, from the
  build report; and each test file the cycle added to the target's tree, with its reason and the CI
  job that ran it (*CI* > *Added test files*). Form:
  [`pr-body-guide.md`](../pr-body-guide.md) > *Verification dispositions*;
- the known gaps ([`pr-body-guide.md`](../pr-body-guide.md) > *한계와 known gaps*): each directly
  related problem the cycle separated, with its separation reason
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*), and each gate recommendation deferred or separated at triage
  ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*);
- in a review-response cycle, the existing PR is updated by the push, and its body is brought up to
  this cycle's records before the reviewer reads it again.

## CI

```
bash scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
```

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name. Its
header carries the full contract; the exit codes route as follows.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | green — at least one check present, every one green, on a PR whose mergeable state was confirmed | *Added test files*, then *Reviewer review* |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read | no waiting on CI: resolve against `origin/main` (rebase or merge) and push again (internal retry); a conflict on a `<submodule>` gitlink another cycle advanced → [`external-review-sequencing.md`](../external-review-sequencing.md) > Reconcile preflight |
| `11` | mergeable, and no check was published within the bound (`CI_POLL_TIMEOUT_SECS`, default 900) | not green: look at the CI trigger (webhook delivery, workflow trigger conditions), or push again to force a `synchronize` event, before escalating |
| `12` | a check concluded failure | *CI-failure re-entry* below |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line; check the token's `actions: read`) | raise `CI_POLL_TIMEOUT_SECS` or run again (internal retry), or escalate |
| `14` | the mergeable state could not be confirmed within the bound — a `gh` transport, auth or parse failure | not a conflict: check `gh auth` and connectivity, run again (internal retry), then escalate |
| `64` | usage | fix the invocation |

Cautions:

- The orchestrator does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.
- Exits `10` and `14` carry the reserved `HANDOFF-INTERNAL-RETRY` token on stderr.

**Added test files.** On exit `0`, for the test files this cycle added to the target's tree (the
build report's `## Test files kept`):

```
bash scripts/handoff/ci-test-file-jobs.sh --pr <N> [--repo <owner/name>] <file>...
```

It searches each GitHub Actions job log of the PR head for each path and prints the job that ran
it, or `none`. The criterion is execution visible in a log, not registration in a workflow.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | every file appears in a job's log | the job is recorded beside the file in the PR body's `## Verification dispositions` |
| `1` | a file appears in no job's log | the orchestrator's judgment: wire the file into the target's CI — committed and pushed as an internal retry, then *CI* again — or list it for the reviewer as not run by CI |
| `3` | the head has no GitHub Actions job | `no CI; local run only` is recorded beside each file |
| `2` | a `gh` read failed | run again |

A cycle that added no test file skips this call.

### CI-failure re-entry

A CI failure (exit `12`) re-enters by `remedy_class` through `scripts/gate/remedy-route.sh route`
([`CLAUDE.md`](../../CLAUDE.md) > Flow Control). The orchestrator
does not read the failure log itself (Cost Control): an anonymous direct subagent —
`subagent_type: autoflow-analyzer`, model per policy key `handoff-review-triage` — reads the failing
check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`.autoflow/issue-{N}-ci-failure.md` with the failing check, the first failing assertion or error,
**one `remedy_class`** (`doc` / `test` / `impl` / `design` / `operator`) and the grounds for it —
the class of change that clears the failure, `design` when clearing it would discard or change a
decision the design settled — and returns the class plus a one-line summary.
`scripts/gate/remedy-route.sh route <class>` picks the entry point (`DOC_COMMIT` / `BUILD` /
`ARCHITECT` / `PAUSE`); the re-entered phase runs forward to HANDOFF again and *CI* re-confirms.
Not classifiable with confidence, or the failure output unobtainable → `operator`, never a guess
([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 3). A failure routed with no recorded class is a
report defect: reject and re-spawn the subagent, as for a missing `fail_hypothesis`. The orchestrator
records the route as an `O` ledger entry naming the check and the class. It has no cap of its own: a
`design` route consumes the ARCHITECT re-entry counter, and a `BUILD` route passes through the exit
check and AUDIT on the way back.

## Reviewer review

Every pull request the cycle opened is reviewed on its own diff by the configured reviewer backend
(`codex` default, `claude` opt-in; [`reviewer-backend.md`](../reviewer-backend.md)) — the host PR
and each sub-repo PR alike; a sub-repo PR's review is required, not optional. One run per PR,
launched in the background:

```
bash scripts/review/codex-review-pr.sh --pr <N> --expected-head <branch> [--repo <owner/name>]
bash scripts/review/review-start-check.sh --pr <N> [--repo <owner/name>] [--log <the run's captured output>]
```

The wrapper stops when the PR it is given is not that OPEN PR on that head branch, then spawns an
independent reviewer session (its model and effort are the target's `.claude/autoflow.local.json`
`.review.<backend>` pins when set, else the CLI's defaults). The reviewer reads `.codex/review.md`,
posts a Korean review comment on that PR with severity-ranked findings, and performs the label step
itself: it removes `blocked-by-review` when the review finds no `Medium`+ finding, leaves it
otherwise, and attaches it to a PR whose review confirms a `Medium`+ finding while the label is
absent. The review's output is the PR comment, so a later session or the operator reads it from
GitHub. It does not approve, request changes, merge or close.

`review-start-check.sh` confirms the run began with a signal scoped to its own PR — a reviewer
process or a codex session rollout whose prompt names that pull request, or the wrapper's
completion marker:

| Exit | Meaning | What follows |
|---|---|---|
| `0` | started, or already completed with exit 0 | the orchestrator ends its turn and waits for the run's completion notification ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > *Wait discipline*) |
| `1` | no signal within the window (30 s) | launch the review again once; a second miss goes to the operator |
| `3` | the wrapper completed with a non-zero exit — the review run itself failed | internal retry, then the operator (a review-infrastructure failure is a harness-level block) |

Cautions:

- A review that started is left to finish on its own clock, however long that takes; it is not
  relaunched because it is slow.
- In a review-response cycle the review runs again on each PR of the cycle whose head this cycle
  advanced (`gh pr view <N> --json headRefOid`), whatever its label state; the reviewer recognises
  the re-review.
- Several reviews may run at once (the host PR plus each sub-repo PR); each is confirmed with its
  own `--pr` and, for a sub-repo PR, `--repo`.

## Review triage

Per reviewed PR, after its review completes and before *End*. While it runs the state's marker is
`review-triage` (`bash scripts/state/set-phase.sh --issue {N} --phase review-triage`).

**1. The findings are read by a spawned analysis role.** The orchestrator does not read the
reviewer comment body itself (Cost Control). An anonymous direct subagent —
`subagent_type: autoflow-analyzer`, on the model the policy names for `handoff-review-triage` —
ingests it (`gh pr view <N> --comments`), weighs each finding (*Whether a finding holds*), writes
every item the review raised, at its severity level (`.codex/review.md` > Severity), to that PR's
findings file, and returns `{max_severity, findings}`. Its prompt names the PR under triage as
`<owner>/<name>#<N>`, the decision ledger, and, for a PR whose repository has submodules, their
paths (its `.gitmodules`) — the locations outside that review's target.

- **[MUST] One findings file per reviewed PR.** Each PR's triage writes `.autoflow/issue-{N}-review-findings-<owner>.<name>-<pr>.md` for the reviewed PR `<owner>/<name>#<pr>` — the whole identity; an owner name holds no `.`, so the first `.` separates it. A single-PR cycle follows the same rule. Only that PR's triage writes the file, and a re-review round of the same PR **overwrites** it. The file carries a `pr: <owner>/<name>#<N>` line naming the reviewed PR, exactly one `max_severity: <level>` line — the highest level among the findings, in colon notation, `max_severity: None` on a clean review (never an omitted line) — and one table row per finding, `| <Severity> | <path>:<line> | <remedy_class> | <finding> |` — severity first, location second (a path relative to the reviewed PR's repository root), and `remedy_class` on every Medium+ row. `scripts/handoff/review-gate.sh` reads the file and exits `2` on one that does not keep this contract; the subagent is then spawned again.
- **[MUST] A PR's review covers its own repository.** A review's target is what the reviewed PR's repository tracks directly — every file of its tree, a submodule's pointer included, never a submodule's contents (`.codex/review.md` > Before Reviewing). Every finding therefore belongs to the reviewed PR, and its `max_severity` and `blocked-by-review` label rest on that PR's own findings alone. A host PR whose diff is a submodule pointer is reviewed over the host repository like any other PR; the sub-repo code behind the pointer is judged by the sub-repo PR's review. A finding a review raises inside a submodule misreads that target: the ingesting subagent writes it as a finding that does not hold, and the rebuttal returns it to the reviewer's re-review. What keeps a host PR from merging ahead of its sub-repo PR is `blocked-by-subrepo`, not the host PR's review label ([`external-review-sequencing.md`](../external-review-sequencing.md) > *Review gate and merge-order gate*).
- **[MUST] `remedy_class` per Medium+ finding.** The ingesting subagent tags **every** `Medium`+ finding with a `remedy_class` from the same vocabulary the late-gate evaluator uses (`doc` / `test` / `impl` / `design` / `operator`, defined at [GATE:QUALITY](gate-quality.md) > *FAIL routing*) and writes it in that finding's row. The classifying question is **not** how large the fix is: it is **does clearing this finding discard or change a decision the design settled?** Yes → `design`. No → the class of change that clears it. Not classifiable with confidence → `operator`, never a guess.

**2. The case is read by script.**

```
bash scripts/handoff/review-gate.sh --issue {N} --pr <P> [--repo <owner/name>]
```

It reads the two signals — the verdict (`max_severity`, the primary signal) and the
`blocked-by-review` label (a derived signal that can disagree with it) — and the auto-resolution
attempts on record, and names the case:

| Exit | Case | What follows |
|---|---|---|
| `0` | `clean` — no label, no finding | *End* (once every PR of the cycle is there) |
| `13` | `low-only` — no label, findings below `Medium` | the orchestrator's judgment, with no fixed rule: a finding that holds and is worth fixing now goes through the same resolution as below (a `Low` alone raises no advisor request unless an advisor criterion is hit); otherwise *End*, optionally with a one-line PR note that the findings were reviewed and deferred. A `Low` on a target comment's divergence or disallowed content is the orchestrator's direct commit or it is left ([GATE:QUALITY](gate-quality.md) > *Code comments in a target*) |
| `10` | `resolve` — a `Medium`+ verdict | *Routing* below. When the label was absent — a previous clean round cleared it and the reviewer's own attach did not land — the script has attached it as the orchestrator's backstop (`backstop: attached`); `backstop: attach failed` means the label likely does not exist in that repository, reported as an operator setup gap ([`external-review-sequencing.md`](../external-review-sequencing.md) > Operator prerequisites) without blocking the resolution |
| `11` | `cap` — a `Medium`+ verdict with 7 attempts on record | pause for the operator (*Attempt cap*) |
| `12` | `rerun-review` — the label is present on a verdict below `Medium` | not a code finding: the review was clean and the label stuck (`.codex/review.md` > label-removal-failure clause), or a backstop attached in error. Run *Reviewer review* on that PR again so the re-review clears the label; still there → a harness-level block for the operator. Consumes no attempt |
| `2` | the findings file is absent or breaks its contract | the triage subagent is spawned again |
| `3` | a `gh` read failed | run again (internal retry) |

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The ingesting subagent, the one that reads the comment, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A role the route hands a finding to that finds in its work that the finding does not hold reports it with the same grounds.

A rebuttal is not a dismissal: the side that raised the finding judges it. The orchestrator posts the rebuttal with its grounds on the PR and runs *Reviewer review* on that PR again; the reviewer reads it with the comments since the previous change and keeps or withdraws the finding. The label, which only a confirmed `Medium`+ finding keeps or attaches, is still cleared only by that re-review. A gate recommendation's rebuttal is judged by the recommending gate's re-score. A finding that does not hold is not routed — its row keeps the class its own fix would take — and one that holds in part is routed by the class its real problem needs. Each rebuttal is recorded with its grounds in the ledger entry of its round: the attempt's `[review-autofix]` entry, or, for a round that only rebuts and so routes nothing, an `O` entry whose heading ends in `[rebuttal]`, which no cap counts. At a gate that entry is also what an interrupted session resumes from ([PREFLIGHT](preflight.md) > *Resume*). When a rebutted finding is kept and the two sides still disagree, the orchestrator asks the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor; [`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 3). When to ask is its judgment and no count decides it.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A review-response can loop: each fix answers the case the reviewer named while the property the
reviewer asserts stays unmet, and the next review names another case. No spawn checks for this on
every attempt. Whoever reads the finding — the triage subagent here, or the DIAGNOSE unit in a
review-response cycle entered at PREFLIGHT — and sees that it repeats the complaint of the previous
attempt (the same property asserted, a different witness case; the previous attempt's
`[review-autofix]` entry and the previous cycle's artifacts are what it compares against) says so
where it writes the finding: in the finding's cell of the findings file, or under the analysis
report's `## Decision points`. The orchestrator then puts it to the advisor
([`role-contracts.md`](../role-contracts.md) > Advisor) with a request written situation-first —
for example restating the acceptance criterion as one rule over the whole input, or a further
case-specific change — and the advisor's `A` entry decides the re-entry: its depth, or none. A
redefined criterion is recorded as `[ac-decision]` entries and the cycle restarts from DIAGNOSE on
it. A complaint the advisor has already decided is not put again without a new verified fact
([`CLAUDE.md`](../../CLAUDE.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case; it is routed like any finding.

### Routing

A `Medium`+ verdict does not end the cycle. Route by `bash scripts/gate/remedy-route.sh route <class>...` over the classes of the Medium+ findings that hold, in whole or in part (mixed → farthest; `operator` anywhere stops routing and goes to the advisor) — the same single owner of the mapping the late gates use:

| Route | What the orchestrator runs | Re-review |
|---|---|---|
| `ARCHITECT` (from `design`) | the design owns the moved decision; the re-entry point is the orchestrator's recorded judgment (below) — a review-response cycle from DIAGNOSE, or an ARCHITECT re-design | *Reviewer review*, per-PR |
| `BUILD` (from `impl` / `test`) | a BUILD unit re-run naming the finding fixes it on the finding's own surface — the implementation, or the test asset (a rewritten `driving` / `regression` test shown failing again first) → exit check ([BUILD](build.md) > *Re-entry*) | *Reviewer review*, per-PR |
| `DOC_COMMIT` (from `doc`) | orchestrator doc commit → the local run the doc diff requires | *Reviewer review*, per-PR |
| `PAUSE` (from `operator`) | the advisor fixes the class ([`role-contracts.md`](../role-contracts.md) > Advisor), and the cycle takes that class's route | that route's |

The `ARCHITECT` route is the one whose depth is judged. **Where the re-entry starts is the orchestrator's judgment** ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2), recorded with its grounds in this attempt's `[review-autofix]` ledger entry before the routed work starts. The two shapes: (a) a **review-response cycle from DIAGNOSE** — entered in-session with `bash scripts/preflight/preflight.sh review-response --issue {N}` ([PREFLIGHT](preflight.md) > *Review-response setup*) and the reviewer comment as the DIAGNOSE trigger target, flowing DIAGNOSE → … → HANDOFF — when the finding contradicts what the problem or the affected structure is, a fact of the analysis the decision rested on; (b) an **ARCHITECT re-design** — the same setup with `--keep-analysis`, whose two differences follow from the analysis standing: `phases` is reset only for the gates this shape re-runs (GATE:PLAN, AUDIT, GATE:QUALITY; the GATE:HYPOTHESIS record stays), and the **DIAGNOSE analysis report is not renamed** — `issue-{N}-analysis.md` stays in place under its flat name as this cycle's analysis input. A fresh U3 Design unit is spawned with a prompt naming the finding, the decision it moves — its heading in the previous cycle's `issue-{N}-c{C}-feature-design.md` — and the previous cycle's design documents, preserved as `issue-{N}-c{C}-feature-design.md` / `issue-{N}-c{C}-verification-design.md` like the other renamed artifacts ([ARCHITECT](architect.md) > *Re-entry*, the new-cycle rule), flowing ARCHITECT → GATE:PLAN → … → HANDOFF — when the finding moves a design decision on a problem whose analysis still stands. The ledger entry names the shape, the fact it rests on (the finding's `path:line` and the decision it moves, by its heading in `issue-{N}-c{C}-feature-design.md`), why the analysis stands, and the **provenance of the reused analysis report** — its path, the cycle that authored it and its `shasum -a 256`. The gate records a shape keeps are what admit its spawns — the hook admits the ARCHITECT unit on the recorded GATE:HYPOTHESIS verdict and the BUILD unit on the GATE:PLAN that re-scores the re-design. The other routes are **thin**: one BUILD unit re-run or one doc commit, execution verification, a delta recorded in the ledger, and the same reviewer re-review — no DIAGNOSE, no ARCHITECT, no GATE:PLAN, no fresh evaluator re-read. **Every independent check is retained on every route and shape** — the label is cleared **only** by the reviewer re-review, the orchestrator never removes it (hook deny), CI still gates, and the attempt cap below applies unchanged.

Every route is recorded in `.autoflow/issue-{N}-ledger.md` with a `review-autofix` marker — a level-2 heading of the form `## O<n> — <title> (cycle <C>, HANDOFF) [review-autofix]` ([`decision-ledger.md`](../decision-ledger.md) > *Entry identifier*) — and the entry names the routed class and, on the `ARCHITECT` route, the judged shape with its grounds. The advisor criteria below take precedence over any route.

- **Put to the advisor** (a request written situation-first per [`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation — [`role-contracts.md`](../role-contracts.md) > Advisor; the cycle does not pause) when the attempt hits **any** of: (a) the fix needs a contract / acceptance-criterion change, or the finding shows a criterion defective ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), (b) the fix direction is ambiguous, (c) the finding is a `Low Confidence` item, (d) the finding repeats the previous attempt's complaint (*A repeated complaint* above). The advisor's `A` entry selects re-entry; the operator may override it at the retry stage. A rebutted finding kept while the two sides still disagree reaches the advisor by the orchestrator's judgment (*Whether a finding holds* above), not by a criterion here.
- **Attempt cap = 7.** The count is the number of auto-resolution attempts not yet checked with the user: the `[review-autofix]` entries in the ledger after the last entry whose heading ends in `[reentry-decision]`, or all of them when there is none. `review-gate.sh` prints it (`attempts: <k> of 7`) and exits `11` when a `Medium`+ verdict meets 7 on record: the orchestrator stops auto-resolving and pauses for the user (`bash scripts/state/set-phase.sh --issue {N} --phase awaiting-user`). A gate's recommendation attempt carries its own marker, `[gate-autofix]`, on its own window ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*), and a `[rebuttal]` round is not an attempt, so neither is counted here. The user approving continuation at that pause is the **re-entry decision**: the orchestrator records it as an `O` entry under `operator decision` whose heading ends in `[reentry-decision]` and sets the cycle active again (`set-phase.sh --phase review-triage`); the entry resets the window — the next auto-entry starts a fresh budget of 7. Nothing else resets it.
- **Durable record (host PR).** Post a one-line comment on the **host PR** via `gh pr comment <hostPR> --body "[autoflow:review-autofix] …"` for two events: (i) when the cap fired — the 7th consecutive attempt paused for the user — and (ii) when a user **re-entry decision** approved continuation (the window-reset event).

## End

Once every pull request of the cycle is clean — no `blocked-by-review` label left, Low findings
triaged — and CI is green:

```
bash scripts/state/set-phase.sh --issue {N} --phase awaiting-external-review --pr <[owner/name#]P>...
```

It names every PR the cycle opened, refuses (exit `1`, state unchanged) while one of them still
carries `blocked-by-review`, sets `active:false` with `phase: "awaiting-external-review"`, and
removes the issue's `status:in-progress` label. The same script makes every other `active:false`
transition (`--phase awaiting-user`, at a pause).

Report: "PR #N open (draft) — configured-reviewer review posted — handed to external review." with
each PR's URL and head commit. AutoFlow ends; the session may terminate.

The cleanup that follows an external merge or rejection runs at PREFLIGHT of the next cycle (or in the live session if it observes the decision before terminating) — dev-branch deletion plus archival (move to the external `$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/` store) of the resolved issue's `.autoflow/issue-{N}*` management files; see [PREFLIGHT](preflight.md) > *The run*.

## Failure and retry

Classify the cause and regress along the matching path.

```
CI failure (a check concluded failure, exit 12) → by remedy_class (CI-failure re-entry above)
CI failure (env / transient)                   → CI retry, then the CI confirmation again (max 2)
PR CONFLICTING (no checks,                     → resolve vs origin/main (rebase/merge) + push again, OR
 build silently skipped)                          concurrent-cycle gitlink → Reconcile preflight;
                                                  then the CI confirmation again (max 2) — never wait on CI green
Push rejected (branch state)                   → dev branch rebase on main → push again (max 2)
```

**Max retries**: HANDOFF internal retry max 2. Two failures → human.
**Re-entry regression**: the ARCHITECT re-entry (max 3) rule applies to a `design` route; a `BUILD` route passes through the exit check and AUDIT ([BUILD](build.md) > *Re-entry*).

## Multi-repo delivery

Topology decides which PRs HANDOFF creates (see [`CLAUDE.md`](../../CLAUDE.md) > Deployment Topology): in a single-repo deployment (target-centric — the default; zero submodules), HANDOFF creates one host PR. In a multi-repo deployment (one or more submodules), HANDOFF creates each affected sub-repo PR plus the host PR; change scope determines which sub-repo PRs exist.

*Secondary (multi-repo):* Sub-repo changes present:

- **Sub-repo PRs.** Each sub-repo PR (fork → upstream) is created as a draft **with `--label "blocked-by-review"`**, body `Part of Munsik-Park/autoflow#N` (no close keyword; only the host PR closes the issue). The review gate is **per-PR**: **every** PR created for this cycle — the host PR *and* each sub-repo PR — carries `blocked-by-review` and is reviewed on its **own diff**. The `blocked-by-review` label must exist in each sub-repo (one-time operator setup — see [`external-review-sequencing.md`](../external-review-sequencing.md)). `blocked-by-subrepo` is a separate, host-only merge-order gate, not a review gate.
- **Pointer bump before the host PR.** **Before** creating the host PR, the **orchestrator** aligns the host dev branch's `<submodule>` gitlink to this cycle's sub-repo PR head — this is the **single source** of the pointer-bump commit format: run `git -C <submodule> checkout <sub-repo-PR-head>`, then `git add <submodule>`, then commit with the message `chore(#N): bump <submodule> pointer to <short-sha>` (the same `chore(#N): …` convention as the `git-workflow.md` reconcile snippet; DELIVER and the review-response re-bump below forward-ref this format rather than restating it). The host PR is then created as a draft carrying `blocked-by-review` and `blocked-by-subrepo` (*Push and pull request* above). The body is the template-rendered host PR body (see `.github/pull_request_template.md` and Issue Auto-Close in [`git-workflow.md`](../git-workflow.md)).
- **[MUST] Review-response re-bump.** Once the sub-repo fix has landed and that sub-repo PR has reached its clean point (the propagation-batching condition below), and **before** the push that updates the host PR, re-bump the host `<submodule>` pointer to that sub-repo PR's new head **once**, then confirm `git ls-tree HEAD <submodule> | awk '{print $3}'` equals that head. This manual pointer-equality check fires once at the clean point, not for a fix push in isolation.
- **Propagation batching.** When a sub-repo fix would bump the host `<submodule>` pointer, **defer** the host pointer bump until that sub-repo PR reaches its **clean point**: its `blocked-by-review` label has cleared (its reviewer re-review is clean), or every `Medium`+ finding its latest review keeps is accepted by the advisor or the operator — an `A` ledger entry under `advisor decision`, or an `O` entry under `operator decision`, appended after that review ([`decision-ledger.md`](../decision-ledger.md) > *Decision-point entries*). At that clean point bump **once** — the same re-bump point as the `[MUST]` above. A bump at an acceptance is a clean-point bump, not an interim one: it takes the ordinary commit format, and the acceptance entry is its record. This holds for the general parent-pointer / sub-repo-PR relation, independent of how many repos deep the change sits. If an intervening host-CI check makes an exceptional interim bump unavoidable, record the reason in the commit message (`chore(#N): interim <submodule> bump: <reason>`). This bullet is the source of truth for the batching norm; [`external-review-sequencing.md`](../external-review-sequencing.md) carries a one-line cross-ref for reviewers.
- Submodule pointer reconciliation after the sub-repo PR is merged upstream defaults to the operator but may be delegated to AutoFlow on explicit request.

## Merge Sequencing (external review)

In a single-repo deployment (target-centric — the default; zero submodules), the cycle produces a single host PR and there is no sub-repo merge-order step at all: HANDOFF opens one host PR with no `blocked-by-subrepo` label, and the external reviewer promotes the draft to ready and merges it directly. The merge-order sequence below governs only a multi-repo deployment.

*Secondary (multi-repo):* AutoFlow opens the host PR as a draft with the `blocked-by-subrepo` label; merging is performed by the external reviewer in this order (see [`external-review-sequencing.md`](../external-review-sequencing.md) for the full reviewer-facing procedure, and [`submodule-common-rules.md`](../submodule-common-rules.md) > **Submodule URL & Pointer Policy**):

1. **Sub-repo PR merged first.** The reviewer merges the host's direct sub-repo PR into `{{REPO_SERVICE_HOST}}:main` (the PR of a submodule nested inside the sub-repo is merged by that sub-repo's own procedure first, outside host handoff scope). The host PR carries the `blocked-by-subrepo` label through this step; the operator removes the label once the sub-repo merge and pointer reconcile are confirmed complete, which clears the host PR for merge (see [`external-review-sequencing.md`](../external-review-sequencing.md) > Merge-order clearance).
2. **Pointer reconciliation in the host dev branch.** The reviewer updates the submodule pointer in the host PR's dev branch to the sub-repo PR's merge commit, then pushes (or asks the original branch owner to push, which may be AutoFlow on explicit request). When delegated to AutoFlow, this step follows the **Reconcile preflight** (concurrent-cycle gitlink guard + post-reconcile mergeable/head-commit check gate) in [`external-review-sequencing.md`](../external-review-sequencing.md) > Reconcile preflight.
3. **Operator confirms the sub-repo merge and pointer reconcile.** Before the merge-order gate is cleared, the operator manually verifies that (i) the host PR is open and carries `blocked-by-subrepo`, (ii) the upstream sub-repo PR is `merged`, and (iii) the host PR's submodule pointer equals that sub-repo PR's merge commit (the pointer reconcile of a submodule nested inside the sub-repo is the sub-repo's own concern). This pointer-equality confirmation is the operator's manual check (see [`external-review-sequencing.md`](../external-review-sequencing.md) > Merge-order clearance). Once confirmed, the operator removes `blocked-by-subrepo`. See [`external-review-sequencing.md`](../external-review-sequencing.md) for the full operator + reviewer guide.
4. **Promote the host PR draft → ready.** The reviewer manually clicks "Ready for review" once their internal review checklist is satisfied. AutoFlow does not auto-promote.
5. **Merge the host PR.** With the `blocked-by-subrepo` label removed and the PR ready, the reviewer merges. The host PR body's literal close-keyword line closes the issue.

**Host-only case**: items 1–3 are skipped. The reviewer still performs items 4 and 5 manually.

**[MUST]** AutoFlow does not perform items 1, 4, or 5. Item 2 may be delegated to AutoFlow on explicit request. AutoFlow only creates the draft PR(s). The hook continues to deny `gh pr merge` and pushes to `main` while a state file has `active:true`.
