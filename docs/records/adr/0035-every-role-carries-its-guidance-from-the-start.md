# ADR-0035: Every role carries its guidance from the start, as the core parts and the documents it uses

## Status

Accepted (issue #494: the operator's instruction to unify the guidance each role receives and to
compose it, in the modular operation, as the core document plus the documents the stage needs;
the method left to the working session, with the grounds in the pull request). Amends ADR-0027 D2
*The core*, *Other homes* and *Subagents*, ADR-0032 D3 and D4, ADR-0025 D2's "what it reads", and
`docs/tool-delivery-contract.md` R2. D2's session and subagent sets and D5's evaluator set aligned
with the carriers by issue #499, with each carriage's grounds (see Amendment note (issue #499)).

## Context

On main `2e72b1a` (0.3.7) the guidance a role follows reached it in three ways (issue #494 >
확인된 사실):

- **as text** in the carrier it starts with — a command body (the core parts its unit uses,
  ADR-0032), an agent definition (its own short rules);
- **as a path** the role chose whether to open — the unit document a session is told to Read, the
  documents line a unit spawn's prompt carries ("the unit reads anything further by its own
  judgment"), the evaluator's `docs/evaluation-system.md`, the reviewers' rule files the wrapper
  names by absolute path;
- **not at all** — the design and build units had no carrier that named
  `docs/submodule-common-rules.md` > Change Surface Rules, the unit agents and the advisor had
  none that named `docs/role-common-rules.md`, and every agent definition carried only the first
  sentence of the core's Instruction Conventions and none of Rule Scope.

The clauses that made it so were delivery clauses: ADR-0027 D2 > *Subagents* ("It names, by path
under that root, the sections it is bound by"), `docs/core.md` > Context Injection ("what a unit
reads beyond it is its own judgment"), the Unit Document Loading Contract's Read on entry, the
unit documents' *Documents* items, `docs/role-contracts.md` > Evaluation AI Prompt Rules 1–2 and
> Functional-unit agents ("and nothing else"), R2's closed list, `docs/evaluation-system.md` >
*What it reads*, `docs/reviewer-backend.md` > Rule files, `docs/INDEX.md`, and the home policy of
`docs/development-guideline.md`, which has no sentence on a generated copy (the issue's criterion
review record lists them with their grounds).

ADR-0032 gave each unit session the core parts it uses through a classification and a generator,
and left the subagents, the documents beyond the core and the reviewers out of its scope.

## Decision

**D1 — One way.** A role's guidance is carried, as text, by the carrier the role starts with:

| Role | Carrier |
|---|---|
| a session (`/autoflow:cycle`, `/autoflow:cycle-u1` … `cycle-u7`, `/autoflow:criterion-review`) | its command body |
| a subagent with an AutoFlow definition (`autoflow-*`) | its agent definition |
| a reviewer (`claude`, `codex`) | its rule file, whose text the wrapper's prompt carries |
| a spawn with no AutoFlow definition (a unit's `general-purpose` helper, a research type, an ad-hoc spawn) | the prompt its spawner writes, from the spawner's own carrier |

What a role reads beyond its guidance and the cycle's inputs stays its own judgment; the guidance
itself is no longer a reading choice.

**D2 — What a role's guidance is: the core parts it uses and the documents its work follows.**
No new criterion is written; the set is read from what the documents already say binds a role.

- *The core parts.* A command body's are ADR-0032's classification. Every agent definition takes
  the core's Instruction Conventions and Rule Scope — the two parts every unit's classification
  takes (`all`) and the standard by which a `[MUST]` item is told from a judgment item — and the
  core part its own definition names as binding it (the build unit: Commit Rules; the advisor:
  Execution Principles > *Human-decision presentation*).
- *The documents.* One reading for every role: the documents and sections its carrier names as
  the home of what the role itself does — its contract, its document, the documents line of its
  spawn, the grammar of what it writes, the rules its work follows — and the documents whose own
  scope statement names it.
  - A session: its unit's document and the documents the core names on the unit's entry (Unit
    Document Loading Contract, Unit references); the homes the core's parts name for what the
    session itself writes and asks — `docs/decision-ledger.md` (the ledger's entries),
    `docs/issue-proposal.md` (an issue draft),
    `docs/role-contracts.md` > Advisor (the advisor request), `docs/state-tracking.md` (the state
    file; not the criterion review stage, which writes none) and, in a unit that spawns an
    evaluator, `docs/role-contracts.md` > Evaluation AI (its spawn and prompt), and
    `docs/role-common-rules.md` > Result delivery path by spawn mode (what carries the report it
    receives, the home the core's Execution Principles name); and the sections of
    `docs/submodule-common-rules.md` whose own scope names every actor (Verification and Tools) or
    every spawn's report (Reporting Format, which the orchestrator also states to a spawn with no
    definition). A session in which the orchestrator commits to the target (U4–U7) takes Change
    Surface Rules, the home of the lint chain the core's Commit Rules bind it to and of the
    comment rules its direct fixes follow.
  - A subagent: what its definition or contract names as above; the unit agents, whose scope
    `docs/role-common-rules.md` ("the unit agents and their helpers") and
    `docs/submodule-common-rules.md` ("every target scope a role works in") name, take both
    whole; every other role takes the sections of `docs/role-common-rules.md` that name it (Bash
    Execution Mode, Result delivery path by spawn mode) and the Verification and Tools and
    Reporting Format sections. Each unit agent
    also takes its exit gate's rubric, the verification that prescribes it (ADR-0025 D2); the
    evaluator takes Change Surface Rules, against which GATE:PLAN `Scope` and GATE:QUALITY
    `Minimal implementation` and `Impact scope` are scored; the reconciler takes the record's
    section contract (`docs/criterion-review.md` > Review record) it updates.
  - A reviewer: its rule file and `docs/review/review.md`, the rules that rule file names.
  - A helper: the three rules `docs/units/build.md` > *What crosses a boundary* names and the
    core's Instruction Conventions and Rule Scope, by which they are read.
- *Not carried.* A section the carried text cites for one item stays a citation, read at its home
  when that item needs it — the shape `docs/evaluation-system.md` > *What it reads* already states
  for the evaluator; a core part a unit's classification leaves out (ADR-0032); the cycle's inputs
  — the attempt's artifacts and the target's files — which a prompt names by path; and the target's
  own guidance (its `CLAUDE.md`, `AGENTS.md`, review rule and lenses files' choice and content, its
  security checklist), which is the target's and reaches a role through the harness or the
  procedure that reads it (the issue's advisor decision A1).

The set of each carrier and the grounds of each entry are in the pull request that sets it, as
ADR-0032 D2 has it for the core.

**D3 — The classification and the generator.** `scripts/skills/role-docs.tsv` records, per
carrier, the documents and sections it carries, in order — a carrier column (a pattern such as
`agents/*.md` names every definition), the document, a heading path and a block prefix, the shape
`core-units.tsv` uses. `scripts/skills/gen-skill-bodies.sh` generates every carrier from it:

- a command body: the header, the core parts by `core-units.tsv`, then the documents, each after a
  `<!-- From <autoflow-root>/<document> > <section> -->` line, and a header line naming them;
- an agent definition and a reviewer's rule file: its own text down to a marker line, then a line
  naming what follows and the core parts and documents, generated.

A document's links point at `<autoflow-root>/…`. An entry already carried whole by its document is
not carried twice. The generator fails on an entry that matches no carrier, a scope or block that
matches no part of its document or more than one, and a link target that does not exist;
`--check` compares every carrier, `--list-all` names them. `tests/plugin/verify-skill-bodies.sh`
checks, apart from the generator, that each entry's first line follows its `From` line in every carrier it names (K3; the whole text is the regen-clean check's), that
the documents, and the sections of them, the core's tables name for a unit are in that unit's body
and the whole-cycle body (K4), and that every agent definition is a generated carrier (G4).

**D4 — Relation to ADR-0032.** One generator and two classifications: `core-units.tsv` keeps the
core parts of a command body; `role-docs.tsv` adds the documents of every carrier and the core
parts of the carriers that are not command bodies. The unit stays the axis of a session's core
parts; a subagent's are few and named per carrier.

**D5 — The evaluator.** One type, `autoflow-evaluator`, serves four gates, and its definition is
fixed text. It carries `docs/evaluation-system.md` whole — the document it already read whole —
the artifact-contract sections of every row of *What it reads* and Change Surface Rules; its gate's
row is its input set, and another gate's rubric and row stay outside it.

**D6 — First run and re-run.** A re-run — a FAIL re-entry, an `impl` or `design` route, a review
fix — is a fresh spawn of the same type, a session started by the same command or a reviewer run by
the same wrapper; it carries the same guidance as the first run, whatever its prompt names.

**D7 — The clauses changed with it.** The delivery clauses of the Context are rewritten to this
way — `docs/core.md` > Context Injection, Unit Document Loading Contract and Unit references; R2;
`docs/INDEX.md`; `docs/role-contracts.md` > Evaluation AI Prompt Rules 1–2, Functional-unit
agents; `docs/evaluation-system.md` > *What it reads*; the unit documents' *Documents* items and
their evaluator spawns; `docs/units/build.md` > *What crosses a boundary*; `docs/criterion-review.md`
> *What the procedure fixes*; `docs/reviewer-backend.md` > Reviewers and Rule files; the agent
definitions' "what you read"; and the home policy, under which a generated copy is the home's text,
regenerated, not another site. The content of the guidance is not changed.

## Alternatives Considered

- **The orchestrator copies the guidance into each spawn's prompt.** Not taken: what a role
  receives would depend on the orchestrator's selection at each spawn — the failure the issue
  observed — and the 5-line evaluator prompt rule exists to keep the orchestrator out of the
  evaluator's reading.
- **A SessionStart or SubagentStart hook injects the guidance.** Not taken, on ADR-0027 >
  Alternatives > *Session-start injection*: SubagentStart reaches every subagent, a user's own
  spawns included, in every repository the plugin is enabled in.
- **One evaluator type per gate.** Not taken: the hook's role mapping, the spawn-policy rows and
  every document that names `autoflow-evaluator` would change for a separation the gate's row
  already gives.
- **An AutoFlow definition for the unit's helpers.** Not taken: a helper is a `general-purpose`
  spawn whose effort its policy row passes per call (`effort_contract`); the three rules its work
  follows are named in `docs/units/build.md` and the unit carries their text.
- **Carrying every section the carried text cites.** Not taken: the citations reach most of the
  document set, so every carrier would carry nearly all of it.
- **A command body that names the documents to read on entry.** Not taken, on ADR-0032 >
  Alternatives: the rules would reach the session through a later `Read`.

## Consequences

### Positive

- Every role starts with its guidance; a role's first run and its re-runs carry the same text.
- The writer and the evaluator of a change hold the same Change Surface Rules; every agent holds
  the core's reading conventions whole.
- A renamed heading, a moved section or a broken link in a carried document fails the generation
  instead of leaving a carrier without it.

### Negative

- The carriers are larger. Measured on this change (bytes, main `2e72b1a` → this change): the
  unit command bodies 37,549–44,901 → 144,250–176,173; `/autoflow:cycle` 49,927 → 399,380;
  `/autoflow:criterion-review` 13,913 → 104,400; the agent definitions 2,816–4,929 → 29,186–149,846;
  the reviewers' rule files 774–1,132 → 11,604–11,962. Most of it was read by path on entry or
  during the work before (the unit document, `docs/evaluation-system.md`,
  `docs/criterion-review.md`, `docs/decision-ledger.md`, `docs/review/review.md`).
- A change to a carried document regenerates every carrier that carries it, and the generated text
  is committed.

### Neutral / Trade-Offs

- The prompts are unchanged in what they name — the inputs, by path — except that the evaluator's
  no longer tells it to consult `docs/evaluation-system.md` and a helper's carries the text of its
  rules.
- A spawn with no AutoFlow definition receives its guidance in a prompt its spawner writes, so no
  generator checks that prompt. For a build helper what it carries is fixed by name
  (`docs/units/build.md` > *What crosses a boundary*); for a research or ad-hoc spawn it is the
  rules its work follows, which the spawner names; both are copied from the spawner's own carrier.

## Amendments

### ADR-0027 D2 > The core, Other homes

- *The core*: a command body carries, after the core, the documents `role-docs.tsv` names for it.
- *Other homes*: a unit's document is carried by the unit's command body, not read on entering it.

### ADR-0027 D2 > Subagents

- Each agent definition declares the AutoFlow root through `${CLAUDE_PLUGIN_ROOT}` and carries,
  below its own text, the core parts and the documents it is bound by (D1–D3).
- A functional unit's `general-purpose` helper receives the root and the text of the rules its work
  follows in the prompt the unit writes for it.
- No SessionStart or SubagentStart hook injects rule text (unchanged).

### ADR-0032

- *D3*: a unit's body is the command header, the core's parts that name the unit or `all`, and
  then the documents `role-docs.tsv` names for it.
- *D4*: the generator generates every carrier; `--list` names the command bodies, `--list-all`
  every carrier.

### ADR-0025 D2

What a unit reads beyond the guidance its definition carries is the unit agent's; the guidance is
not a reading choice.

### `docs/tool-delivery-contract.md` R2

The methodology prose reaches a role only through the carrier it starts with (D1), or as a
document a role reads by path beyond its guidance.

## Related Issues / PRs

- #494, #464 (ADR-0032), #454 (ADR-0027), #369 (ADR-0025), #485 (ADR-0033).

## Amendment note (issue #499)

The recommendation triage (`docs/units/completion-evaluation.md` > *Recommendation triage*), which
the session of every rubric-scored gate performs after the gate's PASS, reached the U2, U3 and U4
sessions by path only: D2's session enumeration does not name it, and the core names it in Flow
Control rows that no check reads. Issue #499 aligns the sets D2 and D5 describe with the carriers
the change ships. What follows are this change's dispositions and their grounds under D2 as written.

1. **The session sets.** Every command-body carriage this change adds enters D2's session
   enumeration through its first clause, "the documents the core names on the unit's entry (Unit
   Document Loading Contract, Unit references)": the core's *Unit references* table names each one
   in its unit's row.
   - U2, U3 and U4: `docs/units/completion-evaluation.md` > *Recommendation triage*, the home of
     what the session itself does after its gate's PASS.
   - U2–U5: the procedures the triage hands the session, as item 3 disposes of them —
     `docs/units/review.md` > *Whether a finding holds* (U2–U5), `docs/submodule-common-rules.md` >
     Change Surface Rules > *Scope judgment* (U2, U3) and `docs/units/completion-evaluation.md` >
     *FAIL routing* with its *`doc` re-entry* (U4).
   - U4, U5 and `/autoflow:cycle`: the reference-integrity block of `docs/evaluation-system.md` >
     GATE:QUALITY > *Known blind-spot checks*, the one definition of the normative documents a
     `doc` remedy fixes every hit in.
   - U6 and `/autoflow:cycle`: `docs/title-guide.md`, the grammar of the pull request title U6
     writes.
   - U7: `docs/units/completion-evaluation.md` > *Code comments in a target*, the terms of the
     direct commit U7 makes for a reviewer's comment `Low`; `docs/units/build.md` > *Unit spawn* and
     *Re-entry*, the BUILD unit re-run U7 runs on a thin route; `docs/units/delivery.md` > *CI*, the
     confirmation of CI after a thin route's push and at *End*.
   - U4, U5, U7 and `/autoflow:cycle`: `docs/role-contracts.md` > *Model tier revert*. The core's
     Spawn Model hands every session the revert and names this home for its signals and their
     anchor; the signals it lists arise at AUDIT (U4), GATE:QUALITY (U5) and the reviewer review
     (U7).

   U2 and U3 take Change Surface Rules > *Scope judgment* on the triage's `Low` judgment, beside
   the U4–U7 commit ground, which stays as it is.

2. **The agent definitions' sets.** D5's evaluator set gains `docs/review/review.md` > *Severity*,
   the value set of the `severity` it writes on every recommendation (the grammar of what it
   writes), and `docs/development-guideline.md` > ADR Policy > *When to create an ADR*, the list its
   ADR-conformance checks decide a trigger area against (the rules its work follows). Under D2's
   subagent clause:
   - the analyzer gains `docs/review/review.md` > *Severity*, the level set and order behind the
     severity and `max_severity` it writes (the grammar of what it writes);
   - the three unit agents gain the first block of `docs/units/review.md` > *Whether a finding
     holds*, whose scope statement names "a role the route hands a finding to" (the documents whose
     own scope statement names it); the section's second block is the aggregator's and the
     orchestrator's;
   - `autoflow-unit-design` gains the ADR trigger list, against which its design is scored (the
     rules its work follows);
   - the advisor gains the core's *Decision Ledger*, the ledger's standing constraints its entries
     follow, which its carried `docs/decision-ledger.md` names (the core part its own definition
     names as binding it).

3. **The homes the triage cites, per unit.** For each U2–U5 session, each home
   `## Recommendation triage` cites is carried, or stays a citation on D2's *Not carried* first
   category — "a section the carried text cites for one item stays a citation, read at its home
   when that item needs it" — with the fact that makes it one.

   | Home | U2 | U3 | U4 | U5 | *Not carried* category | Ground of a citation |
   |---|---|---|---|---|---|---|
   | `docs/units/completion-evaluation.md` > Recommendation triage | carried | carried | carried | carried before | — | — |
   | `docs/units/review.md` > Review triage > Whether a finding holds | carried | carried | carried | carried | — | — |
   | `docs/submodule-common-rules.md` > Change Surface Rules > Scope judgment | carried | carried | carried before | carried before | — | — |
   | `docs/units/completion-evaluation.md` > FAIL routing (with *`doc` re-entry*) | cite | cite | carried | carried before | first | At a gate before execution the triage calls no script and resolves on the gate's own FAIL route; the class a `Low` fixed now records is chosen by the question, and among the values, the carried triage states; the table's re-entry column is not used there. |
   | `docs/units/completion-evaluation.md` > Re-entry re-score | cite | cite | cite | carried before | first | GATE:QUALITY's re-score is the evaluator's act on its narrowed input, which its definition carries; the session's act, spawning a fresh evaluator, is carried (`docs/role-contracts.md` > Evaluation AI). |
   | `docs/units/completion-evaluation.md` > Code comments in a target | cite | cite | cite | carried before | first | The evaluator records a comment finding at GATE:QUALITY only; no GATE:HYPOTHESIS, GATE:PLAN or AUDIT recommendation is one. |
   | `docs/units/design.md` > Report routing > An acceptance-criterion change raised later in the cycle | cite | carried before | cite | cite | first | The session's steps — the decision, the advisor where the grounds do not settle it, one `[ac-decision]` entry per criterion, the analysis table edited on `revised`, `split` or `added`, the re-entry point and its budget — are carried in `docs/decision-ledger.md` > *Acceptance-criterion decisions* and the core's Any-unit row. |
   | `docs/units/design.md` > Output artifacts (the decision layer) | cite | carried before | cite | cite | first | U2: at GATE:HYPOTHESIS the evaluator records a fact below the decision layer at `Low`, and the session's act, deferring it to BUILD in the verdict entry, is stated in the carried triage. U4, U5: the citing clause defers such a fact at a gate before execution, and no AUDIT or GATE:QUALITY recommendation reaches it. |
   | `docs/units/design.md` > Re-entry | cite | carried before | cite | cite | first | An ARCHITECT unit re-run is the U3 session's act. |
   | `docs/units/analysis.md` > Re-entry | carried before | cite | cite | cite | first | A U2 unit re-run is the U2 session's act. |
   | `docs/evaluation-system.md` > Evaluation Output Format; > GATE:PLAN > Re-entry re-score; > AUDIT > Review-response re-score | cite | cite | cite | cite | first | The evaluator's grammar and acts, which its definition carries; the fields the session checks before it accepts a report are listed in the carried triage. |
   | `docs/review/review.md` > Severity | cite | cite | cite | cite | first | The evaluator assigns the level, and the session routes on the threshold the carried triage states (`Medium` and above, `Low`); a level outside those names (`Low Confidence`) is the one item the session reads the home for. |
   | `docs/units/review.md` > Reviewer review | cite | cite | cite | cite | first | The review round that verifies a reviewer finding's fix is U7's act. |
   | `docs/pr-body-guide.md` > 한계와 known gaps | cite | cite | cite | cite | first | U6 writes the pull request's body; the session records a deferral in its verdict entry (the carried triage). |
   | `docs/units/preparation.md` > Resume | cite | cite | cite | cite | first | The resume is U1's act. |
   | `docs/development-guideline.md` > Documentation Policy | cite | cite | cite | cite | first | It governs a change to the rule's text (its search terms), not the triage. |
   | `docs/decision-ledger.md`; `docs/role-contracts.md` > Advisor; `docs/core.md` > Remedy class recording | carried before | carried before | carried before | carried before | — | — |

4. **The check's reach.** `tests/plugin/verify-skill-bodies.sh` K4 fails when a command-body
   carriage of item 1 is deleted from `scripts/skills/role-docs.tsv` and the carriers are
   regenerated, because the core's table names it; it also meets an item whose section a body
   carries inside an enclosing section of the same document (the whole-cycle body carries *Scope
   judgment* inside Change Surface Rules). The agent-definition carriages of item 2 have no
   committed check that fails on their deletion. No declaration of them exists apart from
   `role-docs.tsv` — D2 reads an agent's set from its definition's and contract's prose, and D3
   makes `role-docs.tsv` the classification — so such a check would need a second machine-readable
   list of the same entries: the classification in two homes, and a device per item. A deletion
   still changes the generated carrier, its "Carried below" line and the pull request's diff the
   reviewers read.

5. **Consequence.** The carriers grow. Measured (bytes, main `42d0080` → this change): the unit
   command bodies 144,667–179,601 → 160,789–194,000 (`/autoflow:cycle-u1` unchanged);
   `/autoflow:cycle` 405,252 → 413,359; the agent definitions that change — the advisor, the
   analyzer, the evaluator and the three unit agents — 39,724–150,065 → 40,205–151,415, the
   criterion-review agents unchanged; `/autoflow:criterion-review` (105,687) and the reviewers'
   rule files (11,604–11,962) unchanged.

These are this change's dispositions and their grounds under D2 as written.
