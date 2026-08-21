#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml docs/doc-invariant-registry.md scripts/test/check-manifest-regen-clean.sh scripts/test/check-suite-ci-coverage.sh scripts/test/check-suite-leaf.sh scripts/test/check-suite-manifest.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/lib/harness-pins.sh tests/test-issue-109-doc-assertions.sh tests/test-issue-25-confirm-ci-green.sh tests/test-issue-27-composition-oracle.sh tests/test-issue-30-confirm-ci-green.sh tests/test-issue-43-report-channel-contract.sh tests/test-issue-52-peer-facilitator-premise.sh tests/test-issue-56-carry-evidence-discipline.sh tests/test-issue-59-adoption-evidence-discipline.sh tests/test-issue-62-sequential-rounds.sh tests/test-issue-67-deliberation-record.sh tests/test-issue-69-verification-depth.sh tests/test-issue-71-digest-removal.sh tests/test-workflow-trigger-conformance.sh
# lane: cycle-scoped
# retire-with: #122
# cycle-arm: #122
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
# =============================================================================
# Test: retire duplicated verification idioms + snapshot attribution rule —
#       Issue #122 (cycle-scoped)
# =============================================================================
# Verification design: .autoflow/issue-122-verification-design.md. Per its §3
# ("신규 spec 파일"), this is the ONE new spec file the cycle creates: it asserts
# the landed-diff SHAPE (retirement / extraction / lane-transition / path-move),
# the unique failure mode standard lints (header grammar, reachability, leaf,
# watchdog) do not reach on their own predicate. The dominant-risk layer — that
# a removed check's replacement carrier actually REDS on that check's failing
# input, not merely that the tree sweeps green — is carried here via scratch-tree
# mutation, never by reading source text.
#
# NOT carried here, by the verification design's own §3/§4 determination:
#   - doc-text invariants (attribution rule, admission question, keystone-
#     amendment delta, removal-provenance rows) -> tests/fixtures/doc-invariants.json
#     permanent registry entries, credited by the standing tests/run-doc-invariants.sh.
#   - new lint legs' positive/negative/boundary cases (leaf-widening teeth,
#     ratchet-declaration gating, fossil-detector advisory/not-vacuous,
#     retire-with advisory/degraded, issue-state injection boundary) -> each
#     lint's own `--self-test` fixture set (scripts/test/*.sh, Developer-AI
#     surface; a second registration home here would violate the leaf rule
#     this cycle itself is enforcing).
#   - AC-registry-carrier-paths-coverage's recurrence-prevention leg -> a new
#     leg inside the existing standing suite tests/test-workflow-trigger-
#     conformance.sh, which already owns the Actions-glob matcher and the
#     hosting-workflow resolution relation this leg reuses.
#   - AC-lint-runtime-network (real GitHub API degrade behaviour) ->
#     tests/manual/issue-122-manual-scenarios.md (outside the injection
#     boundary; composition-oracle obligation does not reach it).
#
# RED-TIME EXPECTATION. Every leg whose subject is the ABSENCE of a retired
# arm/invocation/step, or the EXISTENCE of a not-yet-created carrier
# (tests/lib/confirm-ci-green-harness.sh, the bare doc-invariant runner step,
# a migration-provenance row) FAILs at RED — the disposal set is still present
# and the new carriers do not exist yet. Legs asserting RETENTION (the fenced-
# but-not-disposed comparisons, the harness-pins.sh committed literal) are
# non-vacuity controls and PASS both pre- and post-GREEN by design, labelled
# "(guard)". A leg deferred until a not-yet-existing file lands uses
# note_deferred, mirroring the #62/#67/#69 idiom.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$PROJECT_ROOT/scripts/test/suite-manifest.sh"
. "$PROJECT_ROOT/tests/lib/base-ref.sh"
WORKFLOW="$PROJECT_ROOT/.github/workflows/contract-suites.yml"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
REGISTRY_GUIDE="$PROJECT_ROOT/docs/doc-invariant-registry.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
HARNESS_LIB="$PROJECT_ROOT/tests/lib/confirm-ci-green-harness.sh"
HARNESS_PINS="$PROJECT_ROOT/tests/lib/harness-pins.sh"
SUITE_25="$PROJECT_ROOT/tests/test-issue-25-confirm-ci-green.sh"
SUITE_30="$PROJECT_ROOT/tests/test-issue-30-confirm-ci-green.sh"
SUITE_43="$PROJECT_ROOT/tests/test-issue-43-report-channel-contract.sh"
SUITE_52="$PROJECT_ROOT/tests/test-issue-52-peer-facilitator-premise.sh"
SUITE_56="$PROJECT_ROOT/tests/test-issue-56-carry-evidence-discipline.sh"
SUITE_59="$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh"
SUITE_62="$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh"
SUITE_67="$PROJECT_ROOT/tests/test-issue-67-deliberation-record.sh"
SUITE_69="$PROJECT_ROOT/tests/test-issue-69-verification-depth.sh"
SUITE_27="$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"
SUITE_71="$PROJECT_ROOT/tests/test-issue-71-digest-removal.sh"
SUITE_979="$PROJECT_ROOT/tests/test-issue-979-bundle-delivery.sh"
SUITE_51="$PROJECT_ROOT/tests/test-issue-51-teammate-removal-verdict.sh"
SUITE_64="$PROJECT_ROOT/tests/test-issue-64-collection-scope.sh"
SUITE_109="$PROJECT_ROOT/tests/test-issue-109-doc-assertions.sh"

# Hoisted ahead of every use (RED2 / B3-1): check-cycle-scope-guard.sh denies
# any `git diff --name-only` feeding a path allow-list unless it is dominated
# by this cycle's own dev/*-issue-122 branch gate — including a diff used only
# as a negative control, not just the allow_list arm itself. Defined once,
# here, so both the negative control below and the change-surface guard arm
# near the end of this file share one gate.
HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-122|dev/*-issue-122-*) return 0 ;;
    *) return 1 ;;
  esac
}

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

# =============================================================================
echo "=== 1.1 Manifest fence retirement (O-manifest) ==="
# =============================================================================
# The disposal set, by arm identifier (feature design > Manifest fence
# retirement > the disposal table). Absence-of-arm and presence-of-retained
# are checked together so a GREEN that deletes too much or too little is
# equally visible (bidirectional, per the verification design's own framing).

DISPOSED_ARM_HITS=0
check_arm_absent() {  # file needle label
  local f="$1" needle="$2" label="$3" n
  n="$(grep -cF -- "$needle" "$f" 2>/dev/null || true)"
  [ -z "$n" ] && n=0
  if [ "$n" -eq 0 ]; then
    echo "  PASS: AC-fence-set-enumerated: $label absent from $f"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: AC-fence-set-enumerated: $label still present in $f (count: $n)"
    FAIL=$((FAIL + 1))
    DISPOSED_ARM_HITS=$((DISPOSED_ARM_HITS + 1))
  fi
  TESTS=$((TESTS + 1))
}

check_arm_absent "$SUITE_56" 'AC-56-10a' 'AC-56-10a manifest fence'
check_arm_absent "$SUITE_59" 'AC-59-9' 'AC-59-9 manifest fence'
check_arm_absent "$SUITE_62" 'AC-62-20' 'AC-62-20 manifest fence'
check_arm_absent "$SUITE_67" 'AC-67-MANIFEST' 'AC-67-MANIFEST fence'
check_arm_absent "$SUITE_69" 'AC-69-MANIFEST' 'AC-69-MANIFEST fence(s)'
check_arm_absent "$SUITE_27" 'AC-27-21b' 'AC-27-21b all-row fence'
check_arm_absent "$SUITE_979" 'AC2e' 'AC2e all-row fence'
check_arm_absent "$SUITE_52" 'manifest-freshness-a' 'manifest-freshness-a in-tree regen fence'
check_arm_absent "$SUITE_52" 'manifest-freshness-b' 'manifest-freshness-b in-tree regen fence'

# Non-vacuity controls — retained comparisons, PASS pre+post by design.
assert_true "AC-fence-set-enumerated (guard): O1(c)-hash-coherence (scratch-manifest comparison, not committed) is retained in tests/test-issue-51-teammate-removal-verdict.sh" \
  "grep -qF 'O1(c)-hash-coherence' '$SUITE_51'"
assert_true "AC-fence-set-enumerated (guard): AC-62-21a literal-hash pin is retained in tests/test-issue-62-sequential-rounds.sh" \
  "grep -qF 'AC-62-21a' '$SUITE_62'"
assert_true "AC-fence-set-enumerated (guard): script_sha256 JSON-fixture string is retained in tests/test-issue-64-collection-scope.sh" \
  "grep -qF 'script_sha256' '$SUITE_64'"

# AC-fence-carrier-red — the only real ground for retiring the fences: the
# fixed-point carrier (check-manifest-regen-clean.sh) must actually RED when a
# registered source is tampered with, driven against a scratch tree, never
# against a fixture double.
FENCE_SCRATCH="$(mktemp -d)"
trap 'rm -rf "$FENCE_SCRATCH"' EXIT
git -C "$PROJECT_ROOT" ls-files -z | rsync -a0 --files-from=- "$PROJECT_ROOT/" "$FENCE_SCRATCH/" 2>/dev/null \
  || { mkdir -p "$FENCE_SCRATCH"; (cd "$PROJECT_ROOT" && git archive HEAD) | tar -x -C "$FENCE_SCRATCH"; }
TAMPER_SRC="$FENCE_SCRATCH/.claude/workflows/architect-deliberation.js"
if [ -f "$TAMPER_SRC" ]; then
  printf '\n// RED-fixture tamper (issue #122 AC-fence-carrier-red) — content changed, manifest not regenerated\n' >> "$TAMPER_SRC"
  bash "$PROJECT_ROOT/scripts/test/check-manifest-regen-clean.sh" --root "$FENCE_SCRATCH" >/tmp/issue122-fence-carrier.out 2>&1
  FENCE_CARRIER_RC=$?
else
  FENCE_CARRIER_RC=0  # source missing -> cannot tamper -> treat as non-discriminating, not a false PASS on the real predicate
fi
assert_true "AC-fence-carrier-red: check-manifest-regen-clean.sh reds on a tampered registered source in a scratch tree (rc=$FENCE_CARRIER_RC)" \
  "[ $FENCE_CARRIER_RC -ne 0 ]"

# AC-fence-carrier-unguarded — the carrier step in contract-suites.yml carries
# no `if:` key.
CARRIER_STEP_BLOCK2="$(grep -B3 -F 'run: bash scripts/test/check-manifest-regen-clean.sh' "$WORKFLOW" 2>/dev/null || true)"
CARRIER_HAS_IF="$(printf '%s\n' "$CARRIER_STEP_BLOCK2" | grep -c 'if:' || true)"
assert_true "AC-fence-carrier-unguarded: the check-manifest-regen-clean.sh step in contract-suites.yml carries no if: guard (got if: count: ${CARRIER_HAS_IF:-0})" \
  "[ \"${CARRIER_HAS_IF:-0}\" -eq 0 ]"

# AC-regen-arm-tree-clean (static proxy — see RED report caveat). The design
# requires the in-tree regenerating arm's mktemp backup / restore_manifest /
# EXIT trap to leave with the arm, so no fragment of the in-tree mutation
# survives; checked here as source-level absence rather than a timing probe
# (a before/after git-status snapshot cannot observe a mutation a trap already
# restores by the time the suite exits).
assert_true "AC-regen-arm-tree-clean: restore_manifest (the in-tree regen arm's trap-restore function) is absent from tests/test-issue-52-peer-facilitator-premise.sh" \
  "! grep -q 'restore_manifest' '$SUITE_52'"

# =============================================================================
echo ""
echo "=== 1.2 Registry-runner re-run retirement (O-ci-reach / O-registry carrier) ==="
# =============================================================================

check_registry_invoke_absent() {  # file label
  local f="$1" label="$2" n
  n="$(grep -cE 'bash "\$REGISTRY_RUNNER"|bash "\$RUNNER"' "$f" 2>/dev/null || true)"
  [ -z "$n" ] && n=0
  TESTS=$((TESTS + 1))
  if [ "$n" -eq 0 ]; then
    echo "  PASS: AC-registry-rerun-removed: $label carries no registry-runner invocation"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: AC-registry-rerun-removed: $label still invokes the registry runner (count: $n)"
    FAIL=$((FAIL + 1))
  fi
}

check_registry_invoke_absent "$SUITE_27" 'tests/test-issue-27-composition-oracle.sh'
check_registry_invoke_absent "$SUITE_59" 'tests/test-issue-59-adoption-evidence-discipline.sh'
check_registry_invoke_absent "$SUITE_62" 'tests/test-issue-62-sequential-rounds.sh'
check_registry_invoke_absent "$SUITE_69" 'tests/test-issue-69-verification-depth.sh'
check_registry_invoke_absent "$SUITE_71" 'tests/test-issue-71-digest-removal.sh'

assert_true "AC-registry-rerun-removed: the dead REGISTRY_RUNNER assignment is removed from tests/test-issue-67-deliberation-record.sh" \
  "! grep -q 'REGISTRY_RUNNER=' '$SUITE_67'"

# AC-registry-green-carrier — a bare, if:-less current-tree-conformance step.
BARE_RUNNER_LINE="$(grep -n 'run: bash tests/run-doc-invariants\.sh$' "$WORKFLOW" || true)"
BARE_RUNNER_BLOCK="$(grep -B3 -F 'run: bash tests/run-doc-invariants.sh' "$WORKFLOW" 2>/dev/null | grep -v -- '--self-test' || true)"
BARE_RUNNER_IF="$(printf '%s\n' "$BARE_RUNNER_BLOCK" | grep -c 'if:' || true)"
assert_true "AC-registry-green-carrier: contract-suites.yml carries a bare 'run: bash tests/run-doc-invariants.sh' step (no args)" \
  "[ -n \"$BARE_RUNNER_LINE\" ]"
# Gated on the step's own existence: with no bare step, "carries no if:" is
# unfalsifiable and must not vacuously PASS on an empty search.
assert_true "AC-registry-green-carrier: that bare step exists AND carries no if: guard (line found: $([ -n "$BARE_RUNNER_LINE" ] && echo yes || echo no), if: count: ${BARE_RUNNER_IF:-0})" \
  "[ -n \"$BARE_RUNNER_LINE\" ] && [ \"${BARE_RUNNER_IF:-0}\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== 1.3 Confirm-CI-green harness extraction (O none — structural) ==="
# =============================================================================

assert_true "AC-harness-single-source: exists" \
  "[ -f '$HARNESS_LIB' ]"
assert_true "AC-harness-single-source: tests/test-issue-25-confirm-ci-green.sh no longer defines run_bounded locally" \
  "! grep -q '^run_bounded()' '$SUITE_25'"
assert_true "AC-harness-single-source: tests/test-issue-30-confirm-ci-green.sh no longer defines run_bounded locally" \
  "! grep -q '^run_bounded()' '$SUITE_30'"

SUITE_25_HDR="$(head -5 "$SUITE_25")"
SUITE_30_HDR="$(head -5 "$SUITE_30")"
assert_true "AC-harness-selection: tests/test-issue-25-confirm-ci-green.sh's ci-subject header names the harness library" \
  'printf "%s" "$SUITE_25_HDR" | grep -q "tests/lib/confirm-ci-green-harness.sh"'
assert_true "AC-harness-selection: tests/test-issue-30-confirm-ci-green.sh's ci-subject header names the harness library" \
  'printf "%s" "$SUITE_30_HDR" | grep -q "tests/lib/confirm-ci-green-harness.sh"'

if [ -f "$HARNESS_LIB" ]; then
  assert_true "AC-harness-refusal-recorded: the harness header names assert_true/assert_false as deliberately not unified" \
    "grep -q 'assert_true' '$HARNESS_LIB' && grep -qi 'not unif' '$HARNESS_LIB'"
  assert_true "AC-harness-refusal-recorded: the harness header names run_bounded_in as deliberately not unified" \
    "grep -q 'run_bounded_in' '$HARNESS_LIB'"
  assert_true "AC-harness-refusal-recorded: the harness header names harness_run as deliberately not unified" \
    "grep -q 'harness_run' '$HARNESS_LIB'"
  assert_true "AC-harness-watchdog-canonical: the real tree's watchdog-detachment lint accepts the extracted site" \
    "bash '$PROJECT_ROOT/scripts/test/check-watchdog-detachment.sh' >/tmp/issue122-watchdog.out 2>&1"

  # AC-harness-behavior-preserved — label-set comparison, baseline taken at
  # verification time from the parent (pre-extraction) commit, never committed
  # (F7). NOT executed here: check-suite-leaf.sh's subject-set is path-keyed,
  # and both the live suite and a worktree checkout of it resolve to the same
  # enumerated path (tests/test-issue-25-confirm-ci-green.sh), so invoking
  # either from this suite is the sibling-invocation the leaf rule denies —
  # unlike issue #121's I4 precedent (a scratch root under a non-enumerated
  # name). Left as an open item for VERIFY / GATE:QUALITY to resolve: run it
  # as a manual step, or move it to that suite's own self-check once the
  # harness lands (out of THIS suite's leaf-clean surface either way).
  note_deferred "AC-harness-behavior-preserved: label-set comparison intentionally not executed from this suite (check-suite-leaf.sh sibling-invocation conflict — see suite header note) — resolve at VERIFY."
else
  note_deferred "AC-harness-refusal-recorded / AC-harness-watchdog-canonical / AC-harness-behavior-preserved: does not exist yet — deferred until GREEN adds it."
fi

# =============================================================================
echo ""
echo "=== 1.4 Self-registration and self-test re-invocation retirement (O-ci-reach) ==="
# =============================================================================
# AC-self-registration-removed / AC-selftest-carrier-unguarded are enumeration-
# heavy (per-arm, per-lint) and are left to the mock-boundary / VERIFY pass —
# their carrier (check-suite-ci-coverage.sh, workflow-trigger-conformance) is
# exercised for real below via AC-reachability-carrier-red, which is this
# section's dominant-risk leg.

REACH_SCRATCH="$(mktemp -d)"
mkdir -p "$REACH_SCRATCH/tests"
cp -R "$PROJECT_ROOT/.github" "$REACH_SCRATCH/" 2>/dev/null || mkdir -p "$REACH_SCRATCH/.github/workflows"
cat > "$REACH_SCRATCH/tests/test-issue-122-unreachable-fixture.sh" <<'EOF'
#!/usr/bin/env bash
# ci-subject: docs/does-not-exist.md
# lane: cycle-scoped
# retire-with: #122
# budget-secs: SUITE_BUDGET_CEILING_SECS
echo "Results: 0/0 passed, 0 failed"
exit 0
EOF
chmod +x "$REACH_SCRATCH/tests/test-issue-122-unreachable-fixture.sh"
bash "$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh" --root "$REACH_SCRATCH" >/tmp/issue122-reach.out 2>&1
REACH_RC=$?
assert_true "AC-reachability-carrier-red: check-suite-ci-coverage.sh reds on a suite no workflow names, in a scratch tree" \
  "[ $REACH_RC -ne 0 ]"
rm -rf "$REACH_SCRATCH"

# =============================================================================
echo ""
echo "=== 1.5 Snapshot attribution — ratchet against fossil ==="
# =============================================================================
# Instances disposed this cycle (feature design > Snapshot attribution >
# Instances disposed this cycle) — the two, and only those.

assert_true "AC-fossil-disposed: R43-COUNT (origin_issue==43 registry-entry count pin, lane: standing, self-contradicting comment) is removed from tests/test-issue-43-report-channel-contract.sh" \
  "! grep -q 'R43-COUNT' '$SUITE_43'"
assert_true "AC-fossil-disposed: AC-59-11c-count (file-scoped legacy-entry count pin) is removed from tests/test-issue-59-adoption-evidence-discipline.sh" \
  "! grep -q 'AC-59-11c-count' '$SUITE_59'"

# Negative control (feature design > Instances the issue lists that are not
# disposed): the harness ok-count committed literal is a deliberate pin, out
# of scope, and must be UNCHANGED by this cycle's diff.
#
# RED2 / B3-1: the diff half is gated under on_issue_branch —
# check-cycle-scope-guard.sh denies any `git diff --name-only` feeding a
# path allow-list decision unless it is dominated by this cycle's own
# dev/*-issue-122 branch predicate, and this negative control's diff is
# exactly that shape even though it is not the allow_list arm itself. The
# presence half is unconditional (it asserts a state, not a diff).
HARNESS_OK_COUNT_LINE="$(grep -n '^HARNESS_OK_COUNT=' "$HARNESS_PINS" || true)"
assert_true "AC-fossil-disposed (negative control): tests/lib/harness-pins.sh HARNESS_OK_COUNT declaration is present" \
  "[ -n \"$HARNESS_OK_COUNT_LINE\" ]"
if on_issue_branch; then
  NCTRL_BASE_REF="$(resolve_base_ref)" || true
  if [ -n "${NCTRL_BASE_REF:-}" ]; then
    HARNESS_PINS_DIFF="$(cd "$PROJECT_ROOT" && git diff --name-only "$NCTRL_BASE_REF"...HEAD -- "$HARNESS_PINS")"
    assert_true "AC-fossil-disposed (negative control): tests/lib/harness-pins.sh is untouched by this cycle's diff (diff: ${HARNESS_PINS_DIFF:-none})" \
      '[ -z "$HARNESS_PINS_DIFF" ]'
  else
    echo "  BLOCK: no comparison base resolvable — negative-control diff counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-fossil-disposed (negative control) diff half: inert off the issue-122 dev branch (head: ${HEAD_BRANCH:-unknown})."
fi

# =============================================================================
echo ""
echo "=== 1.6 Ratchet directory move — assertion-set baseline precondition ==="
# =============================================================================
# AC-fixture-absence-is-red is ordered ahead of the fixture move itself (F5):
# the baseline-consuming function must fail — not vacuously pass — on a
# missing baseline argument. Driven against the REAL function source at HEAD
# (composition oracle O-keystone; no mock/fixture double), via extraction and
# eval, since the function is private to tests/test-issue-109-doc-assertions.sh.

KEYSTONE_FUNC_SRC="$(sed -n '/^check_assertion_set_preserved()/,/^}/p' "$SUITE_109")"
if [ -n "$KEYSTONE_FUNC_SRC" ]; then
  (
    eval "$KEYSTONE_FUNC_SRC"
    check_assertion_set_preserved "$PROJECT_ROOT/tests/fixtures/__issue-122-nonexistent-baseline__.txt" "$SUITE_109" "RED-probe"
  )
  KEYSTONE_ABSENT_RC=$?
else
  KEYSTONE_ABSENT_RC=1
  echo "  (check_assertion_set_preserved not found in tests/test-issue-109-doc-assertions.sh — cannot extract)" >&2
fi
assert_true "AC-fixture-absence-is-red: check_assertion_set_preserved (real function at HEAD) does NOT vacuously PASS when its baseline path is missing (rc=$KEYSTONE_ABSENT_RC)" \
  "[ $KEYSTONE_ABSENT_RC -ne 0 ]"

# =============================================================================
echo ""
echo "=== 1.8 Cycle-global: provenance and regenerated manifest ==="
# =============================================================================
# AC-provenance-total — the disposal identifier set this suite itself asserts
# above must each have a migration-provenance row in the registry guide. Joined
# against the fence/registry-runner disposal identifiers as a representative
# sample of the full removal set (the full join is the registry entry's own
# job per AC-removal-provenance; this is the cross-check half this suite owns).
DISPOSAL_SAMPLE="AC-56-10a AC-59-9 AC-62-20 AC-67-MANIFEST AC-27-21b AC2e manifest-freshness-a R43-COUNT AC-59-11c-count"
PROVENANCE_MISSING=0
for id in $DISPOSAL_SAMPLE; do
  if ! grep -qF -- "$id" "$REGISTRY_GUIDE"; then
    echo "    MISSING provenance row for: $id" >&2
    PROVENANCE_MISSING=$((PROVENANCE_MISSING + 1))
  fi
done
DISPOSAL_SAMPLE_N="$(set -- $DISPOSAL_SAMPLE; echo $#)"
assert_true "AC-provenance-total: every sampled disposed identifier has a migration-provenance row in docs/doc-invariant-registry.md (missing: $PROVENANCE_MISSING/$DISPOSAL_SAMPLE_N)" \
  "[ $PROVENANCE_MISSING -eq 0 ]"

# AC-manifest-regen-same-commit (guard) — the committed manifest is already
# byte-identical to a fresh regen against the live tree; this is a standing
# invariant this cycle must not break, checked here with the real generator.
REGEN_SCRATCH="$(mktemp -d)"
(cd "$PROJECT_ROOT" && git archive HEAD) | tar -x -C "$REGEN_SCRATCH"
if [ -f "$REGEN_SCRATCH/setup/gen-manifest-hashes.sh" ]; then
  (cd "$REGEN_SCRATCH" && bash setup/gen-manifest-hashes.sh) >/tmp/issue122-regen.out 2>&1
  REGEN_DIFF="$(diff -q "$REGEN_SCRATCH/setup/manifest.json" "$MANIFEST" 2>&1 || true)"
  assert_true "AC-manifest-regen-same-commit (guard): a fresh regen of setup/manifest.json against HEAD is byte-identical to the committed file" \
    "[ -z \"$REGEN_DIFF\" ]"
else
  note_deferred "AC-manifest-regen-same-commit: setup/gen-manifest-hashes.sh not found in the archived tree — deferred."
fi
rm -rf "$REGEN_SCRATCH"

# =============================================================================
echo ""
echo "=== cycle-scope-respected — this cycle's own branch diff stays within its declared allow_list ==="
# =============================================================================
# HEAD_BRANCH / on_issue_branch are defined once, near the top of this file
# (RED2 / B3-1), so the negative control above shares the same gate.

# Full anticipated cycle footprint (RED + GREEN), per feature design > Files
# changed and verification design §5 (Committed-surface allow-list) — not RED's
# own diff alone, since AC-122-SCOPE is evaluated on this branch through the
# whole cycle. Literal paths only (comm -23 is not glob-aware); the ratchet
# fixtures directory's exact member paths are a GREEN-time decision and are
# intentionally not enumerated here (unknown at RED) — REFINE/VALIDATE add them
# if GREEN lands new members under it that this arm would otherwise flag.
allow_list=(
  # RED artifacts
  "tests/test-issue-122-retirement-attribution.sh"
  "tests/manual/issue-122-manual-scenarios.md"
  "tests/fixtures/doc-invariants.json"
  "tests/test-workflow-trigger-conformance.sh"
  # Manifest-fence disposal set
  "tests/test-issue-56-carry-evidence-discipline.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-69-verification-depth.sh"
  "tests/test-issue-27-composition-oracle.sh"
  "tests/test-issue-979-bundle-delivery.sh"
  "tests/test-issue-52-peer-facilitator-premise.sh"
  # Registry-runner re-run disposal set (superset of the above)
  "tests/test-issue-71-digest-removal.sh"
  # Fossil count-pin disposal set
  "tests/test-issue-43-report-channel-contract.sh"
  # Harness extraction
  "tests/lib/confirm-ci-green-harness.sh"
  "tests/test-issue-25-confirm-ci-green.sh"
  "tests/test-issue-30-confirm-ci-green.sh"
  # Keystone / ratchet-move precondition
  "tests/test-issue-109-doc-assertions.sh"
  # Ratchet directory members — moved assertion-set baselines + grow-only
  # sidecars (feature design > Files changed, "tests/fixtures/ ratchet
  # directory + sidecars"; green report §19.6)
  "tests/fixtures/ratchet/issue-109-assertion-baseline-798.txt"
  "tests/fixtures/ratchet/issue-109-assertion-baseline-798.direction.txt"
  "tests/fixtures/ratchet/issue-109-assertion-baseline-799.txt"
  "tests/fixtures/ratchet/issue-109-assertion-baseline-799.direction.txt"
  # Retirement-due fetch adapter — mandated outside the lint by design
  # (feature design > Retirement-due advisory > Injection boundary — adopted;
  # green report §19.7)
  "scripts/test/fetch-issue-state.sh"
  # B1 consequences of the leaf-rule widening (green blocker B1; green report
  # §19.2/§19.3): the literal invocation form is already denied by row D1, so
  # a widening with any teeth must reach the variable form every real site
  # uses, which forced these two out-of-original-surface edits.
  "tests/test-issue-51-teammate-removal-verdict.sh"
  "tests/test-issue-103-suite-leaf.sh"
  # Lints
  "scripts/test/check-suite-leaf.sh"
  "scripts/test/check-suite-manifest.sh"
  # Workflow + derived manifest
  ".github/workflows/contract-suites.yml"
  "setup/manifest.json"
  # Docs
  "docs/doc-invariant-registry.md"
  "docs/autoflow-guide.md"
  "docs/maintained-docs.md"
)

if on_issue_branch; then
  BASE_REF_SCOPE="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_SCOPE:-}" ]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF_SCOPE"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-122-SCOPE: cycle diff set-differenced against the declared allow_list is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  else
    echo "  BLOCK: no comparison base resolvable — AC-122-SCOPE counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-122-SCOPE: change-surface guard inert off the issue-122 dev branch (head: ${HEAD_BRANCH:-unknown})."
fi

# =============================================================================
echo ""
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
