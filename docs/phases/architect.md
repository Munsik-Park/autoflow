# ARCHITECT — Plan Synthesis (Developer AI + Test AI)

> Phase playbook for ARCHITECT. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

Both perspectives participate. The discussion is a **relay the orchestrator runs between two
persistent participants** — the Developer AI and the Test AI, each spawned once for the discussion
and woken by agent ID for each of its turns — and its whole record is one
file, `.autoflow/issue-{N}-architect-transcript.md`, which every turn is appended to. The discussion
has three phases: **Discuss** and **Report** are the relay; **Record** is the
`Workflow` named `architect-deliberation`, which reads the transcript file and writes the artifacts.
The orchestrator relays but does not deliberate: it reads one line per turn and the transcript's
decidable state, never a turn body (Deliberation Isolation).

**Discuss** is the relay. The Developer AI opens with a design proposal, the Test AI answers it, and
the two alternate. Each participant holds one fixed prompt for its role
(`.claude/agents/autoflow-planner.md` > *ARCHITECT relay participant*) and reads the topic once from
the transcript file's `## Topic` section; its context is its memory across turns, and the file is
the record the other side reads. The design documents are written after the discussion. Each turn's heading carries whether the author has anything further to
raise (`[further: yes|none]`), and the discussion ends when two consecutive turns both say
`none` — the participants' own conclusion ends it; `scripts/architect/relay-state.sh state`
computes that condition and the next side, and the orchestrator obeys it. The Discussion
Protocol's VERIFY step applies over the transcript: a fact the transcript cites with
a `path:line` (read at the cycle's commit) or a document's section and quoted sentence is verified for both participants, and a participant reads a file to ground a claim
of its own or to dispute a cited one.

**Report** is one more wake per participant: each appends its reading of the discussion to the
transcript under `## Report — <side>` — the design conclusions both accepted, and each point it
considers worth raising to the orchestrator, with both positions and why it is worth raising.
**Record** is the `Workflow`: one scribe reads the transcript file — topic, turns, any brief, both
reports — and writes the feature design, the verification design and the report from those
conclusions, followed by a ledger call that appends the agreed conclusions under the authority
`ARCHITECT agreed`. Invocation: `Workflow({ name: "architect-deliberation", args: { issue: "N" } })`.

The run returns `{ report: { agreed, unagreed[] }, artifacts, transcript, ledger, summary, stopped }`.
The orchestrator receives that object and routes it (*Report routing* below); it does not receive
the turns or the reports' bodies. It **verifies** what the report rests on by spot-checking targeted
artifact excerpts against re-derived facts — the full read-and-score is GATE:PLAN's. Isolation rule:
[`CLAUDE.md`](../../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation;
contract: [`role-contracts.md`](../role-contracts.md) > Facilitator.

### Relay procedure (orchestrator)

Every spawn below declares `subagent_type: autoflow-planner` and the model the readout names
(`bash scripts/spawn-policy/spawn-policy.sh model architect-dev-participant` /
`… architect-test-participant`), and every wait is a **turn end** ([`CLAUDE.md`](../../CLAUDE.md) >
Execution Principles > *Wait discipline*): the participant's one-line answer arrives as the task
notification of that resumed spawn, and nothing is polled.

1. **Transcript.** `bash scripts/architect/relay-state.sh init .autoflow/issue-{N}-architect-transcript.md {N} ["<brief>"]`
   writes the header — the topic stated once, naming the issue's inputs and the ledger's settled
   authorities; a brief given here is carried into the topic. The file is append-only from this
   point: `init` refuses an existing file.
2. **Spawn the Developer AI** (`Agent`, anonymous, no `name`) with a prompt that names it *the
   Developer AI participant of the ARCHITECT relay for issue #{N}*, the transcript path, and
   *write Turn 1*. Keep the agent ID the spawn result returns. End the turn.
3. **On the notification**, read only the one line it carries, then run
   `bash scripts/architect/relay-state.sh state <transcript>` and act on `next`:
   `test` → spawn the Test AI the same way on its first turn (*write Turn 2*; keep its ID) or, on a
   later turn, `SendMessage` to its ID with *write Turn n*; `dev` → `SendMessage` to the Developer
   AI's ID with *write Turn n*; end the turn after each wake. A `state` exit 1 (a malformed heading,
   a mis-numbered turn) is a transcript defect: re-wake the author with the cause and *re-append
   Turn n correctly*. A wake whose notification arrives with `turns` unchanged is a **missing
   turn**: re-wake that side once with *your Turn n was not appended*; a second miss is the
   infrastructure state `participant missing` — repair (a fresh spawn of that side, pointed at the
   transcript) and continue.
4. **`next=report`.** Wake both participants (in one turn) with *the discussion has ended — append
   your report*; end the turn; when both notifications are in, run `state` again. A side named in
   `reports_missing` is re-woken once; if it is still missing, continue — the scribe records that
   side's positions from its turns.
5. **`next=record`.** Invoke the Record workflow. On its return, run the artifact-existence check
   below and route the report (*Report routing*).
6. **Isolation and lifetime.** The participants are not woken again after the Record workflow
   returns, except for a re-discussion (*Re-discussion* below). The orchestrator never reads the
   transcript's turn bodies.

**Artifact-existence check (orchestrator-side).** Before GATE:PLAN the orchestrator confirms the
three artifacts the scribe writes exist and are non-empty — `.autoflow/issue-{N}-feature-design.md`,
`.autoflow/issue-{N}-verification-design.md` and `.autoflow/issue-{N}-architect-report.md` — and
treats a missing or empty one — or a verification design without its `## Tools` section
(*Tools* below) — as an infrastructure cause to repair and re-run, rather than proceeding.

**Document injection (ARCHITECT onward).** Past DIAGNOSE the Phase A ↔ Phase B isolation does not apply. Injection is still **role-minimal and routed via `docs/INDEX.md`**, never wholesale: the spawn prompt names each participant only the documents its design task needs (e.g. the relevant `docs/records/adr/*`, `docs/records/design-rationale.md`), and the participant reads them once. **Deliberation Isolation is unchanged** — the turns live in the transcript file and only the Record workflow's report returns to the orchestrator.

**Roles**:
- **Developer AI**: feature design (changed files, API interface, data structures).
- **Test AI**: verification design (acceptance criteria → verification method, testability assessment, and the tools each criterion needs — *Tools* below).

## Output artifacts

1. **Feature Design Document** (Developer-AI-led) — `.autoflow/issue-{N}-feature-design.md`, the
   **architecture decision layer** and nothing below it: the decisions, the constraints
   they hold under, and the alternatives considered and rejected with the ground for each rejection.
   It cites the verification design's `Failure mode` column (below) for the failure mode each
   verification exists to catch, rather than stating it. The deliberation stops here.

   **[MUST]** The document carries a `## Scope` section: the cycle's scope beyond the acceptance
   criteria. Each problem the deliberation judged under
   [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
   judgment* — DIAGNOSE's `## Scope judgments` and any the participants found — is listed as
   included or separated, with the conditions it meets and, for a directly related problem left
   out, its separation reason. A section with nothing beyond the criteria says `none`. Scope is a
   decision, settled here, not derived below.

   **[DENY]** The document does not carry a change table of files, a per-suite disposition, or an
   oracle's condition clause. Those are **derived at RED/GREEN entry** by the execution roles — from
   the change delta, run the way the target runs its tests ([`submodule-common-rules.md`](../submodule-common-rules.md) >
   Verification and Tools > *How a test is run is the target's practice*; on an opted-in target the selector
   answers which committed suites the delta reaches), and from the files those roles open to change anyway. The dividing line is one question: **would this
   sentence being wrong mean the design has to be revisited, or would it just be fixed where it is
   found?** The first belongs to the deliberation; the second does not. A derivation RED produces
   under this clause is not acceptance-criterion drift — GATE:QUALITY's Completeness check states
   that exemption explicitly.

2. **Verification Design Document** (Test-AI-led) — the `Issue AC` join key is **not** reduced by
   the layer split above: the per-criterion disposition is a deliberation output. What the split removes from it is depth, not rows: `Method` names the **kind** of oracle
   a row gets, and the condition clause that implements it is RED's.

| Issue AC | Acceptance criterion | Type | Kind | Method | Failure mode | Reason |
|----------|----------------------|------|------|--------|--------------|--------|
| AC1 | (criterion 1) | automated | driving | pytest / API test / etc. | the defect only this test fails on | — |
| AC2 | (criterion 2) | existing-coverage | — | the schema check that already rejects this shape | a value of the shape this criterion forbids | the check runs on every build |
| AC3 | (criterion 3) | manual | — | AI: `<tool in ## Tools>` — scenario doc; the result compared against the referenced material | the behavior the scenario observes breaking | no executable assertion states it; the AI observes it with the tool `## Tools` records |
| AC4 | (criterion 4) | none | — | — | — | absence costs nothing: the value is read from a sample file the user edits |
| — | (criterion 5) | environment-dependent | — | introduce mock or propose design change (except where the composition-oracle clause applies) | the failure the mock itself can catch (`—` on a design-change request) | — |

- **`Type` is the per-criterion verification disposition**, one of
  `automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
  `none`. An `automated` or `manual` row is `cycle` — executed once, uncommitted under
  `.autoflow/issue-{N}-local/`, its run recorded. **In this repository only**, the same cell also
  carries the row's **layer**: a row is `standing` (committed; CI-registered) when the
  cell names one of D1's closed tokens in the form `automated / standing: <token>`
  (`manual / standing: <token>`); the token list is ADR-0024 D1's and is not copied here, and a
  token outside it is a layer violation ([GATE:QUALITY](gate-quality.md) > *Test quality — layer violation*). On a
  target the cell carries no layer token ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *What a cycle
  leaves in the target's tree*). `Kind`
  applies to `automated` rows only (`driving` / `regression` / `characterization`). Both
  vocabularies, and when each disposition is the right answer, are defined once at *Test necessity*
  below.
- **`Issue AC` is the join key.** Each row's value is either an `AC id` from the
  `## Acceptance criteria` table in `.autoflow/issue-{N}-phase-b.md`, or `—` for a criterion this
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
  itself can catch, not the environment behavior the mock stands in for. On a composition-oracle
  row, it names the composition-time behavior at the traced identifier that the mock-boundary check
  does not catch (*Composition oracle* below).
  - **Row grain** — one row per verification: a criterion verified more than one way carries one
    row per verification under the same `Issue AC`, and every other criterion keeps its one row. A
    verification that spans rows carries the same label in `Method` on each of them.
  - **Compared against** — every other distinct verification in the design, and every existing
    mechanism that fails on the same defect: an existing test, a lint rule, a schema, a compiler or
    type check, a build or packaging check. Naming such a mechanism is the `existing-coverage`
    disposition (*Test necessity* below).
  - **[MUST] Owed** on `automated`, `existing-coverage`, `delivery-check` and `manual` rows, on
    `environment-dependent` rows resolved to a mock or a manual delegation, and on composition-oracle
    rows. `none` and design-change-request rows carry `—`.
  - **A cell that cannot be filled** — the verification names no defect that another verification
    or mechanism does not already catch — removes that verification from the agreement rather than
    being argued down. A composition oracle is a floor and is never removed on
    this ground.

- For untestable items: first find the tool that verifies the item directly (*Tools* below); only when none can be secured, state the reason and the alternative (design change / a `manual` row executed by a person (except where the composition-oracle clause applies) / mock (same exception)).
- Design-change request: parts of the feature design that should be revised so they become testable.
- Committed-surface allow-list: a manifest-registered source in the change surface pulls
  `setup/manifest.json` in as a derived member of the allow-list (Change Surface Rules > Derived
  artifacts). Under the layer split above this is **derived at GREEN**, from the actual staged
  surface, not predicted here — but it is still derived *before* the commit, never left to a
  test/CI failure to admit.

3. **Deliberation report** (scribe-written): `.autoflow/issue-{N}-architect-report.md`, under the
   headings `## Agreed` — one line per conclusion both participants accepted — and `## Unagreed` —
   per point, the point, the Developer AI's position, the Test AI's position, and why it was
   raised. This is the artifact the orchestrator routes (*Report routing* below).

### Record

The scribe writes the three artifacts after the discussion, from the transcript file and the two
reports of its last round (a re-discussion opens a new round with a `### Brief` block and ends with
its own two reports; the earlier round's reports stay on the record). The two design documents state the design and the conclusions the participants
reached, in the form each is defined above; the report states what was agreed and what was not.

**[MUST] A re-discussion's Record is a delta, never a rewrite**. On the **first**
Record of a cycle the scribe writes the documents whole. On every Record after that it reads the
existing documents plus **only the turns appended since the previous Record** and both reports of
this round — not the accumulated transcript — and **appends** a delta section rather than
re-authoring the body:

```
## Delta — round <n> (<brief origin: GATE:PLAN FAIL | un-agreed re-discussion | VERIFY design contradiction | design re-entry | acceptance-criterion decision | gate recommendation>)

- <what changed>: <the decision as it now stands> — supersedes <the section or decision it replaces>
- <what was added>: <the decision> — <ground>
```

Text a round did not change is **left exactly as it stands**. The delta section is also GATE:PLAN's
narrowed input on re-entry ([GATE:PLAN](gate-plan.md) > *Re-entry re-score*).
The transcript file is the discussion's own record and is read only by the participants and the
scribe; the Record workflow's report is what reaches the orchestrator. See
[`role-contracts.md`](../role-contracts.md) > Facilitator > Return Contract.

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
| `delivery-check` | a one-shot check that the change was wired / generated / delivered — a `cycle` artifact under `.autoflow/issue-{N}-local/`, never committed; RED/GREEN semantics do not apply to it |
| `manual` | a scenario verified by observation, not by an executable assertion; `Method` names its executor — `AI: <tool>`, the tool the `## Tools` section records, or `person` only when no tool can be secured, the `Reason` saying why (*Tools* below); the row names the checklist — a `cycle` artifact unless the cell carries a D1 token |
| `environment-dependent` | verifiable only against an environment this cycle cannot drive with the tools the `## Tools` section records (except where the composition-oracle clause applies) |
| `none` | no persistent verification has positive value — the row states why absence costs nothing |

- **[MUST]** Every disposition other than `automated` on an **issue** AC row carries a one-line
  `Reason`. A row for a design-added criterion (`Issue AC` = `—`) is never a finding and needs no
  reason.

**Test kind** (the `Kind` of each `automated` row, and the RED expectation for it):

| Kind | Meaning | RED |
|---|---|---|
| `driving` | a required behavior not yet implemented | must FAIL before GREEN |
| `regression` | reproduces a known defect | must FAIL before the fix |
| `characterization` | records existing behavior the change must preserve | may PASS from the start |

**Configuration and data.** A value is not a required behavior; the behavior that consumes it is.
Whether
"production config boots the app" or "every reference resolves" deserves a test is decided by the
two judgments above, not by the subject being data.

**Implementation internals.** A helper name, call order, private branch or internal representation
is not a required behavior. Production code gains no interface, indirection or dependency injection solely to fit
a test shape.

- The dispositions and reasons are the Test AI's to author, and the ARCHITECT facilitator may
  record them on the Test AI's behalf when it writes the verification design.

### Verification depth

- **[MUST]** The verification design opens with a **risk line** — one line naming
  who is harmed and how if this change is wrong.
  Depth is justified against that risk, and this clause sets a justification form, never a quantity
  cap: no layer count, file count, or line budget.
- **Per-verification failure mode** — carried by the acceptance-criteria table's `Failure mode`
  column. The column's bullet under *Output artifacts* above defines what the cell names, what it
  is compared against and what a cell that cannot be filled means.
- **Amendment** — a risk discovered mid-deliberation may raise depth, provided the reason is
  stated in the discussion and carried into the verification design. Depth is revisable, not
  capped, and the amendment adds no artifact (*Record* above).
- **[MUST]** State the determination once in the verification design, and restate no
  verification's failure mode anywhere outside the `Failure mode` column; narrative that states no
  per-layer failure mode (a layer removed, depth added) may stay. The obligation is
  unconditional — every verification design has at least one layer — so an absent statement is a
  missing obligation, not a "not applicable".
- The determination is the Test AI's to author, and the ARCHITECT facilitator may record it on the
  Test AI's behalf when it writes the verification design.

### Composition oracle

- **[MUST]** When the design's change surface names shared state that a **settled decision** also
  names, the verification design must assign at least one oracle that drives that contact point
  through the **real execution environment** — no mock, stub, fake, or simulation may stand in for the shared state.
- **Trigger** — a set intersection, not a judgment. Let `T` be the set of shared-state identifiers named by the design's change surface,
  and `S` the set of shared-state identifiers referenced by the governing settled decisions; the clause
  fires when `T ∩ S ≠ ∅`. One oracle is owed **per element** of `T ∩ S`. A single oracle may discharge
  several elements, provided every element is traced by some oracle — each oracle's row carries the
  intersecting identifier(s) as its trace.
- **Settled decision** — an accepted or proposed ADR under `docs/records/adr/`, a prior issue's agreed
  design, or an entry in this issue's decision ledger (`.autoflow/issue-{N}-ledger.md`).
- **Shared state** — state that outlives a single call and that more than one decision reads or
  writes. The obligation binds to no concrete realization; the following are examples only: e.g. a
  datastore collection or field and the query layer over it, a hardware register or firmware
  setting, a file-format field, a wire-protocol field, a shared memory region.
- **[MUST]** Record the determination once in the verification design, as one `composition-oracle`
  block, and attach the output of `scripts/architect/composition-oracle.sh` run over the written
  file — its stdout and its exit status, both exactly as the shell produced them, never re-typed.
  The Test AI identifies `T` and `S`; the scribe records the block at Record, runs the
  script over the verification design it has just written, and runs it again in a delta round that
  restates the block. This clause is the grammar's only definition — the script and the Record
  prompt cite it:

  ```composition-oracle
  T:
  - <identifier> | <source>
  S: none | <one-line ground>
  ```

  - **Lists** — the label `T:` once and `S:` once, each followed by its entries, one per line:
    `- <identifier> | <source>`. The identifier is one whitespace-free token and matches exactly —
    whether two spellings name one item is the author's call, made by using one identifier for it in
    both lists. A `T` entry's source is the design decision that names the shared state; an `S`
    entry's source is the settled decision, as an ADR path, a prior issue id or a ledger entry id.
  - **An empty list is declared, never implied** — `T: none | <one-line ground>`. A label with
    neither entries nor that declaration, a declaration without its ground, and a declaration
    together with entries each leave the list unestablished.
  - **Delta rounds** — a round that changes `T` or `S` restates the whole block as the payload of
    one `supersedes` bullet in its delta section (*Record* above). The script evaluates the
    **latest** block in document order, never falls back to an earlier one, and names the block it
    evaluated: `evaluated: base`, or `evaluated: round <n>` for the delta round the block sits in.
  - **Outcomes** — `intersection`: exit status `10` with `result: intersection`, the intersecting
    identifiers (the traces the oracle rows carry) on the `intersecting:` line; `empty`: exit
    status `11` with `result: empty`; and `unknown/error` with its `cause:`. An outcome holds only
    when the exit status and the `result:` line agree — any other status, a missing `result:` line,
    or a line and status that disagree is `unknown/error`. An absent or unreadable file, a missing
    block or list, an unestablished list, an entry without an identifier or a source, and a
    malformed latest block are `unknown/error`, never `empty`.
  - **Reading** — an absent statement is not read as "not triggered", and neither is an absent
    output, an `unknown/error` output, or an attached `result:` line and exit status that disagree:
    each is a missing determination. When a delta round attaches a new output, the latest attached
    output governs; an earlier attachment stays as settled text and no longer reproduces on a
    re-run. `empty` establishes that the recorded sets do not meet, not that the lists are complete.
  - **Residual** — two cases rest on the reader alone. No layer verifies that a reader applies the
    rule above to a disagreeing line and status. And a restated block whose fence or delta heading
    the script does not recognise leaves an earlier block evaluated with no error: a stale `empty`
    is then visible only as an `evaluated:` field naming an earlier block than the round that
    restated it, so the reader compares the two.
- When no such oracle can be built, that is a **design-change request** (the bullet above), not a
  manual-scenario fallback and not a mock. This clause narrows the untestable-items bullet and the
  table's environment-dependent row above for triggered composition contact points; both keep
  offering mock or manual delegation for every other untestable item.
- **Complements, does not replace, the VERIFY mock-boundary check.** Step 4's
  `Mock-boundary fidelity check (Test AI)` compares a double's *shape* against the real interface;
  this clause covers **composition-time behavior** — what the change does when it meets the real
  state a settled decision contracted over.

### Tools

The rule is [`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools the work needs*;
this clause is where the verification design applies it. The participants open the materials
Phase B's `## Referenced materials` section lists ([`phases/analysis.md`](analysis.md) >
per-role injection whitelist) — the material, not the issue body's abbreviated example, is the
design's input — and the Test AI finds, for each criterion, the tool that verifies it directly
**before** settling it as a `manual` row executed by a person, as `environment-dependent`, or on a
mock.

- **[MUST]** The verification design carries a `## Tools` section: one line per tool — the tool,
  the rows it verifies (or the design question it serves), its availability, and the ground the
  availability rests on. Availability is one of `available` (usable in this environment now),
  `target procedure: <document section or script>` (off, and the target carries the procedure that
  starts it), or `operator: <what is needed>` (an installation, a credential, a permission setting,
  enabling an MCP server or a browser extension, access to a material). A design that needs no
  tool says `none`, with its ground in one line. AutoFlow names no tool here: which tool, and how
  it is used, is the participants' judgment in the target.
- **Availability is settled here, not at VERIFY.** After the Record workflow returns, the
  orchestrator reads this section — a targeted excerpt, not a full read ([`CLAUDE.md`](../../CLAUDE.md)
  > Cost Control > *Orchestrator context discipline*) — before GATE:PLAN. An `operator` item is the
  tool request pause ([`CLAUDE.md`](../../CLAUDE.md) > Flow Control > *tool or referenced material →
  user*), presented situation-first, and GATE:PLAN is not spawned until the operator answers. A
  `target procedure` item is started when the phase that uses it begins — by the orchestrator when
  the tool must outlive a role spawn. A tool found missing later, at RED, GREEN or VERIFY, takes
  the same pause.
- A criterion no tool can reach after this search keeps the fallbacks of the untestable-items
  bullet above — a `manual` row executed by a person, or a mock — and its `Reason` states why no
  tool could be secured; GATE:PLAN's `Test plan` reads that reason.
- The row verified with a tool is looked at with it once implemented: the Developer AI looks at its
  own result while implementing (GREEN step 2), and the evidence — the row's observation record —
  is the Test AI's, written at VERIFY step 1.

## Testability-driven design

When the Test AI flags an item as "not automatable", the team discusses whether a feature-design change makes it testable. If not, the item stays as a manual scenario with a stated reason — executed by the AI with the tool the `## Tools` section records, or by a person only when no tool can be secured (*Tools* above) — except where the composition-oracle clause applies.

## Report routing

The orchestrator receives the report and routes it. The discussion itself runs under the Discussion
Protocol ([`role-common-rules.md`](../role-common-rules.md) > Discussion Protocol), whose
first-exchange devil's advocate carries ADR conformance as one of its axes: the resolution is
checked against any governing ADR. That is the first, non-gated approach check, and GATE:PLAN is
the gated one.

- **`stopped` is non-null.** The record could not be carried out — the scribe was missing, or the
  spawn policy would not load. Repair the cause and re-run the Record workflow. This is infrastructure state, never a design outcome, and it consumes no counter; its
  relay-side counterpart is a participant that appends no turn after one re-wake (*Relay
  procedure* step 3).
- **No un-agreed point.** The design is the participants' joint conclusion. Run the
  artifact-existence check and read the verification design's `## Tools` section — an `operator`
  item is the tool request pause (*Tools* above) — then GATE:PLAN (a fresh Evaluation AI on the 5-item rubric of [GATE:PLAN](gate-plan.md)). A
  GATE:PLAN FAIL re-enters the deliberation with a brief (*Re-discussion* below); that is the
  existing `GATE:PLAN FAIL → ARCHITECT (max 3×)` re-entry.
- **An un-agreed point.** One judgment, and it is the orchestrator's: discuss further, or stop.
  - **Discuss further** — prepare what the next discussion needs and append it as the `brief`
    (*Re-discussion* below). A preparation may carry the un-agreed points as a narrowed topic, a
    fact the orchestrator verified in the meantime (`path:line` at a commit SHA, command output), the prior
    report's path, or a different perspective for a participant to take. Record the judgment as an
    `O` ledger entry — decision and grounds, authority `orchestrator judgment`. A re-discussion
    after an un-agreed report is not a GATE:PLAN re-entry and consumes no re-entry counter.
  - **Stop** — report situation-first ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles >
    Human-decision presentation), set `active: false`, `phase: "awaiting-user"`. The user's
    decision drives re-entry.
- **An agreed conclusion changes an acceptance criterion's content.** Excluding, revising or
  splitting an issue acceptance criterion, or adding one, is the operator's authority. Report
  situation-first naming the affected criteria and what the design proposes for each, set
  `active: false`, `phase: "awaiting-user"`, and do not spawn GATE:PLAN. Record the answer as one
  `[ac-decision]` ledger entry per decided AC in the grammar at [`decision-ledger.md`](../decision-ledger.md) >
  *Acceptance-criterion decisions*; on `revised`, `split` or `added`, edit the
  Phase B acceptance-criterion table to match; then continue to GATE:PLAN. The pause consumes no
  ARCHITECT re-entry budget.
- **An acceptance-criterion change raised later in the cycle.** A role at GREEN, VERIFY or REFINE whose work shows a
  criterion defective — a fact it presumes that does not hold, or a scope too narrow or too wide for
  the problem ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*) —
  raises it in its report with the criterion, the proposed change and the fact that shows the need
  ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*); a gate recommendation reaches the same point through the triage
  ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*). The orchestrator reports it situation-first, sets
  `active: false`, `phase: "awaiting-user"`, and records the answer in the same grammar with the
  phase the change surfaced in, editing the Phase B table on `revised`, `split` or `added`. Where
  the cycle then re-enters is its judgment, recorded with its grounds in an `O` ledger entry: at
  ARCHITECT, on a `brief` naming the `[ac-decision]` entries, when a verification-design row must be
  added or rewritten — then GATE:PLAN's re-entry re-score and RED; at GREEN when only the
  implementation changes; otherwise at the point it paused. A return to ARCHITECT on this ground
  consumes no re-entry budget.

**What the operator is asked, and what they are not.** A reduction in *verification method* — an AC
verified by an existing mechanism, a manual scenario, a delivery check, or by nothing at all — is a
verification-method choice, not a change to the criterion. It passes three tiers, and only the third
is the operator:

1. **Deliberation (ARCHITECT).** The deliberation chooses any disposition in the *Test necessity*
   vocabulary for an issue AC, **with its reason stated in that row**. A weak reason is argued down
   here and never leaves the deliberation.
2. **External reviewer (HANDOFF).** Every reduced disposition and its reason is carried into the host
   PR body (HANDOFF step 4), so the reviewer judges each one on its stated reason.
3. **Operator.** Asked when the AC's **content** must change — at ARCHITECT or later in the cycle
   (*An acceptance-criterion change raised later in the cycle* above). The options offered are
   exactly these: exclude the criterion, revise it in the proposed form, split it into a separate
   issue, or add a criterion the issue did not state.

Whether a row verifies the property its AC states is not a tier-3 question — that judgment belongs
to GATE:PLAN `Test plan` and to GATE:QUALITY's assertion-claim alignment.

## Re-discussion

A re-discussion continues the same transcript: the orchestrator appends its preparation with
`bash scripts/architect/relay-state.sh brief <transcript> "<preparation>"` — a `### Brief` block,
which re-opens the end condition and starts a new round (`relay-state.sh state` reports `round`,
and counts report sections per round) — and resumes the relay at step 3 of the *Relay procedure*:
the turn numbering and the alternation continue, and the participants answer the brief as they
would a turn. The brief may follow the previous round's two report sections: a GATE:PLAN FAIL
re-entry and an un-agreed re-discussion both continue the same file after a Record. Both are
re-discussions **inside the cycle that spawned the participants**, and only there are the
participants re-woken: when they are still resumable (the same session), they are re-woken by
their IDs and keep everything they read; when they are not (a session restart), each side is
spawned fresh with the transcript path and the relay continues from there. The Record workflow is invoked again at the end, and the scribe reads the brief where it
sits.

**A return from a later phase of the same cycle spawns the participants fresh on the same
transcript.** A return to ARCHITECT after DISPATCH — a VERIFY design contradiction, a `design`
re-entry from GATE:QUALITY or from HANDOFF's CI failure, an acceptance-criterion decision raised
after ARCHITECT (*Report routing*), or a `design`-class gate recommendation at AUDIT or
GATE:QUALITY ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) — never re-wakes the participants
([`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime). The orchestrator appends the `brief` to the **same** transcript —
naming what the return is for: the blocker report, the failed items and their findings, the
`[ac-decision]` entries, or the recommendation's subject and finding — and spawns each side fresh by step 2 of the
*Relay procedure*, pointed at the transcript; the turn numbering continues. The Record appends a delta section whose origin names the trigger (`VERIFY design
contradiction`, `design re-entry`, `acceptance-criterion decision`, `gate recommendation`), GATE:PLAN
re-scores that delta ([GATE:PLAN](gate-plan.md) > *Re-entry re-score*), and the cycle re-enters RED. The counter is the
trigger's: every one of them consumes the ARCHITECT re-entry counter except an acceptance-criterion
decision.

**A new cycle's re-discussion spawns the participants fresh.** A participant's lifetime is one
cycle's ARCHITECT entry ([`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime), so a re-discussion in a new cycle — a review-response cycle entered at PREFLIGHT, or a
HANDOFF step 6.5 shape (b) re-deliberation — never wakes the previous cycle's participants by
their IDs, whether or not the session is the same. It starts a new transcript (the previous
cycle's is preserved as `issue-{N}-c{C}-architect-transcript.md` at PREFLIGHT with the other
artifacts) whose `init` brief names, next to what the re-discussion is for, the previous cycle's
transcript and report paths (`issue-{N}-c{C}-architect-transcript.md`,
`issue-{N}-c{C}-architect-report.md`), and spawns each side by step 2 of the *Relay procedure*.
The prior discussion reaches the participants as a file they read, not as a context they carry. The brief
in the new transcript's header is the record of the handover.

A brief carries what the next discussion needs — for instance a narrowed topic, facts the
orchestrator verified since the prior run, the prior report's path, a perspective for a participant
to take, or an evaluation to answer. On a GATE:PLAN FAIL re-entry the brief names the two design
documents and the evaluation's failed items. On a scope-bounded review-response cycle ([PREFLIGHT](preflight.md) > *Scope-bounded
entry*) the brief is given at `init` (it enters the topic) and states the bounded scope: the Medium+
finding and the PR diff file set; a fix that adds a file leaves the bounded path, and the
re-discussion runs on the full topic. Either way the cycle's brief sits on its own new transcript
(the new-cycle rule above).

Neither the relay scripts nor the workflow read or write the `.autoflow/issue-{N}.json` state file,
so the ARCHITECT re-entry counter is the orchestrator's own accounting (Regressions,
[`CLAUDE.md`](../../CLAUDE.md) > Development Lifecycle).
