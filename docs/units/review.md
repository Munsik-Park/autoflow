# U7 Review — REVIEW

> Unit document for U7. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U7 Review is one module, the review module, whose contract is
`<autoflow-root>/docs/contracts/review.json` and whose procedure is this file
([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D1,
[`ADR-0033`](../records/adr/0033-review-unit-and-script-reviewers.md)): one round of a pull request's
review. It has no unit agent: the session that runs it runs the reviewers, and the aggregation of the
round's reviews into one verdict is made by a spawned role. A script only reads and reports.

- **Goal**: the pull request reviewed by every configured reviewer, and one aggregated verdict over
  their reviews posted on it: each finding once, with its severity and whether it holds.
- **Inputs**: the pull request (`params.pr`) and the round (`params.round`); on a later round, the
  previous round's findings file; the attempt's record directory, where the earlier rounds' records
  and the work's records are.
- **Output**: each reviewer's review record (*Reviewer review*), the findings file and the round's
  comment, posted on the pull request (*Review aggregation*).
- **What a script reads and reports**: a reviewer run's start check (*Reviewer review*; the run
  itself is the reviewer's wrapper), by exit code.
- **Checks**: check-out confirms that the findings file's `pr:` line names the reviewed pull request,
  that its one `max_severity:` line is the highest severity among the rows that hold, and that the
  comment is posted on the pull request (`review.json`); the reviews and their aggregation stand
  outside the work they review.
- **Result owed**: the report of *End* below.

## Reviewer review

A run reviews the one pull request its invocation names (`params.pr`, `<owner>/<name>#<N>`), on its
own diff; each pull request of a change — the host PR and each sub-repo PR alike — is reviewed by a
run of its own, and a sub-repo PR's review is required, not optional. A run is one round of that
PR's review (`params.round`, from `1`): it runs every reviewer, and their records go to one
aggregation (*Review aggregation* below), which posts the round's comment
([ADR-0026](../records/adr/0026-aggregated-review.md)).

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](../reviewer-backend.md) > *Config
location*). Each runs as its own script, launched in the background:

```
bash <autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>] [--records <attempt-dir>]
bash <autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>]
bash <autoflow-root>/scripts/review/review-start-check.sh --pr <N> --reviewer <name> [--repo <owner/name>] [--log <the run's captured output>]
```

Each wrapper stops when the PR it is given is not that OPEN PR on that head branch, then runs its
reviewer over the PR with that reviewer's rule file and, where one is configured, its lenses file
([`reviewer-backend.md`](../reviewer-backend.md) > *Rule files*), on the model and effort the same
file names; the reviewer writes its review and nothing else. `--records` names the attempt's record
directory the invocation gives (`records`), where the `claude` reviewer reads the earlier runs'
work — the analysis report, the design documents, the decision ledger and the build report.
`<record>` is the review record's absolute path below; nothing a wrapper or its reviewer writes
stays in the target's tree.

The run is made in a checkout of the repository — the same origin — whose checked-out branch is the
pull request's head branch at its head: the `claude` reviewer reads that working tree beside the
pull request's diff.

**The reviews of the target's side.** A review a system on the target's side runs on the pull
request by itself — a review bot's review or review comment — is a review of the round too. It is
not launched and leaves no record: the aggregator reads it from the pull request (*Review
aggregation*). Whether to wait for one that has not yet arrived is the module's judgment.

**An unreadable operator file.** When the operator's `~/.autoflow/config.json` cannot be read as
configured, `check-review-backend.sh` exits `6` and each wrapper starts no reviewer and exits `6`;
each prints the marker line `user-config: UNREADABLE <path> — <error>`, which
`review-start-check.sh` reports as exit `4`. The round goes on without those reviewers, on the
reviews of the target's side: the aggregation names the missing reviewers with that reason, and the
run records the unreadable file — its path and the error — as a tool request.

Each review lands in a **review record**, `<out>/reviews/<reviewer>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`).

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker:

| Exit | Meaning | What follows |
|---|---|---|
| `0` | started, or already completed with exit 0 | the session ends its turn and waits for the run's completion notification ([`core.md`](../core.md) > Execution Principles > *Wait discipline*) |
| `1` | no signal within the window (30 s) | the review is launched again, or the reviewer is named unavailable for the round with the reason — the module's judgment |
| `3` | the wrapper completed with a non-zero exit — the review run failed or left no record | the same |
| `4` | the wrapper's output carries `user-config: UNREADABLE …` — no reviewer started | the round goes on without those reviewers (*An unreadable operator file* above); no relaunch |

A reviewer that is unavailable for a round — its CLI absent (`check-review-backend.sh` reports it),
its run failing, or the operator's file unreadable — does not hold the round: the aggregation runs
on the reviews that exist, and its comment names the reviewer that is missing and why. A round with
no review at all — no configured reviewer left a record, and the target's side left none — is a
review-infrastructure failure, a harness-level block the run records in its result, situation-first
([`core.md`](../core.md) > Execution Principles > *Human-decision presentation*).

Cautions:

- A review that started is left to finish on its own clock, however long that takes; it is not
  relaunched because it is slow.
- Every round runs every reviewer on the pull request's current head
  (`gh pr view <N> --json headRefOid`).
- The reviewers of a round may run at once, and runs on the host PR and each sub-repo PR alongside
  each other; each review is confirmed with its own `--pr` and, for a sub-repo PR, `--repo`.

## Review triage

Per reviewed PR, after its round's reviews complete.

### Review aggregation

**1. The reviews are aggregated by a spawned analysis role.** The session does not read the
review records or the comment body itself (Cost Control). An anonymous direct subagent —
`subagent_type: autoflow-analyzer`, on the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names — is
the aggregator. Its prompt names the PR as `<owner>/<name>#<N>`, the round, the record paths, any
reviewer unavailable for the round with the reason, the decision ledger, the earlier rounds'
findings files and comments in the record directory, and, for a PR whose repository has
submodules, their paths (its `.gitmodules`) — the locations outside that review's target. It also
reads the reviews of the target's side from the pull request itself and names each one's author as
its source.

Its purpose is one verdict over every review of the PR. How it groups duplicates, settles a
severity the reviews disagree on, and weighs each finding (*Whether a finding holds*) is its own; what
it leaves behind is fixed:

- **One PR comment**, in Korean, per round: each finding once, with the reviewers that raised it;
  a finding only one reviewer raised kept like any other; each rejected finding listed apart with the
  grounds it does not hold; a reviewer unavailable for the round named with the reason. Its body is kept as
  `<out>/comment.md`.
- **The findings file** (below).

It returns `{max_severity, findings}`.

- **[MUST] One findings file per round.** Each run's aggregation writes `<out>/findings.md` for the reviewed PR `<owner>/<name>#<pr>`; a later round writes its own in its own run directory. The file carries a `pr: <owner>/<name>#<N>` line naming the reviewed PR, exactly one `max_severity: <level>` line — the highest level among the findings that hold, `Low Confidence` included, in colon notation, `max_severity: None` when none remains (never an omitted line) — and one table row per finding, `| <Severity> | <path>:<line> | <finding> | <source> | <disposition> |` — severity first, location second (a path relative to the reviewed PR's repository root), `<source>` the names of the reviewers that raised it (`claude`, `codex`, a review bot's login), and `<disposition>` empty, or `rejected` for a finding that does not hold — always the row's last cell, so a `|` quoted in the finding cell moves no other cell. A `rejected` row is a record: it counts toward no verdict. Where the fix of a finding that holds is made is not the aggregator's to state: it is the judgment of the AI acting on the finding ([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D6).
- **[MUST] A PR's review covers its own repository.** A review's target is what the reviewed PR's repository tracks directly — every file of its tree, a submodule's pointer included, never a submodule's contents (`<autoflow-root>/docs/review/review.md` > Before Reviewing). Every finding therefore belongs to the reviewed PR, and its `max_severity` rests on that PR's own findings alone. A host PR whose diff is a submodule pointer is reviewed over the host repository like any other PR; the sub-repo code behind the pointer is judged by the sub-repo PR's review. A finding a review raises inside a submodule misreads that target: the aggregator rejects it as a finding that does not hold.

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A module acting on a finding that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file and the comment, and counted toward no verdict ([ADR-0026](../records/adr/0026-aggregated-review.md)). A finding that the module acting on it finds does not hold is a rebuttal: it is posted with its grounds on the PR, and the next round's reviews and aggregation judge it — a round of its own also when it only rebuts and changes no code. A gate recommendation's rebuttal is judged by the recommending evaluation's re-score. One that holds in part is fixed for the real problem it points to. When a rebutted finding is kept and the two sides still disagree, the module acting on it puts it to the advisor and follows the decision ([`role-contracts.md`](../role-contracts.md) > Advisor; [`core.md`](../core.md) > Rule Scope, principle 3); no count decides when.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A change can loop: each fix answers the case a reviewer — or an evaluation's recommendation — named
while the property it asserts stays unmet, and the next review or re-score names another case. No
spawn checks for this on every round. Whoever reads the finding — the aggregator here, the analysis
module, or the module acting on an evaluation's recommendation — and sees that it repeats an earlier
complaint (the same property asserted, a different witness case; the earlier rounds' findings files
and comments, and the earlier evaluations in the record directory, are what it compares against)
says so where it writes the finding: in the finding's cell of the findings file, under the analysis
report's `## Decision points`, or in its own report. What follows — restating the acceptance
criterion as one rule over the whole input, a further case-specific change, or leaving the property
a known gap — the module acting on the finding decides; a change to the criterion, and a choice it
doubts, it puts to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor), and a
redefined criterion is recorded as `[ac-decision]` entries. A complaint already decided is not decided again without a new verified
fact ([`core.md`](../core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case.

## End

The run ends when its round's comment is posted. Its report names the pull request's URL and head
commit, the highest severity among the findings that hold (the findings file's `max_severity:`), the
findings file and the comment, and the round `k` — with the rework count `k − 1` — and, for a host
pull request whose pointer names a sub-repo pull request's commit, that dependency.

**[MUST]** AutoFlow merges nothing and promotes no draft. The hook denies `gh pr merge` and a push
to the default branch.

What follows an external merge or close — the attempt's branches and records included — is outside
AutoFlow ([`git-workflow.md`](../git-workflow.md) > Post-Merge Cleanup).
