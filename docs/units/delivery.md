# U6 Delivery — DELIVER, INTEGRATE and HANDOFF

> The procedure of the delivery and ci modules. [`core.md`](../core.md) > Module procedures routes
> to this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

AutoFlow's mission ends by handing off an open pull request — opened, with CI read, by the modules below, and reviewed by [U7 Review](review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

## The two modules

U6 Delivery is two modules, each with its contract under `<autoflow-root>/docs/contracts/` and this
file as its procedure ([`ADR-0039`](../records/adr/0039-delivery-and-ci-modules.md)). Each runs
alone on its invocation. A module is given the kinds of its inputs, the kind and form of its output,
its tools and the authority rules below; how many of a thing it makes, which steps it takes in which
order and what it checks are the AI's, judged from the inputs it is given.

| Module | Output | Default | `timeout` not given |
|---|---|---|---|
| `delivery` | `<out>/delivery.json` (*Push and pull request*) | a sub-repo's pointer commit, the push and the draft pull requests with their bodies | 900 s |
| `ci` | `<out>/ci.json` (*CI*) | the verdict in each pull request's body, its CI part | 900 s |

## What both modules owe

- **Inputs.** A module works from its params and the inputs its invocation gives. The record
  directory (`records`) is where earlier runs left their working files and where the ledger is; it
  does not stand in for an input. An input the work needs and was not given is named as such in the
  failure output.
- **Failure output.** A run that does not reach its goal, or reaches its `timeout` (seconds), writes
  `<out>/failure.md`: what it did, and why it did not reach the goal. Check-out then writes its
  result as `failed` (`<autoflow-root>/scripts/contracts/contract.sh`, header).
- **Check-out** checks the output's form: the file is there and reads in the form its contract
  gives.

## Authority rules

These hold on every push, every pull request and every pull-request body either module makes.

- Pushing, opening a pull request and editing its body are the module's own commands, never run
  through a script or a wrapper (`<autoflow-root>/docs/core.md` > Scripts).
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch; the hook denies
  them. Merging is owned entirely by the external review process.
- Every pull request a module opens is a draft.

## Push and pull request

**DELIVER, INTEGRATE.** The delivery module delivers the change the build made for the operator to
see and decide on: each applied acceptance criterion with its outcome and its evidence, how the
change was shown working, what the work could not verify and why, and what the change leaves
undone.

- **Inputs**: what the build produced and worked from — its commits (`commits`), its report
  (`build_report`), the applied criteria and the verification design —, and the records the
  pull-request body carries: the quality evaluation, the feature design, the tool requests of every
  run (`tool_requests`) and the recommendations deferred or separated (`deferred`).
- **Params**: `base`, the branch the pull requests merge into (not given, the remote's default
  branch); `timeout`.
- **What the AI judges**: how many pull requests the change takes, in which repositories and on which
  branches — a sub-repo's included, read from the project's own information
  ([`core.md`](../core.md) > Project Information) —, and how the pull requests show the change
  working.
- **The change delivered** is one whose local tests the build report records green.
- **The body** states each applied acceptance criterion with its outcome and where its evidence is;
  what the work verified other than by an executable test, and how the change was shown working; what
  the work could not verify, and why — the tool requests, so the operator decides on them; and what
  the change leaves undone — the problems it separated and the recommendations deferred. The pull
  request in the repository the issue is filed in closes it (`Closes #N`); any other references it
  and closes nothing ([`git-workflow.md`](../git-workflow.md) > Issue Auto-Close). The title and the
  body's form are the module's, with [`title-guide.md`](../title-guide.md) and
  [`pr-body-guide.md`](../pr-body-guide.md) to draw on.
- **Tools**: `git` and `gh`, as the module's own commands.
- **Output**: `<out>/delivery.json` — `{pull_requests: [{repo, branch, head, pr}]}`: each branch
  pushed, with its repository (`<owner>/<name>`), its head commit and its pull request as
  `<owner>/<name>#<N>` — the form the review and the ci module take —, `null` for a branch pushed
  with no pull request.
- **Default**: a sub-repo's pointer commit where the change takes one, the branches pushed and the
  draft pull requests opened on the base, with the bodies above; the invocation's `instructions`
  override it ([`core.md`](../core.md) > Development Lifecycle > *Inputs, outputs and default*).
- **Failure output**: `<out>/failure.md` (*What both modules owe*) — among what the run did, what it
  pushed and opened.

## CI

**HANDOFF.** The ci module reads CI on each pull request it is given and states the verdict in
`<out>/ci.json`.

- **Inputs**: the pull requests (`pull_requests`), each with the head CI is read on — the delivery's
  output, or a file the invocation writes, `{pull_requests: [{pr, head}]}`; and, optionally, the
  build report (`build_report`): the test files the change added (`## Test files kept`) and the
  `ci-deferred` lint chains.
- **Params**: `timeout`, which bounds the whole run.
- **What the AI judges**: how it reads CI, how long it waits within the `timeout`, and whether it
  reads a failing check's log.
- **Tools**: `gh`, as the module's own command; and
  `<autoflow-root>/scripts/handoff/confirm-ci-green.sh` — what it reads and what each of its exits
  means are stated in its header.
- **Output**: `<out>/ci.json` — `{prs: [{pr, head, verdict, ground}]}`: each pull request's verdict
  on the head it was read on — `green`, `not-run`, or what CI showed instead — and the ground it rests
  on.
- **Default**: each pull request's body carrying its CI part; the invocation's `instructions`
  override it ([`core.md`](../core.md) > Development Lifecycle > *Inputs, outputs and default*).
  The CI part:
  - the verdict and the head it was read on; a later verdict on a head replaces an earlier one;
  - **CI not run.** Where the target's CI does not run for the pull request — no workflow, or a
    trigger, path filter or condition that excludes it — the body carries the line `CI: not run`,
    alone on its line, with the ground below it (ADR-0034 D5), and what CI was to run for it (a
    `ci-deferred` lint chain, an added test file) is listed as not run. A `green` body carries no such
    line;
  - **Added test files.** Beside each test file the change added to the target's tree, the PR body's
    `## Verification dispositions` records the CI job whose log shows it run, or that no job ran it,
    listed for the reviewer as not run by CI; `no CI; local run only` where the target has no CI.
- **Failure output**: `<out>/failure.md` (*What both modules owe*) — the pull request that is
  neither `green` nor `not-run`, and what CI showed; `<out>/ci.json` states the verdict all the same.
