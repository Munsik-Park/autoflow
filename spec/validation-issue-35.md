# Validation — does the declaration describe the cycle that actually ran?

Target: the issue **#35** canary cycle (PR #36, merged `ee3b2e7`). Method:
trace every durable artifact of the cycle — the cycle-digest record
(`docs/cycle-digest.jsonl:13`), the commit sequence, the branch name, the PR —
against the declarations in `spec/steps/`. Where the cycle cannot be described
by the declaration, the declaration is wrong; those findings are the
deliverable.

## Trace

| Declaration | Evidence from #35 | Described? |
| --- | --- | --- |
| `preflight` → work-branch | branch `dev/2026-07-26-issue-35` (PR #36 head, per the PREFLIGHT step-5 naming convention) | yes |
| `diagnose` → necessity-scores | digest `gate_hypothesis_structure: {pass:true, avg:8, items:{behavior_gap:8, code_change_necessity:8}}` | yes |
| `diagnose` next `code-change-needed-feat` | digest `gate_hypothesis_cause: {verdict:"skipped (feat issue)"}` — the cause gate was routed past, matching `applies-to: bug` | yes |
| `architect` loop `until: mutual_accept`, bounded | digest `architect: {rounds:3, escalate:false}` — converged in 3 rounds, under the binding cap of 6; round count was not predetermined | yes |
| `gate_plan` verdict computed | digest `gate_plan: {pass:true, avg:8.2, items:{feasibility:9, dependencies:8, scope:8, security:9, test_plan:7}, below7:[]}` — pass derives from raw items | yes |
| `red` produces tests, Red confirmed | commit `84a8fca test(#35): add phase-marker emitter test suite (RED)` — precedes the implementation commit | yes |
| `green` produces implementation | commit `edeb27d feat(#35): add phase-marker emitter script` | yes |
| `refine` produces refactor | commit `6335da5 refactor(#35): apply /simplify to the phase-marker emitter` | yes |
| `audit` verdict computed | digest `audit: {pass:true, avg:8.8}` | yes |
| `gate_quality` verdict computed | digest `gate_quality: {pass:true, avg:8.6, below7:[]}` | yes |
| `handoff` produces pr + cycle-digest | PR #36 opened from the dev branch; commit `b2cea72 chore(#35): append cycle digest record` (the digest co-rides the PR) | yes |
| `handoff` next `review-clean: end` | digest `review_max_severity: "None"`, `escaped_defects: []` — flow ended at the open PR | yes |
| `end` = merge is external | merge commit `ee3b2e7` is a GitHub merge of PR #36, not an in-flow action | yes |

## Findings

**F1 — a produced artifact the declaration does not name.** Commit
`e32c497 chore(#35): register the phase-marker cycle surface in CI and the guards`
sits between GREEN and REFINE and registers repo-local derived artifacts
(per-cycle guard allow-list, CI surface). No step's `produces` names it, and it
should not: guard/manifest registration is a **host-repo discipline**, not a
portable output. Resolution adopted: the declared `produces` list is the
portable minimum; a binding may extend it with repo-local derived artifacts
(now stated in `spec/README.md` > Conventions).

**F2 — regression edges are unvalidated.** Every `fail`/`retry` edge in the
declarations is derived from the docs, not from this cycle: the digest records
`regressions: {gate_plan:0, verify:0, audit:0, gate_quality:0}` and zero
review-autofix cycles, so #35 exercised only the pass path. The fail edges are
declared but **unvalidated** — a later cycle that regresses is the validation
vehicle. (Also note the digest's own disclosure: the per-gate regression counts
are currently emitted as constant 0 — "not derived", not "zero regressions";
for #35 the pass-path reading is corroborated by the linear commit sequence.)

**F3 — mechanical steps leave no durable trace.** `validate`, `integrate`, and
`dispatch` produce artifacts (`validation-report`, `integration-result`,
`task-assignments`) that in the actual cycle existed only inside session
context: no commit, no digest field, no `.autoflow` artifact survives for them.
The declaration is not contradicted, but it is **unfalsifiable** for these
steps from durable evidence alone. A runner that owns these steps would persist
their results, closing the gap.

**F4 — one declaration ambiguity found and left open.** `diagnose` currently
bundles intake triage, the isolated two-analyzer fan-out, necessity scoring,
and hypothesis work in one step with six `next` outcomes — the widest step in
the contract. #35 (a feat issue) exercised only one path through it. Whether
`diagnose` should split is deferred until a cycle exercises the other paths;
splitting now would be design ahead of evidence.

## Verdict

The declaration describes the executed #35 path completely — no trace item
required bending a declared field. The contract's untested surface is the
failure/regression half (F2) and the mechanical steps' unrecorded outputs (F3).
