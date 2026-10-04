# U3 Design — ARCHITECT and GATE:PLAN

> Unit document for U3. [`CLAUDE.md`](../../CLAUDE.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

ARCHITECT and GATE:PLAN are one functional unit, U3 Design
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed
by four things only — its goal, its artifact contract, its verification and its loop cap (D2) —
and this file states them, with the cautions the design is asked to heed and the result it owes.
How the unit reaches the goal — what it reads, whether it spawns helpers, whether it asks a critic
to challenge a draft or holds a dialogue at all, how it designs this issue's own verification — is
the unit agent's, recorded with its grounds in its artifact ([`CLAUDE.md`](../../CLAUDE.md) > Rule
Scope, principle 2).

- **Goal**: a design the build unit can implement and verify — the architecture decisions with
  the constraints they hold under and the alternatives rejected, and a verification design that
  says how each acceptance criterion is verified and which failure mode each verification catches.
- **Artifact contract**: the two documents under *Output artifacts* below.
- **Verification**: GATE:PLAN — a fresh Evaluation AI scores the two documents on the rubric of
  [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:PLAN; the unit never
  scores its own artifact (*Verification — GATE:PLAN* below).
- **Loop cap**: a GATE:PLAN FAIL re-runs the unit with the evaluator's findings and the previous
  documents (*Re-entry* below), max 3× (`CLAUDE.md` > Flow Control > Regressions).
- **Result owed**: the two artifact paths and a one-line summary
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting Format). The
  orchestrator does not receive the design's body.

## Unit spawn

- **The spawn.** One `autoflow-unit-design` (`Agent`, anonymous, no `name`, the model
  `bash scripts/spawn-policy/spawn-policy.sh model unit-design` names). The prompt states the goal
  and names the inputs by path — the acceptance-criterion list
  (`.autoflow/issue-{N}-analysis.md` > `## Acceptance criteria`), the decision ledger
  (`.autoflow/issue-{N}-ledger.md`), the DIAGNOSE artifact (`.autoflow/issue-{N}-analysis.md`, the
  GATE:HYPOTHESIS reports) — and the two output paths. On a re-entry it also names what the
  re-entry is for and the previous documents (*Re-entry* below).
- **Documents.** Injection is role-minimal and routed via
  `docs/INDEX.md`, never wholesale: the prompt carries a documents line naming the documents the design needs (e.g. the relevant
  `docs/records/adr/*`, `docs/records/design-rationale.md`); the unit reads anything further its
  design needs, by its own judgment.
- **Before the gate (orchestrator-side).** The orchestrator confirms
  `.autoflow/issue-{N}-feature-design.md` and `.autoflow/issue-{N}-verification-design.md` exist
  and are non-empty, the feature design carries its `## Decision requests` section and the
  verification design its `## Tools` section. A missing or empty one is an infrastructure cause:
  the unit is spawned again with the same inputs, consuming no counter. The return is then routed
  (*Report routing* below).

## Output artifacts

1. **Feature Design Document** — `.autoflow/issue-{N}-feature-design.md`, the
   **architecture decision layer** and nothing below it: the decisions, the constraints
   they hold under, and the alternatives considered and rejected with the ground for each rejection.
   It cites the verification design's `Failure mode` column (below) for the failure mode each
   verification exists to catch, rather than stating it.

   **[MUST]** The document carries a `## Scope` section: the cycle's scope beyond the acceptance
   criteria. Each problem judged under
   [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
   judgment* — DIAGNOSE's `## Scope judgments` and any the design found — is listed as
   included or separated, with the conditions it meets and, for a directly related problem left
   out, its separation reason. A section with nothing beyond the criteria says `none`. Scope is a
   decision, settled here, not derived below.

   **[MUST]** The document carries a `## Decision requests` section: each decision the design
   needs that is not the unit's to make, one entry each, written situation-first
   ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > *Human-decision presentation*) —
   - an **acceptance-criterion content change** — excluding, revising or splitting an issue
     acceptance criterion, or adding one: the criterion, the proposed change and the fact that
     shows the need ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion
     decisions*);
   - a **design point** the unit is not confident to settle, or whose choice is not its own
     ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 3): the options and what each changes.

   A design with no such request says `none`. The unit designs on its proposal and states the
   proposal as pending; it never applies an acceptance-criterion change itself.

   **[DENY]** The document does not carry a change table of files, a per-suite disposition, or an
   oracle's condition clause. Those are **derived at BUILD** by the build unit — from
   the change delta, run the way the target runs its tests ([`submodule-common-rules.md`](../submodule-common-rules.md) >
   Verification and Tools > *How a test is run is the target's practice*; on an opted-in target the selector
   answers which committed suites the delta reaches), and from the files the build opens to change anyway. The dividing line is one question: **would this
   sentence being wrong mean the design has to be revisited, or would it just be fixed where it is
   found?** The first belongs to the design; the second does not. A derivation BUILD produces
   under this clause is not acceptance-criterion drift — GATE:QUALITY's Completeness check states
   that exemption explicitly.

2. **Verification Design Document** — `.autoflow/issue-{N}-verification-design.md`. The
   `Issue AC` join key is **not** reduced by the layer split above: the per-criterion disposition is
   a design output. What the split removes from it is depth, not rows: `Method` names the **kind**
   of oracle a row gets, and the condition clause that implements it is BUILD's. The table's columns
   are what the downstream readers need — GATE:PLAN's AC-authority check joins on `Issue AC`, the
   AUDIT evaluator reads `Kind` for its test-first judgment, GATE:QUALITY reads `Type`, and HANDOFF carries each reduced disposition and its
   `Reason` into the PR body; how each row is reached is the unit's.

| Issue AC | Acceptance criterion | Type | Kind | Method | Failure mode | Reason |
|----------|----------------------|------|------|--------|--------------|--------|
| AC1 | (criterion 1) | automated | driving | pytest / API test / etc. | the defect only this test fails on | — |
| AC2 | (criterion 2) | existing-coverage | — | the schema check that already rejects this shape | a value of the shape this criterion forbids | the check runs on every build |
| AC3 | (criterion 3) | manual | — | AI: `<tool in ## Tools>` — scenario doc; the result compared against the referenced material | the behavior the scenario observes breaking | no executable assertion states it; the AI observes it with the tool `## Tools` records |
| AC4 | (criterion 4) | none | — | — | — | absence costs nothing: the value is read from a sample file the user edits |
| — | (criterion 5) | environment-dependent | — | introduce mock or propose design change | the failure the mock itself can catch (`—` on a design-change request) | — |

- **`Type` is the per-criterion verification disposition**, one of
  `automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
  `none`. An `automated` or `manual` row is `cycle` — executed once, uncommitted under
  `.autoflow/issue-{N}-local/`, its run recorded. **In this repository only**, the same cell also
  carries the row's **layer**: a row is `standing` (committed; CI-registered) when the
  cell names one of D1's closed tokens in the form `automated / standing: <token>`
  (`manual / standing: <token>`); the token list is ADR-0024 D1's and is not copied here, and a
  token outside it is a layer violation ([`evaluation-system.md`](../evaluation-system.md) > GATE:QUALITY > *Test quality — layer violation*). On a
  target the cell carries no layer token ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *What a cycle
  leaves in the target's tree*). `Kind`
  applies to `automated` rows only (`driving` / `regression` / `characterization`). Both
  vocabularies, and when each disposition is the right answer, are defined once at *Test necessity*
  below.
- **`Issue AC` is the join key.** Each row's value is either an `AC id` from the
  `## Acceptance criteria` table in `.autoflow/issue-{N}-analysis.md`, or `—` for a criterion this
  verification design added on its own. **[MUST]** Every AC id in that table gets a row, and a
  criterion the design verifies by anything other than an automated test keeps its row, states that
  disposition, and states its `Reason` in one line — the row is never deleted. A design-added
  criterion (`—`) is never a finding and owes no reason; each problem the feature design's
  `## Scope` section includes gets one.
- **`Failure mode` holds each verification's unique failure mode**, and this bullet is the only
  place that obligation is defined. The cell names the defect that makes the row's verification
  fail and that no other verification catches. On an `existing-coverage` row it names what the
  named mechanism fails on, and `Reason` says why no new layer is owed without restating that
  failure. On an `environment-dependent` row resolved to a mock, it names the failure the mock
  itself can catch, not the environment behavior the mock stands in for.
  - **Row grain** — one row per verification: a criterion verified more than one way carries one
    row per verification under the same `Issue AC`, and every other criterion keeps its one row. A
    verification that spans rows carries the same label in `Method` on each of them.
  - **Compared against** — every other distinct verification in the design, and every existing
    mechanism that fails on the same defect: an existing test, a lint rule, a schema, a compiler or
    type check, a build or packaging check. Naming such a mechanism is the `existing-coverage`
    disposition (*Test necessity* below).
  - **[MUST] Owed** on `automated`, `existing-coverage`, `delivery-check` and `manual` rows, and on
    `environment-dependent` rows resolved to a mock or a manual delegation. `none` and
    design-change-request rows carry `—`.
  - **A cell that cannot be filled** — the verification names no defect that another verification
    or mechanism does not already catch — removes that verification from the design.

- For untestable items: first find the tool that verifies the item directly (*Tools* below); only when none can be secured, state the reason and the alternative (design change / a `manual` row executed by a person / mock). When an item is not automatable, consider first whether a feature-design change makes it testable.
- Design-change request: parts of the feature design that should be revised so they become testable.
- Committed-surface allow-list: a manifest-registered source in the change surface pulls
  `setup/manifest.json` in as a derived member of the allow-list (Change Surface Rules > Derived
  artifacts). Under the layer split above this is **derived at BUILD**, from the actual staged
  surface, not predicted here — but it is still derived *before* the commit, never left to a
  test/CI failure to admit.

### Test necessity

A test exists only when it is needed. The burden of proof lies on the test, never on its absence:
not writing a test needs no justification, and a proposed test that cannot answer both judgments
below is not written. This clause decides **existence** only — whether a criterion is verified at
all. Whether a verification **stays in the repository** is decided by ADR-0024 D1's closed
`standing` list and by nothing else: a stated reason, however good, does not move a row out of the
`cycle` layer. This clause is
the policy body; every other document references it rather than restating it.

- **[MUST]** Each proposed verification answers two judgments, in the row that carries it:
  1. **Required behavior** — is this a behavior or contract a consumer actually requires, as
     opposed to an imagined failure mode?
  2. **Cost of absence** — if no verification exists and this breaks after merge, who loses what,
     concretely?
- **[MUST]** When the two judgments cannot both be answered, the disposition is `none`.
- Necessity is a **judgment**, not a classification: no subject is exempt by category and none is
  obligated by category. The two guidance notes below are that judgment applied to two areas —
  they are not separate rules.

**Verification disposition** (the `Type` of each acceptance-criteria row):

| Disposition | Meaning |
|---|---|
| `automated` | an executable test — `cycle` by default (run once from `.autoflow/issue-{N}-local/`, its run recorded), `standing` only with a D1 token in the cell |
| `existing-coverage` | already detected by an existing test, lint rule, schema, compiler/type check, build or packaging check — the row names which |
| `delivery-check` | a one-shot check that the change was wired / generated / delivered — a `cycle` artifact under `.autoflow/issue-{N}-local/`, never committed; the test-first rule does not apply to it |
| `manual` | a scenario verified by observation, not by an executable assertion; `Method` names its executor — `AI: <tool>`, the tool the `## Tools` section records, or `person` only when no tool can be secured, the `Reason` saying why (*Tools* below); the row names the checklist — a `cycle` artifact unless the cell carries a D1 token |
| `environment-dependent` | verifiable only against an environment this cycle cannot drive with the tools the `## Tools` section records |
| `none` | no persistent verification has positive value — the row states why absence costs nothing |

- **[MUST]** Every disposition other than `automated` on an **issue** AC row carries a one-line
  `Reason`. A row for a design-added criterion (`Issue AC` = `—`) is never a finding and needs no
  reason.

**Test kind** (the `Kind` of each `automated` row, and the test-first expectation for it —
[U4 Build and verify](build.md) > *What the build owes*):

| Kind | Meaning | Before the implementation |
|---|---|---|
| `driving` | a required behavior not yet implemented | must FAIL before the implementation |
| `regression` | reproduces a known defect | must FAIL before the fix |
| `characterization` | records existing behavior the change must preserve | may PASS from the start |

**Configuration and data.** A value is not a required behavior; the behavior that consumes it is.
Whether
"production config boots the app" or "every reference resolves" deserves a test is decided by the
two judgments above, not by the subject being data.

**Implementation internals.** A helper name, call order, private branch or internal representation
is not a required behavior. Production code gains no interface, indirection or dependency injection solely to fit
a test shape.

### Verification depth

- **[MUST]** The verification design opens with a **risk line** — one line naming
  who is harmed and how if this change is wrong.
  Depth is justified against that risk, and this clause sets a justification form, never a quantity
  cap: no layer count, file count, or line budget.
- **Per-verification failure mode** — carried by the acceptance-criteria table's `Failure mode`
  column. The column's bullet under *Output artifacts* above defines what the cell names, what it
  is compared against and what a cell that cannot be filled means.
- **[MUST]** State the determination once in the verification design, and restate no
  verification's failure mode anywhere outside the `Failure mode` column; narrative that states no
  per-layer failure mode (a layer removed, depth added) may stay. The obligation is
  unconditional — every verification design has at least one layer — so an absent statement is a
  missing obligation, not a "not applicable". A risk found later raises depth at a re-entry, with
  its reason stated in the delta (*Re-entry* below).

### Tools

The rule is [`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools the work needs*;
this clause is where the verification design applies it. The design opens the materials
the analysis report's `## Referenced materials` section lists ([U2 Analysis](analysis.md) >
*What the analysis owes*) — the material, not the issue body's abbreviated example, is the
design's input — and finds, for each criterion, the tool that verifies it directly **before**
settling it as a `manual` row executed by a person, as `environment-dependent`, or on a mock.

- **[MUST]** The verification design carries a `## Tools` section: one line per tool — the tool,
  the rows it verifies (or the design question it serves), its availability, and the ground the
  availability rests on. Availability is one of `available` (usable in this environment now),
  `target procedure: <document section or script>` (off, and the target carries the procedure that
  starts it), or `operator: <what is needed>` — what is missing for the tool to be used: the tool
  itself when this environment does not have it (an installation, enabling an MCP server or a
  browser extension), what using a tool the environment has lacks (access, the purpose and
  permitted scope of the host or service it reaches, a credential, a permission setting), or access
  to a material. The item names what is missing, never the output the tool would give; a tool the
  environment has, whose use lacks nothing, is `available`. A design that needs no
  tool says `none`, with its ground in one line. AutoFlow names no tool here: which tool, and how
  it is used, is the design's judgment in the target.
- **Availability is settled here, not at BUILD.** After the unit returns, the orchestrator reads
  this section — a targeted excerpt, not a full read ([`CLAUDE.md`](../../CLAUDE.md)
  > Cost Control > *Orchestrator context discipline*) — before GATE:PLAN. An `operator` item is the
  tool request pause ([`CLAUDE.md`](../../CLAUDE.md) > Flow Control > *tool or referenced material →
  user*), presented situation-first, and GATE:PLAN is not spawned until the operator answers. A
  `target procedure` item is started when the phase that uses it begins — by the orchestrator when
  the tool must outlive a role spawn. A tool found missing later, at BUILD, takes the same pause.
- A criterion for which no tool can be secured — what is missing (the tool, or what using it
  lacks) was requested and the operator answers that it cannot be provided, or no tool exists that
  verifies the criterion — keeps the fallbacks of the untestable-items bullet above — a `manual` row executed by a person, or a mock — and its `Reason` states why no
  tool could be secured; GATE:PLAN's `Verification fit` reads that reason.
- The row verified with a tool is looked at with it once implemented, and the evidence is the row's
  observation record, written at BUILD ([U4 Build and verify](build.md) > Build report > `## Manual checklist`).

## Report routing

The orchestrator routes the unit's return. It reads two targeted excerpts — the verification
design's `## Tools` section and the feature design's `## Decision requests` section — and never
reads the design to judge it: the full read-and-score is GATE:PLAN's.

- **An `operator` item in `## Tools`** — the tool request pause (*Tools* above).
- **`## Decision requests` says `none`** — GATE:PLAN (*Verification — GATE:PLAN* below). A
  GATE:PLAN FAIL re-runs the unit (*Re-entry* below); that is the existing
  `GATE:PLAN FAIL → ARCHITECT (max 3×)` re-entry.
- **An acceptance-criterion content change is requested.** Excluding, revising or splitting an
  issue acceptance criterion, or adding one, is never the design's: the advisor decides first and
  the operator may override at the retry stage ([`role-contracts.md`](../role-contracts.md) >
  Advisor). The orchestrator writes the advisor request situation-first from the section's entry,
  naming the affected criteria and what the design proposes for each, and does not spawn GATE:PLAN
  until the advisor's `[ac-decision]` entries — one per decided AC in the grammar at
  [`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions* — are recorded;
  on `revised`, `split` or `added`, it edits the analysis report's acceptance-criterion table to match. It then
  continues to GATE:PLAN where the answer is the design's proposal, or re-runs the unit on the
  `[ac-decision]` entries where it differs (*Re-entry* below). Neither consumes ARCHITECT re-entry
  budget.
- **A design point is requested.** The orchestrator hands it to the advisor situation-first; the
  answer is an `A` ledger entry. Where the answer is the option the design took, GATE:PLAN follows;
  otherwise the unit re-runs on the answer (*Re-entry* below). Neither consumes a counter.
- **An acceptance-criterion change raised later in the cycle.** The BUILD unit, when its work shows a
  criterion defective — a fact it presumes that does not hold, or a scope too narrow or too wide for
  the problem ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*) —
  raises it in its report with the criterion, the proposed change and the fact that shows the need
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*); a gate recommendation reaches the same point through the triage
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*). The orchestrator hands it to the
  advisor situation-first; the advisor's entries use the same grammar with the phase the change
  surfaced in, and the orchestrator edits the analysis report's table on `revised`, `split` or `added`. Where
  the cycle then re-enters is the orchestrator's judgment, recorded with its grounds in an `O`
  ledger entry: at ARCHITECT, a unit re-run naming the `[ac-decision]` entries, when a
  verification-design row must be added or rewritten — then GATE:PLAN's re-entry re-score and BUILD;
  at BUILD when only the implementation changes; otherwise at the point the question arose. A return to ARCHITECT on this ground
  consumes no re-entry budget.

**What the advisor is asked, and what it is not.** A reduction in *verification method* — an AC
verified by an existing mechanism, a manual scenario, a delivery check, or by nothing at all — is a
verification-method choice, not a change to the criterion. It passes three tiers, and only the third
is the advisor (the operator by override at the retry stage):

1. **Design (ARCHITECT).** The design unit chooses any disposition in the *Test necessity*
   vocabulary for an issue AC, **with its reason stated in that row**; GATE:PLAN scores the reason.
2. **External reviewer (HANDOFF).** Every reduced disposition and its reason is carried into the host
   PR body ([U6 Delivery](delivery.md) > *Push and pull request*), so the reviewer judges each one on its stated reason.
3. **Advisor, then operator.** The advisor is asked when the AC's **content** must change — at
   ARCHITECT or later in the cycle
   (*An acceptance-criterion change raised later in the cycle* above). The options offered are
   exactly these: exclude the criterion, revise it in the proposed form, split it into a separate
   issue, or add a criterion the issue did not state.

Whether a row verifies the property its AC states is not a tier-3 question — that judgment belongs
to GATE:PLAN `Verification fit` and to GATE:QUALITY's assertion-claim alignment.

## Verification — GATE:PLAN

One fresh Evaluation AI (`autoflow-evaluator`, the model
`bash scripts/spawn-policy/spawn-policy.sh model gate-plan` names) scores the two documents on the
rubric of [`evaluation-system.md`](../evaluation-system.md) > *Gate rubrics* > GATE:PLAN. Its
documents line names that document alone.

- **PASS** (avg ≥ 7.5, each ≥ 7) → recommendation triage
  ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) → BUILD.
- **FAIL** → ARCHITECT (max 3×): a fresh U3 Design unit receives this report and the previous
  documents (*Re-entry* below).

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-design` by
*Unit spawn* above, whose prompt names what the re-entry is for, the material that carries it, and
the previous documents.

| Re-entry | Material named | Counter |
|---|---|---|
| GATE:PLAN FAIL | the evaluation report and its failed items | ARCHITECT re-entry (max 3×) |
| advisor answer that differs from the design (*Report routing*) | the `[ac-decision]` or `A` entries | none |
| BUILD design contradiction | `.autoflow/issue-{N}-green-blocker.md` | ARCHITECT re-entry |
| `design` re-entry from GATE:QUALITY or HANDOFF's CI failure | the failed items and their findings | ARCHITECT re-entry |
| acceptance-criterion decision raised after ARCHITECT | the `[ac-decision]` entries | none |
| `design`-class gate recommendation at AUDIT or GATE:QUALITY ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) | the recommendation's subject and finding | ARCHITECT re-entry |

- **[MUST] A re-entry's output is a delta, never a rewrite.** The first unit run of a cycle writes
  the two documents whole. A re-entry within the cycle **appends** to each document it changes a
  section

  ```
  ## Delta — round <n> (<origin: GATE:PLAN FAIL | advisor answer | BUILD design contradiction | design re-entry | acceptance-criterion decision | gate recommendation>)

  - <what changed>: <the decision as it now stands> — supersedes <the section or decision it replaces>
  - <what was added>: <the decision> — <ground>
  ```

  and leaves text the round did not change exactly as it stands. A delta item that corrects a
  decision under the verified-error exception ([`decision-ledger.md`](../decision-ledger.md) >
  Entries) also carries the reproducing command and its summary line. Two sections are the exception:
  the feature design's `## Decision requests` and the verification design's `## Tools` are the
  orchestrator's routing inputs, not decisions, so a re-entry rewrites each in place to its current
  state — a request the advisor has answered is removed (its answer is the ledger entry), a new one
  is added, and `none` means none is open. The delta section is GATE:PLAN's
  narrowed input on re-entry ([`evaluation-system.md`](../evaluation-system.md) > GATE:PLAN >
  *Re-entry re-score*); a re-entry after
  BUILD began re-scores that delta and the cycle re-enters BUILD.
- **A new cycle writes new documents.** A review-response cycle entered at PREFLIGHT finds the
  previous cycle's documents preserved as `issue-{N}-c{C}-feature-design.md` / `issue-{N}-c{C}-verification-design.md`
  ([U1 Preparation](preparation.md) > *Review-response setup*); the prompt names them and
  what the new cycle is for, and the unit writes the new cycle's documents whole. How much
  of the previous cycle's design the new one carries over is the unit's own, recorded in the design.

The unit reads and writes no `.autoflow/issue-{N}.json` state file, so the ARCHITECT re-entry
counter is the orchestrator's own accounting (Regressions, [`CLAUDE.md`](../../CLAUDE.md) >
Development Lifecycle).
