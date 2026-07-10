# Gate-Matching Standard

> The canonical specification for how AutoFlow PreToolUse hook gates match
> commands and order their checks. All AutoFlow hook scripts across the
> Consumer repos converge on this standard.

## Reference Implementation

The reference is the `udcim-monitoring` AutoFlow hook, which already
satisfies both rules below with no modification required.

- Repo: `udcim/udcim-monitoring`
- File: `.claude/hooks/check-autoflow-gate.sh`
- Pinned commit (last hook change): `b3c4d27aea5ea72c632e086448709713fb972418`
  (`feat(autoflow): 보강 PR 1차 — 상태 전이 책임 분담 + 산출물 무결성`, 2026-05-02)

Every gate-hardening PR in the other repos cites this commit as the pattern
source.

## Rule P1 — Boundary-Anchored Command Matching

Hook gates MUST NOT anchor command detection with a bare line-start `^`.
A `^git push` / `^gh pr create` pattern fails to match the most common
real command forms (`cd <dir> && git push`, `a && gh pr create`,
`ENV=v git push`), silently bypassing the gate.

Use a shared command-boundary prefix plus a word boundary on the command
token:

```sh
CMD_BOUNDARY='(^|[;&|]|&&|\|\|)[[:space:]]*'
# match examples (applied to SCAN, see below):
#   ${CMD_BOUNDARY}git[[:space:]]+push\b
#   ${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+create\b
#   ${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+merge\b

# SCAN = command with body text removed before matching:
#   1. drop from the first heredoc introducer (`<<`) onward
#   2. delete single/double-quoted substrings (inline --body "...")
SCAN=$(printf '%s' "${COMMAND%%<<*}" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
```

Backtick and `(` are deliberately **excluded** from the boundary set:
including them (to catch command substitution) made any body text quoting
a prohibited token false-positive, and command-substitution evasion
(`` `gh pr merge` ``) is explicitly out of this gate's threat model — the
gate prevents the agent from merging *as a normal action*, not a
determined adversary, who has unbounded other evasions anyway.

`CMD_BOUNDARY` matches the start of the command, or the position after a
shell separator (`;`, `&`, `|`, backtick, `(`, `&&`, `||`). The trailing
`\b` prevents prefix false-negatives. All gates in a hook share the single
`CMD_BOUNDARY` definition for consistency.

### Body-stripping refinement (applied)

The gate matches `SCAN`, not the raw command. `SCAN` removes the two
places body text lives — the heredoc body (everything from the first `<<`)
and quoted substrings (inline `--body "..."`) — *before* the boundary
match. A real chained command outside quotes (`... --body "x" && gh pr
merge 1`) is preserved and still denied; a body that merely *mentions* a
prohibited token no longer false-positives.

Discovery: the original pattern (boundary set including backtick/`(`,
matched against the whole command) false-positived on this PR's own
`gh pr create` heredoc and was confirmed against `git commit`/inline
`--body` bodies. The refinement above resolves all observed cases; the
regression matrix covers heredoc, inline `--body`, `git commit` body, and
the preserved-real-chain case.

**Residual (accepted, documented):** an *unquoted* multi-token body (rare,
usually invalid shell) or a command-substitution-wrapped prohibited token
is not stripped. This is intentional — it is adversarial evasion, outside
the gate's threat model (preventing routine agent merge/push, not a
hostile operator). No further refinement is planned unless a realistic
non-adversarial false-positive surfaces.

## Rule P2 — Unconditional Denies Precede the Activity Check

A hook has two classes of gate:

1. **Absolute prohibitions** — actions AutoFlow must never perform via the
   agent's tools regardless of state (e.g. `gh pr merge`, push to the
   default branch). These MUST be placed in an unconditional block that
   executes **before** any active-issue / state lookup, so that tearing
   down or deactivating the state file cannot nullify them.
2. **Conditional gates** — score- or phase-dependent checks (e.g. push only
   after AUDIT + GATE:QUALITY pass). These run **after** the activity check;
   being state-scoped is correct for them.

Placing an absolute prohibition after an `active != true → exit 0` guard
makes it state-gated: a terminal phase that sets `active:false` (or removes
the state file) silently disables the prohibition. The reference hook
avoids this by ordering its sections `1. Unconditional blocks` → then
`2. Activity check — bypass if no current-issue`.

Behavioural consequence (intended, not a regression): the agent's Bash
tool can never run `gh pr merge` or a default-branch push in a governed
repo, even outside an active flow. Merging is performed by humans /
external review through GitHub, not through the agent — consistent with
the HANDOFF terminal-phase model.

## Rule P3 — Declared-Role Spawn Classification

Hook gates MUST NOT classify an `Agent` spawn by prompt-keyword inference.
Keyword matching fails in both directions, and both failures were observed
in live cycles:

- **Over-block → evasion training**: benign spawns whose prompts mentioned
  `수정` / `design` / `create` were denied, then re-spawned with sanitized
  wording. The re-spawn succeeding proves the gate checked phrasing, not
  work — and each round taught the orchestrator vocabulary that later lets
  a genuinely gated spawn slip through.
- **Under-block**: a keyword-free implementation prompt was never matched
  to GATE:PLAN at all; a prompt containing an evaluation keyword was
  exempted from every score gate regardless of its actual task.

Instead, the spawn declares its role through a **structural channel** and
the hook owns the role→gate mapping:

| Channel | Declaration |
|---------|-------------|
| Direct spawn | `subagent_type` = `autoflow-analyzer` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator` (defined in `.claude/agents/`) |
| Team spawn | teammate `name` prefix: `analysis-`, `plan-`, `impl-` / `dev-`, `test-`, `eval-` |
| Research | built-in read-only types `Explore` / `Plan` / `claude-code-guide` |

**Channel precedence**: a team spawn (teammate `name` present) is declared by
the name prefix ALONE — `subagent_type` is not consulted. Otherwise a mixed
payload (`subagent_type:"Explore"` + `name:"impl-…"`) would resolve to
research and pass an implementation teammate through without GATE:PLAN
(PR #506 review, Medium). A team spawn whose name carries no role prefix is
undeclared → denied during an active cycle, even if `subagent_type` names a
research or `autoflow-*` type: a contradictory declaration is blocked, not
arbitrated.

Mapping (hook-owned — a spawn never selects its own gate): `planning` →
GATE:HYPOTHESIS (skip-verdict bypass for feat issues); `implementation` /
`testing` → GATE:PLAN; `analysis` / `evaluation` / research → pass
(evaluation must stay spawnable or the gate it scores deadlocks). An
**undeclared** spawn while a cycle is active is denied with a
self-describing message — a loud, auditable stop instead of a silent
misclassification. Outside an active cycle (no state file, or
`active:false`) undeclared spawns are not gated; on a malformed state only
research and evaluation roles are admitted (fail-closed).

The trust model matches the score gates: the AI *records* a fact (its
declared role), the hook *computes* the verdict. A false declaration is an
explicit, auditable act — unlike keyword omission, it leaves evidence.

## Verification Requirement

Each repo's gate-hardening change ships a regression matrix (modelled on
udcim `test-gate.sh`) that asserts BOTH directions:

- **Deny holds**: `cd x && git push`, `a && gh pr merge`, `git push origin
  <default>` are blocked; `gh pr merge` blocked even with no/inactive state.
- **No over-block**: a legitimate `git push -u origin dev/YYYY-MM-DD` and a
  non-merge `gh pr create` are allowed.

The legitimate-allow cases are mandatory — an over-broad pattern that
blocks the normal HANDOFF push is a release blocker.

## Per-Repo Status

| Repo | P1 | P2 | Action |
|------|----|----|--------|
| `udcim/udcim-monitoring` | satisfied | satisfied | reference — no change |
| `Munsik-Park/autoflow` | Gate 3/4 use `^` | Gate 5 below active guard | fix both |
| `ontology-platform` | lines 125/131 use `^` | N/A — no never-merge invariant (upstream merges by design) | fix P1 only |
