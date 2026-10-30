# U3 Design — ARCHITECT and GATE:PLAN

> The procedure of the design module, and the spawn of the plan module. [`core.md`](../core.md) > Module procedures routes to
> this file; the other modules are listed in [`autoflow-guide.md`](../autoflow-guide.md) >
> Modules.

U3 Design is two modules: the design module, whose contract is
`<autoflow-root>/docs/contracts/design.json` and whose procedure is this file, and the plan evaluation
module that scores its two documents (`<autoflow-root>/docs/contracts/plan.json`,
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:PLAN;
[`ADR-0038`](../records/adr/0038-contract-modules-with-no-state-file.md) D1). This file states the
design's goal, what its documents owe, the cautions it is asked to heed and the result it owes. How
the module reaches the goal — what else it reads, whether it spawns helpers, whether it asks a critic
to challenge a draft or holds a dialogue at all, how it designs this issue's own verification — is
its own, recorded with its grounds in its documents ([`core.md`](../core.md) > Rule Scope,
principle 2).

- **Goal**: a design the build module can implement and verify — the architecture decisions with
  the constraints they hold under and the alternatives rejected, and a verification design that
  says how each acceptance criterion is verified and which failure each verification catches.
- **Output**: the two documents under *Output artifacts* below, and the run's tool requests
  ([`core.md`](../core.md) > Development Lifecycle > *Tools*).
- **Default**: nothing beyond its outputs ([`core.md`](../core.md) > Development Lifecycle >
  *Inputs, outputs and default*).
- **Evaluation**: the plan module — a fresh Evaluation AI scores the two documents on the rubric of
  [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:PLAN; the module never
  scores its own documents (*Evaluation — GATE:PLAN* below).
- **Result owed**: the two artifact paths and a one-line summary
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format).

## Unit spawn

- **The spawn.** One `autoflow-unit-design` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-design` names) runs the
  module. Its prompt states the goal and names the inputs the invocation gives by path — the applied
  acceptance criteria (criteria-apply's output), the analysis report, its hypothesis evaluation, the
  decision ledger — its `[ac-decision]` entries and the advisor's other decisions —, the target's documents the design needs
  (e.g. the relevant `docs/records/adr/*`, `docs/records/design-rationale.md`) — the attempt's record
  directory, and the output directory the two documents go to.
- **A re-run** is known by the previous documents being given, with the material it answers: the
  plan evaluation, the build's green-blocker record, or the findings — a quality evaluation's, or a
  review's that moves a decision the design settled (*Re-entry* below).
- **Documents.** The unit's agent definition carries this file and the rubric it is scored on with
  the rest of its guidance ([`core.md`](../core.md) > Context Injection), and the module reads
  anything further its design needs, by its own judgment.

## Output artifacts

1. **Feature Design Document** — `<out>/feature-design.md`, the **architecture decision layer** and
   nothing below it: the decisions, the constraints they hold under, and the alternatives considered
   and rejected with the ground for each rejection. It cites the verification design for what each
   verification exists to catch, rather than restating it.

   The document states the scope beyond the acceptance criteria: each problem judged under
   [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
   judgment* — the analysis's scope judgments and any the design found — included or separated,
   with the conditions it meets and, for a directly related problem left out, its separation
   reason; each item the design includes is named, so the verification design disposes of it as of
   a criterion. Scope is a decision, settled here, not derived below.

   It also states each decision the design put to the advisor (*Report routing* below) — the
   ledger entry's identifier, the decision, and how the documents follow it: an
   **acceptance-criterion content change** ([`decision-ledger.md`](../decision-ledger.md) >
   *Acceptance-criterion decisions*), or a **design point** the module cannot settle on the grounds
   at hand, or doubts ([`core.md`](../core.md) > Development Lifecycle > *Decisions within a module*).

   **[DENY]** The document does not carry a change table of files, a per-suite disposition, or an
   oracle's condition clause. Those are **derived at BUILD** by the build unit — from
   the change delta, run the way the target runs its tests ([`submodule-common-rules.md`](../submodule-common-rules.md) >
   Verification and Tools > *How a test is run is the target's practice*; on an opted-in target the selector
   answers which committed suites the delta reaches), and from the files the build opens to change anyway. The dividing line is one question: **would this
   sentence being wrong mean the design has to be revisited, or would it just be fixed where it is
   found?** The first belongs to the design; the second does not. A derivation BUILD produces
   under this clause is not acceptance-criterion drift — GATE:QUALITY's Completeness check states
   that exemption explicitly.

2. **Verification Design Document** — `<out>/verification-design.md`. Every item the work owes —
   each applied acceptance criterion, by its id, and each item the feature design includes — is
   disposed of: how it is verified and what that verification catches, or why it is not verified.
   Its form and its words are the module's. An item verified by anything other than an executable
   test says how it is verified instead, and why. The per-criterion disposition is a design output;
   what the layer split above removes from it is depth, not items — each names the kind of oracle it
   gets, and the condition clause that implements it is BUILD's. Its readers: GATE:PLAN's
   `Verification fit` reads each disposition against its item, the build verifies each and reports
   each item's outcome, and the pull request carries each item not verified by an executable test
   with its reason
   ([U6 Delivery](delivery.md) > *Push and pull request*).

- For an item that is hard to verify: first find the tool that verifies it directly (*Tools*
  below); only when none can be secured, state the reason and the alternative — a design change, an
  observation by a person, a mock. When an item cannot be automated, consider first whether a
  feature-design change makes it verifiable.
- Design-change request: parts of the feature design that should be revised so they become
  verifiable.

### Test necessity

A test exists only when it is needed. The burden of proof lies on the test, never on its absence:
not writing a test needs no justification, and a proposed test that cannot answer both judgments
below is not written. This clause decides **existence** only — whether an item is verified at all
and by what; where a test file lives is [U4 Build and verify](build.md) > *What the build owes* >
*Where a test lives*. This clause is the policy body; every other document references it rather than
restating it.

- **[MUST]** Each proposed verification answers two judgments:
  1. **Required behavior** — is this a behavior or contract a consumer actually requires, as
     opposed to an imagined failure mode?
  2. **Cost of absence** — if no verification exists and this breaks after merge, who loses what,
     concretely?
- **[MUST]** When the two judgments cannot both be answered, no verification is proposed, and the
  item's row says why its absence costs nothing.
- Necessity is a **judgment**, not a classification: no subject is exempt by category and none is
  obligated by category. The two guidance notes below are that judgment applied to two areas —
  they are not separate rules.

**Configuration and data.** A value is not a required behavior; the behavior that consumes it is.
Whether
"production config boots the app" or "every reference resolves" deserves a test is decided by the
two judgments above, not by the subject being data.

**Implementation internals.** A helper name, call order, private branch or internal representation
is not a required behavior. Production code gains no interface, indirection or dependency injection solely to fit
a test shape.

### Verification depth

- **[MUST]** The verification design opens with a **risk line** — one line naming
  who is harmed and how if this change is wrong. Depth is justified against that risk — never by a
  quantity cap: no layer count, file count, or line budget.
- Each verification catches a failure no other verification in the design, and no existing
  mechanism — an existing test, a lint rule, a schema, a compiler or type check, a build or
  packaging check — already catches. A verification that would catch nothing such a mechanism does
  not is left out, and the mechanism is named in its place. A risk found later raises depth on a
  re-run, its reason stated in the delta (*Re-entry* below).

### Tools

The rule is [`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools the work needs*;
this clause is where the verification design applies it. The design opens the materials
the analysis report's `## Referenced materials` section lists ([U2 Analysis](analysis.md) >
*What the analysis owes*) — the material, not the issue body's abbreviated example, is the
design's input — and finds, for each item, the tool that verifies it directly **before**
settling it on an observation by a person, on an environment it cannot drive, or on a mock.

- A tool the design's verification needs and this environment does not provide — or what using a
  tool the environment has lacks — is recorded as a tool request: what is missing, and the
  verification the design chose instead, with its reason in the item's row. The design goes on to
  its end; whether to provide the tool is the operator's, from the pull request
  ([`core.md`](../core.md) > Development Lifecycle > *Tools*). AutoFlow names no tool here: which
  tool, and how it is used, is the design's judgment in the target.
- The row verified with a tool is looked at with it once implemented, and the evidence is the row's
  observation record, written at BUILD ([U4 Build and verify](build.md) > Build report).

## Report routing

The decisions the design puts to the advisor, and what it does with the advisor's decision
([`role-contracts.md`](../role-contracts.md) > Advisor). The feature design states each (*Output artifacts* above).

- **An acceptance-criterion content change.** Excluding, revising or splitting an issue
  acceptance criterion, or adding one, is never the design's to apply: the design puts the change to
  the advisor, whose decision is recorded as `[ac-decision]` entries — one per decided criterion,
  carrying the criterion's text, in the grammar at [`decision-ledger.md`](../decision-ledger.md) >
  *Acceptance-criterion decisions* —, and the design's documents follow the decision. criteria-apply
  computes the applied criteria from the entries for every module after the design.
- **A design point** the design cannot settle on the grounds at hand, or doubts. The design puts it
  to the advisor, and its documents follow the decision.
- **An acceptance-criterion change shown later.** The build module, when its work shows a criterion
  defective — a fact it presumes that does not hold, or a scope too narrow or too wide for the problem
  ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*) — puts the change
  to the advisor and follows the decision ([U4 Build and verify](build.md) > *What the build owes*);
  a module that takes an evaluation recommendation recording a criterion defect does the same
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*). The decision is
  recorded as above.

**What the advisor is asked, and what it is not.** A reduction in *verification method* — an item
verified by an existing mechanism, an observation, a delivery check, or by nothing at all — is a
verification-method choice, not a change to the criterion. It passes three tiers, and only the third
changes the criterion:

1. **Design.** The design module chooses how each item is verified, **with its reason stated in
   that row**; GATE:PLAN scores the reason.
2. **Reviewer (REVIEW).** Every reduced disposition and its reason is carried into the host
   PR body ([U6 Delivery](delivery.md) > *Push and pull request*), so the reviewer judges each one on its stated reason.
3. **Criterion decision.** When the criterion's **content** must change — at the design or later
   (*An acceptance-criterion change shown later* above) — the decision is an
   `[ac-decision]` entry. The options are exactly these: exclude the criterion, revise it in the
   proposed form, split it into a separate issue, or add a criterion the issue did not state.

Whether a row verifies the property its item states is not a tier-3 question — that judgment belongs
to GATE:PLAN `Verification fit` and to GATE:QUALITY's assertion-claim alignment.

## Evaluation — GATE:PLAN

The plan module scores the two documents: one fresh Evaluation AI (`autoflow-evaluator`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-plan` names), on the rubric of
[`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:PLAN. Its agent definition
carries that document, and its output is the scores and their grounds with its recommendations.

## Re-entry

A re-run is a fresh `autoflow-unit-design` spawn by *Unit spawn* above, given the previous
documents and the material it answers.

- **[MUST] A re-run's output is a delta, never a rewrite.** The first run writes the two documents
  whole. A re-run **appends** to each document it changes a section

  ```
  ## Delta — round <n>

  - <what changed>: <the decision as it now stands> — supersedes <the section or decision it replaces>
  - <what was added>: <the decision> — <ground>
  ```

  — `n` the number of delta sections in the previous document plus one, what the round is for
  stated in the module's own words from its inputs — and leaves text the round did not change
  exactly as it stands. A delta item that corrects a decision under the verified-error exception
  ([`decision-ledger.md`](../decision-ledger.md) > Entries) also carries the reproducing command and
  its summary line; a decision the round put to the advisor is a delta item that names its ledger
  entry. The delta section is GATE:PLAN's narrowed input on a re-score ([`evaluation-system.md`](../evaluation-system.md) >
  GATE:PLAN > *Re-entry re-score*).
- **Earlier runs are in the record directory.** The documents of every earlier run stay in their
  own run directories; how much of an earlier design the run carries over is its own, recorded in
  the design.
