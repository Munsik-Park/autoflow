#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/preflight/check-review-backend.sh scripts/handoff/confirm-ci-green.sh scripts/test/check-watchdog-detachment.sh
# =============================================================================
# Test: bounded-execution fallback watchdog — pipe-hold, orphan sleep, group
#       kill, fixture residue, copy lineage. Issue #100 (standing; the
#       property is a permanent mechanism guarantee, not this cycle's own
#       landed state — docs/autoflow-guide.md > RED > Naming).
# =============================================================================
# .autoflow/issue-100-verification-design.md is the single source for the
# acceptance criteria this suite converts. Layer determination: §2. Composition
# oracle determination: §3.
#
# SCOPING NOTE (declared, not silently narrowed — mirrors the verification
# design's own "declared, not argued down" convention). Every mechanism leg
# below (pipe-release, liveness, timeout-semantics, stream-fidelity,
# blast-radius) drives ONE of the two directly-invokable shipped scripts —
# scripts/preflight/check-review-backend.sh (--probe) and
# scripts/handoff/confirm-ci-green.sh — through their real bound seams
# (PROBE_TIMEOUT_SECS / CI_POLL_TIMEOUT_SECS+CI_POLL_INTERVAL_SECS), each
# under a PATH sanitized to /usr/bin:/bin:/usr/sbin:/sbin so `command -v
# timeout`/`gtimeout` fails inside the product code and its real fallback
# branch runs. The three byte-identical `run_bounded` suite copies and
# `run_bounded_in` are NOT separately driven for these mechanism legs — their
# fallback body is reachable only by running their whole host suite (which
# re-invokes other full suites transitively) or is not independently
# invokable as a library call. Their conformance rests on AC-site-closure's
# canonical-tier exact-block predicate instead, exactly the reasoning the
# feature design (§3) already applies to those same three copies for the
# marker-ordering property. `AC-marker-cleanup`'s two-location requirement
# (mktemp vs. `.watchdog`-suffix) is therefore narrowed to two mktemp sites
# (check-review-backend.sh, confirm-ci-green.sh); the `.watchdog`-suffix
# convention's cleanup rests on the same canonical-tier predicate.
#
# GATE:PLAN carried findings honored throughout (ledger O2):
#   (1) every subject launched under this suite's own drives gets stdin from
#       /dev/null, so a job-control SIGTTIN cannot stop it invisibly.
#   (2) AC-pipe-release legs use a deliberately long bound (>=6s) so bash
#       SECONDS' 1s granularity discriminates a released pipe from a held one.
#   (3) sanitized-PATH legs keep /bin (date lives there on this platform,
#       confirm-ci-green.sh:278 `sleep_to_deadline` calls it) on PATH.
#
# SUITE-INVOKES-SUITE PROHIBITION (ledger O4). This suite contains no
# `bash tests/test-*.sh` of any form. Two categories that previously appeared
# here are removed for this reason, not merely deferred to a later cleanup:
#   - AC-contract-preserved (full re-runs of the sibling contract suites) —
#     removed at ledger O3 already; regression confirmation is the CI sibling
#     step's job, run exactly once per suite per CI pass.
#   - AC-sweep-scope (arm1/arm2, each launching a sibling suite to drive its
#     embedded fixture-residue sweep) — the swept function is private to its
#     host suite (not sourceable without executing that suite's whole body,
#     which is the same prohibition under a different name), so it cannot be
#     asserted without sibling execution. Dropped rather than reimplemented
#     as a duplicated local copy of the swept logic — issue #103 owns the
#     test-architecture re-review this belongs to.
# Also dropped for this reason: AC-coreutils-present-unchanged and
# AC-manifest-regen — neither asserts this cycle's own fallback-shape fix or
# registration; both are broader fences the minimality directive routes to
# #103 rather than keeping here. AC-ci-registration's suite-invoking half
# (tests/test-workflow-trigger-conformance.sh) is dropped for the same
# suite-invokes-suite reason; its static half (scripts/test/check-suite-ci-
# coverage.sh, which scans files and workflow `run:` steps but never invokes
# a tests/test-*.sh suite) is kept below as "this cycle's own static
# registration checks" — it directly asserts that THIS suite's own CI wiring
# (added to contract-suites.yml this cycle) is live. What remains is exactly
# the fallback-behavior legs against the two shipped scripts, the
# site-closure lint over the 7 patched sites, and that one static
# registration check.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK_SCRIPT="$PROJECT_ROOT/scripts/preflight/check-review-backend.sh"
CONFIRM_SCRIPT="$PROJECT_ROOT/scripts/handoff/confirm-ci-green.sh"
MOCK_GH_DIR="$PROJECT_ROOT/tests/issue-25/mock-gh"
WATCHDOG_LINT="$PROJECT_ROOT/scripts/test/check-watchdog-detachment.sh"
CI_COVERAGE_LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"

SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

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

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Fakebin: claude/codex stub for check-review-backend.sh --probe. Modes:
#   ok        -> fast READY exit 0
#   hang      -> BECOMES a single `sleep FAKE_HANG_SECS` process (exec, no
#                fork) — models a genuinely hung single-process external CLI
#                (a real `claude`/`gh` stuck in network I/O forks nothing);
#                a plain `sleep N` statement inside a case arm does NOT get
#                bash's tail-call exec optimisation, so without `exec` this
#                forked a child that pid-scoped kill (at HEAD) orphaned —
#                mistaken for the "orphan sleep" defect itself rather than
#                the fakebin's own artifact (empirically found: the very
#                deadlock this suite's hardening responds to).
#   forkhang  -> forks a background sleep tagged FAKE_CHILD_TOKEN (same
#                process group, since neither the fakebin nor bash's default
#                job launch sets its own -m) then hangs itself — the
#                deliberately forking shape AC-child-reaped needs.
# ---------------------------------------------------------------------------
FAKEBIN="$(mktemp -d)"
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_BACKEND_AUTH:-ok}" in
  ok)       echo '{"result":"READY"}'; exit 0 ;;
  hang)     exec sleep "${FAKE_HANG_SECS:-9999}" ;;
  forkhang) sleep "${FAKE_CHILD_TOKEN:?}" & sleep "${FAKE_HANG_SECS:-9999}" ;;
esac
EOF
chmod +x "$FAKEBIN/claude"

# ---------------------------------------------------------------------------
# harness_run <outer_bound> -- <cmd...>
# Harness-level safety net (same sleep+kill idiom tests/test-issue-979-probe.sh's
# own run_bounded uses to bound ITS harness watchdog around the script under
# test). This suite is deliberately driving the very defect under test (a
# pid-scoped kill that can leave a forked/orphaned descendant holding an
# inherited fd open indefinitely) at HEAD, so a leg's own wait must never be
# allowed to block on that descendant — a HARD outer cap with SIGKILL, applied
# on top of every leg below, is what keeps a HEAD (Red) run from stalling this
# suite itself (observed: an unbounded `| cat` reader on a hang leg blocked on
# an orphaned grandchild for the remainder of its (then 9999s) sleep, until
# externally killed). Returns the wrapped command's own exit status, or 137
# if the outer bound fired.
# ---------------------------------------------------------------------------
harness_run() {
  local outer_bound="$1"; shift
  [ "$1" = "--" ] && shift
  "$@" &
  local hpid=$!
  ( sleep "$outer_bound"; kill -9 "$hpid" 2>/dev/null ) &
  local hwpid=$!
  wait "$hpid" 2>/dev/null
  local hrc=$?
  kill "$hwpid" 2>/dev/null
  wait "$hwpid" 2>/dev/null
  return $hrc
}

# ---------------------------------------------------------------------------
# run_probe <bound> <mode> <hang_secs> <child_token> <sanitized 0|1>
# Drives check-review-backend.sh --probe --backend claude through its real
# PROBE_TIMEOUT_SECS bound seam. Stdout/stderr go to FILES, never a pipe:
# a pipe reader's EOF depends on every inherited fd copy closing, including
# one an orphaned descendant holds (the exact defect this suite exists to
# catch), which is what stalled the harness itself before this hardening.
# Wrapped in harness_run so a HEAD-time miss cannot block this suite for
# longer than bound+20s. Sets PROBE_RC, PROBE_ELAPSED (SECONDS), PROBE_STDERR,
# PROBE_OUTFILE.
# ---------------------------------------------------------------------------
run_probe() {
  local bound="$1" mode="$2" hang="$3" child="$4" sanitized="$5"
  local pathval
  if [ "$sanitized" = "1" ]; then pathval="$FAKEBIN:$SYSTEM_PATH"; else pathval="$FAKEBIN:$PATH"; fi
  local errfile outfile
  errfile="$(mktemp)"; outfile="$(mktemp)"
  SECONDS=0
  harness_run $((bound + 20)) -- env PATH="$pathval" FAKE_BACKEND_AUTH="$mode" FAKE_HANG_SECS="$hang" \
    FAKE_CHILD_TOKEN="$child" PROBE_TIMEOUT_SECS="$bound" "$CHECK_SCRIPT" --backend claude --probe \
    <"/dev/null" >"$outfile" 2>"$errfile"
  PROBE_RC=$?
  PROBE_ELAPSED=$SECONDS
  PROBE_STDERR="$(cat "$errfile")"
  PROBE_OUTFILE="$outfile"
  rm -f "$errfile"
}

# ---------------------------------------------------------------------------
# run_probe_piped <bound> <mode> <sanitized 0|1>
# The ONE shape that genuinely needs pipe-EOF timing (AC-pipe-release,
# AC-no-job-notice's early-exit arm) — mode=ok only, whose worst case at HEAD
# is bounded by the watchdog's own sleep($bound) (it forks no long-lived
# descendant), never the multi-minute orphan-to-init case. Still wrapped in
# harness_run for defense in depth.
# ---------------------------------------------------------------------------
run_probe_piped() {
  local bound="$1" mode="$2" sanitized="$3"
  local pathval
  if [ "$sanitized" = "1" ]; then pathval="$FAKEBIN:$SYSTEM_PATH"; else pathval="$FAKEBIN:$PATH"; fi
  local errfile outfile
  errfile="$(mktemp)"; outfile="$(mktemp)"
  SECONDS=0
  ( PATH="$pathval" FAKE_BACKEND_AUTH="$mode" PROBE_TIMEOUT_SECS="$bound" \
      "$CHECK_SCRIPT" --backend claude --probe </dev/null 2>"$errfile" | cat >"$outfile" ) &
  local ppid=$!
  ( sleep $((bound + 20)); kill -9 "$ppid" 2>/dev/null ) &
  local pwpid=$!
  wait "$ppid" 2>/dev/null
  PROBE_RC=$?
  kill "$pwpid" 2>/dev/null
  wait "$pwpid" 2>/dev/null
  PROBE_ELAPSED=$SECONDS
  PROBE_STDERR="$(cat "$errfile")"
  PROBE_OUTFILE="$outfile"
  rm -f "$errfile"
}

find_pid_by_cmd() {
  # $1 = grep -E pattern matched against the ps args column, end-anchored by
  # the caller so it cannot match this suite's own driving command line.
  ps -eo pid,args | grep -E "$1" | grep -v grep | awk '{print $1}' | head -1
}

pgid_of() {
  ps -o pgid= -p "$1" 2>/dev/null | tr -d ' '
}

echo "=== Issue #100 bounded-execution fallback watchdog (standing) ==="

# =============================================================================
echo ""
echo "=== AC-pipe-release / AC-no-orphan (RED discriminators) ==="
# Long bound (finding 2), subject exits fast: the reader must reach EOF near
# subject completion, not at the bound; and no watchdog sleep for this call's
# unique bound value must survive the return.
run_probe_piped 53 ok 1
assert_true "AC-pipe-release: piped probe reader reaches EOF well under the 53s bound (subject exits at once)" \
  "[ $PROBE_ELAPSED -lt 5 ]"
sleep 0.6
assert_false "AC-no-orphan: no reparented 'sleep 53' watchdog survives the return + settle" \
  "[ -n \"\$(find_pid_by_cmd 'sleep 53$')\" ]"
rm -f "$PROBE_OUTFILE"

# =============================================================================
echo ""
echo "=== AC-bound-fires / AC-fired-flag-truthful (fences: pass at HEAD) ==="
run_probe 47 hang 65 "" 1
assert_true "AC-bound-fires: a genuinely hung subject is terminated near its 47s bound, not left running" \
  "[ $PROBE_ELAPSED -ge 45 ] && [ $PROBE_ELAPSED -le 58 ]"
assert_true "AC-fired-flag-truthful: the killed subject's fired flag reads fired (probe exit 3, PROBE_TIMED_OUT)" \
  "[ $PROBE_RC -eq 3 ]"
sleep 0.6
assert_false "AC-bound-fires: the killed subject itself is gone after the fire + settle" \
  "[ -n \"\$(find_pid_by_cmd 'sleep 65$')\" ]"

run_probe 61 ok 0 "" 1
assert_true "AC-bound-fires (negative arm): an early-exiting subject leaves the fired flag unset (probe exit 0)" \
  "[ $PROBE_RC -eq 0 ]"
assert_true "AC-bound-fires (negative arm): elapsed is nowhere near the 61s bound" \
  "[ $PROBE_ELAPSED -lt 5 ]"

# =============================================================================
echo ""
echo "=== AC-no-self-kill (RED discriminator) ==="
CALLER_PGID="$(pgid_of $$)"
sleep 90 &
SENTINEL_PID=$!
( PATH="$FAKEBIN:$SYSTEM_PATH" FAKE_BACKEND_AUTH=hang FAKE_HANG_SECS=79 PROBE_TIMEOUT_SECS=59 \
    "$CHECK_SCRIPT" --backend claude --probe </dev/null >/dev/null 2>&1 ) &
PROBE_BG_PID=$!
# Outer safety-kill sleep uses a duration DISTINCT from FAKE_HANG_SECS (79) —
# find_pid_by_cmd matches by the literal duration in the ps args column, so a
# collision here would let this harness watchdog's own sleep masquerade as
# the subject's (verification design §5: "every matched token chosen so it
# cannot occur in the driving command line").
( sleep 95; kill -9 "$PROBE_BG_PID" 2>/dev/null ) &
PROBE_BG_WPID=$!
SUB_PID=""
for _ in $(seq 1 40); do
  SUB_PID="$(find_pid_by_cmd 'sleep 79$')"
  [ -n "$SUB_PID" ] && break
  sleep 0.25
done
SUB_PGID=""
[ -n "$SUB_PID" ] && SUB_PGID="$(pgid_of "$SUB_PID")"
wait "$PROBE_BG_PID" 2>/dev/null
kill "$PROBE_BG_WPID" 2>/dev/null
wait "$PROBE_BG_WPID" 2>/dev/null
assert_true "AC-no-self-kill: the hung subject's process group differs from the caller's own group" \
  "[ -n \"$SUB_PGID\" ] && [ \"$SUB_PGID\" != \"$CALLER_PGID\" ]"
assert_true "AC-no-self-kill: a sentinel background job in the caller's own group survives the hang termination" \
  "kill -0 $SENTINEL_PID 2>/dev/null"
kill "$SENTINEL_PID" 2>/dev/null
wait "$SENTINEL_PID" 2>/dev/null

# =============================================================================
echo ""
echo "=== AC-child-reaped (RED discriminator) ==="
run_probe 67 forkhang 85 240 1
sleep 0.8
assert_false "AC-child-reaped: no surviving child ('sleep 240') of the hung, forking subject after the fire + settle" \
  "[ -n \"\$(find_pid_by_cmd 'sleep 240$')\" ]"
find_pid_by_cmd 'sleep 240$' | xargs -I{} kill -9 {} 2>/dev/null || true

# =============================================================================
echo ""
echo "=== AC-marker-cleanup (fence: passes at HEAD; two mktemp-convention sites) ==="
LEG_TMPDIR1="$(mktemp -d)"
TMPDIR="$LEG_TMPDIR1" harness_run 61 -- env PATH="$FAKEBIN:$SYSTEM_PATH" FAKE_BACKEND_AUTH=hang FAKE_HANG_SECS=55 PROBE_TIMEOUT_SECS=41 \
  "$CHECK_SCRIPT" --backend claude --probe </dev/null >/dev/null 2>&1
assert_true "AC-marker-cleanup (check-review-backend.sh, fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$LEG_TMPDIR1\" 2>/dev/null)\" ]"
rm -rf "$LEG_TMPDIR1"

LEG_TMPDIR2="$(mktemp -d)"
TMPDIR="$LEG_TMPDIR2" harness_run 63 -- env PATH="$FAKEBIN:$SYSTEM_PATH" FAKE_BACKEND_AUTH=ok PROBE_TIMEOUT_SECS=43 \
  "$CHECK_SCRIPT" --backend claude --probe </dev/null >/dev/null 2>&1
assert_true "AC-marker-cleanup (check-review-backend.sh, not-fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$LEG_TMPDIR2\" 2>/dev/null)\" ]"
rm -rf "$LEG_TMPDIR2"

# =============================================================================
echo ""
echo "=== AC-no-job-notice (fence: passes at HEAD) ==="
run_probe 71 hang 91 "" 1
assert_true "AC-no-job-notice (hang leg): captured stderr carries no job-control termination line" \
  "! printf '%s' \"\$PROBE_STDERR\" | grep -qE 'Terminated|Killed|Stopped'"
run_probe 73 ok 0 "" 1
assert_true "AC-no-job-notice (early-exit leg): captured stderr carries no job-control termination line" \
  "! printf '%s' \"\$PROBE_STDERR\" | grep -qE 'Terminated|Killed|Stopped'"

# =============================================================================
echo ""
echo "=== AC-marker-cleanup second site: confirm-ci-green.sh ==="
GREEN_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","name":"x","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]}'

CONFIRM_TMPDIR1="$(mktemp -d)"
TMPDIR="$CONFIRM_TMPDIR1" harness_run 110 -- env PATH="$MOCK_GH_DIR:$SYSTEM_PATH" \
  GH_MOCK_PRECHECK_BODY="$GREEN_BODY" GH_MOCK_POLL_BODY="$GREEN_BODY" GH_MOCK_PRECHECK_SLEEP=90 \
  CI_POLL_TIMEOUT_SECS=83 CI_POLL_INTERVAL_SECS=83 "$CONFIRM_SCRIPT" --pr 1 </dev/null >/dev/null 2>&1
assert_true "AC-marker-cleanup (confirm-ci-green.sh, fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$CONFIRM_TMPDIR1\" 2>/dev/null)\" ]"
rm -rf "$CONFIRM_TMPDIR1"

CONFIRM_TMPDIR2="$(mktemp -d)"
TMPDIR="$CONFIRM_TMPDIR2" harness_run 25 -- env PATH="$MOCK_GH_DIR:$SYSTEM_PATH" \
  GH_MOCK_PRECHECK_BODY="$GREEN_BODY" GH_MOCK_POLL_BODY="$GREEN_BODY" \
  CI_POLL_TIMEOUT_SECS=9 CI_POLL_INTERVAL_SECS=9 "$CONFIRM_SCRIPT" --pr 1 </dev/null >/dev/null 2>&1
assert_true "AC-marker-cleanup (confirm-ci-green.sh, not-fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$CONFIRM_TMPDIR2\" 2>/dev/null)\" ]"
rm -rf "$CONFIRM_TMPDIR2"

# =============================================================================
echo ""
echo "=== AC-site-closure (RED discriminator) ==="
assert_true "AC-site-closure: scripts/test/check-watchdog-detachment.sh exists" \
  "[ -f '$WATCHDOG_LINT' ]"
bash "$WATCHDOG_LINT" --self-test >/dev/null 2>&1
assert_true "AC-site-closure: the lint's own --self-test passes (conforming/order-regression/pipe-hold/exemption fixtures classified correctly)" \
  "[ $? -eq 0 ]"
WATCHDOG_LINT_OUT="$(mktemp)"; bash "$WATCHDOG_LINT" >"$WATCHDOG_LINT_OUT" 2>&1
WATCHDOG_LINT_RC=$?
assert_true "AC-site-closure: the real tree conforms end-to-end (every fallback site carries the fix)" \
  "[ $WATCHDOG_LINT_RC -eq 0 ]"
rm -f "$WATCHDOG_LINT_OUT"

# =============================================================================
echo ""
echo "=== This cycle's own CI registration (static, no suite execution) ==="
# scripts/test/check-suite-ci-coverage.sh scans tests/**/*.sh and workflow
# `run:` steps and reports; it never invokes a tests/test-*.sh suite as a
# subprocess, so this is not a sibling-suite call under the O4/O5
# prohibition. It directly asserts this cycle's own change: that THIS suite
# (added to .github/workflows/contract-suites.yml in this cycle) has an
# execution path.
if [ -f "$CI_COVERAGE_LINT" ]; then
  bash "$CI_COVERAGE_LINT" >/dev/null 2>&1
  assert_true "This suite has a CI execution path (scripts/test/check-suite-ci-coverage.sh is green)" \
    "[ $? -eq 0 ]"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
rm -rf "$FAKEBIN" 2>/dev/null
[[ $FAIL -gt 0 ]] && exit 1
exit 0
