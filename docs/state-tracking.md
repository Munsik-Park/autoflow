# AutoFlow State Tracking

The state file's detail — its naming, its schema and fields, the hook gates that read it, and its state at completion. The rules that write into it — the `verdict` rule, score recording and remedy class recording — are [`docs/core.md`](core.md) > AutoFlow State Tracking (Hook integration).

**File naming**: `.autoflow/{repo-key}-issue-{N}/issue-{N}.json`. Every file of one issue — the state file, the ledger, the unit and gate reports, the cycle-layer store `issue-{N}-local/` and the proposal record — lives in that one directory, so a new session resumes from it alone and two repositories' issues of the same number never share a name. `{repo-key}` is `<owner>__<name>` derived from the checkout's `origin` by `scripts/lib/issue-dir.sh` — the key the archive uses too; the one exception is a proposal record for an issue filed with `--repo` in another repository, which takes that repository's key. A state file at the former flat path `.autoflow/issue-{N}.json` is not read: the layout is adopted with no cycle active.

**Companion artifact**: `.autoflow/{repo-key}-issue-{N}/issue-{N}-ledger.md` — the append-only decision ledger ([Decision Ledger](core.md#decision-ledger)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: by the orchestrator, at PREFLIGHT completion.

```json
{
  "active": true,
  "issue": "#N",
  "title": "Issue title",
  "date": "YYYY-MM-DD",
  "branch": "dev/YYYY-MM-DD-HHMMSS-issue-N",
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

**`branch` field**: the issue's dev branch, named once at Creation from the time it is created (`dev/YYYY-MM-DD-HHMMSS-issue-N`) and kept unchanged for the life of the state file — a review-response continues on it, and the archive directory takes its name from it. It is what ties a branch and its pull request to this checkout's cycle when another checkout runs the same issue (`docs/units/preparation.md` > *What is asked*). The hook admits it as a string and does not read it.

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry; what that resets is `docs/units/preparation.md` > *Review-response setup*. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; the review-response setup sets `"review-response"` (target issue's PR is open). The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF aggregates and triages the review result; `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no PR's verdict is Medium+) and at a GATE:HYPOTHESIS `no change needed` review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](core.md#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](core.md#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (a spawn whose caller `agent_type` is a functional-unit agent) → no declaration required; judged by the unit's gate class, and a declared role's own gate also applies (see [Spawn Model](core.md#spawn-model--phase-by-phase) > A unit agent's spawns inherit its gate class).
- `Agent` (role `planning` — `autoflow-unit-design`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` is a `skipped` value (non-bug issue).
- `Agent` (role `implementation` — `autoflow-unit-build`) → GATE:PLAN pass required.
- `Agent` (role `analysis` — `autoflow-analyzer`, `autoflow-reviewer`, `autoflow-criterion-tracer`, `autoflow-criterion-analyzer`, `autoflow-criterion-reconciler`, `autoflow-unit-analysis` — / `evaluation` / `advisor` / research types) → not score-gated.
- `Write` / `Edit` / `MultiEdit` on an `issue-*-ledger.md` → **state-independently**: a write that changes or removes existing text is denied (append-only); adding an `advisor decision` authority or an `A<n>` entry is denied unless the caller `agent_type` is `autoflow-advisor`; adding `operator decision` or an `O<n>` entry is denied unless the caller is the main session; the advisor adding an `O` / `F` / `E` entry is denied ([`docs/role-contracts.md`](role-contracts.md) > Advisor > *Independence*).
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `.autoflow/{repo-key}-issue-{N}/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch (`main`) → **denied while a state file has `active:true`**. AutoFlow never merges; merging is external.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`docs/issue-proposal.md`](issue-proposal.md).
- A **backgrounded** run of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on `Bash` (git / gh commands), `Write|Edit|MultiEdit` and `Agent`.

**Completion**: at HANDOFF, once the aggregated review is clean (no PR's verdict is Medium+ — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-cycle resolution reads the file (review-response mode) and, once the PR is observed merged or closed, archives it with the issue's other artifacts (`docs/units/preparation.md` > *What is asked*).
**Forced termination**: also set `active` to `false`.
