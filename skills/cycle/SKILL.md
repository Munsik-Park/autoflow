---
name: cycle
description: >-
  Run an AutoFlow cycle on an issue in one session — PREFLIGHT, with the
  attempt's criterion review stage, to REVIEW; `new` asks for a new attempt of
  the issue (one unit alone is /autoflow:cycle-u1 … cycle-u7). Use only when the
  operator starts or resumes an AutoFlow cycle (/autoflow:cycle <N> [new]).
argument-hint: "<issue-number> [new [--base <branch>] [--commit <commit>]]"
---

AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target's own files) is the target's, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.

**Scope** (`$ARGUMENTS`): `<N>` alone runs issue #N's cycle, PREFLIGHT to REVIEW; `new` requests a new attempt, and `--base <branch>` / `--commit <commit>` with it name the base and the start commit `autoflow-records new` makes it at. A session that runs one unit alone is started by that unit's command, `/autoflow:cycle-u1` … `/autoflow:cycle-u7`, whose body carries the parts of the core the unit uses; given `unit=Uk` here, report that and stop.

**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: `<autoflow-root>/docs/units/preparation.md`; `<autoflow-root>/docs/criterion-review.md`; `<autoflow-root>/docs/git-workflow.md` > Git Clean Check; `<autoflow-root>/docs/git-workflow.md` > Post-Merge Cleanup; `<autoflow-root>/docs/units/analysis.md`; `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; `<autoflow-root>/docs/units/design.md`; `<autoflow-root>/docs/units/build.md`; `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; `<autoflow-root>/docs/role-contracts.md` > Role Vocabulary and Spawn Mode > Model tier revert; `<autoflow-root>/docs/evaluation-system.md` > Gate rubrics > GATE:QUALITY > Known blind-spot checks > *Impact scope / Doc updates — reference integrity on moves*; `<autoflow-root>/docs/units/completion-evaluation.md`; `<autoflow-root>/docs/units/delivery.md`; `<autoflow-root>/docs/pr-body-guide.md`; `<autoflow-root>/docs/title-guide.md`; `<autoflow-root>/docs/units/review.md`; `<autoflow-root>/docs/reviewer-backend.md`; `<autoflow-root>/docs/decision-ledger.md`; `<autoflow-root>/docs/issue-proposal.md`; `<autoflow-root>/docs/role-contracts.md` > Advisor; `<autoflow-root>/docs/state-tracking.md`; `<autoflow-root>/docs/role-contracts.md` > Evaluation AI; `<autoflow-root>/docs/role-common-rules.md` > Communication > Result delivery path by spawn mode; `<autoflow-root>/docs/submodule-common-rules.md` > Reporting Format; `<autoflow-root>/docs/submodule-common-rules.md` > Verification and Tools.

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

**An attempt goes on by one of two paths.** After its criterion review, an attempt — one run of an issue, keyed by its dev branch — goes on by the full cycle, which writes its state file at PREFLIGHT and which the rest of this section and every unit document describe, or by the abbreviated path — criterion review, work outside an AutoFlow cycle, review — which never writes a state file and is defined in `<autoflow-root>/docs/abbreviated-path.md`.

**PREFLIGHT cannot be skipped.** If its completion conditions (clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the block first and report.

**An attempt's criteria are settled before DIAGNOSE.** Each attempt's cycle begins with its own criterion review stage, against the target's code and policy; its `[criterion-ready]` ledger entry records the settled decisions, and PREFLIGHT reads only that entry for the current issue body (`<autoflow-root>/docs/criterion-review.md`).

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
**Push and PR creation**: the orchestrator pushes and opens the PR(s) with its own `git push` / `gh pr create` — the commands the hook gates, never a script that would carry them past it — and confirms CI is green, or records on the pull request that CI did not run, never reading that as green. What the PR body carries, the host PR's `Closes #N` included, is the orchestrator's; nothing checks it (`<autoflow-root>/docs/units/delivery.md` > *Push and pull request*). Merging is external; AutoFlow does not merge.

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
U1 Preparation         PREFLIGHT       — Git clean check, remote sync, the entry `cycle-status.sh` prints, the attempt's creation on a `new` entry (`autoflow-records new`), target-declared local checks (`preflight.local_checks[]`; none declared → recorded no-op), the attempt's criterion readiness (`<autoflow-root>/scripts/preflight/criterion-ready.sh`), the state file's creation — the orchestrator's own work, decided from the facts `<autoflow-root>/scripts/preflight/cycle-status.sh` reports
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
U7 Review              REVIEW          — the reviewers the operator's configuration names, each run by its own script, and the reviews the target's side leaves on the PR, aggregated into one verdict → review-triage (auto-resolve Medium+ / judge Low) → state inactive once review is clean, with each pull request's facts reported; scripts read and report (reviewer start, triage case), the orchestrator runs the reviews and makes the changes, the aggregator posts the review comment; external review merges out of band
```

**Flow Control** — the transitions, grouped by the unit they leave. Each group's unit document is the home of the
procedure a row names; the row keeps the condition and the destination.

Each unit's body — what it is asked, its artifact contract, its cautions, its routing and its unit-local `[MUST]`/`[DENY]` constraints — lives in its **unit document**, not in this core file. This file retains what crosses a unit's boundary: the cross-unit invariants and authority rules, the router (the unit and phase list and the Flow Control table above, whose per-unit rows are each unit document's `## Transitions` section), the regression / escalation caps (above), the Execution Principles, and the state rules (below; the state file's schema and the hook gates are `<autoflow-root>/docs/state-tracking.md`). Not every part binds every unit: a session that runs one unit receives the parts its unit uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`, and a session that runs the whole cycle receives all of it; each receives the documents its units use with them (*Context Injection*).

The rubric of every gate — GATE:HYPOTHESIS, GATE:PLAN, AUDIT and GATE:QUALITY — is the evaluator's, not the unit's: it lives in `<autoflow-root>/docs/evaluation-system.md` > *Gate rubrics*, and the unit document routes the gate's result.

The evaluation contract (fresh-spawn Evaluation AI, the evaluator's standard, the 10-point scale, the output format) lives in `<autoflow-root>/docs/evaluation-system.md`; how the orchestrator spawns and prompts the evaluator is `<autoflow-root>/docs/role-contracts.md` > Evaluation AI.

### Unit references

| Unit | Also on entry |
|------|------|
| U1 Preparation | facts: `<autoflow-root>/scripts/preflight/cycle-status.sh`; the criterion review stage: `<autoflow-root>/docs/criterion-review.md`; git procedures: `<autoflow-root>/docs/git-workflow.md` (Git Clean Check, Post-Merge Cleanup) |
| U2 Analysis | unit agent: `autoflow-unit-analysis`; contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; recommendation triage: `<autoflow-root>/docs/units/completion-evaluation.md` > Recommendation triage; whether a finding holds: `<autoflow-root>/docs/units/review.md` > Whether a finding holds; the `Low` judgment's questions: `<autoflow-root>/docs/submodule-common-rules.md` > Scope judgment |
| U3 Design | unit agent: `autoflow-unit-design`; contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; recommendation triage: `<autoflow-root>/docs/units/completion-evaluation.md` > Recommendation triage; whether a finding holds: `<autoflow-root>/docs/units/review.md` > Whether a finding holds; the `Low` judgment's questions: `<autoflow-root>/docs/submodule-common-rules.md` > Scope judgment |
| U4 Build and verify | unit agent: `autoflow-unit-build`; contract: `<autoflow-root>/docs/role-contracts.md` > Functional-unit agents; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; checklist: the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist` and resolved by `<autoflow-root>/scripts/gate/security-checklist.sh`; recommendation triage: `<autoflow-root>/docs/units/completion-evaluation.md` > Recommendation triage; the routes: `<autoflow-root>/docs/units/completion-evaluation.md` > FAIL routing; normative documents: `<autoflow-root>/docs/evaluation-system.md` > Impact scope / Doc updates — reference integrity on moves; whether a finding holds: `<autoflow-root>/docs/units/review.md` > Whether a finding holds; tier revert: `<autoflow-root>/docs/role-contracts.md` > Model tier revert |
| U5 Completion evaluation | change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; normative documents: `<autoflow-root>/docs/evaluation-system.md` > Impact scope / Doc updates — reference integrity on moves; whether a finding holds: `<autoflow-root>/docs/units/review.md` > Whether a finding holds; tier revert: `<autoflow-root>/docs/role-contracts.md` > Model tier revert |
| U6 Delivery | PR body: `<autoflow-root>/docs/pr-body-guide.md`; PR title: `<autoflow-root>/docs/title-guide.md`; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules |
| U7 Review | reviewers: `<autoflow-root>/docs/reviewer-backend.md`; change surface: `<autoflow-root>/docs/submodule-common-rules.md` > Change Surface Rules; comment fixes: `<autoflow-root>/docs/units/completion-evaluation.md` > Code comments in a target; the build re-run: `<autoflow-root>/docs/units/build.md` > Unit spawn; its re-entry: `<autoflow-root>/docs/units/build.md` > Re-entry; CI: `<autoflow-root>/docs/units/delivery.md` > CI; tier revert: `<autoflow-root>/docs/role-contracts.md` > Model tier revert |

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

**[MUST] A unit agent's spawns inherit its gate class** (ADR-0025 D5): a spawn whose caller — the hook input's `agent_type` — is a functional-unit agent needs no role declaration and is judged by that unit's gate class; a declared role that has a gate of its own keeps it as well, so an existing role type is never judged more loosely because a unit spawned it. The caller is the immediate one. The explicit-`model` rule above holds for these spawns too. The unit agents and the advisor are defined in the common frame (#372); each unit is wired into the lifecycle by its own migration step (ADR-0025 D9) — U2 Analysis runs DIAGNOSE, U3 Design runs ARCHITECT, U4 Build and verify runs BUILD (`<autoflow-root>/docs/role-contracts.md` > Functional-unit agents).

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

A project whose information names sub-repos delivers each changed sub-repo on its own pull request, and the host pull request's pointer names the commit it delivers: `<autoflow-root>/docs/units/delivery.md` > *Multi-repo delivery*.

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

**`verdict` rule** (gate_hypothesis only; it carries the bug signal the hook reads — the form itself is the same for every issue; when each value is set follows the Flow Control table):

| Issue type | `verdict` value |
|------------|-----------------|
| Bug / incident | `"pending"`, then `"evaluated"` once the form is scored |
| Non-bug (feat, chore, docs, refactor, …) | `"skipped (non-bug issue)"` |

The hook's state-file validator admits exactly these values, an empty or absent `verdict`, and `"skipped (feat issue)"` — the value a non-bug cycle recorded before `"skipped (non-bug issue)"`, admitted so such a state file stays valid and never written by a new cycle. Any other value makes the state file malformed, and every score-gated `git push` / `gh pr create` / gated `Agent` spawn fails closed until it is repaired. If `verdict` is empty or one of the two `skipped` values, the hook does not gate the ARCHITECT spawn on the `gate_hypothesis` scores; the orchestrator still judges the PASS. Bug issues must be initialised as `"pending"`.

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

### PR Wait Rule

**[MUST]** Use the `active` flag as the single start signal, per checkout: begin a new cycle once every **other** attempt of this checkout reads `active:false`. One attempt runs at a time in a checkout — when another of its attempts reads `active:true`, finish or resolve that cycle first, then start the next; another checkout's attempts, of the same issue or any other, neither hold nor are held. The hook applies the same signal to this checkout's attempts only: it admits `git push` / `gh pr create` while every one of their state files reads `active:false`, and fails closed on two or more active. The readiness check and the requested issue's mode selection are `<autoflow-root>/docs/units/preparation.md` > *PR Wait Rule* and *Modes*.

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
| Sub-repo pointer (gitlink) commit | Orchestrator  | Orchestrator |

## Reference Documents

- **AutoFlow phase guide**: `<autoflow-root>/docs/autoflow-guide.md`
- **Role contracts**: `<autoflow-root>/docs/role-contracts.md`
- **Evaluation system**: `<autoflow-root>/docs/evaluation-system.md`
- **Criterion review (an attempt's first stage, in U1)**: `<autoflow-root>/docs/criterion-review.md`
- **Git procedures**: `<autoflow-root>/docs/git-workflow.md`
- **Repo boundary rules**: `<autoflow-root>/docs/repo-boundary-rules.md`
- **Sub-repo common rules**: `<autoflow-root>/docs/submodule-common-rules.md`

<!-- From <autoflow-root>/docs/units/preparation.md -->

# U1 Preparation — PREFLIGHT and CRITERION-REVIEW

> Unit document for U1. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

PREFLIGHT is functional unit U1 Preparation
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1), and an attempt with no
state file passes its criterion review stage, CRITERION-REVIEW, inside it (issue #465,
[`ADR-0030`](<autoflow-root>/docs/records/adr/0030-criterion-review-is-a-stage-of-the-cycle.md)). U1 has no unit
agent: it is the orchestrator's own work, the criterion review's stage 1 included. This file states what it is asked for, the cautions and the result
owed; the order of the work and the commands are the orchestrator's
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2). A script only reads and reports (D8):
every change — to git, to GitHub, to the cycle's state — is made by the orchestrator itself.

- **Goal**: the requested issue's attempt starts, or continues, on a clean tree synced with the
  remote — an attempt that starts with its criteria settled by its own criterion review stage.
- **Artifact contract**: the state file `<attempt-dir>/issue-{N}.json` and the attempt's dev branch
  checked out (*What is asked*), the plugin record and the local-checks record in the ledger
  (*What is asked*, *Stop conditions*), and, for an attempt's start, its criterion review record and
  its `[criterion-ready]` entry (*The criterion review stage*).
- **Verification**: PREFLIGHT has no gate. Its readiness conditions are deterministic — the facts
  `<autoflow-root>/scripts/preflight/cycle-status.sh` reports, its `entry:` line among them, and the
  *Stop conditions* — and DIAGNOSE does not begin until they hold. The criteria are judged by the
  criterion review stage alone ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)); PREFLIGHT's
  readiness check never judges an issue's content: on an attempt not yet started it reads only
  whether the attempt's own review recorded its `[criterion-ready]` entry for the current body.
- **Loop cap**: A condition that does not hold stops the cycle and is reported; PREFLIGHT
  runs again once it is resolved.
- **Result owed**: the state file, the dev branch and the ledger records above. A resume also
  owes its re-entry point, recorded with grounds in the ledger (*Resume*).

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| PREFLIGHT → CRITERION-REVIEW | `entry: new`, or the operator's request for a new attempt the session judges still to carry out (*Modes*) — the attempt created first (`autoflow-records new --issue N`) — or `entry: criterion-review`, on the attempt's dev branch with the tree clean and `origin` fetched → the attempt's criterion review stage runs in this session (`<autoflow-root>/docs/units/preparation.md` > *The criterion review stage*) |
| CRITERION-REVIEW → PREFLIGHT | the stage's exit condition: the attempt's `[criterion-ready]` entry for the current issue body (`criterion-ready.sh status` `READY`) → PREFLIGHT continues at the stop conditions on that attempt, now `entry: start`; an attempt whose pull request is open is `entry: abbreviated` instead, and the session reports and stops |
| PREFLIGHT → DIAGNOSE | Git clean, remote synced, the stop conditions passed (criterion readiness included for an attempt's start), and the state file written for `entry: start` (`mode: new-issue`) or `entry: review-response` (`<autoflow-root>/docs/units/preparation.md` > *What is asked*, *Modes*) |
| PREFLIGHT → resume | `entry: resume` — this checkout's attempt of the issue reads `active:true` → the re-entry point is the orchestrator's judgment over the facts `<autoflow-root>/scripts/preflight/cycle-status.sh --issue N` reports, recorded in the ledger; a gate with no recorded scores is run, never assumed passed (`<autoflow-root>/docs/units/preparation.md` > *Resume*) |
| PREFLIGHT → user | another issue's attempt mid-cycle in this checkout (`entry: hold`), a pause for a human decision (`entry: paused`), an attempt on the abbreviated path (`entry: abbreviated`), an entry `cycle-status.sh` reports as a stop (`stop …`), a dirty tree (resolved only with the user's approval), a Git state that cannot be synced, an undetermined or unusable record root, or a fail-closed stop condition — a failed target check, an unreadable reviewer configuration the operator does not proceed past, a target-declared local check that does not pass after its declared repair, a criterion review stage a harness-level block leaves without its `[criterion-ready]` entry → report and stop; DIAGNOSE does not begin (`<autoflow-root>/docs/units/preparation.md`) |

## What is asked

```
bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue {N}
```

prints the facts the work is decided from and changes nothing: the working tree, the default branch
against its remote-tracking ref, the AutoFlow this run uses (the root the script runs from, the
plugin name and version that root's `.claude-plugin/plugin.json` names, and, when the root is a git
work tree of its own, its `HEAD` and whether it is dirty), the record root and this checkout, any
state file left in the checkout's own `.autoflow/`, and — for every attempt of this repository not
marked completed — its owner (`this`, `other <path>` for a checkout still there, `gone <path>`), its
state (`active`, `phase`, `mode`, `cycle`, or `none` for an attempt with no state file — in its
criterion review stage, ready to start, or on the abbreviated path
([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md))), its dev branch with each side, and, for a state
file that is not active or no state file, its pull request. `cleanup:` lines name this checkout's attempts that are not active and whose pull request is merged or closed; with
`--issue {N}`, `criterion:` lines give the readiness of each attempt of N this checkout could start,
a dev branch carrying N's number with no attempt record is reported `record=none`, and the last line
is the **entry** — which attempt the request enters, and how (*Modes*). Exit `3` means a fact could
not be read (a `gh` lookup, an unreadable state file, an unreadable `plugin.json`), exit `7` that the
record root is undetermined or unusable (its marker line says why — the operator fixes the file or
the directory, and PREFLIGHT runs again); the line says which. From those facts the orchestrator
brings about the following.

- **An attempt that is over is set aside.** An attempt of this checkout
  — its `checkout` file names this checkout — that is not active and whose pull request is merged
  or closed (`cleanup:`) is cleared, whatever its issue: the entry passes over it (*Modes*). What
  is then done with its branches and its records, and when, is the operator's practice
  ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup). An attempt paused with no pull
  request keeps its files in place, and its pending decision is reported.
- **Another checkout's attempt is reported, not touched.** An attempt whose checkout is still there
  (`owner=other`) is that checkout's: it is not entered, changed, marked or cleared from here, and
  its branch is not deleted on either side. An attempt whose checkout is gone (`owner=gone` — a
  removed worktree or clone; its records stay under the record root, its dev branch in the clone
  and, once pushed, on the remote) is reported the same way until a checkout takes it over: the one
  that checks its dev branch out and runs `/autoflow:cycle <N>` or `/autoflow:cycle-u1 <N>` (`claim:` line; `autoflow-records
  claim`). From then on it is that checkout's, its cleanup included. A worktree deleted without
  `git worktree remove` keeps holding its branch in the clone until `git worktree prune`; until then
  git refuses that branch's checkout, and the takeover waits.
- **A dev branch with no attempt record is not an attempt.** A branch reported `record=none` — no
  record directory under the record root carries its name: another machine's attempt, a branch made
  by hand — is reported, and neither side of it is deleted (issue #433). It does not decide the
  entry, even checked out.
- **One attempt runs at a time in a checkout** (*PR Wait Rule*), and the request enters the attempt
  the `entry:` line names, in the mode it names (*Modes*).
- **The tree is clean and synced.** No uncommitted change or untracked file in the working area,
  and the branch the mode works on — the attempt's dev branch — is where the mode needs it: for a
  start, fast-forwarded to its base's latest commit (`git fetch --prune origin`, then
  `git merge --ff-only origin/<base>` on the dev branch, which has no commit of its own yet; `<base>`
  is what `autoflow-records base` prints), unless the attempt was made at a commit the operator named
  — `git config branch.<dev branch>.autoflow-start` prints it — and stays there; for
  a review-response, matching its remote branch ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Git
  Clean Check). This holds in a worktree whose default branch is checked out in another worktree
  and on any branch the checkout had: nothing here checks out or updates the local default branch.
  In a project with sub-repos, syncing the host also brings each submodule to the commit the host's
  pointer names; this is the orchestrator's work item, and no script checks it.
- **A new attempt is created, and an attempt with no state file passes its criterion review
  stage** (*The criterion review stage*), before the stop conditions.
- **The stop conditions pass** (*Stop conditions*): the target check, a readable reviewer
  configuration (or the operator's choice to proceed without those reviewers when the operator
  file is unreadable), the target-declared local checks, and — for an attempt's start — criterion
  readiness.
- **The plugin record is written.** On a start and on review-response entry, before the state
  file is written, the orchestrator appends the AutoFlow values `cycle-status.sh` reported to the
  attempt's ledger as a record entry, `<C>` being the cycle the state file will carry:

  ```
  ### preflight-plugin | cycle: <C>
  - plugin: <name> <version>
  - root: <the root path>
  - git: <HEAD> clean | <HEAD> dirty (<n> path(s)) | not a git work tree
  ```
- **An attempt's start gets its state**: on its dev branch — made with the attempt when the cycle
  created it (`autoflow-records new`), `dev-YYYY-MM-DD-HHMMSS-issue-N` — the state file from the Creation template with that name
  in `branch`, `mode: "new-issue"` and `phase: "in-progress"`
  ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > AutoFlow State Tracking). The name is the
  attempt's for its life: a review-response continues on it, and its record directory is named from
  it. A review-response gets *Review-response setup*.

Cautions:

- **A dirty tree is never resolved without the user.** What is stashed, committed or discarded is
  the user's to approve; PREFLIGHT does not reach DIAGNOSE on a dirty tree.
- **A branch that does not fast-forward, a fetch that fails, or a Git state that cannot be made
  clean is a hard stop**: report to the user. It is not worked around with a reset or a forced
  update.
- **Nothing on the remote is changed.** PREFLIGHT reads pull-request state and fetches, and the
  record function `cleanup-issue.sh` reads neither ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) >
  Post-Merge Cleanup); neither deletes a remote branch, pushes, or closes, labels or comments on a
  pull request.
- **The state file is created last.** A stop condition that fails, a hold or a pause leaves no
  state file behind; the attempt's dev branch and record directory, made when it was created,
  stay as they are — and so do the records of a criterion review stage left unfinished.
- **An attempt is cleared only on an observed merged or closed pull request.** Its pull request is
  looked up by its dev branch's name even when the branch is gone on both sides.

## PR Wait Rule

The readiness check that clears the requested attempt to start. Its source of truth is the state
files of this checkout's attempts, `<attempt-dir>/issue-{N}.json`; the start signal is
[`core.md`](<autoflow-root>/docs/core.md) > PR Wait Rule.

- **[MUST]** An `active:false` state file (`phase: awaiting-external-review`) is **cleared and
  handed off**: its PR belongs to external review, which merges on its own schedule. Readiness is
  tied to the `active` flag alone.
- Another issue's `active:true` attempt in this checkout holds the requested one (`entry: hold`):
  report and hold, and finish or resolve that cycle first. Another checkout's attempts — of the same
  issue, another issue or another repository — never hold it.

## Modes

The requested issue's entry follows from this checkout's attempts' records — the `entry:` line
`cycle-status.sh --issue {N}` prints; none of these is a judgment. An attempt is identified by its dev branch and belongs
to the checkout that started it, or that took it over. Evaluated in order:

| This checkout's records | Entry |
|---|---|
| a state file in the checkout's own `.autoflow/` | `stop in-tree-records` — moved to the record root first ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > *Record location*) |
| another issue's attempt reads `active:true` | `hold` (*PR Wait Rule*) |
| an attempt of N reads `active:true` | `resume` — the in-progress cycle continues (*Resume*); it is not restarted |
| the checked-out branch is an attempt of N whose checkout is still another one | `stop other-checkout` — reported, not entered (in one clone, git does not let the branch be checked out twice) |
| the checked-out branch is an attempt of N — taken over first (`claim:`) when its checkout is gone: | |
| — not active (no state file, or one whose `active` is not `true`), its pull request merged or closed | cleared (`cleanup:`), as any attempt is, and set aside: the *otherwise* rows below give the entry |
| — no state file, no valid entry (the review is not finished, or the body changed after it), a pull request open or none | `criterion-review` — the attempt's criterion review stage runs on that branch (*The criterion review stage*) |
| — no state file, its `[criterion-ready]` entry valid for the current body, an open pull request | `abbreviated` — the attempt is on the abbreviated path ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)): reported, not entered; a full cycle of N beside it is a new attempt (*A new attempt is the operator's request*) |
| — no state file, its `[criterion-ready]` entry valid for the current body, no pull request | `start` — the attempt's cycle begins (*What is asked*) |
| — `active:false`, `phase` other than `awaiting-user`, an open PR | `review-response` (*Review-response setup*) |
| — `active:false` at `phase: "awaiting-user"` (a PR open or not), or with no open PR | `paused`: the cycle waits on a human decision and is not cleared. The pending decision and its `<attempt-dir>/issue-{N}-*.md` context are reported. Re-entry is driven by the user's new decision — never an automatic mode, never a silent restart: when the user decides to continue, the orchestrator sets `active: true` and continues where the pause was taken |
| otherwise, exactly one attempt of N is ready to start, still in its criterion review stage, or has a state file and an open PR (cleared attempts aside) | that attempt's `start`, `criterion-review` or `review-response` — its dev branch is checked out first |
| otherwise, two or more | `stop candidates` — reported; checking one's dev branch out names it |
| otherwise, attempts of N still here, none of those — paused, on the abbreviated path (`abbreviated`), or with a fact that could not be read (a `gh` lookup, an unreadable state file; exit `3`) | `none-to-enter` — each named with its kind; none is entered by the entry, and a paused one's re-entry is the user's decision |
| otherwise — no attempt of N in this checkout, or every one cleared | `new` — the cycle may create the attempt and run its criterion review stage (*The criterion review stage*) |

**A new attempt is the operator's request.** It is created only on the `new` entry or on the operator's explicit request
— `/autoflow:cycle <N> new`, `/autoflow:cycle-u1 <N> new` or `/autoflow:criterion-review <N> new`. With an attempt of N still in
this checkout — an open PR, a paused one, one whose criterion review is not finished — no new
attempt is made without that request.

The entry is a fact, and so is every line above it. Where the facts leave the way on open — the
cases below — the way is the session's judgment, recorded with its grounds in the ledger of the
attempt it enters or creates (an `O` entry under `orchestrator decision`), or in its report when it
stops (Rule Scope, principle 2 — [`core.md`](<autoflow-root>/docs/core.md)):

- **A `new` in the arguments.** Whether it is a request still to carry out, or one this conversation
  already carried out — an attempt it created — and how far that attempt has come, is the session's to judge from the attempts
  `cycle-status.sh` reports and from what the conversation holds. A request still to carry out creates
  the attempt whatever entry is printed beside it, under the conditions `autoflow-records new` applies.
- **A fact that could not be read** (exit `3`: `pr: lookup failed`, an unreadable state file, a
  `criterion:` line that could not be read): whether to run the script again, report and stop, or
  go on with the other facts.
- **A `claim:` line, a dirty tree, an other-checkout attempt**: whether to take the attempt over,
  ask the user about the tree (a dirty tree is never resolved without the user — *Cautions*), or
  report.

## The criterion review stage

CRITERION-REVIEW is the first stage of an attempt's cycle, inside PREFLIGHT: after the entry
`cycle-status.sh` prints and the conditions before it — no state file left in the tree, no other
attempt of this checkout active (*PR Wait Rule*), the record root determined and usable — and
before the stop conditions and the state file. It runs on the entries `new` and
`criterion-review`, and on the operator's request for a new attempt (*Modes*), in the session `/autoflow:cycle <N>` or `/autoflow:cycle-u1 <N>` started; no other command or session is
needed, and `/autoflow:criterion-review <N>` runs this stage alone, from the same entries, ending at
its exit — the entry of the abbreviated path as well ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)):
a `READY` attempt goes on by `/autoflow:cycle <N>` or on that path.

- **The attempt and its record directory come first.** On `new`, or on the request, the orchestrator creates the
  attempt before the stage writes anything: `autoflow-records new --issue {N}` — on a clean tree,
  with no active attempt in this checkout — fetches `origin`, makes the record directory under the
  record root with this checkout as its owner, and checks out a new dev branch
  `dev-<date>-<time>-issue-<N>` at its base's latest commit, local only and, in the full cycle, with
  no commit of its own until the state file is written. The base — the branch the attempt's pull request merges into —
  is the remote default branch, or the branch the operator names for the attempt
  (`autoflow-records new --issue {N} --base <branch>`); an operator who names a commit
  (`--commit <commit>`, with or without `--base`) has the dev branch made at that commit. The
  operator names them with the request (`/autoflow:cycle <N> new --base <branch>`, …). A named
  commit with commits its base does not have is reported (`not-in-base: <n>` — the pull request
  would carry them); whether to stop and report or go on with that stated is the orchestrator's
  judgment, recorded with its grounds (ADR-0034 D1). It refuses —
  and nothing is made — on a dirty tree, an active attempt of this checkout, a failed fetch, no
  remote-tracking ref of the base, a commit not in the checkout, or a record root that is undetermined or unusable (exit `7`); each is a stop reported to
  the user, as PREFLIGHT reports it. On `criterion-review`, the attempt named is checked out, and
  `git fetch --prune origin` runs before the stage reads the code; a failed fetch is the same hard stop,
  and a dirty tree is resolved with the user first (*Cautions*).
- **The stage is the attempt's criterion review.** What it reads and judges, its stages — stage 1
  in this session, then the `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and
  `autoflow-criterion-reconciler` spawns — its record, its authority and its report are
  [`criterion-review.md`](<autoflow-root>/docs/criterion-review.md). Every record of it is in the attempt's record
  directory `<attempt-dir>` (`autoflow-records dir`).
- **Exit.** The attempt's `[criterion-ready]` entry for the current issue body, which
  `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` reports `READY`; then
  PREFLIGHT continues at the stop conditions on that attempt. While a decision waits on a
  harness-level block, the entry is not written and the session reports it and stops.
- **Re-entry.** The stage writes no state file, so a session that ends in the middle of it
  re-enters it from `cycle-status.sh`'s `criterion-review` entry on the same attempt; what
  the stage already wrote is in `<attempt-dir>`, and how much of it the stage takes up again is its
  own judgment, recorded under the review record's `## Session decisions`.
- **One unit per session.** `/autoflow:cycle-u1 <N>` (`<N> new` for a new attempt)
  runs U1 — this stage included — from its entry (`new`, `criterion-review`,
  `start` or `review-response`) to PREFLIGHT → DIAGNOSE, and every stop above is reported the same
  way.
- **The stage does not hold its checkout.** No state file exists while it runs, so the PR Wait
  Rule's `active` signal does not see it: another issue's `new` in the same checkout switches the
  branch away — only on a clean tree, so no uncommitted work is lost, and the stage's records stay
  in its `<attempt-dir>`. The attempt left so is reported and re-entered later like any unfinished
  review (`criterion-review`). An attempt with no state file is not counted as active because an
  unfinished review left for good would otherwise hold the checkout with no state to clear.

## Review-response setup

For a cycle entered at PREFLIGHT in `review-response` mode. On the attempt's dev branch:

- **[MUST] The previous cycle's artifacts are preserved** before any phase of the new cycle writes:
  every `<attempt-dir>/issue-{N}-<artifact>.md` is renamed to `<attempt-dir>/issue-{N}-c{C}-<artifact>.md`,
  `C` being the previous cycle number. What spans cycles keeps its name — the ledger, the criterion
  review record, the advisor records its entries point at (`issue-{N}-advisor-*.md`), the state
  file and the cycle-layer store `issue-{N}-local/`.
- **The state file moves to the next cycle**: `mode: "review-response"`, `active: true`,
  `phase: "in-progress"`, `cycle` incremented, and `phases` reset to the Creation template (the
  `verdict` rule kept).
- The local checks run with the incremented cycle number, and the state is set only once they pass.
- The DIAGNOSE unit's prompt names the review comment or thread that triggered the cycle.

How much of the previous cycle's artifacts the new cycle reuses is the analysis and design units'
own ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > Unit spawn; [U3 Design](<autoflow-root>/docs/units/design.md) > *Re-entry*). The cycle-layer
store's retained set is reviewed, re-authored and re-executed at the new cycle's BUILD; a check that
did not execute is `not-run`, never `passed`.

## Resume

This checkout's attempt of the requested issue reads `active:true`: a cycle a session ended in the
middle of. `cycle-status.sh --issue {N}` reports what the resume is judged from — each gate's
recorded scores, `verdict` and `remedy_class`, the artifacts on disk, the ledger's last
`[gate-autofix]`, `[rebuttal]`, `[review-autofix]` and `[reentry-decision]` entries, and the last
local-checks record of the current cycle. It names no phase: **where the cycle re-enters is the
orchestrator's judgment over those facts**, recorded with its grounds in the ledger. Cautions:

- The cycle is continued, not restarted: a resume does not increment `cycle` and does not reset
  `phases`. It does not require a clean tree either — what the interrupted session left
  uncommitted belongs to the phase that re-enters.
- The attempt's dev branch — the one its record directory is named from and its state file's
  `branch` names — is checked out before any phase re-enters. A missing branch, or facts that do
  not fit together, are reported to the user.
- A last local-checks record of the current cycle that is not `none declared` or `PASS …
  worktree=clean` means the local checks run now, before any phase re-enters (*Stop conditions*).
- A gate with no recorded scores has not passed. It is run, never assumed — the cycle re-enters no
  later than the phase whose artifact that gate scores.
- A gate whose record carries `remedy_class` has an open re-entry: a passed gate's open
  recommendation attempt ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*), which resumes
  on the route its last `[gate-autofix]` entry names and not past the gate; or a failed gate's FAIL
  route.
- A `[rebuttal]` entry with no verdict entry of that gate after it resumes at that gate's re-score
  ([U7 Review](<autoflow-root>/docs/units/review.md) > *Whether a finding holds*).
- An artifact the next phase consumes that is absent is not written by the orchestrator: the phase
  that produces it runs again.

## Stop conditions

Each is a fail-closed hard stop, run by the orchestrator before the state file is created: DIAGNOSE does not begin until every one that applies passes — the first three in every mode that runs them, *Criterion readiness* on an attempt's start only.

**Target check.** PREFLIGHT runs `bash <autoflow-root>/scripts/preflight/target-check.sh` from the target; a non-zero exit stops the cycle. It runs from the AutoFlow root the session loads — the agent definitions, the readout, the selector and the default spawn policy beside it — and reads the target's files as data, executing none of them. **D6** — when the target keeps its own `.claude/autoflow/spawn-policy.json`, which overrides the plugin's default: `<autoflow-root>/scripts/spawn-policy/spawn-policy.sh check` over it against the loaded agent definitions, and its row set against the default `<autoflow-root>/.claude/autoflow/spawn-policy.json` — a `phases` / `workflow_sites` row the default carries and the target's copy lacks, or a `phases` row whose `agent_type` differs, is named. Model values and `workflow_sites` effort are the target's own and are never findings; a target with no policy of its own passes, its readouts answered by the default. **D7** — on a target that opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`, resolved through `<autoflow-root>/scripts/test/suite-manifest.sh`): every executable spec under the target's `tests/**` declares the usable `# ci-subject:` header the selector requires (the selector's own `--check-headers` stage). A target that has not opted in passes without the selector being consulted, and a declaration file that is present but unreadable is a FAIL. Remedies: D6 → edit the target's policy — set each named row to the loaded definition's values and add each missing row from the default — or delete it to take the default; D7 → back-fill each named suite's header per [U4 Build and verify](<autoflow-root>/docs/units/build.md) > Header contract > *Adopting the contract over existing suites*, or repair the unreadable `.claude/autoflow.local.json`. The AutoFlow version is not a stop condition: a newer release reaches the operator through Claude Code's plugin update.

**Reviewer configuration.** PREFLIGHT runs `<autoflow-root>/scripts/preflight/check-review-backend.sh`, which resolves the reviewers REVIEW runs — from the operator's `~/.autoflow/config.json`, and the default reviewers when it names none ([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Config location*) — prints the `reviewers:`, `source:` and `user-config:` readout lines, and probes each reviewer's CLI presence-only (`command -v`; auth is not probed). Exit `1` — a configured reviewer's CLI absent — does not stop the cycle: REVIEW runs the other reviewers without it and names it on the aggregated comment. Exit `6` with the marker line `user-config: UNREADABLE <path> — <error>` — the operator file cannot be read as configured, so nothing in it applies — is put to the operator, situation-first, with the path and the error: proceed without those reviewers (the cycle continues and REVIEW runs on the reviews of the target's side alone), or stop (no state file is written; the operator fixes the file and PREFLIGHT runs again, reading it anew). On exit `0`, `1` and `6` — on `6` once the operator has answered — the orchestrator appends the result to the issue's ledger as a record entry, `<C>` being the cycle the state file will carry, each line copied from the readout:

```
### preflight-review-config | cycle: <C>
- reviewers: <names|none>
- source: user <path> | none
- user-config: absent [<path>] | ok <path> | UNREADABLE <path> — <error>
- exit: 0 | 1 | 6
- operator: proceed without those reviewers | stop
```

The `operator:` line is written only on exit `6`. See [`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Availability*.

**Target-declared local checks.** PREFLIGHT runs the target repository's **own** readiness procedure through `<autoflow-root>/scripts/preflight/local-checks.sh --ledger <attempt-dir>/issue-{N}-ledger.md --cycle <C>` — before the state file is created; `<C>` is the cycle the state file will carry (`1` on a new issue, the incremented value on review-response entry). The target declares that procedure in the target-owned scaffold `.claude/autoflow.local.json` under `preflight.local_checks[]` — one entry per step, each `{ "name", "check", "repair"? }`, where `check` is the command run (exit 0 = ready) and the optional `repair` is run once on a failed `check`, followed by a re-check whose exit is the verdict. A target whose docs name a per-clone setup step (a commit-hook installer, a generated config, a toolchain probe) declares it here; the framework knows **no specific tool** — it runs what is declared and reads only the exit status. **Absent declaration ⇒ no-op**: the record is the single line `PREFLIGHT local checks: none declared`. A declared check that does not pass (after repair, when one is declared) is exit `1` and stops the cycle: run the declared repair, or fix the declaration, then run PREFLIGHT again. A declaration that cannot be read as declared (malformed JSON, wrong types, an entry without a string `check`) is exit `2` and also stops — never a silent no-op. A passing run additionally asserts `git status --porcelain` is empty afterwards: a dirty tree is exit `3` — not a failed check, but the clean-tree condition already broken — so it is resolved with the user's approval and PREFLIGHT is run again. The outcome is written **only** as a ledger record — a level-3 heading `### preflight-local-checks | cycle: <C>` with one `- result:` line whose verdict token is `none declared`, `PASS <name>=PASS[(repaired)] … worktree=clean`, `DIRTY <name>=PASS[(repaired)] … worktree=dirty(<n>)` or `FAIL <name>=FAIL[(…)] … worktree=n/a` (`PASS` is written only when the run passed and the tree is clean) — an identifier-free record entry; the state file is untouched, and the gate hook reads the ledger advisorily only. The commit-time lint-chain obligation (`submodule-common-rules.md` > *Lint chain on the staged surface*) applies on its own: a declared check that installs the lint chain does not replace running it.

**Criterion readiness** (an attempt's start only; issues #430, #466, #465). The criterion review stage's exit condition, read again here: before the state file is created, PREFLIGHT runs `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue {N}` on the attempt's dev branch (`--branch` names another), which reads one fact: whether **that attempt's** ledger carries its criterion review's `[criterion-ready]` entry — the record of its settled decisions — for the issue body as GitHub holds it now ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Confirmation*). Another attempt's entry — an earlier attempt of this checkout, or one of another checkout under the same record root — never makes it ready, and another attempt's state file or records under the record root are never a reason for `NOT READY`. It does not judge the review's content, the criteria, or whether the review was thorough — those are the review's: the session's judgment, the advisor's answers and any operator override. Exit `0` (`READY`) passes. Exit `1` (`NOT READY` — no entry, a malformed one, a missing review record, a body edited after the entry, or an attempt that has already started) and exit `3` (the issue body could not be read) leave no state file behind: on exit `1` the attempt's criterion review stage runs again on its dev branch (`entry: criterion-review`) — for a body edited after the entry, the stage's judgment on the edit and a new entry in that attempt's ledger ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Confirmation*), which the session records once the decisions are settled; neither is an operator confirmation. Exit `3` stops the cycle and is reported situation-first; PREFLIGHT runs again once the body can be read. A `review-response` entry, a resume and a paused cycle do not run this check: their criteria were fixed when the attempt began, and a change to them inside a cycle is an `[ac-decision]` ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md)). An issue filed before this condition existed is reviewed on its turn, with no exemption by filing date ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md) > *Issues filed before this procedure*).

<!-- From <autoflow-root>/docs/criterion-review.md -->

# Criterion Review — The First Stage of an Attempt's Cycle

An issue's acceptance criteria are reviewed against the target's code and policy in the **first
stage of the cycle**, CRITERION-REVIEW, before DIAGNOSE takes them, by each attempt for itself: an
attempt — one run of the issue, in one checkout — begins with its own criterion review and stays
independent of every other attempt from that review to its pull request. The session settles the
criteria under the policy the operator set (*Authority* below) and records the settled decisions
in a `[criterion-ready]` entry in the attempt's ledger — the stage's exit condition; PREFLIGHT
writes that attempt's state file only on that record
([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *The criterion review stage*, Stop conditions >
*Criterion readiness*). This is the
Definition of Ready of backlog refinement: a criterion that presumes a fact that does not hold, that
conflicts with a policy already in force, or that leaves a term undefined is found while it is
still cheap to change — before a unit re-run, a gate re-score and an advisor spawn each find it one
at a time inside the cycle.

The review does not replace the in-cycle path for a criterion defect: DIAGNOSE still takes the
criteria as written, and from ARCHITECT on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## When and by whom

- **When.** As the first stage of each attempt's cycle, inside PREFLIGHT before the attempt's state
  file — `/autoflow:cycle <N>`, or the U1 session `/autoflow:cycle-u1 <N>`, enters it on the entries `new` and `criterion-review` — and again, on
  that attempt's dev branch, after any edit to the issue body before the state file, since the
  `[criterion-ready]` entry is bound to the body it records (*Confirmation* below). Filing an issue
  ([`issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md)) does not make it ready. Run alone
  (`/autoflow:criterion-review <N>`), the stage is also the entry of the abbreviated path
  ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)): a `READY` attempt goes on by `/autoflow:cycle <N>`
  or on that path, and an attempt on that path, which never has a state file, changes a criterion by
  this review run again on its dev branch.
- **The cycle makes the attempt before the stage.** On `criterion-review` the stage reviews the
  attempt that entry names — this checkout's attempt of N with no state file: a re-review after a
  body edit, a review left unfinished — and adds its new entry to that attempt's ledger. On `new`
  the cycle creates a new attempt first, before the stage writes anything:
  `autoflow-records new --issue N` — on a clean tree, with no active attempt in this checkout — fetches
  `origin`, makes the attempt's record directory under the record root with this checkout as its
  owner, and checks out a new dev branch `dev-<date>-<time>-issue-<N>` at the latest commit of the
  attempt's base — the remote default branch, or the branch the operator names (`--base`) — or at
  the commit the operator names (`--commit`), local only and, in the full cycle, with no commit of its own until the
  attempt's state file is written. The attempt's key is that branch's name, and every record of the review — the review
  record, the stage 2 and in-depth files, the advisor records, the ledger with its
  `[criterion-ready]` entry — is in that directory, as the cycle's later records are. While an
  attempt of N with an open pull request, a paused one, or one whose review is unfinished is still
  in this checkout, the entry is that attempt's, and a new attempt is made only on the operator's
  explicit request (`/autoflow:cycle <N> new` or `/autoflow:cycle-u1 <N> new`; [U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *Modes*).
  An attempt that already has a state file takes no `[criterion-ready]` entry: a criterion change
  inside its cycle is an `[ac-decision]`. An attempt begun and then left is reported by PREFLIGHT
  like any other until the operator runs it or leaves it (its branch and records stay, as a paused
  attempt's do).
- **Reviewer.** The session that runs the stage: the `/autoflow:cycle <N>` session — or the U1
  session, `/autoflow:cycle-u1 <N>` — or a `/autoflow:criterion-review <N>` session, which runs this stage
  alone and ends at its exit; no other attempt of its checkout is active. The review is that
  session's own work, and the stage writes no state file. What it reads and how — which code, documents and materials, the order, how far it
  follows a cause or an effect, which tool checks a fact — is its own, recorded under the record's
  `## Inputs` with what it read and why, and what it left out and why (Rule Scope, principle 2 —
  [`core.md`](<autoflow-root>/docs/core.md)). The session carries stage 1 itself, the screening included; stage 2,
  the in-depth analysis and the reconciliation run in fresh contexts it spawns —
  `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and `autoflow-criterion-reconciler`
  (*Stages of the review*, *Cause reach and rule conflict (stage 2)* and *In-depth analysis and
  reconciliation* below).
- **Reference model and effort.** The review session runs on Opus 5.5 (`claude-opus-5-5`) at effort
  `high`; another model or effort may be used. The setting for the session lives here because the
  review is the session's own work, not an `Agent` spawn. Its spawns take theirs from
  `.claude/autoflow/spawn-policy.json` like every other spawn ([`core.md`](<autoflow-root>/docs/core.md) > Spawn
  Model): the model each declares is read with `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model
  criterion-trace`, `… model criterion-in-depth` or `… model criterion-reconciliation`, and the
  effort is the one its agent
  definition carries. The record's `## Inputs` names the model and effort the session and each
  spawn ran on.
- **What the reviewer never does.** It never edits the issue body or a criterion except to apply
  the settled decisions, never writes the `[criterion-ready]` entry while a decision is unsettled,
  and never asks the operator to confirm, approve or re-check a settled decision or waits on the
  operator for one (*Authority*, *Report to the operator* below).

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the commit the
  attempt's dev branch starts from unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`core.md`](<autoflow-root>/docs/core.md) > Project Information), and the documents of the
  sub-repos the issue reaches.

## Purpose and scope

The review's **purpose** is to find, before a cycle commits to the criteria, a criterion that would
lead the work wrong or short of done: one that presumes a fact that does not hold, conflicts with a
policy in force, leaves out part of where the cause reaches or of the behavior the issue reports,
stops at a direct cause where a root cause produces the defect, leaves a term undefined, or cannot
be shown met. Its **object** is the issue's acceptance criteria together with the behavior they
require, wherever in the code the reported cause and the required behavior reach — not only the
code a criterion names. The **quality characteristics** it evaluates are, in stage 1, the review
items below: fit with the code and policy, coverage of the reported behavior, depth of cause,
consistency, clarity, size, testability, and verified premises — and, in the screening, whether
each criterion holds in every case it applies to, judged on the code that decides the behavior;
and, in stage 2, the reach of each confirmed cause beyond the points the issue reports and the
agreement of each required behavior with the rules and behaviors the code already has.

Which code, documents and materials the review reads to judge them, and how far it reads, is the
reviewer's own (*When and by whom* > *Reviewer*); the record's `## Inputs` states that scope.

**What the review leaves to the cycle.** The review judges the criteria against the code and policy
as they stand; it does not set how the change will be made. What shows only once an approach
exists — the change's effect on other functions, the reuse of existing code, where a
responsibility is placed, an approach that meets a rule in force — is the cycle's: the design is
ARCHITECT's ([U3 Design](<autoflow-root>/docs/units/design.md)), and a change's side effects are derived at BUILD, not
predicted at design ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > Evaluation Types — Plan
evaluation (GATE:PLAN): "affected files and side effects are derived at BUILD by the build unit,
not predicted and scored here"). A criterion defect found there takes the in-cycle path
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be
wrong*). A choice of how to make the change is neither asked here nor written into a criterion;
what a criterion keeps is the behavior a user, a caller or an operator observes.

## Stages of the review

**Stage 1** checks the criteria on the review items and screens the cases each criterion applies
to, selecting the ones for in-depth analysis. **Stage 2** starts from what stage 1 confirmed — each
cause the code shows and the behavior each criterion requires — and asks how far they reach,
assuming no fix (*Cause reach and rule conflict (stage 2)* below). The **in-depth analysis**
examines the selected cases, criterion by criterion, and the **reconciliation** settles where a
stage 2 finding or an in-depth verdict differs from the record. Stage 2, the in-depth analysis and
the reconciliation each run in a fresh context.

The screening is wide — every case a criterion applies to, criterion by criterion; stage 2 crosses
the criteria — a cause one criterion's cases show may operate where another criterion, or none,
applies; the in-depth analysis is deep — the code that decides each selected case. A judgment made
early in a session is carried through the rest of it: a later sign against it in the same session —
or in a session handed its record — does not reliably overturn it. A single pass also leaves out
cases the issue does not report, and rests a verdict that a behavior already exists on the point
where it shows rather than on the code that decides it (issue #442). Stage 2 therefore runs apart
from the session that wrote stage 1, so the places that session looked do not bound where stage 2
looks; it is handed the record as its starting point, and asks a question the record did not. The
in-depth analysis receives the cases and their code locations but no earlier verdict or grounds.
Stage 2 may start once stage 1's record is written, and a criterion's in-depth analysis once the
screening has selected its cases; the two may run alongside each other. The reconciliation runs
after stage 2 and every in-depth analysis, since it applies both to the record.

## Review items (stage 1)

Each criterion is checked on the items below — *Actual and expected behavior* and *Size and
separation* once for the issue as a whole; an item that does not apply to a criterion says so.
Each finding carries its grounds: a commit SHA with `path:line` for a fact of the code, or the
document, its section heading and a quoted sentence for a provision of a policy document.

| Item | The question |
|---|---|
| Code and policy fit | Does the code behave as the criterion presumes, and does the criterion agree with the policies in force (an ADR, a rule document)? A criterion that presumes a behavior the code does not have, or one that a standing policy contradicts, is a finding. |
| Cause | Where the issue reports a defect, does the criterion address only the direct cause — the point where the failure shows — or also the root cause that produces it? A criterion narrower than the cause the code shows is a finding, recorded with which of the two it covers. Establishing the cause is DIAGNOSE's work inside the cycle ([U2 Analysis](<autoflow-root>/docs/units/analysis.md)); the review judges what the criterion covers against the cause the code shows. |
| Actual and expected behavior | Set side by side, does the state the criteria describe as done cover the behavior the issue reports as it actually occurs? A criterion set that covers only part of the actual behavior is a finding, recorded with the part left uncovered. |
| Contradiction | Can every criterion hold at once? Two criteria that cannot both be met, or one that undoes another, is a finding. |
| Terms and scope | Is every term a test would turn on defined — a threshold ("exceeds"), a surface ("the conversation screen"), a set ("every page")? An undefined term, or a scope with no stated bound, is a finding. |
| Size and separation | Is the issue one piece of work a single cycle can carry to done, or does it bundle areas that are each complete on their own — separate surfaces, separate causes, criteria that share no code or test? Several independently completable areas in one issue is a finding, recorded with the areas and a proposed split (`split`). |
| Testability | Can the criterion be shown met or unmet by an observation, and does the environment provide what that observation needs? A criterion no observation can settle is a finding. |
| Estimates verified | Is each estimate the body states as fact — a cause, a reproduction, an affected path — confirmed by the code or an observation? An estimate left unconfirmed is a finding, recorded as unconfirmed rather than as wrong. |

## Screening (stage 1)

After the review items, stage 1 screens the cases each criterion applies to:

- **Cases.** For each criterion, every case it applies to: the cases the issue reports, and every
  case in which the object or the state the criterion's words name varies — another surface the
  same cause operates on, or a path where a rule already in the code could prevent the required
  behavior.
- **Locations.** For each case, where the required behavior shows, and the code that decides
  whether and how it occurs — each as `path:line` at the commit read.
- **Verdicts.** For each criterion and case: `finding`, `holds` or `unconfirmed`, with its grounds
  and how far they reach — `shows` (the point where the behavior shows) or `decides` (the code that
  decides it and the condition applied there).
- **In-depth targets.** Every `finding`, and every `holds` or `unconfirmed` whose grounds do not
  reach `decides`. A criterion with no target is recorded as such, and has no in-depth analysis.

## Cause reach and rule conflict (stage 2)

Once stage 1's record is written, one `autoflow-criterion-tracer` spawn — a fresh context that
carries none of the session's conversation — receives the issue body and the stage 1 record.
Starting from each cause the record confirms in the code and the behavior each criterion requires,
it judges two questions:

| Question | What it judges |
|---|---|
| Cause reach | Does a confirmed cause operate beyond the points the issue reports — the same defect showing at another point, surface or element the cause reaches? A point where it does that no criterion covers is a finding. |
| Rule conflict | Does the behavior a criterion requires agree with the rules and behaviors the code already has, in every case the criterion applies to? A rule or behavior in force that keeps the required behavior from holding is a finding, recorded with the rule and the case. |

How the change will be made is not yet set, and stage 2 assumes no fix: an effect that would follow
only from a particular approach is outside it (*Purpose and scope* > *What the review leaves to the
cycle*). Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it
(`new`), and carries its grounds as the review items' findings do. It writes
`<attempt-dir>/issue-{N}-criterion-review-stage-2.md` and returns that path and a
one-line summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: an `autoflow-criterion-analyzer` spawn the review session makes, which carries none of
the session's conversation. The session hands it one target file,
`<attempt-dir>/issue-{N}-criterion-review-target-<criterion>.md`, holding only the
issue body, the criterion's text, the target cases, each case's code locations (`path:line`) and
the commit they were read at — no verdict, grounds or conclusion. The verdict rests on the code
that decides whether and how the required behavior occurs and the condition applied there, never
on the point where it shows alone. Where the behavior occurs only under a condition, the analysis
checks whether a situation that does not meet the condition actually arises — from which input,
state or usage flow; where one does, the behavior does not hold in that situation. It writes
`<attempt-dir>/issue-{N}-criterion-review-in-depth-<criterion>.md` — per case the
verdict, the deciding code and condition, and the grounds — and returns that path and a one-line
summary.

**Reconciliation.** After stage 2 and every in-depth analysis, one `autoflow-criterion-reconciler`
spawn — again a fresh context — receives the review record, the stage 2 file and the in-depth
files. Where a stage 2 finding or an in-depth verdict differs from the record, it confirms in the
code which one holds and settles it. A criterion that does not hold in a case it applies to is a
finding for that case, recorded with the rule or condition that prevents it — never summarized as
holding conditionally. It updates `## Findings`, `## Screening`, `## Proposed changes` and
`## Open questions` to match, writes `## Cause reach and rule conflict` and `## Reconciliation`,
and returns the record's path and a one-line summary.

**What the procedure fixes.** The artifacts — the screening, the stage 2 findings, the in-depth
verdicts and the reconciliation record — and the independence of the fresh contexts: stage 2
receives the issue body and the stage 1 record and none of the session's conversation, and the
in-depth context receives the target file and nothing of the session's verdicts or grounds. Each context's agent definition carries its part of this document ([`core.md`](<autoflow-root>/docs/core.md) >
Context Injection); what else it reads, in what order and with which tool, is its own (Rule Scope,
principle 2 — [`core.md`](<autoflow-root>/docs/core.md)). Each spawn
declares its role by its `subagent_type` and the model its policy row names
([`core.md`](<autoflow-root>/docs/core.md) > Spawn Model), at most five are in flight at once
([`core.md`](<autoflow-root>/docs/core.md) > Cost Control > *Concurrent spawns*), and its prompt states the
delivery as "return … as your report".

## Review record

`<attempt-dir>/issue-{N}-criterion-review.md`, written by the reviewer in the
attempt's record directory (`autoflow-records dir` on its dev branch). Every section is present; a
section with nothing to record says `none`.

| Section | Holds |
|---|---|
| `## Inputs` | the issue body sha256 reviewed; the scope the reviewer set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort the session and each stage 2, in-depth analysis and reconciliation spawn ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Screening` | stage 1 — per criterion, each case it applies to: where the required behavior shows and the code that decides it (`path:line`), the verdict (`finding` / `holds` / `unconfirmed`), the reach of its grounds (`shows` / `decides`), and whether it is an in-depth target; a criterion with no target says so |
| `## Cause reach and rule conflict` | stage 2 — each finding, by question (cause reach / rule conflict), marked `stage 1` or `new`, with its grounds, as the reconciliation settled it — or `none` |
| `## Reconciliation` | per stage 2 finding and per in-depth case: its verdict, how the reconciliation took it — `applied`, `rejected` or `unresolved` — and the grounds, with the file it came from |
| `## Proposed changes` | per finding that calls for one, from either stage or the reconciliation: the criterion, the disposition (`excluded` / `revised` / `split` / `added`), the proposed text, the grounds and where the finding came from (`stage 1`, `stage 2` or `in-depth`) — or `none` |
| `## Open questions` | each point the review could not settle itself (what a term is meant to cover, which of two readings the issue intends) and put to the advisor (*Authority* below): the question, stated as the behavior it concerns, why the code and policy do not settle it, each option with what it changes in the criteria, and the advisor's answer with its ledger entry — or `none`. How the change will be made is never a question here (*Purpose and scope* > *What the review leaves to the cycle*) |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |
| `## Operator decisions` | each decision the operator gave when they chose to — an override of an advisor answer (with its `O` override entry) or of a disposition, or an instruction (a re-run and its scope, a text) — with what it changed; or `none`. It is not an item-by-item operator verdict on the dispositions and advisor answers, and the `[criterion-ready]` entry does not wait on it (*Authority* below) |
| `## Session decisions` | the session's own judgments after the review, apart from the operator's decisions: each detail an operator decision leaves open, with its grounds; whether the review was run again and over what scope when the body the entry records differs from the one `## Inputs` names, with its grounds (*Confirmation* below); and the issue edit that applied the decisions, with the edited body's sha256 — or `none` |

The record is situation-first where the operator reads it — to follow what was decided and to
override any of it ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Human-decision presentation*):
what each finding means for the issue's behavior comes before its anchors.

## Authority

The review follows the same authority over acceptance-criterion content as the cycle, under the
policy the operator set for it: the review session judges, the advisor decides a point the session
cannot settle or is not confident of, and the operator overrides when they choose
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principles 1 and 3). The reviewer judges
each finding and records its disposition with its grounds — a proposed change to the criterion, or
the criterion kept as written; a point the code or a policy settles, or that it can reasonably
choose, it settles and records. A point it cannot settle, or is not confident of, is a decision point: the review session
puts it to a fresh advisor by the advisor's procedure, taking the orchestrator's part, with
`cycle 0` and the phase `CRITERION-REVIEW` ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor);
an answer that decides a criterion's content is an `[ac-decision]` entry
([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), and the record
carries it under `## Open questions`. The advisor's answer is itself the decision: it is applied
as recorded and does not wait on the operator's review.

The operator overrides an advisor answer or a disposition, or gives an instruction, when they
choose; it is recorded under `## Operator decisions`, an override of an advisor answer also as any
override is ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Advisor decisions and operator
overrides*). A detail an operator decision does not itself settle — one that does not change the
decision — is the session's to judge: the session records it with its grounds under
`## Session decisions`, as its own judgment apart from the operator's decision. Such a detail is
not an item for an operator verdict and is not put back to the operator; a detail the session
cannot settle, or is not confident of, goes to the advisor first.

Once every decision is settled — each disposition, each advisor answer and each operator decision
given — the session edits the issue body to match and records the `[criterion-ready]` entry
(*Confirmation* below), without waiting on an operator response or confirmation. The condition for
the entry is that the decisions are settled, not an operator verdict on each of them. The operator
is asked only for a harness-level block ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*). The criteria a cycle starts from are therefore the
issue body as those decisions left it, and the review record is the evidence they were made on.

## Confirmation

The confirmation — the `[criterion-ready]` entry — is the record of the decisions made under the
policy the operator set (*Authority* above). The review session writes it once every decision is
settled, as a decision-ledger entry in the attempt's ledger
`<attempt-dir>/issue-{N}-ledger.md` — an `O<n>` entry under the authority
`operator decision`, which the gate hook admits from the main session only
([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > Hook gates; grammar: [`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
Decision-point entries > *Criterion-readiness confirmations*):

```markdown
## O<n> — criteria settled for a cycle (cycle 0, CRITERION-REVIEW) [criterion-ready]
- Decision: the acceptance criteria of #N, as the issue body now states them, are settled for a cycle
- Record: issue-<N>-criterion-review.md
- Issue body sha256: <criterion-ready.sh hash --issue N, run after the last edit>
- Grounds: the decisions recorded — the dispositions, the advisor answers (their A entries), any operator decision, the session decisions — and, when the body differs from the one ## Inputs names, the re-run judgment under ## Session decisions
- Authority: operator decision
```

The identifier comes from `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> O`, called
immediately before the append ([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). `cycle 0` marks an
entry written before the attempt's state file — in its criterion review stage, ahead of the cycle
number the state file starts at. `- Record:` names a file in the attempt's record
directory, by its name alone: a path to another attempt's record is not read.

**The confirmation is bound to the attempt and to the body.** `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue N`
reads the last `[criterion-ready]` entry in the ledger of the attempt on the checked-out dev branch
(`--branch` names another) — never another attempt's — and reports `READY` only when the attempt
has no state file yet, the entry is an `O` entry under `operator decision`, its record exists, and
its `- Issue body sha256:` equals the sha256 of the issue body read from GitHub now. Any edit to the
body after the entry leaves the attempt not ready until its own review runs again and a new entry
in its ledger records the edited body — another attempt's entry, of this checkout or another, never
stands in for it — written as the first one is: once the decisions are
settled — an operator override included — with no operator confirmation asked. When the body an
entry records differs from the body the record read (the sha256 under `## Inputs`) — an edit after
an entry, or a body edited before the first entry to apply the decisions — whether the review is run
again, and over what (in whole, the changed criteria only, or not at all), is the session's
judgment: it records the judgment with its grounds under `## Session decisions`, and the new entry's
grounds point to it. The session does not ask the operator for it. An operator instruction on the
re-run or its scope is the decision; a session that cannot settle it, or is not confident of it,
asks the advisor.

## Report to the operator

The review session's report to the operator is situation-first ([`core.md`](<autoflow-root>/docs/core.md) >
Execution Principles > *Human-decision presentation*) and tells what the session decided as
recorded — "recorded", not a request: the dispositions; each advisor answer with its `A` entry; each operator
decision applied; the session decisions — the details within an operator decision and the re-run
judgment; and the edited body's sha256 with the `[criterion-ready]` entry. The only thing it asks
the operator is a harness-level block ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor >
*Decision points and harness-level blocks*), and it asks for no other confirmation, approval or
review: an override is the operator's to give when they choose, not something the report requests.
`## Unchecked` is reported as fact and is put to the operator only where it is a harness-level
block. While a harness-level block leaves a decision unsettled, the entry is not written and the
report says which decision waits on it. A report after an operator override or instruction takes
the same form.

## What reads it

- **PREFLIGHT** — the stage's exit, read again on an attempt's start only, as a fail-closed
  condition before the state file is created: it reads the fact the script reports for that attempt
  and never judges the review's content ([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > Stop conditions >
  *Criterion readiness*). A `review-response`, a resume or a paused cycle does not run it.
- **DIAGNOSE** — the attempt's review record is one of the U2 unit's inputs in a `new-issue` cycle
  ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) > *Criterion review record*).
- **The abbreviated path** — its start: an attempt goes on outside a cycle on its
  `[criterion-ready]` entry for the current body, and `cycle-status.sh` reports it
  `criterion-review` while the entry is not valid ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)).

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue filed without a
`[criterion-ready]` entry is reviewed on its turn, when an attempt of it is next begun — its cycle's
criterion review stage — and the review records the entry once its decisions are settled. An issue that already has a
state file — a cycle active, paused, or waiting on external review — is not affected, because those
modes do not run the check. An issue taken up again after an earlier attempt is reviewed again by
the new attempt, whatever the earlier one left: every attempt begins with its own review (*When and
by whom* > *The cycle makes the attempt before the stage*). A `[criterion-ready]` entry a target recorded inside its
tree before the record root (`.autoflow/<repo-key>-issue-<N>/`) belongs to no attempt and is not
read: a new attempt's own criterion review stage records its own.

<!-- From <autoflow-root>/docs/git-workflow.md > Git Clean Check -->

## Git Clean Check

The conditions PREFLIGHT starts from ([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*).
`<autoflow-root>/scripts/preflight/cycle-status.sh` reports the working tree and the default branch against its
remote-tracking ref; bringing them to this state is the orchestrator's.

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch --prune origin
# An attempt's start: its dev branch dev-<date>-<time>-issue-<N>, made at its base's latest commit
# when the cycle created the attempt (autoflow-records new) and with no commit of its own yet, is
# checked out and fast-forwarded to its base's latest commit — `autoflow-records base` prints the
# base; an attempt made at a named commit (git config branch.<dev branch>.autoflow-start) stays there
git switch dev-<date>-<time>-issue-<N>
git merge --ff-only origin/<base>
# A review-response: the dev branch matches its remote branch
git log HEAD..origin/dev-<date>-<time>-issue-<N> --oneline   # must be empty (or handled)
# In a project with sub-repos, each submodule is at the commit the host's pointer names
# after the host is synced (the orchestrator's work item; nothing checks it).
```

Nothing here checks out or updates the local base: a worktree whose base is checked out in
another worktree cannot (`git checkout <base>` and `git fetch origin <base>:<base>` both refuse
there), and a checkout on any other branch needs no more than `origin/<base>`.

If any check fails:

- Uncommitted changes → `git stash`, `git commit`, or discard with the user's
  approval (PREFLIGHT).
- Remote has new commits ahead of a review-response branch → `git pull --rebase` and re-run.
- A dev branch that does not fast-forward → stop and report; it is not reset.

If the working tree cannot be made clean, **stop** and report. PREFLIGHT does
not advance to DIAGNOSE on a dirty tree.

---

<!-- From <autoflow-root>/docs/git-workflow.md > Post-Merge Cleanup -->

## Post-Merge Cleanup

**Merging, and what follows it, are outside AutoFlow.** Whether and when a pull request is merged,
in what sequence beside the pull requests it depends on, by what method, and what is confirmed
before it — the sub-repo pointer included — are the external review's. What follows a merge or a
close — how a host pointer is brought up after a sub-repo pull request merges, what becomes of the
attempt's dev branches on either side, and what is cleaned up, when and how, the record function
below included — is the operator's practice for the project. AutoFlow defines no step, order or
timing for either, and none of its steps waits on them.

What AutoFlow keeps there:

- It merges nothing, promotes no draft, and pushes to neither the default branch nor the attempt's
  base; every pull request it opens is a draft ([`units/delivery.md`](<autoflow-root>/docs/units/delivery.md) > *Push
  and pull request*; [`units/review.md`](<autoflow-root>/docs/units/review.md) > *End*).
- The entry sets aside an attempt of this checkout that is not active and whose pull request is
  merged or closed, by those observed facts alone, and `cycle-status.sh` names it on a `cleanup:`
  line ([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *What is asked*, *Modes*).
- Its own steps change nothing on the remote: PREFLIGHT reads the pull request's state and fetches,
  the record function below reads neither, and neither deletes a remote branch, pushes, or closes,
  labels or comments on a pull request.

**The record function.** `<autoflow-root>/scripts/cleanup/cleanup-issue.sh <dev branch> [<dev
branch> …]` marks an attempt that is over. Its precondition is an attempt of this checkout — one
whose record directory's `checkout` file names this checkout — that is not active (it has no state
file, or its state file's `active` is not `true`) and whose pull request is merged or closed: the
attempt `cycle-status.sh` names on a `cleanup:` line. The mark ends the attempt for the gate hook
too — the hook passes over a record directory marked `completed` when it looks for this checkout's
active attempt — so an attempt still running is not marked, even when its pull request was merged
or closed out of band. The script does not read the state file itself. An attempt of another
checkout still there (`owner=other`), or one whose checkout is gone (`owner=gone`) until a checkout
takes it over, is not this checkout's to mark, and the script refuses it; a dev branch with no
attempt record (`record=none`) has no attempt to mark.

It deletes the attempt's reserved path `<attempt-dir>/issue-{N}-local/disposable/` — the
reproducible output its cycle assets wrote there
([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *How a test is
run is the target's practice*) — and then writes the mark `<attempt-dir>/completed`. Nothing is
moved or archived: the record directory is under the record root, outside every checkout's tree,
from the start, and everything outside the reserved path stays in it — the management files (state
JSON, decision ledger, criterion review, design docs, reports) **and the rest of its cycle-layer
store `issue-{N}-local/`**. A completed attempt is no longer listed as an attempt and is never
entered again. A deletion that fails leaves that attempt unmarked and exits non-zero; re-run it
once the path is removable. A store that is itself a symbolic link keeps its target untouched. It
touches no git ref.

Whether and when it runs is the operator's practice. An attempt left unmarked:

1. stays listed by `cycle-status.sh`;
2. has its pull request looked up on every `cycle-status.sh` run. A lookup that fails is a fact not
   read: the run exits `3`, and the entry for the requested issue, read from the attempt's other
   facts, can name it unread until a run reads the lookup — `none-to-enter <key>:unread`, or
   `stop unreadable <key>` on its checked-out dev branch, for example
   ([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *Modes*);
3. keeps its `issue-{N}-local/disposable/` on disk.

While its pull request can be read, it changes no other issue's entry and no exit code.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path and takes only an attempt's dev branch, checked against the shape
`dev-YYYY-MM-DD-HHMMSS-issue-<N>` (`dev/…` for an attempt made before issue #490) before it becomes the record directory's name
`<record-root>/<repo-key>/<YYYY-MM-DD-HHMMSS>-issue-<N>/` (repo-key = `<org>__<repo>` derived from
`origin` — `<autoflow-root>/scripts/lib/records.sh`), and it refuses an attempt whose `checkout` file
names another checkout. Its one deletion is that reserved path, `issue-<N>-local/disposable`, removed
without following a symbolic link. Allow-list the wrapper
by its absolute path — `Bash(<the AutoFlow root>/scripts/cleanup/cleanup-issue.sh:*)`, the root as `autoflow-root` prints it.

---

<!-- From <autoflow-root>/docs/units/analysis.md -->

# U2 Analysis — DIAGNOSE and GATE:HYPOTHESIS

> Unit document for U2. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

DIAGNOSE and GATE:HYPOTHESIS are one functional unit, U2 Analysis
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed by
four things only — its goal, its artifact contract, its verification and its loop cap (D2) — and
this file states them, with the cautions the analysis is asked to heed and the result it owes. How
the unit reaches the goal — what else it reads and in what order, whether it spawns helpers and what it
gives each, how it keeps the cautions — is the unit agent's, recorded with its grounds in its
artifact ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2).

- **Goal**: the request that triggered the cycle is understood well enough for GATE:HYPOTHESIS to
  score it — the affected structure as it stands, the gap between it and the requested behavior,
  whether a change is owed and whether code is the lever, and the decision points, each conclusion
  with its grounds.
- **Artifact contract**: the analysis report (*Analysis report* below).
- **Verification**: GATE:HYPOTHESIS — a fresh Evaluation AI scores the report on one form for
  every issue, the rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* >
  GATE:HYPOTHESIS: whether the report's conclusion is supported by its grounds and whether the
  analysis met its goal. The unit never scores its own artifact. U2 ends at a `gate_hypothesis`
  PASS (*Verification — GATE:HYPOTHESIS* below).
- **Loop cap**: none counted (issue #421). After a FAIL, what follows is the orchestrator's
  judgment, and the cycle leaves GATE:HYPOTHESIS only on a PASS; a PASS judged unreachable goes, on
  that recorded judgment, to the operator (*Verification — GATE:HYPOTHESIS* below).
- **Result owed**: the report's path and a one-line summary that names any decision point it
  recorded ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Reporting Format). The
  orchestrator does not receive the report's body.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| DIAGNOSE (prerequisite) → orchestrator / advisor | `mode=new-issue` only. The analysis report's `## Decision points` records that a planning/design/ADR prerequisite is clearly required first → the orchestrator decides it on the report's grounds, the advisor where they do not settle it or it is not confident: proceed → GATE:HYPOTHESIS (after a U2 re-run where the analysis stopped at the prerequisite); the prerequisite comes first → the cycle ends with the analysis report (`active:false`, `phase:"awaiting-user"`) — a new issue is filed only on the operator's request; when in doubt, no prerequisite is recorded (`<autoflow-root>/docs/units/analysis.md` > *Report routing*) |
| DIAGNOSE → GATE:HYPOTHESIS | the U2 unit returned, its analysis report carries every required section, and it records no prerequisite (`<autoflow-root>/docs/units/analysis.md` > Unit spawn) |
| GATE:HYPOTHESIS (PASS, `no change needed`) → close / reply / rebuttal | the report concludes the as-is already satisfies the request or nothing is left to do → how the cycle answers it (an already-resolved issue closed, an open PR replied on, a reviewer finding rebutted) is the orchestrator's judgment over the situation, recorded in the ledger (`<autoflow-root>/docs/units/analysis.md` > *Verification — GATE:HYPOTHESIS*) |
| review-response (a repeated complaint) → orchestrator / advisor | whoever reads a reviewer finding — the REVIEW aggregator, or the DIAGNOSE unit — sees it repeat the previous attempt's complaint with a new witness case and records that → the orchestrator decides the re-entry (its depth, or none), the advisor where the grounds do not settle it or it is not confident. No spawn checks for it on every attempt (`<autoflow-root>/docs/units/review.md` > *A repeated complaint*) |
| GATE:HYPOTHESIS → ARCHITECT | PASS + the report concludes `code change` + its recommendations triaged (no attempt open); the hook gates the spawn on the recorded PASS for a bug / incident issue, and `verdict` `skipped (non-bug issue)` admits it for any other |
| GATE:HYPOTHESIS (PASS, `non-code lever`) → orchestrator / advisor | a real gap whose lever is data / configuration / operations → the orchestrator decides it on the report's grounds, the advisor where they do not settle it or it is not confident: a code change is still owed → ARCHITECT; the lever is non-code → the cycle ends with its report (`active:false`, `phase:"awaiting-user"`) |
| GATE:HYPOTHESIS (FAIL) → DIAGNOSE | the re-entry is the orchestrator's judgment over the evaluator's findings, recorded in the ledger — a U2 unit re-run; no count cap, and the cycle leaves GATE:HYPOTHESIS only on a PASS |
| GATE:HYPOTHESIS (a PASS judged unreachable) → advisor / user | the orchestrator judges no re-run will reach a PASS and records that judgment, asking the advisor where it is not confident of it: reachable → a re-run on the answer; not reachable → the operator is asked to confirm closing the issue, the recorded judgment as the direction (`active:false`, `phase:"awaiting-user"`) — the cycle does not close it |

## Unit spawn

- **The spawn.** One `autoflow-unit-analysis` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-analysis` names) at DIAGNOSE entry. The
  prompt states the goal, the cycle's `mode` and
  the report's path, and names the inputs by path: the issue (new-issue) or the review comment /
  thread PREFLIGHT identified (review-response), and the decision ledger
  (`<attempt-dir>/issue-{N}-ledger.md`). In a new-issue cycle it also names the criterion review record
  the ledger's last `[criterion-ready]` entry points at (*Criterion review record* below). In a review-response cycle it also names every artifact the
  previous cycle left (`<attempt-dir>/issue-{N}-c{C}-*.md`) and, where REVIEW's triage wrote one, the
  PR's findings file; how much of the previous analysis the unit reuses is its own, recorded under
  `## Method`. On a re-entry it names what the re-entry is for and the material that carries it
  (*Re-entry* below).
- **Documents.** The unit's agent definition carries the documents the analysis needs (this file, and the
  rubric it is scored on, [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* >
  GATE:HYPOTHESIS) with the rest of its guidance ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection);
  the prompt copies none of them, and the unit reads anything further by its own judgment.
- **Before the gate (orchestrator-side).** The orchestrator confirms the report exists, is
  non-empty and carries every section *Analysis report* lists. A missing one is an infrastructure
  cause: the unit is spawned again with the same inputs, consuming no counter. The return is then
  routed (*Report routing* below).

## What the analysis owes

The analysis is asked for four things, each conclusion with its grounds:

- the affected structure as it currently is, stated as fact;
- the gap between that structure and the behavior the request asks for — and, where the request
  reports a defect, the cause the gap comes from;
- whether a change is owed and, if so, whether a code change is the lever that closes the gap, or
  data, configuration or operations are;
- the decision points — the judgments the working AI is not the one to make.

How far the analysis pursues a cause, and by what means — how many explanations it weighs, which
ones, what it checks and with which tool — is the unit's judgment, recorded with its grounds under
`## Method` and `## Cause`.

The request is the trigger target — the issue, a review comment or thread, or the finding a
re-entry is for — and the as-is is the state it is measured against, which the unit judges from
what it was spawned for and records under `## Method`. The question is whether the as-is already
satisfies the request.

**Cautions.** Each names a bias the analysis is to avoid:

- Describe the current structure as fact, apart from the issue's defect hypothesis — do not read the
  structure to fit the hypothesis.
- A conclusion that a code change is required rests on evidence that the gap is not closed by
  data, configuration, the environment or an earlier fix; a cause that was not established is not
  presented as one.
- The necessity judgment is reuse-neutral: a resolution that uses existing code is not marked down
  for it. Structural fit and over-engineering are GATE:PLAN's and GATE:QUALITY's.
- Open every material the issue body or an acceptance criterion references — a design mockup, an
  asset, an external document — yourself; one that cannot be opened is recorded with the reason.

How the unit guards against these biases — whether it separates the structure reading from the
issue reading, in what order it reads, what it gives or withholds from a helper — is its own,
recorded with its grounds under `## Method`.

The rules below are the ones other documents cite; everything else about the work is the unit's.

- **Acceptance criteria.** The report's `## Acceptance criteria` table is the issue's single
  machine-addressable acceptance-criterion list; an absent or unparseable table is itself a finding
  downstream ([U3 Design](<autoflow-root>/docs/units/design.md) > *Report routing*;
  [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:PLAN > *AC-authority check*). **[MUST]** It is authored once per issue, in the `mode = new-issue` cycle;
  a review-response cycle carries the previous cycle's table forward unchanged — a review comment
  never edits the list; only an `[ac-decision]` ledger entry does
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*; `<autoflow-root>/docs/core.md` > Decision Ledger).
- **Criterion review record** (`mode = new-issue`). The issue's criteria were reviewed against the
  code and policy in the attempt's criterion review stage, and the review's settled decisions were
  recorded in a `[criterion-ready]` entry before PREFLIGHT wrote the state file
  ([`criterion-review.md`](<autoflow-root>/docs/criterion-review.md)); the record that review left is an input,
  not a verdict. The analysis reads its findings as an earlier reading of the code and policy at the
  commits its `## Inputs` names: a finding the analysis builds on — a confirmed cause, a policy it
  cites — is checked at the cycle's base, and a difference from the record is recorded with its
  grounds. The record changes nothing about how the criteria are taken: the `## Acceptance criteria`
  table restates the issue's criteria as the body that entry records states them, the analysis does not run
  the review again (issue #291: DIAGNOSE takes the criteria as written), and a defect it observes as
  a fact is still raised as a decision point on the in-cycle path
  ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > Decision-point entries > *A criterion can be
  wrong*). The record's findings are the reconciled ones: `## Screening` lists each case a
  criterion applies to with the code that decides it, and `## Cause reach and rule conflict` where
  a confirmed cause reaches beyond the reported points or a required behavior meets a rule in force,
  each read like the findings as an earlier reading; `## Reconciliation` records, per stage 2
  finding and per in-depth case, whether it was applied, rejected or left unresolved. The record's `## Unchecked` items, and each case left `unresolved`,
  are findings the analysis may close with its own checks (*Checking a finding* below). How the
  record was used is recorded under `## Method`.
- **Referenced materials.** Each material is recorded under `## Referenced materials` — what it is,
  where it is, how it was opened, and what it shows for the criterion that names it; the material,
  not an abbreviated example in the body, is what the criterion means. **[MUST]** A material
  recorded `not opened: <reason>` is raised to the operator before the cycle leaves DIAGNOSE
  (`<autoflow-root>/docs/core.md` > Flow Control > *tool or referenced material → user*;
  [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *The tools
  the work needs*).
- **Checking a finding.** A finding the analysis checks is checked with what the environment and the
  target's documents and scripts provide — API calls, queries, service status, logs — and those tools
  are looked for before a finding is left unchecked; a tool that is off is started by the target's
  own procedure, and one that needs the operator is requested (*The tools the work needs*). The
  report records each tool a conclusion rests on and whether it was usable; a finding left unchecked
  names the tool it needed.
- **Scope judgments.** Beyond the acceptance criteria, the analysis names the problems the confirmed
  cause carries — its other sites, and what fixing it will expose — with the scope judgment for each
  and its grounds ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface
  Rules > *Scope judgment*). ARCHITECT reads them and settles the cycle's scope in the feature
  design's `## Scope` section; the analysis does not decide it alone.
- **Decision points.** A judgment the working AI is not the one to make is recorded under
  `## Decision points` with its grounds, and the orchestrator routes it (*Report routing*): a
  planning, design or ADR prerequisite clearly required before the issue can be implemented
  (`mode = new-issue`; when in doubt, none); a request the as-is already satisfies; a gap or a cause
  whose lever is not code; on a reviewer finding, one that repeats the previous
  attempt's complaint with a different witness case ([U7 Review](<autoflow-root>/docs/units/review.md) > *A repeated
  complaint*). A suggested split of the issue stays a suggestion: it is filed only on
  the operator's request, through a draft and `<autoflow-root>/scripts/issue/create-issue.sh`
  ([`issue-proposal.md`](<autoflow-root>/docs/issue-proposal.md)).

## Analysis report

`<attempt-dir>/issue-{N}-analysis.md`. The unit writes it whole on its first run and brings it up to
date on a re-entry. Every section below is present; a section with nothing to record says `none`.

| Section | Holds | Read by |
|---|---|---|
| `## Method` | how the analysis was done — the reading order, any helper spawn and what it was given — and how each caution was kept, with grounds | GATE:HYPOTHESIS |
| `## Current structure` | the affected area as it stands — its structure, design intent and data flow — stated as fact | GATE:HYPOTHESIS |
| `## Request` | the concrete cases the request names, the problem type they share, and the resolution approaches it calls for | GATE:HYPOTHESIS |
| `## Acceptance criteria` | a table with the fixed columns `AC id \| criterion \| source`: `AC id` a short readable name unique within the issue, `criterion` the issue's criterion restated faithfully, `source` its place in the issue body | ARCHITECT, GATE:PLAN, BUILD, GATE:QUALITY |
| `## Referenced materials` | each material the issue or a criterion references, as *What the analysis owes* says, or `none` | ARCHITECT (*Tools*) |
| `## Necessity` | whether the issue is a bug / incident; per resolution approach, the behavior gap and whether code is the lever, with grounds; and the conclusion, exactly one of `no change needed` (the as-is already satisfies the request, or nothing is left to do), `non-code lever` (a real gap whose lever is data / configuration / operations) or `code change` | GATE:HYPOTHESIS; the orchestrator (*Verification — GATE:HYPOTHESIS*) |
| `## Cause` | where the request reports a defect, the cause the analysis established and the evidence for it, how far the cause was pursued and why — or, where it is not established, what is known and what was left unchecked; otherwise `none` with the reason | GATE:HYPOTHESIS |
| `## Scope judgments` | each scope judgment, as *What the analysis owes* says | ARCHITECT; GATE:QUALITY `Minimal implementation`, `Impact scope` |
| `## Affected documents` | the documents the change is expected to update | ARCHITECT; BUILD (spawn prompt) |
| `## Decision points` | each decision point with its grounds, or `none` | the orchestrator (*Report routing*) |

Anything else the unit records is its own, written where it judges useful.

## Report routing

- **A prerequisite** (`mode = new-issue`) → the orchestrator decides it on the report's grounds,
  recorded in an `O` ledger entry; where those grounds do not settle it, or it is not confident, the
  advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor), the report as the request's
  anchor, written situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles >
  *Human-decision presentation*).
  **Proceed** → GATE:HYPOTHESIS, after a unit re-run naming the decision's entry where the analysis
  stopped at the prerequisite; **the prerequisite comes first** → the cycle ends with `active:
  false`, `phase: "awaiting-user"`, the report and the decision's record as its report. No counter.
- **A repeated complaint** (a reviewer finding) → the orchestrator decides the re-entry — its
  depth, or none — the advisor where the grounds do not settle it ([U7 Review](<autoflow-root>/docs/units/review.md) > *A
  repeated complaint*). A redefined criterion comes
  back as `[ac-decision]` entries and a unit re-run on them. No counter.
- **Otherwise** → GATE:HYPOTHESIS: one fresh Evaluation AI scores the report. The dispositions — a
  request needing no change, a non-code lever, a FAIL, a PASS judged unreachable — are
  *Verification — GATE:HYPOTHESIS*'s (below); a decision point the report records is confirmed by the
  gate's PASS before any close or end.
- **A material not opened, or a tool the analysis needs that neither this environment nor the
  target's procedures provide, or what using a tool the environment has lacks** — a harness-level block → the operator, situation-first
  (`awaiting-user`; `<autoflow-root>/docs/core.md` > Flow Control > *tool or referenced material → user*).

## Verification — GATE:HYPOTHESIS

One independent Evaluation AI (`autoflow-evaluator`), fresh-spawned per entry on the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-hypothesis` names, scores the report on the
rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:HYPOTHESIS — one
form for every issue. Its agent definition carries that document. The orchestrator records the
scores under `phases.gate_hypothesis`, with the `verdict` `pending` → `evaluated` for a bug /
incident issue and `skipped (non-bug issue)` otherwise ([`core.md`](<autoflow-root>/docs/core.md) > AutoFlow
State Tracking > `verdict` rule). The hook gates the ARCHITECT spawn on the recorded PASS for a bug
/ incident issue only; for any other issue the orchestrator judges the PASS line itself: each ≥ 7,
avg ≥ 7.5.

**PASS** → recommendation triage ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) >
*Recommendation triage*) → the route the report's `## Necessity` conclusion names:

- **`no change needed`** → no change is made. How the cycle answers the conclusion — closing an
  issue that was already resolved, replying on an open PR, rebutting a reviewer finding a re-entry
  examined ([U7 Review](<autoflow-root>/docs/units/review.md) > *Whether a finding holds*) — is the orchestrator's judgment
  over the situation, recorded with its grounds in the ledger ([`core.md`](<autoflow-root>/docs/core.md) > Rule
  Scope, principles 2–3). Before it closes an issue, the orchestrator confirms the recorded
  `phases.gate_hypothesis` scores meet the PASS line and the report's conclusion is `no change
  needed`; the close comment records those scores and a summary of the existing mechanism.
- **`non-code lever`** → the orchestrator decides it on the report's grounds, the advisor where they do not settle it or it is not confident
  ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor). **A code change is still owed** → ARCHITECT; **the lever is non-code** → report the
  finding situation-first ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision
  presentation) — where a PR is open, as the PR reply — and end the cycle with
  `active: false`, `phase: "awaiting-user"`.
- **`code change`** → ARCHITECT.

**FAIL** → what follows is the orchestrator's judgment over the evaluator's findings, recorded with
its grounds in the ledger — a U2 unit re-run naming the findings and the previous report (*Re-entry*
below) is the usual route. No count caps it: the cycle leaves GATE:HYPOTHESIS only on a PASS.

**A PASS judged unreachable** → when the orchestrator judges that no re-run will bring the report
to a PASS — the re-runs do not converge, or the request cannot be brought to a supported conclusion
— it records that judgment with its grounds in the ledger, and asks the advisor where it is not
confident of it. **Reachable** → a re-run on the answer. **Not reachable** → the issue is not
closed by the cycle: the operator is asked to confirm closing it, situation-first, with the recorded
judgment as the direction (`active: false`, `phase: "awaiting-user"`). This differs from `no
change needed`, whose close the orchestrator makes without the operator's confirmation.

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-analysis` by
*Unit spawn* above, whose prompt names what the re-entry is for, the material that carries it, and
the report so far. The report is brought up to date, not rewritten; its `## Acceptance criteria`
table changes only by an `[ac-decision]` entry, which the orchestrator applies.

| Re-entry | Material named | Counter |
|---|---|---|
| GATE:HYPOTHESIS FAIL | the evaluation report and its failed items | none — the orchestrator's judgment (*Verification — GATE:HYPOTHESIS* above) |
| a recommendation attempt at GATE:HYPOTHESIS routed to the analysis | the recommendation's subject and finding | the attempt window (max 7×) |
| an advisor answer or operator override that reaches the analysis | the `A` / `O` entries | none |

A re-entry passes through GATE:HYPOTHESIS again on its re-score
([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:HYPOTHESIS > *Re-entry re-score*). The unit reads and writes no
`<attempt-dir>/issue-{N}.json` state file, so the counter above is the orchestrator's own accounting.

## Spot-check & escalation discipline (incomplete-output guard)

A DIAGNOSE spot-check is an orchestrator read that confirms a finding of the
analysis report before it feeds a routing decision, a blocker, or a user escalation. A Claude
Code behavior produces a **false "absent / stub" reading**:

- **Read-dedup stub.** A re-read of an unchanged file returns a 1-line stub ("file
  unchanged … refer to that earlier tool_result"), and the dedup ledger is not reset on a
  rewind (or a compaction). The `Read` PostToolUse hook (`<autoflow-root>/hooks/check-read-dedup.sh`) flags this
  at runtime — these rules are the procedure it points to.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a routing decision or a
  user escalation**. A single read is never sufficient grounds.
- **[MUST]** A blocker/escalation-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool.
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged`). It is a harness stub, not
  data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after the unit has returned**, as single
  sequential commands. Another
  directory is addressed with `git -C <path>` + absolute paths rather than a
  `cd`-prefixed compound, which can raise a permission prompt.

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

<!-- From <autoflow-root>/docs/units/design.md -->

# U3 Design — ARCHITECT and GATE:PLAN

> Unit document for U3. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

ARCHITECT and GATE:PLAN are one functional unit, U3 Design
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1). The unit is prescribed
by four things only — its goal, its artifact contract, its verification and its loop cap (D2) —
and this file states them, with the cautions the design is asked to heed and the result it owes.
How the unit reaches the goal — what else it reads, whether it spawns helpers, whether it asks a critic
to challenge a draft or holds a dialogue at all, how it designs this issue's own verification — is
the unit agent's, recorded with its grounds in its artifact ([`core.md`](<autoflow-root>/docs/core.md) > Rule
Scope, principle 2).

- **Goal**: a design the build unit can implement and verify — the architecture decisions with
  the constraints they hold under and the alternatives rejected, and a verification design that
  says how each acceptance criterion is verified and which failure mode each verification catches.
- **Artifact contract**: the two documents under *Output artifacts* below.
- **Verification**: GATE:PLAN — a fresh Evaluation AI scores the two documents on the rubric of
  [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:PLAN; the unit never
  scores its own artifact (*Verification — GATE:PLAN* below).
- **Loop cap**: a GATE:PLAN FAIL re-runs the unit with the evaluator's findings and the previous
  documents (*Re-entry* below), max 3× (`<autoflow-root>/docs/core.md` > Flow Control > Regressions).
- **Result owed**: the two artifact paths and a one-line summary
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Reporting Format). The
  orchestrator does not receive the design's body.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| ARCHITECT → GATE:PLAN | the feature design's `## Decision requests` section says `none` (a reduced verification disposition carrying a stated reason is not a request — `<autoflow-root>/docs/units/design.md` > *Report routing*), and the verification design's `## Tools` section carries no `operator` item |
| ARCHITECT (design point) → advisor | the `## Decision requests` section names a design point the unit did not settle → the advisor decides; the answer is an `A` entry, and the cycle continues to GATE:PLAN where it is the option the design took, otherwise to a unit re-run on the answer — consuming no re-entry budget (ARCHITECT > *Report routing*) |
| ARCHITECT (acceptance-criterion content change) → orchestrator / advisor | the `## Decision requests` section proposes excluding, revising or splitting an issue acceptance criterion, or adding one → the orchestrator decides it before GATE:PLAN is spawned, and puts it to the advisor only where the proposal's grounds do not settle it or it is not confident; the decision is recorded as `[ac-decision]` entries (`<autoflow-root>/docs/decision-ledger.md`) and the cycle continues to GATE:PLAN — or, where the decision differs from the proposal, to a unit re-run on the entries — consuming no re-entry budget |
| GATE:PLAN → BUILD | plan evaluation PASS + its recommendations triaged (no attempt open) |

## Unit spawn

- **The spawn.** One `autoflow-unit-design` (`Agent`, anonymous, no `name`, the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model unit-design` names). The prompt states the goal
  and names the inputs by path — the acceptance-criterion list
  (`<attempt-dir>/issue-{N}-analysis.md` > `## Acceptance criteria`), the decision ledger
  (`<attempt-dir>/issue-{N}-ledger.md`), the DIAGNOSE artifact (`<attempt-dir>/issue-{N}-analysis.md`, the
  GATE:HYPOTHESIS reports) — and the two output paths. On a re-entry it also names what the
  re-entry is for and the previous documents (*Re-entry* below).
- **Documents.** The unit's agent definition carries this file and the rubric it is scored on with
  the rest of its guidance ([`core.md`](<autoflow-root>/docs/core.md) > Context Injection); the prompt names the target's documents the design needs by path (e.g. the relevant
  `docs/records/adr/*`, `docs/records/design-rationale.md`), and the unit reads anything further its
  design needs, by its own judgment.
- **Before the gate (orchestrator-side).** The orchestrator confirms
  `<attempt-dir>/issue-{N}-feature-design.md` and `<attempt-dir>/issue-{N}-verification-design.md` exist
  and are non-empty, the feature design carries its `## Decision requests` section and the
  verification design its `## Tools` section. A missing or empty one is an infrastructure cause:
  the unit is spawned again with the same inputs, consuming no counter. The return is then routed
  (*Report routing* below).

## Output artifacts

1. **Feature Design Document** — `<attempt-dir>/issue-{N}-feature-design.md`, the
   **architecture decision layer** and nothing below it: the decisions, the constraints
   they hold under, and the alternatives considered and rejected with the ground for each rejection.
   It cites the verification design's `Failure mode` column (below) for the failure mode each
   verification exists to catch, rather than stating it.

   **[MUST]** The document carries a `## Scope` section: the cycle's scope beyond the acceptance
   criteria. Each problem judged under
   [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope
   judgment* — DIAGNOSE's `## Scope judgments` and any the design found — is listed as
   included or separated, with the conditions it meets and, for a directly related problem left
   out, its separation reason. A section with nothing beyond the criteria says `none`. Scope is a
   decision, settled here, not derived below.

   **[MUST]** The document carries a `## Decision requests` section: each decision the design
   needs that is not the unit's to make, one entry each, written situation-first
   ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Human-decision presentation*) —
   - an **acceptance-criterion content change** — excluding, revising or splitting an issue
     acceptance criterion, or adding one: the criterion, the proposed change and the fact that
     shows the need ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion
     decisions*);
   - a **design point** the unit is not confident to settle, or whose choice is not its own
     ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3): the options and what each changes.

   A design with no such request says `none`. The unit designs on its proposal and states the
   proposal as pending; it never applies an acceptance-criterion change itself.

   **[DENY]** The document does not carry a change table of files, a per-suite disposition, or an
   oracle's condition clause. Those are **derived at BUILD** by the build unit — from
   the change delta, run the way the target runs its tests ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) >
   Verification and Tools > *How a test is run is the target's practice*; on an opted-in target the selector
   answers which committed suites the delta reaches), and from the files the build opens to change anyway. The dividing line is one question: **would this
   sentence being wrong mean the design has to be revisited, or would it just be fixed where it is
   found?** The first belongs to the design; the second does not. A derivation BUILD produces
   under this clause is not acceptance-criterion drift — GATE:QUALITY's Completeness check states
   that exemption explicitly.

2. **Verification Design Document** — `<attempt-dir>/issue-{N}-verification-design.md`. The
   `Issue AC` join key is **not** reduced by the layer split above: the per-criterion disposition is
   a design output. What the split removes from it is depth, not rows: `Method` names the **kind**
   of oracle a row gets, and the condition clause that implements it is BUILD's. The table's columns
   are what the downstream readers need — GATE:PLAN's AC-authority check joins on `Issue AC`, the
   AUDIT evaluator reads `Kind` for its test-first judgment, GATE:QUALITY reads `Type`, and HANDOFF carries each reduced disposition and its
   `Reason` into the PR body; how each row is reached is the unit's.

| Issue AC | Acceptance criterion | Type | Kind | Method | Failure mode | Reason |
|----------|----------------------|------|------|--------|--------------|--------|
| AC1 | (criterion 1) | automated | driving | pytest / API test / etc. | the defect only this test fails on | — |
| AC2 | (criterion 2) | existing-coverage | — | the schema check that already rejects this shape | a value of the shape this criterion forbids | the check runs on every build |
| AC3 | (criterion 3) | manual | — | AI: `<tool in ## Tools>` — scenario doc; the result compared against the referenced material | the behavior the scenario observes breaking | no executable assertion states it; the AI observes it with the tool `## Tools` records |
| AC4 | (criterion 4) | none | — | — | — | absence costs nothing: the value is read from a sample file the user edits |
| — | (criterion 5) | environment-dependent | — | introduce mock or propose design change | the failure the mock itself can catch (`—` on a design-change request) | — |

- **`Type` is the per-criterion verification disposition**, one of
  `automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
  `none`. An `automated` or `manual` row is `cycle` — executed once, uncommitted under
  `<attempt-dir>/issue-{N}-local/`, its run recorded. **In this repository only**, the same cell also
  carries the row's **layer**: a row is `standing` (committed; CI-registered) when the
  cell names one of D1's closed tokens in the form `automated / standing: <token>`
  (`manual / standing: <token>`); the token list is ADR-0024 D1's and is not copied here, and a
  token outside it is a layer violation ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:QUALITY > *Test quality — layer violation*). On a
  target the cell carries no layer token ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *What a cycle
  leaves in the target's tree*). `Kind`
  applies to `automated` rows only (`driving` / `regression` / `characterization`). Both
  vocabularies, and when each disposition is the right answer, are defined once at *Test necessity*
  below.
- **`Issue AC` is the join key.** Each row's value is either an `AC id` from the
  `## Acceptance criteria` table in `<attempt-dir>/issue-{N}-analysis.md`, or `—` for a criterion this
  verification design added on its own. **[MUST]** Every AC id in that table gets a row, and a
  criterion the design verifies by anything other than an automated test keeps its row, states that
  disposition, and states its `Reason` in one line — the row is never deleted. A design-added
  criterion (`—`) is never a finding and owes no reason; each problem the feature design's
  `## Scope` section includes gets one.
- **`Failure mode` holds each verification's unique failure mode**, and this bullet is the only
  place that obligation is defined. The cell names the defect that makes the row's verification
  fail and that no other verification catches. On an `existing-coverage` row it names what the
  named mechanism fails on, and `Reason` says why no new layer is owed without restating that
  failure. On an `environment-dependent` row resolved to a mock, it names the failure the mock
  itself can catch, not the environment behavior the mock stands in for.
  - **Row grain** — one row per verification: a criterion verified more than one way carries one
    row per verification under the same `Issue AC`, and every other criterion keeps its one row. A
    verification that spans rows carries the same label in `Method` on each of them.
  - **Compared against** — every other distinct verification in the design, and every existing
    mechanism that fails on the same defect: an existing test, a lint rule, a schema, a compiler or
    type check, a build or packaging check. Naming such a mechanism is the `existing-coverage`
    disposition (*Test necessity* below).
  - **[MUST] Owed** on `automated`, `existing-coverage`, `delivery-check` and `manual` rows, and on
    `environment-dependent` rows resolved to a mock or a manual delegation. `none` and
    design-change-request rows carry `—`.
  - **A cell that cannot be filled** — the verification names no defect that another verification
    or mechanism does not already catch — removes that verification from the design.

- For untestable items: first find the tool that verifies the item directly (*Tools* below); only when none can be secured, state the reason and the alternative (design change / a `manual` row executed by a person / mock). When an item is not automatable, consider first whether a feature-design change makes it testable.
- Design-change request: parts of the feature design that should be revised so they become testable.

### Test necessity

A test exists only when it is needed. The burden of proof lies on the test, never on its absence:
not writing a test needs no justification, and a proposed test that cannot answer both judgments
below is not written. This clause decides **existence** only — whether a criterion is verified at
all. Whether a verification **stays in the repository** is decided by ADR-0024 D1's closed
`standing` list and by nothing else: a stated reason, however good, does not move a row out of the
`cycle` layer. This clause is
the policy body; every other document references it rather than restating it.

- **[MUST]** Each proposed verification answers two judgments, in the row that carries it:
  1. **Required behavior** — is this a behavior or contract a consumer actually requires, as
     opposed to an imagined failure mode?
  2. **Cost of absence** — if no verification exists and this breaks after merge, who loses what,
     concretely?
- **[MUST]** When the two judgments cannot both be answered, the disposition is `none`.
- Necessity is a **judgment**, not a classification: no subject is exempt by category and none is
  obligated by category. The two guidance notes below are that judgment applied to two areas —
  they are not separate rules.

**Verification disposition** (the `Type` of each acceptance-criteria row):

| Disposition | Meaning |
|---|---|
| `automated` | an executable test — `cycle` by default (run once from `<attempt-dir>/issue-{N}-local/`, its run recorded), `standing` only with a D1 token in the cell |
| `existing-coverage` | already detected by an existing test, lint rule, schema, compiler/type check, build or packaging check — the row names which |
| `delivery-check` | a one-shot check that the change was wired / generated / delivered — a `cycle` artifact under `<attempt-dir>/issue-{N}-local/`, never committed; the test-first rule does not apply to it |
| `manual` | a scenario verified by observation, not by an executable assertion; `Method` names its executor — `AI: <tool>`, the tool the `## Tools` section records, or `person` only when no tool can be secured, the `Reason` saying why (*Tools* below); the row names the checklist — a `cycle` artifact unless the cell carries a D1 token |
| `environment-dependent` | verifiable only against an environment this cycle cannot drive with the tools the `## Tools` section records |
| `none` | no persistent verification has positive value — the row states why absence costs nothing |

- **[MUST]** Every disposition other than `automated` on an **issue** AC row carries a one-line
  `Reason`. A row for a design-added criterion (`Issue AC` = `—`) is never a finding and needs no
  reason.

**Test kind** (the `Kind` of each `automated` row, and the test-first expectation for it —
[U4 Build and verify](<autoflow-root>/docs/units/build.md) > *What the build owes*):

| Kind | Meaning | Before the implementation |
|---|---|---|
| `driving` | a required behavior not yet implemented | must FAIL before the implementation |
| `regression` | reproduces a known defect | must FAIL before the fix |
| `characterization` | records existing behavior the change must preserve | may PASS from the start |

**Configuration and data.** A value is not a required behavior; the behavior that consumes it is.
Whether
"production config boots the app" or "every reference resolves" deserves a test is decided by the
two judgments above, not by the subject being data.

**Implementation internals.** A helper name, call order, private branch or internal representation
is not a required behavior. Production code gains no interface, indirection or dependency injection solely to fit
a test shape.

### Verification depth

- **[MUST]** The verification design opens with a **risk line** — one line naming
  who is harmed and how if this change is wrong.
  Depth is justified against that risk, and this clause sets a justification form, never a quantity
  cap: no layer count, file count, or line budget.
- **Per-verification failure mode** — carried by the acceptance-criteria table's `Failure mode`
  column. The column's bullet under *Output artifacts* above defines what the cell names, what it
  is compared against and what a cell that cannot be filled means.
- **[MUST]** State the determination once in the verification design, and restate no
  verification's failure mode anywhere outside the `Failure mode` column; narrative that states no
  per-layer failure mode (a layer removed, depth added) may stay. The obligation is
  unconditional — every verification design has at least one layer — so an absent statement is a
  missing obligation, not a "not applicable". A risk found later raises depth at a re-entry, with
  its reason stated in the delta (*Re-entry* below).

### Tools

The rule is [`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *The tools the work needs*;
this clause is where the verification design applies it. The design opens the materials
the analysis report's `## Referenced materials` section lists ([U2 Analysis](<autoflow-root>/docs/units/analysis.md) >
*What the analysis owes*) — the material, not the issue body's abbreviated example, is the
design's input — and finds, for each criterion, the tool that verifies it directly **before**
settling it as a `manual` row executed by a person, as `environment-dependent`, or on a mock.

- **[MUST]** The verification design carries a `## Tools` section: one line per tool — the tool,
  the rows it verifies (or the design question it serves), its availability, and the ground the
  availability rests on. Availability is one of `available` (usable in this environment now),
  `target procedure: <document section or script>` (off, and the target carries the procedure that
  starts it), or `operator: <what is needed>` — what is missing for the tool to be used: the tool
  itself when this environment does not have it (an installation, enabling an MCP server or a
  browser extension), what using a tool the environment has lacks (access, the purpose and
  permitted scope of the host or service it reaches, a credential, a permission setting), or access
  to a material. The item names what is missing, never the output the tool would give; a tool the
  environment has, whose use lacks nothing, is `available`. A design that needs no
  tool says `none`, with its ground in one line. AutoFlow names no tool here: which tool, and how
  it is used, is the design's judgment in the target.
- **Availability is settled here, not at BUILD.** After the unit returns, the orchestrator reads
  this section — a targeted excerpt, not a full read ([`core.md`](<autoflow-root>/docs/core.md)
  > Cost Control > *Orchestrator context discipline*) — before GATE:PLAN. An `operator` item is the
  tool request pause ([`core.md`](<autoflow-root>/docs/core.md) > Flow Control > *tool or referenced material →
  user*), presented situation-first, and GATE:PLAN is not spawned until the operator answers. A
  `target procedure` item is started when the phase that uses it begins — by the orchestrator when
  the tool must outlive a role spawn. A tool found missing later, at BUILD, takes the same pause.
- A criterion for which no tool can be secured — what is missing (the tool, or what using it
  lacks) was requested and the operator answers that it cannot be provided, or no tool exists that
  verifies the criterion — keeps the fallbacks of the untestable-items bullet above — a `manual` row executed by a person, or a mock — and its `Reason` states why no
  tool could be secured; GATE:PLAN's `Verification fit` reads that reason.
- The row verified with a tool is looked at with it once implemented, and the evidence is the row's
  observation record, written at BUILD ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > Build report > `## Manual checklist`).

## Report routing

The orchestrator routes the unit's return. It reads two targeted excerpts — the verification
design's `## Tools` section and the feature design's `## Decision requests` section — and never
reads the design to judge it: the full read-and-score is GATE:PLAN's.

- **An `operator` item in `## Tools`** — the tool request pause (*Tools* above).
- **`## Decision requests` says `none`** — GATE:PLAN (*Verification — GATE:PLAN* below). A
  GATE:PLAN FAIL re-runs the unit (*Re-entry* below); that is the existing
  `GATE:PLAN FAIL → ARCHITECT (max 3×)` re-entry.
- **An acceptance-criterion content change is requested.** Excluding, revising or splitting an
  issue acceptance criterion, or adding one, is never the design's to apply. The orchestrator
  decides it first from the section's entry — the affected criteria, what the design proposes for
  each and its grounds; where those grounds do not settle it, or it is not confident, it writes the
  advisor request situation-first from the same entry with its own reading, and the advisor's
  answer is the decision ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor). It does not spawn
  GATE:PLAN until the `[ac-decision]` entries — one per decided AC in the grammar at
  [`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions* — are recorded;
  on `revised`, `split` or `added`, it edits the analysis report's acceptance-criterion table to match. It then
  continues to GATE:PLAN where the decision is the design's proposal, or re-runs the unit on the
  `[ac-decision]` entries where it differs (*Re-entry* below). Neither consumes ARCHITECT re-entry
  budget.
- **A design point is requested.** The orchestrator hands it to the advisor situation-first; the
  answer is an `A` ledger entry. Where the answer is the option the design took, GATE:PLAN follows;
  otherwise the unit re-runs on the answer (*Re-entry* below). Neither consumes a counter.
- **An acceptance-criterion change raised later in the cycle.** The BUILD unit, when its work shows a
  criterion defective — a fact it presumes that does not hold, or a scope too narrow or too wide for
  the problem ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*) —
  raises it in its report with the criterion, the proposed change and the fact that shows the need
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*); a gate recommendation reaches the same point through the triage
  ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*). The orchestrator decides it as above,
  the advisor where the raised grounds do not settle it; the entries use the same grammar with the
  phase the change surfaced in, and the orchestrator edits the analysis report's table on `revised`, `split` or `added`. Where
  the cycle then re-enters is the orchestrator's judgment, recorded with its grounds in an `O`
  ledger entry: at ARCHITECT, a unit re-run naming the `[ac-decision]` entries, when a
  verification-design row must be added or rewritten — then GATE:PLAN's re-entry re-score and BUILD;
  at BUILD when only the implementation changes; otherwise at the point the question arose. A return to ARCHITECT on this ground
  consumes no re-entry budget.

**What the advisor is asked, and what it is not.** A reduction in *verification method* — an AC
verified by an existing mechanism, a manual scenario, a delivery check, or by nothing at all — is a
verification-method choice, not a change to the criterion. It passes three tiers, and only the third
changes the criterion:

1. **Design (ARCHITECT).** The design unit chooses any disposition in the *Test necessity*
   vocabulary for an issue AC, **with its reason stated in that row**; GATE:PLAN scores the reason.
2. **Reviewer (REVIEW).** Every reduced disposition and its reason is carried into the host
   PR body ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *Push and pull request*), so the reviewer judges each one on its stated reason.
3. **Criterion decision.** The orchestrator decides, the advisor where it cannot settle it, when
   the AC's **content** must change — at ARCHITECT or later in the cycle
   (*An acceptance-criterion change raised later in the cycle* above). The options are
   exactly these: exclude the criterion, revise it in the proposed form, split it into a separate
   issue, or add a criterion the issue did not state.

Whether a row verifies the property its AC states is not a tier-3 question — that judgment belongs
to GATE:PLAN `Verification fit` and to GATE:QUALITY's assertion-claim alignment.

## Verification — GATE:PLAN

One fresh Evaluation AI (`autoflow-evaluator`, the model
`bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model gate-plan` names) scores the two documents on the
rubric of [`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > *Gate rubrics* > GATE:PLAN. Its
agent definition carries that document.

- **PASS** (avg ≥ 7.5, each ≥ 7) → recommendation triage
  ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) → BUILD.
- **FAIL** → ARCHITECT (max 3×): a fresh U3 Design unit receives this report and the previous
  documents (*Re-entry* below).

## Re-entry

No unit agent's lifetime spans a spawn: every re-entry spawns a fresh `autoflow-unit-design` by
*Unit spawn* above, whose prompt names what the re-entry is for, the material that carries it, and
the previous documents.

| Re-entry | Material named | Counter |
|---|---|---|
| GATE:PLAN FAIL | the evaluation report and its failed items | ARCHITECT re-entry (max 3×) |
| advisor answer that differs from the design (*Report routing*) | the `[ac-decision]` or `A` entries | none |
| BUILD design contradiction | `<attempt-dir>/issue-{N}-green-blocker.md` | ARCHITECT re-entry |
| `design` re-entry from GATE:QUALITY or HANDOFF's CI failure | the failed items and their findings | ARCHITECT re-entry |
| acceptance-criterion decision raised after ARCHITECT | the `[ac-decision]` entries | none |
| `design`-class gate recommendation at AUDIT or GATE:QUALITY ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) | the recommendation's subject and finding | ARCHITECT re-entry |

- **[MUST] A re-entry's output is a delta, never a rewrite.** The first unit run of a cycle writes
  the two documents whole. A re-entry within the cycle **appends** to each document it changes a
  section

  ```
  ## Delta — round <n> (<origin: GATE:PLAN FAIL | advisor answer | BUILD design contradiction | design re-entry | acceptance-criterion decision | gate recommendation>)

  - <what changed>: <the decision as it now stands> — supersedes <the section or decision it replaces>
  - <what was added>: <the decision> — <ground>
  ```

  and leaves text the round did not change exactly as it stands. A delta item that corrects a
  decision under the verified-error exception ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) >
  Entries) also carries the reproducing command and its summary line. Two sections are the exception:
  the feature design's `## Decision requests` and the verification design's `## Tools` are the
  orchestrator's routing inputs, not decisions, so a re-entry rewrites each in place to its current
  state — a request the advisor has answered is removed (its answer is the ledger entry), a new one
  is added, and `none` means none is open. The delta section is GATE:PLAN's
  narrowed input on re-entry ([`evaluation-system.md`](<autoflow-root>/docs/evaluation-system.md) > GATE:PLAN >
  *Re-entry re-score*); a re-entry after
  BUILD began re-scores that delta and the cycle re-enters BUILD.
- **A new cycle writes new documents.** A review-response cycle entered at PREFLIGHT finds the
  previous cycle's documents preserved as `issue-{N}-c{C}-feature-design.md` / `issue-{N}-c{C}-verification-design.md`
  ([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *Review-response setup*); the prompt names them and
  what the new cycle is for, and the unit writes the new cycle's documents whole. How much
  of the previous cycle's design the new one carries over is the unit's own, recorded in the design.

The unit reads and writes no `<attempt-dir>/issue-{N}.json` state file, so the ARCHITECT re-entry
counter is the orchestrator's own accounting (Regressions, [`core.md`](<autoflow-root>/docs/core.md) >
Development Lifecycle).

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
  own definition — `<autoflow-root>/docs/core.md` > Instruction Conventions and Rule Scope, by
  which they are read, `<autoflow-root>/docs/core.md` > Commit Rules, `<autoflow-root>/docs/submodule-common-rules.md` >
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

<!-- From <autoflow-root>/docs/role-contracts.md > Role Vocabulary and Spawn Mode > Model tier revert -->

### Model tier revert

**[MUST]** Revert a phase to the higher tier — updating `.claude/autoflow/spawn-policy.json` in the same commit — when a lower-tier gate's PASS is materially contradicted within the same cycle: a defect that gate's rubric covers surfaces through an AUDIT test-first finding, an AUDIT block, or a reviewer-review Medium+ finding on the same surface. A lower-tier **role spawn** is covered on the same terms: the exit claim it returns — a unit's artifacts done — stands where a gate's PASS stands, and the contradicting signal is the next check's finding on what it produced in the same cycle (AUDIT, GATE:QUALITY), or a reviewer-review Medium+ finding on that artifact. These signals persist in the GitHub PR/issue thread, which serves as the evidence anchor for the revert.

A change to the per-phase assignment follows the revert rule above.

---

<!-- From <autoflow-root>/docs/evaluation-system.md > Gate rubrics > GATE:QUALITY > Known blind-spot checks > Impact scope / Doc updates — reference integrity on moves -->

- **Impact scope / Doc updates — reference integrity on moves**: when the diff relocates
  or renames files, sections, or identifiers, require evidence of a repo-wide
  inbound-reference sweep (direct references, test-harness expectations, paraphrased
  mentions). A dangling reference in a **normative document** caps the affected item at 6.
  The cap binds normative documents only; a stale name in a **historical record** is the
  evaluator's judgment.
  - *Normative documents* — the one definition, cited from everywhere else — are what an agent
    or the operator reads and follows in a phase, what executes, and what is delivered: (a) the
    rules, unit documents, role contracts, evaluation criteria and agent definitions a phase loads
    (`CLAUDE.md`, `<autoflow-root>/docs/core.md`, `<autoflow-root>/docs/state-tracking.md`, `<autoflow-root>/docs/autoflow-guide.md`, `<autoflow-root>/docs/units/*`, `<autoflow-root>/docs/role-contracts.md`,
    `<autoflow-root>/docs/role-common-rules.md`, `<autoflow-root>/docs/submodule-common-rules.md`, `<autoflow-root>/docs/evaluation-system.md`,
    `<autoflow-root>/agents/*`, and the sections of an ADR that state a decision still in force);
    (b) the scripts, hooks and workflows that run; (c) every document the plugin delivers for a
    role to read — the command bodies under `<autoflow-root>/skills/` and the usage documents
    `<autoflow-root>/docs/INDEX.md` routes, outside the records under `<autoflow-root>/docs/records/`.
  - *Historical records* are what is kept as a record of a past state and followed by no one:
    per-issue manual-verification records, report-excerpt fixtures
    (`tests/fixtures/*`), an ADR's change-history and superseded sections, and completed attempts'
    records. A fixture that an executing test reads is still a historical record for this check,
    while the test that reads it is normative.
  - For a stale name in a historical record the evaluator judges whether a reader following the
    normative documents would be misled by it, and records the judgment with its grounds in the
    item's `reason` (and in `recommendations` when it does not lower the score). A score reduction
    rests on that recorded ground alone, never on the name's presence; a record whose stale names
    mislead no one is left as it is, and rewriting it is not a remedy the evaluator asks for.

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

<!-- From <autoflow-root>/docs/units/delivery.md -->

# U6 Delivery — DELIVER, INTEGRATE and HANDOFF

> Unit document for U6. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

AutoFlow's mission ends by handing off an open PR — after PR creation and CI, here, and the review and its triage in [U7 Review](<autoflow-root>/docs/units/review.md). Merging, issue close, and deployment are outside AutoFlow's authority, performed entirely by an external review process that AutoFlow does not define or perform.

DELIVER, INTEGRATE and HANDOFF are one functional unit, U6 Delivery
([`ADR-0025`](<autoflow-root>/docs/records/adr/0025-outcome-gated-functional-units.md) D1,
[`ADR-0033`](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)). U6 has no unit agent: it
is the orchestrator's own work ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Spawn mode by role
lifetime) — every unit agent has already ended by returning its report. This file states what is
asked, the cautions and the result owed. A script only reads and reports (D8). The orchestrator
pushes, opens the pull requests, writes the state file and the ledger, and confirms that each added
test file ran in CI (*CI* > *Added test files*). One reading is made by a spawned role — what class
a CI failure is.

- **Goal**: the cycle's branch is on the remote at the commit GATE:QUALITY passed, the change is
  shown working above its own tests, and every pull request of the cycle is open with CI green on
  its head — or, where no CI runs for it, that fact and its ground recorded on it (*CI*).
- **Artifact contract**: the pushed branches and the pull requests (*Push and pull request*), the
  integration record (*Integration*), and the ledger entries the routes record.
- **What a script reads and reports**: CI confirmation (*CI*), by exit code.
- **Verification**: the integration checks and CI green — both outside the orchestrator's own
  claim; a CI that did not run is recorded as not run, never read as green.
- **Loop cap**: HANDOFF internal retry, 2 ([`core.md`](<autoflow-root>/docs/core.md) > Flow Control > Regressions).
  An INTEGRATE or CI failure is fixed by the unit its class routes to, and the cycle runs forward
  again (*Integration*, *Failure and retry*).
- **Result owed**: each PR's URL and head commit and the CI result on it.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| DELIVER → INTEGRATE | the cycle's branches pushed, a changed sub-repo's included |
| INTEGRATE → HANDOFF | integration tests pass |
| INTEGRATE → BUILD | integration / bundle failure — fixed `impl` class → a BUILD unit re-run with the failing check → AUDIT → … → INTEGRATE again |
| HANDOFF → REVIEW | every pull request of the cycle open, CI green on its head or recorded on it as not run (*CI*, exit `11`) → [U7 Review](<autoflow-root>/docs/units/review.md) (`<autoflow-root>/docs/units/review.md`) |
| HANDOFF → HANDOFF (retry) | environment / transient error or push rejection → internal retry (max 2) |
| HANDOFF (CI failure) → doc commit / BUILD / ARCHITECT / advisor | `confirm-ci-green.sh` exit `12` → the failing check's `remedy_class`, recorded by an anonymous direct subagent in `<attempt-dir>/issue-{N}-ci-failure.md`, routes as a GATE:QUALITY FAIL does; `operator` → the advisor fixes the class (`<autoflow-root>/docs/units/delivery.md` > *CI-failure re-entry*) |
| HANDOFF → user | HANDOFF internal retry exhausted (2×) |

## Push and pull request

**DELIVER.** The cycle's branch is on the remote, at the commit GATE:QUALITY passed; the pushed
branch and its head commit are carried in the change summary. Which remote, which flags and when
are the orchestrator's. A changed sub-repo's branch is pushed the same way, by the orchestrator's
own `git -C <sub-repo> push …`, to the remote the project's information names for it; the host
pointer that follows it is *Multi-repo delivery* below.

These rules hold on every push and every pull request the cycle makes. Everything they do not
name — the branch, the title, how the body is composed, when the push happens — is the
orchestrator's, and nothing checks for an item left out.

- **Pushing and opening a pull request are the orchestrator's own commands.** `git push …` and
  `gh pr create …` are issued as those commands, so the gate hook sees them: it admits them only on
  a recorded AUDIT and GATE:QUALITY PASS with no re-entry open
  ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > Hook gates). They are not issued through a script or a wrapper
  that would carry them past the hook.
- **[MUST]** AutoFlow runs neither `gh pr merge` nor a push to the default branch or to the
  attempt's base (`autoflow-records base`); the hook denies them. Merging is owned entirely by the
  external review process.
- **Every pull request the cycle opens is a draft** (`gh pr create --draft …`). The host pull
  request's base is the attempt's base, the branch `autoflow-records base` prints — the dev
  branch's `gh-merge-base`, which `gh pr create` reads when no `--base` is given.

What a pull request of a cycle usually carries — offered as what to weigh, not as a checklist:

- a title in the [`title-guide.md`](<autoflow-root>/docs/title-guide.md) convention and a body written to
  [`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md);
- on the host PR, the close keyword for the issue (`Closes #N`); a sub-repo PR references the issue
  and carries no close keyword (*Multi-repo delivery* below);
- the acceptance-criterion check — one line per issue criterion: whether it is met, the commit it
  was confirmed at and where the evidence is, under a head naming the commit the results stand at
  ([`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) > *수용 기준 대조*);
- the `## Verification dispositions` list — the reviewer reads it (`<autoflow-root>/docs/review/review.md` > Before
  Reviewing): every issue acceptance criterion not verified by an automated test, with its
  disposition and one-line reason from its verification-design row; the run record of each
  cycle-layer `automated` row and the observation record of each AI-executed `manual` row, from the
  build report; and each test file the cycle added to the target's tree, with its reason and the CI
  job that ran it, or that none did and its disposition (*CI* > *Added test files*). Form:
  [`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) > *Verification dispositions*;
- the known gaps ([`pr-body-guide.md`](<autoflow-root>/docs/pr-body-guide.md) > *한계와 known gaps*): each directly
  related problem the cycle separated, with its separation reason
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Change Surface Rules > *Scope
  judgment*), and each gate recommendation deferred or separated at triage
  ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*);
- in a review-response cycle, the existing PR is updated by the push, and its body is brought up to
  this cycle's records before the reviewer reads it again.

## Integration

INTEGRATE looks at the change as the system runs it, beyond what BUILD verified per acceptance
criterion.

- **What is asked**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks that takes, and how they are run, is the orchestrator's, the way
  the target runs them ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification
  and Tools).
- **Result owed**: one line per check — its command and the summary line read from its log, the
  log kept under `<attempt-dir>/issue-{N}-local/` — or the no-op line below. A check that was not run
  is `not-run`, never `passed`.
- **Failure**: INTEGRATE FAIL → BUILD — fixed `impl` class: a BUILD unit re-run with the failing
  check fixes it, and the cycle runs forward through AUDIT to INTEGRATE again ([U4 Build and verify](<autoflow-root>/docs/units/build.md) >
  *Re-entry*).

Cautions:

- A project with no integration layer records `INTEGRATE: no-op (no integration suite)`. That is
  a stated no-op, not a skipped check.
- In a project with sub-repos the system is built in the dev environment and what crosses sub-repos
  is what is verified: each affected sub-repo builds (for example
  `docker compose -f docker-compose.dev.yml up -d --build <services>`), each service's health check
  passes, the functional integration tests pass, and the cross-cutting concerns the change touches
  (auth, network ingress) are looked at.

### Deploy/CI-path conditional verification

A **diff-path-conditional** requirement keyed on the class of surface being integrated. It applies to every project; a class the project does not ship resolves to a defined no-op.

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD origin/<base>`, `<base>` the attempt's base). The condition **fires** iff any changed path matches the trigger glob set:

| Class | Glob(s) |
|---|---|
| Submodule layout | `.gitmodules` |
| CI config | `.github/workflows/**`, `**/Jenkinsfile`, `Jenkinsfile` |
| Deploy scripts | `deploy-*.sh`, `**/deploy-*.sh` |
| Env / build-arg | `.env`, `.env.*`, `**/.env`, `**/.env.*` |

Stated as one command (the frozen predicate):

```
git diff --name-only <base>...HEAD \
  | grep -E '(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
```

Non-empty ⇒ the verification bundle below is owed, each item PASS or FAIL. Empty ⇒ record `INTEGRATE deploy/CI-path: no-op (diff touched no deploy/CI-path surface)` — a defined no-op, not a discretionary skip.

**Verification bundle** (owed only when the predicate's output is non-empty; each item is itself a defined no-op when the target ships no such surface):

- **(a) Deploy-script dry-run, incl. recursive submodule init** — the target's `deploy-*.sh` in dry-run (`--dry-run` / read-only) with `git submodule update --init --recursive`, confirming the deploy path resolves the current submodule pointers. *No-op* when the target ships no deploy script.
- **(b) CI-config static validation** — a lint / schema check of the changed CI file itself (`.github/workflows/*` via `actionlint` / YAML-schema; `Jenkinsfile` via the target's `jenkins declarative-linter` or equivalent). *No-op* when no CI file changed.
- **(c) Landing/host routing smoke check** — a smoke request against the built host / landing route (health / routing reachability). *No-op* when the target exposes no host / landing route.

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is an **INTEGRATE FAIL → BUILD** (`impl` class; the re-run above).

## CI

```
bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
```

The script reads the PR's mergeable state first and then runs one finite, deadline-bounded poll over
the checks the CI publishes on the PR head — any check, by count and conclusion, never by name. Its
header carries the full contract; the exit codes route as follows.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | green — at least one check present, every one green, on a PR whose mergeable state was confirmed | *Added test files*, then [U7 Review](<autoflow-root>/docs/units/review.md) |
| `10` | not mergeable — a confirmed `CONFLICTING` / `DIRTY` read | no waiting on CI: resolve against `origin/<base>`, the attempt's base (rebase or merge), and push again (internal retry); a conflict on a sub-repo pointer another cycle advanced → *Multi-repo delivery* below |
| `11` | mergeable, and no check was published within the bound (`CI_POLL_TIMEOUT_SECS`, default 900) | not green: look at the CI trigger (webhook delivery, workflow trigger conditions), or push again to force a `synchronize` event. When the target's CI does not run for this pull request — no workflow, or a trigger, path filter or condition that excludes it — the PR body records that CI did not run and the ground, what CI was to run for it (a `ci-deferred` lint chain, an added test file) is listed as not run, and the cycle goes on to [U7 Review](<autoflow-root>/docs/units/review.md); whether CI is not running or late is the orchestrator's judgment, recorded with its ground (ADR-0034 D5) |
| `12` | a check concluded failure | *CI-failure re-entry* below |
| `13` | checks present, no green verdict at the deadline — still pending, mergeability not re-settled, or a superseded run's workflow unresolved (named on its own stderr line; check the token's `actions: read`) | raise `CI_POLL_TIMEOUT_SECS` or run again (internal retry), or escalate |
| `14` | the mergeable state could not be confirmed within the bound — a `gh` transport, auth or parse failure | not a conflict: check `gh auth` and connectivity, run again (internal retry), then escalate |
| `64` | usage | fix the invocation |

Cautions:

- The orchestrator does not write its own poll loop, and does not read an empty status as green. A
  `CONFLICTING` PR may receive no check at all; that is exit `10`, not a missed webhook.
- Exits `10` and `14` carry the reserved `HANDOFF-INTERNAL-RETRY` token on stderr.

**Added test files.** On exit `0`, each test file this cycle added to the target's tree (the build
report's `## Test files kept`) is confirmed to have actually run in the PR head's CI. The criterion
is execution visible in a job's log: a workflow that only registers the file, or a job that only
prints its path, did not run it, and a log that could not be read shows neither. Beside each file the
PR body's `## Verification dispositions` records the job that ran it, or that no job ran it and what
was done — the file wired into the target's CI and pushed again (internal retry, then *CI* again), or
listed for the reviewer as not run by CI; `no CI; local run only` where the target has no CI. How it
is confirmed is the orchestrator's judgment. A cycle that added no test file has nothing to confirm.

### CI-failure re-entry

A CI failure (exit `12`) re-enters by `remedy_class` through `<autoflow-root>/scripts/gate/remedy-route.sh route`
([Transitions](<autoflow-root>/docs/units/delivery.md)). The orchestrator
does not read the failure log itself (Cost Control): an anonymous direct subagent —
`subagent_type: autoflow-analyzer`, model per policy key `handoff-review-triage` — reads the failing
check's output (`gh run view <run-id> --log-failed`, or the check's own log), writes
`<attempt-dir>/issue-{N}-ci-failure.md` with the failing check, the first failing assertion or error,
**one `remedy_class`** (`doc` / `test` / `impl` / `design` / `operator`) and the grounds for it —
the class of change that clears the failure, `design` when clearing it would discard or change a
decision the design settled — and returns the class plus a one-line summary.
`<autoflow-root>/scripts/gate/remedy-route.sh route <class>` picks the entry point (`DOC_COMMIT` / `BUILD` /
`ARCHITECT` / `PAUSE`); the re-entered phase runs forward to HANDOFF again and *CI* re-confirms.
Not classifiable with confidence, or the failure output unobtainable → `operator`, never a guess
([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3). A failure routed with no recorded class is a
report defect: reject and re-spawn the subagent, as for a missing `fail_hypothesis`. The orchestrator
records the route as an `O` ledger entry naming the check and the class.

## Failure and retry

Classify the cause and regress along the matching path.

```
CI failure (a check concluded failure, exit 12) → by remedy_class (CI-failure re-entry above)
CI failure (env / transient)                   → CI retry, then the CI confirmation again (max 2)
PR CONFLICTING (no checks,                     → resolve vs origin/<base> (rebase/merge) + push again, OR
 build silently skipped)                          a sub-repo pointer → Multi-repo delivery;
                                                  then the CI confirmation again (max 2) — never wait on CI green
Push rejected (branch state)                   → dev branch rebase on origin/<base> → push again (max 2)
```

**Max retries**: HANDOFF internal retry max 2. Two failures → human.
**Re-entry**: a CI failure is fixed by the unit its class routes to, and the cycle runs forward to *CI* again (*CI-failure re-entry* above); a `design` route consumes the ARCHITECT re-entry counter.

## Multi-repo delivery

Where the project's information names sub-repos — a directory whose source is its own repository,
tracked by the host as a submodule pointer (gitlink) — and the cycle changes one, the sub-repo's
change is delivered on its own pull request and the host follows it by its pointer. AutoFlow does
not classify the project; what the sub-repos are, where each one's pull request goes (a fork, the
upstream) and where issues are filed are read from the project's own information
([`core.md`](<autoflow-root>/docs/core.md) > Project Information).

What follows a sub-repo pull request's merge — whether the host's pointer moves to it, when and
how — is the operator's practice, outside AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) >
Post-Merge Cleanup).

What is asked:

- Each changed sub-repo has its branch pushed and its pull request opened by the orchestrator's own
  commands — `git -C <sub-repo> push …`, `gh pr create --repo <owner/name> …` — gated like the
  host's, and draft (*Push and pull request*). A sub-repo pull request
  references the host issue (`Part of <host-owner>/<host-name>#N`) and carries no close keyword; the
  host pull request is the one that closes the issue.
- The host pull request's pointer names the sub-repo commit the cycle delivers, so the host review
  reads the pointer and the sub-repo review reads the code behind it ([U7 Review](<autoflow-root>/docs/units/review.md) >
  *Review triage*).

Cautions:

- A merge of the base into the host branch — the conflict resolution *Failure and retry* routes
  here — can resolve the pointer to the base's, not to the sub-repo commit the cycle delivers. The
  pointer is set to the delivered commit and read back (`git ls-tree HEAD <sub-repo>`) before the
  push.
- Another cycle may have moved the base's pointer since this branch forked. When the delivered
  sub-repo commit does not contain that pointer — the base is ahead of it, or the two have
  diverged — setting it would move the host's pointer backwards or across histories: the
  orchestrator does not push, and reports to the operator.
- Every pointer move is a host commit the host review reads again; a pointer moved while the
  sub-repo pull request is still changing under review costs a host re-review per move.
- A sub-repo nested inside a sub-repo is that sub-repo's own delivery.

Result owed: each pull request's URL and head commit; for the host pull request, the commit each
changed sub-repo's pointer names.

<!-- From <autoflow-root>/docs/pr-body-guide.md -->

# PR Body Authoring Guide

PR body 작성 시 참고하는 가이드. AI orchestrator와 수동 PR 작성자 모두 대상.

## Principles

### 1. Claim의 정확도

PR이 body에서 약속하는 동작 / 검증 / 보호 범위는 실제로 구현하는 것과 정확히
일치해야 한다.

- 강한 표현 (machine-verified, fully enforced, idempotent, atomic, race-free
  등) 은 실제로 그 수준을 충족할 때만 사용.
- 부분적 보장은 부분적으로 명시 — "X는 machine-verified, Y는 reviewer-attested"
  처럼 분리 가능하면 분리.

### 2. 거부된 대안의 노출

implementation을 결정하는 과정에서 고려했으나 거부한 대안이 있다면, 거부
사유와 함께 body에 노출한다.

- 거부 사유는 정확하게: "architectural boundary 위반"인지 "비용 trade-off"인지
  분명히 구분.
- 간단한 PR (typo fix 등) 에는 적용되지 않을 수 있다.

### 3. 한계와 known gaps

이 PR이 cover하지 않는 path / 잔존 risk / 후속 작업이 필요한 항목을 명시.

- "이 PR이 다루지 않는 것" 섹션 또는 body 본문에 단락으로.
- 후속 issue 번호가 있다면 cross-reference.

### 4. 판단 근거의 명시적 링크 (PR-reachability)

리뷰어는 PR에서 출발해 판단 근거에 도달할 수 있어야 한다. 문서가 저장소에
존재하는 것만으로는 부족하다 — PR이 어떤 ADR / design note / architecture
context / AC 를 판단 근거로 삼았는지 `path > section` 형태로 명시한다.

- ADR / design note / architecture context 를 명시적으로 링크. ADR 불필요 시
  사유 한 줄 ("ADR not required: ...").
- linked issue 의 AC 를 PR 에서 도달 가능하게 (이슈 링크 + AC 섹션, 또는 body 에 명시).
- `<attempt-dir>/*` scratch 는 리뷰 입력으로 링크하지 않고, 리뷰어가 봐야 할 근거는
  linked issue 나 commit 된 문서로 옮긴다.

정책: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

### 5. Verification dispositions (검증 처분의 노출)

AutoFlow cycle의 host PR body는 `## Verification dispositions` 섹션을 싣는다 — issue의 acceptance
criterion 중 automated test로 검증되지 않는 모든 항목을, 그 disposition
(`existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
`none`) 과 verification design row에 적힌 한 줄 reason과 함께 나열한다.

- 운영자 주도 PR(AutoFlow cycle 밖에서 운영자가 진행한 작업의 PR)에는 이 섹션을 요구하지 않는다.
  verification design이 없기 때문이다. 수용 기준의 충족은 *6. 수용 기준 대조*로 보인다.
- 이 섹션은 3단 acceptance-criterion guard의 두 번째 tier다: design unit이 검증
  방법의 축소를 결정하고, REVIEW의 reviewer가 그 reason의 타당성을 판단하며,
  criterion의 **내용**이 바뀔 때만 orchestrator가 1차 판단하고, 근거로 정할 수 없으면 advisor가 판단한다
  ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor). 규칙 본문은 [U3 Design](<autoflow-root>/docs/units/design.md) >
  Output artifacts > *Test necessity* 와 *Report routing*.
- 형식은 AC id + disposition + reason 한 줄. reason은 verification design의 셀을
  옮겨 적고 새로 쓰지 않는다.
- issue AC 전부가 `automated` 이면 섹션을 생략하지 않고 그 사실을 한 줄로 적는다.
- `cycle` 층의 `automated` row(`Type` 셀에 `standing:` 토큰이 없는 row)는 같은 섹션에 그
  row의 **run record** — build report의 `## Run record`에 기록된 command와 summary line — 를 한 줄로 싣는다
  ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *Push and pull request*).
- AI가 도구로 실행한 `manual` row는 같은 섹션에 실행 주체, observation record의 경로와 결과 줄을
  한 줄로 싣는다. 사람이 실행하는 `manual` row는 reason에 도구를 확보할 수 없었던 이유가 들어
  있다 ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *The tools the work needs*; [U3 Design](<autoflow-root>/docs/units/design.md) > *Tools*).
- cycle이 target 트리에 **추가한 테스트 파일**은 같은 섹션에 파일별로 나열한다 — 경로,
  남겨 두는 이유, 그리고 HANDOFF의 CI 확인에서 확인한, 그 파일을 실제로 실행한 CI job(실행한 job이 없으면 그
  사실과 처분, target에 CI가 없으면 `no CI; local run only`). 추가한 파일이 없으면 그 사실을 한 줄로 적는다
  ([`submodule-common-rules.md`](<autoflow-root>/docs/submodule-common-rules.md) > Verification and Tools > *What a cycle leaves in the target's tree*;
  [U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *CI* > *Added test files*).

예:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` 가 동일 property를
  build마다 검사한다.
- AC4 — none: 값이 사용자가 편집하는 sample 파일에 있어, 첫 편집에서 검증 대상이
  사라진다. 부재 비용 0.
- AC1 — automated (cycle): `bash <attempt-dir>/issue-42-local/ac1-retry.sh` → `PASS 3/3`
- AC3 — manual (AI: browser): `<attempt-dir>/issue-42-local/ac3-observation.md` →
  `observation: match` — 렌더링된 목록 화면을 이슈가 링크한 시안과 대조.
- Added test files: `tests/retry-backoff.test.ts` — 재시도 간격은 배포 후 설정값에
  따라 달라지므로 target의 회귀 대상; CI job `unit (ubuntu-latest)`에서 실행 확인.
```

### 6. 수용 기준 대조

운영자 주도 PR과 AutoFlow cycle PR 모두, PR body에 linked issue의 수용 기준을 대조하는 절을
싣는다.

- 절 머리에 결과가 어느 commit 기준인지 밝힌다: "`<sha>` 시점의 결과".
- 기준마다 한 줄로 쓴다: 기준 번호(cycle PR은 분석 report `## Acceptance criteria`의 AC id),
  충족 여부, 확인한 commit, 근거 위치(`path` > section, `path:line`, 실행 기록의 summary line 등).
- 충족하지 못했거나 일부만 충족한 기준은 그렇게 적고 사유를 같은 줄에 붙인다. 후속 처리는
  *3. 한계와 known gaps*에 적는다.
- 이 절은 cycle PR의 *5. Verification dispositions*를 대신하지 않는다. dispositions는 검증 방법의
  처분이고, 이 절은 기준의 충족 여부다.
- 항목은 제시만 한다. 이 형식을 검사하는 장치는 없다.

예:

```
## 수용 기준 대조 (#42)

`a1b2c3d` 시점의 결과.

- 1 — 충족 · `a1b2c3d` · `src/retry.ts:40-58`, `<attempt-dir>/issue-42-local/ac1-retry.log` → `PASS 3/3`
- 2 — 충족 · `9f8e7d6` · `docs/retry.md` > Backoff
- 3 — 일부 충족: 설정 파일 경로만 반영, 환경변수 경로는 후속 #43 · `a1b2c3d` · `src/config.ts:12`
```

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

- [U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *Push and pull request* 가 본 가이드를 cross-reference (AI orchestrator).
- 수동 PR 작성 시도 동일하게 참조.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건).

<!-- From <autoflow-root>/docs/title-guide.md -->

# Issue & PR Title Guide

공통 접두어를 대괄호로 묶고, 나머지 설명은 자유롭게 기술한다.

## 형식

```
[type · epic-slice · #N]  자유 설명    ← epic 서브이슈 PR
[type · epic-slice]       자유 설명    ← epic 서브이슈 (이슈 생성 시 번호 미정)
[type · #N]               자유 설명    ← 독립 이슈 / epic 트래커 / 독립 이슈 PR
```

| 항목 | 설명 |
|------|------|
| `type` | `feat` / `fix` / `chore` / `docs` — 아래 표 참고 |
| `epic-slice` | Epic 번호와 슬라이스 코드 (`#73-S3f`, `#72-S5a` 등). epic 서브이슈에만 사용 |
| `#N` | GitHub 이슈 번호. **이슈 제목에는 생략 가능**; **PR 제목에는 필수** |
| 자유 설명 | 길이·언어 제한 없음 |

## type 값

| type | 언제 |
|------|------|
| `feat` | 새 기능 구현 |
| `fix` | 버그 수정 |
| `chore` | 설정·인프라·자동화 |
| `docs` | 문서 단독 변경 |

## 예시

### 이슈 제목

```
[feat · #73-S3f]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a]  멤버 관리 테이블 프론트엔드
[feat · #224]     Enterprise 멤버 활동 감사 로그 구현
[fix  · #200]     YouTube 자막 취득 실패
[chore · #43]     PAT rotation 문서화
```

### PR 제목

```
[feat · #73-S3f · #231]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a · #217]  멤버 관리 테이블 프론트엔드
[feat · #224]             Enterprise 멤버 활동 감사 로그
[fix  · #200]             YouTube 자막 취득 실패
[chore · #43]             PAT rotation 문서화
```

## 접두어 구성 원리

`epic-slice`와 `#N`은 역할이 다르다.

| 참조 | 의미 | 이슈 | PR |
|------|------|------|----|
| `epic-slice` (`#73-S3f`) | 어느 Epic의 몇 번째 슬라이스인가 | ✅ | ✅ |
| `#N` (이슈 번호) | 어떤 GitHub 이슈를 닫는가 | 생략 가능 | **필수** |

epic 서브이슈가 아닌 경우(독립 이슈, epic 트래커)는 `epic-slice` 없이 `#N`만 사용한다.

## 커밋 메시지와의 관계

커밋 메시지 규칙(`<autoflow-root>/docs/core.md` > Commit Rules)은 별도로 유지된다.

```
feat(#231): 소진 내역 탭 프론트 — 기간 필터 + 검색   ← 커밋
[feat · #73-S3f · #231] 소진 내역 탭 프론트            ← PR 제목
```

커밋은 `type(#N):` 형식, 이슈·PR 제목은 `[type · ref]` 형식으로 구별한다.

<!-- From <autoflow-root>/docs/units/review.md -->

# U7 Review — REVIEW

> Unit document for U7. [`core.md`](<autoflow-root>/docs/core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](<autoflow-root>/docs/autoflow-guide.md) > Unit
> Documents.

REVIEW is one functional unit, U7 Review
([`ADR-0033`](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)): the review of every pull
request [U6 Delivery](<autoflow-root>/docs/units/delivery.md) opened, its triage, and the hand-off that ends AutoFlow. U7 has
no unit agent: it is the orchestrator's own work ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) >
Spawn mode by role lifetime). A script only reads and reports. The orchestrator runs the reviewers,
writes the state file and the ledger, and makes the changes a route calls for; the aggregation of a
pull request's reviews into one verdict is made by a spawned role.

U7 is entered with the issue number or with nothing. Where the cycle stands — its attempt, its pull
requests and their rounds — is read from the current state: `bash <autoflow-root>/scripts/preflight/cycle-status.sh`
(with `--issue <N>` when given), the attempt's ledger and records, and the pull requests themselves.
An attempt with no state file whose pull request is open — an attempt on the abbreviated path — is
reviewed as *An attempt with no state file* below says, which takes the place of this unit's goal,
routing, cap and *End* for it.

- **Goal**: every pull request of the cycle reviewed, its aggregated review posted with no
  `Medium`+ finding that holds left and CI green on its head (or recorded on it as not run — [U6
  Delivery](delivery.md) > *CI*), and the state file handed off.
- **Artifact contract**: each reviewed PR's review records and findings file (*Reviewer review*,
  *Review aggregation*), and the ledger entries the routes record.
- **What a script reads and reports**: a reviewer run's start check (*Reviewer review*; the run
  itself is the reviewer's wrapper), and the triage case with its attempt count (*Review triage*).
  Each reports by exit code.
- **Verification**: the aggregated review clean and CI green, or CI's not running recorded — outside the orchestrator's own
  claim.
- **Loop cap**: auto-resolution of reviewer findings, 7 attempts ([`core.md`](<autoflow-root>/docs/core.md) > Flow
  Control > Regressions).
- **Result owed**: the report of *End*, with each PR's URL and head commit, the review verdict, CI
  as recorded and, for a host PR whose pointer names a sub-repo PR's commit, that dependency.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](<autoflow-root>/docs/core.md) > Flow Control.

| Transition | Condition |
|------|------|
| REVIEW (review-triage) → thin route / design re-entry (auto) | the aggregated review verdict is `max_severity ≥ Medium` → each Medium+ finding is routed by its `remedy_class` (`<autoflow-root>/scripts/gate/remedy-route.sh route`): `design` → a re-entry within the cycle from DIAGNOSE or from ARCHITECT, the orchestrator's judgment recorded in the attempt's `[review-autofix]` ledger entry; `impl` / `test` / `doc` → the thin route; `operator` → the advisor fixes the class. A finding that does not hold is rejected, not routed (`<autoflow-root>/docs/units/review.md` > *Review triage*; the case is `<autoflow-root>/scripts/handoff/review-gate.sh` exit `10`) |
| REVIEW (review-triage) → advisor / user | auto-resolution hits an advisor criterion (`<autoflow-root>/docs/units/review.md` > *Routing*), or a rebutted finding the next round's aggregation keeps while the two sides still disagree → the advisor decides; the 7-attempt cap (`review-gate.sh` exit `11`) → `active:false`, `phase:"awaiting-user"` |
| REVIEW → end | every PR's aggregated verdict below Medium + Low triage resolved + CI green, or CI recorded as not run → the orchestrator sets the state `active:false`, `phase:"awaiting-external-review"` and reports each pull request's facts → AutoFlow ends; external review reviews and merges out of band (`<autoflow-root>/docs/units/review.md` > *End*) |

## Reviewer review

Every pull request the cycle opened is reviewed on its own diff — the host PR and each sub-repo PR
alike; a sub-repo PR's review is required, not optional. A round of a PR's review runs every
reviewer, and their records go to one aggregation (*Review aggregation* below), which posts the
round's comment ([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)).

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Config
location*). Each runs as its own script, launched in the background:

```
bash <autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>] [--records <attempt-dir>]
bash <autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>]
bash <autoflow-root>/scripts/review/review-start-check.sh --pr <N> --reviewer <name> [--repo <owner/name>] [--log <the run's captured output>]
```

Each wrapper stops when the PR it is given is not that OPEN PR on that head branch, then runs its
reviewer over the PR with that reviewer's rule file and, where one is configured, its lenses file
([`reviewer-backend.md`](<autoflow-root>/docs/reviewer-backend.md) > *Rule files*), on the model and effort the same
file names; the reviewer writes its review and nothing else. `--records` names the attempt's record
directory, where the `claude` reviewer reads the cycle's design artifacts — the analysis report,
the feature design, the verification design, the decision ledger and the build report.
`<record>` is the review record's absolute path below; nothing a wrapper or its reviewer writes
stays in the target's tree.

**The reviews of the target's side.** A review a system on the target's side runs on the pull
request by itself — a review bot's review or review comment — is a review of the round too. It is
not launched and leaves no record: the aggregator reads it from the pull request (*Review
aggregation*). Whether to wait for one that has not yet arrived is the orchestrator's judgment.

**An unreadable operator file.** When the operator's `~/.autoflow/config.json` cannot be read as
configured, `check-review-backend.sh` exits `6` and each wrapper starts no reviewer and exits `6`;
each prints the marker line `user-config: UNREADABLE <path> — <error>`, which
`review-start-check.sh` reports as exit `4`. The orchestrator asks the operator, situation-first,
with the path and the error, whether to proceed without those reviewers. Proceeding runs the round
on the reviews of the target's side alone, and the aggregation names the missing reviewers with
that reason. Stopping pauses the round until the operator has fixed the file; the step then runs
again and reads it anew.

Each review lands in a **review record**,
`<attempt-dir>/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`), `<k>` the PR's review round from `1`.

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker:

| Exit | Meaning | What follows |
|---|---|---|
| `0` | started, or already completed with exit 0 | the orchestrator ends its turn and waits for the run's completion notification ([`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > *Wait discipline*) |
| `1` | no signal within the window (30 s) | launch the review again once; a second miss makes that reviewer unavailable for the round |
| `3` | the wrapper completed with a non-zero exit — the review run failed or left no record | one internal retry; a second failure makes that reviewer unavailable for the round |
| `4` | the wrapper's output carries `user-config: UNREADABLE …` — no reviewer started | the operator is asked (*An unreadable operator file* above); no relaunch |

A reviewer that is unavailable for a round — its CLI absent (PREFLIGHT reports it), its run failing
twice, or the operator's choice to proceed past an unreadable operator file — does not hold the
round: the aggregation runs on the reviews that exist, and its comment names the reviewer that is
missing and why. A round in which no configured reviewer left a record, other than by that choice of
the operator's, does not go on: it is a review-infrastructure failure, put to the operator
([`core.md`](<autoflow-root>/docs/core.md) > Flow Control > *Advisor at a decision point*).

Cautions:

- A review that started is left to finish on its own clock, however long that takes; it is not
  relaunched because it is slow.
- Every round runs every reviewer again on each PR of the cycle whose head this cycle advanced
  (`gh pr view <N> --json headRefOid`).
- Several reviews may run at once (the host PR plus each sub-repo PR, each with its reviewers);
  each run is confirmed with its own `--pr` and, for a sub-repo PR, `--repo`.

## Review triage

Per reviewed PR, after its round's reviews complete and before *End*. While it runs the state's
marker is `review-triage`, set by the orchestrator.

### Review aggregation

**1. The reviews are aggregated by a spawned analysis role.** The orchestrator does not read the
review records or the comment body itself (Cost Control). An anonymous direct subagent —
`subagent_type: autoflow-analyzer`, on the model the policy names for `handoff-review-triage` — is
the aggregator. Its prompt names the PR as `<owner>/<name>#<N>`, the round, the record paths, any
reviewer unavailable for the round with the reason, the decision ledger, and, for a PR whose repository has
submodules, their paths (its `.gitmodules`) — the locations outside that review's target. It also
reads the reviews of the target's side from the pull request itself and names each one's author as
its source.

Its purpose is one verdict over every review of the PR. How it groups duplicates, settles a
severity the reviews disagree on, and weighs each finding (*Whether a finding holds*) is its own; what
it leaves behind is fixed:

- **One PR comment**, in Korean, per round: each finding once, with the reviewers that raised it;
  a finding only one reviewer raised kept like any other; each rejected finding listed apart with the
  grounds it does not hold; a reviewer unavailable for the round named with the reason. Its body is kept as
  `<attempt-dir>/issue-{N}-local/review/comment-<owner>.<name>-<pr>-r<k>.md`.
- **The findings file** (below).

It returns `{max_severity, findings}`.

- **[MUST] One findings file per reviewed PR.** Each PR's aggregation writes `<attempt-dir>/issue-{N}-local/review/findings-<owner>.<name>-<pr>.md` for the reviewed PR `<owner>/<name>#<pr>` — the whole identity; an owner name holds no `.`, so the first `.` separates it. A single-PR cycle follows the same rule. Only that PR's aggregation writes the file, and a later round of the same PR **overwrites** it. The file carries a `pr: <owner>/<name>#<N>` line naming the reviewed PR, exactly one `max_severity: <level>` line — the highest level among the findings that hold, `Low Confidence` included, in colon notation, `max_severity: None` when none remains (never an omitted line) — and one table row per finding, `| <Severity> | <path>:<line> | <remedy_class> | <finding> | <source> | <disposition> |` — severity first, location second (a path relative to the reviewed PR's repository root), `remedy_class` on every Medium+ row that holds, `<source>` the names of the reviewers that raised it (`claude`, `codex`, a review bot's login), and `<disposition>` empty, or `rejected` for a finding that does not hold — always the row's last cell, so a `|` quoted in the finding cell moves no cell the script reads. A `rejected` row is a record: it counts toward no verdict. `<autoflow-root>/scripts/handoff/review-gate.sh` reads the file and exits `2` on one that does not keep this contract; the aggregator is then spawned again.
- **[MUST] A PR's review covers its own repository.** A review's target is what the reviewed PR's repository tracks directly — every file of its tree, a submodule's pointer included, never a submodule's contents (`<autoflow-root>/docs/review/review.md` > Before Reviewing). Every finding therefore belongs to the reviewed PR, and its `max_severity` rests on that PR's own findings alone. A host PR whose diff is a submodule pointer is reviewed over the host repository like any other PR; the sub-repo code behind the pointer is judged by the sub-repo PR's review. A finding a review raises inside a submodule misreads that target: the aggregator rejects it as a finding that does not hold.
- **[MUST] `remedy_class` per Medium+ finding.** The aggregator tags **every** `Medium`+ finding that holds with a `remedy_class` from the same vocabulary the late-gate evaluator uses (`doc` / `test` / `impl` / `design` / `operator`, defined at [U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *FAIL routing*) and writes it in that finding's row. The classifying question is **not** how large the fix is: it is **does clearing this finding discard or change a decision the design settled?** Yes → `design`. No → the class of change that clears it. Not classifiable with confidence → `operator`, never a guess.

### The case

**2. The case is read by script.**

```
bash <autoflow-root>/scripts/handoff/review-gate.sh --issue {N} --pr <P> [--repo <owner/name>]
```

It reads the verdict (`max_severity`) and the auto-resolution attempts on record, and names the
case:

| Exit | Case | What follows |
|---|---|---|
| `0` | `clean` — no finding | *End* (once every PR of the cycle is there) |
| `13` | `low-only` — findings below `Medium` | the orchestrator's judgment, with no fixed rule: a finding that holds and is worth fixing now goes through the same resolution as below (a `Low` alone raises no advisor request unless an advisor criterion is hit); otherwise *End*, optionally with a one-line PR note that the findings were reviewed and deferred. A `Low` on a target comment's divergence or disallowed content is the orchestrator's direct commit or it is left ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Code comments in a target*) |
| `10` | `resolve` — a `Medium`+ verdict | *Routing* below |
| `11` | `cap` — a `Medium`+ verdict with 7 attempts on record | pause for the operator (*Attempt cap*) |
| `2` | the findings file is absent or breaks its contract | the aggregator is spawned again |
| `3` | a `gh` read failed | run again (internal retry) |

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A role the route hands a finding to that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file and the comment, and counted toward no verdict ([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md)). A finding that a role the route hands it to finds does not hold is a rebuttal: the orchestrator posts it with its grounds on the PR and runs *Reviewer review* on that PR again — a new round, also when the round only rebuts and changes no code — and that round's reviews and aggregation judge it. A gate recommendation's rebuttal is judged by the recommending gate's re-score. A finding that does not hold is not routed and its `rejected` row needs no `remedy_class` — nothing reads one there — and one that holds in part is routed by the class its real problem needs. Each rebuttal is recorded with its grounds in the ledger entry of its round: the attempt's `[review-autofix]` entry, or, for a round that only rebuts and so routes nothing, an `O` entry whose heading ends in `[rebuttal]`, which no cap counts. At a gate that entry is also what an interrupted session resumes from ([U1 Preparation](<autoflow-root>/docs/units/preparation.md) > *Resume*). When a rebutted finding is kept and the two sides still disagree, the orchestrator asks the advisor ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; [`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 3). When to ask is its judgment and no count decides it.

**This section is the rule's only home** ([`development-guideline.md`](<autoflow-root>/docs/development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A review-response can loop: each fix answers the case the reviewer named while the property the
reviewer asserts stays unmet, and the next review names another case. No spawn checks for this on
every attempt. Whoever reads the finding — the aggregator here, or the DIAGNOSE unit — and sees that it repeats the complaint of the previous
attempt (the same property asserted, a different witness case; the previous attempt's
`[review-autofix]` entry and the previous cycle's artifacts are what it compares against) says so
where it writes the finding: in the finding's cell of the findings file, or under the analysis
report's `## Decision points`. The orchestrator then decides the re-entry — its depth, or none;
for example restating the acceptance criterion as one rule over the whole input, or a further
case-specific change — and records it with its grounds in the attempt's `[review-autofix]` entry;
where those grounds do not settle it, or it is not confident, it puts it to the advisor
([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor) with a request written situation-first,
and the advisor's `A` entry decides it. A
redefined criterion is recorded as `[ac-decision]` entries and the cycle restarts from DIAGNOSE on
it. A complaint already decided is not decided again without a new verified fact
([`core.md`](<autoflow-root>/docs/core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case; it is routed like any finding.

### Routing

A `Medium`+ verdict does not end the cycle. Route by `bash <autoflow-root>/scripts/gate/remedy-route.sh route <class>...` over the classes of the Medium+ findings that hold, in whole or in part (mixed → farthest; `operator` anywhere stops routing and goes to the advisor) — the same single owner of the mapping the late gates use:

| Route | What the orchestrator runs | Re-review |
|---|---|---|
| `ARCHITECT` (from `design`) | the design owns the moved decision; a re-entry within the cycle whose start is the orchestrator's recorded judgment (below) | *Reviewer review*, per-PR |
| `BUILD` (from `impl` / `test`) | a BUILD unit re-run naming the finding fixes it on the finding's own surface — the implementation, or the test asset ([U4 Build and verify](<autoflow-root>/docs/units/build.md) > *Re-entry*) | *Reviewer review*, per-PR |
| `DOC_COMMIT` (from `doc`) | orchestrator doc commit → the local run the doc diff requires | *Reviewer review*, per-PR |
| `PAUSE` (from `operator`) | the advisor fixes the class ([`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor), and the cycle takes that class's route | that route's |

The `ARCHITECT` route is the one whose depth is judged. It re-enters within the cycle, as the cycle's other `design` re-entries do ([U3 Design](<autoflow-root>/docs/units/design.md) > *Re-entry*). **Where it starts, and what it re-derives and re-scores, is the orchestrator's judgment** ([`core.md`](<autoflow-root>/docs/core.md) > Rule Scope, principle 2), recorded with its grounds in this attempt's `[review-autofix]` ledger entry before the routed work starts. While the attempt is open, `design` is recorded as `phases.gate_quality.remedy_class` ([`core.md`](<autoflow-root>/docs/core.md) > AutoFlow State Tracking > *Remedy class recording*), so the change is not pushed before GATE:QUALITY re-scores it. The other routes are **thin**: one BUILD unit re-run or one doc commit, execution verification, a delta recorded in the ledger, and the next review round — no DIAGNOSE, no ARCHITECT, no GATE:PLAN, no fresh evaluator re-read. **Every independent check is retained on every route** — the fix is pushed and its CI confirmed as in [U6 Delivery](<autoflow-root>/docs/units/delivery.md) (*Push and pull request*, *CI*), the next review round judges it, and the attempt cap below applies unchanged.

Every route is recorded in `<attempt-dir>/issue-{N}-ledger.md` with a `review-autofix` marker — a level-2 heading of the form `## O<n> — <title> (cycle <C>, REVIEW) [review-autofix]` ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Entry identifier*) — and the entry names the routed class and, on the `ARCHITECT` route, the judged start with its grounds. The advisor criteria below take precedence over any route.

- **Put to the advisor** (a request written situation-first per [`core.md`](<autoflow-root>/docs/core.md) > Execution Principles > Human-decision presentation — [`role-contracts.md`](<autoflow-root>/docs/role-contracts.md) > Advisor; the cycle does not pause) when the attempt hits **any** of: (a) the fix needs a contract or acceptance-criterion change — a finding that shows a criterion defective included — that the orchestrator cannot settle on the finding's grounds ([`decision-ledger.md`](<autoflow-root>/docs/decision-ledger.md) > *Acceptance-criterion decisions*), (b) the fix direction is ambiguous, (c) the finding repeats the previous attempt's complaint and its grounds do not settle the re-entry (*A repeated complaint* above). The advisor's `A` entry selects re-entry. A rebutted finding kept while the two sides still disagree reaches the advisor by the orchestrator's judgment (*Whether a finding holds* above), not by a criterion here.
- **Attempt cap = 7.** The count is the number of auto-resolution attempts not yet checked with the user: the `[review-autofix]` entries in the ledger after the last entry whose heading ends in `[reentry-decision]`, or all of them when there is none. `review-gate.sh` prints it (`attempts: <k> of 7`) and exits `11` when a `Medium`+ verdict meets 7 on record: the orchestrator stops auto-resolving and pauses for the user (`active:false`, `phase:"awaiting-user"`). A gate's recommendation attempt carries its own marker, `[gate-autofix]`, on its own window ([U5 Completion evaluation](<autoflow-root>/docs/units/completion-evaluation.md) > *Recommendation triage*), and a `[rebuttal]` round is not an attempt, so neither is counted here. The user approving continuation at that pause is the **re-entry decision**: the orchestrator records it as an `O` entry under `operator decision` whose heading ends in `[reentry-decision]` and sets the cycle active again; the entry resets the window — the next auto-entry starts a fresh budget of 7. Nothing else resets it.
- **Durable record (host PR).** Post a one-line comment on the **host PR** via `gh pr comment <hostPR> --body "[autoflow:review-autofix] …"` for two events: (i) when the cap fired — the 7th consecutive attempt paused for the user — and (ii) when a user **re-entry decision** approved continuation (the window-reset event).

## End

Once every pull request of the cycle is clean — `review-gate.sh` reports `clean` or `low-only` on
each of them and the Low findings are triaged — and CI is green, or recorded on the pull request as
not run ([U6 Delivery](<autoflow-root>/docs/units/delivery.md) > *CI*), the orchestrator hands the
cycle off:

- the state file reads `active: false`, `phase: "awaiting-external-review"`, with nothing else in
  it changed.
- the report names each pull request's URL and head commit, its review verdict and its CI as
  recorded, and, for a host pull request whose pointer names a sub-repo pull request's commit, that
  dependency.

Cautions:

- The hand-off is not made while a pull request of the cycle has a `Medium`+ verdict.
- A pause for the user is the other `active:false` transition (`phase: "awaiting-user"`).

Report: "PR #N open (draft) — aggregated review posted — handed to external review." with the
facts above. AutoFlow ends; the session may terminate.

**[MUST]** AutoFlow merges nothing and promotes no draft. The hook denies `gh pr merge` and a push
to the default branch.

What follows an external merge or close — the attempt's branches and records included — is outside
AutoFlow ([`git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).

## An attempt with no state file

The attempt of the abbreviated path ([`abbreviated-path.md`](<autoflow-root>/docs/abbreviated-path.md)) has no state
file, and its pull request was opened from its dev branch outside a cycle. U7 reviews it alone,
entered by `/autoflow:cycle-u7 <N>`, and returns its result to the coordinating session, which
decides what follows.

- **Where it runs.** In a checkout of the repository — the same origin — whose checked-out branch
  is the attempt's dev branch at the pull request's head: the `claude` reviewer reads that working
  tree beside the pull request's diff, and `review-gate.sh` finds the attempt's record directory
  from the checkout's origin and the checked-out branch. It need not be the checkout that owns the
  attempt. The attempt and its pull request are read from the `dir:` and `pr:` lines
  `cycle-status.sh --issue <N>` prints for it in any checkout; its entry — `abbreviated <key>` in
  the owning checkout, `stop other-checkout <key>` in another — is not a condition of the review.
- **What runs.** *Reviewer review*, with `--records <attempt-dir>`; *Review aggregation*,
  unchanged — one PR comment and the findings file per round, every `Medium`+ row that holds tagged
  with its `remedy_class` — with the aggregator's prompt also naming the review records and the
  comments of the pull request's earlier rounds, which *A repeated complaint* compares against in
  place of a `[review-autofix]` entry; and *The case*, whose `case:` line is the verdict —
  `clean`, `low-only` or `resolve` (a `Medium`+ verdict). A rebuttal from the work is posted on the
  pull request with its grounds and judged by the next round's aggregation (*Whether a finding
  holds*).
- **CI.** Read with `bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <P>` and returned
  as it is: green (exit `0`), red (`12`), no check published (`11`) together with whether the pull
  request records that CI does not run for it, or no verdict, not mergeable or inconclusive (`13`,
  `10`, `14`). Nothing is read as green, and the review records no not-run itself.
- **What it does not do.** No state file is created, read or required: no `review-triage` marker
  and no *End* write. A `Medium`+ row's class routes nothing — no `remedy-route.sh`, no BUILD unit
  re-run, no ARCHITECT re-entry, no `phases.gate_quality.remedy_class`, no `[review-autofix]`
  entry, no advisor criteria of *Routing*; the rework is the work outside AutoFlow. No attempt cap
  and no `[autoflow:review-autofix]` comment: `review-gate.sh`'s `attempts:` line and `cap` case
  count `[review-autofix]` entries, which the path never writes, and are not read.
- **The return.** The end report carries the pull request's URL and head commit, the verdict, the
  findings file and the round's comment, the CI result as read, and the round count: this round's
  `k`, which every review record's name carries — a new round's `k` is one more than the highest
  the attempt's review store holds for that pull request — with the rework count `k − 1`.

<!-- From <autoflow-root>/docs/reviewer-backend.md -->

# Reviewer Contract

REVIEW reviews every pull request a cycle opens with the reviewers the operator's
configuration names and aggregates their reviews into one verdict
([ADR-0026](<autoflow-root>/docs/records/adr/0026-aggregated-review.md),
[ADR-0033](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)). This document
is the single home for the reviewers — who reviews, on what input, what each one
leaves, their configuration, and their start-confirmation oracle. How a round
runs and how its reviews are aggregated is
[`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review* and *Review
aggregation*.

## Reviewers

Every reviewer is run by its own script, in the reviewed repository's working
directory, with an environment fitted to its CLI; no two reviewers share one.

| Reviewer | Input | Runtime |
|----------|-------|---------|
| `claude` | the PR (diff, body, linked issue), its rule file, and the cycle's design artifacts in the attempt's record directory `--records` names — analysis report, feature design, verification design, decision ledger, build report | `<autoflow-root>/scripts/review/claude-review-pr.sh` — `claude -p` with Read, Grep and Glob (on any path), the `gh` reads the review needs, the commands Claude Code itself treats as read-only, and whatever the operator's own `~/.claude/settings.json` allows — every other tool and every write denied without a prompt (`--permission-mode dontAsk`); the reviewed repository's own `.claude/` settings and `CLAUDE.md` are not loaded (`--setting-sources user`), since in a trusted checkout its permission rules would add tools; the prompt carries the rule file's text, and the final message is the review |
| `codex` | the PR (diff, body, linked issue), its rule file | `<autoflow-root>/scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, which loads that tree's `AGENTS.md` itself; the prompt carries the rule file's text |
| the target's side | what that system reads | a review a system on the target's side runs on the pull request by itself — a review bot — read by the aggregator from the pull request ([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Review aggregation*) |

A new reviewer is a name the resolver supports
(`<autoflow-root>/scripts/review/lib/review-config.sh`), its wrapper and its
rule file.

## Rule files

The review rules every reviewer applies — posture, severity levels, method,
lenses and Output Format — are
`<autoflow-root>/docs/review/review.md`. Each reviewer's own rule file, beside
it, names what that reviewer reads and where its review goes:
`<autoflow-root>/docs/review/review-claude.md`,
`<autoflow-root>/docs/review/review-codex.md`, each of which carries the review
rules (`<autoflow-root>/docs/core.md` > Context Injection). The wrapper's prompt
carries the rule file's text, and states what `<autoflow-root>` is.

Per reviewer, two keys of the configuration (*Config location*) replace or add
to these:

- `.review.<reviewer>.rules` — another rule file in place of
  `<autoflow-root>/docs/review/review-<reviewer>.md`; the prompt carries that file alone, so it carries
  or cites the rules and Output Format its reviewer applies. A wrapper whose rule file is absent
  stops (exit `2`) before the reviewer starts.
- `.review.<reviewer>.lenses` — a file of further review lenses (the defect
  axes `<autoflow-root>/docs/review/review.md` > Review Lenses lists), which the prompt carries
  beside the rule file. Absent from a repository, it is left out of that
  repository's review, with a line on stderr.

A relative path is read from the root of the checkout the wrapper runs in, so
one entry can name each target's own file.

## Contract

```
Contract: reviewer
  Output : one review record per reviewer, PR and round —
           <attempt-dir>/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md —
           in the <autoflow-root>/docs/review/review.md Output Format, in Korean.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (<autoflow-root>/docs/units/review.md > Review aggregation)
  Input  : every review record of the PR and round, and the reviews the
           target's side left on the PR.
  Output : one PR comment; the PR's findings file (source and disposition per
           finding). A finding the aggregator rejects is recorded with its
           grounds and counts toward no verdict.
```

Each wrapper takes the record path:

```
<autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>] [--records <attempt-dir>]
<autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>]
```

Each stops (exit `3`) when the PR is not that OPEN PR on that head branch, and
treats a run that leaves no record as failed (exit `5`).

## Config location

The reviewers are configured in one file, the operator's
`~/.autoflow/config.json` (`$HOME/.autoflow/config.json`), created once by the
plugin's SessionStart hook (*Operator file* below). A target's
`.claude/autoflow.local.json` is not read for reviewers: the reviewers AutoFlow
runs are the same in every project
([ADR-0033](<autoflow-root>/docs/records/adr/0033-review-unit-and-script-reviewers.md)).

```json
{ "review": { "reviewers": ["claude", "codex"] } }
```

The file is read by `<autoflow-root>/scripts/review/lib/review-config.sh`,
type-aware (the key's JSON type first, then its value). `.review.reviewers`
lists the reviewers that run. When it is absent, `null` or `[]` it names none of
its own, and the default reviewers run — `claude` and `codex`; so do they when
the file is absent. Each reviewer's model, effort, rule file and lenses file
come from the same file (*Rule files*, *Model and effort*).

The file **cannot be read as configured** when it is present while `jq` is not
on PATH, is not valid JSON, has a non-object `.review`, a `reviewers` value that
is not an array of supported names, or a per-reviewer value *Model and effort*
or *Rule files* rejects. It never fails closed. It is checked whole — every
condition above, the list and every supported reviewer's settings — on every
run, so every consumer reaches the same verdict on the same file. When it
cannot be read, nothing in it applies and no reviewer runs: the readout names
it (`source: user <path>`), and every consumer prints the fixed marker line
`user-config: UNREADABLE <path> — <error>` and exits `6` — distinct from success,
from exit `2` and from every exit below; no wrapper starts its reviewer. The
orchestrator asks the operator whether to proceed without those reviewers
([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *Stop conditions*,
[`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*): proceeding runs the
round on the reviews of the target's side alone; stopping leaves the operator
to fix the file and run the step again, which reads it anew.

### Operator file

The plugin's SessionStart hook, `<autoflow-root>/hooks/ensure-user-config.sh`,
runs at every session start in every project the plugin is enabled in. When
`~/.autoflow/config.json` is absent it creates it, outside the target's tree,
with

```json
{ "review": { "reviewers": [] } }
```

— no reviewer named, so the default reviewers run until the operator lists them
there — and only then tells the operator where it is and what it holds. An
existing file is never changed, broken or not. Concurrent session starts create
it once: the content is written to a temporary file and published with a hard
link, which fails when the file exists, so a file another session created is
never overwritten, only the creating session notifies, and no reader sees a
partial file. The same file holds the operator's other AutoFlow values — the
record root, `record_root` ([`state-tracking.md`](<autoflow-root>/docs/state-tracking.md) > *Record
location*). Each key is read and validated by its own reader: an error in
`.review` does not touch the record root, and an error in `record_root` does not
touch the reviewers; a file that is not valid JSON, or no `jq`, leaves both
unreadable.

## Model and effort

Each reviewer's model and reasoning effort can be pinned in the operator file
(*Config location*). Every key is optional:

```json
{
  "review": {
    "reviewers": ["claude", "codex"],
    "codex": { "model": "gpt-6-sol", "effort": "high" }
  }
}
```

**Single source of truth.** `<autoflow-root>/scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by the live wrappers (`claude-review-pr.sh`, `codex-review-pr.sh`)
and `check-review-backend.sh` (presence path and `--probe`) from the plugin
root. It alone reads the file; no consumer reads it on its own.

**Flag mapping** (`build_review_backend_args`, the only place it is written):

| Reviewer | model | effort |
|----------|-------|--------|
| `claude` | `claude --model <model>` | `claude --effort <effort>` |
| `codex` | `codex exec --model <model>` | `codex exec -c model_reasoning_effort=<effort>` |

**Precedence** (per value, most specific first):

| Value | Order |
|-------|-------|
| model | `.review.<reviewer>.model` → the reviewer's default (`claude`: `opus`; `codex`: `gpt-6-sol`) |
| effort | `.review.<reviewer>.effort` → **inherit** |

**Inherit means no flag.** When the effort key is absent (or JSON `null`) the
wrapper passes none, and the CLI applies its own configuration (`claude`: its
settings; `codex`: `~/.codex/config.toml`, `model_reasoning_effort`). The model
default lives in the resolver so that a file that pins nothing still reviews on
it.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated):

| Reviewer | Accepted `effort` | Source |
|----------|-------------------|--------|
| `claude` | `low` `medium` `high` `xhigh` `max` | `claude --help` > `--effort` (Claude Code 2.1.304). |
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs`. |

**Rejected values** — part of "cannot be read as configured" (*Config
location*: the `UNREADABLE` result), always **before the reviewer launches**:

- `.review.<reviewer>` is present but not an object;
- `.review.<reviewer>.model`, `.effort`, `.rules` or `.lenses` is present but
  empty (`""`) or not a string;
- `.review.<reviewer>.effort` is a string outside that reviewer's vocabulary.

**Readout lines.** Every consumer prints where the configuration came from and
the operator file's state, in the same form:

```
source: user <path> | none
user-config: absent [<path>] | ok <path> | UNREADABLE <path> — <error>
```

Every diagnostic and remedy names the operator file.

**Start marker.** A wrapper's marker names the reviewer and the effective
model and effort — `[codex-review] starting codex for PR #<N>
(model=gpt-6-sol effort=high) at …`, or `effort=inherit` when none is pinned —
and prints nothing else from the environment (no credentials, no unrelated
variables). `--probe` prints the same summary as
`[check-review-backend] --probe: <reviewer> (model=… effort=…)` before its
round-trip, and passes the identical flags.

**Orchestrator vs. reviewer.** These pins govern only the reviewer subprocess;
the orchestrating session's own model and effort follow the user's session
settings, and the aggregator's the `handoff-review-triage` row of
`.claude/autoflow/spawn-policy.json`. None of them reads another.

## Availability (PREFLIGHT, advisory)

`<autoflow-root>/scripts/preflight/check-review-backend.sh` resolves the
reviewers through the shared resolver, prints them as one
`reviewers: <names|none>` line on stdout — the readout REVIEW runs them from
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*) — followed by the
`source:` and `user-config:` lines (*Model and effort* > Readout lines), and
probes each reviewer's CLI **presence only** (`command -v`):

| Exit | Meaning |
|------|---------|
| `0` | every configured reviewer's CLI is present |
| `1` | a configured reviewer's CLI is absent — named on stderr with its remedies (install it, or list the reviewers to run without it in the operator file) |
| `2` | usage error |
| `6` | the operator file cannot be read as configured — the marker line `user-config: UNREADABLE <path> — <error>`; no reviewer is checked |

PREFLIGHT records the result in the `preflight-review-config` record entry
([`units/preparation.md`](<autoflow-root>/docs/units/preparation.md) > *Stop conditions*). An absent
CLI does **not** stop the cycle: REVIEW runs the other reviewers without it and
the aggregated comment names the omission
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*). An unreadable
operator file (exit `6`) is put to the operator, who chooses between proceeding
without those reviewers and fixing the file. Auth is **not** probed here: a
present-but-unauthenticated reviewer passes and its auth failure surfaces at the
REVIEW run, where it counts as a failed run.

## On-demand auth probe (`--probe`)

`<autoflow-root>/scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured reviewer — the same model-API connection a `claude -p` or a
`codex exec` opens.

**Triggers — on-demand only:** the operator runs it after writing or changing
the reviewer configuration. It is **not** run per-cycle, is **not** wired into
PREFLIGHT, and **no hook consumes it** — a probe failure is narrated, never used
to gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded for every configured reviewer. |
| `1` | A configured reviewer's CLI is **absent** (no round-trip is attempted for it). |
| `2` | Usage error. |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | A reviewer's CLI is **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at the REVIEW run. |
| `6` | The operator file cannot be read as configured (*Config location*); no round-trip is attempted. The probe's report goes to the operator who ran it. |

## Start-confirmation oracle

`<autoflow-root>/scripts/review/review-start-check.sh --pr <N> [--reviewer <name>] [--repo <owner/name>] [--log <the run's output>]`
reads these signals for a reviewer's run and reports the first one it finds
([`units/review.md`](<autoflow-root>/docs/units/review.md) > *Reviewer review*): a running process
of that reviewer's CLI (`--reviewer`; reviewers run side by side on one PR) whose prompt names
`pull request #<N>`, or, for `codex`, a session rollout under
`~/.codex/sessions/` written since the launch whose prompt does; an advancing
rollout `mtime` is codex's long-run health signal, and the review runs in the
background to completion. Each wrapper closes its CLI's stdin (`< /dev/null`)
and prints the completion marker `[review] <reviewer> completed for PR #<N>
(exit=…)` when the subprocess returns; a non-zero exit means the run failed or
left no record. A wrapper that stopped on an unreadable operator file prints the
marker line `user-config: UNREADABLE …` instead and no completion marker;
`review-start-check.sh --log` reports it as exit `4`.

## Trade-offs

- **Two vendors, two inputs.** The `claude` review reads the cycle's design
  artifacts; the `codex` review reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The `claude` review runs on the same account allowance
  as the orchestrator, once per pull request and round.

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
- **Completed**: the file `completed` marks an attempt that is over, written by the record function `cleanup-issue.sh`; its records stay where they are ([`<autoflow-root>/docs/git-workflow.md`](<autoflow-root>/docs/git-workflow.md) > Post-Merge Cleanup).
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

**Completion**: at the end of REVIEW, once the aggregated review is clean (no PR's verdict is Medium+ — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT reads the file afterwards — review-response while its PR is open, set aside once it is merged or closed (`<autoflow-root>/docs/units/preparation.md` > *Modes*); what follows a merge or a close is outside AutoFlow (`<autoflow-root>/docs/git-workflow.md` > Post-Merge Cleanup).
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
