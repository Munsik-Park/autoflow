#!/bin/bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# AutoFlow Gate Check
# The policy denies (ADR-0038 D5; docs/core.md > Records and the hook). Each
# holds in every session and in every repository the plugin is installed in,
# and none reads a state: there is no state file, and no deny depends on which
# module runs or what an evaluation scored.
#
# Command matching follows docs/gate-matching-standard.md:
#   - P1: denies match with the shared CMD_BOUNDARY prefix + word boundary,
#         never a bare `^` (which `cd x && git push` would bypass).
#   - P2: every deny is unconditional.
#   - P3: who acts is read from structural fields only — the caller's
#         `agent_type` and an Agent call's own `model`, never prompt keywords.
#
# Denies:
#   - Bash(gh pr merge)             → DENIED (AutoFlow never merges)
#   - Bash(backgrounded run-suites.sh) → DENIED (foreground only)
#   - Bash(git push <default br>)   → DENIED: the remote default branch
#                                     (`origin/HEAD`, else `main`) — a push there
#                                     is a merge that skips the pull request and
#                                     its review
#   - Bash(gh issue create)         → DENIED; also the REST form (POST to the
#                                     issues collection). Filing goes through
#                                     scripts/issue/create-issue.sh, which
#                                     re-runs the duplicate search from a draft
#                                     (docs/issue-proposal.md)
#   - Agent (any spawn)             → explicit `model` parameter required
#                                     (docs/core.md > Spawn Model)
#   - Write/Edit/MultiEdit on a ledger → append-only (prior text kept); only
#                                     autoflow-advisor adds `advisor decision` /
#                                     A<n>; only the main session adds `operator
#                                     decision` / O<n>; the advisor adds no
#                                     O,F,E (Section 1e, ADR-0025 D7)
#   - (no jq) → the same denies, read from the raw input (Section 0)
#
# Advisory (never denies): an Agent spawn whose model is outside the spawn
# policy's admitted set for its subagent_type (Section 1d).

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
INPUT=$(cat)

# ── AutoFlow paths: helper lookup and the paths a message names ──
# The AutoFlow tree this hook belongs to is looked up from the plugin root first
# and then from this script's own location — never from the project dir, which
# is the target's tree. `$CLAUDE_PLUGIN_ROOT` is set in the hook environment; the
# relative candidate is for a direct invocation without it: the repository root
# is the plugin root, and this script sits at <root>/hooks/ (ADR-0027 D1).
_AF_HOOKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# af_resolve <rel> — the absolute path of <rel> in the AutoFlow tree, or nothing.
af_resolve() {
  local _root _abs
  for _root in "${CLAUDE_PLUGIN_ROOT:-}" "$_AF_HOOKDIR/.."; do
    [ -n "$_root" ] && [ -e "$_root/$1" ] || continue
    _abs="$(cd "$_root" 2>/dev/null && pwd)" || continue
    printf '%s/%s' "$_abs" "$1"
    return 0
  done
  return 0
}
# af_path <rel> — what a message names: the absolute path when the AutoFlow tree
# carries <rel>, otherwise <rel> as written.
af_path() {
  local _p
  _p="$(af_resolve "$1")"
  printf '%s' "${_p:-$1}"
}
# af_helper <rel> — a helper script to run: the AutoFlow tree's own copy, or
# nothing. A copy in the project dir is never run: the project is the target,
# and the hook treats the target's files as data (ADR-0027 D3).
af_helper() {
  local _p
  _p="$(af_resolve "$1")"
  if [ -n "$_p" ] && [ -f "$_p" ]; then printf '%s' "$_p"; fi
  return 0
}

# `git` may carry global options (-c key=value, -C <path>) between the binary
# and the subcommand: `git -c protocol.version=2 push origin main`. Match zero
# or more such option tokens so push detection is not bypassed (issue #13).
# Scope: -c/-C interposition that arises in NORMAL operation. Adversarial
# wrappers (subshell/backtick/command-substitution) stay out of P1's threat
# model and are NOT covered here (docs/gate-matching-standard.md > P1). Defined
# at global scope, before the Bash guard, so both consumers — the
# default-branch deny of Section 1 and its jq-free reading in Section 0 —
# reference one value.
GIT_PUSH='git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+push\b'

# ── The branch AutoFlow does not push to (P2; ADR-0038 D5) ──
# The remote default branch, as `origin/HEAD` names it, else `main`.
# PUSH_DENY_RE matches it as a whole branch name: the name ends where a
# character no branch name has there follows, so a default `dev` does not
# match `dev-…` (a `\b` there would).
DENY_BRANCH=$(git -C "$PROJECT_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DENY_BRANCH="${DENY_BRANCH:-main}"
PUSH_DENY_RE="($(printf '%s' "$DENY_BRANCH" | sed 's/[.+(){}|$]/\\&/g'))([^[:alnum:]_./-]|\$)"

# ── Section 0: no jq (issue #466) ──
# The input is JSON, read with jq. With no jq it cannot be read, and the first
# jq read below would end the hook under `set -e` with exit 127, which
# PreToolUse does not treat as a block. So this section runs first: the denies
# of Sections 1 and 1b are read from the raw input, over-inclusively — an
# escaped mention matches too, the fail-closed direction. Everything else
# passes.
if ! command -v jq >/dev/null 2>&1; then
  _raw_why=""
  if printf '%s' "$INPUT" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge\b'; then _raw_why="'gh pr merge' — AutoFlow does not merge"
  elif printf '%s' "$INPUT" | grep -qE 'gh[[:space:]]+issue[[:space:]]+create\b' \
       || { printf '%s' "$INPUT" | grep -qE 'repos/[^[:space:]"]+/issues([?#[:space:]"]|$)' && printf '%s' "$INPUT" | grep -qE 'POST\b'; }; then _raw_why="'gh issue create' — file through $(af_path scripts/issue/create-issue.sh)"
  elif printf '%s' "$INPUT" | grep -qE "${GIT_PUSH}.*(origin[[:space:]]+(HEAD:)?|:[[:space:]]*)${PUSH_DENY_RE}"; then _raw_why="a push to ${DENY_BRANCH}"
  elif printf '%s' "$INPUT" | grep -qE 'run-suites\.sh' && printf '%s' "$INPUT" | grep -qE '"run_in_background"[[:space:]]*:[[:space:]]*true|nohup|setsid|run-suites\.sh[^"]*&[^&]'; then _raw_why="a backgrounded run of run-suites.sh"
  elif printf '%s' "$INPUT" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"Agent"' && ! printf '%s' "$INPUT" | grep -qE '"model"[[:space:]]*:[[:space:]]*"[^"]+"'; then _raw_why="an Agent spawn without a 'model'"
  fi
  if [ -n "$_raw_why" ]; then
    echo "BLOCKED: jq is not installed, and this call reads as ${_raw_why} — a deny that holds in every session ($(af_path docs/core.md) > Records and the hook)." >&2
    exit 2
  fi
  exit 0
fi

# ── Hook target detection ──
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Shared command-boundary prefix (docs/gate-matching-standard.md > P1).
# Matches command start or the position after ; & | && || — so a gate is
# not bypassed by `cd x && git push` / `a && gh pr create`. Backtick / (
# are intentionally NOT boundary chars: command-substitution evasion is out
# of scope, and including them caused heredoc/body false-positives.
CMD_BOUNDARY='(^|[;&|]|&&|\|\|)[[:space:]]*'

# Scan target: the command with body text removed so a quoted/heredoc body
# that merely mentions a prohibited token does not false-positive, while a
# real chained command outside quotes is preserved (gate-matching-standard
# > Known Limitation refinement):
#   1. drop everything from the first heredoc introducer (`<<`) onward;
#   2. delete single- and double-quoted substrings (inline --body "...").
SCAN=$(printf '%s' "${COMMAND%%<<*}" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")


# ── Caller identity ──
# The hook input's `agent_type` names the sub-agent that made the call; the
# harness sets it on a sub-agent's calls and omits it on the main loop's (Claude
# Code CHANGELOG 2.1.69: "Added `agent_id` (for subagents) and `agent_type` …
# to hook events"). Section 1e (ledger authorship) reads it.
CALLER_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)


# ── _fold_continuations (issue #134 c2) ────────────────────────────────────
# Backslash-newline line-continuation fold, defined at GLOBAL SCOPE beside
# CMD_BOUNDARY / GIT_PUSH (and for the same reason: every consumer references
# ONE definition). Two consumers today — the _JOINED segment fold below and the
# backgrounded-suite-run deny's BG_SCAN pipeline.
#
# CONTRACT. Input: text on stdin. Output on stdout: the same text with each bare
# trailing `\` and the newline after it replaced by a single space (chaining
# permitted); every other newline preserved as a real command separator; a
# trailing `\` on the final line keeps its content with the `\` removed; a
# trailing CR stripped from each physical line before the continuation test.
# The output carries NO trailing newline (`printf '%s'`), so a caller using the
# sentinel idiom below reproduces the pre-extraction in-shell result BYTE FOR
# BYTE. TOTAL: content is never discarded, on any input shape or platform.
#
# IMPLEMENTATION (issue #13 AUDIT cycle 3, user-approved): the fold is a pure
# POSIX-shell while-read loop, NOT `sed`. Rationale: BSD and GNU `sed` diverge
# on `N` at the LAST line of the buffer when it ends in a trailing `\` (a
# continuation with no following line to append) — BSD `N` at EOF has no next
# line and DISCARDS the pattern space, so _JOINED went EMPTY and the whole
# segment-based deny failed OPEN. The cycle-2 `$s/\\$//` pre-strip covered only
# a trailing `\` already present on the LAST physical line; it did NOT cover the
# case where a mid-fold join RE-CREATED a trailing `\` on the new last line
# INSIDE the `N`/`ta` loop, re-triggering the same BSD N-at-EOF discard one
# iteration later on 2+-hop composite input (AC-2t). Rather than patch the sed
# program again, this removes the divergent primitive entirely. The loop reads
# physical lines in order; when a line ends in a bare trailing `\` it strips
# that `\` and joins the next line with a single space (chaining permitted); a
# final line whose `\` has no following line to append keeps its content with
# the `\` removed; a bare newline is preserved as a real separator. It is a
# TOTAL function — input/content is never discarded on any platform or input
# shape, so the BSD/GNU sed N-at-EOF divergence cannot participate.
#
# The loop reads its input from STDIN, so every caller drives it with the same
# `<<<` here-string / pipe idiom and no caller's variables are touched: the
# loop's own variables are function-local. It deliberately does NOT wrap the
# `case` in `$( … )` command substitution: macOS /bin/bash 3.2.57 mis-parses a
# `case` pattern's `)` inside `$( )` as the substitution's closing paren.
# Primitives used: `read` / `case` / `printf`-free string append / `${v%\\}`
# parameter expansion — POSIX sh; no external tool is invoked.
#
# Moving the loop into a function does NOT re-introduce the /bin/bash 3.2.57
# `case`-inside-`$( )` hazard noted above: the `case` is parsed once here, at
# function-definition time and at global scope, and no call site contains any
# `case` text of its own.
_fold_continuations() {
  local _fc_joined='' _fc_acc='' _fc_cont=0 _fc_first=1 _fc_line
  while IFS= read -r _fc_line || [ -n "$_fc_line" ]; do
    # CR normalization (issue #13 AUDIT cycle 4, user-approved): strip a trailing
    # CR from each physical line before the continuation check. `read` splits on
    # LF only, so a CRLF-style continuation (`\`+CR+LF) leaves the CR on the line
    # and `_fc_acc` ends in CR, not the literal `\` the `*\\)` case matches — the
    # fold misses and the composite command passes through unmerged (same bypass
    # class as AC-2t, via a CRLF line ending). By real shell semantics `\`+CR+LF
    # is NOT a line continuation (only `\`+LF is); this normalization is a
    # DELIBERATE over-block so the gate is never weaker on CRLF input than on LF.
    _fc_line="${_fc_line%$'\r'}"
    if [ "$_fc_cont" = 1 ]; then
      _fc_acc="$_fc_acc $_fc_line"     # join continuation with a single space
    else
      _fc_acc="$_fc_line"
    fi
    case "$_fc_acc" in
      *\\)
        _fc_acc="${_fc_acc%\\}"     # strip the bare trailing backslash; keep assembling
        _fc_cont=1
        ;;
      *)
        _fc_cont=0               # completed logical line — append, newline-separated
        if [ "$_fc_first" = 1 ]; then _fc_joined="$_fc_acc"; _fc_first=0
        else _fc_joined="$_fc_joined
$_fc_acc"; fi
        ;;
    esac
  done
  # Continuation `\` on the final line with no following line to append: content
  # is preserved (the backslash was already stripped), nothing is discarded.
  if [ "$_fc_cont" = 1 ]; then
    if [ "$_fc_first" = 1 ]; then _fc_joined="$_fc_acc"; else _fc_joined="$_fc_joined
$_fc_acc"; fi
  fi
  printf '%s' "$_fc_joined"
}

# ── _strip_heredoc_bodies (issue #134 c2) ──────────────────────────────────
# Heredoc-body remover, defined at GLOBAL SCOPE. Used by the backgrounded
# suite-run deny's BG_SCAN pipeline only; SCAN / _JOINED / _SEGMENTS do not
# read it.
#
# WHY IT DELETES-AND-CONTINUES RATHER THAN STOPPING. The earlier `${COMMAND%%<<*}`
# truncation stopped at the FIRST heredoc introducer, so every later logical line
# left the deny's buffer: a heredoc that writes a file followed by
# `bash …/run-suites.sh --all &` — or any earlier `grep -q x <<< "$V"` followed by
# the same invocation — admitted a genuinely backgrounded whole-tree run. That is
# the UNDER-inclusive direction, the harmful one for this gate. This function
# removes bodies and keeps reading to the end of the input instead.
#
# CONTRACT. Input: the folded text on stdin. Output on stdout, no trailing
# newline:
#   - each heredoc introducer token (`<<WORD`, `<<-WORD`, `<<"WORD"`, `<<'WORD'`)
#     is deleted FROM ITS OWN LINE and the remainder of that line — including a
#     trailing `&` — is kept;
#   - the body lines through the matching terminator are removed, and processing
#     continues: no line after a heredoc is lost;
#   - `<<<` is NOT an introducer (a here-string has no body), so the scan steps
#     over it and keeps looking on the same line;
#   - the terminator is a body line equal to the delimiter word exactly; under
#     `<<-`, leading tabs and spaces are stripped before the comparison, and the
#     delimiter's surrounding quotes are removed before matching.
#
# [MUST] TOTALITY ON AN UNTERMINATED HEREDOC. Body lines are BUFFERED, not
# discarded, until the terminator is seen; if the input ends with the body still
# open, the buffer is emitted. This is what makes a MISREAD introducer harmless:
# the strip runs while the buffer is still quoted (stage order — see the BG_SCAN
# call site), so a literal `<<` inside a quoted argument reads as an introducer.
# Under the stopping shape that misreading dropped every later line; under this
# clause it costs only the delimiter-shaped word on that one line, and the
# following real command line is buffered, never terminated, and emitted.
#
# Pure POSIX shell (`read` / `case` / parameter expansion), NOT `sed`, for the
# reason recorded on _fold_continuations above: matching a heredoc body needs a
# delimiter carried across lines, which in `sed` means `N`/hold space — the exact
# primitive class this file removed after the BSD/GNU divergence. Net effect on
# BG_SCAN: one `sed` stage is REMOVED and none added.
#
# Accepted residuals, all OVER-inclusive (content retained, so the deny can only
# fire more, never less): multiple introducers on one line (`cat <<A <<B`) — only
# the first is stripped; an unterminated heredoc keeps its body; a body line
# ending in a bare `\` is folded into the following line before the strip sees it,
# so such a body merges with its terminator and stays in the buffer.
#
# _shb_ltrim: shared leading-space/tab stripper, used both on a candidate
# terminator line (under `<<-`) and on a parsed delimiter token — the same
# trim rule applied at two points in the scan below.
_shb_ltrim() {
  local _v="$1"
  while :; do
    case "$_v" in
      ' '*|$'\t'*) _v="${_v#?}" ;;
      *) break ;;
    esac
  done
  printf '%s' "$_v"
}
_strip_heredoc_bodies() {
  local _shb_all='' _shb_first=1 _shb_buf='' _shb_bufn=0
  local _shb_in=0 _shb_delim='' _shb_dash=0
  local _shb_line _shb_rest _shb_keep _shb_before _shb_after _shb_orig
  local _shb_tok _shb_t _shb_c _shb_cmp
  while IFS= read -r _shb_line || [ -n "$_shb_line" ]; do
    if [ "$_shb_in" = 1 ]; then
      _shb_cmp="$_shb_line"
      if [ "$_shb_dash" = 1 ]; then
        _shb_cmp=$(_shb_ltrim "$_shb_cmp")
      fi
      if [ "$_shb_cmp" = "$_shb_delim" ]; then
        _shb_in=0; _shb_buf=''; _shb_bufn=0    # terminator: body dropped, keep reading
      elif [ "$_shb_bufn" = 0 ]; then
        _shb_buf="$_shb_line"; _shb_bufn=1     # buffered, not discarded (totality)
      else
        _shb_buf="$_shb_buf
$_shb_line"
      fi
      continue
    fi
    _shb_rest="$_shb_line"
    _shb_keep=''
    while :; do
      case "$_shb_rest" in
        *'<<'*) : ;;
        *) _shb_keep="$_shb_keep$_shb_rest"; break ;;
      esac
      _shb_before="${_shb_rest%%<<*}"
      _shb_orig="${_shb_rest#*<<}"
      case "$_shb_orig" in
        '<'*)
          # `<<<` — a here-string, not an introducer: step over it, keep looking.
          _shb_keep="$_shb_keep$_shb_before<<<"
          _shb_rest="${_shb_orig#?}"
          continue
          ;;
      esac
      _shb_tok="$_shb_orig"
      _shb_dash=0
      case "$_shb_tok" in -*) _shb_dash=1; _shb_tok="${_shb_tok#-}" ;; esac
      _shb_tok=$(_shb_ltrim "$_shb_tok")
      _shb_delim=''; _shb_after=''
      case "$_shb_tok" in
        '"'*)
          _shb_t="${_shb_tok#\"}"
          case "$_shb_t" in
            *'"'*) _shb_delim="${_shb_t%%\"*}"; _shb_after="${_shb_t#*\"}" ;;
          esac
          ;;
        "'"*)
          _shb_t="${_shb_tok#\'}"
          case "$_shb_t" in
            *"'"*) _shb_delim="${_shb_t%%\'*}"; _shb_after="${_shb_t#*\'}" ;;
          esac
          ;;
        *)
          _shb_after="$_shb_tok"
          while [ -n "$_shb_after" ]; do
            _shb_c="${_shb_after:0:1}"
            case "$_shb_c" in
              ' '|$'\t'|';'|'&'|'|'|'<'|'>'|'('|')') break ;;
            esac
            _shb_delim="$_shb_delim$_shb_c"
            _shb_after="${_shb_after#?}"
          done
          ;;
      esac
      if [ -z "$_shb_delim" ]; then
        # No delimiter word (`<<` at end of line, before a metachar, or an
        # unclosed quote): no body can be matched, so keep the text as ordinary
        # content — the over-inclusive direction — and keep looking on this line.
        _shb_keep="$_shb_keep$_shb_before<<"
        _shb_rest="$_shb_orig"
        continue
      fi
      # Real introducer: drop the token, keep the rest of the line, open the body.
      _shb_keep="$_shb_keep$_shb_before$_shb_after"
      _shb_in=1; _shb_buf=''; _shb_bufn=0
      break
    done
    if [ "$_shb_first" = 1 ]; then _shb_all="$_shb_keep"; _shb_first=0
    else _shb_all="$_shb_all
$_shb_keep"; fi
  done
  # Unterminated heredoc at end of input: emit the buffer (totality clause).
  if [ "$_shb_in" = 1 ] && [ "$_shb_bufn" = 1 ]; then
    if [ "$_shb_first" = 1 ]; then _shb_all="$_shb_buf"
    else _shb_all="$_shb_all
$_shb_buf"; fi
  fi
  printf '%s' "$_shb_all"
}

# ── Section 1: Unconditional blocks (P2) ──
# AutoFlow never merges and never pushes to the default branch through the
# agent's tools, in every session. Merging is performed by external review.

if [ "$TOOL_NAME" = "Bash" ]; then
  # Shell-separator segment split shared by the co-occurrence denies below
  # (issue-creation REST form, default-branch push). Computed once from SCAN.
  # NOTE (C3): fold backslash-newline line-continuations into ONE logical line
  # BEFORE the separator split. A `\`<newline> continuation is a single logical
  # shell command, but it leaves a literal newline in SCAN, so the per-segment
  # `while read` loops below (which read one physical line at a time) would split
  # that one command into several segments and let a same-segment co-occurrence
  # AND fail OPEN in a security gate (issue #13 AUDIT regression). A bare newline
  # (a physical line NOT ending in `\`) is a real command separator and is
  # deliberately left intact (over-block guard).
  # The fold itself is _fold_continuations (global scope, above); this call site
  # keeps the C4 guard below. SENTINEL IDIOM: command substitution strips trailing
  # newlines, and the fold's output legitimately ends in one when the last logical
  # line is empty — a shape the in-shell loop preserved. Appending `X` inside the
  # substitution and removing it after keeps _JOINED BYTE-IDENTICAL to what the
  # inlined loop produced, so _SEGMENTS and every gate reading it are unmoved.
  _JOINED=$(_fold_continuations <<< "$SCAN"; printf X); _JOINED="${_JOINED%X}"
  # NOTE (C4): fail-closed assertion (defense-in-depth). The while-read fold above
  # is a total function, so a non-empty SCAN always yields a non-empty _JOINED and
  # this guard is not reachable in normal operation. It is retained deliberately:
  # in a security gate an explicit fail-closed invariant is worth its zero cost —
  # should a future refactor reintroduce a path that empties a non-empty SCAN,
  # fall back to the raw SCAN so the segment scan runs against real content and
  # the deny fires, never against an empty buffer that would fail OPEN.
  [ -n "$SCAN" ] && [ -z "$_JOINED" ] && _JOINED=$SCAN
  # NOTE (C2): the replacement is a POSIX literal backslash-newline (an escaped
  # real newline), NOT the `\n` escape — `\n`-in-replacement is undefined by
  # POSIX and a sed that emits literal `n` would collapse segmentation and let a
  # co-occurrence deny fail OPEN in a security gate. The literal form is
  # standard-guaranteed on BSD (macOS operator) and GNU (CI) sed alike.
  _SEGMENTS=$(printf '%s' "$_JOINED" | sed -E 's/(&&|\|\||[;&|])/\
/g')

  if printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+merge\b"; then
    echo "BLOCKED: AutoFlow does not merge — 'gh pr merge' is denied ($(af_path docs/core.md) > Push and PR creation)." >&2
    echo "Merging, issue close, and deployment are owned by an external review process." >&2
    exit 2
  fi

  # ── Backgrounded suite-run deny (issue #134; state-independent — P2) ──
  # A suite run's result is evidence only if the tree stood still under it, and a
  # backgrounded run outlives the turn that started it. The foreground obligation was prose only
  # (docs/role-common-rules.md > Bash Execution Mode); it moves to the tool
  # boundary here. Three surfaces, all reading BG_SCAN (below):
  #   (a) payload   — .tool_input.run_in_background is true AND the command carries
  #                   a run-suites.sh invocation token;
  #   (b) prefix    — BG_PREFIX: a mandatory nohup/setsid wrapper word at the
  #                   command position of the invocation;
  #   (c) trailing& — BG_TAIL: the command containing the invocation is terminated
  #                   by a backgrounding `&` (one `&`, not `&&`, not `&>`, not `2>&1`).
  # Residual over-block, accepted: a PreToolUse hook has no actor or phase
  # knowledge, so the operator's own backgrounded sweep is refused too — the remedy
  # is to run the same command in the foreground. Residual escapes, accepted: a
  # wrapper word outside the group below, a shell variable holding the path, and
  # the `{ …; } &` brace-group form (out of P1's threat model, as above).
  #
  # BG_SCAN / RUN_SUITES / BG_PREFIX / BG_TAIL — rationale (the unquote-vs-delete
  # split, the ordered-alternative argument, the token-interposition shape shared
  # with GIT_PUSH, and the BG_TAIL window rule) is documented once, in full, at
  # docs/gate-matching-standard.md > "Backgrounded-invocation refinement —
  # BG_SCAN / BG_PREFIX / BG_TAIL (applied)"; this deny's OWN scan buffer — SCAN
  # and _SEGMENTS are untouched.
  # BG_SCAN — an ordered THREE-STAGE pipeline over COMMAND (issue #134 c2), with a
  # fail-closed guard. Stage order is load-bearing and each boundary is argued:
  #   1. _fold_continuations — a `\`<newline> continuation is ONE logical shell
  #      command, but `grep -qE` is line-oriented, so `… run-suites.sh --all \`⏎`&`
  #      put the invocation token and its terminating `&` on two physical lines and
  #      no surface matched. Folding FIRST also makes an introducer sitting on a
  #      continued line (`… --all \`⏎`<<EOF &`) visible to stage 2, and restores
  #      quote parity for stage 3 on a quoted span split across a continuation.
  #   2. _strip_heredoc_bodies — remove heredoc BODIES, keep every later line
  #      (see the function's own WHY block). Runs BEFORE unquoting because a body
  #      is arbitrary text and routinely carries an unbalanced apostrophe (`it's`),
  #      which would corrupt stage 3's quote pairing for every real command line
  #      after it. The reverse order buys nothing symmetric: unquoting KEEPS the
  #      contents of a separator-free quoted span, so `git commit -m "a << b"`
  #      still presents a bare `<<` to the strip. That misread is not avoided by
  #      reordering — it is made harmless by the strip's totality clause.
  #   3. the unquoting sed — unchanged from cycle 1.
  BG_SCAN=$(_fold_continuations <<< "$COMMAND" \
    | _strip_heredoc_bodies \
    | sed -E "s/\"([^\";&|]*)\"|\"[^\"]*\"|'([^';&|]*)'|'[^']*'/\1\2/g")
  # NOTE (bg-fail-closed): the same invariant as C4 above, stated here rather than
  # left to inference. In a security gate an empty buffer fails OPEN, and this
  # cycle grows BG_SCAN from one parameter expansion plus one sed into a
  # two-function, one-sed substitution read by ALL THREE deny surfaces — so the
  # surface on which an empty result could arise widens rather than narrows. The
  # fallback is the RAW COMMAND, not a partially-built buffer: it is the only text
  # guaranteed to be real content.
  [ -n "$COMMAND" ] && [ -z "$BG_SCAN" ] && BG_SCAN=$COMMAND
  BG_WRAPPER='(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|nohup|setsid|env|time|command)[[:space:]]+)*'
  BG_INTERP='((sh|bash|zsh|dash|ksh)([[:space:]]+-[^[:space:]]+)*[[:space:]]+)?'
  RUN_SUITES_TAIL="${BG_INTERP}([^[:space:];&|]*/)?run-suites\.sh"
  RUN_SUITES="${CMD_BOUNDARY}${BG_WRAPPER}${RUN_SUITES_TAIL}"
  # BG_PREFIX — RUN_SUITES_TAIL with the wrapper word made MANDATORY; BG_WRAPPER
  # appears on both sides of it so `env FOO=1 nohup bash …` and `nohup setsid
  # bash …` match too.
  BG_PREFIX="${CMD_BOUNDARY}${BG_WRAPPER}(nohup|setsid)[[:space:]]+${BG_WRAPPER}${RUN_SUITES_TAIL}"
  BG_TAIL="${RUN_SUITES}"'([^;]*[^&;<>])?&([^&>]|$)'
  RUN_IN_BACKGROUND=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // empty' 2>/dev/null)
  _bg_deny=0
  if [ "$RUN_IN_BACKGROUND" = "true" ] && printf '%s' "$BG_SCAN" | grep -qE "$RUN_SUITES"; then
    _bg_deny=1
  elif printf '%s' "$BG_SCAN" | grep -qE "$BG_PREFIX|$BG_TAIL"; then
    _bg_deny=1
  fi
  if [ "$_bg_deny" = 1 ]; then
    echo "BLOCKED: a backgrounded run of $(af_path scripts/test/run-suites.sh) is denied — run it in the foreground ($(af_path docs/role-common-rules.md) > Bash Execution Mode)." >&2
    echo "A backgrounded suite run outlives the turn that started it, so its result cannot be keyed to the capture-point tree and starves the foreground verification it is meant to certify." >&2
    exit 2
  fi

  # AI-initiated issue creation is denied at the tool boundary (issue #96). The
  # obligation to review before filing was prose only, so an agent could assert
  # it had checked for duplicates and file anyway — the assertion and the act
  # had no mechanical relation. Filing now goes through
  # scripts/issue/create-issue.sh, which derives the issue from a draft in the
  # repository's draft directory under the record root (`autoflow-records
  # drafts`) and RE-RUNS the duplicate search itself. That wrapper carries no
  # `gh issue create` token in its own invocation string, so this deny does not
  # block it; the operator's permission prompt on the wrapper is layer three.
  # Unconditional (P2), like every Section-1 deny.
  #
  # Two surfaces, both segment-scoped so an adjacent sub-command cannot be
  # mistaken for this one:
  #   (A) the `gh issue create` subcommand, anchored at a segment start so
  #       `gh issue list --search create` (the read-only lookup an agent runs
  #       BEFORE filing, which must stay available) is untouched;
  #   (B) the REST form — a POST whose path ENDS at the issues collection.
  #       Requiring the path to end there keeps `…/issues/12/comments --method
  #       POST` (commenting on an existing issue) out of the deny, which
  #       creates nothing.
  #       A path component ends at a query delimiter `?`, a fragment delimiter
  #       `#`, whitespace, or the segment end — all four are terminators here.
  #       `/` is deliberately excluded: it continues the path into the
  #       sub-resource forms this deny exists to leave alone.
  _issue_create_deny=0
  while IFS= read -r _ic_seg; do
    if printf '%s' "$_ic_seg" | grep -qE "^[[:space:]]*gh[[:space:]]+issue[[:space:]]+create\b"; then
      _issue_create_deny=1; break
    fi
    if printf '%s' "$_ic_seg" | grep -qE "repos/[^[:space:]]+/issues([?#[:space:]]|$)" \
       && printf '%s' "$_ic_seg" | grep -qE "(-X[[:space:]]*|--method[[:space:]=]+)POST\b"; then
      _issue_create_deny=1; break
    fi
  done <<< "$_SEGMENTS"
  if [ "$_issue_create_deny" = 1 ]; then
    echo "BLOCKED: AutoFlow does not file issues directly — 'gh issue create' (and its REST form) is denied ($(af_path docs/issue-proposal.md))." >&2
    echo "Write a draft to \"\$(autoflow-records drafts)/<name>.md\" per $(af_path docs/issue-proposal.md), then run: $(af_path scripts/issue/create-issue.sh) --draft \"\$(autoflow-records drafts)/<name>.md\"" >&2
    echo "The wrapper re-runs the duplicate search from the draft's own title, so the check cannot be satisfied by asserting it was done." >&2
    exit 2
  fi

  # Segment-scoped default-branch-push deny (issue #3): the "git push" and the
  # "target is the default branch" patterns must co-occur in ONE command segment,
  # not merely somewhere in the multi-line scan buffer. Splitting on the shell
  # command separators turns each separator into a newline so the per-segment
  # loop treats one command at a time — a composite cleanup command whose only
  # push is a delete-refspec to a non-default branch no longer AND-matches an
  # unrelated `… origin <default>` sub-command.
  # Reuses the shared $_SEGMENTS split (computed once above) so the fragile
  # segmentation primitive has a single source — see the _SEGMENTS NOTE (C2) for
  # the sed literal-newline rationale. The interposition-tolerant $GIT_PUSH
  # fragment lets `git -c k=v push origin <default>` still match (issue #13).
  while IFS= read -r _bp_seg; do
    if printf '%s' "$_bp_seg" | grep -qE "^[[:space:]]*${GIT_PUSH}" \
       && printf '%s' "$_bp_seg" | grep -qE "(\borigin[[:space:]]+(HEAD:)?|:[[:space:]]*)${PUSH_DENY_RE}"; then
      echo "BLOCKED: AutoFlow does not push to ${DENY_BRANCH}, the remote default branch — push the work branch and open a pull request ($(af_path docs/core.md) > Push and PR creation)." >&2
      exit 2
    fi
  done <<< "$_SEGMENTS"
fi

# ── Section 1b: Agent spawn must declare an explicit model (P2) ──
# docs/core.md > Spawn Model [MUST]: every Agent spawn (any subagent_type)
# declares the `model` parameter explicitly. An omitted model silently
# inherits the HOST SESSION model, bypassing the per-phase model policy — and
# bills at whatever tier the host runs (2x the policy model when the host is on
# a premium tier). No spawn is exempt, research (Explore/Plan) and evaluation
# included: the spawn policy .claude/autoflow/spawn-policy.json models some of
# these types, and a type it does not model still declares (Section 1d).
# Presence-only check: the Agent tool's own enum validates the value.
if [ "$TOOL_NAME" = "Agent" ]; then
  AGENT_MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)
  if [ -z "$AGENT_MODEL" ]; then
    echo "BLOCKED: Agent spawn without an explicit 'model' parameter ($(af_path docs/core.md) > Spawn Model)." >&2
    echo "Declare the phase-policy model on every spawn (e.g. model: \"sonnet\" / \"opus\") — omitting it inherits the host session model and bypasses the per-phase policy." >&2
    exit 2
  fi
fi

# ── Section 1e: decision-ledger integrity (P2; ADR-0025 D7) ──
# The ledger carries two authorities at a decision point — the advisor's first
# judgment and the operator's override — and each is worth only its writer and
# its record staying as written. On a Write / Edit / MultiEdit of an
# issue-*-ledger.md:
#   1. Append-only: the write is applied to the file on disk here, and the
#      result must keep the whole prior content as its prefix — an entry is
#      never rewritten or removed; a decision changes by a new entry that names
#      the one it replaces (docs/decision-ledger.md).
#   2. Authorship of the added text: an `advisor decision` authority or an
#      `A<n>` heading only from the advisor (caller agent_type
#      autoflow-advisor); an `operator decision` authority or an `O<n>` heading
#      only from the main session (no caller agent_type); the advisor adds no
#      O / F / E heading.
# The threat is an agent overstepping in routine work, not a determined evasion
# (docs/role-contracts.md > Advisor > Independence): shell writes and malformed
# text are outside this check.
is_advisor_type() {
  case "$1" in autoflow-advisor|*:autoflow-advisor) return 0 ;; esac
  return 1
}
ledger_deny() {
  echo "BLOCKED: decision ledger — $1 (ADR-0025 D7; $(af_path docs/role-contracts.md) > Advisor > Independence; $(af_path docs/decision-ledger.md))." >&2
  echo "The ledger is append-only: add a new entry that names the entry it supersedes or overrides. The advisor writes A entries only; O entries and the operator's authority are the main session's." >&2
  exit 2
}
# _ledger_has <adv|opr|nonadv>: stdin text; true when a line carries the mark.
_ledger_has() {
  local _re
  case "$1" in
    adv)    _re='^- Authority: advisor decision|^## A[0-9]+ ' ;;
    opr)    _re='^- Authority: operator decision|^## O[0-9]+ ' ;;
    nonadv) _re='^- Authority: operator decision|^## [OFE][0-9]+ ' ;;
  esac
  grep -qE -- "$_re"
}
# _lit_replace <text> <old> <new> <all>: literal replacement, portable to
# /bin/bash 3.2 (whose ${v/"$o"/"$n"} keeps the quotes of the replacement).
_lit_replace() {
  local _t=$1 _o=$2 _n=$3 _out=''
  while [[ "$_t" == *"$_o"* ]]; do
    _out="$_out${_t%%"$_o"*}$_n"
    _t="${_t#*"$_o"}"
    [ "$4" = true ] || break
  done
  printf '%s' "$_out$_t"
}
case "$TOOL_NAME" in
  Write|Edit|MultiEdit)
    _lp=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
    if [[ "$_lp" =~ (^|/)issue-[0-9]+-ledger\.md$ ]]; then
      _cur=""
      if [ -f "$_lp" ]; then _cur=$(cat "$_lp" 2>/dev/null; printf X); _cur="${_cur%X}"; fi
      if [ "$TOOL_NAME" = Write ]; then
        _res=$(echo "$INPUT" | jq -j '.tool_input.content // ""' 2>/dev/null; printf X); _res="${_res%X}"
      else
        _res="$_cur"
        _n=$(echo "$INPUT" | jq -r 'if .tool_name == "MultiEdit" then (.tool_input.edits // [] | length) else 1 end' 2>/dev/null || echo 0)
        _i=0
        while [ "$_i" -lt "$_n" ]; do
          _sel=".tool_input"; [ "$TOOL_NAME" = MultiEdit ] && _sel=".tool_input.edits[$_i]"
          _o=$(echo "$INPUT" | jq -j "$_sel.old_string // \"\"" 2>/dev/null; printf X); _o="${_o%X}"
          _nw=$(echo "$INPUT" | jq -j "$_sel.new_string // \"\"" 2>/dev/null; printf X); _nw="${_nw%X}"
          _all=$(echo "$INPUT" | jq -r "$_sel.replace_all // false" 2>/dev/null || echo false)
          if [ -z "$_o" ]; then
            _res="$_nw"
          else
            _res=$(_lit_replace "$_res" "$_o" "$_nw" "$_all"; printf X); _res="${_res%X}"
          fi
          _i=$((_i + 1))
        done
      fi
      [[ "$_res" == "$_cur"* ]] || ledger_deny "a write that changes or removes text already in the ledger"
      _added="${_res#"$_cur"}"
      if [ -n "$_added" ]; then
        if is_advisor_type "$CALLER_TYPE"; then
          printf '%s\n' "$_added" | _ledger_has nonadv \
            && ledger_deny "the advisor adds no 'operator decision' authority and no O / F / E entry"
        else
          printf '%s\n' "$_added" | _ledger_has adv \
            && ledger_deny "only the advisor (subagent_type autoflow-advisor) adds an 'advisor decision' authority or an A entry"
          if [ -n "$CALLER_TYPE" ]; then
            printf '%s\n' "$_added" | _ledger_has opr \
              && ledger_deny "only the main session adds an 'operator decision' authority or an O entry — caller '$CALLER_TYPE' is a sub-agent"
          fi
        fi
      fi
    fi
    ;;
esac

# ── Section 1d: spawn-policy model advisory (NON-GATING, issue #150) ──────────
# docs/core.md > Spawn Model routes every per-phase model value through
# .claude/autoflow/spawn-policy.json. The hook sees `subagent_type` and `model`
# on the payload but not which phase is active, so a phase↔model comparison is
# not available to it. What IS derivable is the set of models the config admits
# for that subagent_type — `spawn-policy.sh models-for <type>`. When that set is
# NON-EMPTY and the declared model falls outside it, this step emits one warning
# line and returns.
#
# An EMPTY admitted set yields no advice, keyed on the SET and never on the
# type's provenance: the harness research types `Plan` / `claude-code-guide`
# are modelled by no phase row, so warning on them would make the advisory a
# steady false-positive stream on calls the policy has nothing to say about —
# and an advisory that cries wolf on correct calls is worse than absent.
# `Explore` yields an empty set like the other research types and draws no
# advice, while every `autoflow-*` type a phase row names draws it — a
# provenance-keyed rule would get both wrong. The case where the policy SHOULD
# have governed a type is caught in the tree by `spawn-policy.sh check`'s
# partition rule, not by a runtime warning.
#
# Advisory only: Section 1b's presence-only `model` deny already ran above and
# is untouched. This step never exits and never denies. Fail-open by
# construction — the whole step runs under `|| true`, so a missing helper, a
# missing `jq` or an unreadable config degrades to "no advice" rather than to a
# broken hook. The helper is resolved by af_helper (top of this file): the
# AutoFlow tree's own copy, never the target's; the config is then resolved by
# the readout
# itself (the target's policy first, the AutoFlow default after it), never by
# this hook.
spawn_policy_advisory_check() {
  local _helper _subtype _model _admitted
  [ "$TOOL_NAME" = "Agent" ] || return 0
  _helper="$(af_helper scripts/spawn-policy/spawn-policy.sh)"
  [ -n "$_helper" ] || return 0

  _subtype=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
  _model=$(echo "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)
  [ -n "$_subtype" ] || return 0
  [ -n "$_model" ] || return 0
  # Both values come from the payload and are passed as ONE quoted argument
  # each — never interpolated into a command string, never word-split, never
  # glob-expanded. The readout treats an unknown type as the empty set, so a
  # hostile or malformed `subagent_type` yields silence, not an error path.
  case "$_subtype" in
    *[!A-Za-z0-9:_-]*) return 0 ;;
  esac
  _admitted=$(bash "$_helper" models-for "$_subtype" 2>/dev/null) || return 0
  [ -n "$_admitted" ] || return 0
  if ! printf '%s\n' "$_admitted" | grep -qxF "$_model"; then
    echo "WARNING: spawn model '$_model' is outside the spawn policy's admitted set for subagent_type '$_subtype' (advisory — this call is NOT blocked)." >&2
    echo "  Admitted: $(printf '%s' "$_admitted" | tr '\n' ' ')— resolve the phase's model with $(af_path scripts/spawn-policy/spawn-policy.sh) model <phase-key> ($(af_path docs/core.md) > Spawn Model)." >&2
  fi
  return 0
}
spawn_policy_advisory_check || true

# Pass.
exit 0
