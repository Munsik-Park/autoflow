#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml .github/workflows/e2e-dummy-target.yml
# =============================================================================
# Test: push-trigger base-ref resolution — Issue #85 AC-main-green (standing)
# =============================================================================
# .autoflow/issue-85-verification-design.md > AC-main-green:
#   Subject set = every spec that (a) is registered by a `run:` step of a
#   workflow carrying `push: branches: [main]`, AND (b) calls
#   resolve_base_ref or `git merge-base` against the repository under test —
#   a call site, not a `source` line (derived every run, never hardcoded).
#   Oracle: in a scratch clone with GITHUB_BASE_REF unset and origin/main ==
#   HEAD (the push-trigger resolution: `merge-base HEAD origin/main` ==
#   HEAD), each subject must exit 0.
#   Attribution: on a subject FAIL, re-run that one subject with origin/main
#   pinned at the branch point instead. PASS there => a push-context defect
#   this layer owns (FAIL-PUSH-CONTEXT). FAIL there too => a pre-existing
#   defect owned by the subject's own `run:` step; this layer reports it
#   (UNATTRIBUTABLE) and does not claim it — does not fail this layer's exit.
#   Budget: exactly one execution per subject on the green path; the
#   branch-point re-run is failure-only; each execution is wrapped in a
#   per-subject timeout so one hung subject cannot stall the step.
#
# This is a STANDING suite (subject-named, no issue number — the naming rule
# docs/autoflow-guide.md > RED adds this cycle): the property is a permanent
# tree/CI-registration STATE, not this cycle's own landed state. Its `run:`
# step and `paths:` entries are added PERMANENTLY to both workflows named
# above (ci-subject).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# This suite's own repo-relative path — computed, not a literal filename, so
# the self-exemption below tracks a rename automatically. Used to keep this
# suite out of its own derived subject set (see derive_subjects): it is
# registered by a run: step in a push:branches:[main] workflow AND it itself
# calls `git merge-base` (make_scratch_branch_point_context, below) against
# the repository under test, so both derivation criteria are structurally
# always true for it. A child invocation of the parent, capped at the same
# per-subject budget, cannot finish inside that budget (it has to run its own
# nested subject sweep first) — the parent would then always record TIMEOUT
# for itself, at any budget value. Self-identity only: this does not exempt
# any other subject.
SELF_REL="tests/$(basename "${BASH_SOURCE[0]}")"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Issue #85 AC-main-green — push-context base-ref resolution (standing) ==="

TMP_ROOT="$PROJECT_ROOT/tests/fixtures/.tmp-push-context-base-ref-$$"
cleanup() { rm -rf "$TMP_ROOT" 2>/dev/null || true; }
trap cleanup EXIT
mkdir -p "$TMP_ROOT"

# Default budget derived from a real measurement, not a guess: several subjects
# in the current subject set are themselves meta-suites that re-invoke other
# full suites (e.g. tests/test-issue-62-sequential-rounds.sh's AC-62-24 loop
# shells out to tests/test-issue-59-adoption-evidence-discipline.sh [real
# 80.81s] and tests/test-issue-27-composition-oracle.sh [real 41.38s], and its
# own uninterrupted run measured real 412.74s / exit 1 — a legitimate,
# non-hung completion, not a hang]. tests/test-issue-69-verification-depth.sh
# transitively sweeps the same heavy homes via its own pin-consistency sweep
# (grep across tests/*.sh for a shared literal token — deliberately not
# spelled out here in that literal's own shape: this file is itself a
# tests/*.sh suite, and writing the literal here would make this comment a
# false-positive match of that sweep's own selection grep, pulling this file
# into a recursive self-clone-and-run — measured: this is what actually made
# tests/test-issue-69-verification-depth.sh exceed 45 minutes before this
# comment was reworded). A 150s budget would misclassify these
# completing-but-slow subjects as TIMEOUT. 900s keeps more than 2x headroom
# over the slowest measured run while still bounding a genuinely hung
# subject.
PER_SUBJECT_BUDGET_SECS="${PUSH_CONTEXT_BUDGET_SECS:-900}"

# ---------------------------------------------------------------------------
# Bounded execution (per tests/test-issue-25-confirm-ci-green.sh run_bounded):
# prefer timeout/gtimeout; else a sleep+kill fallback. Runs "$@" with CWD
# "$2" and GITHUB_BASE_REF unset (the pull_request-only env var must not leak
# into a push-context reproduction). Sets RB_EXIT / RB_KILLED.
# ---------------------------------------------------------------------------
run_bounded_in() {
  local bound="$1" dir="$2" logfile="$3"; shift 3
  RB_KILLED=0
  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi
  if [ -n "$timeout_bin" ]; then
    ( cd "$dir" && env -u GITHUB_BASE_REF "$timeout_bin" "$bound" "$@" ) >"$logfile" 2>&1
    RB_EXIT=$?
    [ "$RB_EXIT" -eq 124 ] && RB_KILLED=1
  else
    ( cd "$dir" && env -u GITHUB_BASE_REF "$@" ) >"$logfile" 2>&1 &
    local pid=$!
    ( sleep "$bound"; if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo killed > "$logfile.watchdog"; fi ) &
    wait "$pid" 2>/dev/null
    RB_EXIT=$?
    if [ -s "$logfile.watchdog" ]; then RB_KILLED=1; fi
  fi
}

# ---------------------------------------------------------------------------
# Subject-set derivation — STATE, re-derived every run, never hardcoded.
# ---------------------------------------------------------------------------

# Hermetic-driver exemption: a call site that resolves only inside the
# driver's own scratch/fixture repositories is not a live-tree consumer.
# Grep cannot distinguish "resolves against the repo under test" from
# "resolves inside a git-init'd fixture dir" — the same class of exemption
# this tree already uses for suite-internal inventories (EXEMPT_WHOLE_FILES
# in tests/test-issue-71-digest-removal.sh, EXCLUDE_PATHSPEC in
# tests/test-issue-795-handoff-removal.sh). Every entry is justified by a
# comment naming the fixture-repo evidence.
EXEMPT_HERMETIC_DRIVERS=(
  # call sites operate on REPO_A..REPO_D, each git-init'd under this suite's
  # own TMP_ROOT — not the live tree under test (tests/test-run-doc-invariants.sh:583-636)
  "tests/test-run-doc-invariants.sh"
)
is_exempt_hermetic() {
  local rel="$1" x
  for x in "${EXEMPT_HERMETIC_DRIVERS[@]}"; do
    [ "$x" = "$rel" ] && return 0
  done
  return 1
}

derive_subjects() {
  local wf rel
  local -a wf_files=()
  for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
    grep -qE 'branches: *\[ *main *\]' "$wf" 2>/dev/null && wf_files+=("$wf")
  done
  for wf in "${wf_files[@]}"; do
    grep -oE 'run: *bash +tests/[A-Za-z0-9/_.-]+\.sh' "$wf" | sed -E 's/^run: *bash +//'
  done | sort -u | while read -r rel; do
    local abs="$PROJECT_ROOT/$rel"
    [ -f "$abs" ] || continue
    [ "$rel" = "$SELF_REL" ] && continue
    is_exempt_hermetic "$rel" && continue
    # Call-site criterion: a non-comment line invoking resolve_base_ref or
    # `git ... merge-base` (flags between `git` and `merge-base` allowed —
    # e.g. `git -C "$PROJECT_ROOT" merge-base HEAD main`). Naming the
    # resolver only in a comment (tests/test-issue-42-spawn-mode-contract.sh)
    # does not qualify.
    # Process substitution, not a pipe: under `set -o pipefail` (this script's
    # own top-of-file setting), feeding one filter's output straight into a
    # second, early-exiting `grep -qE` exits non-zero whenever that early exit
    # SIGPIPEs the first filter before it finishes writing — silently
    # dropping a true subject from derivation (measured: tests/test-issue-59-
    # adoption-evidence-discipline.sh, a real resolve_base_ref call site,
    # deterministically vanished from the derived set under this pattern).
    # `< <(...)` keeps the filter a single simple command so pipefail has
    # nothing to see.
    if grep -qE '\bresolve_base_ref\b|\bgit\b[^#]*\bmerge-base\b' < <(grep -vE '^\s*#' "$abs" 2>/dev/null); then
      printf '%s\n' "$rel"
    fi
  done
}

mapfile -t SUBJECTS < <(derive_subjects)

echo "Subject set (${#SUBJECTS[@]}): ${SUBJECTS[*]:-<none>}"
assert_true "subject-set derivation finds at least one push-context base-ref consumer (sanity — an empty set silently under-covers)" \
  "[ \"${#SUBJECTS[@]}\" -gt 0 ]"

# Regression guard: "at least one" alone does not catch a real subject being
# silently dropped while others still pass — exactly what the pipefail/SIGPIPE
# defect above did to this file's `derive_subjects` (deterministically
# measured this cycle). Pin a known real resolve_base_ref call site (a
# push:branches:[main] workflow registers it, and it calls the resolver
# against the repo under test at tests/test-issue-59-adoption-evidence-discipline.sh:76)
# so a reintroduction of that class of bug fails loud instead of just shrinking
# the printed count.
assert_true "subject-set derivation includes a known real call site (tests/test-issue-59-adoption-evidence-discipline.sh) — regression guard against silent under-derivation" \
  "grep -qxF 'tests/test-issue-59-adoption-evidence-discipline.sh' < <(printf '%s\n' \"\${SUBJECTS[@]}\")"

# ---------------------------------------------------------------------------
# Scratch contexts — isolated clones (never mutate this repo's own refs).
# push-context: origin/main and local main both == HEAD (reproduces the
# push-trigger resolution `merge-base HEAD origin/main` == HEAD).
# branch-point: both pinned at the merge-base with the real upstream
# origin/main (best-effort fallback: the root commit, when HEAD and
# origin/main already coincide — e.g. immediately after branch creation,
# nothing has diverged yet to probe).
# ---------------------------------------------------------------------------

make_scratch_push_context() {
  local dest="$1" head_sha
  git clone -q "$PROJECT_ROOT" "$dest" >/dev/null 2>&1 || return 1
  head_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
  git -C "$dest" checkout -q "$head_sha" >/dev/null 2>&1 \
    || git -C "$dest" checkout -q -b _push_ctx "$head_sha" >/dev/null 2>&1 || return 1
  git -C "$dest" update-ref refs/remotes/origin/main "$head_sha"
  git -C "$dest" branch -f main "$head_sha" >/dev/null 2>&1
}

make_scratch_branch_point_context() {
  local dest="$1" head_sha branch_point=""
  git clone -q "$PROJECT_ROOT" "$dest" >/dev/null 2>&1 || return 1
  head_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
  git -C "$dest" checkout -q "$head_sha" >/dev/null 2>&1 \
    || git -C "$dest" checkout -q -b _bp_ctx "$head_sha" >/dev/null 2>&1 || return 1
  if git -C "$PROJECT_ROOT" rev-parse --verify -q origin/main^{commit} >/dev/null 2>&1; then
    branch_point="$(git -C "$PROJECT_ROOT" merge-base HEAD origin/main 2>/dev/null || true)"
  fi
  if [ -z "$branch_point" ] || [ "$branch_point" = "$head_sha" ]; then
    branch_point="$(git -C "$dest" rev-list --max-parents=0 "$head_sha" 2>/dev/null | tail -1)"
  fi
  [ -n "$branch_point" ] || return 1
  git -C "$dest" update-ref refs/remotes/origin/main "$branch_point"
  git -C "$dest" branch -f main "$branch_point" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Judgment contract (verification design AC-main-green, GATE:PLAN risk) —
# a pure function so the report/exit contract is unit-testable independent
# of any real subject's current pass/fail status.
# ---------------------------------------------------------------------------

# compute_verdict <push_exit> <push_killed> <bp_available> [<bp_exit> <bp_killed>]
compute_verdict() {
  local push_exit="$1" push_killed="$2" bp_available="$3" bp_exit="${4:-}" bp_killed="${5:-}"
  if [ "$push_killed" = "1" ]; then echo "TIMEOUT"; return; fi
  if [ "$push_exit" = "0" ]; then echo "PASS"; return; fi
  if [ "$bp_available" != "1" ]; then echo "FAIL-PUSH-CONTEXT"; return; fi
  if [ "$bp_killed" = "1" ]; then echo "TIMEOUT"; return; fi
  if [ "$bp_exit" = "0" ]; then echo "FAIL-PUSH-CONTEXT"; return; fi
  echo "UNATTRIBUTABLE"
}

# exit_code_for_counts <fail_push_context_count> <timeout_count>
# UNATTRIBUTABLE never contributes — it is reported, not claimed.
exit_code_for_counts() {
  local failpc="$1" to="$2"
  if [ "$failpc" -gt 0 ] || [ "$to" -gt 0 ]; then echo 1; else echo 0; fi
}

echo ""
echo "=== judgment-contract self-tests (hermetic, synthetic exit/kill combinations) ==="

assert_true "judgment contract: push-context exit 0 -> PASS" \
  "[ \"\$(compute_verdict 0 0 1 0 0)\" = 'PASS' ]"
assert_true "judgment contract: push-context FAIL, branch-point PASS -> FAIL-PUSH-CONTEXT (attributed to this layer)" \
  "[ \"\$(compute_verdict 1 0 1 0 0)\" = 'FAIL-PUSH-CONTEXT' ]"
assert_true "judgment contract: push-context FAIL, branch-point FAIL too -> UNATTRIBUTABLE (pre-existing, reported not claimed)" \
  "[ \"\$(compute_verdict 1 0 1 1 0)\" = 'UNATTRIBUTABLE' ]"
assert_true "judgment contract: watchdog fires on the push-context run -> TIMEOUT, independent of any exit code" \
  "[ \"\$(compute_verdict 0 1 1 0 0)\" = 'TIMEOUT' ]"
assert_true "judgment contract: watchdog fires on the branch-point attribution run -> TIMEOUT, never silently folded into UNATTRIBUTABLE" \
  "[ \"\$(compute_verdict 1 0 1 1 1)\" = 'TIMEOUT' ]"
assert_true "judgment contract: attribution unavailable (no branch-point context) -> FAIL-PUSH-CONTEXT, never silently dropped" \
  "[ \"\$(compute_verdict 1 0 0)\" = 'FAIL-PUSH-CONTEXT' ]"
assert_true "judgment contract: overall exit is 0 iff both FAIL-PUSH-CONTEXT and TIMEOUT counts are 0" \
  "[ \"\$(exit_code_for_counts 0 0)\" = 0 ]"
assert_true "judgment contract: overall exit is non-zero when FAIL-PUSH-CONTEXT count > 0" \
  "[ \"\$(exit_code_for_counts 1 0)\" = 1 ]"
assert_true "judgment contract: overall exit is non-zero when TIMEOUT count > 0" \
  "[ \"\$(exit_code_for_counts 0 1)\" = 1 ]"
assert_true "judgment contract: UNATTRIBUTABLE count alone (0,0) never contributes to the exit code" \
  "[ \"\$(exit_code_for_counts 0 0)\" = 0 ]"

# ---------------------------------------------------------------------------
# Real subject-set execution.
# ---------------------------------------------------------------------------

echo ""
echo "=== subject execution (push-context reproduction, attribution on FAIL) ==="

PASS_N=0; FAILPC_N=0; UNATTR_N=0; TIMEOUT_N=0
BP_SCRATCH=""

if [ "${#SUBJECTS[@]}" -gt 0 ]; then
  PUSH_SCRATCH="$TMP_ROOT/push-ctx"
  if ! make_scratch_push_context "$PUSH_SCRATCH"; then
    echo "BLOCK: could not create the push-context scratch clone"
    FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1))
  else
    for rel in "${SUBJECTS[@]}"; do
      safe_name="$(printf '%s' "$rel" | tr '/' '_')"
      logf="$TMP_ROOT/log-${safe_name}.push.log"
      run_bounded_in "$PER_SUBJECT_BUDGET_SECS" "$PUSH_SCRATCH" "$logf" bash "$rel"
      push_exit="$RB_EXIT"; push_killed="$RB_KILLED"
      bp_available=0; bp_exit=""; bp_killed=""

      if [ "$push_killed" != "1" ] && [ "$push_exit" != "0" ]; then
        if [ -z "$BP_SCRATCH" ]; then
          BP_SCRATCH="$TMP_ROOT/branch-point-ctx"
          make_scratch_branch_point_context "$BP_SCRATCH" || BP_SCRATCH="__unavailable__"
        fi
        if [ "$BP_SCRATCH" != "__unavailable__" ]; then
          bp_available=1
          logf2="$TMP_ROOT/log-${safe_name}.bp.log"
          run_bounded_in "$PER_SUBJECT_BUDGET_SECS" "$BP_SCRATCH" "$logf2" bash "$rel"
          bp_exit="$RB_EXIT"; bp_killed="$RB_KILLED"
        fi
      fi

      verdict="$(compute_verdict "$push_exit" "$push_killed" "$bp_available" "$bp_exit" "$bp_killed")"
      echo "PUSH-CONTEXT: $rel $verdict"
      case "$verdict" in
        PASS) PASS_N=$((PASS_N + 1)) ;;
        FAIL-PUSH-CONTEXT) FAILPC_N=$((FAILPC_N + 1)) ;;
        UNATTRIBUTABLE) UNATTR_N=$((UNATTR_N + 1)) ;;
        TIMEOUT) TIMEOUT_N=$((TIMEOUT_N + 1)) ;;
      esac
      assert_true "push-context oracle: $rel ($verdict)" \
        "[ '$verdict' = 'PASS' ] || [ '$verdict' = 'UNATTRIBUTABLE' ]"
    done
  fi
fi

echo ""
echo "PUSH-CONTEXT-SUMMARY: total=${#SUBJECTS[@]} pass=$PASS_N fail_push_context=$FAILPC_N unattributable=$UNATTR_N timeout=$TIMEOUT_N"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
