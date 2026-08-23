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

### Backgrounded-invocation refinement — `BG_SCAN` / `BG_PREFIX` / `BG_TAIL` (applied)

The backgrounded suite-run deny (issue #134,
`.claude/hooks/check-autoflow-gate.sh` Section 1) adds three named
primitives to P1's vocabulary. It is recorded here because P1 owns the
hook's command-matching rules and this deny introduces a new window rule,
a new scan buffer, and its own accepted residuals.

**`BG_SCAN` reads shell *logical* lines, not physical lines.** `grep -qE` is
line-oriented, so a buffer built from raw `COMMAND` text hands the matchers
physical lines — and a shell command is not a physical line. `BG_SCAN` is
therefore built by an ordered **three-stage** pipeline over `COMMAND`, and the
order of the stages is load-bearing:

```sh
BG_SCAN=$(_fold_continuations <<< "$COMMAND" \
  | _strip_heredoc_bodies \
  | sed -E "s/\"([^\";&|]*)\"|\"[^\"]*\"|'([^';&|]*)'|'[^']*'/\1\2/g")
[ -n "$COMMAND" ] && [ -z "$BG_SCAN" ] && BG_SCAN=$COMMAND
```

1. **`_fold_continuations` — logical-line folding.** Each bare trailing `\` and
   the newline after it become one space (chaining permitted); every other
   newline is preserved as a real command separator; a trailing CR is stripped
   before the continuation test, so the gate is never weaker on CRLF input. It
   is the *same* function the segment fold uses (global scope, one definition,
   as with `CMD_BOUNDARY` and `GIT_PUSH`), a pure `read`/`case` shell loop for
   the recorded BSD/GNU `sed` `N`-at-EOF reason, and **total** — content is
   never discarded. Without it `… run-suites.sh --all \`⏎`&` puts the
   invocation token and its terminating `&` on two physical lines and no
   surface matches.
2. **`_strip_heredoc_bodies` — remove bodies, keep the tail.** Each heredoc
   introducer token (`<<WORD`, `<<-WORD`, `<<"WORD"`, `<<'WORD'`) is deleted
   from its own line while the rest of that line — a trailing `&` included — is
   kept, and the body lines through the matching terminator are removed;
   processing then **continues**, so no line after a heredoc leaves the buffer.
   `<<<` is not an introducer (a here-string has no body): the scan steps over
   it and keeps looking on the same line. On an **unterminated** heredoc the
   body lines are buffered, not discarded, and emitted at end of input. This
   replaces the earlier truncate-at-`<<` shape, which stopped at the first
   introducer and so admitted a genuinely backgrounded run placed on any later
   line.
3. **the unquoting `sed`** — unchanged, and described next.

*Fold before the heredoc stage*: the introducer may itself sit on a continued
line (`… --all \`⏎`<<EOF &`), and under the truncating order the `&` was cut
away before any fold could join it. *Fold before unquoting*: a quoted span split
across a continuation regains quote parity on one line, so the separator-bounded
rule below applies to it as written. *Strip before unquoting*: a heredoc body is
arbitrary text and routinely carries an unbalanced apostrophe (`it's`), which
would corrupt the quote pairing for every real command line after it; the
reverse order buys nothing symmetric, because unquoting **keeps** the contents
of a separator-free span and `git commit -m "a << b"` still presents a bare `<<`
to the strip afterwards.

The **fail-closed** guard on the last line is the same invariant the segment
fold carries at `NOTE (C4)`: in a security gate an empty buffer fails **open**,
so a non-empty `COMMAND` that yields an empty buffer falls back to the raw
`COMMAND` — the only text guaranteed to be real content — never to a
partially-built buffer. `SCAN` and `_SEGMENTS` are untouched by all of this.

**`BG_SCAN` — when a deny may *unquote* a span instead of deleting it.**
The shared `SCAN` deletes quoted substrings whole, which erases the
commonest invocation spelling before any matcher runs:
`bash "$ROOT/scripts/test/run-suites.sh" --all &` reduces to `bash  --all &`.
`BG_SCAN` is a deny-local variant — `SCAN` and `_SEGMENTS` are untouched and
every existing gate keeps reading them — in which a quoted span carrying **no**
command separator is *unquoted* (quote characters dropped, content kept) while a
span whose own text carries `;` `&` or `|` is **deleted whole**, as `SCAN`
deletes it:

(the third stage of the pipeline above):

```sh
sed -E "s/\"([^\";&|]*)\"|\"[^\"]*\"|'([^';&|]*)'|'[^']*'/\1\2/g"
```

Unquoting is admissible only under **both** halves of the following condition,
and each half is load-bearing:

1. the deny's token test is **anchored at `CMD_BOUNDARY`**, so a
   separator-free mention inside an argument is preceded by a word, not by a
   command boundary, and cannot occupy a command position; **and**
2. the unquoting is **bounded to separator-free spans**, because `CMD_BOUNDARY`
   accepts the position after `;` `&` `|` — so once the quote characters are
   gone, a prose body supplies the boundary itself and the anchor stops
   discriminating. Half (1) alone is false in the case the next gate is
   likeliest to meet: a `git commit -m` / `gh pr comment --body` text that
   *describes* the prohibited form (`"deny: run it; bash …/run-suites.sh --all &
   is refused"`), which would deny under an unconditional quote strip.

The four alternatives are **ordered** so that each consumes a complete span —
the safe form is tried first at a span's opening quote, the deleting form
second. Two independent deleting substitutions followed by a blanket quote strip
lose quote parity across two spans (the deleting pattern opens on the *closing*
quote of the first span and closes on the *opening* quote of the second),
admitting the genuine backgrounded run
`bash "$ROOT/scripts/test/run-suites.sh" --all & echo "a; b"`. The `sed`
replacement is a back-reference, never a newline, so the literal-newline
constraint above does not apply to it; a non-participating group expands to the
empty string on BSD and GNU `sed -E` alike.

**`BG_PREFIX` and `BG_TAIL` are single composed patterns, not co-occurrences.**
Both are built on `RUN_SUITES`, the command-position invocation matcher
(`CMD_BOUNDARY` + a wrapper-word group + an optional interpreter + the path
token), and both are matched **once** over `BG_SCAN`:

```sh
BG_PREFIX="${CMD_BOUNDARY}${BG_WRAPPER}(nohup|setsid)[[:space:]]+${BG_WRAPPER}${BG_INTERP}([^[:space:];&|]*/)?run-suites\.sh"
BG_TAIL="${RUN_SUITES}"'([^;]*[^&;<>])?&([^&>]|$)'
```

They therefore fall on the *single-pattern* side of the segment-scoped
co-occurrence MUST above, and the failure mode that MUST exists to prevent is
structurally unavailable to them. `BG_PREFIX`'s wrapper word and path token are
adjacent within one command position. `BG_TAIL`'s invocation token and
backgrounding `&` are two parts of one pattern separated by a run of characters
the pattern itself constrains — and that constraint, `[^;]*`, **is** a segment
bound, expressed inside the regex instead of by pre-splitting the buffer. Note
that neither surface may use `_SEGMENTS`: segmentation is a fold over `SCAN` and
so cannot see a quoted invocation path either.

**The `BG_TAIL` window rule.** The window closes on `;` and on end-of-line —
the separators that start a *new* command — and stays **open** across `&&` and
`|`, because a pipeline or an AND-list containing the invocation is backgrounded
*as a whole* by a trailing `&`. Closing on those would produce false **admits**,
which is the opposite of the co-occurrence MUST's concern. The `&` must not be
preceded by `&` `;` `<` `>` (so `&&` and `2>&1` are not read as backgrounding)
nor followed by `&` or `>` (so `&&` and `&> log` are not), and the intervening
run is optional so the argument-less `bash …/run-suites.sh&` is caught. No `\n`
appears in any bracket expression: its meaning inside a bracket is not portable
across BSD and GNU, and it is unnecessary because the hook matches with
`grep -qE`, which is line-oriented.

**Accepted residuals** (all false *negatives*, per P1's preference for a
false negative over a realistic false positive):

- the `;` window — `bash …/run-suites.sh --all; echo done &` is admitted,
  correctly, since only the `echo` is backgrounded; the brace-group form
  `{ bash …/run-suites.sh --all; } &` does background the run and is admitted
  with it. The brace group sits with the subshell and command-substitution
  wrappers P1 already places outside the threat model;
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
accepted residual in the under-inclusive direction on this surface; it is
recorded rather than repaired because removing it means either parsing quotes
before stripping bodies (which the *strip before unquoting* argument above
rejects on the corruption ground) or narrowing the delimiter scan on shapes a
quoted mention can always re-create. Every other residual listed above sits in
the over-inclusive direction: multiple introducers on one line (`cat <<A <<B`)
leave B's token and body as ordinary text, an unterminated heredoc keeps its
body, and a body line ending in a bare `\` is folded into its terminator so the
body stays in the buffer.

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
| Research | built-in read-only types `Explore` / `Plan` / `claude-code-guide` |

`subagent_type` is the **sole** declaration channel. The team-spawn channel — a
role prefix on the teammate `name` (`analysis-`, `plan-`, `impl-` / `dev-`,
`test-`, `eval-`) — was removed jointly with the spawn-mode migration
(ADR-0017 Q3; pilot discharged by ADR-0021), because every role is now an
anonymous direct spawn and retaining the branch would have left an unreachable
path that still name-prefix-overrode `subagent_type`.

The `<plugin>:<agent>` prefix is accepted for the `autoflow-*` types only —
the built-in research types stay bare (no namespace), since Claude Code
built-ins are never plugin-namespaced and widening them would let a
`foo:Explore` value bypass an active-cycle gate as research.

**Obsolete-declaration disposition**: a payload still carrying a teammate `name`
is undeclared → denied during an active cycle, **even when `subagent_type` names
a research or `autoflow-*` type**. Resolving such a payload by its
`subagent_type` would silently admit a team-spawn attempt as a direct spawn and
hide the caller's mistake on a channel that no longer exists; the older rule that
a contradictory declaration is blocked rather than arbitrated (PR #506 review,
Medium) is preserved, now with the `name` side carrying no role at all.

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

The hook classifies the declaration channel only; it does not enforce spawn mode. A payload carrying a teammate `name` — an `eval-` prefixed one included — is no longer admitted by the mapping above: that channel is retired, so the payload is denied as undeclared, and [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase > Spawn mode by role lifetime now names the anonymous direct spawn as every role's only mode. Read this document as the floor (what is not denied) and the contract as the ceiling (what is permitted): narrowing the hook to the contract would deny a spawn shape that a corrupted-state repair path still needs, so the contract binds the caller and the hook stays permissive.

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
