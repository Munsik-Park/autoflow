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

### Token-interposition refinement — `git` global options (applied)

`git` accepts global options **between the binary and the subcommand** —
`git -c protocol.version=2 push origin main`, `git -C <path> push …`. A
gate fragment that assumes `git` and `push` are adjacent
(`git[[:space:]]+push`) is bypassed by this interposition: the push is not
detected and the deny/score-gate does not fire (issue #13, carried from
issue #3). Tolerate zero or more interposed value-bearing global options
in the push fragment:

```sh
# `-c key=value` / `-C <path>` may sit between `git` and `push`
GIT_PUSH='git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+push\b'
#   ${CMD_BOUNDARY}${GIT_PUSH}                       # Gate 3 (score-gated push)
#   ${CMD_BOUNDARY}(${GIT_PUSH}|gh …pr create)\b     # is_score_gated_surface
#   ^[[:space:]]*${GIT_PUSH}                          # per-segment P2 deny
```

Define the fragment **once at global scope** (before the Bash guard and
before `is_score_gated_surface`) so every consumer — the P2 default-branch
deny, Gate 3, and `is_score_gated_surface` (also reached on the Agent
path) — references one set value; a copy defined inside the Bash guard is
unset on the Agent path and the regex silently voids.

**Scope (P1 threat model):** the interposition tolerated is the `-c`/`-C`
form that arises in **normal** operation (protocol negotiation, work-tree
selection). Only `-c`/`-C` are matched; other global options
(`--no-pager`, `--git-dir=`, `--work-tree=`, …) interposed before `push`
are **accepted residual** — pushing those ahead of `push` is an evasion
construction, not a routine form, and generalizing to arbitrary flags
would miss separate-argument value forms (`-C <path>`) anyway. **Residual
(accepted, documented):** a quoted `-c` value containing spaces
(`git -c 'a.b=c d' push …`) is collapsed by SCAN quote-stripping and slips
— the same already-accepted quoted-value limitation as the Body-stripping
refinement. Likewise a **`-c` alias indirection**
(`git -c alias.p=push p origin main`) defines a `push` alias and invokes it
under a different verb, so the literal `push` token never appears at the
subcommand position the `${GIT_PUSH}` fragment scans — **accepted residual**
(pre-existing, not introduced by this refinement): resolving an alias to its
expansion is outside a token-regex gate's reach, and the construction is an
evasion form, not a routine one. `gh` takes no such global-option
interposition and is left unchanged (no over-generalization).

### Segment-scoped co-occurrence refinement (applied)

A gate whose deny condition is the **AND of two or more patterns** MUST
require the patterns to co-occur in the **same command segment**, not
merely anywhere in `SCAN`. Two independent greps over the whole buffer
false-positive on composite commands: in the post-merge cleanup batch
`git pull --ff-only origin main; git push origin --delete dev/x`, one
grep matches the `git push` in the delete sub-command and the other
matches `origin main` in the unrelated pull sub-command, and the AND
holds even though no sub-command pushes to the default branch (issue #3).

Split `SCAN` on the shell separators, then match per segment:

```sh
_segs=$(printf '%s' "$SCAN" | sed -E 's/(&&|\|\||[;&|])/\
/g')
while IFS= read -r _seg; do
  if printf '%s' "$_seg" | grep -qE "^[[:space:]]*git[[:space:]]+push\b" \
     && printf '%s' "$_seg" | grep -qE "<second pattern>"; then
    ...deny...
  fi
done <<< "$_segs"
```

Within a segment the command token is anchored with `^[[:space:]]*` —
this is not the bare-`^` anti-pattern P1 prohibits: after separator
splitting, segment-start *is* the command boundary, so the anchor is
equivalent to `CMD_BOUNDARY` applied to the unsplit buffer. The sed
replacement is a POSIX **literal backslash-newline** (an escaped real
newline), never the `\n` escape — `\n` in a replacement is undefined by
POSIX, and a sed emitting a literal `n` would collapse segmentation and
fail *open* in a security gate; the literal form is standard-guaranteed
on BSD and GNU sed alike.

Single-pattern gates are unaffected — `CMD_BOUNDARY` matching over the
whole `SCAN` remains correct for them, since one pattern has no
co-occurrence to mis-scope. Reference: the default-branch push deny in
`.claude/hooks/check-autoflow-gate.sh` (segment-scoped since issue #3).

**Second consumer — the label-gate deny (issue #13).** The
`blocked-by-(review|subrepo)` gate-label deny has two forms: the
`--remove-label blocked-by-(review|subrepo)` form is a **single pattern**
(unaffected, matched over the whole `SCAN`), while the `gh api … -X DELETE
…/labels/blocked-by-(review|subrepo)` REST form is an **AND** of the label
path and the `-X DELETE` method. That REST form must co-occur in **one
segment**, or an unrelated pair — a label GET in one sub-command and an
unrelated `curl -X DELETE …/other` in the next
(`gh api …/labels/blocked-by-review ; curl -X DELETE …/unrelated`) —
false-positives over the whole buffer. Both denies now share the single
`_SEGMENTS` split computed once from `SCAN`, so the fragile literal-newline
`sed` primitive has one source of truth rather than a per-deny copy that
could drift.

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
| Direct spawn | `subagent_type` = `autoflow-analyzer` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator` (defined in `.claude/agents/`) — under a plugin install these register as `autoflow:autoflow-analyzer` etc.; the hook matches both the bare and the `<plugin>:<agent>` form |
| Team spawn | teammate `name` prefix: `analysis-`, `plan-`, `impl-` / `dev-`, `test-`, `eval-` |
| Research | built-in read-only types `Explore` / `Plan` / `claude-code-guide` |

The `<plugin>:<agent>` prefix is accepted for the `autoflow-*` types only —
the built-in research types stay bare (no namespace), since Claude Code
built-ins are never plugin-namespaced and widening them would let a
`foo:Explore` value bypass an active-cycle gate as research.

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
