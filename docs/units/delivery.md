# U6 Delivery — DELIVER, INTEGRATE and HANDOFF

> Unit document for U6. [`CLAUDE.md`](../../CLAUDE.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

AutoFlow's mission ends by handing off an open PR — after PR creation, CI, the configured-reviewer review, and resolved review triage. Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

DELIVER, INTEGRATE and HANDOFF are one functional unit, U6 Delivery
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). U6 has no unit agent: it
is the orchestrator's own work ([`role-contracts.md`](../role-contracts.md) > Spawn mode by role
lifetime) — every unit agent has already ended by returning its report. This file states what is
asked, the cautions and the result owed. A script only reads and reports (D8); what changes
anything — a push, a pull request, a label, the state file, the ledger — is done by the
orchestrator itself; and the judgment left to AI is two readings, both made by a spawned analysis
role — what a reviewer finding is and where it routes, and what class a CI failure is.

- **Goal**: the cycle's branch is on the remote at the commit GATE:QUALITY passed, the change is
  shown working above its own tests, every pull request of the cycle is open with CI green on its
  head and the configured reviewer's review posted with no `Medium`+ finding left, and the state
  file is handed off.
- **Artifact contract**: the pushed branches and the pull requests (*Push and pull request*), the
  integration record (*Integration*), each reviewed PR's findings file (*Review triage*), and the
  ledger entries the routes record.
- **What a script reads and reports**: CI confirmation and the added-test-file match (*CI*), the
  reviewer run's start check (*Reviewer review*; the run itself is the reviewer wrapper), and the
  triage case with its attempt count (*Review triage*). Each reports by exit code.
- **Verification**: the integration checks, CI green and the reviewer review clean — all outside
  the orchestrator's own claim.
- **Loop cap**: auto-resolution of reviewer findings, 7 attempts; HANDOFF internal retry, 2
  ([`CLAUDE.md`](../../CLAUDE.md) > Flow Control > Regressions). An INTEGRATE or CI failure is fixed
  by the unit its class routes to, and the cycle runs forward again (*Integration*, *Failure and
  retry*).
- **Result owed**: the report line of *End*, with each PR's URL and head commit, the CI result and
  the review verdict behind it.

## Push and pull request

**DELIVER.** The cycle's branch is on the remote, at the commit GATE:QUALITY passed; the pushed
branch and its head commit are carried in the change summary. Which remote, which flags and when
are the orchestrator's. A changed sub-repo's branch is pushed the same way, by the orchestrator's
own `git -C <sub-repo> push …`, to the remote the project's information names for it; the host
pointer that follows it is *Multi-repo delivery* below.

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
- the acceptance-criterion check — one line per issue criterion: whether it is met, the commit it
  was confirmed at and where the evidence is, under a head naming the commit the results stand at
  ([`pr-body-guide.md`](../pr-body-guide.md) > *수용 기준 대조*);
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
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*);
- in a review-response cycle, the existing PR is updated by the push, and its body is brought up to
  this cycle's records before the reviewer reads it again.

## Integration

INTEGRATE looks at the change as the system runs it, beyond what BUILD verified per acceptance
criterion.

- **What is asked**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks that takes, and how they are run, is the orchestrator's, the way
  the target runs them ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification
  and Tools).
- **Result owed**: one line per check — its command and the summary line read from its log, the
  log kept under `.autoflow/issue-{N}-local/` — or the no-op line below. A check that was not run
  is `not-run`, never `passed`.
- **Failure**: INTEGRATE FAIL → BUILD — fixed `impl` class: a BUILD unit re-run with the failing
  check fixes it, and the cycle runs forward through AUDIT to INTEGRATE again ([U4 Build and verify](build.md) >
  *Re-entry*).

Cautions:

- A project with no integration layer records `INTEGRATE: no-op (no integration suite)`. That is
  a stated no-op, not a skipped check.
- In a project with sub-repos the system is built in the dev environment and what crosses sub-repos
  is what is verified: each affected sub-repo builds (for example
  `docker compose -f docker-compose.dev.yml up -d --build <services>`), each service's health check
  passes, the functional integration tests pass, and the cross-cutting concerns the change touches
  (auth, network ingress) are looked at.

### Deploy/CI-path conditional verification

A **diff-path-conditional** requirement keyed on the class of surface being integrated. It applies to every project; a class the project does not ship resolves to a defined no-op.

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD main`). The condition **fires** iff any changed path matches the trigger glob set:

| Class | Glob(s) |
|---|---|
| Submodule layout | `.gitmodules` |
| CI config | `.github/workflows/**`, `**/Jenkinsfile`, `Jenkinsfile` |
| Deploy scripts | `deploy-*.sh`, `**/deploy-*.sh` |
| Env / build-arg | `.env`, `.env.*`, `**/.env`, `**/.env.*` |

Stated as one command (the frozen predicate):

```
git diff --name-only <base>...HEAD \
  | grep -E '(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
```

Non-empty ⇒ the verification bundle below is owed, each item PASS or FAIL. Empty ⇒ record `INTEGRATE deploy/CI-path: no-op (diff touched no deploy/CI-path surface)` — a defined no-op, not a discretionary skip.

**Verification bundle** (owed only when the predicate's output is non-empty; each item is itself a defined no-op when the target ships no such surface):

- **(a) Deploy-script dry-run, incl. recursive submodule init** — the target's `deploy-*.sh` in dry-run (`--dry-run` / read-only) with `git submodule update --init --recursive`, confirming the deploy path resolves the current submodule pointers. *No-op* when the target ships no deploy script.
- **(b) CI-config static validation** — a lint / schema check of the changed CI file itself (`.github/workflows/*` via `actionlint` / YAML-schema; `Jenkinsfile` via the target's `jenkins declarative-linter` or equivalent). *No-op* when no CI file changed.
- **(c) Landing/host routing smoke check** — a smoke request against the built host / landing route (health / routing reachability). *No-op* when the target exposes no host / landing route.

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is an **INTEGRATE FAIL → BUILD** (`impl` class; the re-run above).

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
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read | no waiting on CI: resolve against `origin/main` (rebase or merge) and push again (internal retry); a conflict on a sub-repo pointer another cycle advanced → *Multi-repo delivery* below |
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
records the route as an `O` ledger entry naming the check and the class.

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
`review-triage`, set by the orchestrator.

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
- **[MUST] `remedy_class` per Medium+ finding.** The ingesting subagent tags **every** `Medium`+ finding with a `remedy_class` from the same vocabulary the late-gate evaluator uses (`doc` / `test` / `impl` / `design` / `operator`, defined at [U5 Completion evaluation](completion-evaluation.md) > *FAIL routing*) and writes it in that finding's row. The classifying question is **not** how large the fix is: it is **does clearing this finding discard or change a decision the design settled?** Yes → `design`. No → the class of change that clears it. Not classifiable with confidence → `operator`, never a guess.

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
| `13` | `low-only` — no label, findings below `Medium` | the orchestrator's judgment, with no fixed rule: a finding that holds and is worth fixing now goes through the same resolution as below (a `Low` alone raises no advisor request unless an advisor criterion is hit); otherwise *End*, optionally with a one-line PR note that the findings were reviewed and deferred. A `Low` on a target comment's divergence or disallowed content is the orchestrator's direct commit or it is left ([U5 Completion evaluation](completion-evaluation.md) > *Code comments in a target*) |
| `10` | `resolve` — a `Medium`+ verdict | *Routing* below. With `backstop: needed` — the label is absent, because a previous clean round cleared it and the reviewer's own attach did not land — the orchestrator attaches it first as its backstop (`gh pr edit <N> --add-label blocked-by-review`, on failure the `gh issue edit` form) and confirms it is on the PR. An attach that does not land likely means the label does not exist in that repository: it is reported as an operator setup gap ([`external-review-sequencing.md`](../external-review-sequencing.md) > Operator prerequisites) and does not block the resolution. The orchestrator attaches this label and never removes it |
| `11` | `cap` — a `Medium`+ verdict with 7 attempts on record | pause for the operator (*Attempt cap*) |
| `12` | `rerun-review` — the label is present on a verdict below `Medium` | not a code finding: the review was clean and the label stuck (`.codex/review.md` > label-removal-failure clause), or a backstop attached in error. Run *Reviewer review* on that PR again so the re-review clears the label; still there → a harness-level block for the operator. Consumes no attempt |
| `2` | the findings file is absent or breaks its contract | the triage subagent is spawned again |
| `3` | a `gh` read failed | run again (internal retry) |

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The ingesting subagent, the one that reads the comment, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A role the route hands a finding to that finds in its work that the finding does not hold reports it with the same grounds.

A rebuttal is not a dismissal: the side that raised the finding judges it. The orchestrator posts the rebuttal with its grounds on the PR and runs *Reviewer review* on that PR again; the reviewer reads it with the comments since the previous change and keeps or withdraws the finding. The label, which only a confirmed `Medium`+ finding keeps or attaches, is still cleared only by that re-review. A gate recommendation's rebuttal is judged by the recommending gate's re-score. A finding that does not hold is not routed — its row keeps the class its own fix would take — and one that holds in part is routed by the class its real problem needs. Each rebuttal is recorded with its grounds in the ledger entry of its round: the attempt's `[review-autofix]` entry, or, for a round that only rebuts and so routes nothing, an `O` entry whose heading ends in `[rebuttal]`, which no cap counts. At a gate that entry is also what an interrupted session resumes from ([U1 Preparation](preparation.md) > *Resume*). When a rebutted finding is kept and the two sides still disagree, the orchestrator asks the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor; [`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 3). When to ask is its judgment and no count decides it.

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
| `BUILD` (from `impl` / `test`) | a BUILD unit re-run naming the finding fixes it on the finding's own surface — the implementation, or the test asset ([U4 Build and verify](build.md) > *Re-entry*) | *Reviewer review*, per-PR |
| `DOC_COMMIT` (from `doc`) | orchestrator doc commit → the local run the doc diff requires | *Reviewer review*, per-PR |
| `PAUSE` (from `operator`) | the advisor fixes the class ([`role-contracts.md`](../role-contracts.md) > Advisor), and the cycle takes that class's route | that route's |

The `ARCHITECT` route is the one whose depth is judged. **Where the re-entry starts is the orchestrator's judgment** ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2), recorded with its grounds in this attempt's `[review-autofix]` ledger entry before the routed work starts. The two shapes: (a) a **review-response cycle from DIAGNOSE** — entered in-session with the setup PREFLIGHT gives a review-response ([U1 Preparation](preparation.md) > *Review-response setup*) and the reviewer comment as the DIAGNOSE trigger target, flowing DIAGNOSE → … → HANDOFF — when the finding contradicts what the problem or the affected structure is, a fact of the analysis the decision rested on; (b) an **ARCHITECT re-design** — the same setup with two differences that follow from the analysis standing: `phases` is reset only for the gates this shape re-runs (GATE:PLAN, AUDIT, GATE:QUALITY; the GATE:HYPOTHESIS record stays), and the **DIAGNOSE analysis report is not renamed** — `issue-{N}-analysis.md` stays in place under its flat name as this cycle's analysis input. A fresh U3 Design unit is spawned with a prompt naming the finding, the decision it moves — its heading in the previous cycle's `issue-{N}-c{C}-feature-design.md` — and the previous cycle's design documents, preserved as `issue-{N}-c{C}-feature-design.md` / `issue-{N}-c{C}-verification-design.md` like the other renamed artifacts ([U3 Design](design.md) > *Re-entry*, the new-cycle rule), flowing ARCHITECT → GATE:PLAN → … → HANDOFF — when the finding moves a design decision on a problem whose analysis still stands. The ledger entry names the shape, the fact it rests on (the finding's `path:line` and the decision it moves, by its heading in `issue-{N}-c{C}-feature-design.md`), why the analysis stands, and the **provenance of the reused analysis report** — its path, the cycle that authored it and its `shasum -a 256`. The gate records a shape keeps are what admit its spawns — the hook admits the ARCHITECT unit on the recorded GATE:HYPOTHESIS verdict and the BUILD unit on the GATE:PLAN that re-scores the re-design. The other routes are **thin**: one BUILD unit re-run or one doc commit, execution verification, a delta recorded in the ledger, and the same reviewer re-review — no DIAGNOSE, no ARCHITECT, no GATE:PLAN, no fresh evaluator re-read. **Every independent check is retained on every route and shape** — the label is cleared **only** by the reviewer re-review, the orchestrator never removes it (hook deny), CI still gates, and the attempt cap below applies unchanged.

Every route is recorded in `.autoflow/issue-{N}-ledger.md` with a `review-autofix` marker — a level-2 heading of the form `## O<n> — <title> (cycle <C>, HANDOFF) [review-autofix]` ([`decision-ledger.md`](../decision-ledger.md) > *Entry identifier*) — and the entry names the routed class and, on the `ARCHITECT` route, the judged shape with its grounds. The advisor criteria below take precedence over any route.

- **Put to the advisor** (a request written situation-first per [`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation — [`role-contracts.md`](../role-contracts.md) > Advisor; the cycle does not pause) when the attempt hits **any** of: (a) the fix needs a contract / acceptance-criterion change, or the finding shows a criterion defective ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), (b) the fix direction is ambiguous, (c) the finding repeats the previous attempt's complaint (*A repeated complaint* above). The advisor's `A` entry selects re-entry; the operator may override it at the retry stage. A rebutted finding kept while the two sides still disagree reaches the advisor by the orchestrator's judgment (*Whether a finding holds* above), not by a criterion here.
- **Attempt cap = 7.** The count is the number of auto-resolution attempts not yet checked with the user: the `[review-autofix]` entries in the ledger after the last entry whose heading ends in `[reentry-decision]`, or all of them when there is none. `review-gate.sh` prints it (`attempts: <k> of 7`) and exits `11` when a `Medium`+ verdict meets 7 on record: the orchestrator stops auto-resolving and pauses for the user (`active:false`, `phase:"awaiting-user"`). A gate's recommendation attempt carries its own marker, `[gate-autofix]`, on its own window ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*), and a `[rebuttal]` round is not an attempt, so neither is counted here. The user approving continuation at that pause is the **re-entry decision**: the orchestrator records it as an `O` entry under `operator decision` whose heading ends in `[reentry-decision]` and sets the cycle active again; the entry resets the window — the next auto-entry starts a fresh budget of 7. Nothing else resets it.
- **Durable record (host PR).** Post a one-line comment on the **host PR** via `gh pr comment <hostPR> --body "[autoflow:review-autofix] …"` for two events: (i) when the cap fired — the 7th consecutive attempt paused for the user — and (ii) when a user **re-entry decision** approved continuation (the window-reset event).

## End

Once every pull request of the cycle is clean — `review-gate.sh` reports no `blocked-by-review`
label on any of them and the Low findings are triaged — and CI is green, the orchestrator hands the
cycle off:

- the state file reads `active: false`, `phase: "awaiting-external-review"`, with nothing else in
  it changed;
- the issue no longer carries `status:in-progress`.

Cautions:

- The hand-off is not made while a pull request of the cycle still carries `blocked-by-review`, and
  the orchestrator does not remove that label to get there — the reviewer's re-review clears it.
- A pause for the user is the other `active:false` transition (`phase: "awaiting-user"`); the issue
  keeps `status:in-progress` through it.

Report: "PR #N open (draft) — configured-reviewer review posted — handed to external review." with
each PR's URL and head commit. AutoFlow ends; the session may terminate.

The cleanup that follows an external merge or rejection runs at PREFLIGHT of the next cycle (or in the live session if it observes the decision before terminating) — dev-branch deletion plus archival (move to the external `$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/` store) of the resolved issue's `.autoflow/issue-{N}*` management files; see [U1 Preparation](preparation.md) > *What is asked*.

## Failure and retry

Classify the cause and regress along the matching path.

```
CI failure (a check concluded failure, exit 12) → by remedy_class (CI-failure re-entry above)
CI failure (env / transient)                   → CI retry, then the CI confirmation again (max 2)
PR CONFLICTING (no checks,                     → resolve vs origin/main (rebase/merge) + push again, OR
 build silently skipped)                          a sub-repo pointer → Multi-repo delivery;
                                                  then the CI confirmation again (max 2) — never wait on CI green
Push rejected (branch state)                   → dev branch rebase on main → push again (max 2)
```

**Max retries**: HANDOFF internal retry max 2. Two failures → human.
**Re-entry**: a CI failure is fixed by the unit its class routes to, and the cycle runs forward to *CI* again (*CI-failure re-entry* above); a `design` route consumes the ARCHITECT re-entry counter.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — and the cycle changes one, the sub-repo's
change is delivered on its own pull request and the host follows it by its pointer. AutoFlow does
not classify the project; what the sub-repos are, where each one's pull request goes (a fork, the
upstream) and where issues are filed are read from the project's own information
([`CLAUDE.md`](../../CLAUDE.md) > Project Information).

**The rule.** After a sub-repo pull request merges, the host keeps a clean state by a reconcile
merge: the host branch that depends on it points at that pull request's merge commit, and stays
mergeable with the default branch. Merging is the operator's, so the request to reconcile after a
sub-repo merge is the operator's too; the orchestrator reconciles when it is asked. When the
pointer moves before that point, and how a reconcile is carried out, are the orchestrator's,
derived from this rule and recorded with their grounds in the ledger.

What is asked:

- Each changed sub-repo has its branch pushed and its pull request opened by the orchestrator's own
  commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` — gated like the
  host's, draft and carrying `blocked-by-review` (*Push and pull request*). A sub-repo pull request
  references the host issue (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the
  host pull request is the one that closes the issue.
- A host pull request whose pointer depends on an unmerged sub-repo pull request carries
  `blocked-by-subrepo`, which the operator clears.
- The host pull request's pointer names the sub-repo commit the cycle delivers, so the host review
  reads the pointer and the sub-repo review reads the code behind it (*Review triage*).

Cautions:

- A merge of the default branch into a host branch whose pointer still sits where the branch forked
  resolves the pointer to the default branch's, not to the sub-repo merge commit. The pointer is set
  and read back (`git ls-tree HEAD <sub-repo>`) before the push.
- Another cycle may have moved the default branch's pointer since this branch forked. When the
  sub-repo merge commit does not contain that pointer — the default branch is ahead of it, or the
  two have diverged — reconciling would move the host's pointer backwards or across histories: the
  orchestrator does not push, and reports to the operator.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.
- The gate labels must exist in each repository a pull request is opened in
  ([`external-review-sequencing.md`](../external-review-sequencing.md) > Operator prerequisites).

Result owed: each pull request's URL and head commit; for the host pull request, the commit each
changed sub-repo's pointer names. After a reconcile: the pointer read back equal to the merge
commit, and the CI confirmation on the new head (*CI*).

## Merge Sequencing (external review)

Merging is outside AutoFlow ([`external-review-sequencing.md`](../external-review-sequencing.md)).
A host pull request with no sub-repo dependency is promoted and merged by the external reviewer
directly. One carrying `blocked-by-subrepo` merges after its sub-repo pull request: the sub-repo
pull request merges first, the host is reconciled to its merge commit (*Multi-repo delivery*), the
operator confirms the host pointer equals that merge commit and removes `blocked-by-subrepo`, and
the host pull request is then promoted and merged.

**[MUST]** AutoFlow merges nothing, promotes no draft and removes neither gate label; of this
sequence it performs only the reconcile, on the operator's request. The hook denies `gh pr merge`
and a push to the default branch while a state file has `active:true`.
