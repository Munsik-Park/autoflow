# Teammate Contracts

> This document defines the role contracts for the teammates that the AI Orchestrator dispatches in AutoFlow: **Evaluation AI**, **Test AI**, and **Submodule AI (Developer AI)**. The Orchestrator's own coordination responsibilities remain in [`CLAUDE.md`](../CLAUDE.md) > Team Structure. Per-phase spawn model policy: see [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase.

---

## Evaluation AI (subagent)
- Independent evaluator that does not participate in planning or implementation.
- Bias prevention: a fresh agent is spawned every call.
- Default spawn model: `sonnet` (rubric-scored gates — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY). Revert conditions: CLAUDE.md > Spawn Model.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `docs/teammate-contracts.md`, target file paths.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — instruct the AI to read `docs/teammate-contracts.md > [section]` or `.autoflow/*` file paths directly. The same principle (file-path-only references) applies to all teammate dispatches; see [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list them in `recommendations` (or `blocking_issues` when score-blocking). Severity and confidence are expressed through the `score` and `reason`, never by silently omitting a finding. The rubric score is the filter; the finding stage prioritizes coverage.
- **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Recent Claude models follow such filtering instructions literally — they investigate just as deeply but drop sub-bar findings instead of reporting them, which lowers recall. Let it report all findings and let the score rank them.

---

## Test AI (testing teammate)
- Participates in plan synthesis (ARCHITECT) from a verification perspective — "how will this design be verified?"
- Authors the verification design document: acceptance criteria → verification method (automated / manual / environment-dependent / requires design change).
- Writes test code before implementation (Test First) and confirms Red.
- For untestable items: states the reason and proposes alternatives (design change / manual scenario / mock).
- Performs minimal-implementation verification after implementation: detects code outside test coverage.
- Operates independently from the Developer AI — tests are written from acceptance criteria, not from the developer's intended implementation.
- Default spawn model: `sonnet` at RED (acceptance criteria → test code). Complex test scenarios fall back to `opus`, with the rationale recorded in the Test AI report.
- **[MUST]** Runs verification (jest/build) in the **foreground**; never uses `run_in_background` — a spawned teammate has no future turn to receive a background-completion notification. See [`teammate-common-rules.md`](teammate-common-rules.md) > Bash Execution Mode.

---

## Submodule AI (per sub-repo, Developer AI)
- Understands and implements the assigned sub-repo's code.
- Writes the minimum code that passes the tests written by the Test AI (does not implement behavior outside tests).
- Has read access to other sub-repos; modifications stay within the assigned sub-repo.
- Works directly in the target repo and pushes to origin (the target repo's own branch). PR creation is performed by the orchestrator.
- *Secondary (multi-repo):* when the target is a sub-repo, the push goes to the AI's fork branch (in the fork-and-PR model).
- Common rules: see [`docs/submodule-common-rules.md`](submodule-common-rules.md).
- Default spawn model: `opus` at GREEN and VERIFY (implementation surface, self-check sycophancy risk). REFINE uses `sonnet` (mechanical `/simplify` application) — spawned fresh on the VERIFY → REFINE boundary, since mid-lifetime model switching is not supported.
- **[MUST]** Runs verification (jest/build) in the **foreground**; never uses `run_in_background` — a spawned teammate has no future turn to receive a background-completion notification. See [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Testing Standards > Bash execution mode.

The Submodule AI operates as the Developer AI directly in the target repo. *Secondary (multi-repo):* when the host contains submodules (see [`CLAUDE.md`](../CLAUDE.md#deployment-topology) > Deployment Topology), the target repo is the AI's assigned sub-repo, the fork/upstream procedure above applies, and PR creation remains the orchestrator's. The role contract is otherwise unchanged.

---

## Facilitator (deliberation sub-context)

The Facilitator runs a multi-teammate deliberation in an **isolated sub-context** so the orchestrator never receives the round-by-round cross-talk. The orchestrator invokes it for phases that run a Developer-AI ↔ Test-AI deliberation: **ARCHITECT** (feature design + verification design) and the **VERIFY** cause-branch. Rationale and the structural rule: [`CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation; [`docs/design-rationale.md`](design-rationale.md) > Decision 8.

### Realization — the `Workflow` tool (single supported mechanism)

The facilitator is realized as a **project workflow** the orchestrator runs with the `Workflow` tool, **not** as a nested Agent Team. This is the only realization that the Claude Code runtime both supports and documents as isolating:

- A spawned teammate **cannot** create its own team or teammates, and a team's lead is **fixed for the team's lifetime** (no lead transfer). So "a spawned facilitator that leads a nested Developer-AI ↔ Test-AI team" is not executable — ruled out. (Agent Teams > Limitations: <https://code.claude.com/docs/en/agent-teams>.)
- A peer-teammate facilitator inside the orchestrator's own team is **not** a documented isolation boundary: the docs state teammate messages arrive at the lead automatically and do **not** guarantee that peer-to-peer message *content* is withheld from the lead — so it cannot be relied on to keep the deliberation out of the orchestrator's context.
- The `Workflow` tool **is** documented as isolating: "intermediate results stay in script variables instead of landing in Claude's context," and the orchestrator receives one final result. (Workflows: <https://code.claude.com/docs/en/workflows>.)

**Invocation / version / config**:
- Prerequisites — both must hold (Workflows: <https://code.claude.com/docs/en/workflows>): (i) Claude Code **v2.1.154+**; (ii) Dynamic workflows **enabled** — they can be off by default (Pro requires turning on the Dynamic workflows row in `/config`) and are disabled by any of `disableWorkflows: true` in `~/.claude/settings.json` (or managed settings), or `CLAUDE_CODE_DISABLE_WORKFLOWS=1`.
- If the prerequisites do not hold, the orchestrator escalates with the **specific** cause — version gap vs. local `/config`/`settings.json` disable vs. env var vs. managed-policy disable — rather than a generic "unavailable", and proposes the matching enable step. It does **not** fall back to running the deliberation in its own turn stream.
- The orchestrator invokes `Workflow({ name: "architect-deliberation", args: { issue: "N" } })` at ARCHITECT and `Workflow({ name: "verify-cause-branch", args: { issue: "N", failLog: "<path>" } })` at VERIFY. Reference scripts: [`.claude/workflows/architect-deliberation.js`](../.claude/workflows/architect-deliberation.js), [`.claude/workflows/verify-cause-branch.js`](../.claude/workflows/verify-cause-branch.js).
- The workflow's internal design/verification sub-agents are spawned with `model: "opus"` (ARCHITECT work type — multi-turn design discussion / devil's advocate); VERIFY self-check sub-agents use `model: "opus"` (self-check sycophancy surface), matching [`CLAUDE.md`](../CLAUDE.md) > Spawn Model.

### Responsibilities

- **Owns the deliberation in-script**: the Developer-AI and Test-AI sub-agents run inside the workflow; their round-by-round exchange stays in workflow script variables and never enters the orchestrator's context.
- **[MUST]** The in-script Developer-AI / Test-AI sub-agents run all Bash **foreground**-only (`run_in_background` is orchestrator-only) — same rule as a directly-spawned teammate, since an in-script sub-agent likewise has no future turn to receive a background-completion notification. See [`teammate-common-rules.md`](teammate-common-rules.md) > Bash Execution Mode.
- **Drives convergence** under the Discussion Protocol ([`docs/teammate-common-rules.md`](teammate-common-rules.md) > Discussion Protocol) — UNDERSTAND → VERIFY → EVALUATE → RESPOND, devil's advocate on the first exchange, no groundless agreement. **ADR conformance** is a required first-exchange devil's-advocate axis: before mutual ACCEPT the exchange verifies the resolution conforms to any governing ADR; a divergence is a COUNTER, not an ACCEPT (blocking `CONVERGED`, which requires an empty `counters` per the Convergence rule). Non-scored — this is the ARCHITECT deliberation surface, not a gate.
- **Writes artifacts** to `.autoflow/issue-{N}-*.md` (feature design, verification design). It does not inline artifact bodies in its return.
- **Appends to the decision ledger** (`.autoflow/issue-{N}-ledger.md`): each settled decision with grounds + authority (append-only).
- **Returns one structured result** to the orchestrator (see Return Contract). It does not forward the discussion.

### Return Contract

The workflow's only output to the orchestrator is one structured result, **specific to the phase** (the two phases drive different next-state machines, so their schemas differ):

**ARCHITECT** (`architect-deliberation`):

```json
{
  "phase": "architect",
  "verdict": "CONVERGED | ESCALATE",
  "artifacts": [".autoflow/issue-N-feature-design.md", ".autoflow/issue-N-verification-design.md"],
  "ledger": ".autoflow/issue-N-ledger.md",
  "rounds": 4,
  "summary": "one-line outcome",
  "escalation": "what blocks convergence (only when verdict = ESCALATE)"
}
```

- Orchestrator routing: `CONVERGED` → GATE:PLAN; `ESCALATE` → surface to the user.
- **Convergence rule**: each round, both sub-agents return `{ response, counters, accept_grounds }`. `CONVERGED` requires, for **both** sides, **all three**: `response: "ACCEPT"`, an **empty** `counters`, and a **non-empty** `accept_grounds` (the dimensions verified + why each passed) — and the **round number > 1**. This encodes the Discussion Protocol structurally: no agreement on the first exchange (round 1 is a mandatory devil's-advocate review), a raised concern is never dropped (`counters` must be empty), and an ACCEPT must name its grounds (`accept_grounds` non-empty). Unresolved counters are threaded into the next round's prompt so fresh sub-agents must address them; the converged `accept_grounds` feed the ledger entry's grounds.
- **Ledger rule**: settled decisions under authority `ARCHITECT mutual ACCEPT` are appended **only** on `CONVERGED`. An `ESCALATE` run appends a single outcome entry under the distinct authority `ARCHITECT non-convergence` and records **no** settled decision — so the append-only ledger is never polluted with un-agreed content that the "no re-litigation without a new verified fact" rule would then lock in.
- **Missing draft / round**: a draft sub-agent that returns null (skipped/errored) or does not write its design artifact, or two consecutive Converge rounds in which **both** sub-agents return null, is recorded truthfully as MISSING and the workflow ESCALATEs early with a **distinct** `escalation` reason (`draft agent missing` / `draft artifact missing` / `sub-agent missing for N consecutive round(s)`) rather than exhausting `MAX_ROUNDS` under the generic "No mutual ACCEPT" text. Mirrors VERIFY's missing-self-check rule — an infrastructure/model failure is never laundered into a design-disagreement reason.

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

- **ARCHITECT**: a *round* = one Developer-AI ↔ Test-AI exchange cycle. Max **6 rounds**; on no mutual ACCEPT at round 6, the workflow returns `verdict: "ESCALATE"`. (Encoded as `MAX_ROUNDS = 6` in the script.)
- **VERIFY**: a single self-check round (each side answers once → deterministic `next_action`); there is no internal loop. Repeated VERIFY entries are bounded by the existing GREEN↔VERIFY round-trip cap (max 3) in [`CLAUDE.md`](../CLAUDE.md) > Flow Control.
- **[MUST]** No round-by-round messages, no duplicate dual reports, no artifact bodies in the return — paths + verdict/next-action + one line only (mirrors [`docs/submodule-common-rules.md`](submodule-common-rules.md) > Reporting Format).

### Orchestrator-side verification (leverage preserved)

After the result returns, the orchestrator **verifies** it before accepting — this is preserved, only the deliberation prose is isolated:

- It does **not** read the design docs cover-to-cover to *judge* them — that full read-and-score is GATE:PLAN's fresh Evaluation AI. The orchestrator instead **spot-checks targeted excerpts**: it pulls the specific `path:line` a returned decision rests on and re-derives the cited fact (`git show`, command re-run, `git show HEAD:<file>`). This is the same targeted anchor-check carved out by [`CLAUDE.md`](../CLAUDE.md#cost-control) > Orchestrator context discipline, not a full-body absorption.

### Verification scenarios (manual)

**Automated (mock-runtime regression)** — `test/workflows/run.mjs` locks the pure control-flow logic (convergence rule incl. round-1 block + grounded ACCEPT, counter threading, ledger-authority branching, ARCHITECT missing-draft/missing-artifact/consecutive-null early ESCALATE, VERIFY next_action incl. `missing`, and the arg guards) by running each script against a mock runtime that injects only the real globals (`args`, `phase`, `parallel`, `agent`, `console`) — a stray undefined global throws, catching the ABI-regression class. Run `node test/workflows/run.mjs`; the GitHub Actions `workflow-regression` job (`.github/workflows/workflow-regression.yml`) runs it on every PR/push touching `.claude/workflows/**` or `test/workflows/**`, on `ubuntu-latest` where a node runtime is guaranteed — the Jenkins agent is provisioned for compose/shell validation only and carries no node, so the regression lives where the runtime exists (same rationale as `.github/workflows/image-scan.yml`). Enforcement is **advisory**: this repo's plan provides no GitHub branch-protection/required-status-checks (the API returns 403), so a red run does not auto-block merge — it surfaces a pass/fail signal that the external reviewer verifies green before merge (the "CI green" precondition in [`external-review-sequencing.md`](external-review-sequencing.md)), the same path as every other CI check.

**Manual (live runtime)** — these need an actual session and confirm isolation/routing end-to-end; run once on a prerequisite-satisfying session (see Invocation / version / config) and record in the cycle notes:

- **Smoke**: invoke each workflow with `Workflow({ name: ... })` and confirm it reaches the first `agent()` without a runtime error.
- **Isolation**: run `architect-deliberation`; confirm the orchestrator transcript contains the single result object and **no** round-by-round Developer/Test messages.
- **VERIFY routing**: exercise all four self-check combinations; confirm each maps to `RED` / `GREEN` / `SEQUENTIAL_FIX` / `EVALUATION_AI`.
- **Counters block ACCEPT**: have a sub-agent return `ACCEPT` with a non-empty `counters`; confirm the run does **not** converge and the counter is carried into the next round.
- **Cap & ledger**: force round-6 non-convergence; confirm the workflow returns `ESCALATE`, appends **no** `ARCHITECT mutual ACCEPT` entry, and records only the `ARCHITECT non-convergence` outcome.
- **fs availability (R1, option b)**: under the live hosted Workflow runtime, confirm the `await import('node:fs')` draft-artifact existence check either (i) resolves and detects a withheld artifact as `draft artifact missing`, or (ii) throws and the try/catch degrades cleanly to the null-return (missing-draft) path without crashing. This is the only place the fs-availability question — and the fs-absent `catch` branch — can be observed: the mock harness always runs under Node, where `import('node:fs')` resolves, so the branch is harness-unreachable by design.

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
| Plan evaluation | Feasibility, Dependencies, Scope, Security, Test plan (5) — Feasibility/Scope carry structural-fit & over-engineering (not scored at DIAGNOSE) | max 3× |
| Security audit | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) | max 3× |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

### Evaluation Output Format

```json
{
  "type": "hypothesis_evaluation | plan_evaluation | security_audit | quality_evaluation | doc_evaluation",
  "target": "scope name",
  "issue": "#N",
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": ["items 5-6"]
}
```
