# Gate-Matching Standard

> The canonical specification for how AutoFlow PreToolUse hook gates match
> commands and order their checks. Every AutoFlow hook script conforms to
> this standard.

## Rule P1 — Boundary-Anchored Command Matching

Hook gates MUST NOT anchor command detection with a bare line-start `^`.

P1's named primitives are the shared `CMD_BOUNDARY` prefix and the `SCAN`
buffer defined below, the `GIT_PUSH` token-interposition fragment, and the
global-scope normalisation function `_fold_continuations` (logical-line
folding).

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
#   ^[[:space:]]*${GIT_PUSH}                          # per-segment P2 deny
```

Define the fragment **once at global scope**, before the Bash guard; every
consumer — the P2 default-branch deny — references that one value.

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
`<autoflow-root>/hooks/check-autoflow-gate.sh`.

## Rule P2 — Every Deny Is Unconditional

A hook's denies are absolute prohibitions — actions AutoFlow must never
perform via the agent's tools (`gh pr merge`, a push to the remote default
branch, `gh issue create`, a ledger rewrite, a spawn without `model`). None reads a state: each holds in every session, in
every repository the plugin is installed in
([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D5).

Behavioural consequence: the agent's Bash
tool can never run `gh pr merge` or a default-branch push in a governed
repo. Merging is performed by humans /
external review through GitHub, not through the agent.

## Rule P3 — A Role Is Read From Structural Fields Only

Hook gates MUST NOT classify an `Agent` spawn by prompt-keyword inference. A
deny that reads a spawn reads a structural field of the `Agent` call: its own
`model`. The role an AutoFlow spawn fills is its `subagent_type`
(`<autoflow-root>/agents/`; under a plugin install `autoflow:autoflow-<role>`),
which the non-gating spawn-policy advisory reads. No deny maps a role to a
gate, denies an undeclared spawn, or depends on which session or sub-agent
makes a call.

**Decision-ledger integrity**, on a write into an `issue-*-ledger.md`:

- *Append-only.* A `Write` / `Edit` / `MultiEdit` is applied to the file on
  disk (a literal replacement portable to `/bin/bash` 3.2) and must keep the
  whole prior content as its prefix.

A shell write to a ledger and text that only imitates an entry are outside the
matched surface: the threat is routine overstepping, not a determined evasion.

The hook does not enforce how a role is spawned. Read this document as the floor (what is not denied) and the contract as the ceiling (what is permitted): the contract binds the caller and the hook stays permissive.

## Verification Requirement

Each repo's gate-hardening change ships a regression matrix that asserts BOTH
directions:

- **Deny holds**: `cd x && git push`, `a && gh pr merge`, `git push origin
  <default>` are blocked, in every session.
- **No over-block**: a legitimate `git push -u origin <work branch>` — a
  `dev-…` branch with a default branch named `dev` included — and a
  non-merge `gh pr create` are allowed.

The legitimate-allow cases are mandatory — an over-broad pattern that
blocks the delivery module's push is a release blocker.
