# U6 Delivery — DELIVER, INTEGRATE and HANDOFF

> Unit document for U6. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

AutoFlow's mission ends by handing off an open PR — after PR creation and CI, here, and the review and its triage in [U7 Review](review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

DELIVER, INTEGRATE and HANDOFF are one functional unit, U6 Delivery
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1,
[`ADR-0033`](../records/adr/0033-review-unit-and-script-reviewers.md)). U6 has no unit agent: it
is the orchestrator's own work ([`role-contracts.md`](../role-contracts.md) > Spawn mode by role
lifetime) — every unit agent has already ended by returning its report. This file states what is
asked, the cautions and the result owed. A script only reads and reports (D8). The orchestrator
pushes, opens the pull requests, writes the state file and the ledger, and confirms that each added
test file ran in CI (*CI* > *Added test files*). One reading is made by a spawned role — what class
a CI failure is.

- **Goal**: the cycle's branch is on the remote at the commit GATE:QUALITY passed, the change is
  shown working above its own tests, and every pull request of the cycle is open with CI green on
  its head — or, where no CI runs for it, that fact and its ground recorded on it (*CI*).
- **Artifact contract**: the pushed branches and the pull requests (*Push and pull request*), the
  integration record (*Integration*), and the ledger entries the routes record.
- **What a script reads and reports**: CI confirmation (*CI*), by exit code.
- **Verification**: the integration checks and CI green — both outside the orchestrator's own
  claim; a CI that did not run is recorded as not run, never read as green.
- **Loop cap**: HANDOFF internal retry, 2 ([`core.md`](../core.md) > Flow Control > Regressions).
  An INTEGRATE or CI failure is fixed by the unit its class routes to, and the cycle runs forward
  again (*Integration*, *Failure and retry*).
- **Result owed**: each PR's URL and head commit and the CI result on it.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](../core.md) > Flow Control.

| Transition | Condition |
|------|------|
| DELIVER → INTEGRATE | the cycle's branches pushed, a changed sub-repo's included |
| INTEGRATE → HANDOFF | integration tests pass |
| INTEGRATE → BUILD | integration / bundle failure — fixed `impl` class → a BUILD unit re-run with the failing check → AUDIT → … → INTEGRATE again |
| HANDOFF → REVIEW | every pull request of the cycle open, CI green on its head or recorded on it as not run (*CI*, exit `11`) → [U7 Review](review.md) (`<autoflow-root>/docs/units/review.md`) |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF (CI failure) → doc commit / BUILD / ARCHITECT / advisor | `confirm-ci-green.sh` exit `12` → the failing check's `remedy_class`, recorded by an anonymous direct subagent in `<attempt-dir>/issue-{N}-ci-failure.md`, routes as a GATE:QUALITY FAIL does; `operator` → the advisor fixes the class (`<autoflow-root>/docs/units/delivery.md` > *CI-failure re-entry*) |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

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
  ([`state-tracking.md`](../state-tracking.md) > Hook gates). They are not issued through a script or a wrapper
  that would carry them past the hook.
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch or to the
  attempt's base (`autoflow-records base`); the hook denies them. Merging — including, for multi-repo changes, the sub-repo → pointer → host
  sequencing — is owned entirely by the external review process.
- **Every pull request the cycle opens is a draft** (`gh pr create --draft …`). The host pull
  request's base is the attempt's base, the branch `autoflow-records base` prints — the dev
  branch's `gh-merge-base`, which `gh pr create` reads when no `--base` is given.

What a pull request of a cycle usually carries — offered as what to weigh, not as a checklist:

- a title in the [`title-guide.md`](../title-guide.md) convention and a body written to
  [`pr-body-guide.md`](../pr-body-guide.md);
- on the host PR, the close keyword for the issue (`Closes #N`); a sub-repo PR references the issue
  and carries no close keyword (*Multi-repo delivery* below);
- the acceptance-criterion check — one line per issue criterion: whether it is met, the commit it
  was confirmed at and where the evidence is, under a head naming the commit the results stand at
  ([`pr-body-guide.md`](../pr-body-guide.md) > *수용 기준 대조*);
- the `## Verification dispositions` list — the reviewer reads it (`<autoflow-root>/docs/review/review.md` > Before
  Reviewing): every issue acceptance criterion not verified by an automated test, with its
  disposition and one-line reason from its verification-design row; the run record of each
  cycle-layer `automated` row and the observation record of each AI-executed `manual` row, from the
  build report; and each test file the cycle added to the target's tree, with its reason and the CI
  job that ran it, or that none did and its disposition (*CI* > *Added test files*). Form:
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
  log kept under `<attempt-dir>/issue-{N}-local/` — or the no-op line below. A check that was not run
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

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD origin/<base>`, `<base>` the attempt's base). The condition **fires** iff any changed path matches the trigger glob set:

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
bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
```

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name. Its
header carries the full contract; the exit codes route as follows.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | green — at least one check present, every one green, on a PR whose mergeable state was confirmed | *Added test files*, then [U7 Review](review.md) |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read | no waiting on CI: resolve against `origin/<base>`, the attempt's base (rebase or merge), and push again (internal retry); a conflict on a sub-repo pointer another cycle advanced → *Multi-repo delivery* below |
| `11` | mergeable, and no check was published within the bound (`CI_POLL_TIMEOUT_SECS`, default 900) | not green: look at the CI trigger (webhook delivery, workflow trigger conditions), or push again to force a `synchronize` event. When the target's CI does not run for this pull request — no workflow, or a trigger, path filter or condition that excludes it — the PR body records that CI did not run and the ground, what CI was to run for it (a `ci-deferred` lint chain, an added test file) is listed as not run, and the cycle goes on to [U7 Review](review.md); whether CI is not running or late is the orchestrator's judgment, recorded with its ground (ADR-0034 D5) |
| `12` | a check concluded failure | *CI-failure re-entry* below |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line; check the token's `actions: read`) | raise `CI_POLL_TIMEOUT_SECS` or run again (internal retry), or escalate |
| `14` | the mergeable state could not be confirmed within the bound — a `gh` transport, auth or parse failure | not a conflict: check `gh auth` and connectivity, run again (internal retry), then escalate |
| `64` | usage | fix the invocation |

Cautions:

- The orchestrator does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.
- Exits `10` and `14` carry the reserved `HANDOFF-INTERNAL-RETRY` token on stderr.

**Added test files.** On exit `0`, each test file this cycle added to the target's tree (the build
report's `## Test files kept`) is confirmed to have actually run in the PR head's CI. The criterion
is execution visible in a job's log: a workflow that only registers the file, or a job that only
prints its path, did not run it, and a log that could not be read shows neither. Beside each file the
PR body's `## Verification dispositions` records the job that ran it, or that no job ran it and what
was done — the file wired into the target's CI and pushed again (internal retry, then *CI* again), or
listed for the reviewer as not run by CI; `no CI; local run only` where the target has no CI. How it
is confirmed is the orchestrator's judgment. A cycle that added no test file has nothing to confirm.

### CI-failure re-entry

A CI failure (exit `12`) re-enters by `remedy_class` through `<autoflow-root>/scripts/gate/remedy-route.sh route`
([Transitions](#transitions)). The orchestrator
does not read the failure log itself (Cost Control): an anonymous direct subagent —
`subagent_type: autoflow-analyzer`, model per policy key `handoff-review-triage` — reads the failing
check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`<attempt-dir>/issue-{N}-ci-failure.md` with the failing check, the first failing assertion or error,
**one `remedy_class`** (`doc` / `test` / `impl` / `design` / `operator`) and the grounds for it —
the class of change that clears the failure, `design` when clearing it would discard or change a
decision the design settled — and returns the class plus a one-line summary.
`<autoflow-root>/scripts/gate/remedy-route.sh route <class>` picks the entry point (`DOC_COMMIT` / `BUILD` /
`ARCHITECT` / `PAUSE`); the re-entered phase runs forward to HANDOFF again and *CI* re-confirms.
Not classifiable with confidence, or the failure output unobtainable → `operator`, never a guess
([`core.md`](../core.md) > Rule Scope, principle 3). A failure routed with no recorded class is a
report defect: reject and re-spawn the subagent, as for a missing `fail_hypothesis`. The orchestrator
records the route as an `O` ledger entry naming the check and the class.

## Failure and retry

Classify the cause and regress along the matching path.

```
CI failure (a check concluded failure, exit 12) → by remedy_class (CI-failure re-entry above)
CI failure (env / transient)                   → CI retry, then the CI confirmation again (max 2)
PR CONFLICTING (no checks,                     → resolve vs origin/<base> (rebase/merge) + push again, OR
 build silently skipped)                          a sub-repo pointer → Multi-repo delivery;
                                                  then the CI confirmation again (max 2) — never wait on CI green
Push rejected (branch state)                   → dev branch rebase on origin/<base> → push again (max 2)
```

**Max retries**: HANDOFF internal retry max 2. Two failures → human.
**Re-entry**: a CI failure is fixed by the unit its class routes to, and the cycle runs forward to *CI* again (*CI-failure re-entry* above); a `design` route consumes the ARCHITECT re-entry counter.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — and the cycle changes one, the sub-repo's
change is delivered on its own pull request and the host follows it by its pointer. AutoFlow does
not classify the project; what the sub-repos are, where each one's pull request goes (a fork, the
upstream) and where issues are filed are read from the project's own information
([`core.md`](../core.md) > Project Information).

**The rule.** After a sub-repo pull request merges, the host keeps a clean state by a reconcile
merge: the host branch that depends on it points at that pull request's merge commit, and stays
mergeable with its pull request's base. Merging is the operator's, so the request to reconcile after a
sub-repo merge is the operator's too; the orchestrator reconciles when it is asked. When the
pointer moves before that point, and how a reconcile is carried out, are the orchestrator's,
derived from this rule and recorded with their grounds in the ledger.

What is asked:

- Each changed sub-repo has its branch pushed and its pull request opened by the orchestrator's own
  commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` — gated like the
  host's, and draft (*Push and pull request*). A sub-repo pull request
  references the host issue (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the
  host pull request is the one that closes the issue.
- The host pull request's pointer names the sub-repo commit the cycle delivers, so the host review
  reads the pointer and the sub-repo review reads the code behind it ([U7 Review](review.md) >
  *Review triage*).

Cautions:

- A merge of the base into a host branch whose pointer still sits where the branch forked
  resolves the pointer to the base's, not to the sub-repo merge commit. The pointer is set
  and read back (`git ls-tree HEAD <sub-repo>`) before the push.
- Another cycle may have moved the base's pointer since this branch forked. When the
  sub-repo merge commit does not contain that pointer — the base is ahead of it, or the
  two have diverged — reconciling would move the host's pointer backwards or across histories: the
  orchestrator does not push, and reports to the operator.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.

Result owed: each pull request's URL and head commit; for the host pull request, the commit each
changed sub-repo's pointer names. After a reconcile: the pointer read back equal to the merge
commit, and the CI confirmation on the new head (*CI*).
