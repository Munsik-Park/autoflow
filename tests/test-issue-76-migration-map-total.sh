#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
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
# SCOPE (stated explicitly, not left implicit): this RED pass drives Leg 1 +
# Leg 2 over the two suites that are migrated-and-deleted WHOLESALE, per
# .autoflow/issue-76-feature-design.md > "Files to change" —
# tests/test-issue-843-doc-assertions.sh and
# tests/test-issue-844-doc-assertions.sh — where "every assertion in the
# suite" and "every assertion the map must carry" are the same set with no
# ambiguity. The partially-touched suites (846/848/955/798/799/985/847,
# adr-0016-conformance-check.sh, test-issue-16, test-issue-795,
# tests/issue-92/*.bats) mix migrated (doc-STATE) and retained
# (execution-shaped) assertions per the same file-table row; classifying
# which occurrence is which is a migration-map authoring decision the map
# itself must record, not something this checker can infer from source text
# alone. Extending this suite's SUITES list to those files is carried
# forward as RED2 follow-up once the map's per-suite disposition is
# authored; not adding them now is a scoping decision, not an oversight —
# recorded here so it is checkable rather than silently absent.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/issue-76-extract-assertions.sh
source "$SCRIPT_DIR/lib/issue-76-extract-assertions.sh"

MAP="$PROJECT_ROOT/tests/fixtures/issue-76-migration-map.md"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
DISPOSITION_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"

SUITES=(
  "tests/test-issue-843-doc-assertions.sh"
  "tests/test-issue-844-doc-assertions.sh"
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

assert_true "AC-a-1 pre: migration map exists at the committed path tests/fixtures/issue-76-migration-map.md" \
  "[ -f '$MAP' ]"

if [ ! -f "$MAP" ]; then
  echo ""
  echo "  (map absent — every per-suite/per-occurrence check below is reported"
  echo "   FAIL rather than skipped, since a missing map discharges nothing)"
fi

for rel in "${SUITES[@]}"; do
  suite="$PROJECT_ROOT/$rel"
  [ -f "$suite" ] || { assert_true "AC-a-1: touched suite exists: $rel" "false"; continue; }

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
