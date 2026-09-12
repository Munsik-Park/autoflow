# AutoFlow Design Rationale

This document explains the design intent and reasoning behind every major decision in AutoFlow.
Where CLAUDE.md describes **what to do and how**, this document explains **why** it was designed that way.

**Any new AI reading this repository should read this document first.**
Understanding the design intent takes priority over following the rules.
Without understanding the reasons, an AI may propose something that "looks better" but undermines a core principle.

---

## The Problems This System Solves

AutoFlow addresses structural problems that arise in AI-driven development environments.

### Problem 1: AI Is Biased Toward Solving the Moment It Receives an Issue

AI is trained to be helpful. The moment it receives an issue, the frame "this is a problem to solve" locks into its context. Even when analyzing code afterward, it tends to overlook parts where the existing structure already handles the concern, or proposes unnecessary code changes.

This is not a defect in AI. It is a byproduct of "be helpful" training. It cannot be fixed through training alone. **It must be blocked structurally.**

### Problem 2: A Single Session Cannot Effectively Challenge Its Own Reasoning

When analysis and evaluation happen in the same conversation, previously generated text influences subsequent generation (self-reinforcement). Evaluation converges toward "my analysis was correct." This is a structural problem inherent to the context window.

### Problem 3: AI Self-Reporting Is Unreliable

Even when an AI declares "PASS," whether that judgment actually meets the defined criteria is a separate question. AI tends to implicitly adjust standards while scoring, or interpret edge cases favorably.

---

## Core Design Decisions and Their Reasoning

### Decision 1: AI-A Does Not Receive the Issue Content (3-Phase Independent Analysis)

**What it does**

- **AI-A**: Analyzes code structure only — without seeing the issue content
- **AI-B**: Analyzes the issue text only — without seeing the code
- **Phase 3**: AI-A evaluates the *necessity* of AI-B's proposed resolution against the actual structure (reuse-neutral — not a structural-fit judgment)

**Why it works this way**

Information isolation is the key. If AI-A knows the issue, it starts looking for "structure that solves this problem." Without the issue, it sees the structure as it actually is. The information asymmetry between the two AIs creates the validity of cross-verification.

It is normal for AI-B to use zero tools. Its purpose is to analyze the problem from the issue text alone. If it reads code, it shares the same bias as AI-A, making Phase 3 verification purely ceremonial.

Claude is already trained to "give balanced answers." It rarely produces overtly one-sided responses. That is the effect of training. But the bias AutoFlow prevents is different. When Claude receives an issue, "I need to solve this" is already embedded in the context. When it analyzes code in that state, it reads existing structure that already handles the concern as "insufficient." There is no malice. It is correct, helpful behavior. That is precisely why training cannot catch it. Training blocks "bad answers." Structure blocks "good intentions aimed in the wrong direction." This is why information isolation is necessary.

**Why this design must not be changed**

The suggestion "let's give AI-A the issue for efficiency" destroys the core of this system. Bias prevention can only be achieved through information isolation. Claude's built-in bias mitigation training is effective at balancing response tone, but it cannot prevent context contamination.

---

### Decision 2: Evaluation AI Is Spawned Fresh Every Time

**What it does**

The Evaluation AI at GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY is created new for each invocation. It carries no prior conversation history.

**Why it works this way**

To start from a state with no trace of prior reasoning. When the same agent creates a plan and then evaluates it, it struggles to reject its own plan. A freshly spawned agent sees only the deliverable. It has no investment in the process.

**Bias elimination takes priority over cost**

"Reusing the same agent saves tokens" is factually true. But in this system, bias elimination takes priority over cost optimization. The quality of an expert system comes from the independence of its judgments.

---

### Decision 3: The Hook Does Not Trust AI's PASS Judgment

**What it does**

`check-autoflow-gate.sh` does **not** read the `pass` field written by the AI. It calculates the average, minimum, and security score directly from the raw `scores` object.

**Why it works this way**

To bring the trust chain down to the script level. An AI can implicitly decide "this is good enough to pass" while recording scores. The script ignores that judgment and looks only at the numbers. Numbers cannot be manipulated (within the system's constraints).

**What this means**

No matter how eloquently an AI says "the plan is excellent," if the scores don't meet the threshold, it cannot advance to the next phase. The gate operates on numbers, not explanations.

---

### Decision 4: The Pipeline Is Designed to Be Stateless

**What it does**

Each issue is processed independently. Past issue evaluation results do not influence the current issue's analysis.

**Why it works this way**

If a past evaluation was wrong and it influences the next evaluation, bias propagates. As incorrect judgments accumulate, the system hardens in a particular direction. Injecting past data into a pipeline whose principle is bias elimination undermines that principle.

**Improvement loops happen outside the pipeline**

Analysis of pass/fail patterns, modification of evaluation criteria, and identification of cross-issue correlations are performed by humans externally. Changes are reflected through CLAUDE.md and evaluation prompt modifications, with history tracked in Git. If the pipeline modifies its own criteria, it becomes impossible to trace which point in time had the correct judgment.

**However, factual lookups are different**

Injecting past evaluation results (bias injection) and looking up past code change history or issue context (factual lookup) are different things. Querying related issues and commit history at DIAGNOSE is allowed because it serves to accurately understand the current state.

---

### Decision 5: Phase Transitions Are Completion-Condition Based

**What it does**

Each phase transitions to the next only when its stated completion conditions are met.

**Why it works this way**

A completion condition is checkable after the fact — a recorded gate PASS, a Red or Green confirmation with its command and summary line, a PR whose CI is green — so a transition never rests on the transitioning AI's own sense of being done. The condition, not the AI, says when the next phase may start.

**History.** Until issue #227 this decision also read *All phases are performed regardless of change size*, on the ground that "this one is simple" is a pre-implementation judgment the AI cannot verify and so must not make. Decision 12 narrowed it for review-response cycles; Decision 17 retired it — the route and its depth are the working AI's recorded judgment, and what the retired rule protected, the independent checks, is what Decision 17 keeps fixed.

---

### Decision 6: Structure Evaluation FAIL = No Code Change Needed (close, or reply if a PR is open)

**What it does**

When the structure evaluation at GATE:HYPOTHESIS returns FAIL, no code change is needed — either because as-is already satisfies the request (Behavior gap low) or because the lever is data / config / ops, not code (Code-change necessity low). For the already-satisfied case the next action follows the cycle's `mode` (recorded at PREFLIGHT): if `mode = new-issue` (no open PR) the orchestrator auto-closes the GitHub issue with a comment recording the structure-evaluation scores and a summary of the existing mechanisms, and AutoFlow terminates locally (`active: false`); if `mode = review-response` (open PR) it instead replies on the PR with the finding and leaves the issue and PR open. For the non-code-lever case it reports to the user and pauses (reclassification as Type 2 / non-code is the re-entry). The gate scores *necessity only* and is reuse-neutral — a fix that leverages existing code is not a FAIL. (Canonical disposition: [`phases/analysis.md`](phases/analysis.md) — the DIAGNOSE analysis playbook.)

**Why it works this way**

A structure-evaluation FAIL on the **gap** item (Behavior gap for code issues, Content gap for doc issues) means as-is already satisfies the request — no code change is needed. The cheapest correct outcome is to stop and record that conclusion in a single auditable action, matching the principle that **the best code is code that is never written**. The gate scores *necessity only* and is reuse-neutral: a fix that leverages existing code is not a FAIL — only an already-satisfied behavior is.

Every disposition branch has a defined terminus, so no "FAIL but open" intermediate state is left for the orchestrator to interpret (which would put the disposition back in front of the bias the gate exists to prevent). In a **new-issue** cycle (`mode = new-issue`) the issue is auto-closed; if the human author disagrees, reopening or re-filing is the natural correction path. In a **review-response** cycle (`mode = review-response`) the issue's PR is open, so closing the issue would be wrong — the finding is posted as a PR reply and the cycle ends `active: false` / `awaiting-external-review`, handing the disposition to the same external review that owns the PR. The gate has exactly two items, so the only other FAIL is *Code-change necessity low* — a real gap whose lever is data / config / ops, not code; that is reported to the user and AutoFlow pauses (mirroring the non-code-root-cause exit at GATE:HYPOTHESIS), with reclassification (Type 2 / non-code) as the re-entry. The structure gate never re-DIAGNOSEs.

---

### Decision 7: All Loops Must Have Termination Conditions

**What it does**

Every repetition in AutoFlow (e.g., GREEN↔VERIFY test-fix cycles, GATE:QUALITY re-evaluation cycles, LAND retry attempts) has an explicit maximum retry count. No loop can run indefinitely.

**Why it works this way**

When a loop fails, the work does not simply stop. The failure cause is classified, and the flow regresses to the appropriate phase. When all retries are exhausted, the work is handed to a human. There is no scenario where a loop never terminates.

For comparison: review gate structures where two models find problems in each other's output (e.g., Codex-style mutual review) lack explicit termination conditions, creating infinite loop risk. AutoFlow blocks this through three mechanisms: **maximum regression count + cause classification + defined human escalation point.**

**This principle applies to all future additions**

When introducing any new loop structure to this system, it must have an explicit termination condition. A loop without a termination condition is not permitted. This is not a guideline — it is a hard constraint.

**The ARCHITECT deliberation is a conversation, not a retry loop** (issue #166)

The ARCHITECT deliberation is two participants discussing one topic in relayed turns, and it ends where a discussion ends: at the participants' own conclusion, when each in turn has nothing further to raise. What follows the discussion is a judgment, and it belongs to the next judge — GATE:PLAN's fresh Evaluation AI scores an agreed design, and the orchestrator routes a report that still carries an un-agreed point: discuss further, having prepared what the next discussion needs, or stop and put the question to the user. The human escalation point this decision requires is that stop. A discussion whose participants keep finding something worth raising is not a loop running away; it is a disagreement that has earned a human's attention, and the orchestrator's one judgment is what carries it there.

---

### Decision 8: Deliberation Runs in an Isolated Sub-Context (Delegated Facilitation)

**What it does**

Multi-teammate deliberation phases — ARCHITECT (Developer AI + Test AI design discussion) and the VERIFY cause-branch self-check exchange — run outside the orchestrator's context, and the orchestrator receives only a single structured result + artifact paths, never the round-by-round messages. The VERIFY exchange runs inside an isolated **facilitator** realized as a `Workflow` (the one runtime mechanism documented to keep intermediate results out of the caller's context): the Developer-AI and Test-AI self-checks run as in-script sub-agents and their exchange stays in workflow variables. The ARCHITECT discussion is, since ADR-0023 (issue #179), an **orchestrator relay of two persistent participants**: the Developer AI and the Test AI are spawned once for the discussion, woken in alternation by agent ID, and write every turn and their reports to a transcript file (`.autoflow/issue-{N}-architect-transcript.md`), returning one line each; a Record `Workflow` then reads the file and writes the artifacts. A companion append-only **decision ledger** (`.autoflow/issue-{N}-ledger.md`) records each settled decision with its grounds and authority, and a recorded decision is not re-opened without a new verified fact.

The realization matters because the obvious alternative does not exist: in Claude Code Agent Teams a spawned teammate cannot create its own team and the lead is fixed for the team's lifetime, so "a facilitator that leads a nested team" is not executable; a facilitator sub-agent relaying persistent participants is not executable either, since a woken participant's answer reaches only the session's main loop (ADR-0023, constraint 2); and a peer-teammate facilitator was rejected on a ground this repository has since withdrawn: peer-to-peer content was measured *not* to enter the lead's stream. The peer-facilitator alternative is recorded as reopened, not adopted. Observed, not guaranteed — reproduce via `tests/manual/issue-52-manual-scenarios.md` > M1. For VERIFY, the `Workflow` runtime is the mechanism whose isolation is actually documented, so the contract binds to it rather than to an abstract "sub-context". For ARCHITECT the per-turn respawn that the `Workflow` implied was measured to cost 195 calls and 93 minutes per discussion because a memoryless turn re-verifies everything (ADR-0023, Context), so the rule's realization clause was superseded there: relay order and the two-consecutive-`further: none` end condition are computed by a decidable-state script (`scripts/architect/relay-state.sh`) over the transcript file and obeyed by the orchestrator's procedure; isolation is held by the participants' prompt (bodies to the file, one line back). What the rule protects — the orchestrator never holds deliberation prose — is unchanged; the effect record of the change is in ADR-0023 D4.

**Why it works this way**

A teammate→lead message is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator leads the discussion, every round of cross-talk — including the two teammates' near-duplicate convergence reports — accumulates in its context. The harm is not only token cost: retracted claims, wrong oracles, and reversed scopes pile up in the orchestrator's working context, and it begins to oscillate on decisions it had already settled. This was observed directly in issue #189, where the orchestrator flipped a scope decision (FOLD-IN ↔ KEEP-SEPARATE) while submerged in a back-and-forth that mixed live and retracted claims.

This is a context-contamination problem of the same family as Problem 2 (a single session cannot effectively challenge its own reasoning) — but here the contamination flows *into the coordinator* from the teammates it coordinates. Cheaper or summarized rounds (the file-pull / checkpoint-summary direction) do not fix it, because the orchestrator still receives the round and still accumulates the duplication. The fix is structural: remove the orchestrator from the deliberation loop entirely. The deliberation runs in an isolated context; only a structured report crosses back.

The decision ledger is the second half of the fix. Isolation stops new contamination from entering; the ledger stops already-settled decisions from being silently re-opened by an enlarged context. Re-opening requires a *new verified fact* — not a re-reading of material already on the record — which caps oscillation-driven round explosion. This is the same principle as a settled gate verdict outranking a re-reading of the issue body.

**Isolation is for deliberation, not verification**

The orchestrator's real value is verification, and that value is preserved. In the issue #189 session, every substantive catch — a refuted provenance claim, a wrong "0 failed" oracle, a RED test that copied a mock boundary — came from the orchestrator reading the *distilled artifacts and deterministic facts*, never from reading the deliberation prose. So the rule removes only the prose: after the report returns, the orchestrator still reads the artifacts and runs deterministic spot-checks (`git show`, command re-run) before accepting. "The orchestrator does not deliberate" is correct; "the orchestrator does not verify" would discard the system's main safeguard.

**Why this design must not be weakened to a summarization tweak**

The tempting shortcut is "have the teammates report more cheaply" or "summarize each round before it reaches the orchestrator." Both leave the orchestrator in the loop and therefore leave the duplicate accumulation and the oscillation in place. Delegated facilitation is not a cost optimization that happens to reduce tokens; it is a bias-elimination mechanism that happens to reduce tokens. Replacing it with a cheaper in-loop variant reintroduces the bias it exists to prevent.

### Decision 9: HANDOFF Acts on Its Own Configured-Reviewer Review Before Handing Off (Bounded Auto-Resolution)

**Problem.** AutoFlow's terminal phase originally ran the per-PR reviewer review and then ended unconditionally, leaving any `blocked-by-review` label (Critical/High/Medium findings) for a human to notice and re-trigger. The findings the methodology itself produced sat idle until someone re-invoked the issue.

**Decision.** HANDOFF adds a review-triage step after the reviewer review. If the reviewer verdict is `Medium` or worse, the orchestrator auto-enters a review-response cycle in-session with the reviewer comment as the DIAGNOSE trigger — reusing the existing review-response machinery (DIAGNOSE target, loop check, gates, re-HANDOFF, re-review) rather than introducing a new phase. If the label was cleared (only Low or no findings), the orchestrator judges the Low findings by pure agent judgment and decides whether to fix them. This deliberately extends AutoFlow's reach past the "end at PR creation" reflex: the methodology now resolves its own review output before handing the PR off, while still never merging.

**Why it is safe.**
- **The orchestrator never clears the label.** The gate hook denies `--remove-label blocked-by-review` unconditionally, so **removal** authority remains reviewer-only: only the configured isolated reviewer subprocess's re-review can take the gate off. **Attach** is reviewer-primary with an orchestrator backstop — the reviewer attaches the label whenever its review confirms a `Critical`/`High`/`Medium` finding on a PR the label is absent from, and HANDOFF's step-6.5 triage re-attaches it when that attach did not land ([`autoflow-guide.md`](autoflow-guide.md) > HANDOFF, `max_severity ≥ Medium` but the label is absent). The backstop is safe precisely because it is one-directional: attaching only ever *adds* signal, and an attach made in error is undone by a reviewer re-review, never by the orchestrator. Auto-resolution can only *fix code and re-trigger the review*; it can never declare itself clean. The fix trigger keys off the review **verdict (`max_severity`), not label presence alone** — `.codex/review.md` lets a clean review leave the label on if `--remove-label` fails, so a label-present / sub-Medium PR is routed to a reviewer re-review (or operator escalation), not a code-fix loop.
- **Backend-neutral (issue #979).** The review backend is selectable — `codex` by default, `claude` as an opt-in fallback (`.claude/autoflow.local.json` `.review.backend`; see [`reviewer-backend.md`](reviewer-backend.md)). This authority argument is backend-independent: it rests only on the reviewer running as an **isolated subprocess that does not load the orchestrator's `.claude/settings.json` gate hooks**, which holds for `codex exec` (a separate subprocess) and for neutral-cwd `claude -p` (project settings not discovered from a neutral working directory) alike. Whichever backend runs, it remains the sole authorized clearer of `blocked-by-review`.
- **The auto-loop is bounded.** A user-decision pause fires on any of four triggers (contract/AC change, ambiguous fix, `Low Confidence` item, loop-check match), and a hard cap of 7 auto-resolution attempts — counted as the *consecutive `review-autofix`-marked ledger entries since the last user re-entry decision (reset by that decision; if none yet this cycle, since the first auto-entry)* — escalates to the user. A monotone total is deliberately avoided: it would re-fire the pause immediately after the user has already approved continuation, defeating the pause's purpose. The window's sole reset anchor is the user re-entry decision. A per-PR label-clear is rejected as such a trigger — it is the wrong granularity for a per-issue cap and would let an oscillating loop run unbounded. This reuses the existing loop-termination and oscillation-guard mechanisms (Decision 7), so the new trigger source cannot loop without a termination condition. Cap-fire and user-re-entry events are additionally written as a one-line host-PR comment (prefix `[autoflow:review-autofix]`), so they survive the ledger's cleanup deletion and stay durably auditable; this is an audit note, not a gate input (the cap remains ledger-counted — see "No new gate surface").
- **No new gate surface.** The cap is tracked in the append-only ledger, not the state file, so the gate hook and its state-schema whitelist are unchanged. Re-pushes route through the existing AUDIT + GATE:QUALITY gates.

**The tempting shortcut** is to have HANDOFF auto-promote or auto-merge once findings are addressed. That is rejected: merging stays external (the host-PR `Closes #N` and the merge-sequencing workflow), and the orchestrator is structurally barred from clearing the gate label itself. Auto-resolution improves the PR that is handed off; it does not take over the hand-off.

### Decision 10: Gate Scoring Carries Its Own Counter-Hypothesis Step

**Problem.** The framework's confirmation-bias defenses divide into **counter-hypothesis forcing**, where the actor is made to argue the opposite case, and **evaluator independence**, where the actor is replaced by a disinterested one. The four rubric-scored gates carried only the Type-B device — independence — and none of the Type-A device; this decision adds it. Type-A appears at DIAGNOSE ("the code may not be the bug"), at ARCHITECT (first-exchange devil's advocate) and at RED (Red confirmation); Type-B is the gates' fresh-spawn evaluator (Decision 2) and the hook's distrust of a self-reported PASS (Decision 3). A fresh evaluator removes self-interest, but the scoring frame it inherits is still "how good is each item" — nothing asks "if this deliverable must FAIL, what is the ground?".

**Evidence.** **#287 cycle 1** — GATE:PLAN avg 8.8 and GATE:QUALITY avg 8.9 both PASS, contradicted in the same cycle by external Medium findings that those gates' own rubric items cover (`useSearchEnabled` mechanism misread → Feasibility; `/d/library` blast radius → Dependencies/Scope; a spec-seeded `search.enabled: true` masking the missing wiring → Test coverage). The response then was a model revert (`CLAUDE.md` > Spawn Model), which changed *who* scores, not *how*. **#309** ([`autoflow-guide.md`](autoflow-guide.md) > VERIFY) — three mock-masked integration gaps passed every internal gate and only external review caught them; the remedy adopted, the mock-boundary fidelity check at VERIFY step 4, was itself a counter-argument procedure. In both cases the defect was caught by an adversarial reading, and in both cases the fix the framework reached for was Type-A.

**Decision.** The Evaluation AI contract gains a pre-scoring step ([`teammate-contracts.md`](teammate-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis): form the "this must FAIL" hypothesis, search for its strongest rubric-framed ground with the deliverable's anchors re-derived from source, attempt refutation, and only then score. The search and its disposition are recorded in the additive `fail_hypothesis` output field, whose non-emptiness is enforced by the orchestrator's acceptance of the report (reject + re-spawn, capped), not by a machine validator — the hook still reads only `scores`.

**Conclusion recorded.** Independence is necessary but not sufficient: it removes self-interest, not the leniency framing. The pre-scoring FAIL hypothesis supplies the missing frame.

**What it does not do.** It is not a stricter gate. Rubric item counts, PASS thresholds (each ≥ 7, avg ≥ 7.5, security ≤ 3) and regression caps are unchanged, and a refuted FAIL case never moves a score — the obligation is to search, not to deduct. If gate FAIL rates rise materially after adoption, that is observable through the same evidence anchor the Spawn-Model revert rule uses (gate verdicts persist in the PR/issue thread).

**Route.** Recorded here rather than as a new ADR, per [`development-guideline.md`](development-guideline.md) > ADR Policy, which accepts "an ADR **or** a documented owner decision". The owner's own artifact makes that call: issue #40's *ADR 후보 대조* section defers the ADR-necessity judgment to DIAGNOSE intake triage and asks only that the relationship to ADR-0016 be recorded, while AC5 asks for the decision to land in this document. The relationship is the one ADR-0016 already set — extend an existing evaluation procedure rather than add a rubric item.

### Decision 11: A Late-Gate FAIL Re-enters at the Phase Its Cause Names

**Problem.** GATE:QUALITY, VALIDATE step 1 and INTEGRATE each failed to a single destination — RED — regardless of why they failed. The evaluator already produces per-item scores and reasons; the routing discarded that information, and every FAIL re-ran test writing, implementation, verification, refactor, the whole-tree sweep, the security audit and a full ten-item re-score.

**Evidence.** **#138 cycle 1** — GATE:QUALITY failed three times (ledger O5, O7, O9), each time on the single item `Doc updates` with the other nine items passing; each FAIL re-ran the full tail of the cycle (about 5.7 h, five whole-tree runs, three `opus` Developer AI spawns, three full ten-item re-scores) to change two to four lines of documentation per attempt. In the same session, VERIFY's cause-branched path returned a `fix_test` verdict to RED alone and was Green again in 35 minutes — the cost difference between a routed and an unrouted failure, measured in one session.

**Decision.** The evaluator tags each failed item with a `remedy_class` (`doc` / `test` / `impl` / `design`, or `operator` when it cannot say), and the orchestrator re-enters at the nearest phase that can make that kind of change — a doc commit, RED, GREEN, or ARCHITECT; mixed classes go to the farthest point ([`autoflow-guide.md`](autoflow-guide.md) > GATE:QUALITY > FAIL routing; `scripts/gate/remedy-route.sh`). Re-entry re-scores only the failed items and any inherited item the re-entry diff touched. The `doc` route, which skips RED / GREEN / VERIFY, carries a class-level remedy obligation: the fix anchors on a repo-wide sweep record the hook checks before the doc commit, because #138's second and third FAILs were residual sites of a kind the first remedies had already fixed elsewhere. VALIDATE and INTEGRATE failures branch the same way (`test` / `impl`; INTEGRATE is fixed `impl`).

**What it does not do.** Caps and escalation timing are unchanged — `max 3×`, escalation on the fourth FAIL; the cap counts FAILs, not the distance travelled. The classification is the evaluator's, never the implementing role's (the VERIFY arbitration principle), and an item it cannot classify pauses for the operator rather than being routed with its neighbours. A `doc` re-entry runs only what the doc diff requires; since ADR-0024 (issue #225) no phase runs the whole tree locally — regression verification is CI's at HANDOFF.

**Route.** This is the methodology's second deliberate divergence from upstream (`CLAUDE.md` > What This Repo Is), taken as an **operator decision** — the issue (#140) was filed by the operator and the change was executed as operator work outside an AutoFlow cycle. Recorded here rather than as a new ADR, per [`development-guideline.md`](development-guideline.md) > ADR Policy.

### Decision 12: A Review-Response Cycle Whose Scope Is Mechanically Bounded Re-derives Less, Verifies the Same

**Problem.** A reviewer's Medium finding on an open PR re-opens the cycle, and that cycle re-ran everything a new issue runs: a structure analysis of a codebase that had not changed, a full design deliberation over a one-function fix, a security audit that re-confirmed the previous cycle's conclusions. And the one signal that would have caught the finding before hand-off — a /simplify suggestion REFINE had rejected as behavior-changing — sat in a report no phase read.

**Evidence.** **#130 cycle 2** — 12 lines of shell changed, 13 minutes spent writing the test and the fix, 1 h 58 min and about $59 for the cycle; 89% procedure. The cycle-2 structure analysis was longer than cycle 1's (450 vs 271 lines) over an unchanged structure; the deliberation produced 14 new ledger entries for a one-function change. In cycle 1, REFINE's `Rejected / deferred` list contained the exact proposal the reviewer later filed ("expose the resolved `ARCHIVE_ROOT`"), correctly refused as behavior-changing — and nothing downstream read that list.

**Decision.** Four changes. (1) REFINE writes a report with a mandatory *out-of-scope observations — guard / boundary logic touched* section, and GATE:QUALITY's fresh evaluator dispositions every entry as scoring input (`refine_observations`). (2) HANDOFF triage appends a `scope-bounded` judgment to the findings file — a set relation computed by `scripts/review/scope-bounded.sh` (every Medium+ finding names a file; those files ⊆ the PR's diff file set), re-checked after GREEN (a fix that adds a file leaves the bounded path). (3) On the bounded path the previous cycle's artifacts are preserved and Phase A is reused, ARCHITECT's brief states the bounded scope, and AUDIT re-scores the prior Low list on the change surface. (4) GATE:PLAN, RED, GREEN, VERIFY, REFINE, the whole-tree sweep, GATE:QUALITY, CI and the reviewer re-review are unchanged.

**What this does to the "no size judgment" rule.** The rule above (*All phases are performed regardless of change size*) was written against a specific actor: the implementing AI judging its own change small and skipping verification. That actor no longer makes the call — the judgment here is a set relation over files, computed by a script — the finding file set written down, the PR diff file set re-derived from its anchor (`gh pr diff <N> --name-only`) — so a reader re-computes it; the implementing role never sees or sets it. And the verification the rule protected is not what the bounded path removes: it removes *re-derivation* (a structure description of an unchanged tree, an unnarrowed deliberation over a single function, an audit re-confirming itself), while every independent check — the gates, the whole-tree sweep, CI, and the external reviewer's re-review — runs unchanged. Two of those (CI and the external reviewer) did not exist when the rule was written; they are the backstop that makes the policy change safe to take. Decision 17 later retired the rule itself; this paragraph stays as the record of its first narrowing.

**Route.** Operator decision, recorded here per [`development-guideline.md`](development-guideline.md) > ADR Policy; the issue (#135) was operator-filed and the change operator-executed. The *No lightweight mode* limitation was narrowed accordingly at the time — no lightweight mode for a new issue; a bounded path for a review-response cycle, selected by a mechanical rule — and Decision 17 later retired it.

---

### Decision 13: A Test Exists Only When It Is Needed; Acceptance-Criterion Reductions Pass Through Three Tiers

**Problem.** The flow's default was *everything verifiable gets a test*, and nothing asked whether a given test was worth its cost. ADR-0018 bounded verification **depth** — layers against other layers — but not individual tests, and VERIFY step 3 asked a coverage question ("is any part of the impl diff uncovered?") whose only answer-shaped remedy is one more test. Separately, ADR-0020 stopped the run for the operator on five finding kinds, three of which (`not-carried`, `deferred`, `weakened`) describe *how* a criterion is verified rather than *what* it says.

**Evidence.** A prior cycle authored an equality assertion over a shipped sample file — the sample's literals against a spec table. The subject is user-editable, so the assertion loses its subject at the target's first edit; its cost was paid at authoring, at every verification run in the cycle, and in maintenance, while its absence would have cost nothing at any point (no consumer requires the sample to hold any particular literal; the behavior that reads the sample had its own coverage). The test existed because the default was *test it*, not because a question about it was answered.

**Decision.** A test exists only when it is needed, and the burden of proof lies on the test — not on its absence. Necessity has two inputs, answered in the verification-design row: **required behavior** (does a consumer actually require this behavior or contract?) and **cost of absence** (who loses what, concretely, if this breaks after merge?). A proposal that cannot answer both is not written, and under uncertainty the disposition is `none` — the asymmetry is the evidence above: the unneeded test's cost is real and recurring, the missing test's cost on such subjects was nil. The per-criterion disposition vocabulary is closed (`automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` / `none`) and every non-`automated` issue-AC row states a one-line reason; automated rows carry a kind (`driving` / `regression` / `characterization`) that is also RED's expectation. Acceptance-criterion reductions pass three tiers: the deliberation chooses a reduced disposition **with its reason in the row**, the external reviewer judges every reduction and reason from the host PR body, and the operator is asked only when the criterion's **content** must change. Reconcile's finding set narrows to `dropped` / `unreasoned` / `substituted`, and issue #160 then retires `substituted` — the one semantic kind — leaving the two findings a non-judging channel can compute (the "does the row verify the AC's property" judgment moves to GATE:PLAN `Test plan`); issue #166 then retires the Reconcile check itself, leaving the three tiers standing on the orchestrator's routing of the deliberation report and the two gates' AC-authority checks; VERIFY step 3 keeps its name and becomes a scope check. Authority: [`adr/0022-test-necessity-and-three-tier-ac-guard.md`](adr/0022-test-necessity-and-three-tier-ac-guard.md), amending ADR-0020.

**What was rejected.** Making configuration/data and implementation internals *exempt categories* — refused, because that converts a judgment back into a classification, and both "production config boots the app" and "every reference resolves" can be entirely worth their cost; the two areas stay as guidance notes, the same two judgments applied where they are most often answered wrong. Keeping the coverage form of VERIFY step 3 alongside a necessity clause at ARCHITECT — refused, because the two contradict each other inside one cycle: the design declines a test on necessity grounds and step 3 then reports the same code as an uncovered hunk whose remedy is that test. Letting the comparison channel judge whether a stated reason is good — refused on ADR-0020's own ground, that this judgment is capturable by a well-written rationale.

**What it costs.** `none` under uncertainty will sometimes be wrong, and the miss surfaces after merge; the tiers bound it rather than remove it — the reviewer sees every reduction with its reason, and the recorded reason makes a wrong call diagnosable. The operator loses sight of reductions the ADR-0020 pause used to show them; that transfer of attention is the intent, and it is safe only because the reviewer tier is mandatory and its input sits in the PR body. And one finding kind retires with no replacement gate: a criterion `deferred` out of the cycle with a stated reason now leaves the deliberation without an operator decision, and tier 2 is where a postponement that should have been an issue split is expected to be caught.

---

### Decision 14: PREFLIGHT Has a Call Site for the Target's Own Readiness Procedure, Not Knowledge of Any Tool

**Problem.** PREFLIGHT ran only what the framework itself needs — Git clean, remote sync, bundle drift, reviewer-backend presence. A target repository's own per-clone setup step (llmroute's commit-hook installer, documented there as a required setup step) had no point at which AutoFlow would read it, so a cycle could start with the target's lint chain uninstalled; six teammate commits in llmroute #279 skipped it, and the orchestrator swept 23 files at VALIDATE step 7 (issue #181). The same class had been recorded in the target's own docs once before.

**Decision.** PREFLIGHT gains one **call site**, `scripts/preflight/local-checks.sh`, that runs whatever the target declares under `preflight.local_checks[]` in its own scaffold `.claude/autoflow.local.json` — a `check` command (exit 0 = ready), an optional `repair` run once on failure and followed by a re-check — and stops fail-closed when a check does not pass. Nothing declared is a no-op, recorded as one line. The outcome goes to the ledger as an identifier-free record, never to the state file.

**Why a call site and not a rule.** The defect is a target property, not a methodology gap: what "ready" means differs per repository, and encoding one repository's tool (husky, lint-staged) in the framework would be wrong for every other target. A declaration slot generalizes; a rule about hooks would not. The lint-chain obligation at commit time (`submodule-common-rules.md`) is unchanged — the call site makes the chain *installed* before the first teammate commit; it does not substitute for running it.

**Why fail-closed and why the ledger.** A target that wrote a declaration meant it to run, so an unreadable declaration is an error, not an absent one — the same stance `check-review-backend.sh` takes on an unreadable backend config. The record is a ledger line rather than a state-file field because the hook reads the state file as gate input and the ledger only advisorily: the new surface must add no gate and no schema change (issue #181 requirement 3).

### Decision 15: The Deliberation Owns Decisions; Everything Below Them Is Derived Where It Is Executed

**Problem.** llmroute #280 cost $427 at list price (613M tokens, 2 cycles) against $49 for the code change itself — the remaining ~$380 was procedure, retries and orchestration. The retries were not spread across the rubric: **all four GATE:PLAN FAILs were the single item `Dependencies`** (the list of affected files and side effects), every item it named was one RED met on first execution, and after the operator overrode the gate (ledger O6) the plan passed DISPATCH unchanged. Meanwhile the change requests that arrived *after* ARCHITECT — a reviewer Medium finding worth five production lines, a standing guard rejecting one instrument, a missing checklist row — each took the full-cycle path, because severity and not cause decided the entry point. And each pass re-produced its inputs whole: the transcript is append-only (6,529 lines by the last round), the scribe re-read it and re-authored the design documents every round (feature design 376 → 775 lines; the round-6 scribe alone 8.2M tokens), and a fresh GATE:PLAN evaluator re-read the result every time (7.2M → 25.6M).

**Decision.** Three changes, one mechanism (issue #192).

1. **ARCHITECT stops at the architecture decision layer** — decisions, their constraints, rejected alternatives with grounds, and the failure mode each verification layer catches. A change table of files, a per-suite disposition and an oracle's condition clause are **derived at RED/GREEN entry** by the roles that open those files anyway (`scripts/test/select-suites.sh` already owned suite selection). `Dependencies` leaves the GATE:PLAN rubric (5 items → 4).
2. **A review finding routes by cause, not by severity.** Every Medium+ finding is tagged with a `remedy_class` answering *does clearing this discard or change a settled decision?*; `scripts/gate/remedy-route.sh` — unchanged, the single owner since Decision 11 — picks the entry point. `design` runs the full review-response cycle; `impl`/`test`/`doc` take a thin route (one owning role, execution verification, a ledger delta, the same reviewer re-review). (Decision 17 later made the `design` re-entry point — a cycle from DIAGNOSE, or ARCHITECT on a brief — the orchestrator's recorded judgment.)
3. **Record and re-score by delta.** Only a cycle's first Record writes the documents whole; later ones append a `## Delta — round <n>` section and leave settled text untouched. GATE:PLAN gains the re-entry re-score narrowing GATE:QUALITY and AUDIT already had, reading that delta.

**The dividing line.** One question decides which layer a sentence belongs to: *if this were wrong, would the design have to be revisited, or would it just be fixed where it is found?* The first is the deliberation's; the second is not. This is why the `Issue AC` join key was **not** reduced along with the rest — an unverified acceptance criterion is the one defect class execution does not surface, because the suite passes green. Everything else the gate used to predict, execution reports.

**Why this is not a weakening of verification.** Removing an item from a gate would weaken it if the check disappeared. It does not: the affected-file set is now derived deterministically instead of predicted and graded, and a real miss still surfaces — at RED, at VERIFY step 1, or at the VALIDATE whole-tree sweep — and routes by the existing class rules. The trade is where the fact is met, and the same session measured both sides: a cause-branched RED re-entry ran 6–12 minutes and 1–3M tokens, while the same class of fact met at the gate cost a re-deliberation, a full document rewrite and a fresh full re-read. Decision 11 established proportional re-entry for late gates; this extends it to the entry point that still ignored cause, and moves the prediction burden off the gate that could not check it cheaply.

**What was rejected.** The same issue proposed changing the deliberation's participant composition (a designer plus a fresh adversarial critic, with the Developer AI and Test AI demoted to recipients), on the ground that four decision-overturning defects came from fresh evaluators and execution while the pair contributed none. The operator rejected it, and the ground is the counting rule: that tally counts only defects that **escaped** the deliberation, a set the participants who author the decisions cannot appear in by construction — anything they catch never becomes a decision. The same ledger records 315 agreed conclusions for that issue, including the pair correcting each other's citations, grounds and proposed oracles, and it records four fresh-evaluator FAILs the operator overrode as unnecessary. Composition may be revisited from observation once Decisions 15's three changes have run — with a counting rule that scores catches and false alarms, not escapes alone — rather than on this evidence.

### Decision 16: A Long-Lived Document Cites a Provision by Section and Sentence; a Line Number Belongs Only to a One-Shot Artifact Bound to a Commit

**Problem.** ADR-0024 cited other documents by line number 95 times, and 38 of the 50 rows in its adjustment-scope tables identified a provision by coordinate; the adjacent ADRs (0019, 0022) carried no line citation. Within the same cycle, the commits that retired cycle-scoped suites shifted a CI workflow file by two lines each, the citations drifted, and the orchestrator made two commits that changed nothing but citations (554d2de, 844ceec). The evaluator flagged "a line not in the table" and "a mis-pointed coordinate" every round, and AUDIT recorded as Low that a scope citation had swept in guard control flow (`if` / `exit 1`) beside the provision it meant. Separately, `docs/INDEX.md` > Quick Routing listed ADR file names by hand while `docs/adr/README.md` maintained the same list; issue #217 updated one and missed the other, and the evaluator flagged it twice (issue #221).

**Cause.** The `path:line` anchor convention exists so that an AI can re-derive a fact deterministically within the same commit — a teammate report, an evaluation report. That form leaked into long-lived documents (ADRs, design documents, rule documents, issue bodies, adjustment-scope tables), whose lifetime is not one commit. A line number presumes the cited document never changes; when it does change, the citation still looks valid while pointing at the wrong place, the mis-pointing draws review findings, and the commit that fixes the citations shifts others.

**Decision** (operator decision, issue #221).

1. **A long-lived document cites a provision by identity, not by coordinate**: the document, its section heading, and the provision's own sentence as a verbatim fragment. Line numbers are not used. The form is `` `<path>` > <heading chain> — "<verbatim fragment>" `` (for example `` `docs/autoflow-guide.md` > VERIFY > Detection record — "A check that did not execute is recorded as `not-run`" ``); a script or workflow file substitutes its function, `case` arm, or job/step name for the heading chain.
2. **A line number appears only in a one-shot artifact bound to one commit** — an evaluation report, a role report, a ledger grounds line for a fact of this tree — and always together with the commit SHA (`<path>:<line>` at `<SHA>`). Such an artifact is re-derived when the tree changes; that is its premise.
3. **One list, one home.** The same information is not maintained by hand in two places; a second location points at the first (`docs/INDEX.md` > Quick Routing points at `docs/adr/README.md` instead of naming ADRs).
4. **A set comparison ("all replaced or deleted") is made over provision identity** — section heading plus sentence. A coordinate is not an identity.
5. **The principle is enforced by rewriting the rule sentences and showing the form, not by adding a format checker.** The sentences in the rule documents that required a line-number anchor now distinguish the two lifetimes, and the ADR template shows the durable form.

**Why not a checker.** A pattern over `:<digits>` cannot tell a line citation from a step number, a duration or a version string, and a checker that could would leave the drift class untouched — the failure is the reference form, not its notation. The wrapper's Grounds check (`scripts/issue/create-issue.sh`) was the one place that mechanically admitted a bare line anchor; it now accepts a commit SHA, a URL, or a durable citation, since an issue body is a long-lived document.

**Scope.** Past ADRs and ledgers are not converted retroactively; the report formats of evaluators and roles keep their line numbers under rule 2.

---

### Decision 17: The Route Is the Working AI's Recorded Judgment; the Independent Checks Are the Rule

**Problem.** Issue #225 put the operator's four principles at `CLAUDE.md` > Rule Scope — principle 2 makes the route, the tests run and the reach of the work the working AI's judgment, recorded with grounds. Two rules still fixed the route regardless. *Every phase is mandatory: no skipping based on perceived simplicity* (Execution Principles) sent a documentation-only change through every phase: issue #217 changed five files in about eight hours, about five of them in the execution and verification phases. And HANDOFF step 6.5's *Only the `ARCHITECT` route runs the full cycle* sent every `design`-class review finding back to DIAGNOSE; #217 did that three times, once per review round. Two open proposals for relief, #193 (a new-issue lightweight path) and #195 (a conditional REFINE /simplify), were both written on the premise that the judgment must be a script's, not an agent's — the premise principle 2 reverses.

**Decision.** Operator decision (issue #227), three changes and no new device.

1. **The Execution Principle is replaced.** Which work phases a change passes through and how deep each goes is the working AI's judgment, recorded with its grounds in the ledger entry or phase report that phase already produces. What is never skipped is an independent check — an authority rule under principle 1: PREFLIGHT's readiness conditions, the gate score thresholds, the push / PR-creation gate, CI, the configured-reviewer review and its label, and the auto-resolution caps.
2. **The `design` re-entry point at HANDOFF step 6.5 is judged.** `scripts/gate/remedy-route.sh` still maps the class set to a route and `design` still means the deliberation owns the change; where that re-entry starts — a review-response cycle from DIAGNOSE, or an ARCHITECT re-deliberation on a `brief` — is the orchestrator's judgment, recorded with its grounds in the attempt's `[review-autofix]` ledger entry. The re-deliberation shape resets only the gate records it re-runs, so the hook's spawn gates admit exactly the roles whose preceding gate holds a recorded PASS, and it keeps the DIAGNOSE analysis artifacts in place under their flat names — GATE:PLAN and GATE:QUALITY read the acceptance-criterion table at its unchanged path — with each reused file's authoring cycle and hash recorded in the re-entry's ledger entry (PR #230 review, round 1). The seven-attempt cap, the loop check and the operator-pause criteria are unchanged.
3. **REFINE's /simplify run is judged.** Whether it runs and over what is the Developer AI's judgment on the diff, recorded in the REFINE report's `simplify:` / `simplify-grounds:` lines; the report is written either way and GATE:QUALITY reads it. The *skip bias* ground and the *do NOT skip* sentence are deleted; no predicate script or exclusion list is introduced.

**Why the devices need no change.** The hook never enforced phase order; it gates role spawns on the recorded PASS of the preceding gate, `git push` / `gh pr create` on AUDIT and GATE:QUALITY, and the merge on nothing (denied while active). A route that skips a phase therefore cannot skip the gate after it — a phase whose artifact a gate scores runs at least far enough to produce that artifact — which is the structural form of principle 3. `remedy-route.sh`'s mapping is unchanged (its header comment is updated, per principle 4); the Flow Control rows and the guide's step 6.5 restate the judged re-entry in words.

**What this does to Decisions 5, 12 and 15.** Decision 5's *all phases regardless of change size* is retired (its *History* note records the ground it stood on); Decision 12's narrowing of that rule stays as history; Decision 15's *`design` runs the full cycle* is revised to the judged re-entry point. The bounded path of Decision 12 — a set relation over files that selects which DIAGNOSE inputs are reused — is unchanged: it decides what a re-entry that runs DIAGNOSE re-derives, not whether DIAGNOSE runs.

**Dispositions.** #193 is closed as superseded: the judgment it wanted to give a script (a new-issue proportionality predicate that excludes the agent's estimate) is the judgment principle 2 gives the working AI, and its measurement criterion is the observation the Limitations list now names. #195 is closed as superseded by change 3: its predicate script and exclusion list are the shape principle 2 rejects, and its stated aim — no /simplify spawn on a diff that has nothing to simplify, with the grounds on record — is what the judged step 1 delivers.

**What it costs.** A route judgment will sometimes be wrong in the direction the retired rule feared — too shallow — and the miss surfaces at a gate, in CI or at review rather than in the skipped phase. The recorded grounds make each such miss attributable to the judgment that caused it, which is what an observation series needs; none has been collected yet (Limitations).

**Route.** Operator decision, recorded here per [`development-guideline.md`](development-guideline.md) > ADR Policy; the issue (#227) was operator-filed and the change operator-executed.

### Decision 18: A Gate Cap Binds Normative Documents; a Historical Record and a Re-score's New Finding Are the Evaluator's Recorded Judgment

**Problem.** Issue #228's GATE:QUALITY failed four times in a row, every implementation item passing and `Doc updates` capped at 6 each time, because past issues' manual-verification records (`tests/manual/issue-112-manual-scenarios.md` and its kind) still carried the names of devices the cycle deleted. Three remedy commits took about 70 minutes; the fourth FAIL escalated to the operator, who retired those records wholesale, and the fifth evaluation passed. Three rules combined to produce the loop. The reference-integrity check ([`autoflow-guide.md`](autoflow-guide.md) > GATE:QUALITY > Known blind-spot checks) capped the item on any remaining reference, without distinguishing a document someone follows from a record of a past state. The re-entry re-score was a fresh evaluator opening on *"this deliverable must FAIL"* ([`teammate-contracts.md`](teammate-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis), so each remedy's newly written sentences became the next evaluator's target — every report from the second to the fifth opened *"Adopted 'this Nth doc remedy must FAIL'"*, and the reports grew from 29 KB to 55 KB. And the `doc` re-entry's *wider sweep predicate on a second FAIL* obligation made each round rewrite more historical records, whose new sentences the next round flagged; the third evaluator itself wrote that three sweeps had each found a new loop. Under `CLAUDE.md` > Rule Scope a rule binds authority and prevents self-certification (principle 1), while whether a stale sentence in a past record is actually a problem is a judgment the AI makes and records (principles 2 and 3) — the three rules had made that judgment by rule.

**Decision.** Operator decision (issue #232), four changes and no device change.

1. **The reference-integrity cap binds normative documents only.** A normative document is what an agent or the operator reads and follows in a phase, what executes, and what is delivered — defined once, at the check itself, with the delivered set bounded by the manifest generator's link closure that already exists (`setup/gen-manifest-hashes.sh` > `compute_doc_closure`). A stale name in a historical record — a per-issue manual-verification record, a report-excerpt fixture, an ADR's change history, an archived cycle artifact — is the evaluator's judgment on whether it misleads a reader following the normative documents, recorded with its ground in the item's `reason`; a score reduction rests on that ground alone (issue #211's precedent of keeping old excerpts verbatim stands).
2. **A re-score's subject is the flagged defect.** On a re-entry evaluation the FAIL hypothesis takes the form *"the previously flagged defect still remains"*, and each prior finding is dispositioned `cleared` / `remains`. A defect newly seen on a re-scored item is still surfaced, and the evaluator judges and records whether it blocks — a blocking finding is scored, a non-blocking one goes to `recommendations` without lowering the item.
3. **The `doc` re-entry's sweep scope is judged.** The sweep still enumerates repo-wide, and the hook still checks that the record carries its command and output; which hits the remedy fixes — every hit in a normative document, a hit in a historical record only where the evaluator's recorded judgment named it — is the orchestrator's judgment, recorded in the same file. A second FAIL of the same class re-examines that judgment against the new report's grounds; a wider predicate is one possible outcome, not a rule.
4. **The report format carries the dispositions** (`rescore.prior_findings`, `rescore.new_findings` — [`evaluation-system.md`](evaluation-system.md) > Evaluation Output Format), so the orchestrator's acceptance of the report is the enforcement point, as it is for `fail_hypothesis` and `remedy_class`.

**Why the hook does not change.** Gate 5 checks that the sweep record exists with a non-empty `## Command` and `## Output` — the anti-self-certification device for a route that skips RED / GREEN / VERIFY. The scope judgment is prose in the same record, and the hook was never a reader of wording (`docs/gate-matching-standard.md` > P3). The gate thresholds (each ≥ 7, avg ≥ 7.5) and the `max 3×` cap are unchanged; what changes is what the cap keys on and what a re-score looks for.

**What it costs.** An evaluator may judge a misleading stale sentence harmless, and the miss then surfaces at the configured reviewer's review rather than at the gate — the same shape as Decision 17's cost, and attributable to the recorded judgment the same way.

**Route.** Operator decision, recorded here per [`development-guideline.md`](development-guideline.md) > ADR Policy, on the precedent of Decisions 11 and 17; the issue (#232) was operator-filed and the change operator-executed.

## Generalization Rationale

This repository is the **generalized form** of the AutoFlow methodology that originated in `ontology-platform`. The generalization is intentionally narrow:

1. **Name generalization** — upstream's numeric identifiers (`STEP 0~9`, `5a/5b/5c/5d/5.5/5.7`) are replaced by semantic phase names (`PREFLIGHT`, `DIAGNOSE`, `GATE:HYPOTHESIS`, `ARCHITECT`, `GATE:PLAN`, `DISPATCH`, `RED`, `GREEN`, `VERIFY`, `REFINE`, `VALIDATE`, `AUDIT`, `GATE:QUALITY`, `SHIP`, `LAND`). Each generalized name maps 1:1 to an upstream STEP.

2. **Single-repo adaptation** — concepts that exist in upstream solely because that repo is a submodule-based deployment orchestrator are dropped (STEP 7 submodule push, STEP 8 docker-compose integration, STEP 9 submodule-PR-first ordering, cross-project boundary rules tied to fork/upstream distinctions). The single-repo PR/merge flow remains.

Beyond these two adaptations, generalization adds nothing and removes nothing. Every rule, retry cap, evaluation category, score threshold, and regression path is preserved verbatim from upstream. New design improvements belong in `ontology-platform` first; this repository tracks upstream rather than evolving independently.

---

## Evaluation System Design Intent

### Why Scoring Criteria Are Not Fixed

The evaluation categories and weights in CLAUDE.md must be customized per project. They should reflect "what actually matters in this project," not universal standards. As a project matures, patterns emerge showing which items correlate with actual failures. At that point, humans adjust the criteria.

### Why PASS Criteria Are Strict (Average ≥ 7.5, Individual ≥ 7)

Lenient criteria create a pattern of "scoring high on easy items to raise the average while passing difficult items." This is why individual minimum thresholds exist. The reason security score ≤ 3 triggers mandatory rework is the same — some items cannot be diluted by averaging.

### The Role of Issue Analysis Evaluation (GATE:HYPOTHESIS)

The purpose is to ensure only well-analyzed issues proceed to implementation. Entering implementation with insufficient analysis incurs greater costs later. The stricter this gate, the higher the quality of subsequent phases.

---

## What Must NOT Be Done in This System

The following may look like "better approaches" but undermine core principles:

| Do Not | Reason |
|--------|--------|
| Give AI-A the issue content | Context contamination → bias introduced |
| Reuse the Evaluation AI | Self-reinforcement bias → independence lost |
| Trust the Hook's `pass` field | Trusting AI self-report → gate neutralized |
| Inject past evaluation results into current analysis | Bias propagation → system hardens in one direction |
| Skip an independent check — a gate threshold, the push gate, CI, the reviewer review — on a route judgment | A rule binds authority (`CLAUDE.md` > Rule Scope, principle 1); the route is the AI's to judge, the checks are not (Decision 17) |
| Let the pipeline modify its own criteria | Judgment tracing impossible → trust chain collapse |
| Design loops without termination conditions | No maximum retry → infinite loop risk → system hangs |
| Run a multi-teammate deliberation in the orchestrator's own context | Round-by-round cross-talk + duplicate reports accumulate → judgment contamination → decision oscillation (Decision 8) |
| Replace deliberation isolation with a cheaper in-loop summary | Orchestrator stays in the loop → duplicate accumulation and oscillation remain; it is a bias mechanism, not a cost tweak |
| Re-open a ledgered decision without a new verified fact | Re-reading the same material re-opens settled scope → oscillation-driven round explosion |
| Add improvements to this repository before they exist in upstream | Generalization is mirror, not branch — improvements diverge the methodology and break parity |

---

## Known Limitations and Ongoing Discussions

### Limitations

- **No failure learning loop**: No structured per-cycle evidence is captured; pass/fail pattern analysis is performed by humans externally.
- **No cross-issue correlation detection**: A complaint class recurring across distinct issues is not detected; correlation analysis across issues is human-external. Decision 4 (no auto-modification of rubric/criteria) is unaffected.
- **No measurement of judged routes yet**: Decision 17 makes a cycle's route and depth the working AI's recorded judgment, for new issues and review-response cycles alike. Whether that judgment is calibrated — what it skipped, and what a gate or the reviewer then caught — is read from the recorded grounds and the review outcomes after the fact, and no such series has been collected yet. Decision 18's evaluator judgments (a historical record's stale name; a re-score's new finding) join the same unmeasured series.

### Under Discussion

- Including related issue and commit history lookup at DIAGNOSE entry (factual lookup, not bias injection)
- Systematizing issue preparation stages through external cross-issue correlation analysis

---

## Behavioral Rule Authoring Style

Every behavioral rule in this system should have three elements:

1. **The action** — stated in positive form: "the AI does X."
2. **The reason** — why this action is required.
3. **Step instructions** — how to perform it, if non-obvious.

**Why positive form over negative prohibition**

Negative rules ("do not do X") leave loopholes: an LLM can reason "I did not do X, I did Y instead" and satisfy the prohibition while violating the intent. Positive rules anchor the behavior — "cite file paths and line numbers" is harder to route around than "no vague statements."

The classic failure mode: `[DENY] No opinions or leading phrases` — an LLM can silently reframe an opinion as a "neutral observation" and pass the check. The positive form breaks this: `[MUST] State observations as direct facts — cite file paths and line numbers` gives a concrete, verifiable action.

**When the forbidden-form note is still needed**

A forbidden-form note is appropriate when listing specific prohibited patterns. It is NOT a substitute for stating what the AI should do. Rule of thumb: the `[MUST]` positive action comes first; the prohibited forms are the safety net.

---

## Summary: The Design Philosophy of This System

**The pipeline's goal is not to get better with each run, but to perform well without bias every single time.**

Improvement does not happen automatically inside the pipeline. Humans observe patterns, make judgments, modify CLAUDE.md, and those changes take effect from the next issue onward. The pipeline is a tool that executes those criteria without bias.

When adding new features or modifications to this system, ask this question first:

> "Does this change eliminate a bias, or does it introduce one?"
