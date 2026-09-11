# ADR-0024: Verification splits into a standing layer and a cycle layer; the target owns its test command

## Status

Proposed

## Context

A cycle's verification is executed **locally**, by AutoFlow's own runner, over AutoFlow's own suite
format. Three consequences follow, and they are the issue's three recorded problems
(`Munsik-Park/autoflow#217`).

**The local run performs CI's scope.** VALIDATE step 1 requires an unconditional whole-tree sweep
every cycle (`docs/autoflow-guide.md:1462`), and GREEN step 5, VERIFY step 1 and REFINE step 2 each
re-run the selected set at a capture point (`:949`, `:985`, `:1413-1416`). The same tree costs 89 s
in CI and 594 s locally (`scripts/test/suite-manifest.sh:50`). Issue #112 recorded that inversion;
the answers built since — local selection, suite-grained inheritance, the shared Green-tree register
and its input hash (ADR-0019, issues #121, #130, #134) — all reduced the *cost* of the local run
while leaving the *scope* where it was. Moving the floor to CI was explicitly left out of scope
at #130.

**AutoFlow imposes its test format on the target.** Every `*.sh` under `tests/**` must carry the
suite header contract; a target that has not migrated is BLOCKed at RED (issue #213) and, from
0.2.2, stopped at PREFLIGHT by drift-check D7 (`setup/thin-root-layer/drift-check.sh:481`). Lint
does not work this way: it follows the chain the target itself declares
(`docs/submodule-common-rules.md:181`), and a place for the target to declare its test command
already exists (`:99-101`).

**There is no distinction between one-shot delivery verification and regression verification.**
`lane: cycle-scoped` means only "inert off its own dev branch" (`docs/autoflow-guide.md:856`) — the
file is still committed, still enumerated, and still forced into CI with no exemption
(`scripts/test/check-suite-ci-coverage.sh:26-30`); retirement is a manual act at the cycle's final
commit (`:872`). The test kinds (`driving` / `regression` / `characterization`, `:495-497`) classify
a test's role in RED, not its lifetime.

**Why the local run holds that scope today.** Push is admitted only after AUDIT and GATE:QUALITY
(`CLAUDE.md:430`) and CI runs only on `pull_request` (`.github/workflows/contract-suites.yml:38`),
so no CI verdict exists during the cycle and the local run stands in for one. ADR-0019 rejected
using CI results as an "advisory CI signal" (`docs/adr/0019-scope-fit-verification-policy.md:100-102`),
yet HANDOFF step 5 already requires CI green as a `[MUST]` (`docs/autoflow-guide.md:1798`) — the
rejection and the flow disagree.

The operator's decision that governs this ADR: AutoFlow verifies **its own** tests; a target's test
execution and format are the target's; locally only the changed part is tested once; that one-shot
test must not execute after merge **by structure**, not by inertness; the CI layer is separated from
it; and the `[MUST]` / `[DENY]` rules and evaluation criteria are adjusted to match.

## Decision

### M — The two-layer verification model

Verification has **two layers**, partitioned by the **subject** of the verification and named by
**persistence**, not by execution site:

- **`standing`** — the property must still hold under a later, unrelated change.
- **`cycle`** — the property's subject dies at merge: it was wired / generated / delivered /
  converted / swept for *this* change.

The **verdict point** for a `standing` `automated` row is CI (D4). That is a separate fact from the
layer's name.

**Execution rule** (this model's operative sentence):

> Local execution = every `automated` row this cycle authored or changed, plus every
> `delivery-check` row. No other `automated` row executes locally.

The rule is what keeps RED intact. A `driving` row must FAIL before GREEN
(`docs/autoflow-guide.md:495-497`) and no CI run exists before push, so a reading of "locally, only
a one-shot test of the changed part" that excluded this cycle's own new tests would delete RED. The
sentence forbids that reading: what leaves the local run is the *unchanged* standing set, never the
set this cycle wrote.

The layer name is faithful to the issue's own gloss — the CI layer is "머지 후 유지되는 속성",
persistence, not execution site. The separation the operator asked for is recorded; what changed is
that each layer is named by what defines it.

### D1 — Classification criterion and declaration site

**Criterion.** *Must this property still hold under a later, unrelated change?* Yes → `standing`;
no → `cycle`. The predicate is over the **property**, not over the file.

**Declaration site.** The **existing `Type` cell** of the verification design's acceptance-criteria
table. **No `Layer` column is added.** The layer is a **total function of `Type`** over ADR-0022
decision 2's closed disposition vocabulary, and this ADR carries the mapping:

| `Type` | Layer | Asset |
|---|---|---|
| `delivery-check` | `cycle` | one-shot, uncommitted, archived with the cycle's artifacts |
| `automated` | `standing` | `committed` unconditionally; `CI-registered` only where the target opted in |
| `existing-coverage` | `standing` | the named mechanism, already standing |
| `manual` | `standing` | the committed scenario file; the verdict is a person's, not CI's |
| `environment-dependent` | `standing` where resolved to an oracle or a mock; no asset on a design-change request | — |
| `none` | — | — |

Three consequences are recorded here so that no gate re-derives them:

- **No new scored item anywhere.** Because the layer is derived rather than declared, there is no
  named check to place on GATE:PLAN `Test plan`, and therefore no divergence from ADR-0018
  decision 2, which placed a depth judgment on an existing criterion and explicitly refused a new
  scored item. What GATE:PLAN scores is that the chosen `Type` is right, which `Test plan` and
  `Scope` already score (`docs/autoflow-guide.md:717`, `:730`).
- **ADR-0022's tier-2 mechanism is not amended.** Every `cycle`-layer row is `delivery-check`, which
  is `≠ automated`, so the host PR body's `## Verification dispositions` inclusion predicate
  (`docs/autoflow-guide.md:1788`; `docs/pr-body-guide.md:55-60`) already admits it: the external
  reviewer sees every `cycle`-layer row with its stated reason, with no widening of the predicate.
- **The `automated` asset cell splits.** AutoFlow establishes `committed` on every target;
  `CI-registered` only where the target opted in, because the target's own CI is the target's
  business. On a non-opted-in target GATE:QUALITY `Test coverage`'s standing half is
  `not-applicable` (`docs/submodule-common-rules.md:197`) — which is not clean, and which is a
  rubric disposition, never a route class, so it never reaches `scripts/gate/remedy-route.sh`.

A **composition oracle** is `standing` by this mapping and not by a separate rule: an oracle row is
`automated`, or an `environment-dependent` row resolved to a real-environment oracle, and neither
maps to `cycle`. "A floor that does not survive merge is not a floor" is a consequence of the
mapping, recorded as one, rather than an independent clause that could drift from it.

### D2 — Storage form of cycle-layer assets

A `cycle`-layer asset is **uncommitted**. It is a cycle artifact under the single declared prefix
`.autoflow/issue-{N}-local/`, executed once at the cycle's verification point and archived with the
issue's other `.autoflow/issue-{N}*` artifacts at prior-cycle cleanup. It never enters the merged
tree.

The prefix must be a **single declared path prefix**, because a predicate needs a subject: "the
cycle layer lives with the other cycle artifacts" is a convention, not something a check can read.
`.autoflow/` costs nothing to name — it is already the cycle-artifact store and already ignored
(`.gitignore:6-7`).

**Cross-cycle disposition.** The store is a **fourth cycle-spanning artifact** on
`docs/autoflow-guide.md:189`'s exception list, alongside the ledger, the state file and the
review-findings file. That line's rename pattern matches a flat `.md` and does not match a
directory, and the three existing exceptions are exactly the artifacts whose subject is *the issue*
rather than *the cycle* — and a `delivery-check`'s subject is the open PR's **cumulative landed
diff**, so on a review-response cycle the previous cycle's delivery checks still have a live
subject. The store's **retained set is reviewed and re-authored at RED entry**, then re-executed at
the new cycle's verification point; a check that did not execute is `not-run`, never `passed`
(`docs/submodule-common-rules.md:196`). Review at RED entry rather than on a failure is deliberate:
it makes every retained check that executes one whose subject this cycle did not change, so a
failure is unambiguous and needs no new branch — a `delivery-check` has no RED/GREEN semantics
(ADR-0022 decision 2), so the VERIFY cause-branch is not its home.

**AC3's confirming means.** One standing **tracked-file predicate** over the declared prefix,
authored by a named sub-issue (S3 below). It is `standing` by D1's criterion: it must hold under a
later, unrelated change — the realistic defect it catches is a `.gitignore` edit three cycles from
now, which no per-PR relation can see.

### D3 — Target test entry point, and the suite plane's fate on targets

**Entry point.** The phases invoke **the target's declared test command** through a call site, not
through AutoFlow's runner. Discovery order, first hit wins: (1) `.claude/autoflow.local.json` →
`tests.command`; (2) the target's `CLAUDE.md` > Development Commands `Test` entry. JSON first
because it is machine-readable; the `CLAUDE.md` entry second because it is free text.

**Suite plane.** The AutoFlow suite plane — the header contract, the selector, the runner,
suite-coverage, `scripts/test/check-suite-manifest.sh` and drift-check D7 — becomes **opt-in, not
removed**, declared at `tests.suite_plane` in the same target-owned scaffold. Its target-side
enforcement fires only where the target declares it.

**One resolver.** A **single shared opt-in resolver** is sourced by every device that depends on the
declaration: the header contract (`scripts/test/check-suite-manifest.sh`), the selector
(`scripts/test/select-suites.sh`) and drift-check D7, which gains a **new opt-in-keyed arm that
calls the resolver** rather than carrying its own copy of the predicate. Three copies of one
predicate is the defect, not the fix — `scripts/test/check-suite-ci-coverage.sh:20-24` already names
that shape ("two definitions of one subject"), and three predicates that must agree is a
verification that can pass while the system is inconsistent. D7 today has exactly two SKIP arms
(`setup/thin-root-layer/drift-check.sh:501-505`) and the selector ships to every stamped target
(`setup/manifest.json`), so a non-opted-in target resolves the selector, runs D7 and FAILs: the new
arm is required, not optional.

**AutoFlow synthesizes no selection predicate for the target.** What AutoFlow never does is derive,
on the target's behalf, *which of the target's tests this change requires*. The phases invoke the
command **as declared**: scoping is the target's practice, and a target that wants a change-scoped
run declares one.

**Boundary.** AC2 and M bind what AutoFlow's phases require of **AutoFlow's own run set**. What a
target's declared test command executes internally is **outside this model** — a target's test
execution and format are the target's (설계 원칙 1, restated in this record's Context at `:43-46`) —
and no acceptance criterion of this issue verifies it. The ground travels with the sentence instead
of being asserted: AC2's second sentence names the verification's object — *"조정 범위 1의 규정이
모두 새 모델로 대체되거나 삭제된다"* — and every row of that enumeration is an AutoFlow rule
(`docs/autoflow-guide.md`, `docs/submodule-common-rules.md`, `.claude/agents/*`,
`docs/teammate-contracts.md`, `docs/evaluation-system.md`, `CLAUDE.md`, the header contract); not one
row is a target's test command.

**Outcome, and what it is read from.** The **exit status of the declared command as invoked** is the
input: AutoFlow reports what the invocation returned and adjudicates nothing beyond it — scoping and
failure attribution are the target's practice. The call site reports through the lint chain's outcome
vocabulary, total over reachable states — `clean` / `fixed-and-staged` / `detected` / `not-run` /
`not-applicable` with their reason classes (`docs/submodule-common-rules.md:192-196`) — including
that `not-run` is never `clean`. What does **not** carry across is that vocabulary's lint-side
qualifier *attributable to the staged files*: a linter reports at the offending file and a test
runner reports at the assertion site, so this decision takes the exit status rather than a reading of
the output. A non-zero exit is therefore reported non-clean, and AutoFlow neither excuses it nor
adjudicates its cause.

**The unsatisfiable case.** A target that declares no test command while the design types a row
`automated` is caught at **GATE:PLAN `Feasibility`** (`docs/autoflow-guide.md:730` — "a plan not
grounded in the actual structure"). The fact is carried **in the verification design**, which
GATE:PLAN reads; the PREFLIGHT ledger entry remains the record and carries no gate weight, because
the ledger is not a gate input (`CLAUDE.md` > Decision Ledger). A residual state proceeds correctly:
a target with no declared test command whose design types every row `none` / `manual` /
`existing-coverage` is `not-applicable` and proceeds, because it owes no automated verification.

**Why this blocking point is not a device on the target path.** The test is *whose artifact must
change to clear the block?* — here, **AutoFlow's own verification design**: retype the row, and the
residual above already lets a design owing no automated verification proceed. GATE:PLAN is also the
sole point at which that judgment is ever re-derived, since an `automated` row never reaches the
external reviewer — the host PR body's `## Verification dispositions` section covers every criterion
typed *other than* `automated` (`docs/autoflow-guide.md:1787-1790`). A blocking point whose remedy
lies entirely inside AutoFlow's own artifact mandates nothing of the target; one whose remedy lies in
the target's declaration would be a device on the target path however it is worded.

### D4 — CI-layer verdict point and CI-failure re-entry

**Verdict point.** **HANDOFF step 5**, `scripts/handoff/confirm-ci-green.sh` exit `0`
(`docs/autoflow-guide.md:1798`), which is already a `[MUST]`. **The push gate is not relaxed**:
pulling CI earlier would change *when* the security gate binds, which is an ADR trigger in its own
right, and no acceptance criterion asks for it.

**Re-entry.** A CI failure re-enters by `remedy_class` through `scripts/gate/remedy-route.sh route`,
replacing the unconditional route at **both** `CLAUDE.md:314` and `docs/autoflow-guide.md:1803`.

**Classifier — three stages, every input a declaration.**

- **Stage 1 — opted-in target.** The failing check's suite `ci-subject` header, declared by the
  suite author. This is VALIDATE's existing header-based classification, moved rather than invented.
- **Stage 2 — non-opted-in target.** The class authored by the existing tagging role, which performs
  a **separate read of the failing check's output** — the output, not the check's identity.
  AutoFlow's shipped CI reading surface is conclusion-only by design (step 5 reads any check by
  count and conclusion, never by name; exit `12` says only "a check concluded failure"), so without
  naming the input the role would have nothing but an identity and a conclusion in front of it, and
  would author the very name-versus-path inference this decision rejects while wearing a signature.
  The cost of the separate read is bounded by an existing shape: the classifier is a spawn that
  absorbs the log and returns a class, so reading the failure output does not put a log in the
  orchestrator's context.
- **Stage 3 — not classifiable with confidence, or the failure output is unobtainable.** Class
  `operator`, which `scripts/gate/remedy-route.sh:58`, `:69` routes to `PAUSE` — `operator`'s stated
  meaning, "AutoFlow holds no declaration here".

Fail-closed per `docs/autoflow-guide.md:1814`, **cited, not rewritten**: not classifiable with
confidence → `operator`, never a guess; and a CI failure routed with no recorded class is a report
defect — reject the report and re-spawn the ingesting subagent.

**No new cap.** The CI-layer verdict inherits VALIDATE step 1's failure disposition because it
inherits its role: it *is* the whole-tree floor, relocated. The existing
`environment / push rejection → HANDOFF internal retry (max 2×)` branch is untouched — that is not a
CI-layer verdict.

### D5 — This repository, and the advisory CI

This repository is a **consumer of its own model**: the local whole-tree floor is removed here too,
and `.github/workflows/contract-suites.yml` is its standing layer. The workflow **stays advisory at
the branch-protection level**, while the AutoFlow-side verdict is binding — advisory-to-the-merger
and binding-to-the-hand-off are different bindings, and both documents already say so
(`.github/workflows/contract-suites.yml:31-33` against the `[MUST]` at
`docs/autoflow-guide.md:1798`). Promoting the workflow to a required status check would bind the
**external reviewer's merge**, which is authority AutoFlow does not hold (ADR-0003).

Two pre-existing fail-closed properties are what make an advisory workflow admissible as the
standing layer, and both are retained:

- "No check published" is **not** green — `confirm-ci-green.sh` exit `11` is a distinct non-green
  code, so a CI that never fired cannot read as a pass.
- A path-filtered CI could publish some green check while the relevant suite step never ran. That
  residual is bounded by a standing oracle: the workflow's `paths:` blocks must carry every path
  declared by a registered suite's `ci-subject` header, asserted by
  `tests/test-workflow-trigger-conformance.sh`.

The suite **header contract is therefore retained here as a gate input**, not as a CI convenience:
here it is the standing layer's trigger-coverage mechanism, even as D3 makes it opt-in for targets.

### D6 — ADR-0019's supersede scope, and the retirements that follow

**Supersede mapping.**

- **ADR-0019 decision 1** (selection-based interim verification plus the VALIDATE whole-tree floor)
  — **superseded in full.** The floor relocates to the standing layer (D4, D5).
- **ADR-0019 decision 2** (suite-grained inheritance, input-hash key, shared store) — **superseded
  in full; the mechanism is retired, not re-keyed.** Inheritance exists only to avoid re-running
  tests a change did not touch; once the local run set *is* the change, there is nothing left to
  inherit, and ADR-0019's own Consequences > Negative already calls it "new machinery on the
  verification path". With its purpose gone it is pure carrying cost.
- **ADR-0019 decision 3** (evaluator execution discipline) — **superseded in part.**
  `inherited_verdicts` goes with the register. The other three obligations are **retained and
  re-homed in this ADR's body** (next section), and `docs/teammate-contracts.md:62-65`'s *Governing
  record* pointer is repointed here. They govern evaluator **search** discipline and touch nothing
  in the layer model; they were bundled into ADR-0019 only because that was the cycle that wrote
  them.

**Retirements.**

- **The Green-tree register and its shared store — both retired.** Every consumer disappears: the
  tree-identity and suite-coverage predicates at GREEN step 5 / VERIFY step 1 / REFINE step 2, and
  the orchestrator's one discharge exception under *Verify teammate claims*. The shared store's
  retirement has no gate consequence by its own charter — `CLAUDE.md` already declares it "a cache,
  not a ledger … not gate input".
- **Reporting Format's `inherited Green` anchor sub-class — retired.** Item 5's primary test-pass
  anchor (the exact summary line plus the command that produced it) covers every step once every
  step executes what it claims; the sub-class was added precisely as the exception for a step that
  did **not** execute, and that exception's subject is gone.
- **`out-of-tree-inputs` — deleted, and the exposure it guarded is closed, not unguarded.** Its only
  functional consumer is the inheritance exclusion (`scripts/test/suite-coverage.sh:440-442`). The
  tightening existed because a base-ref-dependent suite can change answer while the tree is
  untouched — an inheritance-specific exposure; with nothing inheriting, such a suite simply runs.
  What would otherwise remain is a lint demanding a declaration nothing reads.
- **`lane`, `retire-with`, `cycle-arm` — deleted.** Under D2 the `cycle-scoped` lane is an **empty
  category by construction**: every committed suite is `standing`, so a two-value field with one
  reachable value is not a declaration. `cycle-arm` has **zero live instances** of the case its own
  rationale names ("a standing suite may carry a cycle-scoped arm") — the only declaration in the
  tree sits on a suite that is itself cycle-scoped.
- **`tests/test-suite-coverage-agreement.sh` — deleted.** Its subject is the agreement between the
  resolver and the coverage predicate, and both sides are retired.

**Not superseded.** ADR-0018 and ADR-0022 stand. ADR-0022's disposition vocabulary is untouched; the
one amendment is `delivery-check`'s definition (*Amends ADR-0022*, below). The retained
test-quality items — mock-boundary fidelity (`docs/teammate-contracts.md:110`), Test necessity
(`:104`) and output hygiene — are **`retained`**: they are independent of the layer partition and
nothing in this ADR touches them.

### Evaluator execution discipline (re-homed from ADR-0019 decision 3)

This ADR is the governing record for the three obligations that survive ADR-0019 decision 3.
`docs/teammate-contracts.md:62-65`'s *Governing record* pointer names this ADR.

1. **Resolve an anchor before executing.** An evaluator resolves the cited **anchor** — the
   `path:line`, the commit, the command — before it executes anything against it; an unresolved
   anchor is a report defect, not an input.
2. **Representative sampling, escalating to exhaustive on a hit.** A search starts from a
   representative sample and escalates to the exhaustive set as soon as the sample yields a hit.
3. **A declared wall-clock cap, with unsearched items recorded.** The search declares its
   wall-clock cap up front, and any item left unsearched when the cap binds is recorded
   `not-searched` — never reported clean.

`inherited_verdicts` is **not** re-homed: it is deleted with the register (D6).

### Sub-issue split, and the obligations carried into it

Implementation is deferred by the issue's own `범위 밖` to four sub-issues, along the split the
operator declared:

- **S1 — rule documents.** `CLAUDE.md`, `docs/autoflow-guide.md`, `docs/submodule-common-rules.md`,
  `docs/teammate-contracts.md` and the agent definitions: Area 1's rows, plus Area 3's two
  unconditional-route sites.
- **S2 — evaluation criteria.** `docs/evaluation-system.md` and the two gates' rubric items:
  Area 2's rows.
- **S3 — scripts, hook and lint.** `scripts/test/**`, `scripts/gate/**`, `.claude/hooks/**` and
  `tests/**`: the shared opt-in resolver, the classifier, the deletions, and **AC3's standing
  tracked-file predicate over `.autoflow/issue-{N}-local/`**.
- **S4 — shipping.** `setup/manifest.json`, `setup/thin-root-layer/**` and the scaffold that carries
  `.claude/autoflow.local.json`: D7's opt-in-keyed arm and the declaration site's shipping.

Two obligations of this cycle are **carried forward** to those sub-issues, because a
deferred-implementation cycle separates each obligation from the change surface that triggers it and
this record is the only carrier across that gap:

- **Composition-oracle forward-carry.** This cycle's change surface is a document set, so it names
  no shared-state identifier and the oracle is empty. The retired identifiers —
  `green-tree-register`, `green-tree-shared-store`, `ci-subject`, `lane` — are named by S1's and
  S3's change surfaces, and the composition-oracle floor is carried to whichever sub-issue's surface
  names them.
- **Dangling-reference forward-carry.** GATE:QUALITY's reference-integrity sweep
  (`docs/autoflow-guide.md:1604-1607`) triggers on relocation and renaming. This cycle's diff adds a
  file and edits status text, so the sweep never fires here; the obligation binds in the sub-issues,
  where relocation and renaming actually happen.

### Clauses this ADR carries beyond M and D1–D6

- **Effective-from.** The cycle that writes this ADR is governed by the **pre-existing** rules —
  the header contract, the selector, the cycle-scoped lane and CI registration all apply to the
  checks that cycle writes. Same convention as `docs/autoflow-guide.md:409`, `:510`, `:533`. Without
  it, this cycle's own GATE:QUALITY would score `Test quality` against the test-asset rule the same
  cycle deletes.
- **AC1 naming equivalence.** The issue's 로컬 layer is this ADR's **`cycle`** layer, and the
  issue's CI layer is this ADR's **`standing`** layer. The renaming carries no content change, so
  neither gate's acceptance-criterion-authority check has to decide whether a renamed layer is a
  changed criterion.
- **`Amends ADR-0022`** — see *Related Issues / PRs*.
- **The adjustment-scope table below is not the change table `docs/autoflow-guide.md:347-353`
  `[DENY]`s.** Issue #192 bars a *prediction of the files implementation will touch*, decided by
  "would this being wrong mean the design is revisited, or just fixed where it is found?" Here the
  enumeration **is** the operator-declared deliverable and a wrong row means a rule survives that
  contradicts the model — the design is revisited. Same test, opposite answer; and the closed
  vocabulary enforces the discipline by construction, since `deleted` / `replaced` / `retained` /
  `conditional` are fates of rules, and a diff has no fate.
- **Status `Proposed`** is sufficient for this record to govern the sub-issues
  (`docs/adr/0018-verification-depth-justification.md:101`).

## Adjustment scope

Every row of the three areas carries **exactly one** disposition from a closed vocabulary, which is
what makes the issue's "모두 / 일치" a set relation over its own enumeration rather than a reading of
prose:

| Word | Meaning |
|---|---|
| `deleted` | the rule and its subject both go |
| `replaced` | the subject survives, the rule is rewritten |
| `retained` | unchanged text, unchanged subject |
| `conditional` | the rule survives, keyed on the target's opt-in declaration |

A row's subject is always **a rule or an enforcement device**, never "a file that will need
editing".

### Area 1 — `[MUST]` / `[DENY]` local-execution rules

| Rule | Disposition |
|---|---|
| VALIDATE step 1's whole-tree sweep and its tree quiesce (`docs/autoflow-guide.md:1462`, `:1464`) | `deleted` — the coverage floor relocates to the standing layer (D4, D5) |
| GREEN step 5 / VERIFY step 1 / REFINE step 2 capture-point execution, quiesce and tree-identity predicate (`docs/autoflow-guide.md:949`, `:985`, `:1413-1416`) | `replaced` — the predicate and the quiesce leave with the register (D6); the execution obligation narrows to M's execution rule |
| Whole-tree-run prohibition and its one-invoker sentence (`docs/autoflow-guide.md:900`; `.claude/agents/autoflow-implementer.md:38`) | `replaced` — deleting VALIDATE step 1 falsifies the rule's own text, so it is rewritten to *the cycle layer carries no local whole-tree execution: none scheduled, none held in reserve*; the local run set is **declared** under M's execution rule rather than selected, so no device has a local whole-tree run to degrade to |
| Selector-BLOCK degradation (`docs/autoflow-guide.md:1693-1695`) and its two coupled device sites — the selector's degrade-to-executing sentence (`scripts/test/select-suites.sh:195`) and the runner's failed-selection comment and operator message (`scripts/test/run-suites.sh:129-137`) | `deleted` — the rule and its subject both go: with the local run set declared rather than selected, a selector BLOCK is a device failure on a path that no longer carries a coverage floor, not a local coverage hole to backfill by executing the standing set |
| Runner/selector-only execution and the `\|\| { … }` idiom (`docs/submodule-common-rules.md:262`, `:277`) | `conditional` — keyed on the target's suite-plane opt-in (D3); the idiom leaves with `scripts/test/suite-coverage.sh` |
| RED-entry derivation of the affected suites (`.claude/agents/autoflow-tester.md:11`) | `replaced` — by D3's call site to the target's declared test command |
| `inherited` reporting and the green-tree discharge (`docs/teammate-contracts.md:67`, `:112`, `:127`; `docs/evaluation-system.md:141`, `:143`; `CLAUDE.md` > *Verify teammate claims*) | `deleted` — with the register and its shared store (D6) |
| Header contract and suite-disposition derivation (`docs/autoflow-guide.md:349`, RED > *Completion*) | `conditional` — on the target's opt-in (D3); `retained` for this repository, where the contract is the standing layer's trigger-coverage input (D5) |
| Cycle-artifact preservation list (`docs/autoflow-guide.md:189`) | `replaced` — `.autoflow/issue-{N}-local/` joins it as a fourth cycle-spanning artifact (D2) |

**Why the Selector-BLOCK row is `deleted` and not `replaced`.** Once the local run set is declared,
the selector answers a different question — *which of the standing suites could this delta have
broken* — and D4/D5 make that question CI's. A BLOCK on that path is a device failure, not a local
coverage hole, so the rule that degraded it to executing has no surviving subject. What is
**retained** is the **fail-closed** disposition wherever selection survives: the selector already
refuses to emit an empty selection (`scripts/test/select-suites.sh:203-206`) and CI already exits
non-zero on an unresolved selection (`.github/workflows/contract-suites.yml:353-356`) rather than
widening the run. That site is therefore not a coupled site of the deleted row — it carries the rule
this record keeps, not the one it deletes.

### Area 2 — evaluation criteria

| Criterion | Disposition |
|---|---|
| GATE:PLAN `Test plan` (`docs/autoflow-guide.md:717`; `docs/evaluation-system.md:67`) | `retained` — no new judgment is added: the layer is derived from `Type`, which this item and `Scope` already score |
| GATE:PLAN `Feasibility` (`docs/autoflow-guide.md:730`) | `retained` — it carries D3's blocking point unchanged, with the fact supplied by the verification design |
| GATE:QUALITY `Test quality` — test-asset disposition (`docs/autoflow-guide.md:1608-1614`) | `replaced` — its subject (a cycle-scoped asset left CI-registered) cannot occur; the replacement subject is a **layer violation** — a committed asset on a `delivery-check` row, or an uncommitted one on an `automated` row |
| GATE:QUALITY `Test coverage` (`docs/evaluation-system.md:69`) | `replaced` — the subject is restated from *CI result* to *standing-layer asset realisability + cycle-layer executed result*, both checkable strictly before push; `not-applicable` on a non-opted-in target |
| ADR-0019 decision 3 (evaluator execution discipline) | `replaced` — in part (D6): `inherited_verdicts` goes with the register, while the anchor, sampling and wall-clock obligations are re-homed above and `docs/teammate-contracts.md:62-65`'s *Governing record* pointer is repointed to this ADR |
| VALIDATE failure routing by `ci-subject` (`docs/autoflow-guide.md:1472`; `scripts/gate/remedy-route.sh`) | `replaced` — moved, not deleted: the same header-based classification becomes stage 1 of D4's CI-failure classifier, through the same routing script |
| GATE:QUALITY `doc` remedy step 3's selected-suites run (`docs/autoflow-guide.md:1691-1695`) | `replaced` — by M's execution rule; the repo-wide doc sweep record (`.autoflow/issue-{N}-remedy-sweep.md`, hook-gated) is a doc sweep, not a test run, and stays untouched |

### Area 3 — enforcement devices

| Device | Disposition |
|---|---|
| Backgrounded `run-suites.sh` deny (`.claude/hooks/check-autoflow-gate.sh:28`) | `retained` — a backgrounded run's result is not keyed to the tree the claim is made about; where the plane is not opted in there is no invocation to deny, so the rule is vacuous rather than wrong |
| `scripts/test/check-suite-ci-coverage.sh:26-30` — CI registration with no exemption | `retained` — its subject becomes true by construction: every committed test is a standing-layer test by definition |
| `scripts/test/check-suite-manifest.sh` and drift-check D7 (`setup/thin-root-layer/drift-check.sh:481` ff.) | `conditional` — a **new** opt-in-keyed arm that calls the one shared resolver (D3) |
| `setup/manifest.json`'s suite-plane shipping rows | `retained` — shipping continues; only *enforcement* becomes conditional |
| ADR-0019 decisions 1–3 (`docs/adr/0019-scope-fit-verification-policy.md:28-90`) | `replaced` — per D6's supersede mapping, decision by decision |
| `CLAUDE.md:314` — HANDOFF CI failure → RED, unconditional | `replaced` — by D4's class route |
| The `lane` header field (`docs/autoflow-guide.md:856`) | `deleted` (D6) — the cycle-scoped value becomes an empty category by construction |
| The `retire-with` header field (`docs/autoflow-guide.md:857`) | `deleted` (D6) — it names the retirement of a lane that no longer exists |
| The `cycle-arm` header field (`docs/autoflow-guide.md:858`) | `deleted` (D6) — zero live instances of the case its own rationale names |
| `tests/test-suite-coverage-agreement.sh` | `deleted` (D6) — an enforcement device whose subject is gone on both sides |
| `cycle-arm`'s coupled sites — its grammar (`scripts/test/suite-manifest.sh:27`, `:314-319`), the three-way lint (`scripts/test/check-suite-manifest.sh:92`, `:104`, `:107`, `:110`), the one live declaration, and the quoted literal carried in the agreement suite (`:101`, `:106`) | `deleted` (D6) |
| `out-of-tree-inputs` — the field, its lint (`scripts/test/check-suite-manifest.sh:133-138`), its doc sites (`docs/autoflow-guide.md:867`, `:1272`) and its three live declarations | `deleted` (D6) |
| The Green-tree register and its shared store | `deleted` (D6) — every consumer disappears with M's execution rule |
| `docs/autoflow-guide.md:1803` — `confirm-ci-green.sh` exit `12` → RED | `replaced` — the second site of the same unconditional route; leaving it makes the script's own exit contract contradict D4 |
| `delivery-check`'s definition at `docs/autoflow-guide.md:482` | `replaced` — D2 makes the asset an uncommitted `.autoflow/issue-{N}-local/` artifact, not a check living in a manifest lane |
| RED's `delivery-check` conversion rule (`docs/autoflow-guide.md:833`) | `replaced` — same subject, same replacement: the row produces a cycle-layer artifact under the declared prefix |
| The Admission question's default for a delivery-pinned check (`docs/autoflow-guide.md:879`) | `replaced` — the default answer becomes the cycle-layer store, not a lane-declared committed suite |
| The `lane` / `retire-with` grammar fence in the header block (`docs/autoflow-guide.md:849-850`) | `deleted` (D6) |
| The lane adoption item (`docs/autoflow-guide.md:865`) | `deleted` (D6) |
| The cycle-scoped naming rule (`docs/autoflow-guide.md:872`) | `deleted` (D6) — with the lane gone, an issue-numbered filename has no declaration to follow |
| The `lane` / `retire-with` grammar in the manifest library (`scripts/test/suite-manifest.sh:25-26`) | `deleted` (D6) |
| The lane-value lint arm (`scripts/test/check-suite-manifest.sh:87-88`) | `deleted` (D6) |
| The cycle-scoped coupling lint arm (`scripts/test/check-suite-manifest.sh:96-98`) | `deleted` (D6) |
| The ADR-0019 status records (`docs/adr/0019-scope-fit-verification-policy.md:5`, `docs/adr/README.md:36`) | `replaced` — adjacent sites of the enumerated ADR-0019 row, repaired to the composite status string form |
| The ADR-0022 status records (`docs/adr/0022-test-necessity-and-three-tier-ac-guard.md:5`, `docs/adr/README.md:39`) | `replaced` — grounded in this ADR's *Amends ADR-0022* line, in the same composite form |
| The `docs/adr/README.md` ADR-0024 row | **additive** — a new record, not a fate of an existing rule; outside the four-word vocabulary by construction |

The two device sites coupled to the now-`deleted` Selector-BLOCK degradation rule
(`scripts/test/select-suites.sh:195`, `scripts/test/run-suites.sh:129-137`) are disposed in their
parent rule's Area-1 row, under the same convention as `cycle-arm`'s coupled sites above.

**Why the status rows are here and not cosmetic.** A governing ADR is one with status `Accepted` /
`Proposed` whose Decision scope intersects the change surface (`docs/autoflow-guide.md:734`), and
`Proposed` is sufficient for the record to govern. A stale record therefore makes superseded
decisions **governing input** to the next cycle's two ADR-conformance checks, with every link
resolving so no reference check fires. The repair form is the **composite status string** already
used at `docs/adr/README.md:35`, `:37`, `:40`, recorded on both the ADR's `## Status` and its
registry row.

## Alternatives Considered

- **Naming the persistent layer "CI".** Under D1's mapping three of the five non-`none` dispositions
  map to the persistent layer while **CI executes none of them** — `existing-coverage` is a
  mechanism that already stands, `manual`'s verdict is a person's, and a resolved
  `environment-dependent` row is executed by whatever runs the suite. Every rewritten rule site
  would inherit an ambiguity between *the property persists* and *CI runs it*, and D1's criterion is
  the first.
- **A `Layer` column alongside `Failure mode`.** It adds an axis that can disagree with `Type`, it
  would need a named GATE:PLAN check (the ADR-0018 decision 2 divergence D1 avoids), and it creates
  a row class tier 2 cannot see — a `Layer: local` + `Type: automated` row is invisible both in the
  diff and in the PR body. Making `Layer` merely *constrain* `Type`, or widening the PR-body
  inclusion predicate, were superseded by deriving the layer outright.
- **Reusing the suite header's `lane: standing | cycle-scoped` as the declaration site.** It is
  already this partition, but it is declared in an artifact derived at RED (issue #192) and it has
  no execution consequence today: `cycle-scoped` means only "inert off its own dev branch" while
  `scripts/test/check-suite-ci-coverage.sh:26` forces it into CI anyway with no exemption. A
  partition with no teeth is not a declaration site.
- **Committing the cycle-layer asset and excluding it structurally (D2 mechanism B).**
  Non-execution after merge would rest on an exclusion rule every future enumerator must keep
  honoring — structurally the same shape as today's `cycle-scoped` lane, which is the failure this
  issue records. A file absent from the merged tree cannot be enumerated by any enumerator, present
  or future; that is the only guarantee that does not depend on a rule staying correct.
- **Keeping `cycle-scoped` with a retirement obligation.** That is today's design: retirement is
  manual at the cycle's final commit and its only enforcement is a scoring cap. A structure
  principle enforced by a 6-point cap is not a structure.
- **Removing the suite plane from targets outright.** It strands the one target that has already
  migrated its headers under issue #213, and it strands this repository, whose own standing layer
  depends on `ci-subject` (D5). The lint precedent does not remove lint — it defers to the target's
  declaration, and deferral is what produces the symmetry the issue asks for.
- **Keeping D7 blocking and migrating targets.** That is the shipped 0.2.2 behavior, and it is the
  concrete thing the operator's first principle names as wrong: it makes AutoFlow's format a
  precondition of the target's own tests.
- **A VALIDATE-style pause for the no-test-command state.** It detects "this cycle could never
  verify anything" only after DIAGNOSE, ARCHITECT, GATE:PLAN, RED, GREEN, VERIFY and REFINE have
  run; the fact is knowable at GATE:PLAN.
- **Relaxing the push gate to pull CI earlier.** It buys detection latency at the price of pushing
  un-audited code to a shared remote — a change to *when the security gate binds*.
- **An unconditional `HANDOFF → RED` on CI failure.** Discarded-information routing at the most
  expensive point in the cycle, against the same measurement that produced Decision 11.
- **A job-name-versus-path heuristic as classifier stage 2.** It is class inference from names, its
  wrong answers are invisible because a route has no oracle, and this tree's recorded measurement of
  that exact shape is already on the record ("the spawn prompt is never used to infer the spawn's
  class").
- **Straight to `operator` on every non-opted-in target.** It converts the automation the CI-failure
  route exists to provide into a pause by default on exactly the targets D3's opt-in is written for.
- **Promoting `contract-suites.yml` to a required status check.** It would bind the external
  reviewer's merge — authority AutoFlow does not hold — and convert a flaky check into a hard block
  the reviewer cannot judge around.
- **Keeping a local whole-tree run as an operator-approved, logged exception.** It requires an
  operator decision reopening the acceptance criterion that forbids the run (`CLAUDE.md` >
  *Acceptance-criterion decisions*) — authority this record does not hold — and it puts a human in
  every cycle run from a shallow clone, a common environment rather than a rare one.
- **Re-deriving the change set by another route** — a worktree diff, a last-known-good SHA, a
  target-declared file list — so that a selector BLOCK has something to degrade to. It reinstates
  AutoFlow synthesizing a selection predicate for the target, which D3's first sentence refuses, and
  it relocates the failure inside the selector instead of removing it; moot once the run set is
  declared rather than selected.
- **Declaring the un-narrowable path "locally unverifiable" and mandating CI registration on it.**
  It contradicts D1's split (`CI-registered` only where the target opted in) and, decisively, it
  breaks RED: no CI run exists before push, so a `driving` row would have no failing observation
  anywhere. It trades one violation for another.
- **Requiring the target's declared command to take the change as an input, and obtaining an
  operator `[ac-decision]` reopening AC2 to license the collateral such a command runs.** The
  external review's own suggested path. Rejected: AC2 needs no exception once its second sentence is
  read — its object is this record's Area-1 enumeration of AutoFlow's own rules, not a target's test
  runtime (D3 > *Boundary*) — so the pause would purchase nothing, and it would ratify on the target
  path a requirement the governing operator decision at `:43-46` excludes.
- **Repairing or replacing the file-name predicate with any other AutoFlow-side attribution rule** —
  a base-tree differential, a known-failure test-id fingerprint set carried across cycles, or a
  repair of name matching itself. Rejected on 설계 원칙 1 (`:43-46`): the defect is that AutoFlow
  adjudicates the target's test execution at all, not that this particular predicate reads the
  unreliable half of a test runner's output. The declared command's exit status is what the outcome
  is read from, and attribution is the target's practice.

## Consequences

### Positive

- The local cycle pays for the change it made, not for the tree: the 594 s whole-tree sweep leaves
  the cycle and its scope is carried by CI, whose measured cost for the same tree is 89 s.
- A one-shot check cannot outlive its subject: absence from the merged tree is a guarantee no future
  enumerator can erode.
- A target adopts AutoFlow without adopting AutoFlow's test format — the symmetry lint already has.
- A CI failure re-enters at the phase its cause names instead of unconditionally at RED.
- Three copies of the opt-in predicate are replaced by one resolver with three callers.

### Negative

- The coverage floor's verdict moves to the most expensive point in the cycle: a CI failure at
  HANDOFF re-enters and re-traverses VERIFY → REFINE → VALIDATE → AUDIT → GATE:QUALITY → DELIVER →
  INTEGRATE → HANDOFF. No new cap is introduced (D4), so the bound is the existing GREEN ↔ VERIFY
  round-trip rules.
- A `cycle`-layer asset is uncommitted, so the external reviewer sees the row's **reason** and never
  the check's **code** — tier 2 of the three-tier guard loses that review surface. Low severity: the
  check executes inside the same trust boundary as the agent that authored it.
- The suite plane becomes two configurations to reason about (opted in / not), and a non-opted-in
  target's standing half of GATE:QUALITY `Test coverage` is `not-applicable` rather than verified.
- With no AutoFlow-side attribution rule, a target whose declared command reports a failure this
  change did not cause surfaces as a non-clean outcome, and the resolution is the coding AI's and the
  human's practice: AutoFlow neither excuses the failure nor blocks the target. AC5's *변경분*
  qualifier is discharged by invoking the declared command — whether that command is keyed to the
  change is the target's practice under 설계 원칙 1.

### Neutral / Trade-Offs

- The layer is derived, not declared, so nothing new is scored and nothing new is written in a
  verification design; the cost is that a reader must know the mapping, which is why it lives here.
- Retiring the inheritance machinery removes a correctness dependency (`ci-subject` declaration
  quality driving inheritance) at the price of losing the fast path it bought.

## Related Issues / PRs

- Issue #217 — this decision; implementation deferred to the S1–S4 sub-issues above.
- **Revision — PR #220 review, round 1 (cycle 2).** The external review of this record returned two
  `Medium` findings on D3 and its Area-1 rows, and this revision was the response. What still stands
  from it: D3's *AutoFlow synthesizes no selection predicate* clause; the whole-tree-run prohibition
  row's replacement text, which no longer holds a local whole-tree run in reserve; and the
  Selector-BLOCK degradation row's move `replaced` → `deleted`, carrying its two coupled device sites
  (`scripts/test/select-suites.sh:195`, `scripts/test/run-suites.sh:129-137`), with
  `scripts/test/select-suites.sh:203-206` not among them because it carries the fail-closed rule this
  record retains. **Retracted by round 2 below** — named here so no reader takes them as governing —
  this entry's statements that the whole-tree-run clause was superseded by a declared-form
  precondition and the borrowed lint verdict rule by an exit-status verdict over a declared run set;
  that *D3 additively gains the declared-form precondition, the M-boundary clause and the content of
  the fact it carries into the verification design*; and that M's execution rule keeps its text while
  the M-boundary clause re-scopes its reach. All three are **withdrawn** by round 2's removals.
  Area 2 and Area 3 keep their words.
- **Revision — PR #220 review, round 2 (cycle 2).** The re-review returned one `Medium` finding
  (R2-F1): round 1's precondition on the target's declared command, and the minimum-unit collateral
  reading that accompanied it, still placed AutoFlow's judgment on the target's own test execution.
  The operator settled it (decision ledger `O13`, authority `operator decision`): **AutoFlow is a
  tool — it neither mandates how a target composes or runs its tests nor judges what a target's
  declared command executes internally**, and what this record delivers is a **rule** stated as
  guidance, never a gate on the target path. The delta is checkable against this record alone: the
  round-1 text contradicted `:43-46`, the governing operator decision the Context already carried.
  - **Removed from D3**, each with the round-1 statement asserting it **retracted** above: the
    declared-form precondition and the infeasibility route it opened on the target's declaration; the
    grain rule and the categorical line over the declared form; the M-boundary clause and its
    minimum-unit collateral reading; the fact D3 carried into the verification design, with its
    parameter; the residual `not-run` state stated as a gate; the exit-status verdict over a declared
    run set, its base-tree differential, the exculpatory-only clause, the set predicate, the flakiness
    clause and the cost bound; and the residual *"where the target's declared command supports
    scoping, run it scoped"* mandate, together with the *"can carry a scoped form"* reason for JSON's
    place in the discovery order. Round 1's **deletion** of the file-name attribution predicate
    stays: what round 2 removes is the replacement machinery, not the deletion.
  - **What D3 now says**: the entry point with first-hit-wins discovery; the suite-plane opt-in and
    the one shared resolver; *AutoFlow synthesizes no selection predicate for the target*, with the
    invocation restated as practice — the phases invoke the command as declared, scoping is the
    target's practice, and a target that wants a change-scoped run declares one; one additive
    **boundary** sentence, carrying its own ground; the outcome vocabulary, whose input is the
    declared command's exit status; and the unsatisfiable case, which now carries the *whose artifact
    must change to clear the block* test and the re-homed tier-2 anchor
    (`docs/autoflow-guide.md:1787-1790`). **M's execution rule does not move, and neither does its
    reach** — round 1's re-scoping of it is **withdrawn** rather than restated.
  - **Round 1's F1-b is closed by the boundary, not left open by the removal.** The case *the
    target's declared command cannot be narrowed to the change* no longer resolves to a local
    whole-tree run — that was round 1 — and it does not fall back to being unresolved now that the
    precondition is gone. It is **closed** by the **boundary** sentence together with the operator
    decision's own fourth clause, that AC2 is a property of AutoFlow's rules and not an observation
    of target runtime: what the declared command executes internally is outside this model, so there
    is nothing left for AutoFlow to require of it, degrade to, or refuse. What survives of round 1's
    residual state is a **report, not a gate**, and it is stated where it belongs — **M**'s
    RED-integrity paragraph (`:67-71`): a `driving` row that never ran yields no Red confirmation,
    which is the absence of a confirmation AutoFlow owes **itself**, not a rule imposed on the
    target. D3 states no residual `not-run` gate of its own.
  - **Also moved**: the two *Alternatives* entries whose subject was the precondition's candidate
    objects lose it and go; the file-name-predicate entry is rewritten to reject **any**
    AutoFlow-side attribution rule on 설계 원칙 1, absorbing the known-failure-fingerprint entry as
    one of its variants; and the reviewer's own suggested path — keep the requirement and obtain an
    operator `[ac-decision]` reopening AC2 — is recorded and rejected. *Consequences > Negative*
    gains the cost, stated plainly. **Acceptance-criterion content is unchanged**: round 2 removes
    constraints rather than adding them, and AC2's own second sentence carries the boundary, so no
    `[ac-decision]` is owed. Area 1, Area 2 and Area 3 keep their words and their dispositions.
- Supersedes `docs/adr/0019-scope-fit-verification-policy.md`: decision 1 and decision 2 in full,
  decision 3 in part — `inherited_verdicts` is deleted with the Green-tree register, while the
  anchor-before-execute, representative-sampling and wall-clock-cap obligations are retained and
  re-homed in this ADR's *Evaluator execution discipline* section.
- Amends `docs/adr/0022-test-necessity-and-three-tier-ac-guard.md`: decision 2's definition of
  `delivery-check` — the row's asset is a one-shot artifact under `.autoflow/issue-{N}-local/`, not
  a committed check in the `lane: cycle-scoped` manifest lane. The closed disposition vocabulary,
  the Test-necessity judgment and the three-tier acceptance-criterion guard are unchanged.
- Builds on `docs/adr/0018-verification-depth-justification.md`: the layer is derived from an
  existing cell, so no scored item is added.
- Reinforces `docs/adr/0003-autoflow-ends-at-handoff.md`: D5 declines to bind the reviewer's merge.
- Issues #112, #121, #130, #134 — the local-cost series this decision closes.
- Issue #213 — the target header BLOCK and drift-check D7 that D3 makes conditional.
- Issue #140 — the `remedy_class` cause branch D4 routes through.
- Issues #75, #76, #85, #122 — the cycle-scoped lane and CI-registration rules D6 retires.

## Notes

- Numbering: 0024 is the next free integer, contiguous after 0023.
- The decision alters agent-workflow gates and evaluation policy — a `docs/adr/README.md` >
  "When to Create an ADR" trigger area — so it lands ahead of the mechanisms it governs.
- **Effective from the next cycle.** The cycle that writes this record is governed by the
  pre-existing rules; see *Clauses this ADR carries beyond M and D1–D6*.
- **Revised twice in response to the external review of PR #220.** Each round's findings, what
  changed, what stands and what is retracted are recorded in *Related Issues / PRs*.
