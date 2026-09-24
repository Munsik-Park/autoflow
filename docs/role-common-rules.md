# Role Common Rules

> Shared rules that apply to every role spawn (Test AI, Developer AI) participating in
> the AutoFlow lifecycle in this repository.

The orchestrator (the main session) coordinates work; role spawns are launched as
Agents and execute the actual writing of code, tests, and documentation. The rules
below describe the contract every role spawn honours.

---

## Identity

- The role spawn understands, implements, and tests files within its assigned scope.
- The role spawn may **read** any file in the repository.
- The role spawn **may not modify** files outside the scope assigned by the dispatch
  instructions for the current issue.
- PR creation is the orchestrator's responsibility — the role spawn's git work
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
- No new branch for the **same issue** while that issue's own PR is still open — a review-response cycle continues on that issue's existing dev branch. Whether a *different* issue may start is **not** gated on the prior PR's merge state; it is governed by [`CLAUDE.md`](../CLAUDE.md) > PR Wait Rule (the `active` flag).
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

- **[MUST]** A role spawn runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- The background + completion-notification pattern is **orchestrator-only**.
- **[MUST] A foreground command ends on its own.** This binds the same actors as the first bullet, in three forms:
  - **The session shell may not be bash.** The Bash tool's shell is initialized from the user's profile, and a stock macOS profile is zsh, whose expansion differs from bash's: an unquoted `$VAR` is not word-split, an unmatched glob is an error (`no matches found`) instead of the literal word, and a word beginning with `=` is replaced by a command's path. A list — PIDs, file names, arguments — is held in an array and expanded quoted, `"${pids[@]}"`; a glob meant as an argument is quoted (`--include='*.sh'`); a procedure written for bash runs under bash — `bash -c '…'`, or a file run with `bash <path>`.
  - **No bare `wait`.** `wait "$pid"` names its process and is for a process that ends by itself; a process that must be stopped — a load generator, a server — is waited out by a bounded poll: `kill -0 "$pid"` against a counter, then `kill -KILL`, then a report of any PID that is still alive. The bound does not depend on `timeout`.
  - **A cleanup command's stderr is kept.** Its exit status is read one PID at a time. Only a probe whose failure is the expected answer — `kill -0` asking whether a process is still alive — discards its stderr.

  A reproduction that starts background processes and stops them in the same command, in a form that reaches its end whether or not the cleanup succeeds:

  ```bash
  # Start: every PID recorded in an array, one element each.
  pids=()
  for i in 1 2 3 4; do
    yes > /dev/null &
    pids+=("$!")
  done

  # ... the reproduction ...

  # Stop: one kill per PID, stderr kept; then each wait is bounded (about 5 s, then KILL).
  for pid in "${pids[@]}"; do
    kill "$pid" || echo "cleanup: kill $pid failed (stderr above)"
  done
  for pid in "${pids[@]}"; do
    n=0
    while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 50 ]; do
      sleep 0.1
      n=$((n + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "cleanup: $pid survived TERM; sending KILL"
      kill -KILL "$pid"
    fi
  done
  ```
- **Enforced at the tool boundary for suite runs:** a backgrounded invocation of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the orchestrator included; the orchestrator-only background pattern above never extends to a suite run (`docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).
- **The orchestrator's side of the wait:** the orchestrator waits by **ending its turn**, never by blocking on one task — the deprecated `TaskOutput` tool is refused by the PreToolUse hook state-independently, and a foreground `sleep` loop polling for a spawn's result is the same fault by other means (`CLAUDE.md` > Execution Principles > *Wait discipline*). A spawned agent is unaffected in what it may do: it runs foreground and returns; it is the orchestrator that must not sit in a block while that return is pending.

---

## Tree Quiesce (spawn-boundary form)

- **[MUST]** A spawned agent performs tracked-tree writes only inside its own spawn's lifetime, on
  the assignment its spawn prompt carries.
- The orchestrator's spawn schedule issues no tree-writing spawn while another spawn's run is in
  flight.

---

## Work Completion Process

```
Implement → /simplify as judged and the comment check (REFINE step 1) → tests pass → push branch → return the report
```

**Required content of the completion report** (the spawn's return value — write any
body to `.autoflow/*` and return an anchor plus a one-line summary):

- Files changed.
- Test results (pass/fail).
- Cross-cutting impact (interfaces, data structures, config).
- Caveats or known limitations.
- Branch name and final commit hash.

---

## Communication

The orchestrator spawns each role with `Agent`
(`subagent_type`, explicit `model`), and the spawn's return value is its report. There
is no team, no mailbox, and no peer-to-peer messaging between roles.

| Action | Method | Note |
|--------|--------|------|
| Receive instruction from orchestrator | the spawn prompt | delivered once, at spawn |
| Report to orchestrator | the spawn's return value | completion, escalation — body to `.autoflow/*`, return an anchor + one-line summary |
| Cross-cutting impact notice | in the returned report | the orchestrator routes it to the affected scope |
| Discuss with another role | not available | a deliberation is delegated (below): at ARCHITECT to the orchestrator's relay of two persistent participants over a transcript file, at VERIFY to a facilitator `Workflow` — never held between ordinary spawns |

**Facilitated deliberation phases** (ARCHITECT, VERIFY cause-branch): the orchestrator
never receives the round-by-round exchange. At **ARCHITECT** the Developer AI and the
Test AI are two persistent participants (anonymous direct spawns of `autoflow-planner`)
that the orchestrator wakes in alternation by agent ID; every turn and each report is
appended to `.autoflow/issue-{N}-architect-transcript.md` and the participant returns one
line, and a Record **`Workflow`** then writes the artifacts from that file. At
**VERIFY** the self-checks run as in-script sub-agents of an isolated `Workflow`. In
both, only a single structured result returns to the orchestrator. See
[`role-contracts.md`](role-contracts.md) > Facilitator
and [`CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) >
Deliberation Isolation.

### Result delivery path by spawn mode

Every role is an anonymous direct spawn, so there is exactly one delivery path — the spawn's final text — whether the spawn is answering its prompt or a later wake.

| Spawn mode | Where the final turn text goes | Required delivery action |
|---|---|---|
| anonymous direct (`subagent_type`) — the only mode | the spawn's return value (sync) or a task notification (background) | none — the final text is the report; write the body to `.autoflow/*` and return an anchor + one-line summary |
| the same spawn **resumed by agent ID** (`SendMessage`, no `name`) — the ARCHITECT relay participants only | a task notification of the resumed spawn, its final text verbatim in the `result` field | none — the final text is one line (`turn <n> — further: <yes|none>`); the turn body goes to the transcript file, never to the return |

A spawn carries no `name`: the gate hook keys the role→gate mapping on `subagent_type` alone and denies a `name`-carrying payload inside a cycle.

The single mode applies to every role; the per-role table is [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase > Spawn mode by role lifetime.

---

## Discussion Protocol (Single Source of Truth)

The rules below govern every multi-AI discussion. The orchestrator's `CLAUDE.md` references this section
as the canonical Discussion Protocol. In facilitated deliberation phases (ARCHITECT,
VERIFY cause-branch) this protocol is driven outside the orchestrator's context — at
ARCHITECT between two persistent participants over a transcript file the orchestrator
relays, at VERIFY inside an isolated `Workflow` — and only a single result returns to
the orchestrator; the Developer AI and the Test AI are role spawns, not members of an orchestrator team (see Communication
above).

**Response process**:

1. **UNDERSTAND** — restate the other party's proposal in concrete terms (a bare
   "I understand" is not acceptable).
2. **VERIFY** — actually **read** the relevant source files, schemas, and config.
   Memory alone is not enough. Scope over a shared transcript: a fact
   the transcript cites with a `path:line` (or a command and its output) is verified
   for both participants; a participant reads a file to ground a claim it is making
   or to dispute a cited one — not to re-verify what either side already anchored.
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
- Run `/simplify` after implementation when the diff warrants it — the judgment and its grounds go in the REFINE report (`docs/autoflow-guide.md` > REFINE step 1).
- Do not add unnecessary refactors or type annotations. A comment carries only what `docs/submodule-common-rules.md` > Change Surface Rules > *Code comments* admits.
- Do not introduce security vulnerabilities.
- Do not make changes outside the assigned scope.

---

## Documentation Rules

- Code/policy: English.
- Markdown docs: English (source of truth).
- HTML docs: Korean (translation), if maintained.
- Interface changes require updating the related docs.
