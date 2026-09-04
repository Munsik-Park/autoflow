# ADR-0020: Changing an issue's acceptance criteria is the operator's authority, enforced by a halt

## Status

Accepted, amended by ADR-0022; the ARCHITECT halt superseded by issue #166 (see Superseding note)

## Context

An AutoFlow cycle can drop, decline, defer, weaken or substitute an issue's acceptance criterion
without any human deciding that it may be changed, and nothing in the flow asks *who has the
authority* to make that call.

Observed in the #134 cycle. The converged verification design carried two criteria the issue stated
and neither of them was verified: one row was typed *not carried as a criterion*, another *deferred —
not verified in this cycle*. Both dispositions were transparent, well argued, and conformant with the
prose that governs them — `docs/teammate-contracts.md` types "requires design change" as a legitimate
verification outcome, and the ARCHITECT untestable-items bullet offers a design-change request as the
sanctioned disposition for an item that cannot be verified. Three gates saw the result and scored it
favorably.

Two structural facts explain why nothing caught it:

- **ARCHITECT computes its verdict from `converged` alone.** The facilitation script's terminal
  verdict expression reads the mutual-ACCEPT flag and nothing else, and its verdict enum is closed at
  two values. No point in the deliberation reads the issue's acceptance criteria.
- **The two gates behind it score the quality of the stated reason.** GATE:PLAN and GATE:QUALITY each
  cap a named item at 6 on an ADR-conformance violation, and neither takes the issue's
  acceptance-criterion list as an independent input. A rubric that reads a well-written rationale
  scores it well; that is what it is for.

A third fact bounds the fix. The detection cannot be a phrase match: the literal `"NOT CARRIED"` does
not occur in the #134 artifact at all, and the two dropped criteria are spelled two different ways. A
detector must be specified by *effect on the criterion*, and it needs a key to join on.

## Decision

**Changing an issue's acceptance criteria is the operator's authority. A deliberation may propose the
change; only an operator decision may make it. The flow stops and asks.**

1. **The acceptance-criterion list is one machine-addressable artifact.** The DIAGNOSE Phase B
   artifact `.autoflow/issue-{N}-phase-b.md` carries a required `## Acceptance criteria` table with
   the fixed columns `AC id | criterion | source`. It is authored once per issue, in the
   `mode = new-issue` cycle; a review-response cycle carries it forward unchanged, because a reviewer
   comment never edits the acceptance-criterion list. The verification design's acceptance-criteria
   table gains a leading `Issue AC` column carrying that id, or `—` for a criterion the design added
   on its own. This turns "was a criterion dropped?" into a key join rather than a reading of prose.

2. **ARCHITECT halts on an unauthorized change (`AC_CHANGE`).** A `Reconcile` phase sits between
   `Converge` and `Ledger` and runs **only on a converged run** — verdict precedence is `ESCALATE`
   before `AC_CHANGE` before `CONVERGED`, so an infrastructure or non-convergence cause still
   outranks a design outcome. It calls one closed-schema **comparison channel** that transcribes
   cells and never judges whether a change was justified; the facilitation script derives each
   finding's kind (`dropped` / `not-carried` / `deferred` / `weakened` / `substituted`, first match
   wins, at most one per criterion) and its authorization in its own code. On any finding no
   operator decision covers, the run returns `AC_CHANGE`, the orchestrator reports situation-first,
   sets `active:false` / `phase:"awaiting-user"`, and does **not** spawn GATE:PLAN.

3. **The check is fail-closed.** A null return, a malformed payload, or an absent/unparseable AC
   table resolves to `AC_CHANGE` with its own sentinel (`ac reconciliation unavailable` /
   `ac list absent`), carried on a field of its own rather than folded into `escalation`. Degrading
   to `CONVERGED` when the reconciliation cannot run would restore the silent path in exactly the
   failure mode where nothing else is watching.

4. **The operator's answer is a ledger entry, in one fixed grammar.** One entry per decided
   criterion, headed `## O<n> — <title> (cycle <C>, ARCHITECT) [ac-decision]`, carrying a
   `- AC: <ac id>` line, a disposition of `excluded | revised | split`, and the authority value
   `operator decision`. The issue text's `authority: operator` maps to exactly those two literals and
   nothing else: the marker `[ac-decision]` is what the Reconcile channel and both gates **locate**
   the entry by; `operator decision` is the authority **value**, added to the facilitation script's
   settled-authority seed set so a resumed deliberation treats the call as closed. The marker sits at
   the end of the heading, leaving HANDOFF's `[review-autofix]` count predicate unaffected.

5. **Two scoring backstops behind the halt**, both on the ADR-0016 mechanism — scored inside an
   existing item, no new scored item, no threshold change, a violation caps the named item at 6.
   GATE:PLAN's `AC-authority check` (within `Scope`) is a key join over both sides. GATE:QUALITY's
   (within `Completeness`, appended to the Known blind-spot checks) is deliberately weaker — a
   **name-the-site obligation**, since only the left side is keyed — and catches drift introduced
   after ARCHITECT. Neither subsumes the other. Both take the acceptance-criterion list and the issue
   ledger as declared inputs the evaluator reads and never reinterprets.

6. **An AC pause costs a round, not a re-deliberation.** Re-entry is the ordinary ARCHITECT resume,
   and consumes no ARCHITECT re-entry budget: the pause is a human authority checkpoint inside the
   deliberation already counted.

## Alternatives Considered

- **Doc-only — strengthen the Agreement-criteria prose, add no control flow.** Refused. The prose it
  would add has to compete with prose already licensing the opposite, and the incident's removal was
  conformant with that prose and scored well by three rubrics. What is missing is not a statement
  that acceptance criteria belong to the operator; it is a place where the run stops and the operator
  answers. (The two *cap* halves of this decision are doc-only, on the ADR-0016 precedent — prose
  suffices where the reader is a scoring evaluator and does not where the need is a halt.)
- **Enforce the GATE:PLAN non-spawn in the gate hook.** Refused. The hook's `evaluation` role class is
  deliberately never score-gated, because it produces the scores; gating it would deadlock every
  gate. This decision states plainly that no runtime guard stands behind the routing rule — its
  carriers are the doc invariants and the returned verdict.
- **A new `.autoflow/issue-{N}-ac.md` artifact.** Refused. The list already exists inside the Phase B
  artifact in two archived cycles; a new file adds a surface, a lifecycle and an archive rule and
  buys no addressability a section heading does not already give.
- **Let the comparison channel judge whether a change was justified.** Refused. That judgment is
  precisely what the incident showed to be capturable by a well-written rationale.
- **Let `weakened` mean "asserts a strictly weaker property".** Refused. It is a depth judgment about
  verification strength, handed to a channel forbidden to judge, and an unbounded false-positive
  source; every fail-closed path pages the operator, so an unreliable reading is expensive. Bounded to
  the decidable form (no executable method named); real-but-executable weakening stays with
  GATE:PLAN's depth items, which already score it.
- **Give the final change set its own AC id column so GATE:QUALITY joins a key too.** Refused. It puts
  an annotation on every test assertion and implementation site, maintained by the same agents the
  check exists to witness against — an annotation an agent writes cannot witness against that agent.

## Consequences

### Positive

- An acceptance criterion cannot leave a cycle without a human having decided it may, and the
  decision is on the record with its own authority literal.
- Detection is a key join computed in code, not a model's reading of prose, so it is assertable
  against a fixture with no model in the assertion path.
- The two backstops cover the window the halt cannot see — drift introduced after ARCHITECT.

### Negative

- One new false-positive surface: `substituted` is a semantic reading, and a wrong one pauses an
  honest convergence and trains the operator to click the pause through. The design carries a
  negative control against it (a clean AC table must produce no findings) and states the residual
  rather than assuming it away. *Realized and retired*: #157 cycle 1 paused on exactly this
  surface (one criterion split into two rows by verification method), and issue #160 removed the
  kind — see ADR-0022 > Notes > *Amendment (issue #160)*.
- **The `ac reconciliation unavailable` pause has no exit mechanism, by decision.** That path
  produces no finding, so no `[ac-decision]` entry can clear it: every resume re-runs Reconcile and
  re-pauses until the underlying cause is repaired. This is an accepted consequence, following the
  contract every other infrastructure escalation in the facilitation script already has — none
  carries a bounded retry or an in-flow override. The operator's exit is the ordinary one: author the
  missing table or rows, or re-run once the channel recovers.
- A well-formed reconciliation payload whose transcribed row set is **empty** resolves to `ac list
  absent` rather than to a clean convergence, so a channel that read the table and transcribed
  nothing pauses the run instead of passing it silently — at the cost of pausing a genuinely empty
  acceptance-criteria table too, which this design treats as the correct outcome.

### Neutral / Trade-Offs

- GATE:QUALITY's half gives a weaker guarantee than GATE:PLAN's, and says so in its own text rather
  than claiming a join it does not perform.
- Both caps bind **from** the cycle whose DIAGNOSE authored an AC table under this decision, the same
  *Effective from* convention the composition-oracle and verification-depth clauses use. A cycle
  already past DIAGNOSE is not retroactively deficient.

## Related Issues / PRs

- Issue #138 — this decision and its implementation.
- Issue #134 — the incident that motivated it (two criteria changed with no operator decision).
- Precedent: `docs/adr/0016-adr-conformance-gate-scoring.md` (cap-at-6 inside an existing item, no
  added scored item, no threshold change).

## Notes

- Numbering: 0020 is the next free integer, contiguous after 0019.
- Amended by [`0022-test-necessity-and-three-tier-ac-guard.md`](0022-test-necessity-and-three-tier-ac-guard.md):
  the operator retains authority over acceptance-criterion **content**, while a verification-method
  reduction carrying a stated reason is the deliberation's and is judged by the external reviewer —
  so the finding set narrows from five kinds to `dropped` / `unreasoned` / `substituted`; issue
  #160 further retires `substituted`, leaving `dropped` / `unreasoned`. The halt,
  the fail-closed sentinels, the `[ac-decision]` grammar and the budget accounting are unchanged.
- The decision alters agent-workflow gates and evaluation policy — a `docs/adr/README.md` >
  "When to Create an ADR" trigger area — so it lands with, or ahead of, the mechanism it governs.

## Superseding note (issue #166)

The ARCHITECT deliberation returns to its original form — participants discuss a topic in relayed
turns and report their conclusions — so the automatic Reconcile join between the issue's acceptance
criteria and the verification design, and the `AC_CHANGE` halt it raised, are retired with it.

The authority principle this ADR decided stands unchanged: an issue's acceptance-criterion
**content** is the operator's, and a verification-method reduction carrying a stated reason is the
deliberation's. It is now exercised at three points:

1. **The orchestrator's routing of the deliberation report.** An agreed conclusion that excludes,
   revises or splits an acceptance criterion is presented to the operator before GATE:PLAN, and the
   answer is recorded as one `[ac-decision]` ledger entry per decided AC.
2. **GATE:PLAN's AC-authority check** — unchanged, scored, capping `Scope` at 6 on a difference no
   `[ac-decision]` entry covers.
3. **GATE:QUALITY's assertion-claim alignment** — unchanged, scored.

The `[ac-decision]` ledger grammar is unchanged: the entry heading marker, the `- AC:` and
`- Disposition:` lines, and the authority value `operator decision`.
