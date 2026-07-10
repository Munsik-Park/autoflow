# DIAGNOSE — Issue Analysis Playbook

> **Phase playbook (single source of truth for the DIAGNOSE analysis procedure).**
> [`CLAUDE.md`](../../CLAUDE.md) routes to this file from its Phase Playbook Loading
> Contract; read it on entering DIAGNOSE. The cross-phase invariants, the router
> (phase list + Flow Control), the regression caps, and the state schema remain in
> `CLAUDE.md`. The structure-gate scores are recorded in the `.autoflow/issue-{N}.json`
> state file under `phases.gate_hypothesis_structure`, but the hook **does not gate**
> `gate_hypothesis_structure` — the orchestrator judges the structure pass/fail against
> the CLAUDE.md thresholds (each ≥ 7; the 3-item Type 2 rubric also avg ≥ 7.5) and records
> the fresh-spawn Evaluation AI's scores; the hook enforces only the four gated phases
> (`gate_hypothesis_cause`, `gate_plan`, `audit`, `gate_quality` — see `CLAUDE.md` >
> AutoFlow State Tracking). Design rationale:
> [`design-rationale.md`](../design-rationale.md) > Decision 1, Decision 6.

When an issue arrives, classify cause hypotheses **before** code analysis.

**Review-response loop check** (`mode = review-response` only; runs at DIAGNOSE entry, ahead of the structure analysis below). A `sonnet` Explore sub-agent (clears the pre-GATE hook like Phase A/3) writes `.autoflow/issue-{N}-loopcheck.md` and returns a one-line summary. The contract has three separated steps:

1. **Record the observation — on every review-response DIAGNOSE entry, before comparing.** Append a ledger observation for this cycle: the **complaint class** (the property the reviewer asserts, e.g. "duplicate-member detection is incomplete"), the **witness case** (e.g. two identical entries, then three identical entries), the **shape of the prior change** (a check for the named case, or a rule over the whole property), and the cycle number. Recording unconditionally (not only on a match) is what gives the *next* cycle a baseline — the first review-response cycle stores its observation even though it has no prior to compare against.
2. **Compare against the immediately-prior review-response observation.** When the class matches and only the witness case differs, first check the ledger for an **active *case-specific* suppression** on this class — a *case-specific* decision recorded for this class with no different class observed in any later cycle. If one is active, the class is suppressed: continue the normal flow without pausing (the user already chose to keep patching this class). Otherwise reply on the PR with the comparison and ask the user how to proceed **situation-first** ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation) — for example restating the acceptance criterion as one rule over the whole input, or a further case-specific change — then set `active: false`, `phase: "awaiting-user"`, and append a ledger entry marking the match. Do **not** record a decision here — the user has not answered yet. When the class **and** witness are both the same (a fix that did not take), this check does not apply — continue to the structure analysis (scope-split applies); a different class also continues normally and, by appearing, releases any earlier suppression on other classes.
3. **Re-enter after the user answers.** Append a separate ledger entry recording the decision, then **restore the run state to `active: true`, `phase: "in-progress"`** so the *same* cycle resumes — without this the next PREFLIGHT reads the `active: false` + open PR as a fresh review-response entry and double-increments the cycle. Both branches execute after this restore: a *redefine-AC* answer restarts DIAGNOSE in this cycle from the new acceptance criterion; a *case-specific* answer continues the normal flow and suppresses re-surfacing of that class until a new class appears.

Review-response loop check ↔ cross-issue recurrence scan (#954) — relationship:

The per-issue **Review-response loop check** above **supplements, and does not replace** — and is in turn supplemented by — the PREFLIGHT **step 1.5 cross-issue recurrence scan** ([`autoflow-guide.md`](../autoflow-guide.md) > PREFLIGHT). The two are disjoint in scope. **Per-issue** (this loop check): compares a **single issue** across its **consecutive** review-response cycles, from this issue's ledger observation vs. its immediately-prior cycle; signal = local "this fix did not take"; on match → reply on PR + pause the user. **Cross-issue** (the scan): tallies **distinct issues cumulatively** over the last M=20 records of `docs/cycle-digest.jsonl`; signal = global "the rubric/rule is systematically deficient"; on breach → emit a candidate finding for human promotion. Neither reads the other's store — this loop check never reads the digest, and the cross-issue scan never touches the ledger. This is the explicit non-conflation of the two mechanisms.

**Intake readiness triage** (`mode = new-issue` only; runs at DIAGNOSE entry, ahead of the structure fan-out below — the new-issue counterpart to the review-response loop check above). A `sonnet` sub-agent — a **separate role from Phase B** (it shares Phase B's no-code rule but has its own input set: the issue body + the host `docs/development-guideline.md` (work-type classification) and the target sub-repo's work-type / workflow-audit doc if it provides one, plus the sub-repo's product / actor context doc only if a readiness call genuinely needs it; **[MUST] no code search/read tools**; clears the pre-GATE hook like Phase A/B) — answers exactly one question: **is a planning / design / ADR prerequisite clearly required before this issue can be implemented?** It is a pre-filter, **not** a final implementability verdict — necessity is Phase 3's job and plan-fit is GATE:PLAN's; when in doubt it PASSes.

- **PASS** (no clear prerequisite) → proceed to the structure fan-out (step 2). **Only after PASS do Phase A/B run** (no fan-out is spent on an issue that needs planning first).
- **FAIL** (a planning/design/ADR prerequisite is clearly needed) → **no auto issue creation**. Write the reason + a suggested issue-split draft to `.autoflow/issue-{N}-triage.md`; present it to the user **situation-first** — the user-visible problem and the suggested split in domain terms, with the file as the drill-down anchor ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation). Orchestrator context discipline still bounds what the orchestrator *retains* (anchor + summary), but the user receives the situation, not a bare anchor. Pause with `active: false`, `phase: "awaiting-user"` — this reuses the existing non-code-lever terminus, so there is no new status and no regression cap. Later, on the user's explicit request, the planning/design/ADR work starts as a separate cycle.

The triage sub-agent and the Phase B sub-agent use **separate agent lifetimes** (no reuse).

```
1. Identify affected sub-repos.
2. Independent structure analysis (3-Phase).

   [AI limitation] An AI given an issue tends to focus on clearing the
   stated case and proposes code changes even when the existing structure
   already addresses the concern. To prevent this, structure analysis is
   isolated from issue analysis, and the structure-analysis AI scores the
   necessity of each proposed resolution (a DRY-triage — is a code change
   genuinely needed — reuse-neutral, not a structural-fit judgment).

   Phase A + Phase B: run in parallel.

   AI-A (structure analysis): is NOT given the issue content
     - Input: affected sub-repo + functional area (e.g., "librechat's normalization pipeline").
     - Instruction: "Analyze how this area currently works — pipeline structure, design intent, data flow."
     - Output: factual description of the area as it stands.
     - [MUST] Do NOT include the issue number, title, or problem description in the prompt.
     - [MUST] Do NOT use words like "problem", "fix", "missing", "insufficient" in the prompt.

   AI-B (issue analysis): does NOT see the code
     - Input: issue body.
     - Instruction:
       1. List the concrete cases mentioned in the issue.
       2. Identify the higher-level problem type these cases share.
       3. Propose resolution approaches (what mechanism is needed).
     - Output: cases + problem types + resolution approaches.
     - [MUST] Do NOT use code search/read tools.

   Phase 3: AI-A evaluates the necessity of AI-B's resolution approaches against the actual structure (reuse-neutral — not a structural-fit judgment).

   The orchestrator re-spawns AI-A:
     - Input: Phase A structure analysis + AI-B's resolution list.
     - Instruction: "For each proposed resolution, score two necessity items against the current code (as-is): (1) Behavior gap — does as-is NOT yet produce the required behavior? (2) Code-change necessity — is a code change the lever, not data/config/ops? Score necessity only — a resolution that reuses existing code is not a failure; do not judge plan quality or structural fit (that is GATE:PLAN's job)."
     - [MUST] Do NOT include the issue body (only AI-B's resolution list).

   Issue type classification:
     - Type 1 (code change): bug fix, new feature, script change, pattern extension, hook change.
     - Type 2 (documentation/consistency): content sync, doc update, cross-file consistency.
     - Mixed/unclear → default to Type 1 (conservative).

   Scoring (10 points per item, by issue type — Type 1: 2 items; Type 2: 3 items):

   Type 1 (code change) — a *necessity* gate (DRY-triage), reuse-neutral, **two items only**. Both are scoreable from Phase 3's inputs alone (Phase A structure description + AI-B's resolution list) — neither requires the issue body or code reads. The gate answers exactly one question — "is a code change genuinely needed?" — and nothing else: plan feasibility / structural grounding → GATE:PLAN (Feasibility, Scope); structural-fit and over-engineering → GATE:PLAN (Scope) + GATE:QUALITY (Minimal implementation / Fit); "where / how to change" → DIAGNOSE task decomposition (step 6) + ARCHITECT feature design. None of those is a *necessity* judgment, and none can be scored before a design exists. A fix that reuses existing code scores high, not low.

   | Item | Criterion |
   |------|-----------|
   | Behavior gap          | Per Phase A, does the current structure NOT yet produce the required behavior? (high = real gap → change needed; already-produced / already-fixed → low) |
   | Code-change necessity | Is a *code* change the lever, not data/config/ops? (high = code change needed; resolvable by config / data / ops → low) |

   Type 2 (documentation/consistency):

   | Item | Criterion |
   |------|-----------|
   | Content gap        | Is there an actual content gap or inconsistency? (high = gap exists) |
   | Consistency impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
   | Propagation scope  | Is the change scope appropriate — not too broad, not missing targets? (high = appropriate scope) |

   Evaluation target & baseline:
     - Target  = the request that triggered this cycle. New-issue cycle: the issue body. Review-response cycle: the specific reviewer comment/thread identified at PREFLIGHT (if it carries inline code, Phase B receives its behavioral intent, not the snippet — Phase B's no-code-tools rule forbids investigating the repo, not reading a quoted line).
     - as-is   = the current dev-branch HEAD (one uniform instruction, no mode flag). In a new-issue cycle this equals `main` (no implementation commits exist at DIAGNOSE); in a review-response cycle it is the change already under review. The branch state differs, so the same instruction yields the correct baseline in both.
     - Question = "Does as-is already satisfy the target request?"

   PASS criteria: each ≥ 7 — and, for the 3-item Type 2 rubric, also avg ≥ 7.5. (The cross-gate `avg ≥ 7.5` rule assumes a 3+-item rubric where a strong item offsets a weak one; the 2-item Type 1 gate uses `each ≥ 7` alone, so an honest 7/7 — both items real but not emphatic — is not mechanically rejected.)
     - PASS (gap real + code is the lever) → code change required → continue to step 3.
     - FAIL → disposition by the failing item (never a bare composite — a real code gap is never auto-closed):
       - **Gap item low** (as-is already satisfies the target — no behavior/content gap) → no change needed. Branch on the cycle's `mode` recorded at PREFLIGHT (a single persisted source — `mode` is the cycle-entry classification; a PR state change mid-cycle is re-classified at the next PREFLIGHT, not re-derived here):
         - `mode = review-response` (target issue has an open PR) → reply on the PR with the finding; do NOT close the issue or PR; set `active: false`, `phase: "awaiting-external-review"`. A defined terminus, not an open intermediate state. (Same terminus HANDOFF uses — both hand the open PR to external review; the PR diff is the record of whether code changed.)
         - `mode = new-issue` (no open PR) → issue auto-closed via `gh issue close` + AutoFlow terminated (`active: false`). **Pre-close verification** (the hook does not gate `gh issue close` — this is orchestrator discipline): before running the destructive `gh issue close`, the orchestrator confirms the recorded `phases.gate_hypothesis_structure` scores actually meet the FAIL condition per the CLAUDE.md thresholds (gap item < 7 — as-is already satisfies the target), so a mis-recorded PASS never auto-closes a live gap. The close comment records those structure-evaluation scores + the existing-mechanism summary (audit trail + reopen recourse). Re-filing as a new issue — or reopening — is the natural re-entry path.
       - **Gap item high, but Code-change necessity low** (a real gap, but the lever is data / config / ops — not a code change) → not a Type 1 code issue → the same non-code exit as GATE:HYPOTHESIS (see GATE:HYPOTHESIS > "non-code root cause confirmed → report to user"): report the finding to the user **situation-first** ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation) (in a `mode = review-response` cycle, post it as the PR reply) and pause AutoFlow with `active: false`, `phase: "awaiting-user"`. Reclassification (Type 2 / non-code) is the re-entry. No retry loop — the structure gate does not re-DIAGNOSE.

3. Cause hypotheses (at least 3; "not a code bug" must be one).
   - Code bug: logic error, missing exception handling.
   - Missing data: required data is not in the data store.
   - Environment / configuration: env var missing, service not running, network.
   - External dependency: external API outage.
   - Already fixed: resolved in a recent commit.
4. Lightweight verification (when a dev environment is available):
   - API calls, queries, service status, log inspection.
   - Items that cannot be verified are marked "unverified".
5. Hypothesis verdict notes: per hypothesis, eliminated / likely / unverified, with evidence.
6. Task decomposition (only if code change is required).
7. Identify affected docs (from the maintained-docs registry).
```

**Per-role document injection whitelist** (preserves the isolation across the three pre-fan-out / structure roles; the orchestrator selects documents per role via `docs/INDEX.md` as a router and never injects it wholesale). The three roles are **distinct columns** — `Intake triage` and `Phase B` are NOT the same role:

| Document | Phase A (structure — issue-isolated) | Intake triage (readiness — no code) | Phase B (issue — no code) |
|----------|--------------------------------------|--------------------------------------|----------------------------|
| the target sub-repo's current-state / architecture baseline doc(s) (area-scoped excerpt) | allowed — **current-state, area-scoped excerpt only** | denied | denied |
| issue body | denied | allowed | allowed |
| host `development-guideline.md` + the sub-repo's work-type / workflow-audit doc (work-type) | denied | allowed | **denied** |
| the sub-repo's product / actor context doc (product / actor) | denied | optional / limited if a readiness call needs it | **denied** |
| the sub-repo's problem / risk / improvement / priority docs (ADR candidates, risk analysis, tech-debt, refactoring queue) | denied | denied | denied |

- **[MUST] Phase B is issue-body only.** Its role is to analyze the issue body without code — not to expand interpretation with product-background or work-type docs. **No baseline, work-type, or product-background doc is injected into Phase B — `denied`, with no exception.** Work-type classification is the intake triage's job, not Phase B's, so a "classification need" is never grounds to inject the work-type or product-background docs into Phase B.
- **[MUST] Intake triage** receives the issue body + the readiness/work-type docs (host `development-guideline.md` + the sub-repo's work-type / workflow-audit doc, if any); the sub-repo's product / actor context doc only if a readiness call genuinely needs it. It shares Phase B's no-code rule but is a **separate role with a separate input set**.
- **[MUST]** Phase A receives **current-state / observed-structure excerpts only**. Exclude problem, risk, recommended-direction, ADR-priority, issue-intent, and prerequisite-necessity wording — these leak what the issue is trying to do.
- **[MUST]** Phase A excerpt selection uses the **functional-area coordinate** Phase A already receives (e.g. "host deployment structure", "submodule boundary"), not the issue's problem statement. Inject the matching excerpt, never the whole file.
- **[DENY]** Injecting `docs/INDEX.md` itself, or any of the sub-repo's "improvement / risk / priority" docs (ADR-candidate / risk / tech-debt / refactoring-queue), into any of the three roles.

**Structure-analysis bias prevention**: Phase A's information isolation prevents the AI from reading the issue and overlooking existing structure. Phase B defines the problem without code influence. The structure gate scores *necessity only* and is reuse-neutral — leveraging existing code is a high-quality outcome, not a fail reason; structural-fit quality is judged later at GATE:PLAN (Feasibility, Scope) and GATE:QUALITY (Minimal implementation / Fit).

**Confirmation-bias prevention**: "the code may not be buggy" must be one hypothesis. Concluding that code change is required requires evidence that other causes have been ruled out.

## Spawn model (per-phase policy)

The DIAGNOSE sub-agents run on `sonnet` (Phase A structure description, Phase B issue
classification, Phase 3 necessity scoring). Each `Agent` spawn declares `model` explicitly —
see [`CLAUDE.md`](../../CLAUDE.md) > Spawn Model — Phase-by-Phase. The orchestrator's own
context discipline applies: Phase A/B/3 write their bodies to `.autoflow/issue-{N}-phase-*.md`
and return only an anchor + one-line summary (`CLAUDE.md` > Cost Control > Orchestrator
context discipline).

## Spot-check & escalation discipline (incomplete-output guard)

The orchestrator's DIAGNOSE spot-checks — the reads that confirm a Phase A/B/3
finding before it feeds a structure-gate score, a blocker, or a user
escalation — run against one working copy while the parallel Phase A/B/3
sub-agents and the orchestrator's own Bash compete for it. Two Claude Code
behaviors turn that into a **false "absent / stub" reading** that has escalated
a phantom blocker to the user (issue #243):

- **Read-dedup stub (anthropics/claude-code#46749).** A re-read of an unchanged
  file returns a 1-line stub ("file unchanged … refer to that earlier
  tool_result"); the dedup ledger is not reset on compaction, so after a long
  session the referenced earlier read can be gone and the model confabulates
  the content (a 197-line file read as a phantom "57-line stub"). The `Read`
  PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags this at runtime —
  these rules are the procedure it points to.
- **Parallel `cd`-prefixed Bash cancellation.** A parallel batch of
  `cd <path> && git …` calls where one sibling errors at the tool layer returns
  a 1-line `Cancelled: parallel tool call … errored` for the rest, read as the
  command's (empty) output.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a structure-gate score or a
  user escalation**. A single read is never sufficient grounds.
- **[MUST]** A blocker/escalation-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool, so the dedup
  ledger is bypassed (the documented #46749 workaround).
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged` / `Cancelled`). It is a
  harness stub, not data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after all Phase A/B/3 sub-agents have returned**,
  as single sequential commands with `git -C <path>` + absolute paths — never
  interleaved with the fan-out and never a parallel batch of `cd`-prefixed Bash.

**Operator-level mitigation (optional, session-global):** a long session that
has compacted is also prone to holding stale context with high confidence
(anthropics/claude-code#29230) — `--no-compaction` avoids it at the cost of
context headroom; the dedup feature has a server-side killswitch
(`tengu_read_dedup_killswitch`) that may not be user-exposable. The hook + rules
above are the in-repo defense; these are fallbacks.

## After this phase

- **Intake readiness triage FAIL** (`mode = new-issue`; a planning/design/ADR prerequisite is clearly required) → pause for the user (`awaiting-user`); the user's explicit request starts any prerequisite work as a separate cycle. Structure fan-out is not run.
- **Bug / incident issue** (structure PASS, code change required) → **GATE:HYPOTHESIS**
  (cause analysis evaluation) — see [`autoflow-guide.md`](../autoflow-guide.md) > GATE:HYPOTHESIS.
- **Feat issue** (structure PASS) → **ARCHITECT** directly (GATE:HYPOTHESIS cause is skipped).
- **Structure FAIL** → disposition above (close / reply on PR / report to user + pause), driven
  by the cycle `mode`.
- **Review-response loop check match** → reply on PR + pause for the user (`awaiting-user`); the
  user's decision selects the re-entry.
