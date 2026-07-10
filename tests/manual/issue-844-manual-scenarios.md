# Issue #844 — Manual/Environment-Dependent Verification Scenarios (Tier-2)

This acceptance criterion is **not** covered by
`tests/test-issue-844-doc-assertions.sh` — it is a semantic/soundness judgment
a grep cannot make. Delegated per the verification design
(`.autoflow/issue-844-verification-design.md` AC2 "Testability assessment"):
this cycle is documentation-only (Type 2) — no application source, script, or
`.claude/hooks/*` change is in scope. The branch-source precondition (AC-B3)
that this scenario originally also carried has since been made an automated
RED assertion (feature design E-B3 / verification design C4 resolution) and
is asserted by `tests/test-issue-844-doc-assertions.sh` (AC-B3-a..e); only the
step-3 conservative-default judgment below remains manual.

---

## AC2 (residual) — Resume procedure step 3's conservative-default soundness (Tier 2)

**Why not automated:** the Resume procedure's step 3 ("re-enter at the phase
immediately after the last passed gate; if indeterminate, fall back to
re-running from the phase after the most recent gate whose scores are
present — never skip a gate lacking a recorded PASS") is a grep-checkable
*presence* of the rule (`tests/test-issue-844-doc-assertions.sh` AC2-e
confirms the text exists), but whether the rule is actually **safe** — that
it never resumes past a gate that should have been re-run, and never
re-runs a gate that has already legitimately passed — is a semantic judgment
over a state machine, not a fixed-string match.

**Steps:**

1. Open `docs/autoflow-guide.md` > PREFLIGHT > Resume procedure, step 3, as
   landed.
2. Walk at least these three concrete `phases` snapshots against the landed
   rule and confirm the re-entry point it derives is correct in each case:
   - **(a) Clean mid-cycle resume**: `gate_plan` has recorded `scores`
     (PASS-shaped), no phase past DISPATCH has recorded state → the rule
     must re-enter at DISPATCH/RED, not re-run GATE:PLAN and not skip ahead
     to VERIFY.
   - **(b) Gate attempted but not recorded**: a gate's `scores` object is
     present but incomplete/malformed (e.g. missing a rubric item's score)
     → the rule's "never skip a gate that has no recorded PASS" clause must
     be read to re-run that gate, not treat a partial `scores` object as a
     recorded PASS.
   - **(c) Indeterminate `phase` vs. `phases` mismatch**: the coarse `phase`
     marker suggests one point (e.g. `"in-progress"` written after VERIFY
     entry) but `phases.gate_quality` already carries recorded `scores` →
     confirm step 1's "highest phase whose gate `scores` are recorded" read
     is the one that governs (not the coarser `phase` string), so the
     procedure does not regress past an already-passed gate.
3. Confirm the "unrecoverable, report" fallback (step 2) fires — rather than
   the procedure guessing — whenever any of the three snapshots above cannot
   be resolved to a single unambiguous re-entry point (e.g. two adjacent
   gates both show empty `scores` with no way to tell which was mid-flight).

**Pass condition:** for each of the three snapshots, the derived re-entry
point matches the expected phase above, and the procedure defers to "report,
do not fabricate" whenever the state is genuinely ambiguous, never silently
picking a phase or skipping a gate lacking a recorded PASS.

---

## Tier-3 (not run this cycle) — recorded for completeness

- **Live resume exercise**: an actual abnormal-session-end + resume against a
  real `.autoflow/issue-{N}.json` mid-cycle state — this cycle is a
  documentation-only fix (Phase B §4 confirmed no hook/session-runtime
  change is in scope); the resume procedure is not exercised end-to-end
  until a future cycle's session is interrupted mid-flight.
