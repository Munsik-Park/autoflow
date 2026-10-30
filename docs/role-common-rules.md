# Role Common Rules

> Shared rules that apply to every role spawn (the unit agents and their helpers) a module's run
> makes.

The session that runs a module spawns its roles; role spawns are launched as
Agents and execute the actual writing of code, tests, and documentation. The rules
below describe the contract every role spawn honours.

---

## Identity

- The role spawn understands, implements, and tests files within its assigned scope.
- The role spawn may **read** any file in the repository.
- The role spawn **may not modify** files outside the scope assigned by the dispatch
  instructions for the current issue.
- Push and PR creation are the delivery module's — the role spawn's git
  work finishes at `git commit` on its branch
  ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).

---

## Bash Execution Mode

- A role spawn runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, evaluator, advisor, the unit agents) **and** every helper a unit agent spawns. Run the command, wait for its result, then report.
- The background + completion-notification pattern is **the main session's only**.
- **A foreground command ends on its own.** This binds the same actors as the first bullet, in three forms:
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
- **Enforced at the tool boundary for suite runs:** a backgrounded invocation of `<autoflow-root>/scripts/test/run-suites.sh` — the `run_in_background` payload field, a `nohup`/`setsid` prefix, or a trailing `&` — is **refused** by the PreToolUse hook for every actor, the main session included; the main session's background pattern above never extends to a suite run (`<autoflow-root>/docs/gate-matching-standard.md` > Rule P1 > Backgrounded-invocation refinement).

---

## Communication

The session that runs a module spawns each role with `Agent`
(`subagent_type`, explicit `model`), and the spawn's return value is its report.

| Action | Method | Note |
|--------|--------|------|
| Receive instruction from the spawning session | the spawn prompt | delivered once, at spawn |
| Report to the spawning session | the spawn's return value | completion, escalation — body to the run's output directory, return where it is and what its reader needs to act on |
| Cross-cutting impact notice | in the returned report | the module states it in its output |

### Result delivery path by spawn mode

A spawn's report to its caller is its return value; what carries it is the harness's.

---

## Documentation Rules

- Code/policy: English.
- Documents an AI reads, and the base documents: English.
- An HTML review artifact: the language of the person who reads it.
- Interface changes require updating the related docs.
