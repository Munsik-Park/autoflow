#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: reviewer --probe surface — Issue #979 (cycle 9, review-response)
# =============================================================================
# Scope (.autoflow/issue-979-verification-design.md cycle 9, C9-AC-1..9;
# feature design .autoflow/issue-979-feature-design.md §3): a new on-demand
# `scripts/preflight/check-review-backend.sh --probe` mode that makes ONE
# real authenticated round-trip to the *configured* backend (R1), triggered
# at install-time (SKILL.md 4c->4d) and backend-change-time
# (set-review-backend.sh reminder) only (R2), leaving the non-`--probe`
# PREFLIGHT path byte-identical/presence-only (R3), and NOT changing HANDOFF
# step-6 runtime-failure surfacing (R4).
#
# Kept SEPARATE from tests/test-issue-979-preflight-backend-check.sh (the
# presence-only suite stays intact per feature §3.7 / verification design
# "final RED placement is the Test AI's call") and from
# tests/test-issue-979-review-backend.sh (the HANDOFF step-6 claude-branch
# suite, re-run here as a behavior-preservation regression guard for the
# §3.2 claude-isolation extraction, C9-AC-6/DCR-6).
#
# No live claude/codex CLI is ever invoked ([MUST]) — every backend call is a
# PATH stub. All new assertion pipes use the #964 sigpipe-safe idiom
# (`… | grep -F … >/dev/null` or command-sub + `[ -n … ]`, never
# `grep -[ABC] … | grep -q`) per DCR-0.
#
# RED expectation (pre-implementation, this commit): C9-AC-1/-2/-3/-7 FAIL —
# `--probe` does not exist at HEAD, so it hits the `*) unknown argument`
# branch and exits 2; no probe subprocess is ever dispatched, so the auth
# stub farm is never invoked and its capture files stay empty. C9-AC-4/-8
# FAIL — SKILL.md / docs/reviewer-backend.md / the script header do not yet
# mention `--probe`. C9-AC-5/-6 PASS at HEAD (regression pins over
# already-shipped, untouched behavior) and MUST stay green after GREEN.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_SCRIPT="$PROJECT_ROOT/scripts/preflight/check-review-backend.sh"
REVIEWER_BACKEND_MD="$PROJECT_ROOT/docs/reviewer-backend.md"
INSTALL_SKILL_MD="$PROJECT_ROOT/plugin/autoflow/skills/install/SKILL.md"
SETUP_GUIDE_MD="$PROJECT_ROOT/setup/SETUP-GUIDE.md"
CODEX_REVIEW_SH="$PROJECT_ROOT/scripts/review/codex-review-pr.sh"
CLAUDE_ISOLATION_LIB="$PROJECT_ROOT/scripts/review/lib/claude-isolation.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  fi
}

# Bounded execution helper (reuses tests/test-issue-979-preflight-backend-check.sh's
# C3-AC-3 watchdog idiom): prefer timeout/gtimeout; else a sleep+kill fallback.
# Sets RB_EXIT (the command's exit code, or the SIGTERM/GNU-timeout code on a
# kill) and RB_KILLED (1 iff the watchdog actually fired).
run_bounded() {
  local bound="$1" logfile="$2"; shift 2
  RB_KILLED=0
  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi
  if [ -n "$timeout_bin" ]; then
    ( "$timeout_bin" "$bound" "$@" ) >"$logfile" 2>&1
    RB_EXIT=$?
    [ "$RB_EXIT" -eq 124 ] && RB_KILLED=1
  else
    ( "$@" ) >"$logfile" 2>&1 &
    local pid=$!
    ( sleep "$bound"; if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo killed > "$logfile.watchdog"; fi ) &
    local watchdog_pid=$!
    wait "$pid" 2>/dev/null
    RB_EXIT=$?
    if [ -s "$logfile.watchdog" ]; then
      RB_KILLED=1
    else
      kill "$watchdog_pid" 2>/dev/null
    fi
    wait "$watchdog_pid" 2>/dev/null
    rm -f "$logfile.watchdog" 2>/dev/null
  fi
}

echo "=============================================="
echo "reviewer --probe surface (cycle 9, C9-AC-1..9)"
echo "=============================================="

SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# ---------------------------------------------------------------------------
# Auth-state stub farm (net-new fixture — verification design §T1/DCR-2b):
# claude/codex PATH stubs branch on FAKE_BACKEND_AUTH=ok|fail|hang and log
# their own argv/cwd/env to per-backend capture files, so the same fixture
# proves BOTH dispatch-correctness (C9-AC-2) and isolation-fidelity (C9-AC-7)
# as well as exercising the exit-code contract (C9-AC-3).
# ---------------------------------------------------------------------------
FAKEBIN_AUTH="$(mktemp -d)"
CAPTURE_CLAUDE="$(mktemp)"
CAPTURE_CODEX="$(mktemp)"

cat > "$FAKEBIN_AUTH/claude" <<EOF
#!/usr/bin/env bash
{
  echo "ARGV:\$*"
  echo "ARGV_ARGS_BEGIN"
  printf '%s\n' "\$@"
  echo "ARGV_ARGS_END"
  echo "CWD:\$(pwd)"
  if [ -n "\${ANTHROPIC_API_KEY:-}" ]; then
    echo "ANTHROPIC_API_KEY_VISIBLE:yes"
  else
    echo "ANTHROPIC_API_KEY_VISIBLE:no"
  fi
  echo "ENV_DUMP_BEGIN"
  env
  echo "ENV_DUMP_END"
} >> "$CAPTURE_CLAUDE"
case "\${FAKE_BACKEND_AUTH:-ok}" in
  ok)   echo '{"result":"READY"}'; exit 0 ;;
  fail) echo "authentication rejected" >&2; exit 1 ;;
  hang) sleep 30 ;;
esac
EOF
chmod +x "$FAKEBIN_AUTH/claude"

cat > "$FAKEBIN_AUTH/codex" <<EOF
#!/usr/bin/env bash
{
  echo "ARGV:\$*"
  echo "ARGV_ARGS_BEGIN"
  printf '%s\n' "\$@"
  echo "ARGV_ARGS_END"
} >> "$CAPTURE_CODEX"
case "\${FAKE_BACKEND_AUTH:-ok}" in
  ok)   echo 'READY'; exit 0 ;;
  fail) echo "authentication rejected" >&2; exit 1 ;;
  hang) sleep 30 ;;
esac
EOF
chmod +x "$FAKEBIN_AUTH/codex"

FAKEBIN_ABSENT="$(mktemp -d)"
# stays empty (no claude/codex stub) — genuinely-absent CLI arm.

if [ -x "$CHECK_SCRIPT" ]; then

  echo ""
  echo "=== C9-AC-1 (--probe is a recognized mode, R1) ==="
  : > "$CAPTURE_CLAUDE"
  PROBE1_LOG="$(mktemp)"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok "$CHECK_SCRIPT" --backend claude --probe ) >"$PROBE1_LOG" 2>&1
  PROBE1_EXIT=$?
  assert_true "C9-AC-1: --probe does not fall through to the unknown-argument branch (stderr carries no 'unknown argument')" \
    "! grep -qi 'unknown argument' '$PROBE1_LOG'"
  assert_true "C9-AC-1: --probe (authed stub) exits 0 — a distinct, recognized probe path ran" \
    "[ '$PROBE1_EXIT' -eq 0 ]"
  rm -f "$PROBE1_LOG" 2>/dev/null

  echo ""
  echo "=== C9-AC-2 (probe dispatches the CONFIGURED backend's CLI, DCR-2b PATH-resolved) ==="
  : > "$CAPTURE_CLAUDE"; : > "$CAPTURE_CODEX"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok "$CHECK_SCRIPT" --backend claude --probe ) >/dev/null 2>&1
  assert_true "C9-AC-2 (claude configured): the claude stub was invoked (capture non-empty)" \
    "[ -s '$CAPTURE_CLAUDE' ]"
  assert_true "C9-AC-2 (claude configured): the codex stub was NOT invoked" \
    "[ ! -s '$CAPTURE_CODEX' ]"
  if [ -s "$CAPTURE_CLAUDE" ]; then
    CAP_ARGV="$(grep '^ARGV:' "$CAPTURE_CLAUDE" | sed 's/^ARGV://')"
    assert_true "C9-AC-2 (real-call shape, not presence-check): captured claude invocation carries -p (not a bare command -v probe)" \
      "printf '%s' \"\$CAP_ARGV\" | grep -qE -- '(^| )-p( |$)'"
  else
    assert_true "C9-AC-2 (real-call shape): claude never invoked pre-impl" "false"
  fi

  : > "$CAPTURE_CLAUDE"; : > "$CAPTURE_CODEX"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok "$CHECK_SCRIPT" --backend codex --probe ) >/dev/null 2>&1
  assert_true "C9-AC-2 (codex configured): the codex stub was invoked (capture non-empty)" \
    "[ -s '$CAPTURE_CODEX' ]"
  assert_true "C9-AC-2 (codex configured): the claude stub was NOT invoked" \
    "[ ! -s '$CAPTURE_CLAUDE' ]"

  echo ""
  echo "=== C9-AC-3 (machine-verifiable exit-code contract, DCR-2/DCR-5) ==="

  # Arm: auth-ok -> exit 0
  : > "$CAPTURE_CLAUDE"
  PROBE_OK_LOG="$(mktemp)"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok "$CHECK_SCRIPT" --backend claude --probe ) >"$PROBE_OK_LOG" 2>&1
  assert_true "C9-AC-3 (ok): auth-ok stub -> exit 0" "[ $? -eq 0 ]"
  rm -f "$PROBE_OK_LOG" 2>/dev/null

  # Arm: auth-fail, CLI PRESENT but round-trip rejected -> exit 4 (DCR-2:
  # distinct from 1=absent).
  PROBE_FAIL_LOG="$(mktemp)"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=fail "$CHECK_SCRIPT" --backend claude --probe ) >"$PROBE_FAIL_LOG" 2>&1
  PROBE_FAIL_EXIT=$?
  assert_true "C9-AC-3 (auth-fail, DCR-2): CLI present, round-trip rejected -> exit 4 (distinct from 1=absent)" \
    "[ '$PROBE_FAIL_EXIT' -eq 4 ]"
  rm -f "$PROBE_FAIL_LOG" 2>/dev/null

  # Arm: hang -> exit 3 (indeterminate), bounded by PROBE_TIMEOUT_SECS=2 so
  # the arm is fast/deterministic regardless of the GNU-timeout vs fallback
  # watchdog path (DCR-5).
  PROBE_HANG_LOG="$(mktemp)"
  run_bounded 10 "$PROBE_HANG_LOG" env PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=hang PROBE_TIMEOUT_SECS=2 "$CHECK_SCRIPT" --backend claude --probe
  assert_true "C9-AC-3 (hang, DCR-5): the harness watchdog never had to fire (the probe's own PROBE_TIMEOUT_SECS=2 bound fired first)" \
    "[ '$RB_KILLED' -eq 0 ]"
  assert_true "C9-AC-3 (hang, DCR-5): a hanging round-trip bounded by PROBE_TIMEOUT_SECS=2 -> exit 3 (indeterminate), not a multi-second harness kill" \
    "[ '$RB_KILLED' -eq 0 ] && [ \"\$RB_EXIT\" -eq 3 ]"
  rm -f "$PROBE_HANG_LOG" 2>/dev/null

  # Arm: absent CLI -> exit 1 (short-circuit, no round-trip attempted —
  # distinct from auth-fail's exit 4).
  PROBE_ABSENT_LOG="$(mktemp)"
  ( PATH="$FAKEBIN_ABSENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend claude --probe ) >"$PROBE_ABSENT_LOG" 2>&1
  PROBE_ABSENT_EXIT=$?
  assert_true "C9-AC-3 (absent CLI): --probe on an absent CLI reuses the existing presence exit 1 (short-circuit, no round-trip)" \
    "[ '$PROBE_ABSENT_EXIT' -eq 1 ]"
  rm -f "$PROBE_ABSENT_LOG" 2>/dev/null

  # Arm: --probe + bad --backend -> exit 2 (existing usage-config semantics).
  PROBE_BADBACKEND_LOG="$(mktemp)"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend gemini --probe ) >"$PROBE_BADBACKEND_LOG" 2>&1
  PROBE_BADBACKEND_EXIT=$?
  assert_true "C9-AC-3 (bad --backend): --probe + an unrecognized backend value -> exit 2" \
    "[ '$PROBE_BADBACKEND_EXIT' -eq 2 ]"
  rm -f "$PROBE_BADBACKEND_LOG" 2>/dev/null

  echo ""
  echo "=== C9-AC-5 (R3 non-leak — the non-'--probe' PREFLIGHT path stays presence-only) ==="

  # Load-bearing regression guard: a present-but-"unauthenticated" backend
  # (FAKE_BACKEND_AUTH=fail) run WITHOUT --probe must still exit 0 — the
  # default path must NEVER auth-probe.
  : > "$CAPTURE_CLAUDE"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=fail "$CHECK_SCRIPT" --backend claude ) >/dev/null 2>&1
  NO_PROBE_UNAUTH_EXIT=$?
  assert_true "C9-AC-5 (R3 load-bearing guard): no '--probe' + present-but-unauthenticated stub -> still exit 0 (presence-only; the probe must NOT leak into the default path)" \
    "[ '$NO_PROBE_UNAUTH_EXIT' -eq 0 ]"
  assert_true "C9-AC-5 (R3 load-bearing guard): the default (no --probe) path never invoked the claude stub's round-trip body (capture empty — presence-only never execs the CLI)" \
    "[ ! -s '$CAPTURE_CLAUDE' ]"

  echo ""
  echo "=== C9-AC-5 (regression pin) — the full existing presence-only suite stays green ==="
  PREFLIGHT_SUITE="$PROJECT_ROOT/tests/test-issue-979-preflight-backend-check.sh"
  PREFLIGHT_SUITE_LOG="$(mktemp)"
  bash "$PREFLIGHT_SUITE" >"$PREFLIGHT_SUITE_LOG" 2>&1
  PREFLIGHT_SUITE_EXIT=$?
  assert_true "C9-AC-5 (regression pin): tests/test-issue-979-preflight-backend-check.sh (presence-only baseline) is unaffected and stays green" \
    "[ '$PREFLIGHT_SUITE_EXIT' -eq 0 ]"
  rm -f "$PREFLIGHT_SUITE_LOG" 2>/dev/null

  echo ""
  echo "=== C9-AC-7 (claude probe reuses the isolation triple + OAuth carve-out, DCR-4) ==="
  : > "$CAPTURE_CLAUDE"
  ( PATH="$FAKEBIN_AUTH:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok \
      ANTHROPIC_API_KEY=sk-test-fixture \
      CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=parent-test \
      CLAUDE_CODE_CHILD_SESSION=1 CLAUDE_SOMETHING_FUTURE=x \
      CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel-979-probe \
      "$CHECK_SCRIPT" --backend claude --probe ) >/dev/null 2>&1
  PROBE_ISO_EXIT=$?
  assert_true "C9-AC-7 (dispatch, precondition): the claude probe call was made (capture non-empty)" \
    "[ -s '$CAPTURE_CLAUDE' ]"
  if [ -s "$CAPTURE_CLAUDE" ]; then
    CAP_ARGS_LIST="$(sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' "$CAPTURE_CLAUDE")"
    CAP_ENV_DUMP="$(sed -n '/^ENV_DUMP_BEGIN$/,/^ENV_DUMP_END$/p' "$CAPTURE_CLAUDE")"
    CAP_KEY_VISIBLE="$(grep '^ANTHROPIC_API_KEY_VISIBLE:' "$CAPTURE_CLAUDE" | sed 's/^ANTHROPIC_API_KEY_VISIBLE://')"
    CAP_CWD="$(grep '^CWD:' "$CAPTURE_CLAUDE" | sed 's/^CWD://' | tail -1)"

    assert_true "C9-AC-7 (neutral cwd): the probe's claude subprocess cwd is NOT the project toplevel" \
      "[ \"\$CAP_CWD\" != \"$PROJECT_ROOT\" ]"
    assert_true "C9-AC-7 (--setting-sources \"\"): captured probe invocation carries an empty --setting-sources value" \
      "printf '%s\\n' \"\$CAP_ARGS_LIST\" | grep -A1 -F -x -- '--setting-sources' | tail -1 | grep -E '^\$' >/dev/null"
    assert_true "C9-AC-7 (API-key guard): the probe's claude subprocess does NOT observe ANTHROPIC_API_KEY even though the caller exported it" \
      "[ \"\$CAP_KEY_VISIBLE\" = 'no' ]"
    assert_false "C9-AC-7 (CLAUDE* scrub, DCR-4): no CLAUDE-prefixed var OTHER THAN CLAUDE_CODE_OAUTH_TOKEN reaches the probe's claude subprocess env" \
      "[ -n \"\$(printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -E '^CLAUDE[A-Z_]*=' | grep -vE '^CLAUDE_CODE_OAUTH_TOKEN=')\" ]"
    assert_true "C9-AC-7 (OAuth-token retention, DCR-4): CLAUDE_CODE_OAUTH_TOKEN survives the scrub and reaches the probe's claude subprocess env unchanged" \
      "[ -n \"\$(printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -xF 'CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel-979-probe')\" ]"
    assert_true "C9-AC-7 (headless-result contract): captured probe invocation carries --output-format json" \
      "printf '%s' \"\$(grep '^ARGV:' '$CAPTURE_CLAUDE' | sed 's/^ARGV://')\" | grep -qE -- '--output-format[= ]json'"
  else
    for d in "neutral cwd" "--setting-sources" "API-key guard" "CLAUDE* scrub" "OAuth retention" "headless-result contract"; do
      assert_true "C9-AC-7 ($d): claude probe never invoked pre-impl" "false"
    done
  fi

  echo ""
  echo "=== C9-AC-7 (extraction-structural arm, §3.2 primary = extract, settled DCR-6) ==="
  assert_true "C9-AC-7 (single source of truth): scripts/review/lib/claude-isolation.sh exists (the shared helper closing the Round-7 drift class)" \
    "[ -f '$CLAUDE_ISOLATION_LIB' ]"
  assert_true "C9-AC-7 (single source of truth): scripts/review/codex-review-pr.sh sources the shared claude-isolation helper" \
    "[ -f '$CODEX_REVIEW_SH' ] && grep -qF 'claude-isolation.sh' '$CODEX_REVIEW_SH'"
  assert_true "C9-AC-7 (single source of truth): scripts/preflight/check-review-backend.sh (the probe) sources the shared claude-isolation helper" \
    "grep -qF 'claude-isolation.sh' '$CHECK_SCRIPT'"

else
  for d in \
    "C9-AC-1 (recognized mode)" "C9-AC-2 (dispatch correctness)" \
    "C9-AC-3 (exit-code contract)" "C9-AC-5 (R3 non-leak)" \
    "C9-AC-7 (isolation reuse)" "C9-AC-7 (extraction structural)"
  do
    assert_true "$d: scripts/preflight/check-review-backend.sh does not exist" "false"
  done
fi

rm -rf "$FAKEBIN_AUTH" "$FAKEBIN_ABSENT" 2>/dev/null
rm -f "$CAPTURE_CLAUDE" "$CAPTURE_CODEX" 2>/dev/null

echo ""
echo "=== C9-AC-6 (HANDOFF step-6 runtime surfacing unchanged — behavior-preservation, DCR-6) ==="

REVIEW_BACKEND_SUITE="$PROJECT_ROOT/tests/test-issue-979-review-backend.sh"
REVIEW_BACKEND_SUITE_LOG="$(mktemp)"
bash "$REVIEW_BACKEND_SUITE" >"$REVIEW_BACKEND_SUITE_LOG" 2>&1
REVIEW_BACKEND_SUITE_EXIT=$?
assert_true "C9-AC-6 (behavior-preservation regression guard): tests/test-issue-979-review-backend.sh (asserts the claude branch's observed isolation env/argv, not merely run/exit) stays green after the §3.2 extract" \
  "[ '$REVIEW_BACKEND_SUITE_EXIT' -eq 0 ]"
rm -f "$REVIEW_BACKEND_SUITE_LOG" 2>/dev/null

assert_true "C9-AC-6 (doc-invariant): docs/reviewer-backend.md's start-confirmation / step-6 section still states auth failure surfaces at HANDOFF step 6" \
  "[ -f '$REVIEWER_BACKEND_MD' ] && grep -qi 'step 6' '$REVIEWER_BACKEND_MD' && grep -qi 'surfaces' '$REVIEWER_BACKEND_MD'"

echo ""
echo "=== C9-AC-4 (on-demand trigger wiring — install-time, structural) ==="

STEP4_BLOCK="$([ -f "$INSTALL_SKILL_MD" ] && awk '/^## Step 4/{flag=1} /^## Step [5-9]/{flag=0} flag' "$INSTALL_SKILL_MD" || true)"
export STEP4_BLOCK
assert_true "C9-AC-4: SKILL.md Step 4 block names a --probe step referencing check-review-backend.sh" \
  "printf '%s' \"\$STEP4_BLOCK\" | grep -qF -- '--probe' && printf '%s' \"\$STEP4_BLOCK\" | grep -qF 'check-review-backend.sh'"

# Ordering: the probe step sits at/after 4c (persist, marker
# REVIEWER-BACKEND-PERSIST) and before 4d (drift-check invocation) — assert
# via line-number comparison inside the Step 4 block, not a bare substring
# match (avoids a false PASS if --probe is mentioned elsewhere, e.g. only in
# a stale comment after 4d).
PERSIST_LINE="$(printf '%s\n' "$STEP4_BLOCK" | grep -nF 'REVIEWER-BACKEND-PERSIST' | head -1 | cut -d: -f1)"
DRIFTCHECK_LINE="$(printf '%s\n' "$STEP4_BLOCK" | grep -nF 'drift-check.sh' | head -1 | cut -d: -f1)"
PROBE_LINE="$(printf '%s\n' "$STEP4_BLOCK" | grep -nF -- '--probe' | head -1 | cut -d: -f1)"
assert_true "C9-AC-4 (ordering): the --probe step is positioned at/after 4c (REVIEWER-BACKEND-PERSIST) and before 4d (drift-check.sh)" \
  "[ -n \"\$PERSIST_LINE\" ] && [ -n \"\$DRIFTCHECK_LINE\" ] && [ -n \"\$PROBE_LINE\" ] && [ \"\$PROBE_LINE\" -ge \"\$PERSIST_LINE\" ] && [ \"\$PROBE_LINE\" -lt \"\$DRIFTCHECK_LINE\" ]"

assert_true "C9-AC-4 (advisory, R3): SKILL.md's --probe step is advisory — it narrates the outcome but does not abort the install" \
  "printf '%s' \"\$STEP4_BLOCK\" | grep -qiE 'not abort|never abort|advisory'"

DISCLOSURE_BLOCK="$([ -f "$INSTALL_SKILL_MD" ] && awk '/<!-- REVIEWER-BACKEND-DISCLOSURE -->/{flag=1} /^## Step 2/{flag=0} flag' "$INSTALL_SKILL_MD" || true)"
export DISCLOSURE_BLOCK
assert_true "C9-AC-4 (disclosure honesty): the REVIEWER-BACKEND-DISCLOSURE block mentions the on-demand auth probe" \
  "printf '%s' \"\$DISCLOSURE_BLOCK\" | grep -qF -- '--probe'"

echo ""
echo "=== C9-AC-8 (doc contract revised — docs/reviewer-backend.md + script header) ==="

assert_true "C9-AC-8 (script header): scripts/preflight/check-review-backend.sh header names --probe as an on-demand authenticated check" \
  "grep -qF -- '--probe' '$CHECK_SCRIPT' && grep -qiE 'on.demand' '$CHECK_SCRIPT'"
assert_true "C9-AC-8 (script header, R3 retained): the header still affirms the non-probe PREFLIGHT path is presence-only" \
  "grep -qiE 'presence.only' '$CHECK_SCRIPT'"

AVAILABILITY_BLOCK="$([ -f "$REVIEWER_BACKEND_MD" ] && awk '
  $0 ~ /^## Availability/ { f=1; next }
  f && /^## / { f=0 }
  f { print }
' "$REVIEWER_BACKEND_MD" || true)"
export AVAILABILITY_BLOCK
assert_true "C9-AC-8 (Availability section scoped, not deleted): still affirms PREFLIGHT / the non-probe path is presence-only" \
  "printf '%s' \"\$AVAILABILITY_BLOCK\" | grep -qiE 'presence.only|not probed'"

assert_true "C9-AC-8 (new on-demand-probe subsection): docs/reviewer-backend.md documents an on-demand --probe subsection" \
  "[ -f '$REVIEWER_BACKEND_MD' ] && grep -qiE '^## .*probe' '$REVIEWER_BACKEND_MD'"

PROBE_DOC_BLOCK="$([ -f "$REVIEWER_BACKEND_MD" ] && awk '
  $0 ~ /^## .*[Pp]robe/ { f=1; next }
  f && /^## / { f=0 }
  f { print }
' "$REVIEWER_BACKEND_MD" || true)"
export PROBE_DOC_BLOCK
assert_true "C9-AC-8 (probe subsection content, R2): names both trigger moments (install-time and backend-change-time)" \
  "printf '%s' \"\$PROBE_DOC_BLOCK\" | grep -qiE 'install' && printf '%s' \"\$PROBE_DOC_BLOCK\" | grep -qiE 'backend.change|change.time'"
assert_true "C9-AC-8 (probe subsection content, R3): states the probe is NOT wired into PREFLIGHT / no hook consumes it" \
  "printf '%s' \"\$PROBE_DOC_BLOCK\" | grep -qiE 'not.*(wired|consum)|no hook'"
assert_true "C9-AC-8 (probe subsection content, exit contract): names the five-arm exit contract (0/1/2/3/4)" \
  "printf '%s' \"\$PROBE_DOC_BLOCK\" | grep -qF '0' && printf '%s' \"\$PROBE_DOC_BLOCK\" | grep -qF '4'"

assert_true "C9-AC-8 (SETUP-GUIDE): the Reviewer-backend prerequisite mentions the on-demand --probe auth check" \
  "[ -f '$SETUP_GUIDE_MD' ] && grep -B2 -A6 -iF 'Reviewer backend' '$SETUP_GUIDE_MD' | grep -F -- '--probe' >/dev/null"
assert_true "C9-AC-8 (SETUP-GUIDE, R3 retained): the Reviewer-backend prerequisite still affirms PREFLIGHT stays presence-only / fail-closed on CLI absence" \
  "[ -f '$SETUP_GUIDE_MD' ] && grep -B2 -A6 -iF 'Reviewer backend' '$SETUP_GUIDE_MD' | grep -iE 'presence.only|fail.closed' >/dev/null"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
