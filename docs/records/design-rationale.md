# AutoFlow Design Rationale

This document explains the design intent and reasoning behind every major decision in AutoFlow.
Where CLAUDE.md describes **what to do and how**, this document explains **why** it was designed that way.

**This document is not read first by every AI: which documents a role receives is routed per role (`CLAUDE.md` > Context Injection — Role-Scoped Document Routing), and this record is read when a decision's grounds are needed (`docs/INDEX.md` > Design and decision records).**
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

A completion condition is checkable after the fact — a recorded gate PASS, a Red or Green confirmation with its command and summary line, a PR whose CI is green — so a transition never rests on the transitioning AI's own sense of being done. The condition, not the AI, says when the next phase may start. Which phases a change passes through, and how deep each goes, is the working AI's recorded judgment (Decision 17).

---

### Decision 6: Structure Evaluation FAIL = No Code Change Needed (close, or reply if a PR is open)

**What it does**

When the structure evaluation at GATE:HYPOTHESIS returns FAIL, no code change is needed — either because as-is already satisfies the request (Behavior gap low) or because the lever is data / config / ops, not code (Code-change necessity low). For the already-satisfied case the next action follows the cycle's `mode` (recorded at PREFLIGHT): if `mode = new-issue` (no open PR) the orchestrator auto-closes the GitHub issue with a comment recording the structure-evaluation scores and a summary of the existing mechanisms, and AutoFlow terminates locally (`active: false`); if `mode = review-response` (open PR) it instead replies on the PR with the finding and leaves the issue and PR open. For the non-code-lever case it reports to the user and pauses (reclassification as Type 2 / non-code is the re-entry). The gate scores *necessity only* and is reuse-neutral — a fix that leverages existing code is not a FAIL. (Canonical disposition: [`phases/analysis.md`](../phases/analysis.md) — the DIAGNOSE analysis playbook.)

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

Multi-participant deliberation phases — ARCHITECT (Developer AI + Test AI design discussion) and the VERIFY cause-branch self-check exchange — run outside the orchestrator's context, and the orchestrator receives only a single structured result + artifact paths, never the round-by-round messages. The VERIFY exchange runs inside an isolated **facilitator** realized as a `Workflow` (the one runtime mechanism documented to keep intermediate results out of the caller's context): the Developer-AI and Test-AI self-checks run as in-script sub-agents and their exchange stays in workflow variables. The ARCHITECT discussion is, since ADR-0023 (issue #179), an **orchestrator relay of two persistent participants**: the Developer AI and the Test AI are spawned once for the discussion, woken in alternation by agent ID, and write every turn and their reports to a transcript file (`.autoflow/issue-{N}-architect-transcript.md`), returning one line each; a Record `Workflow` then reads the file and writes the artifacts. A companion append-only **decision ledger** (`.autoflow/issue-{N}-ledger.md`) records each settled decision with its grounds and authority, and a recorded decision is not re-opened without a new verified fact.

The realization matters because the obvious alternative does not exist: in Claude Code Agent Teams a spawned teammate cannot create its own team and the lead is fixed for the team's lifetime, so "a facilitator that leads a nested team" is not executable; a peer facilitator — a role spawn relaying the participants — is not executable either, since a woken participant's reply reaches only the session's main loop (`docs/records/adr/0023-deliberation-participant-lifetime.md` > Alternatives Considered, constraint 2); the current realization is the ADR-0023 relay. For VERIFY, the `Workflow` runtime is the mechanism whose isolation is actually documented, so the contract binds to it rather than to an abstract "sub-context". For ARCHITECT the realization is the relay: relay order and the two-consecutive-`further: none` end condition are computed by a decidable-state script (`scripts/architect/relay-state.sh`) over the transcript file and obeyed by the orchestrator's procedure; isolation is held by the participants' prompt (bodies to the file, one line back). The relay's ground is a measurement — a memoryless per-turn spawn re-verifies everything, 195 calls and 93 minutes per discussion (ADR-0023, Context; effect record in D4). What the rule protects — the orchestrator never holds deliberation prose — holds in both realizations.

**Why it works this way**

A teammate→lead message is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator leads the discussion, every round of cross-talk — including the two participants' near-duplicate convergence reports — accumulates in its context. The harm is not only token cost: retracted claims, wrong oracles, and reversed scopes pile up in the orchestrator's working context, and it begins to oscillate on decisions it had already settled. This was observed directly in issue #189, where the orchestrator flipped a scope decision (FOLD-IN ↔ KEEP-SEPARATE) while submerged in a back-and-forth that mixed live and retracted claims.

This is a context-contamination problem of the same family as Problem 2 (a single session cannot effectively challenge its own reasoning) — but here the contamination flows *into the coordinator* from the participants it coordinates. Cheaper or summarized rounds (the file-pull / checkpoint-summary direction) do not fix it, because the orchestrator still receives the round and still accumulates the duplication. The fix is structural: remove the orchestrator from the deliberation loop entirely. The deliberation runs in an isolated context; only a structured report crosses back.

The decision ledger is the second half of the fix. Isolation stops new contamination from entering; the ledger stops already-settled decisions from being silently re-opened by an enlarged context. Re-opening requires a *new verified fact* — not a re-reading of material already on the record — which caps oscillation-driven round explosion. This is the same principle as a settled gate verdict outranking a re-reading of the issue body.

**Isolation is for deliberation, not verification**

The orchestrator's real value is verification, and that value is preserved. In the issue #189 session, every substantive catch — a refuted provenance claim, a wrong "0 failed" oracle, a RED test that copied a mock boundary — came from the orchestrator reading the *distilled artifacts and deterministic facts*, never from reading the deliberation prose. So the rule removes only the prose: after the report returns, the orchestrator still reads the artifacts and runs deterministic spot-checks (`git show`, command re-run) before accepting. "The orchestrator does not deliberate" is correct; "the orchestrator does not verify" would discard the system's main safeguard.

**Why this design must not be weakened to a summarization tweak**

The tempting shortcut is "have the participants report more cheaply" or "summarize each round before it reaches the orchestrator." Both leave the orchestrator in the loop and therefore leave the duplicate accumulation and the oscillation in place. Delegated facilitation is not a cost optimization that happens to reduce tokens; it is a bias-elimination mechanism that happens to reduce tokens. Replacing it with a cheaper in-loop variant reintroduces the bias it exists to prevent.

### Decision 9: HANDOFF Acts on Its Own Configured-Reviewer Review Before Handing Off (Bounded Auto-Resolution)

**Problem.** AutoFlow's terminal phase originally ran the per-PR reviewer review and then ended unconditionally, leaving any `blocked-by-review` label (Critical/High/Medium findings) for a human to notice and re-trigger. The findings the methodology itself produced sat idle until someone re-invoked the issue.

**Decision.** HANDOFF adds a review-triage step after the reviewer review. If the reviewer verdict is `Medium` or worse, the orchestrator auto-enters a review-response cycle in-session with the reviewer comment as the DIAGNOSE trigger — reusing the existing review-response machinery (DIAGNOSE target, loop check, gates, re-HANDOFF, re-review) rather than introducing a new phase. If the label was cleared (only Low or no findings), the orchestrator judges the Low findings by pure agent judgment and decides whether to fix them. This deliberately extends AutoFlow's reach past the "end at PR creation" reflex: the methodology now resolves its own review output before handing the PR off, while still never merging.

**Why it is safe.**
- **The orchestrator never clears the label.** The gate hook denies `--remove-label blocked-by-review` unconditionally, so **removal** authority remains reviewer-only: only the configured isolated reviewer subprocess's re-review can take the gate off. **Attach** is reviewer-primary with an orchestrator backstop — the reviewer attaches the label whenever its review confirms a `Critical`/`High`/`Medium` finding on a PR the label is absent from, and HANDOFF's step-6.5 triage re-attaches it when that attach did not land ([`autoflow-guide.md`](../autoflow-guide.md) > HANDOFF, `max_severity ≥ Medium` but the label is absent). The backstop is safe precisely because it is one-directional: attaching only ever *adds* signal, and an attach made in error is undone by a reviewer re-review, never by the orchestrator. Auto-resolution can only *fix code and re-trigger the review*; it can never declare itself clean. The fix trigger keys off the review **verdict (`max_severity`), not label presence alone** — `.codex/review.md` lets a clean review leave the label on if `--remove-label` fails, so a label-present / sub-Medium PR is routed to a reviewer re-review (or operator escalation), not a code-fix loop.
- **Backend-neutral (issue #979).** The review backend is selectable — `codex` by default, `claude` as an opt-in fallback (`.claude/autoflow.local.json` `.review.backend`; see [`reviewer-backend.md`](../reviewer-backend.md)). This authority argument is backend-independent: it rests only on the reviewer running as an **isolated subprocess that does not load the orchestrator's `.claude/settings.json` gate hooks**, which holds for `codex exec` (a separate subprocess) and for neutral-cwd `claude -p` (project settings not discovered from a neutral working directory) alike. Whichever backend runs, it remains the sole authorized clearer of `blocked-by-review`.
- **The auto-loop is bounded.** A user-decision pause fires on any of four triggers (contract/AC change, ambiguous fix, `Low Confidence` item, loop-check match), and a hard cap of 7 auto-resolution attempts — counted as the *consecutive `review-autofix`-marked ledger entries since the last user re-entry decision (reset by that decision; if none yet this cycle, since the first auto-entry)* — escalates to the user. A monotone total is deliberately avoided: it would re-fire the pause immediately after the user has already approved continuation, defeating the pause's purpose. The window's sole reset anchor is the user re-entry decision. A per-PR label-clear is rejected as such a trigger — it is the wrong granularity for a per-issue cap and would let an oscillating loop run unbounded. This reuses the existing loop-termination and oscillation-guard mechanisms (Decision 7), so the new trigger source cannot loop without a termination condition. Cap-fire and user-re-entry events are additionally written as a one-line host-PR comment (prefix `[autoflow:review-autofix]`), so they survive the ledger's cleanup deletion and stay durably auditable; this is an audit note, not a gate input (the cap remains ledger-counted — see "No new gate surface").
- **No new gate surface.** The cap is tracked in the append-only ledger, not the state file, so the gate hook and its state-schema whitelist are unchanged. Re-pushes route through the existing AUDIT + GATE:QUALITY gates.

**The tempting shortcut** is to have HANDOFF auto-promote or auto-merge once findings are addressed. That is rejected: merging stays external (the host-PR `Closes #N` and the merge-sequencing workflow), and the orchestrator is structurally barred from clearing the gate label itself. Auto-resolution improves the PR that is handed off; it does not take over the hand-off.

### Decision 10: Gate Scoring Carries Its Own Counter-Hypothesis Step

**Problem.** The framework's confirmation-bias defenses divide into **counter-hypothesis forcing**, where the actor is made to argue the opposite case, and **evaluator independence**, where the actor is replaced by a disinterested one. The four rubric-scored gates carried only the Type-B device — independence — and none of the Type-A device; this decision adds it. Type-A appears at DIAGNOSE ("the code may not be the bug"), at ARCHITECT (first-exchange devil's advocate) and at RED (Red confirmation); Type-B is the gates' fresh-spawn evaluator (Decision 2) and the hook's distrust of a self-reported PASS (Decision 3). A fresh evaluator removes self-interest, but the scoring frame it inherits is still "how good is each item" — nothing asks "if this deliverable must FAIL, what is the ground?".

**Evidence.** **#287 cycle 1** — GATE:PLAN avg 8.8 and GATE:QUALITY avg 8.9 both PASS, contradicted in the same cycle by external Medium findings that those gates' own rubric items cover (`useSearchEnabled` mechanism misread → Feasibility; `/d/library` blast radius → Dependencies/Scope; a spec-seeded `search.enabled: true` masking the missing wiring → Test coverage). The response then was a model revert (`CLAUDE.md` > Spawn Model), which changed *who* scores, not *how*. **#309** ([`autoflow-guide.md`](../autoflow-guide.md) > VERIFY) — three mock-masked integration gaps passed every internal gate and only external review caught them; the remedy adopted, the mock-boundary fidelity check at VERIFY step 4, was itself a counter-argument procedure. In both cases the defect was caught by an adversarial reading, and in both cases the fix the framework reached for was Type-A.

**Decision.** The Evaluation AI contract gains a pre-scoring step ([`role-contracts.md`](../role-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis): form the "this must FAIL" hypothesis, search for its strongest rubric-framed ground with the deliverable's anchors re-derived from source, attempt refutation, and only then score. The search and its disposition are recorded in the additive `fail_hypothesis` output field, whose non-emptiness is enforced by the orchestrator's acceptance of the report (reject + re-spawn, capped), not by a machine validator — the hook still reads only `scores`.

**Conclusion recorded.** Independence is necessary but not sufficient: it removes self-interest, not the leniency framing. The pre-scoring FAIL hypothesis supplies the missing frame.

**What it does not do.** It is not a stricter gate. Rubric item counts, PASS thresholds (each ≥ 7, avg ≥ 7.5, security ≤ 3) and regression caps are unchanged, and a refuted FAIL case never moves a score — the obligation is to search, not to deduct. If gate FAIL rates rise materially after adoption, that is observable through the same evidence anchor the Spawn-Model revert rule uses (gate verdicts persist in the PR/issue thread).

**Route.** Recorded here rather than as a new ADR, per [`development-guideline.md`](../development-guideline.md) > ADR Policy, which accepts "an ADR **or** a documented owner decision". The owner's own artifact makes that call: issue #40's *ADR 후보 대조* section defers the ADR-necessity judgment to DIAGNOSE intake triage and asks only that the relationship to ADR-0016 be recorded, while AC5 asks for the decision to land in this document. The relationship is the one ADR-0016 already set — extend an existing evaluation procedure rather than add a rubric item.

### Decision 11: A Late-Gate FAIL Re-enters at the Phase Its Cause Names

**Problem.** GATE:QUALITY, VALIDATE step 1 and INTEGRATE each failed to a single destination — RED — regardless of why they failed. The evaluator already produces per-item scores and reasons; the routing discarded that information, and every FAIL re-ran test writing, implementation, verification, refactor, the whole-tree sweep, the security audit and a full ten-item re-score.

**Evidence.** **#138 cycle 1** — GATE:QUALITY failed three times (ledger O5, O7, O9), each time on the single item `Doc updates` with the other nine items passing; each FAIL re-ran the full tail of the cycle (about 5.7 h, five whole-tree runs, three `opus` Developer AI spawns, three full ten-item re-scores) to change two to four lines of documentation per attempt. In the same session, VERIFY's cause-branched path returned a `fix_test` verdict to RED alone and was Green again in 35 minutes — the cost difference between a routed and an unrouted failure, measured in one session.

**Decision.** The evaluator tags each failed item with a `remedy_class` (`doc` / `test` / `impl` / `design`, or `operator` when it cannot say), and the orchestrator re-enters at the nearest phase that can make that kind of change — a doc commit, RED, GREEN, or ARCHITECT; mixed classes go to the farthest point ([`autoflow-guide.md`](../autoflow-guide.md) > GATE:QUALITY > FAIL routing; `scripts/gate/remedy-route.sh`). Re-entry re-scores only the failed items and any inherited item the re-entry diff touched. The `doc` route, which skips RED / GREEN / VERIFY, carries a class-level remedy obligation: the fix anchors on a repo-wide sweep record the hook checks before the doc commit, because #138's second and third FAILs were residual sites of a kind the first remedies had already fixed elsewhere. VALIDATE and INTEGRATE failures branch the same way (`test` / `impl`; INTEGRATE is fixed `impl`).

**What it does not do.** Caps and escalation timing are unchanged — `max 3×`, escalation on the fourth FAIL; the cap counts FAILs, not the distance travelled. The classification is the evaluator's, never the implementing role's (the VERIFY arbitration principle), and an item it cannot classify pauses for the operator rather than being routed with its neighbours. A `doc` re-entry runs only what the doc diff requires; since ADR-0024 (issue #225) no phase runs the whole tree locally — regression verification is CI's at HANDOFF.

**Route.** This is the methodology's second deliberate divergence from upstream (`CLAUDE.md` > What This Repo Is), taken as an **operator decision** — the issue (#140) was filed by the operator and the change was executed as operator work outside an AutoFlow cycle. Recorded here rather than as a new ADR, per [`development-guideline.md`](../development-guideline.md) > ADR Policy.

### Decision 12: A Review-Response Cycle Whose Scope Is Mechanically Bounded Re-derives Less, Verifies the Same

**Problem.** A reviewer's Medium finding on an open PR re-opens the cycle, and that cycle re-ran everything a new issue runs: a structure analysis of a codebase that had not changed, a full design deliberation over a one-function fix, a security audit that re-confirmed the previous cycle's conclusions. And the one signal that would have caught the finding before hand-off — a /simplify suggestion REFINE had rejected as behavior-changing — sat in a report no phase read.

**Evidence.** **#130 cycle 2** — 12 lines of shell changed, 13 minutes spent writing the test and the fix, 1 h 58 min and about $59 for the cycle; 89% procedure. The cycle-2 structure analysis was longer than cycle 1's (450 vs 271 lines) over an unchanged structure; the deliberation produced 14 new ledger entries for a one-function change. In cycle 1, REFINE's `Rejected / deferred` list contained the exact proposal the reviewer later filed ("expose the resolved `ARCHIVE_ROOT`"), correctly refused as behavior-changing — and nothing downstream read that list.

**Decision.** Four changes. (1) REFINE writes a report with a mandatory *out-of-scope observations — guard / boundary logic touched* section, and GATE:QUALITY's fresh evaluator dispositions every entry as scoring input (`refine_observations`). (2) HANDOFF triage appends a `scope-bounded` judgment to the findings file — a set relation computed by `scripts/review/scope-bounded.sh` (every Medium+ finding names a file; those files ⊆ the PR's diff file set), re-checked after GREEN (a fix that adds a file leaves the bounded path). (3) On the bounded path the previous cycle's artifacts are preserved and Phase A is reused, ARCHITECT's brief states the bounded scope, and AUDIT re-scores the prior Low list on the change surface. (4) GATE:PLAN, RED, GREEN, VERIFY, REFINE, the whole-tree sweep, GATE:QUALITY, CI and the reviewer re-review are unchanged.

**What the bounded path removes.** The scope judgment is a set relation over files, computed by a script — the finding file set written down, the PR diff file set re-derived from its anchor (`gh pr diff <N> --name-only`) — so a reader re-computes it; the implementing role never sees or sets it. The bounded path removes *re-derivation* (a structure description of an unchanged tree, an unnarrowed deliberation over a single function, an audit re-confirming itself), while every independent check — the gates, CI, and the external reviewer's re-review — runs unchanged.

**Route.** Operator decision, recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy; the issue (#135) was operator-filed and the change operator-executed.

---

### Decision 13: A Test Exists Only When It Is Needed; Acceptance-Criterion Reductions Pass Through Three Tiers

**Problem.** The flow's default was *everything verifiable gets a test*, and nothing asked whether a given test was worth its cost. ADR-0018 bounded verification **depth** — layers against other layers — but not individual tests, and VERIFY step 3 asked a coverage question ("is any part of the impl diff uncovered?") whose only answer-shaped remedy is one more test. Separately, ADR-0020 stopped the run for the operator on five finding kinds, three of which (`not-carried`, `deferred`, `weakened`) describe *how* a criterion is verified rather than *what* it says.

**Evidence.** A prior cycle authored an equality assertion over a shipped sample file — the sample's literals against a spec table. The subject is user-editable, so the assertion loses its subject at the target's first edit; its cost was paid at authoring, at every verification run in the cycle, and in maintenance, while its absence would have cost nothing at any point (no consumer requires the sample to hold any particular literal; the behavior that reads the sample had its own coverage). The test existed because the default was *test it*, not because a question about it was answered.

**Decision.** A test exists only when it is needed, and the burden of proof lies on the test — not on its absence. Necessity has two inputs, answered in the verification-design row: **required behavior** (does a consumer actually require this behavior or contract?) and **cost of absence** (who loses what, concretely, if this breaks after merge?). A proposal that cannot answer both is not written, and under uncertainty the disposition is `none` — the asymmetry is the evidence above: the unneeded test's cost is real and recurring, the missing test's cost on such subjects was nil. The per-criterion disposition vocabulary is closed (`automated` / `existing-coverage` / `delivery-check` / `manual` / `environment-dependent` / `none`) and every non-`automated` issue-AC row states a one-line reason; automated rows carry a kind (`driving` / `regression` / `characterization`) that is also RED's expectation. Acceptance-criterion reductions pass three tiers: the deliberation chooses a reduced disposition **with its reason in the row**, the external reviewer judges every reduction and reason from the host PR body, and the operator is asked only when the criterion's **content** must change. Reconcile's finding set narrows to `dropped` / `unreasoned` / `substituted`, and issue #160 then retires `substituted` — the one semantic kind — leaving the two findings a non-judging channel can compute (the "does the row verify the AC's property" judgment moves to GATE:PLAN `Test plan`); issue #166 then retires the Reconcile check itself, leaving the three tiers standing on the orchestrator's routing of the deliberation report and the two gates' AC-authority checks; VERIFY step 3 keeps its name and becomes a scope check. Authority: [`adr/0022-test-necessity-and-three-tier-ac-guard.md`](adr/0022-test-necessity-and-three-tier-ac-guard.md), amending ADR-0020.

**What was rejected.** Making configuration/data and implementation internals *exempt categories* — refused, because that converts a judgment back into a classification, and both "production config boots the app" and "every reference resolves" can be entirely worth their cost; the two areas stay as guidance notes, the same two judgments applied where they are most often answered wrong. Keeping the coverage form of VERIFY step 3 alongside a necessity clause at ARCHITECT — refused, because the two contradict each other inside one cycle: the design declines a test on necessity grounds and step 3 then reports the same code as an uncovered hunk whose remedy is that test. Letting the comparison channel judge whether a stated reason is good — refused on ADR-0020's own ground, that this judgment is capturable by a well-written rationale.

**What it costs.** `none` under uncertainty will sometimes be wrong, and the miss surfaces after merge; the tiers bound it rather than remove it — the reviewer sees every reduction with its reason, and the recorded reason makes a wrong call diagnosable. The operator loses sight of reductions the ADR-0020 pause used to show them; that transfer of attention is the intent, and it is safe only because the reviewer tier is mandatory and its input sits in the PR body. And one finding kind retires with no replacement gate: a criterion `deferred` out of the cycle with a stated reason now leaves the deliberation without an operator decision, and tier 2 is where a postponement that should have been an issue split is expected to be caught.

---

### Decision 14: PREFLIGHT Has a Call Site for the Target's Own Readiness Procedure, Not Knowledge of Any Tool

**Problem.** PREFLIGHT ran only what the framework itself needs — Git clean, remote sync, bundle drift, reviewer-backend presence. A target repository's own per-clone setup step (llmroute's commit-hook installer, documented there as a required setup step) had no point at which AutoFlow would read it, so a cycle could start with the target's lint chain uninstalled; six role-spawn commits in llmroute #279 skipped it, and the orchestrator swept 23 files at VALIDATE step 7 (issue #181). The same class had been recorded in the target's own docs once before.

**Decision.** PREFLIGHT gains one **call site**, `scripts/preflight/local-checks.sh`, that runs whatever the target declares under `preflight.local_checks[]` in its own scaffold `.claude/autoflow.local.json` — a `check` command (exit 0 = ready), an optional `repair` run once on failure and followed by a re-check — and stops fail-closed when a check does not pass. Nothing declared is a no-op, recorded as one line. The outcome goes to the ledger as an identifier-free record, never to the state file.

**Why a call site and not a rule.** The defect is a target property, not a methodology gap: what "ready" means differs per repository, and encoding one repository's tool (husky, lint-staged) in the framework would be wrong for every other target. A declaration slot generalizes; a rule about hooks would not. The lint-chain obligation at commit time (`submodule-common-rules.md`) is unchanged — the call site makes the chain *installed* before the first role-spawn commit; it does not substitute for running it.

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

**Problem.** ADR-0024 cited other documents by line number 95 times, and 38 of the 50 rows in its adjustment-scope tables identified a provision by coordinate; the adjacent ADRs (0019, 0022) carried no line citation. Within the same cycle, the commits that retired cycle-scoped suites shifted a CI workflow file by two lines each, the citations drifted, and the orchestrator made two commits that changed nothing but citations (554d2de, 844ceec). The evaluator flagged "a line not in the table" and "a mis-pointed coordinate" every round, and AUDIT recorded as Low that a scope citation had swept in guard control flow (`if` / `exit 1`) beside the provision it meant. Separately, `docs/INDEX.md` > Quick Routing listed ADR file names by hand while `docs/records/adr/README.md` maintained the same list; issue #217 updated one and missed the other, and the evaluator flagged it twice (issue #221).

**Cause.** The `path:line` anchor convention exists so that an AI can re-derive a fact deterministically within the same commit — a role spawn's report, an evaluation report. That form leaked into long-lived documents (ADRs, design documents, rule documents, issue bodies, adjustment-scope tables), whose lifetime is not one commit. A line number presumes the cited document never changes; when it does change, the citation still looks valid while pointing at the wrong place, the mis-pointing draws review findings, and the commit that fixes the citations shifts others.

**Decision** (operator decision, issue #221).

1. **A long-lived document cites a provision by identity, not by coordinate**: the document, its section heading, and the provision's own sentence as a verbatim fragment. Line numbers are not used. The form is `` `<path>` > <heading chain> — "<verbatim fragment>" `` (for example `` `docs/autoflow-guide.md` > VERIFY > Detection record — "A check that did not execute is recorded as `not-run`" ``); a script or workflow file substitutes its function, `case` arm, or job/step name for the heading chain.
2. **A line number appears only in a one-shot artifact bound to one commit** — an evaluation report, a role report, a ledger grounds line for a fact of this tree — and always together with the commit SHA (`<path>:<line>` at `<SHA>`). Such an artifact is re-derived when the tree changes; that is its premise.
3. **One list, one home.** The same information is not maintained by hand in two places; a second location points at the first (`docs/INDEX.md` > Quick Routing points at `docs/records/adr/README.md` instead of naming ADRs).
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

**Relation to Decision 12.** The bounded path of Decision 12 — a set relation over files that selects which DIAGNOSE inputs are reused — decides what a re-entry that runs DIAGNOSE re-derives, not whether DIAGNOSE runs.

**Alternatives rejected.** A new-issue proportionality predicate computed by a script that excludes the agent's estimate (#193), and a predicate script with an exclusion list for the /simplify run (#195): both give a script the judgment principle 2 gives the working AI. What they aimed at — no re-derivation on a change that needs none, no /simplify spawn on a diff that has nothing to simplify, with the grounds on record — is what the judged route and the judged step 1 deliver; the measurement #193 asked for is the observation the Limitations list names.

**What it costs.** A route judgment will sometimes be wrong in the direction of too shallow, and the miss surfaces at a gate, in CI or at review rather than in the skipped phase. The recorded grounds make each such miss attributable to the judgment that caused it, which is what an observation series needs; none has been collected yet (Limitations).

**Route.** Operator decision, recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy; the issue (#227) was operator-filed and the change operator-executed.

### Decision 18: A Gate Cap Binds Normative Documents; a Historical Record and a Re-score's New Finding Are the Evaluator's Recorded Judgment

**Problem.** Issue #228's GATE:QUALITY failed four times in a row, every implementation item passing and `Doc updates` capped at 6 each time, because past issues' manual-verification records (`tests/manual/issue-112-manual-scenarios.md` and its kind) still carried the names of devices the cycle deleted. Three remedy commits took about 70 minutes; the fourth FAIL escalated to the operator, who retired those records wholesale, and the fifth evaluation passed. Three rules combined to produce the loop. The reference-integrity check ([`autoflow-guide.md`](../autoflow-guide.md) > GATE:QUALITY > Known blind-spot checks) capped the item on any remaining reference, without distinguishing a document someone follows from a record of a past state. The re-entry re-score was a fresh evaluator opening on *"this deliverable must FAIL"* ([`role-contracts.md`](../role-contracts.md) > Evaluation AI > Pre-scoring FAIL hypothesis), so each remedy's newly written sentences became the next evaluator's target — every report from the second to the fifth opened *"Adopted 'this Nth doc remedy must FAIL'"*, and the reports grew from 29 KB to 55 KB. And the `doc` re-entry's *wider sweep predicate on a second FAIL* obligation made each round rewrite more historical records, whose new sentences the next round flagged; the third evaluator itself wrote that three sweeps had each found a new loop. Under `CLAUDE.md` > Rule Scope a rule binds authority and prevents self-certification (principle 1), while whether a stale sentence in a past record is actually a problem is a judgment the AI makes and records (principles 2 and 3) — the three rules had made that judgment by rule.

**Decision.** Operator decision (issue #232), four changes and no device change.

1. **The reference-integrity cap binds normative documents only.** A normative document is what an agent or the operator reads and follows in a phase, what executes, and what is delivered — defined once, at the check itself, with the delivered set bounded by the manifest generator's link closure that already exists (`setup/gen-manifest-hashes.sh` > `compute_doc_closure`). A stale name in a historical record — a per-issue manual-verification record, a report-excerpt fixture, an ADR's change history, an archived cycle artifact — is the evaluator's judgment on whether it misleads a reader following the normative documents, recorded with its ground in the item's `reason`; a score reduction rests on that ground alone (issue #211's precedent of keeping old excerpts verbatim stands).
2. **A re-score's subject is the flagged defect.** On a re-entry evaluation the FAIL hypothesis takes the form *"the previously flagged defect still remains"*, and each prior finding is dispositioned `cleared` / `remains`. A defect newly seen on a re-scored item is still surfaced, and the evaluator judges and records whether it blocks — a blocking finding is scored, a non-blocking one goes to `recommendations` without lowering the item.
3. **The `doc` re-entry's sweep scope is judged.** The sweep still enumerates repo-wide, and the hook still checks that the record carries its command and output; which hits the remedy fixes — every hit in a normative document, a hit in a historical record only where the evaluator's recorded judgment named it — is the orchestrator's judgment, recorded in the same file. A second FAIL of the same class re-examines that judgment against the new report's grounds; a wider predicate is one possible outcome, not a rule.
4. **The report format carries the dispositions** (`rescore.prior_findings`, `rescore.new_findings` — [`evaluation-system.md`](../evaluation-system.md) > Evaluation Output Format), so the orchestrator's acceptance of the report is the enforcement point, as it is for `fail_hypothesis` and `remedy_class`.

**Why the hook does not change.** Gate 5 checks that the sweep record exists with a non-empty `## Command` and `## Output` — the anti-self-certification device for a route that skips RED / GREEN / VERIFY. The scope judgment is prose in the same record, and the hook was never a reader of wording (`docs/gate-matching-standard.md` > P3). The gate thresholds (each ≥ 7, avg ≥ 7.5) and the `max 3×` cap are unchanged; what changes is what the cap keys on and what a re-score looks for.

**What it costs.** An evaluator may judge a misleading stale sentence harmless, and the miss then surfaces at the configured reviewer's review rather than at the gate — the same shape as Decision 17's cost, and attributable to the recorded judgment the same way.

**Route.** Operator decision, recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, on the precedent of Decisions 11 and 17; the issue (#232) was operator-filed and the change operator-executed.

### Decision 19: What the Orchestrator Reads Directly Is Its Recorded Judgment; Gate Scoring and Deliberation Bodies Stay Fixed

**Problem.** `CLAUDE.md` > Cost Control > *Orchestrator context discipline* forbade the orchestrator every raw read — "never raw material", "does not read a full artifact" — and had it spawn a subagent to be handed a summary of any completed artifact instead. The prohibition cited no measurement of its own. The #136 figure in the same section (a Test AI at 515K of context, 86% of it Bash output and file dumps) is a role spawn's context blow-up, and the judgment-contamination case behind Decision 8 (issue #189) is deliberation prose accumulating round by round; neither shows a risk in the orchestrator reading a short, finished fact document, and nothing shows that a context ratio alone manages contamination either. Under `CLAUDE.md` > Rule Scope a rule binds authority and prevents self-certification (principle 1), while how far a read reaches is a judgment the AI makes and records (principle 2) — the blanket read ban made that judgment by rule, and paid a spawn for every summary.

**Decision.** Operator decision (issue #199), one rule rewritten and no device change.

1. **The direct-read scope is the orchestrator's judgment, recorded with its grounds** in the report or ledger entry the phase already produces — the same form as the route judgment of Decision 17. A cheap anchor-check (`git show <SHA>`, a one-line command re-run, a targeted `git show HEAD:<file>`) is unchanged and needs no recorded ground; a completed artifact — a single report, a design document — may be read in full when the orchestrator judges the read necessary, and the entry names what was read and why.
2. **Two rows stay fixed**, because each binds authority rather than cost. The orchestrator never scores what a gate scores: the full read-and-score of a gate's artifact set is the fresh Evaluation AI's (Decision 2), and an orchestrator read of those artifacts informs a spot-check, never a verdict. And the orchestrator never receives a deliberation body: an ARCHITECT transcript turn or a participant report reaches it only as the Record workflow's structured result and artifact paths (Decision 8).
3. **A spawn's return shape is unchanged.** *Role-spawn report format* still has every spawn write its body to `.autoflow/*` and return an anchor + one-line summary; the judgment is over what the orchestrator then reads of that body, not over what a spawn sends back — a spawn that inlined its body would decide the orchestrator's intake for it.

**Why the devices need no change.** No hook ever read the rule: gate `scores` are written from the Evaluation AI's report, deliberation isolation is held by the participants' prompt and the Record workflow's return contract (`scripts/architect/relay-state.sh`, `.claude/workflows/architect-deliberation.js`), and the ledger check is advisory. The two fixed rows are enforced where they always were.

**What it costs.** An orchestrator that reads a long artifact in full carries it until compaction, and a wrong read-scope judgment surfaces as the oscillation Decision 8 describes rather than at a gate; the ledger's new-verified-fact rule is the backstop. The *Wait discipline* exclusion of an unchosen intake — a timed-out agent's transcript dump (issue #165) — stands, since that intake is not a judgment at all.

**Route.** Operator decision, recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, on the precedent of Decisions 17 and 18; the issue (#199) was operator-filed and the change operator-executed.

### Decision 20: A Verified Error in a Ledger Entry's Own Grounds Is Corrected by the Decision's Original Authority; Preference and Re-reading Stay Barred

**Problem.** `CLAUDE.md` > Decision Ledger admits re-opening a recorded decision only on a *new verified fact* — one unavailable when the entry was written and deterministically checkable. That definition has no place for an error in the record itself: an entry whose two grounds contradict each other, whose number was miscalculated, or whose cited source does not say what the entry claims. Such an error was available at writing time, so it is not a new fact, and the only route to correcting it was the operator (Rule Scope, principle 3) — even where a single command over the cited material reproduces the error. The alternative the issue rejected, a "stated reason plus an attempt cap", would admit the failure Decision 8 records from issue #189: the same material re-read and the judgment reversed, now with a reason attached.

**Decision.** Operator decision (issue #202), one exception sentence added to the rule and no device change.

1. **Three conditions, all required.** The error is reproduced by command output over the material the entry cites; the re-opening is judged by the decision's original authority; and the superseding entry's grounds carry the reproducing command with its summary line — the existing "summary line with its command" grounds form (Decision 16) — and name the superseded entry's identifier. The append-only rule is untouched: the correction is a new entry, never an edit.
2. **The original authority judges, mapped by what settled the entry.** A gate verdict is re-scored by a fresh Evaluation AI on that item (Decision 2 — the orchestrator never scores what a gate scores, Decision 19); an ARCHITECT conclusion goes back to the deliberation on a `brief` naming the entry, and that is an ARCHITECT re-entry consuming the re-entry counter unless the deliberation is still open, on the same terms as a VERIFY design contradiction; an operator decision returns to the operator. Where the authority cannot say with confidence that the reproduced error changes the decision, it asks the operator — the principle-3 route is narrowed, not removed.
3. **What is not an error.** A changed preference, a re-weighting, or a re-interpretation of material already on the record reproduces nothing by command and remains barred; the exception keys on the reproduction, not on the strength of the argument.

**Why the devices need no change.** The ledger is not a gate input (`CLAUDE.md` > AutoFlow State Tracking): no hook, cap or transition reads the re-litigation rule, and `scripts/ledger/ledger-entry-id.sh` checks identifiers, not grounds. The rule is enforced where it always was — by the reader of the ledger and by the reviewer at HANDOFF — and the superseding entry's recorded command is what makes a correction checkable after the fact.

**Relation to #249.** Issue #249 relaxes ordinary report confirmation from re-execution to log evidence, and leaves the ledger's re-opening ground to this decision. Re-opening a settled decision is the case where the reproduction itself is the ground, so the entry records the command and its summary line; a log path may accompany it as drill-down but does not replace the command line.

**Route.** Operator decision, recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, on the precedent of Decisions 17–19; the issue (#202) was operator-filed and the change operator-executed. No ADR: no gate threshold, cap, hook or merge authority changes, and the exception routes each correction to the authority that already owned the decision.

### Decision 21: How a Target Runs and Keeps Its Tests Is the Target's Practice — Guidance to the Roles, Exposure to the Reviewer, No Declared Command and No Token on Targets

**Problem.** ADR-0024 D3 had AutoFlow run a target's committed tests only through a command the target declared (`.claude/autoflow.local.json` > `tests.command`, else `CLAUDE.md` > Development Commands `Test`), and D1 decided what a cycle leaves in a target's tree by a closed token list (`packaging` / `manifest` / `target-runtime` / `cross-file`), with a composition oracle `standing` by the `cross-file` mapping and a shipped device enforcing the set relation. Both are the shape AutoFlow uses to improve **itself** — its suite plane and its standing categories — imposed on targets as a declared command and a token. `connev-llm/llmroute#285` (the 0.2.3 observation cycle) showed the cost on a target whose tests run per workspace from a submodule's own `CLAUDE.md`: no declaration existed, its absence surfaced only at GATE:PLAN after DIAGNOSE and ARCHITECT, the recorded remedy retyped `automated` rows to weaker dispositions rather than running anything, `CLAUDE.md` > Rule Scope and the GATE:PLAN / GREEN rules disagreed on whether every `automated` row needed the declared command, and eleven of the design's twelve `standing` rows were `cross-file` — drop-zone wiring, footnote mapping, badge behaviour — functional checks the deliberation had itself called settled by one local run, committed because the composition-oracle clause fitted them to a category. A category can be fitted as readily as a reason can be stated (ADR-0024 D1 on `connev-llm/llmroute#628`), so refining the list or its definitions bounds nothing.

**Decision.** Operator decision (issue #238), executed as operator work outside an AutoFlow cycle — a cycle would have applied the rules being removed to their own removal.

1. **AutoFlow's test method is for AutoFlow.** The suite plane, the header contract, the selector and runner, and D1's closed list stay, and apply in this repository and where a target opted into the plane (`tests.suite_plane: true`). The token grammar, the layer violation and `scripts/gate/verification-layer-check.sh` apply in this repository only; the device leaves the bundle.
2. **Execution is guided, not prescribed.** No declared command: the role that runs a test finds the target's practice at the execution location — documents, scripts, workspace structure — runs the tests it judges the change requires that way, and records the command and its summary line (`CLAUDE.md` > Rule Scope > *How a test is run is the target's practice*). The form of a one-shot local test is the AI's.
3. **An omission is filled where it is found, not gated.** A row with no run record is `not-run`; it surfaces at GREEN's entry run of the RED tests, at VERIFY and VALIDATE's row-to-record match, in the spawn prompt that hands the record to the next role, and at GATE:QUALITY `Test coverage`, where the evaluator withholds the item rather than failing it and a fresh evaluator re-scores that item after the run. No new `remedy_class`, so `scripts/gate/remedy-route.sh` is unchanged; a run that fails routes as before.
4. **CI is the target's.** RED wires an added test file into the target's CI where registration is needed; HANDOFF step 5 matches each added file against the green run's logs — execution visible in the log, not registration — and records the job in the PR body, wiring inside HANDOFF what no job executed.
5. **Retention is not classified on targets.** A cycle adds no test file to a target by default. An added file is listed in the PR body with its reason and its CI job, and the reviewer and the operator judge it against the target's convention. AutoFlow certifies nothing by a token; the composition-oracle `standing` sentence is withdrawn, the oracle's non-mock obligation is not.

**Why guidance and not a narrower rule.** The alternatives — a better discovery order, a `tests.command` the stamp fills, a fifth token, a definition of `cross-file` that excludes functional wiring — all keep AutoFlow as the authority over a question that is the target's (Rule Scope, principle 2: which tests to run and how far the work reaches are the working AI's judgment) and each is defeated by the same fitting that defeated the last. What Rule Scope principle 1 keeps as rules is untouched: the gate thresholds, the push gate, the attempt caps, the `standing` list for this repository's own designs. A wrong judgment about a target's tests is caught where principle 3 says it is — at the reviewer, from a PR body that now shows every added file and every recorded run.

**Route.** Operator decision recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, with ADR-0024 D1 and D3 revised in place (their originals recorded under that ADR's Related Issues / PRs) on the precedent of the #222 and #225 revisions; #249 later aligns the run record's evidence form to the sentences this decision edits.

### Decision 22: A Run's Evidence Is the Log It Left; a Report Is Confirmed by Reading It, and Re-executed Only Where the Log Is Absent or Contradicts the Record

**Problem.** AutoFlow confirms an AI's report on the premise that the report may be wrong, and the rules implemented that premise as *re-execute everything*: the evidence of a test pass was a summary line with its command, defined as re-derivable by re-running (`docs/submodule-common-rules.md` > Reporting Format item 5), and four points re-ran it — the orchestrator accepting a role-spawn report (`CLAUDE.md` > Execution Principles > *Verify role-spawn claims*), VALIDATE step 1 ("reproduces when re-run"), GATE:QUALITY's `Test coverage` ("the command and summary line reproduce") and its `Test quality / Completeness` check ("reproduces by re-running the cited command") — while the Evaluation AI's contract made the re-run a `[MUST]` (`docs/role-contracts.md` > Evaluation AI > *Execution discipline* — "the evaluator re-runs that command"). The output was already written to a log (Testing Standards item 7) that nothing read as evidence, and Rule Scope's *How a test is run* called the recorded line the witness that the asset executed while the four points witnessed it again. On `connev-llm/llmroute#285` the same set ran three times: the role, the orchestrator, the GATE:QUALITY evaluator.

**Decision.** Operator decision (issue #249, 2026-09-14), executed as operator work outside an AutoFlow cycle — a cycle would have applied the re-execution rule to its own removal.

1. **What a wrong report looks like fixes what is trusted.** The form of a wrong AI report is a claim of work not done or a value filled by guess; a forged execution log is not the form. So the evidence a run leaves — its log — is trusted, and a "done" / "PASS" claim is confirmed by reading the evidence it cites, which is a different act from producing that evidence again.
2. **The evidence is the log; the summary line is read from it.** A run record is the command, the log file the run's output was written to — cited by path under `.autoflow/issue-{N}-local/`, where it outlives the spawn and is archived with the issue (ADR-0024 D2; the store's index check reads tracked paths, so a log there is not an asset it sees) — and the summary line read from that log. A line no log carries is not evidence (`CLAUDE.md` > Rule Scope > *A run's evidence is the log it left*; Reporting Format item 5).
3. **Confirmation is reading, at every point that confirms.** The orchestrator's acceptance of a report, VALIDATE step 1, GATE:QUALITY's `Test coverage` and `Test quality` and the Evaluation AI's anchor resolution read the recorded line at the cited log path. A command is re-run only where the evidence is absent or contradicts the record, and then the disposition is the omission path Decision 21 fixed: the row is `not-run`, run where it is found, its record filled in, not failed. At GATE:QUALITY the two cases part: a record with **no log behind it** is a missing run and takes the `Test coverage` withhold-and-run path; a log that **does not carry the recorded line** is evidence authored without a run and keeps the existing cap on the citing item — the cap is retained, and its judgment is now made by reading the log, not by re-running.
4. **One ground stays the reproduction.** Re-opening a settled ledger decision on a verified error is the case where the reproduction itself is the ground (Decision 20): the superseding entry records the command and its summary line, and a log path may accompany it as drill-down. This decision does not touch it.

**Why the devices are the role definitions.** No hook or script reads a summary line (`grep` over `scripts/`, `.claude/hooks/` and `setup/` for the phrase finds none); the rule was enforced by the roles that re-ran and by the contract that told them to. The devices that change with the rule (Rule Scope, principle 4) are therefore the Test AI and Developer AI definitions (the record's three parts and the log's location), the Evaluation AI definition and contract (read, never re-run; the two GATE:QUALITY dispositions), and ADR-0024's evidence-form sentences, revised in place with the originals recorded under its Related Issues / PRs.

**Route.** Operator decision recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, with ADR-0024's evidence-form sentences (D1, D2, D3, D6, *Evaluator execution discipline*) revised in place on the precedent of the #222, #225 and #238 revisions; it lands after Decision 21 and aligns to the sentences #238 edited, as that decision's *Route* anticipated.

### Decision 23: A Comment Is a Present-Tense Claim About Its Code; a Decision, a History and a Discussion Go to Records That Do Not Change With the Code

**Problem.** The rules on comments were two negative sentences about quantity — `docs/role-common-rules.md` > Quality Standards ("Do not add unnecessary refactors, comments, or type annotations") and `docs/submodule-common-rules.md` > Over-engineering guard ("Comment only where the logic isn't self-evident") — and neither said what a comment carries or where the rest goes. A role that judged a design ground "not self-evident" moved it into a comment, where it became a claim that goes false when the code or another file changes, and every such divergence cost a review round or a gate item (issue #276, its observations: a stale comment raised to an ARCHITECT decision item, `doc_updates` scored 7 on a docstring residue). In this repository at `3b58eaba7514dcd022fe61bb517e654e68e8e584` the tracked `.sh` files under `scripts/`, `plugin/` and `setup/` carry 4,699 comment lines against 6,336 code lines (non-blank, shebang excluded; 42.6%), and 234 of those comment lines carry an issue / PR reference or a change-history marker (`#<digits>`, `PR #`, `issue #`, `review round`, `no longer`, `previously`, `pre-#`) — measured by a line-head `#` heuristic over `git ls-files 'scripts/*.sh' 'plugin/*.sh' 'setup/*.sh'`, which counts tool-read header lines as comments.

**Decision.** Operator decision (issue #284, 2026-09-22), executed at the operator's instruction as orchestrator work outside an AutoFlow cycle.

1. **What a comment is decides what it carries.** A comment is a present-tense claim about the code it sits on; it carries only a sentence that stays true for as long as that code is unchanged. What it carries, what it does not, and where the rest goes are one rule with one home: `docs/submodule-common-rules.md` > Change Surface Rules > *Code comments*. The role contracts and the implementation and test agent definitions cite it.
2. **The content is not lost, only its synchronization duty.** A decision and its grounds go to the decision record, a change history to the commit message and the PR body, a discussion to the `.autoflow/*` design documents and the issue — records of a moment, which cannot go out of step with code that changed after them. A comment carries at most one ADR identifier; an issue or PR number is reached through `git blame` and the commit message, so a comment carries none (operator-settled, not re-opened by a deliberation).
3. **The comment check is a signal, not a gate.** Each role disposes of the pattern hits in the files it writes, before its commit: the Test AI over the test files it commits (RED step 1), the Developer AI over the rest of the cycle's diff (REFINE step 1), which also records the comment-line ratio as an observation. A hit outside the Developer AI's write scope, or one an abandoned refactor left, is recorded in the REFINE report as such and left in place; no phase passes or fails on the report's comment-check content. It is not a hook denial: a rule binds authority or prevents self-certification (`CLAUDE.md` > Rule Scope, principle 1), and a comment's content does neither; identifying a comment line needs the file's language, and a hook that parsed every target's languages would encode per-target tooling in the framework, which Decision 14 rejects ("encoding one repository's tool … in the framework would be wrong for every other target"); and #276, which settles how a comment divergence is handled, has it block neither a gate nor a PR. The ratio has no threshold because no quantitative basis for a right comment density was found; the evidence gathered in issue #284 bears on the kind of comment, not the amount.
4. **The rule applies to this repository's scripts and suites.** The rule documents already bind every role spawn working here (`docs/role-common-rules.md`, header), the measurement above is the case the rule addresses, and the rule weakens no check this repository keeps: a suite's `# ci-subject:` header is a directive the rule does not govern, and the documentation and header consistency checks and the `doc` re-entry sweep are unchanged — #276's exclusion of this repository concerns how a divergence is handled, not how a comment is written, and this decision does not change it.
5. **Existing comments are not swept.** The rule governs code a cycle writes or modifies; a comment on untouched code stays under *Surrounding code*, and a comment attached to modified code is part of the change — updated or deleted in the same commit, deleted when its truth is uncertain.

**Why the devices are the role documents.** The check is a signal, so no hook or script changes (Rule Scope, principle 4 is satisfied by the absence of an enforcing device); what changes with the rule are the documents the roles load — *Code comments*, the RED and REFINE steps and the report section, VALIDATE step 4's section count (a presence check, not a content check), the Test AI and Submodule AI contracts, and the implementation and test agent definitions.

**Route.** Operator decision recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy. It touches none of the ADR trigger areas — the REFINE check gates nothing and no evaluation criterion changes; #276 carries the review-side change (severity, the fix route, the `doc` class) and plugs into the same REFINE step rather than adding a second check.

### Decision 24: A Target Comment's Divergence or Disallowed Content Is a `Low` Finding, Fixed by the Orchestrator's Direct Commit; It Routes Nothing

**Problem.** Decision 23 settled what a comment carries; how a comment that diverges from its code is handled stayed where it was. The `doc` class was defined as "documentation / comments", so a code-comment fix in a target travelled the `doc` re-entry — a repo-wide sweep record the hook checks before the commit, then a GATE:QUALITY re-score — a device built to catch the residual sites of one kind of error across this repository's normative documents (Decision 11, #138). Neither the reviewer protocol nor the evaluation criteria set a severity for a comment. Issue #276 records the cost: across five A/B LibreChat PRs, comment lines were 36% of the lines AutoFlow added (3,129/8,789) against 11% under operator-led work (157/1,370); the reviewer raised no comment finding on those PRs, and the cost fell inside the cycle — a stale comment's correction became an ARCHITECT decision item, GATE:QUALITY scored `doc_updates` 7 on a docstring residue, and the residue was carried into the PR body's known-gap list.

**Decision.** Operator decision (issue #276, 2026-09-22), executed at the operator's instruction as orchestrator work outside an AutoFlow cycle.

1. **A comment that diverges from its code, or that carries what a comment does not carry, is `Low`.** The same sentence stands in the reviewer protocol (`.codex/review.md` > Review Posture) and in the evaluation criteria (`docs/role-contracts.md` > Evaluation AI > *Code comments in a target*), because the reviewer, an isolated session, reads only the first and the evaluator reads the second. The reviewer neither keeps nor attaches `blocked-by-review` for it; the evaluator records it in `recommendations` and lowers no item's score for it, so it is never a failed item, never the cause of a FAIL on the average, and carries no `remedy_class`. Only that finding is `Low`: a defect a comment carries on its own ground — an exposed credential, token or personal data — takes the severity and the route its impact sets (PR #287 review, Medium 1: an unbounded "a comment finding" would have taken a secret in a comment out of every gate). What counts as a divergence and what REFINE removes share one standard, Decision 23's test — a sentence that stays true for as long as its code is unchanged.
2. **Its fix is the orchestrator's direct commit, and the fix ends there.** Whether to fix is the orchestrator's judgment (`CLAUDE.md` > Rule Scope, principle 2); a fix is one commit that deletes comment lines or corrects their sentences and changes nothing else, with no sweep record, no re-entry, no re-score and no reviewer re-review, and a comment whose correct wording is uncertain is deleted (Decision 23, item 5). The `doc` class no longer covers a target's code comments. The commit's lint chain and CI on the pushed head stay. The re-review is omitted because the finding such a fix clears is `Low` under item 1, so re-reviewing the fix cannot change the gate label on that ground; a fix that touches any other line, or removes a defect of its own ground, is not this route. The `doc` sweep exists to catch the residual sites of one error kind in documents an agent follows (Decision 11, Decision 18); no phase follows a comment as a rule, so a stale one costs a reader, not a gate.
3. **`Minimal implementation` weighs comment content and volume, recorded but not scored.** On a target the item reads the REFINE report's `## Comment check` (Decision 23, item 3) — its `comment-ratio` line and its hits — with the comments in the diff. A comment the rule does not admit is depth the acceptance criteria do not need; and even admitted comments whose amount, absolute and relative to the code they sit on, exceeds what a reader of the changed code needs are judged the same way — qualitatively, naming the comment blocks, with no ratio threshold (Decision 23 found no quantitative basis for one). Either finding goes in the item's `reason` and in `recommendations` and lowers no score (PR #287 review round 3, Medium 1: content alone left the volume the issue named unweighed). An earlier draft let it lower the item to no less than 7; that floor did not keep a comment from failing the gate, because the PASS criteria bound the ten items' average (≥ 7.5) as well as each item (≥ 7), and a cut from 8 to 7 can take the average from 7.5 to 7.4 — a FAIL with no item below 7 and so no `remedy_class` to route it (PR #287 review round 4, Medium 1). The REFINE comment check stays Decision 23's single procedure, extended to the comments no pattern finds — a restatement of the code, design discussion, another file's contract, commented-out code — which the Developer AI finds by reading: one check, not two.
4. **A directive is code.** A line a tool reads to change its behavior is outside items 1–3: a defect in it takes the severity and the route of the behavior it changes. Which lines are directives is judged in each target, and no list is kept (`docs/submodule-common-rules.md` > Change Surface Rules > *Code comments* > *Directives are code*).
5. **This repository is excluded.** Here the documents are the product and a suite's `# ci-subject:` header line executes, so comments stay under the checks they had — the reviewer's severity as judged, the `doc` class, and the `doc` re-entry's sweep record. The precedent is ADR-0024 D1's closed category list, this repository's convention whose device runs only here (`CLAUDE.md` > Rule Scope). Decision 23, item 4 (the writing rule applies to this repository's scripts) is unchanged: it governs how a comment is written, this decision how a divergence is handled.

**Why the devices need no change.** The hook's `doc` gate reads the class the orchestrator records (`phases.gate_quality.remedy_class`), never the content of a fix; a divergence or disallowed-content finding produces no class, so the hook has nothing to gate, and `scripts/gate/remedy-route.sh` maps classes without defining them. The rule's enforcing parties are the reviewer and the evaluator, and their documents change in this change (Rule Scope, principle 4): `.codex/review.md`; `docs/role-contracts.md` (the Evaluation AI's comment subsection and the `doc` class); `docs/submodule-common-rules.md` (the `Minimal implementation` linkage); `docs/autoflow-guide.md` (REFINE step 1 and its report, GATE:QUALITY's input, `Minimal implementation`, the `doc` row, *Code comments in a target*, and HANDOFF step 6.5's `Low` branch); and `CLAUDE.md` (the orchestrator's commit authority).

**Route.** Operator decision recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, which accepts "an ADR or a documented owner decision". It touches a trigger area — evaluation policy: a severity rule and a finding class excluded from scoring — and is recorded as the documented owner decision, on the precedent of Decision 11, which set the `remedy_class` vocabulary the same way. It narrows Decision 11's `doc` definition for a target's code only; Decision 11 is left as written. PR #287 review round 2 (Medium 1) found the round-1 narrowing missed the two `doc` class definitions; the correction then swept every sentence stating a target comment's handling (`git grep` over `CLAUDE.md`, `.codex/`, `docs/`, `.claude/`, `plugin/`) and bounded each to the divergence or disallowed-content finding.

### Decision 25: Scope Is Two Recorded Judgments, Not an Acceptance-Criterion ID; a PASS's Recommendations Take the Reviewer-Finding Procedure; an Acceptance-Criterion Change Can Be Raised From Any Phase

**Problem.** The scope rule asked one question — "which acceptance criterion requires this change?" — and a problem with no answer was removed or sent to a separate issue. Including a problem needed an AC ID; separating one needed no reason. A problem from the same confirmed cause, a problem this change created, and a style inconsistency seen in passing were handled alike. The devices leaned the same way: three narrowed the change (Change Surface Rules' Trace rule and Over-engineering guard, VERIFY step 3's minimal-implementation check, GATE:QUALITY's `Minimal implementation` and `Impact scope`), and none widened it — the evaluator must list every finding in `recommendations`, but nothing said what the orchestrator does with a PASS report's recommendations, and fixing one broke the Trace rule because it carried no AC ID. The asymmetry had a second face: an external reviewer's finding takes a procedure with classification, route, pause criteria, record and cap (HANDOFF step 6.5), while the same finding from the Evaluation AI, one phase earlier, was dropped unclassified and came back as a reviewer finding to be fixed at HANDOFF's re-entry cost. Issue #275 records the cost, from the evidence index #273: #594 carried a `doc_updates` finding forward as a known gap; #607 moved cycle 1's four GATE:QUALITY residuals into the PR body and they returned as reviewer `Medium` findings in cycles 2 to 4; #630 carried an AUDIT `Low` forward and it returned as a reviewer `Medium` and one autofix. Operator-led work took 2–8 operator decisions on work content per item and AutoFlow 0–3 — in #630 AutoFlow's three were all CI infrastructure, the operator-led work's eight all content — and #607 recorded an added criterion as `revised` for want of a word.

**A first attempt, not taken.** PR #288 built a disposition system of its own for gate recommendations — a `fix` / `reject` / `outside` / `operator` vocabulary, a ledger entry per pass, per-route closing evidence, an added Resume condition, a one-fix-pass bound per gate, a `## Scope separations` PR section. Five review rounds returned eleven `Medium` findings, and every one after the first sat at a joint between the new system and an existing device — the Resume procedure, the re-entry re-score, the two no-re-score paths, the PR body in review-response mode, the participants' lifetime. Each joint closed opened the next. The lesson the issue records: the analysis-stage finding must take the **same** procedure as the reviewer finding, because a separate one has to re-solve what that procedure already solved — classification, route, pause, record, cap, verification — and leaves a gap at every joint.

**Decision.** Operator decision (issue #275, 2026-09-22 revision, 2026-09-23), executed at the operator's instruction as orchestrator work outside an AutoFlow cycle.

1. **Scope is two judgments, recorded.** A problem the acceptance criteria do not name is (1) *directly related* when it comes from the same confirmed cause, when this change created or exposed it, or when the behavior a criterion promises does not hold in actual use unless it is fixed; and (2) *desirable to fix in this cycle* when it lies in the same module, is confirmed by the same verification and would reopen the same code if fixed separately — not when it needs a design decision of its own, touches another ownership scope, or carries more risk than the issue. Directly related and desirable → fixed; directly related and not → separated with a reason; unrelated → separated as before. The default moves: an inclusion rests on a recorded judgment, and separating a directly related problem needs a recorded reason. The rule has one home, `docs/submodule-common-rules.md` > Change Surface Rules > *Scope judgment*, and each role records its judgments under `## Scope judgments` in the report or artifact its phase already produces (`CLAUDE.md` > Rule Scope, principle 2).
2. **The same question is asked where the scope is set and where the work meets a problem**: DIAGNOSE's task decomposition and the ARCHITECT feature design's `## Scope` section, whose inclusions get verification-design rows with `Issue AC` `—`; GREEN, VERIFY step 3 and REFINE during the work. Inside the recommendation triage (item 4) the two questions decide which recommendation is not the issue's and ground the `Low` judgment.
3. **The narrowing devices change with the rule, on one standard** (Rule Scope, principle 4). The Trace rule asks for an acceptance criterion, the confirmed cause, a plan item or a recorded scope judgment. VERIFY step 3 has the Test AI judge the behavior it finds outside the scope rather than only ask for its removal. `Minimal implementation` fails a hunk that rests on no judgment, or on one meeting none of question 1's conditions; `Impact scope`, whose criterion was stated nowhere, is scored on the same scope from the other side — a directly related problem left out with no reason. GATE:PLAN's `Scope` reads the design's `## Scope` section. The minimal-implementation principle, the Over-engineering guard and the separation of style, pre-existing dead code and refactors noticed in passing are unchanged — none of them meets question 1. What changes is what counts as the issue's work, not how small that work is made; an over-wide inclusion is caught by the same `Minimal implementation` item and by the reviewer.
4. **A PASS's recommendations take the reviewer-finding procedure.** After the PASS of every rubric-scored gate — GATE:HYPOTHESIS in both forms, GATE:PLAN, AUDIT and GATE:QUALITY, since the finding-coverage contract binds them all — the orchestrator triages the report's `recommendations` by HANDOFF step 6.5's procedure, and no procedure of their own (`docs/autoflow-guide.md` > GATE:QUALITY > *Recommendation triage*). What is added is one output contract: each recommendation carries its subject, its severity in the reviewer's vocabulary, and on `Medium` and above a `remedy_class` — the evaluator classifies, as it already does for a failed item, by the question the ingesting subagent asks of a reviewer finding. Everything else is the existing procedure read at the gate's position: `scripts/gate/remedy-route.sh route` picks the phase, and a phase behind the gate is re-entered and re-scored by the gate's narrowed re-score, while a phase ahead of it receives the recommendation as input (a `doc` / `test` / `impl` at GATE:PLAN in the DISPATCH spawn prompt, scored by GATE:QUALITY; at GATE:HYPOTHESIS every class amends the analysis in DIAGNOSE and the same form re-scores it) — the per-call-site reading the script's own header already provides for its four callers. The four pause criteria are the reviewer's, the `Low` judgment is the reviewer's, each `Medium`+ attempt is a ledger entry in the `[review-autofix]` grammar under its own marker `[gate-autofix]`, and the cap is the reviewer's 7 on its own window. No ingesting subagent is spawned, because the evaluator's report is already structured. A recommendation none of question 1's conditions covers is separated as the scope rule says; a directly related `Medium`+ is fixed or put to the operator, never separated on the orchestrator's own judgment. Deferred `Low` items and separations go to the PR body's existing known-gaps line, not to a section of their own.
5. **An acceptance-criterion change can be raised from any phase.** The authority is unchanged — acceptance-criterion content is the operator's (ADR-0020). The entries widen: besides the ARCHITECT deliberation and VERIFY's design contradiction, a role at GREEN, VERIFY or REFINE raises a needed change in its report, and a recommendation reaches the operator through the triage's pause criterion (a). `[ac-decision]` names the phase the change surfaced in and gains a fourth disposition, `added`; an `added` entry covers nothing in either gate backstop, since the criterion it adds is owed a row and a site. Where the cycle re-enters after such a decision is the orchestrator's recorded judgment, and a return to ARCHITECT on that ground consumes no re-entry budget, being bounded by the operator's decision. A return to ARCHITECT after DISPATCH — this one, a `design`-class recommendation, and the existing VERIFY design contradiction and `design` re-entries, which had no stated shape — spawns both participants fresh on the same transcript, because the phase boundary ended their lifetime, and the Record's delta names the trigger as its origin.

**The points the issue left to the design.**

- *Does a `Medium` recommendation block the transition after a PASS?* Yes, as it blocks the reviewer's hand-off: the PASS stands as the gate's score record — the hook admits the next role spawns on it — and the transition waits until no `Medium`+ recommendation is open. The device is the one the FAIL route already has: the orchestrator records the routed class as `phases.<gate>.remedy_class` while the attempt is open, and the hook's `git push` / `gh pr create` gate denies on its presence at `audit` or `gate_quality` — the counterpart of the reviewer's label, which the orchestrator cannot clear. The `doc` route keeps its sweep record for the same reason: it is the `doc` route.
- *The cap.* The reviewer's — 7 consecutive attempts since the last user decision — on a window of its own, so a gate attempt and a reviewer attempt never count each other. An attempt is not a FAIL and consumes no FAIL cap; a failing re-score is an ordinary FAIL; a route through ARCHITECT consumes the ARCHITECT counter. Reaching the cap is never a separation reason — the disposition there is the operator's.
- *Resume.* The same state field: a passed gate whose latest record still carries `remedy_class` has an open attempt, and the Resume procedure resumes on the route the last `[gate-autofix]` entry names, not past the gate; a re-score that FAILed is an ordinary FAIL and resumes on its FAIL route.
- *Is a fix after a PASS scored?* Yes. #607's ledger (O49) gave "a commit after the gate sends an unscored tree to the reviewer" as the ground for leaving its recommendations unfixed; the narrowed re-score FAIL re-entries already use (issue #232) removes that ground at the cost of one fresh spawn over the touched items.
- *Which role judges direct relation, at what cost?* The role that meets the problem, where it meets it, in the report it already writes — no added spawn. VERIFY step 3's only alternative to removal was a scope question to ARCHITECT, far costlier than removal, so removal always won. Now the Test AI judges the behavior against GREEN's recorded judgment; a disagreement is one orchestrator judgment between the two recorded grounds, the operator's when the orchestrator is not confident (principle 3); and ARCHITECT is reached only when keeping the behavior would change a design decision.
- *The gaps PR #288's review exposed.* A return to ARCHITECT after DISPATCH now has a stated shape (item 5). The `## Verification dispositions` staleness in review-response mode is not touched here: no new PR section is added, so nothing of this decision depends on step 4 running. `Impact scope` has its criterion sentence (item 3).

**What was rejected.** A single per-issue scope file every role appends to — a new artifact where principle 2 asks for the report the phase already produces; the common heading makes the records findable instead. A disposition system of the gate's own (PR #288, above). Asking the operator about every inclusion — the operator's authority is acceptance-criterion content, an inclusion changes no criterion, and routing every inclusion to the operator would restore the narrowing default under another name. A separate cap counted against the gate's FAIL cap — a PASS with three `Medium` recommendations would then exhaust a FAIL budget without a FAIL.

**Why the devices are documents, two prompts and one hook branch.** A scope judgment is a principle-2 judgment caught by `Minimal implementation`, `Impact scope`, GATE:PLAN's `Scope` and the reviewer; no hook reads it. The recommendation triage reuses the devices the reviewer procedure and the FAIL route already have — `remedy-route.sh`, the narrowed re-score, the ledger marker grammar, the state field — and the one device it extends is the push gate: an open re-entry recorded in state is now a `git push` / `gh pr create` deny, which is principle 1's kind of rule (the orchestrator must not push past a finding it has not had re-scored) and changes in this change (principle 4). The documents that change: `docs/submodule-common-rules.md` (Change Surface Rules, GATE:QUALITY linkage), `docs/autoflow-guide.md` (Resume, ARCHITECT's artifacts, report routing and re-discussion, GATE:PLAN, DISPATCH, GREEN, VERIFY step 3, REFINE, AUDIT, GATE:QUALITY with *Recommendation triage*, HANDOFF steps 4 and 6.5), `docs/phases/analysis.md` (step 6), `docs/role-contracts.md`, `docs/evaluation-system.md`, `CLAUDE.md` (the `[ac-decision]` grammar, Flow Control, Regressions, the `phase` field, remedy-class recording, the hook gates) and the evaluator, implementer, tester and planner agent definitions. The prompts: the ARCHITECT topic (`scripts/architect/relay-state.sh`) asks the scope question, and the Record scribe (`.claude/workflows/architect-deliberation.js`) writes the `## Scope` section and its `—` rows, its delta heading naming each origin a return to ARCHITECT can have; `test/workflows/run.mjs` and `tests/test-issue-179-relay-state.sh` assert the sentences, and `tests/test-issue-140-remedy-route.sh` asserts the push-gate branch. `scripts/ledger/ledger-entry-id.sh` checks identifiers, not markers, and `scripts/metrics/cycle-metrics.py` counts the new marker beside `[review-autofix]`.

**Route.** Operator decision recorded here per [`development-guideline.md`](../development-guideline.md) > ADR Policy, which accepts "an ADR or a documented owner decision". It touches a trigger area — evaluation policy: the `Minimal implementation`, `Impact scope` and GATE:PLAN `Scope` criteria, and the recommendations output contract — and is recorded as the documented owner decision, on the precedent of Decisions 11 and 24. It widens ADR-0020's entry points and disposition vocabulary without changing its authority principle; ADR-0020 carries an amendment note.

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
| Have the orchestrator score a gate's artifact set itself, or take a deliberation body into its context | The two read-scope rows that bind authority (Decision 19): self-scoring neutralizes the fresh-evaluator gate (Decision 2); deliberation prose contaminates judgment (Decision 8) |
| Let the pipeline modify its own criteria | Judgment tracing impossible → trust chain collapse |
| Design loops without termination conditions | No maximum retry → infinite loop risk → system hangs |
| Run a multi-participant deliberation in the orchestrator's own context | Round-by-round cross-talk + duplicate reports accumulate → judgment contamination → decision oscillation (Decision 8) |
| Replace deliberation isolation with a cheaper in-loop summary | Orchestrator stays in the loop → duplicate accumulation and oscillation remain; it is a bias mechanism, not a cost tweak |
| Re-open a ledgered decision without a new verified fact, or without an error reproduced by command output and judged by the decision's original authority (Decision 20) | Re-reading the same material re-opens settled scope → oscillation-driven round explosion; a stated reason without a reproduction is a re-reading with a label |
| Add improvements to this repository before they exist in upstream | Generalization is mirror, not branch — improvements diverge the methodology and break parity |

---

## Known Limitations and Ongoing Discussions

### Limitations

- **No failure learning loop**: No structured per-cycle evidence is captured; pass/fail pattern analysis is performed by humans externally.
- **No cross-issue correlation detection**: A complaint class recurring across distinct issues is not detected; correlation analysis across issues is human-external. Decision 4 (no auto-modification of rubric/criteria) is unaffected.
- **No measurement of judged routes yet**: Decision 17 makes a cycle's route and depth the working AI's recorded judgment, for new issues and review-response cycles alike. Whether that judgment is calibrated — what it skipped, and what a gate or the reviewer then caught — is read from the recorded grounds and the review outcomes after the fact, and no such series has been collected yet. Decision 18's evaluator judgments (a historical record's stale name; a re-score's new finding) join the same unmeasured series. Decision 19's orchestrator read-scope judgment joins it too: whether a direct read of a completed artifact was worth its context, or fed the oscillation Decision 8 describes, is read from the recorded grounds and the ledger after the fact. Decision 20's error-correction exception joins it as well: how often a ledger entry is superseded on a reproduced error, and whether the original authority's re-judgment held at the reviewer, is read from the superseding entries' recorded commands after the fact.

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
