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
#   bash tests/run-doc-invariants.sh --self-test [registry.json]
# With no argument it defaults to tests/fixtures/doc-invariants.json (its
# normal CI invocation). An optional positional argument selects an alternate
# registry (used by the RED suite to drive the runner against fixture
# registries hermetically). `--self-test` runs the mutation-teeth mode
# described below; default behaviour and output format are untouched by it.
#
# Load-time well-formedness gate (step 0, BLOCK exit 1 before any evaluation):
#   - registry parses as JSON; .invariants is a non-empty array;
#   - every entry has id/file/predicate/scope; ids are unique;
#   - predicate is one of present|absent|ordered (any diff/count/delta-shaped
#     predicate is rejected — DELTA guards are cycle-scoped, never in the
#     registry, see docs/doc-invariant-registry.md);
#   - scope is exactly "permanent";
#   - section_kind is one of heading|line|block (default "heading"), and
#     section_end is rejected for "line" (a line body is the anchored line);
#   - each entry's section (and section_end when set) resolves to EXACTLY ONE
#     anchor in entry.file, counted by the entry's own section_kind — headings
#     for "heading", fixed column-1 prefix lines for "line"/"block"
#     (0 -> dangling anchor, >1 -> ambiguous anchor).
#
# Anchor kinds (issue #76):
#   heading — current behaviour: stripped-heading text equality, level-aware
#             close, section_end heading or thematic break.
#   line    — `section` is a FIXED-STRING prefix anchored at column 1 and must
#             match exactly one line; the body is that line alone.
#   block   — same anchor resolution; the body runs from the anchored line to
#             the first terminator, TERMINATOR EXCLUDED, with all three
#             terminators live simultaneously and tie-broken in this order on
#             the same line: section_end (same fixed column-1 prefix rule, not
#             required to be a heading) > markdown heading > thematic break.
# `match` selects the grep flavour for the PREDICATE only; it never applies to
# the anchor.
#
# Self-test mode (`--self-test`, issue #76 `teeth-in-runner`): for each entry,
# construct a mutated copy of the entry's target file that MUST break the
# entry's predicate, evaluate the entry in-process against it, and require the
# entry's own predicate to report FAIL. Every non-reacting entry class is a
# diagnostic-bearing NON-CREDIT inside the denominator — an unexpressible
# shape, an ineffective (byte-identical) mutation, a mutator error, and a
# mutation that leaves a "line"/"block" anchor unresolvable. `block()` is not
# reachable from this mode: the load gate runs once at startup over real
# content, and mutated content is evaluated against parsed rows in-process.
#
# The per-entry fields are read in a SINGLE jq pass (base64-encoded columns) so
# the runner stays fast enough to be driven hundreds of times by the RED suite.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SELF_TEST=0
REGISTRY=""
for arg in "$@"; do
  case "$arg" in
    --self-test) SELF_TEST=1 ;;
    *) [ -n "$REGISTRY" ] || REGISTRY="$arg" ;;
  esac
done
REGISTRY="${REGISTRY:-$SCRIPT_DIR/fixtures/doc-invariants.json}"

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
# Non-heading anchor resolution (section_kind "line" / "block", issue #76).
# The anchor is a FIXED-STRING prefix anchored at column 1 — never a regex —
# which is the mode every migrated source extractor used (`grep -m1 '^| 1 |'`,
# `grep -m1 '^\*\*Review-response mode setup\*\*'`, …). Fixed rather than
# regex keeps `| 1 |` and `**Resume procedure**` usable verbatim.
# ---------------------------------------------------------------------------

# Count lines in a file that carry the anchor as a fixed column-1 prefix.
count_line() {               # anchor file
  local anchor="$1" file="$2"
  ANCHOR="$anchor" awk '
    index($0, ENVIRON["ANCHOR"]) == 1 { c++ }
    END { print c+0 }
  ' "$file"
}

# Print the single anchored line (section_kind "line").
extract_line() {             # anchor file
  local anchor="$1" file="$2"
  ANCHOR="$anchor" awk '
    !done && index($0, ENVIRON["ANCHOR"]) == 1 { print; done=1 }
  ' "$file"
}

# Print the anchored line plus every line up to (excluding) the first
# terminator (section_kind "block"). All three terminators are live at once;
# on the same line the precedence is section_end > heading > thematic break.
extract_block() {            # anchor file [section_end]
  local anchor="$1" file="$2" endpat="${3:-}"
  ANCHOR="$anchor" ENDPAT="$endpat" awk '
    BEGIN { a=ENVIRON["ANCHOR"]; e=ENVIRON["ENDPAT"] }
    !seen && index($0, a) == 1 { seen=1; print; next }
    seen && !stop {
      if (e != "" && index($0, e) == 1) { stop=1; next }
      if ($0 ~ /^#{1,6} +/)            { stop=1; next }
      if ($0 ~ /^---[ \t]*$/)          { stop=1; next }
      print
    }
  ' "$file"
}

# Resolve an entry's anchor to a match count, dispatching on section_kind.
count_anchor() {             # anchor file kind
  case "$3" in
    line|block) count_line "$1" "$2" ;;
    *)          count_heading "$1" "$2" ;;
  esac
}

# Resolve an entry's body, dispatching on section_kind. An empty section means
# whole-file scope for every kind.
resolve_body() {             # section file kind [section_end]
  local section="$1" file="$2" kind="$3" endpat="${4:-}"
  if [ -z "$section" ]; then
    cat "$file"
    return
  fi
  case "$kind" in
    line)  extract_line "$section" "$file" ;;
    block) extract_block "$section" "$file" "$endpat" ;;
    *)     extract_section "$section" "$file" "$endpat" ;;
  esac
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
jq -e -n 'input | all(.invariants[];
  ((.literal // "") + (.before // "") + (.after // "")) | contains("\n") | not)' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: literal/before/after must not contain an embedded newline (grep -F degrades to an OR of patterns and matches vacuously)"
jq -e -n 'input | all(.invariants[];
  (.section_kind // "heading") | . == "heading" or . == "line" or . == "block")' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: section_kind must be one of heading|line|block (default heading)"
jq -e -n 'input | all(.invariants[];
  ((.section_kind // "heading") == "line" and (.section_end // "") != "") | not)' "$REGISTRY" >/dev/null 2>&1 \
  || block "invalid registry: section_end is rejected for section_kind \"line\" (a line body is the anchored line alone)"

# Read all entries in ONE jq pass: base64-encoded columns, colon-separated.
# Colon is outside the base64 alphabet (A-Za-z0-9+/=), and unlike a tab it is
# not IFS-whitespace, so empty columns (e.g. section:null) survive `read`.
ROWS="$(jq -rn 'input | .invariants[] | [
  (.id|@base64), (.file|@base64), ((.section//"")|@base64), ((.section_end//"")|@base64),
  (.predicate|@base64), ((.match//"fixed")|@base64), ((.literal//"")|@base64),
  ((.before//"")|@base64), ((.after//"")|@base64), ((.section_kind//"heading")|@base64)
] | join(":")' "$REGISTRY")"

# ---------------------------------------------------------------------------
# Step 0b — anchor well-formedness: each section (and section_end) resolves to
# exactly one heading in its file. section:null => whole-file scope, skipped.
# ---------------------------------------------------------------------------
while IFS=: read -r id_b file_b sec_b end_b pred_b match_b lit_b before_b after_b kind_b; do
  [ -n "$id_b" ] || continue
  id="$(d64 "$id_b")"; file="$(d64 "$file_b")"
  section="$(d64 "$sec_b")"; section_end="$(d64 "$end_b")"
  kind="$(d64 "$kind_b")"; kind="${kind:-heading}"
  [ "$kind" = "heading" ] && unit="heading" || unit="line"
  srcfile="$PROJECT_ROOT/$file"
  [ -f "$srcfile" ] || continue
  if [ -n "$section" ]; then
    n="$(count_anchor "$section" "$srcfile" "$kind")"
    [ "$n" -eq 0 ] && block "dangling anchor: entry $id section '$section' resolves to no $unit (0 matches) in $file"
    [ "$n" -gt 1 ] && block "ambiguous anchor: entry $id section '$section' resolves to multiple ${unit}s ($n matches) in $file"
  fi
  if [ -n "$section_end" ]; then
    n="$(count_anchor "$section_end" "$srcfile" "$kind")"
    [ "$n" -eq 0 ] && block "dangling anchor: entry $id section_end '$section_end' resolves to no $unit (0 matches) in $file"
    [ "$n" -gt 1 ] && block "ambiguous anchor: entry $id section_end '$section_end' resolves to multiple ${unit}s ($n matches) in $file"
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

# eval_entry <srcfile> <section> <kind> <section_end> <predicate> <match>
#            <literal> <before> <after>
# Echoes PASS or FAIL. The single evaluator both the default pass and the
# self-test mode use, so a mutated copy is judged by exactly the predicate the
# real run applies.
eval_entry() {
  local srcfile="$1" section="$2" kind="$3" section_end="$4" predicate="$5"
  local match="$6" literal="$7" before="$8" after="$9"
  local body bln aln
  body="$(resolve_body "$section" "$srcfile" "$kind" "$section_end")"
  case "$predicate" in
    present)
      body_has "$body" "$literal" "$match" && echo PASS || echo FAIL ;;
    absent)
      body_has "$body" "$literal" "$match" && echo FAIL || echo PASS ;;
    ordered)
      bln="$(first_line_of "$body" "$before" "$match")"
      aln="$(first_line_of "$body" "$after" "$match")"
      if [ -n "$bln" ] && [ -n "$aln" ] && [ "$bln" -lt "$aln" ]; then
        echo PASS
      else
        echo FAIL
      fi
      ;;
    *) echo FAIL ;;
  esac
}

# ---------------------------------------------------------------------------
# Step 1 — evaluate each entry against current file state
# ---------------------------------------------------------------------------
run_default_mode() {
echo "=== doc-invariant registry: $(basename "$REGISTRY") ==="
while IFS=: read -r id_b file_b sec_b end_b pred_b match_b lit_b before_b after_b kind_b; do
  [ -n "$id_b" ] || continue
  id="$(d64 "$id_b")"; file="$(d64 "$file_b")"
  section="$(d64 "$sec_b")"; section_end="$(d64 "$end_b")"
  predicate="$(d64 "$pred_b")"; match="$(d64 "$match_b")"
  kind="$(d64 "$kind_b")"; kind="${kind:-heading}"
  srcfile="$PROJECT_ROOT/$file"
  loc="[$file${section:+§$section}] $predicate"

  if [ ! -f "$srcfile" ]; then
    record FAIL "$id" "$loc — missing target file"
    continue
  fi

  literal="$(d64 "$lit_b")"; before="$(d64 "$before_b")"; after="$(d64 "$after_b")"
  verdict="$(eval_entry "$srcfile" "$section" "$kind" "$section_end" \
    "$predicate" "$match" "$literal" "$before" "$after")"

  case "$predicate" in
    present|absent) record "$verdict" "$id" "$loc '$literal'" ;;
    ordered)        record "$verdict" "$id" "$loc '$before' < '$after'" ;;
  esac
done <<< "$ROWS"

# ---------------------------------------------------------------------------
# Step 2 — results
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"

[[ $FAIL -gt 0 ]] && return 1
return 0
}

if [ "$SELF_TEST" -eq 0 ]; then
  run_default_mode
  exit $?
fi

# ---------------------------------------------------------------------------
# Self-test mode — mutation teeth (issue #76 `teeth-in-runner`)
# ---------------------------------------------------------------------------
# Promoted from the negative-teeth leg of the retired per-cycle registry suite.
# Two properties change in the move, both deliberate: the mutation is evaluated
# against the already parsed row set in ONE pass per entry (the retired leg
# re-invoked the whole runner per entry, quadratic in registry size), and the
# mutators generalise to the new anchor kinds.
#
# Anchor preservation. For "line"/"block" an entry's body IS (or starts at) its
# anchored line, so the whole-line mutators would delete the anchor itself. The
# mutation is therefore BODY-SCOPED for those kinds — a `present` literal is
# removed as a substring occurrence inside the body, an `absent` witness is
# appended to the anchored line ("line") or inserted as a new line inside the
# body ("block"). "heading" and whole-file entries keep the whole-line mutators
# unchanged. Residual anchor destruction — the anchor no longer resolving to
# exactly one line after mutation — is a NON-CREDIT with a diagnostic, never an
# abort and never a credit: crediting it would credit an entry that showed only
# that it destroyed its own anchor.
SELF_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/doc-invariants-selftest.XXXXXX")"
cleanup_self_test() { rm -rf "$SELF_TEST_DIR" 2>/dev/null || true; }
trap cleanup_self_test EXIT

# mutate_remove_lines <src> <pattern> <match> <dest>
# Whole-line removal (heading-kind and whole-file entries). Returns non-zero
# only on a real grep error (exit >= 2, e.g. an invalid ERE); "every line
# removed" (exit 1) is a valid maximal mutation.
mutate_remove_lines() {
  local src="$1" pat="$2" match="$3" dest="$4" rc
  if [ "$match" = "regex" ]; then
    grep -vE -- "$pat" "$src" > "$dest" 2>/dev/null; rc=$?
  else
    grep -vF -- "$pat" "$src" > "$dest" 2>/dev/null; rc=$?
  fi
  [ "$rc" -le 1 ]
}

# mutate_body_remove <src> <anchor> <kind> <section_end> <pattern> <match> <dest>
# Substring removal restricted to the entry's body lines, leaving the column-1
# anchor prefix intact.
mutate_body_remove() {
  local src="$1" anchor="$2" kind="$3" endpat="$4" pat="$5" match="$6" dest="$7"
  MUT_ANCHOR="$anchor" MUT_END="$endpat" MUT_PAT="$pat" MUT_KIND="$kind" MUT_MATCH="$match" \
  awk '
    function strip_fixed(s, p,   out, i) {
      out = ""
      while ((i = index(s, p)) > 0) { out = out substr(s, 1, i - 1); s = substr(s, i + length(p)) }
      return out s
    }
    BEGIN { a=ENVIRON["MUT_ANCHOR"]; e=ENVIRON["MUT_END"]; p=ENVIRON["MUT_PAT"]
            k=ENVIRON["MUT_KIND"]; m=ENVIRON["MUT_MATCH"] }
    {
      inbody = 0
      if (!seen && index($0, a) == 1) { seen = 1; inbody = 1 }
      else if (seen && !stop && k == "block") {
        if (e != "" && index($0, e) == 1)      stop = 1
        else if ($0 ~ /^#{1,6} +/)             stop = 1
        else if ($0 ~ /^---[ \t]*$/)           stop = 1
        else                                   inbody = 1
      }
      if (inbody) {
        if (m == "regex") gsub(p, "")
        else              $0 = strip_fixed($0, p)
      }
      print
    }
  ' "$src" > "$dest" 2>/dev/null
}

# mutate_body_inject <src> <anchor> <kind> <literal> <dest>
# "line": append the witness to the anchored line. "block": insert it as a new
# line immediately after the anchored line (inside the body under every
# terminator shape).
mutate_body_inject() {
  local src="$1" anchor="$2" kind="$3" literal="$4" dest="$5"
  MUT_ANCHOR="$anchor" MUT_LIT="$literal" MUT_KIND="$kind" awk '
    BEGIN { a=ENVIRON["MUT_ANCHOR"]; l=ENVIRON["MUT_LIT"]; k=ENVIRON["MUT_KIND"] }
    !done && index($0, a) == 1 {
      done = 1
      if (k == "line") { print $0 " " l } else { print; print l }
      next
    }
    { print }
  ' "$src" > "$dest" 2>/dev/null
}

# mutate_heading_inject <src> <heading> <literal> <dest>
# An EOF append lands outside a non-last heading section, so the witness is
# injected immediately after the section heading line — the earliest line of
# the extracted body, in scope for every terminator shape.
mutate_heading_inject() {
  local src="$1" heading="$2" literal="$3" dest="$4"
  MUT_LIT="$literal" awk -v h="$heading" '
    { print }
    !done && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { print ENVIRON["MUT_LIT"]; done=1 }
    }
  ' "$src" > "$dest" 2>/dev/null
}

echo "=== doc-invariant registry self-test (mutation teeth): $(basename "$REGISTRY") ==="

ST_TOTAL=0; ST_OK=0
while IFS=: read -r id_b file_b sec_b end_b pred_b match_b lit_b before_b after_b kind_b; do
  [ -n "$id_b" ] || continue
  id="$(d64 "$id_b")"; file="$(d64 "$file_b")"
  section="$(d64 "$sec_b")"; section_end="$(d64 "$end_b")"
  predicate="$(d64 "$pred_b")"; match="$(d64 "$match_b")"
  literal="$(d64 "$lit_b")"; before="$(d64 "$before_b")"; after="$(d64 "$after_b")"
  kind="$(d64 "$kind_b")"; kind="${kind:-heading}"
  srcfile="$PROJECT_ROOT/$file"
  [ -f "$srcfile" ] || continue

  mutated="$SELF_TEST_DIR/$(printf '%s' "$id" | tr -c 'A-Za-z0-9._-' '_').mut"
  rm -f "$mutated"
  why=""
  body_scoped=0
  [ -n "$section" ] && { [ "$kind" = "line" ] || [ "$kind" = "block" ]; } && body_scoped=1

  case "$predicate" in
    present|ordered)
      pat="$literal"; [ "$predicate" = "ordered" ] && pat="$before"
      if [ "$body_scoped" -eq 1 ]; then
        if printf '%s' "$section" | grep -qF -- "$pat" 2>/dev/null; then
          why="unmigratable shape: literal '$pat' overlaps its own column-1 anchor prefix — no mutation can demonstrate teeth without destroying the anchor"
          cp "$srcfile" "$mutated"
        else
          mutate_body_remove "$srcfile" "$section" "$kind" "$section_end" "$pat" "$match" "$mutated" \
            || why="mutator error (match=$match): pattern is not a usable ${match} pattern"
        fi
      else
        mutate_remove_lines "$srcfile" "$pat" "$match" "$mutated" \
          || why="mutator error (match=$match): pattern is not a usable ${match} pattern"
      fi
      ;;
    absent)
      if [ "$match" = "regex" ]; then
        # Injection cannot synthesise a witness string in an arbitrary ERE's
        # language. Produce an unmutated copy so the byte-identity gate below
        # reports this loudly instead of skipping it.
        cp "$srcfile" "$mutated"
        why="unsupported shape: absent + match:\"regex\" has no injectable witness"
      elif [ "$body_scoped" -eq 1 ]; then
        mutate_body_inject "$srcfile" "$section" "$kind" "$literal" "$mutated"
      elif [ -n "$section" ]; then
        mutate_heading_inject "$srcfile" "$section" "$literal" "$mutated"
      else
        cp "$srcfile" "$mutated"
        printf '\n%s\n' "$literal" >> "$mutated"
      fi
      ;;
    *) continue ;;
  esac
  ST_TOTAL=$((ST_TOTAL + 1))

  # Effectiveness gate. `why` is consulted first and unconditionally: a mutator
  # error leaves an EMPTY destination, which is NOT byte-identical to the
  # source, so a byte-identity-only gate would credit an entry with teeth it
  # never demonstrated.
  if [ -n "$why" ] || [ ! -f "$mutated" ] || cmp -s "$srcfile" "$mutated"; then
    echo "  NO-TEETH: $id [$predicate/$match/$kind] — ${why:-ineffective mutation — mutated fixture is byte-identical to $file}"
    continue
  fi

  # Residual anchor destruction — non-credit with a diagnostic, never an abort.
  if [ -n "$section" ]; then
    n_after="$(count_anchor "$section" "$mutated" "$kind")"
    if [ "$n_after" -ne 1 ]; then
      if [ "$n_after" -eq 0 ]; then unresolvable="zero matches"; else unresolvable="multiple matches ($n_after)"; fi
      echo "  NO-TEETH: $id [$predicate/$match/$kind] — mutation left the anchor '$section' unresolvable in $file ($unresolvable); not credited"
      continue
    fi
  fi

  verdict="$(eval_entry "$mutated" "$section" "$kind" "$section_end" \
    "$predicate" "$match" "$literal" "$before" "$after")"
  if [ "$verdict" = "FAIL" ]; then
    ST_OK=$((ST_OK + 1))
    echo "  TEETH: $id [$predicate/$match/$kind] — mutated copy reports FAIL"
  else
    echo "  NO-TEETH: $id [$predicate/$match/$kind] — mutated copy still reports $verdict (expected FAIL); entry has no teeth"
  fi
done <<< "$ROWS"

echo ""
echo "Self-test results: $ST_OK/$ST_TOTAL entries demonstrated mutation teeth"

# Denominator coverage gate (issue #119). ST_OK == ST_TOTAL is credit over the
# population the loop actually REACHED, not over the registry. Three paths
# `continue` before ST_TOTAL is incremented — an empty resolved id, a `file`
# that is not in the tree, and an unrecognised predicate — so an entry whose
# file was renamed or deleted moves neither counter and this mode would report
# full credit over a shrunken population. The registry's own entry count is the
# denominator the credit must be over, and a shortfall fails loud with both
# numbers named. The length is read without a readability guard: the load-time
# gate above already `jq -e`-validated, on this same $REGISTRY, that
# `.invariants` is an array of length > 0, and it runs at top level before the
# mode dispatch — so this read cannot yield an empty or non-numeric value.
ST_REGISTRY_LEN="$(jq -r '.invariants | length' "$REGISTRY")"
if [ "$ST_TOTAL" -ne "$ST_REGISTRY_LEN" ]; then
  echo "DENOMINATOR-SHORT: the self-test evaluated $ST_TOTAL of the registry's $ST_REGISTRY_LEN entries — $((ST_REGISTRY_LEN - ST_TOTAL)) entry/entries were skipped before the counter (missing file, empty id, or unrecognised predicate), so full credit here would be credit over a shrunken population"
  exit 1
fi

[ "$ST_TOTAL" -gt 0 ] && [ "$ST_OK" -eq "$ST_TOTAL" ] || exit 1
exit 0
