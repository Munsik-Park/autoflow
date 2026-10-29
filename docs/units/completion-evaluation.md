# U5 Completion evaluation — GATE:QUALITY

> The procedure of the quality module. [`core.md`](../core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U5 Completion evaluation is one module, the quality evaluation, whose contract is
`<autoflow-root>/docs/contracts/quality.json` and whose procedure is
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY — its input, its ten
items, its known blind-spot checks and its re-score
([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D1). This file states
the module's goal, how the recommendations of every evaluation are disposed of, and how a comment in
a target's code is treated.

- **Goal**: the change, judged against the applied acceptance criteria, the design and the build's
  own records before it is delivered — complete, correct, verified, within its scope, and committed
  and documented as the rules ask.
- **Output**: the evaluation object [`evaluation-system.md`](../evaluation-system.md) > Evaluation
  Output Format defines — ten scores with their grounds, `refine_observations`, `recommendations`,
  and `rescore` on a re-score —, which the evaluator writes to `<out>/evaluation.json`.
- **Independence**: a fresh Evaluation AI (`autoflow-evaluator`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-quality` names) for every
  run, never the author of what it scores, read-only
  ([`role-contracts.md`](../role-contracts.md) > Evaluation AI); check-out confirms the output's
  form. Beyond it, CI and the review verify the delivered change.
- **Result owed**: the evaluation file and a one-line summary.

**Evaluator**: a fresh-spawned Evaluation AI scores the change on the rubric of
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY. Its agent
definition carries that document.

## Recommendation triage

An evaluation's `recommendations` — at GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY alike —
are findings the evaluator recorded, each with its subject, the item it was found under, its severity
and the finding ([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format). They
are disposed of as a reviewer's findings are: whether each holds is weighed first
([U7 Review](review.md) > *Whether a finding holds*), and every one leaves with a disposition and its
grounds. Where a fix is made is the judgment of the AI acting on the finding
([`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D6). The severity is information for that
judgment, and no rule branches on it.

- **Fixed.** The fix is made where the change it needs belongs — the analysis report, the design,
  the build — or, for a fix no module owns, in a commit of its own. The
  recommending evaluation's re-score judges it: the finding's `rescore.prior_findings` entry is
  `cleared` or `remains`.
- **Does not hold.** It is rebutted with the grounds that show it, and the recommending
  evaluation's re-score judges the rebuttal (*Whether a finding holds*).
- **Deferred.** It is left for later and stated on the pull request: the issue that takes it, or
  the gap stated in a line ([`pr-body-guide.md`](../pr-body-guide.md) > *한계와 known gaps*). A known
  gap worth fixing becomes an issue.
- **Separated.** Not directly related — none of question 1's three conditions of
  [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment* holds —, it is separated with its ground and a separate issue as the follow-up path.
- **A criterion defect is decided.** A recommendation that records an acceptance criterion
  defective — the evaluator records one as a fact, the criterion as its subject
  ([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format) — or one whose fix
  could keep a criterion's letter only by adding a rule the criterion did not state
  ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), is neither
  fixed, separated nor deferred as it stands: the module acting on it puts the change to the advisor,
  whose decision is recorded as `[ac-decision]` entries ([U3 Design](design.md) > *Report routing* >
  *An acceptance-criterion change shown later*).
- **A fact below the decision layer** ([U3 Design](design.md) > *Output artifacts* item 1) that an
  evaluation of the analysis or the design records is not a defect of the artifact it scores; it is
  taken up where the build derives it, and judged with that work at GATE:QUALITY.

The AI acting on a recommendation puts it to the advisor, and follows the decision
([`role-contracts.md`](../role-contracts.md) > Advisor), when (a) the fix needs a contract or
acceptance-criterion change; (b) the fix direction is
ambiguous, or a directly related recommendation looks undesirable to fix in this change (question 2)
and would be left; (c) a re-score keeps the previous finding `remains` after its fix — the same
complaint answered twice — and the re-score's grounds do not settle the next fix.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) >
Documentation Policy). Its search terms:

```
git grep -n -i -E 'recommendation triage|recommendations triaged|deferred or separated|disposed of as a reviewer'
```

## Re-entry re-score

A quality run given the previous evaluation re-scores as
[`evaluation-system.md`](../evaluation-system.md) > *Evaluator conduct* > *Re-score* and
*Gate rubrics* > GATE:QUALITY > *Re-entry re-score* set: it states which items it scored afresh and
which it inherited, and what became of the previous evaluation's findings.

## Code comments in a target

A comment in a target's code that diverges from its code, or that carries what a comment does not
carry, never routes the cycle.

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never raises a review's verdict above `Low`
  (`<autoflow-root>/docs/review/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](../evaluation-system.md) > *Code comments in a target*). It is
  therefore never the cause of a low score on any item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity its impact sets, as any finding does.
- **Fix — a commit no module owns.** A comment surfaced by this evaluation's `recommendations`,
  the build report's `## Comment check` or a reviewer's finding is fixed by one commit that deletes
  comment lines or corrects their sentences and changes nothing else, and it ends there: no re-run, no re-score, and no review round. The commit still runs the lint chain over its staged files
  ([`core.md`](../core.md) > Commit Rules); one made after the delivery module's push is pushed, and
  CI is confirmed on the new head. A comment whose correct wording is uncertain is deleted, not
  rewritten (*Code comments* > *Changing commented code*). A fix that changes any line other than a
  comment, or that removes a defect of its own ground (above), is not this fix.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity of the behavior it
  changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged, and its
  fix is made like any other change.
- *Secondary (multi-repo):* a comment in a sub-repo is in that sub-repo's scope
  ([`core.md`](../core.md) > Cross-Project Boundary Rules); its fix is the same single commit, on
  the same terms, in that scope.
