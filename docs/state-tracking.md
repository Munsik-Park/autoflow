# AutoFlow State Tracking

The state file's detail — its naming, its schema and fields, the hook gates that read it, and its state at completion. The rules that write into it — the `verdict` rule, score recording and remedy class recording — are [`<autoflow-root>/docs/core.md`](core.md) > AutoFlow State Tracking (Hook integration).

**Record location**: an attempt — one run of an issue — keeps every file in its record directory `<attempt-dir>` = `<record-root>/<repo-key>/<stamp>-issue-{N}/`, named by its dev branch `dev/<stamp>-issue-{N}` (`<stamp>` = `YYYY-MM-DD-HHMMSS`): the state file, the ledger, the criterion review record, the unit and gate reports, the review records and the cycle-layer store `issue-{N}-local/`. `autoflow-records dir` prints it for the checked-out dev branch (`--branch` for another), and every document, agent definition, script and hook names a record path through that command or the library it wraps, `<autoflow-root>/scripts/lib/records.sh`. Two repositories' issues of the same number never share a name, and two attempts of one issue — in one checkout, two worktrees or two clones — never share a directory. `{repo-key}` is `<owner>__<name>` derived from the checkout's `origin`.

- **The record root** is `record_root` in the operator's `~/.autoflow/config.json` — an absolute path; the file itself never moves with it. No file, no key, or a JSON `null` → the default `~/.autoflow`. A file that cannot be read as JSON (a syntax error, or no `jq`), or a `record_root` that is not an absolute path string (not a string, empty, relative), leaves the record root **undetermined**, never the default in its stead; an error in the same file's `.review` does not touch it. A record root inside the session's checkout, or one that cannot be created or written, is **unusable**. Either way every script that needs it writes nothing and stops with exit `7` and the marker line `record-root: UNDETERMINED <config path> — <error>` or `record-root: UNUSABLE <record root> — <error>`, asking nothing; the next run reads the file anew. Nothing else — no environment variable — names the root, the records or `_metrics/`.
- **The owner**: the file `checkout` in the record directory names the checkout the attempt belongs to — the one that started it, or the one that took it over (`autoflow-records claim`, once that checkout is gone). Entry, the hook's gates and cleanup read only this checkout's attempts ([`<autoflow-root>/docs/units/preparation.md`](units/preparation.md) > *What is asked*).
- **Completed**: the file `completed` marks an attempt whose Post-Merge Cleanup has run; its records stay where they are ([`<autoflow-root>/docs/git-workflow.md`](git-workflow.md) > Post-Merge Cleanup).
- **Records kept inside the tree before the record root** (`.autoflow/<repo-key>-issue-{N}/`, issues #423 to #465): a state file there is never passed over. The hook refuses the score-gated calls and PREFLIGHT stops (`entry: stop in-tree-records`) until `<autoflow-root>/scripts/migrate/migrate-in-tree-records.sh` moves each such directory whose state file names a dev branch `dev/<stamp>-issue-{N}` to that attempt's record directory, with this checkout as its owner; the cycle then continues from there. One naming no such branch is moved too when it reads `active: false` — to `<record-root>/<repo-key>/in-tree-<date>-<time>-issue-{N}/`, marked `completed`, kept as a record and never entered; when it reads `active: true` it is reported and left for the operator (name the branch in the attempt shape, or set `active: false`), and the script runs again. A directory with no state file (a proposal record, a criterion review of no attempt) is not a cycle and is left in place.

**Companion artifact**: `<attempt-dir>/issue-{N}-ledger.md` — the attempt's append-only decision ledger ([Decision Ledger](core.md#decision-ledger)). The hook reads it **advisorily only** and never denies a tool call on what it finds; the ledger is not a gate input — no gate verdict, retry cap or transition reads it.

**Creation**: by the orchestrator, at PREFLIGHT completion — the attempt's record directory and dev branch already exist, made by its criterion review (`autoflow-records new`; [`<autoflow-root>/docs/criterion-review.md`](criterion-review.md) > *When and by whom*).

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

**`branch` field**: the attempt's dev branch, named once when its criterion review creates the attempt (`dev/YYYY-MM-DD-HHMMSS-issue-N`) and kept unchanged for the life of the state file — a review-response continues on it, and the record directory is named from it. The hook admits it as a string and does not read it.

**`cycle` field**: starts at `1` on Creation. It is incremented on review-response entry; what that resets is `<autoflow-root>/docs/units/preparation.md` > *Review-response setup*. The hook gates read from the current `phases`; the durable cycle record lives in the GitHub PR/issue thread and commit log.

**`mode` field**: `"new-issue"` on Creation; the review-response setup sets `"review-response"` (target issue's PR is open). The hook does not read it (additive field).

**`phase` field**: coarse, non-exhaustive lifecycle marker (the hook does not read it; additive field) — `"in-progress"` during a cycle; `"review-triage"` while HANDOFF aggregates and triages the review result; `"awaiting-external-review"` at HANDOFF (set only once the review is clean — no PR's verdict is Medium+) and at a GATE:HYPOTHESIS `no change needed` review-response exit; `"awaiting-user"` at every pause for a human decision (the Flow Control rows that set it). A terminal or escalation state this list does not name leaves `phase` at its last value; `active` is the authoritative run flag.

**Hook gates** (script computes from `scores`):

- `Agent` (any spawn) → explicit `model` parameter required (state-independent — see [Spawn Model](core.md#spawn-model--phase-by-phase)).
- `Agent` (any spawn, active cycle) → **declared role** required (`autoflow-*` subagent_type or a research type); an undeclared spawn is denied. The gate class comes from the declaration, never from prompt keywords — see [Spawn Model](core.md#spawn-model--phase-by-phase) > Spawn role declaration.
- `Agent` (a spawn whose caller `agent_type` is a functional-unit agent) → no declaration required; judged by the unit's gate class, and a declared role's own gate also applies (see [Spawn Model](core.md#spawn-model--phase-by-phase) > A unit agent's spawns inherit its gate class).
- `Agent` (role `planning` — `autoflow-unit-design`) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` is a `skipped` value (non-bug issue).
- `Agent` (role `implementation` — `autoflow-unit-build`) → GATE:PLAN pass required.
- `Agent` (role `analysis` — `autoflow-analyzer`, `autoflow-reviewer`, `autoflow-criterion-tracer`, `autoflow-criterion-analyzer`, `autoflow-criterion-reconciler`, `autoflow-unit-analysis` — / `evaluation` / `advisor` / research types) → not score-gated.
- `Write` / `Edit` / `MultiEdit` on an `issue-*-ledger.md` → **state-independently**: a write that changes or removes existing text is denied (append-only); adding an `advisor decision` authority or an `A<n>` entry is denied unless the caller `agent_type` is `autoflow-advisor`; adding `operator decision` or an `O<n>` entry is denied unless the caller is the main session; the advisor adding an `O` / `F` / `E` entry is denied ([`<autoflow-root>/docs/role-contracts.md`](role-contracts.md) > Advisor > *Independence*).
- `git push` → AUDIT + GATE:QUALITY pass required, and neither's latest record carries `remedy_class` (an open re-entry — a recommendation attempt not yet re-scored clean).
- `gh pr create` → the same two conditions.
- Which state gates: the state files of **this checkout's** attempts — the record directories whose `checkout` file names the session's checkout (`CLAUDE_PROJECT_DIR`), not marked `completed`. Another checkout's attempt never gates the session. Two or more active ones fail closed on the score-gated surface (`git push`, `gh pr create`, a spawn other than research or evaluation); so does a malformed one.
- In a session with an AutoFlow dev branch (`dev/…-issue-<N>`) checked out — or being rebuilt by an interrupted rebase on a detached HEAD — a record root that is undetermined or unusable, a directory under it that cannot be read, or no `jq` (so neither the input nor the state can be read), refuses the same score-gated surface with the user file's path and error; reads, the writes that repair the file and research / evaluation spawns pass, and the next call reads the file anew. A session with no dev branch checked out can have no attempt in progress and is not refused for it. With no `jq`, the state-independent denies below still hold, read the same over-inclusive way from the raw input.
- A state file in the checkout's own `.autoflow/` (*Record location* above) refuses the score-gated surface until it is moved.
- `git commit` while the latest `phases.gate_quality` record carries `remedy_class: "doc"` → the sweep record `<attempt-dir>/issue-{N}-remedy-sweep.md` must exist with non-empty `## Command` and `## Output` sections (the class-level remedy anchor; the hook checks the file, never the wording of an instruction). Other classes and commits outside a `doc` re-entry are ungated.
- `gh pr merge`, and any push to the default branch (`main`) → **denied state-independently**. AutoFlow never merges; merging is external.
- `gh issue create` (bare command form, and the same-segment REST `POST …/issues` form) → **denied state-independently**; issue filing goes through `<autoflow-root>/scripts/issue/create-issue.sh`, which requires a reviewed draft and re-runs the duplicate check itself — see [`<autoflow-root>/docs/issue-proposal.md`](issue-proposal.md).
- A **backgrounded** run of `<autoflow-root>/scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` on the invocation — → **denied state-independently**, for every actor including the orchestrator; suite runs execute in the foreground (matching rule: `<autoflow-root>/docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

These gates are wired via PreToolUse on `Bash` (git / gh commands), `Write|Edit|MultiEdit` and `Agent`.

**Completion**: at HANDOFF, once the aggregated review is clean (no PR's verdict is Medium+ — Medium+ findings auto-resolved and Low findings triaged), set `active` to `false` and record `phase: "awaiting-external-review"`. PREFLIGHT's prior-attempt resolution reads the file (review-response mode) and, once the PR is observed merged or closed, marks the attempt completed; its records stay in its record directory (`<autoflow-root>/docs/units/preparation.md` > *What is asked*).
**Forced termination**: also set `active` to `false`.
