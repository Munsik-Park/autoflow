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
# Usage:
#   bash scripts/test/check-step-reconciliation.sh \
#        [--selected <file|->] [--steps <file|->] [--governed <path>]... [--self-test]
#
# One `MISMATCH: <path> selected=… outcome=…` line per disagreement.
# Exit 0 on agreement, 1 on any mismatch, 2 usage.
# =============================================================================

set -uo pipefail

MODE="default"
SELECTED_FILE=""
STEPS_FILE=""
GOVERNED_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --selected)  SELECTED_FILE="${2:-}"; shift ;;
    --steps)     STEPS_FILE="${2:-}"; shift ;;
    --governed)  GOVERNED_ARGS+=("${2:-}"); shift ;;
    *)           echo "check-step-reconciliation: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# step_id_of <repo-relative suite path> — the `id` a governed step carries.
step_id_of() {
  local base="${1##*/}"
  printf 's-%s\n' "${base%.*}"
}

# ---------------------------------------------------------------------------
# reconcile <selected-file> <steps-file> [<governed path>...]
# ---------------------------------------------------------------------------
reconcile() {
  local sel="$1" steps="$2"; shift 2
  local mismatches=0 line path state id outcome

  local sel_body steps_body
  if [ "$sel" = "-" ]; then sel_body="$(cat)"; else sel_body="$(cat "$sel" 2>/dev/null)"; fi
  if [ "$steps" = "-" ]; then steps_body="$(cat)"; else steps_body="$(cat "$steps" 2>/dev/null)"; fi

  if ! printf '%s' "$steps_body" | jq -e . >/dev/null 2>&1; then
    echo "check-step-reconciliation: the step-outcome input is not valid JSON" >&2
    return 1
  fi

  # hosted_here <suite path> — the job's step context carries this suite's id.
  hosted_here() {
    printf '%s' "$steps_body" | jq -e --arg k "$(step_id_of "$1")" 'has($k)' >/dev/null 2>&1
  }

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
      hosted_here "$path" || continue
    fi

    id="$(step_id_of "$path")"
    outcome="$(printf '%s' "$steps_body" | jq -r --arg k "$id" '.[$k].outcome // "absent"')"

    if [ "$state" = selected ]; then
      case "$outcome" in
        success|failure) ;;
        skipped)
          echo "MISMATCH: $path selected=yes outcome=skipped (a selected suite was skipped — the guard evaluated false)"
          mismatches=$((mismatches + 1)) ;;
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

  rm -rf "$dir"
  if [ "$fails" -ne 0 ]; then
    echo "check-step-reconciliation: --self-test FAILED ($fails of 6 fixture classes misclassified)"
    rc=1
  else
    echo "check-step-reconciliation: --self-test OK (6/6 fixture classes classified correctly)"
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

if reconcile "$SELECTED_FILE" "$STEPS_FILE" "${GOVERNED_ARGS[@]+"${GOVERNED_ARGS[@]}"}"; then
  echo "check-step-reconciliation: OK — the run's selection and its step outcomes agree"
  exit 0
fi
echo "check-step-reconciliation: the run's selection and its own step outcomes disagree"
echo "  A selected suite that CI skipped is a wrongly-false if: guard, not a green run."
exit 1
