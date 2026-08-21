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
# undetected BY CONSTRUCTION.
#
# Each denied row is written below with `bash` as its interpreter word, but the
# word is not what the row is about. The admitted set is the CLOSED interpreter
# class `{bash, sh}` defined once in scripts/test/invocation-scan.sh
# (`invscan_interp_alt`), and every row reads `sh` exactly as it reads `bash` —
# a shell spawned on the argument is the invocation, whichever of the two names
# it. Keying the rows on `bash` alone is precisely what let five live
# whole-suite re-runs in this tree's POSIX-sh plugin suites sit under a clean
# report; the residual below now names the interpreters that remain outside.
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
#     D5  `bash "$v"` in command position, where v is assigned ANYWHERE in the
#         same file from a value whose literal text names an ENUMERATED suite —
#         as a repo-relative path (`v="$PROJECT_ROOT/tests/<suite>.sh"`) or as
#         an enumerated basename under a directory expansion
#         (`v="$SCRIPT_DIR/<suite>.sh"`). Decidable, not heuristic, on two
#         counts: the assignment's value is read as literal text, and the name
#         is checked against `suite_enumerate`'s set, so "looks like a suite
#         name" never enters the judgement.
#     D6  `bash "$v"` in command position with NO argument, where v is
#         assigned in the same file a value whose literal text names a DENIED
#         NON-SUITE TARGET — the set held in `denied_nonsuite_targets`, whose
#         one member is `tests/run-doc-invariants.sh`. D5 cannot reach it: D5
#         keys on `suite_enumerate`'s set, and the runner is a declared
#         exclusion from that set, so a suite re-running the whole doc-invariant
#         registry read as an ordinary product-script drive (I2). A BARE run is
#         whole-registry re-execution of a leg that already carries its own
#         unguarded workflow steps; an invocation carrying ANY argument (a
#         fixture registry path, `--self-test`, a root override) is driving the
#         runner as a SUBJECT against a fixture, which is what the runner's own
#         contract suite legitimately does, and stays admitted. A trailing
#         redirection or command-substitution terminator is not an argument.
#         The literal form (`bash tests/run-doc-invariants.sh`) needs no row of
#         its own: D1 already denies every command-position literal `tests/`
#         path, enumerated or not.
#
#   IGNORED
#     I1  the same token inside a single- or double-quoted string, a heredoc
#         body, or after `#` — assertion labels and YAML fixture bodies, of
#         which this tree carries many, and which a naive non-comment grep
#         flags every one of. What decides is where the `bash` TOKEN sits, not
#         how its argument is quoted: `bash "tests/x.sh"` is D1 (the token is in
#         command position, the argument merely quoted), while
#         `grep -B3 'run: bash tests/x.sh'` is I1 (the token itself is inside a
#         quoted span, in no command position at all).
#     I2  `bash "$HOOK"` / `bash "$SCRIPT"` — any indirect invocation not
#         matching a denied row. Driving a PRODUCT script is the normal way a
#         suite drives its subject, and the bulk of what this tree does.
#     I3  an enumerated-suite path assigned to a variable that is only READ —
#         a `grep` file operand, say — and never invoked. D5's antecedent is a
#         CONJUNCTION (the assignment AND a command-position `bash "$v"`), and
#         this half of it is a permanent, deliberate shape in this tree.
#     I5  a word that merely ENDS in an interpreter's letters — `run-suites.sh`,
#         `finish` — is not an interpreter word. `sh` is a suffix of `bash` and
#         of every `*.sh` path in the tree, so the match is anchored at a word
#         boundary, and this row is the negative control for that anchoring.
#
# RESIDUAL, stated rather than implied and narrowed to what the rows above
# leave. It has three parts.
#
#   The ARGUMENT. Quoting no longer hides one, and a variable naming an
#   enumerated suite no longer hides one either, so what remains undetected is
#   an argument whose LITERAL TEXT never appears in the file: a path assembled
#   through printf or string concatenation, read from a file at run time, or
#   passed across two levels of function call.
#
#   The INTERPRETER. The word set is closed at `{bash, sh}`, so a suite driven
#   through any other spelling is undetected: another interpreter (`zsh`,
#   `dash`, `ksh`), an interpreter behind a wrapper word (`env sh …`,
#   `exec sh …`, `timeout 60 bash …`), an interpreter reached through an
#   expansion (`"$SHELL" tests/x.sh`), and direct execution with no interpreter
#   word at all (`./tests/x.sh`, or a `$SUITE` made executable and called
#   bare). The two admitted members are the two this tree writes; widening the
#   set is a one-line edit at `invscan_interp_alt`, and each new member needs
#   its own self-test arm.
#
#   The SUBJECT. Outside every row by construction: an invocation of a path the
#   enumeration does not carry (D5 keys on the enumerated set, which is what
#   keeps `tests/lib/*` — an excluded subject — from reading as a sibling).
#   `tests/run-doc-invariants.sh` was in that residual until issue #122 named it
#   in `denied_nonsuite_targets` (D6). Admitting a further non-suite target is
#   one line there plus its own self-test arms; nothing else generalises to it.
#
# This lint raises the cost of re-introducing sibling execution; it does not
# make the class unrepresentable.
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
# shellcheck source=scripts/test/invocation-scan.sh
. "$SCRIPT_DIR/invocation-scan.sh"

# ---------------------------------------------------------------------------
# denied_nonsuite_targets — repo-relative paths that are NOT in
# `suite_enumerate`'s set (so D1-D5 cannot reach them through a variable) but
# whose BARE invocation from a suite is whole-subject re-execution all the same.
# One member today: the doc-invariant registry runner, whose current-tree
# conformance and mutation-teeth legs both carry their own unguarded steps in
# .github/workflows/contract-suites.yml (issue #122). Adding a member is one
# line here plus its own self-test arms, per the header's convention.
# ---------------------------------------------------------------------------
denied_nonsuite_targets() {
  printf '%s\n' 'tests/run-doc-invariants.sh'
}

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
# analyze_file <path> <subjects-file> — one `path:line: <shape>: <reason>`
# record per denied occurrence. Exit status is always 0; the caller counts
# records.
#
# The two views come from scripts/test/invocation-scan.sh, composed into this
# program rather than re-implemented: the command view locates the
# command-position interpreter word and carries the D2/D3/D4 antecedent scans, and
# the argument view — identical in length, so one offset indexes both — is what
# the argument is READ from, which is why a quoted literal is now legible.
#
# <subjects-file> holds the enumerated subject set of the tree being checked,
# one repo-relative path per line. D5 keys on it, so "looks like a suite name"
# never enters the judgement.
# ---------------------------------------------------------------------------
analyze_file() {
  awk -v FILEPATH="$1" -v SUBJECTS="$2" -v NONSUITE="$(denied_nonsuite_targets | tr '\n' ' ')" "$INVSCAN_AWK_LIB"'
    BEGIN {
      while ((getline s < SUBJECTS) > 0) {
        if (s == "") continue
        subj[s] = 1
        b = s; sub(/^.*\//, "", b); subjbase[b] = 1
      }
      close(SUBJECTS)
      nn = split(NONSUITE, nsarr, /[[:space:]]+/)
      for (k = 1; k <= nn; k++) {
        if (nsarr[k] == "") continue
        nonsuite[nsarr[k]] = 1
        b = nsarr[k]; sub(/^.*\//, "", b); nonsuitebase[b] = 1
      }
    }
    { lines[NR] = $0 }

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
        tag = invscan_heredoc_tag(l)
        if (tag != "") { in_here = 1; here_tag = tag }
      }

      # ---- the two views ----------------------------------------------
      for (i = 1; i <= n; i++) {
        code[i]    = heredoc[i] ? "" : invscan_command_view(lines[i])
        argview[i] = heredoc[i] ? "" : invscan_argument_view(lines[i])
      }

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
          # A quote delimiter is one BLANK in the length-preserving view, not a
          # dropped character, so the `="$1"` shape reads `= $1` here.
          if (match(c, /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=[[:space:]]?\$[0-9]/)) {
            v = c; sub(/^[[:space:]]*(local[[:space:]]+)?/, "", v); sub(/=.*$/, "", v)
            positional[v] = 1
          }
          # `local a="$1" b="$2"` — bind every name assigned from a positional
          m = c
          while (match(m, /[A-Za-z_][A-Za-z0-9_]*=[[:space:]]?\$[0-9]/)) {
            v = substr(m, RSTART, RLENGTH); sub(/=.*$/, "", v)
            positional[v] = 1
            m = substr(m, RSTART + RLENGTH)
          }
          fn_scope[i] = fname
        }
      }

      # ---- D5 antecedent: variables assigned, ANYWHERE in the same file, a
      #      value whose literal text names an ENUMERATED suite — either as a
      #      repo-relative path (`VAR="$PROJECT_ROOT/tests/<suite>.sh"`) or as
      #      an enumerated basename under a directory expansion
      #      (`VAR="$SCRIPT_DIR/<suite>.sh"`). The literal is read from the
      #      ARGUMENT view, since the shape is a quoted literal, and the name is
      #      checked against the enumeration rather than against a suite-looking
      #      pattern — which is what makes the row decidable rather than a
      #      heuristic.
      # ---- I4 antecedent: SCRATCH ROOTS. A variable this file assigns from
      #      `mktemp` or `git worktree add` names a copy of the tree at another
      #      on-disk state, and a suite under it is not the registered sibling —
      #      it is a negative control whose own CI step, running the unperturbed
      #      tree, cannot stand in for it.
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (!match(c, /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) continue
        if (c !~ /mktemp|worktree[[:space:]]+add/) continue
        v = substr(c, RSTART, RLENGTH)
        sub(/^[[:space:]]*(local[[:space:]]+)?/, "", v); sub(/=$/, "", v)
        scratch[v] = 1
      }

      for (i = 1; i <= n; i++) {
        a = argview[i]
        if (!match(a, /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) continue
        v = substr(a, RSTART, RLENGTH)
        val = substr(a, RSTART + RLENGTH)
        sub(/^[[:space:]]*(local[[:space:]]+)?/, "", v); sub(/=$/, "", v)
        root = val; sub(/^[[:space:]]+/, "", root)
        if (match(root, /^\$[{]?[A-Za-z_][A-Za-z0-9_]*[}]?\//)) {
          root = substr(root, RSTART, RLENGTH)
          gsub(/[\$\{\}\/]/, "", root)
          if (root in scratch) continue
        }
        if (match(val, /tests\/[A-Za-z0-9_.\/-]+\.(sh|bats)/)) {
          lit = substr(val, RSTART, RLENGTH)
          if (lit in subj) named[v] = 1
          if (lit in nonsuite) named_nonsuite[v] = 1
        } else if (match(val, /\$[{]?[A-Za-z_][A-Za-z0-9_]*[}]?\/[A-Za-z0-9_.-]+\.(sh|bats)/)) {
          tok = substr(val, RSTART, RLENGTH); sub(/^.*\//, "", tok)
          if (tok in subjbase) named[v] = 1
          if (tok in nonsuitebase) named_nonsuite[v] = 1
        }
      }

      # ---- report ------------------------------------------------------
      # The argument is parsed positionally rather than matched by one large
      # regex: locate the interpreter command word in the COMMAND view, step over its
      # option words and any `--` separator, then read the first argument token
      # from the ARGUMENT view at the same offset. That keeps each denied row a
      # statement about the ARGUMENT, keeps the rows independent of one another,
      # and is what makes a quoted literal legible without making a quoted grep
      # pattern a command position.
      for (i = 1; i <= n; i++) {
        c = code[i]
        if (!match(c, "(^|[[:space:]();&|])" invscan_interp_alt() "[[:space:]]")) continue
        rest = substr(argview[i], RSTART + RLENGTH)
        while (match(rest, /^[[:space:]]*(--|-[A-Za-z]+)([[:space:]]|$)/)) rest = substr(rest, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", rest)

        # D1 — a literal tests/ path
        if (rest ~ /^(\.\.\/|\.\/)*tests\/[A-Za-z0-9_.-]+\.(sh|bats)/) {
          printf "%s:%d: D1: command-position literal invocation of a sibling suite\n", FILEPATH, i
          continue
        }

        # D5, direct form — `bash "$DIR/<suite>.sh"`: the argument itself
        # carries the literal, with no intermediate variable to assign it to.
        if (match(rest, /^\$[{]?[A-Za-z_][A-Za-z0-9_]*[}]?\//)) {
          root = substr(rest, RSTART, RLENGTH); gsub(/[\$\{\}\/]/, "", root)
          tok = rest; sub(/[[:space:]].*$/, "", tok)
          base = tok; sub(/^.*\//, "", base)
          if (!(root in scratch) &&
              ((match(tok, /tests\/[A-Za-z0-9_.\/-]+\.(sh|bats)$/) && (substr(tok, RSTART, RLENGTH) in subj)) ||
               (base in subjbase))) {
            printf "%s:%d: D5: command-position invocation of an enumerated suite under a directory expansion\n", FILEPATH, i
            continue
          }
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
        if ((v in named) && !prefixed) {
          printf "%s:%d: D5: invocation of $%s, a variable this file assigns a literal enumerated-suite path\n", FILEPATH, i, v
          continue
        }
        # D6 — a BARE invocation of a denied non-suite target. What follows the
        # argument decides: a further word is an argument (the runner driven as
        # a subject against a fixture, admitted); a redirection or a command-
        # substitution terminator is not.
        if ((v in named_nonsuite) && !prefixed) {
          after = rest; sub(/^[^[:space:]]+/, "", after); sub(/^[[:space:]]+/, "", after)
          if (after == "" || after ~ /^([0-9]*[<>]|[)|;&#])/) {
            printf "%s:%d: D6: bare invocation of $%s, a variable this file assigns a denied non-suite target (whole-subject re-execution)\n", FILEPATH, i, v
            continue
          }
        }
      }
    }
  ' "$1"
}

# ---------------------------------------------------------------------------
check_tree() {
  local root="$1" violations=0 subjects=0 f out subjfile
  subjfile="$(mktemp)"
  suite_enumerate "$root" > "$subjfile"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$root/$f" ] || continue
    subjects=$((subjects + 1))
    out="$(analyze_file "$root/$f" "$subjfile")"
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | sed "s|^${root}/||"
      violations=$((violations + $(printf '%s\n' "$out" | grep -c .)))
    fi
  done < "$subjfile"
  rm -f "$subjfile"
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
    local label="$1" file="$2" want="$3" out subjfile
    # Re-enumerated per arm: the D5 fixtures plant their callee alongside the
    # caller, and the row keys on the enumeration rather than on a name shape.
    subjfile="$(mktemp)"
    suite_enumerate "$dir" > "$subjfile"
    out="$(analyze_file "$dir/tests/$file" "$subjfile")"
    rm -f "$subjfile"
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

  # --- D1 admitted forms: quoted, ./-prefixed, and `--`-separated ----------
  # Each was undetected before this cycle: the masker erased a quoted literal
  # entirely, the option-stepping regex did not consume a `--`, and the literal
  # row admitted a `../` prefix but not a `./` one.
  echo 'true' > "$dir/tests/test-fixture-d1-callee.sh"
  cat > "$dir/tests/test-fixture-d1-quoted.sh" <<'SH'
#!/usr/bin/env bash
bash "tests/test-fixture-d1-callee.sh"
bash 'tests/test-fixture-d1-callee.sh'
SH
  expect "D1: a double- or single-quoted literal argument" test-fixture-d1-quoted.sh denied

  cat > "$dir/tests/test-fixture-d1-dotslash.sh" <<'SH'
#!/usr/bin/env bash
bash ./tests/test-fixture-d1-callee.sh
SH
  expect "D1: a ./-prefixed literal argument" test-fixture-d1-dotslash.sh denied

  cat > "$dir/tests/test-fixture-d1-dashdash.sh" <<'SH'
#!/usr/bin/env bash
bash -- tests/test-fixture-d1-callee.sh
SH
  expect "D1: a literal argument behind a -- separator" test-fixture-d1-dashdash.sh denied

  # --- D1/D5 under the second interpreter word ----------------------------
  # The word set is {bash, sh}, and `sh` was the half that was missing: five
  # live whole-suite re-runs in the POSIX-sh plugin suites sat outside a
  # bash-keyed grammar while the lint reported the tree clean. Both a literal
  # and a variable-mediated argument are exercised, since the word is located
  # independently of which denied row then reads the argument.
  cat > "$dir/tests/test-fixture-sh-interp.sh" <<'SH'
#!/usr/bin/env bash
sh tests/test-fixture-d1-callee.sh
SH
  expect "D1: a literal argument under the sh interpreter word" test-fixture-sh-interp.sh denied

  cat > "$dir/tests/test-fixture-sh-interp-var.sh" <<'SH'
#!/usr/bin/env bash
CALLEE="$PROJECT_ROOT/tests/test-fixture-d1-callee.sh"
OUT=$(sh "$CALLEE" 2>&1)
SH
  expect "D5: a named variable invoked under the sh interpreter word inside a substitution" test-fixture-sh-interp-var.sh denied

  # --- I5: a word merely ENDING in the interpreter's letters ---------------
  # `sh` is a suffix of both `bash` and of every `*.sh` path, so a widened word
  # set is only sound if the match is anchored at a word boundary. This arm is
  # the negative control for that anchoring.
  cat > "$dir/tests/test-fixture-i5.sh" <<'SH'
#!/usr/bin/env bash
PRODUCT="$PROJECT_ROOT/scripts/test/run-suites.sh"
"$PRODUCT" --all
echo "finish tests/test-fixture-d1-callee.sh"
SH
  expect "I5: a word merely ending in the interpreter's letters is not an interpreter word" test-fixture-i5.sh ignored

  # --- D5: a variable this file assigns a literal enumerated-suite path ----
  cat > "$dir/tests/test-fixture-d5.sh" <<'SH'
#!/usr/bin/env bash
CALLEE="$PROJECT_ROOT/tests/test-fixture-d1-callee.sh"
bash "$CALLEE"
SH
  expect "D5: a named variable carrying a literal enumerated-suite path" test-fixture-d5.sh denied

  # --- I3: D5's antecedent is a CONJUNCTION -------------------------------
  # The assignment alone is not the violation. This shape is permanent and
  # deliberate in the tree — a suite path held as a `grep` file operand — so a
  # row keyed on the assignment would red a conforming file.
  cat > "$dir/tests/test-fixture-i3.sh" <<'SH'
#!/usr/bin/env bash
CALLEE="$PROJECT_ROOT/tests/test-fixture-d1-callee.sh"
grep -q 'EXPECTED_OK=' "$CALLEE"
SH
  expect "I3: an enumerated-suite path assigned but only READ, never invoked, is not a violation" test-fixture-i3.sh ignored

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

  # --- D6: bare invocation of a denied non-suite target (issue #122) -------
  # The callee is planted so the fixture tree is realistic; the row keys on the
  # denied_nonsuite_targets set, not on the file being present.
  echo 'true' > "$dir/tests/run-doc-invariants.sh"
  cat > "$dir/tests/test-fixture-d6.sh" <<'SH'
#!/usr/bin/env bash
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
OUT="$(cd "$PROJECT_ROOT" && bash "$REGISTRY_RUNNER" 2>&1)"
SH
  expect "D6: a bare invocation of the registry runner through a variable is denied" test-fixture-d6.sh denied

  # --- D6 non-firing: an ARGUMENT means the runner is the subject ----------
  cat > "$dir/tests/test-fixture-d6-nf-selftest.sh" <<'SH'
#!/usr/bin/env bash
RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
OUT="$(bash "$RUNNER" --self-test 2>&1)"
SH
  expect "D6 non-firing: an invocation carrying --self-test drives the runner as a subject and stays admitted" test-fixture-d6-nf-selftest.sh ignored

  cat > "$dir/tests/test-fixture-d6-nf-fixture.sh" <<'SH'
#!/usr/bin/env bash
RUNNER="$SCRIPT_DIR/run-doc-invariants.sh"
OUT="$(bash "$RUNNER" "$FIXTURE_REGISTRY" 2>&1)"
SH
  expect "D6 non-firing: an invocation carrying a fixture registry path drives the runner as a subject and stays admitted" test-fixture-d6-nf-fixture.sh ignored

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
    echo "check-suite-leaf: --self-test FAILED ($fails of 20 fixture classes misclassified)"
    rc=1
  else
    echo "check-suite-leaf: --self-test OK (20/20 fixture classes classified correctly)"
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
