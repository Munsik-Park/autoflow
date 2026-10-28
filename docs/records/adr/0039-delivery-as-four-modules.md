# ADR-0039: Delivery as four modules

## Status

Proposed (issue #518). Amends ADR-0038 D1 — the module list, and check-out's result — and the
delivery's contract. ADR-0038 D2, ADR-0034 D2 and D5, and the authority rules of the core stand.

## Context

ADR-0038 D1 made U6 Delivery one module, whose run pushed the branch, ran the integration checks,
opened the draft pull requests and wrote their bodies, confirmed CI, recorded a CI that did not run,
confirmed that each added test file ran in CI, had a failed check read, delivered each changed
sub-repo with its pointer, and ordered all of it: the pull request opened once the integration
checks passed, the next step chosen by the CI result (`docs/units/delivery.md` before this change).
Its contract (`docs/contracts/delivery.json`) required six inputs from four modules, and its
check-out read the pull request and its CI in one check, so a re-run of one part was a re-run of
all of it with every input.

The criterion review split one session's procedure into four modules on each stage's fixed inputs
and outputs (`docs/records/design-reviews/io-contract-modules.md` > 4); whether the four run in
one session or one alone is not AutoFlow's to say (ADR-0038 D2). Issue #518 asks the same of the
delivery and records three facts:

- the CI confirmation script and the delivery's check-out judged green differently — the script by
  one representative per check identity with a superseded run's `CANCELLED` dropped, check-out by
  every element of the raw rollup — so a pull request re-run to green beside an old `CANCELLED`
  row passed the one and was refused by the other (PR #517's review);
- Munsik-Park/opensre#29 received no check within the bound, with Actions on and its workflow
  active; the cause was not found;
- the script's message on that exit, "re-push to force a synchronize event", has no effect: a push
  of the same commit sends no ref update.

The operator's decisions on the issue: the decision not to open a pull request after a failed
integration check is not a module's; whether a sub-repo's pull request is opened, and whether its
pointer is recorded now, is not a module's — the module pushes, opens and records what it is told;
and by default, with local tests green, pushing and opening the pull request are one action, a
push alone or no pull request only on an explicit instruction. A module is given its inputs, the
expected value of its output and its end — the expected output reached, or a failure output saying
what it did and why it did not reach it, a timeout included —, and its steps are the AI's.

## Decision

**D1 — Delivery is four modules.** Each has a contract under `docs/contracts/` and
`docs/units/delivery.md` as its procedure:

- `integration` — the change shown working above its own tests, on the branch, before a push;
- `delivery` — the branches pushed and their draft pull requests opened or updated, sub-repos
  included as the invocation names them;
- `ci` — CI confirmed on each pull request it is given, the body's CI part written, each added test
  file's CI job confirmed;
- `ci-failure` — what each failed check shows and where its fix is made, read by an
  `autoflow-analyzer` spawn.

Each process of the former module is placed as follows.

| Process | Placed in | Grounds |
|---|---|---|
| Push of the host branch | `delivery` | A push is a module's own command, which the hook sees (core > Push and PR creation; Rule Scope principle 1); by the operator's default it is one action with opening the pull request. |
| Integration checks and the deploy/CI-path verification | `integration` | Own inputs (the commits and the design and build documents) and own output (`integration.md`); it runs on the branch before anything is pushed. Kept apart from the push so that whether a pull request follows a failed check is decided outside the module, as the operator decided. |
| Opening the draft pull request, its body, updating an open one | `delivery` | The operator's default: push and pull request are one action; the draft rule is an authority rule of the module that opens it. |
| CI confirmation, the conflict read, recording CI as not run, confirming each added test file ran in CI | `ci` | All four are the state of CI on a pull request's head and the body's CI part that states it; one script reads them; run alone, it can be run again on a pull request whose head or draft state changed since it was opened. |
| Reading a failed check | `ci-failure` | A role spawn of its own with its own input (the failed checks) and output (`ci-failure.md`), as each criterion stage was; whether a failure is read after a red CI is a choice made on the CI result, which is not a module's (D2). |
| Sub-repo push, pull request and host pointer commit | `delivery`, per the invocation's `sub_repos` | The delivery module is the committer of the pointer and the opener of each pull request (core > Commit Ownership); which sub-repos, and whether a pointer moves now, the invocation says (the operator's decision). |
| Opening a pull request only after the integration checks pass | outside the modules | The operator's decision. |
| The next step after a CI result — reading a failure, a new push, a rebuild | outside the modules | The order of modules and what follows an output are not a module's (ADR-0038 D2). |
| Whether a sub-repo's pull request is opened, and whether its pointer is recorded now | outside the modules | The operator's decision; it needs information no one module has. |
| A re-run, its count, and a timeout's value for a run | outside the modules | ADR-0038 D2, Q3; a module takes its timeout as a param. |

What is left outside is not described: no document names who does it or how (ADR-0038 D2).

**D2 — Each delivery module states its inputs, its expected output and its end.** A module works
from its params and its declared inputs; the record directory is where earlier runs' working files
and the ledger are, and does not stand in for an input — an input the work needs and was not given
is named in the failure output. A module's contract carries a `timeout` param (seconds), with its
default in the procedure. Inside a run the steps are the AI's.

**D3 — A run that cannot reach its expected output writes a failure output, and its result is
`failed`.** A contract may declare one output as its failure output (`"failure": true`, a markdown
file, not required). A run that judges its expected output unreachable, or reaches its timeout,
writes it — what it did, what it observed, and why it did not reach the expected output. Check-out
then checks that file is not empty and the tool requests, records every output present, and writes
`result.json` with `status: "failed"` (exit `3`). `accepted` and `refused` keep their meaning; a
`failed` result is the module's own statement, not a defect of its output. The four delivery
contracts declare `failure.md`.

**D4 — Green is one judgment, made by one script, on the head the output names.** The ci module
confirms CI with `scripts/handoff/confirm-ci-green.sh`, and its check-out (`ci_verdict`) judges
each pull request its output calls `green` or `not-run` with the same script read once (`--once`),
on the pull request's head when it equals the head the output names: `green` is exit `0` and a body
without the `CI: not run` line, `not-run` exit `11` and a body with it. So the identity dedup, the
superseded-run drop and the mergeable state are applied by both, and a head that moved since the
output was written is a defect, not a verdict on another head. In the script, a check that has
concluded with any conclusion but `SUCCESS`, `NEUTRAL` and `SKIPPED` is a failure (exit `12`) —
`STARTUP_FAILURE`, `STALE` and `ACTION_REQUIRED` no longer wait for the deadline; exit `11` needs at
least one well-formed read of the checks, and a run in which every read failed is exit `14`; every
non-green exit ends with the line of what it read (`observed: …`); and its messages state what was
read, not what to do next — the "re-push to force a synchronize event" and "re-run with a larger
CI_POLL_TIMEOUT_SECS" advice goes. The documents that described green as "at least one check present
and every element green" refer to the script's judgment instead.

**D5 — The delivery module's output names every branch it pushed and every pull request it opened
or updated.** `delivery.json` lists each pushed branch (`{repo, branch, head, path}`), each pull
request as `<owner>/<name>#<N>` with its head and whether this run opened it, each pointer set and
each changed sub-repo not delivered. Check-out (`pushed`, `pr_open`) reads each on GitHub: a branch
at its head, a pull request open at its head and, when this run opened it, a draft — so a pull
request the operator has since promoted does not refuse a later run that did not open it. The review
takes its `pr` from an entry. Check-in does not re-read these facts of an input; what holds now is
the reading module's to judge.

## Alternatives Considered

- **Three modules, the failure read inside `ci`.** Rejected: the read is a separate role spawn
  with its own output, and reading it is a choice on the CI result — the order D2 of ADR-0038
  leaves outside.
- **Integration inside `delivery`.** Rejected: the module would then decide not to open the pull
  request after a failed check, which the operator left outside the module.
- **Push and pull request as two modules.** Rejected by the operator's decision: one action by
  default; a push alone is the `pull_request: none` param, and a further split waits for a need.
- **A failed run reported as `refused`.** Rejected: `refused` means the output does not meet the
  contract; a module that honestly reports it could not reach its expected output would read the
  same as one whose output is wrong.
- **check-out keeping its own green predicate, aligned with the script's.** Rejected: two
  implementations of one judgment are what diverged (PR #517); one script judges both.

## Consequences

### Positive

- One part of the delivery can be run again with only its own inputs: CI confirmed again on a
  promoted pull request, a failure read on any red pull request, the integration checks run before a
  push.
- The ci module and its check-out cannot disagree on what green is on the head the output names.
- A run that did not reach its expected output is `failed` in `result.json`, with its failure
  output beside it.
- Every pull request the delivery opens, sub-repos included, is in its output and checked.

### Negative

- Four command bodies and four contracts where there was one.
- What the former module ordered — no pull request after a failed check, a failure read after a red
  CI — is nowhere in AutoFlow's text; nothing AutoFlow ships enforces it.
- The ci module's check-out reads GitHub once more, with the superseded-run lookups.

## Relation to other decisions

- **ADR-0038** — D1's list of functional modules names `integration`, `delivery`, `ci` and
  `ci-failure` in place of `delivery`, and check-out writes `failed` beside `accepted` and
  `refused` (D3). D2 stands and is applied: what follows each output is not described.
- **ADR-0034** — D5's hand-off without CI stands: `not-run` is the ci module's expected output when
  CI does not run for a pull request, recorded with its ground.
- **ADR-0033** — U7 Review stays one module; it takes its `pr` from an entry of `delivery.json`.

## Related Issues / PRs

- Issue #518; PR #517's review (the green judgment); Munsik-Park/opensre#28 and #29 (the facts on
  CI).
