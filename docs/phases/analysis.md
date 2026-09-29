# DIAGNOSE — U2 Analysis unit

> Phase playbook for DIAGNOSE. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

DIAGNOSE and GATE:HYPOTHESIS are one functional unit, U2 Analysis
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed by
four things only — its goal, its artifact contract, its verification and its loop cap (D2) — and
this file states them, with the cautions the analysis is asked to heed. How the unit reaches the
goal — what it reads and in what order, whether it spawns helpers and what it gives each, how it
keeps the cautions — is the unit agent's, recorded with its grounds in its artifact
([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2).

- **Goal**: the request that triggered the cycle is understood well enough for GATE:HYPOTHESIS to
  score it — the affected structure as it stands, the gap between it and the requested behavior,
  whether a code change is the lever, and, for a bug or incident issue, the cause hypotheses and
  their lightweight verification.
- **Artifact contract**: the analysis report (*Analysis report* below).
- **Verification**: GATE:HYPOTHESIS — a fresh Evaluation AI scores the report's structure form for
  every issue and its cause form for a bug / incident issue ([GATE:HYPOTHESIS](gate-hypothesis.md));
  the unit never scores its own artifact. U2 ends at a `gate_hypothesis_cause` PASS, or at the
  structure-form PASS of a non-bug issue, whose verdict is `skipped (non-bug issue)` (D6).
- **Loop cap**: a cause-form FAIL re-runs the unit with the evaluator's findings and the previous
  report (*Re-entry* below), max 2× (`CLAUDE.md` > Flow Control > Regressions). The structure form
  has no retry loop: its FAIL is a disposition ([GATE:HYPOTHESIS](gate-hypothesis.md) > *Structure
  form*).

## Review-response loop check

`mode = review-response` only. The check runs **once per review-response attempt**, at whichever point that attempt begins: at DIAGNOSE entry, ahead of the unit spawn below, for an attempt that runs DIAGNOSE; and at HANDOFF step 6.5 before the routed work, for a route that does not — a thin route, or a `design` re-entry judged to start at ARCHITECT ([`handoff.md`](handoff.md)). Steps 1 and 2 below are what the step-6.5 call site executes; step 3 applies unchanged at either call site. This section is the contract's only documentary home — the call sites cite it rather than restate it. An `autoflow-loopcheck` sub-agent (a shipped read-only definition), on the model the policy names for `diagnose-loopcheck` (an analysis-class spawn, never score-gated), writes `.autoflow/issue-{N}-loopcheck.md` and returns a one-line summary. The contract has three separated steps:

1. **Record the observation — on every review-response DIAGNOSE entry, before comparing.** Append a ledger observation for this cycle: the **complaint class** (the property the reviewer asserts, e.g. "duplicate-member detection is incomplete"), the **witness case** (e.g. two identical entries, then three identical entries), the **shape of the prior change** (a check for the named case, or a rule over the whole property), and the cycle number. Recording is unconditional (not only on a match): the first review-response cycle records its observation too, with no prior to compare against.
2. **Compare against the immediately-prior review-response observation.** When the class matches and only the witness case differs, first check the ledger for an **active *case-specific* suppression** on this class — a *case-specific* decision recorded for this class with no different class observed in any later cycle. If one is active, the class is suppressed: continue the normal flow without pausing. Otherwise reply on the PR with the comparison, append a ledger entry marking the match, and hand the decision to the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor) with a request written **situation-first** — for example restating the acceptance criterion as one rule over the whole input, or a further case-specific change. Do **not** record a decision in the match entry: the advisor's entry is the decision. When the class **and** witness are both the same (a fix that did not take), this check does not apply — continue to the unit spawn (scope-split applies); a different class also continues normally and, by appearing, releases any earlier suppression on other classes.
3. **Re-enter on the advisor's answer.** The advisor's `A` entry records the decision, and the *same* cycle continues with no pause. A *redefine-AC* answer restarts DIAGNOSE in this cycle from the new acceptance criterion (recorded as `[ac-decision]` entries); a *case-specific* answer continues the normal flow and suppresses re-surfacing of that class until a new class appears. An operator override of that answer at the retry stage re-enters the same way ([`role-contracts.md`](../role-contracts.md) > Advisor > *Operator review at the retry stage*).

## Unit spawn

1. **Spawn** one `autoflow-unit-analysis` (`Agent`, anonymous, no `name`, the model
   `bash scripts/spawn-policy/spawn-policy.sh model unit-analysis` names) at DIAGNOSE entry — in a
   review-response cycle, after the loop check. The prompt states the goal, the cycle's `mode` and
   the report's path, and names the inputs by path: the issue (new-issue) or the reviewer comment /
   thread PREFLIGHT identified (review-response), and the decision ledger
   (`.autoflow/issue-{N}-ledger.md`). In a review-response cycle it also names every artifact the
   previous cycle left (`.autoflow/issue-{N}-c{C}-*.md`) and, when
   `scripts/review/scope-bounded.sh entry` printed `scope-bounded: true`, that the path is bounded
   ([PREFLIGHT](preflight.md) > *Scope-bounded entry*) — how the unit reuses the previous analysis
   on that path is its own. On a re-entry it names what the re-entry is for and the material that
   carries it (*Re-entry* below).
2. **Documents.** Injection stays role-minimal and routed via `docs/INDEX.md`, never wholesale: the
   prompt carries a documents line naming the documents the analysis needs (this file,
   [GATE:HYPOTHESIS](gate-hypothesis.md)); the unit reads anything further by its own judgment.
3. **Return.** The unit returns the report's path and a one-line summary that names any decision
   point it recorded ([`submodule-common-rules.md`](../submodule-common-rules.md) > Reporting
   Format). The orchestrator does not receive the report's body.
4. **Artifact-existence check (orchestrator-side).** Before GATE:HYPOTHESIS the orchestrator confirms
   the report exists, is non-empty and carries every section *Analysis report* lists. A missing one
   is an infrastructure cause: the unit is spawned again with the same inputs, consuming no counter.
5. **Route** the return (*Report routing* below).

## What the analysis owes

The analysis is asked for four things:

- the affected structure as it currently is, stated as fact;
- the gap between that structure and the behavior the request asks for;
- whether a code change is the lever that closes the gap, or data, configuration or operations are;
- for a bug or incident issue, the cause hypotheses, the lightweight verification of each, and a
  verdict per hypothesis.

The request is the trigger target — the issue body in a new-issue cycle, the reviewer comment or
thread PREFLIGHT identified in a review-response cycle — and the as-is is the dev branch's HEAD
(`main` in a new-issue cycle, the change under review in a review-response cycle). The question is
whether the as-is already satisfies the request.

**Cautions.** Each names a bias the analysis is to avoid:

- Describe the current structure as fact, apart from the issue's defect hypothesis — do not read the
  structure to fit the hypothesis.
- "Not a code defect" — data, configuration, environment, already fixed — is one of the hypotheses.
  A conclusion that a code change is required rests on evidence that rules the others out.
- The necessity judgment is reuse-neutral: a resolution that uses existing code is not marked down
  for it. Structural fit and over-engineering are GATE:PLAN's and GATE:QUALITY's.
- Open every material the issue body or an acceptance criterion references — a design mockup, an
  asset, an external document — yourself; one that cannot be opened is recorded with the reason.

How the unit guards against these biases — whether it separates the structure reading from the
issue reading, in what order it reads, what it gives or withholds from a helper — is its own,
recorded with its grounds under `## Method`.

The rules below are the ones other documents cite; everything else about the work is the unit's.

- **Acceptance criteria.** The report's `## Acceptance criteria` table is the issue's single
  machine-addressable acceptance-criterion list; an absent or unparseable table is itself a finding
  downstream ([ARCHITECT](architect.md) > *Report routing*; [GATE:PLAN](gate-plan.md) >
  *AC-authority check*). **[MUST]** It is authored once per issue, in the `mode = new-issue` cycle;
  a review-response cycle carries the previous cycle's table forward unchanged — a reviewer comment
  never edits the list; only an `[ac-decision]` ledger entry does, the advisor's or the operator's
  override (`CLAUDE.md` > Decision Ledger).
- **Referenced materials.** Each material is recorded under `## Referenced materials` — what it is,
  where it is, how it was opened, and what it shows for the criterion that names it; the material,
  not an abbreviated example in the body, is what the criterion means. **[MUST]** A material
  recorded `not opened: <reason>` is raised to the operator before the cycle leaves DIAGNOSE
  (`CLAUDE.md` > Flow Control > *tool or referenced material → user*;
  [`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools
  the work needs*).
- **Lightweight verification.** A hypothesis is checked with what the environment and the target's
  documents and scripts provide — API calls, queries, service status, logs — and those tools are
  looked for before an item is marked `unverified`; a tool that is off is started by the target's
  own procedure, and one that needs the operator is requested (*The tools the work needs*). The
  verdict notes record each tool, whether it was usable and how it was secured; an `unverified` item
  names the tool it needed.
- **Scope judgments.** Beyond the acceptance criteria, the analysis names the problems the confirmed
  cause carries — its other sites, and what fixing it will expose — with the scope judgment for each
  and its grounds ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface
  Rules > *Scope judgment*). ARCHITECT reads them and settles the cycle's scope in the feature
  design's `## Scope` section; the analysis does not decide it alone.
- **Decision points.** A judgment the working AI is not the one to make is recorded under
  `## Decision points` with its grounds, and the orchestrator routes it (*Report routing*): a
  planning, design or ADR prerequisite clearly required before the issue can be implemented
  (`mode = new-issue`; when in doubt, none); a request the as-is already satisfies; a gap or a cause
  whose lever is not code. A suggested split of the issue stays a suggestion: it is filed only on
  the operator's request, through a draft and `scripts/issue/create-issue.sh`
  ([`issue-proposal.md`](../issue-proposal.md)).

## Analysis report

`.autoflow/issue-{N}-analysis.md`. The unit writes it whole on its first run and brings it up to
date on a re-entry. Every section below is present; a section with nothing to record says `none`.

| Section | Holds | Read by |
|---|---|---|
| `## Method` | how the analysis was done — the reading order, any helper spawn and what it was given — and how each caution was kept, with grounds | GATE:HYPOTHESIS |
| `## Current structure` | the affected area as it stands — its structure, design intent and data flow — stated as fact | structure form |
| `## Request` | the concrete cases the request names, the problem type they share, and the resolution approaches it calls for | structure form |
| `## Acceptance criteria` | a table with the fixed columns `AC id \| criterion \| source`: `AC id` a short readable name unique within the issue, `criterion` the issue's criterion restated faithfully, `source` its place in the issue body | ARCHITECT, GATE:PLAN, BUILD, GATE:QUALITY |
| `## Referenced materials` | each material the issue or a criterion references, as *What the analysis owes* says, or `none` | ARCHITECT (*Tools*) |
| `## Necessity` | the issue type — Type 1 or Type 2 ([GATE:HYPOTHESIS](gate-hypothesis.md) > *Structure form*), and bug / incident or not — and, per resolution approach, the behavior gap and whether code is the lever, with grounds | structure form |
| `## Hypotheses` | for a bug / incident issue, at least three cause hypotheses, "not a code defect" among them, each with its lightweight verification, the tools it used and its verdict — eliminated, likely or unverified — with evidence; for a non-bug issue, `none — non-bug issue` | cause form |
| `## Scope judgments` | each scope judgment, as *What the analysis owes* says | ARCHITECT; GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Affected documents` | the documents the change is expected to update | ARCHITECT; BUILD (documents line) |
| `## Decision points` | each decision point with its grounds, or `none` | the orchestrator (*Report routing*) |

Anything else the unit records is its own, written where it judges useful.

## Report routing

- **A prerequisite** (`mode = new-issue`) → the advisor ([`role-contracts.md`](../role-contracts.md) >
  Advisor), the report as the request's anchor, written situation-first
  ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > *Human-decision presentation*).
  **Proceed** → GATE:HYPOTHESIS, after a unit re-run naming the advisor's entry where the analysis
  stopped at the prerequisite; **the prerequisite comes first** → the cycle ends with `active:
  false`, `phase: "awaiting-user"`, the report and the advisor's record as its report. No counter.
- **Otherwise** → GATE:HYPOTHESIS: one fresh Evaluation AI scores the structure form and, for a bug
  / incident issue, the cause form. The dispositions — an already-satisfied request, a non-code
  lever or cause, a non-bug issue's `skipped (non-bug issue)` verdict, a cause-form FAIL — are
  [GATE:HYPOTHESIS](gate-hypothesis.md)'s; a decision point the report records is confirmed by the
  gate's scores before any close or end.
- **A material not opened, or a tool the analysis needs that neither this environment nor the
  target's procedures provide** — a harness-level block → the operator, situation-first
  (`awaiting-user`; `CLAUDE.md` > Flow Control > *tool or referenced material → user*).

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-analysis` by
*Unit spawn* above, whose prompt names what the re-entry is for, the material that carries it, and
the report so far. The report is brought up to date, not rewritten; its `## Acceptance criteria`
table changes only by an `[ac-decision]` entry, which the orchestrator applies.

| Re-entry | Material named | Counter |
|---|---|---|
| GATE:HYPOTHESIS cause-form FAIL | the evaluation report and its failed items | GATE:HYPOTHESIS cause FAIL (max 2×) |
| a recommendation attempt at GATE:HYPOTHESIS routed to the analysis | the recommendation's subject and finding | the attempt window (max 7×) |
| the bounded path left ([PREFLIGHT](preflight.md) > *Scope-bounded entry*) | the full topic and the PR diff | none |
| an advisor answer or operator override that reaches the analysis | the `A` / `O` entries | none |

A re-entry passes through GATE:HYPOTHESIS again on its re-score
([GATE:HYPOTHESIS](gate-hypothesis.md) > *Re-entry re-score*). The unit reads and writes no
`.autoflow/issue-{N}.json` state file, so every counter above is the orchestrator's own accounting.

## Spawn model

Every DIAGNOSE spawn's model is resolved from the spawn policy, never restated here:
`bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` over
`.claude/autoflow/spawn-policy.json` — `diagnose-loopcheck` for the loop check, `unit-analysis`
for the unit, `gate-hypothesis` for the evaluator. Each `Agent` spawn declares `model` explicitly
([`CLAUDE.md`](../../CLAUDE.md) > Spawn Model — Phase-by-Phase), and each is an anonymous direct
spawn ([`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime); a spawn the unit
makes inherits its analysis class.

## Spot-check & escalation discipline (incomplete-output guard)

A DIAGNOSE spot-check is an orchestrator read that confirms a finding of the
analysis report before it feeds a routing decision, a blocker, or a user escalation. A Claude
Code behavior produces a **false "absent / stub" reading**:

- **Read-dedup stub.** A re-read of an unchanged file returns a 1-line stub ("file
  unchanged … refer to that earlier tool_result"), and the dedup ledger is not reset on
  compaction. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags this
  at runtime — these rules are the procedure it points to.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a routing decision or a
  user escalation**. A single read is never sufficient grounds.
- **[MUST]** A blocker/escalation-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool.
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged`). It is a harness stub, not
  data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after the unit has returned**, as single
  sequential commands. Another
  directory is addressed with `git -C <path>` + absolute paths rather than a
  `cd`-prefixed compound, which can raise a permission prompt.

**Operator-level mitigation (optional, session-global):** a long session that
has compacted is also prone to holding stale context with high confidence —
`--no-compaction` avoids it at the cost of context headroom. The hook + rules
above are the in-repo defense; this is a fallback.
