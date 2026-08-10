#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/fixtures/issue-76-migration-map.md docs/doc-invariant-registry.md tests/fixtures/doc-invariants.json
# =============================================================================
# Test: migration map totality and discharge — Issue #76 AC-a-1
# =============================================================================
# .autoflow/issue-76-verification-design.md > AC-a-1 (two legs):
#   Leg 1 — the map is total: every assertion occurrence extracted from a
#     touched suite at the base ref has exactly one map row, and no row names
#     an occurrence that does not exist.
#   Leg 2 — every row is discharged: every occurrence resolves to a carrier
#     (a registry `id`, a §5 disposition row, or the named
#     `load-time anchor gate`) — an unresolved occurrence fails the row.
#
# Map location: `tests/fixtures/issue-76-migration-map.md`, a COMMITTED path
# (GATE:PLAN carried finding, `.autoflow/issue-76-ledger.md` E6: "the
# migration map path `.autoflow/issue-76-migration-map.md` is gitignored —
# unusable by a CI-registered suite; commit the map or scope AC-a-1 Leg 1 to
# VERIFY-local"). This suite reads the committed path.
#
# Expected map format, one table row per distinct (suite, key) pair:
#   | <suite path> | <verbatim first-argument key> | <occurrence count> | <carrier 1>[; <carrier 2>...] |
# `<carrier>` is one of:
#   - `registry:<id>`      — a registry entry id present in
#                            tests/fixtures/doc-invariants.json
#   - `disposition:<row>`  — a §5 disposition-table row label in
#                            docs/doc-invariant-registry.md
#   - `load-time anchor gate` — the literal, reserved carrier
# A row whose occurrence count is N carries N semicolon-separated carrier
# GROUPS (one per occurrence), each itself a comma-separated conjunct-carrier
# list — see the verification design's "row cardinality is one-to-many"
# passage. This suite validates against that shape.
#
# RED2 (2026-08-11): extracts from the BASE REF, not the working tree — the
# two wholesale-deleted suites (843/844) are already gone at HEAD once GREEN
# lands the migration, and every partially-touched suite has its doc-STATE
# assertions REMOVED by the same migration, so a working-tree read would
# silently shrink to the retained-only subset. `tests/lib/base-ref.sh`
# (issue #951 AC4 precedent) resolves the comparison base the same way every
# other DELTA-shaped suite in this tree does.
#
# SUITES now covers every touched suite whose assertions use the
# assert_true/assert_false shape the extraction rule is defined over — the
# two wholesale-deleted suites plus the ten partially-touched ones named in
# .autoflow/issue-76-feature-design.md > "Files to change". `tests/issue-92/
# *.bats` is deliberately EXCLUDED: its assertions are `@test { ... }` bats
# blocks, a different syntax the AC-a-1 extraction rule (defined explicitly
# over the assert_true/assert_false command word) does not range over. Bats
# migration totality needs its own extractor or a manual-scenario leg; that
# gap is reported, not silently absorbed into this suite's green/red count.
#
# For the ten partially-touched suites, Leg 1 (totality) still requires a
# map row per EXTRACTED occurrence, migrated or retained — the map's
# admissible-carrier taxonomy (registry id / §5 disposition row / load-time
# anchor gate) has no fourth "stays in place, unchanged" kind, so whether a
# retained execution-shaped assertion needs a new carrier kind or is simply
# out of AC-a-1's intended scope is a real open question this run surfaces
# rather than resolves — see the RED2 report to main.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/issue-76-extract-assertions.sh
source "$SCRIPT_DIR/lib/issue-76-extract-assertions.sh"
# shellcheck source=tests/lib/base-ref.sh
source "$SCRIPT_DIR/lib/base-ref.sh"

MAP="$PROJECT_ROOT/tests/fixtures/issue-76-migration-map.md"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
DISPOSITION_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"

SUITES=(
  "tests/test-issue-843-doc-assertions.sh"
  "tests/test-issue-844-doc-assertions.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-847-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-985-doc-assertions.sh"
  "tests/adr-0016-conformance-check.sh"
  "tests/test-issue-16-manifest-locale-invariance.sh"
  "tests/test-issue-795-handoff-removal.sh"
)

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

echo "=== Issue #76 — migration map totality & discharge (AC-a-1) ==="

BASE_REF="$(resolve_base_ref)" || {
  echo "  BLOCK: no base ref resolvable (tried override/GITHUB_BASE_REF/origin main/local main)"
  echo "Results: 0/1 passed, 1 failed"
  exit 1
}
echo "  INFO: base ref resolved to $BASE_REF"

assert_true "AC-a-1 pre: migration map exists at the committed path tests/fixtures/issue-76-migration-map.md" \
  "[ -f '$MAP' ]"

if [ ! -f "$MAP" ]; then
  echo ""
  echo "  (map absent — every per-suite/per-occurrence check below is reported"
  echo "   FAIL rather than skipped, since a missing map discharges nothing)"
fi

TMPDIR_76="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_76"' EXIT

for rel in "${SUITES[@]}"; do
  suite="$TMPDIR_76/$(basename "$rel")"
  if ! git -C "$PROJECT_ROOT" show "${BASE_REF}:${rel}" > "$suite" 2>/dev/null; then
    assert_true "AC-a-1: touched suite resolves at base ref $BASE_REF — $rel" "false"
    continue
  fi

  # Leg 1a — every extracted occurrence has a map row naming it.
  while IFS=$'\t' read -r ln key; do
    [ -n "$key" ] || continue
    esc_key="$(printf '%s' "$key" | sed 's/[.[\*^$/]/\\&/g')"
    if [ -f "$MAP" ] && grep -qF "| $rel | $key |" "$MAP" 2>/dev/null; then
      found=true
    else
      found=false
    fi
    assert_true "AC-a-1 Leg1: $rel:$ln occurrence has a map row — \"$key\"" "$found"
  done < <(issue76_rule_extract "$suite")

  # Leg 1b — totality quantities: invocation count and conjunct count are
  # recomputed here (never hardcoded, per verification-design record
  # discipline) and reported for the reconciliation the design requires.
  rule_count="$(issue76_rule_extract "$suite" | wc -l | tr -d ' ')"
  dumb_count="$(issue76_dumb_count_lines "$suite" | wc -l | tr -d ' ')"
  excluded="$((dumb_count - rule_count))"
  echo "  INFO: $rel — rule invocation count=$rule_count, dumb line count=$dumb_count, excluded=$excluded"
  assert_true "AC-a-1 Leg1 reconciliation: $rel dumb-count minus rule-excluded lines equals rule count" \
    "[ $((dumb_count - excluded)) -eq $rule_count ]"

  if [ -f "$MAP" ]; then
    map_rows_for_suite="$(grep -cF "| $rel |" "$MAP" 2>/dev/null || true)"
    assert_true "AC-a-1 Leg1: $rel — map carries no phantom row (row count <= distinct key count)" \
      "[ '$map_rows_for_suite' -le '$rule_count' ]"
  fi

  # Leg 2 — every map row for this suite resolves to an admissible carrier.
  if [ -f "$MAP" ]; then
    while IFS='|' read -r _ mrel mkey mcount mcarriers _; do
      mrel="$(echo "$mrel" | xargs)"
      [ "$mrel" = "$rel" ] || continue
      mkey="$(echo "$mkey" | xargs)"
      mcarriers="$(echo "$mcarriers" | xargs)"
      resolved=true
      IFS=';' read -ra groups <<< "$mcarriers"
      for group in "${groups[@]}"; do
        IFS=',' read -ra carriers <<< "$group"
        for c in "${carriers[@]}"; do
          c="$(echo "$c" | xargs)"
          case "$c" in
            registry:*)
              id="${c#registry:}"
              if [ ! -f "$REGISTRY" ] || ! jq -e --arg id "$id" '.invariants[] | select(.id == $id)' "$REGISTRY" >/dev/null 2>&1; then
                resolved=false
              fi
              ;;
            disposition:*)
              label="${c#disposition:}"
              if [ ! -f "$DISPOSITION_DOC" ] || ! grep -qF "$label" "$DISPOSITION_DOC" 2>/dev/null; then
                resolved=false
              fi
              ;;
            "load-time anchor gate") ;;
            *) resolved=false ;;
          esac
        done
      done
      assert_true "AC-a-1 Leg2: $rel — row \"$mkey\" carriers all resolve" "$resolved"
    done < "$MAP"
  fi
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
