# ADR-0041: The SessionStart hook tells the operator of a requirement not met

## Status

Accepted (issue #553). Extends ADR-0028 D4: the hook that creates the user-level file also speaks at
a session start when the file exists. Replaces the statement of
[design-rationale.md](../design-rationale.md) Decision 34 that the minimum Claude Code version is not
an enforced check, as far as telling the operator goes; nothing denies or stops on it.

## Context

[`requirements.md`](../../requirements.md) names Claude Code v2.1.277+, `jq` and `gh`. No code compared
the version, no script looked for `gh`, and `jq` was looked for only by the scripts that use it, when
they run. So an operator without `jq` had a gate hook that lets a ledger write through unchecked
(`check-autoflow-gate.sh` Section 0) and no way to learn it when the session started. `plugin.json`
cannot declare any of this: its `dependencies` names plugins only.

## Decision

**D1 — The existing hook carries the notice.** `hooks/ensure-user-config.sh` runs the check before it
ends, whether or not the file exists, and prints one JSON object whose `systemMessage` holds what it
has to say. The Claude Code hooks reference makes stdout holding an output object and anything else a
parse failure, so the two messages are joined, not printed apart. A second `SessionStart` entry would
print separately, and it would leave the order of the two messages open.

**D2 — The check is `scripts/lib/prerequisites.sh`.** It holds the tools and the minimum version, and
`tests/plugin/verify-package.sh` AC6 fails when they differ from `requirements.md`. A script does not
parse the document: it is prose for people, and a rewording would turn the check off with no failure.

**D3 — The version is read from `claude --version` on `PATH`.** The SessionStart input carries no
version. `CLAUDE_CODE_EXECPATH` is not used: it is not documented, and a session started with it unset
did not have it in its hook's environment. So the check judges the `claude` on `PATH`, and the notice
names it with its path rather than calling it the running Claude Code. The read is limited to five
seconds, since a command hook's default timeout is 600 and a hung read would hold the session start:
the command gets SIGTERM at four seconds and SIGKILL at five, so one that ignores SIGTERM ends too.

**D4 — What cannot be read is not reported.** With no `claude` on `PATH`, or output that is not
`N.N.N (Claude Code)`, the check says nothing: it found no low version, and a notice at every session
start would name a state the operator may not be able to change. The gap this leaves is in the
Consequences.

**D5 — The notice repeats at every session start, of every source.** A missing requirement stays
missing, and the hook has no matcher because the file's creation needs none.

**D6 — A failure of the check does not stop the session or the file's creation.** Each part runs in its
own subshell, the hook exits 0 and a part that fails prints nothing. The existing `jq` checks of the
scripts and the gate hook's behaviour without `jq` are not changed.

## Consequences

- An operator on a route where `claude` is not on the hook's `PATH` gets no notice of a low version.
- When the `claude` on `PATH` and the running Claude Code are different installs, the judgment can be
  wrong both ways: a current Claude Code gets the notice because the one on `PATH` is old, and a Claude
  Code below the minimum gets none because the one on `PATH` is current. Issue #553's criterion that an
  operator of a Claude Code below the minimum is told is met only where the two are the same install.
- A process that SIGKILL does not end (uninterruptible sleep) still holds the read, since the check
  waits on it.
- `gh` and `jq` are found by presence only: `gh`'s authentication and the GitHub repository requirement
  are not checked, the second being each target's.
- A new requirement in `requirements.md` written with backticks fails AC6 until the check holds it too.
