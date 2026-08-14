#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml .github/workflows/e2e-dummy-target.yml
# =============================================================================
# Test: push-trigger base-ref resolution, delta-scoped subject execution —
# Issue #99 (standing; supersedes the Issue #85 whole-subject-sweep oracle)
# =============================================================================
# .autoflow/issue-99-verification-design.md:
#   The oracle no longer re-executes every derived subject on every run. It
#   still DERIVES the subject set exactly as before (see derive_subjects,
#   unchanged), but narrows EXECUTION to the subset the run's own change
#   surface could have altered (SELECT), while relying on native
#   push-topology coverage for the rest (see feature design §2's
#   native-push-coverage argument, ASSERTED by the native-coverage-premise
#   checks below, not merely assumed).
#
#   Resolver-topology layer (§3.1): hermetic proof that resolve_base_ref
#   degenerates correctly in the push topology (origin/main == HEAD).
#   Native-coverage-premise layer (§3.2): both halves (checkout depth, push
#   paths: reach) asserted fail-loud per derived subject against its
#   registering workflow.
#   Selection layer (§3.3): a derived subject is selected iff its own path is
#   in the delta, tests/lib/base-ref.sh (the definition site) is in the
#   delta, a delta path occurs as a literal on a non-comment line of its
#   source, its run: line is newly registered, or its invocation surface is
#   undecidable and the delta is non-empty. Selected subjects run through the
#   UNCHANGED push-context/branch-point/compute_verdict machinery below.
#   Mutation-teeth layer (§3.4, #77 constraint): a hermetic fixture proves the
#   oracle still reds the #85-class defect and stays green on the guarded
#   complement.
#
#   Budget: exactly one execution per SELECTED subject on the green path; the
#   branch-point re-run is failure-only; each execution is wrapped in a
#   per-subject timeout so one hung subject cannot stall the step.
#
# This is a STANDING suite (subject-named, no issue number — the naming rule
# docs/autoflow-guide.md > RED adds this cycle): the property is a permanent
# tree/CI-registration STATE, not this cycle's own landed state. Its `run:`
# step and `paths:` entries are added PERMANENTLY to both workflows named
# above (ci-subject).
#
# Explicit root-override interface (GATE:PLAN finding 3; precedent style:
# `tests/run-doc-invariants.sh --self-test [registry.json]` takes a
# positional target override). This suite's own analogous override is an
# optional POSITIONAL `<root>` argument: `bash tests/test-push-context-base-ref.sh
# [root]`. With no argument (the CI registration above, unchanged), the
# suite runs exactly as before, scoped to the real project tree. With a
# `<root>` argument, every root-scoped path below (derive_subjects,
# select_subjects, the scratch-context clones) is scoped to that root
# instead — this is what lets the mutation-teeth / selection-rule fixtures
# below drive the WHOLE reduction (derivation -> selection -> execution)
# hermetically, without mutating this repository's own refs. A second guard,
# the PUSH_CONTEXT_INNER env var, marks a recursive/nested drive so the new
# RED assertion sections beneath the preserved #85 sections run exactly once,
# at the outermost invocation, and never recurse into themselves.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SELF_ABS="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# Root-override: see header. Applied AFTER SELF_ABS/SCRIPT_DIR are fixed (the
# recursion target and the self-exemption basename below must always resolve
# against the REAL script location, never the overridden root).
if [ -n "${1:-}" ]; then
  PROJECT_ROOT="$1"
fi

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

echo "=== Issue #99 push-context base-ref oracle — delta-scoped selection (standing) ==="

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
# Root-scoped: reads PROJECT_ROOT, which the `<root>` override above may have
# repointed at a fixture tree.
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
# the printed count. Real-tree only — an override root has its own subjects.
if [ -z "${1:-}" ]; then
  assert_true "subject-set derivation includes a known real call site (tests/test-issue-59-adoption-evidence-discipline.sh) — regression guard against silent under-derivation" \
    "grep -qxF 'tests/test-issue-59-adoption-evidence-discipline.sh' < <(printf '%s\n' \"\${SUBJECTS[@]}\")"
fi

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

# =============================================================================
# NEW (Issue #99): delta-scoped selection — resolver-topology, native-coverage
# premise, selection-rule fixtures, real-tree benefit binding, mutation teeth,
# report-surface assertions. Runs exactly once, at the outermost invocation
# (PUSH_CONTEXT_INNER unset), never inside a recursive/nested drive of this
# same script. This whole block is additive — none of the sections above are
# touched by it (AC-subject-derivation-preserved, the judgment-contract
# self-tests, and the whole-subject execution above are unchanged).
# =============================================================================

if [ -z "${PUSH_CONTEXT_INNER:-}" ]; then
export PUSH_CONTEXT_INNER=1

BASE_REF_LIB="$SCRIPT_DIR/lib/base-ref.sh"

git_fixture_new() {  # git_fixture_new <dir>
  local dir="$1"
  mkdir -p "$dir"
  git init -q -b trunk "$dir"
  git -C "$dir" config user.email "test@example.invalid"
  git -C "$dir" config user.name "test"
}

fixture_commit_all() {  # fixture_commit_all <dir> <message>
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -q -m "$2" >/dev/null 2>&1
}

# Every fixture subject below needs to independently satisfy derive_subjects'
# own call-site criterion (a non-comment resolve_base_ref/merge-base call) —
# only then is it a DERIVED subject the selection rules quantify over.
mk_subj() {  # mk_subj <fixture_dir> <relname-under-tests/> <extra-body-line>
  local dir="$1" name="$2" body="${3:-true}"
  mkdir -p "$dir/tests/lib"
  cp "$BASE_REF_LIB" "$dir/tests/lib/base-ref.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
    echo 'source "$SDIR/lib/base-ref.sh"'
    echo 'resolve_base_ref >/dev/null 2>&1 || true'
    printf '%s\n' "$body"
    echo 'exit 0'
  } > "$dir/tests/$name"
}

# drive_suite_over_root <root> [budget] -> sets DRIVE_OUT / DRIVE_EXIT
drive_suite_over_root() {
  local root="$1" budget="${2:-1}"
  DRIVE_OUT="$(PUSH_CONTEXT_BUDGET_SECS="$budget" bash "$SELF_ABS" "$root" 2>&1)"
  DRIVE_EXIT=$?
}

echo ""
echo "=== resolver-topology-oracle (§3.1, hermetic) — AC-resolver-push-identity / AC-degenerate-delta ==="

RESOLVER_FX="$TMP_ROOT/resolver-fixture"
git_fixture_new "$RESOLVER_FX"
echo one > "$RESOLVER_FX/f.txt"
fixture_commit_all "$RESOLVER_FX" "init"
RFX_HEAD1="$(git -C "$RESOLVER_FX" rev-parse HEAD)"
git -C "$RESOLVER_FX" update-ref refs/remotes/origin/main "$RFX_HEAD1"

RESOLVED_PUSH="$(cd "$RESOLVER_FX" && env -u GITHUB_BASE_REF bash -c "source \"$BASE_REF_LIB\"; resolve_base_ref" 2>/dev/null)"
RESOLVED_PUSH_EXIT=$?
assert_true "AC-resolver-push-identity: resolve_base_ref prints HEAD's own SHA under the push topology (origin/main == HEAD, GITHUB_BASE_REF unset) and returns 0" \
  "[ '$RESOLVED_PUSH_EXIT' -eq 0 ] && [ '$RESOLVED_PUSH' = '$RFX_HEAD1' ]"

PUSH_DELTA="$(git -C "$RESOLVER_FX" diff --name-only "$RESOLVED_PUSH"...HEAD 2>/dev/null)"
assert_true "AC-degenerate-delta: the delta derived from the push-topology resolved base (git diff --name-only <out>...HEAD) is empty" \
  "[ -z '$PUSH_DELTA' ]"

# branch-point control arm: origin/main stays pinned at the ancestor commit,
# HEAD moves forward — the delta must become non-empty, pinning emptiness
# above to the TOPOLOGY, not to the fixture.
echo two > "$RESOLVER_FX/f.txt"
fixture_commit_all "$RESOLVER_FX" "second"
RESOLVED_BP="$(cd "$RESOLVER_FX" && env -u GITHUB_BASE_REF bash -c "source \"$BASE_REF_LIB\"; resolve_base_ref" 2>/dev/null)"
BP_DELTA="$(git -C "$RESOLVER_FX" diff --name-only "$RESOLVED_BP"...HEAD 2>/dev/null)"
assert_true "AC-degenerate-delta (control): branch-point topology (origin/main at an ancestor) yields a NON-empty delta" \
  "[ -n '$BP_DELTA' ]"

echo ""
echo "=== native-coverage-premise (§3.2, fixture) — AC-native-coverage-premise-depth / -reach ==="

# Shallow-checkout fixture: reach is fine (paths: covers the subject's own
# path) but depth is 1, not 0 -- must be a loud FAIL, never silently skipped.
NCP_DEPTH_FX="$TMP_ROOT/ncp-depth-fixture"
git_fixture_new "$NCP_DEPTH_FX"
mkdir -p "$NCP_DEPTH_FX/.github/workflows"
cat > "$NCP_DEPTH_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "tests/**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - run: bash tests/subj-shallow.sh
EOF
mk_subj "$NCP_DEPTH_FX" "subj-shallow.sh"
fixture_commit_all "$NCP_DEPTH_FX" "shallow checkout"

drive_suite_over_root "$NCP_DEPTH_FX"
assert_true "AC-native-coverage-premise-depth: a registering workflow whose job checkout is not fetch-depth: 0 is reported as a loud FAIL for that subject, never silently skipped" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'NATIVE-COVERAGE:[[:space:]]+tests/subj-shallow\.sh[[:space:]]+FAIL-DEPTH'"

# Narrow-paths fixture: depth is fine but the push paths: block never covers
# the subject's own path -- the reach half must independently FAIL.
NCP_REACH_FX="$TMP_ROOT/ncp-reach-fixture"
git_fixture_new "$NCP_REACH_FX"
mkdir -p "$NCP_REACH_FX/.github/workflows"
cat > "$NCP_REACH_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "docs/**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-narrow.sh
EOF
mk_subj "$NCP_REACH_FX" "subj-narrow.sh"
fixture_commit_all "$NCP_REACH_FX" "narrow paths"

drive_suite_over_root "$NCP_REACH_FX"
assert_true "AC-native-coverage-premise-reach: a registering workflow whose push paths: block does not cover the subject's own path is reported as a loud FAIL for that subject" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'NATIVE-COVERAGE:[[:space:]]+tests/subj-narrow\.sh[[:space:]]+FAIL-REACH'"

# Real-tree corroboration: both halves already hold at HEAD for every real
# derived subject (re-derived in the verification design's own premise
# section) — this is a re-verification of an already-settled premise, not new
# behavior, so a PASS here is expected and is not a RED-confirmation defect.
drive_suite_over_root "$PROJECT_ROOT"
assert_true "AC-native-coverage-premise-{depth,reach} (real tree): the pinned known call site reports NATIVE-COVERAGE PASS" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'NATIVE-COVERAGE:[[:space:]]+tests/test-issue-59-adoption-evidence-discipline\.sh[[:space:]]+PASS'"

echo ""
echo "=== selection-semantics fixture (§3.3) — AC-selection-rule-* / AC-selection-negative-control / AC-selection-undecidable-nonempty-delta ==="

# One shared fixture tree exercises five ACs from a single delta: the rule
# order is own-path > definition-site > transitive-literal > new-registration
# > undecidable-invocation, so a delta touching exactly one derived subject's
# own path is the discriminating case for all of: own-path (subj-own),
# transitive-literal (subj-literal, which shells out to subj-own.sh by
# literal path), the comment-only exclusion (subj-comment, which only
# MENTIONS subj-own.sh in a comment), the negative control (subj-negative,
# unrelated under every rule) and undecidable-invocation (subj-undecidable,
# a glob-enumerating driver, selected regardless of WHICH path changed
# because the delta is non-empty).
RULE_FX="$TMP_ROOT/rule-fixture"
git_fixture_new "$RULE_FX"
mkdir -p "$RULE_FX/.github/workflows"
cat > "$RULE_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-own.sh
      - run: bash tests/subj-def.sh
      - run: bash tests/subj-literal.sh
      - run: bash tests/subj-comment.sh
      - run: bash tests/subj-negative.sh
      - run: bash tests/subj-undecidable.sh
EOF
mk_subj "$RULE_FX" "subj-own.sh"
mk_subj "$RULE_FX" "subj-def.sh"
mk_subj "$RULE_FX" "subj-literal.sh" 'bash tests/subj-own.sh'
mk_subj "$RULE_FX" "subj-comment.sh" '# tests/subj-own.sh is described here only in prose'
mk_subj "$RULE_FX" "subj-negative.sh"
mk_subj "$RULE_FX" "subj-undecidable.sh" 'for f in tests/subj-*.sh; do bash "$f"; done'
fixture_commit_all "$RULE_FX" "base"
RULE_BASE_SHA="$(git -C "$RULE_FX" rev-parse HEAD)"
git -C "$RULE_FX" update-ref refs/remotes/origin/main "$RULE_BASE_SHA"

echo touched >> "$RULE_FX/tests/subj-own.sh"
fixture_commit_all "$RULE_FX" "touch subj-own.sh only"

drive_suite_over_root "$RULE_FX"

assert_true "AC-selection-rule-own-path: a derived subject whose own path is in the delta is selected, reason own-path" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-own.sh own-path'"
assert_true "AC-selection-rule-transitive-literal: a subject whose source contains a delta path as a literal on a non-comment line is selected, reason transitive-literal" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-literal.sh transitive-literal'"
assert_true "AC-selection-rule-transitive-comment-only: a subject whose only occurrence of the delta path is inside a comment is NOT selected on that ground, reported NOT-SELECTED reason unchanged-source" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'NOT-SELECTED: tests/subj-comment.sh unchanged-source'"
assert_true "AC-selection-negative-control: a derived subject unrelated to the delta under every rule is NOT selected, reported on its own NOT-SELECTED line reason unchanged-source" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'NOT-SELECTED: tests/subj-negative.sh unchanged-source'"
assert_true "AC-selection-undecidable-nonempty-delta: a subject with an undecidable invocation surface is conservatively selected on a non-empty delta, reason undecidable-invocation, never dropped to NOT-SELECTED" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-undecidable.sh undecidable-invocation'"

echo ""
echo "=== definition-site rule (§3.3) — AC-selection-rule-definition-site ==="

DEFSITE_FX="$TMP_ROOT/defsite-fixture"
git_fixture_new "$DEFSITE_FX"
mkdir -p "$DEFSITE_FX/.github/workflows"
cat > "$DEFSITE_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-own.sh
      - run: bash tests/subj-negative.sh
EOF
mk_subj "$DEFSITE_FX" "subj-own.sh"
mk_subj "$DEFSITE_FX" "subj-negative.sh"
fixture_commit_all "$DEFSITE_FX" "base"
DEFSITE_BASE_SHA="$(git -C "$DEFSITE_FX" rev-parse HEAD)"
git -C "$DEFSITE_FX" update-ref refs/remotes/origin/main "$DEFSITE_BASE_SHA"

echo touched >> "$DEFSITE_FX/tests/lib/base-ref.sh"
fixture_commit_all "$DEFSITE_FX" "touch the definition site only"

drive_suite_over_root "$DEFSITE_FX"
assert_true "AC-selection-rule-definition-site: when tests/lib/base-ref.sh is in the delta, every derived subject is selected, reason definition-site" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-own.sh definition-site' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-negative.sh definition-site'"

echo ""
echo "=== new-registration rule (§3.3) — AC-selection-rule-new-registration ==="

NEWREG_FX="$TMP_ROOT/newreg-fixture"
git_fixture_new "$NEWREG_FX"
mkdir -p "$NEWREG_FX/.github/workflows"
cat > "$NEWREG_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-negative.sh
EOF
mk_subj "$NEWREG_FX" "subj-negative.sh"
# subj-new.sh already exists at base, but is NOT YET registered by any run:
# step -- so it is not part of the base derived set at all.
mk_subj "$NEWREG_FX" "subj-new.sh"
fixture_commit_all "$NEWREG_FX" "base (subj-new.sh present but unregistered)"
NEWREG_BASE_SHA="$(git -C "$NEWREG_FX" rev-parse HEAD)"
git -C "$NEWREG_FX" update-ref refs/remotes/origin/main "$NEWREG_BASE_SHA"

# The delta touches ONLY the workflow file (adding subj-new.sh's run: line) --
# subj-new.sh's own path, and every other rule's ground, are untouched.
cat > "$NEWREG_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-negative.sh
      - run: bash tests/subj-new.sh
EOF
fixture_commit_all "$NEWREG_FX" "register subj-new.sh"

drive_suite_over_root "$NEWREG_FX"
assert_true "AC-selection-rule-new-registration: a subject whose run: line appears among a changed workflow's added lines is selected, reason new-registration" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-new.sh new-registration'"
assert_true "AC-selection-rule-new-registration (control): the pre-existing, unregistered-at-base subject stays NOT-SELECTED (its own path was never touched)" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'NOT-SELECTED: tests/subj-negative.sh unchanged-source'"

echo ""
echo "=== undecidable-invocation, empty-delta arm (§3.3) — AC-selection-undecidable-empty-delta ==="

UNDEC_EMPTY_FX="$TMP_ROOT/undec-empty-fixture"
git_fixture_new "$UNDEC_EMPTY_FX"
mkdir -p "$UNDEC_EMPTY_FX/.github/workflows"
cat > "$UNDEC_EMPTY_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-undecidable.sh
EOF
mk_subj "$UNDEC_EMPTY_FX" "subj-undecidable.sh" 'for f in tests/subj-*.sh; do bash "$f"; done'
fixture_commit_all "$UNDEC_EMPTY_FX" "base"
UNDEC_EMPTY_HEAD="$(git -C "$UNDEC_EMPTY_FX" rev-parse HEAD)"
# push topology: origin/main == HEAD -> the resolved delta is genuinely empty.
git -C "$UNDEC_EMPTY_FX" update-ref refs/remotes/origin/main "$UNDEC_EMPTY_HEAD"

drive_suite_over_root "$UNDEC_EMPTY_FX"
assert_true "AC-selection-undecidable-empty-delta: with an empty resolved delta the undecidable subject is NOT-SELECTED reason empty-delta, never unchanged-source" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'NOT-SELECTED: tests/subj-undecidable.sh empty-delta' && ! printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'NOT-SELECTED: tests/subj-undecidable.sh unchanged-source'"

echo ""
echo "=== unresolvable base (§3.3) — AC-selection-unresolvable-base ==="

UNRES_FX="$TMP_ROOT/unresolvable-fixture"
git_fixture_new "$UNRES_FX"
mkdir -p "$UNRES_FX/.github/workflows"
cat > "$UNRES_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-own.sh
EOF
mk_subj "$UNRES_FX" "subj-own.sh"
fixture_commit_all "$UNRES_FX" "base"
# Deliberately: no refs/remotes/origin/main, no local branch literally named
# "main" (the fixture's default branch is "trunk", per git_fixture_new), and
# GITHUB_BASE_REF is unset by run_bounded_in -- resolve_base_ref's own
# precedence chain (tests/lib/base-ref.sh:30-50) has no rung left and must
# return 1.

drive_suite_over_root "$UNRES_FX"
assert_true "AC-selection-unresolvable-base: an unresolvable comparison base is a visible BLOCK/FAIL and a non-zero exit -- never a green run with an empty selected set" \
  "[ '$DRIVE_EXIT' -ne 0 ] && printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'BLOCK'"

echo ""
echo "=== benefit-binding on the real tree (§3.3) — AC-benefit-empty-delta-real-tree / AC-benefit-proper-subset-real-tree ==="

REALCLONE="$TMP_ROOT/real-benefit-clone"
if git clone -q "$PROJECT_ROOT" "$REALCLONE" >/dev/null 2>&1; then
  REAL_HEAD="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
  git -C "$REALCLONE" checkout -q "$REAL_HEAD" >/dev/null 2>&1 || true

  # Empty-delta arm: force origin/main == HEAD (the push topology) on the
  # clone of the REAL derived set and require the selected set to be empty.
  git -C "$REALCLONE" update-ref refs/remotes/origin/main "$REAL_HEAD"
  drive_suite_over_root "$REALCLONE"
  NOTSEL_REAL_COUNT="$(printf '%s\n' "$DRIVE_OUT" | grep -cE '^NOT-SELECTED: .* empty-delta$' || true)"
  # "no SELECTED: line" alone is satisfied vacuously while the report surface
  # is unimplemented (zero SELECTED:/NOT-SELECTED: lines at all) -- also
  # require every real derived subject to be POSITIVELY reported
  # NOT-SELECTED reason empty-delta, so the check cannot pass on silence.
  assert_true "AC-benefit-empty-delta-real-tree: over the real derived set, a resolved empty delta (origin/main == HEAD) selects nothing -- every derived subject is positively reported NOT-SELECTED reason empty-delta, not merely absent from a SELECTED: line" \
    "! printf '%s\n' \"\$DRIVE_OUT\" | grep -qE '^SELECTED:' && [ \"\$NOTSEL_REAL_COUNT\" -eq \"\${#SUBJECTS[@]}\" ]"

  # Proper-subset arm: for EVERY real derived subject, a delta consisting of
  # exactly that subject's own path selects a PROPER subset of the real
  # derived set (never the whole set, never nothing selected).
  DERIVED_COUNT="${#SUBJECTS[@]}"
  PROPER_SUBSET_OK=1
  for subj in "${SUBJECTS[@]}"; do
    git -C "$REALCLONE" update-ref refs/remotes/origin/main "$REAL_HEAD"
    echo "# issue-99 proper-subset probe" >> "$REALCLONE/$subj"
    fixture_commit_all "$REALCLONE" "touch $subj"
    drive_suite_over_root "$REALCLONE"
    SEL_COUNT="$(printf '%s\n' "$DRIVE_OUT" | grep -cE '^SELECTED:' || true)"
    if [ "$SEL_COUNT" -lt 1 ] || [ "$SEL_COUNT" -ge "$DERIVED_COUNT" ]; then
      PROPER_SUBSET_OK=0
      echo "  (proper-subset probe FAILED for $subj: selected=$SEL_COUNT derived=$DERIVED_COUNT)"
      break
    fi
    git -C "$REALCLONE" reset -q --hard "$REAL_HEAD" >/dev/null 2>&1
  done
  assert_true "AC-benefit-proper-subset-real-tree: over the real derived set, a delta consisting of exactly one derived subject's own path selects a PROPER subset of the derived set, for every derived subject" \
    "[ '$PROPER_SUBSET_OK' -eq 1 ]"
else
  assert_true "AC-benefit-empty-delta-real-tree / AC-benefit-proper-subset-real-tree: real-tree scratch clone available" "false"
fi

echo ""
echo "=== mutation-teeth check (§3.4, #77 constraint) — AC-teeth-main-red / -guarded-green / -fixture-isolation ==="

TEETH_FX="$TMP_ROOT/teeth-fixture"
git_fixture_new "$TEETH_FX"
mkdir -p "$TEETH_FX/.github/workflows"
cat > "$TEETH_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-buggy.sh
      - run: bash tests/subj-guarded.sh
EOF
# subj-buggy.sh: the #85-class defect -- an UNGUARDED assertion that the
# resolved base-vs-HEAD delta is non-empty. Selected via own-path (its path
# is in the fixture's own delta below); executed by the unchanged push-context
# machinery, where the topology makes the delta genuinely empty -- the
# unguarded assertion must therefore FAIL there.
mk_subj "$TEETH_FX" "subj-buggy.sh" '
BUGGY_BASE="$(resolve_base_ref)" || exit 1
BUGGY_DELTA="$(git diff --name-only "$BUGGY_BASE"...HEAD 2>/dev/null)"
[ -n "$BUGGY_DELTA" ] || exit 1'
# subj-guarded.sh: the complementary mutant -- the SAME assertion, guarded
# against the degenerate empty-delta case, so it must stay PASS.
mk_subj "$TEETH_FX" "subj-guarded.sh" '
GUARDED_BASE="$(resolve_base_ref)" || exit 1
GUARDED_DELTA="$(git diff --name-only "$GUARDED_BASE"...HEAD 2>/dev/null)"
if [ -z "$GUARDED_DELTA" ]; then exit 0; fi
[ -n "$GUARDED_DELTA" ] || exit 1'
fixture_commit_all "$TEETH_FX" "base"
TEETH_BASE_SHA="$(git -C "$TEETH_FX" rev-parse HEAD)"
git -C "$TEETH_FX" update-ref refs/remotes/origin/main "$TEETH_BASE_SHA"
echo touched >> "$TEETH_FX/tests/subj-buggy.sh"
echo touched >> "$TEETH_FX/tests/subj-guarded.sh"
fixture_commit_all "$TEETH_FX" "touch both fixture subjects (own-path selects both)"

drive_suite_over_root "$TEETH_FX" 30
# Each teeth assertion below requires BOTH the SELECTED: line (own-path,
# since both fixture subjects are the touched paths) AND the PUSH-CONTEXT
# verdict -- the verdict alone is not discriminating: the PRESERVED
# whole-subject sweep above already executes every derived subject
# unconditionally and would produce the same verdicts even with no
# selection logic implemented at all. Requiring the SELECTED: line ties the
# check to the delta-scoped reduction this cycle actually adds.
assert_true "AC-teeth-main-red: the #85-class unguarded-assertion mutant is SELECTED (reason own-path) and, executed by the unchanged machinery, is driven to FAIL-PUSH-CONTEXT" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-buggy.sh own-path' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'PUSH-CONTEXT: tests/subj-buggy\.sh FAIL-PUSH-CONTEXT'"
assert_true "AC-teeth-guarded-green: the complementary guarded mutant is SELECTED (reason own-path) and driven to PASS -- the discriminating control against an oracle that reds on everything" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-guarded.sh own-path' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'PUSH-CONTEXT: tests/subj-guarded\.sh PASS'"
assert_true "AC-selected-execution-fidelity: a SELECTED subject is executed by the unchanged machinery (push-context scratch clone, branch-point attribution re-run, unchanged verdict vocabulary) -- demonstrated by the FAIL-PUSH-CONTEXT/PASS split above rather than a uniform verdict, and gated on selection actually having occurred" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-buggy.sh own-path' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'PUSH-CONTEXT: tests/subj-buggy\.sh FAIL-PUSH-CONTEXT' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-guarded.sh own-path' && printf '%s\n' \"\$DRIVE_OUT\" | grep -qE 'PUSH-CONTEXT: tests/subj-guarded\.sh PASS'"

# Fixture isolation: the live derive_subjects output (real tree, no root
# override) must never contain a fixture path -- a leaked fixture would put a
# deliberately-defective subject into the real sweep. This is a structural
# invariant, not new implementation behavior, so it is expected to already
# hold and is not itself a RED-confirmation defect.
assert_true "AC-teeth-fixture-isolation: the live derive_subjects output (real tree) contains no fixture path" \
  "! printf '%s\n' \"\${SUBJECTS[@]}\" | grep -qE 'subj-buggy\.sh|subj-guarded\.sh|teeth-fixture'"

echo ""
echo "=== report-surface (§5) — AC-audit-line-completeness / AC-selection-reason-line ==="

# Reuse the RULE_FX drive above (own-path + transitive-literal + comment-only
# + negative-control + undecidable, all from one delta) to check the report
# PAIRING and the reason vocabulary, rather than membership alone.
drive_suite_over_root "$RULE_FX"

DERIVED_LINE="$(printf '%s\n' "$DRIVE_OUT" | grep -E '^Subject set \(' | head -1)"
SELECTED_PATHS="$(printf '%s\n' "$DRIVE_OUT" | grep -E '^SELECTED:' | awk '{print $2}' | sort -u)"
NOTSEL_PATHS="$(printf '%s\n' "$DRIVE_OUT" | grep -E '^NOT-SELECTED:' | awk '{print $2}' | sort -u)"
PUSHCTX_PATHS="$(printf '%s\n' "$DRIVE_OUT" | grep -E '^PUSH-CONTEXT:' | awk '{print $2}' | sort -u)"
FIXTURE_DERIVED_PATHS="$(printf 'tests/subj-own.sh\ntests/subj-def.sh\ntests/subj-literal.sh\ntests/subj-comment.sh\ntests/subj-negative.sh\ntests/subj-undecidable.sh\n' | sort -u)"
UNION_SEL_NOTSEL="$(printf '%s\n%s\n' "$SELECTED_PATHS" "$NOTSEL_PATHS" | sort -u)"

assert_true "AC-audit-line-completeness (membership): every derived subject appears in exactly the union of SELECTED and NOT-SELECTED, no more, no fewer" \
  "[ \"\$UNION_SEL_NOTSEL\" = \"\$FIXTURE_DERIVED_PATHS\" ]"
assert_true "AC-audit-line-completeness (pairing): the SELECTED path set equals the PUSH-CONTEXT verdict path set -- a selected subject that never produced a verdict line is a missing pair" \
  "[ \"\$SELECTED_PATHS\" = \"\$PUSHCTX_PATHS\" ]"

# VOCAB_OK starts at 0: an absent report surface (zero SELECTED:/
# NOT-SELECTED: lines) must NOT satisfy this check by vacuous silence -- it
# is only set to 1 once at least one line of each kind was actually seen and
# every reason token on it was a vocabulary member.
VOCAB_OK=0
SEL_REASON_COUNT=0
NOTSEL_REASON_COUNT=0
SEL_VOCAB_VIOLATION=0
while IFS= read -r reason; do
  [ -z "$reason" ] && continue
  SEL_REASON_COUNT=$((SEL_REASON_COUNT + 1))
  case "$reason" in
    own-path|definition-site|transitive-literal|new-registration|undecidable-invocation) ;;
    *) SEL_VOCAB_VIOLATION=1 ;;
  esac
done < <(printf '%s\n' "$DRIVE_OUT" | grep -E '^SELECTED:' | awk '{print $3}')
NOTSEL_VOCAB_VIOLATION=0
while IFS= read -r reason; do
  [ -z "$reason" ] && continue
  NOTSEL_REASON_COUNT=$((NOTSEL_REASON_COUNT + 1))
  case "$reason" in
    empty-delta|unchanged-source) ;;
    *) NOTSEL_VOCAB_VIOLATION=1 ;;
  esac
done < <(printf '%s\n' "$DRIVE_OUT" | grep -E '^NOT-SELECTED:' | awk '{print $3}')
if [ "$SEL_REASON_COUNT" -gt 0 ] && [ "$NOTSEL_REASON_COUNT" -gt 0 ] \
   && [ "$SEL_VOCAB_VIOLATION" -eq 0 ] && [ "$NOTSEL_VOCAB_VIOLATION" -eq 0 ]; then
  VOCAB_OK=1
fi
assert_true "AC-selection-reason-line (vocabulary): at least one SELECTED and one NOT-SELECTED line are actually reported, and every reason token on each is a member of its closed vocabulary" \
  "[ '$VOCAB_OK' -eq 1 ]"

# Overlap case: a single commit touching BOTH a fixture subject's own path
# AND the definition site must report own-path (first in §3.3's order), not
# definition-site, for that subject.
OVERLAP_FX="$TMP_ROOT/overlap-fixture"
git_fixture_new "$OVERLAP_FX"
mkdir -p "$OVERLAP_FX/.github/workflows"
cat > "$OVERLAP_FX/.github/workflows/w.yml" <<'EOF'
on:
  push:
    branches: [main]
    paths:
      - "**"
jobs:
  x:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash tests/subj-own.sh
EOF
mk_subj "$OVERLAP_FX" "subj-own.sh"
fixture_commit_all "$OVERLAP_FX" "base"
OVERLAP_BASE_SHA="$(git -C "$OVERLAP_FX" rev-parse HEAD)"
git -C "$OVERLAP_FX" update-ref refs/remotes/origin/main "$OVERLAP_BASE_SHA"
echo touched >> "$OVERLAP_FX/tests/subj-own.sh"
echo touched >> "$OVERLAP_FX/tests/lib/base-ref.sh"
fixture_commit_all "$OVERLAP_FX" "touch own path AND the definition site in one commit"

drive_suite_over_root "$OVERLAP_FX"
assert_true "AC-selection-reason-line (overlap, first-match order): when a subject's own path AND the definition site are both in the delta, the reported reason is own-path (first in §3.3's order), not definition-site" \
  "printf '%s\n' \"\$DRIVE_OUT\" | grep -qF 'SELECTED: tests/subj-own.sh own-path'"

fi
# =============================================================================
# End of the Issue #99 additive block.
# =============================================================================

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
