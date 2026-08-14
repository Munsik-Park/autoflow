#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh plugin/autoflow/hooks/check-autoflow-gate.sh scripts/cleanup/cleanup-issue.sh setup/manifest.json scripts/issue/create-issue.sh docs/issue-proposal.md
# =============================================================================
# Test: the hook-side and cross-mechanism half of the AI-initiated
#       issue-creation gate — STANDING (issue #96 origin; see
#       .autoflow/issue-96-verification-design.md and
#       docs/doc-invariant-registry.md §10)
# =============================================================================
# Covers, per the verification design's acceptance-criteria table:
#   Hook-Denies-Bare-Create, Hook-Denies-REST-Form, Hook-Deny-Is-State-Independent,
#   Hook-Boundary-Fidelity, Hook-Deny-Coexistence, Wrapper-Not-Self-Blocked,
#   Namespace-Coexistence (composition oracle), scan-path-composition (composition
#   oracle), Bundle-Registration (rides in this file per verification design >
#   Verification depth > "rows riding inside an existing layer").
#
# Split rationale (verification design > New spec files): this file drives the
# hook and cleanup-issue.sh over an UNMODIFIED PATH so no `gh` shim can mask a
# hook decision; the wrapper-behavior cases live in the shimmed sibling file
# tests/test-issue-create-wrapper.sh.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
CLEANUP="$PROJECT_ROOT/scripts/cleanup/cleanup-issue.sh"

PASS=0
FAIL=0

# run_hook <expected_exit> <desc> <project_dir> <json> — idiom shared with
# tests/test-gate-hardening.sh.
run_hook() {
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_true() {
  local desc="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }

CLEANUP_TMP_DIRS=()
cleanup_all() {
  for d in "${CLEANUP_TMP_DIRS[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup_all EXIT

mktempd() {
  local d
  d=$(mktemp -d)
  CLEANUP_TMP_DIRS+=("$d")
  printf '%s' "$d"
}

# --- Fixtures ---------------------------------------------------------------
NOSTATE=$(mktempd)   # no .autoflow at all

ACTIVE=$(mktempd)    # active issue, empty scores
mkdir -p "$ACTIVE/.autoflow"
cat > "$ACTIVE/.autoflow/issue-9.json" <<'EOF'
{ "active": true, "issue": "#9",
  "phases": { "audit": {"scores":{}}, "gate_quality": {"scores":{}} } }
EOF

INACTIVE=$(mktempd)  # state present but active:false
mkdir -p "$INACTIVE/.autoflow"
cat > "$INACTIVE/.autoflow/issue-9.json" <<'EOF'
{ "active": false, "issue": "#9", "phases": {} }
EOF

echo "=== issue #96 — Hook-Denies-Bare-Create ==="
run_hook 2 "Hook-Denies-Bare-Create: bare 'gh issue create' is denied" \
  "$NOSTATE" "$(bash_json 'gh issue create --title "x" --body "y"')"

echo ""
echo "=== issue #96 — Hook-Denies-REST-Form (segment co-occurrence) ==="
run_hook 2 "Hook-Denies-REST-Form: POST to the issues endpoint in one segment is denied" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues --method POST -f title=x')"
run_hook 0 "Hook-Denies-REST-Form: the two patterns split across DIFFERENT segments are not denied" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues --method GET ; gh api repos/o/r/other --method POST')"

echo ""
echo "=== issue #96 — Hook-Deny-Is-State-Independent ==="
run_hook 2 "state-independent: no .autoflow directory" \
  "$NOSTATE" "$(bash_json 'gh issue create --title "x" --body "y"')"
run_hook 2 "state-independent: active:false state file" \
  "$INACTIVE" "$(bash_json 'gh issue create --title "x" --body "y"')"
run_hook 2 "state-independent: active:true state file" \
  "$ACTIVE" "$(bash_json 'gh issue create --title "x" --body "y"')"

echo ""
echo "=== issue #96 — Hook-Boundary-Fidelity ==="
run_hook 2 "boundary: chained form (cmd && gh issue create)" \
  "$NOSTATE" "$(bash_json 'git status && gh issue create --title "x" --body "y"')"
run_hook 2 "boundary: backslash-continued form" \
  "$NOSTATE" "$(bash_json $'gh issue \\\ncreate --title "x" --body "y"')"
run_hook 0 "boundary: a quoted body that merely NAMES the token is not denied" \
  "$NOSTATE" "$(bash_json 'git commit -m "gh issue create is now denied"')"
run_hook 0 "boundary: a heredoc body that merely names the token is not denied" \
  "$NOSTATE" "$(bash_json $'cat <<EOF\ngh issue create --title x\nEOF')"
run_hook 0 "boundary: the read-only 'gh issue list' subcommand is not denied" \
  "$NOSTATE" "$(bash_json 'gh issue list --search foo --state all')"
run_hook 0 "boundary: the 'gh issue edit' subcommand is not denied" \
  "$NOSTATE" "$(bash_json 'gh issue edit 5 --add-label triage')"

echo ""
echo "=== issue #96 — Hook-Deny-Coexistence ==="
if bash "$SCRIPT_DIR/test-gate-hardening.sh" >/dev/null 2>&1; then
  echo "  PASS: existing tests/test-gate-hardening.sh suite is unaffected by the new deny"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tests/test-gate-hardening.sh regressed after the new deny was added"
  FAIL=$((FAIL + 1))
fi
run_hook 0 "coexistence: an unrelated label edit (status:in-progress) is still allowed" \
  "$NOSTATE" "$(bash_json 'gh issue edit 1 --remove-label status:in-progress')"
run_hook 2 "coexistence: gate-label removal deny still fires standing alone" \
  "$NOSTATE" "$(bash_json 'gh pr edit 1 --remove-label blocked-by-review')"

echo ""
echo "=== issue #96 — Wrapper-Not-Self-Blocked ==="
run_hook 0 "the wrapper's own invocation string is not denied by layer 1 and is not score-gated" \
  "$ACTIVE" "$(bash_json 'scripts/issue/create-issue.sh --draft .autoflow/issue-proposal-example-slug.md')"

echo ""
echo "=== issue #96 — scan-path-composition (composition oracle: T ∩ S = hook Bash-command scan path) ==="
run_hook 2 "scan-path: new deny in one segment + existing default-branch push deny in another segment — both still decide their own segment" \
  "$NOSTATE" "$(bash_json 'gh issue create --title "x" --body "y" ; git push origin main')"
run_hook 0 "scan-path: adjacent segments carrying near-miss tokens for BOTH denies are not cross-contaminated (list, not create; feature branch, not default)" \
  "$NOSTATE" "$(bash_json 'gh issue list --search create ; git push origin feature-branch')"

echo ""
echo "=== issue #96 — Namespace-Coexistence (composition oracle: T ∩ S = .autoflow/ filename namespace) ==="
NS=$(mktempd)
git -C "$NS" init -q
mkdir -p "$NS/.autoflow"
# Real, passing state file for issue 96 (so the hook's downstream score gate
# does not itself explain any denial we observe below).
cat > "$NS/.autoflow/issue-96.json" <<'EOF'
{ "active": true, "issue": "#96",
  "phases": {
    "gate_hypothesis_cause": {"verdict":"skipped (feat issue)"},
    "gate_plan":    {"scores":{"a":{"score":8},"b":{"score":8}}},
    "audit":        {"scores":{"a":{"score":8},"b":{"score":8}}},
    "gate_quality": {"scores":{"a":{"score":8},"b":{"score":8}}} } }
EOF
echo "## E1 | cycle 1" > "$NS/.autoflow/issue-96-ledger.md"
# Both lifecycle names of the proposal artifact, co-resident (verification
# design > Composition oracle > namespace-coexistence).
printf '## Title\npre-create draft\n' > "$NS/.autoflow/issue-proposal-example-slug.md"
printf '## Title\npost-create record\n' > "$NS/.autoflow/issue-96-proposal.md"
# A co-resident issue's own files, unaffected by cleanup(96). Recorded
# active:false — a second active:true state file here would trip the hook's
# own multi-active fail-closed branch, which is a different property than the
# one this oracle traces (the .autoflow/ filename namespace).
cat > "$NS/.autoflow/issue-97.json" <<'EOF'
{ "active": false, "issue": "#97", "phases": {} }
EOF
echo "## E1 | cycle 1" > "$NS/.autoflow/issue-97-ledger.md"

run_hook 0 "namespace: neither proposal .md name is admitted as a state file — a real gh pr create is decided by issue-96.json's own PASS scores" \
  "$NS" "$(bash_json 'gh pr create --title x --body-file y')"

# scripts/cleanup/cleanup-issue.sh refuses an archive root INSIDE the repo tree
# (ledger E14 implementation note 3) — redirect outside the temp repo. The
# script derives ROOT from `git rev-parse --show-toplevel` against $PWD, so it
# must be invoked WITH cwd set to the fixture tree, not merely pointed at it.
ARCHIVE_ROOT=$(mktempd)
if ( cd "$NS" && AUTOFLOW_ARCHIVE_ROOT="$ARCHIVE_ROOT" bash "$CLEANUP" 96 ) >/tmp/issue-96-cleanup-out.$$  2> /tmp/issue-96-cleanup-err.$$; then
  echo "  PASS: cleanup-issue.sh 96 exits 0 over the co-resident tree"
  PASS=$((PASS + 1))
else
  echo "  FAIL: cleanup-issue.sh 96 exited non-zero: $(cat /tmp/issue-96-cleanup-err.$$)"
  FAIL=$((FAIL + 1))
fi
rm -f /tmp/issue-96-cleanup-out.$$ /tmp/issue-96-cleanup-err.$$

ARCHIVED_DIR=$(find "$ARCHIVE_ROOT" -mindepth 2 -maxdepth 2 -type d -name 'issue-96-*' 2>/dev/null | head -1)
assert_true "namespace: post-create name issue-96-proposal.md is swept into the cycle's archive" \
  "[ -n \"$ARCHIVED_DIR\" ] && [ -f \"$ARCHIVED_DIR/issue-96-proposal.md\" ]"
assert_true "namespace: archived post-create content is byte-identical to the source" \
  "[ -n \"$ARCHIVED_DIR\" ] && diff -q \"$ARCHIVED_DIR/issue-96-proposal.md\" <(printf '## Title\npost-create record\n') >/dev/null 2>&1"
assert_true "namespace: pre-create draft name (issue-proposal-example-slug.md) is NOT swept — deliberate non-sweep" \
  "[ -f '$NS/.autoflow/issue-proposal-example-slug.md' ]"
assert_true "namespace: the co-resident issue #97 state file is untouched" \
  "[ -f '$NS/.autoflow/issue-97.json' ]"
assert_true "namespace: the co-resident issue #97 ledger is untouched" \
  "[ -f '$NS/.autoflow/issue-97-ledger.md' ]"

echo ""
echo "=== issue #96 — Bundle-Registration (rides in this file per verification design) ==="
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
assert_true "bundle: scripts/issue/create-issue.sh is a root-layer copy row in setup/manifest.json" \
  "jq -e '.artifacts[] | select(.source==\"scripts/issue/create-issue.sh\" and .tier==\"root-layer\" and .kind==\"copy\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "bundle: docs/issue-proposal.md is inside the bundle's doc closure (an artifacts[] row)" \
  "jq -e '.artifacts[] | select(.source==\"docs/issue-proposal.md\")' '$MANIFEST' >/dev/null 2>&1"

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
