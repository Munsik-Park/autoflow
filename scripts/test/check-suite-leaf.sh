#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-suite-leaf.sh — standing lint: a suite executes its subject, not another
# suite.
# =============================================================================
# The prohibition was settled before this lint existed; what was missing was a
# mechanism. Sibling re-execution is duplicate work whose callee already carries
# its own `run:` step, and it makes a suite's cost a function of what its
# siblings do.
#
# THE DETECTABLE SET IS CLOSED, AND ITS RESIDUAL IS STATED. Static assignment
# tracing in bash is not decidable in general, so this lint is not written as
# "traces to an enumeration". It is a finite list of syntactic shapes, each
# derived from a real occurrence in this tree, and anything outside the list is
# undetected BY CONSTRUCTION:
#
#   DENIED
#     D1  `bash tests/<name>.sh` in command position — the token begins a simple
#         command or follows ||, &&, ;, (, $(, or an assignment's $(
#     D2  `bash "$v"` / `bash "tests/$v"` in command position, where v is
#         assigned in the same file from a pipeline sourced by find/grep/ls
#         over tests/
#     D3  `bash "$v"` in command position inside a function, where v is a
#         POSITIONAL parameter and some call site in the same file passes a
#         literal `tests/…` argument in that position
#     D4  `bash "tests/$v"` in command position where v is a LOOP VARIABLE over
#         a literal list containing a tests/ name
#
#   IGNORED
#     I1  the same token inside a single- or double-quoted string, a heredoc
#         body, or after `#` — assertion labels and YAML fixture bodies, of
#         which this tree carries many, and which a naive non-comment grep
#         flags every one of
#     I2  `bash "$HOOK"` / `bash "$SCRIPT"` — any indirect invocation not
#         matching a denied row. Driving a PRODUCT script is the normal way a
#         suite drives its subject, and the bulk of what this tree does.
#
# RESIDUAL, stated rather than implied: an indirect invocation outside those
# rows — a path assembled through printf, read from a file, or passed across two
# levels of function call — is not detected. This lint raises the cost of
# re-introducing sibling execution; it does not make the class unrepresentable.
# That is acceptable because the residue it guards was enumerated site by site
# and emptied first: the job is preventing re-introduction, not discovering an
# unknown population.
#
# Usage:
#   bash scripts/test/check-suite-leaf.sh [--self-test] [--root <dir>] [--list-subjects]
#
# The default run performs the self-test FIRST, then reports the real-tree
# result — the precedent scripts/test/check-cycle-scope-guard.sh sets. On a tree
# whose residue is empty an exit 0 is unfalsifiable, so the self-test's
# one-fixture-per-row arms are what keep it from being vacuous.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

MODE="default"
ROOT=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test)     MODE="self-test" ;;
    --root)          ROOT="${2:-}"; shift ;;
    --list-subjects) LIST=1 ;;
    *)               echo "check-suite-leaf: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# analyze_file <path> — one `path:line: <shape>: <reason>` record per denied
# occurrence. Exit status is always 0; the caller counts records.
#
# The awk program masks I1 before matching anything: comments, quoted-string
# bodies and heredoc bodies are blanked, so the denied rows are evaluated
# against code positions only.
# ---------------------------------------------------------------------------
analyze_file() {
  awk -v FILEPATH="$1" '
    { lines[NR] = $0 }

    # mask(l) — reduce a line to its COMMAND positions. Blanked: a trailing
    # comment, a single-quoted span (pure text), and the literal text of a
    # double-quoted span. Preserved: anything inside a $( … ) command
    # substitution, and a $var / ${var} expansion inside double quotes — both
    # are code, and blanking them is what would make the denied rows blind to
    # every `bash "$v"` shape they exist to catch.
    function mask(l,   out, i, c, nx, n, q, depth, stack) {
      out = ""; q = ""; depth = 0; n = length(l)
      for (i = 1; i <= n; i++) {
        c = substr(l, i, 1); nx = substr(l, i + 1, 1)

        # `$(` opens a fresh quoting context: the substitution body is code
        # again, even when the substitution itself sits inside double quotes.
        # Without the stack, a quoted grep PATTERN inside a substitution —
        # `X="$(grep -cF "run: bash tests/foo.sh" "$F")"` — reads as a command
        # position, and every registration assertion in this tree false-fires.
        if (c == "$" && nx == "(" && q != "\x27") {
          stack[depth] = q; depth++; q = ""; out = out "  "; i++; continue
        }
        if (c == ")" && depth > 0 && q == "") {
          depth--; q = stack[depth]; out = out " "; continue
        }

        if (q == "\x27") { if (c == "\x27") { q = ""; continue } out = out " "; continue }
        if (q == "\"") {
          if (c == "\"") { q = ""; continue }
          if (c == "$") {
            # a $var / ${var} expansion inside double quotes is code, and
            # blanking it is what would blind every `bash "$v"` denied row
            out = out c
            for (i = i + 1; i <= n; i++) {
              c = substr(l, i, 1)
              if (c ~ /[A-Za-z0-9_{}]/) { out = out c } else { i--; break }
            }
            continue
          }
          out = out " "
          continue
        }
        if (c == "#") break
        if (c == "\x27") { q = "\x27"; continue }
        if (c == "\"")   { q = "\"";   continue }
        out = out c
      }
      return out
    }

    END {
      n = NR

      # ---- heredoc body spans (I1) ------------------------------------
      # A heredoc body is fixture text, never a command position.
      in_here = 0; here_tag = ""
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (in_here) {
          heredoc[i] = 1
          s = l; sub(/^[[:space:]]+/, "", s)
          if (s == here_tag) { in_here = 0; here_tag = "" }
          continue
        }
        if (match(l, /<<-?[[:space:]]*[\x27"]?[A-Za-z_][A-Za-z0-9_]*[\x27"]?/)) {
          tag = substr(l, RSTART, RLENGTH)
          sub(/^<<-?[[:space:]]*/, "", tag)
          gsub(/[\x27"]/, "", tag)
          if (tag != "") { in_here = 1; here_tag = tag }
        }
      }

      # ---- masked code view -------------------------------------------
      for (i = 1; i <= n; i++) code[i] = heredoc[i] ? "" : mask(lines[i])

      # ---- D2 antecedent: variables assigned from a find/grep/ls over tests/
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (c ~ /(find|grep|ls)[^|]*tests/ &&
            match(c, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/)) {
          v = substr(c, RSTART, RLENGTH); sub(/^[[:space:]]*/, "", v); sub(/=$/, "", v)
          swept[v] = 1
        }
      }

      # ---- D4 antecedent: loop variables over a literal list holding a
      #      tests/ name --------------------------------------------------
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (match(c, /^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]/)) {
          v = c; sub(/^[[:space:]]*for[[:space:]]+/, "", v); sub(/[[:space:]]+in[[:space:]].*$/, "", v)
          # the literal list may continue across escaped line breaks
          body = lines[i]; j = i
          while (body ~ /\\[[:space:]]*$/ && j < n) { j++; body = body lines[j] }
          if (body ~ /tests\/[A-Za-z0-9_.-]+\.(sh|bats)/) looped[v] = 1
          # D2 propagation: iterating a swept variable makes the loop variable
          # swept too. The real occurrence assigns the sweep to one name and
          # invokes the loop variable, so a rule that stops at the assignment
          # sees nothing.
          if (match(c, /in[[:space:]]+\$[{]?[A-Za-z_][A-Za-z0-9_]*/)) {
            src = substr(c, RSTART, RLENGTH)
            sub(/^in[[:space:]]+\$[{]?/, "", src)
            if (src in swept) swept[v] = 1
          }
        }
      }

      # ---- D3 antecedent: a function whose positional parameter is passed a
      #      literal tests/ path at some call site in the same file ---------
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (match(c, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/)) {
          fname = c; sub(/^[[:space:]]*/, "", fname); sub(/\(\).*$/, "", fname)
          fnames[fname] = i
        }
      }
      for (fname in fnames) {
        for (i = 1; i <= n; i++) {
          if (i == fnames[fname]) continue
          c = code[i]
          if (c ~ ("(^|[[:space:]();&|])" fname "[[:space:]]")) {
            # a call site; does it pass a literal tests/ path? the argument may
            # sit inside quotes, so this row reads the RAW line by design.
            if (lines[i] ~ /tests\/[A-Za-z0-9_.-]+\.(sh|bats)/) fn_literal[fname] = 1
          }
        }
      }
      # positional parameters bound inside such a function
      for (fname in fn_literal) {
        depth = 0; started = 0
        for (i = fnames[fname]; i <= n; i++) {
          c = code[i]
          if (!started) { started = 1; depth = 1; continue }
          if (c ~ /^\}/) break
          if (match(c, /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=[\"]?\$[0-9]/)) {
            v = c; sub(/^[[:space:]]*(local[[:space:]]+)?/, "", v); sub(/=.*$/, "", v)
            positional[v] = 1
          }
          if (match(c, /^[[:space:]]*local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=?[[:space:]]*[A-Za-z0-9_[:space:]]*$/) &&
              c ~ /\$[0-9]/) { }
          # `local a="$1" b="$2"` — bind every name assigned from a positional
          m = c
          while (match(m, /[A-Za-z_][A-Za-z0-9_]*=\"?\$[0-9]/)) {
            v = substr(m, RSTART, RLENGTH); sub(/=.*$/, "", v)
            positional[v] = 1
            m = substr(m, RSTART + RLENGTH)
          }
          fn_scope[i] = fname
        }
      }

      # ---- report ------------------------------------------------------
      # The argument is parsed positionally rather than matched by one large
      # regex: locate the `bash` command word, step over its option words, then
      # read the first argument token. That keeps each denied row a statement
      # about the ARGUMENT, and keeps the rows independent of one another.
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (!match(c, /(^|[[:space:]();&|])bash[[:space:]]+/)) continue
        rest = substr(c, RSTART + RLENGTH)
        while (match(rest, /^-[A-Za-z]+[[:space:]]+/)) rest = substr(rest, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", rest)

        # D1 — a literal tests/ path
        if (rest ~ /^(\.\.\/)*tests\/[A-Za-z0-9_.-]+\.(sh|bats)/) {
          printf "%s:%d: D1: command-position literal invocation of a sibling suite\n", FILEPATH, i
          continue
        }

        # otherwise the argument must be an expansion, optionally tests/-prefixed
        prefixed = 0
        if (rest ~ /^tests\/\$/) { prefixed = 1; sub(/^tests\//, "", rest) }
        if (rest !~ /^\$/) continue
        v = substr(rest, 2)
        sub(/^[{]/, "", v)
        if (!match(v, /^[A-Za-z_][A-Za-z0-9_]*/)) continue
        v = substr(v, 1, RLENGTH)

        if (v in swept) {
          printf "%s:%d: D2: invocation of a suite path derived from a find/grep/ls enumeration over tests/\n", FILEPATH, i
          continue
        }
        if (v in looped) {
          printf "%s:%d: D4: invocation of $%s, a loop variable over a literal list holding a suite name\n", FILEPATH, i, v
          continue
        }
        if ((v in positional) && (i in fn_scope) && !prefixed) {
          printf "%s:%d: D3: invocation of positional parameter $%s, which a call site passes a literal tests/ path\n", FILEPATH, i, v
          continue
        }
      }
    }
  ' "$1"
}

# ---------------------------------------------------------------------------
check_tree() {
  local root="$1" violations=0 subjects=0 f out
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$root/$f" ] || continue
    subjects=$((subjects + 1))
    out="$(analyze_file "$root/$f")"
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | sed "s|^$root/||; s|^|  |; s|^  |  $f |" >/dev/null
      printf '%s\n' "$out" | sed "s|^${root}/||"
      violations=$((violations + $(printf '%s\n' "$out" | grep -c .)))
    fi
  done < <(suite_enumerate "$root")
  LAST_SUBJECT_COUNT="$subjects"
  LAST_VIOLATION_COUNT="$violations"
  [ "$violations" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Self-test — one fixture per denied row and one per ignored row. The ignored
# arm is not decorative: a naive non-comment grep false-positives on every one
# of them, on the real occurrences the rows are derived from.
# ---------------------------------------------------------------------------
self_test() {
  local dir rc=0 fails=0
  dir="$(mktemp -d)"
  mkdir -p "$dir/tests"

  expect() { # <label> <basename> <denied|ignored>
    local label="$1" file="$2" want="$3" out
    out="$(analyze_file "$dir/tests/$file")"
    if [ "$want" = denied ] && [ -z "$out" ]; then
      echo "  SELF-TEST FAIL: $label — expected a denied record, got none"; fails=$((fails + 1))
    elif [ "$want" = ignored ] && [ -n "$out" ]; then
      echo "  SELF-TEST FAIL: $label — expected no record, got:"; printf '%s\n' "$out" | sed 's/^/    /'
      fails=$((fails + 1))
    else
      echo "  SELF-TEST PASS: $label"
    fi
  }

  # --- D1: command-position literal ---------------------------------------
  cat > "$dir/tests/test-fixture-d1.sh" <<'SH'
#!/usr/bin/env bash
OUT="$(cd "$PROJECT_ROOT" && bash tests/test-issue-999-callee.sh 2>&1)"
bash tests/test-issue-998-callee.sh
SH
  expect "D1: command-position literal invocation" test-fixture-d1.sh denied

  # --- D2: find/grep-derived enumeration sweep ----------------------------
  cat > "$dir/tests/test-fixture-d2.sh" <<'SH'
#!/usr/bin/env bash
HOMES="$(grep -rl 'EXPECTED_OK=' tests/ | sort)"
for home in $HOMES; do
  bash "$home"
done
SH
  expect "D2: invocation of a find/grep-derived enumeration" test-fixture-d2.sh denied

  # --- D3: function positional with a literal call site -------------------
  cat > "$dir/tests/test-fixture-d3.sh" <<'SH'
#!/usr/bin/env bash
assert_suite_exit0() {
  local suite_path="$1"
  bash "$suite_path"
}
assert_suite_exit0 tests/test-issue-997-callee.sh
SH
  expect "D3: function positional whose call site passes a literal tests/ path" test-fixture-d3.sh denied

  # --- D4: loop variable over a literal list ------------------------------
  cat > "$dir/tests/test-fixture-d4.sh" <<'SH'
#!/usr/bin/env bash
for suite in tests/test-issue-996-callee.sh tests/test-issue-995-callee.sh; do
  bash "$suite"
done
SH
  expect "D4: loop variable over a literal list holding a suite name" test-fixture-d4.sh denied

  # --- I1a: quoted assertion label ----------------------------------------
  cat > "$dir/tests/test-fixture-i1a.sh" <<'SH'
#!/usr/bin/env bash
assert_true "the workflow registers: run: bash tests/test-issue-994-callee.sh" "true"
grep -qF 'run: bash tests/test-issue-993-callee.sh' "$CI_WORKFLOW"
SH
  expect "I1a: the token inside a quoted assertion label" test-fixture-i1a.sh ignored

  # --- I1b: YAML heredoc fixture body -------------------------------------
  cat > "$dir/tests/test-fixture-i1b.sh" <<'SH'
#!/usr/bin/env bash
cat > "$FIXTURE/wf.yml" <<'YML'
jobs:
  j:
    steps:
      - run: bash tests/test-issue-992-callee.sh
YML
SH
  expect "I1b: the token inside a YAML heredoc fixture body" test-fixture-i1b.sh ignored

  # --- I1c: after # --------------------------------------------------------
  cat > "$dir/tests/test-fixture-i1c.sh" <<'SH'
#!/usr/bin/env bash
# This suite used to run bash tests/test-issue-991-callee.sh; it no longer does.
true   # bash tests/test-issue-990-callee.sh
SH
  expect "I1c: the token after a # comment marker" test-fixture-i1c.sh ignored

  # --- I2: indirect product-script drive ----------------------------------
  cat > "$dir/tests/test-fixture-i2.sh" <<'SH'
#!/usr/bin/env bash
HOOK=".claude/hooks/check-autoflow-gate.sh"
bash "$HOOK"
SCRIPT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"
bash "$SCRIPT" --self-test
SH
  expect "I2: an indirect product-script drive is the normal shape and is not flagged" test-fixture-i2.sh ignored

  # --- SUBJECT-SET leg: the enumeration is not vacuous --------------------
  mkdir -p "$dir/tests/plugin"
  echo 'true' > "$dir/tests/plugin/verify-fixture-subject.sh"
  local enumerated
  enumerated="$(suite_enumerate "$dir")"
  if printf '%s\n' "$enumerated" | grep -qxF 'tests/plugin/verify-fixture-subject.sh' \
     && printf '%s\n' "$enumerated" | grep -qxF 'tests/test-fixture-d1.sh'; then
    echo "  SELF-TEST PASS: subject-set leg — the enumeration reaches a filename outside test-*.sh"
  else
    echo "  SELF-TEST FAIL: subject-set leg — enumeration missed a planted spec"
    fails=$((fails + 1))
  fi

  rm -rf "$dir"
  if [ "$fails" -ne 0 ]; then
    echo "check-suite-leaf: --self-test FAILED ($fails of 9 fixture classes misclassified)"
    rc=1
  else
    echo "check-suite-leaf: --self-test OK (9/9 fixture classes classified correctly)"
  fi
  return $rc
}

if [ "$LIST" -eq 1 ]; then
  suite_enumerate "$ROOT"
  exit 0
fi

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if ! self_test; then
  echo "check-suite-leaf: detector self-test failed — real-tree result not reported"
  exit 1
fi

LAST_SUBJECT_COUNT=0
LAST_VIOLATION_COUNT=0
if check_tree "$ROOT"; then
  echo "check-suite-leaf: OK — $LAST_SUBJECT_COUNT suite(s), none executing another suite"
  exit 0
fi
echo "check-suite-leaf: $LAST_VIOLATION_COUNT sibling-invocation site(s) across $LAST_SUBJECT_COUNT suite(s)"
echo "  A suite executes its subject, not another suite: each callee carries its own run: step,"
echo "  so a sibling invocation is duplicate execution of an already-covered surface."
exit 1
