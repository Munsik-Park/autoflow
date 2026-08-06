# Issue #62 — Manual/Environment-Dependent Verification Scenarios

This acceptance criterion is **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `62-AC*`), `test/workflows/run.mjs`, or
`tests/test-issue-62-sequential-rounds.sh` — it is the issue's own **outcome**
criterion (fewer false-negative ESCALATEs from a navigational-counter treadmill),
which depends on a live opus sub-agent's actual deliberation behavior and has no
deterministic oracle. Delegated per the verification design
(`.autoflow/issue-62-verification-design.md` §1.5, §2.3): the automated lanes prove
the **mechanism** (round order, carry-payload shape, citation-mode partitioning by
mutability) — never the outcome. Any claim that the automated suite proves the
outcome is unsupported; that is exactly the gap this manual scenario exists to
close, mirroring the boundary #56/#59 recorded for their own outcome-level items
(`tests/manual/issue-56-manual-scenarios.md`, `tests/manual/issue-59-manual-scenarios.md`).

---

## M1 — Live ARCHITECT convergence + navigational-counter classification (Tier 3, environment-dependent)

**Source AC:** AC-62-27 — a live ARCHITECT deliberation converges without a
navigational-counter treadmill (the issue's actual goal).

**Step 0 (pass/fail, not an observation):** Before any counter classification,
confirm that `Workflow({ name: "architect-deliberation", args: { issue: "<N>" } })`
**launches at all** — i.e. the runtime does not reject the script pre-execution
with `SyntaxError: import() is not available in workflow scripts.` (the defect
recorded against the pre-fix script, B18/B19 in the verification design). A grep
proving the dynamic `import()` is gone (AC-62-29) cannot by itself prove nothing
*else* blocks the launch — only a real invocation can. A launch failure here is a
**hard FAIL**, routed to GREEN, not merely noted.

**Setup:** Run a real `architect-deliberation` Workflow on a live issue (post-GREEN,
on the fixed script).

**Procedure:** Record:

1. Rounds to converge (or `ESCALATE` at the 6-round cap).
2. For every counter present in the **terminal** round, classify it as
   **substantive** (names a concrete gap in the feature or verification design,
   grounded in a re-derived `path:line` or section/item-ID citation) or
   **navigational** (restates a position already addressed, cites no new
   ground, or is a re-assertion of carried text without re-derivation).
3. Whether the Developer AI's open-concern entries (AC-62-28's channel) actually
   appear in `${feature}` as named entries, and whether the Test AI's next-round
   response engages with them (the residual behavioral risk the automated lane
   cannot assert — verification design §2.2).

**Baseline for comparison** (the issue's own measurement, not a threshold): 4
prior runs, 2 `ESCALATE`, terminal counters 0 substantive : 2–3 navigational; the
one run that manually adopted section-ID citation converged in 4 rounds.

**Pass / observation, not a gate:** a single post-fix run cannot separate the fix
from model variance, so no numeric threshold is asserted here. Record the
rounds-to-converge and the substantive:navigational ratio at the terminal round
for the cycle notes; a result that does not visibly improve on the baseline is a
signal to re-open the mechanism, not an automatic FAIL of this cycle.

**Fail (step 0 only):** the Workflow does not launch, or launches and is rejected
before reaching the first `agent()` call.
