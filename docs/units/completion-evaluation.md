# U5 Completion evaluation — GATE:QUALITY

> Unit document for U5. [`CLAUDE.md`](../../CLAUDE.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

GATE:QUALITY is functional unit U5 Completion evaluation
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). U5 has no unit agent: the
gate is the unit, and its work is the evaluator's. This file states the unit's four items (D2) and the
rules the orchestrator applies to the result — the FAIL routing, and, for every rubric-scored gate,
the triage of a PASS report's recommendations. The rubric the evaluator scores on is
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY.

- **Goal**: the change the cycle built, judged against the acceptance criteria, the design and the
  build's own records before it is delivered — complete, correct, verified, within the cycle's
  scope, and committed and documented as the rules ask.
- **Artifact contract**: the evaluation report in the shape
  [`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format defines — ten scores
  with their reasons, `fail_hypothesis`, `remedy_class` on every failed item, `refine_observations`,
  `recommendations`, and `rescore` on a re-entry — whose `scores` the orchestrator records verbatim
  as `phases.gate_quality`.
- **Verification**: the evaluator's independence — a fresh Evaluation AI (`autoflow-evaluator`,
  the model `bash scripts/spawn-policy/spawn-policy.sh model gate-quality` names) for every
  evaluation, never the author of what it scores, read-only
  ([`role-contracts.md`](../role-contracts.md) > Evaluation AI); the orchestrator's acceptance of its
  report, which rejects and re-spawns a report missing what the contract requires; and the hook,
  which computes PASS from the recorded scores before it admits `git push` / `gh pr create`.
  Beyond U5, CI and the review verify the delivered change (ADR-0025 D4).
- **Loop cap**: a FAIL re-enters by `remedy_class` (*FAIL routing* below), max 3× — the cap counts
  FAILs, not the distance re-entered; a recommendation attempt is not a FAIL and counts on its own
  window, max 7 (*Recommendation triage* below).
- **Result owed**: the report, returned as the spawn's report, with its scores recorded; on a PASS
  with no attempt open, the cycle moves to DELIVER.

**Evaluator**: a fresh-spawned Evaluation AI scores the change on the rubric of
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY — its input, its ten
items, its known blind-spot checks and its re-entry re-score. Its documents line names that document
alone.

## Verification result

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → block) → *Recommendation triage* (below) → DELIVER.
- **FAIL** → routed by `remedy_class` (below; max 3× — the cap counts FAILs, not the distance re-entered).

## Recommendation triage

A PASS report's `recommendations` are findings the evaluator recorded without scoring the item down.
They are triaged by **the procedure the
reviewer's findings already take** — HANDOFF's review-triage classification, the weighing of whether a finding holds, route, pause criteria, `Low`
judgment, ledger record and attempt cap — after the PASS of every rubric-scored gate
(GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY) and before the transition it opens.
The one thing added is the evaluator's output contract for `recommendations`
([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format): each item names its
subject — a `path:line` of the evaluated artifact at the evaluated commit, or a section of the evaluated artifact (a design document, the DIAGNOSE analysis report) — its severity in the reviewer's vocabulary, and — on `Medium` and above — its `remedy_class`.
No separate disposition system exists for gate recommendations.

| Review triage | Gate recommendation |
|---|---|
| Classification: the reviewer's severity level (`.codex/review.md` > Severity) | the evaluator's, per item, on the same levels |
| `remedy_class` on every `Medium`+ finding, by the aggregator — *does clearing this discard or change a decision the design settled?* | the evaluator's, on every `Medium`+ recommendation, by the same question — the class it already puts on a failed item (*FAIL routing* below), and the same classifying authority |
| Route: `scripts/gate/remedy-route.sh route <class>...` | as a FAIL re-enters — to the phase that owns the change: at a gate after execution the same script; at a gate before execution the gate's own FAIL route (below) |
| Pause criteria (a)–(c) | the same three, read for a gate (below) |
| `Low`: the orchestrator's judgment — fix now, or defer with a one-line PR note | the same, its grounds the two questions of [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment*; a `Low` fixed now is an attempt like a `Medium`+, and a below-layer `Low` at a gate before execution is deferred to BUILD (below) |
| Verification of the fix: the next review round (*Reviewer review*) | the recommending gate's existing narrowed re-score (*Re-entry re-score*; [`evaluation-system.md`](../evaluation-system.md) > GATE:PLAN > *Re-entry re-score*, > AUDIT > *Review-response re-score*; at GATE:HYPOTHESIS the same form over the amended artifact) |
| Record: a `[review-autofix]` ledger entry per attempt; cap 7 | a `[gate-autofix]` ledger entry per attempt, in the same grammar; cap 7 on its own window |

- **No aggregator.** The orchestrator reads the evaluator's `recommendations` list
  directly. It is therefore the orchestrator that weighs whether each item holds ([U6 Delivery](delivery.md) > *Whether a
  finding holds*), and the recommending gate's re-score that judges a rebuttal. A
  `Medium`+ item with no `remedy_class`, or any item missing a field of that contract (subject, item,
  severity, finding), is a report defect:
  reject and re-spawn the evaluator, as for a missing `fail_hypothesis`.
- **A criterion defect goes to the advisor, at any severity.** A recommendation that records an
  acceptance criterion defective — the evaluator records one as a fact, the criterion as its subject
  ([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format) — or one whose fix
  could keep a criterion's letter only by adding a rule the criterion did not state
  ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), is neither
  routed, separated nor deferred as a `Low`: it is put to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor) and the
  answer recorded as its `[ac-decision]` entries ([U3 Design](design.md) > *Report routing* > *An acceptance-criterion change raised
  later in the cycle*).
- **`Medium` and above → do not transition.** Route as a FAIL re-enters — to the phase that owns
  the change:
  - **A gate after execution** — AUDIT and GATE:QUALITY — routes by `scripts/gate/remedy-route.sh
    route` over the `Medium`+ recommendations' classes (mixed → farthest; `operator` anywhere stops routing and goes to the advisor)
    and re-enters where it prints (`DOC_COMMIT` / `BUILD` / `ARCHITECT`, exactly as at
    *FAIL routing*, the `doc` route's sweep record included); the routed work flows forward, and the
    recommending gate re-scores on the narrowed input its re-entry already uses.
  - **A gate before execution** — GATE:HYPOTHESIS and GATE:PLAN — does not call the script: every `Medium`+ recommendation is resolved on the artifact the gate scores,
    by the gate's own FAIL route narrowed to the item, and re-scored by the same form: at GATE:PLAN an ARCHITECT unit re-run naming the
    recommendation ([U3 Design](design.md) > *Re-entry*), then GATE:PLAN's *Re-entry re-score* ([`evaluation-system.md`](../evaluation-system.md) > GATE:PLAN) over the
    delta; at GATE:HYPOTHESIS a U2 unit re-run naming the recommendation amends the analysis
    report ([U2 Analysis](analysis.md) > *Re-entry*) — a problem the confirmed cause carries enters its
    `## Scope judgments` — then the same form re-scores. The class such a recommendation carries (`doc` / `test` / `impl` / `design`) names the
    change the problem will need once the design or analysis carries it; it rides on the amended
    artifact as the ground ARCHITECT or BUILD then reads, and it never sends the cycle forward
    past the gate unre-scored. A fact below the decision layer ([U3 Design](design.md) > *Output artifacts*
    item 1) is not a defect of the artifact these gates score, so the evaluator records it at `Low`, and the orchestrator's `Low` judgment **defers**
    it: to the build — recorded in the gate's verdict entry as deferred to BUILD, carried
    in the BUILD spawn prompt, and judged with that work at GATE:QUALITY — or to the known-gaps
    line. It is never a fix-now attempt: it takes no re-score by this gate, no `[gate-autofix]` entry
    and no `remedy_class` in state.
  - **Not directly related** — none of question 1's three conditions holds — is separated as *Scope
    judgment*'s table says, recorded with its ground and a separate issue the follow-up path. A
    `Medium`+ recommendation that **is** directly related is fixed on its route or put to the
    advisor; the orchestrator never separates one on its own judgment (advisor criterion (b)).
- **Put to the advisor** (a request written situation-first — [`role-contracts.md`](../role-contracts.md) > Advisor; the cycle does not
  pause) when the attempt hits any of: (a) the fix needs a contract /
  acceptance-criterion change — recorded as the advisor's `[ac-decision]` entry
  ([U3 Design](design.md) > *Report routing* > *An acceptance-criterion change raised later in the cycle*);
  (b) the fix direction is ambiguous, or the orchestrator judges a directly related recommendation
  undesirable to fix in this cycle (question 2) and would separate it; (c) the re-score
  dispositions the previous attempt's finding `remains` after its fix (`rescore.prior_findings`)
  — the same complaint answered twice. The advisor's `A` entry
  selects re-entry; the operator may override it at the retry stage.
- **`Low`** → the orchestrator's judgment, on the two questions, recorded with its grounds in the
  gate's verdict entry: fix now, or defer — to the PR body's known-gaps line
  ([`pr-body-guide.md`](../pr-body-guide.md) > *한계와 known gaps*), or, for a `Low` below the decision
  layer at a gate before execution, to the build at BUILD (above). A `Low`
  fixed now **enters the procedure above as an attempt from that point**: the orchestrator judges
  its `remedy_class` (the evaluator tags none on a `Low`), and the fix is routed, recorded as a
  `[gate-autofix]` entry, marked in `phases.<gate>.remedy_class`, re-scored by the same gate and
  counted on the same window exactly as a `Medium`+ attempt. A `Low` on a target
  comment's divergence or disallowed content keeps its own handling — the orchestrator's direct
  commit, or left (*Code comments in a target* below).
- **Record.** Each attempt — a `Medium`+ recommendation, or a `Low` the orchestrator fixes now: a route that re-enters a phase and awaits the gate's re-score — is one ledger entry headed
  `## O<n> — <title> (cycle <C>, <GATE>) [gate-autofix]`, naming each recommendation it routes
  (subject, severity, class), the route, and the grounds — appended before the routed work starts.
  The marker sits at the end of the heading like `[review-autofix]`, and the two are distinct:
  neither cap's count reads the other's marker. While an attempt is open the orchestrator records
  the routed class as `phases.<gate>.remedy_class` in the state file, as it does for a FAIL
  ([`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking > *Remedy class recording*), and removes it
  once the re-score PASSes and no attempt is left open — a `Medium`+ the re-score itself raises is a
  new attempt; the hook denies `git push` / `gh pr create` while it is present on `audit` or
  `gate_quality`.
  A resume reads the same field ([U1 Preparation](preparation.md) > *Resume*).
- **Attempt cap = 7**: the consecutive `[gate-autofix]` entries this cycle since the last user
  re-entry decision (an entry whose heading ends in `[reentry-decision]`). When the triage after the 7th such attempt would open
  another — a `Medium`+ still open, or a `Low` the orchestrator would fix now — it pauses for the
  user instead; the user's decision resets the window. A re-score's own recommendations enter this
  triage on the same window, so a run of `Low`-only re-scores each fixed now counts like a run of
  `Medium`+ fixes. The cap bounds attempts, and reaching it is
  never a separation reason — the disposition at the cap is the operator's.
- **Not a FAIL.** An attempt consumes no FAIL cap; a re-score that FAILs is an ordinary FAIL, routed
  and counted by the gate's own rule, and a route through ARCHITECT consumes the ARCHITECT re-entry
  counter. The transition opens when the PASS stands and no attempt is open — every `Medium`+
  fixed and re-scored clean, withdrawn by the re-score on its rebuttal, separated as not directly
  related, or decided by the advisor or the operator, and any
  `Low` fixed now re-scored.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) >
Documentation Policy). Its search terms:

```
git grep -n -i -E 'recommendation triage|recommendations triaged|recommendation attempt|gate-autofix|attempt (is left )?open|no attempt|fixed now|fix-now|fix now|open re-entry|reviewer-finding procedure|recommendations.{0,40}(Medium|remedy_class)'
```

## FAIL routing (`remedy_class`)

The evaluator tags **every failed item** (score < 7) with a
`remedy_class` — the kind of change that clears it — and the orchestrator re-enters the cycle at the
nearest phase that can make that change. The evaluator is the classifying authority: the BUILD unit does not
re-classify.

| `remedy_class` | Meaning | Re-entry |
|---|---|---|
| `doc` | the item clears by editing documentation with no behavior change — in this repository comment text too; a target comment's divergence or disallowed content is never a failed item, while a defect a comment carries on its own ground is classed like any other (*Code comments in a target* below) | orchestrator doc commit → the local run the doc diff requires → GATE:QUALITY re-score |
| `test` | the item clears by changing test assets | a BUILD unit re-run with the failed items → AUDIT ([U4 Build and verify](build.md) > *Re-entry*) |
| `impl` | the item clears by changing implementation | the same BUILD re-run |
| `design` | the item clears only by revisiting the agreed design | ARCHITECT (consumes the ARCHITECT re-entry counter, as the BUILD design-contradiction row does) |
| `operator` | the evaluator cannot classify with confidence | the advisor's answer fixes the class ([`role-contracts.md`](../role-contracts.md) > Advisor); the cycle re-enters on that class's route |

- **Default class per item** — the evaluator's starting point, overridable with a stated reason:
  `Doc updates` → `doc`; `Test coverage`, `Test quality` → `test`; `Fit` → `design`; every other
  item → `impl` (`scripts/gate/remedy-route.sh default-class <item>`). A `Doc updates` cap caused
  by text that executes — a prompt string inside a workflow script, a hook message — is `impl`, not
  `doc`. When the evaluator is not confident, it writes `operator` rather than guessing: an
  unclassifiable item is never carried along a route chosen for its neighbours.
- **Mixed classes go to the farthest point**: `design` > `impl` > `test` > `doc`; `operator` anywhere
  stops routing and goes to the advisor. `scripts/gate/remedy-route.sh route <class>...` is the single owner of this rule; the
  orchestrator records the routed class as `phases.gate_quality.remedy_class` in the state file
  ([`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking > Remedy class recording).
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: reject
  it and re-spawn a fresh Evaluation AI, exactly as for a missing `fail_hypothesis`
  ([`evaluation-system.md`](../evaluation-system.md) > *Remedy class*).

### `doc` re-entry — class-level remedy

The `doc` route's remedy must be **class-level, not site-level**. The fix anchors on a **repo-wide sweep
for the pattern the evaluator named**, not on the list of sites it happened to find. The sweep
enumerates; **which hits the remedy fixes is the orchestrator's judgment**, recorded with its grounds
in the sweep record (`CLAUDE.md` > Rule Scope, principle 2).

1. Write `.autoflow/{repo-key}-issue-{N}/issue-{N}-remedy-sweep.md` with two sections: `## Command` — the repo-wide
   command(s) that enumerate the pattern — and `## Output` — their output, the full hit list. The
   remedy fixes every hit in a normative document ([`evaluation-system.md`](../evaluation-system.md) > GATE:QUALITY > *Known blind-spot checks* > reference integrity —
   the one definition of the boundary) and records, beside the two sections, the scope judgment for
   the rest: a hit in a historical record is fixed only where the evaluator's recorded judgment
   named it as misleading, and is otherwise recorded as exempt with the ground (the record is
   followed by no one). The judgment and its grounds are
   prose in the same file; the hook reads only the two sections.
2. Commit the doc remedy (orchestrator authority: [`CLAUDE.md`](../../CLAUDE.md) > Team Structure /
   Commit Ownership); its lint outcome is added as that commit's rows in the build report's `## Lint`
   table ([U4 Build and verify](build.md) > Build report).
   **The hook denies `git commit` while `remedy_class` is `doc` until the sweep
   record exists with both sections non-empty** — it checks the record file, never the wording of an
   instruction. On a second `doc` FAIL of the same class, the orchestrator re-examines its scope
   judgment against the grounds the new report records — the previously flagged defect that
   `rescore.prior_findings` marks `remains`, or a new finding it marks blocking — and records the
   revised judgment in the sweep record; a wider predicate is one possible outcome, not a rule.
   No standing doc-phrase suite is kept.
3. Run, once, the tests the doc diff requires ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *Local
   verification*) — often none for a doc-only diff; on an opted-in target the selector names any
   suite whose `ci-subject` reaches an edited doc — and record the command and its summary line,
   with the log the run wrote.
4. Re-score (below).

## Re-entry re-score

After any class's re-entry, a fresh evaluator re-scores on the narrowed input
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:QUALITY > *Re-entry re-score*
defines; the state file still receives all ten scores, inherited ones copied verbatim from the cited
report.

## Code comments in a target

A comment in a target's code that diverges from its code, or that carries what a comment does not
carry, never routes the cycle.

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never counts toward the review verdict that keeps `blocked-by-review`
  (`.codex/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](../evaluation-system.md) > *Code comments in a target*). It is
  therefore never a failed item, never the cause of a FAIL on the average, carries no `remedy_class`, and is not a `doc` item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity and the route its impact sets, as any finding does.
- **Fix — the orchestrator's direct commit.** Whether a comment surfaced by this gate's
  `recommendations`, the build report's `## Comment check` or the reviewer's `Low` findings (HANDOFF
  review triage) is fixed is the orchestrator's judgment, recorded with its grounds in the ledger
  ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2). A fix is one orchestrator commit that
  deletes comment lines or corrects their sentences and changes nothing else, and it ends there: no
  sweep record, no re-entry, no re-score, and no review round. The commit still runs the lint chain over its staged files
  ([`CLAUDE.md`](../../CLAUDE.md) > Commit Rules); one made after HANDOFF's push is pushed, and the CI
  confirmation runs on the new head. A comment whose correct wording is uncertain is deleted, not
  rewritten (*Code comments* > *Changing commented code*). A fix that changes any line other than a
  comment, or that removes a defect of its own ground (above), is not this route.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity and the route of the
  behavior it changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged, the
  `doc` class, and the `doc` re-entry's sweep record.
- *Secondary (multi-repo):* a comment in a sub-repo is outside the orchestrator's scope
  ([`CLAUDE.md`](../../CLAUDE.md) > Cross-Project Boundary Rules); the build unit of that scope makes
  the same single commit on the same terms.
