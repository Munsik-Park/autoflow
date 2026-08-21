#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md scripts/test/check-suite-manifest.sh tests/fixtures/doc-invariants.json tests/manual/issue-42-manual-scenarios.md tests/run-doc-invariants.sh tests/test-issue-109-doc-assertions.sh tests/test-issue-16-manifest-locale-invariance.sh tests/test-issue-43-report-channel-contract.sh tests/test-issue-51-teammate-removal-verdict.sh tests/test-issue-52-peer-facilitator-premise.sh tests/test-issue-56-carry-evidence-discipline.sh tests/test-issue-59-adoption-evidence-discipline.sh tests/test-issue-62-sequential-rounds.sh tests/test-issue-71-digest-removal.sh tests/test-run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: no
# =============================================================================
# Test: cycle-arm residue — Issue #107
#   .autoflow/issue-107-verification-design.md, .autoflow/issue-107-feature-design.md
#   (§3.8's "the class assertion is where the durable protection lives"; the
#   specific-instance arms over this cycle's six suites are this file's own).
# =============================================================================
# Subject-named per docs/autoflow-guide.md:456 — this suite is standing, not
# cycle-scoped: its class assertion (below) is a permanent property of the
# tree, not this cycle's own diff.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CYCLE_ARM_RESIDUE_SELF_REL="tests/test-cycle-arm-residue.sh"

# shellcheck source=scripts/test/suite-manifest.sh
. "$PROJECT_ROOT/scripts/test/suite-manifest.sh"
# shellcheck source=scripts/test/invocation-scan.sh
. "$PROJECT_ROOT/scripts/test/invocation-scan.sh"

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

echo "=== Issue #107 — cycle-arm residue (array-less dev/*-issue-<N> gate class + this cycle's dispositions) ==="

# =============================================================================
# Class predicate — root-parameterised, no re-invocable script body.
#
# A LIVE GATE (feature design §3.8) is a line that is (1) a case-branch label
# or a `[[ ... == ... ]]` / `[[ ... = ... ]]` pattern (both string-equality
# forms are live; `!=` is excluded) whose pattern is `dev/*-issue-<N>`, (2)
# not a comment line, and (3) not inside a heredoc body — text a suite
# *writes out* as a fixture is fixture data, not a gate the suite evaluates.
# Heredoc-body
# tracking reuses invscan_heredoc_tag (scripts/test/invocation-scan.sh), the
# same definition the leaf lint already relies on, rather than re-deriving
# quote-handling here.
#
# Drive shape (feature design §3.8 "Drive shape", verification design
# `new-suite-non-vacuous`): these are plain shell FUNCTIONS taking the
# enumeration root as a parameter. Neither is ever invoked as
# `bash tests/test-cycle-arm-residue.sh` (leaf-lint row D1) nor through a
# variable assigned that literal enumerated path (row D5) — the top-level arm
# below calls the function in-process against the real project root, and the
# negative control calls it in-process against a scratch root.
# =============================================================================

# cycle_arm_residue_live_gate_numbers <file> — issue numbers (deduped) matched
# by a live dev/*-issue-<N> gate in <file>.
cycle_arm_residue_live_gate_numbers() {
  [ -f "$1" ] || return 0
  awk "$INVSCAN_AWK_LIB"'
    {
      if (in_here) {
        s = $0; sub(/^[[:space:]]+/, "", s)
        if (s == here_tag) { in_here = 0; here_tag = "" }
        next
      }
      s = $0; sub(/^[[:space:]]*/, "", s)
      if (s !~ /^#/) {
        m = $0
        while (match(m, /dev\/\*-issue-[0-9]+/)) {
          tok = substr(m, RSTART, RLENGTH)
          rest = substr(m, RSTART + RLENGTH)
          num = tok; sub(/^dev\/\*-issue-/, "", num)
          is_case_label = (rest ~ /^(-\*)?([[:space:]]*\|[[:space:]]*dev\/\*-issue-[0-9]+-\*)?[[:space:]]*\)/)
          # `=` and `==` are both valid [[ ]] string-equality operators; a
          # single-= gate ([[ $b = dev/*-issue-42* ]]) is just as live as a
          # double-= one (GATE:QUALITY FAIL #1, finding 2). Requiring
          # whitespace immediately before the operator matches both while
          # excluding `!=` (whose char immediately before `=` is `!`, not
          # whitespace).
          is_bracket_pattern = ($0 ~ /\[\[[^]]*[[:space:]]=[=]?[[:space:]]*"?dev\/\*-issue-/)
          if (is_case_label || is_bracket_pattern) print num
          m = rest
        }
      }
      tag = invscan_heredoc_tag($0)
      if (tag != "") { in_here = 1; here_tag = tag }
    }
  ' "$1" | sort -u
}

# cycle_arm_residue_violations <root> — "<repo-relative-path> <issue-number>"
# per suite carrying a live gate for <issue-number> with no matching
# "# cycle-arm: #<issue-number>" declaration. Self-excludes its own path.
cycle_arm_residue_violations() {
  local root="$1" rel f num hdr
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ "$rel" = "$CYCLE_ARM_RESIDUE_SELF_REL" ] && continue
    f="$root/$rel"
    [ -f "$f" ] || continue
    while IFS= read -r num; do
      [ -n "$num" ] || continue
      hdr="$(suite_header_field "$f" cycle-arm 2>/dev/null || true)"
      if [ "$hdr" != "#$num" ]; then
        printf '%s %s\n' "$rel" "$num"
      fi
    done < <(cycle_arm_residue_live_gate_numbers "$f")
  done < <(suite_enumerate "$root")
}

# ---------------------------------------------------------------------------
# Top-level arm — the durable protection, driven against the real root.
# ---------------------------------------------------------------------------
REAL_VIOLATIONS="$(cycle_arm_residue_violations "$PROJECT_ROOT")"
if [ -n "$REAL_VIOLATIONS" ]; then
  echo "  ---- live array-less dev/*-issue-<N> gates with no cycle-arm declaration ----"
  printf '%s\n' "$REAL_VIOLATIONS" | sed 's/^/    /'
  echo "  ---- end ----"
fi
assert_true "class: no suite under tests/** carries a live array-less dev/*-issue-<N> gate (every live gate declares a matching # cycle-arm:)" \
  "[ -z \"\$REAL_VIOLATIONS\" ]"

assert_true "new-suite-self-exclusion: this suite's own source contains the gate-glob text its predicate searches for (a live property, not a vacuous no-op)" \
  "grep -qE 'dev\\\\/\\\\\\*-issue-' '$SCRIPT_DIR/test-cycle-arm-residue.sh'"
assert_true "new-suite-self-exclusion: the class predicate over the real root does not flag this suite's own path" \
  "! printf '%s\\n' \"\$REAL_VIOLATIONS\" | grep -qE '^tests/test-cycle-arm-residue\\.sh '"

# ---------------------------------------------------------------------------
# new-suite-non-vacuous — negative control. A class predicate that passes
# because it matches nothing (including the self-match case) is not coverage.
# ---------------------------------------------------------------------------
NEG_DIR="$(mktemp -d)"; mkdir -p "$NEG_DIR/tests"

cat > "$NEG_DIR/tests/test-fixture-107-violation.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
case "${HEAD_BRANCH:-}" in
  dev/*-issue-555|dev/*-issue-555-*)
    echo "gated"
    ;;
esac
SH
NEG_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a planted array-less dev/*-issue-555 gate with no cycle-arm header is caught" \
  "printf '%s\\n' \"\$NEG_RESULT\" | grep -qE '^tests/test-fixture-107-violation\\.sh 555\$'"
rm -f "$NEG_DIR/tests/test-fixture-107-violation.sh"

cat > "$NEG_DIR/tests/test-fixture-107-conforming.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #555
# budget-secs: 30
case "${HEAD_BRANCH:-}" in
  dev/*-issue-555|dev/*-issue-555-*)
    echo "gated"
    ;;
esac
SH
CONFORMING_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: the same gate, declared with a matching cycle-arm header, is not flagged" \
  "! printf '%s\\n' \"\$CONFORMING_RESULT\" | grep -qE '^tests/test-fixture-107-conforming\\.sh 555\$'"
rm -f "$NEG_DIR/tests/test-fixture-107-conforming.sh"

cat > "$NEG_DIR/tests/test-fixture-107-heredoc.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
cat > /tmp/107-fixture.sh <<'INNER'
case "$HEAD_BRANCH" in
  dev/*-issue-556)
    :
    ;;
esac
INNER
SH
HEREDOC_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a gate-glob match inside a heredoc body (fixture text a suite emits, not a gate it evaluates) is not flagged" \
  "! printf '%s\\n' \"\$HEREDOC_RESULT\" | grep -qE '556'"

cat > "$NEG_DIR/tests/test-fixture-107-comment.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
# was once gated on dev/*-issue-557|dev/*-issue-557-*)
true
SH
COMMENT_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a gate-glob mention inside a comment line is not flagged" \
  "! printf '%s\\n' \"\$COMMENT_RESULT\" | grep -qE '557'"

# GATE:QUALITY FAIL #2: the bracket-pattern arm's original `==` form had no
# fixture of its own (only the single-= variant added below did) — add one so
# the class predicate's most common live shape is itself under a negative
# control, not just its extension.
cat > "$NEG_DIR/tests/test-fixture-107-double-eq.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
b="${HEAD_BRANCH:-}"
if [[ $b == dev/*-issue-560* ]]; then
  echo "gated"
fi
SH
DOUBLE_EQ_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a [[ \$b == dev/*-issue-560* ]] double-== bracket gate with no cycle-arm header is caught" \
  "printf '%s\\n' \"\$DOUBLE_EQ_RESULT\" | grep -qE '^tests/test-fixture-107-double-eq\\.sh 560\$'"
rm -f "$NEG_DIR/tests/test-fixture-107-double-eq.sh"

# GATE:QUALITY FAIL #1, finding 2: a [[ ]] bracket-pattern gate written with a
# single `=` (POSIX-shape string equality, just as live as `==`) evaded the
# prior is_bracket_pattern regex, which required `==` literally.
cat > "$NEG_DIR/tests/test-fixture-107-single-eq.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
b="${HEAD_BRANCH:-}"
if [[ $b = dev/*-issue-558* ]]; then
  echo "gated"
fi
SH
SINGLE_EQ_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a [[ \$b = dev/*-issue-558* ]] single-= bracket gate with no cycle-arm header is caught" \
  "printf '%s\\n' \"\$SINGLE_EQ_RESULT\" | grep -qE '^tests/test-fixture-107-single-eq\\.sh 558\$'"
rm -f "$NEG_DIR/tests/test-fixture-107-single-eq.sh"

# Negative control for the fix above: [[ $b != dev/*-issue-559* ]] is a
# NEGATED comparison, not a gate on the pattern — the char immediately before
# `=` is `!`, not whitespace, so it must stay excluded.
cat > "$NEG_DIR/tests/test-fixture-107-not-eq.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# budget-secs: 30
b="${HEAD_BRANCH:-}"
if [[ $b != dev/*-issue-559* ]]; then
  echo "not gated"
fi
SH
NOT_EQ_RESULT="$(cycle_arm_residue_violations "$NEG_DIR")"
assert_true "new-suite-non-vacuous: a [[ \$b != dev/*-issue-559* ]] negated comparison is not flagged (the single-= fix must not swallow !=)" \
  "! printf '%s\\n' \"\$NOT_EQ_RESULT\" | grep -qE '559'"

rm -rf "$NEG_DIR"

# =============================================================================
# This cycle's own dispositions — tests/test-issue-{43,51,52,56,59,62}-*.sh
# =============================================================================
SUITE_43="$PROJECT_ROOT/tests/test-issue-43-report-channel-contract.sh"
SUITE_51="$PROJECT_ROOT/tests/test-issue-51-teammate-removal-verdict.sh"
SUITE_52="$PROJECT_ROOT/tests/test-issue-52-peer-facilitator-premise.sh"
SUITE_56="$PROJECT_ROOT/tests/test-issue-56-carry-evidence-discipline.sh"
SUITE_59="$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh"
SUITE_62="$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh"

# ---------------------------------------------------------------------------
# arm-removed — no dev/*-issue-{43,51,52,56,59,62} gate remains, and each
# removed arm's own DEFERRED-OBSERVABLE marker is gone with it.
# ---------------------------------------------------------------------------
assert_true "arm-removed: test-issue-43 carries no dev/*-issue-43 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_43')\" ]"
assert_true "arm-removed: test-issue-43's S43-UNTOUCHED deferral marker is gone" \
  "! grep -qF 'S43-UNTOUCHED' '$SUITE_43'"

assert_true "arm-removed: test-issue-51 carries no dev/*-issue-51 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_51')\" ]"
assert_true "arm-removed: test-issue-51's AC1(d) deferral marker is gone" \
  "! grep -qF 'AC1(d): lane A-delta member inert' '$SUITE_51'"
assert_true "arm-removed: test-issue-51's AC6(b)/(c) deferral marker is gone" \
  "! grep -qF 'AC6(b)/(c): lane A-delta members inert' '$SUITE_51'"

assert_true "arm-removed: test-issue-52 carries no dev/*-issue-52 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_52')\" ]"
assert_true "arm-removed: test-issue-52's BASE52/case/assert_true vacuous-PASS fence (scope-fence-held-b) is gone" \
  "! grep -qF 'scope-fence-held-b' '$SUITE_52'"

assert_true "arm-removed: test-issue-56 carries no dev/*-issue-56 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_56')\" ]"
assert_true "arm-removed: test-issue-56's AC-56-8 deferral marker is gone" \
  "! grep -qF 'AC-56-8: EXPECTED_OK=37 regression pin inert' '$SUITE_56'"
assert_true "arm-removed: test-issue-56's AC-56-9a/9b deferral marker is gone" \
  "! grep -qF 'AC-56-9a/9b: cycle-scoped change-surface fence inert' '$SUITE_56'"

assert_true "arm-removed: test-issue-59 carries no dev/*-issue-59 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_59')\" ]"
assert_true "arm-removed: test-issue-59's AC-59-10 deferral marker is gone" \
  "! grep -qF 'AC-59-10:' '$SUITE_59'"
assert_true "arm-removed: test-issue-59's AC-59-11a/11b deferral marker is gone" \
  "! grep -qF 'AC-59-11a/11b:' '$SUITE_59'"
assert_true "arm-removed: test-issue-59's AC-59-15a deferral marker is gone" \
  "! grep -qF 'AC-59-15a:' '$SUITE_59'"

assert_true "arm-removed: test-issue-62 carries no dev/*-issue-62 gate" \
  "[ -z \"\$(cycle_arm_residue_live_gate_numbers '$SUITE_62')\" ]"
assert_true "arm-removed: test-issue-62's AC-62-23 deferral marker is gone" \
  "! grep -qF 'AC-62-23:' '$SUITE_62'"
assert_true "arm-removed: test-issue-62's AC-62-35 deferral marker is gone" \
  "! grep -qF 'AC-62-35:' '$SUITE_62'"
assert_true "arm-removed: test-issue-62's AC-62-36 case/esac deferral marker is gone (both controls ungated per-control)" \
  "! grep -qF 'AC-62-36(ii)/(iii)/(iv):' '$SUITE_62'"
assert_true "arm-removed: test-issue-62 keeps guard_result_at_ref_mutated (§12.1's kept row cites it; a delete would falsify the registry)" \
  "grep -qE 'guard_result_at_ref_mutated\\(\\)[[:space:]]*\\{' '$SUITE_62'"

# ---------------------------------------------------------------------------
# no-orphan-base-resolution — feature design §3.1/§3.2/§3.5 constraint 1/2:
# each of these five suites' resolve_base_ref call is the arm's own, and its
# last non-comment reader retires with the arm. Direct, deterministic form:
# the post-change disposition is zero non-comment resolver calls and zero
# non-comment base-ref.sh sourcing, not a conditional "if a call survives it
# has a consumer" — every named suite here loses its only call site.
# (test-issue-62 never called resolve_base_ref and is not in this set.)
# ---------------------------------------------------------------------------
for pair in "$SUITE_43:43" "$SUITE_51:51" "$SUITE_52:52" "$SUITE_56:56" "$SUITE_59:59"; do
  f="${pair%%:*}"; n="${pair##*:}"
  assert_true "no-orphan-base-resolution: test-issue-$n carries no non-comment resolve_base_ref / git-merge-base call (its retired arm was the last reader)" \
    "[ -z \"\$(grep -vE '^[[:space:]]*#' '$f' | grep -E '\\bresolve_base_ref\\b|\\bgit\\b[^#]*\\bmerge-base\\b')\" ]"
  assert_true "no-orphan-base-resolution: test-issue-$n's non-comment lines no longer reference tests/lib/base-ref.sh (direct source or a BASEREF_LIB-style assignment)" \
    "[ -z \"\$(grep -vE '^[[:space:]]*#' '$f' | grep -F 'lib/base-ref.sh')\" ]"
done

# ---------------------------------------------------------------------------
# header-matches-content — declared ci-subject tokens narrow with the removed
# dependency, and are backed by a non-comment body reference (feature design
# §3.6's stated rule, applied here as the decidable predicate).
# ---------------------------------------------------------------------------
assert_true "header-matches-content: test-issue-51's ci-subject header no longer declares tests/lib/base-ref.sh (its resolve_base_ref call is retired)" \
  "! grep -qE '^# ci-subject:.*tests/lib/base-ref\\.sh' '$SUITE_51'"
assert_true "header-matches-content: test-issue-52's ci-subject header no longer declares tests/lib/base-ref.sh" \
  "! grep -qE '^# ci-subject:.*tests/lib/base-ref\\.sh' '$SUITE_52'"
assert_true "header-matches-content: test-issue-56's ci-subject header no longer declares tests/lib/base-ref.sh" \
  "! grep -qE '^# ci-subject:.*tests/lib/base-ref\\.sh' '$SUITE_56'"
assert_true "header-matches-content: test-issue-59's ci-subject header no longer declares tests/lib/base-ref.sh" \
  "! grep -qE '^# ci-subject:.*tests/lib/base-ref\\.sh' '$SUITE_59'"
assert_true "header-matches-content: test-issue-59's ci-subject header no longer declares tests/lib/harness-pins.sh (its EXPECTED_OK reader is retired, duplicating tests/test-issue-27-composition-oracle.sh)" \
  "! grep -qE '^# ci-subject:.*tests/lib/harness-pins\\.sh' '$SUITE_59'"
assert_true "header-matches-content: test-issue-62's ci-subject header no longer declares tests/lib/harness-pins.sh (never sourced; only comment mentions backed it, which is not a subject relation)" \
  "! grep -qE '^# ci-subject:.*tests/lib/harness-pins\\.sh' '$SUITE_62'"

# =============================================================================
# Sibling assertions amended in the same change (feature design §3.10) — the
# specific delta each amendment must land, re-derived at run time against
# whatever the sibling file currently says rather than duplicated from memory.
# =============================================================================
SIBLING_103_MANIFEST="$PROJECT_ROOT/tests/test-issue-103-suite-manifest.sh"
SIBLING_103_PIN_DOCS="$PROJECT_ROOT/tests/test-issue-103-pin-and-docs.sh"

# §3.10b — the retired 59-sourcing row is gone; the surviving 27-sourcing row
# is no longer the untightened bare-substring predicate (GATE:PLAN finding (a)
# reproduced against this cycle: docs/doc-invariant-registry.md:392, ledger).
OLD_59_SOURCING_ROW=$(cat <<'EOF'
grep -q 'harness-pins.sh' '$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh'
EOF
)
OLD_27_SOURCING_ROW=$(cat <<'EOF'
grep -q 'harness-pins.sh' '$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh'
EOF
)
assert_true "pin-home-sourcing-preserved: tests/test-issue-103-suite-manifest.sh's retired 'test-issue-59 sources tests/lib/harness-pins.sh' row is gone" \
  '! grep -qF -- "$OLD_59_SOURCING_ROW" "$SIBLING_103_MANIFEST"'
assert_true "pin-home-sourcing-preserved: tests/test-issue-103-suite-manifest.sh's surviving test-issue-27 sourcing row no longer uses the untightened bare-substring predicate" \
  '! grep -qF -- "$OLD_27_SOURCING_ROW" "$SIBLING_103_MANIFEST"'
# GATE:QUALITY FAIL #1, finding 1: the prior predicate below (`(^|[[:space:]])\.[[:space:]]|source[[:space:]]`)
# never mentioned harness-pins.sh, so it stayed green on ANY non-comment
# source/. line in the file — including the unrelated
# `. "$BASEREF_LIB"` (tests/test-issue-27-composition-oracle.sh:106) or a jq
# `.source ==` line — even after a harness-pins.sh sourcing removal. Tightened
# to require the matched line both has the source/. shape AND names
# harness-pins.sh.
TEST27_SUITE="$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"
HARNESS_PINS_SOURCE_PREDICATE='((^|[[:space:]])\.[[:space:]]|source[[:space:]]).*harness-pins\.sh'
assert_true "pin-home-sourcing-preserved: tests/test-issue-103-suite-manifest.sh still asserts a non-comment source/. line that both sources AND names tests/lib/harness-pins.sh against test-issue-27 (the tightened predicate has teeth on the real file, not just on prose)" \
  "grep -vE '^[[:space:]]*#' '$TEST27_SUITE' | grep -qE '$HARNESS_PINS_SOURCE_PREDICATE'"

# Teeth check (scratch, sed/grep-filtered COPY only — nothing is committed):
# the tightened predicate above must FLIP RED when the real harness-pins.sh
# sourcing line is removed from test-issue-27, or it is satisfied by
# something else in the file (exactly the GATE:QUALITY #1 finding). This
# demonstrates the predicate has teeth rather than merely asserting it does.
TEETH_COPY="$(mktemp)"
grep -vF 'source "$PROJECT_ROOT/tests/lib/harness-pins.sh"' "$TEST27_SUITE" > "$TEETH_COPY"
assert_true "pin-home-sourcing-preserved teeth-check: the tightened predicate reds against a scratch copy of test-issue-27 with its harness-pins.sh sourcing line removed (proves it is not satisfied by an unrelated source/. line, e.g. tests/lib/base-ref.sh's BASEREF_LIB sourcing)" \
  "! (grep -vE '^[[:space:]]*#' '$TEETH_COPY' | grep -qE '$HARNESS_PINS_SOURCE_PREDICATE')"
rm -f "$TEETH_COPY"

# §3.10c — the 62/56 positive-presence rows are flipped, not left green on a
# claim this cycle retires.
OLD_62_PRESENCE_ROW=$(cat <<'EOF'
grep -qF 'EXPECTED_OK=58' '$SUITE_62'
EOF
)
OLD_56_TAUTOLOGY_ROW=$(cat <<'EOF'
[ -f '$SUITE_56' ]
EOF
)
assert_true "ok-count-foreign-home-presence-pin-flipped: tests/test-issue-103-pin-and-docs.sh's 62 positive-presence row (EXPECTED_OK=58) is retired" \
  '! grep -qF -- "$OLD_62_PRESENCE_ROW" "$SIBLING_103_PIN_DOCS"'
assert_true "ok-count-foreign-home-presence-pin-flipped: tests/test-issue-103-pin-and-docs.sh's 56 row is no longer the file-existence tautology [ -f \$SUITE_56 ]" \
  '! grep -qF -- "$OLD_56_TAUTOLOGY_ROW" "$SIBLING_103_PIN_DOCS"'
assert_true "ok-count-foreign-home-presence-pin-flipped: test-issue-62 carries no EXPECTED_OK= literal at all (successor form both rows flip to)" \
  "! grep -qE 'EXPECTED_OK=' '$SUITE_62'"
assert_true "ok-count-foreign-home-presence-pin-flipped: test-issue-56 carries no EXPECTED_OK= literal at all (successor form both rows flip to)" \
  "! grep -qE 'EXPECTED_OK=' '$SUITE_56'"

# =============================================================================
# docs/doc-invariant-registry.md §12 / §12.1
# =============================================================================
DOC_REGISTRY="$PROJECT_ROOT/docs/doc-invariant-registry.md"

doc_section_body() { # <file> <start-line-regex> <end-line-regex-or-empty>
  awk -v start="$2" -v end="$3" '
    $0 ~ start { grab = 1; next }
    grab && end != "" && $0 ~ end { grab = 0 }
    grab { print }
  ' "$1"
}

disposition_row_names() { # <table-body-text> <needle>
  # A dedicated disposition row's asset cell IS the suite path (optionally
  # backtick-wrapped, optionally with trailing annotation) — anchored at the
  # cell's start, not "mentions it anywhere". A pre-existing row that merely
  # PARENTHESISES the path inside a longer prose asset cell (this tree already
  # has such rows for other subjects) is not a dedicated disposition row for
  # it and must not satisfy this check.
  printf '%s\n' "$1" | awk -v needle="$2" -F'|' '
    NF >= 4 {
      cell = $2
      gsub(/^[ \t]+|[ \t]+$/, "", cell)
      gsub(/`/, "", cell)
      if (index(cell, needle) == 1) found = 1
    }
    END { exit(found ? 0 : 1) }
  '
}

SEC_12_BODY="$(doc_section_body "$DOC_REGISTRY" '^## 12\.' '^### 12\.1')"
SEC_121_BODY="$(doc_section_body "$DOC_REGISTRY" '^### 12\.1' '^## [0-9]')"

# ---------------------------------------------------------------------------
# normative-status-declared (presence half) — §12 states a verdict for an
# array-less dev/*-issue-<N> gate. Adequacy (does the wording actually settle
# the class for a future auditor) is a reading judgement, delegated to
# tests/manual/issue-107-manual-scenarios.md per the verification design.
# ---------------------------------------------------------------------------
assert_true "normative-status-declared (presence): §12 states a normative verdict for an array-less dev/*-issue-<N> gate (no cycle-arm, no allow-list array)" \
  "printf '%s' \"\$SEC_12_BODY\" | grep -qiE 'array-less|non-conforming'"

# ---------------------------------------------------------------------------
# disposition-recorded — §12.1 carries a three-cell disposition row naming
# each retired arm's suite.
# ---------------------------------------------------------------------------
for rel in \
  "tests/test-issue-43-report-channel-contract.sh" \
  "tests/test-issue-51-teammate-removal-verdict.sh" \
  "tests/test-issue-52-peer-facilitator-premise.sh" \
  "tests/test-issue-56-carry-evidence-discipline.sh" \
  "tests/test-issue-59-adoption-evidence-discipline.sh" \
  "tests/test-issue-62-sequential-rounds.sh"
do
  assert_true "disposition-recorded: §12.1 carries a disposition row naming $rel" \
    "disposition_row_names \"\$SEC_121_BODY\" '$rel'"
done

# ---------------------------------------------------------------------------
# retained-arm-registered (conditional) — vacuous only when arm-removed holds
# for every named suite; its antecedent (a surviving gate) is independently
# derived here, not a flag the implementation sets.
# ---------------------------------------------------------------------------
ANY_LIVE_GATE=0
for pair in "$SUITE_43:43" "$SUITE_51:51" "$SUITE_52:52" "$SUITE_56:56" "$SUITE_59:59" "$SUITE_62:62"; do
  f="${pair%%:*}"; n="${pair##*:}"
  if [ -n "$(cycle_arm_residue_live_gate_numbers "$f")" ]; then
    ANY_LIVE_GATE=1
    rel="tests/$(basename "$f")"
    assert_true "retained-arm-registered: $rel still carries a dev/*-issue-$n gate, so §12 must name it with a retention ground" \
      "printf '%s' \"\$SEC_12_BODY\$SEC_121_BODY\" | grep -qF '$rel'"
  fi
done
if [ "$ANY_LIVE_GATE" -eq 0 ]; then
  TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
  echo "  PASS (vacuous): retained-arm-registered — no touched suite retains a live gate, nothing to register"
fi

# ---------------------------------------------------------------------------
# kept-row-anchor-resolves — §12.1's kept row for guard_result_at_ref_mutated
# cites a path:line-range; that range must contain the function's definition
# line on the real post-change file. Re-derived from whatever the row
# currently says, not from a fixed line number, since the deletions above it
# shift the anchor.
# ---------------------------------------------------------------------------
KEPT_ROW="$(printf '%s\n' "$SEC_121_BODY" | grep -F 'guard_result_at_ref_mutated' | head -1)"
KEPT_ANCHOR="$(printf '%s' "$KEPT_ROW" | grep -oE 'tests/test-issue-62-sequential-rounds\.sh:[0-9]+-[0-9]+' | head -1)"
assert_true "kept-row-anchor-resolves: §12.1's kept row cites a tests/test-issue-62-sequential-rounds.sh:<start>-<end> anchor for guard_result_at_ref_mutated" \
  "[ -n \"\$KEPT_ANCHOR\" ]"
if [ -n "$KEPT_ANCHOR" ]; then
  ANCHOR_RANGE="${KEPT_ANCHOR##*:}"
  ANCHOR_START="${ANCHOR_RANGE%-*}"
  ANCHOR_END="${ANCHOR_RANGE#*-}"
  assert_true "kept-row-anchor-resolves: the cited range $KEPT_ANCHOR contains the guard_result_at_ref_mutated() definition line on the real file" \
    "sed -n \"${ANCHOR_START},${ANCHOR_END}p\" '$SUITE_62' | grep -qE 'guard_result_at_ref_mutated\\(\\)[[:space:]]*\\{'"
fi

# =============================================================================
# This cycle's own dispositions — issue #120 (state direction: what the
# registry provenance section and the deletion/keystone set claim must
# actually hold in the tree at HEAD). The converse (delta) direction — an arm
# or file that left the tree with no provenance row and no registry entry —
# is the cycle-scoped tests/test-issue-120-arm-reconciliation.sh; that layer
# reads the base-ref diff and cannot live in this standing suite (verification
# design .autoflow/issue-120-verification-design.md > Verification layers).
# =============================================================================
echo ""
echo "=== Issue #120 — disposition residue (deletion set, keystone retirement, firewall pins, #51 note, provenance section) ==="

SUITE_ADR0016_PATH="$PROJECT_ROOT/tests/adr-0016-conformance-check.sh"
SUITE_42_PATH="$PROJECT_ROOT/tests/test-issue-42-spawn-mode-contract.sh"
SUITE_109="$PROJECT_ROOT/tests/test-issue-109-doc-assertions.sh"
SUITE_16="$PROJECT_ROOT/tests/test-issue-16-manifest-locale-invariance.sh"
SUITE_71="$PROJECT_ROOT/tests/test-issue-71-digest-removal.sh"
SUITE_51_120="$PROJECT_ROOT/tests/test-issue-51-teammate-removal-verdict.sh"
FIXTURE_ADR0016_BASELINE="$PROJECT_ROOT/tests/fixtures/issue-109-assertion-baseline-adr0016.txt"
MANUAL_42="$PROJECT_ROOT/tests/manual/issue-42-manual-scenarios.md"
WORKFLOW_CONTRACT="$PROJECT_ROOT/.github/workflows/contract-suites.yml"
WORKFLOW_E2E="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

# ---------------------------------------------------------------------------
# arm-removed (file level) — the two full-file deletions (feature design §2).
# ---------------------------------------------------------------------------
assert_true "120 arm-removed: tests/adr-0016-conformance-check.sh is deleted (every arm migrated, retired against a carrier, or dropped with recorded coverage loss)" \
  "[ ! -f '$SUITE_ADR0016_PATH' ]"
assert_true "120 arm-removed: tests/test-issue-42-spawn-mode-contract.sh is deleted (every arm migrated or retired against a carrier)" \
  "[ ! -f '$SUITE_42_PATH' ]"

# ---------------------------------------------------------------------------
# keystone-remnant-gone — feature design §3: the adr-0016 half of the #109
# keystone is retired in the same change that deletes its subject, so nothing
# reads a file that no longer exists (which would otherwise pass vacuously on
# empty $(cat ...) content).
# ---------------------------------------------------------------------------
assert_true "120 keystone-remnant-gone: tests/fixtures/issue-109-assertion-baseline-adr0016.txt is deleted" \
  "[ ! -f '$FIXTURE_ADR0016_BASELINE' ]"
assert_true "120 keystone-remnant-gone: test-issue-109's SUITE_ADR0016/_CONTENT/_HEADER variables are gone" \
  "! grep -qE '^SUITE_ADR0016(_CONTENT|_HEADER)?=' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109's GROUP_D_ADR0016 array is gone" \
  "! grep -qE '^GROUP_D_ADR0016=' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109's loop over GROUP_D_ADR0016 is gone" \
  "! grep -qF 'for id in \"\${GROUP_D_ADR0016[@]}\"' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109's AC1-AC6 blanket-claim arm for adr-0016 is gone" \
  "! grep -qF 'no longer claims blanket AC1-AC6 coverage' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109's AC-961-5/AC-961-7 inline-list loop for adr-0016 is gone" \
  "! grep -qE 'for id in \"AC-961-5\" \"AC-961-7\"' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109's AC-carrier-recorded path loop no longer iterates tests/adr-0016-conformance-check.sh" \
  "ctx=\$(grep -A6 -F 'for path in \"tests/test-issue-798-topology-flip.sh\"' '$SUITE_109'); ! grep -qF 'tests/adr-0016-conformance-check.sh' <<<\"\$ctx\""
assert_true "120 keystone-remnant-gone: test-issue-109's ci-subject header no longer declares tests/adr-0016-conformance-check.sh" \
  "! grep -qE '^# ci-subject:.*tests/adr-0016-conformance-check\\.sh' '$SUITE_109'"
assert_true "120 keystone-remnant-gone: test-issue-109 carries no remaining mention of adr-0016-conformance-check.sh (comment or code — catch-all)" \
  "! grep -qF 'adr-0016-conformance-check.sh' '$SUITE_109'"
assert_true "120 keystone-remnant-gone (guard, PASS pre+post): §13's carrier rows naming tests/adr-0016-conformance-check.sh still exist in the registry (feature design §3 — the rows record where the arms went and stay true after the file is gone)" \
  "grep -qF 'tests/adr-0016-conformance-check.sh' '$PROJECT_ROOT/docs/doc-invariant-registry.md'"

# ---------------------------------------------------------------------------
# firewall-pin-gone — feature design §4: the two executable inbound pins on a
# deleted file, plus their comment-only siblings.
# ---------------------------------------------------------------------------
assert_true "120 firewall-pin-gone: test-issue-16's ADR_0016_TEST variable and AC4-adr0016-suite-exists arm are gone" \
  "! grep -qE 'ADR_0016_TEST=|AC4-adr0016-suite-exists' '$SUITE_16'"
assert_true "120 firewall-pin-gone: test-issue-16 carries no remaining mention of adr-0016-conformance-check.sh (comment-only citations included)" \
  "! grep -qF 'adr-0016-conformance-check.sh' '$SUITE_16'"

assert_true "120 firewall-pin-gone: test-issue-71's AC-71-CITATION banner/arms and ADR0016_SUITE variable are gone" \
  "! grep -qE 'AC-71-CITATION|ADR0016_SUITE=' '$SUITE_71'"
assert_true "120 firewall-pin-gone: test-issue-71's ci-subject header no longer declares tests/adr-0016-conformance-check.sh" \
  "! grep -qE '^# ci-subject:.*tests/adr-0016-conformance-check\\.sh' '$SUITE_71'"
assert_true "120 firewall-pin-gone: test-issue-71's allow_list array no longer names tests/adr-0016-conformance-check.sh" \
  "ctx=\$(grep -A200 '^allow_list=' '$SUITE_71'); ! grep -qF 'tests/adr-0016-conformance-check.sh' <<<\"\$ctx\""

SUITE_43_120="$PROJECT_ROOT/tests/test-issue-43-report-channel-contract.sh"
# feature design §4's cited :73 comment names the OTHER deletion target
# (tests/test-issue-42-spawn-mode-contract.sh — "same approach as
# tests/test-issue-42-spawn-mode-contract.sh."), not adr-0016-conformance-
# check.sh; the earlier form of this arm checked the wrong filename and
# read as satisfied on an untouched line. Check both deleted suites. A line
# mentioning either is a violation UNLESS it also carries a tombstone
# marker ("formerly …" / "… retired in #120") — a retrospective citation of
# a deleted file's own history is not a stale present-tense reference to it.
FORTYTHREE_STALE_LINES_120="$(grep -nE 'tests/adr-0016-conformance-check\.sh|tests/test-issue-42-spawn-mode-contract\.sh' "$SUITE_43_120" 2>/dev/null || true)"
FORTYTHREE_NONTOMBSTONE_120="$(printf '%s\n' "$FORTYTHREE_STALE_LINES_120" | grep -vE 'retired in #120|[Ff]ormerly' || true)"
assert_true "120 stale-citation-gone: tests/test-issue-43-report-channel-contract.sh carries no present-tense citation of either deleted suite (adr-0016-conformance-check.sh or test-issue-42-spawn-mode-contract.sh) — a tombstone phrasing ('formerly …', '… retired in #120') is allowed (non-tombstone hits: $(printf '%s' "$FORTYTHREE_NONTOMBSTONE_120" | paste -sd';' -))" \
  "[ -z \"\$FORTYTHREE_NONTOMBSTONE_120\" ]"
assert_true "120 stale-citation-gone: tests/test-run-doc-invariants.sh no longer mentions adr-0016-conformance-check.sh (comment-only citation)" \
  "! grep -qF 'adr-0016-conformance-check.sh' '$PROJECT_ROOT/tests/test-run-doc-invariants.sh'"
assert_true "120 stale-citation-gone: scripts/test/check-suite-manifest.sh no longer mentions adr-0016-conformance-check.sh (comment-only citation)" \
  "! grep -qF 'adr-0016-conformance-check.sh' '$PROJECT_ROOT/scripts/test/check-suite-manifest.sh'"
assert_true "120 stale-citation-gone: tests/manual/issue-42-manual-scenarios.md's header no longer cites tests/test-issue-42-spawn-mode-contract.sh (feature design §4)" \
  "! grep -qF 'tests/test-issue-42-spawn-mode-contract.sh' '$MANUAL_42'"
assert_true "120 stale-citation-gone (guard, PASS pre+post): tests/manual/issue-42-manual-scenarios.md still cites its registry-entry reference '42-AC*' — the document is retained, not retired" \
  "grep -qF '42-AC*' '$MANUAL_42'"

assert_true "120 firewall-workflow: .github/workflows/contract-suites.yml carries no paths:/run: entry for tests/adr-0016-conformance-check.sh" \
  "! grep -qF 'tests/adr-0016-conformance-check.sh' '$WORKFLOW_CONTRACT'"
assert_true "120 firewall-workflow: .github/workflows/e2e-dummy-target.yml carries no paths:/run: entry for tests/adr-0016-conformance-check.sh or tests/test-issue-42-spawn-mode-contract.sh" \
  "! grep -qE 'tests/adr-0016-conformance-check\\.sh|tests/test-issue-42-spawn-mode-contract\\.sh' '$WORKFLOW_E2E'"

# ---------------------------------------------------------------------------
# #51 note — feature design §6: the TEMPORARY sentence no longer names AC12,
# the PERMANENT list still does (CI wiring, not registry-expressible), and
# the two are not left in mutual contradiction.
# ---------------------------------------------------------------------------
SUITE_51_120_TEMP_SENTENCE="$(grep -B3 -F 'TEMPORARY discriminators here' "$SUITE_51_120" 2>/dev/null || true)"
SUITE_51_120_PERM_BLOCK="$(doc_section_body "$SUITE_51_120" 'PERMANENTLY in this file' '^# This file once carried')"

assert_true "120 #51-AC12-struck: the TEMPORARY-discriminator sentence (if any remains) no longer names AC12 as a bounded token" \
  "! printf '%s\n' \"\$SUITE_51_120_TEMP_SENTENCE\" | grep -qE '(^|[^0-9A-Za-z-])AC12([^0-9A-Za-z-]|\$)'"
assert_true "120 #51-AC12-retained-permanent (guard, PASS pre+post): the PERMANENT list still names AC12 as CI wiring" \
  "printf '%s\n' \"\$SUITE_51_120_PERM_BLOCK\" | grep -qE 'AC12.*CI wiring|CI wiring.*AC12'"

# ---------------------------------------------------------------------------
# provenance section — docs/doc-invariant-registry.md carries a #120 section
# following the §5/§16 shape (one table, one row per disposition, three
# columns: arm / disposition / basis). Row-content checks (F3's row-form-by-
# disposition-class separability) follow.
# ---------------------------------------------------------------------------
DOC_REGISTRY_120="$PROJECT_ROOT/docs/doc-invariant-registry.md"
SEC_120_BODY="$(doc_section_body "$DOC_REGISTRY_120" '^## [0-9]+\. .*\(issue #120\)' '^## [0-9]+\.')"

assert_true "120 provenance-section-exists: docs/doc-invariant-registry.md carries a migration-provenance section for issue #120" \
  "[ -n \"\$SEC_120_BODY\" ]"

REGISTRY_IDS_120="$(jq -r '.invariants[].id' "$PROJECT_ROOT/tests/fixtures/doc-invariants.json" 2>/dev/null || true)"
CITED_120_CARRIER_IDS="$(printf '%s' "$SEC_120_BODY" | grep -oE '\`120-[A-Za-z0-9._-]+\`' | tr -d '\`' | sort -u || true)"

assert_true "120 provenance-conformance (non-vacuous): the #120 section cites at least one backtick-quoted 120-* carrier id (this cycle's migrated arms have carriers)" \
  "[ -n \"\$CITED_120_CARRIER_IDS\" ]"

UNRESOLVED_120_IDS=""
for id in $CITED_120_CARRIER_IDS; do
  if ! printf '%s\n' "$REGISTRY_IDS_120" | grep -qxF "$id"; then
    UNRESOLVED_120_IDS="$UNRESOLVED_120_IDS $id"
  fi
done
assert_true "120 provenance-conformance: every backtick-quoted 120-* carrier id cited in the #120 section resolves against tests/fixtures/doc-invariants.json's live id set (unresolved:${UNRESOLVED_120_IDS:- none})" \
  "[ -z \"\$UNRESOLVED_120_IDS\" ]"

DROPPED_ROWS_WITH_CARRIER_120="$(awk -F'|' '
  NF >= 4 {
    disp = $3; basis = $4
    if (disp ~ /dropped/ && basis ~ /`120-[A-Za-z0-9._-]+`/) print
  }
' <<<"$SEC_120_BODY")"
assert_true "120 provenance-class (guard, PASS pre+post): no dropped-class row in the #120 section cites a carrier id (a dropped row states lost coverage, never a carrier)" \
  "[ -z \"\$DROPPED_ROWS_WITH_CARRIER_120\" ]"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
