#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# doc-invariant registry runner — Issue #951 (AC1/AC2/AC5)
# =============================================================================
# The single runner that replaces the per-issue doc-assertion suites. It reads
# the declarative registry (tests/fixtures/doc-invariants.json) via jq,
# resolves each entry's section by DURABLE HEADING ANCHOR (never a line
# number), evaluates its STATE predicate against the CURRENT file state, prints
# one PASS/FAIL line per entry, and exits non-zero on any FAIL.
#
# STATE-ONLY: no entry reads a diff or a base ref, so a foreign cycle's diff
# cannot contaminate it and an upstream insertion cannot dislocate it. The
# runner therefore has no silent-skip path for its own invariants (feature
# §4). It does NOT source lib/base-ref.sh — a permanent STATE invariant reads
# no base ref, so there is no base-ref consumer here.
#
# Usage:
#   bash tests/run-doc-invariants.sh [registry.json]
# With no argument it defaults to tests/fixtures/doc-invariants.json (its
# normal CI invocation). An optional positional argument selects an alternate
# registry (used by the RED suite to drive the runner against fixture
# registries hermetically).
#
# Load-time well-formedness gate (step 0, BLOCK exit 1 before any evaluation):
#   - registry parses as JSON; .invariants is a non-empty array;
#   - every entry has id/file/predicate/scope; ids are unique;
#   - predicate is one of present|absent|ordered (any diff/count/delta-shaped
#     predicate is rejected — DELTA guards are cycle-scoped, never in the
#     registry, see docs/doc-invariant-registry.md);
#   - scope is exactly "permanent";
#   - each entry's section (and section_end when set) resolves to EXACTLY ONE
#     heading in entry.file (0 -> dangling anchor, >1 -> ambiguous anchor).
#
# The per-entry fields are read in a SINGLE jq pass (base64-encoded columns) so
# the runner stays fast enough to be driven hundreds of times by the RED suite.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGISTRY="${1:-$SCRIPT_DIR/fixtures/doc-invariants.json}"

PASS=0; FAIL=0; TESTS=0

block() {
  echo "BLOCK: $*" >&2
  echo "BLOCK: $*"
  exit 1
}

d64() { printf '%s' "$1" | base64 --decode; }

# ---------------------------------------------------------------------------
# Section extractor — resolves a heading anchor to its section body.
# Exact-match anchor (stripped-text equality, C6): a heading with regex
# metacharacters, or one that is a substring of a sibling, cannot resolve the
# wrong section. Level-aware close: a section owns its lower-level subsections
# until the next same-or-higher-level heading (or an explicit section_end
# heading, or a thematic-break terminator). Never shrinks below the source
# window of the migrated suites' forked extractors.
# ---------------------------------------------------------------------------
extract_section() {          # heading_text file [section_end]
  local heading="$1" file="$2" endpat="${3:-}"
  awk -v h="$heading" -v endpat="$endpat" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (endpat!="" && /^#{1,6} +/ && $0 ~ endpat)  { f=0; next }
      else if (/^#{1,6} +/ && level($0)<=L)          { f=0; next }
      else if (endpat=="" && /^---[ \t]*$/)          { f=0; next }
      else print
    }
  ' "$file"
}

# Count headings in a file whose stripped text equals the anchor exactly.
count_heading() {            # anchor file
  local anchor="$1" file="$2"
  awk -v h="$anchor" '
    /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) c++
    }
    END { print c+0 }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Step 0 — load-time well-formedness gate (structural)
# ---------------------------------------------------------------------------
# The registry is read as the FIRST JSON value in the file (`jq -n 'input'`),
# so a trailing non-JSON line appended by a no-op touch does not change the
# verdict — the state-only design has no dependence on the exact bytes of the
# registry file beyond its first JSON value.
[ -f "$REGISTRY" ] || block "registry not found: $REGISTRY"
jq -n 'input' "$REGISTRY" >/dev/null 2>&1 || block "registry is not valid JSON: $REGISTRY"
jq -e -n 'input | (.invariants | type == "array") and (.invariants | length > 0)' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: .invariants must be a non-empty array"
jq -e -n 'input | all(.invariants[]; has("id") and has("file") and has("predicate") and has("scope"))' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: every entry must carry id/file/predicate/scope"
jq -e -n 'input | ([.invariants[].id] | length) == ([.invariants[].id] | unique | length)' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: entry ids must be unique"
jq -e -n 'input | all(.invariants[]; .predicate == "present" or .predicate == "absent" or .predicate == "ordered")' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: predicate must be one of present|absent|ordered (diff/count/delta predicates are cycle-scoped, not permanent)"
jq -e -n 'input | all(.invariants[]; .scope == "permanent")' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: every entry scope must be \"permanent\" (a cycle-scoped guard belongs in its cycle's RED suite, not the registry)"

# Read all entries in ONE jq pass: base64-encoded columns, colon-separated.
# Colon is outside the base64 alphabet (A-Za-z0-9+/=), and unlike a tab it is
# not IFS-whitespace, so empty columns (e.g. section:null) survive `read`.
ROWS="$(jq -rn 'input | .invariants[] | [
  (.id|@base64), (.file|@base64), ((.section//"")|@base64), ((.section_end//"")|@base64),
  (.predicate|@base64), ((.match//"fixed")|@base64), ((.literal//"")|@base64),
  ((.before//"")|@base64), ((.after//"")|@base64)
] | join(":")' "$REGISTRY")"

# ---------------------------------------------------------------------------
# Step 0b — anchor well-formedness: each section (and section_end) resolves to
# exactly one heading in its file. section:null => whole-file scope, skipped.
# ---------------------------------------------------------------------------
while IFS=: read -r id_b file_b sec_b end_b pred_b match_b lit_b before_b after_b; do
  [ -n "$id_b" ] || continue
  id="$(d64 "$id_b")"; file="$(d64 "$file_b")"
  section="$(d64 "$sec_b")"; section_end="$(d64 "$end_b")"
  srcfile="$PROJECT_ROOT/$file"
  [ -f "$srcfile" ] || continue
  if [ -n "$section" ]; then
    n="$(count_heading "$section" "$srcfile")"
    [ "$n" -eq 0 ] && block "dangling anchor: entry $id section '$section' resolves to no heading (0 matches) in $file"
    [ "$n" -gt 1 ] && block "ambiguous anchor: entry $id section '$section' resolves to multiple headings ($n matches) in $file"
  fi
  if [ -n "$section_end" ]; then
    n="$(count_heading "$section_end" "$srcfile")"
    [ "$n" -eq 0 ] && block "dangling anchor: entry $id section_end '$section_end' resolves to no heading (0 matches) in $file"
    [ "$n" -gt 1 ] && block "ambiguous anchor: entry $id section_end '$section_end' resolves to multiple headings ($n matches) in $file"
  fi
done <<< "$ROWS"

# ---------------------------------------------------------------------------
# grep flavor per entry match mode
# ---------------------------------------------------------------------------
body_has() {                 # body literal match
  local body="$1" literal="$2" match="$3"
  if [ "$match" = "regex" ]; then
    grep -qE -- "$literal" <<<"$body"
  else
    grep -qF -- "$literal" <<<"$body"
  fi
}

first_line_of() {            # body literal match -> line number or empty
  local body="$1" literal="$2" match="$3" out
  if [ "$match" = "regex" ]; then
    out="$(grep -nE -- "$literal" <<<"$body" || true)"
  else
    out="$(grep -nF -- "$literal" <<<"$body" || true)"
  fi
  printf '%s\n' "$out" | head -1 | cut -d: -f1
}

record() {                   # verdict id detail
  local verdict="$1" id="$2" detail="$3"
  TESTS=$((TESTS + 1))
  if [ "$verdict" = "PASS" ]; then
    echo "  PASS: $id $detail"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $id $detail"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Step 1 — evaluate each entry against current file state
# ---------------------------------------------------------------------------
echo "=== doc-invariant registry: $(basename "$REGISTRY") ==="
while IFS=: read -r id_b file_b sec_b end_b pred_b match_b lit_b before_b after_b; do
  [ -n "$id_b" ] || continue
  id="$(d64 "$id_b")"; file="$(d64 "$file_b")"
  section="$(d64 "$sec_b")"; section_end="$(d64 "$end_b")"
  predicate="$(d64 "$pred_b")"; match="$(d64 "$match_b")"
  srcfile="$PROJECT_ROOT/$file"
  loc="[$file${section:+§$section}] $predicate"

  if [ ! -f "$srcfile" ]; then
    record FAIL "$id" "$loc — missing target file"
    continue
  fi

  if [ -n "$section" ]; then
    body="$(extract_section "$section" "$srcfile" "$section_end")"
  else
    body="$(cat "$srcfile")"
  fi

  case "$predicate" in
    present)
      literal="$(d64 "$lit_b")"
      if body_has "$body" "$literal" "$match"; then
        record PASS "$id" "$loc '$literal'"
      else
        record FAIL "$id" "$loc '$literal'"
      fi
      ;;
    absent)
      literal="$(d64 "$lit_b")"
      if body_has "$body" "$literal" "$match"; then
        record FAIL "$id" "$loc '$literal'"
      else
        record PASS "$id" "$loc '$literal'"
      fi
      ;;
    ordered)
      before="$(d64 "$before_b")"; after="$(d64 "$after_b")"
      bln="$(first_line_of "$body" "$before" "$match")"
      aln="$(first_line_of "$body" "$after" "$match")"
      if [ -n "$bln" ] && [ -n "$aln" ] && [ "$bln" -lt "$aln" ]; then
        record PASS "$id" "$loc '$before' < '$after'"
      else
        record FAIL "$id" "$loc '$before'(${bln:-absent}) < '$after'(${aln:-absent})"
      fi
      ;;
  esac
done <<< "$ROWS"

# ---------------------------------------------------------------------------
# Step 2 — results
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
