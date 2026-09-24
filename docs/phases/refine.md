# REFINE — Refactor (Green maintained)

> Phase playbook for REFINE. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

**[MUST]** REFINE entry spawns the Developer AI fresh, on the model the policy names for REFINE, carrying only `.autoflow/issue-{N}-*.md` paths. The rule forbids carrying VERIFY's spawn into REFINE by reusing its context — the phase boundary is a fresh spawn.

```
1. Developer AI: the refactor pass over the cycle's diff — /simplify as judged, then the comment check.
   /simplify:
   - Decide whether to run /simplify, and over what — then run it as decided. Whether it runs
     and which files it covers is the Developer AI's judgment on the diff
     ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2), recorded with its grounds in the
     REFINE report's `simplify:` / `simplify-grounds:` lines (below). The report is written
     whether or not it ran.
   - When it runs: three parallel agents (reuse / quality / efficiency); apply suggested fixes
     (no behavior change — tests must pass without modification); a finding of nothing is
     `none` in each section.
   - A suggestion outside the change surface is a refactor noticed in passing and is rejected
     (Change Surface Rules > REFINE scope). A suggestion that describes a behavior defect is
     rejected as behavior-changing and judged under Change Surface Rules > *Scope judgment*; one
     judged directly related goes to the report's section 3 whatever its subject.
   Comment check (every pass, whether or not /simplify ran):
   - Over the lines the cycle's diff adds (`git diff <base>...HEAD`), identify the comment lines
     by each file's language; a directive a tool reads is code, not a comment
     ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules >
     *Code comments*).
   - Match each added comment line against the classes that rule sends out of a comment and that
     a pattern finds without judgment: an issue / PR reference (`#<digits>`, `PR #`), a review
     round, an acceptance-criterion identifier, a path of another file, a change-history marker
     (`no longer`, `previously`, `formerly`, and their equivalents in the comment's language).
   - Read the added comments the pattern did not hit against the same rule: a restatement of the
     code, design discussion, another file's contract and commented-out code are found by reading,
     not by a pattern. Each comment read as one of them is a hit of that class.
   - Dispose of every hit: removed, or rewritten to what the rule admits (when unsure the
     rewrite is still true, removed); kept only when the match is not the class — the reason
     stated. The content goes where the rule sends it when it is not already there. A hit in a
     test file is outside the Developer AI's write scope — the Test AI disposes of test-file hits
     before its commit (RED step 1) — so it is recorded as `test file — outside scope` and left
     in place.
   - Record the ratio of comment lines to added lines as an observation. No threshold passes or
     fails it.
   - The check is a signal written into the report, not a gate: no hook reads it and it routes
     nowhere.
2. [MUST] Confirm Green after the refactor: when step 1 changed a file, re-run the cycle's local run
   set (VERIFY step 1's command) once and record the command, the log and its summary line; when step 1
   changed nothing, the VERIFY step-1 record stands and nothing re-runs.
   - On FAIL → revert step 1's changes → Developer AI fixes (max 2×).
3. Commit (refactor type; skip if step 1 made no changes).
```

**Max retries**: 2; on second failure, abandon refactor and proceed to VALIDATE
with the Green state from VERIFY. A comment-check hit the abandoned change had removed or rewritten
is then recorded as `not disposed — refactor abandoned`.

## REFINE report (`.autoflow/issue-{N}-refine-report.md`)

The Developer AI writes one report per REFINE pass, with four sections in this order — every
section is present and a section with nothing to say states
`none` explicitly (an omitted section is a VALIDATE step-4 failure, not a silence). The report
opens with two lines that record step 1's judgment — `simplify: run <files or scope>` or
`simplify: not run`, then `simplify-grounds: <what in the diff did or did not warrant it>` — and
when /simplify did not run each of the first three sections reads `none`:

1. `## Applied` — each /simplify suggestion applied, one line each.
2. `## Rejected / deferred` — each suggestion not applied, with the reason (`behavior-changing`,
   `out of scope`, `disagree`, …). A `behavior-changing` suggestion carries its scope judgment
   (`directly related — <condition>` or `not directly related`).
3. `## Out-of-scope observations — guard / boundary logic touched` — the subset of the rejected
   list whose reason is *behavior-changing* **and** whose subject is validation, a guard, path /
   root resolution, input or output boundary handling, or error handling — plus every
   behavior-changing suggestion the Developer AI judged directly related to the issue, whatever its
   subject, with that judgment. Each entry names the suggestion, the `path:line` (at the report's commit) it points at,
   and what behavior would change.
4. `## Comment check` — step 1's comment check, written on every pass. It opens with the line
   `comment-ratio: <added comment lines>/<added lines> (<percent>)`, an observation with no
   threshold, then one line per hit: its `path:line` at the report's commit, its class, and its
   disposition — `removed`, `rewritten`, `kept — <why the match is not the class>`,
   `test file — outside scope`, or `not disposed — refactor abandoned`. A pass with no hit states
   `none` below the ratio line. The section is a signal recorded in the report; no phase passes
   or fails on its content. On a target, GATE:QUALITY reads it — the ratio line included — under
   `Minimal implementation`, which records the comments' content and volume findings without
   lowering its score ([GATE:QUALITY](gate-quality.md) > *Code comments in a target*).

GATE:QUALITY reads section 3 as scoring input for `Quality` and `Impact scope` ([GATE:QUALITY](gate-quality.md) > Scoring) and cites
what it read. Writing the section is the Developer AI's duty; judging it is the fresh evaluator's —
the author's "this is fine" is not the disposition.

**Foreground execution note**: the step-2 re-run is a short foreground command — the assigned Developer AI runs it foreground and reports, or the orchestrator runs it directly foreground — never a background spawn-and-wait (`docs/role-common-rules.md` > Bash Execution Mode).
