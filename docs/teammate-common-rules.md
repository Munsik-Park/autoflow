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
# The orchestrator opens the PR — report completion in the spawn's return value.
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
2. Read the assignment in the spawn prompt — it carries the task and the
   `.autoflow/*` paths. There is no mailbox to poll: the prompt is delivered
   once, at spawn.

---

## Bash Execution Mode

- **[MUST]** A spawned teammate runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- **Why (lifecycle contract):** the harness's background-task contract — *re-invoke the owning agent when the task completes* — holds only for an agent that has a future turn. A spawned subagent terminates with its final response, so any still-pending background process is **reaped at teardown**: its output is lost and no completion notification is ever delivered, stalling the orchestrator on a report that never arrives (issue #952 — 71-minute orchestrator deadlock, 2026-07-07). A background CPU-heavy process can also starve the agent's own foreground verification and distort the pass/fail verdict (issue #287). The background + completion-notification pattern is therefore **orchestrator-only** (the main loop is the sole actor with future turns).
- **Enforced at the tool boundary for suite runs (issue #134):** a backgrounded invocation of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the orchestrator included; the orchestrator-only background pattern above never extends to a suite run, whose result must stay keyed to the capture-point tree (`docs/autoflow-guide.md` > VERIFY > Green-tree register; `docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).
- **The orchestrator's side of the wait (issue #165):** the notification the orchestrator waits for arrives only between its tool calls, so the orchestrator waits by **ending its turn**, never by blocking on one task — the deprecated `TaskOutput` tool is refused by the PreToolUse hook state-independently, and a foreground `sleep` loop polling for a spawn's result is the same fault by other means (`CLAUDE.md` > Execution Principles > *Wait discipline*). A spawned agent is unaffected in what it may do: it runs foreground and returns; it is the orchestrator that must not sit in a block while that return is pending.

---

## Tree Quiesce (spawn-boundary form)

- **[MUST]** A spawned agent performs tracked-tree writes only inside its own spawn's lifetime, on
  the assignment its spawn prompt carries — there is no message channel through which new tree work
  can arrive mid-flight, and none through which a freeze could be delivered.
- **Why:** the orchestrator takes a *capture point* (`git status --porcelain`, `git rev-parse
  HEAD^{tree}`, `git rev-parse HEAD`) immediately before starting a suite run, and the run's result is
  evidence only for the tree observed at that instant
  (`docs/autoflow-guide.md` > VERIFY > Green-tree register > *Capture point*). A tracked-tree write
  landing while that run is in flight moves the tree under it, the register refuses the entry, and the
  whole run is wasted.
- The quiesce obligation therefore sits with the **orchestrator's spawn schedule**, not with a
  message protocol: no tree-writing spawn is issued between a capture point and the end of the run it
  opened, and a capture point is taken only while no tree-writing spawn is in flight. (The HOLD/GO
  message protocol this section previously specified belonged to the retired named-teammate mode —
  see `CLAUDE.md` > Communication.)

---

## Work Completion Process

```
Implement → /simplify → tests pass → push branch → return the report
```

**Required content of the completion report** (the spawn's return value — write any
body to `.autoflow/*` and return an anchor plus a one-line summary):

- Files changed.
- Test results (pass/fail).
- Cross-cutting impact (interfaces, data structures, config).
- Caveats or known limitations.
- Branch name and final commit hash.

---

## Communication — Agent Teams

The Agent Teams channel is **retired**. The orchestrator spawns each role with `Agent`
(`subagent_type`, explicit `model`), and the spawn's return value is its report. There
is no team, no mailbox, and no peer-to-peer messaging between roles.

| Action | Method | Note |
|--------|--------|------|
| Receive instruction from orchestrator | the spawn prompt | delivered once, at spawn |
| Report to orchestrator | the spawn's return value | completion, escalation — body to `.autoflow/*`, return an anchor + one-line summary |
| Mark task done | `TaskUpdate(status: "completed")` | then check `TaskList` |
| Cross-cutting impact notice | in the returned report | the orchestrator routes it to the affected scope |
| Discuss with another role | not available | a deliberation is delegated to a facilitator `Workflow` (below), never held between spawns |

**Message economy** (issue #136, discharged structurally by the spawn-mode migration). The #136
measurement priced every named-teammate message as a context re-write. With every role an anonymous
direct spawn there is no message channel left to economize: the assignment travels once in the spawn
prompt, the report travels once in the return value, and no ACK, HOLD/GO, or idle-notification turn
exists. The measurement itself is retained at `docs/adr/0017-teammate-removal-feasibility.md` >
Notes > C8.

**Facilitated deliberation phases** (ARCHITECT, VERIFY cause-branch): the discussion
runs inside an isolated **`Workflow`** (the facilitator). The Developer-AI and Test-AI
run as in-script workflow sub-agents, their round-by-round exchange stays in workflow
variables, and only a single structured result returns to the orchestrator. See
[`teammate-contracts.md`](teammate-contracts.md) > Facilitator
and [`CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) >
Deliberation Isolation.

### Result delivery path by spawn mode

Every role is an anonymous direct spawn, so there is exactly one delivery path.

| Spawn mode | Where the final turn text goes | Required delivery action |
|---|---|---|
| anonymous direct (`subagent_type`) — the only mode | the spawn's return value (sync) or a task notification (background) | none — the final text is the report; write the body to `.autoflow/*` and return an anchor + one-line summary |

**Why the other mode was removed, and the measurement that removed it.** A named team spawn's final turn text was **discarded — never delivered to the lead**, so a report existing only as the final response was lost with no error; that mode required an explicit `SendMessage(to: "team-lead")` instead. Observed, not guaranteed: across all 12 subagents of the #40 cycle, delivery matched the `SendMessage` call count 12 out of 12 — every spawn that called it once was received, every spawn that never called it was not, and no transport failure occurred. Three of those losses (`eval-gate-plan-40`, `eval-quality-40`, `test-red-40`) were recovered only by re-requesting the report. That measurement is the case for the migration and is retained here for that reason; it described Claude Code Agent Teams behavior at the time and was re-derivable through `tests/manual/issue-42-manual-scenarios.md` M1. The remaining open question — whether a direct spawn detects as well on VERIFY steps 3 and 4 — was settled by the ADR-0017 C7 pilot, which returned `EQUAL_OR_BETTER` (`docs/adr/0021-c7-pilot-spawn-mode-result.md`).

The single mode applies to every role; the per-role table is [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase > Spawn mode by role lifetime.

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
