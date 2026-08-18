# Issue #107 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This acceptance criterion is **not** covered by `tests/test-cycle-arm-residue.sh` — it is a
reading-comprehension question about prose (does the wording actually *settle* the array-less
class for a future auditor), not a decidable predicate over document text, and is not
automatable (verification design `.autoflow/issue-107-verification-design.md`,
`normative-status-declared` row: "presence is automatable … adequacy … is a reading judgement
and stays a manual scenario").

**Coverage boundary, stated plainly.** `tests/test-cycle-arm-residue.sh`'s
`normative-status-declared (presence)` arm proves `docs/doc-invariant-registry.md` §12
contains *some* statement scoped to a `dev/*-issue-<N>` gate that declares no `cycle-arm` and no
allow-list array (grepping for `array-less` / `non-conforming`). It does not — and cannot —
prove that statement actually *disposes of* the question a later auditor will ask: "I found a
bare `dev/*-issue-<N>` gate in some suite with no `cycle-arm` header — is that suite broken, or
is it fine as written?" That is this file's M1.

---

## M1 — §12's array-less-gate statement settles the auditor's question (Tier 3)

**Source AC:** `normative-status-declared` (verification design, adequacy half) — feature design
§3.7 states the intended content: a `dev/*-issue-<N>` gate carried by a suite that declares no
`cycle-arm` and no allow-list array is **non-conforming**, because it sits outside
`scripts/test/check-cycle-scope-guard.sh`'s subject set by construction (that lint's own header
states its subject as "every enumerated spec … declaring a path allow-list array") — so nothing
holds such a gate to §2's off-branch discipline. A gate whose gated body is a **permanent
property** is not retired but **ungated** (the §2b disposition); a gate whose body genuinely
asserts a **live cycle's diff** declares `# cycle-arm:` and an allow-list array, joining the
governed form. `header-matches-content`'s `# ci-subject:` backing rule is stated in the same
paragraph.

**Procedure.**

1. Read `docs/doc-invariant-registry.md` §12 (between the `## 12.` heading and the `### 12.1`
   heading) as landed by this cycle.
2. Take the auditor's question literally: given a suite discovered tomorrow that (a) contains a
   `case`-branch label or `[[ … == … ]]` / `[[ … = … ]]` pattern (both string-equality forms;
   `!=` excluded) matching `dev/*-issue-<N>` on a non-comment, non-heredoc line, and (b) declares
   no `# cycle-arm: #<N>` header field — does §12's text tell
   the auditor, without consulting this issue's ledger or PR, which of the two dispositions
   applies (retire it, or ungate it and add `# cycle-arm:`)?
3. Confirm the text states the **rule over the shape**, not a list of this cycle's six files
   (feature design §3.7's own constraint: "§12 states a rule over the shape, not a list of this
   cycle's files … or the same audit ambiguity returns with the next leftover arm"). A paragraph
   that reads as a narrative of *this cycle's* cleanup, with the array-less/non-conforming
   language present only as color rather than as the operative rule, fails this check even though
   `tests/test-cycle-arm-residue.sh`'s presence arm still passes.
4. Confirm the text distinguishes the two dispositions (retire vs. ungate) by the **stated
   ground** ("permanent property" vs. "live cycle diff"), not merely by asserting that array-less
   gates are bad.

**Disposition.** PASS if a reader arriving at §12 with only the auditor's question in hand (no
access to this issue's ledger, PR, or `.autoflow/*` artifacts) can state which of the two
dispositions applies to a hypothetical newly discovered array-less gate, and why. FAIL, with the
specific missing element quoted, otherwise.

**Not carried automatically.** This scenario is not one `tests/test-cycle-arm-residue.sh` can
discharge itself: an automated grep can confirm a sentence containing the right keywords exists
(the presence arm already does this), but cannot confirm that sentence functions as a rule an
auditor can apply — that is exactly the reading judgement `docs/doc-invariant-registry.md` §1's
two-lane rule already delegates to human review at its own promotion boundary (§3, "a deliberate,
reviewable registry edit").
