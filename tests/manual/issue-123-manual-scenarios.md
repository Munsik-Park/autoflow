# Issue #123 — Manual/Environment-Dependent Verification Scenarios

AC9 is the only acceptance criterion with no automated path
(`.autoflow/issue-123-verification-design.md` > Testability assessment): the
hosted Workflow runtime is not launchable from this repository's test tree —
`test/workflows/run.mjs` states its own scope explicitly (`test/workflows/run.mjs:8-11`,
"They do NOT exercise a live Claude Code Workflow runtime"), and the script
cannot observe its own environment (no filesystem, `import(` rejected at
parse time). Every other AC1-AC13 criterion is covered by `test/workflows/run.mjs`
("ARCHITECT: cap-round closing half-round" cases) and the
`tests/fixtures/doc-invariants.json` registry entries (`123-AC7-*`, and — since
GATE:QUALITY promoted them from the now-retired cycle-scoped
`tests/test-issue-123-closing-half-round.sh`, docs/doc-invariant-registry.md
§15 — `123-AC5-closing-reason-*` / `123-AC6-closing-label-*`).

---

## M1 — Closing half-round under the real hosted Workflow runtime (Tier 3, environment-dependent)

**Source AC:** AC9 — the closing half-round behaves the same under the hosted
Workflow runtime as the mock-runtime harness predicts.

**Setup:** On a session satisfying the Workflow prerequisites
(`docs/teammate-contracts.md` > Facilitator > Realization > Invocation /
version / config — Claude Code v2.1.154+, Dynamic workflows enabled), pick or
construct an issue whose ARCHITECT deliberation is expected to reach the
6-round cap without mutual ACCEPT at round 6 — e.g. an issue with a design
axis the Test AI and Developer AI are likely to keep contesting past round 5
(a genuinely disputed scope boundary works better than an artificially
withheld ACCEPT, since the latter risks the sub-agents converging early on
their own devil's-advocate judgment).

**Procedure:** Run `Workflow({ name: "architect-deliberation", args: { issue: "<N>" } })`
and let it proceed to completion. Record, from the workflow's own console log
(`console.log` lines the script emits per round) and the returned result
object:

1. whether round 6 (`MAX_ROUNDS`) is reached with the Developer AI's verdict a
   grounded ACCEPT (`accepted(lastDev)` true) and the Test AI's verdict not a
   grounded ACCEPT;
2. whether a further Test-AI-only call is made after round 6 (visible as an
   additional round-log line or an additional agent invocation beyond the
   6 rounds x 2 calls + 2 draft calls the console log would otherwise show);
3. the returned `verdict`, `rounds`, and `escalation` fields, and whether
   `rounds` still reads `6` (not `7`);
4. on an ESCALATE outcome, whether the appended ledger entry's grounds
   reference the closing call's own counters/dispositions rather than the
   stale round-6 Test verdict.

**Pass:** the closing call is made under the trigger conditions above, `rounds`
stays at `6`, and the verdict/grounds match what the mock-runtime harness's
AC1/AC2/AC4 cases predict for the same input shape — a grounded closing ACCEPT
yields `CONVERGED`, anything else yields `ESCALATE` with grounds sourced from
the closing turn.

**Fail:** the closing call is never made despite the trigger conditions
holding, `rounds` reads `7` (an extra exchange was counted), the hosted
runtime rejects or mis-delivers the closing `agent()` call in a way the
injected-globals mock in `test/workflows/run.mjs` does not reproduce, or the
returned verdict/grounds diverge from the harness's prediction for an
equivalent input shape.

**Status:** delegated to user (operator-run; requires a live Claude Code
session with Dynamic workflows enabled — not executable from this
repository's automated test tree).
