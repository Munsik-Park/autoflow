#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Extraction rule library — Issue #76 AC-a-1
# =============================================================================
# Implements the AC-a-1 "Extraction rule" from
# .autoflow/issue-76-verification-design.md verbatim:
#
#   - An invocation line is, after OPTIONAL leading whitespace, a line that
#     begins with the command word `assert_true` or `assert_false` FOLLOWED
#     BY WHITESPACE OR A LINE-CONTINUATION BACKSLASH. A definition line
#     (`assert_true() {`) is excluded because `(` is neither whitespace nor a
#     backslash.
#   - The identity is the invocation's FIRST ARGUMENT, verbatim (un-expanded
#     source text): the first double-quoted token that follows the command
#     word on the invocation line if one is present there; otherwise the
#     first double-quoted token on the immediately following source line
#     (the continuation-only shape).
#   - Identity is a MULTISET: two invocations with byte-identical first
#     arguments are two distinct occurrences, not one.
#
# Sourced by tests/test-issue-76-migration-map-total.sh. Every quantity here
# is recomputed from the CURRENT working tree (or a `git show <ref>:<path>`
# snapshot the caller feeds in) — nothing is cached or hardcoded, per the
# verification design's record-discipline note that a number written into a
# document would drift the moment a suite is edited.
# =============================================================================

set -uo pipefail

# Shared awk helpers for the two extractors below (both need the same
# quoted-token scanner). is_ws: whitespace test. extract_quoted: extracts the
# first double-quoted token starting at position p (1-based, pointing at the
# opening quote) in string s; returns the token TEXT (without the surrounding
# quotes) via global RESULT, and the index just past the closing quote via
# global RESULT_END (0 if unterminated).
_ISSUE76_AWK_QUOTE_HELPERS='
    function is_ws(c) { return c == " " || c == "\t" }
    function extract_quoted(s, p,   n, i, c, buf) {
      n = length(s)
      buf = ""
      i = p + 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\" && i < n) {
          buf = buf substr(s, i, 2)
          i += 2
          continue
        }
        if (c == "\"") {
          RESULT = buf
          RESULT_END = i + 1
          return
        }
        buf = buf c
        i++
      }
      RESULT = buf
      RESULT_END = 0
      return
    }
'

# rule_extract <file>
# Prints one line per occurrence: "<line_no>\t<verbatim first argument>"
# in source order. Reads its input from a real file path (caller is
# responsible for materializing a base-ref snapshot to a temp file first).
issue76_rule_extract() {
  local file="$1"
  awk "$_ISSUE76_AWK_QUOTE_HELPERS"'
    {
      lines[NR] = $0
    }
    END {
      for (ln = 1; ln <= NR; ln++) {
        line = lines[ln]
        stripped = line
        sub(/^[ \t]+/, "", stripped)
        # candidate: starts with assert_true or assert_false
        if (stripped !~ /^assert_(true|false)/) continue
        kwlen = (stripped ~ /^assert_true/) ? 11 : 12
        rest = substr(stripped, kwlen + 1)
        nextc = substr(rest, 1, 1)
        if (!(is_ws(nextc) || nextc == "\\")) continue   # definition form: "("
        # find first quote in the remainder of this line
        qpos = index(rest, "\"")
        if (qpos > 0) {
          extract_quoted(rest, qpos)
          printf "%d\t%s\n", ln, RESULT
        } else {
          # continuation-only shape: first quoted token on the NEXT source line
          nxt = lines[ln + 1]
          if (nxt == "") continue
          qpos2 = index(nxt, "\"")
          if (qpos2 == 0) continue
          extract_quoted(nxt, qpos2)
          printf "%d\t%s\n", ln, RESULT
        }
      }
    }
  ' "$file"
}

# dumb_count_lines <file>
# Prints one line number per line whose first non-whitespace token begins
# with "assert_true" or "assert_false" — no boundary/shape refinement at
# all (admits the definition form and every indentation). This is the
# extraction-rule-independent reconciliation check.
issue76_dumb_count_lines() {
  local file="$1"
  awk '
    {
      stripped = $0
      sub(/^[ \t]+/, "", stripped)
      if (stripped ~ /^assert_(true|false)/) print NR
    }
  ' "$file"
}

# conjunct_count <file>
# Prints the total number of conjuncts (&&/||-separated predicate clauses)
# across every rule-extracted invocation in <file>. The predicate is the
# SECOND argument to assert_true/assert_false; this counts top-level " && "
# / " || " occurrences in that argument (occurrences inside a nested quoted
# string are not split further — sufficient for this corpus's shape, which
# uses `&&`/`||` only to join grep/test clauses, never inside a literal).
issue76_conjunct_count() {
  local file="$1"
  awk "$_ISSUE76_AWK_QUOTE_HELPERS"'
    { lines[NR] = $0 }
    END {
      total = 0
      for (ln = 1; ln <= NR; ln++) {
        line = lines[ln]
        stripped = line
        sub(/^[ \t]+/, "", stripped)
        if (stripped !~ /^assert_(true|false)/) continue
        kwlen = (stripped ~ /^assert_true/) ? 11 : 12
        rest = substr(stripped, kwlen + 1)
        nextc = substr(rest, 1, 1)
        if (!(is_ws(nextc) || nextc == "\\")) continue
        qpos = index(rest, "\"")
        predicate = ""
        if (qpos > 0) {
          extract_quoted(rest, qpos)
          after = substr(rest, RESULT_END)
          qpos2 = index(after, "\"")
          if (qpos2 > 0) {
            extract_quoted(after, qpos2)
            predicate = RESULT
          } else {
            # predicate continues on the next line(s); best-effort: join
            # subsequent lines until a line without a trailing backslash.
            k = ln
            joined = ""
            while (k + 1 <= NR) {
              k++
              joined = joined " " lines[k]
              if (lines[k] !~ /\\[ \t]*$/) break
            }
            predicate = joined
          }
        } else {
          nxt = lines[ln + 1]
          if (nxt == "") continue
          qpos2 = index(nxt, "\"")
          if (qpos2 == 0) continue
          extract_quoted(nxt, qpos2)
          after = substr(nxt, RESULT_END)
          qpos3 = index(after, "\"")
          if (qpos3 > 0) { extract_quoted(after, qpos3); predicate = RESULT }
        }
        n = split(predicate, parts, / && | \|\| /)
        total += (n > 0 ? n : 1)
      }
      print total
    }
  ' "$file"
}
