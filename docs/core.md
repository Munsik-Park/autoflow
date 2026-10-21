# AutoFlow Core

<!-- The source of the /autoflow:cycle, /autoflow:cycle-u1 … /autoflow:cycle-u7 and /autoflow:criterion-review command bodies: scripts/skills/gen-skill-bodies.sh generates skills/*/SKILL.md from this file (ADR-0027 D2, ADR-0032), a unit's body by the classification scripts/skills/core-units.tsv. Edit this file — and the classification, for a part added or one whose units change — then regenerate. -->

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the auto-resolution attempt caps are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and by the gates. When the AI is not confident, or the choice is not its own to make, it asks the advisor, whose answer is recorded and applied; the operator is asked only when a call is blocked at the harness level ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Advisor).
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a cycle leaves in the target's tree — are [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools.

## Development Lifecycle — AutoFlow

**PREFLIGHT cannot be skipped.** If its completion conditions (prior-cycle resolved, clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the block first and report.

**An attempt's criteria are settled before DIAGNOSE.** Each attempt's cycle begins with its own criterion review stage, against the target's code and policy; its `[criterion-ready]` ledger entry records the settled decisions, and PREFLIGHT reads only that entry for the current issue body ([`<autoflow-root>/docs/criterion-review.md`](criterion-review.md)).

### Flow Control

Each unit's rows are its unit document's `## Transitions` section, read on entering the unit (the router table in *Unit Document Loading Contract* below); the rows that leave no single unit are *Any unit* below.

#### Any unit

| Transition | Condition |
|------|------|
| BUILD / gate recommendation (acceptance-criterion content change) → orchestrator / advisor | the build report raises a change to an acceptance criterion's content, or a gate recommendation records a criterion defect (`<autoflow-root>/docs/decision-ledger.md` > *A criterion can be wrong*) or its fix needs one → the orchestrator decides it, and puts it to the advisor only where the raised grounds do not settle it or it is not confident. After its `[ac-decision]` entries the cycle re-enters where the orchestrator judges the decision reaches — ARCHITECT, BUILD, or the point the question arose at — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| any phase (tool or referenced material → user) | a harness-level block: the work needs a tool, or a material an acceptance criterion or the issue body references, that neither this environment nor a procedure in the target's documents or scripts can provide — or needs, for a tool the environment has, what using it lacks (access, a purpose and permitted scope, a credential, a permission setting); the request names what is missing, never the tool's output → report situation-first, `active:false`, `phase:"awaiting-user"`. The answer is an `O` ledger entry with the authority `operator decision`; the cycle resumes where it paused, or at an ARCHITECT unit re-run when a verification-design row must change, consuming no re-entry budget (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ARCHITECT > *Tools*) |
| GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY (PASS, a recommendation attempt) → doc commit / BUILD / ARCHITECT / DIAGNOSE → that gate's re-score, or → advisor / user | the PASS report's recommendation triage opens an attempt → the transition out of the gate waits until no attempt is open and no rebuttal awaits its re-score; a pause criterion, or a rebutted recommendation the re-score keeps while the two sides still disagree → the advisor decides; the attempt cap → user (`active:false`, `phase:"awaiting-user"`) (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS FAIL → a re-entry the orchestrator judges (no count cap; a PASS judged unreachable → not reachable: the operator confirms the close). GATE:PLAN FAIL → ARCHITECT (max 3×; a BUILD design contradiction re-run consumes this same counter, so ARCHITECT re-entries are capped at 3 per cycle regardless of which phase triggered them; a unit re-run on an advisor answer to the unit's own `## Decision requests` is not a re-entry and consumes no counter — an acceptance-criterion decision is an authority checkpoint inside the design, not a new one — and a return to ARCHITECT that an `[ac-decision]` raised after ARCHITECT calls for consumes none either, and neither does one that the operator's answer to a tool or referenced-material request, or an operator override of an advisor decision, calls for; a return to ARCHITECT to fix a gate recommendation does consume it). AUDIT test-first finding and AUDIT FAIL → a BUILD unit re-run (max 2×, one counter shared by both; how the unit iterates inside a run is its own and is recorded in its report). GATE:QUALITY FAIL → class-routed re-entry (doc commit / BUILD / ARCHITECT by `remedy_class`; max 3× — the cap counts FAILs, not the distance re-entered; a `design` route also consumes the ARCHITECT re-entry counter above). A recommendation attempt at any rubric-scored gate is not a FAIL and consumes no FAIL cap: max 7× on its own window, counted as `<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage* says; a re-score that fails is an ordinary FAIL. INTEGRATE FAIL → BUILD (`impl`). HANDOFF failure → cause classification: CI failure → class-routed re-entry by `remedy_class` (a `design` route consumes the ARCHITECT re-entry counter); environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at REVIEW) → class-routed re-entry, at the depth the route's recorded judgment names (max 7× — the cap counts attempts, not the distance re-entered, so a thin route consumes one exactly as a re-entry from DIAGNOSE does; on the 7th consecutive (per the count window in `<autoflow-root>/docs/units/review.md` > *Routing*) without the verdict falling below Medium, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total); GATE:HYPOTHESIS has no count cap — the recorded judgment that its PASS is not reachable is its escalation. HANDOFF internal retry exhausted → human. A harness-level block → human.
**Advisor at a decision point** (ADR-0025 D7): every Flow Control row that routes to the advisor — the rows above and each unit document's `## Transitions` rows — is a decision point — a fresh `autoflow-advisor` answers, its answer is recorded as an `A` ledger entry and applied, and the cycle continues without pausing. The operator stops the forward path only at a harness-level block — a permission denial, a tool, credential or material the environment does not provide, or what using a tool it has lacks (a review-infrastructure failure the reviewer re-run does not clear is one); PREFLIGHT's fail-closed readiness stop is an independent check, not a decision point. An operator override of a recorded decision is an `O` entry under `operator decision`. Procedure and independence: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Advisor.
**Phase scripts** (ADR-0025 D8): a script AutoFlow ships for a phase reads and reports; it changes nothing in git, on GitHub or in the cycle's state — every such change is the orchestrator's own.
**Push and PR creation**: the orchestrator pushes and opens the PR(s) with its own `git push` / `gh pr create` — the commands the hook gates, never a script that would carry them past it — and confirms CI is green, or records on the pull request that CI did not run, never reading that as green. What the PR body carries, the host PR's `Closes #N` included, is the orchestrator's; nothing checks it (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*). Merging is external; AutoFlow does not merge.

### Unit Document Loading Contract

**[MUST]** On entering a phase, Read the document of its unit below **before** acting in that phase. The unit document is the source of truth for that unit's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the unit document each cycle.

| Unit | Phases | Document to Read on entry | Exit |
|------|--------|------|------|
| U1 Preparation | PREFLIGHT, CRITERION-REVIEW | [`<autoflow-root>/docs/units/preparation.md`](units/preparation.md) | PREFLIGHT's readiness conditions |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | [`<autoflow-root>/docs/units/analysis.md`](units/analysis.md) | GATE:HYPOTHESIS |
| U3 Design | ARCHITECT, GATE:PLAN | [`<autoflow-root>/docs/units/design.md`](units/design.md) | GATE:PLAN |
| U4 Build and verify | BUILD, AUDIT | [`<autoflow-root>/docs/units/build.md`](units/build.md) | AUDIT |
| U5 Completion evaluation | GATE:QUALITY | [`<autoflow-root>/docs/units/completion-evaluation.md`](units/completion-evaluation.md) | GATE:QUALITY |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | [`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) | HANDOFF: every pull request open, CI green or recorded as not run |
| U7 Review | REVIEW | [`<autoflow-root>/docs/units/review.md`](units/review.md) | REVIEW: the aggregated review below Medium, CI green or recorded as not run |

What each phase does, and what else a unit reads on entry: the phase list and *Unit references* below.

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above, and the unit documents and rubrics apply them. Who enforces what: the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`) computes PASS from the recorded `scores` — for the score-gated role spawns, `git push` and `gh pr create` — and denies `git push` / `gh pr create` while the `audit` or `gate_quality` record carries `remedy_class`; it counts no FAIL. The FAIL and re-entry counts are the orchestrator's own accounting, and the REVIEW auto-resolution count is `<autoflow-root>/scripts/handoff/review-gate.sh`'s (exit `11` at 7).

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

Seven functional units carry the phases ([`ADR-0025`](records/adr/0025-outcome-gated-functional-units.md) D1, [`ADR-0033`](records/adr/0033-review-unit-and-script-reviewers.md)). A unit is the unit of prescription — its goal, artifact contract, verification and loop cap — and each has one document (*Unit Document Loading Contract* above). The phase and gate names stay: they are the identifiers the state keys, the ledger headings, the spawn-policy keys and the hook messages carry.

```
U1 Preparation         PREFLIGHT       — prior-attempt resolution (cleanup after external merge/close), Git clean check, remote sync, the entry `cycle-status.sh` prints, the attempt's creation on a `new` entry (`autoflow-records new`), target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op), the attempt's criterion readiness (`<autoflow-root>/scripts/preflight/criterion-ready.sh`), the state file's creation — the orchestrator's own work, decided from the facts `<autoflow-root>/scripts/preflight/cycle-status.sh` reports
                       CRITERION-REVIEW — inside PREFLIGHT, after the entry and before the stop conditions, on an attempt with no state file: the attempt's criterion review — the session's own stage 1, then the tracer, analyzer and reconciler spawns — whose exit is the attempt's `[criterion-ready]` entry for the current issue body (`<autoflow-root>/docs/criterion-review.md`)
U2 Analysis            DIAGNOSE        — one `autoflow-unit-analysis` spawn writes the analysis report: current structure, the gap to the request, whether a change is owed and code is the lever (the conclusion), the cause where a defect is reported, acceptance-criterion table, scope judgments, affected docs, decision points — each conclusion with its grounds, its method (how far and by what means a cause is pursued included) its own
                       GATE:HYPOTHESIS — one Evaluation AI: one form for every issue (2 items × 10 points — the conclusion's grounds and the goal's coverage)
U3 Design              ARCHITECT       — one `autoflow-unit-design` spawn writes the architecture decision layer + verification design, its method its own (file rows / suite dispositions / oracle clauses are derived at BUILD, not written here)
                       GATE:PLAN       — Evaluation AI (5 items × 10 points)
U4 Build and verify    BUILD           — one `autoflow-unit-build` spawn implements and verifies the design (test-first, run records, manual checklist, maintained docs, lint), its method its own; then AUDIT
                       AUDIT           — independent Evaluation AI: test-first judged from the build report and git, then 5 items × 10 points, the target's own security checklist at the version `<autoflow-root>/scripts/gate/security-checklist.sh` names (none declared → the rubric alone)
U5 Completion eval.    GATE:QUALITY    — Evaluation AI (10 items × 10 points); the gate is the unit
U6 Delivery            DELIVER         — the orchestrator's own `git push`, a command the hook gates (a changed sub-repo's branch too)
                       INTEGRATE       — the change shown working above its own tests: the system build, health check and functional test, or the project's integration suite
                       HANDOFF         — PR creation by the orchestrator's own commands → CI green, or recorded as not run; a script reads and reports CI, the orchestrator makes the changes
U7 Review              REVIEW          — the reviewers the operator's configuration names, each run by its own script, and the reviews the target's side leaves on the PR, aggregated into one verdict → review-triage (auto-resolve Medium+ / judge Low) → state inactive once review is clean, with the merge order reported; scripts read and report (reviewer start, triage case), the orchestrator runs the reviews and makes the changes, the aggregator posts the review comment; external review merges out of band
```

**Flow Control** — the transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **unit document**, not in this core file. This file retains what crosses a unit's boundary: the cross-unit invariants and authority rules, the router (the unit and phase list and the Flow Control table above, whose per-unit rows are each unit document's `## Transitions` section), the regression / escalation caps (above), the Execution Principles, and the state rules (below; the state file's schema and the hook gates are [`<autoflow-root>/docs/state-tracking.md`](state-tracking.md)). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification [`<autoflow-root>/scripts/skills/core-units.tsv`](../scripts/skills/core-units.tsv), and a session that runs the whole cycle receives all of it.

The rubric of every gate — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the unit's: it lives in [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > *Gate rubrics*, and the unit document routes the gate's result.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md); how the orchestrator spawns and prompts the evaluator is [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI.

### Unit references

| Unit | Also read on entry |
|------|------|
| U1 Preparation | facts: `<autoflow-root>/scripts/preflight/cycle-status.sh`; the criterion review stage: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md); git procedures: [`<autoflow-root>/docs/git-workflow.md`](git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| U2 Analysis | unit agent: `<autoflow-root>/agents/autoflow-unit-analysis.md`; contract: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Functional-unit agents |
| U3 Design | unit agent: `<autoflow-root>/agents/autoflow-unit-design.md`; contract: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Functional-unit agents |
| U4 Build and verify | unit agent: `<autoflow-root>/agents/autoflow-unit-build.md`; change surface: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules; checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `<autoflow-root>/scripts/gate/security-checklist.sh` |
| U6 Delivery | PR body: [`<autoflow-root>/docs/pr-body-guide.md`](pr-body-guide.md) |
| U7 Review | reviewers: [`<autoflow-root>/docs/reviewer-backend.md`](reviewer-backend.md); merge order: [`<autoflow-root>/docs/external-review-sequencing.md`](external-review-sequencing.md) |

## Cost Control

These rules apply to every cycle.

- **[MUST] Orchestrator context discipline**: two rows are fixed (Rule Scope, principle 1): (1) **the orchestrator never scores what a gate scores** — the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and an orchestrator read of those artifacts informs a spot-check, never a verdict; (2) **the orchestrator never receives a unit's body** — the DIAGNOSE, ARCHITECT and BUILD units return only their artifact paths and a one-line summary. What the orchestrator reads directly is its own judgment, recorded with its grounds in the report or ledger entry the phase already produces (Rule Scope, principle 2). A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why. The Reporting Format ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format) applies to every direct/ad-hoc `Agent` spawn, scripted-phase or not — the spawn writes its body to `<attempt-dir>/*` and returns only an anchor + one-line summary (e.g. the DIAGNOSE unit writes `<attempt-dir>/issue-N-analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the orchestrator's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `<attempt-dir>/*` body the user reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md`, fixes settled decisions. What an entry records, its identifier grammar, and the decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`) — are [`<autoflow-root>/docs/decision-ledger.md`](decision-ledger.md).

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled gate verdict is likewise not overturned by re-reading the issue body. Two exceptions: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries), and an operator's override of an advisor decision, whose ground is the operator's authority (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every role spawn's scope — it is host-owned, written only by the orchestrator and the advisor (what each appends: `<autoflow-root>/docs/decision-ledger.md` > Entries > *Writers*). **[MUST]** Only the advisor adds the authority `advisor decision` or an `A<n>` entry; only the main session adds `operator decision` or an `O<n>` entry; the advisor never adds an `O` / `F` / `E` entry; and a write never changes text already in the ledger — enforced by the gate hook ([`<autoflow-root>/docs/state-tracking.md`](state-tracking.md) > Hook gates).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers of one namespace that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- The gate hook runs `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` as a **non-gating advisory** over changed ledgers: `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error, and the hook warns — to the model as `additionalContext` on a call it admits — and never denies a tool call over a ledger defect. A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (a harness-level block such as a tool or referenced-material request, a cap reached, a cycle the advisor ended at DIAGNOSE or GATE:HYPOTHESIS) — and in every advisor request and advisor answer record ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Advisor), the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format), which is anchor-first. The `<attempt-dir>/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.
- **Verify role-spawn claims before dispatch**: every role-spawn report's Evidence anchor (see [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim.
- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's design, BUILD's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What is never skipped is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI, the aggregated review and its verdict, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate.
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `<attempt-dir>/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop), and every role spawn's Bash runs foreground-only; the binding rule lives in `<autoflow-root>/docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — a foreground `sleep` loop polling for a result — is not used. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. One timer is admitted beside that wait, the **cache keep-alive wake**: a running task keeps its own prompt cache warm through its own requests, while the orchestrator sends none, so a wait longer than the prompt-cache TTL expires the orchestrator's cached context and its first turn after the notification re-writes all of it. While a tracked task runs, the orchestrator therefore may arm one backgrounded `sleep` shorter than that TTL (`run_in_background`; 50 minutes at the 1-hour TTL) and end its turn. The turn the timer wakes is not a poll: it reads no transcript or output file of the task — only a cheap anchor-check (a log's modification time, `git log -1`) — re-arms the timer and ends the turn, and the timer is stopped once the task's notification arrives. What the wake observes about the task's progress, and any decision drawn from it, is the orchestrator's judgment, recorded with its grounds in the report or ledger entry the phase already produces. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your report", naming no carrier: the harness picks the carrier by permission mode, and in auto mode a spawn's final plain text is not delivered. There is one delivery path, and it is the return value; what carries a spawn's report is `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document ([`<autoflow-root>/docs/units/analysis.md`](units/analysis.md) > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per [`<autoflow-root>/docs/issue-proposal.md`](issue-proposal.md) and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
- **[MUST] Check cross-issue consistency before an added proposal**: before raising an additional follow-up, confirm whether it duplicates or conflicts with the other issues that already exist (open and closed, plus the cycle's tracking hub), and carry that confirmation into the proposal's grounds.

## Spawn Model — Phase-by-Phase

AutoFlow role spawns and every other subagent spawn choose the model by phase work type rather than inheriting the host session model.

The per-phase assignment itself — every phase's `model`, its `effort`, and the work type that
justifies it — lives in exactly ONE machine-readable place and is **not** restated here:

**`.claude/autoflow/spawn-policy.json`**, read through `<autoflow-root>/scripts/spawn-policy/spawn-policy.sh`:

```
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model  <phase-key>   # the model to declare on the spawn
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh effort <phase-key>   # the effort, or the config's own inherit sentinel
bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh check                # validate the config
```

**[MUST]** Every `Agent` spawn declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Enforced by the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`, PreToolUse `Agent`): a spawn without `model` is denied, independent of Auto-Flow state — research and evaluation spawns included. The orchestrator's own model follows the user's session settings (outside this policy).

**[MUST]** The value a spawn declares is **resolved by running the readout**, never recalled from a table or from memory of a prior cycle: `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>`. Editing one config row is therefore the whole of a policy change — no other file is touched. The hook additionally emits a non-gating advisory when a declared `model` falls outside the set the config admits for that `subagent_type`; it warns and never denies.

**[MUST] Spawn role declaration**: every `Agent` spawn made while an AutoFlow cycle is active (`active:true` state file present) declares its **role structurally** — every spawn uses a dedicated `subagent_type` (`autoflow-analyzer` / `autoflow-evaluator` / `autoflow-advisor`, the criterion-review agents `autoflow-criterion-tracer` / `autoflow-criterion-analyzer` / `autoflow-criterion-reconciler`, and the functional-unit agents `autoflow-unit-analysis` / `autoflow-unit-design` / `autoflow-unit-build`, defined in `<autoflow-root>/agents/`); the built-in research types (`Explore` / `Plan` / `claude-code-guide`) count as declared. `subagent_type` is the sole declaration channel. The hook owns the role→gate mapping (analysis — the criterion-review agents and `autoflow-unit-analysis` included — / evaluation / advisor / research pass; planning — `autoflow-unit-design`, the ARCHITECT unit → GATE:HYPOTHESIS; implementation — `autoflow-unit-build`, the BUILD unit → GATE:PLAN) and **denies an undeclared spawn while a cycle is active**. The spawn prompt is never used to infer the spawn's class. A spawn declares **who it is**; it never declares which gate applies to it. See `<autoflow-root>/docs/gate-matching-standard.md` > P3. Every role's spawn mode is fixed by the `[MUST]` below.

**[MUST] A unit agent's spawns inherit its gate class** (ADR-0025 D5): a spawn whose caller — the hook input's `agent_type` — is a functional-unit agent needs no role declaration and is judged by that unit's gate class; a declared role that has a gate of its own keeps it as well, so an existing role type is never judged more loosely because a unit spawned it. The caller is the immediate one. The explicit-`model` rule above holds for these spawns too. The unit agents and the advisor are defined in the common frame (#372); each unit is wired into the lifecycle by its own migration step (ADR-0025 D9) — U2 Analysis runs DIAGNOSE, U3 Design runs ARCHITECT, U4 Build and verify runs BUILD (`<autoflow-root>/docs/role-contracts.md` > Functional-unit agents).

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `<attempt-dir>/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope are [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `<autoflow-root>/docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

Each unit spawn's documents line is set by its unit document — [`<autoflow-root>/docs/units/analysis.md`](units/analysis.md) > Unit spawn, [`<autoflow-root>/docs/units/design.md`](units/design.md) > Unit spawn, [`<autoflow-root>/docs/units/build.md`](units/build.md) > Unit spawn — and preserves role-minimal injection; what a unit reads beyond it is its own judgment. An Evaluation AI's documents line names one document, [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) — the evaluator's standard, its conduct and the rubrics of all four gates — and no unit document.

## Communication

Communication with a role spawn is the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`; at ARCHITECT that is one `autoflow-unit-design` spawn.
- A spawn writes any body to `<attempt-dir>/*` and returns an anchor + one-line summary ([`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not an orchestrator channel — the orchestrator resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

For details, see [`<autoflow-root>/docs/repo-boundary-rules.md`](repo-boundary-rules.md).

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states is asked of the operator in conversation, with the request that the operator create the file or record the fact in it.

A project whose information names sub-repos delivers each changed sub-repo on its own pull request and keeps the host clean by its pointer: [`<autoflow-root>/docs/units/delivery.md`](units/delivery.md) > *Multi-repo delivery*.

## Team Structure

각 역할의 상세 계약은 [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md)를 참조한다.

### AI Orchestrator (host repo)
- Does not write code directly; coordinates role spawns.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly, as may the fix of a comment's divergence or disallowed content in a target's code (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*).

### Evaluation AI — contract: `<autoflow-root>/docs/evaluation-system.md`; spawn and prompt: `<autoflow-root>/docs/role-contracts.md` > Evaluation AI
### Build unit (U4) — contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; in a target scope: `<autoflow-root>/docs/role-contracts.md` > Build unit in a target scope
### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor
### Functional-unit agents (U2 / U3 / U4) — contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents

## AutoFlow State Tracking (Hook integration)

Every record of an attempt — one run of an issue, keyed by its dev branch — lives in the attempt's record directory `<attempt-dir>`, which `autoflow-records dir` prints for the checked-out dev branch: `<record-root>/<repo-key>/<stamp>-issue-<N>/`, under the record root outside every checkout's tree (default `~/.autoflow`; the operator's `~/.autoflow/config.json` > `record_root`). While the attempt runs, its state file is there; the hook computes pass/fail directly from `scores` to enforce gates.

The state file's naming, its schema and fields, the hook gates and the state at completion are [`<autoflow-root>/docs/state-tracking.md`](state-tracking.md).

**`verdict` rule** (gate_hypothesis only; it carries the bug signal the hook reads — the form itself is the same for every issue; when each value is set follows the Flow Control table):

| Issue type | `verdict` value |
|------------|-----------------|
| Bug / incident | `"pending"`, then `"evaluated"` once the form is scored |
| Non-bug (feat, chore, docs, refactor, …) | `"skipped (non-bug issue)"` |

The hook's state-file validator admits exactly these values, an empty or absent `verdict`, and `"skipped (feat issue)"` — the value a non-bug cycle recorded before `"skipped (non-bug issue)"`, admitted so such a state file stays valid and never written by a new cycle. Any other value makes the state file malformed, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until it is repaired. If `verdict` is empty or one of the two `skipped` values, the hook does not gate the ARCHITECT spawn on the `gate_hypothesis` scores; the orchestrator still judges the PASS. Bug issues must be initialised as `"pending"`.

**Score recording**: the orchestrator copies the `scores` object of the Evaluation AI's report into the state file verbatim. The evaluator's own documents fix that object's shape ([`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md) > Evaluation Output Format), so an evaluator prompt does not restate it ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Evaluation AI Prompt Rules, rule 2). Each item's score is a number in `0`–`10`, bare or as an object's `score` — shown below; the two shapes may be mixed within one gate. A prose string such as `"9 - reason"` is **not** a score: the hook's state-file validator rejects it, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until the file is repaired.

<!-- SCORE-SHAPE-EXAMPLE -->
```json
{ "decision_grounds": { "score": 9, "reason": "evidence" }, "scope": 8 }
```

This object is the value of `phases.<gate>.scores` in `<attempt-dir>/issue-{N}.json`.

**Remedy class recording** (a GATE:QUALITY FAIL, an open recommendation attempt at any gate — what opens one is `<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage* — and an open REVIEW review-triage `design` attempt, recorded at `gate_quality` — `<autoflow-root>/docs/units/review.md` > *Routing*): the orchestrator writes the routed class — the farthest of the classes the route was computed from, or `operator` — as `phases.<gate>.remedy_class` (a sibling of `evaluator` and `scores` inside the phase object, the one additive placement the validator admits; never top-level, never inside `scores`). The value is **removed** once the re-score PASSes and no attempt is left open, or is left behind by a later cycle's record of that gate. The hook reads `gate_quality`'s value for the `git commit` gate ([`<autoflow-root>/docs/state-tracking.md`](state-tracking.md) > Hook gates), and the presence of a value at `audit` or `gate_quality` for the `git push` / `gh pr create` gates — an open re-entry is not pushed past (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

## Evaluation System
→ [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md)

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: [`<autoflow-root>/docs/git-workflow.md`](git-workflow.md)

### PR Wait Rule

**[MUST]** Use the `active` flag as the single start signal, per checkout: begin a new cycle once every **other** attempt of this checkout reads `active:false`. One attempt runs at a time in a checkout — when another of its attempts reads `active:true`, finish or resolve that cycle first, then start the next; another checkout's attempts, of the same issue or any other, neither hold nor are held. The hook applies the same signal to this checkout's attempts only: it admits `git push` / `gh pr create` while every one of their state files reads `active:false`, and fails closed on two or more active. The readiness check and the requested issue's mode selection are [`<autoflow-root>/docs/units/preparation.md`](units/preparation.md) > *PR Wait Rule* and *Modes*.

### Commit Rules

```
<type>(#<issue>): <description>

Next: <next action>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

Attribution lines (such as `Co-Authored-By`) are not part of the AutoFlow commit format; whether a commit or PR carries one follows the execution environment (harness) and the operator's settings.

- No direct commits to main — always branch + PR.
- No `feat`/`fix` commit while tests fail → use `wip`.
- `git status` before every commit.
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (identifying the chains, execution trust boundary, scoping, outcome vocabulary, evidence anchor): [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md) > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation and tests, sub-repo) | Build unit (U4) of that scope | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |
| Comment divergence fix (target code) | Orchestrator (sub-repo: the build unit of that scope) | Orchestrator |
| Sub-repo pointer (gitlink) commit or reconcile merge | Orchestrator  | Orchestrator |

## Reference Documents

- **AutoFlow phase guide**: [`<autoflow-root>/docs/autoflow-guide.md`](autoflow-guide.md)
- **Role contracts**: [`<autoflow-root>/docs/role-contracts.md`](role-contracts.md)
- **Evaluation system**: [`<autoflow-root>/docs/evaluation-system.md`](evaluation-system.md)
- **Criterion review (an attempt's first stage, in U1)**: [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md)
- **Git procedures**: [`<autoflow-root>/docs/git-workflow.md`](git-workflow.md)
- **Repo boundary rules**: [`<autoflow-root>/docs/repo-boundary-rules.md`](repo-boundary-rules.md)
- **Sub-repo common rules**: [`<autoflow-root>/docs/submodule-common-rules.md`](submodule-common-rules.md)
