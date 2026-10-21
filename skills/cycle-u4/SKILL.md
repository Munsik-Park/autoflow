---
name: cycle-u4
description: >-
  Run unit U4 (Build and verify — BUILD, AUDIT) of an AutoFlow cycle alone,
  in a session of its own, with the parts of the core U4 uses. Use only when
  the operator starts a U4 session (/autoflow:cycle-u4 <N>).
argument-hint: "<issue-number>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: `<N>`) — unit U4, Build and verify (BUILD, AUDIT), of issue #N's cycle alone: confirm from `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` that the cycle stands at U4's entry (otherwise report the situation and stop), run U4 from its entry to its exit transition, and end the session with the report the invoking prompt asks for.

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that U4 uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle: PREFLIGHT cannot be skipped, An attempt's criteria are settled before DIAGNOSE; Development Lifecycle > Flow Control > Any unit: Push and PR creation; Development Lifecycle > Unit Document Loading Contract: U1 Preparation, U2 Analysis, U3 Design, U5 Completion eval, U6 Delivery, U7 Review; Development Lifecycle > Unit references: U1 Preparation, U2 Analysis, U3 Design, U5 Completion evaluation, U6 Delivery, U7 Review; Project Information: A project whose information names sub-repos; AutoFlow State Tracking: verdict rule, The hook's state-file validator admits; Git Workflow — Rules: PR Wait Rule.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/build.md`; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the auto-resolution attempt caps are rules of this kind.
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and by the gates. When the AI is not confident, or the choice is not its own to make, it asks the advisor, whose answer is recorded and applied; the operator is asked only when a call is blocked at the harness level (`<autoflow-root>/docs/role-contracts.md` > Advisor).
4. **A rule and the device that enforces it change in the same change.**

The rules that apply these principles to running and confirming tests and to securing tools — *Local verification*, a run's evidence, how a test is run, the tools the work needs, a missing run, what a cycle leaves in the target's tree — are `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Development Lifecycle — AutoFlow

### Flow Control

Each unit's rows are its unit document's `## Transitions` section, which the unit's body carries (the router table in *Unit Document Loading Contract* below); the rows that leave no single unit are *Any unit* below.

#### Any unit

| Transition | Condition |
|------|------|
| BUILD / gate recommendation (acceptance-criterion content change) → orchestrator / advisor | the build report raises a change to an acceptance criterion's content, or a gate recommendation records a criterion defect (`<autoflow-root>/docs/decision-ledger.md` > *A criterion can be wrong*) or its fix needs one → the orchestrator decides it, and puts it to the advisor only where the raised grounds do not settle it or it is not confident. After its `[ac-decision]` entries the cycle re-enters where the orchestrator judges the decision reaches — ARCHITECT, BUILD, or the point the question arose at — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| any phase (tool or referenced material → user) | a harness-level block: the work needs a tool, or a material an acceptance criterion or the issue body references, that neither this environment nor a procedure in the target's documents or scripts can provide — or needs, for a tool the environment has, what using it lacks (access, a purpose and permitted scope, a credential, a permission setting); the request names what is missing, never the tool's output → report situation-first, `active:false`, `phase:"awaiting-user"`. The answer is an `O` ledger entry with the authority `operator decision`; the cycle resumes where it paused, or at an ARCHITECT unit re-run when a verification-design row must change, consuming no re-entry budget (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*; ARCHITECT > *Tools*) |
| GATE:HYPOTHESIS / GATE:PLAN / AUDIT / GATE:QUALITY (PASS, a recommendation attempt) → doc commit / BUILD / ARCHITECT / DIAGNOSE → that gate's re-score, or → advisor / user | the PASS report's recommendation triage opens an attempt → the transition out of the gate waits until no attempt is open and no rebuttal awaits its re-score; a pause criterion, or a rebutted recommendation the re-score keeps while the two sides still disagree → the advisor decides; the attempt cap → user (`active:false`, `phase:"awaiting-user"`) (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*) |

**Regressions** (cap semantics: "max N×" = N regressions permitted; the gate escalates to a human on the **(N+1)th** FAIL — e.g. `max 2×` → escalate on the 3rd FAIL): GATE:HYPOTHESIS FAIL → a re-entry the orchestrator judges (no count cap; a PASS judged unreachable → not reachable: the operator confirms the close). GATE:PLAN FAIL → ARCHITECT (max 3×; a BUILD design contradiction re-run consumes this same counter, so ARCHITECT re-entries are capped at 3 per cycle regardless of which phase triggered them; a unit re-run on an advisor answer to the unit's own `## Decision requests` is not a re-entry and consumes no counter — an acceptance-criterion decision is an authority checkpoint inside the design, not a new one — and a return to ARCHITECT that an `[ac-decision]` raised after ARCHITECT calls for consumes none either, and neither does one that the operator's answer to a tool or referenced-material request, or an operator override of an advisor decision, calls for; a return to ARCHITECT to fix a gate recommendation does consume it). AUDIT test-first finding and AUDIT FAIL → a BUILD unit re-run (max 2×, one counter shared by both; how the unit iterates inside a run is its own and is recorded in its report). GATE:QUALITY FAIL → class-routed re-entry (doc commit / BUILD / ARCHITECT by `remedy_class`; max 3× — the cap counts FAILs, not the distance re-entered; a `design` route also consumes the ARCHITECT re-entry counter above). A recommendation attempt at any rubric-scored gate is not a FAIL and consumes no FAIL cap: max 7× on its own window, counted as `<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage* says; a re-score that fails is an ordinary FAIL. INTEGRATE FAIL → BUILD (`impl`). HANDOFF failure → cause classification: CI failure → class-routed re-entry by `remedy_class` (a `design` route consumes the ARCHITECT re-entry counter); environment / push rejection → HANDOFF internal retry (max 2×). reviewer-review auto-resolution (Medium+ found at REVIEW) → class-routed re-entry, at the depth the route's recorded judgment names (max 7× — the cap counts attempts, not the distance re-entered, so a thin route consumes one exactly as a re-entry from DIAGNOSE does; on the 7th consecutive (per the count window in `<autoflow-root>/docs/units/review.md` > *Routing*) without the verdict falling below Medium, pause for the user).
**Human escalation**: a gate's own regression cap exhausted without a pass (each gate's cap is the "max N×" on the Regressions line above, which fixes the escalation timing — this is **per-gate**, not a cross-gate running total); GATE:HYPOTHESIS has no count cap — the recorded judgment that its PASS is not reachable is its escalation. HANDOFF internal retry exhausted → human. A harness-level block → human.
**Advisor at a decision point** (ADR-0025 D7): every Flow Control row that routes to the advisor — the rows above and each unit document's `## Transitions` rows — is a decision point — a fresh `autoflow-advisor` answers, its answer is recorded as an `A` ledger entry and applied, and the cycle continues without pausing. The operator stops the forward path only at a harness-level block — a permission denial, a tool, credential or material the environment does not provide, or what using a tool it has lacks (a review-infrastructure failure the reviewer re-run does not clear is one); PREFLIGHT's fail-closed readiness stop is an independent check, not a decision point. An operator override of a recorded decision is an `O` entry under `operator decision`. Procedure and independence: `<autoflow-root>/docs/role-contracts.md` > Advisor.
**Phase scripts** (ADR-0025 D8): a script AutoFlow ships for a phase reads and reports; it changes nothing in git, on GitHub or in the cycle's state — every such change is the orchestrator's own.

### Unit Document Loading Contract

**[MUST]** On entering a phase, act on the document of its unit below, which the session's command body carries after the core (*Context Injection*), **before** acting in that phase. The unit document is the source of truth for that unit's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — the body is the unit document of the installed version.

| Unit | Phases | Unit document | Exit |
|------|--------|------|------|
| U1 Preparation | PREFLIGHT, CRITERION-REVIEW | `<autoflow-root>/docs/units/preparation.md` | PREFLIGHT's readiness conditions |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | `<autoflow-root>/docs/units/analysis.md` | GATE:HYPOTHESIS |
| U3 Design | ARCHITECT, GATE:PLAN | `<autoflow-root>/docs/units/design.md` | GATE:PLAN |
| U4 Build and verify | BUILD, AUDIT | `<autoflow-root>/docs/units/build.md` | AUDIT |
| U5 Completion evaluation | GATE:QUALITY | `<autoflow-root>/docs/units/completion-evaluation.md` | GATE:QUALITY |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | `<autoflow-root>/docs/units/delivery.md` | HANDOFF: every pull request open, CI green or recorded as not run |
| U7 Review | REVIEW | `<autoflow-root>/docs/units/review.md` | REVIEW: the aggregated review below Medium, CI green or recorded as not run |

What each phase does, and what else a unit's body carries: the phase list and *Unit references* below.

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above, and the unit documents and rubrics apply them. Who enforces what: the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`) computes PASS from the recorded `scores` — for the score-gated role spawns, `git push` and `gh pr create` — and denies `git push` / `gh pr create` while the `audit` or `gate_quality` record carries `remedy_class`; it counts no FAIL. The FAIL and re-entry counts are the orchestrator's own accounting, and the REVIEW auto-resolution count is `<autoflow-root>/scripts/handoff/review-gate.sh`'s (exit `11` at 7).

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

Seven functional units carry the phases (`ADR-0025` D1, `ADR-0033`). A unit is the unit of prescription — its goal, artifact contract, verification and loop cap — and each has one document (*Unit Document Loading Contract* above). The phase and gate names stay: they are the identifiers the state keys, the ledger headings, the spawn-policy keys and the hook messages carry.

```
U4 Build and verify    BUILD           — one `autoflow-unit-build` spawn implements and verifies the design (test-first, run records, manual checklist, maintained docs, lint), its method its own; then AUDIT
                       AUDIT           — independent Evaluation AI: test-first judged from the build report and git, then 5 items × 10 points, the target's own security checklist at the version `<autoflow-root>/scripts/gate/security-checklist.sh` names (none declared → the rubric alone)
```

**Flow Control** — the transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in its **unit document**, not in this core file. This file retains what crosses a unit's boundary: the cross-unit invariants and authority rules, the router (the unit and phase list and the Flow Control table above, whose per-unit rows are each unit document's `## Transitions` section), the regression / escalation caps (above), the Execution Principles, and the state rules (below; the state file's schema and the hook gates are `<autoflow-root>/docs/state-tracking.md`). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

The rubric of every gate — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the unit's: it lives in `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics*, and the unit document routes the gate's result.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in `<autoflow-root>/docs/evaluation-system.md`; how the orchestrator spawns and prompts the evaluator is `<autoflow-root>/docs/role-contracts.md` > Evaluation AI.

### Unit references

| Unit | Also on entry |
|------|------|
| U4 Build and verify | unit agent: `autoflow-unit-build`; contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `<autoflow-root>/scripts/gate/security-checklist.sh` |

## Cost Control

These rules apply to every cycle.

- **[MUST] Orchestrator context discipline**: two rows are fixed (Rule Scope, principle 1): (1) **the orchestrator never scores what a gate scores** — the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), and an orchestrator read of those artifacts informs a spot-check, never a verdict; (2) **the orchestrator never receives a unit's body** — the DIAGNOSE, ARCHITECT and BUILD units return only their artifact paths and a one-line summary. What the orchestrator reads directly is its own judgment, recorded with its grounds in the report or ledger entry the phase already produces (Rule Scope, principle 2). A cheap anchor-check — a `git show <SHA>`, the summary line read in a cited log, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify role-spawn claims) — needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why. The Reporting Format (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format) applies to every direct/ad-hoc `Agent` spawn, scripted-phase or not — the spawn writes its body to `<attempt-dir>/*` and returns only an anchor + one-line summary (e.g. the DIAGNOSE unit writes `<attempt-dir>/issue-N-analysis.md` and returns a summary, not the body), and a multi-step investigation is delegated to a role spawn or research subagent on the same terms; the orchestrator's judgment is over what it then reads of that body, not over what a spawn sends back. The "anchor + one-line summary" rule bounds what a spawn **returns**; it does not set how a **human decision** is framed — a user-facing pause follows *Execution Principles > Human-decision presentation* (situation-first), and the `<attempt-dir>/*` body the user reads is written in that order.
- **Concurrent spawns**: keep ≤ 5 `Agent` spawns in flight at once.

## Decision Ledger

A per-attempt append-only record, `<attempt-dir>/issue-{N}-ledger.md`, fixes settled decisions. What an entry records, its identifier grammar, and the decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`) — are `<autoflow-root>/docs/decision-ledger.md`.

- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content read at a named commit), not a re-reading or re-interpretation of material already on the record. A settled gate verdict is likewise not overturned by re-reading the issue body. Two exceptions: a verified error in the record itself (`<autoflow-root>/docs/decision-ledger.md` > Entries), and an operator's override of an advisor decision, whose ground is the operator's authority (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact — or, under the verified-error exception, the reproduced error — and references the entry it supersedes.
- The ledger is outside every role spawn's scope — it is host-owned, written only by the orchestrator and the advisor (what each appends: `<autoflow-root>/docs/decision-ledger.md` > Entries > *Writers*). **[MUST]** Only the advisor adds the authority `advisor decision` or an `A<n>` entry; only the main session adds `operator decision` or an `O<n>` entry; the advisor never adds an `O` / `F` / `E` entry; and a write never changes text already in the ledger — enforced by the gate hook (`<autoflow-root>/docs/state-tracking.md` > Hook gates).
- **[MUST]** `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` allocates every identifier, and is called immediately before that entry's own append — one call per entry, never a serial incremented locally across a batch. It derives the serial from the file on disk and from the identifiers already reserved, and reserves the one it prints, so writers of one namespace that allocate concurrently — advisors spawned together — receive distinct identifiers (`<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Allocation*).
- The gate hook runs `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh check <ledger>` as a **non-gating advisory** over changed ledgers: `check` exits 1 on a duplicated identifier or an unidentified level-2 heading, 2 on a usage error, and the hook warns — to the model as `additionalContext` on a call it admits — and never denies a tool call over a ledger defect. A defect cannot be removed from an append-only ledger; what the writer does about one is its judgment, recorded as a new entry (Rule Scope, principle 2), and a citation of a shared identifier is read as `<autoflow-root>/docs/decision-ledger.md` > Entry identifier > *Identifier collision* says.

## Execution Principles

- **[MUST] Human-decision presentation**: when a phase pauses to ask the human for a decision or answer — `AskUserQuestion`, or a "report to user + pause" exit (a harness-level block such as a tool or referenced-material request, a cap reached, a cycle the advisor ended at DIAGNOSE or GATE:HYPOTHESIS) — and in every advisor request and advisor answer record (`<autoflow-root>/docs/role-contracts.md` > Advisor), the presentation is **situation-first**, in this order: ① the situation in domain / behavior terms — what is wrong or being decided, and for whom (e.g. "auth state is not retained across pages from the user's entry point", **not** "module A's anchor-format constraint at the A↔B↔C consistency boundary"); ② the decision being asked, plus each option and what it changes; ③ anchors demoted to supporting evidence for drill-down, never the lead — a commit SHA with `path:line` for a fact of this tree, or the document, section heading and quoted sentence for a provision of a long-lived document. This register is distinct from the machine **Reporting Format** (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format), which is anchor-first. The `<attempt-dir>/*` body the user is pointed to is written in this same situation-first order — *Orchestrator context discipline*'s "anchor + one-line summary" governs what a spawn **returns**, not how a human decision is **framed**.
- **Verify role-spawn claims before dispatch**: every role-spawn report's Evidence anchor (see `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format item 5) is verified before ACCEPT — `git show <SHA>` for a commit anchor, the summary line read in the cited log for a test-pass anchor (the command is re-run only when the log is absent or does not carry that line, and the run is then `not-run` and run in place — `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *A run's evidence is the log it left*), `git show <SHA>:<file>` at the report's commit for a file-state anchor (a `path:line` is read only at the commit the report names), the result line read in the cited observation record for an observation anchor (`<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools > *The tools the work needs*). **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim.
- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's design, BUILD's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What is never skipped is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI (its result as it is: green, or, where the target's CI does not run for the pull request, that recorded on it — never read as green), the aggregated review and its verdict, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate.
- **Role-spawn idle handling**: a task notification signals only that a spawn finished; it does not require a response, and it is not itself the report. Continue work when (a) a spawn returns an actionable report — its return value — (b) a Bash result you initiated returns, or (c) the user types a new prompt. When a **Done** direct-spawn produces no report, do not wait for a follow-up: verify its `<attempt-dir>/*` artifact by shell and proceed (see "Incomplete output is never ground truth").
- **Background execution is orchestrator-only**: the `run_in_background` + wait-for-completion-notification pattern is available **only** to the orchestrator (the main loop), and every role spawn's Bash runs foreground-only; the binding rule lives in `<autoflow-root>/docs/role-common-rules.md` > Bash Execution Mode.
- **[MUST] Wait discipline (orchestrator)**: the orchestrator waits for a subagent, a `Workflow`, or a backgrounded Bash task by **ending its turn** — the harness re-invokes the session with a task notification when the task completes, and other tasks' notifications and the user's prompts are delivered in between. A **blocking wait** — a foreground `sleep` loop polling for a result — is not used. A polling wait is reserved for external state the harness cannot notify about (a CI run, a remote queue), and even then a bounded one; a task the harness tracks is never polled. One timer is admitted beside that wait, the **cache keep-alive wake**: a running task keeps its own prompt cache warm through its own requests, while the orchestrator sends none, so a wait longer than the prompt-cache TTL expires the orchestrator's cached context and its first turn after the notification re-writes all of it. While a tracked task runs, the orchestrator therefore may arm one backgrounded `sleep` shorter than that TTL (`run_in_background`; 50 minutes at the 1-hour TTL) and end its turn. The turn the timer wakes is not a poll: it reads no transcript or output file of the task — only a cheap anchor-check (a log's modification time, `git log -1`) — re-arms the timer and ends the turn, and the timer is stopped once the task's notification arrives. What the wake observes about the task's progress, and any decision drawn from it, is the orchestrator's judgment, recorded with its grounds in the report or ledger entry the phase already produces. The "no turn ends before the work is done" instruction is satisfied by the re-entry — the turn that ends on a pending notification is not an abandonment, the harness resumes it.
- **[DENY]** **mailbox-delivery instruction in a spawn prompt**: a prompt must never instruct a spawn to deliver its result by message to the orchestrator. A spawn prompt states the delivery action as "return … as your report", naming no carrier: the harness picks the carrier by permission mode, and in auto mode a spawn's final plain text is not delivered. There is one delivery path, and it is the return value; what carries a spawn's report is `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode.
- **Incomplete output is never ground truth**: a 1-line tool result such as a Read-dedup stub (`file unchanged … refer to that earlier tool_result`) is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`) and reproduce the finding before acting. Address another directory with `git -C <path>` + absolute paths rather than a `cd`-prefixed compound, which can raise a permission prompt. The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags the dedup case at runtime; the U2 unit document (`<autoflow-root>/docs/units/analysis.md` > Spot-check & escalation discipline) carries the full procedure.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.
- **[MUST] Ground every proposal**: present each proposal — especially a post-completion follow-up (new issue, follow-on work, improvement) — together with the sufficient grounds that support it (a verified fact, a reproducible observation, or a stated design judgment).
- **[MUST] File every issue through the wrapper**: `gh issue create` (and its REST form) is denied at the tool boundary. An issue is filed by writing a draft to `<drafts>/<name>.md` (`<drafts>` is what `autoflow-records drafts` prints) per `<autoflow-root>/docs/issue-proposal.md` and running `<autoflow-root>/scripts/issue/create-issue.sh --draft <drafts>/<name>.md`, which re-runs the duplicate search from the draft's own title. A report of having searched neither substitutes for the search nor narrows it. Keep the wrapper off every permission allow-list.
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

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `<attempt-dir>/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope are `<autoflow-root>/docs/role-contracts.md` > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are `<autoflow-root>/docs/role-contracts.md` > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. No document is injected wholesale as common context to every spawn; `<autoflow-root>/docs/INDEX.md` routes the usage documents beyond a role's guidance.

A spawn prompt names the cycle's inputs by path — the attempt's artifacts and the target's files — as its unit document's Unit spawn section says, and copies no guidance its carrier carries. A spawn with no AutoFlow definition — a unit's `general-purpose` helper, a research type, an ad-hoc spawn — receives the text of the rules its work follows in the prompt its spawner writes, from the spawner's own carrier. What a role reads beyond its guidance and its inputs is its own judgment.

## Communication

Communication with a role spawn is the `Agent` call itself:
the orchestrator spawns each role with a `subagent_type`, and the spawn's **return value is its
report**.

- The orchestrator spawns each role via `Agent` with `subagent_type: autoflow-<role>` and an explicit `model`; at ARCHITECT that is one `autoflow-unit-design` spawn.
- A spawn writes any body to `<attempt-dir>/*` and returns an anchor + one-line summary (`<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format).
- No team is created and no spawn carries `team_name` or `name` — a functional-unit agent's own helper spawns excepted, which are its method (ADR-0025 D2; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents). `SendMessage` is not an orchestrator channel — the orchestrator resumes no role by its agent ID (a functional-unit agent's use of it with its own helpers is its method), and it is never a report channel (a spawn's carrier: `<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). A project with sub-repos that needs another cross-service coordination takes it up through a new ADR, not through `SendMessage`.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: modifications outside the assigned scope are not allowed. *Secondary (multi-repo):* in a project with sub-repos, all AIs additionally have read access to the other sub-repositories.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`.
- A role spawn's "own scope" is the **target scope** it is assigned (the target repo/directory that owns the source). *Secondary (multi-repo):* in a project with sub-repos, that target scope is the sub-repo's directory.
- Cross-service changes are coordinated by the orchestrator, which spawns each scope's role directly and reconciles their returned reports.

For details, see `<autoflow-root>/docs/repo-boundary-rules.md`.

## Project Information

AutoFlow does not classify a project's repository structure and keeps no file of project facts. When work on a repository starts, the AI reads the project's own information and rule files where they exist — a `README.md`, a `CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs, such as how the repositories are composed (a host and its sub-repos, forks and upstreams) and where issues are filed. The operator writes those files while setting up the project, and they may already exist. A fact the work needs that no such file states is asked of the operator in conversation, with the request that the operator create the file or record the fact in it.

## Team Structure

각 역할의 상세 계약은 `<autoflow-root>/docs/role-contracts.md`를 참조한다.

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

The state file's naming, its schema and fields, the hook gates and the state at completion are `<autoflow-root>/docs/state-tracking.md`.

**Score recording**: the orchestrator copies the `scores` object of the Evaluation AI's report into the state file verbatim. The evaluator's own documents fix that object's shape (`<autoflow-root>/docs/evaluation-system.md` > Evaluation Output Format), so an evaluator prompt does not restate it (`<autoflow-root>/docs/role-contracts.md` > Evaluation AI Prompt Rules, rule 2). Each item's score is a number in `0`–`10`, bare or as an object's `score` — shown below; the two shapes may be mixed within one gate. A prose string such as `"9 - reason"` is **not** a score: the hook's state-file validator rejects it, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until the file is repaired.

<!-- SCORE-SHAPE-EXAMPLE -->
```json
{ "decision_grounds": { "score": 9, "reason": "evidence" }, "scope": 8 }
```

This object is the value of `phases.<gate>.scores` in `<attempt-dir>/issue-{N}.json`.

**Remedy class recording** (a GATE:QUALITY FAIL, an open recommendation attempt at any gate — what opens one is `<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage* — and an open REVIEW review-triage `design` attempt, recorded at `gate_quality` — `<autoflow-root>/docs/units/review.md` > *Routing*): the orchestrator writes the routed class — the farthest of the classes the route was computed from, or `operator` — as `phases.<gate>.remedy_class` (a sibling of `evaluator` and `scores` inside the phase object, the one additive placement the validator admits; never top-level, never inside `scores`). The value is **removed** once the re-score PASSes and no attempt is left open, or is left behind by a later cycle's record of that gate. The hook reads `gate_quality`'s value for the `git commit` gate (`<autoflow-root>/docs/state-tracking.md` > Hook gates), and the presence of a value at `audit` or `gate_quality` for the `git push` / `gh pr create` gates — an open re-entry is not pushed past (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

## Evaluation System
→ `<autoflow-root>/docs/evaluation-system.md`

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: `<autoflow-root>/docs/git-workflow.md`

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
- **[MUST]** Before committing, the committing role — every role that commits, the orchestrator included — runs the target repository's own lint chain over the staged files and confirms zero errors attributable to them. Elaboration (identifying the chains, execution trust boundary, scoping, outcome vocabulary, evidence anchor): `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules > *Lint chain on the staged surface*.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation and tests, sub-repo) | Build unit (U4) of that scope | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |
| Comment divergence fix (target code) | Orchestrator (sub-repo: the build unit of that scope) | Orchestrator |
| Sub-repo pointer (gitlink) commit or reconcile merge | Orchestrator  | Orchestrator |

## Reference Documents

- **AutoFlow phase guide**: `<autoflow-root>/docs/autoflow-guide.md`
- **Role contracts**: `<autoflow-root>/docs/role-contracts.md`
- **Evaluation system**: `<autoflow-root>/docs/evaluation-system.md`
- **Criterion review (an attempt's first stage, in U1)**: `<autoflow-root>/docs/criterion-review.md`
- **Git procedures**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/units/build.md -->

# U4 Build and verify — BUILD and AUDIT

> Unit document for U4. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

BUILD and AUDIT are one functional unit, U4 Build and verify
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed by
four things only — its goal, its artifact contract, its verification and its loop cap (D2) — and
this file states them, with the cautions the build is asked to heed and the result it owes. How the
unit reaches the goal — what else it reads, whether it spawns helpers, how it divides test and
implementation work, how it runs its checks and when it stops iterating — is the unit agent's,
recorded with its grounds in its artifact ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope,
principle 2).

- **Goal**: the design that passed GATE:PLAN, implemented within the cycle's scope, with every
  acceptance criterion verified as the verification design says.
- **Artifact contract**: the commits on the cycle's branch and the build report (*Build report*
  below).
- **Verification**: AUDIT — a fresh Evaluation AI that judges test-first from the build report and
  git, then scores the change on the rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) >
  *Gate rubrics* > AUDIT; the unit never scores its own artifact. U4 ends when `audit` PASSes
  (*Verification — AUDIT* below).
- **Loop cap**: a test-first finding or an AUDIT FAIL re-runs the unit with its findings and the
  previous artifacts (*Re-entry* below), max 2× together — the AUDIT FAIL cap
  (`<autoflow-root>/docs/core.md` > Flow Control > Regressions).
- **Result owed**: the build report's path, the commit SHAs and a one-line summary
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Reporting Format). The orchestrator
  does not receive the report's body.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| BUILD → AUDIT | the unit returned (`<autoflow-root>/docs/units/build.md` > *Report routing*) |
| AUDIT (test-first) → BUILD | the AUDIT evaluator does not confirm that a `driving` / `regression` test's Red run precedes its implementation commit with its failure shown in its log → it scores nothing, and a unit re-run takes its `## Test-first` section; consumes the AUDIT FAIL counter (Regressions below) (`<autoflow-root>/docs/evaluation-system.md` > AUDIT > *Test-first*; `<autoflow-root>/docs/units/build.md` > *Verification — AUDIT*) |
| BUILD → ARCHITECT | design contradiction — implementation and tests each faithful to the design while the acceptance criteria are mutually unsatisfiable, reproduced by measurement and recorded in `<attempt-dir>/issue-{N}-green-blocker.md` → ARCHITECT unit re-run → GATE:PLAN re-evaluation → BUILD re-entry (cap: Regressions below) |
| BUILD → user | a harness-level block — a lint chain covering a staged file stays `not-run (unexecuted)` because it is neither executable in this checkout nor covered by a nameable pull-request CI job → report situation-first + pause (`active:false`, `phase:"awaiting-user"`) |
| AUDIT entry (security-checklist change) → advisor | `<autoflow-root>/scripts/gate/security-checklist.sh status` exits `3` (the cycle changed the target's declared security checklist and no `[checklist-decision]` entry covers the committed version) → AUDIT is **not** spawned until the advisor's `[checklist-decision]` entry is recorded and the status re-run; `rejected` → the change is reverted first; consumes no re-entry budget (`<autoflow-root>/docs/units/build.md` > *Security checklist*) |
| AUDIT → GATE:QUALITY | security audit PASS + its recommendations triaged (no attempt open) |

## Unit spawn

- **The spawn.** One `autoflow-unit-build` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-build` names) once GATE:PLAN has PASSed. The
  prompt states the goal and names the inputs by path — the two design documents
  (`<attempt-dir>/issue-{N}-feature-design.md`, `<attempt-dir>/issue-{N}-verification-design.md`), the
  acceptance-criterion list (`<attempt-dir>/issue-{N}-analysis.md` > `## Acceptance criteria`), the
  decision ledger, the cycle-layer store `<attempt-dir>/issue-{N}-local/`, and each recommendation a
  gate's triage deferred to the build with its subject and finding
  ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) — and the build report's path. On a
  re-entry it also names what the re-entry is for and the material that carries it (*Re-entry*
  below).
- **Documents.** The unit's agent definition carries this file with the rest of its guidance
  ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection); the prompt names the affected docs DIAGNOSE
  identified by path, and the unit reads anything further by its own judgment. The return is routed
  (*Report routing* below).

## What the build owes

These are the rules other documents cite; everything else about the work is the unit's.

- **Scope.** The unit implements every issue acceptance criterion within the cycle's scope — the
  feature design with its `## Scope` section, and the verification design. An AC whose disposition
  is not `automated` ([U3 Design](<autoflow-root>/docs/units/design.md) > *Test necessity*) is still implemented; only its
  evidence differs. A problem met during the work that the scope does not name is judged under
  [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment* and recorded under `## Scope judgments`. Tests verify correctness; they do not define the
  solution — no hard-coding to test inputs, no special-casing an assertion. Once the scope is
  implemented and verified, a further change the unit judges useful beyond the scope and the problems
  its scope judgments include is recorded under `## Scope judgments`, not made.
- **Test-first (TDD).** Every `driving` and `regression` row's test is written before the
  implementation it verifies and seen failing; a `characterization` test may pass from the start. The
  order of the work — a failing run in the working tree first, or a test commit first — is the
  unit's. The result owed is the Red run's evidence (*Build report* > `## Test-first`). Cautions:
  - A test that passes from the start is not Red evidence. Look again at whether it checks the
    required behavior, and record that judgment in the report.
  - The Red run's failure is readable in its log, the exit status included.
  - `## Run record` holds one row per verification row — its latest run. The Red run goes in
    `## Test-first` only.

  ADR-0025 D3's test-first rule is judged by the AUDIT evaluator from this report and git: the Red
  run precedes the implementation commit, and its failure is shown by its log
  ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > AUDIT > *Test-first*).
- **Where a test lives.** A `cycle` row's test, a `delivery-check`, a `manual` scenario document and
  an observation record live under `<attempt-dir>/issue-{N}-local/` and are run by their path
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools). A test file
  goes into the target's tree only as the exception: in this repository a `standing` row
  (`automated / standing: <token>`); on a target, a file the unit judges the target should keep,
  listed under `## Test files kept` with its reason and the CI job expected to run it — HANDOFF
  carries that list into the PR body with the CI job that actually ran each file
  ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *CI* > *Added test files*). Such a file
  is wired into the target's CI discovery in the same commit.
- **Running tests.** Locally and once, the tests the change requires, the way the target runs them
  (*How a test is run is the target's practice*, *Local verification*); no whole-tree run. A row
  verified with a tool (`manual`, executor `AI: <tool>`) is looked at with that tool and its
  observation record written under the store, ending in one result line — `observation: match` or
  `observation: mismatch — <what differs>` (*The tools the work needs*). A tool neither this
  environment nor the target's procedures provide, or what using a tool the environment has lacks, is
  reported — naming what is missing, not the output the tool would give — and never acquired.
- **Comment check.** Before the unit's last commit it reads the comment lines the cycle's diff adds
  (`git diff <base>...HEAD`) against [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) >
  Change Surface Rules > *Code comments* — the classes a pattern finds (an issue / PR reference, a
  review round, an acceptance-criterion identifier, another file's path, a change-history marker) and
  those found by reading (a restatement of the code, design discussion, another file's contract,
  commented-out code, and content none of the cases under *What a comment carries* admits, such as a
  value, count or list copied from another file) — disposes of every hit (removed, rewritten, or
  kept with the reason the match is not the class) and records the result under `## Comment check`.
  The check is a signal, not a gate.
- **Design contradiction.** When the acceptance criteria are themselves mutually unsatisfiable — the
  implementation and the tests each faithful to the design — the unit implements the satisfiable
  subset and records the contradiction in `<attempt-dir>/issue-{N}-green-blocker.md`: the conflicting AC
  IDs, the measurement that reproduces the conflict, and `path:line` anchors at the cycle's commit.
- **Acceptance-criterion change.** Work that shows a criterion defective ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)
  > *Acceptance-criterion decisions*) is raised in the report with the criterion, the proposed change
  and the fact that shows the need — never worked around by keeping the criterion's letter
  ([U3 Design](<autoflow-root>/docs/units/design.md) > *Report routing* > *An acceptance-criterion change raised later in the
  cycle*).
- **Commits.** Every commit follows `<autoflow-root>/docs/core.md` > Commit Rules, the lint chain over its staged files
  included. The unit does not push.

## Dividing the work

A recommendation, not a rule: whether the unit divides its work, and how, stays its own, and the
division it chose and its grounds go in the build report. This section records what a division is
worth and where it loses.

- **What a boundary is worth.** A context's cost is what it carries times the requests that carry
  it: what was read for finished work is read again on every later request. A boundary pays when
  the context it drops, less what a new context takes in to start (the standing prompt and the
  handoff below), is large and many requests follow it. A boundary that drops little more than
  that, or that few requests follow, costs more than it saves.
- **Where to divide.** On a build whose design names several areas that share no code, two
  boundaries pay:
  - between areas — an area's code is not used by the next, so the next carries none of it;
  - after the last implementation commit — verification and integration read again what they
    need, which costs far less than carrying every area's context.

  Inside an area the Red→Green loop is not divided: the test, the implementation and the reading
  of a failure use the same code.
- **A layout.**

  | Context | Its work | Policy row |
  |---|---|---|
  | The unit itself | reads the design and the rules, assigns the areas, checks each return, spawns the observations | `unit-build` |
  | One per area | the area's Red→Green, its tests and lint, its commits | `unit-build-area` |
  | Verification and integration | the run record, each verification row's check, the follow-up of the observations, the comment check, the build report | `unit-build-verify` |
  | One per observation | the observation with its tool: running it, judging match or mismatch, probing a cause | `unit-build-observe` |

  A helper is spawned as `general-purpose` with the model and the effort its row reads out
  (`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <row>`, `… effort <row>`), the effort passed as
  the `Agent` tool's `effort` parameter — or the parameter omitted when the row reads out the
  inherit sentinel, which is the policy file's own value and never an argument (`effort_contract`).
- **What crosses a boundary.** To an area: its section of the feature design, the sections every
  area shares (`## Scope` and the common constraints the design names), its verification rows, a
  note of the repository's conventions (how its tests and lint run, its commit rules) the unit
  writes once, and the diff of a shared file an earlier area changed. From an area: its commits,
  its `## Test-first`, `## Run record` and `## Lint` rows, its scope judgments and out-of-scope
  observations, and what a later area needs to know of its changes. To every helper: the AutoFlow
  root (the unit's root declaration) and the text of the rules its work follows, from the unit's
  own definition —
  `<autoflow-root>/docs/core.md` > Commit Rules, `<autoflow-root>/docs/submodule-common-rules.md` >
  Change Surface Rules > *Lint chain on the staged surface* and `<autoflow-root>/docs/role-common-rules.md` >
  Bash Execution Mode — since a `general-purpose` helper has no AutoFlow definition of its own
  (`<autoflow-root>/docs/core.md` > Context Injection). Requirements of two areas that
  cannot both hold take the design-contradiction path above; a design point two areas meet
  differently is a decision point.
- **A deterministic run is a command, not a context.** Running tests, lint and builds, and
  committing, take no judgment; what they cost is their output carried in the context that reads
  it. A run goes through a command that bounds its time, keeps the full output in a log under the
  cycle-layer store, and prints the exit status, the summary line, the names of failing tests, the
  first error block and the log's path. That short result fills `## Run record` and `## Test-first`;
  the log stays the evidence. A run with no bound holds the context that started it, and every
  helper report waiting on that context. A model spawned for each run costs more than it saves:
  each spawn writes its standing prompt anew.
- **A judgment stays with the work it judges.** An observation's match or mismatch is judged by
  the context that ran it, which can probe a cause while the state is in front of it; a judging
  context split from the run reads the records and captures again and cannot probe. The comment
  check and the scope judgments belong to the context that holds the whole diff.
- **When a division loses.**
  - The areas share code: what each must read again of the others' code outweighs the context
    dropped.
  - The build is small: the context before a boundary is near what a new context starts with, or
    few requests follow it.
  - A model is spawned for each deterministic run.
  - The handoff is the whole design and every convention rather than the area's part: most of the
    saving is lost.

## Build report

`<attempt-dir>/issue-{N}-build-report.md`. The unit writes it whole on its first run and brings it up to
date on a re-entry that passes through AUDIT and GATE:QUALITY (*Re-entry* below). Every section
below is present; a section with nothing to record says `none`.
The five record sections are tables, one row per item, in any column order; the column a reader
needs is named below.

| Section | Holds | Read by |
|---|---|---|
| `## Test-first` | one row per `driving` / `regression` test: `Issue AC`, `Test` (its path), `Red at` (the commit the failing run was made at), `Red log`, `Red line` (the summary line read from that log), `Red exit` (the run's non-zero exit status, shown in its log), `Impl commit` (the commit that makes it pass) | AUDIT (*Test-first*) |
| `## Run record` | one row per `automated` or `delivery-check` verification row, its latest run: `Issue AC`, `Command`, `Log`, `Summary line`, `Result` (`pass` / `fail`) | GATE:QUALITY `Test coverage`; HANDOFF (PR body) |
| `## Manual checklist` | one row per `manual` row: `Issue AC`, `Executor` (`AI: <tool>` or `person`), `Record` (the observation record's path, or `delegated to user`) | GATE:QUALITY `Test coverage`; HANDOFF (PR body) |
| `## Maintained documents` | one line per document the change updated, ``- `<path>` — <what changed>``, or `- none — <reason>` | GATE:QUALITY `Doc updates` |
| `## Lint` | one row per chain per commit this cycle makes on the branch: `Commit` (≥ 7 hex), `Chain`, `Outcome` (the lint outcome word, a `not-run` with its reason class in parentheses); a commit another actor makes on the branch adds its own rows | GATE:QUALITY `Commit conventions` |
| `## Scope judgments` | each scope judgment the work made ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope judgment*) | GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Out-of-scope observations — guard / boundary logic touched` | each behavior-changing suggestion the unit rejected whose subject is validation, a guard, path / root resolution, an input or output boundary or error handling, and each one it judged directly related — its `path:line` and the behavior it would change | GATE:QUALITY (`refine_observations`) |
| `## Comment check` | the line `comment-ratio: <added comment lines>/<added lines> (<percent>)`, then one line per hit — `path:line`, class, disposition | GATE:QUALITY (*Code comments in a target*) |
| `## Test files kept` | each test file added to the target's tree, its reason and the CI job expected to run it | GATE:QUALITY `Test quality`; HANDOFF (PR body; *Added test files*) |

Anything else the unit records — how it divided the work, the checks it chose to run and what they
found — is its own, written where it judges useful.

## Report routing

- **The unit's return** → AUDIT (*Verification — AUDIT* below), whose evaluator judges test-first
  before it scores.
- **A `green-blocker` record** → an ARCHITECT unit re-run naming it ([U3 Design](<autoflow-root>/docs/units/design.md) >
  *Re-entry*), then GATE:PLAN's re-entry re-score and a U4 re-run; consumes the ARCHITECT re-entry
  counter.
- **An acceptance-criterion change** → the orchestrator's decision, the advisor's where the
  report's grounds do not settle it; where the cycle re-enters on its `[ac-decision]` entries is the orchestrator's judgment
  ([U3 Design](<autoflow-root>/docs/units/design.md) > *Report routing*). No counter.
- **A tool, or what using one lacks, reported missing** → the tool request pause ([`core.md`](<autoflow-root>/docs/core.md) > Flow Control).
- **A lint chain reported `not-run (unexecuted)`** because it is not executable in this checkout and
  no pull-request CI job covering it can be named → a harness-level block: the cycle pauses for the
  operator (`active:false`, `phase:"awaiting-user"`), presented situation-first
  ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Human-decision presentation*).

## Verification — AUDIT

One fresh Evaluation AI (`autoflow-evaluator`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model audit` names) judges test-first and scores the
change on the rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > AUDIT.
Its agent definition carries that document. Its spawn prompt carries the security-checklist record
line (*Security checklist* below).

- **Test-first not confirmed** → the evaluator scores nothing and returns its `## Test-first`
  section. The orchestrator does not re-spawn the evaluator: a BUILD unit re-run takes the section
  (*Re-entry* below), consuming the AUDIT FAIL counter.
- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → immediate block) → recommendation triage
  ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) → GATE:QUALITY.
- **FAIL** → a BUILD unit re-run with the report's failed items (*Re-entry* below), then a
  re-evaluation (max 2×, the counter shared with test-first findings). Third FAIL → human.

### Security checklist

The target's own: AutoFlow ships no checklist and names no item. A target declares its checklist
in the target-owned scaffold `.claude/autoflow.local.json`
(`{"audit":{"security_checklist":"<repository-relative path>"}}`). At AUDIT entry the orchestrator
runs `bash <autoflow-root>/scripts/gate/security-checklist.sh status --ledger <attempt-dir>/issue-{N}-ledger.md` and
acts on its one record line:

| Exit | Verdict | What follows |
|------|---------|-------------|
| 0 | `none-declared` | AUDIT is spawned; no checklist — the five items are scored from the change alone |
| 0 | `unchanged` | AUDIT is spawned; it reads the checklist as of the cycle's base commit (`score=<base>:<path>`) |
| 0 | `changed-decided` | AUDIT is spawned; it reads the changed version a `[checklist-decision]` entry accepted (`score=HEAD:<path>`, or `none` for a dropped declaration) |
| 3 | `changed-undecided` | **[MUST]** AUDIT is not spawned: the orchestrator hands the change to the advisor with a request written situation-first ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor) and re-runs the status on its answer |
| 2 | — | nothing — a malformed declaration, a declared file not committed, an uncommitted edit to the declaration or the checklist, or no resolvable base; repair it and re-run |

**A change the cycle makes to its checklist.** A change to the file, or to the declaration that
points at it, has no effect on that cycle's AUDIT until it is accepted — by the advisor first, and
by the operator's override, recorded as an entry that names the advisor's (`- Overrides: A<n>`).
Standing entries that disagree with neither naming the other are a conflict: the record is
undecided with `conflict=<ids>`, and a new entry resolves it. The answer is a `[checklist-decision]`
ledger entry ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Security-checklist decisions*):
`accepted`, carrying the committed version's blob and non-empty Decision and Grounds lines under
the authority `advisor decision` on an `A<n>` entry (an override: `operator decision` on an `O<n>`
entry) → the status re-run reports `changed-decided`;
`rejected` → the change is reverted and the status re-run. The decision consumes no re-entry budget.

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-build` by *Unit
spawn* above, whose prompt names what the re-entry is for, the material that carries it, and the
build report so far. On a re-entry that passes through AUDIT and GATE:QUALITY, the report is
brought up to date, not rewritten: a row a re-entry supersedes is replaced, a new commit adds its lint
rows, and the sections GATE:QUALITY reads carry the current state.

| Re-entry | Material named | Counter |
|---|---|---|
| AUDIT test-first finding | the AUDIT report's `## Test-first` section | AUDIT FAIL (max 2×, shared) |
| AUDIT FAIL | the AUDIT report and its failed items | AUDIT FAIL (max 2×, shared) |
| GATE:QUALITY FAIL routed `test` / `impl` | the evaluation report and its failed items | GATE:QUALITY FAIL (max 3×) |
| a `test` / `impl` recommendation attempt at AUDIT or GATE:QUALITY | the recommendation's subject and finding | the attempt window (max 7×) |
| REVIEW review-triage thin route (`test` / `impl`) | the finding row in the PR's findings file | the auto-resolution window (max 7×) |
| advisor answer or operator override that reaches the build | the `A` / `O` entries | none |

An INTEGRATE failure names the failing check and its output; a HANDOFF CI failure routed `test` /
`impl` names `<attempt-dir>/issue-{N}-ci-failure.md`. The unit fixes what failed, and the cycle runs
forward again to the INTEGRATE check or the CI that failed.

A re-entry passes through AUDIT and GATE:QUALITY on their narrowed re-scores
([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > AUDIT > *Review-response re-score*; > GATE:QUALITY > *Re-entry re-score*). A REVIEW thin route fixes the finding on its own surface and returns to the reviewer
re-review; it does not bring the build report up to date.

The unit reads and writes no `<attempt-dir>/issue-{N}.json` state file, so every counter above is the
orchestrator's own accounting.

## Header contract

Opted-in targets only; this repository does not opt in. Every executable spec under `tests/**`
declares, in a column-1 comment header, what it is and what it costs — at creation, not
retroactively. The grammar's single definition site is `<autoflow-root>/scripts/test/suite-manifest.sh`, and
`<autoflow-root>/scripts/test/check-suite-manifest.sh` enforces it.

  ```
  # ci-subject: <path-or-glob> [<path-or-glob> ...]
  # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
  ```

- `ci-subject` — the trigger surface. It is a coverage declaration and the selector's input: `<autoflow-root>/scripts/test/select-suites.sh` consumes it to decide which suites a change requires.
- **The grammar is those two fields and nothing else.** The lint admits no other field.
- `budget-secs` — the wall-clock ceiling for one run, **derived from the suite's own CI step duration**, never from local wall-clock. A suite with no CI-measured duration yet declares `SUITE_BUDGET_CEILING_SECS` verbatim. The workflow step's `timeout-minutes` must equal `ceil(budget-secs / 60)`.

**Adopting the contract over existing suites**. *At creation, not retroactively* fixes what a **cycle** owes: no cycle is deficient for a suite it did not create. It does not exempt a suite from selection — `<autoflow-root>/scripts/test/select-suites.sh` BLOCKs every selection while any enumerated suite lacks a usable `ci-subject` header — so a target that opted into the suite plane and whose `tests/**` held suites before it did migrates them once, as target-owned work outside any cycle, before its first BUILD. The PREFLIGHT target check (`<autoflow-root>/scripts/preflight/target-check.sh`, leg D7) names each one, and `bash <autoflow-root>/scripts/test/select-suites.sh --check-headers` lists them on demand. For each listed file:

1. **Suite or helper** — every `*.sh` / `*.bats` under `tests/**` is enumerated, and the runner executes it. A file other suites source is not a spec: it moves under `tests/lib/`, the one exclusion (`suite_is_excluded`), and needs no header.
2. **`ci-subject`** — every path whose change can move the suite's verdict: the scripts it executes, the files it reads or greps, the configuration it parses. The suite's own path is matched without being listed. An uncertain subject takes a directory token (`scripts/`) or a glob (`src/**`) rather than a guess at single files; `**` selects the suite on every change.
3. **`budget-secs`** — `ceil(measured CI step duration × SUITE_BUDGET_HEADROOM_PERCENT / 100)` when the suite already has a CI step duration, otherwise `SUITE_BUDGET_CEILING_SECS` verbatim; a local wall-clock figure is never the source.
4. **CI steps** — where the target's CI runs these suites, `check-suite-manifest.sh` requires one step per suite behind a `select` step that runs `select-suites.sh`, each carrying `id: s-<basename>`, the guard `if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/<file> ')` and `timeout-minutes` equal to `ceil(budget-secs / 60)`. A step that runs several suites is split into one step per suite.

The fields go in the file's leading comment block at column 1, before its first non-comment line. The migration is complete when `select-suites.sh --check-headers` exits `0`, `check-suite-manifest.sh` reports OK and the target check reports `PASS: D7`.

**Naming**: a committed test is subject-named; an issue number does not belong in its file name. A one-shot check is not a committed file, so no naming rule reaches it.

**Leaf rule**: a suite executes its subject, not another suite. Enforced by `<autoflow-root>/scripts/test/check-suite-leaf.sh`.

**Admission**: before creating a suite file at all, answer these two questions.

- Does an existing standing lint already hold the property tree-wide? If so the check is that lint's, not a new arm's.
- Does the defect the check catches surface only *before* deployment — one local run settles it, or it is pinned to this cycle's landed diff? Then it is a `cycle` artifact under `<attempt-dir>/issue-{N}-local/` (a `delivery-check`, or a default `automated` row), not a suite file (in this repository the `standing` categories are ADR-0024 D1's closed list, and on a target the default is to add no file at all).

<!-- From <autoflow-root>/docs/role-contracts.md > Functional-unit agents -->

## Functional-unit agents (U2 / U3 / U4)

ADR-0025 D1 replaces the sixteen phases with six functional units as the unit of prescription; D2
prescribes a unit by its goal, its artifact contract, its verification and its loop cap only. The
three unit agents that run a unit's work are defined here; U1, U5, U6 and U7 have none (U1, U6 and U7 are the orchestrator's
own work, with scripts that read and report, D8; U5 is the gate itself).

| Unit agent (`subagent_type`) | Unit | Gate class (hook) | Exit |
|---|---|---|---|
| `autoflow-unit-analysis` | U2 Analysis (DIAGNOSE, GATE:HYPOTHESIS) | analysis — no score gate | `gate_hypothesis` |
| `autoflow-unit-design` | U3 Design (ARCHITECT, GATE:PLAN) | planning — GATE:HYPOTHESIS pass, or a `skipped` verdict | `gate_plan` |
| `autoflow-unit-build` | U4 Build and verify (BUILD, AUDIT) | implementation — GATE:PLAN pass | `audit`, test-first judged by its evaluator |

- **Method is the unit's.** How the unit reaches its goal — what else it reads, whether it spawns helpers
  or holds a dialogue, how it designs the issue's own verification — is the unit agent's, recorded
  with its grounds in the unit's artifact ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).
  The definitions (`<autoflow-root>/agents/autoflow-unit-*.md`) name the goal, the artifact contract and the
  verification, and nothing else of their own; below that they carry the unit's guidance, generated
  ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection).
- **A unit agent's spawns inherit its gate class.** The hook admits a spawn whose caller
  (`agent_type`) is a unit agent without a role declaration and judges it by the unit's class; a
  declared role that has a gate of its own keeps that gate too, so an existing role type is never
  judged more loosely because a unit spawned it (`<autoflow-root>/docs/gate-matching-standard.md`
  > P3). The caller is the immediate one: a helper's own spawn is judged by its own declaration.
- **The authority rules hold** (ADR-0025 D3): a unit agent never scores its own artifact, never writes
  the state file or the ledger, never pushes, merges or files an issue, and a decision point it meets
  goes to the advisor.
- **Model and effort** come from the policy rows `unit-analysis`, `unit-design` and `unit-build`,
  held at the values of the phase rows each unit replaces (DIAGNOSE; ARCHITECT; RED /
  GREEN), so each migration step's measurement against the baseline isolates the method change.
  The helpers a U4 unit spawns when it divides its work take theirs from the rows
  `unit-build-area`, `unit-build-verify` and `unit-build-observe`: each is spawned as
  `general-purpose` with the row's model and with the row's effort passed as the `Agent` tool's
  `effort` parameter, omitted when the row reads out the inherit sentinel
  ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *Dividing the work*). A helper receives in its prompt
  the AutoFlow root and the text of the rules its work follows
  ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *What crosses a boundary*).

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Change Surface Rules -->

## Change Surface Rules

Every changed line traces to the cycle's scope: the issue's acceptance criteria, the confirmed cause recorded in DIAGNOSE, the agreed plan, and each problem a recorded scope judgment includes (**Scope judgment** below). What belongs to the cycle is decided by that judgment, not by whether an acceptance criterion names the line. How small the change stays inside that scope is governed by **Trace rule**, **Surrounding code** and the **Over-engineering guard** below.

### Scope judgment
A role that meets a problem the acceptance criteria do not name answers two questions and records the answers with their grounds, under a `## Scope judgments` heading in the report or artifact its phase already produces ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

1. **Is it directly related to this issue?** It is when any one of these holds:
   - it comes from the same confirmed cause;
   - this change created it or exposed it;
   - unless it is fixed, the behavior an acceptance criterion promises does not hold in actual use.
2. **Is fixing it in this cycle desirable?** It is when it lies in the same module, is confirmed by the same verification, and fixing it separately would reopen the same code. It is not when it needs a design decision of its own, touches another ownership scope, or carries more risk than this issue.

| Judgment | Disposition |
|---|---|
| Directly related, fixing it here desirable | fixed in this cycle; the recorded judgment is the trace of its hunks |
| Directly related, fixing it here not desirable | separated, with its **separation reason** recorded |
| Not directly related | separated — reported in one line with its `path:line`; a separate issue is the follow-up path |

- **The default follows the first question.** A directly related problem is included unless a separation reason is recorded. A problem noticed in passing — a style inconsistency, pre-existing dead code, a refactor opportunity — meets none of the three conditions and stays out (**Surrounding code**, **Refactor scope**).
- **A record line** names the problem (its `path:line` at the report's commit, or the design section), the condition of question 1 it meets or that none does, the answer to question 2 with its ground, and the disposition.
- **An inclusion is verified like the rest of the scope.** At ARCHITECT it gets a verification-design row whose `Issue AC` is `—`; found later, the role that fixes it runs the tests it judges the fix requires and records the run (Verification and Tools > *Local verification*).
- **Criterion defects.** From ARCHITECT on, beside the two questions the role weighs whether what it met shows a criterion defective ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*). A same-cause problem reaching past what the criteria name may mean the issue drew the problem too narrowly — and then whether the approach itself must change is the question, not only whether to include the rest; an item a criterion names that turns out to be a problem separate from this issue may mean it drew too wide. Including a problem does not change a criterion, and a criterion is not carried out merely because it names an item: a defect so judged is recorded here and raised in the report with the criterion, the proposed change and the fact that shows it, and the orchestrator decides it, putting it to the advisor where those grounds do not settle it ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*).
- A role that is not confident, or whose inclusion would change a design decision, raises the question instead of deciding it (principle 3).
- **Where it is applied**: DIAGNOSE's scope judgments (the analysis report's `## Scope judgments`) and the ARCHITECT feature design's `## Scope` section set the cycle's scope; the BUILD unit judges what it meets during the work; and the gates' recommendations are triaged by the reviewer-finding procedure, where the same two questions decide which recommendation is not the issue's and ground the `Low` judgment (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which acceptance criterion, confirmed cause, plan item or recorded scope judgment requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk whose rationale names none of them is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC or a recorded scope judgment requires the change. A comment attached to code this change modifies is not adjacent — it is part of the change (**Code comments** > *Changing commented code*).
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing — which **Scope judgment** does not make directly related — are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the cycle's scope needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the cycle's scope (**Scope judgment**). A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. What a comment on changed code may carry is **Code comments** below.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Code comments
The rule governs every comment in code a cycle writes or modifies — implementation and test files, in a target and in this repository. Existing comments on code the cycle leaves untouched stay as they are (**Surrounding code**).

- **[MUST] The test**: a comment carries only a sentence that stays true for as long as the code it sits on is unchanged — however much time passes, and whatever changes in other files.
- **What a comment carries** — only what a reader cannot recover from the code, and only in one of these cases, each about the code the comment sits on:
  - an external constraint: the behavior of a runtime, a tool, or a protocol the code depends on;
  - an invariant that the code does not make evident;
  - what breaks if the code is written otherwise, in a line or two;
  - a function's contract — its arguments, return value, and exit codes — in one line.
- **What a comment does not carry**:
  - a restatement of what the code does;
  - design discussion and rejected alternatives;
  - change history — what the code did before, what it no longer does, what an earlier version wrote;
  - an issue, PR, review-round, or acceptance-criterion identifier;
  - the path or the contract of another file;
  - commented-out code.
- **Where that content goes**: a decision and its grounds → the repository's decision record (in this repository, `docs/records/adr/` and `docs/records/design-rationale.md`); change history → the commit message and the PR body; discussion → the cycle's `<attempt-dir>/*` design documents and the issue. The only reference a comment carries is at most one ADR identifier (`ADR-0024`).
- **Test files**: a test's intent is stated in its name and its assertion messages. A comment in a test file carries only the reason for a fixture that the fixture does not make evident.
- **Changing commented code**: **[MUST]** a comment attached to code this change modifies is updated or deleted in the same commit. When it is uncertain whether the comment is still true, delete it.
- **Directives are code**: a line a tool reads to change its behavior is code even when written in comment syntax — a lint suppression or a type-checker directive, for example — and this rule does not govern it; an explanation written beside it is a comment and does. Which lines are directives is the working AI's judgment in that target; no list is kept.

The BUILD unit checks the cycle's diff against this rule (`<autoflow-root>/docs/units/build.md` > What the build owes, *Comment check*). In a target's code, a comment that diverges from its code or carries what this rule sends out of a comment is a `Low` finding for the reviewer and the evaluator, and its fix is the orchestrator's direct commit; a defect a comment carries on its own ground, such as an exposed credential, takes the severity and route its impact sets (`<autoflow-root>/docs/units/completion-evaluation.md` > *Code comments in a target*).

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC or a recorded scope judgment requires it.

### Lint chain on the staged surface
This section is the rule's only home. Its search terms:

```
git grep -n -i -E 'lint[- ]chain|lint-outcome|lint outcome|ci-deferred|unexecuted|not-covered|modified-in-branch'
```

- **[MUST]** Before a commit is made, the committing role runs every lint chain of the target repository that covers at least one staged file over the staged files, and confirms zero errors attributable to them. Auto-fixable formatting is applied and staged in the same commit.

**Which chains exist, and how each runs, is the target's practice.** AutoFlow prescribes no lint command and no discovery order to a target. The committing role finds, at the location it commits in, how that target lints a change: its documents (`CLAUDE.md` > Development Commands, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a commit hook) and its pull-request CI. From them it judges which chains exist, the command that runs each in the working checkout, the files each covers, and which CI lint steps gate this pull request. A CI step that does not run for this pull request — its trigger, path filter, or job or step condition excludes it — gates nothing here and is not counted as a chain; the condition that excludes it is recorded as the ground. Where a CI step and a local command both stand for one chain, the local command run is one that selects and checks the files the step does. The judgment and its grounds go into the report (**Evidence anchor** below).

**Execution trust boundary** — **[MUST]** the command run at commit time is one the baseline — the attempt's base (`autoflow-records base`) at its merge-base with `HEAD` — already carries. Before running it, the committing role confirms that the command's text at its source — the document entry, the script definition or the CI step body it was taken from — and any script file that text invokes by path are unchanged versus the baseline. A command this branch altered or added is not executed: the chain is reported `not-run` with the reason `modified-in-branch`, whichever source it came from. A command is run exactly as its source states it — a read-only check, not licence to run any other step, argument or command its source names.

**Not executable in the checkout** — a chain the committing role cannot run in the working checkout (a CI step whose work is a third-party action reference with no local command that does the same, a tool the environment lacks) is reported `not-run` naming the step or command and the reason. A chain that cannot be run imposes a reporting obligation, not a blocking one: the commit proceeds. Not blocking the commit is not clearing the gate — GATE:QUALITY's `Commit conventions` clears the chain only by its reason class (**`not-run` reason classes** below). Making a chain locally executable belongs to the target repository's ops and is outside this rule's authority; a tool the work needs is secured as Verification and Tools > *The tools the work needs* says.

**Scoping** — run the chain restricted to the staged files where the chain supports scoping. Where the chain only runs whole-tree, run it whole-tree and require that no reported error names a staged file; pre-existing errors on untouched files are not this cycle's surface (**Surrounding code**).

**Outcome vocabulary** — the report carries one word per chain the committing role identified, and the word set is total over the reachable states:

- `clean` — the chain ran and reported nothing attributable to the staged files;
- `fixed-and-staged` — the chain ran and reported fixable findings, and the fixes are in this commit;
- `detected` — the chain ran and reported findings attributable to the staged files that were not auto-fixed; the commit does not proceed until they are resolved;
- `not-run` — the chain covers a staged file but did not execute; the word attaches to the fact of non-execution, regardless of why it did not execute, and the report names the chain, the reason, and exactly one reason class from **`not-run` reason classes** below;
- `not-covered` — the chain exists and no staged file is in the set of files it covers;
- `not-applicable` — the committing role found no lint chain in the target; the report carries this word once, in place of any per-chain line.

**`not-run` reason classes** — **[MUST]** every `not-run` line carries exactly one of two classes. The class, not the word, decides whether the lint record's reader — GATE:QUALITY's `Commit conventions` ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:QUALITY) — clears the chain:

- `ci-deferred` — the chain cannot run at the commit boundary (**Not executable in the checkout** because no local command does what its CI step does, or withheld by the **Execution trust boundary** as `modified-in-branch`) **and** a named pull-request CI job runs that same chain over the staged files for this pull request. It is cleared as a deferral;
- `unexecuted` — anything else: executable but not run, a tool the environment lacks, or no covering pull-request job can be named. It is not cleared: it is an omission, filled where it is found (Verification and Tools > *A missing run is filled where it is found*).

- **[MUST]** Fail-closed default: a chain whose reason class cannot be established is `unexecuted`. The permissive class is the one earned by evidence; the absence of evidence yields the blocking one.

A `ci-deferred` deferral is discharged at HANDOFF's CI confirmation, which confirms the PR's check rollup is green — at least one check present and every element green (`<autoflow-root>/scripts/handoff/confirm-ci-green.sh`). That confirmation is over the rollup, not a per-job execution guarantee: nothing in it re-checks that the named covering job appears in the rollup, so the producer's covering-job citation and trigger evidence (Reporting Format item 5) are what tie the deferral to a job that actually runs, and the evaluators re-derive them from the report. When no CI runs for the pull request (`confirm-ci-green.sh` exit `11` judged not run), the deferral is not discharged: the chain is listed on the pull request as not run ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI*).

- **[MUST]** A chain that did not execute is reported `not-run`, never `clean`.

**Evidence anchor** — the committing role's report carries the lint outcome as an anchor class of Reporting Format item 5, whose single-anchor requirement it satisfies as a per-chain enumeration followed by the grounds of the identification (form and cardinality there).

### Refactor scope
A refactor of the cycle's diff applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. A refactor tool's findings are advisory, not licence to expand the change surface. A finding that describes a behavior defect rather than a refactor is not a refactor to apply: the BUILD unit records its **Scope judgment**, and one judged directly related goes to the build report's out-of-scope-observations section for the evaluator to dispose of (`<autoflow-root>/docs/units/build.md` > Build report).

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` and `Impact scope` items are scored against this section, on one scope: prefer the smallest sufficient change that resolves the confirmed problem within the cycle's scope. The cycle's scope is the acceptance criteria, the confirmed cause recorded in DIAGNOSE (`<attempt-dir>/issue-{N}-analysis.md`), and the problems the cycle's recorded scope judgments include (**Scope judgment**) — a boundary, not a line count. A correctly scoped change is not scored down for being larger than a symptom patch. The evaluator reads the scope records for both items: the feature design's `## Scope` section and every `## Scope judgments` section in the cycle's `<attempt-dir>/issue-{N}-*.md` reports, with the ledger's `[gate-autofix]` entries and gate verdict entries (`<autoflow-root>/docs/units/completion-evaluation.md` > *Recommendation triage*).

A high-scoring change:
- resolves the confirmed cause, not only the reported symptom
- stays inside the module or component that owns that cause
- includes the local cleanup the fix itself requires — the code and symbols this change renders unreachable or unused, removed in the same commit; cleanup merely noticed nearby does not qualify (**Surrounding code**), and **Orphans from this cycle** is the symbol-removal instance of this same test, not its limit
- fixes each directly related problem its scope judgments include, and leaves out a directly related problem only with a recorded separation reason
- leaves every surface outside the scope untouched — behavior, APIs, configuration, and documentation are examples of such a surface, not the boundary — and keeps, inside it, the existing behavior that neither the acceptance criteria, the confirmed cause nor a problem its scope judgments include asks to change, a protection or the order of checks included; recording such a change as a known gap does not bring it into scope

`Minimal implementation` asks whether each hunk is needed. The question is asked against the smallest change that satisfies the acceptance criteria, with the tests its verification design requires, and resolves the confirmed cause: a hunk beyond it stands only on its own recorded ground. It fails when a hunk traces to no acceptance criterion, confirmed cause or recorded scope judgment — "I noticed it while I was here" cleanup (**Surrounding code**) or depth creep beyond what the scope needs (**Over-engineering guard**) — regardless of code quality, and when a hunk rests on a scope judgment that meets none of question 1's three conditions. It fails symmetrically when the change is too narrow to resolve the confirmed cause: a change that leaves the confirmed cause in place is not sufficient, and does not score well for being small.

`Impact scope` asks the same question from the other side: whether the change reaches what its scope requires. A directly related problem that the cycle's own records show — a scope judgment, a build observation, an earlier gate's recommendation — and that the change leaves out with no separation reason recorded lowers it, as does a separation reason that answers neither half of question 2.

**Comments in a target's code.** The item also weighs the comments the change adds, by content and by volume, reading the build report's `## Comment check` section (`<autoflow-root>/docs/units/build.md` > Build report) — its `comment-ratio` line and its hits — with the comments in the diff:
- *Content*: a comment that **Code comments** does not admit — a restatement of the code, a design ground, a reference or a history — is depth the AC does not need, as an unneeded hunk is.
- *Volume*: even where every comment is admitted, the evaluator judges whether their amount, absolute and relative to the code they sit on, exceeds what a reader of the changed code needs — a comment block larger than the logic it explains, for example. The judgment is qualitative, with no ratio threshold, and names the comment blocks it rests on.

The evaluator records each such finding in the item's `reason` and in `recommendations`, and does not lower the item's score for it: in a target a comment finding never fails the gate (`<autoflow-root>/docs/evaluation-system.md` > *Code comments in a target*, which also names the defects a comment can carry on their own ground and that this exclusion does not cover). In this repository the item is scored without this comment weighing.

---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Reporting Format -->

## Reporting Format

When a role spawn reports to the orchestrator — the report is the spawn's return value, with any body written to `<attempt-dir>/*` and an anchor plus a one-line summary returned — it must follow this shape (see [`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Orchestrator context discipline*). This format governs **AI↔AI / AI↔orchestrator** reporting: the returned report, and what a unit agent's helpers report to it. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in [`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite `<attempt-dir>/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report the test runner's summary line (e.g., "Tests: 147 passed, 147 total"), read from the run's log (item 5), + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the run's **log** — the file its output was written to (Testing Standards item 7), cited by path under `<attempt-dir>/issue-{N}-local/` — with the command that produced it and the exact `Tests: N passed, N total` (or equivalent) summary line read from that log. The log is the evidence and the summary line is the value read from it; a line no log carries is not evidence (Verification and Tools > *A run's evidence is the log it left*)
   - file state → `path:line` at the commit SHA the report is keyed to, plus the verbatim content of that line (a line number is read only at that commit — [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger)
   - observation (a criterion verified with a tool) → the row's observation record, cited by path under `<attempt-dir>/issue-{N}-local/`, with its result line (`observation: match` / `observation: mismatch — …`) read from it; the artifacts it cites are under the same prefix (Verification and Tools > *The tools the work needs*)
   - lint outcome (the pre-commit lint chain over the staged surface, Change Surface Rules > *Lint chain on the staged surface*) → one line per chain the committing role identified, followed by the grounds of the identification — where it looked (the documents, scripts and CI files read) and each CI lint step it did not count as a chain with the condition that excludes it — the enumeration as a whole standing as this item's one anchor. Each line's form follows its outcome word: `clean` / `fixed-and-staged` / `detected` → the command as invoked, its source (document section, script definition or workflow `path:line` and step name) and the result line it produced; `not-run` → the literal `not-run` plus its reason class in parentheses (`ci-deferred` / `unexecuted`, Change Surface Rules > *`not-run` reason classes*), the reason, and the unexecuted chain's identity (its command and source, or the workflow `path:line` and step name), and a `ci-deferred` line additionally names the covering pull-request job (workflow `path:line` plus job/step name) and the trigger evidence that it runs for this pull request — the workflow's `on: pull_request` entry, either no `paths:` filter or one whose patterns match a staged file, and a job and step condition that admits this pull request; a line missing that evidence is `unexecuted`, not `ci-deferred`; `not-covered` → the chain and the file set it covers; `not-applicable` → that word alone, with the grounds naming where the committing role looked. A report citing one chain where the committing role identified several is malformed, not compliant.

   Anchors must be deterministically confirmable by the orchestrator against what produced them (`git show <SHA>` / the summary line read in the cited log / `git show <SHA>:<file>`); a test-pass anchor is confirmed by reading, not by re-running — the command is re-run only when the log is absent or does not carry the line, and the run is then `not-run` and run in place. Reports without an anchor are rejected, not interpreted. This item's line-number forms are for the report; a long-lived document (an ADR, a design or rule document, an issue body) cites a provision by document, section heading and quoted sentence instead.


---

<!-- From <autoflow-root>/docs/submodule-common-rules.md > Verification and Tools -->

## Verification and Tools

This section applies to every actor of a cycle — the orchestrator and every role.

**Local verification** (the instance of [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2 the phases cite). A change runs, locally and once, the tests the working AI judges it requires — at minimum every `automated` row this cycle authored or changed and every `delivery-check` row — and records each run's command, the log its output was written to, and the summary line read from that log (Reporting Format item 5). Judging which tests a change requires includes finding how the target's CI selects tests for a change — a changed-since selection, a path filter, a suite that only mounts or imports the changed module — in the target's CI configuration; what CI would select is guidance for that judgment, which stays the working AI's. Regression verification is HANDOFF's CI — whatever the target's CI runs. There is no local whole-tree run: none scheduled, none held in reserve.

**A run's evidence is the log it left; a report is confirmed by reading it, not by running it again**. The evidence of a test run is the log file its output was written to (Testing Standards item 7's `$LOG`), cited by path under `<attempt-dir>/issue-{N}-local/`; the summary line is the value read from that log, and the command is what produced it. What a run left is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence the claim cites: the summary line at the cited log path, the commit at the SHA, the file at the commit. Confirming is not re-executing. Every point that confirms a run record — the orchestrator's acceptance of a role-spawn report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Verify role-spawn claims*), AUDIT's test-first judgment, GATE:QUALITY's `Test coverage` and `Test quality`, the Evaluation AI's anchor resolution — reads the log. A command is re-run only where the evidence is absent or contradicts the record: a record with no log behind it, or a log that does not carry the recorded line, leaves the row `not-run`, and the row is run there and its record filled in (the paragraph below), not failed; at GATE:QUALITY a recorded line the log does not carry is additionally evidence authored without a run and caps the citing item. One ground stays the reproduction itself: re-opening a settled ledger decision on a verified error ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entries > the verified-error exception).

**How a test is run is the target's practice**. AutoFlow prescribes no test command to a target. The role that runs a test — the BUILD unit, or a helper it spawns — finds, in the target checkout it works in, how that target runs its tests: its documents (`CLAUDE.md`, a README, a contributing guide), its scripts (a package manifest's scripts, a Makefile, a wrapper script) and its workspace structure (a monorepo's per-package runner, a submodule's own tree), runs the tests it judges the change requires that way, and records the command, the log and the summary line read from it. What the command executes internally is the target's practice; AutoFlow reads the outcome and adjudicates nothing beyond it. A **cycle-layer asset** — a default `automated` row's test, a `delivery-check`, a `manual` checklist — lives in the attempt's cycle-layer store `<attempt-dir>/issue-{N}-local/`, under the record root outside the target's tree; it is authored as an executable file there and **invoked directly by its path**, never through a driver AutoFlow ships. The recorded command **names the asset's absolute path in the store** and is run from the target checkout's root: the asset finds the tree it checks from its working directory (`git rev-parse --show-toplevel`), never from its own location, which is outside every tree. The verification design's table declares the set, and each row's recorded run — its **run record**: command, log path and summary line — is the witness that its asset executed, the log being what the witness is read from. A cycle that wants one command for several assets writes that driver *as* a cycle-layer asset in the same store. Such an asset is never committed, and stays with the attempt's other records. A cycle asset writes its reproducible output — a build result, a copy of a source tree or of another original: an output re-creatable from inputs its record already names, such as a commit and a command — only under the store's reserved path `<attempt-dir>/issue-{N}-local/disposable/`, which cleanup deletes — the one path it deletes ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). Nothing a run record, an observation record or a cycle report cites ever goes there — not a log, a record file, the artifacts an observation left, or the asset itself, whose path the recorded command names — even when it is re-creatable. Whether an output is reproducible and uncited is the writer's judgment; where such an output goes is not. Only the store's top-level `disposable/` is reserved — a `disposable` deeper in the store is kept like any other path — and reproducible output left outside it is a deviation, kept with the rest of the store.

**The tools the work needs are found and used; what a tool lacks is requested from the operator**. Analysis, design, implementation and verification each find the tools they need — a browser to see a screen, a database to see data, a running server to see behavior, any other tool the problem calls for — in this environment (the session's tools, MCP servers included) and in the target (its documents, scripts and workspace structure). AutoFlow names no tool and no method to a target: which tool, what is started and how the result is looked at are the working AI's judgment in that target, recorded with its grounds. The orchestrator pursues securing them. A tool that is off, and whose starting procedure the target's documents or scripts carry (a dev server, a compose file, a seed), is started by that procedure, the procedure cited as the ground; one that must outlive a role spawn is started by the orchestrator ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Background execution is orchestrator-only*), and stopped once the cycle no longer needs it. A tool that cannot be used has something missing, and that is what is requested from the operator, situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Flow Control > *tool or referenced material → user*): the tool itself when this environment does not have it — an installation, enabling an MCP server or a browser extension — or, for a tool it has, what using it lacks — access, the purpose and permitted scope of the host or service it reaches, a credential, a permission setting. Providing any of these is outside the assigned scope ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); using a tool the environment already provides is not. A purpose or permitted scope is a project fact, asked with the request that the operator record it in the project's information ([`core.md`](<autoflow-root>/docs/core.md) > Project Information). The request names what is missing, not the output the tool would give: the output answers one cycle, and the next cycle that needs the same fact stops at the same point. A criterion falls back to a person's observation or a mock only when no tool can be secured: what is missing — the tool, or what using it lacks — was requested and the operator answers that it cannot be provided, or no tool exists that verifies the criterion (`<autoflow-root>/docs/units/design.md` > *Tools*). A material an acceptance criterion or the issue body points to — a design mockup, an asset, an external document — is opened, and the record of opening it is an input to analysis and to the verification design; an abbreviated example in the issue body does not stand in for it, and a material that cannot be opened reaches the operator the same way. A criterion verified with a tool is looked at with that tool once implemented: what was looked at, how, and the artifacts it left are its **observation record** under `<attempt-dir>/issue-{N}-local/` — for a screen, the rendered result compared against the referenced material — and, like a run's log, the record is what is read to confirm it, never a second observation. Where each phase does this: `<autoflow-root>/docs/units/analysis.md` (DIAGNOSE), `<autoflow-root>/docs/units/design.md` > *Tools* and `<autoflow-root>/docs/units/build.md` > What the build owes.

**A missing run is filled where it is found, not gated.** A row with no run record — or whose record has no log behind it, or a log that does not carry the recorded line — is `not-run`, never `passed`. Nothing blocks on the omission: it surfaces at the next point that reads the record — a spawn prompt that hands the record to the next role, GATE:QUALITY's `Test coverage` or `Commit conventions` — and is run there, by the role at that point, and its record filled in. An omission is not a FAIL and routes nowhere; a run that fails routes as the phase's own rules say.

**What a cycle leaves in the target's tree is not classified by AutoFlow**. A cycle adds no test file to the target repository by default: a verified criterion's evidence is its one-shot run's record. A test file the cycle does add is the exception, listed in the PR body with the reason it is kept and the CI job that executed it ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *CI* > *Added test files*), so the reviewer and the operator judge it against the target's own convention — AutoFlow does not certify retention by a token of its own. Which deployment-level checks a target keeps is the target's convention.

AutoFlow's own suite plane — the header contract, the selector and the runner — applies only where the target opted in (`.claude/autoflow.local.json` > `tests.suite_plane: true`).

---

<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->
