# U6 Delivery — INTEGRATE, DELIVER and HANDOFF

> The procedure of the four delivery modules. [`core.md`](../core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

AutoFlow's mission ends by handing off an open pull request — opened, with CI read, by the modules below, and reviewed by [U7 Review](review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

## The four modules

U6 Delivery is four modules, each with its contract under `<autoflow-root>/docs/contracts/` and
this file as its procedure ([`ADR-0039`](../records/adr/0039-delivery-as-four-modules.md)). Each
runs alone on its invocation; whether a module runs, in which order, on which pull request, and what
follows its result — a failed integration check, a red CI, a sub-repo's pull request — are not this
document's ([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D2).

| Module | Expected output | The work is done by | `timeout` not given |
|---|---|---|---|
| `integration` | `<out>/integration.md`: the change shown working above its own tests, every check passed or a stated no-op (*Integration*) | the session itself | 3600 s |
| `delivery` | `<out>/delivery.json`: the branches pushed at their heads and, unless `pull_request` is `none`, each one's draft pull request open (*Push and pull request*) | the session itself | 900 s |
| `ci` | `<out>/ci.json`: CI green on each pull request's head, or its not running recorded on it, and the body's CI part stating it (*CI*) | the session itself; a script reads and reports CI | 900 s |
| `ci-failure` | `<out>/ci-failure.md`: what each failed check shows and where its fix is made (*CI failure*) | an `autoflow-analyzer` spawn (`handoff-review-triage`) | 900 s |

## What every delivery module owes

- **Inputs.** A module works from its params and the inputs its invocation gives. The record
  directory (`records`) is where earlier runs left their working files and where the ledger is; it
  does not stand in for an input. An input the work needs and was not given is named as such in the
  failure output, and the run does not go on from a guess.
- **The end of a run.** A run ends when its expected output is reached, or when it judges it cannot
  be reached or its `timeout` (seconds) runs out. A run that cannot reach it writes
  `<out>/failure.md` instead — what it did, what it observed, and why it did not reach the expected
  output — and check-out writes its result as `failed` (`<autoflow-root>/scripts/contracts/contract.sh`,
  header). A failure output is a result, not a defect: its reader learns from it alone what
  happened.
- **Inside a run** the steps are the AI's: it designs them from what it finds, repeats what it needs
  within the run, and checks before ending whether the expected output stands. A repetition inside
  one run is not a re-run.
- **Checks.** Each module's check-out confirms the facts its output names, by the judgment the
  module itself uses — a branch at its head, a pull request open at its head, CI green on the head
  by the same script (*CI*); what the PR body states for the operator is the review's to judge. The
  integration checks and CI stand outside the module's own claim; a CI that did not run is
  recorded as not run, never read as green.

## Integration

INTEGRATE looks at the change as the system runs it, beyond what the build verified per item — on
the branch, before anything is pushed.

- **Expected output**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks
  that takes, and how they are run, is the module's, the way the target runs them
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools).
  `<out>/integration.md` has one line per check — its command and the summary line read from its
  log, the log kept under `<out>/local/` — or the no-op line below. A check that was not run is
  `not-run`, never `passed`.
- **Failure output**: a check that fails is recorded in `<out>/integration.md` with its output, and
  `<out>/failure.md` names it — the change is not shown working. A fix of what failed is the build's.

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

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD origin/<base>`, `<base>` the invocation's `base`). The condition **fires** iff any changed path matches the trigger glob set:

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

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is a failing integration check (*Integration* above).

## Push and pull request

**DELIVER.** One run pushes and opens the pull requests: the branch the invocation names
(`params.branch`) goes to the remote at the last commit of the build's range (`commits`), and each
pushed branch gets its draft pull request — or, when it already has an open one, the push updates
it and its body is brought up to the inputs the run was given. With `pull_request: none` the run
pushes and opens or updates no pull request. The change it delivers is the one whose local tests the
build report records green; a build report that does not is a failure output, and nothing is
pushed. Which remote, which flags and when are the module's.

These rules hold on every push and every pull request the module makes. Everything they do not
name — the title, how the body is composed, when the push happens — is the module's.

- **Pushing and opening a pull request are the module's own commands.** `git push …` and
  `gh pr create …` are issued as those commands, never through a script or a wrapper, so the hook
  sees them.
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch; the hook denies
  them. Merging is owned entirely by the external review process.
- **Every pull request the module opens is a draft** (`gh pr create --draft …`), on the base the
  invocation names (`params.base`), or the remote's default branch when it names none.

The body lets the operator decide on the pull request. It states:

- each applied acceptance criterion with its outcome and where its evidence is;
- what the work verified other than by an executable test, and how — the reviewer reads it
  (`<autoflow-root>/docs/review/review.md` > Before Reviewing) —, and, given the integration
  record, how the change was shown working above its own tests;
- what the work could not verify, and why: the tool requests in each run's file the invocation
  gives (`tool_requests`) — the criterion review's runs as much as the last ones —, so the operator
  decides on them;
- what the change leaves undone: the problems it separated and the recommendations deferred
  (`deferred`);
- CI's result, in the body's CI part, which is the ci module's (*CI*): a pull request this run
  opens says CI is not yet confirmed, and a body this run updates keeps the CI part as it stands.

The host PR closes the issue (`Closes #N`); a sub-repo PR references it and closes nothing
(*Multi-repo delivery* below). The title and the body's form are the module's, with
[`title-guide.md`](../title-guide.md) and [`pr-body-guide.md`](../pr-body-guide.md) to draw on.

**Expected output**: `<out>/delivery.json` —
`{pushed: [{repo, branch, head, path}], pull_requests: [{pr, url, head, path, opened}], pointers: [{path, commit}], not_delivered: [{path, why}]}`:
each pushed branch with its repository (`<owner>/<name>`) and head, `path` the host's `.` or the
sub-repo's directory; each pull request as `<owner>/<name>#<N>` — the form the review takes as its
`pr` — with its head and `opened: true` when this run opened it; each pointer the host's branch
sets; and each changed sub-repo the invocation does not name, which is not pushed. Check-out reads
each branch and pull request on GitHub at the head the file names.

**Failure output**: a push refused, a pull request that cannot be opened, a pointer that cannot be
set (*Multi-repo delivery*), local tests the build report does not record green, or the `timeout`
reached — `<out>/failure.md` states what was pushed and opened before it, and why the rest was not.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — the sub-repos the invocation names
(`sub_repos`) are delivered on their own pull requests and the host follows each by its pointer.
AutoFlow does not classify the project; what the sub-repos are, where each one's pull request goes
(a fork, the upstream) and where issues are filed are read from the project's own information
([`core.md`](../core.md) > Project Information).

What follows a sub-repo pull request's merge is outside AutoFlow ([`git-workflow.md`](../git-workflow.md) >
Post-Merge Cleanup).

For each sub-repo the invocation names:

- its branch is pushed and, unless `pull_request` is `none`, its pull request opened by the module's
  own commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` —, as a draft, on
  the host's terms (*Push and pull request*). A sub-repo pull request references the host issue
  (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the host pull request is the
  one that closes the issue;
- unless its entry says `pointer: false`, the host's pointer is set to the sub-repo commit the
  change delivers, in a host commit pushed with the host branch, so the host review reads the
  pointer and the sub-repo review reads the code behind it ([U7 Review](review.md) > *Review
  triage*).

Cautions:

- A conflict on the pointer is settled by setting it to the delivered commit, read back
  (`git ls-tree HEAD <sub-repo>`) before the push.
- Another change may have moved the base's pointer since this branch forked. When the delivered
  sub-repo commit does not contain that pointer — the base is ahead of it, or the two have
  diverged — setting it would move the host's pointer backwards or across histories: the
  module does not push the host, and its failure output states it, situation-first.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.

## CI

The ci module confirms CI on each pull request it is given (`pull_requests`, each with the head it
is to be confirmed on) with one script, its `timeout` as the script's bound:

```
CI_POLL_TIMEOUT_SECS=<timeout> bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <N> --repo <owner/name>
```

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name.
Green is what the script judges green (its header): one representative per check identity, a
superseded run's cancelled rows not counted, at least one present and every one green, on a PR whose
mergeable state was confirmed. Check-out judges by the same script, read once (`--once`), on the
head the output names. Every exit but `0` ends with a stderr line of what it read
(`observed: reads=… checks_seen=… mergeable=… merge_state=…`), which the output carries.

| Exit | What was read | `verdict` |
|---|---|---|
| `0` | green | `green` |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read; CI was not waited on | `conflict` |
| `11` | mergeable, and no check published on the head on any well-formed read within the bound | `not-run`, or the run's failure (below) |
| `12` | a check concluded and is not green | `failed` |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line) | `pending` |
| `14` | the mergeable state, or any read of the checks, could not be confirmed — a `gh` transport, auth or parse failure, or a merge state that never settled | `unread` |
| `64` | usage | — |

**Expected output**: `<out>/ci.json` — `{prs: [{pr, head, verdict, exit, observed, failing}]}`, every
pull request `green` or `not-run` — and each pull request's body carrying its CI part:

- the CI result, and the head it was read on; a later result on a head replaces an earlier one, and
  a `green` body carries no `CI: not run` line;
- **CI not run.** On exit `11`, whether the target's CI does not run for this pull request — no
  workflow, or a trigger, path filter or condition that excludes it — or is late is the module's
  judgment, recorded with its ground (ADR-0034 D5). Not running: the body carries the line
  `CI: not run`, alone on its line, with the ground below it, and what CI was to run for it (a
  `ci-deferred` lint chain, an added test file) is listed as not run; the verdict is `not-run`;
- **Added test files.** On `green`, each test file the change added to the target's tree (the build
  report's `## Test files kept`) is confirmed to have actually run in the PR head's CI. The criterion
  is execution visible in a job's log: a workflow that only registers the file, or a job that only
  prints its path, did not run it, and a log that could not be read shows neither. Beside each file
  the PR body's `## Verification dispositions` records the job that ran it, or that no job ran it,
  listed for the reviewer as not run by CI; `no CI; local run only` where the target has no CI. How
  it is confirmed is the module's judgment. A change that added no test file has nothing to confirm.

The output is judged on the pull request as it stands once the body is written: a check the body's
edit itself starts is read like any other.

**Failure output**: a pull request that is `conflict`, `failed`, `pending` or `unread`, or `11` judged
late — `<out>/ci.json` carries every pull request's verdict, `failing` names each failed check and
its URL, the body's CI part states the result, and `<out>/failure.md` says which pull request did not
reach green and what the script observed.

Cautions:

- The module does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.

### CI failure

The ci-failure module reads what each failed check shows (`ci`: the pull requests whose verdict is
`failed`, with their failing checks). The session does not read the failure log itself (Cost
Control): an anonymous direct subagent — `subagent_type: autoflow-analyzer`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names — reads
the failing check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`<out>/ci-failure.md` with the failing check, the first failing assertion or error, where the fix
that clears it is made — the implementation, a test asset, a document, or the design when clearing
it would discard or change a decision the design settled — and the grounds for that judgment, and
returns the path and a one-line summary. Where it cannot judge with confidence, it puts the judgment
to the advisor and records the advisor's decision with its ledger entry
([`role-contracts.md`](../role-contracts.md) > Advisor; [`core.md`](../core.md) >
Development Lifecycle > *Decisions within a module*).

**Failure output**: a failure output it cannot obtain is a tool request ([`core.md`](../core.md) >
Development Lifecycle > *Tools*); a check whose output could not be read is named in
`<out>/failure.md`, with what was tried.
