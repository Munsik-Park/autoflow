# Gate-Matching Standard

> The canonical specification for how AutoFlow PreToolUse hook gates match
> commands and order their checks. Every AutoFlow hook script conforms to
> this standard.

## Rule P1 — Boundary-Anchored Command Matching

Hook gates MUST NOT anchor command detection with a bare line-start `^`.

P1's named primitives are the shared `CMD_BOUNDARY` prefix and the `SCAN`
buffer defined below, the `GIT_PUSH` token-interposition fragment, the two
global-scope normalisation functions `_fold_continuations` (logical-line
folding, shared with the segment fold) and `_strip_heredoc_bodies` (heredoc-body
removal, applied in that order), and — for the backgrounded suite-run deny — the
deny-local scan buffer `BG_SCAN` those two build, together with the two composed
patterns `BG_PREFIX` and `BG_TAIL` matched over it. Each is specified in its own
refinement subsection below.

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

Backtick and `(` are **excluded** from the boundary set, and
command-substitution evasion (`` `gh pr merge` ``) is explicitly out of this
gate's threat model — the gate prevents the agent from merging *as a normal
action*, not a determined adversary.

`CMD_BOUNDARY` matches the start of the command, or the position after a
shell separator (`;`, `&`, `|`, backtick, `(`, `&&`, `||`). All gates in a
hook share the single `CMD_BOUNDARY` definition.

### Body-stripping refinement

The gate matches `SCAN`, not the raw command. `SCAN` removes the two
places body text lives — the heredoc body (everything from the first `<<`)
and quoted substrings (inline `--body "..."`) — *before* the boundary
match. A real chained command outside quotes (`... --body "x" && gh pr
merge 1`) is preserved and still denied; a body that merely *mentions* a
prohibited token does not false-positive.

A regression matrix for body stripping covers heredoc, inline `--body`,
`git commit` body, and the preserved-real-chain case.

**Residual (accepted, documented):** an *unquoted* multi-token body or a
command-substitution-wrapped prohibited token is not stripped.

### Token-interposition refinement — `git` global options

`git` accepts global options **between the binary and the subcommand** —
`git -c protocol.version=2 push origin main`, `git -C <path> push …`.
Tolerate zero or more interposed value-bearing global options in the push
fragment:

```sh
# `-c key=value` / `-C <path>` may sit between `git` and `push`
GIT_PUSH='git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+push\b'
#   ${CMD_BOUNDARY}${GIT_PUSH}                       # Gate 3 (score-gated push)
#   ${CMD_BOUNDARY}(${GIT_PUSH}|gh …pr create)\b     # is_score_gated_surface
#   ^[[:space:]]*${GIT_PUSH}                          # per-segment P2 deny
```

Define the fragment **once at global scope** (before the Bash guard and
before `is_score_gated_surface`); every consumer — the P2 default-branch
deny, Gate 3, and `is_score_gated_surface` (also reached on the Agent
path) — references that one value.

**Scope (P1 threat model):** only `-c`/`-C` are matched; other global options
(`--no-pager`, `--git-dir=`, `--work-tree=`, …) interposed before `push`
are **accepted residual**. **Residual (accepted, documented):** a quoted `-c` value containing spaces
(`git -c 'a.b=c d' push …`) is collapsed by SCAN quote-stripping and slips.
Likewise a **`-c` alias indirection**
(`git -c alias.p=push p origin main`) defines a `push` alias and invokes it
under a different verb, so the literal `push` token never appears at the
subcommand position the `${GIT_PUSH}` fragment scans — **accepted residual**.
`gh` takes no such global-option interposition, and its fragment tolerates
none.

### Segment-scoped co-occurrence refinement

A gate whose deny condition is the **AND of two or more patterns** MUST
require the patterns to co-occur in the **same command segment**, not
merely anywhere in `SCAN`.

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
this is not the bare-`^` anti-pattern P1 prohibits. The sed replacement is a
POSIX **literal backslash-newline** (an escaped real newline), never the `\n`
escape.

Single-pattern gates are unaffected — they match `CMD_BOUNDARY` over the
whole `SCAN`. Reference: the default-branch push deny in
`.claude/hooks/check-autoflow-gate.sh`.

**Second consumer — the label-gate deny.** The
`blocked-by-(review|subrepo)` gate-label deny has two forms: the
`--remove-label blocked-by-(review|subrepo)` form is a **single pattern**
(unaffected, matched over the whole `SCAN`), while the `gh api … -X DELETE
…/labels/blocked-by-(review|subrepo)` REST form is an **AND** of the label
path and the `-X DELETE` method. That REST form must co-occur in **one
segment**. Both denies share the single `_SEGMENTS` split computed once from
`SCAN`.

### Backgrounded-invocation refinement — `BG_SCAN` / `BG_PREFIX` / `BG_TAIL`

The backgrounded suite-run deny (`.claude/hooks/check-autoflow-gate.sh`
Section 1) adds three named primitives to P1's vocabulary.

**`BG_SCAN` reads shell *logical* lines, not physical lines.** `BG_SCAN` is
built by an ordered **three-stage** pipeline over `COMMAND`:

```sh
BG_SCAN=$(_fold_continuations <<< "$COMMAND" \
  | _strip_heredoc_bodies \
  | sed -E "s/\"([^\";&|]*)\"|\"[^\"]*\"|'([^';&|]*)'|'[^']*'/\1\2/g")
[ -n "$COMMAND" ] && [ -z "$BG_SCAN" ] && BG_SCAN=$COMMAND
```

1. **`_fold_continuations` — logical-line folding.** Each bare trailing `\` and
   the newline after it become one space (chaining permitted); every other
   newline is preserved as a real command separator; a trailing CR is stripped
   before the continuation test. It is the *same* function the segment fold
   uses (global scope, one definition, as with `CMD_BOUNDARY` and `GIT_PUSH`),
   a pure `read`/`case` shell loop, and **total** — content is never
   discarded.
2. **`_strip_heredoc_bodies` — remove bodies, keep the tail.** Each heredoc
   introducer token (`<<WORD`, `<<-WORD`, `<<"WORD"`, `<<'WORD'`) is deleted
   from its own line while the rest of that line — a trailing `&` included — is
   kept, and the body lines through the matching terminator are removed;
   processing then **continues**, so no line after a heredoc leaves the buffer.
   `<<<` is not an introducer (a here-string has no body): the scan steps over
   it and keeps looking on the same line. On an **unterminated** heredoc the
   body lines are buffered, not discarded, and emitted at end of input.
3. **the unquoting `sed`** — described next.

The **fail-closed** guard on the last line is the same invariant the segment
fold carries at `NOTE (C4)`: a non-empty `COMMAND` that yields an empty buffer
falls back to the raw `COMMAND`, never to a partially-built buffer. `SCAN` and
`_SEGMENTS` are untouched by all of this.

**`BG_SCAN` — when a deny may *unquote* a span instead of deleting it.**
`BG_SCAN` is a deny-local variant — `SCAN` and `_SEGMENTS` are untouched — in
which a quoted span carrying **no**
command separator is *unquoted* (quote characters dropped, content kept) while a
span whose own text carries `;` `&` or `|` is **deleted whole**, as `SCAN`
deletes it:

(the third stage of the pipeline above):

```sh
sed -E "s/\"([^\";&|]*)\"|\"[^\"]*\"|'([^';&|]*)'|'[^']*'/\1\2/g"
```

Unquoting is admissible only under **both** halves of the following condition:

1. the deny's token test is **anchored at `CMD_BOUNDARY`**; **and**
2. the unquoting is **bounded to separator-free spans**.

The four alternatives are **ordered** — the safe form is tried first at a span's
opening quote, the deleting form second — and each consumes a complete span. The
`sed` replacement is a back-reference, never a newline, so the literal-newline
constraint above does not apply to it.

**`BG_PREFIX` and `BG_TAIL` are single composed patterns, not co-occurrences.**
Both are built on `RUN_SUITES`, the command-position invocation matcher
(`CMD_BOUNDARY` + a wrapper-word group + an optional interpreter + the path
token), and both are matched **once** over `BG_SCAN`:

```sh
BG_PREFIX="${CMD_BOUNDARY}${BG_WRAPPER}(nohup|setsid)[[:space:]]+${BG_WRAPPER}${BG_INTERP}([^[:space:];&|]*/)?run-suites\.sh"
BG_TAIL="${RUN_SUITES}"'([^;]*[^&;<>])?&([^&>]|$)'
```

They fall on the *single-pattern* side of the segment-scoped co-occurrence MUST
above. Neither surface may use `_SEGMENTS`.

**The `BG_TAIL` window rule.** The window closes on `;` and on end-of-line —
the separators that start a *new* command — and stays **open** across `&&` and
`|`. The `&` must not be preceded by `&` `;` `<` `>` nor followed by `&` or `>`,
and the intervening run is optional. No `\n` appears in any bracket expression.

**Accepted residuals** (all false *negatives*, per P1's preference for a
false negative over a realistic false positive):

- the `;` window — `bash …/run-suites.sh --all; echo done &` is admitted,
  correctly; the brace-group form `{ bash …/run-suites.sh --all; } &` does
  background the run and is admitted with it;
- an invocation reached through a wrapper word the group does not name, or
  through a shell variable holding the path;
- a quoted argument whose own text ends in a backgrounding-shaped `&` is
  deleted whole by the span bound, so it cannot be mis-read as backgrounding.

**The terminated-misread swallow — an accepted *under*-inclusive residual.**
Because `_strip_heredoc_bodies` runs while the buffer is still quoted, a literal
`<<` inside a quoted argument is read as an introducer. The totality clause
bounds that misreading in the common case: the body is never terminated, so the
following real command line is emitted and the deny still fires. It is **not**
bounded when a later line happens to equal the misread delimiter word exactly —

```
echo "<< EOF is a heredoc"
bash scripts/test/run-suites.sh --all &
EOF
```

— where the third line terminates the misread body and the invocation is
swallowed with it, so the form is **admitted** (exit 0). This is the one
accepted residual in the under-inclusive direction on this surface. Every other
residual listed above sits in the over-inclusive direction: multiple introducers on one line (`cat <<A <<B`)
leave B's token and body as ordinary text, an unterminated heredoc keeps its
body, and a body line ending in a bare `\` is folded into its terminator so the
body stays in the buffer.

## Rule P2 — Unconditional Denies Precede the Activity Check

A hook has two classes of gate:

1. **Absolute prohibitions** — actions AutoFlow must never perform via the
   agent's tools regardless of state (e.g. `gh pr merge`, push to the
   default branch, and — keyed on the tool name rather than a command
   token — the `TaskOutput` blocking wait). These MUST be placed in an unconditional block that
   executes **before** any active-issue / state lookup.
2. **Conditional gates** — score- or phase-dependent checks (e.g. push only
   after AUDIT + GATE:QUALITY pass). These run **after** the activity check.

A hook orders its sections `1. Unconditional blocks` → then
`2. Activity check — bypass if no current-issue`.

Behavioural consequence: the agent's Bash
tool can never run `gh pr merge` or a default-branch push in a governed
repo, even outside an active flow, and `TaskOutput` is never callable there
(the hook matcher must list `TaskOutput`). Merging is performed by humans /
external review through GitHub, not through the agent.

## Rule P3 — Declared-Role Spawn Classification

Hook gates MUST NOT classify an `Agent` spawn by prompt-keyword inference.

Instead, the spawn declares its role through a **structural channel** and
the hook owns the role→gate mapping:

| Channel | Declaration |
|---------|-------------|
| Direct spawn | `subagent_type` = `autoflow-analyzer` / `autoflow-loopcheck` / `autoflow-planner` / `autoflow-implementer` / `autoflow-tester` / `autoflow-evaluator` (defined in `.claude/agents/`) — under a plugin install these register as `autoflow:autoflow-analyzer` etc.; the hook matches both the bare and the `<plugin>:<agent>` form |
| Research | built-in read-only types `Explore` / `Plan` / `claude-code-guide` |

`subagent_type` is the **sole** declaration channel.

The `<plugin>:<agent>` prefix is accepted for the `autoflow-*` types only —
the built-in research types stay bare (no namespace).

**Teammate-`name` disposition**: a payload carrying a teammate `name`
is undeclared → denied during an active cycle, **even when `subagent_type` names
a research or `autoflow-*` type**. A contradictory declaration is blocked rather
than arbitrated, with the `name` side carrying no role at all.

Mapping (hook-owned — a spawn never selects its own gate): `planning` →
GATE:HYPOTHESIS (skip-verdict bypass for feat issues); `implementation` /
`testing` → GATE:PLAN; `analysis` / `evaluation` / research → pass. An
**undeclared** spawn while a cycle is active is denied with a
self-describing message. Outside an active cycle (no state file, or
`active:false`) undeclared spawns are not gated; on a malformed state only
research and evaluation roles are admitted (fail-closed).

The hook classifies the declaration channel only; it does not enforce spawn mode. A payload carrying a teammate `name` is not admitted by the mapping above: it is denied as undeclared, and [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase names the anonymous direct spawn as every role's only mode. Read this document as the floor (what is not denied) and the contract as the ceiling (what is permitted): the contract binds the caller and the hook stays permissive.

## Verification Requirement

Each repo's gate-hardening change ships a regression matrix that asserts BOTH
directions:

- **Deny holds**: `cd x && git push`, `a && gh pr merge`, `git push origin
  <default>` are blocked; `gh pr merge` blocked even with no/inactive state.
- **No over-block**: a legitimate `git push -u origin dev/YYYY-MM-DD` and a
  non-merge `gh pr create` are allowed.

The legitimate-allow cases are mandatory — an over-broad pattern that
blocks the normal HANDOFF push is a release blocker.
