# ADR-0039: Delivery and CI as two modules

## Status

Accepted (operator decisions 2026-10-28 and 2026-10-29, issue #518). The 2026-10-29 decision
revises the 2026-10-28 one: two modules in place of four, each given only the kinds of its inputs,
the kind and form of its output, its tools and its authority rules, and check-out checking the
output's form only. Amends ADR-0038 D1 — the module list, and check-out's result — and the
delivery's contract. ADR-0038 D2, ADR-0034 D2 and D5, and the authority rules of the core stand.
D3 and D4 extended to every module, D1's `pull_request` param, the delivery's goal and the ci
module's goal amended, by ADR-0040 (issue #523).

## Context

ADR-0038 D1 made U6 Delivery one module, whose run pushed the branch, ran the integration checks,
opened the draft pull requests and wrote their bodies, confirmed CI, recorded a CI that did not run,
confirmed that each added test file ran in CI, had a failed check read, delivered each changed
sub-repo with its pointer, and ordered all of it (`docs/units/delivery.md` before this change). Its
contract (`docs/contracts/delivery.json`) required six inputs from four modules, and its check-out
read the pull request and its CI in one check, so a re-run of one part was a re-run of all of it
with every input.

Issue #518 asks for the delivery to be split on fixed inputs and outputs, as the criterion review
was (`docs/records/design-reviews/io-contract-modules.md` > 4), and records three facts:

- the CI confirmation script and the delivery's check-out judged green differently — the script by
  one representative per check identity with a superseded run's `CANCELLED` dropped, check-out by
  every element of the raw rollup — so a pull request re-run to green beside an old `CANCELLED`
  row passed the one and was refused by the other (PR #517's review);
- Munsik-Park/opensre#29 received no check within the bound, with Actions on and its workflow
  active; the cause was not found;
- the script's message on that exit, "re-push to force a synchronize event", has no effect: a push
  of the same commit sends no ref update.

The operator's decision of 2026-10-28 split the delivery into four modules — integration, delivery,
ci and ci-failure —, with a `sub_repos` input naming the sub-repos to deliver and a check-out that
read each pushed branch, each pull request and its CI on GitHub. Its reviews on PR #521 turned on
that check-out — what it compares the output with, and how it reads CI the same way under every
environment — and on how far the procedure prescribed the delivery of sub-repos.

The operator's decision of 2026-10-29: a module is given the kinds of its inputs, the kind and form
of its output, its tools and its authority rules; how many of a thing it makes, in which order it
works and what it checks, the AI judges from the inputs. How to use git, gh and CI, command
examples, enumerated cases and decision formulas are not written in the documents. Check-out checks
the output's form only — the file is there and reads in its form — and reads nothing again on
GitHub or in git. A run that does not reach its goal writes what it did and why, and ends `failed`.

## Decision

**D1 — Delivery is two modules.** Each has a contract under `docs/contracts/` and
`docs/units/delivery.md` as its procedure:

- `delivery` — the change the build made on the target's remote in draft pull requests whose bodies
  show it working and let the operator decide on them; its inputs the build's commits and report,
  the applied criteria and the verification design, and the records the body carries (the quality
  evaluation, the feature design, the tool requests, the deferred recommendations); its output
  `delivery.json`, `{pull_requests: [{repo, branch, head, pr}]}`;
- `ci` — CI's verdict on each pull request it is given, with its ground, stated in the body's CI
  part; its inputs the pull requests (`[{pr, head}]`, the delivery's output or a file the invocation
  writes) and, optionally, the build report; its output `ci.json`, `{prs: [{pr, head, verdict,
  ground}]}`; its tool `scripts/handoff/confirm-ci-green.sh`.

| Process | Placed in | Grounds |
|---|---|---|
| Push, pull requests and their bodies, a sub-repo's included | `delivery` | By default, with local tests green, pushing and opening the pull request are one action (the operator's decision, 2026-10-28); a push alone is the `pull_request: none` param. How many pull requests, in which repositories and on which branches, is the AI's from the inputs (2026-10-29). |
| Showing the change working above its own tests | `delivery` | The body shows it to the operator; how it is shown is the AI's (2026-10-29). The integration module, its checks and its deploy/CI-path predicate go. |
| CI's verdict, a CI that does not run, the CI job of each added test file, the body's CI part | `ci` | The state of CI on a pull request's head, read with one script; run alone, it can be run again on a pull request whose head changed. |
| Reading a failed check's log | `ci`, as the AI judges | The ci-failure module and its spawn go (2026-10-29). |
| Whether an output fits its input, and whether the facts it states hold | outside the modules | ADR-0038 D2: what checks a module's output beyond its form is not described. |
| A re-run, its count, and a timeout's value for a run | outside the modules | ADR-0038 D2, Q3; a module takes its timeout as a param. |

**D2 — A module is given the kinds of its inputs, the kind and form of its output, its tools and
its authority rules.** Its steps, their order, how many of a thing it makes and what it checks are
the AI's. A module works from its params and its declared inputs; the record directory is where
earlier runs' working files and the ledger are, and does not stand in for an input. A module's
contract carries a `timeout` param (seconds), with its default in the procedure. The authority rules
of both: pushing, opening a pull request and editing its body are the module's own commands; no
merge and no push to the default branch (the hook denies them); every pull request a module opens is
a draft.

**D3 — A run that does not reach its goal writes a failure output, and its result is `failed`.** A
contract may declare one output as its failure output (`"failure": true`, a markdown file, not
required). A run that does not reach its goal, or reaches its timeout, writes it — what it did, and
why it did not reach the goal. Check-out then checks that file is not empty and the tool requests,
records every output present, and writes `result.json` with `status: "failed"` (exit `3`).
`accepted` and `refused` keep their meaning; a `failed` result is the module's own statement, not a
defect of its output. Both contracts declare `failure.md`.

**D4 — Check-out checks the output's form.** For both modules it checks that the output file is
there and reads in the form the contract gives — the `keys` check, each list entry carrying its
keys (`items_keys`). It reads nothing again on GitHub or in git: the `pushed`, `pr_open` and
`ci_verdict` checks of the 2026-10-28 decision, and their reads, go. Check-in applies the same form
checks to an input.

**D5 — The CI script states what it read.** In `scripts/handoff/confirm-ci-green.sh`, a check still
running — a CheckRun whose conclusion is empty or whose status is not `COMPLETED` — has not
concluded; a check that has concluded with any conclusion but `SUCCESS`, `NEUTRAL` and `SKIPPED` is a
failure (exit `12`) — `STARTUP_FAILURE`, `STALE` and `ACTION_REQUIRED` no longer wait for the
deadline; exit `11` needs at least one well-formed read of the checks, and a run in which every read
of the checks failed is exit `14`; every non-green exit ends with the line of what it read
(`observed: …`); and its messages state what was read, not what to do next — the "re-push to force a
synchronize event" and "re-run with a larger CI_POLL_TIMEOUT_SECS" advice goes. What each exit means
is stated in the script's header, and the documents that described green as "at least one check
present and every element green" refer to the script instead.

## Alternatives Considered

- **Four modules — integration, delivery, ci, ci-failure (the decision of 2026-10-28).** Superseded
  by the operator's decision of 2026-10-29: the integration checks and the failure read were
  procedures written for the AI, and the two modules leave them to its judgment.
- **A `sub_repos` input naming the sub-repos to deliver, with a pointer flag.** Rejected
  (2026-10-29): which repositories a change takes is read from the inputs and the project's own
  information.
- **check-out reading each branch, pull request and CI verdict on GitHub.** Rejected (2026-10-29):
  it made check-out a second implementation of the module's judgment, and what it compared with —
  the invocation, the environment's CI bounds — kept moving across the reviews.
- **A failed run reported as `refused`.** Rejected: `refused` means the output does not meet the
  contract; a module that honestly reports it did not reach its goal would read the same as one
  whose output is wrong.

## Consequences

### Positive

- One part of the delivery can be run again with only its own inputs: CI read again on a pull
  request whose head changed, without a new push.
- The documents state what each module is given and owes, and no procedure the AI is to follow.
- A run that did not reach its goal is `failed` in `result.json`, with its failure output beside it.
- The CI script and the documents no longer state two judgments of green.

### Negative

- What the former module ordered or checked — no pull request after a failed integration check, a
  failure read after a red CI, a sub-repo pointer at the commit its pull request delivers — is
  nowhere in AutoFlow's text; nothing AutoFlow ships enforces it.
- Check-out accepts an output whose facts no longer hold, or that leaves out a pull request the
  change takes, as long as its form holds.

## Relation to other decisions

- **ADR-0038** — D1's list of functional modules names `delivery` and `ci` in place of `delivery`,
  and check-out writes `failed` beside `accepted` and `refused` (D3). D2 stands and is applied: what
  checks an output beyond its form is not described.
- **ADR-0034** — D5's hand-off without CI stands: `not-run` is the ci module's verdict when the
  target's CI does not run for a pull request, recorded with its ground.
- **ADR-0033** — U7 Review stays one module; it takes its `pr` from an entry of `delivery.json`.

## Related Issues / PRs

- Issue #518; PR #521 (its reviews); PR #517's review (the green judgment); Munsik-Park/opensre#28
  and #29 (the facts on CI).
