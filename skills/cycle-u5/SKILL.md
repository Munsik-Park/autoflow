---
name: cycle-u5
description: >-
  Run unit U5 (Completion evaluation — GATE:QUALITY) of an AutoFlow cycle
  alone, in a session of its own, with the parts of the core U5 uses. Use only
  when the operator starts a U5 session (/autoflow:cycle-u5 <N>).
argument-hint: "<issue-number>"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`: `<N>`) — unit U5, Completion evaluation (GATE:QUALITY), of issue #N's cycle alone: confirm from `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` that the cycle stands at U5's entry (otherwise report the situation and stop), run U5 from its entry to its exit transition, and end the session with the report the invoking prompt asks for.

**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that U5 uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: Development Lifecycle: An attempt goes on by one of two paths, PREFLIGHT cannot be skipped, An attempt's criteria are settled before DIAGNOSE; Development Lifecycle > Flow Control > Any unit: Push and PR creation; Development Lifecycle > Unit Document Loading Contract: U1 Preparation, U2 Analysis, U3 Design, U4 Build and verify, U6 Delivery, U7 Review; Development Lifecycle > Unit references: U1 Preparation, U2 Analysis, U3 Design, U4 Build and verify, U6 Delivery, U7 Review; Spawn Model: A unit agent's spawns inherit its gate class; Project Information: A project whose information names sub-repos; Team Structure: Build unit (U4), Functional-unit agents; AutoFlow State Tracking: verdict rule, The hook's state-file validator admits; Git Workflow — Rules: PR Wait Rule.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/completion-evaluation.md`; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/state-tracking.md`; `<autoflow-root>/docs/role-contracts.md` > Evaluation AI; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…").
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Rule Scope — Authority Rules and AI Judgment

This section is the single home of the four principles; every other document cites it rather than restating it.

1. **A rule exists only to bind authority and to prevent self-certification.** The push gate, the merge prohibition, the gate score thresholds, the rule that a change to acceptance-criterion content stands only as a recorded `[ac-decision]` ledger entry, and the auto-resolution attempt caps are rules of this kind. Each binds the path that carries it — the full cycle every one of them, the abbreviated path the ones its definition names (`<autoflow-root>/docs/abbreviated-path.md` > *The checks that bind it*).
2. **Which route to take, which tests to run, and how far the work reaches are the working AI's judgment**, and the AI records the grounds for each judgment in the report or ledger entry the phase already produces.
3. **A judgment can be wrong.** A wrong judgment is caught by CI, by the external reviewer, and, in the full cycle, by the gates. When the AI is not confident, or the choice is not its own to make, it asks the advisor, whose answer is recorded and applied; the operator is asked only when a call is blocked at the harness level (`<autoflow-root>/docs/role-contracts.md` > Advisor).
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

What each phase does, and what else a unit's body carries: the phase list and *Unit references* below, and *Context Injection*.

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → immediate block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above, and the unit documents and rubrics apply them. Who enforces what: the hook (`<autoflow-root>/hooks/check-autoflow-gate.sh`) computes PASS from the recorded `scores` — for the score-gated role spawns, `git push` and `gh pr create` — and denies `git push` / `gh pr create` while the `audit` or `gate_quality` record carries `remedy_class`; it counts no FAIL. The FAIL and re-entry counts are the orchestrator's own accounting, and the REVIEW auto-resolution count is `<autoflow-root>/scripts/handoff/review-gate.sh`'s (exit `11` at 7).

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

Seven functional units carry the phases (`ADR-0025` D1, `ADR-0033`). A unit is the unit of prescription — its goal, artifact contract, verification and loop cap — and each has one document (*Unit Document Loading Contract* above). The phase and gate names stay: they are the identifiers the state keys, the ledger headings, the spawn-policy keys and the hook messages carry.

```
U5 Completion eval.    GATE:QUALITY    — Evaluation AI (10 items × 10 points); the gate is the unit
```

**Flow Control** — the transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in its **unit document**, not in this core file. This file retains what crosses a unit's boundary: the cross-unit invariants and authority rules, the router (the unit and phase list and the Flow Control table above, whose per-unit rows are each unit document's `## Transitions` section), the regression / escalation caps (above), the Execution Principles, and the state rules (below; the state file's schema and the hook gates are `<autoflow-root>/docs/state-tracking.md`). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

The rubric of every gate — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the unit's: it lives in `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics*, and the unit document routes the gate's result.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in `<autoflow-root>/docs/evaluation-system.md`; how the orchestrator spawns and prompts the evaluator is `<autoflow-root>/docs/role-contracts.md` > Evaluation AI.

### Unit references

| Unit | Also on entry |
|------|------|
| U5 Completion evaluation | change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules |

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
- **The route is the AI's judgment; the independent checks are not** (Rule Scope, principles 1–3): which work phases a change passes through and how deep each goes — DIAGNOSE's analysis, ARCHITECT's design, BUILD's execution, INTEGRATE's bundle — is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What the full cycle never skips is an independent check, an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds (GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY), the `git push` / `gh pr create` gate, CI (its result as it is: green, or, where the target's CI does not run for the pull request, that recorded on it — never read as green), the aggregated review and its verdict, and the auto-resolution attempt caps. The hook keeps the two apart structurally: a role spawn is admitted only on the recorded PASS of the gate that precedes it, so a phase whose artifact a gate scores runs at least far enough to produce that artifact, and a skipped phase never skips a gate. The abbreviated path's checks are its definition's (`<autoflow-root>/docs/abbreviated-path.md` > *The checks that bind it*).
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

**[MUST]** Every role is an **anonymous direct spawn**. No role holds a lifetime spanning phases or cycles: each phase spawns its role fresh, hands it `<attempt-dir>/issue-{N}-*.md` paths, and takes its result as the spawn's return value. Each role's mode and per-call scope are `<autoflow-root>/docs/role-contracts.md` > Spawn mode by role lifetime.

**[MUST]** A lower-tier gate's PASS, or a lower-tier role spawn's phase-exit claim, materially contradicted within the same cycle reverts that phase to the higher tier, updating `.claude/autoflow/spawn-policy.json` in the same commit; the contradicting signals and their evidence anchor are `<autoflow-root>/docs/role-contracts.md` > Model tier revert, which a change to the per-phase assignment also follows.

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. A role's guidance — the parts of this core it uses and the documents its work follows — is carried by the carrier the role starts with, from the start: a session's command body, a subagent's agent definition, a reviewer's rule file, which its wrapper's prompt carries. `<autoflow-root>/scripts/skills/gen-skill-bodies.sh` generates each carrier from the guidance's homes — a command body's core parts by `<autoflow-root>/scripts/skills/core-units.tsv`, and every carrier's documents, an agent definition's core parts with them, by `<autoflow-root>/scripts/skills/role-docs.tsv` — so a role's first run and every re-run carry the same guidance. `<autoflow-root>/docs/INDEX.md` is never injected wholesale as common context to every spawn; it routes the usage documents beyond a role's guidance.

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
### Advisor — contract: `<autoflow-root>/docs/role-contracts.md` > Advisor

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

<!-- From <autoflow-root>/docs/units/completion-evaluation.md -->

# U5 Completion evaluation — GATE:QUALITY

> Unit document for U5. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

GATE:QUALITY is functional unit U5 Completion evaluation
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1). U5 has no unit agent: the
gate is the unit, and its work is the evaluator's. This file states the unit's four items (D2) and the
rules the orchestrator applies to the result — the FAIL routing, and, for every rubric-scored gate,
the triage of a PASS report's recommendations. The rubric the evaluator scores on is
[`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:QUALITY.

- **Goal**: the change the cycle built, judged against the acceptance criteria, the design and the
  build's own records before it is delivered — complete, correct, verified, within the cycle's
  scope, and committed and documented as the rules ask.
- **Artifact contract**: the evaluation report in the shape
  [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format defines — ten scores
  with their reasons, `fail_hypothesis`, `remedy_class` on every failed item, `refine_observations`,
  `recommendations`, and `rescore` on a re-entry — whose `scores` the orchestrator records verbatim
  as `phases.gate_quality`.
- **Verification**: the evaluator's independence — a fresh Evaluation AI (`autoflow-evaluator`,
  the model `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-quality` names) for every
  evaluation, never the author of what it scores, read-only
  ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Evaluation AI); the orchestrator's acceptance of its
  report, which rejects and re-spawns a report missing what the contract requires; and the hook,
  which computes PASS from the recorded scores before it admits `git push` / `gh pr create`.
  Beyond U5, CI and the review verify the delivered change (ADR-0025 D4).
- **Loop cap**: a FAIL re-enters by `remedy_class` (*FAIL routing* below), max 3× — the cap counts
  FAILs, not the distance re-entered; a recommendation attempt is not a FAIL and counts on its own
  window, max 7 (*Recommendation triage* below).
- **Result owed**: the report, returned as the spawn's report, with its scores recorded; on a PASS
  with no attempt open, the cycle moves to DELIVER.

**Evaluator**: a fresh-spawned Evaluation AI scores the change on the rubric of
[`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:QUALITY — its input, its ten
items, its known blind-spot checks and its re-entry re-score. Its agent definition carries that
document.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| GATE:QUALITY → DELIVER | completion evaluation PASS + its recommendations triaged (no attempt open) |
| GATE:QUALITY (FAIL) → doc commit / BUILD / ARCHITECT | FAIL routed by each failed item's `remedy_class` (mixed → farthest: `design` > `impl` > `test` > `doc` — `<autoflow-root>/scripts/gate/remedy-route.sh route`): `doc` → orchestrator doc commit → GATE:QUALITY re-score; `test` / `impl` → a BUILD unit re-run with the failed items → AUDIT; `design` → ARCHITECT (consumes the ARCHITECT re-entry counter). The doc route's sweep record and the re-score scope: `<autoflow-root>/docs/units/completion-evaluation.md` > *FAIL routing* / *Re-entry re-score* |
| GATE:QUALITY (FAIL) → advisor | any failed item carries `remedy_class: operator` (the evaluator could not classify it with confidence) → the advisor's answer fixes the class and the cycle re-enters on that class's route. A FAIL report missing `remedy_class` on a failed item is rejected and the evaluator re-spawned (same disposition as a missing `fail_hypothesis`) |

## Verification result

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → block) → *Recommendation triage* (below) → DELIVER.
- **FAIL** → routed by `remedy_class` (below; max 3× — the cap counts FAILs, not the distance re-entered).

## Recommendation triage

A PASS report's `recommendations` are findings the evaluator recorded without scoring the item down.
They are triaged by **the procedure the
reviewer's findings already take** — REVIEW's review-triage classification, the weighing of whether a finding holds, route, pause criteria, `Low`
judgment, ledger record and attempt cap — after the PASS of every rubric-scored gate
(GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY) and before the transition it opens.
The one thing added is the evaluator's output contract for `recommendations`
([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format): each item names its
subject — a `path:line` of the evaluated artifact at the evaluated commit, or a section of the evaluated artifact (a design document, the DIAGNOSE analysis report) — its severity in the reviewer's vocabulary, and — on `Medium` and above — its `remedy_class`.
No separate disposition system exists for gate recommendations.

| Review triage | Gate recommendation |
|---|---|
| Classification: the reviewer's severity level (`<autoflow-root>/docs/review/review.md` > Severity) | the evaluator's, per item, on the same levels |
| `remedy_class` on every `Medium`+ finding, by the aggregator — *does clearing this discard or change a decision the design settled?* | the evaluator's, on every `Medium`+ recommendation, by the same question — the class it already puts on a failed item (*FAIL routing* below), and the same classifying authority |
| Route: `<autoflow-root>/scripts/gate/remedy-route.sh route <class>...` | as a FAIL re-enters — to the phase that owns the change: at a gate after execution the same script; at a gate before execution the gate's own FAIL route (below) |
| Pause criteria (a)–(c) | the same three, read for a gate (below) |
| `Low`: the orchestrator's judgment — fix now, or defer with a one-line PR note | the same, its grounds the two questions of [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope judgment*; a `Low` fixed now is an attempt like a `Medium`+, and a below-layer `Low` at a gate before execution is deferred to BUILD (below) |
| Verification of the fix: the next review round (*Reviewer review*) | the recommending gate's existing narrowed re-score (*Re-entry re-score*; [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:PLAN > *Re-entry re-score*, > AUDIT > *Review-response re-score*; at GATE:HYPOTHESIS the same form over the amended artifact) |
| Record: a `[review-autofix]` ledger entry per attempt; cap 7 | a `[gate-autofix]` ledger entry per attempt, in the same grammar; cap 7 on its own window |

- **No aggregator.** The orchestrator reads the evaluator's `recommendations` list
  directly. It is therefore the orchestrator that weighs whether each item holds ([U7 Review](<autoflow-root>/docs/units/review.md) > *Whether a
  finding holds*), and the recommending gate's re-score that judges a rebuttal. A
  `Medium`+ item with no `remedy_class`, or any item missing a field of that contract (subject, item,
  severity, finding), is a report defect:
  reject and re-spawn the evaluator, as for a missing `fail_hypothesis`.
- **A criterion defect is decided, at any severity.** A recommendation that records an
  acceptance criterion defective — the evaluator records one as a fact, the criterion as its subject
  ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format) — or one whose fix
  could keep a criterion's letter only by adding a rule the criterion did not state
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), is neither
  routed, separated nor deferred as a `Low`: the orchestrator decides the change — putting it to the advisor only where the
  recommendation's grounds do not settle it or it is not confident ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor) — and the
  decision is recorded as its `[ac-decision]` entries ([U3 Design](<autoflow-root>/docs/units/design.md) > *Report routing* > *An acceptance-criterion change raised
  later in the cycle*).
- **`Medium` and above → do not transition.** Route as a FAIL re-enters — to the phase that owns
  the change:
  - **A gate after execution** — AUDIT and GATE:QUALITY — routes by `<autoflow-root>/scripts/gate/remedy-route.sh
    route` over the `Medium`+ recommendations' classes (mixed → farthest; `operator` anywhere stops routing and goes to the advisor)
    and re-enters where it prints (`DOC_COMMIT` / `BUILD` / `ARCHITECT`, exactly as at
    *FAIL routing*, the `doc` route's sweep record included); the routed work flows forward, and the
    recommending gate re-scores on the narrowed input its re-entry already uses.
  - **A gate before execution** — GATE:HYPOTHESIS and GATE:PLAN — does not call the script: every `Medium`+ recommendation is resolved on the artifact the gate scores,
    by the gate's own FAIL route narrowed to the item, and re-scored by the same form: at GATE:PLAN an ARCHITECT unit re-run naming the
    recommendation ([U3 Design](<autoflow-root>/docs/units/design.md) > *Re-entry*), then GATE:PLAN's *Re-entry re-score* ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:PLAN) over the
    delta; at GATE:HYPOTHESIS a U2 unit re-run naming the recommendation amends the analysis
    report ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > *Re-entry*) — a problem the confirmed cause carries enters its
    `## Scope judgments` — then the same form re-scores. The class such a recommendation carries (`doc` / `test` / `impl` / `design`) names the
    change the problem will need once the design or analysis carries it; it rides on the amended
    artifact as the ground ARCHITECT or BUILD then reads, and it never sends the cycle forward
    past the gate unre-scored. A fact below the decision layer ([U3 Design](<autoflow-root>/docs/units/design.md) > *Output artifacts*
    item 1) is not a defect of the artifact these gates score, so the evaluator records it at `Low`, and the orchestrator's `Low` judgment **defers**
    it: to the build — recorded in the gate's verdict entry as deferred to BUILD, carried
    in the BUILD spawn prompt, and judged with that work at GATE:QUALITY — or to the known-gaps
    line. It is never a fix-now attempt: it takes no re-score by this gate, no `[gate-autofix]` entry
    and no `remedy_class` in state.
  - **Not directly related** — none of question 1's three conditions holds — is separated as *Scope
    judgment*'s table says, recorded with its ground and a separate issue the follow-up path. A
    `Medium`+ recommendation that **is** directly related is fixed on its route or put to the
    advisor; the orchestrator never separates one on its own judgment (advisor criterion (b)).
- **Put to the advisor** (a request written situation-first — [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; the cycle does not
  pause) when the attempt hits any of: (a) the fix needs a contract or
  acceptance-criterion change the orchestrator cannot settle on the grounds at hand (the criterion-defect bullet above);
  (b) the fix direction is ambiguous, or the orchestrator judges a directly related recommendation
  undesirable to fix in this cycle (question 2) and would separate it; (c) the re-score
  dispositions the previous attempt's finding `remains` after its fix (`rescore.prior_findings`)
  — the same complaint answered twice — and the re-score's grounds do not settle the next fix. The advisor's `A` entry
  selects re-entry.
- **`Low`** → the orchestrator's judgment, on the two questions, recorded with its grounds in the
  gate's verdict entry: fix now, or defer — to the PR body's known-gaps line
  ([`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) > *한계와 known gaps*), or, for a `Low` below the decision
  layer at a gate before execution, to the build at BUILD (above). A `Low`
  fixed now **enters the procedure above as an attempt from that point**: the orchestrator judges
  its `remedy_class` (the evaluator tags none on a `Low`), and the fix is routed, recorded as a
  `[gate-autofix]` entry, marked in `phases.<gate>.remedy_class`, re-scored by the same gate and
  counted on the same window exactly as a `Medium`+ attempt. A `Low` on a target
  comment's divergence or disallowed content keeps its own handling — the orchestrator's direct
  commit, or left (*Code comments in a target* below).
- **Record.** Each attempt — a `Medium`+ recommendation, or a `Low` the orchestrator fixes now: a route that re-enters a phase and awaits the gate's re-score — is one ledger entry headed
  `## O<n> — <title> (cycle <C>, <GATE>) [gate-autofix]`, naming each recommendation it routes
  (subject, severity, class), the route, and the grounds — appended before the routed work starts.
  The marker sits at the end of the heading like `[review-autofix]`, and the two are distinct:
  neither cap's count reads the other's marker. While an attempt is open the orchestrator records
  the routed class as `phases.<gate>.remedy_class` in the state file, as it does for a FAIL
  ([`core.md`](<autoflow-root>/docs/core.md) > AutoFlow State Tracking > *Remedy class recording*), and removes it
  once the re-score PASSes and no attempt is left open — a `Medium`+ the re-score itself raises is a
  new attempt; the hook denies `git push` / `gh pr create` while it is present on `audit` or
  `gate_quality`.
  A resume reads the same field ([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *Resume*).
- **Attempt cap = 7**: the consecutive `[gate-autofix]` entries this cycle since the last user
  re-entry decision (an entry whose heading ends in `[reentry-decision]`). When the triage after the 7th such attempt would open
  another — a `Medium`+ still open, or a `Low` the orchestrator would fix now — it pauses for the
  user instead; the user's decision resets the window. A re-score's own recommendations enter this
  triage on the same window, so a run of `Low`-only re-scores each fixed now counts like a run of
  `Medium`+ fixes. The cap bounds attempts, and reaching it is
  never a separation reason — the disposition at the cap is the operator's.
- **Not a FAIL.** An attempt consumes no FAIL cap; a re-score that FAILs is an ordinary FAIL, routed
  and counted by the gate's own rule, and a route through ARCHITECT consumes the ARCHITECT re-entry
  counter. The transition opens when the PASS stands and no attempt is open — every `Medium`+
  fixed and re-scored clean, withdrawn by the re-score on its rebuttal, separated as not directly
  related, or decided by the advisor or the operator, and any
  `Low` fixed now re-scored.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) >
Documentation Policy). Its search terms:

```
git grep -n -i -E 'recommendation triage|recommendations triaged|recommendation attempt|gate-autofix|attempt (is left )?open|no attempt|fixed now|fix-now|fix now|open re-entry|reviewer-finding procedure|recommendations.{0,40}(Medium|remedy_class)'
```

## FAIL routing (`remedy_class`)

The evaluator tags **every failed item** (score < 7) with a
`remedy_class` — the kind of change that clears it — and the orchestrator re-enters the cycle at the
nearest phase that can make that change. The evaluator is the classifying authority: the BUILD unit does not
re-classify.

| `remedy_class` | Meaning | Re-entry |
|---|---|---|
| `doc` | the item clears by editing documentation with no behavior change — in this repository comment text too; a target comment's divergence or disallowed content is never a failed item, while a defect a comment carries on its own ground is classed like any other (*Code comments in a target* below) | orchestrator doc commit → the local run the doc diff requires → GATE:QUALITY re-score |
| `test` | the item clears by changing test assets | a BUILD unit re-run with the failed items → AUDIT ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *Re-entry*) |
| `impl` | the item clears by changing implementation | the same BUILD re-run |
| `design` | the item clears only by revisiting the agreed design | ARCHITECT (consumes the ARCHITECT re-entry counter, as the BUILD design-contradiction row does) |
| `operator` | the evaluator cannot classify with confidence | the advisor's answer fixes the class ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor); the cycle re-enters on that class's route |

- **Default class per item** — the evaluator's starting point, overridable with a stated reason:
  `Doc updates` → `doc`; `Test coverage`, `Test quality` → `test`; `Fit` → `design`; every other
  item → `impl` (`<autoflow-root>/scripts/gate/remedy-route.sh default-class <item>`). A `Doc updates` cap caused
  by text that executes — a prompt string inside a workflow script, a hook message — is `impl`, not
  `doc`. When the evaluator is not confident, it writes `operator` rather than guessing: an
  unclassifiable item is never carried along a route chosen for its neighbours.
- **Mixed classes go to the farthest point**: `design` > `impl` > `test` > `doc`; `operator` anywhere
  stops routing and goes to the advisor. `<autoflow-root>/scripts/gate/remedy-route.sh route <class>...` is the single owner of this rule; the
  orchestrator records the routed class as `phases.gate_quality.remedy_class` in the state file
  ([`core.md`](<autoflow-root>/docs/core.md) > AutoFlow State Tracking > Remedy class recording).
- **[MUST]** A FAIL report with a failed item lacking `remedy_class` is a contract violation: reject
  it and re-spawn a fresh Evaluation AI, exactly as for a missing `fail_hypothesis`
  ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Remedy class*).

### `doc` re-entry — class-level remedy

The `doc` route's remedy must be **class-level, not site-level**. The fix anchors on a **repo-wide sweep
for the pattern the evaluator named**, not on the list of sites it happened to find. The sweep
enumerates; **which hits the remedy fixes is the orchestrator's judgment**, recorded with its grounds
in the sweep record (`<autoflow-root>/docs/core.md` > Rule Scope, principle 2).

1. Write `<attempt-dir>/issue-{N}-remedy-sweep.md` with two sections: `## Command` — the repo-wide
   command(s) that enumerate the pattern — and `## Output` — their output, the full hit list. The
   remedy fixes every hit in a normative document ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:QUALITY > *Known blind-spot checks* > reference integrity —
   the one definition of the boundary) and records, beside the two sections, the scope judgment for
   the rest: a hit in a historical record is fixed only where the evaluator's recorded judgment
   named it as misleading, and is otherwise recorded as exempt with the ground (the record is
   followed by no one). The judgment and its grounds are
   prose in the same file; the hook reads only the two sections.
2. Commit the doc remedy (orchestrator authority: [`core.md`](<autoflow-root>/docs/core.md) > Team Structure /
   Commit Ownership); its lint outcome is added as that commit's rows in the build report's `## Lint`
   table ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > Build report).
   **The hook denies `git commit` while `remedy_class` is `doc` until the sweep
   record exists with both sections non-empty** — it checks the record file, never the wording of an
   instruction. On a second `doc` FAIL of the same class, the orchestrator re-examines its scope
   judgment against the grounds the new report records — the previously flagged defect that
   `rescore.prior_findings` marks `remains`, or a new finding it marks blocking — and records the
   revised judgment in the sweep record; a wider predicate is one possible outcome, not a rule.
   No standing doc-phrase suite is kept.
3. Run, once, the tests the doc diff requires ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *Local
   verification*) — often none for a doc-only diff; on an opted-in target the selector names any
   suite whose `ci-subject` reaches an edited doc — and record the command and its summary line,
   with the log the run wrote.
4. Re-score (below).

## Re-entry re-score

After any class's re-entry, a fresh evaluator re-scores on the narrowed input
[`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:QUALITY > *Re-entry re-score*
defines; the state file still receives all ten scores, inherited ones copied verbatim from the cited
report.

## Code comments in a target

A comment in a target's code that diverges from its code, or that carries what a comment does not
carry, never routes the cycle.

- **Severity.** A comment that diverges from its code, or that carries what a comment does not carry
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Code comments*),
  is a `Low` finding. It never counts toward the review's `Medium`+ verdict
  (`<autoflow-root>/docs/review/review.md`); the evaluator records it in `recommendations` and lowers no item's score for
  it ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Code comments in a target*). It is
  therefore never a failed item, never the cause of a FAIL on the average, carries no `remedy_class`, and is not a `doc` item. Only that
  finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or
  personal data, for example — takes the severity and the route its impact sets, as any finding does.
- **Fix — the orchestrator's direct commit.** Whether a comment surfaced by this gate's
  `recommendations`, the build report's `## Comment check` or the reviewer's `Low` findings (REVIEW
  review triage) is fixed is the orchestrator's judgment, recorded with its grounds in the ledger
  ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2). A fix is one orchestrator commit that
  deletes comment lines or corrects their sentences and changes nothing else, and it ends there: no
  sweep record, no re-entry, no re-score, and no review round. The commit still runs the lint chain over its staged files
  ([`core.md`](<autoflow-root>/docs/core.md) > Commit Rules); one made after HANDOFF's push is pushed, and the CI
  confirmation runs on the new head. A comment whose correct wording is uncertain is deleted, not
  rewritten (*Code comments* > *Changing commented code*). A fix that changes any line other than a
  comment, or that removes a defect of its own ground (above), is not this route.
- **Directives.** A line a tool reads to change its behavior is code even in comment syntax, and
  which lines those are is the working AI's judgment in that target, with no list kept (*Code
  comments* > *Directives are code*). A defect in one takes the severity and the route of the
  behavior it changes.
- **This repository is excluded.** Here a comment takes the reviewer's severity as judged, the
  `doc` class, and the `doc` re-entry's sweep record.
- *Secondary (multi-repo):* a comment in a sub-repo is outside the orchestrator's scope
  ([`core.md`](<autoflow-root>/docs/core.md) > Cross-Project Boundary Rules); the build unit of that scope makes
  the same single commit on the same terms.

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

<!-- From <autoflow-root>/docs/decision-ledger.md -->

# Decision Ledger

The per-attempt decision ledger, `<attempt-dir>/issue-{N}-ledger.md`: what an entry records, how it is
identified, and the grammar of the entries a decision point produces — the advisor's first judgment
and the operator's override. The ledger's standing constraints —
append-only, no re-litigation without a new verified fact, host ownership, and identifier
allocation — are [`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger.

## Entries

- Each entry records: the decision (one line), its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence), its **authority** (what settled it — `orchestrator decision`, `advisor decision`, `GATE:PLAN PASS (avg 8.2)`, `operator decision`), and the cycle/phase.
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the re-opening is **judged by the decision's original authority** — a gate verdict by a fresh Evaluation AI re-scoring that item, an ARCHITECT design decision — recorded in the feature design, not the ledger — by a U3 Design unit re-run naming its heading there (an ARCHITECT re-entry, consuming that counter, unless the design has not yet reached GATE:PLAN), an advisor decision by a fresh advisor, an operator decision by the operator — and when that authority cannot say with confidence that the error changes the decision, it asks the advisor ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3); (3) the correction records the reproducing command and its summary line in the grounds form above and names what it supersedes — for a ledger entry, in the superseding entry's grounds, by the superseded entry's identifier; for a feature-design decision, in the U3 re-run's delta item, as `supersedes <heading>` ([`units/design.md`](<autoflow-root>/docs/units/design.md) > *Re-entry*). A change of preference or a re-interpretation of the same material is not an error and stays barred.

**Writers**. The advisor appends its answer to a decision point under the authority `advisor decision`, and it alone writes that authority (*Advisor decisions and operator overrides* below); the ARCHITECT design unit and the BUILD unit append nothing — their decisions and records are their own artifacts ([`units/design.md`](<autoflow-root>/docs/units/design.md), [`units/build.md`](<autoflow-root>/docs/units/build.md) > Build report); the orchestrator appends each gate's verdict after the gate, each auto-resolution attempt and rebuttal round at a gate or at REVIEW, its own decision at a point it settles without the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Decision points and harness-level blocks*; an acceptance-criterion change: *Acceptance-criterion decisions* below), an operator override of an advisor decision when the operator gives one, and — before the issue's first cycle, by the criterion review session taking the orchestrator's part — the `[criterion-ready]` entry recording the review's settled decisions (*Criterion-readiness confirmations* below).

## Entry identifier

A settled-decision entry is headed `## <ID> — <title> (cycle <C>, <PHASE>)`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only. An auto-triggered review-response entry carries its REVIEW marker in the same grammar: `## O<n> — <title> (cycle <C>, REVIEW) [review-autofix]` — the marker stays at the end of the heading. The operator's decision to continue after an attempt-cap pause is an `O` entry under `operator decision` whose heading ends in `[reentry-decision]`; the attempt count restarts after it ([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Routing* > Attempt cap). An entry written before the attempt's state file — in its criterion review stage, the criterion-readiness confirmation included — carries `cycle 0`. Record entries (`preflight-plugin`, `preflight-local-checks`, `preflight-review-config` — [`units/preparation.md`](<autoflow-root>/docs/units/preparation.md)) are level-3 headings and carry no identifier.

| Writer | Namespace |
|---|---|
| Orchestrator | `O` |
| Advisor | `A` |
| Pre-protocol legacy entries (readable, never issued) | `E` |
| Legacy facilitator-delegate entries (readable, never issued) | `F` |

This table is the mapping's only documentary home; other documents cite it rather than restate it.

- **Allocation**. `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> <NS>` issues every identifier, called immediately before that entry's own append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). It takes the next serial above both the highest in the file and the highest already reserved, and reserves it before printing it — an empty directory `issue-{N}-ledger.ids/<ID>` beside the ledger, which one caller alone can create. Writers of one namespace that call it concurrently — two advisors spawned together, each allocating before the other has appended — therefore receive distinct identifiers. A reserved identifier that is never appended (the append denied, the writer stopped) leaves a gap in the serial; a gap is not a defect, and `check` does not report one. A writer whose append must be retried keeps the identifier it was issued.
- **Identifier collision**. Two entries can share an identifier — entries written before this protocol or before `next` reserved what it issued, or a heading appended in error; they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair. A reader that resolves a supersession by identifier (`<autoflow-root>/scripts/gate/security-checklist.sh`) displaces every earlier entry it counts that the named identifier matches — never an operator entry by an advisor's — so a re-deriving entry written by the colliding entries' own authority is the one that stands.

## Decision-point entries

**Advisor decisions and operator overrides.** A decision point is answered first by the advisor
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor): an `A<n>` entry under the authority
`advisor decision`, carrying a `- Record:` line to the advisor's answer file
(`<attempt-dir>/issue-{N}-advisor-<ID>.md`) and the marker and fields its kind requires below. Only the
advisor writes that authority or an `A` heading, and the advisor never writes `operator decision` or
an `O` / `F` / `E` heading — the gate hook denies both
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*). The operator may
override an advisor's entry: the orchestrator — the main session, the
only writer the gate hook admits for an `O` entry or the `operator decision` authority — records the
override as an `O<n>` entry under the authority `operator decision`, with the same marker and fields
and an `- Overrides: A<n>` line. An override supersedes the advisor's entry without a new verified
fact — the operator's authority is the ground, the one supersession the no-re-litigation rule admits
besides the verified-error exception; an advisor never supersedes an operator entry.

**Replacement is explicit.** An entry is never edited to change a decision — the gate hook keeps the
ledger append-only ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*). A later
entry replaces an earlier one only by naming it: `- Supersedes: <id>` (the same authority, on a new
verified fact or the verified-error exception) or `- Overrides: A<n>` (the operator over the
advisor). Two standing entries on the same subject whose conclusions disagree, with neither naming
the other, are a **conflict**: nothing is settled by recency, and the conflict is resolved by a new
entry — the advisor's, naming the entries it resolves, unless an operator entry is among them, which
only the operator replaces. The same conclusion recorded twice is not a conflict. An identifier two entries
already share is read as *Identifier collision* above says, never repaired by editing either entry.

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is
never the design's or a unit's to apply: the **orchestrator** decides it first, on the grounds the
raising report or recommendation carries, and puts it to the **advisor** only where those grounds
do not settle it or it is not confident ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*); the **operator** may override. The change stands only
as the entries below ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1); choosing how a
criterion is *verified* is the design's, provided the row states its reason, which the
reviewers then judge at REVIEW (the three-tier guard — [`units/design.md`](<autoflow-root>/docs/units/design.md) >
*Report routing*). A content change reaches the orchestrator from wherever it surfaces: the ARCHITECT design
unit's `## Decision requests` section, before GATE:PLAN; a problem the BUILD unit meets and raises in
its report; or a gate recommendation that records a criterion defect, or whose
triage hits the acceptance-criterion pause criterion ([`units/design.md`](<autoflow-root>/docs/units/design.md) > *Report routing*,
[`units/completion-evaluation.md`](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*). The change excludes, revises or splits a criterion, or adds one. The
decision is recorded as one entry per decided AC, in the same trailing-marker grammar:
the heading `## O<n> — <title> (cycle <C>, <PHASE>) [ac-decision]` (the advisor's: `## A<n> — …`; an override: `## O<n> — …`),
`<PHASE>` being the phase the change surfaced in, followed by the entry's own `- AC: <ac id>` line (for
an added criterion, the id it takes), a `- Disposition:` line valued `excluded` / `revised` / `split` /
`added`, and the ordinary Decision / Grounds / Authority lines with the authority value
`orchestrator decision` (the advisor's: `advisor decision`; an override: `operator decision`).

**A criterion can be wrong; from ARCHITECT on, the work tests it**. DIAGNOSE takes the criteria as written — it
analyzes the problem as the issue states it and runs no test of the criteria of its own. That says how
DIAGNOSE works, not when a defect may be raised: a defect observed as a fact is raised wherever it is
observed, a gate before ARCHITECT included. From ARCHITECT on — the design, the build
and every gate after them — a criterion is a hypothesis the work tests, not a truth the
work is bent to fit: wherever the work and a criterion disagree, *is the criterion wrong?* is one of the
answers the judgment weighs, beside *how is it satisfied?* A criterion is **defective** when (a) a fact
it presumes does not hold — a device, a phase or a state it takes for granted; or (b) the scope it draws does not fit the problem — too
narrow, when the same cause reaches past what it names, and the question is then whether the issue saw
the problem as local and the approach itself must change, not only whether to include the rest (a
widening: `revised` / `added`); or too wide, when it binds in a problem separate from this issue (a
split: `split` / `excluded`). A defect so judged is raised for a decision — the orchestrator's first, the advisor's where it cannot settle it;
it is never resolved by keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the unit documents and agent definitions cite it.

The marker sits at the **end** of the heading. The authority over an acceptance criterion maps to
these literals and nothing else: the entry's authority **value** is `advisor decision` on an `A<n>`
entry, or `orchestrator decision` or `operator decision` on an `O<n>` entry, and the entry is **located** by the `[ac-decision]`
heading marker. The two gate backstops key on the marker. When the entries for one AC disagree, an `operator decision` entry wins. When the
disposition is `revised`, `split` or `added`, the analysis report's acceptance-criterion table
(`<attempt-dir>/issue-{N}-analysis.md`) is edited to
match before re-entry, and this entry is the record of who authorized the edit. An `added` entry
covers no difference in either gate backstop: the criterion it adds is owed its verification-design
row and its discharging site like any other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and a cycle's AUDIT reads it as of the cycle's base commit ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). Changing it inside a cycle — the file, or the
declaration that points at it — is never the cycle's own to accept: the **advisor** decides first
and the **operator** may override. When `<autoflow-root>/scripts/gate/security-checklist.sh status` reports the
change at AUDIT entry, the orchestrator spawns the advisor, and the answer is recorded in the same
trailing-marker grammar: the heading `## A<n> — <title> (cycle <C>, AUDIT) [checklist-decision]` (an
override: `## O<n> — …`), followed by a `- Checklist:` line (the declared path at HEAD, or `none` when
the declaration is dropped), a `- Blob:` line (the `git rev-parse HEAD:<path>` of the approved
version, or `none`), a `- Disposition:` line valued `accepted` / `rejected`, and the ordinary
Decision / Grounds / Authority lines with the authority value `advisor decision` (an override:
`operator decision`), plus the `- Supersedes:` / `- Overrides:` line when it replaces an entry. The
script counts an entry only when its Decision and Grounds lines are non-empty, its Disposition is
`accepted` or `rejected`, and its Authority matches its namespace (`advisor decision` on `A<n>`,
`operator decision` on `O<n>`), and only while its Checklist and Blob equal HEAD's, so a later edit to
the checklist is a new change owed its own decision. An entry stands unless a later counted entry
replaces it by name (*Replacement is explicit* above; an advisor entry never replaces an operator
entry). The standing entries decide only when they agree: all `accepted` → the change is covered; all
`rejected` → it is not, and the change is reverted before AUDIT; both → a conflict, reported as
`conflict=<ids>` on an undecided (exit `3`) record and resolved by a new entry, never by recency.

**Criterion-readiness confirmations** (`[criterion-ready]`). In the first stage of an attempt's
cycle, before its state file, the attempt's own review checks the issue's acceptance criteria and
the decisions the review settles are recorded ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). The review session
judges and records its dispositions, a point it cannot settle is decided by the advisor as at any
decision point — the answer is itself the decision and does not wait on the operator's review —
and the operator overrides either when they choose. Once every decision is settled, the review
session records them in one entry, with no operator confirmation asked: the entry is the record of
the decisions made under the policy the operator set for the review, under the authority
`operator decision` — the same authority over acceptance content as an override
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1). It is recorded in the trailing-marker grammar: the heading
`## O<n> — <title> (cycle 0, CRITERION-REVIEW) [criterion-ready]`, followed by a `- Decision:`
line, a `- Record:` line (the review record's file name in the attempt's own record directory, by name
alone), an
`- Issue body sha256:` line (the value `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints
for the body the entry records), and the ordinary Grounds and Authority lines with the authority value
`operator decision`. No `A<n>` entry carries the marker, and an attempt that has a state file takes
none. `<autoflow-root>/scripts/preflight/criterion-ready.sh
status` reads the **last** entry carrying the marker in the attempt's own ledger — never another
attempt's — and counts it only when it is an `O` entry
under `operator decision`, its record exists and its sha256 equals the issue body's now; an edit to
the body is confirmed by a new entry, never by editing this one. The entry is the criterion review
stage's exit, and PREFLIGHT reads that status on the attempt's start
([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*, Stop conditions >
*Criterion readiness*); nothing after the state file reads the entry, and a criterion change from
then on stays an `[ac-decision]`.

<!-- From <autoflow-root>/docs/issue-proposal.md -->

# Issue Proposal — Draft Grammar and Filing Procedure

An issue is filed from a **draft on disk**, never from arguments typed at the
moment of filing. `gh issue create` is denied at the tool boundary
(`<autoflow-root>/hooks/check-autoflow-gate.sh` > Section 1); the only filing path is:

```bash
<autoflow-root>/scripts/issue/create-issue.sh --draft <path> [--repo <owner/name>] [--dry-run]
```

The wrapper derives search terms from the draft's **own title**, runs the query
itself, and then compares what that query returned against the candidates the
draft dispositioned. It never judges whether a disposition is *correct* — that
judgment is the operator's, at layer three. It refuses when the draft disposes of
nothing the wrapper found.

Three layers guard the path:

| Layer | Mechanism |
|-------|-----------|
| 1 | hook deny on `gh issue create` and its REST form |
| 2 | `<autoflow-root>/scripts/issue/create-issue.sh` re-runs the query and compares dispositions |
| 3 | the operator permission prompt on the wrapper |

Layer three works by **omission**: keep the wrapper off every allow list —
neither `"Bash(scripts/issue/create-issue.sh:*)"` nor a broad `Bash(scripts/*)` /
`Bash(scripts/issue/*)` goes into `.claude/settings.json` or
`.claude/settings.local.json`.

## Draft grammar

Write the draft **directly inside** the repository's draft directory under the record root,
`<record-root>/<repo-key>/drafts/` — the path `autoflow-records drafts` prints (and creates) —
outside the target's tree.

Four required level-2 sections, in **any order** — each runs from its own
heading to the next level-2 heading or to end of file:

```markdown
## Title
[feat] one line, exactly as the issue title should read

## Grounds
`<autoflow-root>/scripts/issue/create-issue.sh` > `has_section "Grounds"` — "a grounding anchor under '## Grounds'": the check runs here, not in the caller

## Duplicate check
searched: create-issue duplicate gate
candidates: none

## Body
The issue body, verbatim. Everything here — and nothing from the other
sections — becomes the created issue's body.
```

| Section | Content | Wrapper's check |
|---------|---------|-----------------|
| `## Title` | one line — the issue title | non-empty single line |
| `## Grounds` | why the issue is warranted | at least one anchor: a commit SHA, a URL, or a durable citation — a document, its section heading and a quoted sentence, written `` `<path>` > <heading> — "<fragment>" ``. A bare `path:line` is not an anchor here |
| `## Duplicate check` | a `searched:` line listing the query terms, then either `candidates: none` or one `#<number> — <disposition>` row per candidate | the `searched:` line is present and non-empty; its tokens feed the term derivation; the candidate rows are the set the disposition invariant compares against |
| `## Body` | the text from its heading to the next level-2 heading | non-empty; becomes the issue body |

A heading inside the body is written at level 3 or deeper (`### Background`),
never at level 2. A `## ` line ends the section above it wherever it sits — a
fenced code block included — so the text under a level-2 heading that names none
of the four sections belongs to no section. The wrapper refuses such a draft,
naming each such heading with its line, instead of filing the body cut short at
it.

## The two names of the artifact

| Stage | Path |
|-------|------|
| Before creation (draft) | `<record-root>/<repo-key>/drafts/issue-proposal-<slug>.md` |
| After creation | `<record-root>/<repo-key>/proposals/issue-<N>-proposal.md` |

Both are under the record root, outside every checkout's tree, and no cleanup touches either. An
unfiled draft stays until its author abandons it. Once the issue exists, the wrapper's rename binds
the record to the issue's number; it belongs to the issue, not to any one attempt of it.

## What the wrapper does

1. Refuses unless the draft is a regular file directly inside the repository's
   draft directory. The directory being **absent** is diagnosed separately from a
   misplaced draft, with a different message. The wrapper does not create the
   directory. A draft that is itself a symlink is refused rather than resolved.
2. Refuses a draft missing any required element, or carrying a level-2 heading
   outside the four sections, naming **every** such defect.
3. Derives title terms by a rule with no implementation freedom: strip a leading
   `[tag]`; lowercase the ASCII range only; split on whitespace and ASCII
   punctuation, with bytes outside ASCII never acting as separators, so a
   non-ASCII run survives as one token; keep a token of `[a-z0-9]` at ≥ 4
   codepoints and a token carrying non-ASCII at ≥ 2; deduplicate keeping first
   appearance; keep the first 8. Codepoints are counted **locale-free**.
4. Appends the `searched:` line's tokens under the same lowercase/separator rule,
   with no floor and no cap. Recorded terms are strictly **additive**: they can
   only lengthen the query.
5. Refuses if the title derives **no** term.
6. Runs **one query per term**, `--state all`, `--limit 100`. If any one term
   returns a full page → refuse, naming the term.
7. Refuses if any returned issue number is not already dispositioned in the
   draft, listing the undispositioned numbers.
8. On success — and only then — renames the draft to
   `<record-root>/<repo-key>/proposals/issue-<N>-proposal.md`, with `<N>` parsed from the URL `gh`
   returned and `<repo-key>` the repository the issue was filed in — the `--repo` value when one is
   named, the current origin otherwise — so a record for another repository's issue never shares a
   name with this repository's issue of the same number. A URL with no parsable trailing number is a failed bind: the draft
   stays put.

`--dry-run` runs every check and creates nothing, leaving the draft in place.

Filing is not readiness: a filed issue reaches DIAGNOSE only once its attempt's criterion review
stage has reviewed its acceptance criteria and recorded the `[criterion-ready]` entry
([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | created, or `--dry-run` passed every check |
| `64` | usage, or the draft is not directly inside the draft directory (including that directory being absent) |
| `7` | the record root is undetermined or unusable (its marker line says why) |
| `65` | refusal — missing section, a level-2 heading outside the four sections, no grounding anchor, no derivable term, an undispositioned candidate, or a query at its page limit |
| `70` | the issue was created but its number could not be bound |
| other | `gh`'s own exit, propagated |

The floors, the cap, the tag strip and their order are **fixed constants in the
script, not flags**; an unrecognised argument is a usage error.

## Accepted limits

Each limit below is an under-block, with layer three as the catch:

- The term cap drops terms on ordinary titles, so a duplicate reachable only
  through a dropped term is never surfaced, and the wrapper reports a clean
  check.
- A term is queried in the surface form the title wrote, so a duplicate phrased
  with a different inflection of the same word falls outside the candidate set.
- On a large tracker a common derived term can return a full page and trip the
  truncation refusal, leaving the agent unable to file until a human intervenes —
  the escape is the operator's, not the agent's.
- The REST-form deny matches any same-segment `POST` paired with a
  `repos/…/issues` path regardless of client, so the plain `curl -X POST
  https://api.github.com/repos/<o>/<r>/issues` form is denied too. The path is
  required to end at the issues collection, and it is taken to end at exactly
  two suffix delimiters — a query `?` and a fragment `#` — so
  `repos/<o>/<r>/issues?per_page=1` and `repos/<o>/<r>/issues#note` are denied
  as well, while `…/issues/12/comments` stays unmatched. No other delimiter is
  claimed: the trailing-slash form `…/issues/ --method POST` is **not** matched.
  What is not matched beyond that is a determined evasion — an obfuscated URL,
  a client invoked through a wrapper script, a quoted form (the hook's scan
  strips quoted substrings exactly as it does for every other Section 1 deny),
  or a command-substituted form (which the scan does *not* strip — it goes
  unmatched). The threat model is the routine self-authorized filing, not a
  determined evasion.

<!-- From <autoflow-root>/docs/role-contracts.md > Advisor -->

## Advisor (first judgment at a decision point)

ADR-0025 D7 moves the first judgment at a decision point from the operator to a dedicated advisor.
This section is the procedure's single home; [`core.md`](<autoflow-root>/docs/core.md) > Flow Control routes to
it and the unit documents cite it.

### Decision points and harness-level blocks

- **A decision point** is a decision the working AI cannot settle on the grounds at hand, or is not
  confident of ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3). An acceptance-criterion
  change, a non-code root cause or a non-code lever, a planning / design / ADR prerequisite the
  analysis records, a reviewer finding that repeats the previous attempt's complaint, and a
  GATE:HYPOTHESIS PASS the orchestrator judges unreachable are where such a decision arises, not
  decision points by their kind: the orchestrator judges each first, and where the grounds the
  raising report, finding or evaluation carries settle it, it decides and records the decision with
  those grounds in an `O` ledger entry under `orchestrator decision` — for an acceptance-criterion
  change, its `[ac-decision]` entries ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
  *Acceptance-criterion decisions*); for a repeated complaint, the attempt's `[review-autofix]`
  entry. An un-agreed design point, a `remedy_class: operator`, and a recommendation or finding the
  orchestrator cannot route with confidence (a pause criterion, a rebuttal the re-score or the
  reviewer keeps while the two sides still disagree) are already decisions the working AI could not
  settle. A security-checklist change (`[checklist-decision]`) is the one decision point by its
  kind: `<autoflow-root>/scripts/gate/security-checklist.sh` counts only an advisor or an operator entry
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Security-checklist decisions*). In U1's criterion
  review stage, a point the review cannot settle is one as well, put by the session running the
  stage — the orchestrator, or a `/autoflow:criterion-review` session taking its part — in the
  procedure below with `cycle 0` and the phase `CRITERION-REVIEW`
  ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Authority*). Each decision point is answered by
  the advisor first.
- **A harness-level block** is what AI cannot perform: a call the harness denies (a permission
  denial), or a tool, credential, installation or material the environment does not provide — for a
  tool it has, what using it lacks (access, a purpose and permitted scope, a permission setting). Only
  such a block stops the cycle for the operator on the forward path — situation-first, `active:false`,
  `phase:"awaiting-user"` ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision
  presentation). A decision at one of those points can end the cycle instead — a non-code lever or cause, a
  prerequisite that comes first, a GATE:HYPOTHESIS PASS not reachable; the last asks the operator to
  confirm closing the issue, the cycle not closing it itself ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) >
  *Verification — GATE:HYPOTHESIS*). PREFLIGHT's readiness conditions, the gate thresholds and the caps are not decision
  points and are unchanged ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 1).

### Procedure

1. **Request.** The orchestrator writes `<attempt-dir>/issue-{N}-advisor-request-<k>.md` situation-first:
   the situation in domain terms, the decision asked with each option and what it changes, the
   orchestrator's own reading — the option it leans to, its grounds, and the point where those
   grounds stop settling it — and the anchors (the artifact paths, the report or finding the
   decision surfaced in). The advisor starts from that reading rather than gathering the material
   anew.
2. **Spawn.** One fresh `autoflow-advisor` per decision, anonymous, model from
   `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model advisor` (its effort is the definition's
   `effort:` line). The prompt names the request file, the ledger, the issue, the cycle and the
   phase. The spawn is never score-gated. Where two or more decisions are open and none depends on
   another's answer, their advisors may be spawned together, and a decision that depends on another's
   answer is spawned after that answer is recorded; whether to spawn them together or one after
   another is the orchestrator's judgment (`<autoflow-root>/docs/core.md` > Rule Scope, principle 2), within the
   concurrent-spawn limit (`<autoflow-root>/docs/core.md` > Cost Control).
3. **Answer and record.** The advisor weighs the material itself, writes its answer to
   `<attempt-dir>/issue-{N}-advisor-<ID>.md` in the same situation-first order, and appends one
   `A`-namespace entry per decision to the ledger under the authority `advisor decision`, carrying a
   `- Record:` line to the answer file and the marker and fields the decision's kind requires
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)). Its identifier comes from
   `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> A`, called immediately before the append; the
   call reserves the identifier, so advisors spawned together receive distinct ones
   ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Entry identifier > *Allocation*). It appends with `Edit`, which the gate hook applies to
   the file on disk and checks (*Independence* below), so the prior content is never re-written. It
   returns the identifier and the answer in one line.
4. **Apply.** The orchestrator verifies the anchor — the ledger heading and the record file exist —
   and routes the cycle as the operator's answer to that point would have been routed: the
   Flow Control row the point sits on names the route. The cycle does not pause. An advisor that
   reports the decision blocked at the harness level turns it into a harness-level block.

### Independence

The advisor is never the author of what it judges: it is a fresh spawn per decision, not the unit
agent, role spawn or orchestrator whose work raised the point, and its record carries its own grounds.
Its authority is worth only that separation, and the operator's override only its own — so each
is written by its own writer alone and stays as written. Three locks:

- **Authorship — the gate hook** (`<autoflow-root>/hooks/check-autoflow-gate.sh`, *Section 1e*,
  state-independent): text a `Write` / `Edit` / `MultiEdit` adds to an `issue-*-ledger.md` that carries an `advisor decision`
  authority or an `A<n>` heading is denied unless the caller's `agent_type` is `autoflow-advisor`;
  text carrying an `operator decision` authority or an `O<n>` heading is denied unless the caller is
  the main session (no `agent_type` — the orchestrator, or a `/autoflow:criterion-review` session
  taking its part, recording its own decision, an operator override or instruction, or the review's
  `[criterion-ready]` entry); the advisor
  adds no `operator decision` and no `O` / `F` / `E` heading.
- **Append-only — the same hook section**: a `Write` / `Edit` / `MultiEdit` is applied to the file
  on disk and must keep the whole prior content as its prefix, so no entry is rewritten or removed.
  A decision changes only by a new entry that names the one it replaces
  (`<autoflow-root>/docs/decision-ledger.md` > *Advisor decisions and operator overrides*).
- **The record convention**: a consumer counts `advisor decision` only on an `A<n>` entry and
  `operator decision` only on an `O<n>` entry, and lets an entry replace another only by an explicit
  `- Supersedes:` / `- Overrides:` line (`<autoflow-root>/scripts/gate/security-checklist.sh`; the gate backstops
  match the `[ac-decision]` marker and read the authority as recorded).

The threat these locks answer is an agent overstepping in routine work — rewriting a ledger it
meant to append to, or writing an authority that is not its own — not a determined evasion (the
same model as `<autoflow-root>/docs/issue-proposal.md`). Outside the hook's surface: a shell write to a ledger
(redirect, `tee`, `sed -i`, a script), and text that only imitates an entry (a heading-less field
line, a malformed heading, a variant spelling of an authority).

### Operator override

An operator override of an advisor decision is recorded by the orchestrator as an `O` entry under
the authority `operator decision`, with the marker of the entry it overrides and a line naming that
`A` identifier. It supersedes the advisor's entry without a new verified fact — the override is the
authority ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor decisions and operator
overrides*) — and the cycle re-enters where the overridden answer's route reaches, consuming no
re-entry budget.

### Claude Code's advisor tool (`advisorModel`)

Distinct from the advisor sub-agent above: Claude Code's advisor tool
(<https://code.claude.com/docs/en/advisor>) lets the session's model consult a stronger model
mid-task. AutoFlow neither enables it nor directs its use. It cannot carry a
decision point: its model is configurable and its effort is not, and Claude decides when to call it,
which is why the first judgment is the sub-agent's (ADR-0025 D7).

---

<!-- From <autoflow-root>/docs/state-tracking.md -->

# AutoFlow State Tracking

The state file's detail — its naming, its schema and fields, the hook gates that read it, and its state at completion. The rules that write into it — the `verdict` rule, score recording and remedy class recording — are [`<autoflow-root>/docs/core.md`](<autoflow-root>/docs/core.md) > AutoFlow State Tracking (Hook integration).

**Record location**: an attempt — one run of an issue — keeps every file in its record directory `<attempt-dir>` = `<record-root>/<repo-key>/<stamp>-issue-{N}/`, named by its dev branch `dev-<stamp>-issue-{N}` (`<stamp>` = `YYYY-MM-DD-HHMMSS`; `dev/<stamp>-issue-{N}` for an attempt made before issue #490): the state file, the ledger, the criterion review record, the unit and gate reports, the review records and the cycle-layer store `issue-{N}-local/`. `autoflow-records dir` prints it for the checked-out dev branch (`--branch` for another), and every document, agent definition, script and hook names a record path through that command or the library it wraps, `<autoflow-root>/scripts/lib/records.sh`. Two repositories' issues of the same number never share a name, and two attempts of one issue — in one checkout, two worktrees or two clones — never share a directory. `{repo-key}` is `<owner>__<name>` derived from the checkout's `origin`.

- **The record root** is `record_root` in the operator's `~/.autoflow/config.json` — an absolute path; the file itself never moves with it. No file, no key, or a JSON `null` → the default `~/.autoflow`. A file that cannot be read as JSON (a syntax error, or no `jq`), or a `record_root` that is not an absolute path string (not a string, empty, relative), leaves the record root **undetermined**, never the default in its stead; an error in the same file's `.review` does not touch it. A record root inside the session's checkout, or one that cannot be created or written, is **unusable**. Either way every script that needs it writes nothing and stops with exit `7` and the marker line `record-root: UNDETERMINED <config path> — <error>` or `record-root: UNUSABLE <record root> — <error>`, asking nothing; the next run reads the file anew. Nothing else — no environment variable — names the root, the records or `_metrics/`.
- **The owner**: the file `checkout` in the record directory names the checkout the attempt belongs to — the one that started it, or the one that took it over (`autoflow-records claim`, once that checkout is gone). Entry, the hook's gates and cleanup read only this checkout's attempts ([`<autoflow-root>/docs/units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*).
- **Completed**: the file `completed` marks an attempt whose Post-Merge Cleanup has run; its records stay where they are ([`<autoflow-root>/docs/git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).
- **Records kept inside the tree before the record root** (`.autoflow/<repo-key>-issue-{N}/`, issues #423 to #465): a state file there is never passed over. The hook refuses the score-gated calls and PREFLIGHT stops (`entry: stop in-tree-records`) until `<autoflow-root>/scripts/migrate/migrate-in-tree-records.sh` moves each such directory whose state file names a dev branch `dev/<stamp>-issue-{N}` to that attempt's record directory, with this checkout as its owner; the cycle then continues from there. One naming no such branch is moved too when it reads `active: false` — to `<record-root>/<repo-key>/in-tree-<date>-<time>-issue-{N}/`, marked `completed`, kept as a record and never entered; when it reads `active: true` it is reported and left for the operator (name the branch in the attempt shape, or set `active: false`), and the script runs again. A directory with no state file (a proposal record, a criterion review of no attempt) is not a cycle and is left in place.

**Companion artifact**: `<attempt-dir>/issue-{N}-ledger.md` — the attempt's append-only decision ledger ([Decision Ledger](<autoflow-root>/docs/core.md)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: by the orchestrator, at PREFLIGHT completion, after the attempt's criterion review stage — the attempt's record directory and dev branch already exist, made when the cycle created the attempt (`autoflow-records new`; [`<autoflow-root>/docs/units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*).

```json
{
  "active": true,
  "issue": "#N",
  "title": "Issue title",
  "date": "YYYY-MM-DD",
  "branch": "dev-YYYY-MM-DD-HHMMSS-issue-N",
  "cycle": 1,
  "mode": "new-issue",
  "phase": "in-progress",
  "phases": {
    "gate_hypothesis": { "evaluator": "", "scores": {}, "verdict": "pending" },
    "gate_plan":       { "evaluator": "", "scores": {} },
    "audit":           { "evaluator": "", "scores": {} },
    "gate_quality":    { "evaluator": "", "scores": {} }
  }
}
```

**`branch` field**: the attempt's dev branch, named once when the cycle creates the attempt (`dev-YYYY-MM-DD-HHMMSS-issue-N`) and kept unchanged for the life of the state file — a review-response continues on it, and the record directory is named from it. The hook admits it as a string and does not read it.

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry; what that resets is `<autoflow-root>/docs/units/preparation.md` > *Review-response setup*. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; the review-response setup sets `"review-response"` (target issue's PR is open). The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while REVIEW aggregates and triages the review result; `"awaiting-external-review"` at the end of REVIEW (set only once the review is clean — no PR's verdict is Medium+) and at a GATE:HYPOTHESIS `no change needed` review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](<autoflow-root>/docs/core.md)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](<autoflow-root>/docs/core.md) > Spawn role declaration.
- `Agent` (a spawn whose caller `agent_type` is a functional-unit agent) → no declaration required; judged by the unit's gate class, and a declared role's own gate also applies (see [Spawn Model](<autoflow-root>/docs/core.md) > A unit agent's spawns inherit its gate class).
- `Agent` (role `planning` — `autoflow-unit-design`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` is a `skipped` value (non-bug issue).
- `Agent` (role `implementation` — `autoflow-unit-build`) → GATE:PLAN pass required.
- `Agent` (role `analysis` — `autoflow-analyzer`, `autoflow-criterion-tracer`, `autoflow-criterion-analyzer`, `autoflow-criterion-reconciler`, `autoflow-unit-analysis` — / `evaluation` / `advisor` / research types) → not score-gated.
- `Write` / `Edit` / `MultiEdit` on an `issue-*-ledger.md` → **state-independently**: a write that changes or removes existing text is denied (append-only); adding an `advisor decision` authority or an `A<n>` entry is denied unless the caller `agent_type` is `autoflow-advisor`; adding `operator decision` or an `O<n>` entry is denied unless the caller is the main session; the advisor adding an `O` / `F` / `E` entry is denied ([`<autoflow-root>/docs/role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor > *Independence*).
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- Which state gates: the state files of **this checkout's** attempts — the record directories whose `checkout` file names the session's checkout (`CLAUDE_PROJECT_DIR`), not marked `completed`. Another checkout's attempt never gates the session. Two or more active ones fail closed on the score-gated surface (`git push`, `gh pr create`, a spawn other than research or evaluation); so does a malformed one.
- In a session with an AutoFlow dev branch (`dev-…-issue-<N>`, or `dev/…-issue-<N>` made before issue #490) checked out — or being rebuilt by an interrupted rebase on a detached HEAD — a record root that is undetermined or unusable, a directory under it that cannot be read, or no `jq` (so neither the input nor the state can be read), refuses the same score-gated surface with the user file's path and error; reads, the writes that repair the file and research / evaluation spawns pass, and the next call reads the file anew. A session with no dev branch checked out can have no attempt in progress and is not refused for it. With no `jq`, the state-independent denies below still hold, read the same over-inclusive way from the raw input.
- A state file in the checkout's own `.autoflow/` (*Record location* above) refuses the score-gated surface until it is moved.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `<attempt-dir>/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch or — in a dev-branch session — to the dev branch's base (its `gh-merge-base`) → **denied state-independently**. AutoFlow never merges; merging is external.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `<autoflow-root>/scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`<autoflow-root>/docs/issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md).
- A **backgrounded** run of `<autoflow-root>/scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `<autoflow-root>/docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on `Bash` (git / gh commands), `Write|Edit|MultiEdit` and `Agent`.

**Completion**: at the end of REVIEW, once the aggregated review is clean (no PR's verdict is Medium+ — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-attempt resolution reads the file (review-response mode) and, once the PR is observed merged or closed, marks the attempt completed; its records stay in its record directory (`<autoflow-root>/docs/units/preparation.md` > *What is asked*).
**Forced termination**: also set `active` to `false`.

<!-- From <autoflow-root>/docs/role-contracts.md > Evaluation AI -->

## Evaluation AI (subagent)

This section is the orchestrator's side of the Evaluation AI: how it is spawned, prompted and its
result recorded. What the evaluator does — its standard, its conduct, every gate's rubric and its
output — is [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md), the one document its agent definition carries with the sections it names.

- Independent evaluator that does not participate in planning or implementation.
- A fresh agent is spawned every call.
- Spawn model: resolved from the spawn policy, never restated here — `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model <phase-key>` for the rubric-scored gates (`gate-hypothesis`, `gate-plan`, `audit`, `gate-quality`). Source: `.claude/autoflow/spawn-policy.json`; revert conditions: *Model tier revert* above.
- Spawn mode: **anonymous direct** — `Agent(subagent_type: "autoflow-evaluator", model: "…")` — never a named team spawn. The Evaluation AI holds no Write tool, so its return value is the only delivery path for its scores (`<autoflow-root>/docs/role-common-rules.md` > Result delivery path by spawn mode). Contract: *Spawn mode by role lifetime* above.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, target file paths, and — for GATE:PLAN and GATE:QUALITY — the path of the issue's **acceptance-criterion list** (`<attempt-dir>/issue-{N}-analysis.md` > `## Acceptance criteria`) together with the issue decision ledger (`<attempt-dir>/issue-{N}-ledger.md`). Those two are the declared source the AC-authority check diffs against. The list is an **input the evaluator reads**, never one it may reinterpret, rewrite or judge the merit of. A criterion the evaluator observes defective as a matter of fact — a fact it presumes that does not hold, or a scope that does not fit the problem ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*) — is recorded as a recommendation ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Output Format); whether it changes is the operator's.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — the agent definition carries `<autoflow-root>/docs/evaluation-system.md` and the sections it names ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection), and the prompt names the `<attempt-dir>/*` files by path. The same principle (file-path-only references to the inputs) applies to every role spawn; see [`core.md`](<autoflow-root>/docs/core.md) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").
5. **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Let it report all findings and let the score rank them ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Finding coverage*).

### Recording the result

The hook does **not** read the evaluator's `pass`, `avg` or `min` fields: it computes them from the raw
`scores` the orchestrator records. The phase keys recorded in `<attempt-dir>/issue-{N}.json` are below.
The four keys match the `gated_phase_keys` allow-list in `tests/fixtures/gate-schema.json`:

- `gate_hypothesis` — GATE:HYPOTHESIS, one form for every issue (hook-gated for a bug / incident issue; its `verdict` `skipped (non-bug issue)` lets the hook admit the ARCHITECT spawn without reading the scores, and the orchestrator judges the PASS)
- `gate_plan` — GATE:PLAN (hook-gated)
- `audit` — AUDIT (hook-gated)
- `gate_quality` — GATE:QUALITY (hook-gated)

- **[MUST]** When an evaluation's `fail_hypothesis` is recorded in state, it is written at `phases.<phase_key>.fail_hypothesis` — a sibling of `evaluator` and `scores` inside the phase object. **[DENY]** Never at the state file's top level and never as an entry inside `scores`. Recording is permitted, not required.

See [`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) for the full schema.


---

<!-- From <autoflow-root>/docs/role-common-rules.md > Communication > Result delivery path by spawn mode -->

### Result delivery path by spawn mode

Every role is an anonymous direct spawn, so there is exactly one delivery path — the spawn's report to its caller, which these rules call its return value — whether the spawn is answering its prompt or a later wake. What carries the report is the harness's, and it depends on the session's permission mode (Claude Code CHANGELOG, 2.1.271: "Changed auto mode so a subagent reports back to its caller through a dedicated hand-back call …"):

- **auto mode** — the spawn's `SubagentHandback` call, which the harness instructs every sub-agent to make; plain text the spawn writes at the end is not delivered. The caller receives two events, in either order: an `<agent-message from="<id>">` hand-back frame, which carries the report, and a task notification whose `result` only points to that frame. The pointer notification is not a spawn that produced no report ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Role-spawn idle handling*) — the report is the frame, arriving before or after it.
- **any other mode** — the spawn's final text: the return value (sync) or the task notification's `result` (background).

The hand-back carries exactly what the final text carries in the other modes — the anchor + one-line summary — never the body, whatever the harness's own tool description says of a "full report" ([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Orchestrator context discipline*, row 2).

| Spawn mode | Where the report arrives | Required delivery action |
|---|---|---|
| anonymous direct (`subagent_type`) — the only mode | auto: the hand-back frame, beside a pointer task notification; otherwise: the return value (sync) or the task notification's `result` (background) | auto: the hand-back call the harness instructs; otherwise none. Write the body to `<attempt-dir>/*` and report an anchor + one-line summary |

A spawn carries no `name`: the gate hook keys the role→gate mapping on `subagent_type` alone and denies a `name`-carrying payload inside a cycle.

The single mode applies to every role; the per-role table is [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Spawn mode by role lifetime.

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
