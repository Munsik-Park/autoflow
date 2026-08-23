#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: CLAUDE.md docs/ .claude/workflows/ .claude/agents/
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: verdict-enum coherence — every line naming both CONVERGED and
#       ESCALATE also names AC_CHANGE (issue #138, GATE:QUALITY attempt 3,
#       ledger O9)
# =============================================================================
# Issue #138 widened the ARCHITECT facilitator's return verdict from a
# two-valued enum (CONVERGED | ESCALATE) to a three-valued one
# (CONVERGED | AC_CHANGE | ESCALATE). RED3/RED4/RED5 each pinned individual
# sites where a doc or a script comment restated the stale two-valued shape,
# and each round the enum-sweep found MORE such sites — the per-site `absent`
# pin does not generalize, because the restatement class recurs anywhere the
# two literals CONVERGED and ESCALATE are named together without AC_CHANGE.
#
# This suite replaces the per-site instrument with a STANDING PROPERTY: over
# every text line under the roots this suite's own ci-subject declares
# (CLAUDE.md, docs/**, .claude/workflows/**, .claude/agents/**), a line that
# names both `CONVERGED` and `ESCALATE` must also name `AC_CHANGE` on that
# same line — unless the line is listed in the committed allow-list
# (tests/fixtures/verdict-enum-allowlist.txt), reserved for lines that are
# LEGITIMATELY two-valued (a necessary-condition statement about CONVERGED
# alone that happens to also mention ESCALATE as the alternative outcome of a
# narrower, pre-Reconcile decision, or a historical ADR record of a decision
# made before #138 widened the enum).
#
# The 4 sites the enum-sweep found at RED (verbatim, expected to still FAIL
# here until GREEN4 fixes them -- see .autoflow/issue-138-red6-report.md):
#   .claude/workflows/architect-deliberation.js:674
#   docs/teammate-contracts.md:174
#   docs/teammate-contracts.md:194
#   docs/autoflow-guide.md:475
# None of the four is allow-listed: each is exactly the restatement class
# this suite exists to catch, not a legitimately two-valued statement -- a
# round's closing verdict, or a resume round's outcome, can still turn into
# AC_CHANGE once Reconcile runs after Converge, so "this verdict alone
# decides CONVERGED versus ESCALATE" / "may end in CONVERGED ... Otherwise
# ... ESCALATE" is stale, not narrower-but-true.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOWLIST="$PROJECT_ROOT/tests/fixtures/verdict-enum-allowlist.txt"

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

# scan_violations <root> [<root> ...] <allowlist-path>
# Prints one "path:lineno:content" line per violation found under the given
# roots, after excluding lines the allow-list covers for that exact path.
# The allow-list format is `<path>:<literal-substring>` (one entry per line,
# blank lines and lines starting with '#' ignored; an optional trailing
# `  # <reason>` comment on a data line is stripped before matching) -- an
# entry excludes a violation on <path> whose content contains
# <literal-substring> verbatim.
scan_violations() {
  local allowlist="${@: -1}"
  local roots=("${@:1:$#-1}")

  local hits
  hits="$(grep -rnE 'CONVERGED' "${roots[@]}" 2>/dev/null \
    | grep -E 'ESCALATE' \
    | grep -v 'AC_CHANGE' || true)"

  [ -z "$hits" ] && return 0

  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    local path="${hit%%:*}"
    local excluded=0
    if [ -f "$allowlist" ]; then
      while IFS= read -r entry; do
        entry="${entry%%#*}"
        entry="$(printf '%s' "$entry" | sed -E 's/[[:space:]]+$//')"
        [ -z "$entry" ] && continue
        local entry_path="${entry%%:*}"
        local entry_substr="${entry#*:}"
        if [ "$entry_path" = "$path" ] && printf '%s' "$hit" | grep -qF "$entry_substr"; then
          excluded=1
          break
        fi
      done < "$allowlist"
    fi
    [ "$excluded" -eq 0 ] && printf '%s\n' "$hit"
  done <<< "$hits"
}

echo "=== AC-verdict-enum-coherence: standing property over the real tree ==="

REAL_VIOLATIONS="$(scan_violations "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/docs" "$PROJECT_ROOT/.claude/workflows" "$PROJECT_ROOT/.claude/agents" "$ALLOWLIST")"

if [ -n "$REAL_VIOLATIONS" ]; then
  echo "  FAIL: AC-verdict-enum-coherence: found $(printf '%s\n' "$REAL_VIOLATIONS" | grep -c .) line(s) naming CONVERGED and ESCALATE without AC_CHANGE, not covered by the allow-list:"
  while IFS= read -r v; do
    echo "    $v" | head -c 240
    echo
  done <<< "$REAL_VIOLATIONS"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: AC-verdict-enum-coherence: no uncovered two-valued restatement found"
  PASS=$((PASS + 1))
fi
TESTS=$((TESTS + 1))

echo ""
echo "=== AC-verdict-enum-teeth: negative self-test (injected violation must be caught) ==="

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/docs"
cat > "$TMP_ROOT/docs/injected-violation.md" <<'EOF'
# Scratch fixture — negative self-test only

This line names `CONVERGED` and `ESCALATE` together and deliberately omits
the third verdict, so the checker must flag it.
EOF

INJECTED="$(scan_violations "$TMP_ROOT/docs" "$ALLOWLIST")"
assert_true "AC-verdict-enum-teeth: an injected two-valued line (not on the allow-list) is DETECTED" \
  '[ -n "$INJECTED" ]'
assert_true "AC-verdict-enum-teeth: the detected line names the injected fixture path" \
  'printf "%s" "$INJECTED" | grep -qF "injected-violation.md"'

echo ""
echo "=== AC-verdict-enum-allowlist-respected: an allow-listed line is excluded ==="

ALLOWLISTED_TMP_ROOT="$(mktemp -d)"
mkdir -p "$ALLOWLISTED_TMP_ROOT/docs"
cat > "$ALLOWLISTED_TMP_ROOT/docs/allowlisted.md" <<'EOF'
# Scratch fixture — allow-list exclusion self-test only

This line names CONVERGED and ESCALATE for the allow-list exclusion test.
EOF
ALLOWLIST_TMP="$(mktemp)"
cat > "$ALLOWLIST_TMP" <<EOF
$ALLOWLISTED_TMP_ROOT/docs/allowlisted.md:for the allow-list exclusion test
EOF

ALLOWLISTED_HITS="$(scan_violations "$ALLOWLISTED_TMP_ROOT/docs" "$ALLOWLIST_TMP")"
assert_true "AC-verdict-enum-allowlist-respected: an allow-listed line is EXCLUDED, not reported" \
  '[ -z "$ALLOWLISTED_HITS" ]'

rm -rf "$ALLOWLISTED_TMP_ROOT" "$ALLOWLIST_TMP"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
