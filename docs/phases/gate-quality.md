# GATE:QUALITY — Completion Evaluation

> Phase playbook for GATE:QUALITY. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: full change set + test results + AUDIT result, plus the issue's acceptance-criterion list
(`.autoflow/issue-{N}-phase-b.md` > `## Acceptance criteria`), the verification design,
the issue decision ledger (`.autoflow/issue-{N}-ledger.md`), and the REFINE report
(`.autoflow/issue-{N}-refine-report.md`, section `## Out-of-scope observations — guard / boundary
logic touched`, and — on a target — section `## Comment check`), and the cycle's scope records —
the feature design's `## Scope` section, every `## Scope judgments` section in the cycle's
`.autoflow/issue-{N}-*.md` reports, and the `[gate-autofix]` ledger entries and gate verdict entries that
record how earlier gates' recommendations were triaged
([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment*).

**[MUST] REFINE observations are scoring input**: the evaluator reads the REFINE
report's out-of-scope-observations section, dispositions every entry (`defect — scored` /
`not a defect — reason`), and records the dispositions in the `refine_observations` output field
([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format). An entry dispositioned
`defect` is scored under `Quality` or `Impact scope` like any other finding. An absent
`refine_observations` field, or one that does not account for every entry in the section, is a
report defect: reject and re-spawn, as for a missing `fail_hypothesis`.

## Scoring (10 items × 10 points)

Completeness, Quality, Test coverage, Test quality, Security (references AUDIT),
Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates.

The `Minimal implementation` item is scored against [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > GATE:QUALITY linkage, which holds the criterion body and the positive criteria the item is scored by.
Guiding rule: prefer the smallest sufficient change that resolves the confirmed problem within the cycle's scope — the acceptance criteria, the confirmed cause, and the problems the cycle's recorded scope judgments include.
A hunk tracing to none of them fails this item regardless of code quality, and so does a change too narrow to resolve the confirmed cause.
`Impact scope` is scored against the same section and the same scope from the other side: a directly related problem the cycle's records show, left out with no recorded separation reason, lowers it.
On a target the item also weighs the comments the change adds, by content and by volume — the volume judged qualitatively from the REFINE report's `comment-ratio` and the diff, with no threshold — and records what it finds in its `reason` and `recommendations` without lowering its score (the same linkage section, *Comments in a target's code*; *Code comments in a target* below).

## Known blind-spot checks (scored within existing items)

The evaluator applies the checks below **inside the existing 10 items** — they add no scored items and change no
PASS threshold. Each violation caps the named item at 6, which fails the gate via the
each-item ≥ 7 criterion:

- **Test quality — mock-boundary fidelity**: sample the suite's test doubles and verify
  each against the real interface at HEAD (signature, argument count, return shape).
  A double that diverges from the real interface caps `Test quality` at 6.
- **Test quality / Completeness — assertion-claim alignment**: for each AC, confirm the
  test asserts the behavior the AC states, not a weaker proxy (e.g. "the function was
  called" where the AC requires a result shape) and not a different property than the
  one the AC it names states. Confirm every cited evidence line
  (test summary, log excerpt) against the log the cited run left, read at the cited path —
  never by re-running the command; a recorded line the log does not carry was authored, not
  produced by a run, and caps the citing item at 6. A record with no log behind it is not a
  fabricated line but a missing run: it takes the `Test coverage` omission path below, not this
  cap ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *A run's evidence is the log it left*). For an
  observation record, confirm that the result was compared against the material the AC names — the
  referenced mockup, asset or document itself; a comparison against the issue body's abbreviated
  example, or a check that the result merely renders, is a weaker proxy.
- **Impact scope / Doc updates — reference integrity on moves**: when the diff relocates
  or renames files, sections, or identifiers, require evidence of a repo-wide
  inbound-reference sweep (direct references, test-harness expectations, paraphrased
  mentions). A dangling reference in a **normative document** caps the affected item at 6.
  The cap binds normative documents only; a stale name in a **historical record** is the
  evaluator's judgment.
  - *Normative documents* — the one definition, cited from everywhere else — are what an agent
    or the operator reads and follows in a phase, what executes, and what is delivered: (a) the
    rules, playbooks, role contracts, evaluation criteria and agent definitions a phase loads
    (`CLAUDE.md`, `docs/autoflow-guide.md`, `docs/phases/*`, `docs/role-contracts.md`,
    `docs/role-common-rules.md`, `docs/submodule-common-rules.md`, `docs/evaluation-system.md`,
    `.claude/agents/*`, and the sections of an ADR that state a decision still in force);
    (b) the scripts, hooks and workflows that run; (c) every document delivered to a target — the
    boundary of (c) is the manifest generator's markdown-link closure of `CLAUDE.md` +
    `docs/INDEX.md` plus its other artifact rows (`setup/gen-manifest-hashes.sh` >
    `compute_doc_closure`).
  - *Historical records* are what is kept as a record of a past state and followed by no one:
    per-issue manual-verification records, report-excerpt fixtures
    (`tests/fixtures/*`), an ADR's change-history and superseded sections, and archived cycle
    artifacts. A fixture that an executing test reads is still a historical record for this check,
    while the test that reads it is normative.
  - For a stale name in a historical record the evaluator judges whether a reader following the
    normative documents would be misled by it, and records the judgment with its grounds in the
    item's `reason` (and in `recommendations` when it does not lower the score). A score reduction
    rests on that recorded ground alone, never on the name's presence; a record whose stale names
    mislead no one is left as it is, and rewriting it is not a remedy the evaluator asks for.
- **Test quality — layer violation** (**this repository only**): for each
  verification-design row, the asset matches the layer its `Type` cell declares — a `cycle` row
  (no `standing:` token) has no committed test file; a `standing` row has its committed file,
  CI-registered; and every `standing:` token is one of ADR-0024 D1's closed list. A committed asset
  on a `cycle` row, an uncommitted asset on a `standing` row, or a token outside the list caps
  `Test quality` at 6. The token check is a set relation, not a judgment, and it is performed
  **by the device**: the evaluator runs
  `bash scripts/gate/verification-layer-check.sh .autoflow/issue-{N}-verification-design.md` and
  attaches its output — a non-zero exit is a token outside D1's closed list and caps the item; the
  device's second output, the row↔asset pairing report, is input to this check and to
  `Test coverage`, never a verdict. The device is not delivered to targets and the check does not
  run there: on a target, a test file the cycle added is judged by the reviewer against the target's
  convention from the PR body's listing (HANDOFF step 4), not by a token ([`submodule-common-rules.md`](../submodule-common-rules.md)
  > Verification and Tools > *What a cycle leaves in the target's tree*); under this item the evaluator confirms
  that every test file the cycle added to the target's tree carries, in the Test AI's RED report,
  the reason it is kept and the CI job expected to run it — the record HANDOFF step 4 copies into
  the PR body — and an added file with no such record caps
  `Test quality` at 6.
- **Test coverage — the run record is the subject**: the item's subject is not a CI result. For
  each `automated` / `delivery-check` row
  it is the row's recorded run — the command, the log and the summary line read from it, confirmed
  by reading the line at the cited log path rather than by re-running; in this repository a
  `standing` row's subject is additionally the committed asset's realisability — the file exists,
  runs, and is CI-registered. For a `manual` row executed by the AI it is the row's observation
  record (VERIFY step 1), confirmed by reading the record and opening the artifacts it cites — a
  screenshot is read as an image — never by observing again; a row with no record, or
  a record whose artifacts are absent, takes the omission path below.
  - **Execution omission is not a defect** ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *A missing run
    is filled where it is found*). A row with no run record — or with no log behind it — is `not-run`, and the evaluator does
    **not** score `Test coverage` over it: the report names each such row under `Test coverage` as
    `not-run: <rows>` and withholds that item's score. Such a report is not a verdict — it is not
    recorded in the state file, consumes no FAIL of the `max 3×` cap, and carries no `remedy_class`
    for the omission. The orchestrator has each named row run in place — a cycle-layer asset by its
    path (the orchestrator itself may run it), a test in the target's tree by the owning role the
    way the target runs its tests — and its record filled in, then spawns a fresh evaluator that
    re-scores `Test coverage` only, in the *Re-entry re-score* form below with the withheld report
    as the inheritance source. A recorded run that **fails** is a defect, scored and classed like
    any other.
- **Fit — ADR conformance**: on the final change set, re-confirm the shipped change conforms to any governing ADR (same
  governing-ADR / trigger-area / N/A definition as the GATE:PLAN ADR-conformance check; the
  trigger areas are `docs/development-guideline.md` > ADR Policy > *When to create an ADR*). A
  divergence from a governing ADR, or an architecture-impacting change with no governing
  ADR/owner decision, caps Fit at 6.
- **Completeness — AC-authority check**: the backstop for acceptance-criterion drift introduced **after** ARCHITECT — a VERIFY → RED test
  edit, or the satisfiable-subset GREEN implementation the GREEN playbook explicitly permits.
  The check is a **name-the-site obligation**, not the GATE:PLAN key join: for each
  verification-design row whose `Issue AC` is not `—`, the evaluator names the test file and
  assertion, or the implementation site, that discharges it. A row for which no
  site can be named, and which no `[ac-decision]`-marked ledger entry covers, caps `Completeness`
  at 6 (an `added` entry covers nothing: the criterion it adds is owed its row and its site).
  **Derivation is not drift**: a file row, suite disposition or oracle condition clause
  RED or GREEN derived under the ARCHITECT layer split ([ARCHITECT](architect.md) > *Output artifacts* item 1;
  [RED](red.md) > *Derivation on entry*) is the designed division of labour, never a post-ARCHITECT AC change.
  The check binds a verification-design row whose `Issue AC` is not `—` and for which no
  discharging site can be named.

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → block) → *Recommendation triage* (below) → DELIVER.
- **FAIL** → routed by `remedy_class` (below; max 3× — the cap counts FAILs, not the distance re-entered).

## Recommendation triage

A PASS report's `recommendations` are findings the evaluator recorded without scoring the item down.
They are triaged by **the procedure the
reviewer's findings already take** — HANDOFF step 6.5's classification, the weighing of whether a finding holds, route, pause criteria, `Low`
judgment, ledger record and attempt cap — after the PASS of every rubric-scored gate
(GATE:HYPOTHESIS in both forms, GATE:PLAN, AUDIT, GATE:QUALITY) and before the transition it opens.
The one thing added is the evaluator's output contract for `recommendations`
([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format): each item names its
subject — a `path:line` of the evaluated artifact at the evaluated commit, or a section of the evaluated artifact (a design document, a DIAGNOSE analysis file) — its severity in the reviewer's vocabulary, and — on `Medium` and above — its `remedy_class`.
No separate disposition system exists for gate recommendations.

| Step 6.5 | Gate recommendation |
|---|---|
| Classification: the reviewer's severity (`Critical` / `High` / `Medium` / `Low`, `Low Confidence`) | the evaluator's, per item, in the same vocabulary |
| `remedy_class` on every `Medium`+ finding, by the ingesting subagent — *does clearing this discard or change a decision the deliberation settled?* | the evaluator's, on every `Medium`+ recommendation, by the same question — the class it already puts on a failed item (*FAIL routing* below), and the same classifying authority |
| Route: `scripts/gate/remedy-route.sh route <class>...` | as a FAIL re-enters — to the phase that owns the change: at a gate after execution the same script; at a gate before execution the gate's own FAIL route (below) |
| Pause criteria (a)–(d) | the same four, read for a gate (below) |
| `Low`: the orchestrator's judgment — fix now, or defer with a one-line PR note | the same, its grounds the two questions of [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment*; a `Low` fixed now is an attempt like a `Medium`+, and a below-layer `Low` at a gate before execution is deferred to DISPATCH (below) |
| Verification of the fix: the reviewer re-review (step 6) | the recommending gate's existing narrowed re-score (*Re-entry re-score*; [GATE:PLAN](gate-plan.md) > *Re-entry re-score*; [AUDIT](audit.md) > *Review-response re-score*; at GATE:HYPOTHESIS the same form over the amended artifact) |
| Record: a `[review-autofix]` ledger entry per attempt; cap 7 | a `[gate-autofix]` ledger entry per attempt, in the same grammar; cap 7 on its own window |

- **No ingesting subagent.** The orchestrator reads the evaluator's `recommendations` list
  directly. It is therefore the orchestrator that weighs whether each item holds ([HANDOFF](handoff.md) step 6.5 > *Whether a
  finding holds*), and the recommending gate's re-score that judges a rebuttal. A
  `Medium`+ item with no `remedy_class`, or any item missing a field of that contract (subject, item,
  severity, finding), is a report defect:
  reject and re-spawn the evaluator, as for a missing `fail_hypothesis`.
- **A criterion defect goes to the operator, at any severity.** A recommendation that records an
  acceptance criterion defective — the evaluator records one as a fact, the criterion as its subject
  ([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format) — or one whose fix
  could keep a criterion's letter only by adding a rule the criterion did not state
  ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), is neither
  routed, separated nor deferred as a `Low`: it is put to the operator and the answer recorded as
  `[ac-decision]` entries ([ARCHITECT](architect.md) > *Report routing* > *An acceptance-criterion change raised
  later in the cycle*).
- **`Medium` and above → do not transition.** Route as a FAIL re-enters — to the phase that owns
  the change:
  - **A gate after execution** — AUDIT and GATE:QUALITY — routes by `scripts/gate/remedy-route.sh
    route` over the `Medium`+ recommendations' classes (mixed → farthest; `operator` anywhere pauses)
    and re-enters the phase it prints (`DOC_COMMIT` / `RED` / `GREEN` / `ARCHITECT`, exactly as at
    *FAIL routing*, the `doc` route's sweep record included); the routed work flows forward, and the
    recommending gate re-scores on the narrowed input its re-entry already uses.
  - **A gate before execution** — GATE:HYPOTHESIS and GATE:PLAN — does not call the script: every `Medium`+ recommendation is resolved on the artifact the gate scores,
    by the gate's own FAIL route narrowed to the item, and re-scored by the same form: at GATE:PLAN an ARCHITECT re-discussion on a `brief` naming the
    recommendation ([ARCHITECT](architect.md) > *Re-discussion*), then [GATE:PLAN](gate-plan.md)'s *Re-entry re-score* over the
    delta; at GATE:HYPOTHESIS the role that wrote the analysis it names amends that artifact — a
    problem the confirmed cause carries enters its `## Scope judgments` — then the same form
    re-scores. The class such a recommendation carries (`doc` / `test` / `impl` / `design`) names the
    change the problem will need once the design or analysis carries it; it rides on the amended
    artifact as the ground ARCHITECT or DISPATCH then reads, and it never sends the cycle forward
    past the gate unre-scored. A fact below the decision layer ([ARCHITECT](architect.md) > *Output artifacts*
    item 1) is not a defect of the artifact these gates score, so the evaluator records it at `Low`, and the orchestrator's `Low` judgment **defers**
    it: to the executing role — recorded in the gate's verdict entry as deferred to DISPATCH, carried
    in the RED / GREEN spawn prompt, and judged with that work at GATE:QUALITY — or to the known-gaps
    line. It is never a fix-now attempt: it takes no re-score by this gate, no `[gate-autofix]` entry
    and no `remedy_class` in state.
  - **Not directly related** — none of question 1's three conditions holds — is separated as *Scope
    judgment*'s table says, recorded with its ground and a separate issue the follow-up path. A
    `Medium`+ recommendation that **is** directly related is fixed on its route or paused for the
    operator; the orchestrator never separates one on its own judgment (pause criterion (b)).
- **Pause for the user** (`AskUserQuestion`, situation-first; `active:false`,
  `phase:"awaiting-user"`) when the attempt hits any of: (a) the fix needs a contract /
  acceptance-criterion change — recorded on the operator's answer as an `[ac-decision]` entry
  ([ARCHITECT](architect.md) > *Report routing* > *An acceptance-criterion change raised later in the cycle*);
  (b) the fix direction is ambiguous, or the orchestrator judges a directly related recommendation
  undesirable to fix in this cycle (question 2) and would separate it; (c) the item is
  `Low Confidence`; (d) the re-score dispositions the previous attempt's finding `remains` after its
  fix (`rescore.prior_findings`) — the same complaint answered twice. The user's answer is appended to the ledger and selects
  re-entry.
- **`Low`** → the orchestrator's judgment, on the two questions, recorded with its grounds in the
  gate's verdict entry: fix now, or defer — to the PR body's known-gaps line
  ([`pr-body-guide.md`](../pr-body-guide.md) > *한계와 known gaps*), or, for a `Low` below the decision
  layer at a gate before execution, to the executing role at DISPATCH (above). A `Low`
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
  The Resume procedure reads the same field ([PREFLIGHT](preflight.md) > *Resume procedure* step 3).
- **Attempt cap = 7**, counted as step 6.5 counts: the consecutive `[gate-autofix]` entries this
  cycle since the last user re-entry decision. When the triage after the 7th such attempt would open
  another — a `Medium`+ still open, or a `Low` the orchestrator would fix now — it pauses for the
  user instead; the user's decision resets the window. A re-score's own recommendations enter this
  triage on the same window, so a run of `Low`-only re-scores each fixed now counts like a run of
  `Medium`+ fixes. The cap bounds attempts, and reaching it is
  never a separation reason — the disposition at the cap is the operator's.
- **Not a FAIL.** An attempt consumes no FAIL cap; a re-score that FAILs is an ordinary FAIL, routed
  and counted by the gate's own rule, and a route through ARCHITECT consumes the ARCHITECT re-entry
  counter. The transition opens when the PASS stands and no attempt is open — every `Medium`+
  fixed and re-scored clean, withdrawn by the re-score on its rebuttal, separated as not directly
  related, or decided by the operator, and any
  `Low` fixed now re-scored.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) >
Documentation Policy). Its search terms:

```
git grep -n -i -E 'recommendation triage|recommendations triaged|recommendation attempt|gate-autofix|attempt (is left )?open|no attempt|fixed now|fix-now|fix now|open re-entry|reviewer-finding procedure|recommendations.{0,40}(Medium|remedy_class)'
```

## FAIL routing (`remedy_class`)

The evaluator tags **every failed item** (score < 7) with a
`remedy_class` — the kind of change that clears it — and the orchestrator re-enters the cycle at the
nearest phase that can make that change. The evaluator is the classifying authority: the Developer AI /
Test AI do not re-classify.

| `remedy_class` | Meaning | Re-entry |
|---|---|---|
| `doc` | the item clears by editing documentation with no behavior change — in this repository comment text too; a target comment's divergence or disallowed content is never a failed item, while a defect a comment carries on its own ground is classed like any other (*Code comments in a target* below) | orchestrator doc commit → the local run the doc diff requires → GATE:QUALITY re-score |
| `test` | the item clears by changing test assets | RED |
| `impl` | the item clears by changing implementation | GREEN → VERIFY step 1 → REFINE → VALIDATE |
| `design` | the item clears only by revisiting the agreed design | ARCHITECT (consumes the ARCHITECT re-entry counter, as the VERIFY design-contradiction row does) |
| `operator` | the evaluator cannot classify with confidence | report situation-first, `active:false`, `phase:"awaiting-user"`; the operator's answer fixes the class |

- **Default class per item** — the evaluator's starting point, overridable with a stated reason:
  `Doc updates` → `doc`; `Test coverage`, `Test quality` → `test`; `Fit` → `design`; every other
  item → `impl` (`scripts/gate/remedy-route.sh default-class <item>`). A `Doc updates` cap caused
  by text that executes — a prompt string inside a workflow script, a hook message — is `impl`, not
  `doc`. When the evaluator is not confident, it writes `operator` rather than guessing: an
  unclassifiable item is never carried along a route chosen for its neighbours.
- **Mixed classes go to the farthest point**: `design` > `impl` > `test` > `doc`; `operator` anywhere
  pauses. `scripts/gate/remedy-route.sh route <class>...` is the single owner of this rule; the
  orchestrator records the routed class as `phases.gate_quality.remedy_class` in the state file
  ([`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking > Remedy class recording).
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: reject
  it and re-spawn a fresh Evaluation AI, exactly as for a missing `fail_hypothesis`
  ([`role-contracts.md`](../role-contracts.md) > Evaluation AI > Remedy class).

### `doc` re-entry — class-level remedy

The `doc` route's remedy must be **class-level, not site-level**. The fix anchors on a **repo-wide sweep
for the pattern the evaluator named**, not on the list of sites it happened to find. The sweep
enumerates; **which hits the remedy fixes is the orchestrator's judgment**, recorded with its grounds
in the sweep record (`CLAUDE.md` > Rule Scope, principle 2).

1. Write `.autoflow/issue-{N}-remedy-sweep.md` with two sections: `## Command` — the repo-wide
   command(s) that enumerate the pattern — and `## Output` — their output, the full hit list. The
   remedy fixes every hit in a normative document (*Known blind-spot checks* > reference integrity —
   the one definition of the boundary) and records, beside the two sections, the scope judgment for
   the rest: a hit in a historical record is fixed only where the evaluator's recorded judgment
   named it as misleading, and is otherwise recorded as exempt with the ground (the record is
   followed by no one). The judgment and its grounds are
   prose in the same file; the hook reads only the two sections.
2. Commit the doc remedy (orchestrator authority: [`CLAUDE.md`](../../CLAUDE.md) > Team Structure /
   Commit Ownership). **The hook denies `git commit` while `remedy_class` is `doc` until the sweep
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

After any class's re-entry, GATE:QUALITY runs again as a **fresh spawn with a narrowed input**: it
re-scores the items that failed plus every previously-passing item whose anchor files the re-entry
diff touched; the remaining items inherit their prior score by citation. The report states the
re-scored item list and the inheritance source (the prior report's path) in its `rescore` field
([`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format). The state file still
receives all ten scores, inherited ones copied
verbatim from the cited report. An inherited item whose anchor file appears in the re-entry diff
and is missing from the re-scored list is a report defect: reject and re-spawn.

**The re-score's subject is the previously flagged defect**. The fresh evaluator's FAIL hypothesis
on a re-scored item is *"the flagged defect still remains"*, searched against the re-entry diff
([`role-contracts.md`](../role-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis >
*re-entry form*); each prior finding is dispositioned `cleared` / `remains` in
`rescore.prior_findings`. A defect the evaluator newly sees on a re-scored item — including one in
the sentences the remedy itself wrote — is recorded per *Finding coverage*, and the evaluator
judges whether it blocks: a blocking finding is scored under its item and listed in
`rescore.new_findings` with its ground; one that does not block goes to `recommendations` and does
not lower the item.

## Code comments in a target

A comment in a target's code that diverges from its code, or that carries what a comment does not
carry, never routes the cycle.

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. The reviewer never keeps or attaches `blocked-by-review` for it
  (`.codex/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`role-contracts.md`](../role-contracts.md) > Evaluation AI > *Code comments in a target*). It is
  therefore never a failed item, never the cause of a FAIL on the average, carries no `remedy_class`, and is not a `doc` item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity and the route its impact sets, as any finding does.
- **Fix — the orchestrator's direct commit.** Whether a comment surfaced by this gate's
  `recommendations`, the REFINE report's `## Comment check` or the reviewer's `Low` findings (HANDOFF
  step 6.5) is fixed is the orchestrator's judgment, recorded with its grounds in the ledger
  ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2). A fix is one orchestrator commit that
  deletes comment lines or corrects their sentences and changes nothing else, and it ends there: no
  sweep record, no re-entry, no re-score, and no reviewer re-review. The commit still runs the lint chain over its staged files
  ([`CLAUDE.md`](../../CLAUDE.md) > Commit Rules); one made after HANDOFF's push is pushed, and step 5
  confirms CI on the new head. A comment whose correct wording is uncertain is deleted, not
  rewritten (*Code comments* > *Changing commented code*). A fix that changes any line other than a
  comment, or that removes a defect of its own ground (above), is not this route.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity and the route of the
  behavior it changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged, the
  `doc` class, and the `doc` re-entry's sweep record.
- *Secondary (multi-repo):* a comment in a sub-repo is outside the orchestrator's scope
  ([`CLAUDE.md`](../../CLAUDE.md) > Cross-Project Boundary Rules); the Developer AI of that scope makes
  the same single commit on the same terms.
