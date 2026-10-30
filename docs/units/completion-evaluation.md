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
- **Default**: nothing beyond its outputs ([`core.md`](../core.md) > Development Lifecycle >
  *Inputs, outputs and default*).
- **Independence**: a fresh Evaluation AI (`autoflow-evaluator`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-quality` names) for every
  run, never the author of what it scores, read-only
  ([`role-contracts.md`](../role-contracts.md) > Evaluation AI); check-out confirms the output's
  form. Beyond it, CI and the review verify the delivered change.
- **Result owed**: the evaluation file and a summary.

**Evaluator**: a fresh-spawned Evaluation AI scores the change on the rubric of
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY. Its agent
definition carries that document.

## Re-entry re-score

A quality run given the previous evaluation re-scores as
[`evaluation-system.md`](../evaluation-system.md) > *Evaluator conduct* > *Re-score* and
*Gate rubrics* > GATE:QUALITY > *Re-entry re-score* set: every item scored afresh or inherited, and
every previous finding dispositioned.

## Code comments in a target

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never raises a review's verdict above `Low`
  (`<autoflow-root>/docs/review/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](../evaluation-system.md) > *Code comments in a target*). It is
  therefore never the cause of a low score on any item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity its impact sets, as any finding does.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity of the behavior it
  changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged.
- *Secondary (multi-repo):* a comment in a sub-repo is in that sub-repo's scope
  ([`core.md`](../core.md) > Cross-Project Boundary Rules); its fix is the same single commit, on
  the same terms, in that scope.
