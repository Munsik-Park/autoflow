# Issue #26 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

These acceptance criteria are **not** covered by
`tests/fixtures/doc-invariants.json` (registry entries `26-AC*`) or by
`tests/test-issue-26-verify-architect-route.sh` — they are semantic judgments a
grep cannot make, or they depend on a live AutoFlow cycle that is not
reproducible in CI. Delegated per the verification design
(`.autoflow/issue-26-verification-design.md` §4, ledger E24): this cycle is
documentation-only — the change surface is the methodology spec text in
`CLAUDE.md` (Flow Control) and `docs/autoflow-guide.md` (Lifecycle Diagram,
VERIFY, GREEN). No runtime component changes (E3: no new `next_action` enum
value; E4/E26: no `.claude/workflows/*` edit).

**Coverage boundary, stated plainly.** Automated coverage for #26 is
*documentary*: it proves the routing rule is written, positioned, capped and
internally consistent across every surface it must appear on. It does not and
cannot prove an agent obeys it. A green suite for #26 should be read as "the
spec says the right thing, everywhere it must say it" — the behavioral claim
rests entirely on **M2** below.

---

## M1 — AC-26-6 residual: the two adjacent VERIFY rows are mutually exclusive to a routing reader (Tier 2)

**Source AC:** AC-26-6 (E6 positioning — discrimination, both directions).

**Why not automated:** the mechanical half *is* automated — registry entries
`26-AC6a-deadlock-row-hands-off-to-architect` and
`26-AC6b-row-names-arbitration-outcome` assert that each row carries a token
pointing at the other's case, and `26-AC5-ordered-deadlock-before-architect`
asserts they are adjacent and correctly ordered. The residual is the claim
those predicates cannot express: that **no reader can route the same situation
to both rows**. Mutual exclusivity of two natural-language conditions is not
expressible as a grep — a row pair can satisfy every token assertion and still
leave a reader unable to decide which applies.

**Steps:**

1. Open `CLAUDE.md` > Flow Control and read **only** the two adjacent rows
   `| VERIFY → Evaluation AI | …` and `| VERIFY → ARCHITECT | …`, plus the
   `| VERIFY → RED | …` row. Do **not** consult `docs/autoflow-guide.md` — the
   test is whether the router table alone decides the routing.
2. For each of the three fixed situations below, name the single row that
   applies:

   | # | Situation | Expected row |
   |---|-----------|--------------|
   | (i)   | The test misreads an acceptance criterion; the implementation is right. | `VERIFY → RED` |
   | (ii)  | Both self-checks are honest and report "no problem", and the acceptance criteria **are** jointly satisfiable — a genuine judgment disagreement. | `VERIFY → Evaluation AI` (deadlock) |
   | (iii) | Both self-checks are honest, and the acceptance criteria are **mutually unsatisfiable**, reproduced by measurement and recorded in a GREEN blocker report. | `VERIFY → ARCHITECT` (design contradiction) |

3. Confirm that for each situation exactly **one** row is a defensible answer,
   and that no situation admits two.
4. Confirm the direction of the pairing is legible: that the deadlock row reads
   as the *entry* into Evaluation-AI arbitration and the ARCHITECT row reads as
   one of its *exits* (ledger E7 — D1: the two rows are sequential and can never
   both fire for one event), rather than as two sibling triggers competing for
   the same event.

**Pass condition:** all three situations route to the expected row from the
table text alone, no situation admits two rows, and the entry/exit relationship
in step 4 is legible without the guide.

**Fail disposition:** a row pair that passes every automated token assertion but
fails this scenario is a **prose defect**, not a test defect — route it back to
GREEN for a wording fix, not to RED.

---

## M2 — AC-26-15: an orchestrator meeting a design contradiction actually routes to ARCHITECT (Tier 3)

**Source AC:** AC-26-15 (behavioral effect).

**Why not automated:** environment-dependent by nature. The artifact under
change is **instruction text consumed by a model at runtime**; exercising it
requires a live AutoFlow cycle containing a real, mutually-unsatisfiable
acceptance-criteria pair. No mock is proposed and none should be: a fake
"orchestrator" harness would assert the *mock's* routing, not AutoFlow's
(mock-boundary fidelity, `docs/autoflow-guide.md` > VERIFY step 4; verification
design DCR-7). This is verified as a **paper walkthrough** against the amended
text, and the limitation is stated rather than papered over with a green check.

**Steps:**

1. Take as the input case the historical situation that motivated this issue
   (`.autoflow/issue-26-diagnose.md`): at VERIFY, the Developer AI and the Test
   AI each self-check honestly and each is faithful to the design, and the
   residual failure is caused by the acceptance criteria themselves being
   jointly unsatisfiable.
2. Walk the **amended** text in order, as an orchestrator would:
   a. `CLAUDE.md` > Flow Control, `| GREEN → VERIFY |` — confirm the entry
      condition admits the blocked case (the satisfiable subset implemented and
      the contradiction recorded), so VERIFY is entered at all rather than GREEN
      hanging on "implementation done". *(This is the reachability precondition —
      ledger E11.)*
   b. `docs/autoflow-guide.md` > GREEN — Implementation — confirm the Developer
      AI was instructed to write
      `.autoflow/issue-{N}-*-green-blocker.md` with the conflicting AC IDs, the
      measurement reproducing the conflict, and `path:line` anchors.
   c. `CLAUDE.md` > Flow Control, `| VERIFY → Evaluation AI |` — confirm the
      case enters arbitration, and that the row's outcome enumeration names the
      design-contradiction hand-off.
   d. `CLAUDE.md` > Flow Control, `| VERIFY → ARCHITECT |` — confirm the
      arbitration outcome routes to ARCHITECT re-deliberation → GATE:PLAN
      re-evaluation → RED re-entry.
   e. `docs/autoflow-guide.md` > VERIFY — Test Run + Verification, the
      **Deadlock resolution** line — confirm the stated oracle carve-out (under
      a design contradiction the acceptance criteria are the *contradicted*
      artifact, so they are not the baseline) is present and consistent with (d).
3. Confirm the regression is counted against the **existing** `GATE:PLAN FAIL →
   ARCHITECT (max 3×)` cap and that no new numeric cap was introduced
   (ledger E9/E13; mechanically fenced by `AC-26-9` in
   `tests/test-issue-26-verify-architect-route.sh`).
4. Confirm that **no human escalation** is triggered before that cap is
   exhausted: read the `**Human escalation**` line in `CLAUDE.md` > Flow Control
   and confirm it now excludes the design-contradiction case, and read the
   Lifecycle Diagram's `VER -->|…| HUMAN` mermaid edge and confirm its label
   carries the same exclusion (AC-26-11d) rather than contradicting it.
5. Confirm both renderings of the Lifecycle Diagram agree: the mermaid dotted
   `VER -.->|…| ARC` edge and the plain-text fallback annotation both show the
   design-contradiction route, so the block's own claim ("The same diagram in
   plain text") stays true (ledger E14).

**Pass condition:** the amended text alone routes the step-1 case to
ARCHITECT → GATE:PLAN → RED at every one of the five reading points, the
regression consumes the existing GATE:PLAN cap, and no reading point in step 4
or 5 sends the same case to a human or leaves the two diagram renderings
disagreeing.

**Explicitly out of scope for this scenario:** whether a model in a live cycle
*in fact* follows the amended text. That is an observation about model
behavior, not about the spec, and this cycle does not claim it.
