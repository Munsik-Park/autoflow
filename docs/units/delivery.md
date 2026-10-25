# U6 Delivery — DELIVER, INTEGRATE and HANDOFF

> Unit document for U6. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

AutoFlow's mission ends by handing off an open pull request — opened, with CI read, by this module, and reviewed by [U7 Review](review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

U6 Delivery is one module, the delivery module, whose contract is
`<autoflow-root>/docs/contracts/delivery.json` and whose procedure is this file
([`ADR-0038`](../records/adr/0038-contract-modules-run-by-the-coordinator.md) D1). It has no unit
agent: the session that runs it pushes, runs the integration checks, opens the pull requests and
confirms that each added test file ran in CI (*CI* > *Added test files*); a script only reads and
reports. One reading is made by a spawned role — what a failed CI check shows (*CI failure* below).

- **Goal**: the branch on the remote at the last commit of the range the quality evaluation scored
  (`commits`), the change shown working above its own tests, and every pull request of the change
  open as a draft with CI green on its head — or, where no CI runs for it, that fact and its ground
  recorded on it (*CI*) — whose body lets the operator decide on it.
- **Output**: the pushed branches and the pull requests (*Push and pull request*), the integration
  record `<out>/integration.md` (*Integration*), the CI-failure record `<out>/ci-failure.md` when a
  check failed (*CI failure*), and the run's tool requests.
- **What a script reads and reports**: CI confirmation (*CI*), by exit code.
- **Checks**: check-out confirms each pull request open and a draft, its body stating every
  applied criterion, every tool request of the work and every deferred recommendation's disposition,
  and its CI green or the body's `CI: not run` line (`delivery.json`). The integration checks and CI
  stand outside the module's own claim; a CI that did not run is recorded as not run, never read as
  green.
- **Result owed**: each PR's URL and head commit and the CI result on it.

## Push and pull request

**DELIVER.** The branch the invocation names (`params.branch`) is on the remote, at the last commit
of the range the quality evaluation scored; the pushed branch and its head commit are carried in the
change summary. Which remote, which flags and when are the module's. A changed sub-repo's branch is
pushed the same way, by the module's own `git -C <sub-repo> push …`, to the remote the project's
information names for it; the host pointer that follows it is *Multi-repo delivery* below.

These rules hold on every push and every pull request the module makes. Everything they do not
name — the title, how the body is composed, when the push happens — is the module's.

- **Pushing and opening a pull request are the module's own commands.** `git push …` and
  `gh pr create …` are issued as those commands, never through a script or a wrapper, so the hook
  sees them.
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch; the hook denies
  them. Merging is owned entirely by the external review process.
- **Every pull request the module opens is a draft** (`gh pr create --draft …`), on the base the
  invocation names (`params.base`), or the remote's default branch when it names none.

What a pull request usually carries — offered as what to weigh, not as a checklist:

- a title in the [`title-guide.md`](../title-guide.md) convention and a body written to
  [`pr-body-guide.md`](../pr-body-guide.md);
- on the host PR, the close keyword for the issue (`Closes #N`); a sub-repo PR references the issue
  and carries no close keyword (*Multi-repo delivery* below);
- the acceptance-criterion check — one line per applied criterion: whether it is met, the commit it
  was confirmed at and where the evidence is, under a head naming the commit the results stand at
  ([`pr-body-guide.md`](../pr-body-guide.md) > *수용 기준 대조*);
- the `## Verification dispositions` list — the reviewer reads it (`<autoflow-root>/docs/review/review.md` > Before
  Reviewing): every item the verification design verifies other than by an executable test, with
  how it is verified instead and why, from its row; each item's run record or observation record,
  from the build report's `## Run record` and `## Manual checklist`; and each test file the change
  added to the target's tree, with its reason and the CI job that ran it, or that none did and its
  disposition (*CI* > *Added test files*). Form:
  [`pr-body-guide.md`](../pr-body-guide.md) > *Verification dispositions*;
- the tool requests: every tool request of the work — each run's `tool-requests.json` the
  invocation names (`tool_requests`) — with what it left unverified, so the operator decides on it:
  provide the tool and run again, close the pull request and set the tool up apart, or merge and add
  the tool;
- the known gaps ([`pr-body-guide.md`](../pr-body-guide.md) > *한계와 known gaps*): each directly
  related problem the work separated, with its separation reason
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*), and each recommendation the Coordinator deferred or separated (`deferred`;
  [U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) by its
  disposition — the issue that takes it, or the gap stated in a line —, not the finding's text whole;
- when the branch already has an open pull request, the push updates it, and its body is brought up
  to the current records before the reviewer reads it again.

## Integration

INTEGRATE looks at the change as the system runs it, beyond what the build verified per item.

- **What is asked**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks that takes, and how they are run, is the module's, the way
  the target runs them ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification
  and Tools).
- **Result owed**: one line per check in `<out>/integration.md` — its command and the summary line
  read from its log, the log kept under `<out>/local/` — or the no-op line below. A check that was not
  run is `not-run`, never `passed`.
- **A failing check**: the pull request is opened once the integration checks pass. A check that
  fails is recorded with its output, and the run ends there, its result refused for want of the
  pull request; a fix of what failed is the build's, and which module runs next is the Coordinator's.

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

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD origin/<base>`, `<base>` the pull request's base). The condition **fires** iff any changed path matches the trigger glob set:

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

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is an integration failure (*Integration* above).

## CI

```
bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
```

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name. Its
header carries the full contract; the exit codes read as follows.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | green — at least one check present, every one green, on a PR whose mergeable state was confirmed | *Added test files*; the run ends |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read | no waiting on CI: the branch is brought onto `origin/<base>`, the pull request's base (rebase or merge), pushed again and CI read again; a conflict on a sub-repo pointer another change advanced → *Multi-repo delivery* below |
| `11` | mergeable, and no check was published within the bound (`CI_POLL_TIMEOUT_SECS`, default 900) | not green: look at the CI trigger (webhook delivery, workflow trigger conditions), or push again to force a `synchronize` event. When the target's CI does not run for this pull request — no workflow, or a trigger, path filter or condition that excludes it — the PR body carries the line `CI: not run`, alone on its line, with the ground below it, and what CI was to run for it (a `ci-deferred` lint chain, an added test file) is listed as not run; whether CI is not running or late is the module's judgment, recorded with its ground (ADR-0034 D5) |
| `12` | a check concluded failure | *CI failure* below |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line; check the token's `actions: read`) | the run ends with CI unsettled, stated in its result |
| `14` | the mergeable state could not be confirmed within the bound — a `gh` transport, auth or parse failure | not a conflict: check `gh auth` and connectivity; the run ends with the failure stated in its result |
| `64` | usage | fix the invocation |

Whether the delivery runs again after an unsettled or failed read is the Coordinator's.

Cautions:

- The module does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.

**Added test files.** On exit `0`, each test file the change added to the target's tree (the build
report's `## Test files kept`) is confirmed to have actually run in the PR head's CI. The criterion
is execution visible in a job's log: a workflow that only registers the file, or a job that only
prints its path, did not run it, and a log that could not be read shows neither. Beside each file the
PR body's `## Verification dispositions` records the job that ran it, or that no job ran it and what
was done — the file wired into the target's CI and pushed again, then *CI* again, or listed for the
reviewer as not run by CI; `no CI; local run only` where the target has no CI. How it is confirmed is
the module's judgment. A change that added no test file has nothing to confirm.

### CI failure

A CI failure (exit `12`) is read, not routed. The session does not read the failure log itself
(Cost Control): an anonymous direct subagent — `subagent_type: autoflow-analyzer`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names — reads
the failing check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`<out>/ci-failure.md` with the failing check, the first failing assertion or error, where the fix
that clears it is made — the implementation, a test asset, a document, or the design when clearing
it would discard or change a decision the design settled — and the grounds for that judgment, and
returns the path and a one-line summary. Where it cannot judge with confidence, or the failure output
is unobtainable, it says so and states the question for the advisor, never a guess
([`core.md`](../core.md) > Rule Scope, principle 3). The run ends with the record; which module runs
next is the Coordinator's.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — and the change touches one, the sub-repo's
change is delivered on its own pull request and the host follows it by its pointer. AutoFlow does
not classify the project; what the sub-repos are, where each one's pull request goes (a fork, the
upstream) and where issues are filed are read from the project's own information
([`core.md`](../core.md) > Project Information).

What follows a sub-repo pull request's merge — whether the host's pointer moves to it, when and
how — is the Coordinator's, outside AutoFlow ([`git-workflow.md`](../git-workflow.md) >
Post-Merge Cleanup).

What is asked:

- Each changed sub-repo has its branch pushed and its pull request opened by the module's own
  commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` —, as a draft, on the
  host's terms (*Push and pull request*). A sub-repo pull request
  references the host issue (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the
  host pull request is the one that closes the issue.
- The host pull request's pointer names the sub-repo commit the change delivers, so the host review
  reads the pointer and the sub-repo review reads the code behind it ([U7 Review](review.md) >
  *Review triage*).

Cautions:

- A merge of the base into the host branch — the conflict resolution of *CI* exit `10` — can
  resolve the pointer to the base's, not to the sub-repo commit the change delivers. The pointer is
  set to the delivered commit and read back (`git ls-tree HEAD <sub-repo>`) before the
  push.
- Another change may have moved the base's pointer since this branch forked. When the delivered
  sub-repo commit does not contain that pointer — the base is ahead of it, or the two have
  diverged — setting it would move the host's pointer backwards or across histories: the
  module does not push, and states it in its result for the operator, situation-first.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.

Result owed: each pull request's URL and head commit; for the host pull request, the commit each
changed sub-repo's pointer names.
