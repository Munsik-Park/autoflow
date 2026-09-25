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
> AutoFlow State Tracking).

When an issue arrives, classify cause hypotheses **before** code analysis.

**Review-response loop check** (`mode = review-response` only). It runs **once per review-response attempt**, at whichever point that attempt begins: at DIAGNOSE entry, ahead of the structure analysis below, for an attempt that runs DIAGNOSE; and at HANDOFF step 6.5 before the routed work, for a route that does not — a thin route, or a `design` re-entry judged to start at ARCHITECT ([`handoff.md`](handoff.md)). Steps 1 and 2 below are what the step-6.5 call site executes; step 3 applies unchanged when either call site pauses. This section is the contract's only documentary home — the call sites cite it rather than restate it. An `autoflow-loopcheck` sub-agent (a shipped read-only definition), on the model the policy names for `diagnose-loopcheck` (clears the pre-GATE hook like Phase A/3), writes `.autoflow/issue-{N}-loopcheck.md` and returns a one-line summary. The contract has three separated steps:

1. **Record the observation — on every review-response DIAGNOSE entry, before comparing.** Append a ledger observation for this cycle: the **complaint class** (the property the reviewer asserts, e.g. "duplicate-member detection is incomplete"), the **witness case** (e.g. two identical entries, then three identical entries), the **shape of the prior change** (a check for the named case, or a rule over the whole property), and the cycle number. Recording is unconditional (not only on a match): the first review-response cycle records its observation too, with no prior to compare against.
2. **Compare against the immediately-prior review-response observation.** When the class matches and only the witness case differs, first check the ledger for an **active *case-specific* suppression** on this class — a *case-specific* decision recorded for this class with no different class observed in any later cycle. If one is active, the class is suppressed: continue the normal flow without pausing. Otherwise reply on the PR with the comparison and ask the user how to proceed **situation-first** ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation) — for example restating the acceptance criterion as one rule over the whole input, or a further case-specific change — then set `active: false`, `phase: "awaiting-user"`, and append a ledger entry marking the match. Do **not** record a decision here. When the class **and** witness are both the same (a fix that did not take), this check does not apply — continue to the structure analysis (scope-split applies); a different class also continues normally and, by appearing, releases any earlier suppression on other classes.
3. **Re-enter after the user answers.** Append a separate ledger entry recording the decision, then **restore the run state to `active: true`, `phase: "in-progress"`** so the *same* cycle resumes. Both branches execute after this restore: a *redefine-AC* answer restarts DIAGNOSE in this cycle from the new acceptance criterion; a *case-specific* answer continues the normal flow and suppresses re-surfacing of that class until a new class appears.

**Intake readiness triage** (`mode = new-issue` only; runs at DIAGNOSE entry, ahead of the structure fan-out below — the new-issue counterpart to the review-response loop check above). A sub-agent on the model the policy names for `diagnose-intake-triage` — a **separate role from Phase B** (it shares Phase B's no-code rule but has its own input set: the issue body + the host `docs/development-guideline.md` (work-type classification) and the target sub-repo's work-type / workflow-audit doc if it provides one, plus the sub-repo's product / actor context doc only if a readiness call genuinely needs it; **[MUST] no code search/read tools**; clears the pre-GATE hook like Phase A/B) — answers exactly one question: **is a planning / design / ADR prerequisite clearly required before this issue can be implemented?** It is a pre-filter, **not** a final implementability verdict — necessity is Phase 3's job and plan-fit is GATE:PLAN's; when in doubt it PASSes.

- **PASS** (no clear prerequisite) → proceed to the structure fan-out (step 2). **Only after PASS do Phase A/B run**.
- **FAIL** (a planning/design/ADR prerequisite is clearly needed) → **no auto issue creation**. Write the reason + a suggested issue-split draft to `.autoflow/issue-{N}-triage.md`; present it to the user **situation-first** — the user-visible problem and the suggested split in domain terms, with the file as the drill-down anchor ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation). Orchestrator context discipline bounds what the triage spawn *returns* (anchor + summary); how much of the triage file the orchestrator then reads is its recorded judgment, and the user receives the situation, not a bare anchor. Pause with `active: false`, `phase: "awaiting-user"`. Later, on the user's explicit request, the planning/design/ADR work starts as a separate cycle.

The triage sub-agent and the Phase B sub-agent use **separate agent lifetimes** (no reuse).

A suggested split written to `.autoflow/issue-{N}-triage.md` stays a suggestion until the user acts on it: the triage step does not file it, whatever it concludes, and it is filed only through a draft plus `scripts/issue/create-issue.sh` ([`docs/issue-proposal.md`](../issue-proposal.md)).

```
1. Identify affected sub-repos.
2. Independent structure analysis (3-Phase).

   Structure analysis is isolated from issue analysis, and the structure-analysis
   AI scores the necessity of each proposed resolution (a DRY-triage — is a code
   change genuinely needed — reuse-neutral, not a structural-fit judgment).

   Phase A + Phase B: run in parallel — except on the bounded path of a review-response cycle
   (`scripts/review/scope-bounded.sh entry` prints `scope-bounded: true` over the per-PR findings
   files; `docs/phases/preflight.md` > Scope-bounded
   entry), where Phase A is NOT re-authored: the previous cycle's preserved
   `.autoflow/issue-{N}-c{C}-phase-a.md` is Phase 3's structure input. Phase B, Phase 3 and the loop
   check run as usual.

   AI-A (structure analysis): is NOT given the issue content
     - Input: affected sub-repo + functional area (e.g., "the API's request-normalization pipeline").
     - Instruction: "Analyze how this area currently works — pipeline structure, design intent, data flow."
     - Output: factual description of the area as it stands.
     - [MUST] Do NOT include the issue number, title, or problem description in the prompt.
     - [MUST] The prompt describes the current structure and does not convey the issue's defect hypothesis.

   AI-B (issue analysis): does NOT see the code
     - Input: issue body.
     - Instruction:
       1. List the concrete cases mentioned in the issue.
       2. Identify the higher-level problem type these cases share.
       3. Propose resolution approaches (what mechanism is needed).
       4. Open each material the issue body or an acceptance criterion references — a design
          mockup, an asset, an external document — and record it under `## Referenced materials`:
          what it is, where it is, how it was opened, and what it shows for the criterion that
          names it. The material, not an abbreviated example in the body, is what the criterion
          means; a material that cannot be opened is recorded `not opened: <reason>`
          ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *The tools the work needs*).
     - Output: cases + problem types + resolution approaches + `## Referenced materials` (`none`
       when the issue references no material), plus a required
       `## Acceptance criteria` section — a table with the fixed columns
       `AC id | criterion | source`, where `AC id` is a short readable name unique within the
       issue, `criterion` restates the issue's criterion faithfully, and `source` locates it in the
       issue body artifact. **[MUST]** This section is the issue's single machine-addressable
       acceptance-criterion list; an absent or unparseable table is itself a finding downstream
       (`docs/phases/architect.md` > *Report routing*; `docs/phases/gate-plan.md` >
       *AC-authority check*). It is authored **once per issue**, in the `mode = new-issue` cycle.
     - **[MUST]** A review-response cycle's Phase B targets the reviewer comment, not the issue
       body, so it **carries the existing table forward unchanged** rather than re-deriving it — a
       reviewer comment never edits the acceptance-criterion list; only an operator decision does,
       recorded as an `[ac-decision]` ledger entry (`CLAUDE.md` > Decision Ledger).
     - [MUST] Do NOT use code search/read tools. Opening a material the issue itself references
       (step 4 above) is not a code read.

   Phase 3: AI-A evaluates the necessity of AI-B's resolution approaches against the actual structure (reuse-neutral — not a structural-fit judgment).

   The orchestrator re-spawns AI-A:
     - Input: Phase A structure analysis + AI-B's resolution list.
     - Instruction: "For each proposed resolution, score two necessity items against the current code (as-is): (1) Behavior gap — does as-is NOT yet produce the required behavior? (2) Code-change necessity — is a code change the lever, not data/config/ops? Score necessity only — a resolution that reuses existing code is not a failure; do not judge plan quality or structural fit (that is GATE:PLAN's job)."
     - [MUST] Do NOT include the issue body (only AI-B's resolution list).

   Issue type classification:
     - Type 1 (code change): bug fix, new feature, script change, pattern extension, hook change.
     - Type 2 (documentation/consistency): content sync, doc update, cross-file consistency.
     - Mixed/unclear → default to Type 1.

   Scoring (10 points per item, by issue type — Type 1: 2 items; Type 2: 3 items):

   Type 1 (code change) — a *necessity* gate (DRY-triage), reuse-neutral, **two items only**. The gate answers exactly one question — "is a code change genuinely needed?" — and nothing else: plan feasibility / structural grounding → GATE:PLAN (Feasibility, Scope); structural-fit and over-engineering → GATE:PLAN (Scope) + GATE:QUALITY (Minimal implementation / Fit); "where / how to change" → DIAGNOSE task decomposition (step 6) + ARCHITECT feature design. A fix that reuses existing code scores high, not low.

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
     - as-is   = the current dev-branch HEAD. In a new-issue cycle this equals `main`; in a review-response cycle it is the change already under review.
     - Question = "Does as-is already satisfy the target request?"

   PASS criteria: each ≥ 7 — and, for the 3-item Type 2 rubric, also avg ≥ 7.5.
     - PASS (gap real + code is the lever) → code change required → continue to step 3.
     - FAIL → disposition by the failing item (never a bare composite — a real code gap is never auto-closed):
       - **Gap item low** (as-is already satisfies the target — no behavior/content gap) → no change needed. Branch on the cycle's `mode` recorded at PREFLIGHT (`mode` is the cycle-entry classification; a PR state change mid-cycle is re-classified at the next PREFLIGHT, not re-derived here):
         - `mode = review-response` (target issue has an open PR) → reply on the PR with the finding; do NOT close the issue or PR; set `active: false`, `phase: "awaiting-external-review"`. A defined terminus, not an open intermediate state.
         - `mode = new-issue` (no open PR) → issue auto-closed via `gh issue close` + AutoFlow terminated (`active: false`). **Pre-close verification** (the hook does not gate `gh issue close` — this is orchestrator discipline): before running the destructive `gh issue close`, the orchestrator confirms the recorded `phases.gate_hypothesis_structure` scores actually meet the FAIL condition per the CLAUDE.md thresholds (gap item < 7 — as-is already satisfies the target). The close comment records those structure-evaluation scores + the existing-mechanism summary. Re-filing as a new issue — or reopening — is the natural re-entry path.
       - **Gap item high, but Code-change necessity low** (a real gap, but the lever is data / config / ops — not a code change) → not a Type 1 code issue → the same non-code exit as GATE:HYPOTHESIS (see GATE:HYPOTHESIS > "non-code root cause confirmed → report to user"): report the finding to the user **situation-first** ([`CLAUDE.md`](../../CLAUDE.md) > Execution Principles > Human-decision presentation) (in a `mode = review-response` cycle, post it as the PR reply) and pause AutoFlow with `active: false`, `phase: "awaiting-user"`. Reclassification (Type 2 / non-code) is the re-entry. No retry loop — the structure gate does not re-DIAGNOSE.

3. Cause hypotheses (at least 3; "not a code bug" must be one).
   - Code bug: logic error, missing exception handling.
   - Missing data: required data is not in the data store.
   - Environment / configuration: env var missing, service not running, network.
   - External dependency: external API outage.
   - Already fixed: resolved in a recent commit.
4. Lightweight verification:
   - API calls, queries, service status, log inspection.
   - Find the tools the verification needs — in this environment and in the target's documents
     and scripts — before marking an item "unverified"; a tool that is off is started by the
     target's own procedure, and one that needs the operator is requested ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools
     > *The tools the work needs*). Record with the verdict notes each tool, whether it was usable,
     and how it was secured.
   - Items that cannot be verified are marked "unverified", naming the tool they needed.
5. Hypothesis verdict notes: per hypothesis, eliminated / likely / unverified, with evidence.
6. Task decomposition (only if code change is required).
   - Beyond the acceptance criteria, name the problems the confirmed cause carries — its other
     sites, and what fixing it will expose — and record the scope judgment for each
     ([`submodule-common-rules.md`](../submodule-common-rules.md) > Change Surface Rules >
     *Scope judgment*) with its grounds, under `## Scope judgments` in the DIAGNOSE artifact that
     carries the task decomposition. ARCHITECT reads it as an input and settles the cycle's scope
     in the feature design's `## Scope` section; DIAGNOSE does not decide it alone.
7. Identify affected docs.
```

**Per-role document injection whitelist** (the orchestrator selects documents per role via `docs/INDEX.md` as a router and never injects it wholesale). The three roles are **distinct columns** — `Intake triage` and `Phase B` are NOT the same role:

| Document | Phase A (structure — issue-isolated) | Intake triage (readiness — no code) | Phase B (issue — no code) |
|----------|--------------------------------------|--------------------------------------|----------------------------|
| the target sub-repo's current-state / architecture baseline doc(s) (area-scoped excerpt) | allowed — **current-state, area-scoped excerpt only** | denied | denied |
| issue body | denied | allowed | allowed |
| host `development-guideline.md` + the sub-repo's work-type / workflow-audit doc (work-type) | denied | allowed | **denied** |
| the sub-repo's product / actor context doc (product / actor) | denied | optional / limited if a readiness call needs it | **denied** |
| the sub-repo's problem / risk / improvement / priority docs (ADR candidates, risk analysis, tech-debt, refactoring queue) | denied | denied | denied |
| a material the issue body or an acceptance criterion references (a design mockup, an asset, an external document) | denied | denied | allowed — **opened by Phase B itself** and recorded under `## Referenced materials` |

- **[MUST] Phase B is issue-body only.** **No baseline, work-type, or product-background doc is injected into Phase B — `denied`, with no exception.** A material the issue itself references is part of the issue, not an injected document: Phase B opens it and records it (AI-B step 4), and Phase A never receives it. A material recorded `not opened` is raised to the operator before the cycle leaves DIAGNOSE (`CLAUDE.md` > Flow Control > *tool or referenced material → user*). Work-type classification is the intake triage's job, not Phase B's, so a "classification need" is never grounds to inject the work-type or product-background docs into Phase B.
- **[MUST] Intake triage** receives the issue body + the readiness/work-type docs (host `development-guideline.md` + the sub-repo's work-type / workflow-audit doc, if any); the sub-repo's product / actor context doc only if a readiness call genuinely needs it. It shares Phase B's no-code rule but is a **separate role with a separate input set**.
- **[MUST]** Phase A receives **current-state / observed-structure excerpts only**. Exclude problem, risk, recommended-direction, ADR-priority, issue-intent, and prerequisite-necessity wording.
- **[MUST]** Phase A excerpt selection uses the **functional-area coordinate** Phase A already receives (e.g. "host deployment structure", "submodule boundary"), not the issue's problem statement. Inject the matching excerpt, never the whole file.
- **[DENY]** Injecting `docs/INDEX.md` itself, or any of the sub-repo's "improvement / risk / priority" docs (ADR-candidate / risk / tech-debt / refactoring-queue), into any of the three roles.

**Structure-analysis bias prevention**: The structure gate scores *necessity only* and is reuse-neutral — leveraging existing code is a high-quality outcome, not a fail reason; structural-fit quality is judged later at GATE:PLAN (Feasibility, Scope) and GATE:QUALITY (Minimal implementation / Fit).

**Confirmation-bias prevention**: "the code may not be buggy" must be one hypothesis. Concluding that code change is required requires evidence that other causes have been ruled out.

## Spawn model (per-phase policy)

Every DIAGNOSE spawn's model is resolved from the single-source spawn policy, never restated
here: `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` over
`.claude/autoflow/spawn-policy.json`, with one row per DIAGNOSE direct spawn
(`diagnose-intake-triage`, `diagnose-loopcheck`, `diagnose-phase-a`, `diagnose-phase-b`,
`diagnose-phase-3`). Each `Agent` spawn declares `model` explicitly —
see [`CLAUDE.md`](../../CLAUDE.md) > Spawn Model — Phase-by-Phase. The orchestrator's own
context discipline applies: Phase A/B/3 write their bodies to `.autoflow/issue-{N}-phase-*.md`
and return only an anchor + one-line summary (`CLAUDE.md` > Cost Control > Orchestrator
context discipline).

Spawn channel: all five DIAGNOSE spawns — intake readiness triage, Phase A, Phase B, Phase 3, and the review-response loop check — are anonymous direct spawns (a `subagent_type` only, with no `team_name`/`name` pair), so each one's anchor + summary reaches the orchestrator as the spawn's own return value. See [`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime.

## Spot-check & escalation discipline (incomplete-output guard)

A DIAGNOSE spot-check is an orchestrator read that confirms a Phase A/B/3 finding
before it feeds a structure-gate score, a blocker, or a user escalation. Two Claude
Code behaviors produce a **false "absent / stub" reading**:

- **Read-dedup stub.** A re-read of an unchanged file returns a 1-line stub ("file
  unchanged … refer to that earlier tool_result"), and the dedup ledger is not reset on
  compaction. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags this
  at runtime — these rules are the procedure it points to.
- **Parallel `cd`-prefixed Bash cancellation.** A parallel batch of
  `cd <path> && git …` calls where one sibling errors at the tool layer returns
  a 1-line `Cancelled: parallel tool call … errored` for the rest, read as the
  command's (empty) output.

- **[MUST]** A blocker / "absent" / "dependency missing" finding is
  **reproduced with a fresh read before it feeds a structure-gate score or a
  user escalation**. A single read is never sufficient grounds.
- **[MUST]** A blocker/escalation-feeding spot-check reads via **shell**
  (`sed -n 'N,Mp' <file>`, `grep -n`, `wc -l`), not the Read tool.
- **[DENY]** Concluding "absent / empty / stub / smaller-than-expected" from a
  1-line result (`Wasted call` / `file unchanged` / `Cancelled`). It is a
  harness stub, not data — re-run the single command sequentially first.
- **[MUST]** Spot-checks run **after all Phase A/B/3 sub-agents have returned**,
  as single sequential commands with `git -C <path>` + absolute paths — never
  interleaved with the fan-out and never a parallel batch of `cd`-prefixed Bash.

**Operator-level mitigation (optional, session-global):** a long session that
has compacted is also prone to holding stale context with high confidence —
`--no-compaction` avoids it at the cost of context headroom. The hook + rules
above are the in-repo defense; this is a fallback.

## After this phase

- **Intake readiness triage FAIL** (`mode = new-issue`; a planning/design/ADR prerequisite is clearly required) → pause for the user (`awaiting-user`); the user's explicit request starts any prerequisite work as a separate cycle. Structure fan-out is not run.
- **Bug / incident issue** (structure PASS, code change required) → **GATE:HYPOTHESIS**
  (cause analysis evaluation) — see [`gate-hypothesis.md`](gate-hypothesis.md).
- **Non-bug issue** (feat, chore, docs, refactor, …; structure PASS) → **ARCHITECT** directly (GATE:HYPOTHESIS cause is skipped; `verdict` is set to `"skipped (non-bug issue)"` — [`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking > `verdict` rule).
- **Structure FAIL** → disposition above (close / reply on PR / report to user + pause), driven
  by the cycle `mode`.
- **Review-response loop check match** → reply on PR + pause for the user (`awaiting-user`); the
  user's decision selects the re-entry.
- **A referenced material not opened, or a tool the analysis needs and the target's procedures
  cannot provide** → request it from the operator, situation-first (`awaiting-user`; `CLAUDE.md` >
  Flow Control > *tool or referenced material → user*).
