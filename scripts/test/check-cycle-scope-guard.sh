#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-cycle-scope-guard.sh — standing lint: a cycle-scoped path allow-list
# must be branch-scoped by construction.
# =============================================================================
# Subject: every tests/test-issue-*.sh declaring a path allow-list array
# (`allow_list=(` / `ALLOWLIST_<name>=(`).
#
# The check is applied to the array's EVALUATION set, not to the array data:
# every dereference of the array, every `git diff --name-only` feeding it, and
# every `resolve_base_ref` invocation in the file must be dominated by a branch
# gate naming the file's own issue number in `dev/*-issue-<N>` form. The
# assignment (and any `+=` append) is excluded — an array literal is inert
# data, and both conforming suites in this tree assign above their gate.
#
# Why the file-scoped form ("does a gate exist in this file?") is rejected: a
# suite may carry an own-issue gate that dominates a DIFFERENT lane while the
# array's dereference runs unconditionally. Dominance is the property; gate
# co-presence is not.
#
# Gate spelling is not fixed: a plain `case "$HEAD_BRANCH"`, a suffixed
# `case "$HEAD_BRANCH_<N>"`, and a single-level predicate function wrapping
# either all count. The gate is matched on the `dev/*-issue-<N>` pattern, not
# on the variable's name.
#
# The complementary (off-branch) arm must reach `note_deferred` and must not
# assign TESTS/PASS/FAIL — an off-branch arm that credits a counter is a
# vacuous PASS, which is the class this lint exists to keep out of the tree.
#
# Usage:
#   bash scripts/test/check-cycle-scope-guard.sh [--self-test]
#
# The default run performs the self-test first, so a run whose subject set is
# empty still exercises the detector.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---------------------------------------------------------------------------
# analyze_file <path> <issue-number>
#   Prints one `path:line: <reason>` record per violation. Exit status is
#   always 0; the caller counts the records.
# ---------------------------------------------------------------------------
analyze_file() {
  awk -v FILEPATH="$1" -v ISSUE="$2" '
    function is_comment(l) { return l ~ /^[[:space:]]*#/ }
    function strip(l)      { sub(/^[[:space:]]+/, "", l); return l }

    # --- pass 1 is done by the caller; this awk makes two passes itself -----
    {
      lines[NR] = $0
    }

    END {
      n = NR
      gate_pat = "dev/\\*-issue-" ISSUE "([^0-9]|$)"

      # ---- collect declared array names --------------------------------
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (is_comment(l)) continue
        if (match(l, /^[[:space:]]*(allow_list|ALLOWLIST_[0-9A-Za-z_]+)=\(/)) {
          name = strip(substr(l, RSTART, RLENGTH))
          sub(/=\(.*$/, "", name)
          arrays[name] = 1
        }
      }
      if (length(arrays) == 0) exit 0

      # ---- collect single-level predicate functions whose body gates ----
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (is_comment(l)) continue
        if (match(l, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/)) {
          fname = strip(l); sub(/\(\).*$/, "", fname)
          gates_here = 0
          for (j = i + 1; j <= n; j++) {
            if (lines[j] ~ /^\}/) break
            if (!is_comment(lines[j]) && lines[j] ~ gate_pat) gates_here = 1
          }
          if (gates_here) preds[fname] = 1
        }
      }

      # ---- mark gated lines and collect complementary arms --------------
      depth = 0
      gate_depth = -1            # depth at which the active gate opened
      gate_kind = ""             # "if" | "arm"
      have_gate = 0
      comp_seen = 0              # a complementary arm was observed
      comp_deferred = 0
      comp_credits = 0
      in_comp = 0
      comp_depth = -1

      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (is_comment(l) || l ~ /^[[:space:]]*$/) { gated[i] = have_gate; continue }
        s = strip(l)

        # --- closers ---------------------------------------------------
        if (s ~ /^(fi|esac|done)([[:space:]]|;|$)/) {
          if (in_comp && depth == comp_depth) in_comp = 0
          depth--
          if (have_gate && depth < gate_depth) { have_gate = 0; gate_depth = -1 }
          gated[i] = have_gate
          continue
        }

        # --- case-arm terminator ---------------------------------------
        if (s ~ /^;;[[:space:]]*$/) {
          if (have_gate && gate_kind == "arm" && depth == gate_depth) {
            have_gate = 0; gate_depth = -1
          }
          if (in_comp && depth == comp_depth) in_comp = 0
          gated[i] = have_gate
          continue
        }

        # --- else / elif: the complementary arm of an if-gate -----------
        if (s ~ /^(else|elif)([[:space:]]|;|$)/) {
          if (have_gate && gate_kind == "if" && depth == gate_depth) {
            have_gate = 0; gate_depth = -1
            in_comp = 1; comp_depth = depth; comp_seen = 1
          }
          gated[i] = have_gate
          continue
        }

        if (in_comp) {
          if (l ~ /note_deferred/) comp_deferred = 1
          if (l ~ /(TESTS|PASS|FAIL)=/) comp_credits = 1
        }

        gated[i] = have_gate

        # --- openers ---------------------------------------------------
        opened = 0
        if (s ~ /^case[[:space:]].*[[:space:]]in[[:space:]]*$/) { depth++; opened = 1; in_case[depth] = 1 }
        else if (s ~ /^(if|while|until|for)([[:space:]]|$)/) {
          depth++; opened = 1
          # an if whose condition applies a gating predicate function
          for (fn in preds) {
            if (s ~ ("^if[[:space:]]+(!?[[:space:]]*)?" fn "([[:space:]]|;|$)")) {
              if (!have_gate) { have_gate = 1; gate_depth = depth; gate_kind = "if" }
            }
          }
          # an if whose own condition names the branch pattern directly
          if (!have_gate && s ~ gate_pat) { have_gate = 1; gate_depth = depth; gate_kind = "if" }
        }

        # --- case arms -------------------------------------------------
        if (!opened && depth > 0 && in_case[depth] && s ~ /\)[[:space:]]*$/) {
          if (s ~ gate_pat) {
            if (!have_gate) { have_gate = 1; gate_depth = depth; gate_kind = "arm" }
            in_comp = 0
          } else if (s ~ /^(\*|\*\))/ || s ~ /^\*\)/) {
            in_comp = 1; comp_depth = depth; comp_seen = 1
          }
        }
      }

      # ---- report violations over the evaluation set --------------------
      for (i = 1; i <= n; i++) {
        l = lines[i]
        if (is_comment(l)) continue
        why = ""
        for (name in arrays) {
          # the assignment and any += append are excluded by construction
          if (l ~ ("^[[:space:]]*" name "\\+?=\\(")) continue
          if (l ~ ("\\$\\{" name "\\[")) why = "ungated dereference of " name
        }
        if (why == "" && l ~ /git[[:space:]]+diff[[:space:]]+--name-only/) why = "ungated git diff --name-only feeding a path allow-list"
        if (why == "" && l ~ /resolve_base_ref/ && l !~ /^[[:space:]]*(\.|source)[[:space:]]/ && l !~ /resolve_base_ref\(\)/) why = "ungated resolve_base_ref invocation"
        if (why == "") continue
        if (!gated[i]) printf "%s:%d: %s (not dominated by a dev/*-issue-%s gate)\n", FILEPATH, i, why, ISSUE
      }

      if (comp_seen && !comp_deferred)
        printf "%s:0: the gate'"'"'s off-branch arm does not reach note_deferred\n", FILEPATH
      if (comp_seen && comp_credits)
        printf "%s:0: the gate'"'"'s off-branch arm credits TESTS/PASS/FAIL (uncounted-marker property violated)\n", FILEPATH
    }
  ' "$1"
}

# ---------------------------------------------------------------------------
# check_tree <root> — returns 0 when every subject file conforms.
# ---------------------------------------------------------------------------
check_tree() {
  local root="$1" violations=0 subjects=0 f base issue out
  for f in "$root"/tests/test-issue-*.sh; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    issue="$(printf '%s' "$base" | sed -n 's/^test-issue-\([0-9][0-9]*\)-.*$/\1/p')"
    [ -n "$issue" ] || continue
    grep -qE '^[[:space:]]*(allow_list|ALLOWLIST_[0-9A-Za-z_]+)=\(' "$f" || continue
    subjects=$((subjects + 1))
    out="$(analyze_file "$f" "$issue")"
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      violations=$((violations + $(printf '%s\n' "$out" | grep -c .)))
    fi
  done
  LAST_SUBJECT_COUNT="$subjects"
  LAST_VIOLATION_COUNT="$violations"
  [ "$violations" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Self-test — one fixture per named false-negative / false-positive class.
# ---------------------------------------------------------------------------
FIXTURE_HEAD='#!/usr/bin/env bash
set -uo pipefail
PROJECT_ROOT=.
note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }
assert_true() { TESTS=$((TESTS + 1)); }
HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
'

write_fixture() { # <dir> <basename> <body>
  printf '%s%s\n' "$FIXTURE_HEAD" "$3" > "$1/$2"
}

self_test() {
  local dir rc=0 fails=0
  dir="$(mktemp -d)"
  mkdir -p "$dir/tests"
  trap 'rm -rf "$dir"' RETURN

  expect() { # <label> <fixture-basename> <expected: ok|violation>
    local label="$1" file="$2" want="$3" out
    out="$(analyze_file "$dir/tests/$file" "$(printf '%s' "$file" | sed -n 's/^test-issue-\([0-9][0-9]*\)-.*$/\1/p')")"
    if [ "$want" = ok ] && [ -n "$out" ]; then
      echo "  SELF-TEST FAIL: $label — expected conforming, got:"; printf '%s\n' "$out" | sed 's/^/    /'
      fails=$((fails + 1))
    elif [ "$want" = violation ] && [ -z "$out" ]; then
      echo "  SELF-TEST FAIL: $label — expected a violation, got none"
      fails=$((fails + 1))
    else
      echo "  SELF-TEST PASS: $label"
    fi
  }

  # (1) conforming, plain case gate, array assigned ABOVE the gate (the 67 shape)
  write_fixture "$dir/tests" test-issue-1001-conforming-case.sh '
allow_list=(
  "a.txt"
)
case "$HEAD_BRANCH" in
  dev/*-issue-1001|dev/*-issue-1001-*)
    BASE_REF="$(resolve_base_ref)"
    DIFF_FILES="$(git diff --name-only "$BASE_REF"...HEAD)"
    UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
    assert_true "scope" "[ -z \"$UNCOVERED\" ]"
    ;;
  *)
    note_deferred "scope: inert off the issue-1001 dev branch"
    ;;
esac
'
  expect "conforming: array assigned above a plain case gate (67 shape)" test-issue-1001-conforming-case.sh ok

  # (2) conforming, predicate-function gate; base-ref resolved under a DIFFERENT
  #     application of the same predicate (the 69 shape)
  write_fixture "$dir/tests" test-issue-1002-conforming-pred.sh '
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-1002|dev/*-issue-1002-*) return 0 ;;
    *) return 1 ;;
  esac
}
if on_issue_branch; then
  BASE_REF="$(resolve_base_ref)"
else
  note_deferred "rubric: inert off the issue-1002 dev branch"
fi
allow_list=(
  "a.txt"
)
if on_issue_branch; then
  DIFF_FILES="$(git diff --name-only "$BASE_REF"...HEAD)"
  UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
  assert_true "scope" "[ -z \"$UNCOVERED\" ]"
else
  note_deferred "scope: inert off the issue-1002 dev branch"
fi
'
  expect "conforming: predicate-function gate, base ref under a different application (69 shape)" test-issue-1002-conforming-pred.sh ok

  # (3) violating, no gate at all
  write_fixture "$dir/tests" test-issue-1003-no-gate.sh '
allow_list=(
  "a.txt"
)
BASE_REF="$(resolve_base_ref)"
DIFF_FILES="$(git diff --name-only "$BASE_REF"...HEAD)"
UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
assert_true "scope" "[ -z \"$UNCOVERED\" ]"
'
  expect "violating: no branch gate at all" test-issue-1003-no-gate.sh violation

  # (4) violating, array assigned INSIDE the gate but dereferenced outside it
  write_fixture "$dir/tests" test-issue-1004-deref-outside.sh '
case "$HEAD_BRANCH" in
  dev/*-issue-1004|dev/*-issue-1004-*)
    allow_list=(
      "a.txt"
    )
    ;;
  *)
    note_deferred "scope: inert off the issue-1004 dev branch"
    ;;
esac
DIFF_FILES="$(git diff --name-only HEAD)"
UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
assert_true "scope" "[ -z \"$UNCOVERED\" ]"
'
  expect "violating: assignment gated, evaluation outside the gate" test-issue-1004-deref-outside.sh violation

  # (5) violating, gate present but dominating a DIFFERENT lane (the 52 shape)
  write_fixture "$dir/tests" test-issue-1005-other-lane.sh '
case "$HEAD_BRANCH" in
  dev/*-issue-1005|dev/*-issue-1005-*)
    assert_true "some other lane" "true"
    ;;
  *)
    note_deferred "some other lane: inert off the issue-1005 dev branch"
    ;;
esac
ALLOWLIST_1005=(
  "a.txt"
)
DIFF_FILES="$(git diff --name-only HEAD)"
UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${ALLOWLIST_1005[@]}"))"
assert_true "scope" "[ -z \"$UNCOVERED\" ]"
'
  expect "violating: gate dominates a different lane (52 shape)" test-issue-1005-other-lane.sh violation

  # (6) violating, resolve_base_ref outside every own-issue gate while the array
  #     lane itself is gated
  write_fixture "$dir/tests" test-issue-1006-ungated-baseref.sh '
allow_list=(
  "a.txt"
)
BASE_REF="$(resolve_base_ref)"
case "$HEAD_BRANCH" in
  dev/*-issue-1006|dev/*-issue-1006-*)
    DIFF_FILES="$(git diff --name-only "$BASE_REF"...HEAD)"
    UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
    assert_true "scope" "[ -z \"$UNCOVERED\" ]"
    ;;
  *)
    note_deferred "scope: inert off the issue-1006 dev branch"
    ;;
esac
'
  expect "violating: ungated resolve_base_ref while the array lane is gated" test-issue-1006-ungated-baseref.sh violation

  # (7) violating, gate dominates the dereference but the off-branch arm credits
  #     TESTS/PASS instead of emitting an uncounted marker
  write_fixture "$dir/tests" test-issue-1007-counted-offarm.sh '
allow_list=(
  "a.txt"
)
case "$HEAD_BRANCH" in
  dev/*-issue-1007|dev/*-issue-1007-*)
    BASE_REF="$(resolve_base_ref)"
    DIFF_FILES="$(git diff --name-only "$BASE_REF"...HEAD)"
    UNCOVERED="$(comm -23 <(printf "%s\n" "$DIFF_FILES") <(printf "%s\n" "${allow_list[@]}"))"
    assert_true "scope" "[ -z \"$UNCOVERED\" ]"
    ;;
  *)
    echo "  PASS (vacuous): scope guard off-branch"
    TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
    ;;
esac
'
  expect "violating: off-branch arm credits TESTS/PASS instead of note_deferred" test-issue-1007-counted-offarm.sh violation

  if [ "$fails" -ne 0 ]; then
    echo "check-cycle-scope-guard: --self-test FAILED ($fails of 7 fixture classes misclassified)"
    rc=1
  else
    echo "check-cycle-scope-guard: --self-test OK (7/7 fixture classes classified correctly)"
  fi
  return $rc
}

# ---------------------------------------------------------------------------
main() {
  if [ "${1:-}" = "--self-test" ]; then
    self_test
    exit $?
  fi

  # The default run performs the self-test first, so a run whose subject set is
  # empty still exercises the detector.
  if ! self_test; then
    echo "check-cycle-scope-guard: detector self-test failed — real-tree result not reported"
    exit 1
  fi

  LAST_SUBJECT_COUNT=0
  LAST_VIOLATION_COUNT=0
  if check_tree "$PROJECT_ROOT"; then
    echo "check-cycle-scope-guard: OK — $LAST_SUBJECT_COUNT allow-list-bearing suite(s), every evaluation branch-scoped to its own cycle"
    exit 0
  fi
  echo "check-cycle-scope-guard: $LAST_VIOLATION_COUNT violation(s) across $LAST_SUBJECT_COUNT allow-list-bearing suite(s)"
  echo "  A cycle-scoped path allow-list must be evaluated only on its own dev/*-issue-<N> branch;"
  echo "  off-branch it must emit an uncounted note_deferred marker. See docs/doc-invariant-registry.md §2."
  exit 1
}

main "$@"
