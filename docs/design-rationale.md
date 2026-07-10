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

Each phase transitions to the next only when its stated completion conditions are met. All phases are performed regardless of change size.

**Why it works this way**

AI tends to judge "this change is small enough to skip phases." That judgment itself is a product of bias. The thought "this one is simple" causes verification to be skipped, and problems emerge from the skipped verification. Simplicity can be determined after the process, not before it.

The act of judging "this change is simple" is itself a product of bias. That judgment is made before implementation. Before implementation, there is no way to know whether it is actually simple. The judgment may sometimes be correct, but when it is wrong, problems emerge from the verification that was skipped. AutoFlow does not permit this judgment at all. Simplicity can be evaluated post-hoc, after all phases are completed. Pre-process judgment is not allowed.

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

---

### Decision 8: Deliberation Runs in an Isolated Sub-Context (Delegated Facilitation)

**What it does**

Multi-teammate deliberation phases — ARCHITECT (Developer AI + Test AI design discussion) and the VERIFY cause-branch self-check exchange — run inside an isolated **facilitator**, realized as a `Workflow` (the one runtime mechanism documented to keep intermediate results out of the caller's context). The Developer-AI and Test-AI run as in-script sub-agents, their round-by-round cross-talk stays in workflow variables, and the orchestrator receives only a single structured result + artifact paths. The orchestrator never receives the round-by-round messages. A companion append-only **decision ledger** (`.autoflow/issue-{N}-ledger.md`) records each settled decision with its grounds and authority, and a recorded decision is not re-opened without a new verified fact.

The realization matters because the obvious alternative does not exist: in Claude Code Agent Teams a spawned teammate cannot create its own team and the lead is fixed for the team's lifetime, so "a facilitator that leads a nested team" is not executable; and a peer-teammate facilitator inside the orchestrator's own team is not a documented isolation boundary (teammate messages reach the lead automatically). The `Workflow` runtime is the mechanism whose isolation is actually documented, so the contract binds to it rather than to an abstract "sub-context".

**Why it works this way**

A teammate→lead message is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator leads the discussion, every round of cross-talk — including the two teammates' near-duplicate convergence reports — accumulates in its context. The harm is not only token cost: retracted claims, wrong oracles, and reversed scopes pile up in the orchestrator's working context, and it begins to oscillate on decisions it had already settled. This was observed directly in issue #189, where the orchestrator flipped a scope decision (FOLD-IN ↔ KEEP-SEPARATE) while submerged in a back-and-forth that mixed live and retracted claims.

This is a context-contamination problem of the same family as Problem 2 (a single session cannot effectively challenge its own reasoning) — but here the contamination flows *into the coordinator* from the teammates it coordinates. Cheaper or summarized rounds (the file-pull / checkpoint-summary direction) do not fix it, because the orchestrator still receives the round and still accumulates the duplication. The fix is structural: remove the orchestrator from the deliberation loop entirely. The deliberation converges in an isolated context; only a distilled verdict crosses back.

The decision ledger is the second half of the fix. Isolation stops new contamination from entering; the ledger stops already-settled decisions from being silently re-opened by an enlarged context. Re-opening requires a *new verified fact* — not a re-reading of material already on the record — which caps oscillation-driven round explosion. This is the same principle as a settled gate verdict outranking a re-reading of the issue body.

**Isolation is for deliberation, not verification**

The orchestrator's real value is verification, and that value is preserved. In the issue #189 session, every substantive catch — a refuted provenance claim, a wrong "0 failed" oracle, a RED test that copied a mock boundary — came from the orchestrator reading the *distilled artifacts and deterministic facts*, never from reading the deliberation prose. So the rule removes only the prose: after the verdict returns, the orchestrator still reads the artifacts and runs deterministic spot-checks (`git show`, command re-run) before accepting. "The orchestrator does not deliberate" is correct; "the orchestrator does not verify" would discard the system's main safeguard.

**Why this design must not be weakened to a summarization tweak**

The tempting shortcut is "have the teammates report more cheaply" or "summarize each round before it reaches the orchestrator." Both leave the orchestrator in the loop and therefore leave the duplicate accumulation and the oscillation in place. Delegated facilitation is not a cost optimization that happens to reduce tokens; it is a bias-elimination mechanism that happens to reduce tokens. Replacing it with a cheaper in-loop variant reintroduces the bias it exists to prevent.

### Decision 9: HANDOFF Acts on Its Own Configured-Reviewer Review Before Handing Off (Bounded Auto-Resolution)

**Problem.** AutoFlow's terminal phase originally ran the per-PR reviewer review and then ended unconditionally, leaving any `blocked-by-review` label (Critical/High/Medium findings) for a human to notice and re-trigger. The findings the methodology itself produced sat idle until someone re-invoked the issue.

**Decision.** HANDOFF adds a review-triage step after the reviewer review. If the reviewer verdict is `Medium` or worse, the orchestrator auto-enters a review-response cycle in-session with the reviewer comment as the DIAGNOSE trigger — reusing the existing review-response machinery (DIAGNOSE target, loop check, gates, re-HANDOFF, re-review) rather than introducing a new phase. If the label was cleared (only Low or no findings), the orchestrator judges the Low findings by pure agent judgment and decides whether to fix them. This deliberately extends AutoFlow's reach past the "end at PR creation" reflex: the methodology now resolves its own review output before handing the PR off, while still never merging.

**Why it is safe.**
- **The orchestrator never owns the label.** The gate hook denies `--remove-label blocked-by-review` unconditionally, so the label's single authority remains the configured isolated reviewer subprocess's re-review. Auto-resolution can only *fix code and re-trigger the review*; it can never declare itself clean. The fix trigger keys off the review **verdict (`max_severity`), not label presence alone** — `.codex/review.md` lets a clean review leave the label on if `--remove-label` fails, so a label-present / sub-Medium PR is routed to a reviewer re-review (or operator escalation), not a code-fix loop.
- **Backend-neutral (issue #979).** The review backend is selectable — `codex` by default, `claude` as an opt-in fallback (`.claude/autoflow.local.json` `.review.backend`; see [`reviewer-backend.md`](reviewer-backend.md)). This authority argument is backend-independent: it rests only on the reviewer running as an **isolated subprocess that does not load the orchestrator's `.claude/settings.json` gate hooks**, which holds for `codex exec` (a separate subprocess) and for neutral-cwd `claude -p` (project settings not discovered from a neutral working directory) alike. Whichever backend runs, it remains the sole authorized clearer of `blocked-by-review`.
- **The auto-loop is bounded.** A user-decision pause fires on any of four triggers (contract/AC change, ambiguous fix, `Low Confidence` item, loop-check match), and a hard cap of 7 auto-resolution attempts — counted as the *consecutive `review-autofix`-marked ledger entries since the last user re-entry decision (reset by that decision; if none yet this cycle, since the first auto-entry)* — escalates to the user. A monotone total is deliberately avoided: it would re-fire the pause immediately after the user has already approved continuation, defeating the pause's purpose. The window's sole reset anchor is the user re-entry decision. A per-PR label-clear is rejected as such a trigger — it is the wrong granularity for a per-issue cap and would let an oscillating loop run unbounded. This reuses the existing loop-termination and oscillation-guard mechanisms (Decision 7), so the new trigger source cannot loop without a termination condition. Cap-fire and user-re-entry events are additionally written as a one-line host-PR comment (prefix `[autoflow:review-autofix]`), so they survive the ledger's cleanup deletion and stay durably auditable; this is an audit note, not a gate input (the cap remains ledger-counted — see "No new gate surface").
- **No new gate surface.** The cap is tracked in the append-only ledger, not the state file, so the gate hook and its state-schema whitelist are unchanged. Re-pushes route through the existing AUDIT + GATE:QUALITY gates.

**The tempting shortcut** is to have HANDOFF auto-promote or auto-merge once findings are addressed. That is rejected: merging stays external (the host-PR `Closes #N` and the merge-sequencing workflow), and the orchestrator is structurally barred from clearing the gate label itself. Auto-resolution improves the PR that is handed off; it does not take over the hand-off.

---

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
| Allow phase-skipping judgment | "This one is simple" is itself a biased judgment |
| Let the pipeline modify its own criteria | Judgment tracing impossible → trust chain collapse |
| Design loops without termination conditions | No maximum retry → infinite loop risk → system hangs |
| Run a multi-teammate deliberation in the orchestrator's own context | Round-by-round cross-talk + duplicate reports accumulate → judgment contamination → decision oscillation (Decision 8) |
| Replace deliberation isolation with a cheaper in-loop summary | Orchestrator stays in the loop → duplicate accumulation and oscillation remain; it is a bias mechanism, not a cost tweak |
| Re-open a ledgered decision without a new verified fact | Re-reading the same material re-opens settled scope → oscillation-driven round explosion |
| Add improvements to this repository before they exist in upstream | Generalization is mirror, not branch — improvements diverge the methodology and break parity |

---

## Known Limitations and Ongoing Discussions

### Limitations

- **No failure learning loop**: Structured per-cycle evidence is now durably captured at HANDOFF (`docs/cycle-digest.jsonl`, issue #953) and never injected into any gate evaluation; pass/fail pattern analysis over it is still performed by humans externally.
- **No cross-issue correlation detection (mechanism now shipped; judgment external)**: A bounded, deterministic cross-issue complaint-class recurrence scan is now implemented (issue #954, `scripts/preflight/scan-cross-issue-recurrence.sh`, run at PREFLIGHT step 1.5 over the #953 `docs/cycle-digest.jsonl` corpus): a class recurring across K=3 distinct issues in the last M=20 records emits a **candidate** finding to `docs/improvement-backlog.md`. The mechanism exists; **judgment and promotion of a candidate to an issue stay human-external** and the scan never auto-modifies any rubric/criteria and never feeds a gate/evaluator (Decision 4). Fuzzy/semantic clustering across issues remains out of scope (exact-after-normalization matching only).
- **No lightweight mode**: Full phase execution even for small changes. Overhead exists.

### Under Discussion

- Including related issue and commit history lookup at DIAGNOSE entry (factual lookup, not bias injection)
- Systematizing issue preparation stages through external cross-issue correlation analysis (the #954 recurrence scan supplies factual candidate signals; the systematization judgment on them stays human-external)

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
