# GREEN — Implementation

> Phase playbook for GREEN. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

The Developer AI implements the issue acceptance criteria within the cycle's scope — the feature
design, its `## Scope` section included, plus the verification design. Automated tests are one form of evidence for that scope, not
its definition: an issue AC whose disposition is `manual`, `existing-coverage`, `delivery-check`,
`environment-dependent` or `none` ([ARCHITECT](architect.md) > Output artifacts > *Test necessity*) is still
implemented; only its evidence differs.

```
1. Read the verification design's acceptance-criteria table and the test code authored by the Test AI,
   then run the RED tests the way the target runs its tests before writing any implementation and
   confirm that every `driving` and `regression` test fails — a `characterization` test may already
   pass, as RED step 2 says. A `driving` or `regression` test that already passes surfaces here —
   the criterion is already met, or the test is wrong (RED step 2) — and a row the RED report left
   without a run record is run here and its record filled in ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *A missing run is filled where it
   is found*).
2. Write the minimum code that satisfies every issue AC in scope and passes the `automated` tests.
   - [MUST] Do NOT implement behavior outside the cycle's scope — the feature design, its `## Scope` section included, and the verification design's rows. A required AC without an automated test is in scope; a behavior neither the scope nor a recorded scope judgment requires is not, whether or not a test could be written for it.
   - [MUST] A problem met while implementing that the scope does not name is judged under [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules > *Scope judgment* and recorded under `## Scope judgments` in the GREEN report: directly related and desirable to fix here → fixed in this cycle, with the tests the fix requires run and recorded; directly related but not desirable → left, with its separation reason; not directly related → left, reported in one line. A fix that would contradict a design **decision** returns to ARCHITECT. Work that shows an acceptance criterion defective — whether through a problem the scope does not name or an item a criterion names ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*) — is raised in the report for the operator, not worked around by keeping the criterion's letter ([ARCHITECT](architect.md) > *Report routing* > *An acceptance-criterion change raised later in the cycle*).
   - [MUST] Stay on the change surface defined in the plan — see [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules.
   - [MUST] Tests verify correctness; they do not define the solution. Implement the actual logic that solves the problem for all valid inputs — never hard-code to the test inputs, special-case the assertions, or add workaround/helper scripts just to turn a test green. "Minimum code" means the smallest *general* implementation that satisfies the AC, not the narrowest path that satisfies the assertions. If a test looks wrong or infeasible, raise it as a VERIFY cause-branch rather than coding around it.
   - For a row verified with a tool (a `manual` row whose executor is `AI: <tool>`), look at the result with that tool while implementing; the row's evidence is the observation record the Test AI writes at VERIFY step 1, not this look ([ARCHITECT](architect.md) > *Tools*).
   - [MUST] Run locally what the change requires and nothing more: this cycle's `automated` tests and the tests you judge the change reaches, the way the target runs its tests ([RED](red.md) > *Derivation on entry*), recording the command, the log and its summary line. There is no local whole-tree run — none scheduled, none held in reserve ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *Local verification*).
   - [MUST] If the acceptance criteria are themselves mutually unsatisfiable — no implementation can satisfy them all — implement the satisfiable subset, record the contradiction in `.autoflow/issue-{N}-*-green-blocker.md` (the conflicting AC IDs, the measurement that reproduces the conflict, and `path:line` anchors at the cycle's commit), and proceed to VERIFY; the residual failure is what the arbitration adjudicates.
3. Before committing, if this change touched a manifest-registered source, run
   the manifest regen and stage the result in the same commit.
   - [MUST] If `git diff --name-only <base>...HEAD` intersects
     `jq -r '.artifacts[].source' setup/manifest.json` on any path other than
     `setup/manifest.json` itself, run `setup/gen-manifest-hashes.sh` and stage
     the regenerated `setup/manifest.json` in this commit — the check is
     mechanical set-intersection, not a judgment call. See
     [`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface
     Rules > Derived artifacts.
4. Commit (feat/fix branch). The report's Evidence anchor is the step-2 run's log, with the
   command that produced it and the summary line read from it (Reporting Format item 5); the
   orchestrator confirms it by reading that line at the cited log path, and re-runs the command
   only when the log is absent or does not carry it ([`CLAUDE.md`](../../CLAUDE.md) > Execution
   Principles > *Verify role-spawn claims*).
```
