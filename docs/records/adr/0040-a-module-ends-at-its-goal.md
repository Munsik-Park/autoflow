# ADR-0040: A module ends at its goal — its checks see form, the instructions override its default

## Status

Accepted (operator decision 2026-10-29, issue #523). Extends ADR-0039 D3 and D4 from the delivery
and ci modules to every module. Amends ADR-0038 D1 — what the contract checks — and D4 — the commits
as a range the invocation names —, ADR-0039 D1 — the delivery's `pull_request` param, the
delivery's goal and the ci module's goal —, and ADR-0026 D3 — the posting of the one comment on the
pull request. ADR-0038 D2, ADR-0039 D2 and the authority rules of the
core stand. The operator's answers of 2026-10-29 to the first draft's open points are applied: the
re-score's rubric and the goal of every item the work owes stand, and the failure output is one
shape of the output, required of no contract by a check. The operator's decision of 2026-10-29 on
the pull request's third review round is applied to D5: a module is defined by its inputs, its
outputs and its default, each contract states its `default`, and the instructions override the
default and never the outputs. The operator's decision of 2026-10-30 is applied to D5: a module's
role is its goal, and its default holds only what it does with its result by default — the build's
commits are its goal, its default nothing beyond its outputs; the delivery's goal is the change
delivered for the operator to decide on, its default the pointer commit, the push and the draft pull
requests with their bodies. The operator's decision of 2026-10-30 on the pull request's fourth review
round is applied to D5: the review's outputs are its result, its default nothing beyond them. D5's
clause that the instructions never change the outputs is removed by issue #539.

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
goal asks for and ends; whether it reached the goal is judged by the AI that did the work. The
output a run makes of its inputs is one of two: what reaches the goal, or what does not — what it
did and why it did not reach the goal. Check-in sees that an input is there and of its form,
check-out that an output is there in the form asked; the facts an output states, and its fit to the
inputs, are the receiving side's to check with the same tools — it reads the result anyway, and runs
the module again when it is wrong. No device counts the items of a goal one by one: counting fixed
items is a script's work, and the AI is given the goal — the output disposes of every item the work
owes, each applied acceptance criterion among them, and the re-score's rubric stands as one of the
goals. A module is defined by its inputs, its outputs and its default: its outputs are the files it
writes in its output directory, by the names and forms its contract gives; its default is what it
does with its result unless the invocation says otherwise; the invocation's instructions override the
default and never the outputs. Kept: an input's producing module (`from`), which names the input's form — check-in
reads the form, not where the file came from, so an input the running side wrote in the same form
passes —; the dispositions the criterion-screen and criterion-reconcile goals list; and the form
checks of an output (keys, sections, tables, duplicates, forbidden keys) and the failure output in
the form ADR-0039 D3 set.

## Decision

**D1 — A run ends at its goal.** The AI that does the work judges when its output reaches the
module's goal, and the run ends there. A failure is not a device of its own but one shape of the
output: the output a run makes of its inputs is either what reaches the goal or what does not — what
the run did and why it did not reach the goal —, written in the form ADR-0039 D3 set, the contract's
failure output `<out>/failure.md`, on which check-out writes `failed`. The contracts whose work an AI
does — functional and evaluation — declare it; criteria-apply, a script, refuses its run as before.
No check requires a contract to declare it.

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
(`rescore.rescored`) and which it inherited (`rescore.inherited`). The re-score's rubric stands as
one of the goals the evaluator works to: `docs/evaluation-system.md` > *Re-score* keeps its two
`[MUST]` bullets, the Evaluation AI's role contract — the items scored afresh (each scored below 7
or with a finding in the previous evaluation, and each whose anchors the change since touched) and
the rest inherited, every rubric item in one of the two lists; every finding of the previous
evaluation `cleared` or `remains` with its ground, a finding on an inherited item `remains`. The
counting checks that compared the output with the previous evaluation go (`partition`, `covers`,
`rescore` required when an input is given); `rescore` stays in the output's form as an object.

**D5 — A module is its inputs, its outputs and its default; the instructions override the default.**
An invocation may carry `instructions`, a text; check-in checks that it is a non-empty string. A
module's outputs are the files it writes in its output directory, by the names and in the forms its
contract gives; the instructions do not change them, and check-out checks that form as before. Its
default is what it does with its result unless the invocation says otherwise; each contract states
it as `default` and the module's procedure states it apart from the outputs. A module's role is its
goal, and its default holds only what it does with the result: the delivery's goal is the change the
build made delivered for the operator to see and decide on, and pushing it and opening the draft
pull requests is its default; the build's commits are its goal; the review's goal is the pull
request's reviews aggregated into one verdict, its default nothing beyond its outputs. The
instructions override the default. The AI that does the module's work — the session, or the spawn
the work is given to — receives the instructions with the inputs and follows them, the authority
rules holding under any instruction (`docs/core.md` > Development Lifecycle > *Inputs, outputs and
default*). Applied:

| Module | Outputs | Default | Before |
|---|---|---|---|
| `ci` | `<out>/ci.json` | each pull request's body carrying the verdict in its CI part | the goal included the body's CI part |
| `delivery` | `<out>/delivery.json` | a sub-repo's pointer commit, the change pushed, each branch in a draft pull request with its body | the goal included the push and the draft pull requests; `pull_request: open\|none` |
| every other module | its contract's | nothing beyond its outputs | — |

## Alternatives Considered

- **A per-contract param for each changeable default** (`pull_request` widened to every module).
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
- A run that falls short says so in its output, in the one form ADR-0039 D3 set, the same for every
  module.

### Negative

- Check-out accepts a `commits.json` whose commits are not on the branch and a re-score that leaves
  out an item or a previous finding, as long as each file's form holds; nothing AutoFlow ships checks
  those facts. The re-score's rubric binds the evaluator as its role contract, and the receiving side
  reads whether it was met.
- An instruction to write an output under another name or in another form is not followed in the
  output directory: check-out reads the contract's names and forms only.
- What an instruction may change is not enumerated; an instruction the authority rules forbid is
  denied by the hook where it reaches one, and otherwise by the module's reading of the rules.

## Relation to other decisions

- **ADR-0038** — D1's "the contract checks the inputs and the facts of the output" becomes the form
  of the inputs and outputs (D2); "the output disposes of every item the work owes" stands as the
  goal, which the evaluations judge, and the core adds the run's end (D1). D4's "the commits as a
  range" is the build's `commits.json` (D3). D2 stands and is applied.
- **ADR-0039** — D3's form of the failure output is the one every module uses, and D4 extends to
  every module (D1, D2). D1's `pull_request` param goes, its
  default kept (D5); the delivery's goal is the change delivered for the operator to decide on, the
  push and the draft pull requests its default, and the ci module's goal the verdict, the body's CI
  part its default.
- **ADR-0026** — D3's posting of the one comment on the pull request is amended: the one comment is
  the review's output `<out>/comment.md` (D5). Issue #537 removed that output: the findings file is
  the review's one report.

## Related Issues / PRs

- Issue #523; issue #518, PR #521 and ADR-0039 (the pattern applied).
