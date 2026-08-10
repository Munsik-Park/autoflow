# Issue #71 — Manual/Environment-Dependent Verification Scenarios

Only one acceptance criterion is delegated here per the verification design
(`.autoflow/issue-71-verification-design.md` > Acceptance criteria table,
**procedure-still-executable**; ARCHITECT mutual ACCEPT, ledger entry "the
two design documents are closed against each other"). Every other criterion
carries a concrete automated method — the removal-state suite
`tests/test-issue-71-digest-removal.sh`, or one of the real-environment
oracles it drives inline (manifest regeneration, the doc-invariant registry
runner, the `#799` dual-pin guard, the hook malformed-state re-home).

---

## `procedure-still-executable` — the post-removal HANDOFF and PREFLIGHT step sequences read as an executable procedure for an operator

**Why not automated:** every scripted predicate in the removal-state suite
checks a discrete literal (a step header gone, a `[MUST]` sentence
surviving, a table row absent). Whether the **surrounding** step numbering,
ordering and cross-references still read as one coherent, followable
procedure once step 1.5 and step 6.7 are excised — no orphaned "see below"
pointing at a section that no longer exists, no step number left implying a
predecessor that vanished — is a judgment a grep cannot make.

**Steps:**

1. Read `docs/autoflow-guide.md` > **PREFLIGHT — Pre-Work** step table
   top to bottom. Confirm the sequence reads `1 → 2 → 3 → 4 → 5` with no
   gap, no leftover `1.5` row, and no step's action text still says "after
   step 1" / "before step 2" in a way that only made sense with the scan in
   between (re-read step 1 and step 2's own action cells for any phrase that
   assumed the scan's presence).
2. Read `docs/autoflow-guide.md` > **HANDOFF — PR Creation + Hand-off**
   step list top to bottom. Confirm the sequence reads `6 → 6.5 → 7 → 8`
   with no leftover `6.7` step, and that step 6.5's own text (the
   `[MUST] Findings-file max_severity contract` bullet) reads as a complete,
   self-contained mandate — not a dangling sentence that used to continue
   into the now-deleted step 6.7 clause.
3. Confirm the `HANDOFF failure → regression` flowchart immediately below
   the step list (docs/autoflow-guide.md, "HANDOFF (retry) failure:" block)
   still routes correctly with no reference to a step-6.7 failure mode.
4. Re-read `CLAUDE.md` > **Development Lifecycle — AutoFlow** phase table
   and the `Flow Control` table's `HANDOFF (review-triage) → ...` rows to
   confirm neither cites the removed digest emission as part of the HANDOFF
   sequence (the phase table's own HANDOFF one-line summary should describe
   only PR + CI + review + triage, matching `docs/autoflow-guide.md`'s
   trimmed step 6.5 → step 7 transition).
5. Re-read `docs/phases/analysis.md`'s review-response loop-check section in
   full (the block that used to sit above the now-deleted relationship
   section) and confirm it stands alone as a complete description of the
   per-issue loop check, with no forward reference into the deleted
   cross-issue-scan relationship paragraph.
6. Re-read `docs/design-rationale.md`'s two edited Known-Limitations entries
   and the edited Under-Discussion bullet in full sentence context (not just
   the struck clause) — confirm each reads as a complete, grammatical
   sentence after the removal, not a fragment.

**Pass condition:** an operator reading PREFLIGHT top-to-bottom and HANDOFF
top-to-bottom, with no other context, can follow the procedure without
hitting a numbering gap, a dangling "see below" pointer, or a sentence
fragment left over from the excised clauses.
