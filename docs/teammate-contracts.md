# Teammate Contracts

> This document defines the role contracts for the teammates that the AI Orchestrator dispatches in AutoFlow: **Evaluation AI**, **Test AI**, and **Submodule AI (Developer AI)**. The Orchestrator's own coordination responsibilities remain in [`CLAUDE.md`](../CLAUDE.md) > Team Structure. Per-phase spawn model policy: see [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase.

---

## Evaluation AI (subagent)
- Independent evaluator that does not participate in planning or implementation.
- Bias prevention: a fresh agent is spawned every call.
- Spawn model: resolved from the spawn policy, never restated here — `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` for the rubric-scored gates (`gate-hypothesis`, `gate-plan`, `audit`, `gate-quality`) and for `verify-arbitration`. Source: `.claude/autoflow/spawn-policy.json`; revert conditions: CLAUDE.md > Spawn Model.
- Spawn mode: **anonymous direct** — `Agent(subagent_type: "autoflow-evaluator", model: "…")` — never a named team spawn. The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores; under a named spawn the final turn text is discarded and the gate deadlocks on a report that never arrives (`docs/teammate-common-rules.md` > Result delivery path by spawn mode). Contract: `CLAUDE.md` > Spawn Model — Phase-by-Phase > Spawn mode by role lifetime.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `docs/teammate-contracts.md`, target file paths, and — for GATE:PLAN and GATE:QUALITY — the path of the issue's **acceptance-criterion list** (`.autoflow/issue-{N}-phase-b.md` > `## Acceptance criteria`) together with the issue decision ledger (`.autoflow/issue-{N}-ledger.md`). Those two are the declared source the AC-authority check diffs against; without them the check has nothing to establish authority from. The list is an **input the evaluator reads**, never one it may reinterpret, rewrite or judge the merit of.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — instruct the AI to read `docs/teammate-contracts.md > [section]` or `.autoflow/*` file paths directly. The same principle (file-path-only references) applies to all teammate dispatches; see [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list them in `recommendations` (or `blocking_issues` when score-blocking). Severity and confidence are expressed through the `score` and `reason`, never by silently omitting a finding. The rubric score is the filter; the finding stage prioritizes coverage.
- **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Recent Claude models follow such filtering instructions literally — they investigate just as deeply but drop sub-bar findings instead of reporting them, which lowers recall. Let it report all findings and let the score rank them.

### Pre-scoring FAIL hypothesis (consider-the-opposite)

This subsection binds **every rubric-scored gate** — GATE:HYPOTHESIS (both the structure and cause forms), GATE:PLAN, AUDIT, GATE:QUALITY — and the doc-evaluation form when one is run, as a shared Evaluation AI contract. No gate opts out.

- **[MUST]** Form the FAIL hypothesis first: adopt the hypothesis **"this deliverable must FAIL"** and search for the strongest evidence supporting it, framed in the terms of this evaluation's own rubric items. The search re-derives the deliverable's cited anchors from the current source (`path:line`, command output, `git show HEAD:<file>`) rather than accepting the deliverable's own account of them.
- **[MUST]** Attempt to refute each FAIL case found. A refuted case does not affect the score. A case that survives refutation is carried into the affected item's `reason` and listed in `recommendations` (or `blocking_issues` when score-blocking). A surviving case may coexist with a score of 7 or higher: the routing obligation is to record it, not to lower the item.
- **[MUST]** Assign scores only after the FAIL hypothesis has been formed, searched, and dispositioned. Scoring never precedes the search.
- **[MUST]** Record the search in the `fail_hypothesis` output field, including the case that finding nothing was the outcome. An empty or omitted `fail_hypothesis` is a contract violation: the orchestrator **rejects** such an evaluation report and re-spawns a fresh Evaluation AI, exactly as it rejects an anchor-less teammate report (`CLAUDE.md` > Execution Principles > *Verify teammate claims*). The re-spawn is capped (max 2) — on a third consecutive report whose `fail_hypothesis` is empty or omitted, stop re-spawning and escalate to the user. No machine validator enforces this — the hook reads only `scores` — so the orchestrator's acceptance is the enforcement point.

### REFINE observations (GATE:QUALITY input)

Binds the GATE:QUALITY form only (issue #135).

- **[MUST]** Read the REFINE report's `## Out-of-scope observations — guard / boundary logic touched` section, disposition every entry (`defect — scored under <item>` or `not a defect — <reason>`), and record the dispositions in the `refine_observations` output field. A `defect` entry is scored under `Quality` or `Impact scope`. The author's rejection reason is context, not the disposition — the section exists because REFINE may not change behavior and therefore cannot be the judge of the behavior it declined to change.
- **[MUST]** A report whose `refine_observations` is absent, or that does not account for every entry in the section, is rejected and the evaluator re-spawned, with the same cap (max 2) and escalation as an empty `fail_hypothesis`.

### Remedy class (GATE:QUALITY FAIL routing)

Binds the GATE:QUALITY form only. The orchestrator routes a FAIL's re-entry from this field
([`autoflow-guide.md`](autoflow-guide.md) > GATE:QUALITY > FAIL routing); the evaluator is the
classifying authority and the implementing roles do not re-classify.

- **[MUST]** On a FAIL, tag every item scored below 7 with a `remedy_class` — `doc` (documentation /
  comment text, no behavior change), `test` (test assets), `impl` (implementation), `design` (the
  converged design itself) — starting from the default per item (`scripts/gate/remedy-route.sh
  default-class <item>`) and overriding it with a stated reason when the default misreads the
  defect (a `Doc updates` cap caused by a prompt string or a hook message is `impl`).
- **[MUST]** Write `operator` when the class cannot be stated with confidence. Do not guess: an
  `operator` entry pauses the cycle for the operator's decision, which is cheaper than a wrong route.
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: the
  orchestrator rejects it and re-spawns a fresh Evaluation AI, with the same cap (max 2) and the same
  escalation as an empty `fail_hypothesis`.
- **[MUST]** On a re-entry evaluation, score afresh only the items listed in `rescore.rescored` — the
  previously failed items plus any inherited item whose anchor files the re-entry diff touched — and
  copy the rest from the cited prior report (`rescore.source`). The fresh-spawn rule is unchanged;
  the input is narrowed, not the independence.

### Execution discipline (scope, sampling, time)

This subsection **constrains** the pre-scoring FAIL hypothesis above; it does not replace it. The
evaluator still forms the hypothesis first, still re-derives anchors, still records the search in
`fail_hypothesis`. Governing record:
[`docs/adr/0019-scope-fit-verification-policy.md`](adr/0019-scope-fit-verification-policy.md).

- **[MUST] Host-record citation-inheritance.** Where the anchor being re-derived is a **suite
  verdict**, resolve it against the host's own record before executing anything: run
  `bash scripts/test/suite-coverage.sh --ledger .autoflow/issue-{N}-ledger.md --cycle <C> --candidates all`
  and read the per-suite records. A suite reported `INHERIT` is **cited, not re-executed**. A suite
  reported `RUN`, or a record the evaluator's own capture point contradicts, is executed. This
  mirrors the discharge the orchestrator already holds ([`CLAUDE.md`](../CLAUDE.md) > Execution
  Principles > *Verify teammate claims before dispatch*) and closes the asymmetry that no equivalent
  rule reached the evaluator. The check is **performed** — a command with an output — never
  asserted, so "I inherited" is itself an anchor a reader re-derives. The citation lands in
  `inherited_verdicts`, a key of the [Evaluation Output Format](evaluation-system.md), always
  present and `[]` when the evaluator executed everything.
- **[MUST] Sampling default.** A blind-spot search over a **repeated surface** takes a
  representative sample per rubric item by default (one or two instances), and states the sample
  basis in `fail_hypothesis`. Exhaustive enumeration is entered only when a sampled instance yields
  a FAIL case that survives refutation — escalate on a hit, rather than enumerate by default.
  Coverage of *finding types* is unaffected: the finding-coverage rule above still forbids dropping
  a found issue.
- **[MUST] Time cap.** An evaluation declares a **wall-clock cap** and reports against it. The cap
  is **30 minutes** unless the spawning orchestrator declares a different value in the spawn prompt,
  in which case the declared value governs and is reported. On reaching the cap the evaluator stops
  searching, scores what it searched, and records every unsearched item as `not-searched` in
  `fail_hypothesis` — **never as clean**. This is the same truthfulness rule the phase records apply
  with `not-run` ≠ `clean` and `inherited` ≠ `passed`. A cap reached with unsearched items is a
  signal to the orchestrator that the rubric item's evidence is thin, not a pass.

  *Basis for 30 minutes*: measured on the #108 cycle and recorded in issue #112's body — an
  undisciplined first evaluation ran 81 minutes; after citation-inheritance and sampling were
  instructed, the same evaluations completed in 4 and 31 minutes with detection power retained (the
  second found a real defect). The cap bounds the disciplined range that was observed to work rather
  than the runaway that motivated it, so it constrains the failure mode without cutting into
  evaluations that already terminate.

---

## Test AI (testing teammate)
- Participates in plan synthesis (ARCHITECT) from a verification perspective — "how will this design be verified?"
- Authors the verification design document: acceptance criteria → verification disposition (`automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` / `none`) → method, with a one-line reason on every non-automated issue-AC row and a test kind (`driving` / `regression` / `characterization`) on every automated row.
- **[MUST]** Applies **Test necessity**: a test exists only when it is needed — the burden of proof lies on the test, and the default under uncertainty is `none`. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT > Output artifacts > *Test necessity*.
- **[MUST]** Assigns a composition oracle — an oracle driving the contact point through the real execution environment, non-mock — whenever the design's change surface names shared state a settled decision also names, and states the determination (including the negative case) in the verification design. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT > Output artifacts > *Composition oracle*.
- **[MUST]** Justifies **Verification depth**: the verification design carries a risk line, and every verification layer and new spec file states the failure mode it catches that no other layer catches; a layer that cannot name one is dropped rather than argued down. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT > Output artifacts > *Verification depth*.
- Writes test code before implementation (Test First) and confirms Red — every `driving` and `regression` test fails; a `characterization` test may start green.
- For untestable items: states the reason and proposes alternatives (design change / manual scenario (except where the composition-oracle clause applies) / mock (same exception)).
- Performs minimal-implementation verification after implementation: detects observable behavior or contract the implementation introduces outside the agreed scope (feature design + verification design), not code outside test coverage. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > VERIFY step 3.
- **[MUST]** Performs the mock-boundary fidelity check after implementation: re-enumerates the iteration set from the test tree at HEAD (every double in scope and the real interface each stands for), re-derives each real interface at HEAD, and cites its `file:line`. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > VERIFY step 4.
- **[MUST]** States, per check, the **detection outcome** — `detected` / `clean` / `not-run` — in the VERIFY report, together with the iteration set as named doubles; a check that did not execute is reported `not-run`, never `clean`. The orchestrator appends these outcomes to the decision ledger; see [`autoflow-guide.md`](autoflow-guide.md) > VERIFY > *Detection record*.
- **[MUST]** On an inherited path — the tree-identity predicate matched, so the step did not execute the suite — reports the outcome word `inherited`, never `passed`, and cites the register entry as its Evidence anchor instead of stating a suite summary line it did not produce; a re-typed summary line on an inherited path is a contract violation. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > VERIFY > *Green-tree register*.
- **[MUST]** Runs the target repository's lint chain over the staged files before committing, confirms zero errors attributable to them, and reports one outcome word per discovered chain as the commit's lint-outcome evidence anchor. Rule body: [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.
- Operates independently from the Developer AI — tests are written from acceptance criteria, not from the developer's intended implementation.
- Spawn model: resolved from the spawn policy, never restated here — `bash scripts/spawn-policy/spawn-policy.sh model red` (and `refine-test-reconfirm` at REFINE). Complex test scenarios may fall back to the higher tier, with the rationale recorded in the Test AI report. Source: `.claude/autoflow/spawn-policy.json`.
- **[MUST]** Runs verification (jest/build) in the **foreground**; never uses `run_in_background` — a spawned teammate has no future turn to receive a background-completion notification. See [`teammate-common-rules.md`](teammate-common-rules.md) > Bash Execution Mode.
- **[MUST]** Reports to the orchestrator through the spawn's **return value**. This role is spawned as an **anonymous direct subagent** (`subagent_type: autoflow-tester`), so no mailbox exists and the return value is the report — the body goes to `.autoflow/*` and the return carries an anchor plus a one-line summary. See [`teammate-common-rules.md`](teammate-common-rules.md) > Result delivery path by spawn mode. The named-team-spawn path this obligation once named is retired (ADR-0017, pilot discharged by ADR-0021); the role's spawn mode is fixed by [`CLAUDE.md`](../CLAUDE.md) > Spawn mode by role lifetime.

---

## Submodule AI (per sub-repo, Developer AI)
- Understands and implements the assigned sub-repo's code.
- Writes the minimum code that passes the tests written by the Test AI (does not implement behavior outside tests).
- Has read access to other sub-repos; modifications stay within the assigned sub-repo.
- Works directly in the target repo and pushes to origin (the target repo's own branch). PR creation is performed by the orchestrator.
- *Secondary (multi-repo):* when the target is a sub-repo, the push goes to the AI's fork branch (in the fork-and-PR model).
- **[MUST]** On an inherited path — the tree-identity predicate matched, so the step did not execute the suite — reports the outcome word `inherited`, never `passed`, and cites the register entry as its Evidence anchor instead of stating a suite summary line it did not produce; a re-typed summary line on an inherited path is a contract violation. Rule body: [`autoflow-guide.md`](autoflow-guide.md) > VERIFY > *Green-tree register*.
- **[MUST]** Runs the target repository's lint chain over the staged files before committing, confirms zero errors attributable to them, and reports one outcome word per discovered chain as the commit's lint-outcome evidence anchor. Rule body: [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.
- **[MUST]** At REFINE, writes `.autoflow/issue-{N}-refine-report.md` with its three sections — `## Applied`, `## Rejected / deferred`, `## Out-of-scope observations — guard / boundary logic touched` — each present, `none` when empty. A /simplify suggestion rejected as behavior-changing that touches validation, a guard, path / root resolution, an input or output boundary, or error handling goes into the third section with its `path:line` and the behavior it would change; REFINE is right to refuse it and wrong to bury it (issue #135; `docs/autoflow-guide.md` > REFINE > REFINE report).
- Common rules: see [`docs/submodule-common-rules.md`](submodule-common-rules.md).
- Spawn model: resolved from the spawn policy, never restated here — `bash scripts/spawn-policy/spawn-policy.sh model green` and `… model refine-impl`. REFINE is spawned fresh at REFINE entry, since each phase's spawn resolves its own model. Source: `.claude/autoflow/spawn-policy.json`.
- **[MUST]** Runs verification (jest/build) in the **foreground**; never uses `run_in_background` — a spawned teammate has no future turn to receive a background-completion notification. See [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Testing Standards > Bash execution mode.
- **[MUST]** Reports to the orchestrator through the spawn's **return value**. This role is spawned as an **anonymous direct subagent** (`subagent_type: autoflow-implementer`), so no mailbox exists and the return value is the report — the body goes to `.autoflow/*` and the return carries an anchor plus a one-line summary. See [`teammate-common-rules.md`](teammate-common-rules.md) > Result delivery path by spawn mode. The named-team-spawn path this obligation once named is retired (ADR-0017, pilot discharged by ADR-0021); the role's spawn mode is fixed by [`CLAUDE.md`](../CLAUDE.md) > Spawn mode by role lifetime.

The Submodule AI operates as the Developer AI directly in the target repo. *Secondary (multi-repo):* when the host contains submodules (see [`CLAUDE.md`](../CLAUDE.md#deployment-topology) > Deployment Topology), the target repo is the AI's assigned sub-repo, the fork/upstream procedure above applies, and PR creation remains the orchestrator's. The role contract is otherwise unchanged.

---

## Facilitator (deliberation sub-context)

The Facilitator runs a multi-teammate deliberation in an **isolated sub-context** so the orchestrator never receives the round-by-round cross-talk. The orchestrator invokes it for phases that run a Developer-AI ↔ Test-AI deliberation: **ARCHITECT** (feature design + verification design) and the **VERIFY** cause-branch. Rationale and the structural rule: [`CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation; [`docs/design-rationale.md`](design-rationale.md) > Decision 8.

### Realization — the `Workflow` tool (single supported mechanism)

The facilitator is realized as a **project workflow** the orchestrator runs with the `Workflow` tool, **not** as a nested Agent Team. This is the only realization that the Claude Code runtime both supports and documents as isolating:

- A spawned teammate **cannot** create its own team or teammates, and a team's lead is **fixed for the team's lifetime** (no lead transfer). So "a spawned facilitator that leads a nested Developer-AI ↔ Test-AI team" is not executable — ruled out. (Agent Teams > Limitations: <https://code.claude.com/docs/en/agent-teams>.)
- A peer-teammate facilitator inside the orchestrator's own team is rejected on the ground recorded at [`docs/design-rationale.md`](design-rationale.md) > Decision 8, which cites the measurement in `tests/manual/issue-52-manual-scenarios.md` > M1. This bullet does not restate that ground.
- The `Workflow` tool **is** documented as isolating: "intermediate results stay in script variables instead of landing in Claude's context," and the orchestrator receives one final result. (Workflows: <https://code.claude.com/docs/en/workflows>.)

**Invocation / version / config**:
- Prerequisites — both must hold (Workflows: <https://code.claude.com/docs/en/workflows>): (i) Claude Code **v2.1.154+**; (ii) Dynamic workflows **enabled** — they can be off by default (Pro requires turning on the Dynamic workflows row in `/config`) and are disabled by any of `disableWorkflows: true` in `~/.claude/settings.json` (or managed settings), or `CLAUDE_CODE_DISABLE_WORKFLOWS=1`.
- If the prerequisites do not hold, the orchestrator escalates with the **specific** cause — version gap vs. local `/config`/`settings.json` disable vs. env var vs. managed-policy disable — rather than a generic "unavailable", and proposes the matching enable step. It does **not** fall back to running the deliberation in its own turn stream.
- The orchestrator invokes `Workflow({ name: "architect-deliberation", args: { issue: "N" } })` at ARCHITECT and `Workflow({ name: "verify-cause-branch", args: { issue: "N", failLog: "<path>" } })` at VERIFY. Reference scripts: [`.claude/workflows/architect-deliberation.js`](../.claude/workflows/architect-deliberation.js), [`.claude/workflows/verify-cause-branch.js`](../.claude/workflows/verify-cause-branch.js).
- **ARCHITECT `args` contract** (issue #127): `issue` is required; `resume` is optional. `Workflow({ name: "architect-deliberation", args: { issue: "N", resume: "true" } })` re-enters an `ESCALATE`d deliberation from its persisted register instead of cold-restarting it — Draft is skipped, no design document is re-authored, and exactly one further exchange (two turns) runs. `resume` admits `true` and `"true"`; absent, `false` and `"false"` take the cold path; **any other value throws at the boundary** (a silently ignored malformed value would degrade into the cold restart the argument exists to remove). The prose-args salvage below additionally sets `resume` from a standalone `resume` word token.
- Skill-channel invocation (issue #14): each script's `meta.description` now states the required `args` contract (the only surface the harness exposes to a skill-channel caller — no `SKILL.md` exists for these workflows), and both scripts tolerate a prose-string `args` by salvaging `issue` inside the `JSON.parse` catch path via a three-tier rule (first hit wins): tier 1 a `#N` token, tier 2 an `issue N`-anchored number, tier 3 a bare digit run **only when exactly one is present** (two-or-more bare runs is ambiguous → fail loud rather than silently adopting the first). `failLog` deliberately has **no** prose fallback — a prose invocation of `verify-cause-branch` still fails loudly on the `failLog` guard. The object-form examples above remain the canonical orchestrator path and are unchanged.
- The workflow's internal design/verification sub-agents carry no model literal: each call site spreads its opts from the `workflow_sites` row the script loads at run time (`.claude/autoflow/spawn-policy.json`), so the ARCHITECT design-discussion sites and the VERIFY self-check sites are governed by the config alone. See [`CLAUDE.md`](../CLAUDE.md) > Spawn Model.

### Responsibilities

- **Owns the deliberation in-script**: the Developer-AI and Test-AI sub-agents run inside the workflow; their round-by-round exchange stays in workflow script variables and never enters the orchestrator's context.
- **[MUST]** The in-script Developer-AI / Test-AI sub-agents run all Bash **foreground**-only (`run_in_background` is orchestrator-only) — same rule as a directly-spawned teammate, since an in-script sub-agent likewise has no future turn to receive a background-completion notification. See [`teammate-common-rules.md`](teammate-common-rules.md) > Bash Execution Mode.
- **Drives convergence** under the Discussion Protocol ([`docs/teammate-common-rules.md`](teammate-common-rules.md) > Discussion Protocol) — UNDERSTAND → VERIFY → EVALUATE → RESPOND, devil's advocate on the first exchange, no groundless agreement. **ADR conformance** is a required first-exchange devil's-advocate axis: before accepting, the exchange verifies the resolution conforms to any governing ADR; a divergence is raised as a counter and the reviewing side withholds `accept`, so the deliberation continues. Non-scored — this is the ARCHITECT deliberation surface, not a gate.
- **Writes artifacts** to `.autoflow/issue-{N}-*.md` (feature design, verification design). It does not inline artifact bodies in its return.
- **Appends to the decision ledger** (`.autoflow/issue-{N}-ledger.md`): each settled decision with grounds + authority (append-only).
- **[MUST]** Every ledger append allocates its entry identifier per [`CLAUDE.md`](../CLAUDE.md) > Decision Ledger > *Entry identifier* — one `ledger-entry-id.sh next` call in the facilitator's own namespace immediately before that entry's append, then `check` after the appends. That section is the single documentary home of the writer→namespace mapping; this line cites it and does not restate which letter the facilitator holds.
- **Returns one structured result** to the orchestrator (see Return Contract). It does not forward the discussion.

### Return Contract

The workflow's only output to the orchestrator is one structured result, **specific to the phase** (the two phases drive different next-state machines, so their schemas differ):

**ARCHITECT** (`architect-deliberation`):

```json
{
  "phase": "architect",
  "verdict": "CONVERGED | AC_CHANGE | ESCALATE",
  "artifacts": [".autoflow/issue-N-feature-design.md", ".autoflow/issue-N-verification-design.md"],
  "ledger": ".autoflow/issue-N-ledger.md",
  "turns": 4,
  "summary": "one-line outcome",
  "escalation": "what blocks convergence (only when verdict = ESCALATE)",
  "resumed": false,
  "register": ".autoflow/issue-N-architect-register.json",
  "registerWritten": true,
  "acReason": "the acceptance-criterion pause's cause (only when verdict = AC_CHANGE)",
  "acChange": [{ "ac": "AC1", "kind": "dropped", "locator": "row name", "proposed": "the row's disposition wording" }]
}
```

- Orchestrator routing: `CONVERGED` → GATE:PLAN; `AC_CHANGE` → surface to the user and do **not** spawn GATE:PLAN; `ESCALATE` → surface to the user.
- **Acceptance-criterion authority** (issue #138): between `Converge` and `Ledger`, and **only on a converged run**, a `Reconcile` phase compares the issue's `## Acceptance criteria` table against the converged verification design's `Issue AC` column through one closed-schema comparison channel. The channel **transcribes** (cells and `[ac-decision]` ledger ids) and never judges whether a change was justified; the script derives each finding's `kind` (`dropped` / `unreasoned` / `substituted`, first match wins, at most one per AC — a reduced verification disposition **with** a stated reason is not a finding: it is the deliberation's to make, carried to the PR body for the external reviewer to judge, per issue #153) and its `authorized` flag (exact-after-trim match against the transcribed id list, never a prefix) in its own code. Verdict precedence is `ESCALATE` before `AC_CHANGE` before `CONVERGED`: an infrastructure or non-convergence cause outranks a design outcome, and Reconcile does not run at all on a non-converged run. **Fail-closed, deliberately asymmetric with the terminal Ledger/Register calls**: those run *after* the verdict and are absorbed to null, whereas Reconcile runs *before* it and stands in front of a human authority boundary — so a null return, a malformed payload or an absent/unparseable AC table resolves to `AC_CHANGE` with its own sentinel (`ac reconciliation unavailable` / `ac list absent` / `unauthorized acceptance-criterion change`) rather than degrading to `CONVERGED`. `escalation` stays `null` on `AC_CHANGE` (the run is not escalating for a deliberation cause) and the sentinel is carried on `acReason` instead, on **both** the return and the persisted register payload; `acChange` is `[]` on every other verdict and carries the unauthorized findings on this one. An `AC_CHANGE` run always mints **at least one open** register entry — one per unauthorized finding, or one named `ac-authority:reconciliation-unavailable` / `ac-authority:ac-list-absent` on the two fail-closed paths — so the operator's resume is not refused by the `no open entry` guard, and the ledger records **exactly one** outcome entry under the distinct authority `ARCHITECT ac-change` with **no** settled decision. The register load schema admits `AC_CHANGE`, while the `already converged` guard stays keyed to `CONVERGED` alone, which is what keeps an `AC_CHANGE` register resumable. Operator procedure: [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT > *Acceptance-criterion change*.
- **Resume fields** (issue #127): `resumed` states whether this run entered through the resume path, so the orchestrator can tell a resume entry from a fresh deliberation in its own bookkeeping — a resume consumes no ARCHITECT re-entry budget (see [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT). `register` is the path of the durable register artifact. `registerWritten` reports whether the terminal Register phase's write sub-agent returned; a failed write — a rejection and a synchronous throw alike — is absorbed to a null acknowledgement, reported as `registerWritten: false`, and **never** alters the already-decided `verdict`. The consequence lands on the next resume, which re-enters from the last successfully persisted state: the register an earlier run left behind when one exists — unchanged, since the failed write never touched it — and, when none exists, the resume load guard's `resume register absent` escalation (zero turns run) rather than a silent cold restart. The terminal ledger append is absorbed the same way, and carries no reported field at all: a failed ledger append is absorbed and reported nowhere in the return, so the run's record survives only in the register artifact the Register phase then writes. `turns` is **absolute**, continuing across a resume rather than restarting per invocation.
- **Register artifact** (issue #127): `.autoflow/issue-{N}-architect-register.json`, written by the terminal Register phase of every run that ever held a faithful register — on all three verdicts (`CONVERGED`, `AC_CHANGE`, `ESCALATE`), since the write is guarded by whether a faithful register was ever held and not by the verdict. Writing on `CONVERGED` is load-bearing: the `already converged` resume guard reads this file's own `verdict`, so skipping it would let a later resume reopen a design the ledger already records under `ARCHITECT mutual ACCEPT`. Two run shapes are write-ineligible, because neither ever read or built the register it would overwrite: a resume that failed a load guard, and a cold run that early-escalates on a null draft. Besides `entries` (every status, not only the open ones) the artifact carries `lastTurn`, `verdict`, `escalation` and `lastResponses` — the last two are read by the operator, not by any control-flow path.
- **Convergence rule** (turn model, issue #152): the Test AI and the Developer AI alternate **single-participant turns** (Test AI first; a resume continues the persisted parity). Each turn returns `{ modified, accept, counters, accept_grounds, dispositions }`, where `modified` states whether this turn edited a design document and `accept` states whether this participant accepts the current design. The deliberation converges **only** when the previous turn and the current turn both report `modified: false, accept: true` — the other participant accepted the design without modifying it, and so did this one. A turn that modified a document **never** converges, whatever its `accept` says (the modified design still owes the other side a review, which the next turn naturally provides); every other state simply continues. No combination is restricted (`modified: true, accept: true` is a valid "I changed it and I am satisfied" state that cannot terminate), no verdict history, snapshot hash, revision pin, acceptance-invalidation rule or separate convergence-verification step exists, and `counters` no longer block convergence — they are the deliberation's **record**, feeding the issue register and the ESCALATE grounds. The first turn of any run (cold and resume alike) has no predecessor to pair with and structurally cannot converge; the mandatory first-exchange devil's-advocate review survives as prompt guidance on each side's first turn of a cold run, not as a structural guard. The converging turn's and its predecessor's `accept_grounds` feed the ledger entry's grounds.
- **Turn execution order**: strictly alternating, **Test AI on odd turns, Developer AI on even turns**. The verification design challenges the feature design, so the test-first order makes each exchange a complete challenge-and-response; each turn receives its predecessor's live report (`modified`/`accept` plus counters) in its prompt. Concurrency is retained only for the Draft phase, where the two drafts are independent by design.
- **Counter shape and the issue register**: a counter is a record `{ agenda, locator, argument }` — the concern's name, where to look, and the case itself. All three cross the turn boundary as an **issue register** entry `{ name, conclusion, evidence, status, raisedBy }`, held in a script variable for the whole run and rendered into every later turn's prompt. An entry is keyed by its normalized short name, updated **in place** on a re-raise, and rendered as exactly four labelled lines (`name` / `conclusion` / `evidence` / `status`) followed by a `---` terminator — a structural per-entry bound, with **no character cap and no truncation marker**. Every entry carries every round regardless of status, so a disposed issue stays visible and the no-re-litigation rule has something to point at. Because `conclusion` (the former `argument`) now crosses the boundary, a Developer-AI counter's reasoning reaches the Test AI inside the record; the design document is no longer used as that durable channel.
- **Disposition**: the script cannot judge agreement, so each side additionally returns `dispositions: [{ name, conclusion, evidence, status }]` with `status` in `{agreed, rejected}` — required, empty array permitted. A disposition acts only on an **existing** entry (an unresolvable name is ignored, never minted) and only with an in-enum status; names resolve through the same normalization as register keys. **Only the entry's raiser may close it** — a disposition from the other side overwrites `conclusion`/`evidence` as a proposed resolution but leaves `status: open`.
- **Citation mode is partitioned by target mutability**: the two design documents are edited in place during the deliberation, so counters and adoptions cite them by **section heading or item ID**; `path:line` is reserved for repository source files, which are immutable for the run. Uniform line-number citation was the generator of purely notational counters that blocked convergence.
- **Ledger rule**: settled decisions under authority `ARCHITECT mutual ACCEPT` are appended **only** on `CONVERGED`, together with one entry per **rejected** register issue under the distinct authority `ARCHITECT rejected` — the cross-session half of the no-re-litigation rule, which the Draft prompts read back at the start of the next deliberation. An `AC_CHANGE` run likewise appends **exactly one** outcome entry, under the distinct authority `ARCHITECT ac-change`, and records **no** settled decision; an `ESCALATE` run appends a single outcome entry under the distinct authority `ARCHITECT non-convergence` and records **no** settled decision — so the append-only ledger is never polluted with un-agreed content that the "no re-litigation without a new verified fact" rule would then lock in. Terminal ledger grounds are the rendered **open** register entries — every unresolved concern of the run with its conclusion, not only the last turn's counters — falling back to the escalation reason alone when no entry is open, so the grounds are never empty.
- **Record discipline**: the design documents carry only the current design and its conclusions — no round history, no measurement logs, command output or code text transcribed into them; evidence is one line of what was checked and how, re-verified next round with tooling. Issues are named with short readable names, never serial numbers, and no totals or counts are written into the documents.
- **Missing draft / turn**: a draft sub-agent that returns null (skipped/errored), or two consecutive Converge turns (one per side) that return null, is recorded truthfully as MISSING and the workflow ESCALATEs early with a **distinct** `escalation` reason (`draft agent missing` / `sub-agent missing for N consecutive turn(s)`) rather than exhausting the turn ceiling under the generic no-convergence text. A single missing turn does not abort the run, and the two turns around it never pair for convergence — the predecessor a turn is compared against is the immediately preceding turn, missing or not. **Artifact existence is not among these**: the hosted Workflow runtime injects no filesystem access and rejects `import(` at parse time, so the script cannot observe whether a draft was written. That check belongs to the orchestrator, which has a shell — see [`autoflow-guide.md`](autoflow-guide.md) > ARCHITECT. Mirrors VERIFY's missing-self-check rule — an infrastructure/model failure is never laundered into a design-disagreement reason.
- **Resume guards and the resume turn bound** (issue #127; turn model per issue #152): a resume run loads the register before Converge, and each admission failure resolves to its own bare `escalation` sentinel — `resume register load agent missing`, `resume register absent`, `resume design artifact missing`, `resume register has no open entry`, `resume register already converged`. Artifact existence **is** checked on this path, because resume skips Draft and the load sub-agent is already reading the filesystem the script cannot reach. Turn numbering continues from the register's `lastTurn`, never from an argument, and the run admits exactly one further **exchange** (two turns, side parity continuing). The resumed run's first turn has no predecessor to pair with, so a resume converges only on its own two unmodified-accept turns — the escalated run's last turn is deliberately not restored as a pairing predecessor, at the cost of at most one extra turn; open register entries are the resume's **agenda**, not a convergence condition. A converged resume returns `CONVERGED` only when the Reconcile check that follows finds no unauthorized acceptance-criterion change, and `AC_CHANGE` when it does. A null final turn on that bound is a MISSING judgment immediately (`sub-agent missing for 1 consecutive turn(s)`) rather than falling through to the generic turn-exhaustion text: with no further turn to retry it, the operator's decided extension must not be spent saying the wrong thing. The resume's agenda is the **open** entries; `agreed` and `rejected` entries are carried under a declared settled-block heading as a record, not as work — after an `ESCALATE` the ledger holds no record of what the prior run rejected, so deleting them would reopen re-litigation through the back door.

**VERIFY** (`verify-cause-branch`):

```json
{
  "phase": "verify",
  "test_self_check": "fix_test | no_problem | missing",
  "impl_self_check": "fix_impl | no_problem | missing",
  "next_action": "RED | GREEN | SEQUENTIAL_FIX | EVALUATION_AI",
  "ledger": ".autoflow/issue-N-ledger.md",
  "summary": "one-line outcome"
}
```

- `next_action` is derived from the two self-checks (the existing VERIFY branch table): `fix_test` + `no_problem` → `RED`; `no_problem` + `fix_impl` → `GREEN`; `fix_test` + `fix_impl` → `SEQUENTIAL_FIX` (fix test → Red → fix impl → Green); `no_problem` + `no_problem` → `EVALUATION_AI` (deadlock arbitration). The orchestrator routes strictly on `next_action`.
- **Missing self-check**: a sub-agent that did not return a verdict (skipped/errored) is recorded **truthfully** as `"missing"` — never substituted with `no_problem`. Any `missing` routes to `EVALUATION_AI` (a judgment that never happened cannot decide a fix path), and the ledger grounds record `missing` as fact, so a later step never treats a non-existent self-check as authoritative.

### Termination (explicit caps — Decision 7)

- **ARCHITECT**: a *turn* = one participant's review (Test AI and Developer AI alternate); one exchange = two turns. The cold and scope-bounded turn ceilings are **config values** — `.claude/autoflow/spawn-policy.json` > `deliberation_caps["architect-deliberation"]` (`max_turns` / `bounded_max_turns`, integers ≥ 2) — never code literals; the script fails closed with the sentinel `spawn policy deliberation caps incomplete` when its row is missing or malformed. Reaching the ceiling without two consecutive unmodified accepts returns `verdict: "ESCALATE"` with the reason `No convergence within N turns (reached turn M)`. No closing half-round exists (retired with issue #152): a ceiling-turn revision simply fails the no-modification condition, and its review — like every review — belongs to the next turn, which an operator resume can grant. A converged run still passes through the Reconcile check, returning `CONVERGED` or `AC_CHANGE` as above.
- **VERIFY**: a single self-check round (each side answers once → deterministic `next_action`); there is no internal loop. Repeated VERIFY entries are bounded by the existing GREEN↔VERIFY round-trip cap (max 3) in [`CLAUDE.md`](../CLAUDE.md) > Flow Control.
- **[MUST]** No round-by-round messages, no duplicate dual reports, no artifact bodies in the return — paths + verdict/next-action + one line only (mirrors [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format).

### Orchestrator-side verification (leverage preserved)

After the result returns, the orchestrator **verifies** it before accepting — this is preserved, only the deliberation prose is isolated:

- It does **not** read the design docs cover-to-cover to *judge* them — that full read-and-score is GATE:PLAN's fresh Evaluation AI. The orchestrator instead **spot-checks targeted excerpts**: it pulls the specific `path:line` a returned decision rests on and re-derives the cited fact (`git show`, command re-run, `git show HEAD:<file>`). This is the same targeted anchor-check carved out by [`CLAUDE.md`](../CLAUDE.md#cost-control) > Orchestrator context discipline, not a full-body absorption.

### Verification scenarios (manual)

**Automated (mock-runtime regression)** — `test/workflows/run.mjs` locks the pure control-flow logic (the turn-based convergence rule — two consecutive unmodified accepts, modified turns never converging — counter threading into the register, ledger-authority branching, ARCHITECT missing-draft/consecutive-null early ESCALATE, VERIFY next_action incl. `missing`, and the arg guards) by running each script against a mock runtime that injects only the real globals (`args`, `phase`, `parallel`, `agent`, `console`) — a stray undefined global throws, catching the ABI-regression class. Run `node test/workflows/run.mjs`; the GitHub Actions `workflow-regression` job (`.github/workflows/workflow-regression.yml`) runs it on every PR/push touching `.claude/workflows/**` or `test/workflows/**`, on `ubuntu-latest` where a node runtime is guaranteed — the Jenkins agent is provisioned for compose/shell validation only and carries no node, so the regression lives where the runtime exists (same rationale as `.github/workflows/image-scan.yml`). Enforcement is **advisory**: this repo's plan provides no GitHub branch-protection/required-status-checks (the API returns 403), so a red run does not auto-block merge — it surfaces a pass/fail signal that the external reviewer verifies green before merge (the "CI green" precondition in [`external-review-sequencing.md`](external-review-sequencing.md)), the same path as every other CI check.

**Manual (live runtime)** — these need an actual session and confirm isolation/routing end-to-end; run once on a prerequisite-satisfying session (see Invocation / version / config) and record in the cycle notes:

- **Smoke**: invoke each workflow with `Workflow({ name: ... })` and confirm it reaches the first `agent()` without a runtime error.
- **Isolation**: run `architect-deliberation`; confirm the orchestrator transcript contains the single result object and **no** round-by-round Developer/Test messages.
- **VERIFY routing**: exercise all four self-check combinations; confirm each maps to `RED` / `GREEN` / `SEQUENTIAL_FIX` / `EVALUATION_AI`.
- **Modification blocks convergence**: have a sub-agent return `modified: true, accept: true` after an unmodified accept; confirm the run does **not** converge on that pair and its counters are carried into the next turn.
- **Ceiling & ledger**: force non-convergence through the configured turn ceiling; confirm the workflow returns `ESCALATE`, appends **no** `ARCHITECT mutual ACCEPT` entry, and records only the `ARCHITECT non-convergence` outcome.

---

## Evaluation System

### Scoring (10-point scale)

| Score | Meaning | Action |
|------|------|------|
| 9-10 | Excellent | Proceed |
| 7-8  | Good      | Proceed |
| 5-6  | Insufficient | Rework recommended |
| 3-4  | Poor      | Rework required |
| 1-2  | Failing   | Redesign or human decision |

### PASS Criteria

- **[MUST]** Average ≥ 7.5
- **[MUST]** Each item ≥ 7
- **[MUST]** Security ≤ 3 → automatic rework

### Evaluation Types

| Type | Items | Retry |
|------|-------|-------|
| Structure evaluation | Type 1: Behavior gap, Code-change necessity (2) — Type 2: Content gap, Consistency impact, Propagation scope (3) | none (PASS/FAIL single verdict; reuse-neutral; gap-low → close/reply, non-code lever → report to user; no retry. Canonical: [`phases/analysis.md`](phases/analysis.md)) |
| Hypothesis evaluation | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× |
| Plan evaluation | Feasibility, Dependencies, Scope, Security, Test plan (5) — Feasibility/Scope carry structural-fit & over-engineering across the plan and its verification design (not scored at DIAGNOSE) | max 3× |
| Security audit | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) | max 3× |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

### Evaluation Output Format

```json
{
  "type": "hypothesis_evaluation | plan_evaluation | security_audit | quality_evaluation | doc_evaluation",
  "target": "scope name",
  "issue": "#N",
  "fail_hypothesis": {
    "case": "strongest rubric-framed reason this deliverable should FAIL",
    "disposition": "refuted | survived | none_found",
    "reflected_in": ["rubric item name"]
  },
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": ["items 5-6"]
}
```
