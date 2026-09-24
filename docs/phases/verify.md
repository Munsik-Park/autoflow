# VERIFY — Test Run + Verification

> Phase playbook for VERIFY. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

Run the tests; on failure, branch by cause.

```
1. [MUST] Local run, once: execute the cycle's local run set — every `automated` row this cycle
   authored or changed plus every `delivery-check` row — and record each run's command,
   its log and its summary line ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *Local verification*). The means
   follows where the asset lives: a test in the target's tree runs **the way the target runs its
   tests** ([RED](red.md) > *Derivation on entry*), while a `cycle`-layer asset is **invoked directly by its
   path** under `.autoflow/issue-{N}-local/` (`bash .autoflow/issue-{N}-local/<asset>`) — no driver
   is shipped for it, and the recorded command names that path. Before the run, match the design table's rows against the run record
   so far (the RED and GREEN reports): a row with no record — or whose log is absent or does not
   carry the recorded line — is run here and its record filled in — an
   omission is filled in place, never routed as a failure ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools >
   *A missing run is filled where it is found*). A check that did not execute is `not-run`, never
   `passed`. Nothing is inherited and no whole-tree run happens here — regression verification is
   HANDOFF step 5's CI.
   A `manual` row whose executor is `AI: <tool>` is part of the run set: the Test AI performs its
   scenario with the tool and writes the row's **observation record** under
   `.autoflow/issue-{N}-local/` — what was looked at, how (the tool and the steps), the artifacts it
   left (by path under the same prefix), the comparison against the referenced material, and one
   result line, `observation: match` or `observation: mismatch — <what differs>`
   ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools the work needs*). A mismatch is a failure
   and branches as step 2, the observation record passed as the workflow's `failLog`; a row with no
   record is `not-run` and is filled here.
2. Branch on result:
   All PASS → step 3.
   Some FAIL → cause branching (run under delegated facilitation — the `verify-cause-branch` workflow returns a single
   next_action — RED | GREEN | SEQUENTIAL_FIX | EVALUATION_AI — and the orchestrator
   routes on it; it never sees the round-by-round exchange; see [`CLAUDE.md`](../../CLAUDE.md) > Deliberation Isolation):
     The workflow hands the failure log + test code + implementation code to both AIs — for an
     observation mismatch, the observation record (as `failLog`) + the scenario document and the
     referenced material it names, in place of the log and the test code.
     Test AI:      "Does my test accurately reflect the acceptance criterion?" — self-check.
     Developer AI: "Does my implementation meet the acceptance criterion?"     — self-check.
       ├─ fix_test + no_problem → RED            → fix test → re-confirm Red → re-enter GREEN
       ├─ no_problem + fix_impl → GREEN          → fix implementation → re-run VERIFY
       ├─ fix_test + fix_impl   → SEQUENTIAL_FIX → fix test first → Red → fix impl → Green
       ├─ no_problem + no_problem → EVALUATION_AI → deadlock: Evaluation AI judges against acceptance criteria — except on a design contradiction (see Deadlock resolution below)
       └─ a missing/errored self-check → EVALUATION_AI (recorded as "missing", never as no_problem)
3. Minimal-implementation check (Test AI):
   diff analysis: does the implementation introduce observable behavior or contract
   outside the cycle's scope (feature design with its `## Scope` section + verification design)?
     ├─ Everything the diff does is in scope → PASS
     ├─ Behavior outside it → the Test AI judges it under Change Surface Rules > Scope judgment,
     │  against the GREEN report's recorded judgment when there is one, and records its own under
     │  `## Scope judgments` in the VERIFY report:
     │    ├─ directly related, desirable to fix here → in scope; the Test AI names the run GREEN
     │    │  recorded for it, and a fix with none has the tests it requires run here and recorded —
     │    │  never by silently adding a test
     │    ├─ directly related but not desirable, or not directly related → ask the Developer AI
     │    │  to remove it, stating the separation reason or the condition that fails
     │    ├─ the Test AI's judgment differs from the GREEN report's → one orchestrator judgment
     │    │  between the two recorded grounds, in an `O` ledger entry (the operator's when the
     │    │  orchestrator is not confident) — not an ARCHITECT round
     │    └─ keeping it would change a design decision → a scope question to ARCHITECT
     ├─ What the diff shows — in scope or out — reveals an acceptance criterion defective
     │  ([`decision-ledger.md`](../decision-ledger.md) > Acceptance-criterion decisions) → raised for the operator,
     │  not resolved by keeping the criterion's letter ([ARCHITECT](architect.md) > Report routing > An
     │  acceptance-criterion change raised later in the cycle)
     └─ A helper, private branch or internal abstraction whose required behavior is already
        protected at a higher level does not owe its own direct test — that is in scope, not a gap
4. Mock-boundary fidelity check (Test AI):
   for every test double (mock / stub / fake) standing in for a real interface,
   re-derive the real interface at HEAD (signature, argument count, return shape,
   error path) and confirm the double matches — cite the real implementation's
   file:line, at the commit the report is keyed to, in the report.
     ├─ All doubles match → PASS
     └─ A double diverges → masked failure, not a Green → branch by cause as in step 2
        (a test built on a wrong double → RED; the impl wrong against the real interface → GREEN)
```

**Detection record**: the outcomes of steps 3 and 4 are recorded on the per-issue decision ledger
`.autoflow/issue-{N}-ledger.md` as a fixed-field entry whose heading carries a `verify-detection` marker,
the cycle, and the VERIFY pass. The Test AI reports the outcomes;
**the orchestrator appends the record** — written **at VERIFY exit**, on every VERIFY pass that reached
step 3, before the phase transition is taken (to REFINE on a pass, or to RED / GREEN / SEQUENTIAL_FIX /
Evaluation-AI arbitration on a branch). Entry fields: `step-3 minimal-implementation` and
`step-4 mock-boundary fidelity`, each one of `detected` / `clean` / `not-run`; `iteration set` — the
doubles by name with the real interface each stands for, or `none`; `grounds` — the Test AI report's
Evidence anchor; `authority` — `VERIFY step 3/4 record`.

- **Vocabulary**: `detected` = the check found out-of-scope observable behavior it did not accept
  into the scope, or a diverging double;
  `clean` = the check ran and found none; `not-run` = the check did not execute. A check that did not
  execute is recorded as `not-run` and **never** as `clean`.
- **Non-interference with HANDOFF's auto-resolution cap**: a `verify-detection` entry is a **record, not
  a decision** — its marker is distinct from `review-autofix`, it is not an auto-resolution attempt, and it
  neither increments nor resets that cap's count window (step 6.5).
- **Non-interference with the ARCHITECT ledger seed**: the entry's `authority` is `VERIFY step 3/4 record`,
  outside the settled-decision set the seed rule selects (`ARCHITECT agreed` / `ARCHITECT mutual ACCEPT` / `ARCHITECT rejected`),
  so a detection record is never seeded into a later deliberation as a settled decision. The ledger's
  no-re-litigation rule binds decisions, so a later cycle's detection outcome neither supersedes nor is
  blocked by an earlier one.

**Deadlock resolution**: Evaluation AI judges against the acceptance criteria as the objective baseline — except on a design contradiction, where the verdict is ARCHITECT re-deliberation. Its verdict is one of four:

- the test misreads an acceptance criterion → RED;
- the implementation misses an acceptance criterion → GREEN;
- **design contradiction** — implementation and test are each faithful to the design and the
  acceptance criteria are mutually unsatisfiable, reproduced by measurement → **ARCHITECT
  re-deliberation**. The Developer AI has already recorded the contradiction in
  `.autoflow/issue-{N}-*-green-blocker.md` at GREEN (see GREEN step 2): the conflicting AC IDs,
  the measurement that reproduces the conflict, and `path:line` anchors at the cycle's commit. The re-deliberation
  returns through GATE:PLAN and re-enters RED, and consumes the existing GATE:PLAN → ARCHITECT cap
  (max 3× per cycle; the 4th → human);
- undecidable → human.

**Max round-trips**: GREEN ↔ VERIFY max 3. After 3 unresolved → human.

**Foreground execution note**: a short re-verification (a suite re-run) is a foreground command — the assigned Developer AI runs it foreground and reports, or the orchestrator runs it directly foreground — never a background spawn-and-wait (`docs/role-common-rules.md` > Bash Execution Mode).
