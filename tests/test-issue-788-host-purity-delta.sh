#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
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

  # #985 AC3-SPDX-COVERAGE: every tracked .yml gains a 2-line inline SPDX
  # header. This admits an SPDX-header-only diff on the two CI runner YAMLs
  # (added lines matching only the SPDX header patterns, no deletions and no
  # other additions) — mirroring AC10a's #843 parity-carry exception. Any
  # other change to these files stays caught.
  wf_diff="$(git -C "$PROJECT_ROOT" diff "$base_ref"..HEAD -- \
    .github/workflows/workflow-regression.yml .github/workflows/schema-hook-contract.yml 2>/dev/null)"
  wf_untouched="no"; [[ -z "$wf_diff" ]] && wf_untouched="yes"
  wf_change_admitted="no"
  if [[ "$wf_untouched" == "yes" ]]; then
    wf_change_admitted="yes"
  else
    wf_deleted_lines="$(printf '%s\n' "$wf_diff" | grep -c '^-[^-]')"
    wf_added_other="$(printf '%s\n' "$wf_diff" | grep '^+[^+]' \
      | grep -vE '^\+# SPDX-FileCopyrightText:|^\+# SPDX-License-Identifier:' \
      | wc -l | tr -d ' ')"
    if [[ "$wf_deleted_lines" -eq 0 && "$wf_added_other" -eq 0 ]]; then
      wf_change_admitted="yes"
    fi
  fi
  assert_eq "AC10b: existing CI runner YAMLs untouched vs origin/main, OR changed with an SPDX-header-only diff (#985 AC3-SPDX-COVERAGE inline header)" \
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
