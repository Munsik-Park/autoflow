#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# invocation-scan.sh — sourced library: the single definition site of "what does
# this file invoke".
# =============================================================================
# SOURCED, NOT EXECUTED. It has no independent exit status and is excluded from
# the subject set for that reason (tests/lib/*.sh is the excluded shape; this
# file sits beside scripts/test/suite-manifest.sh for the same reason that one
# does — a second copy of one subject is two definitions).
#
# THE ADMISSION RULE: the interpreter token's own POSITION decides admission;
# the argument's quoting does not. An interpreter word is an invocation only
# when it stands in command position — at the start of a simple command, or
# after `;`, `&&`, `||`, `|`, `(`, `$(`, or an assignment's `$(`. Its first
# non-option argument is then read WITH QUOTING REMOVED, so a literal argument
# is legible whether or not it was quoted.
#
# THE INTERPRETER WORD SET IS CLOSED, and `invscan_interp_alt` is its single
# definition site: exactly `{bash, sh}`. Both spawn a shell that executes the
# argument as a script, which is the whole of what "this file invokes that one"
# means here, and this tree writes suite invocations both ways (`bash tests/…`
# in workflow `run:` steps, `sh "$SUITE"` in the POSIX-sh plugin suites). A
# word-set keyed on `bash` alone made every `sh`-form invocation invisible to
# BOTH views at once — the leaf lint reported a tree clean over five live
# whole-suite re-runs, and the coverage lint's reachability relation was missing
# the corresponding edges. Outside the set by construction, and stated in each
# consumer's residual: other interpreters (`zsh`, `dash`, `ksh`), `env sh`,
# `exec sh`, and an interpreter reached through a variable (`"$SHELL" x.sh`).
#
# That single rule discharges two requirements at once: `bash "tests/x.sh"` is
# admitted (the `bash` word is unquoted, the argument is dequoted), while
# `grep -B3 'run: bash tests/x.sh'` is rejected (the `bash` word itself sits
# inside a quoted span, so it is in no command position). Stating the fix as an
# admission rule rather than as "stop masking" is what lets the leaf lint keep
# reading `$v` expansions inside double quotes while the coverage lints stop
# reading pattern strings as edges.
#
# TWO LENGTH-PRESERVING VIEWS over one offset space:
#
#   command view   quoted spans blanked; `$var` / `${var}` inside double quotes
#                  preserved; `$( … )` bodies re-entered as code; text after an
#                  unquoted `#` blanked. Used to LOCATE the command-position
#                  interpreter word.
#   argument view  identical, except that the CONTENTS of quoted spans are
#                  preserved and only the delimiters are blanked. Used to READ
#                  the argument once the interpreter word's offset is known.
#
# Every removed character is replaced by a space, so an offset found in the
# command view indexes the same character in the argument view; no second parse
# and no re-tokenisation is involved.
#
# HEREDOC SUPPRESSION IS FILE-SCOPED, NOT PER-LINE. A heredoc body is fixture
# text, never a command position, but a heredoc span is a multi-line notion the
# per-line views cannot see. The two views are therefore heredoc-agnostic BY
# CONSTRUCTION, and the delimitation lives in the file-scoped entry points:
# `invscan_shell_invocations` marks body spans over the whole file, and
# `invscan_workflow_steps` applies the same marking WITHIN a block scalar's
# body — so a step that writes a fixture workflow through a heredoc does not
# register the fixture's `run:` line as an invocation.
#
# Exported surface (awk half: invscan_interp_alt / invscan_interp_len as well):
#   invscan_command_view <line>
#   invscan_argument_view <line>
#   invscan_shell_invocations <file>
#   invscan_workflow_steps <file>       -> start|runpaths|id|if|timeout-minutes
#   invscan_workflow_invocations <file>
# =============================================================================

# ---------------------------------------------------------------------------
# The awk half of the library. It is carried as a string rather than as a
# separate .awk file so that a consumer whose own logic is one awk program —
# scripts/test/check-suite-leaf.sh — composes the same function bodies into its
# program instead of shelling out per line. One definition site, two embedding
# forms.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2016
INVSCAN_AWK_LIB='
function invscan_view(l, keep_quoted,   out, i, c, nx, n, q, depth, stack, ch) {
  out = ""; q = ""; depth = 0; n = length(l)
  for (i = 1; i <= n; i++) {
    c = substr(l, i, 1); nx = substr(l, i + 1, 1)

    # `$(` opens a fresh quoting context: the substitution body is code again,
    # even when the substitution itself sits inside double quotes. The opening
    # is rendered " (" and its close ")" — length-preserving, and it keeps the
    # command boundary an assignment substitution introduces visible.
    if (c == "$" && nx == "(" && q != "\x27") {
      stack[depth] = q; depth++; q = ""; out = out " ("; i++; continue
    }
    if (c == ")" && depth > 0 && q == "") {
      depth--; q = stack[depth]; out = out ")"; continue
    }

    if (q == "\x27") {
      if (c == "\x27") { q = ""; out = out " "; continue }
      out = out (keep_quoted ? c : " "); continue
    }
    if (q == "\"") {
      if (c == "\"") { q = ""; out = out " "; continue }
      if (!keep_quoted && c == "$") {
        # a $var / ${var} expansion inside double quotes is code, and blanking
        # it is what would blind every `bash "$v"` denied row
        out = out c
        for (i = i + 1; i <= n; i++) {
          ch = substr(l, i, 1)
          if (ch ~ /[A-Za-z0-9_{}]/) { out = out ch } else { i--; break }
        }
        continue
      }
      out = out (keep_quoted ? c : " "); continue
    }
    if (c == "#") { for (; i <= n; i++) out = out " "; break }
    if (c == "\x27") { q = "\x27"; out = out " "; continue }
    if (c == "\"")   { q = "\"";   out = out " "; continue }
    out = out c
  }
  return out
}

function invscan_command_view(l)  { return invscan_view(l, 0) }
function invscan_argument_view(l) { return invscan_view(l, 1) }

# invscan_interp_alt() — the closed interpreter-word set as a regex alternation,
# for composition with each consumer own leading-context class. This is the
# single definition site of the set; a consumer that spells `bash` into its own
# pattern re-opens the split that made sh-form invocations invisible.
function invscan_interp_alt() { return "(bash|sh)" }

# invscan_interp_len(seg) — the length of the interpreter word inside a segment
# matched by an invscan interpreter pattern, where the word is the last word of
# the segment before any trailing delimiter. The word is READ OUT of the segment
# rather than inferred from an ordered alternation, so `sh` being a suffix of
# `bash` cannot mis-locate the argument offset, and adding a member to the set
# leaves this function untouched.
function invscan_interp_len(seg) {
  sub(/[[:space:]]+$/, "", seg)
  sub(/^.*[^A-Za-z0-9_]/, "", seg)
  return length(seg)
}

# invscan_first_arg(s) — the first non-option argument of a command whose word
# list begins at s (an ARGUMENT-VIEW slice), reduced to a repo-relative spec
# path, or "" when the argument is not one. An optional `./` prefix is accepted,
# option words and a `--` separator are stepped over.
function invscan_first_arg(s,   tok) {
  sub(/^[[:space:]]+/, "", s)
  while (match(s, /^(--|-[A-Za-z]+)([[:space:]]+|$)/)) {
    s = substr(s, RLENGTH + 1); sub(/^[[:space:]]+/, "", s)
  }
  if (!match(s, /^[^[:space:]]+/)) return ""
  tok = substr(s, RSTART, RLENGTH)
  sub(/^\.\//, "", tok)
  if (tok ~ /^(tests|scripts)\/[A-Za-z0-9_.\/-]+\.(sh|bats)$/) return tok
  return ""
}

# invscan_line_paths(text) — newline-terminated repo-relative paths the single
# line of shell text invokes in command position.
function invscan_line_paths(text,   cv, av, res, n, i, s, seg, off, tok, wl, trail) {
  cv = invscan_command_view(text)
  av = invscan_argument_view(text)
  res = ""; n = length(cv); i = 1
  while (i <= n) {
    s = substr(cv, i)
    if (!match(s, "(^|[;&|(){}])[[:space:]]*" invscan_interp_alt() "([[:space:]]|$)")) break
    seg = substr(s, RSTART, RLENGTH)
    wl = invscan_interp_len(seg)
    trail = (seg ~ /[[:space:]]$/) ? 1 : 0
    off = i + RSTART - 1 + length(seg) - trail - wl
    tok = invscan_first_arg(substr(av, off + wl))
    if (tok != "") res = res tok "\n"
    i = off + wl
  }
  return res
}

# invscan_heredoc_tag(l) — the body-terminating tag a line opens, or "".
function invscan_heredoc_tag(l,   tag) {
  if (!match(l, /<<-?[[:space:]]*[\x27"]?[A-Za-z_][A-Za-z0-9_]*[\x27"]?/)) return ""
  tag = substr(l, RSTART, RLENGTH)
  sub(/^<<-?[[:space:]]*/, "", tag)
  gsub(/[\x27"]/, "", tag)
  return tag
}
'

# ---------------------------------------------------------------------------
# invscan_command_view <line> / invscan_argument_view <line>
# ---------------------------------------------------------------------------
invscan_command_view() {
  printf '%s\n' "$1" | awk "$INVSCAN_AWK_LIB"'{ print invscan_command_view($0) }'
}

invscan_argument_view() {
  printf '%s\n' "$1" | awk "$INVSCAN_AWK_LIB"'{ print invscan_argument_view($0) }'
}

# ---------------------------------------------------------------------------
# invscan_shell_invocations <file> — repo-relative paths a shell file invokes in
# command position, one per line, sorted and unique. Heredoc body lines
# contribute nothing.
# ---------------------------------------------------------------------------
invscan_shell_invocations() {
  [ -f "$1" ] || return 0
  awk "$INVSCAN_AWK_LIB"'
    {
      if (in_here) {
        s = $0; sub(/^[[:space:]]+/, "", s)
        if (s == here_tag) { in_here = 0; here_tag = "" }
        next
      }
      printf "%s", invscan_line_paths($0)
      tag = invscan_heredoc_tag($0)
      if (tag != "") { in_here = 1; here_tag = tag }
    }
  ' "$1" | sort -u
}

# ---------------------------------------------------------------------------
# invscan_workflow_steps <file> — one
# `start|runpaths|id|if|timeout-minutes` record per workflow step whose `run:`
# value invokes at least one path, where `runpaths` is the space-separated set
# of paths that value invokes, from a plain scalar or a `|` / `>` block scalar
# alike.
#
# Block-scalar bodies are delimited by indentation relative to the `run:` key,
# and `id:` / `if:` / `timeout-minutes:` are recognised only at the step's own
# key indentation — which the block delimitation requires anyway, and which is
# what keeps a key nested under `with:` / `env:` out of the record.
# ---------------------------------------------------------------------------
invscan_workflow_steps() {
  [ -f "$1" ] || return 0
  awk "$INVSCAN_AWK_LIB"'
    function indent_of(l,   i, n, ch) {
      n = length(l); i = 1
      while (i <= n) { ch = substr(l, i, 1); if (ch != " " && ch != "\t") break; i++ }
      return i - 1
    }
    function add(text,   got, k, parts, m) {
      got = invscan_line_paths(text)
      m = split(got, parts, "\n")
      for (k = 1; k <= m; k++) {
        if (parts[k] == "") continue
        if (!(parts[k] in seen)) { seen[parts[k]] = 1; runpaths = (runpaths == "" ? parts[k] : runpaths " " parts[k]) }
      }
    }
    function flush() {
      if (start > 0 && runpaths != "")
        printf "%d|%s|%s|%s|%s\n", start, runpaths, sid, ifval, tmo
      start = 0; runpaths = ""; sid = ""; ifval = ""; tmo = ""
      delete seen
      in_block = 0; in_here = 0; here_tag = ""
    }
    {
      line = $0
      ind = indent_of(line)
      trimmed = line; sub(/^[[:space:]]+/, "", trimmed)

      if (in_block) {
        if (trimmed == "" || ind > block_indent) {
          if (in_here) {
            s = trimmed
            if (s == here_tag) { in_here = 0; here_tag = "" }
          } else {
            add(line)
            tag = invscan_heredoc_tag(line)
            if (tag != "") { in_here = 1; here_tag = tag }
          }
          next
        }
        in_block = 0; in_here = 0; here_tag = ""
      }

      if (match(line, /^[[:space:]]*- /)) {
        flush()
        start = NR
        key_indent = RLENGTH
        line = substr(line, RLENGTH + 1)
        ind = key_indent
      } else if (start == 0) {
        next
      } else {
        if (ind != key_indent) next
        line = trimmed
      }

      if (match(line, /^run:[[:space:]]*/)) {
        rest = substr(line, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", rest)
        if (rest == "|" || rest == ">" || rest ~ /^[|>][-+0-9]*$/) {
          in_block = 1; block_indent = key_indent
        } else {
          add(rest)
        }
      }
      else if (match(line, /^id:[[:space:]]*/))              { sid = substr(line, RLENGTH + 1) }
      else if (match(line, /^if:[[:space:]]*/))              { ifval = substr(line, RLENGTH + 1) }
      else if (match(line, /^timeout-minutes:[[:space:]]*/)) { tmo = substr(line, RLENGTH + 1) }
    }
    END { flush() }
  ' "$1"
}

# ---------------------------------------------------------------------------
# invscan_workflow_invocations <file> — the union of `runpaths` across a
# workflow's steps, one per line, sorted and unique.
# ---------------------------------------------------------------------------
invscan_workflow_invocations() {
  invscan_workflow_steps "$1" | awk -F'|' '{ n = split($2, p, " "); for (i = 1; i <= n; i++) if (p[i] != "") print p[i] }' | sort -u
}
