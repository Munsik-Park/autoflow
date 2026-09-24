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

- **[MUST]** A role spawn runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- **Why (lifecycle contract):** the harness's background-task contract — *re-invoke the owning agent when the task completes* — holds only for an agent that has a future turn. A spawned subagent terminates with its final response, so any still-pending background process is **reaped at teardown**: its output is lost and no completion notification is ever delivered, stalling the orchestrator on a report that never arrives (issue #952 — 71-minute orchestrator deadlock, 2026-07-07). A background CPU-heavy process can also starve the agent's own foreground verification and distort the pass/fail verdict (issue #287). The background + completion-notification pattern is therefore **orchestrator-only** (the main loop is the sole actor with future turns).
- **[MUST] A foreground command ends on its own (issue #279).** Foreground-only moves the risk from a background task reaped at teardown to a foreground command that never returns: a spawn blocked in one looks to the orchestrator like a spawn still working, and nothing times it out (llmroute #594 — a CI-failure classifier's `kill $STRESS_PIDS 2>/dev/null; wait` held its spawn until the operator killed the processes by hand). This binds the same actors as the first bullet, in three forms:
  - **The session shell may not be bash.** The Bash tool's shell is initialized from the user's profile, and a stock macOS profile is zsh, whose expansion differs from bash's: an unquoted `$VAR` is not word-split (the incident's `kill` received its twelve PIDs as one argument and failed with `illegal pid`), an unmatched glob is an error (`no matches found`) instead of the literal word, and a word beginning with `=` is replaced by a command's path. A list — PIDs, file names, arguments — is held in an array and expanded quoted, `"${pids[@]}"`, which gives one word per element in bash and zsh alike; a glob meant as an argument is quoted (`--include='*.sh'`); a procedure written for bash runs under bash — `bash -c '…'`, or a file run with `bash <path>`.
  - **No bare `wait`.** `wait` with no operand blocks until every child of the shell has ended, so one child a failed cleanup left running blocks it for good. `wait "$pid"` names its process and is for a process that ends by itself; a process that must be stopped — a load generator, a server — is waited out by a bounded poll: `kill -0 "$pid"` against a counter, then `kill -KILL`, then a report of any PID that is still alive. The bound does not depend on `timeout`, which not every host carries (a stock macOS has none; `probe_run_bounded` in `scripts/preflight/check-review-backend.sh` falls back to a sleep+kill watchdog for the same reason).
  - **A cleanup command's stderr is kept.** The `kill` that stops the processes is what reports that the cleanup failed; `2>/dev/null` on it turns the failure into silence that a later wait then hangs on. Its exit status is read one PID at a time: a `kill` given several PIDs reports failure differently by shell — bash returns success when any one signal was sent, zsh returns failure when any one was not. Only a probe whose failure is the expected answer — `kill -0` asking whether a process is still alive — discards it.

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
- **Enforced at the tool boundary for suite runs (issue #134):** a backgrounded invocation of `scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the orchestrator included; the orchestrator-only background pattern above never extends to a suite run, whose result must stay keyed to the tree the claim is made about (`docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).
- **The orchestrator's side of the wait (issue #165):** the notification the orchestrator waits for arrives only between its tool calls, so the orchestrator waits by **ending its turn**, never by blocking on one task — the deprecated `TaskOutput` tool is refused by the PreToolUse hook state-independently, and a foreground `sleep` loop polling for a spawn's result is the same fault by other means (`CLAUDE.md` > Execution Principles > *Wait discipline*). A spawned agent is unaffected in what it may do: it runs foreground and returns; it is the orchestrator that must not sit in a block while that return is pending.

---

## Tree Quiesce (spawn-boundary form)

- **[MUST]** A spawned agent performs tracked-tree writes only inside its own spawn's lifetime, on
  the assignment its spawn prompt carries — there is no message channel through which new tree work
  can arrive mid-flight, and none through which a freeze could be delivered.
- **Why:** a test run's recorded command, log and summary line are evidence only for the tree the run
  executed over; a tracked-tree write landing from another spawn while a run is in flight moves the
  tree under it. The obligation sits with the orchestrator's spawn schedule: no tree-writing spawn is
  issued while another spawn's run is in flight.

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

**Message economy** (issue #136, discharged structurally by the spawn-mode migration). The #136
measurement priced every named-teammate message as a context re-write. With every role an anonymous
direct spawn there is no message channel left to economize: the assignment travels once in the spawn
prompt, the report travels once in the return value, and no ACK, HOLD/GO, or idle-notification turn
exists. The measurement itself is retained at `docs/records/adr/0017-teammate-removal-feasibility.md` >
Notes > C8.

**Facilitated deliberation phases** (ARCHITECT, VERIFY cause-branch): the orchestrator
never receives the round-by-round exchange. At **ARCHITECT** the Developer AI and the
Test AI are two persistent participants (anonymous direct spawns of `autoflow-planner`)
that the orchestrator wakes in alternation by agent ID; every turn and each report is
appended to `.autoflow/issue-{N}-architect-transcript.md` and the participant returns one
line, and a Record **`Workflow`** then writes the artifacts from that file (ADR-0023). At
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
| the same spawn **resumed by agent ID** (`SendMessage`, no `name`) — the ARCHITECT relay participants only (ADR-0023 D2) | a task notification of the resumed spawn, its final text verbatim in the `result` field | none — the final text is one line (`turn <n> — further: <yes|none>`); the turn body goes to the transcript file, never to the return |

**Why the named mode is still not used — cost and consistency, not delivery correctness.** A named spawn is a persistent, resumable teammate: the runtime launches any spawn carrying `name` as one, and a later `SendMessage` re-wakes it from its transcript. The grounds for keeping every role anonymous and direct are:

| Ground | Evidence | Standing |
|---|---|---|
| Wake cost — a persistent teammate re-writes context it had already read on every wake | ADR-0017 > Notes > C8 (issue #136): 16–43% of agent cost across two real cycles. Re-confirmed by the #168 probe below: a warm wake 57 s after the previous turn, inside the 5-minute cache TTL, re-wrote 25.6K of a 48.0K-token prefix (53%) — the wake message itself changes the prefix — and a cold wake 14 min 35 s later, past the TTL, re-wrote the whole 48.2K-token prefix (100%) | current |
| No offsetting benefit | ADR-0021 (C7 pilot): direct-spawn VERIFY step 3/4 detection `EQUAL_OR_BETTER` than the named baseline (sample of 3, fixture-based) | current |
| Consistency — one delivery path (the return value), one declaration channel (`subagent_type`) | ADR-0017 Q3; the gate hook keys the role→gate mapping on `subagent_type` alone and denies a `name`-carrying payload inside a cycle | design choice |

**Anonymous resume by agent ID, measured (Claude Code 2.1.261, 2026-09-05, issue #179 step 0).** Outside a cycle, one anonymous `general-purpose` spawn (Haiku 4.5, no `name`) was told to end with a nonce line and to call no tool; it was then resumed twice by `SendMessage` to its agent ID, each time with a new nonce (44 s and 55 s after the previous answer, under `subagentPromptCacheTtl: 1h`). All three times the final text **reached the orchestrator** as the task notification of that spawn, verbatim in its `result` field (3/3, no `SendMessage` from the spawn). Per-turn usage from the spawn's transcript (`message.usage`): turn 1 — cache write 44,593, cache read 0; wake 1 — cache read 44,593, cache write 190; wake 2 — cache read 44,783, cache write 159. On this path and under this TTL the wake re-wrote only the new message; the #168 re-write below was measured on the **named** path at the 5-minute TTL. This is the delivery precondition ADR-0023 D4 set for the relay's A2 realization, and it held.

**Delivery re-measured (Claude Code 2.1.260, 2026-09-04, issue #168).** Outside a cycle, one named spawn (`name: probe-168`, `general-purpose`, Haiku 4.5) was told to end with a nonce line and to call no tool and no `SendMessage`; it was then re-woken twice by `SendMessage`, each time with a new nonce — once inside the 5-minute cache TTL and once past it. All three times the final text **reached the lead**: it arrived as the teammate's `idle_notification` with the text verbatim in its `result` field, injected into the lead's conversation as a turn at the lead's next turn boundary (3/3, no `SendMessage` from the spawn). Per-turn usage from the spawn's transcript (`message.usage`, de-duplicated by `message.id`): turn 1 — cache write 47,691, cache read 0; turn 2 (warm wake, +57 s) — cache read 22,366, cache write 25,626; turn 3 (cold wake, +14 min 35 s) — cache read 0, cache write 48,216. Output was 197 tokens on turn 1 and a few tokens on each wake — the cost of a wake is the prefix, not the answer. Procedure: `tests/manual/issue-42-manual-scenarios.md` > M1, retrievable as `git show 8011c1d:tests/manual/issue-42-manual-scenarios.md` (the file was removed by issue #293).

The single mode applies to every role; the per-role table is [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase > Spawn mode by role lifetime.

---

## Discussion Protocol (Single Source of Truth)

The rules below govern every multi-AI discussion. They prevent groundless agreement
and force grounded judgement. The orchestrator's `CLAUDE.md` references this section
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
   Memory alone is not enough. Scope over a shared transcript (ADR-0023 D1): a fact
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
