# Teammate Common Rules

> Shared rules that apply to all teammates (Test AI, Developer AI) participating in
> the AutoFlow lifecycle in this repository.

The orchestrator (the main session) coordinates work; teammates are spawned as
Agents and execute the actual writing of code, tests, and documentation. The rules
below describe the contract every teammate honours.

---

## Identity

- The teammate understands, implements, and tests files within its assigned scope.
- The teammate may **read** any file in the repository.
- The teammate **may not modify** files outside the scope assigned by the dispatch
  instructions for the current issue.
- PR creation is the orchestrator's responsibility — the teammate's git work
  finishes at `git push` of its branch.

---

## Git Workflow

```bash
# At session start (after the orchestrator has prepared a branch in PREFLIGHT)
git status                  # confirm a clean working tree
git log --oneline -5        # confirm the recent history

# After completing the assigned work
git add <files> && git commit
git push -u origin <branch-name>
# The orchestrator opens the PR — report completion via SendMessage.
```

**Absolute rules**:

- No direct commits to the default branch (`main`).
- No new branch for the **same issue** while that issue's own PR is still open — a review-response cycle continues on that issue's existing dev branch. Whether a *different* issue may start is **not** gated on the prior PR's merge state; it is governed by [`CLAUDE.md`](../CLAUDE.md) > PR Wait Rule (the `active` flag). AutoFlow hands off at an open PR and the next cycle starts once every other issue reads `active:false`, so "prior PR still unmerged" is the designed steady state, not a blocker.
- Always run `git status` before committing.
- No `feat`/`fix` commit while tests are failing — use `wip` instead.

---

## Commit Format

```
<type>(#<issue>): <description>

Next: <what comes next>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

---

## Session Protocol

At the start of each session:

```bash
git log --oneline -5        # what was last committed
git status                  # any uncommitted work?
```

1. Read the `Next:` line in the most recent commit and continue from there.
2. Read pending `SendMessage` from the orchestrator (delivered automatically via
   Agent Teams).

---

## Bash Execution Mode

- **[MUST]** A spawned teammate runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- **Why (lifecycle contract):** the harness's background-task contract — *re-invoke the owning agent when the task completes* — holds only for an agent that has a future turn. A spawned subagent terminates with its final response, so any still-pending background process is **reaped at teardown**: its output is lost and no completion notification is ever delivered, stalling the orchestrator on a report that never arrives (issue #952 — 71-minute orchestrator deadlock, 2026-07-07). A background CPU-heavy process can also starve the agent's own foreground verification and distort the pass/fail verdict (issue #287). The background + completion-notification pattern is therefore **orchestrator-only** (the main loop is the sole actor with future turns).

---

## Work Completion Process

```
Implement → /simplify → tests pass → push branch → SendMessage report
```

**Required content of the completion report** (`SendMessage(to: "team-lead")`):

- Files changed.
- Test results (pass/fail).
- Cross-cutting impact (interfaces, data structures, config).
- Caveats or known limitations.
- Branch name and final commit hash.

---

## Communication — Agent Teams

The orchestrator spawns teammates with `Agent` (`team_name`, `name`). Messages are
push-delivered.

| Action | Method | Note |
|--------|--------|------|
| Receive instruction from orchestrator | automatic (push) | message arrives via Agent Teams |
| Discuss with another teammate | `SendMessage(to: "name")` | direct, no orchestrator routing |
| Report to orchestrator | `SendMessage(to: "team-lead")` | completion, escalation |
| Mark task done | `TaskUpdate(status: "completed")` | then check `TaskList` |
| Cross-cutting impact notice | `SendMessage` | to affected teammate, or to lead |

**Facilitated deliberation phases** (ARCHITECT, VERIFY cause-branch): the discussion
does **not** run as Agent-Teams teammates messaging the orchestrator. It runs inside
an isolated **`Workflow`** (the facilitator): the Developer-AI and Test-AI run as
in-script workflow sub-agents, their round-by-round exchange stays in workflow
variables, and only a single structured result returns to the orchestrator. There is
no `SendMessage(to: facilitator)` and no nested team — those are not supported by the
Agent Teams runtime. See [`teammate-contracts.md`](teammate-contracts.md) > Facilitator
and [`CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) >
Deliberation Isolation.

---

## Discussion Protocol (Single Source of Truth)

The rules below govern every multi-AI discussion. They prevent groundless agreement
and force grounded judgement. The orchestrator's `CLAUDE.md` references this section
as the canonical Discussion Protocol. In facilitated deliberation phases (ARCHITECT,
VERIFY cause-branch) this protocol is driven inside an isolated `Workflow` (the
facilitator) and only a single result returns to the orchestrator — the protocol
itself is unchanged; what differs is that the Developer-AI/Test-AI run as in-script
workflow sub-agents rather than as orchestrator teammates (see Communication — Agent
Teams above).

**Response process**:

1. **UNDERSTAND** — restate the other party's proposal in concrete terms (a bare
   "I understand" is not acceptable).
2. **VERIFY** — actually **read** the relevant source files, schemas, and config.
   Memory alone is not enough.
3. **EVALUATE** — assess on at least two of:
   - Feasibility — is this possible with the current code/infrastructure?
   - Fit — does it follow existing patterns, naming, and layering?
   - Trade-offs — cost, maintenance, migration complexity?
   - Alternatives — is there a simpler path?
   - Scope — is the level of abstraction right?
4. **RESPOND** — exactly one of:
   - **ACCEPT** — name the dimensions verified and why each passed.
   - **COUNTER** — state the problem + a concrete alternative + evidence.
   - **PARTIAL** — accept the parts that pass; counter the parts that don't.
   - **ESCALATE** — fundamental disagreement → present both sides to the user.

**Anti-patterns (forbidden)**:

- "Sounds good" — no agreement without naming the dimension verified and why.
- Evaluating code/schema/config proposals without reading the file.
- Stacking new features on top of unverified proposals.
- Agreeing on the first exchange — at least one dimension must be reviewed as
  devil's advocate.
- Letting a raised concern go unanswered — re-raise until resolved.

---

## Quality Standards

- Read and understand the existing code before changing it.
- Run the relevant tests after each change and confirm they pass.
- Run `/simplify` after implementation as a self-optimization step.
- Do not add unnecessary refactors, comments, or type annotations.
- Do not introduce security vulnerabilities.
- Do not make changes outside the assigned scope.

---

## Documentation Rules

- Code/policy: English.
- Markdown docs: English (source of truth).
- HTML docs: Korean (translation), if maintained.
- Interface changes require updating the related docs.
