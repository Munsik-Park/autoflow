# U7 Review — REVIEW

> The procedure of the review module. [`core.md`](../core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U7 Review is one module, the review module, whose contract is
`<autoflow-root>/docs/contracts/review.json` and whose procedure is this file
([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D1,
[`ADR-0033`](../records/adr/0033-review-unit-and-script-reviewers.md)): one pull request's review.

- **Goal**: the given pull request reviewed by its configured reviewers, and their reviews aggregated
  into one report.
- **Inputs**: the pull request (`params.pr`); on a later review, the previous report; the attempt's
  record directory, where the earlier reviews' records and the work's records are.
- **Output**: each reviewer's review record, `<out>/reviews/`, and the report,
  `<out>/review-findings.md`.
- **Default**: nothing beyond its outputs ([`core.md`](../core.md) > Development Lifecycle >
  *Inputs, outputs and default*).

## Reviewer review

A run reviews the one pull request its invocation names (`params.pr`, `<owner>/<name>#<N>`). The
review rules are `<autoflow-root>/docs/review/review.md`.

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](../reviewer-backend.md) > *Config
location*). Each runs as its own script:

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

Each review lands in a **review record**, `<out>/reviews/<reviewer>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`).

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker, and reports by exit code (the script's header).

## Review triage

### Review aggregation

How the reviews become one report is the run's own judgment. An `autoflow-analyzer` spawn, on the
model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model handoff-review-triage` names, is available for it.

For reference, a report a later run can act on names the reviewed pull request and its head, and each
finding once — the reviewers that raised it, its severity
(`<autoflow-root>/docs/review/review.md` > Severity) and whether it holds, with the grounds of one that
does not — and the highest severity among the findings that hold.

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and records a finding that does not hold, or holds in part, with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A module acting on a finding that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file, and counted toward no verdict ([ADR-0026](../records/adr/0026-aggregated-review.md)). A finding that the module acting on it finds does not hold is a rebuttal: it is posted with its grounds on the PR, and the next round's reviews and aggregation judge it — a round of its own also when it only rebuts and changes no code. A gate recommendation's rebuttal is judged by the recommending evaluation's re-score. One that holds in part is fixed for the real problem it points to. When a rebutted finding is kept and the two sides still disagree, the module acting on it puts it to the advisor and follows the decision ([`role-contracts.md`](../role-contracts.md) > Advisor; [`core.md`](../core.md) > Development Lifecycle > *Decisions within a module*); no count decides when.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A change can loop: each fix answers the case a reviewer — or an evaluation's recommendation — named
while the property it asserts stays unmet, and the next review or re-score names another case. No
spawn checks for this on every round. Whoever reads the finding — the aggregator here, the analysis
module, or the module acting on an evaluation's recommendation — and sees that it repeats an earlier
complaint (the same property asserted, a different witness case; the earlier rounds' findings files, and the earlier evaluations in the record directory, are what it compares against)
says so where it writes the finding: with the finding in the findings file, under the analysis
report, or in its own report. What follows — restating the acceptance
criterion as one rule over the whole input, a further case-specific change, or leaving the property
a known gap — the module acting on the finding decides; a change to the criterion, and a choice it
doubts, it puts to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor), and a
redefined criterion is recorded as `[ac-decision]` entries. A complaint already decided is not decided again without a new verified
fact ([`core.md`](../core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case.

## End

The run ends with its output — the verdict its goal asks for, or the failure output when it does not reach the goal ([`core.md`](../core.md) > Development Lifecycle).

What follows an external merge or close — the attempt's branches and records included — is outside
AutoFlow ([`git-workflow.md`](../git-workflow.md) > Post-Merge Cleanup).
