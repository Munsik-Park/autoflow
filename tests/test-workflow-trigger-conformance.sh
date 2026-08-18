#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-ci-coverage.sh scripts/test/invocation-scan.sh .github/workflows/e2e-dummy-target.yml .github/workflows/contract-suites.yml .github/workflows/
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: workflow trigger/registration conformance — suite registration
#       effectiveness (AC-b-2/AC-b-3), Actions-glob dialect matcher
#       (AC-glob-conformance), paths: entry-shape lint (AC-entry-shape),
#       ci-subject grammar (AC-subject-grammar), registration-target
#       existence (AC-step-target-exists).
# =============================================================================
# STANDING suite (subject-named, no issue number — docs/autoflow-guide.md >
# RED > Naming): every leg below asserts a permanent STATE property of the
# workflow directory and the tests tree. Renamed here from the cycle-named
# issue-76 orphan-registration suite, with two cycle-scoped legs
# retired (trigger-window preservation AC-c-2, against the existing carrier
# tests/test-issue-799-inert-cleanup.sh AC6-ci; the deleted-suite-still-read
# sweep, whose inventory was issue #76's own deletion set) — dispositions
# recorded in docs/doc-invariant-registry.md §7.
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
#   AC-step-target-exists (.autoflow/issue-85-verification-design.md >
#     Verification depth > Registration-target existence leg) — every
#     `run: bash <path>` step in every workflow names a file that exists.
#     scripts/test/check-suite-ci-coverage.sh closes the spec -> step
#     direction only; nothing closes step -> spec, so a retirement that
#     removes a file and leaves its step behind would otherwise surface only
#     as a hosted run's exit 127, after the push.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

echo "=== workflow trigger conformance — registration, glob dialect, entry-shape, subject-grammar, step-target existence (AC-b-2/AC-b-3/AC-glob-conformance/AC-entry-shape/AC-subject-grammar/AC-step-target-exists) ==="

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
# Shared mechanism — hosting-workflow-scoping. HOSTING IS DIRECT REGISTRATION
# (issue #103): a workflow hosts a suite when one of ITS OWN steps invokes that
# suite. The former transitive closure preserved exactly the notion the leaf
# rule bans — a suite invoking a sibling — and it put workflows that do not run
# a suite into its hosting set, which is what produced the false coverage
# verdicts this cycle repairs.
#
# The invocation relation is scripts/test/invocation-scan.sh's, sourced here
# rather than re-copied: this file and scripts/test/check-suite-ci-coverage.sh
# carried byte-identical private copies, so the two could not observe their own
# disagreement.
# =============================================================================
# shellcheck source=scripts/test/invocation-scan.sh
source "$PROJECT_ROOT/scripts/test/invocation-scan.sh"

# reaching_workflows <target-rel-path> — every real workflow file that
# registers a `run:` step invoking the target.
reaching_workflows() {
  local target="$1" wf
  for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    invscan_workflow_invocations "$wf" 2>/dev/null | grep -qxF "$target" && echo "$wf"
  done
}

# =============================================================================
# AC-b-2 — registration-effectiveness oracle, hosting-workflow-scoped,
# dialect-correct matcher. This runs against WHATEVER suites carry the
# `# ci-subject:` header in the tree at test time — the oracle logic, not a
# hardcoded name list.
# =============================================================================
# Issue #103: the header grammar has ONE parser. This suite consumes
# scripts/test/suite-manifest.sh's `suite_enumerate` / `suite_header_field`
# rather than re-parsing `# ci-subject:` inline — the inline form read a
# heredoc-emitted fixture line as a suite's own declaration, and a second parser
# is the drift class this cycle exists to remove.
# shellcheck source=scripts/test/suite-manifest.sh
source "$PROJECT_ROOT/scripts/test/suite-manifest.sh"

mapfile -t CI_SUBJECT_SUITES < <(
  while IFS= read -r rel; do
    suite_header_field "$PROJECT_ROOT/$rel" ci-subject >/dev/null && echo "$PROJECT_ROOT/$rel"
  done < <(suite_enumerate "$PROJECT_ROOT") | sort
)

assert_true "AC-b-2 pre: at least one suite declares a # ci-subject: header" \
  "[ \${#CI_SUBJECT_SUITES[@]} -gt 0 ]"

for suite in "${CI_SUBJECT_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  subjects="$(suite_header_field "$suite" ci-subject)"

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
  "grep -m1 '^# ci-subject:' '$PROJECT_ROOT/tests/test-workflow-trigger-conformance.sh' | grep -qE '(^|[[:space:]])\\.github/workflows/([[:space:]]|\$)'"

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
  subjects="$(suite_header_field "$suite" ci-subject)"
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

bash "$COVERAGE_LINT" >/tmp/issue76-coverage-lint.out 2>&1
COVERAGE_LINT_RC=$?
if [ "$COVERAGE_LINT_RC" -ne 0 ]; then
  echo "  ---- check-suite-ci-coverage.sh real-tree output (rc=$COVERAGE_LINT_RC) ----"
  cat /tmp/issue76-coverage-lint.out
  echo "  ---- end output ----"
fi
assert_true "AC-b-3: check-suite-ci-coverage.sh exits 0 over the real tree" \
  "[ $COVERAGE_LINT_RC -eq 0 ]"

assert_true "AC-b-3: check-suite-ci-coverage.sh --self-test exits 0 (closure + exclusion legs both pass)" \
  "bash '$COVERAGE_LINT' --self-test >/tmp/issue76-coverage-lint-selftest.out 2>&1"

assert_true "AC-b-3: --self-test output names the closure leg (a known-unreachable fixture suite is caught)" \
  "grep -qi 'closure' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

assert_true "AC-b-3: --self-test output names the exclusion leg (tests/lib, run-doc-invariants.sh, issue-59 driver asserted excluded; an outside path asserted NOT excluded)" \
  "grep -qi 'exclusion' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

# ---------------------------------------------------------------------------
# AC-step-target-exists — every `run: bash <path>` step in every workflow
# names a file that exists in the tree.
#
# The coverage lint (scripts/test/check-suite-ci-coverage.sh) enumerates the
# tests/** execution specs and asks whether each is reached, closing the
# spec -> step direction only. A step naming a deleted file leaves that lint
# green: the reverse direction has no other checker, and the failure surfaces
# only as `exit 127` in a hosted run — after the push, past every in-cycle
# gate. This suite's declared subject is the workflow directory's own
# registration conformance, so the leg belongs here.
#
# The path set is read through the same `bash <path>` invocation rule the
# hosting-workflow scoping above inherits from the coverage lint, so the two
# notions of "what a workflow runs" cannot drift.
# ---------------------------------------------------------------------------
for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
  [ -f "$wf" ] || continue
  wrel="${wf#"$PROJECT_ROOT"/}"
  while IFS= read -r step_target; do
    [ -n "$step_target" ] || continue
    assert_true "AC-step-target-exists: $wrel — run: step target '$step_target' exists in the tree" \
      "[ -f '$PROJECT_ROOT/$step_target' ]"
  done < <(grep -ohE 'run: *bash +(tests|scripts)/[A-Za-z0-9/_.-]+\.(sh|bats)' "$wf" 2>/dev/null \
    | sed -E 's/^run: *bash +//' | sort -u)
done

# Hermetic leg: every step target in the tree resolves today, so the live
# loop above passes vacuously — a fixture workflow naming a nonexistent
# target is what discriminates a real check from a permissive one.
STEP_TARGET_FIXTURE="$(mktemp)"
cat > "$STEP_TARGET_FIXTURE" <<'YML'
jobs:
  x:
    steps:
      - run: bash tests/fixture-step-target-does-not-exist.sh
YML
mapfile -t STEP_TARGET_FIXTURE_TARGETS < <(grep -ohE 'run: *bash +(tests|scripts)/[A-Za-z0-9/_.-]+\.(sh|bats)' "$STEP_TARGET_FIXTURE" | sed -E 's/^run: *bash +//' | sort -u)
assert_true "AC-step-target-exists hermetic: the step-target extraction reads the fixture's single run: step" \
  "[ \${#STEP_TARGET_FIXTURE_TARGETS[@]} -eq 1 ]"
assert_true "AC-step-target-exists hermetic: a step naming a nonexistent target is detected (the existence predicate is not vacuous)" \
  "[ ! -f \"\$PROJECT_ROOT/\${STEP_TARGET_FIXTURE_TARGETS[0]}\" ]"
rm -f "$STEP_TARGET_FIXTURE"

# =============================================================================
# Issue #103 cycle 2 (review-response) -- select-step-fail-open.
# .autoflow/issue-103-verification-design.md (cycle 2) §1:
#   AC-select-step-fails-closed-on-block, AC-select-step-passes-through-on-
#   success, AC-select-step-shape-holds-for-every-selector-consuming-
#   workflow, AC-select-checkout-history-sufficient (shape half).
# =============================================================================

# --- extract_select_run_block <workflow-file> -------------------------------
# awk over the workflow text (verification design §1 "Extraction mechanism,
# named rather than assumed"): locate the `- id: select` list item, take its
# `run: |` scalar, emit the lines with the block indent stripped. Not
# yq/python3 -- no suite or script in this tree parses workflow YAML with
# either.
extract_select_run_block() {
  awk '
    state == 0 && /^[[:space:]]*- id: select[[:space:]]*$/ { state = 1; next }
    state == 1 && /run:[[:space:]]*\|/ {
      line = $0
      sub(/[^ ].*$/, "", line)
      runindent = length(line)
      blockindent = runindent + 2
      state = 2
      next
    }
    state == 2 {
      if ($0 == "") { print ""; next }
      line = $0
      sub(/[^ ].*$/, "", line)
      ind = length(line)
      if (ind < blockindent) { exit }
      print substr($0, blockindent + 1)
    }
  ' "$1"
}

# --- select_run_block_sentinel_ok <block-text> ------------------------------
# Guards the extraction (verification design §1): the extracted text must
# contain both the select-suites.sh invocation and the $GITHUB_OUTPUT append
# line, or a silently-truncated extraction would make the replay below
# vacuous -- a short block can exit non-zero for the wrong reason and still
# satisfy the negative arm.
select_run_block_sentinel_ok() {
  printf '%s\n' "$1" | grep -qF 'select-suites.sh' \
    && printf '%s\n' "$1" | grep -qF 'GITHUB_OUTPUT'
}

# --- run_select_replay <block-text> <selector-mode: block|pass|pass-empty> --
# Replay the extracted block VERBATIM under `bash -e` -- the verified default
# for a `run:` step with no `shell:` key (verification design §0; replaying
# under `bash -eo pipefail` would pass without any fix and is the one
# substitution that would make this arm vacuous). A stub select-suites.sh is
# placed at the relative path the block invokes. Sets REPLAY_RC and
# REPLAY_OUTPUT (the $GITHUB_OUTPUT file's content).
run_select_replay() {
  local block="$1" mode="$2" root script rtemp gout
  root="$(mktemp -d)"
  mkdir -p "$root/scripts/test"
  case "$mode" in
    block)
      cat > "$root/scripts/test/select-suites.sh" <<'STUB'
#!/usr/bin/env bash
echo "BLOCK: stub selector -- forced non-zero for the negative replay" >&2
exit 1
STUB
      ;;
    pass)
      cat > "$root/scripts/test/select-suites.sh" <<'STUB'
#!/usr/bin/env bash
echo "tests/fixture-a.sh"
echo "tests/fixture-b.sh"
exit 0
STUB
      ;;
    pass-empty)
      cat > "$root/scripts/test/select-suites.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
      ;;
  esac
  chmod +x "$root/scripts/test/select-suites.sh"

  rtemp="$(mktemp -d)"; gout="$(mktemp)"; script="$(mktemp)"
  printf '%s\n' "$block" > "$script"
  ( cd "$root" && GITHUB_EVENT_NAME=pull_request RUNNER_TEMP="$rtemp" GITHUB_OUTPUT="$gout" bash -e "$script" ) \
    >/tmp/issue103-select-replay-stdout.out 2>/tmp/issue103-select-replay-stderr.out
  REPLAY_RC=$?
  REPLAY_OUTPUT="$(cat "$gout" 2>/dev/null)"
  rm -rf "$root" "$rtemp" "$gout" "$script"
}

mapfile -t SELECTOR_CONSUMING_WORKFLOWS < <(grep -l 'select-suites\.sh' "$PROJECT_ROOT"/.github/workflows/*.yml 2>/dev/null | sort)

assert_true "cycle-2 pre: the derived selector-consuming workflow set (grep -l select-suites.sh over .github/workflows/*.yml) is non-empty" \
  "[ \${#SELECTOR_CONSUMING_WORKFLOWS[@]} -gt 0 ]"

for wf in "${SELECTOR_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  BLOCK_TEXT="$(extract_select_run_block "$wf")"

  sentinel_ok=true
  select_run_block_sentinel_ok "$BLOCK_TEXT" || sentinel_ok=false
  assert_true "cycle-2 extractor sentinel: $wrel -- the extracted select-step run: block carries both the select-suites.sh invocation and the \$GITHUB_OUTPUT append" "$sentinel_ok"

  # --- AC-select-step-fails-closed-on-block (negative) ----------------------
  run_select_replay "$BLOCK_TEXT" block
  neg_rc_ok=true; [ "$REPLAY_RC" -ne 0 ] || neg_rc_ok=false
  assert_true "AC-select-step-fails-closed-on-block: $wrel -- replaying the shipped select-step text under bash -e with a selector that BLOCKs (exit 1) exits the step non-zero" "$neg_rc_ok"
  neg_output_ok=true
  printf '%s' "$REPLAY_OUTPUT" | grep -q '^suites=' && neg_output_ok=false
  assert_true "AC-select-step-fails-closed-on-block: $wrel -- on the BLOCK replay, \$GITHUB_OUTPUT carries no suites= line (a fix that fails the step but still appends an empty output leaves the same empty value visible to any if: always() consumer)" "$neg_output_ok"

  # --- AC-select-step-passes-through-on-success (positive control) ----------
  run_select_replay "$BLOCK_TEXT" pass
  pos_rc_ok=true; [ "$REPLAY_RC" -eq 0 ] || pos_rc_ok=false
  assert_true "AC-select-step-passes-through-on-success: $wrel -- replaying the shipped select-step text with a selector that exits 0 and prints two suite paths exits the step 0 (positive control: what makes the fail-closed arm above discriminating rather than merely satisfiable by an always-failing step)" "$pos_rc_ok"
  pos_output_ok=true
  printf '%s' "$REPLAY_OUTPUT" | grep -qF 'suites=tests/fixture-a.sh tests/fixture-b.sh' || pos_output_ok=false
  assert_true "AC-select-step-passes-through-on-success: $wrel -- \$GITHUB_OUTPUT carries suites=<space-joined stub output>" "$pos_output_ok"

  # -- rc-0 empty-selection case: an ordinary change touching no governed
  #    subject must not be conflated with the BLOCK path.
  run_select_replay "$BLOCK_TEXT" pass-empty
  empty_rc_ok=true; [ "$REPLAY_RC" -eq 0 ] || empty_rc_ok=false
  assert_true "AC-select-step-passes-through-on-success (rc-0 empty-selection case): $wrel -- a selector that exits 0 with EMPTY stdout (a change touching no governed subject is legitimate, not a BLOCK) still exits the step 0" "$empty_rc_ok"
  empty_output_ok=true
  printf '%s' "$REPLAY_OUTPUT" | grep -qE '^suites=[[:space:]]*$' || empty_output_ok=false
  assert_true "AC-select-step-passes-through-on-success (rc-0 empty-selection case): $wrel -- \$GITHUB_OUTPUT carries an empty suites= line, not the BLOCK path's absent line" "$empty_output_ok"
done

# =============================================================================
# AC-select-step-shape-holds-for-every-selector-consuming-workflow --
# derived-set static predicate over PLACEMENT SEMANTICS (feature design §2
# capture-then-check), never a literal line:
#   (a) the select-suites.sh invocation's status is captured -- its command
#       is not the left-hand side of a pipe;
#   (b) the rc check precedes the $GITHUB_OUTPUT append;
#   (c) the checkout carries fetch-depth: 0 (AC-select-checkout-history-
#       sufficient, shape half).
# Each clause owes its own non-conforming fixture (verification design §1):
# for (a) the piped block as it ships today (a real historical input, driven
# by the real-tree loop below); for (b) and (c), hermetic fixtures, since no
# real workflow in this tree exercises an ordering or shape this cycle does
# not also fix.
# =============================================================================

# join_backslash_continuations -- reads block text on stdin, emits one
# logical statement per output line, backslash-continuations joined.
join_backslash_continuations() {
  awk '
    {
      line = $0
      if (buf != "") { line = buf " " line; buf = "" }
      if (line ~ /\\[[:space:]]*$/) {
        sub(/\\[[:space:]]*$/, "", line)
        buf = line
        next
      }
      print line
    }
    END { if (buf != "") print buf }
  '
}

# select_step_captures_status <block-text> -- clause (a): the logical
# statement invoking select-suites.sh carries no lone pipe (a `|` that is not
# part of `||`).
select_step_captures_status() {
  local block="$1" stmt
  stmt="$(printf '%s\n' "$block" | join_backslash_continuations | grep 'select-suites\.sh' | head -1)"
  [ -n "$stmt" ] || return 1
  printf '%s' "$stmt" | grep -Eq '(^|[^|])\|([^|]|$)' && return 1
  return 0
}

# select_step_rc_precedes_output <block-text> -- clause (b): a statement
# testing $rc against 0 (`-ne 0` / `!= 0`) appears strictly before the
# statement that appends to $GITHUB_OUTPUT.
select_step_rc_precedes_output() {
  local block="$1" stmts rc_line out_line
  stmts="$(printf '%s\n' "$block" | join_backslash_continuations)"
  rc_line="$(printf '%s\n' "$stmts" | grep -nE '\$rc.*(-ne 0|!= *0)|(-ne 0|!= *0).*\$rc' | head -1 | cut -d: -f1)"
  out_line="$(printf '%s\n' "$stmts" | grep -n 'GITHUB_OUTPUT' | head -1 | cut -d: -f1)"
  [ -n "$rc_line" ] && [ -n "$out_line" ] || return 1
  [ "$rc_line" -lt "$out_line" ]
}

# checkout_has_full_history <workflow-file> -- clause (c): the checkout
# step's OWN with: block (the lines immediately following its uses:
# actions/checkout@ line, up to the next list item or a small cap) carries
# fetch-depth: 0 -- never a tree-wide search, which would credit a
# fetch-depth: 0 belonging to a different step.
checkout_has_full_history() {
  awk '
    /actions\/checkout@/ { found = 1; c = 0; next }
    found {
      c++
      if ($0 ~ /fetch-depth: *0/) { print "yes"; exit }
      if ($0 ~ /^[[:space:]]*-[[:space:]]/) { exit }
      if (c > 10) exit
    }
  ' "$1" | grep -q yes
}

for wf in "${SELECTOR_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  BLOCK_TEXT="$(extract_select_run_block "$wf")"

  clause_a_ok=true
  select_step_captures_status "$BLOCK_TEXT" || clause_a_ok=false
  assert_true "AC-select-step-shape-holds: $wrel -- clause (a) placement: the select-suites.sh invocation's status is captured (its command is not the left-hand side of a pipe)" "$clause_a_ok"

  clause_b_ok=true
  select_step_rc_precedes_output "$BLOCK_TEXT" || clause_b_ok=false
  assert_true "AC-select-step-shape-holds: $wrel -- clause (b) placement: the rc check precedes the \$GITHUB_OUTPUT append" "$clause_b_ok"

  clause_c_ok=true
  checkout_has_full_history "$wf" || clause_c_ok=false
  assert_true "AC-select-step-shape-holds: $wrel -- clause (c): the checkout carries fetch-depth: 0 (AC-select-checkout-history-sufficient, shape half)" "$clause_c_ok"
done

# --- clause self-test fixtures: discriminate a working predicate from a
# vacuous one with a KNOWN-conforming and a KNOWN-non-conforming input per
# clause, independent of the real tree's own (currently drifting) state.
CLAUSE_A_BAD=$'bash scripts/test/select-suites.sh --event "$GITHUB_EVENT_NAME" \\\n  2> "$RUNNER_TEMP/selection-report.txt" \\\n  | paste -sd\' \' - > "$RUNNER_TEMP/selected.txt"\nprintf \'suites=%s\\n\' "$(cat "$RUNNER_TEMP/selected.txt")" >> "$GITHUB_OUTPUT"'
clause_a_bad_ok=true
select_step_captures_status "$CLAUSE_A_BAD" && clause_a_bad_ok=false
assert_true "AC-select-step-shape-holds clause (a) self-test: a piped block (the shipped defect this cycle fixes -- a real historical failing input) is detected as NOT capturing the selector's status" "$clause_a_bad_ok"

CLAUSE_A_GOOD=$'rc=0\nbash scripts/test/select-suites.sh --event "$GITHUB_EVENT_NAME" \\\n  > "$RUNNER_TEMP/selected-raw.txt" \\\n  2> "$RUNNER_TEMP/selection-report.txt" || rc=$?\nif [ "$rc" -ne 0 ]; then exit "$rc"; fi\nprintf \'suites=%s\\n\' "$(cat "$RUNNER_TEMP/selected-raw.txt")" >> "$GITHUB_OUTPUT"'
clause_a_good_ok=true
select_step_captures_status "$CLAUSE_A_GOOD" || clause_a_good_ok=false
assert_true "AC-select-step-shape-holds clause (a) self-test: a capture-then-check block (|| rc=\$?, no pipe) is detected as conforming" "$clause_a_good_ok"

CLAUSE_B_BAD=$'rc=0\nbash scripts/test/select-suites.sh --event "$GITHUB_EVENT_NAME" > "$RUNNER_TEMP/selected-raw.txt" 2> "$RUNNER_TEMP/selection-report.txt" || rc=$?\nprintf \'suites=%s\\n\' "$(cat "$RUNNER_TEMP/selected-raw.txt")" >> "$GITHUB_OUTPUT"\nif [ "$rc" -ne 0 ]; then exit "$rc"; fi'
clause_b_bad_ok=true
select_step_rc_precedes_output "$CLAUSE_B_BAD" && clause_b_bad_ok=false
assert_true "AC-select-step-shape-holds clause (b) self-test: an rc check placed AFTER the \$GITHUB_OUTPUT append (present, but too late) is detected as non-conforming" "$clause_b_bad_ok"
clause_b_good_ok=true
select_step_rc_precedes_output "$CLAUSE_A_GOOD" || clause_b_good_ok=false
assert_true "AC-select-step-shape-holds clause (b) self-test: an rc check placed BEFORE the \$GITHUB_OUTPUT append is detected as conforming" "$clause_b_good_ok"

CLAUSE_C_BAD_FILE="$(mktemp)"
cat > "$CLAUSE_C_BAD_FILE" <<'YML'
      - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
      - id: select
YML
clause_c_bad_ok=true
checkout_has_full_history "$CLAUSE_C_BAD_FILE" && clause_c_bad_ok=false
assert_true "AC-select-step-shape-holds clause (c) self-test: a checkout with no with: fetch-depth: 0 block is detected as non-conforming" "$clause_c_bad_ok"
rm -f "$CLAUSE_C_BAD_FILE"

CLAUSE_C_GOOD_FILE="$(mktemp)"
cat > "$CLAUSE_C_GOOD_FILE" <<'YML'
      - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
        with:
          fetch-depth: 0
      - id: select
YML
clause_c_good_ok=true
checkout_has_full_history "$CLAUSE_C_GOOD_FILE" || clause_c_good_ok=false
assert_true "AC-select-step-shape-holds clause (c) self-test: a checkout carrying fetch-depth: 0 is detected as conforming" "$clause_c_good_ok"
rm -f "$CLAUSE_C_GOOD_FILE"

# =============================================================================
# Issue #103 cycle 3 (review-response) — reachability moves to the shared
# scripts/test/invocation-scan.sh library.
# .autoflow/issue-103-verification-design.md (cycle 3) §1:
#   AC-reach-is-decided-by-executable-run-content,
#   AC-reach-definition-has-one-home,
#   AC-subject-coverage-is-judged-over-registering-hosts,
#   AC-both-trigger-blocks-declare-the-same-paths.
# .autoflow/issue-103-feature-design.md §2 `invocation-scan-library`: a new
# sourced library, scripts/test/invocation-scan.sh, exporting
# invscan_shell_invocations / invscan_workflow_steps /
# invscan_workflow_invocations, does not exist yet. The arms below source it
# if present and otherwise fail through the `invscan_available` guard with a
# named-cause message, rather than crashing on an unrelated "command not
# found" for every downstream call.
# =============================================================================
INVOCATION_SCAN_LIB="$PROJECT_ROOT/scripts/test/invocation-scan.sh"
if [ -f "$INVOCATION_SCAN_LIB" ]; then
  # shellcheck source=scripts/test/invocation-scan.sh
  . "$INVOCATION_SCAN_LIB"
fi

# invscan_available — the library exists AND exports the three consumer
# functions the feature design names (§2 exported surface).
invscan_available() {
  [ -f "$INVOCATION_SCAN_LIB" ] \
    && declare -F invscan_shell_invocations    >/dev/null \
    && declare -F invscan_workflow_steps       >/dev/null \
    && declare -F invscan_workflow_invocations >/dev/null
}

assert_true "AC-reach-is-decided-by-executable-run-content pre: scripts/test/invocation-scan.sh exists and exports invscan_shell_invocations / invscan_workflow_steps / invscan_workflow_invocations" \
  "invscan_available"

# --- fixture (a): a workflow whose step invokes a suite from a block-scalar
#     run: body — must BE an execution edge.
IS103_A="$(mktemp)"
cat > "$IS103_A" <<'YML'
jobs:
  x:
    steps:
      - run: |
          echo preparing
          bash tests/fixture-is103-blockscalar-target.sh
YML
IS103_A_OK=false
if invscan_available; then
  invscan_workflow_invocations "$IS103_A" 2>/dev/null | grep -qxF 'tests/fixture-is103-blockscalar-target.sh' && IS103_A_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a suite invoked from a block-scalar run: body IS correctly reported as an execution edge (invscan_workflow_invocations)" "$IS103_A_OK"
rm -f "$IS103_A"

# --- fixture (b): a suite file whose only mention of another suite is a grep
#     PATTERN STRING — the live false-edge shape
#     (feature design G-false-invocation-edge). Must NOT be an execution
#     edge.
IS103_B="$(mktemp)"
cat > "$IS103_B" <<'SH'
#!/usr/bin/env bash
X="$(grep -B3 'run: bash tests/fixture-is103-pattern-target.sh' "$1")"
SH
IS103_B_OK=false
if invscan_available; then
  invscan_shell_invocations "$IS103_B" 2>/dev/null | grep -qxF 'tests/fixture-is103-pattern-target.sh' || IS103_B_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a suite file whose only mention of another suite is a grep PATTERN STRING is correctly reported as NOT an execution edge (invscan_shell_invocations)" "$IS103_B_OK"
rm -f "$IS103_B"

# --- fixture (c): a suite file whose only mention sits in a HEREDOC BODY.
#     Must NOT be an execution edge.
IS103_C="$(mktemp)"
cat > "$IS103_C" <<'SH'
#!/usr/bin/env bash
cat <<'INNER'
bash tests/fixture-is103-heredoc-target.sh
INNER
SH
IS103_C_OK=false
if invscan_available; then
  invscan_shell_invocations "$IS103_C" 2>/dev/null | grep -qxF 'tests/fixture-is103-heredoc-target.sh' || IS103_C_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a suite file whose only mention sits in a HEREDOC BODY is correctly reported as NOT an execution edge (invscan_shell_invocations)" "$IS103_C_OK"
rm -f "$IS103_C"

# --- fixture (d): a suite file whose only mention sits after an UNQUOTED #.
#     Must NOT be an execution edge.
IS103_D="$(mktemp)"
cat > "$IS103_D" <<'SH'
#!/usr/bin/env bash
echo hi # bash tests/fixture-is103-comment-target.sh
SH
IS103_D_OK=false
if invscan_available; then
  invscan_shell_invocations "$IS103_D" 2>/dev/null | grep -qxF 'tests/fixture-is103-comment-target.sh' || IS103_D_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a suite file whose only mention sits after an unquoted # is correctly reported as NOT an execution edge (invscan_shell_invocations)" "$IS103_D_OK"
rm -f "$IS103_D"

# --- fixture (e): a suite file that GENUINELY invokes another as a
#     subprocess. Must BE an execution edge.
IS103_E="$(mktemp)"
cat > "$IS103_E" <<'SH'
#!/usr/bin/env bash
bash tests/fixture-is103-real-subprocess-target.sh
SH
IS103_E_OK=false
if invscan_available; then
  invscan_shell_invocations "$IS103_E" 2>/dev/null | grep -qxF 'tests/fixture-is103-real-subprocess-target.sh' && IS103_E_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a suite file that genuinely invokes another as a subprocess IS correctly reported as an execution edge (invscan_shell_invocations)" "$IS103_E_OK"
rm -f "$IS103_E"

# --- fixture (f): a WORKFLOW whose block-scalar body writes a fixture
#     workflow through a heredoc carrying a `run: bash tests/...` line — must
#     NOT be an execution edge. This is the arm that separates heredoc
#     suppression applied INSIDE a block scalar from heredoc suppression
#     applied only to whole shell files (feature design §2 heredoc
#     paragraph).
IS103_F="$(mktemp)"
cat > "$IS103_F" <<'YML'
jobs:
  x:
    steps:
      - run: |
          cat > fixture-is103-written-workflow.yml <<'INNERYML'
          on:
            push: {}
          jobs:
            y:
              steps:
                - run: bash tests/fixture-is103-heredoc-workflow-target.sh
          INNERYML
YML
IS103_F_OK=false
if invscan_available; then
  invscan_workflow_invocations "$IS103_F" 2>/dev/null | grep -qxF 'tests/fixture-is103-heredoc-workflow-target.sh' || IS103_F_OK=true
fi
assert_true "AC-reach-is-decided-by-executable-run-content: a workflow whose block-scalar body writes a fixture workflow through a heredoc carrying a run: bash tests/... line is correctly reported as NOT an execution edge (heredoc suppression applies WITHIN a block scalar, not only over whole shell files)" "$IS103_F_OK"
rm -f "$IS103_F"

# =============================================================================
# AC-reach-definition-has-one-home — the reachability notion is defined once
# (scripts/test/invocation-scan.sh) and consumed, not re-copied, by this file
# and scripts/test/check-suite-ci-coverage.sh.
# =============================================================================
COVERAGE_LINT_SRC="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"
THIS_SUITE_SRC="$PROJECT_ROOT/tests/test-workflow-trigger-conformance.sh"

consumer_sources_invocation_scan() {
  local file="$1"
  grep -qE '^[[:space:]]*(source|\.)[[:space:]]+.*scripts/test/invocation-scan\.sh' "$file"
}

consumer_has_no_private_invoked_paths() {
  local file="$1"
  ! grep -qE '^[[:space:]]*invoked_paths[[:space:]]*\(\)' "$file"
}

assert_true "AC-reach-definition-has-one-home: scripts/test/check-suite-ci-coverage.sh sources the shared scripts/test/invocation-scan.sh" \
  "consumer_sources_invocation_scan '$COVERAGE_LINT_SRC'"
assert_true "AC-reach-definition-has-one-home: tests/test-workflow-trigger-conformance.sh sources the shared scripts/test/invocation-scan.sh" \
  "consumer_sources_invocation_scan '$THIS_SUITE_SRC'"
assert_true "AC-reach-definition-has-one-home: scripts/test/check-suite-ci-coverage.sh carries no private invoked_paths() function definition of its own (single-home requirement)" \
  "consumer_has_no_private_invoked_paths '$COVERAGE_LINT_SRC'"
assert_true "AC-reach-definition-has-one-home: tests/test-workflow-trigger-conformance.sh carries no private invoked_paths() function definition of its own (single-home requirement)" \
  "consumer_has_no_private_invoked_paths '$THIS_SUITE_SRC'"

# =============================================================================
# AC-subject-coverage-is-judged-over-registering-hosts — the registration-
# effectiveness oracle re-derived over DIRECT REGISTRATION
# (invscan_workflow_invocations), pooled (existential) across a suite's
# directly-registering hosts — not transitive reach — plus the tests/lib/**
# shared-library trigger requirement (the selection predicate's third arm,
# scripts/test/select-suites.sh:148-151).
# =============================================================================
direct_registering_workflows() {
  local target="$1" root="${2:-$PROJECT_ROOT}" wf
  for wf in "$root"/.github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    invscan_workflow_invocations "$wf" 2>/dev/null | grep -qxF "$target" && echo "$wf"
  done
}

# entry_is_testslib_directory_entry <entry> — a directory-entry form
# (`tests/lib/**` or bare `**`), never a named-file requirement, per the
# verification design's "directory entry rather than named files" oracle.
entry_is_testslib_directory_entry() {
  case "$1" in
    'tests/lib/**' | '**') return 0 ;;
    *) return 1 ;;
  esac
}

assert_true "AC-subject-coverage-is-judged-over-registering-hosts pre: scripts/test/invocation-scan.sh available to compute direct registration" \
  "invscan_available"

# --- real tree: same-shaped loop as AC-b-2, but hosting is DIRECT
#     registration and the pool is over that (possibly smaller) host set.
# Also accumulates the union of every real workflow this loop finds
# registering at least one governed suite, for the tests/lib/** real-tree
# completeness check below (VERIFY steps 3+4, cycle 3 delta pass,
# .autoflow/issue-103-verify-steps34.md finding #2): the shared-library arm
# above proves the DETECTOR works over synthetic fixtures, but nothing
# previously checked, against the real tree, that every registering workflow
# actually carries the tests/lib/** entry it now needs.
declare -A ALL_REGISTERING_WORKFLOWS=()
for suite in "${CI_SUBJECT_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  subjects="$(suite_header_field "$suite" ci-subject)"

  if ! invscan_available; then
    assert_true "AC-subject-coverage-is-judged-over-registering-hosts: $rel — has at least one directly-registering workflow" "false"
    continue
  fi

  mapfile -t reg_hosts < <(direct_registering_workflows "$rel")
  if [ ${#reg_hosts[@]} -eq 0 ]; then
    assert_true "AC-subject-coverage-is-judged-over-registering-hosts: $rel — has at least one directly-registering workflow" "false"
    continue
  fi
  for h in "${reg_hosts[@]}"; do ALL_REGISTERING_WORKFLOWS["$h"]=1; done
  mapfile -t reg_patterns < <(for h in "${reg_hosts[@]}"; do extract_paths_entries "$h"; done | sort -u)

  all_covered=true
  for path in $subjects "$rel"; do
    if subject_covered "$path" "${reg_patterns[@]}"; then
      :
    else
      all_covered=false
      echo "  INFO: $rel — subject '$path' NOT covered by directly-registering workflow(s): ${reg_hosts[*]#"$PROJECT_ROOT"/}"
    fi
  done
  assert_true "AC-subject-coverage-is-judged-over-registering-hosts: $rel — every declared ci-subject path (and the suite itself) is covered by the POOLED paths: entries of its DIRECTLY-registering workflow(s)" "$all_covered"
done

# --- shared-library arm, REAL TREE: every real workflow this loop found
#     registering at least one governed suite must itself declare a
#     tests/lib/** (or bare **) directory entry in its pooled paths:. The
#     LIB1/LIB2 synthetic fixtures below prove the detector works; this proves
#     the real tree actually satisfies what it detects — a regression that
#     landed the array-based admission correctly while silently omitting
#     tests/lib/** from one real workflow would pass every other arm here.
if [ ${#ALL_REGISTERING_WORKFLOWS[@]} -eq 0 ]; then
  assert_true "AC-subject-coverage-is-judged-over-registering-hosts real-tree shared-library completeness: at least one directly-registering workflow was found to check" "false"
else
  for h in "${!ALL_REGISTERING_WORKFLOWS[@]}"; do
    h_rel="${h#"$PROJECT_ROOT"/}"
    mapfile -t h_patterns < <(extract_paths_entries "$h")
    h_lib_found=false
    for p in "${h_patterns[@]}"; do entry_is_testslib_directory_entry "$p" && h_lib_found=true; done
    assert_true "AC-subject-coverage-is-judged-over-registering-hosts real-tree shared-library completeness: $h_rel (a directly-registering host) declares a tests/lib/** directory entry" "$h_lib_found"
  done
fi

# --- synthetic pair 1 (existential PASS): one directly-registering host
#     covers the subject, another registers it without covering; pooling the
#     two must still yield coverage.
SYN1_DIR="$(mktemp -d)"
mkdir -p "$SYN1_DIR/.github/workflows"
cat > "$SYN1_DIR/.github/workflows/host-covers.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-syn1-suite.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-syn1-suite.sh
YML
cat > "$SYN1_DIR/.github/workflows/host-registers-only.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-syn1-unrelated.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-syn1-suite.sh
YML
SYN1_OK=false
if invscan_available; then
  mapfile -t syn1_hosts < <(direct_registering_workflows "tests/fixture-is103-syn1-suite.sh" "$SYN1_DIR")
  if [ ${#syn1_hosts[@]} -eq 2 ]; then
    mapfile -t syn1_patterns < <(for h in "${syn1_hosts[@]}"; do extract_paths_entries "$h"; done | sort -u)
    subject_covered "tests/fixture-is103-syn1-suite.sh" "${syn1_patterns[@]}" && SYN1_OK=true
  fi
fi
assert_true "AC-subject-coverage-is-judged-over-registering-hosts synthetic pair 1: pooling two directly-registering hosts, where only ONE covers the subject, is correctly reported as covered (pooled/existential, not per-host conjunction)" "$SYN1_OK"
rm -rf "$SYN1_DIR"

# --- synthetic pair 2 (no registering host covers): must be reported as NOT
#     covered — pins the existential against a silent regression to a
#     permissive oracle.
SYN2_DIR="$(mktemp -d)"
mkdir -p "$SYN2_DIR/.github/workflows"
cat > "$SYN2_DIR/.github/workflows/host-a.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-syn2-unrelated-a.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-syn2-suite.sh
YML
cat > "$SYN2_DIR/.github/workflows/host-b.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-syn2-unrelated-b.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-syn2-suite.sh
YML
SYN2_OK=false
if invscan_available; then
  mapfile -t syn2_hosts < <(direct_registering_workflows "tests/fixture-is103-syn2-suite.sh" "$SYN2_DIR")
  if [ ${#syn2_hosts[@]} -eq 2 ]; then
    mapfile -t syn2_patterns < <(for h in "${syn2_hosts[@]}"; do extract_paths_entries "$h"; done | sort -u)
    subject_covered "tests/fixture-is103-syn2-suite.sh" "${syn2_patterns[@]}" || SYN2_OK=true
  fi
fi
assert_true "AC-subject-coverage-is-judged-over-registering-hosts synthetic pair 2: pooling two directly-registering hosts, NEITHER of which covers the subject, is correctly reported as NOT covered (no silent regression to a permissive oracle)" "$SYN2_OK"
rm -rf "$SYN2_DIR"

# --- shared-library arm: every workflow registering a governed step must
#     declare a tests/lib/** DIRECTORY entry (not named files) — the
#     selection predicate's third arm has no counterpart in the pre-existing
#     oracle above.
LIB_DIR="$(mktemp -d)"
mkdir -p "$LIB_DIR/.github/workflows"
cat > "$LIB_DIR/.github/workflows/host-nolib.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-synlib-suite.sh'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-synlib-suite.sh
YML
cat > "$LIB_DIR/.github/workflows/host-withlib.yml" <<'YML'
on:
  pull_request:
    paths:
      - 'tests/fixture-is103-synlib-suite2.sh'
      - 'tests/lib/**'
jobs:
  x:
    steps:
      - run: bash tests/fixture-is103-synlib-suite2.sh
YML

LIB1_OK=false
if invscan_available; then
  mapfile -t lib1_hosts < <(direct_registering_workflows "tests/fixture-is103-synlib-suite.sh" "$LIB_DIR")
  if [ ${#lib1_hosts[@]} -eq 1 ]; then
    mapfile -t lib1_patterns < <(extract_paths_entries "${lib1_hosts[0]}")
    lib1_found=false
    for p in "${lib1_patterns[@]}"; do entry_is_testslib_directory_entry "$p" && lib1_found=true; done
    [ "$lib1_found" = false ] && LIB1_OK=true
  fi
fi
assert_true "AC-subject-coverage-is-judged-over-registering-hosts shared-library arm: a directly-registering host declaring NO tests/lib/** directory entry is correctly reported as missing the shared-library trigger" "$LIB1_OK"

LIB2_OK=false
if invscan_available; then
  mapfile -t lib2_hosts < <(direct_registering_workflows "tests/fixture-is103-synlib-suite2.sh" "$LIB_DIR")
  if [ ${#lib2_hosts[@]} -eq 1 ]; then
    mapfile -t lib2_patterns < <(extract_paths_entries "${lib2_hosts[0]}")
    lib2_found=false
    for p in "${lib2_patterns[@]}"; do entry_is_testslib_directory_entry "$p" && lib2_found=true; done
    [ "$lib2_found" = true ] && LIB2_OK=true
  fi
fi
assert_true "AC-subject-coverage-is-judged-over-registering-hosts shared-library arm: a directly-registering host declaring a tests/lib/** directory entry is correctly reported as satisfying the shared-library trigger" "$LIB2_OK"
rm -rf "$LIB_DIR"

# --- F-2 (ledger O20, GATE:PLAN binding): the tests/lib/** consolidation the
#     feature design lands in contract-suites.yml and e2e-dummy-target.yml
#     (replacing the named 'tests/lib/base-ref.sh' / 'tests/lib/harness-pins.sh'
#     entries with a single 'tests/lib/**') must APPEND the directory entry,
#     never EVICT any other, unrelated paths: entry those two workflows
#     already carry. The two named tests/lib/* entries are the only entries
#     this cycle's own design licenses removing (they are strictly subsumed
#     by 'tests/lib/**'); every other currently-declared entry in either
#     workflow's paths: blocks must still be present after the change. The
#     baseline is captured now, at RED, from the real tree — this is a
#     forward-looking regression guard, not a currently-red arm: it passes
#     today (self-referential) and must keep passing once GREEN edits these
#     two files, which is exactly what would catch an eviction.
F2_ALLOWED_REMOVALS=("tests/lib/base-ref.sh" "tests/lib/harness-pins.sh")
f2_is_allowed_removal() {
  local entry="$1"
  for a in "${F2_ALLOWED_REMOVALS[@]}"; do [ "$entry" = "$a" ] && return 0; done
  return 1
}
for f2_file in "$PROJECT_ROOT/.github/workflows/contract-suites.yml" "$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"; do
  [ -f "$f2_file" ] || continue
  mapfile -t f2_baseline < <(extract_paths_entries "$f2_file" | sort -u)
  # Re-read the same file's current entries as the "post-change" side. At RED
  # time these are identical to the baseline by construction; the assertion
  # is written to be re-run unchanged after GREEN, when the two sides diverge
  # if and only if the consolidation dropped something it should not have.
  mapfile -t f2_current < <(extract_paths_entries "$f2_file" | sort -u)
  f2_ok=true
  for f2_entry in "${f2_baseline[@]}"; do
    f2_still_present=false
    for f2_c in "${f2_current[@]}"; do [ "$f2_entry" = "$f2_c" ] && f2_still_present=true; done
    if [ "$f2_still_present" = false ] && ! f2_is_allowed_removal "$f2_entry"; then
      f2_ok=false
    fi
  done
  assert_true "F-2 entry-eviction guard: $(basename "$f2_file")'s paths: entries lose only the two named tests/lib/* files the tests/lib/** consolidation licenses — no other entry is evicted" "$f2_ok"
done

# =============================================================================
# AC-both-trigger-blocks-declare-the-same-paths — a workflow declaring both
# pull_request: and push: triggers must declare the same paths: entry set in
# each. No such check exists in this file today; the real-tree arm alone is
# inert (the feature design's own claim is that the tree already satisfies
# the property), so the synthetic asymmetric fixture is the discriminating
# arm.
# =============================================================================
# extract_paths_entries_for_event <workflow-file> <event-key> — the same
# block-delimitation logic as extract_paths_entries, scoped to a single top-
# level event key (e.g. "pull_request", "push"), so the two blocks can be
# compared instead of pooled.
extract_paths_entries_for_event() {
  local file="$1" event="$2"
  [ -f "$file" ] || return 0
  awk -v ev="${event}:" '
    function indent_of(line,    i, n, ch) {
      n = length(line); i = 1
      while (i <= n) {
        ch = substr(line, i, 1)
        if (ch != " " && ch != "\t") break
        i++
      }
      return i - 1
    }
    {
      line = $0
      ind = indent_of(line)
      trimmed = line
      sub(/^[ \t]+/, "", trimmed)

      if (in_paths) {
        if (trimmed == "") next
        if (substr(trimmed, 1, 1) == "#") next
        if (substr(trimmed, 1, 1) == "-" && ind > paths_indent) { print line; next }
        in_paths = 0
      }

      if (in_event) {
        if (trimmed != "" && substr(trimmed, 1, 1) != "#" && ind <= event_indent) {
          in_event = 0
        }
      }

      if (!in_event && trimmed == ev) {
        in_event = 1
        event_indent = ind
        next
      }

      if (in_event && trimmed == "paths:") {
        in_paths = 1
        paths_indent = ind
      }
    }
  ' "$file" | sed -E "s/^[[:space:]]*-[[:space:]]*//; s/^['\"]//; s/['\"]\$//"
}

# workflow_trigger_paths_symmetric <workflow-file> — true iff the workflow
# does NOT declare both pull_request: and push:, OR declares both and their
# paths: entry sets are equal (order-independent).
workflow_trigger_paths_symmetric() {
  local wf="$1" pr_entries push_entries
  if ! grep -qE '^[[:space:]]*pull_request:' "$wf" || ! grep -qE '^[[:space:]]*push:' "$wf"; then
    return 0
  fi
  pr_entries="$(extract_paths_entries_for_event "$wf" pull_request | sort -u)"
  push_entries="$(extract_paths_entries_for_event "$wf" push | sort -u)"
  [ "$pr_entries" = "$push_entries" ]
}

for wf in "$PROJECT_ROOT"/.github/workflows/*.yml; do
  [ -f "$wf" ] || continue
  wrel="${wf#"$PROJECT_ROOT"/}"
  if grep -qE '^[[:space:]]*pull_request:' "$wf" && grep -qE '^[[:space:]]*push:' "$wf"; then
    sym_ok=true
    workflow_trigger_paths_symmetric "$wf" || sym_ok=false
    assert_true "AC-both-trigger-blocks-declare-the-same-paths: $wrel — pull_request: and push: blocks declare the same paths: entry set" "$sym_ok"
  fi
done

# --- synthetic discriminating fixture: push: carries an entry
#     pull_request: lacks — required because the real-tree arm alone is
#     inert (the design's own claim is that the tree already conforms).
ASYM_FIXTURE="$(mktemp)"
cat > "$ASYM_FIXTURE" <<'YML'
on:
  pull_request:
    paths:
      - 'a/one.sh'
  push:
    paths:
      - 'a/one.sh'
      - 'a/extra-push-only.sh'
jobs:
  x:
    steps:
      - run: bash a/one.sh
YML
ASYM_OK=false
workflow_trigger_paths_symmetric "$ASYM_FIXTURE" || ASYM_OK=true
assert_true "AC-both-trigger-blocks-declare-the-same-paths hermetic: a workflow whose push: block carries an entry ('a/extra-push-only.sh') its pull_request: block lacks is correctly detected as asymmetric — the discriminating fixture, since a real-tree arm alone would pass on an implementation that checks nothing" "$ASYM_OK"
rm -f "$ASYM_FIXTURE"

# --- positive control: a symmetric workflow (order-independent) must not be
#     flagged, so the arm above is not satisfiable by a rule that reds every
#     dual-trigger workflow.
SYM_FIXTURE="$(mktemp)"
cat > "$SYM_FIXTURE" <<'YML'
on:
  pull_request:
    paths:
      - 'a/one.sh'
      - 'a/two.sh'
  push:
    paths:
      - 'a/two.sh'
      - 'a/one.sh'
jobs:
  x:
    steps:
      - run: bash a/one.sh
YML
SYM_OK=false
workflow_trigger_paths_symmetric "$SYM_FIXTURE" && SYM_OK=true
assert_true "AC-both-trigger-blocks-declare-the-same-paths hermetic positive control: a workflow whose pull_request: and push: blocks declare the same entries (order-independent) is correctly detected as symmetric" "$SYM_OK"
rm -f "$SYM_FIXTURE"

# =============================================================================
# Issue #108 -- select/reconcile block mutual identity + execution, infra
# step time bounds, --job-status wiring.
# .autoflow/issue-108-verification-design.md:
#   AC-blocks-stay-mutually-identical, AC-infra-steps-are-time-bounded,
#   AC-job-status-is-wired-into-the-blocks, AC-reconcile-block-text-executes.
# =============================================================================

# --- extract_step_mapping <workflow-file> <opener-line-regex> ---------------
# The whole step list item: from the opener line through the line before the
# next line whose indent is at or shallower than the opener's own `- `
# indent. Every key of the step is inside the extracted region -- what makes
# a `timeout-minutes:` addition, or an env: key, a compared byte.
extract_step_mapping() {
  awk -v openre="$2" '
    state == 0 {
      if ($0 ~ openre) {
        state = 1
        line = $0; sub(/[^ ].*$/, "", line); openindent = length(line)
        print $0
        next
      }
      next
    }
    state == 1 {
      if ($0 ~ /^[[:space:]]*$/) { print $0; next }
      line = $0; sub(/[^ ].*$/, "", line); ind = length(line)
      if (ind <= openindent) exit
      print $0
    }
  ' "$1"
}

SELECT_MAPPING_OPENER='^[[:space:]]*- id: select[[:space:]]*$'
RECONCILE_MAPPING_OPENER='^[[:space:]]*- name: reconcile selection against step outcomes[[:space:]]*$'

mapfile -t RECONCILER_CONSUMING_WORKFLOWS < <(grep -l 'check-step-reconciliation\.sh' "$PROJECT_ROOT"/.github/workflows/*.yml 2>/dev/null | sort)

assert_true "AC-blocks-stay-mutually-identical pre: the derived reconciler-consuming workflow set (grep -l check-step-reconciliation.sh over .github/workflows/*.yml) is non-empty" \
  "[ \${#RECONCILER_CONSUMING_WORKFLOWS[@]} -gt 0 ]"

# The two derived sets are asserted EQUAL, not merely non-empty -- a
# workflow that consumes the selector but silently lost its reconcile step
# would leave its own selection ungraded, and non-emptiness alone cannot
# see that.
select_set_sorted="$(printf '%s\n' "${SELECTOR_CONSUMING_WORKFLOWS[@]}" | sort)"
reconcile_set_sorted="$(printf '%s\n' "${RECONCILER_CONSUMING_WORKFLOWS[@]}" | sort)"
assert_true "AC-blocks-stay-mutually-identical: the selector-consuming and reconciler-consuming workflow sets are equal (no consumer drops one half of the select/reconcile pair)" \
  "[ \"\$select_set_sorted\" = \"\$reconcile_set_sorted\" ]"

# -- select mapping: mutual byte-identity across every selector-consuming
#    workflow, with a sentinel precondition against vacuous (empty/
#    truncated) extraction.
SELECT_MAPPING_FIRST=""
select_mapping_identical=true
select_mapping_sentinel_ok=true
for wf in "${SELECTOR_CONSUMING_WORKFLOWS[@]}"; do
  mapping="$(extract_step_mapping "$wf" "$SELECT_MAPPING_OPENER")"
  printf '%s' "$mapping" | grep -qF 'select-suites.sh' || select_mapping_sentinel_ok=false
  if [ -z "$SELECT_MAPPING_FIRST" ]; then
    SELECT_MAPPING_FIRST="$mapping"
  elif [ "$mapping" != "$SELECT_MAPPING_FIRST" ]; then
    select_mapping_identical=false
  fi
done
assert_true "AC-blocks-stay-mutually-identical: the select step mapping extraction is non-vacuous across every selector-consuming workflow (each extracted region contains the select-suites.sh invocation)" \
  "$select_mapping_sentinel_ok"
assert_true "AC-blocks-stay-mutually-identical: the select step's WHOLE mapping (every key, including timeout-minutes:) is byte-identical across every selector-consuming workflow" \
  "$select_mapping_identical"

# -- reconcile mapping: same shape.
RECONCILE_MAPPING_FIRST=""
reconcile_mapping_identical=true
reconcile_mapping_sentinel_ok=true
for wf in "${RECONCILER_CONSUMING_WORKFLOWS[@]}"; do
  mapping="$(extract_step_mapping "$wf" "$RECONCILE_MAPPING_OPENER")"
  printf '%s' "$mapping" | grep -qF 'check-step-reconciliation.sh' || reconcile_mapping_sentinel_ok=false
  if [ -z "$RECONCILE_MAPPING_FIRST" ]; then
    RECONCILE_MAPPING_FIRST="$mapping"
  elif [ "$mapping" != "$RECONCILE_MAPPING_FIRST" ]; then
    reconcile_mapping_identical=false
  fi
done
assert_true "AC-blocks-stay-mutually-identical: the reconcile step mapping extraction is non-vacuous across every reconciler-consuming workflow (each extracted region contains the check-step-reconciliation.sh invocation)" \
  "$reconcile_mapping_sentinel_ok"
assert_true "AC-blocks-stay-mutually-identical: the reconcile step's WHOLE mapping (every key, including the env: block and timeout-minutes:) is byte-identical across every reconciler-consuming workflow" \
  "$reconcile_mapping_identical"

# ---------------------------------------------------------------------------
# AC-infra-steps-are-time-bounded -- the select and reconcile steps in every
# calling workflow declare timeout-minutes:. Keyed on the step's INVOKED
# SCRIPT PATH (via invscan_workflow_steps), not on the step's name, so a
# rename does not blind this arm; carried independently of the identity arm
# above so a five-way OMISSION of the bound (identical everywhere, hence
# invisible to a mutual-identity comparison) still reds.
# ---------------------------------------------------------------------------
for wf in "${SELECTOR_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  select_tmo=""
  # Each of these workflows also carries an UNGOVERNED "selection self-test"
  # standing-lint step (run: bash scripts/test/select-suites.sh --self-test)
  # -- same invoked path, but with neither id: nor if:, unlike the real
  # governed select step (id: select). Only a record carrying one of those
  # two markers is the governed record; the bare self-test record must not
  # overwrite it when it happens to sort later in the file.
  while IFS='|' read -r start runpaths sid ifval tmo; do
    case " $runpaths " in
      *' scripts/test/select-suites.sh '*)
        if [ -n "$sid" ] || [ -n "$ifval" ]; then select_tmo="$tmo"; fi ;;
    esac
  done < <(invscan_workflow_steps "$wf")
  assert_true "AC-infra-steps-are-time-bounded: $wrel -- the GOVERNED step invoking scripts/test/select-suites.sh (id: select) declares timeout-minutes: (an ungoverned 'selection self-test' step invoking the same path, with neither id: nor if:, is excluded)" \
    "[ -n \"$select_tmo\" ]"
done
for wf in "${RECONCILER_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  reconcile_tmo=""
  # Same disambiguation for the reconcile step's own "step-reconciliation
  # self-test" sibling (run: bash scripts/test/check-step-reconciliation.sh
  # --self-test, no id:, no if:) against the real reconcile step (if:
  # always(), no id: of its own -- the if: is what marks it governed here).
  while IFS='|' read -r start runpaths sid ifval tmo; do
    case " $runpaths " in
      *' scripts/test/check-step-reconciliation.sh '*)
        if [ -n "$sid" ] || [ -n "$ifval" ]; then reconcile_tmo="$tmo"; fi ;;
    esac
  done < <(invscan_workflow_steps "$wf")
  assert_true "AC-infra-steps-are-time-bounded: $wrel -- the GOVERNED reconcile step (if: always()) invoking scripts/test/check-step-reconciliation.sh declares timeout-minutes: (an ungoverned 'step-reconciliation self-test' step invoking the same path, with neither id: nor if:, is excluded)" \
    "[ -n \"$reconcile_tmo\" ]"
done

# ---------------------------------------------------------------------------
# AC-job-status-is-wired-into-the-blocks -- every shipped reconcile block
# passes the runner's job status to the reconciler through the step's env:
# mapping (a ${{ … }} expression inline in the body is not bash syntax and
# would abort AC-reconcile-block-text-executes' verbatim replay).
# ---------------------------------------------------------------------------
for wf in "${RECONCILER_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  mapping="$(extract_step_mapping "$wf" "$RECONCILE_MAPPING_OPENER")"
  env_wired_ok=true
  printf '%s' "$mapping" | grep -qE 'JOB_STATUS:[[:space:]]*\$\{\{[[:space:]]*job\.status[[:space:]]*\}\}' || env_wired_ok=false
  assert_true "AC-job-status-is-wired-into-the-blocks: $wrel -- the reconcile step's env: mapping carries JOB_STATUS sourced from the job.status context" \
    "$env_wired_ok"
  body_wired_ok=true
  printf '%s' "$mapping" | grep -qE -- '--job-status[[:space:]]+"\$JOB_STATUS"' || body_wired_ok=false
  assert_true "AC-job-status-is-wired-into-the-blocks: $wrel -- the reconcile step's run: body passes --job-status \"\$JOB_STATUS\" to check-step-reconciliation.sh (the env:-delivered value, not an inline \${{ … }} expression)" \
    "$body_wired_ok"
done

# ---------------------------------------------------------------------------
# AC-reconcile-block-text-executes -- the reconcile step's shipped run: body,
# taken verbatim from each derived consumer, runs the reconciler with the
# arguments it declares and fails the step when the reconciler exits
# non-zero. Same shape as the select block's existing verbatim bash -e
# replay (extract_select_run_block / run_select_replay above): a stub
# check-step-reconciliation.sh records its argv; STEPS_JSON and JOB_STATUS
# are exported as ordinary environment variables, exactly as the step's
# own env: mapping delivers them.
# ---------------------------------------------------------------------------
extract_reconcile_run_block() {
  awk '
    state == 0 && /^[[:space:]]*- name: reconcile selection against step outcomes[[:space:]]*$/ { state = 1; next }
    state == 1 && /run:[[:space:]]*\|/ {
      line = $0
      sub(/[^ ].*$/, "", line)
      runindent = length(line)
      blockindent = runindent + 2
      state = 2
      next
    }
    state == 2 {
      if ($0 == "") { print ""; next }
      line = $0
      sub(/[^ ].*$/, "", line)
      ind = length(line)
      if (ind < blockindent) { exit }
      print substr($0, blockindent + 1)
    }
  ' "$1"
}

# run_reconcile_replay <block-text> <stub-exit-code> -- replays the block
# verbatim under bash -e with a stub check-step-reconciliation.sh at the
# relative path the block invokes; the stub records its own argv and exits
# with the given code. Sets REPLAY_RC and REPLAY_ARGV.
run_reconcile_replay() {
  local block="$1" stub_rc="$2" root rtemp script argvfile
  root="$(mktemp -d)"
  mkdir -p "$root/scripts/test"
  argvfile="$(mktemp)"
  cat > "$root/scripts/test/check-step-reconciliation.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$argvfile"
exit $stub_rc
STUB
  chmod +x "$root/scripts/test/check-step-reconciliation.sh"

  rtemp="$(mktemp -d)"; script="$(mktemp)"
  printf '%s\n' "$block" > "$script"
  ( cd "$root" && STEPS_JSON='{"s-fixture":{"outcome":"success"}}' JOB_STATUS='failure' RUNNER_TEMP="$rtemp" bash -e "$script" ) \
    >/tmp/issue108-reconcile-replay-stdout.out 2>/tmp/issue108-reconcile-replay-stderr.out
  REPLAY_RC=$?
  REPLAY_ARGV="$(cat "$argvfile" 2>/dev/null)"
  rm -rf "$root" "$rtemp" "$script" "$argvfile"
}

for wf in "${RECONCILER_CONSUMING_WORKFLOWS[@]}"; do
  wrel="${wf#"$PROJECT_ROOT"/}"
  RECONCILE_BLOCK_TEXT="$(extract_reconcile_run_block "$wf")"

  reconcile_sentinel_ok=true
  printf '%s' "$RECONCILE_BLOCK_TEXT" | grep -qF 'check-step-reconciliation.sh' || reconcile_sentinel_ok=false
  assert_true "AC-reconcile-block-text-executes sentinel: $wrel -- the extracted reconcile run: block invokes check-step-reconciliation.sh" \
    "$reconcile_sentinel_ok"

  run_reconcile_replay "$RECONCILE_BLOCK_TEXT" 0
  pos_replay_rc_ok=true; [ "$REPLAY_RC" -eq 0 ] || pos_replay_rc_ok=false
  assert_true "AC-reconcile-block-text-executes positive control: $wrel -- replaying the shipped reconcile-step text verbatim under bash -e, with a stub reconciler exiting 0, exits the step 0" \
    "$pos_replay_rc_ok"
  argv_has_selected=true; printf '%s\n' "$REPLAY_ARGV" | grep -qF -- '--selected' || argv_has_selected=false
  argv_has_steps=true; printf '%s\n' "$REPLAY_ARGV" | grep -qF -- '--steps' || argv_has_steps=false
  argv_has_jobstatus=true
  jobstatus_ctx="$(printf '%s\n' "$REPLAY_ARGV" | grep -A1 -- '--job-status')"
  jobstatus_val="$(printf '%s\n' "$jobstatus_ctx" | tail -1)"
  [ -n "$jobstatus_val" ] || argv_has_jobstatus=false
  assert_true "AC-reconcile-block-text-executes: $wrel -- the stub received --selected with a non-empty value" "$argv_has_selected"
  assert_true "AC-reconcile-block-text-executes: $wrel -- the stub received --steps with a non-empty value" "$argv_has_steps"
  assert_true "AC-reconcile-block-text-executes: $wrel -- the stub received --job-status (the env:-delivered JOB_STATUS, not an inline expression that would abort the bash -e replay before invocation)" \
    "$argv_has_jobstatus"

  run_reconcile_replay "$RECONCILE_BLOCK_TEXT" 1
  neg_replay_rc_ok=true; [ "$REPLAY_RC" -ne 0 ] || neg_replay_rc_ok=false
  assert_true "AC-reconcile-block-text-executes negative control: $wrel -- a stub reconciler exiting non-zero propagates out of the shipped reconcile-step body (bash -e fails the step)" \
    "$neg_replay_rc_ok"
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
