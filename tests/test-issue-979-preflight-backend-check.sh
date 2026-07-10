#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: PREFLIGHT fail-closed reviewer-backend availability check — Issue #979
# =============================================================================
# Scope (.autoflow/issue-979-verification-design.md §1 AC-2, feature design D5):
# a new standalone script scripts/preflight/check-review-backend.sh
# [--backend codex|claude] probes CLI presence (no live token spend) and exits
# 0 (available) or non-zero + stderr reason (unavailable), wired into
# PREFLIGHT as a drift-check-style stop condition.
#
# Oracle (C1 RESOLVED, presence-only both backends — the verification design's
# explicit disposition): presence for BOTH codex and claude, PATH-stubbable.
# No auth-probe assertion is written here — a present-but-unauthenticated
# claude passes PREFLIGHT by design; that failure surfaces at HANDOFF step 6,
# not here.
#
# RED expectation (pre-implementation, this commit): ALL assertions FAIL — the
# script does not exist yet, and docs/autoflow-guide.md does not yet name a
# backend-availability PREFLIGHT stop condition.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_SCRIPT="$PROJECT_ROOT/scripts/preflight/check-review-backend.sh"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"

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

echo "=============================================="
echo "PREFLIGHT reviewer-backend availability check (AC-2)"
echo "=============================================="

# ---------------------------------------------------------------------------
# Presence-branch, both backends: manipulate PATH so the fake bin dir (with or
# without a backend stub) is searched FIRST, real system binaries excluded.
# ---------------------------------------------------------------------------
FAKEBIN_PRESENT="$(mktemp -d)"
FAKEBIN_ABSENT="$(mktemp -d)"
for b in codex claude; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKEBIN_PRESENT/$b"
  chmod +x "$FAKEBIN_PRESENT/$b"
done
# FAKEBIN_ABSENT stays empty — no codex/claude stub — but still carries the
# baseline utilities the check script needs (grep, jq, etc.) via a minimal
# PATH scoped to system dirs only (no project bin), so "absent" means
# genuinely unresolvable, not a PATH-scoping accident.
SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

if [ -x "$CHECK_SCRIPT" ]; then
  # codex present -> exit 0
  ( PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend codex ) >/tmp/check-979-codex-present.log 2>&1
  CODEX_PRESENT_EXIT=$?
  assert_true "AC-2 (codex present): exit 0 when codex is on PATH" \
    "[ '$CODEX_PRESENT_EXIT' -eq 0 ]"

  # codex absent -> non-zero + reason naming codex + the two remedies
  ( PATH="$FAKEBIN_ABSENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend codex ) >/tmp/check-979-codex-absent.log 2>&1
  CODEX_ABSENT_EXIT=$?
  assert_true "AC-2 (codex absent): non-zero exit" \
    "[ '$CODEX_ABSENT_EXIT' -ne 0 ]"
  assert_true "AC-2 (codex absent): stderr names the missing backend (codex)" \
    "grep -qi 'codex' /tmp/check-979-codex-absent.log"
  assert_true "AC-2 (codex absent): stderr names both remedies (install the CLI / switch backend in config)" \
    "grep -qi 'install' /tmp/check-979-codex-absent.log && grep -qi 'autoflow.local.json\\|switch\\|backend' /tmp/check-979-codex-absent.log"

  # claude present -> exit 0 (presence-only, symmetric with codex)
  ( PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend claude ) >/tmp/check-979-claude-present.log 2>&1
  CLAUDE_PRESENT_EXIT=$?
  assert_true "AC-2 (claude present, C1 presence-only symmetric with codex): exit 0" \
    "[ '$CLAUDE_PRESENT_EXIT' -eq 0 ]"

  # claude absent -> non-zero + reason
  ( PATH="$FAKEBIN_ABSENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend claude ) >/tmp/check-979-claude-absent.log 2>&1
  CLAUDE_ABSENT_EXIT=$?
  assert_true "AC-2 (claude absent): non-zero exit" \
    "[ '$CLAUDE_ABSENT_EXIT' -ne 0 ]"
  assert_true "AC-2 (claude absent): stderr names the missing backend (claude)" \
    "grep -qi 'claude' /tmp/check-979-claude-absent.log"

  # VERIFY step-3 coverage additions (minimal-implementation check): the
  # config-scaffold resolution path (no --backend: read
  # .claude/autoflow.local.json) and the unknown-backend exit-2 arm were in
  # the GREEN diff but only the --backend override arms were asserted.

  # Config-resolution arm: a cwd whose scaffold selects claude, run WITHOUT
  # --backend, under a claude-absent PATH -> non-zero naming claude (proves
  # the script read the config, not the codex default).
  CFG_DIR="$(mktemp -d)"
  mkdir -p "$CFG_DIR/.claude"
  printf '{ "review": { "backend": "claude" } }\n' > "$CFG_DIR/.claude/autoflow.local.json"
  ( cd "$CFG_DIR" && PATH="$FAKEBIN_ABSENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-cfg.log 2>&1
  CFG_EXIT=$?
  assert_true "AC-2 (config resolution): without --backend, the scaffold's backend=claude is read (claude-absent -> non-zero naming claude, not the codex default)" \
    "[ '$CFG_EXIT' -ne 0 ] && grep -qi 'claude' /tmp/check-979-cfg.log && ! grep -qi \"backend 'codex'\" /tmp/check-979-cfg.log"
  rm -rf "$CFG_DIR" /tmp/check-979-cfg.log 2>/dev/null

  # Unknown-backend arm: an invalid configured value must exit 2 with a
  # message naming the expected values.
  ( PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend gemini ) >/tmp/check-979-unknown.log 2>&1
  UNKNOWN_EXIT=$?
  assert_true "AC-2 (unknown backend): an unrecognized backend value exits 2 and names the expected codex|claude values" \
    "[ '$UNKNOWN_EXIT' -eq 2 ] && grep -qi 'unknown review backend' /tmp/check-979-unknown.log"
  rm -f /tmp/check-979-unknown.log 2>/dev/null

  # C3-AC-3 (cycle 3, Low F2): a value-less --backend (the final CLI token,
  # no value follows) must fail fast (exit 2 + stderr) instead of hanging.
  # HEAD bug: `${2:-}` guards -u, but the following `shift 2` then fails
  # (only 1 positional left) and, since this script's `set -uo pipefail`
  # omits `-e`, the failure is swallowed and the arg loop re-selects the same
  # `--backend` token forever.
  #
  # Harness-owned bounded execution (D-1, MUST): prefer timeout/gtimeout;
  # else a sleep+kill watchdog fallback. Verified round-1 fact: this host has
  # neither `timeout` nor `gtimeout` on PATH, so the fallback is the *live*
  # path here. The oracle keys on a harness-set KILLED flag (0/1) rather than
  # a hardcoded exit code — a SIGTERM-killed job reports 143, not GNU
  # timeout's 124, so a raw `-ne 124` check would be a false GREEN on the
  # fallback path.
  NOVAL_LOG="$(mktemp)"
  KILLED=0
  HANG_EXIT=""
  TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  fi
  if [ -n "$TIMEOUT_BIN" ]; then
    ( PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$TIMEOUT_BIN" 5 "$CHECK_SCRIPT" --backend ) >"$NOVAL_LOG" 2>&1
    HANG_EXIT=$?
    [ "$HANG_EXIT" -eq 124 ] && KILLED=1
  else
    ( PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" --backend ) >"$NOVAL_LOG" 2>&1 &
    NOVAL_PID=$!
    (
      sleep 5
      if kill -0 "$NOVAL_PID" 2>/dev/null; then
        kill "$NOVAL_PID" 2>/dev/null
        echo killed > "$NOVAL_LOG.watchdog"
      fi
    ) &
    WATCHDOG_PID=$!
    wait "$NOVAL_PID" 2>/dev/null
    HANG_EXIT=$?
    if [ -s "$NOVAL_LOG.watchdog" ]; then
      KILLED=1
    else
      kill "$WATCHDOG_PID" 2>/dev/null
    fi
    wait "$WATCHDOG_PID" 2>/dev/null
    rm -f "$NOVAL_LOG.watchdog" 2>/dev/null
  fi

  assert_true "C3-AC-3 (no-hang): a value-less --backend terminates on its own — the watchdog never fires (bound-agnostic: GNU timeout's 124 or the SIGTERM fallback's 143 both set KILLED=1)" \
    "[ '$KILLED' -eq 0 ]"
  assert_true "C3-AC-3 (clean exit): a value-less --backend exits 2 (matches this script's existing bad-arg class, line 40)" \
    "[ '$KILLED' -eq 0 ] && [ \"\$HANG_EXIT\" -eq 2 ]"
  assert_true "C3-AC-3 (message pin): stderr is pinned to the feature design's literal F2 message ('--backend requires a value')" \
    "grep -qi 'backend' '$NOVAL_LOG' && grep -qi 'requires a value' '$NOVAL_LOG'"
  rm -f "$NOVAL_LOG" 2>/dev/null

  rm -f /tmp/check-979-*.log 2>/dev/null

  # -------------------------------------------------------------------------
  # Cycle 5 (review-response, Codex Medium, issue-comment 4931950297) —
  # C5-AC-1(B)/C5-AC-4/C5-AC-6: a malformed or empty-value config must fail
  # closed (exit 2), never silently resolve to codex; absent/null must keep
  # resolving to codex. The discriminating condition is that BOTH codex and
  # claude CLIs are present on PATH (FAKEBIN_PRESENT), so a correct fix
  # exits 2 despite codex being available — a masked-to-codex resolution
  # would instead exit 0.
  #
  # RED expectation (this commit): HEAD's `jq … 2>/dev/null || echo codex`
  # idiom swallows jq's exit status; malformed/empty configs mask to the
  # literal 'codex', codex is present -> exit 0, not 2.
  # -------------------------------------------------------------------------
  CFG_DIR5="$(mktemp -d)"
  mkdir -p "$CFG_DIR5/.claude"

  # --- C5-AC-1(B): malformed JSON -> exit 2 ---
  printf '{ "review": { "backend": "claude"' > "$CFG_DIR5/.claude/autoflow.local.json"
  ( cd "$CFG_DIR5" && PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-c5-malformed.log 2>&1
  C5_MALFORMED_EXIT=$?
  assert_true "C5-AC-1(B): malformed .claude/autoflow.local.json makes check-review-backend.sh exit 2 (codex CLI present, not silently resolved to codex)" \
    "[ '$C5_MALFORMED_EXIT' -eq 2 ]"
  assert_true "C5-AC-1(B) message: stderr names the malformed config file" \
    "grep -qi 'autoflow.local.json' /tmp/check-979-c5-malformed.log && grep -qiE 'malformed|not valid|invalid|parse' /tmp/check-979-c5-malformed.log"
  rm -f /tmp/check-979-c5-malformed.log 2>/dev/null

  # --- C5-AC-6(B): empty-string value -> exit 2 ---
  printf '{ "review": { "backend": "" } }\n' > "$CFG_DIR5/.claude/autoflow.local.json"
  ( cd "$CFG_DIR5" && PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-c5-empty.log 2>&1
  C5_EMPTY_EXIT=$?
  assert_true "C5-AC-6(B): empty .review.backend (\"\") makes check-review-backend.sh exit 2 (codex CLI present, not silently resolved to codex)" \
    "[ '$C5_EMPTY_EXIT' -eq 2 ]"
  assert_true "C5-AC-6(B) message: stderr names the empty configured value" \
    "grep -qi 'autoflow.local.json' /tmp/check-979-c5-empty.log && grep -qiE 'empty' /tmp/check-979-c5-empty.log"
  rm -f /tmp/check-979-c5-empty.log 2>/dev/null

  # --- C5-AC-4: absent file / {} / null still resolve to codex (regression pin — passes at HEAD) ---
  rm -f "$CFG_DIR5/.claude/autoflow.local.json"
  ( cd "$CFG_DIR5" && PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-c5-absent.log 2>&1
  assert_true "C5-AC-4 (absent file): check-review-backend.sh still resolves to codex (exit 0, codex CLI present)" \
    "[ $? -eq 0 ]"

  printf '{}\n' > "$CFG_DIR5/.claude/autoflow.local.json"
  ( cd "$CFG_DIR5" && PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-c5-emptyobj.log 2>&1
  assert_true "C5-AC-4 (empty object {}): check-review-backend.sh still resolves to codex (exit 0, codex CLI present)" \
    "[ $? -eq 0 ]"

  printf '{ "review": { "backend": null } }\n' > "$CFG_DIR5/.claude/autoflow.local.json"
  ( cd "$CFG_DIR5" && PATH="$FAKEBIN_PRESENT:$SYSTEM_PATH" "$CHECK_SCRIPT" ) >/tmp/check-979-c5-null.log 2>&1
  assert_true "C5-AC-4 (null backend): check-review-backend.sh still resolves to codex (exit 0, codex CLI present)" \
    "[ $? -eq 0 ]"

  rm -rf "$CFG_DIR5" 2>/dev/null
  rm -f /tmp/check-979-c5-*.log 2>/dev/null

  # -------------------------------------------------------------------------
  # Cycle 5b (ledger E41) — jq-ABSENT + config-PRESENT must fail closed,
  # matching scripts/review/codex-review-pr.sh's already-fail-closed
  # behavior in the same situation. HEAD guards the config read with
  # `[ -f "$CFG" ] && command -v jq …` — when jq is absent the `&&` short-
  # circuits false, the whole config-read block is skipped, BACKEND stays
  # empty, and the script falls through to the codex default (exit 0 here,
  # since codex's stub is present in FAKEBIN_PRESENT) instead of failing
  # closed. This is a silent downgrade of an explicitly configured backend
  # (config says "claude") to codex — exactly the class of bug D5's
  # presence-only oracle exists to prevent.
  #
  # jq-absent PATH is built via the symlink-farm technique from
  # tests/plugin/verify-install-skill-scripts.sh's path_without_jq() (every
  # PATH executable resolvable via symlink EXCEPT jq, so codex/claude/other
  # utilities used by the script keep working while `command -v jq` fails).
  #
  # RED expectation (this commit): HEAD exits 0 (masked to codex default),
  # not the expected 2 — this arm FAILS at HEAD.
  # -------------------------------------------------------------------------
  echo ""
  echo "=== Cycle 5b (ledger E41) — jq-absent + config-present fail-closed ==="

  NOJQ_DIR="$(mktemp -d)"
  _oldifs="$IFS"
  IFS=':'
  for _d in $FAKEBIN_PRESENT $SYSTEM_PATH; do
    [ -n "$_d" ] && [ -d "$_d" ] || continue
    for _f in "$_d"/*; do
      [ -f "$_f" ] && [ -x "$_f" ] || continue
      _name="$(basename "$_f")"
      [ "$_name" = "jq" ] && continue
      [ -e "$NOJQ_DIR/$_name" ] && continue
      ln -s "$_f" "$NOJQ_DIR/$_name" 2>/dev/null
    done
  done
  IFS="$_oldifs"

  # Sanity guard: the farm must actually make jq unresolvable, else the
  # arms below would silently test nothing.
  if PATH="$NOJQ_DIR" command -v jq >/dev/null 2>&1; then
    assert_true "cycle 5b setup sanity: jq-absent PATH farm actually hides jq" "false"
  fi

  CFG_DIR6="$(mktemp -d)"
  mkdir -p "$CFG_DIR6/.claude"

  # (a) config present (valid backend: claude) + jq absent -> exit 2 + a
  # message naming jq's absence (fail closed, matches codex-review-pr.sh).
  printf '{ "review": { "backend": "claude" } }\n' > "$CFG_DIR6/.claude/autoflow.local.json"
  ( cd "$CFG_DIR6" && PATH="$NOJQ_DIR" "$CHECK_SCRIPT" ) >/tmp/check-979-c5b-present.log 2>&1
  C5B_PRESENT_EXIT=$?
  assert_true "cycle 5b (a): config present + jq absent -> exit 2 (fail closed, not silently resolved to codex)" \
    "[ '$C5B_PRESENT_EXIT' -eq 2 ]"
  assert_true "cycle 5b (a) message: stderr names jq's absence" \
    "grep -qi 'jq' /tmp/check-979-c5b-present.log"
  rm -f /tmp/check-979-c5b-present.log 2>/dev/null

  # (b) config absent + jq absent -> exit 0, codex default (regression pin
  # — no config to read, so jq's absence is moot; likely already passing
  # at HEAD since the `[ -f "$CFG" ]` arm of the guard short-circuits
  # before `command -v jq` either way).
  rm -f "$CFG_DIR6/.claude/autoflow.local.json"
  ( cd "$CFG_DIR6" && PATH="$NOJQ_DIR" "$CHECK_SCRIPT" ) >/tmp/check-979-c5b-absent.log 2>&1
  C5B_ABSENT_EXIT=$?
  assert_true "cycle 5b (b): config absent + jq absent -> exit 0, codex default (regression pin)" \
    "[ '$C5B_ABSENT_EXIT' -eq 0 ]"

  rm -rf "$CFG_DIR6" "$NOJQ_DIR" 2>/dev/null
  rm -f /tmp/check-979-c5b-*.log 2>/dev/null
else
  for d in \
    "AC-2 (codex present)" "AC-2 (codex absent, exit)" "AC-2 (codex absent, backend name)" \
    "AC-2 (codex absent, remedies)" "AC-2 (claude present)" \
    "AC-2 (claude absent, exit)" "AC-2 (claude absent, backend name)"
  do
    assert_true "$d: scripts/preflight/check-review-backend.sh exists (pre-impl: does not)" "false"
  done
fi

rm -rf "$FAKEBIN_PRESENT" "$FAKEBIN_ABSENT" 2>/dev/null

echo ""
echo "=== AC-2 (doc-invariant) — PREFLIGHT names the backend-availability check as a stop condition ==="

PREFLIGHT_BODY="$([ -f "$GUIDE_MD" ] && awk '
  $0 ~ /^## PREFLIGHT/ { f=1; next }
  f && /^## / { f=0 }
  f { print }
' "$GUIDE_MD" || true)"
PREFLIGHT_JOINED="$(printf '%s' "$PREFLIGHT_BODY" | tr '\n' ' ')"
export PREFLIGHT_JOINED

assert_true "AC-2 (doc): PREFLIGHT section names a reviewer-backend availability stop condition" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'backend' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'availab|fail.closed'"
assert_true "AC-2 (doc): PREFLIGHT section names the check script scripts/preflight/check-review-backend.sh" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qF 'check-review-backend.sh'"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
