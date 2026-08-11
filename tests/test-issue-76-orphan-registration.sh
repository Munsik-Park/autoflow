#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-ci-coverage.sh .github/workflows/e2e-dummy-target.yml .github/workflows/contract-suites.yml
# =============================================================================
# Test: orphan-suite registration effectiveness — Issue #76 AC-b-2/AC-b-3,
#       trigger-window preservation (AC-c-2), dangling-reference sweep,
#       CYCLE 2 (PR #83 Finding 1): Actions-glob dialect matcher
#       (AC-glob-conformance), hosting-workflow-scoped coverage (AC-b-2
#       rewrite), paths: entry-shape lint (AC-entry-shape), ci-subject
#       grammar (AC-subject-grammar).
# =============================================================================
# .autoflow/issue-76-verification-design.md (cycle 2 sections):
#   AC-b-2 — each named orphan suite executes on an edit to its OWN subject:
#     registration-effectiveness oracle, restated so the verdict is about the
#     composition it claims — resolve each suite's HOSTING workflows (the
#     workflows that reach it, transitively, over `bash <path>` invocations —
#     the same relation scripts/test/check-suite-ci-coverage.sh computes) and
#     require every declared subject, plus the suite file itself, to be
#     covered by an entry in THOSE workflows' own paths: blocks — never the
#     tree-wide pool. Coverage is decided by the documented Actions-glob
#     dialect (AC-glob-conformance), not by exact-string-or-prefix. A
#     directory subject `D/` is covered only when some pattern is `X/**` (or
#     bare `**`) with `X/` a prefix of `D/` (`subject-grammar`).
#   AC-glob-conformance — the coverage matcher answers as GitHub's path
#     filter does, for the forms the tree uses: table-driven conformance rows
#     over the matcher alone, both directions, with required negative rows
#     pinning the reviewed defect (a bare trailing-slash entry matches no
#     file under it) as a permanent negative.
#   AC-subject-grammar — every `# ci-subject:` token is a file path or a
#     trailing-slash directory, never a glob.
#   AC-entry-shape — every `paths:` entry in every workflow is a documented
#     form (arm 1: entry form — no bare trailing-slash); no workflow uses a
#     filter form the matcher does not implement (arm 2: model coverage —
#     no `paths-ignore:`, no `!` negation, no bracket/`?` form), scanned
#     tree-wide, not only over this cycle's file.
#   `paths:` block-parse fixture (verification design depth table, bound
#     here per GATE:PLAN carried finding 1 / ledger E37): the single block-
#     delimitation parse (§ 3 Interfaces) both AC-b-2's oracle and
#     AC-entry-shape's arms share — a hermetic fixture proves the parse reads
#     the right entry set (comments inside a list, an unfiltered event with
#     no paths: key, a block spanning to its next sibling key), because an
#     under- or over-collecting parse is invisible to every other leg here.
#   AC-b-3 — no valid suite is left with zero execution paths:
#     `scripts/test/check-suite-ci-coverage.sh` over the real tree, exit 0,
#     plus two named --self-test legs (closure, exclusion) over a hermetic
#     fixture tree so the live-tree exit 0 is never read as vacuous.
#   AC-c-2 — the scenario-document retirement move evicts no existing
#     `paths:` entry from the fixed-window `e2e-dummy-target.yml` reads
#     (`window-safety`, `yml-window-eviction`).
#   `deleted-suite-still-read` (verification design depth table) — no
#     retained suite reads a deletion target's file TEXT (content grep, not a
#     comment mention).
#   AC-runtime-witness is HANDOFF-deferred (hook gates push/pr-create on
#     AUDIT+GATE:QUALITY) and is NOT implemented here — see
#     tests/manual/issue-76-manual-scenarios.md > M5.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
COVERAGE_LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"

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

echo "=== Issue #76 — orphan registration, glob dialect, entry-shape, subject-grammar (AC-b-2/AC-b-3/AC-c-2/AC-glob-conformance/AC-entry-shape/AC-subject-grammar) ==="

# =============================================================================
# Shared mechanism — Actions path-filter dialect matcher (oracle-models-actions-glob)
# =============================================================================
# pattern_to_regex <pattern> — translate an Actions path-filter pattern to an
# anchored POSIX ERE body: `**` -> any characters (incl. `/`); `*` -> any
# characters except `/`; everything else literal (regex-escaped). Longest
# token first, so `**` is consumed before a lone `*`.
pattern_to_regex() {
  local pat="$1"
  local i=0 len=${#pat} c out=""
  while [ "$i" -lt "$len" ]; do
    c="${pat:$i:1}"
    if [ "$c" = "*" ] && [ "${pat:$((i + 1)):1}" = "*" ]; then
      out+='.*'
      i=$((i + 2))
    elif [ "$c" = "*" ]; then
      out+='[^/]*'
      i=$((i + 1))
    else
      case "$c" in
        '.' | '^' | '$' | '(' | ')' | '{' | '}' | '|' | '\' | '+') out+="\\$c" ;;
        *) out+="$c" ;;
      esac
      i=$((i + 1))
    fi
  done
  printf '%s' "$out"
}

# matcher_check <pattern> <path> — echoes "match" | "nomatch" | "unsupported".
# A pattern carrying any Actions metacharacter outside this dialect subset
# (`?`, `+`, `[`, `]`, a leading `!` negation) is reported unsupported rather
# than matched literally — the same defect class this cycle fixes: a pattern
# form the oracle does not model, silently evaluated under the wrong rule.
matcher_check() {
  local pattern="$1" path="$2" regex
  case "$pattern" in
    '!'*) echo unsupported; return ;;
  esac
  case "$pattern" in
    *'?'* | *'+'* | *'['* | *']'*) echo unsupported; return ;;
  esac
  regex="$(pattern_to_regex "$pattern")"
  if [[ "$path" =~ ^${regex}$ ]]; then
    echo match
  else
    echo nomatch
  fi
}

# subject_covered <subject> <pattern...> — Cover(): a file subject is covered
# when some pattern matches it; a directory subject `D/` is covered only when
# some pattern is `X/**` (or bare `**`) with `X/` a prefix of `D/`
# (subject-grammar's directory-cover rule — sufficient, not complete: a
# directory covered only by an exotic pattern reds, which is the wanted
# false-red direction).
subject_covered() {
  local subject="$1"; shift
  local p px
  if [[ "$subject" == */ ]]; then
    for p in "$@"; do
      if [ "$p" = "**" ]; then
        return 0
      fi
      case "$p" in
        */'**')
          px="${p%'**'}"
          [[ "$subject" == "$px"* ]] && return 0
          ;;
      esac
    done
    return 1
  else
    for p in "$@"; do
      [ "$(matcher_check "$p" "$subject")" = "match" ] && return 0
    done
    return 1
  fi
}

# =============================================================================
# Shared mechanism — the single `paths:` block-delimitation parse
# (§ 3 Interfaces > `paths:` block delimitation). Both AC-b-2's pattern-set
# collection and AC-entry-shape's two arms read entries through this one
# function, so the two readers cannot drift into two different parses of the
# same blocks.
# =============================================================================
# extract_paths_entries <workflow-file> — every entry under every `paths:`
# key in the file (all events pooled per-file, matching § 3's "Pattern set"
# wording — "from each [reaching workflow], the entries under its
# on.<event>.paths keys"). Start: a line whose only non-whitespace content is
# `paths:`, indentation recorded. Body: a following `-`-led line at strictly
# greater indentation, quotes stripped. Ignored: blank lines and `#` comment
# lines — both occur inside a live block in this tree, so they do not
# terminate. Terminator: the first line that is neither; excluded. An event
# declaring no `paths:` key contributes zero entries — not an error, and not
# read as a false "nothing covers this" the way an empty-but-required set
# would be, since coverage is decided over the union across all this
# workflow's `paths:` blocks, not per-event.
extract_paths_entries() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    {
      line = $0
      n = length(line)
      i = 1
      while (i <= n) {
        ch = substr(line, i, 1)
        if (ch != " " && ch != "\t") break
        i++
      }
      indent = i - 1
      trimmed = substr(line, i)
      if (in_block) {
        if (trimmed == "") next
        if (substr(trimmed, 1, 1) == "#") next
        if (substr(trimmed, 1, 1) == "-" && indent > key_indent) { print line; next }
        in_block = 0
      }
      if (trimmed == "paths:") { in_block = 1; key_indent = indent }
    }
  ' "$file" | sed -E "s/^[[:space:]]*-[[:space:]]*//; s/^['\"]//; s/['\"]\$//"
}

# workflow_has_paths_ignore_key <workflow-file> — a `paths-ignore:` key
# anywhere in the file (any event). AC-entry-shape arm 2.
workflow_has_paths_ignore_key() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    {
      line = $0
      n = length(line)
      i = 1
      while (i <= n) {
        ch = substr(line, i, 1)
        if (ch != " " && ch != "\t") break
        i++
      }
      trimmed = substr(line, i)
      if (trimmed == "paths-ignore:") { found = 1 }
    }
    END { exit !found }
  ' "$file"
}

# entry_is_bare_trailing_slash <entry> — the reviewed defect's exact shape:
# ends in `/`, carries no wildcard at all.
entry_is_bare_trailing_slash() {
  local e="$1"
  case "$e" in
    */)
      case "$e" in
        *'*'*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# entry_is_unsupported_shape <entry> — a filter shape oracle-models-actions-glob
# does not implement: `!` negation, `?`, or a bracket class.
entry_is_unsupported_shape() {
  case "$1" in
    '!'* | *'?'* | *'['* | *']'*) return 0 ;;
    *) return 1 ;;
  esac
}

# =============================================================================
# Shared mechanism — hosting-workflow-scoping (transitive reach). Inherits
# the coverage lint's own `bash <path>` invocation rule verbatim so the two
# reachability notions cannot drift (scripts/test/check-suite-ci-coverage.sh
# invoked_paths / reachable_set).
# =============================================================================
invoked_paths() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -h 'bash' "$file" 2>/dev/null \
    | grep -ohE '(tests|scripts)/[A-Za-z0-9_./-]+\.(sh|bats)' \
    | sort -u
}

# workflow_reaches <workflow-file> <target-rel-path> — transitive closure
# over `bash <path>` invocations starting from the workflow's own run: steps.
workflow_reaches() {
  local wf="$1" target="$2" seen frontier next f
  seen="$(mktemp)"; frontier="$(mktemp)"; next="$(mktemp)"
  invoked_paths "$wf" > "$frontier"
  sort -u "$frontier" -o "$frontier"
  cat "$frontier" > "$seen"
  while [ -s "$frontier" ]; do
    : > "$next"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      invoked_paths "$PROJECT_ROOT/$f" >> "$next"
    done < "$frontier"
    sort -u "$next" -o "$next"
    comm -23 "$next" <(sort -u "$seen") > "$frontier"
    cat "$frontier" >> "$seen"
    sort -u "$seen" -o "$seen"
  done
  local rc=1
  grep -qxF "$target" "$seen" && rc=0
  rm -f "$seen" "$frontier" "$next"
  return $rc
}

# reaching_workflows <target-rel-path> — every real workflow file that
# reaches the target, directly or transitively.
reaching_workflows() {
  local target="$1" wf
  for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    workflow_reaches "$wf" "$target" && echo "$wf"
  done
}

# =============================================================================
# AC-b-2 — registration-effectiveness oracle, hosting-workflow-scoped,
# dialect-correct matcher. This runs against WHATEVER suites carry the
# `# ci-subject:` header in the tree at test time — the oracle logic, not a
# hardcoded name list.
# =============================================================================
mapfile -t CI_SUBJECT_SUITES < <(grep -rl '^# ci-subject:' "$PROJECT_ROOT/tests" 2>/dev/null | sort)

assert_true "AC-b-2 pre: at least one suite declares a # ci-subject: header" \
  "[ \${#CI_SUBJECT_SUITES[@]} -gt 0 ]"

for suite in "${CI_SUBJECT_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  subjects_line="$(grep -m1 '^# ci-subject:' "$suite")"
  subjects="${subjects_line#\# ci-subject:}"

  mapfile -t hosts < <(reaching_workflows "$rel")
  if [ ${#hosts[@]} -eq 0 ]; then
    assert_true "AC-b-2: $rel — has at least one reaching (hosting) workflow" "false"
    continue
  fi
  mapfile -t patterns < <(
    for h in "${hosts[@]}"; do extract_paths_entries "$h"; done | sort -u
  )

  all_covered=true
  for path in $subjects "$rel"; do
    if subject_covered "$path" "${patterns[@]}"; then
      :
    else
      all_covered=false
      echo "  INFO: $rel — subject '$path' NOT covered by hosting workflow(s): ${hosts[*]#"$PROJECT_ROOT"/}"
    fi
  done
  assert_true "AC-b-2: $rel — every declared ci-subject path (and the suite itself) is covered by its HOSTING workflow's paths: block, under the Actions-glob dialect matcher" "$all_covered"
done

# entry-shape-leg > Subject wiring: this suite's own subject grows to include
# the whole workflow directory (`.github/workflows/`), and the covering entry
# that makes it honest (`orphan-registration-self-entry`) is a workflow-side
# fix, not a test-side one. Both land in the same GREEN commit per §4/§5 of
# the feature design; this assertion is the left-hand side that makes the
# omission visible until they do.
assert_true "AC-entry-shape subject-wiring: this suite's own # ci-subject: header declares the directory '.github/workflows/' as its OWN token (entry-shape-leg's tree-wide arm needs its own subject — a substring hit inside another token, e.g. '.github/workflows/e2e-dummy-target.yml', does not count)" \
  "grep -m1 '^# ci-subject:' '$PROJECT_ROOT/tests/test-issue-76-orphan-registration.sh' | grep -qE '(^|[[:space:]])\\.github/workflows/([[:space:]]|\$)'"

# =============================================================================
# AC-glob-conformance — table-driven conformance rows over the matcher alone,
# both directions. Required negative rows pin the reviewed defect and its
# siblings as permanent negatives; required positive rows prove the matcher
# is not simply permissive. Hermetic — fixed inputs, not the live tree, so
# these are green-by-construction against `matcher_check` and independent of
# workflow-file state.
# =============================================================================
# rows: "pattern|||path|||expected"
GLOB_CONFORMANCE_ROWS=(
  # --- required negative rows -------------------------------------------
  "docs/adr/|||docs/adr/0016.md|||nomatch"                       # reviewed defect, permanent negative
  "docs/adr/*|||docs/adr/sub/x.md|||nomatch"                      # single-star does not cross /
  "setup/manifest.json|||setup/manifest.json.bak|||nomatch"       # exact entry is not an implicit prefix
  "docs/adr|||docs/adr/0016.md|||nomatch"                         # bare dir name, no wildcard, matches nothing under it
  # --- required positive rows --------------------------------------------
  "docs/adr/**|||docs/adr/0016.md|||match"
  "docs/adr/**|||docs/adr/sub/x.md|||match"
  "docs/adr/*|||docs/adr/0016.md|||match"
  "**.md|||docs/adr/0016.md|||match"
  "setup/manifest.json|||setup/manifest.json|||match"             # exact entry matches its own path
)
for row in "${GLOB_CONFORMANCE_ROWS[@]}"; do
  pattern="${row%%'|||'*}"
  rest="${row#*'|||'}"
  path="${rest%%'|||'*}"
  expected="${rest#*'|||'}"
  actual="$(matcher_check "$pattern" "$path")"
  result=true
  [ "$actual" = "$expected" ] || result=false
  assert_true "AC-glob-conformance: pattern '$pattern' vs path '$path' -> expected $expected, got $actual" "$result"
done

# --- three legs outside the table (matcher-self-test) -----------------------
# (i) directory-cover rule: dir/** covers dir/, dir/ alone does not.
DC1=true; subject_covered "docs/adr/" "docs/adr/**" || DC1=false
assert_true "matcher-self-test: subject_covered — pattern 'docs/adr/**' covers directory subject 'docs/adr/'" "$DC1"
DC2=true; subject_covered "docs/adr/" "docs/adr/" && DC2=false
assert_true "matcher-self-test: subject_covered — pattern 'docs/adr/' (bare trailing slash) does NOT cover directory subject 'docs/adr/'" "$DC2"

# (ii) hosting-workflow-scoping: a pattern belonging to a non-reaching
# workflow does not credit coverage — hermetic two-workflow fixture.
HWS_DIR="$(mktemp -d)"
mkdir -p "$HWS_DIR/reaching" "$HWS_DIR/non_reaching"
cat > "$HWS_DIR/reaching.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-hws-unrelated.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-hws-suite.sh
YML
cat > "$HWS_DIR/non_reaching.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-hws-suite.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-hws-other.sh
YML
mapfile -t HWS_REACHING_PATTERNS < <(extract_paths_entries "$HWS_DIR/reaching.yml")
HWS_RESULT=true
subject_covered "tests/fixture-hws-suite.sh" "${HWS_REACHING_PATTERNS[@]}" && HWS_RESULT=false
assert_true "matcher-self-test: hosting-workflow-scoping — a pattern in a workflow that does NOT reach the suite (non_reaching.yml covers the subject but has no run: step for it) does not credit coverage when only the REACHING workflow's (reaching.yml) patterns are pooled" "$HWS_RESULT"
rm -rf "$HWS_DIR"

# (iii) unsupported-shape boundary arm: an unmodelled metacharacter is
# reported, never matched literally.
US1=true; [ "$(matcher_check 'tests/fixture-a?.sh' 'tests/fixture-ax.sh')" = "unsupported" ] || US1=false
assert_true "matcher-self-test: oracle-models-actions-glob boundary — pattern with '?' is reported unsupported, not matched" "$US1"
US2=true; [ "$(matcher_check '!excluded/**' 'excluded/x')" = "unsupported" ] || US2=false
assert_true "matcher-self-test: oracle-models-actions-glob boundary — leading '!' negation is reported unsupported, not matched" "$US2"
US3=true; [ "$(matcher_check 'tests/fixture[ab].sh' 'tests/fixturea.sh')" = "unsupported" ] || US3=false
assert_true "matcher-self-test: oracle-models-actions-glob boundary — bracket-class pattern is reported unsupported, not matched" "$US3"

# =============================================================================
# AC-entry-shape — every `paths:` entry in every workflow, tree-wide (not
# only this cycle's file). Arm 1: entry form. Arm 2: model coverage.
# =============================================================================
for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
  [ -f "$wf" ] || continue
  wrel="${wf#"$PROJECT_ROOT"/}"

  # Arm 2a: no `paths-ignore:` key anywhere in this workflow.
  arm2a=true
  workflow_has_paths_ignore_key "$wf" && arm2a=false
  assert_true "AC-entry-shape arm2: $wrel — carries no paths-ignore: key (unmodelled filter form)" "$arm2a"

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    arm1=true
    entry_is_bare_trailing_slash "$entry" && arm1=false
    assert_true "AC-entry-shape arm1: $wrel — entry '$entry' is a documented path/glob form (exact path, or built from * / **), not a bare trailing-slash entry" "$arm1"

    arm2b=true
    entry_is_unsupported_shape "$entry" && arm2b=false
    assert_true "AC-entry-shape arm2: $wrel — entry '$entry' carries no unmodelled metacharacter (leading !, ?, [, ])" "$arm2b"
  done < <(extract_paths_entries "$wf")
done

# --- hermetic legs for arm 2 (no workflow in the tree carries any of these
# forms today, so the live-tree loop above passes vacuously on arm 2 — only
# fixture text discriminates a correct check from a permissive one).
ENTRY_SHAPE_FIXTURE="$(mktemp)"
cat > "$ENTRY_SHAPE_FIXTURE" <<'YML'
on:
  pull_request:
    paths-ignore:
      - 'docs/**'
    paths:
      - '!excluded/**'
      - 'tests/fixture-a?.sh'
      - 'tests/fixture[ab].sh'
YML
assert_true "AC-entry-shape arm2 hermetic: paths-ignore: key is detected" \
  "workflow_has_paths_ignore_key '$ENTRY_SHAPE_FIXTURE'"
mapfile -t ENTRY_SHAPE_FIXTURE_ENTRIES < <(extract_paths_entries "$ENTRY_SHAPE_FIXTURE")
ES_EXPECTED=$'!excluded/**\ntests/fixture-a?.sh\ntests/fixture[ab].sh'
ES_ACTUAL="$(printf '%s\n' "${ENTRY_SHAPE_FIXTURE_ENTRIES[@]}")"
assert_true "AC-entry-shape arm2 hermetic: paths: block under paths-ignore: still parses the three unmodelled entries ('!'-negation, '?', bracket class)" \
  "[ \"\$(printf '%s' '$ES_ACTUAL' | sort)\" = \"\$(printf '%s' '$ES_EXPECTED' | sort)\" ]"
for entry in "${ENTRY_SHAPE_FIXTURE_ENTRIES[@]}"; do
  esr=true
  entry_is_unsupported_shape "$entry" || esr=false
  assert_true "AC-entry-shape arm2 hermetic: entry '$entry' is flagged as an unmodelled shape" "$esr"
done
rm -f "$ENTRY_SHAPE_FIXTURE"

# =============================================================================
# AC-subject-grammar — every `# ci-subject:` token is a file path or a
# trailing-slash directory, never a glob.
# =============================================================================
is_subject_grammar_valid() {
  local token="$1"
  case "$token" in
    *'*'* | *'?'* | *'['* | *']'* | '!'*) return 1 ;;
  esac
  if [[ "$token" == */ ]]; then
    [ -d "$PROJECT_ROOT/$token" ]
  else
    [ -f "$PROJECT_ROOT/$token" ]
  fi
}

for suite in "${CI_SUBJECT_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  subjects_line="$(grep -m1 '^# ci-subject:' "$suite")"
  subjects="${subjects_line#\# ci-subject:}"
  for token in $subjects; do
    sg=true
    is_subject_grammar_valid "$token" || sg=false
    assert_true "AC-subject-grammar: $rel — declared subject '$token' is a file path or a trailing-slash directory, never a glob" "$sg"
  done
done

# Hermetic leg: no header in the tree carries a glob token today, so the
# live-tree loop above passes vacuously — a fixture token is required.
SG1=true; is_subject_grammar_valid 'docs/*.md' && SG1=false
assert_true "AC-subject-grammar hermetic: a glob-bearing token ('docs/*.md') fails the grammar check" "$SG1"
SG2=true; is_subject_grammar_valid 'docs/adr/' || SG2=false
assert_true "AC-subject-grammar hermetic: a real trailing-slash directory token ('docs/adr/') passes" "$SG2"
SG3=true; is_subject_grammar_valid 'setup/manifest.json' || SG3=false
assert_true "AC-subject-grammar hermetic: a real file-path token ('setup/manifest.json') passes" "$SG3"

# =============================================================================
# `paths:` block-parse fixture — bound to AC-entry-shape / AC-b-2's shared
# parse (GATE:PLAN carried finding 1, ledger E37). Hermetic workflow text
# whose expected entry set is fixed independently of the parser: a comment
# line between the event key and its paths: key, a comment line INSIDE the
# entry list, an event (pull_request) declaring no paths: key at all (must
# contribute zero entries, not error), and a block that runs many lines to
# its next sibling key (no fixed-window assumption).
# =============================================================================
BLOCK_PARSE_FIXTURE="$(mktemp)"
{
  echo "on:"
  echo "  pull_request:"
  echo "  push:"
  echo "    branches: [main]"
  echo "    # a comment between the event key and its paths: key"
  echo "    paths:"
  echo "      - 'a/one.sh'"
  echo "      # a comment INSIDE the entry list — must not terminate the block"
  echo "      - 'a/two.sh'"
  echo ""
  echo "      - 'a/three.sh'"
  for n in $(seq 1 60); do
    echo "      - 'a/filler-$n.sh'"
  done
  echo "      - 'a/four.sh'"
  echo "jobs:"
  echo "  x:"
  echo "    steps:"
  echo "      - run: bash a/one.sh"
} > "$BLOCK_PARSE_FIXTURE"

mapfile -t BLOCK_PARSE_ENTRIES < <(extract_paths_entries "$BLOCK_PARSE_FIXTURE")
BP_EXPECTED_COUNT=64
assert_true "paths: block-parse fixture: extracted entry count matches the fixture's known entry set (comments skipped, blank line skipped, long block read to its true terminator)" \
  "[ \${#BLOCK_PARSE_ENTRIES[@]} -eq $BP_EXPECTED_COUNT ]"
BP1=false
for e in "${BLOCK_PARSE_ENTRIES[@]}"; do [ "$e" = "a/one.sh" ] && BP1=true; done
assert_true "paths: block-parse fixture: 'a/one.sh' (before the inline comment) is captured" "$BP1"
BP2=false
for e in "${BLOCK_PARSE_ENTRIES[@]}"; do [ "$e" = "a/two.sh" ] && BP2=true; done
assert_true "paths: block-parse fixture: 'a/two.sh' (immediately after the inline comment) is captured — the comment did not terminate the block" "$BP2"
BP3=false
for e in "${BLOCK_PARSE_ENTRIES[@]}"; do [ "$e" = "a/three.sh" ] && BP3=true; done
assert_true "paths: block-parse fixture: 'a/three.sh' (after a blank line) is captured — the blank line did not terminate the block" "$BP3"
BP4=false
for e in "${BLOCK_PARSE_ENTRIES[@]}"; do [ "$e" = "a/four.sh" ] && BP4=true; done
assert_true "paths: block-parse fixture: 'a/four.sh', 60 filler lines below the start, is captured — no fixed-window assumption in the parse" "$BP4"
assert_true "paths: block-parse fixture: the unfiltered pull_request: event (no paths: key at all) contributes zero entries, and is not an error — the fixture's own 'jobs:' key never appears as an entry" \
  "! printf '%s\n' \"\${BLOCK_PARSE_ENTRIES[*]}\" | grep -qF 'jobs:'"
rm -f "$BLOCK_PARSE_FIXTURE"

# ---------------------------------------------------------------------------
# AC-b-3 — standing coverage lint: existence, exit 0 over the real tree, and
# the two --self-test legs (closure over a hermetic unreachable-suite
# fixture; exclusion asserted positively for each of the three named paths).
# ---------------------------------------------------------------------------
assert_true "AC-b-3: scripts/test/check-suite-ci-coverage.sh exists" \
  "[ -x '$COVERAGE_LINT' ] || [ -f '$COVERAGE_LINT' ]"

assert_true "AC-b-3: check-suite-ci-coverage.sh exits 0 over the real tree" \
  "bash '$COVERAGE_LINT' >/tmp/issue76-coverage-lint.out 2>&1"

assert_true "AC-b-3: check-suite-ci-coverage.sh --self-test exits 0 (closure + exclusion legs both pass)" \
  "bash '$COVERAGE_LINT' --self-test >/tmp/issue76-coverage-lint-selftest.out 2>&1"

assert_true "AC-b-3: --self-test output names the closure leg (a known-unreachable fixture suite is caught)" \
  "grep -qi 'closure' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

assert_true "AC-b-3: --self-test output names the exclusion leg (tests/lib, run-doc-invariants.sh, issue-59 driver asserted excluded; an outside path asserted NOT excluded)" \
  "grep -qi 'exclusion' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

# ---------------------------------------------------------------------------
# AC-c-2 — trigger-window preservation over e2e-dummy-target.yml. Recomputes
# the fixed grep -A40 window below the FIRST paths: key and re-asserts every
# literal the three window-dependent live suites require, per
# `contract-suite-workflow`'s measured saturation
# (tests/test-issue-799-inert-cleanup.sh, tests/test-issue-55-*,
# tests/test-issue-52-*).
# ---------------------------------------------------------------------------
FIRST_PATHS_LINE="$(grep -n '^ *paths:' "$CI_WORKFLOW" | head -1 | cut -d: -f1)"
assert_true "AC-c-2 pre: e2e-dummy-target.yml has a paths: block to window against" "[ -n '$FIRST_PATHS_LINE' ]"

if [ -n "$FIRST_PATHS_LINE" ]; then
  WINDOW="$(sed -n "${FIRST_PATHS_LINE},$((FIRST_PATHS_LINE + 40))p" "$CI_WORKFLOW")"
  # Literals named by the three window-dependent live suites at HEAD.
  # GATE:QUALITY FAIL #6 (ledger E14): checked only 1 of the 6 literals
  # test-issue-799-inert-cleanup.sh:336-339 actually requires inside the
  # window — the other 5 could be silently evicted without this leg ever
  # noticing. All six now asserted.
  WINDOW_LITERALS=(
    "README.md"
    "docs/submodule-common-rules.md"
    "docs/external-review-sequencing.md"
    "docs/INDEX.md"
    "docs/maintained-docs.md"
    "docs/git-workflow.md"
  )
  for lit in "${WINDOW_LITERALS[@]}"; do
    assert_true "AC-c-2: window literal survives inside the first paths: block's 40-line window — '$lit'" \
      "printf '%s\n' \"\$WINDOW\" | grep -qF '$lit'"
  done
fi

# ---------------------------------------------------------------------------
# deleted-suite-still-read — dangling-reference sweep over the retirement
# set (GATE:QUALITY FAIL #2, ledger E14). Now that migration has landed,
# 843/844/the pre-split 951 suite, and the doc-invariants-baseline.txt
# fixture, are genuinely gone at HEAD; the sweep is a real assertion, not
# the `"true"` stub the prior round shipped (whose own justifying comment
# was already false at HEAD — the suites ARE deleted).
#
# Classification rule, stated because "comment-only mentions are harmless"
# (verification design, deleted-suite-still-read) needs a mechanical
# separation, not an eyeball one:
#   1. A hit on a line whose trimmed content starts with '#' is a
#      COMMENT — exempt. This is where a historical/provenance citation
#      lives (e.g. tests/test-issue-69-verification-depth.sh's "Moved here
#      from the permanent registry (GATE:QUALITY attempt-2 finding):
#      ... tests/test-issue-951-registry.sh, FINDING 3-E" — citing WHERE a
#      finding originated, not depending on that file existing).
#   2. A hit inside a file whose OWN declared purpose is a durable record
#      of what this cycle deleted and why — tests/fixtures/issue-76-
#      migration-map.md and docs/doc-invariant-registry.md — is exempt at
#      the FILE level: a "dangling reference" concern does not apply to a
#      document whose entire job is to name deleted things.
#   3. Everything else is a LIVE reference and fails the assertion — this
#      is what would previously have caught a suite's own SUITES[]/
#      DELETED_SUITES[] data array (a non-comment, non-provenance-file
#      line) content-referencing a target that no longer resolves.
DELETED_TARGETS=(
  "test-issue-843-doc-assertions.sh"
  "test-issue-844-doc-assertions.sh"
  "test-issue-951-registry.sh"
  "doc-invariants-baseline.txt"
)
EXEMPT_PROVENANCE_FILES=(
  "tests/fixtures/issue-76-migration-map.md"
  "docs/doc-invariant-registry.md"
  # tests/test-issue-76-migration-map-total.sh's SUITES[] array names
  # 843/844 as base-ref subjects it materialises via `git show
  # <base>:<path>` (see its own RED2 header note) — it never reads the
  # working-tree path, so a deletion cannot turn it red the way the
  # design's failure mode describes. Same exemption class as the map
  # document itself.
  "tests/test-issue-76-migration-map-total.sh"
  # tests/test-issue-76-runner-self-test-contract.sh's AC-f body-equality
  # leg materialises tests/test-issue-844-doc-assertions.sh via the same
  # `git show <base>:<path>` pattern (never the working-tree path) to
  # re-derive the deleted suite's own Resume-procedure extractor.
  "tests/test-issue-76-runner-self-test-contract.sh"
)
is_exempt_provenance_file() {
  local rel="$1" f
  for f in "${EXEMPT_PROVENANCE_FILES[@]}"; do
    [ "$rel" = "$f" ] && return 0
  done
  return 1
}
for name in "${DELETED_TARGETS[@]}"; do
  live_hits=()
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    hfile="${hit%%:*}"
    hrel="${hfile#"$PROJECT_ROOT"/}"
    [ "$hrel" = "tests/test-issue-76-orphan-registration.sh" ] && continue
    [ "$hrel" = "$name" ] && continue
    if is_exempt_provenance_file "$hrel"; then
      echo "  INFO: $name — exempt (provenance record): $hrel"
      continue
    fi
    hcontent="${hit#*:*:}"
    trimmed="$(printf '%s' "$hcontent" | sed -e 's/^[[:space:]]*//')"
    case "$trimmed" in
      \#*)
        echo "  INFO: $name — exempt (comment-only): $hit"
        ;;
      *)
        echo "  INFO: $name — LIVE reference: $hit"
        live_hits+=("$hit")
        ;;
    esac
  done < <(grep -rn -- "$name" "$PROJECT_ROOT/tests" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/docs" "$PROJECT_ROOT/.github" 2>/dev/null || true)
  assert_true "deleted-suite-still-read: no live (non-comment, non-provenance-file) reference to deleted target '$name' survives" \
    "[ ${#live_hits[@]} -eq 0 ]"
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
