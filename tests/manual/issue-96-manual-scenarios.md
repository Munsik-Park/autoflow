# Issue #96 — Manual/Operator Verification Scenarios (Tier-3)

This discharges the single non-automated acceptance criterion of this cycle —
**`Permission-Ask-Prompts`** — per the disposition in
`.autoflow/issue-96-verification-design.md` > Testability assessment: "the
permission decision is made by the harness before the Bash tool executes; no
in-repo process observes it, and the file that determines it is gitignored
operator-owned state... a manual scenario with the reason stated is the
correct disposition."

---

## M1 — `Permission-Ask-Prompts`: invoking the wrapper raises an operator prompt

**Source AC:** `Permission-Ask-Prompts` (verification design, acceptance
criteria table) — layer three of the feature design (`.autoflow/issue-96-feature-design.md`
> §2 Control layers), the operator's own `.claude/settings*.json` permission
allow-list, is expected to raise an interactive approval prompt on
`scripts/issue/create-issue.sh` invocations, since the wrapper is
**deliberately never added to any shipped allow list** (feature design §8).

**Why not automated:** the permission decision is made by the Claude Code
harness *before* the Bash tool executes the command — no process inside this
repository observes or records that decision. The file that determines it,
`.claude/settings.local.json`, is gitignored operator-owned state
(`.gitignore:1`) and is not a composition contact point this design's
`T ∩ S` computation reaches (verification design > Composition oracle). What
automation *can* and does verify — that the wrapper's own invocation string
carries no hook-denied token and is not score-gated — is `Wrapper-Not-Self-Blocked`
in `tests/test-issue-96-issue-create-gate.sh`. Whether a live session's
permission layer actually pauses for approval is not.

**Steps (operator, in a live Claude Code session on this repository):**

1. Confirm the operator's own `.claude/settings.local.json` (or global
   `~/.claude/settings.json`) does **not** carry a broad allow entry that
   would match `scripts/issue/create-issue.sh` (e.g. `Bash(*)` or an entry
   naming `scripts/issue/*`) — `docs/issue-proposal.md` states this
   recommendation once the wrapper ships.
2. Author a draft proposal file at `.autoflow/issue-proposal-<slug>.md`
   following the grammar in `docs/issue-proposal.md` (once created by GREEN).
3. Ask the session to run
   `scripts/issue/create-issue.sh --draft .autoflow/issue-proposal-<slug>.md`.
4. **Expected**: the harness raises an interactive approval prompt naming the
   command before it executes — the agent cannot file the issue without a
   human confirming the invocation.
5. **Regression signal**: if the command runs without a prompt, the
   operator's allow-list has drifted to match the wrapper's path (e.g. a
   broad `scripts/*` or `scripts/issue/*` entry was added) — layer three is
   silently inert, and only layers one and two (the hook deny + the
   wrapper's own re-verification) are carrying the load, exactly as the
   feature design's stated limitation (§2) describes for this repository's
   own current settings.

**Repeat cadence:** whenever `.claude/settings.local.json` or the global
settings file changes, or when `docs/issue-proposal.md`'s recommended
allow-list guidance is revised.
