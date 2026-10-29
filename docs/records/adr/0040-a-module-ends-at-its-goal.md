# ADR-0040: A module ends at its goal — its checks see form, its outputs have defaults

## Status

Accepted (operator decision 2026-10-29, issue #523). Extends ADR-0039 D3 and D4 from the delivery
and ci modules to every module. Amends ADR-0038 D1 — what the contract checks, and the output's
disposal of every item the work owes — and D4 — the commits as a range the invocation names —, and
ADR-0039 D1 — the delivery's `pull_request` param and the ci module's goal. ADR-0038 D2, ADR-0039 D2
and the authority rules of the core stand.

## Context

ADR-0038 D2 settled that AutoFlow describes the modules, not what runs them: whether a module's
output is right, and what is done with it, is the running side's. ADR-0039 applied it to the
delivery and ci modules (issue #518): each given the kinds of its inputs, the kind and form of its
output, its tools and its authority rules; a run that does not reach its goal writes a failure
output; check-out checks the output's form only.

Issue #523 records where the other contracts still departed from it:

- **Checks that stood in for the receiving side's.** The review's check-out read the pull request's
  comments on GitHub and compared them with `comment.md` (`pr_comment_posted`), so a review kept as
  a file alone was refused. The build's check-in recorded the branch's head and its check-out
  computed the commit range in git (`git_range`), writing the output `commits` itself, and required a
  `## No commit` section of the report when there was none (`absent_reason`). The check-in of a
  commit-range input — audit, quality, delivery — read git for the branch, both commits, their order
  and the branch containing them (`check_range`).
- **A goal split into items and counted.** On a re-score, the four evaluation contracts required
  `rescore` (`required_when` an input), counted an entry of `rescore.prior_findings` for every
  finding of the previous evaluation (`covers`, `count_only`), and checked that every rubric item
  was in exactly one of `rescore.rescored` and `rescore.inherited` (`partition`).
- **Outputs whose destination was fixed.** The review's goal included posting on the pull request and
  its comment's format was `pull-request-comment`; the ci module's goal included writing the verdict
  into the body's CI part; the delivery's way to change its default was `pull_request: open|none`, an
  enumeration of two values.

The operator's decision of 2026-10-29: a module is a part. It takes its inputs, makes the output its
goal asks for and ends; whether it reached the goal is judged by the AI that did the work, and a run
that does not reach it writes what it did and why. Check-in sees that an input is there and of its
form, check-out that an output is there in the form asked; the facts an output states, and its fit
to the inputs, are the receiving side's to check with the same tools — it reads the result anyway,
and runs the module again when it is wrong. No device counts the items of a goal one by one:
counting fixed items is a script's work, and the AI is given the goal. An output has a default and
the invocation's instructions change it; the contract states the default only. Kept: an input's
producing module (`from`), which names the input's form — check-in reads the form, not where the
file came from, so an input the running side wrote in the same form passes —; the dispositions the
criterion-screen and criterion-reconcile goals list; and the form checks of an output (keys,
sections, tables, duplicates, forbidden keys) and the failure output.

## Decision

**D1 — A run ends at its goal.** The AI that does the work judges when its output reaches the
module's goal, and the run ends there. A run that does not reach it writes its contract's failure
output, `<out>/failure.md` — what it did, and why it did not reach the goal —, in place of its
expected output, and check-out writes `failed` (ADR-0039 D3). Every contract whose work an AI does —
functional and evaluation — declares the failure output; criteria-apply, a script, refuses its run
as before. `contract.sh lint` refuses a functional or evaluation contract with no failure output.

**D2 — The checks see form, each file read alone.** Check-in checks that each param and input the
contract declares is given and that an input file is of the form its producer's output, or the
invocation's file, is given; check-out that each output is there in its form. Nothing in git, on
GitHub or in another input is read to check a file. `contract.sh` drops the `git` and
`pull-request-comment` formats, the `git_range`, `pr_comment_posted`, `partition` and `covers`
checks, a table's `covers`, a `when` or `required_when` naming an input, the commit-range check of
an input and the branch heads check-in recorded; `lint` refuses a check that names an input. The
`.check-in.json` marker stays, naming the module.

**D3 — The build names its own commits.** The build writes `<out>/commits.json`, `{branch, from,
to}` — the branch it worked on and its head when the run began and when it ended, `from` equal to
`to` when it made no commit, its report saying why. Check-out checks the keys. The audit, quality
and delivery modules take that file's path as their `commits` input, its form checked at check-in.
The `## No commit` section goes; the report still says why a run made no commit.

**D4 — A re-score states what it scored afresh and what it inherited.** The goal of each evaluation
module states it: given the previous evaluation, the evaluation names which items it scored afresh
(`rescore.rescored`) and which it inherited (`rescore.inherited`), and what became of the previous
evaluation's findings (`rescore.prior_findings`, `cleared` or `remains` with the ground). Which items
it scores afresh is the evaluator's judgment from the previous evaluation and the change since it.
`rescore` stays in the output's form as an object, required by no check; the two `[MUST]` bullets of
`docs/evaluation-system.md` > *Re-score* that the counting checks enforced become that goal.

**D5 — An output has a default, and the invocation's instructions change it.** An invocation may
carry `instructions`, a text; check-in checks that it is a non-empty string. Each output's default
is what its contract and its procedure state — a file in the output directory and, for some modules
beyond it, a push, a pull request, a comment, a pull request's body —; the instructions change where
an output goes or its form, and the module follows them, the authority rules holding under any
instruction (`docs/core.md` > Development Lifecycle > *Where an output goes*). Applied:

| Module | Default | Before |
|---|---|---|
| `review` | `<out>/comment.md`, a markdown file, posted on the pull request | the goal posted it; the format `pull-request-comment`, checked on GitHub |
| `ci` | `<out>/ci.json`, and each pull request's body carrying its CI part | the goal included the body's CI part |
| `delivery` | the branches pushed and draft pull requests opened, `<out>/delivery.json` | `pull_request: open\|none` |
| every module | its outputs in `<out>` as its contract names them | no way to change them |

## Alternatives Considered

- **A per-contract param for each changeable output** (`pull_request` widened to every module).
  Rejected: every contract would enumerate the alternatives to its default, where the decision is
  that a contract states the default only.
- **Keeping the re-score's counting checks as a warning.** Rejected: a counted item list is the
  device the decision removes; the receiving side reads the re-score anyway.
- **The build's range still computed by check-out, written beside the run's own.** Rejected: the
  check-out would again be a second implementation of what the module reports.

## Consequences

### Positive

- A module can run where git or GitHub is not what it writes to — a review kept as a file, a push
  with no pull request — and still be `accepted`.
- The contracts and the checker read files only; the checker needs `jq` alone.
- A run that falls short says so in one place, the same for every module.

### Negative

- Check-out accepts a `commits.json` whose commits are not on the branch, a comment that was never
  posted and a re-score that leaves out an item or a previous finding, as long as each file's form
  holds; nothing AutoFlow ships checks those facts.
- What an instruction may change is not enumerated; an instruction the authority rules forbid is
  denied by the hook where it reaches one, and otherwise by the module's reading of the rules.

## Relation to other decisions

- **ADR-0038** — D1's "the contract checks the inputs and the facts of the output" becomes the form
  of the inputs and outputs (D2), and "the output disposes of every item the work owes" leaves the
  core's text, which states the goal and the run's end (D1). D4's "the commits as a range" is the
  build's `commits.json` (D3). D2 stands and is applied.
- **ADR-0039** — D3 and D4 extend to every module (D1, D2). D1's `pull_request` param goes, its
  default kept (D5); the ci module's goal no longer includes the body's CI part, which stays its
  default output.
- **ADR-0026** — one aggregated comment per round stands; where it goes is the review's default.

## Related Issues / PRs

- Issue #523; issue #518, PR #521 and ADR-0039 (the pattern applied).
