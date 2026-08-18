#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-step-reconciliation.sh — a run reconciles its own selection against its
# own step outcomes.
# =============================================================================
# A step whose `if:` guard evaluates false is SKIPPED, and its job still
# concludes successfully — so a green run is precisely what a wrongly-false
# guard produces, and enforcement in this repository is advisory with no
# required status check behind it. Static shape checking (which
# scripts/test/check-suite-manifest.sh performs) cannot observe evaluation, so
# each umbrella workflow ends with an `if: always()` step that hands this script
# the `select` step's own report and the job's own `toJSON(steps)` outcome map.
#
# The comparison is between the run's two records, so it needs no second source
# of truth, and it is falsifiable locally against synthetic step-outcome JSON.
#
# GOVERNED SET — a step is reconciled only when it maps to a suite the selection
# report actually recorded. The standing-lint steps and the registry-runner step
# run unconditionally and appear in `steps` with outcome `success` while sitting
# in no SELECTED:/NOT-SELECTED: record; reconciling them would red every correct
# run. `--governed` narrows the set explicitly when a caller needs to.
#
# JOB-LOCAL NARROWING — the two inputs are not the same width. The selection
# report is TREE-WIDE (select-suites.sh enumerates every governed suite in the
# repository), while `toJSON(steps)` is JOB-LOCAL (only the steps of the job
# that produced it). The 63 governed suites are hosted across five workflows, so
# a suite this job does not host is legitimately absent from this job's outcome
# map — reconciling it as a missing step reds every job of every workflow on
# every run, which is the state issue #103's GATE:QUALITY caught (F1).
#
# So when no `--governed` is given, the governed set is derived from the outcome
# map itself: a report entry is reconciled when the job's step context carries
# its `id`. That is the only job-local signal the script is handed, and it is
# per-job by construction rather than by a hand-maintained list that would drift
# from the steps above it in the same file.
#
# Silence is not agreement: a governed suite absent from the outcome map
# entirely — the missing-`id` case, invisible to `toJSON(steps)` — is a
# mismatch, not a pass. Under the derivation above that class is unobservable
# for a single suite (an id-less step and a step hosted elsewhere are the same
# absence), with two things holding it: (a) when the outcome map resolves NO
# entry of the report there is no job-local view to narrow to, so the whole
# report is reconciled and the absence still reds; (b) the per-step form of the
# class is enforced statically — check-suite-manifest.sh requires an `id:` on
# every governed step and fails the build without one. An explicit `--governed`
# set restores the runtime detection for a caller that can name its own suites.
#
# STEP ID CONVENTION — a governed step's `id` is `s-<basename without
# extension>`, which is how an outcome key resolves back to a suite path.
#
# CASCADE SKIPS — GitHub puts an implicit `success() &&` on every step, so once
# one step fails each later governed step is SKIPPED without its guard ever
# being evaluated. Grading those as wrongly-false guards produces one wrong
# diagnosis per remaining suite on top of one real failure. A selected suite
# whose outcome is `skipped` is therefore reported `CASCADE-SKIP` rather than
# `MISMATCH` when the run is already failing, on either of two independent
# signals: the job status handed in by `--job-status`, or a `failure` /
# `cancelled` value anywhere in the outcome map. Neither subsumes the other —
# the standing-lint steps carry no `id:` and so contribute nothing to
# `toJSON(steps)`, which is invisible to the map arm, while a local run or a
# fixture has no job status to hand in. The class does not change the exit
# status: it is only ever reached on a run that is already red.
#
# Usage:
#   bash scripts/test/check-step-reconciliation.sh \
#        [--selected <file|->] [--steps <file|->] [--governed <path>]... \
#        [--job-status <success|failure|cancelled>] [--self-test]
#
# EVIDENCE IS A PRECONDITION, NOT AN OUTCOME. Zero evidence is not agreement:
# an unreadable report, a report carrying the selector's own `BLOCK:` line, a
# report parsing to no record, and a `--governed` set intersecting the report in
# nothing each fail before the comparison, with a message of their own. Each is
# a state the old absorption (`cat … 2>/dev/null` plus a loop that never ran)
# reported as `OK — the run's selection and its step outcomes agree`.
#
# BOUNDARY ACCOUNTING — under job-local narrowing a record hosted by another
# workflow is reported `OUT-OF-JOB: <path> selected=<yes|no>` rather than
# dropped in silence. This is deliberately NOT a failure: a job-local input
# cannot decide a cross-job fact, and inventing a cross-job source of truth
# would re-introduce the hand-maintained list this header rejects. The boundary
# itself is guaranteed statically, by the registration and coverage lints.
#
# One `MISMATCH: <path> selected=… outcome=…` line per disagreement.
# Exit 0 on agreement, 1 on any mismatch or on a failed evidence precondition,
# 2 usage.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

MODE="default"
SELECTED_FILE=""
STEPS_FILE=""
JOB_STATUS=""
GOVERNED_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test)  MODE="self-test" ;;
    --selected)   require_value check-step-reconciliation "$1" $# "${2:-}" || exit 2; SELECTED_FILE="$2"; shift ;;
    --steps)      require_value check-step-reconciliation "$1" $# "${2:-}" || exit 2; STEPS_FILE="$2"; shift ;;
    --governed)   require_value check-step-reconciliation "$1" $# "${2:-}" || exit 2; GOVERNED_ARGS+=("$2"); shift ;;
    --job-status) require_value check-step-reconciliation "$1" $# "${2:-}" || exit 2; JOB_STATUS="$2"; shift ;;
    *)            echo "check-step-reconciliation: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# reconcile <selected-file> <steps-file> [<governed path>...]
# ---------------------------------------------------------------------------
reconcile() {
  local sel="$1" steps="$2"; shift 2
  local mismatches=0 line path state id outcome
  RECONCILED_COUNT=0
  OUT_OF_JOB_COUNT=0
  CASCADE_SKIP_COUNT=0

  local sel_body steps_body
  # An unreadable report is the ABSENCE of evidence, not agreement. The former
  # `cat … 2>/dev/null` absorbed the read failure into an empty body, and the
  # comparison below then found no records and returned success — so a run whose
  # select step never produced a report reported OK.
  if [ "$sel" = "-" ]; then
    sel_body="$(cat)"
  elif [ ! -r "$sel" ]; then
    echo "check-step-reconciliation: the selection report is unreadable: $sel" >&2
    echo "  There is nothing to reconcile against, which is not the same as agreement." >&2
    return 3
  else
    sel_body="$(cat "$sel")"
  fi
  if [ "$steps" = "-" ]; then steps_body="$(cat)"; else steps_body="$(cat "$steps" 2>/dev/null)"; fi

  if ! printf '%s' "$steps_body" | jq -e . >/dev/null 2>&1; then
    echo "check-step-reconciliation: the step-outcome input is not valid JSON" >&2
    return 1
  fi

  # The selector's own fail-loud output: a BLOCK means there is no selection to
  # reconcile. Reporting agreement over it states a comparison that never ran.
  if printf '%s\n' "$sel_body" | grep -q '^BLOCK:'; then
    echo "check-step-reconciliation: the selection report carries a BLOCK line — the selector refused to emit a selection, so there is no selection to reconcile" >&2
    printf '%s\n' "$sel_body" | grep '^BLOCK:' | sed 's/^/  /' >&2
    return 3
  fi

  # Zero records parsed. The script's contract is a comparison between two
  # records; it cannot be satisfied by one of them being empty.
  if ! printf '%s\n' "$sel_body" | grep -qE '^(SELECTED|NOT-SELECTED): '; then
    echo "check-step-reconciliation: the selection report parses to no SELECTED:/NOT-SELECTED: record — an empty report is the absence of evidence, not agreement" >&2
    return 3
  fi

  # `--governed` is the caller's own set. An empty intersection with the report
  # is a caller error, distinct from an empty report: the report parses fully
  # here, and it is the intersection that is empty.
  if [ $# -gt 0 ]; then
    local gp gfound=0
    for gp in "$@"; do
      printf '%s\n' "$sel_body" | grep -qE "^(SELECTED|NOT-SELECTED): ${gp}( |\$)" && gfound=1
    done
    if [ "$gfound" -eq 0 ]; then
      echo "check-step-reconciliation: the --governed set ($*) names no path the selection report records — the caller's set and the report do not overlap, so no comparison is possible" >&2
      return 3
    fi
  fi

  # hosted_here <suite path> — the job's step context carries this suite's id.
  hosted_here() {
    printf '%s' "$steps_body" | jq -e --arg k "$(suite_step_id "$1")" 'has($k)' >/dev/null 2>&1
  }

  # Is this run already failing? Evaluated once, before anything is graded.
  # Arm A is the job status the caller handed in; it is authoritative when
  # present, and an unrecognised value is read as "not failing" so an unparsed
  # status narrows the cascade class rather than widening it. Arm B reads the
  # outcome map, which keeps the script self-sufficient where no status is
  # available (a local run, a fixture).
  local cascade=0
  case "$JOB_STATUS" in
    failure|cancelled) cascade=1 ;;
  esac
  if [ "$cascade" -eq 0 ] && printf '%s' "$steps_body" \
     | jq -e 'any(.[]?; .outcome? == "failure" or .outcome? == "cancelled")' >/dev/null 2>&1; then
    cascade=1
  fi

  # Without an explicit `--governed` set, narrow to the suites this job hosts.
  # The fallback: a report none of whose entries the outcome map carries is not
  # a narrowed view of it, so reconcile the whole report (see JOB-LOCAL
  # NARROWING in the header).
  local narrow=0
  if [ $# -eq 0 ]; then
    while IFS= read -r line; do
      case "$line" in 'SELECTED: '*) path="${line#SELECTED: }" ;; 'NOT-SELECTED: '*) path="${line#NOT-SELECTED: }" ;; *) continue ;; esac
      path="${path%% *}"
      [ -n "$path" ] || continue
      if hosted_here "$path"; then narrow=1; break; fi
    done <<< "$sel_body"
  fi

  while IFS= read -r line; do
    case "$line" in
      'SELECTED: '*)     state=selected;   path="${line#SELECTED: }" ;;
      'NOT-SELECTED: '*) state=unselected; path="${line#NOT-SELECTED: }" ;;
      *) continue ;;
    esac
    path="${path%% *}"
    [ -n "$path" ] || continue

    # `--governed`, when given, is the authoritative set; otherwise the job's
    # own step context is.
    if [ $# -gt 0 ]; then
      local g found=0
      for g in "$@"; do [ "$g" = "$path" ] && found=1; done
      [ "$found" -eq 1 ] || continue
    elif [ "$narrow" -eq 1 ]; then
      # A record this job's step context does not carry is dropped — but the
      # drop is stated rather than silent. A single job cannot decide whether
      # the suite ran somewhere else, so this is not a failure; what the line
      # buys is that the boundary is visible in the log, where a false green
      # would otherwise be indistinguishable from a narrow, correct run.
      if ! hosted_here "$path"; then
        echo "OUT-OF-JOB: $path selected=$([ "$state" = selected ] && echo yes || echo no) (hosted by another workflow — this job's step context cannot judge it)"
        OUT_OF_JOB_COUNT=$((OUT_OF_JOB_COUNT + 1))
        continue
      fi
    fi

    RECONCILED_COUNT=$((RECONCILED_COUNT + 1))
    id="$(suite_step_id "$path")"
    outcome="$(printf '%s' "$steps_body" | jq -r --arg k "$id" '.[$k].outcome // "absent"')"

    if [ "$state" = selected ]; then
      case "$outcome" in
        success|failure) ;;
        skipped)
          if [ "$cascade" -eq 1 ]; then
            echo "CASCADE-SKIP: $path selected=yes outcome=skipped (a preceding step failed — this run cannot observe the guard's own evaluation)"
            CASCADE_SKIP_COUNT=$((CASCADE_SKIP_COUNT + 1))
          else
            echo "MISMATCH: $path selected=yes outcome=skipped (a selected suite was skipped — the guard evaluated false)"
            mismatches=$((mismatches + 1))
          fi ;;
        absent)
          echo "MISMATCH: $path selected=yes outcome=absent (no step outcome — the step carries no id, so it is invisible to toJSON(steps))"
          mismatches=$((mismatches + 1)) ;;
        *)
          echo "MISMATCH: $path selected=yes outcome=$outcome (unexpected outcome for a selected suite)"
          mismatches=$((mismatches + 1)) ;;
      esac
    else
      case "$outcome" in
        skipped|absent) ;;
        *)
          echo "MISMATCH: $path selected=no outcome=$outcome (an unselected suite ran)"
          mismatches=$((mismatches + 1)) ;;
      esac
    fi
  done <<< "$sel_body"

  [ "$mismatches" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Self-test — synthetic step-outcome JSON, one fixture per named class. A live
# CI run supplies real outcomes; only these fixtures discriminate a working
# reconciler from an inert one.
# ---------------------------------------------------------------------------
self_test() {
  local dir rc=0 fails=0 sel steps
  dir="$(mktemp -d)"
  sel="$dir/selected"; steps="$dir/steps"

  expect() { # <label> <expected: agree|mismatch>
    local label="$1" want="$2"
    if reconcile "$sel" "$steps" >/dev/null 2>&1; then
      if [ "$want" = agree ]; then echo "  SELF-TEST PASS: $label"
      else echo "  SELF-TEST FAIL: $label — expected a mismatch, got agreement"; fails=$((fails + 1)); fi
    else
      if [ "$want" = mismatch ]; then echo "  SELF-TEST PASS: $label"
      else echo "  SELF-TEST FAIL: $label — expected agreement, got a mismatch"; fails=$((fails + 1)); fi
    fi
  }

  printf 'SELECTED: tests/test-fixture-recon.sh\n' > "$sel"
  printf '{"s-test-fixture-recon": {"outcome": "success"}}\n' > "$steps"
  expect "selected suite that ran -> agreement" agree

  printf '{"s-test-fixture-recon": {"outcome": "skipped"}}\n' > "$steps"
  expect "selected suite skipped (wrongly-false guard) -> mismatch" mismatch

  printf '{}\n' > "$steps"
  expect "selected suite absent from the outcome map (missing id) -> mismatch" mismatch

  printf 'NOT-SELECTED: tests/test-fixture-recon.sh no delta match\n' > "$sel"
  printf '{"s-test-fixture-recon": {"outcome": "success"}}\n' > "$steps"
  expect "unselected suite that ran -> mismatch" mismatch

  printf '{"s-test-fixture-recon": {"outcome": "skipped"}}\n' > "$steps"
  expect "unselected suite skipped -> agreement" agree

  # Governed-set boundary: unconditional standing-lint and registry-runner
  # steps sit in no selection record and must not reconcile as "ran while
  # unselected".
  printf 'SELECTED: tests/test-fixture-recon.sh\n' > "$sel"
  cat > "$steps" <<'JSON'
{
  "s-test-fixture-recon": {"outcome": "success"},
  "check-suite-ci-coverage": {"outcome": "success"},
  "run-doc-invariants": {"outcome": "success"}
}
JSON
  expect "ungoverned steps present in the outcome map -> agreement" agree

  # --- CASCADE SKIPS: a downstream skip after a failure is not a false guard --
  # The outcome-map arm only; the job-status arm is reachable solely through the
  # CLI flag loop, which self_test bypasses by calling reconcile directly.
  printf 'SELECTED: tests/test-fixture-recon.sh\n' > "$sel"
  cat > "$steps" <<'JSON'
{
  "s-upstream": {"outcome": "failure"},
  "s-test-fixture-recon": {"outcome": "skipped"}
}
JSON
  local casc_out
  casc_out="$(reconcile "$sel" "$steps" 2>&1)"
  if [ $? -eq 0 ] && printf '%s\n' "$casc_out" | grep -q '^CASCADE-SKIP: tests/test-fixture-recon.sh selected=yes outcome=skipped' \
     && ! printf '%s\n' "$casc_out" | grep -q 'MISMATCH'; then
    echo "  SELF-TEST PASS: a selected suite skipped downstream of a failing step is graded CASCADE-SKIP and does not change the exit code"
  else
    echo "  SELF-TEST FAIL: a selected suite skipped downstream of a failing step is graded CASCADE-SKIP and does not change the exit code — got: $casc_out"
    fails=$((fails + 1))
  fi

  # Under a cascade every other branch is unchanged: a failing run says nothing
  # about a step that carries no id at all, which is a static defect.
  printf '{"s-upstream": {"outcome": "failure"}}\n' > "$steps"
  expect "a cascading run carrying a selected suite absent from the outcome map -> mismatch" mismatch

  # --- EVIDENCE PRECONDITION: zero evidence is not agreement ---------------
  # Each arm asserts the non-zero exit AND a message of its own: a mismatch also
  # exits non-zero, so an arm reading only the code cannot tell "there was
  # nothing to reconcile" from "the two records disagreed".
  expect_precondition() { # <label> <selected-file> <pattern> [<governed path>...]
    local label="$1" selfile="$2" pattern="$3"; shift 3
    local out
    out="$(reconcile "$selfile" "$steps" "$@" 2>&1)"
    if [ $? -eq 3 ] && printf '%s\n' "$out" | grep -qiE "$pattern" \
       && ! printf '%s\n' "$out" | grep -q 'MISMATCH'; then
      echo "  SELF-TEST PASS: $label"
    else
      echo "  SELF-TEST FAIL: $label — expected a precondition failure naming its cause, got: $out"
      fails=$((fails + 1))
    fi
  }

  printf '{"s-test-fixture-recon": {"outcome": "success"}}\n' > "$steps"
  expect_precondition "an unreadable selection report -> precondition failure" "$dir/absent-report" 'unreadable'
  : > "$sel"
  expect_precondition "an empty selection report -> precondition failure" "$sel" 'no SELECTED'
  printf 'this is not a selection report\n' > "$sel"
  expect_precondition "an unparseable selection report -> precondition failure" "$sel" 'no SELECTED'
  printf 'BLOCK: no base ref resolvable\n' > "$sel"
  expect_precondition "a BLOCK-bearing selection report -> precondition failure" "$sel" 'BLOCK'

  printf 'SELECTED: tests/test-fixture-recon.sh\n' > "$sel"
  expect_precondition "a --governed set intersecting the report in nothing -> precondition failure" "$sel" 'governed' tests/test-fixture-absent-from-report.sh

  # --- BOUNDARY ACCOUNTING: an out-of-job record is reported, not dropped ---
  printf 'SELECTED: tests/test-fixture-recon.sh\nSELECTED: tests/test-fixture-elsewhere.sh\n' > "$sel"
  printf '{"s-test-fixture-recon": {"outcome": "success"}}\n' > "$steps"
  local ooj_out
  ooj_out="$(reconcile "$sel" "$steps" 2>&1)"
  if [ $? -eq 0 ] && printf '%s\n' "$ooj_out" | grep -q '^OUT-OF-JOB: tests/test-fixture-elsewhere.sh selected=yes'; then
    echo "  SELF-TEST PASS: an out-of-job record is reported under its own label and does not change the exit code"
  else
    echo "  SELF-TEST FAIL: an out-of-job record is reported under its own label and does not change the exit code — got: $ooj_out"
    fails=$((fails + 1))
  fi

  rm -rf "$dir"
  if [ "$fails" -ne 0 ]; then
    echo "check-step-reconciliation: --self-test FAILED ($fails of 14 fixture classes misclassified)"
    rc=1
  else
    echo "check-step-reconciliation: --self-test OK (14/14 fixture classes classified correctly)"
  fi
  return $rc
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if [ -z "$SELECTED_FILE" ] || [ -z "$STEPS_FILE" ]; then
  echo "check-step-reconciliation: both --selected and --steps are required" >&2
  exit 2
fi

reconcile "$SELECTED_FILE" "$STEPS_FILE" "${GOVERNED_ARGS[@]+"${GOVERNED_ARGS[@]}"}"
RC=$?
if [ "$RC" -eq 0 ]; then
  # The success line states WHAT WAS COMPARED rather than asserting agreement in
  # the abstract, so a reader can tell a real comparison from a vacuous one
  # without reading the exit code alone.
  echo "check-step-reconciliation: OK — $RECONCILED_COUNT record(s) reconciled against this job's step outcomes, $OUT_OF_JOB_COUNT out-of-job entr(y|ies) reported, $CASCADE_SKIP_COUNT cascade skip(s) reported"
  exit 0
fi
if [ "$RC" -eq 3 ]; then
  echo "check-step-reconciliation: the evidence precondition failed — no comparison ran (see the message above)"
  exit 1
fi
echo "check-step-reconciliation: the run's selection and its own step outcomes disagree"
echo "  A selected suite that CI skipped is a wrongly-false if: guard, not a green run."
# The aggregate is owed on every path the reconciliation loop ran, not only on
# the agreeing one: the realistic CI shape is a real failure cascading a roster
# that also carries a genuine disagreement, which exits here.
echo "  $CASCADE_SKIP_COUNT cascade skip(s) reported — a suite skipped downstream of a failing step is graded separately, since this run cannot observe its guard."
exit 1
