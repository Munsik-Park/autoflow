#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md tests/fixtures/doc-invariants.json tests/manual/issue-120-manual-scenarios.md tests/test-issue-109-doc-assertions.sh tests/test-issue-120-arm-reconciliation.sh tests/test-issue-16-manifest-locale-invariance.sh tests/test-issue-51-teammate-removal-verdict.sh tests/test-issue-62-sequential-rounds.sh tests/test-issue-71-digest-removal.sh tests/test-issue-846-doc-assertions.sh tests/test-issue-848-doc-assertions.sh tests/test-issue-955-subagent-background-ban.sh tests/test-issue-979-doc-neutrality.sh
# lane: cycle-scoped
# retire-with: #120
# cycle-arm: #120
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
# =============================================================================
# Test: arm-and-deletion reconciliation — Issue #120
# =============================================================================
# Verification design: .autoflow/issue-120-verification-design.md >
# "Verification layers" > *Arm-and-deletion reconciliation (cycle-scoped
# suite)* and > "Arm extraction predicate (reconciliation layer)". Feature
# design: .autoflow/issue-120-feature-design.md §5 (arm identifier form, the
# four key-uniqueness discriminators).
#
# FAILURE MODE THIS SUITE CATCHES, AND NO OTHER LAYER DOES: an assertion arm
# removed from a surviving suite, or a suite file deleted, with the wiring
# correctly cleaned and NO provenance row and NO registry entry written. This
# is the converse of the standing residue suite's disposition-residue arms
# (tests/test-cycle-arm-residue.sh — record-to-tree direction, current state
# only): this suite is the ONLY layer that reads the base ref, so it is the
# only one that can see what LEFT the tree. A delta assertion cannot live in
# the standing lane (docs/doc-invariant-registry.md §1's two-lane rule), which
# is why this is a second, cycle-scoped file rather than an extension of the
# standing one.
#
# RED-TIME EXPECTATION. The arm-key reconciliation legs below are diff-driven:
# on the unmodified pre-GREEN tree the base-ref diff of every touched suite is
# EMPTY, so those legs iterate zero times and emit no PASS/FAIL (not a false
# PASS — an empty iteration is not a credited assertion; see the
# extractor-self-test negative controls below, which ARE non-vacuous today
# because they run the extractor against a planted scratch diff, not the real
# one). The suite's direct, non-diff legs (file-level: a deleted suite file
# has a provenance row; provenance-conformance de-duplication with the
# standing suite's own legs) are NOT diff-driven and DO fail today, which is
# this suite's actual Red signal pre-GREEN. Once GREEN lands, the diff-driven
# legs come alive and carry the suite's namesake obligation.
#
# LEAF RULE (scripts/test/check-suite-leaf.sh): this suite reads suite files
# as text and diffs them against a base ref; it executes nothing under
# tests/**.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$PROJECT_ROOT/scripts/test/suite-manifest.sh"
# shellcheck source=tests/lib/base-ref.sh
. "$PROJECT_ROOT/tests/lib/base-ref.sh"

PASS=0; FAIL=0; TESTS=0
assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}
note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }

echo "=== Issue #120 — arm-and-deletion reconciliation ==="

# The cycle's own branch gate — every resolve_base_ref call, every
# `git diff --name-only` and every dereference of allow_list below is
# dominated by it, with note_deferred on the complementary arm
# (scripts/test/check-cycle-scope-guard.sh dominance rule).
HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-120|dev/*-issue-120-*) return 0 ;;
    *) return 1 ;;
  esac
}

# =============================================================================
# Arm extraction — verification design > "Arm extraction predicate".
# =============================================================================

# arm_extract_removed_keys <repo-relative-path> <base-ref>
# Emits one reconciliation key per removed assertion arm, one per line, in
# the form `<suite-basename> `<key>`` where <key> is either:
#   - a statically written arm's <AC-id>, with a trailing `#<n>` occurrence
#     ordinal when the removal set holds more than one static arm sharing
#     that <AC-id> (source order);
#   - a loop-generated arm's `<AC-id>(<source>:<element>)`, with a trailing
#     `#<t>` template ordinal when the removed loop body holds more than one
#     assert_* template under one <AC-id>. <source> is the dereferenced array
#     variable name, or `inline(<comma-joined elements>)` for a literal list.
arm_extract_removed_keys() {
  local abs_file="$1" base="$2"
  local rel="${abs_file#"$PROJECT_ROOT"/}"
  local base_name; base_name="$(basename "$rel")"
  local diff
  diff="$(git -C "$PROJECT_ROOT" diff "$base"...HEAD -- "$rel" 2>/dev/null || true)"
  [ -n "$diff" ] || return 0

  local -a removed=()
  local dline
  while IFS= read -r dline; do
    case "$dline" in
      ---*) : ;;
      -*) removed+=("${dline#-}") ;;
    esac
  done <<<"$diff"

  local n=${#removed[@]}
  local -a static_ids=()
  local -A arm_array=()
  local i=0
  while [ "$i" -lt "$n" ]; do
    local line="${removed[$i]}"
    local trimmed="${line#"${line%%[![:space:]]*}"}"

    # Array declaration, single-line: NAME=("a" "b" "c")
    if [[ "$trimmed" =~ ^([A-Za-z_][A-Za-z0-9_]*)=\((.*)\)[[:space:]]*$ ]]; then
      local arr_name="${BASH_REMATCH[1]}" arr_body="${BASH_REMATCH[2]}"
      local -a elems=()
      eval "elems=($arr_body)" 2>/dev/null || elems=()
      arm_array["$arr_name"]="$(IFS=,; echo "${elems[*]}")"
      i=$((i + 1))
      continue
    fi

    # Array declaration, multi-line: NAME=( \n "a" \n "b" \n )
    if [[ "$trimmed" =~ ^([A-Za-z_][A-Za-z0-9_]*)=\($ ]]; then
      local arr_name="${BASH_REMATCH[1]}"
      local -a elems=()
      local j=$((i + 1))
      while [ "$j" -lt "$n" ] && [[ "${removed[$j]}" != ")" ]] && [[ "${removed[$j]}" != *")" ]]; do
        local el; el="$(printf '%s' "${removed[$j]}" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
        [ -n "$el" ] && elems+=("$el")
        j=$((j + 1))
      done
      arm_array["$arr_name"]="$(IFS=,; echo "${elems[*]}")"
      i=$((j + 1))
      continue
    fi

    # for VAR in ...
    if [[ "$trimmed" =~ ^for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+(.*)$ ]]; then
      local rhs="${BASH_REMATCH[1]}"
      rhs="$(printf '%s' "$rhs" | sed -E 's/;?[[:space:]]*do[[:space:]]*$//')"
      local source_token elems_csv
      if [[ "$rhs" =~ \"\$\{([A-Za-z_][A-Za-z0-9_]*)\[@\]\}\" ]]; then
        local arr_name="${BASH_REMATCH[1]}"
        source_token="$arr_name"
        elems_csv="${arm_array[$arr_name]:-}"
        if [ -z "$elems_csv" ]; then
          elems_csv="$(git -C "$PROJECT_ROOT" show "$base:$rel" 2>/dev/null \
            | sed -n "/^${arr_name}=($/,/^)\$/p" \
            | sed -E '1d;$d;s/^[[:space:]]*"?//; s/"?[[:space:]]*$//' \
            | paste -sd, -)"
        fi
      else
        local -a toks=()
        eval "toks=($rhs)" 2>/dev/null || toks=()
        elems_csv="$(IFS=,; echo "${toks[*]}")"
        source_token="inline(${elems_csv})"
      fi

      local -a body=()
      local j=$((i + 1))
      while [ "$j" -lt "$n" ] && [[ "${removed[$j]}" != "done" ]] && [[ "${removed[$j]}" != *"done" ]]; do
        body+=("${removed[$j]}")
        j=$((j + 1))
      done

      local -a templates=()
      local bl
      for bl in "${body[@]}"; do
        if [[ "$bl" =~ assert_(true|false)[[:space:]]*\"([^\"]*)\" ]]; then
          local desc="${BASH_REMATCH[2]}"
          templates+=("${desc%%:*}")
        fi
      done
      local tcount=${#templates[@]} ti=0 t suffix el
      for t in "${templates[@]}"; do
        ti=$((ti + 1))
        suffix=""
        [ "$tcount" -gt 1 ] && suffix="#${ti}"
        local IFS=','
        for el in $elems_csv; do
          printf '%s `%s(%s:%s)`%s\n' "$base_name" "$t" "$source_token" "$el" "$suffix"
        done
      done
      i=$((j + 1))
      continue
    fi

    if [[ "$trimmed" =~ assert_(true|false)[[:space:]]*\"([^\"]*)\" ]]; then
      static_ids+=("${BASH_REMATCH[2]%%:*}")
    fi
    i=$((i + 1))
  done

  local -A dupcount=() seen=()
  local sid
  for sid in "${static_ids[@]}"; do dupcount["$sid"]=$((${dupcount["$sid"]:-0} + 1)); done
  for sid in "${static_ids[@]}"; do
    if [ "${dupcount[$sid]}" -gt 1 ]; then
      seen["$sid"]=$((${seen["$sid"]:-0} + 1))
      printf '%s `%s`#%d\n' "$base_name" "$sid" "${seen[$sid]}"
    else
      printf '%s `%s`\n' "$base_name" "$sid"
    fi
  done
}

# =============================================================================
# Extractor self-test — negative controls against a planted scratch diff, so
# the predicate's teeth are demonstrated independent of this cycle's own
# (still-empty pre-GREEN) diff. Non-vacuous today.
# =============================================================================
SELFTEST_DIR="$(mktemp -d)"
git -C "$SELFTEST_DIR" init -q
git -C "$SELFTEST_DIR" config user.email "t@example.com"
git -C "$SELFTEST_DIR" config user.name "t"

cat > "$SELFTEST_DIR/fixture.sh" <<'SH'
#!/usr/bin/env bash
STATIC_IDS=("AC-71-CITATION")
assert_true "AC-71-CITATION: first" "true"
assert_true "AC-71-CITATION: second" "true"
assert_true "AC-71-CITATION: third" "true"
GROUP_D_ADR0016=("AC4" "AC5" "AC6")
for id in "${GROUP_D_ADR0016[@]}"; do
  assert_true "AC-assertless-header-removed: $id" "true"
done
for q in Q1 Q2 Q3; do
  assert_true "AC2: first template $q" "true"
  assert_true "AC2: second template $q" "true"
done
for id in "AC-961-5" "AC-961-7"; do
  assert_true "AC-header-scope-list-consistent: $id" "true"
done
SH
git -C "$SELFTEST_DIR" add fixture.sh
git -C "$SELFTEST_DIR" commit -q -m base
SELFTEST_BASE="$(git -C "$SELFTEST_DIR" rev-parse HEAD)"

: > "$SELFTEST_DIR/fixture.sh"
cat > "$SELFTEST_DIR/fixture.sh" <<'SH'
#!/usr/bin/env bash
true
SH
git -C "$SELFTEST_DIR" add fixture.sh
git -C "$SELFTEST_DIR" commit -q -m "remove everything"

# arm_extract_removed_keys reads $PROJECT_ROOT for its `git -C` calls; a
# bash `local PROJECT_ROOT=...` inside this wrapper dynamically shadows the
# outer PROJECT_ROOT for the duration of the nested call, re-pointing the
# extractor at the scratch repo without touching the real one.
arm_extract_removed_keys_selftest() {
  local abs_file="$1" base="$2"
  local PROJECT_ROOT="$SELFTEST_DIR"
  arm_extract_removed_keys "$abs_file" "$base"
}
SELFTEST_KEYS="$(arm_extract_removed_keys_selftest "$SELFTEST_DIR/fixture.sh" "$SELFTEST_BASE")"

assert_true "extractor-self-test: statically written AC-71-CITATION arms get occurrence ordinals #1/#2/#3" \
  "printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC-71-CITATION\`#1' && printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC-71-CITATION\`#2' && printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC-71-CITATION\`#3'"
assert_true "extractor-self-test: loop-generated arm carries the array-identity source token" \
  "printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC-assertless-header-removed(GROUP_D_ADR0016:AC5)\`'"
assert_true "extractor-self-test: two assert_* templates in one loop body under one <AC-id> get template ordinals #1/#2, per element" \
  "printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC2(inline(Q1,Q2,Q3):Q2)\`#1' && printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC2(inline(Q1,Q2,Q3):Q2)\`#2'"
assert_true "extractor-self-test: an inline-literal-list loop carries the inline(...) source token" \
  "printf '%s\n' \"\$SELFTEST_KEYS\" | grep -qF 'fixture.sh \`AC-header-scope-list-consistent(inline(AC-961-5,AC-961-7):AC-961-7)\`'"
assert_true "extractor-self-test (non-vacuous count): the planted removal yields at least 12 distinct keys (3 static + 3 loop-A + 6 loop-B + 2 loop-C)" \
  "[ \"\$(printf '%s\n' \"\$SELFTEST_KEYS\" | grep -c '.')\" -ge 12 ]"

rm -rf "$SELFTEST_DIR"

# =============================================================================
# Reconciliation over this cycle's own diff — the layer's namesake obligation.
# Diff-driven; inert (zero iterations) until GREEN lands a diff. See the
# RED-TIME EXPECTATION note above.
# =============================================================================
TOUCHED_SUITES=(
  "tests/adr-0016-conformance-check.sh"
  "tests/test-issue-42-spawn-mode-contract.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-979-doc-neutrality.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/test-issue-109-doc-assertions.sh"
  "tests/test-issue-51-teammate-removal-verdict.sh"
  "tests/test-issue-16-manifest-locale-invariance.sh"
  "tests/test-issue-71-digest-removal.sh"
)

DOC_REGISTRY_RECON="$PROJECT_ROOT/docs/doc-invariant-registry.md"
REGISTRY_IDS_RECON="$(jq -r '.invariants[].id' "$PROJECT_ROOT/tests/fixtures/doc-invariants.json" 2>/dev/null || true)"

recon_section_body() {
  awk '
    /^## [0-9]+\. .*\(issue #120\)/ { grab = 1; next }
    grab && /^## [0-9]+\./ { grab = 0 }
    grab { print }
  ' "$DOC_REGISTRY_RECON"
}

if on_issue_branch; then
  RECON_BASE="$(resolve_base_ref)" || true
  if [ -n "${RECON_BASE:-}" ]; then
    SEC_120_RECON_BODY="$(recon_section_body)"
    RECON_MISSING=""
    RECON_TOTAL_KEYS=0
    for rel in "${TOUCHED_SUITES[@]}"; do
      while IFS= read -r key_line; do
        [ -n "$key_line" ] || continue
        RECON_TOTAL_KEYS=$((RECON_TOTAL_KEYS + 1))
        # A removed arm reconciles if the #120 provenance section names its
        # suite-basename-plus-key row (arm identifier form, feature design
        # §5), OR its <AC-id> resolves as a registry entry id whose
        # origin_issue is 120 (migrated shape).
        id_only="$(printf '%s' "$key_line" | sed -E 's/^[^`]*`([^`]*)`.*/\1/')"
        if printf '%s\n' "$SEC_120_RECON_BODY" | grep -qF -- "$key_line"; then
          :
        elif printf '%s\n' "$REGISTRY_IDS_RECON" | grep -qxF "120-${id_only}"; then
          :
        else
          RECON_MISSING="${RECON_MISSING}${key_line}\n"
        fi
      done < <(arm_extract_removed_keys "$PROJECT_ROOT/$rel" "$RECON_BASE")
    done
    assert_true "AC-120-RECON: every assertion arm removed from a touched suite is either a registry entry id or a provenance row (checked $RECON_TOTAL_KEYS removed keys; unreconciled: $(printf '%b' "$RECON_MISSING" | paste -sd';' -))" \
      "[ -z \"\$(printf '%b' \"\$RECON_MISSING\")\" ]"
  else
    echo "  BLOCK: no comparison base resolvable — AC-120-RECON counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-120-RECON: arm reconciliation inert off the issue-120 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own trigger surface, not every branch's."
fi

# =============================================================================
# File-level leg — criteria row: "Every suite file this cycle deletes has a
# provenance row naming it, and every suite recorded retain — partial still
# holds at least one arm." Not diff-driven — direct existence checks, so
# this leg carries real Red signal pre-GREEN.
# =============================================================================
DOC_REGISTRY_FILELEG="$PROJECT_ROOT/docs/doc-invariant-registry.md"
for rel in "tests/adr-0016-conformance-check.sh" "tests/test-issue-42-spawn-mode-contract.sh"; do
  assert_true "AC-120-FILE: $rel is deleted and the registry names it in a provenance row" \
    "[ ! -f '$PROJECT_ROOT/$rel' ] && grep -qF '$rel' '$DOC_REGISTRY_FILELEG'"
done
for rel in \
  "tests/test-issue-846-doc-assertions.sh" \
  "tests/test-issue-848-doc-assertions.sh" \
  "tests/test-issue-979-doc-neutrality.sh" \
  "tests/test-issue-955-subagent-background-ban.sh" \
  "tests/test-issue-62-sequential-rounds.sh"
do
  assert_true "AC-120-FILE (guard, PASS pre+post): $rel is recorded retain — partial and still holds at least one assert_ arm" \
    "[ -f '$PROJECT_ROOT/$rel' ] && grep -qE 'assert_(true|false)' '$PROJECT_ROOT/$rel'"
done

# =============================================================================
# cycle-scope-respected — this cycle's own branch diff stays within its
# declared allow_list.
# =============================================================================
echo ""
echo "=== cycle-scope-respected — this cycle's own branch diff stays within its declared allow_list ==="

allow_list=(
  "tests/fixtures/doc-invariants.json"
  "tests/adr-0016-conformance-check.sh"
  "tests/test-issue-42-spawn-mode-contract.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-979-doc-neutrality.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/test-issue-109-doc-assertions.sh"
  "tests/fixtures/issue-109-assertion-baseline-adr0016.txt"
  "tests/test-issue-51-teammate-removal-verdict.sh"
  "tests/test-issue-16-manifest-locale-invariance.sh"
  "tests/test-issue-71-digest-removal.sh"
  "tests/manual/issue-42-manual-scenarios.md"
  "docs/doc-invariant-registry.md"
  "setup/manifest.json"
  ".github/workflows/contract-suites.yml"
  ".github/workflows/e2e-dummy-target.yml"
  "tests/test-cycle-arm-residue.sh"
  "tests/test-issue-120-arm-reconciliation.sh"
  "tests/manual/issue-120-manual-scenarios.md"
  # RED re-entry 2: aligning the residue/reconciliation suites' headers with
  # their hosting workflows' paths: blocks touched this file (§4's own
  # regression-scope discipline).
  "tests/test-issue-103-cycle-scope-repoint.sh"
  # §4's comment-only inbound-pin resolution targets (stale-citation repair,
  # not guaranteed to land if already clean at GREEN time — see this suite's
  # own tests/test-cycle-arm-residue.sh "already satisfied at HEAD" finding
  # for tests/test-issue-43-report-channel-contract.sh).
  "tests/test-run-doc-invariants.sh"
  "scripts/test/check-suite-manifest.sh"
  "tests/test-issue-43-report-channel-contract.sh"
)

if on_issue_branch; then
  BASE_REF_SCOPE="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_SCOPE:-}" ]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF_SCOPE"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-120-SCOPE: cycle diff set-differenced against the declared allow_list is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  else
    echo "  BLOCK: no comparison base resolvable — AC-120-SCOPE counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-120-SCOPE: change-surface guard inert off the issue-120 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
