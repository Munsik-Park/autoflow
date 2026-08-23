#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/preflight/check-review-backend.sh scripts/handoff/confirm-ci-green.sh scripts/test/check-watchdog-detachment.sh scripts/test/run-suites.sh
# lane: standing
# budget-secs: 123
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
# under a PATH composed by this suite's single seam (compose_path) from an
# inclusion-built scratch directory holding exactly the allowlisted
# externals the driven surface needs — never a slice of real system bin
# directories — so `command -v timeout`/`gtimeout` fails inside the product
# code on every platform this suite runs on, Linux CI included, and its real
# fallback branch runs. The fail-fast precondition guard right after setup
# asserts this at runtime rather than merely claiming it (review-response
# cycle 2: the prior exclusion-based slice still resolved Ubuntu's own
# `/usr/bin/timeout`, so CI never entered the fallback branch it claimed to
# cover). The three byte-identical `run_bounded` suite copies and
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
# GATE:PLAN carried findings honored throughout (ledger O2, cycle 1):
#   (1) every subject launched under this suite's own drives gets stdin from
#       /dev/null, so a job-control SIGTTIN cannot stop it invisibly.
#   (2) AC-pipe-release legs use a deliberately long bound (>=6s) so bash
#       SECONDS' 1s granularity discriminates a released pipe from a held one.
#   (3) `date` is superseded by the cycle-2 allowlist entry below (it was
#       previously kept on PATH by retaining /bin wholesale; the inclusion
#       build symlinks it in by name instead — confirm-ci-green.sh:278
#       `sleep_to_deadline` still needs it, unchanged).
#
# GATE:PLAN carried findings honored throughout (ledger O8, cycle 2):
#   (1) the composition seam (compose_path) takes only the front component —
#       no tail-flavour parameter. AC-path-seam-single is scoped to the
#       compositions a subject is actually launched with; the two drive
#       helpers' unreached ambient-PATH `else` arm (ledger F19/O8) keeps
#       assembling its own value and is not routed through the seam.
#   (2) the existing confirm-ci-green.sh marker-cleanup legs stay
#       synchronous — no background-and-poll rewrite. The confirm subject's
#       AC-fallback-witness leg is a separate, new leg instead.
#   (3) scripts/test/check-watchdog-detachment.sh excludes this whole file
#       from its SUBJECT SET by a file-scoped `grep -vF` filter
#       (scripts/test/check-watchdog-detachment.sh:83-96) — this is not the
#       ENUMERATED-EXEMPTION tier (that tier is for known-exempt PRODUCT
#       sites). Noted once here rather than repeated at each new
#       backgrounded sleep this cycle adds (the witness legs below).
#   (4) AC-fallback-precondition and AC-fallback-witness are Red-unobservable
#       on a host that already resolves neither `timeout` nor `gtimeout`
#       under the prior slice (e.g. this suite's own macOS development
#       host — §0 of the verification design) — Red for both exists only on
#       the Linux CI runner, where the prior slice kept `/usr/bin/timeout`
#       reachable.
#
# BOUND-REDUCTION NOTE (issue #119). The six drives whose bound genuinely
# fires are this suite's wall clock, and their bounds are minimized to
# 9/15/11/8/13/17 under two floors re-derived from this file:
#   - GRANULARITY FLOOR (>= 8) — see the "bound reduction (static)" section
#     below (search `Issue #119 bound reduction`), which derives and asserts
#     this floor; not restated here.
#   - DISCOVERY FLOOR. AC-no-self-kill is the one drive that LOCATES its
#     subject by polling, so its bound is also its subject's liveness budget:
#     bound >= 2x the poll budget (iterations x step). Both sides move — the
#     poll is 24 iterations at 0.25s (6s) against a bound of 15.
# The pipe-release bound (run_probe_piped) is NOT in the reduction set: its
# leg discriminates a released pipe from a held one by elapsed time and keeps
# the >= 6s constraint recorded at ledger O2 (2) above.
# AC-no-self-kill is a FENCE, not a fire discriminator (ledger F1): it asserts
# what was NOT killed (the subject's pgid differs from the caller's; a
# sentinel in the caller's group survives), so no fire reading is added to it
# and its vacuity protection is the discovery floor instead.
# Hang, child, sentinel and outer-cap literals keep their values across the
# reduction, so no grepped find_pid_by_cmd token moves.

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
#
# Issue #103 cycle 2 (review-response) -- AC-fallback-site-enrolled-in-site-
# closure. Once scripts/test/run-suites.sh carries its own sleep+kill
# fallback it becomes a member of the watchdog site set, and the existing
# AC-site-closure canonical-block predicate below (the real-tree run of
# scripts/test/check-watchdog-detachment.sh) already governs it -- no new
# assertion is written, which would add a layer without adding a subject.
# What this cycle adds is the SELECTION half: scripts/test/run-suites.sh
# joins this suite's own # ci-subject: header above, so an edit to the
# runner alone selects this suite -- without that, the enrollment breaks in
# a run where this suite is the only one that would catch a violation.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK_SCRIPT="$PROJECT_ROOT/scripts/preflight/check-review-backend.sh"
CONFIRM_SCRIPT="$PROJECT_ROOT/scripts/handoff/confirm-ci-green.sh"
MOCK_GH_DIR="$PROJECT_ROOT/tests/issue-25/mock-gh"
CI_COVERAGE_LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"

# ---------------------------------------------------------------------------
# Inclusion-based sanitized PATH tail (feature design §2 "Inclusion-based
# sanitized PATH"). A scratch directory holding one symlink per allowlisted
# external — never a slice of real system bin directories, which cannot
# express "everything except timeout" when timeout shares a directory with
# commands the subject needs (Ubuntu's own /usr/bin/timeout, the review-
# response cycle-2 finding). Renamed from the old SYSTEM_PATH: the name now
# denotes the property the value carries, not a directory slice.
# ---------------------------------------------------------------------------
NEITHER_TIMEOUT_TAIL="$(mktemp -d)"
ALLOWLIST_CMDS="bash env dirname mktemp rm rmdir sleep date jq cat sed tail tr wc"
for _cmd in $ALLOWLIST_CMDS; do
  _real="$(command -v "$_cmd" 2>/dev/null || true)"
  if [ -z "$_real" ]; then
    echo "FATAL: allowlist command not resolvable on this host: $_cmd" >&2
    exit 2
  fi
  ln -s "$_real" "$NEITHER_TIMEOUT_TAIL/$_cmd"
done

# compose_path <front-component> — the suite's single subject-PATH builder
# (feature design §2 "One named composition seam"). Every actually-launched
# leg obtains its subject PATH here; the two drive helpers' unreached
# ambient-tailed `else` arm is not routed through it (ledger O8 (1)).
compose_path() {
  printf '%s:%s' "$1" "$NEITHER_TIMEOUT_TAIL"
}

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

# assert_no_resolution_failure <desc> <captured-stream-text> — AC-toolchain-
# sufficient: a leg's outcome assertion alone cannot distinguish "the subject
# did its work" from "the subject crashed early on a missing command", since
# both can leave a clean TMPDIR and a fast exit. Reads the leg's own captured
# stdout+stderr for that failure shape.
assert_no_resolution_failure() {
  local desc="$1" stream="$2"
  TESTS=$((TESTS + 1))
  if printf '%s' "$stream" | grep -qiE 'command not found|no such file or directory'; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# assert_fallback_precondition <label> <composed-path-value> — AC-fallback-
# precondition, fail-fast (feature design §2). Resolved in a real child shell
# under the exact exported value, once per distinct composed flavour, before
# any behavioural leg runs: a runner-image change or an allowlist edit that
# re-adds a real directory must abort the suite loudly rather than let the
# legs silently drive the wrong branch.
assert_fallback_precondition() {
  local label="$1" pathval="$2"
  TESTS=$((TESTS + 1))
  if PATH="$pathval" bash -c 'command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1'; then
    echo "  FAIL: AC-fallback-precondition ($label): bound tool resolves under PATH=$pathval"
    FAIL=$((FAIL + 1))
    echo "ABORT: fallback precondition violated for $label — PATH=$pathval" >&2
    rm -rf "$FAKEBIN" "$NEITHER_TIMEOUT_TAIL" 2>/dev/null
    exit 1
  else
    echo "  PASS: AC-fallback-precondition ($label): neither timeout nor gtimeout resolves"
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
  if [ "$sanitized" = "1" ]; then pathval="$(compose_path "$FAKEBIN")"; else pathval="$FAKEBIN:$PATH"; fi
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
  if [ "$sanitized" = "1" ]; then pathval="$(compose_path "$FAKEBIN")"; else pathval="$FAKEBIN:$PATH"; fi
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
echo "=== AC-path-seam-single (static): no subject PATH assembled outside compose_path ==="
# Every composition of $FAKEBIN or $MOCK_GH_DIR against a PATH-shaped tail
# must go through compose_path(); its own definition uses "$1", not either
# literal name, so it never matches this pattern itself. The sole permitted
# exception is the two drive helpers' unreached ambient-tailed `else` arm
# (ledger O8 (1)) — not scoped by this criterion because no caller reaches
# it (feature design §2 "One named composition seam").
DIRECT_COMPOSITIONS="$(grep -nE '(FAKEBIN|MOCK_GH_DIR)"?:\$(PATH|NEITHER_TIMEOUT_TAIL)' "$SCRIPT_DIR/test-bounded-execution-fallback.sh" \
  | grep -v 'else pathval="\$FAKEBIN:\$PATH"; fi')"
assert_true "AC-path-seam-single: every actually-launched leg's subject PATH comes from compose_path (only the unreached ambient else arm is exempt)" \
  "[ -z \"$DIRECT_COMPOSITIONS\" ]"

# =============================================================================
echo ""
echo "=== Issue #119 bound reduction (static): the six real-wait bounds ==="
# Six drives in this file genuinely wait for their bound to fire; every other
# leg's subject exits at once and costs nothing. Those six ARE this suite's
# wall clock, and issue #119 reduces them. Two floors bound the reduction, both
# re-derived from this file rather than asserted:
#
#   * GRANULARITY FLOOR — >= 8. The paired negative arms below assert
#     `PROBE_ELAPSED -lt 5`, fixing a 5-second early-exit ceiling, and bash
#     SECONDS has one-second granularity. At or below 5 no timing oracle here
#     can separate "the watchdog fired at the bound" from "the subject exited
#     at once", and the absence-shaped arms (no surviving child, empty TMPDIR)
#     go vacuous rather than red when the bound fires before the subject has
#     finished starting. 8 leaves three seconds of clearance and leaves the
#     ceiling itself untouched.
#   * REDUCTION CEILING — <= 20. The settled assignment (ledger F8: 9/15/11/
#     8/13/17) tops out at 17; the ceiling carries the same three seconds of
#     clearance above it that the floor carries below the early-exit ceiling.
#     It is a band, not a pin: §2.7 of the feature design declines to pin an
#     arithmetic figure, and a per-drive band admits any assignment that
#     actually reduces the wait.
#
# Each drive is located by its own HANG token, not by its bound — the hang,
# child, sentinel and outer-cap literals keep their values across this change
# (feature design §2.4), so anchoring on them survives the reduction the arm
# exists to check.
BOUND_SRC="$SCRIPT_DIR/test-bounded-execution-fallback.sh"
declare -a REDUCED_BOUND_NAMES=() REDUCED_BOUND_VALUES=()
add_reduced_bound() {          # <drive-name> <extracted-value>
  REDUCED_BOUND_NAMES+=("$1")
  REDUCED_BOUND_VALUES+=("$2")
}
add_reduced_bound "AC-bound-fires (hang 65)" \
  "$(grep -oE '^run_probe [0-9]+ hang 65' "$BOUND_SRC" | head -1 | awk '{print $2}')"
add_reduced_bound "AC-no-self-kill (hang 79)" \
  "$(grep -oE 'FAKE_HANG_SECS=79 PROBE_TIMEOUT_SECS=[0-9]+' "$BOUND_SRC" | head -1 | sed -E 's/.*PROBE_TIMEOUT_SECS=//')"
add_reduced_bound "AC-child-reaped (forkhang 85)" \
  "$(grep -oE '^run_probe [0-9]+ forkhang 85' "$BOUND_SRC" | head -1 | awk '{print $2}')"
add_reduced_bound "AC-marker-cleanup probe fired (hang 55)" \
  "$(grep -oE 'FAKE_HANG_SECS=55 PROBE_TIMEOUT_SECS=[0-9]+' "$BOUND_SRC" | head -1 | sed -E 's/.*PROBE_TIMEOUT_SECS=//')"
add_reduced_bound "AC-no-job-notice hang leg (hang 91)" \
  "$(grep -oE '^run_probe [0-9]+ hang 91' "$BOUND_SRC" | head -1 | awk '{print $2}')"
add_reduced_bound "AC-marker-cleanup confirm fired (precheck sleep 90)" \
  "$(grep -A2 'GH_MOCK_PRECHECK_SLEEP=90' "$BOUND_SRC" | grep -oE 'CI_POLL_TIMEOUT_SECS=[0-9]+' | head -1 | sed -E 's/.*=//')"

REDUCED_BOUND_LIST=""
for i in "${!REDUCED_BOUND_NAMES[@]}"; do
  bname="${REDUCED_BOUND_NAMES[$i]}"; bval="${REDUCED_BOUND_VALUES[$i]}"
  assert_true "AC-119-bound-located: the '$bname' drive's bound literal is still locatable by its unchanged hang token (found: '${bval:-none}')" \
    "[ -n \"$bval\" ]"
  [ -n "$bval" ] || continue
  REDUCED_BOUND_LIST="$REDUCED_BOUND_LIST $bval"
  assert_true "AC-119-bound-reduced: '$bname' bound $bval is inside the reduction band [8,20] — above the granularity floor the 5s early-exit ceiling fixes, and actually reduced" \
    "[ $bval -ge 8 ] && [ $bval -le 20 ]"
done
REDUCED_BOUND_UNIQUE="$(printf '%s\n' $REDUCED_BOUND_LIST | sort -u | wc -l | tr -d ' ')"
REDUCED_BOUND_COUNT="$(printf '%s\n' $REDUCED_BOUND_LIST | wc -l | tr -d ' ')"
assert_true "AC-119-bound-reduced: the six reduced bounds are pairwise distinct ($REDUCED_BOUND_COUNT drives,$REDUCED_BOUND_LIST) — a shared bound would make two legs' derived outer caps and watchdog sleeps indistinguishable to find_pid_by_cmd" \
  "[ '$REDUCED_BOUND_UNIQUE' = '$REDUCED_BOUND_COUNT' ] && [ '$REDUCED_BOUND_COUNT' = '6' ]"

# The one elapsed-window assertion in this file is the timing oracle of the
# AC-bound-fires drive, so its two edges move WITH that drive's bound. The
# coupling is asserted rather than remembered: lower edge above the 5s
# early-exit ceiling and below the bound (a fast kill passes, an instant exit
# does not); upper edge below bound + 20, so a harness_run outer-cap fire —
# which returns the kill status, not the product's own timeout status — still
# fails the arm instead of passing inside a widened window.
BOUND_FIRES_BOUND="${REDUCED_BOUND_VALUES[0]}"
ELAPSED_LOW="$(grep -oE 'PROBE_ELAPSED -ge [0-9]+' "$BOUND_SRC" | head -1 | awk '{print $3}')"
ELAPSED_HIGH="$(grep -oE 'PROBE_ELAPSED -le [0-9]+' "$BOUND_SRC" | head -1 | awk '{print $3}')"
assert_true "AC-119-elapsed-window-tracks-bound: the AC-bound-fires elapsed window [${ELAPSED_LOW:-?},${ELAPSED_HIGH:-?}] sits above the 5s early-exit ceiling, below its own bound ${BOUND_FIRES_BOUND:-?}, and below bound+20 — it moves with the bound instead of being left behind" \
  "[ -n \"$ELAPSED_LOW\" ] && [ -n \"$ELAPSED_HIGH\" ] && [ $ELAPSED_LOW -gt 5 ] && [ $ELAPSED_LOW -le $BOUND_FIRES_BOUND ] && [ $ELAPSED_HIGH -lt $((BOUND_FIRES_BOUND + 20)) ]"

# AC-pipe-release-bound-untouched — explicitly OUTSIDE the reduction set. The
# pipe-release leg discriminates a released pipe from a held one by elapsed
# time, so its bound has to stay far enough above the 5s ceiling for bash
# SECONDS to separate the two (the >= 6s constraint recorded in this file's
# own GATE:PLAN finding block).
PIPE_RELEASE_BOUND="$(grep -oE '^run_probe_piped [0-9]+' "$BOUND_SRC" | head -1 | awk '{print $2}')"
assert_true "AC-pipe-release-bound-untouched: the pipe-release bound (${PIPE_RELEASE_BOUND:-none}) stays >= 6 — it is not in the reduction set, and shrinking it would collapse the elapsed discrimination it exists for" \
  "[ -n \"$PIPE_RELEASE_BOUND\" ] && [ $PIPE_RELEASE_BOUND -ge 6 ]"

# AC-119-discovery-floor. AC-no-self-kill is the one drive that LOCATES its
# subject by polling, so its bound is also its subject's liveness budget: the
# subject must still be alive when the poll finds it. Each poll iteration costs
# a full `ps -eo pid,args` sweep, so the budget is iterations x step. Rule:
# bound >= 2x the poll budget. The failure mode of an undersized budget is
# loud, not silent — discovery failure leaves SUB_PGID empty and the pgid arm
# reds — but nothing stops a later edit from re-creating the condition, which
# is what this static arm holds.
POLL_ITERS="$(grep -oE 'for _ in \$\(seq 1 [0-9]+\); do' "$BOUND_SRC" | head -1 | grep -oE '[0-9]+\)' | tr -d ')')"
POLL_STEP_CENTIS=25   # the polls below step at 0.25s; expressed in centiseconds so the comparison stays integer
NO_SELF_KILL_BOUND="${REDUCED_BOUND_VALUES[1]}"
assert_true "AC-119-discovery-floor: the AC-no-self-kill poll budget (${POLL_ITERS:-?} iterations x 0.25s) is at most half its bound (${NO_SELF_KILL_BOUND:-?}s) — the subject outlives the sweep that has to locate it" \
  "[ -n \"$POLL_ITERS\" ] && [ -n \"$NO_SELF_KILL_BOUND\" ] && [ $((POLL_ITERS * POLL_STEP_CENTIS * 2)) -le $((NO_SELF_KILL_BOUND * 100)) ]"

# =============================================================================
echo ""
echo "=== AC-token-collision-free (static): grepped tokens, per banner-delimited leg ==="
# find_pid_by_cmd matches a caller-supplied, end-anchored duration pattern
# against the whole `ps` args column, so it cannot tell the subject's `sleep N`
# from any other `sleep N` alive at that instant. A collision does not red the
# leg — it makes the leg green against the WRONG process, which is why no
# behavioural arm above can catch it and why this one is static.
#
# Scoped to the GREPPED tokens, per leg. Two broader forms are wrong on the
# unmodified tree and are rejected for that reason, not omitted:
#   * file-wide distinctness reds on the pipe-release leg's `sleep 53` sentinel
#     against the confirm leg's GH_MOCK_PRECHECK_SLEEP — legitimate, since the
#     sentinel is killed long before the confirm leg starts;
#   * per-leg distinctness over ALL literals reds on the confirm leg's
#     deliberately equal CI_POLL_TIMEOUT_SECS / CI_POLL_INTERVAL_SECS pair —
#     confirm-ci-green.sh clamps the precheck bound to the interval, so
#     equality is what keeps the poll from gaining an iteration.
# The legs run sequentially, so "alive at the same instant" is the leg's own
# launched set. Legs are delimited by this file's own column-0 `echo "=== … ==="`
# banners; a `(static)` banner marks a block that launches nothing.
#
# Coverage half: every find_pid_by_cmd call site in the file falls inside some
# block, so no pattern escapes the check.
COLLISION_BLOCK_BANNERS="$(grep -nE '^echo "=== ' "$BOUND_SRC" | cut -d: -f1)"
COLLISION_GREPPED_TOTAL=0
COLLISION_CHECKED_TOTAL=0
COLLISION_VIOLATIONS=""
prev_line=""
for line in $COLLISION_BLOCK_BANNERS "$(wc -l < "$BOUND_SRC")"; do
  if [ -n "$prev_line" ]; then
    block="$(sed -n "${prev_line},$((line - 1))p" "$BOUND_SRC")"
    banner="$(printf '%s' "$block" | head -1 | sed -E 's/^echo "=== //; s/ ?===".*$//; s/[^A-Za-z0-9 :()/-]//g')"
    case "$banner" in *'(static)'*) prev_line="$line"; continue ;; esac

    # Grepped tokens: the durations actually used as `ps` patterns.
    grepped="$(printf '%s\n' "$block" | grep -oE "find_pid_by_cmd '[a-z]* ?[0-9]+\\\$'" | grep -oE '[0-9]+' | sort -u)"
    [ -n "$grepped" ] || { prev_line="$line"; continue; }

    # Launched literals: every duration this block starts a process with.
    launched="$(
      printf '%s\n' "$block" | grep -oE '(FAKE_HANG_SECS|PROBE_TIMEOUT_SECS|CI_POLL_TIMEOUT_SECS|CI_POLL_INTERVAL_SECS|GH_MOCK_PRECHECK_SLEEP|FAKE_CHILD_TOKEN)=[0-9]+' | sed -E 's/.*=//'
      # Bare `sleep N` only at a COMMAND position — a `sleep N` inside a
      # find_pid_by_cmd pattern or an assertion description is a reference to a
      # launch, not a launch, and counting it would make every token collide
      # with its own matcher.
      printf '%s\n' "$block" | grep -oE '(^|\(|;|&&)[[:space:]]*sleep [0-9]+' | grep -oE '[0-9]+'
      printf '%s\n' "$block" | grep -oE '^harness_run [0-9]+' | awk '{print $2}'
      # run_probe/run_probe_piped: bound, hang, child token, and the derived
      # outer cap harness_run backgrounds as `sleep bound+20` (run_probe:293).
      printf '%s\n' "$block" | grep -oE '^run_probe(_piped)? [0-9]+( [a-z]+( [0-9]+)?( [0-9]+)?)?' \
        | awk '{ print $2; print $2 + 20; if ($4 ~ /^[0-9]+$/) print $4; if ($5 ~ /^[0-9]+$/) print $5 }'
    )"

    for tok in $grepped; do
      COLLISION_GREPPED_TOTAL=$((COLLISION_GREPPED_TOTAL + 1))
      hits="$(printf '%s\n' $launched | grep -cxF "$tok" || true)"
      if [ "$hits" != "1" ]; then
        COLLISION_VIOLATIONS="$COLLISION_VIOLATIONS [${banner} / token $tok matches $hits launched literals]"
        echo "  ---- collision: leg '$banner' greps 'sleep $tok', which matches $hits literal(s) that leg launches ----"
      fi
      COLLISION_CHECKED_TOTAL=$((COLLISION_CHECKED_TOTAL + 1))
    done
  fi
  prev_line="$line"
done

assert_true "AC-token-collision-free: every grepped duration token matches exactly one literal its own leg launches — the one the assertion means (checked $COLLISION_CHECKED_TOTAL token(s)); violations:${COLLISION_VIOLATIONS:- none}" \
  "[ -z \"$COLLISION_VIOLATIONS\" ]"
COLLISION_CALLSITES="$(grep -cE "find_pid_by_cmd '[a-z]* ?[0-9]+\\\$'" "$BOUND_SRC" | tr -d ' ')"
assert_true "AC-token-collision-free (coverage half): every duration-pattern find_pid_by_cmd call site in the file falls inside a checked leg ($COLLISION_GREPPED_TOTAL distinct token(s) over $COLLISION_CALLSITES call site(s)) — no pattern escapes the check" \
  "[ $COLLISION_GREPPED_TOTAL -gt 0 ] && [ $COLLISION_CALLSITES -ge $COLLISION_GREPPED_TOTAL ]"

# =============================================================================
echo ""
echo "=== AC-fallback-precondition (fail-fast, before any behavioural leg) ==="
assert_fallback_precondition "probe (fakebin flavor)" "$(compose_path "$FAKEBIN")"
assert_fallback_precondition "confirm (mock-gh flavor)" "$(compose_path "$MOCK_GH_DIR")"

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
run_probe 9 hang 65 "" 1
assert_true "AC-bound-fires: a genuinely hung subject is terminated near its 9s bound, not left running" \
  "[ $PROBE_ELAPSED -ge 8 ] && [ $PROBE_ELAPSED -le 20 ]"
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
NOKILL_OUT="$(mktemp)"; NOKILL_ERR="$(mktemp)"
( PATH="$(compose_path "$FAKEBIN")" FAKE_BACKEND_AUTH=hang FAKE_HANG_SECS=79 PROBE_TIMEOUT_SECS=15 \
    "$CHECK_SCRIPT" --backend claude --probe </dev/null >"$NOKILL_OUT" 2>"$NOKILL_ERR" ) &
PROBE_BG_PID=$!
# Outer safety-kill sleep uses a duration DISTINCT from FAKE_HANG_SECS (79) —
# find_pid_by_cmd matches by the literal duration in the ps args column, so a
# collision here would let this harness watchdog's own sleep masquerade as
# the subject's (verification design §5: "every matched token chosen so it
# cannot occur in the driving command line").
( sleep 95; kill -9 "$PROBE_BG_PID" 2>/dev/null ) &
PROBE_BG_WPID=$!
SUB_PID=""
for _ in $(seq 1 24); do
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
assert_no_resolution_failure "AC-toolchain-sufficient (no-self-kill leg): captured streams carry no command-resolution failure" \
  "$(cat "$NOKILL_OUT" "$NOKILL_ERR" 2>/dev/null)"
kill "$SENTINEL_PID" 2>/dev/null
wait "$SENTINEL_PID" 2>/dev/null
rm -f "$NOKILL_OUT" "$NOKILL_ERR"

# =============================================================================
echo ""
echo "=== AC-fallback-witness (probe): backgrounded subject is its own process-group leader ==="
# Fresh, unique hang/bound/outer tokens (97/101/131) so find_pid_by_cmd's
# end-anchored match cannot collide with another leg's driving command line
# (verification design §5). This subshell + its outer safety-kill sleep are
# a new backgrounded-sleep site in this file — see the ledger O8 (3) note at
# the top of this file for why no per-site EXEMPT_SITES entry is needed.
( PATH="$(compose_path "$FAKEBIN")" FAKE_BACKEND_AUTH=hang FAKE_HANG_SECS=97 PROBE_TIMEOUT_SECS=101 \
    "$CHECK_SCRIPT" --backend claude --probe </dev/null >/dev/null 2>&1 ) &
WITNESS_BG_PID=$!
( sleep 131; kill -9 "$WITNESS_BG_PID" 2>/dev/null ) &
WITNESS_WPID=$!
WITNESS_PID=""
for _ in $(seq 1 40); do
  WITNESS_PID="$(find_pid_by_cmd 'sleep 97$')"
  [ -n "$WITNESS_PID" ] && break
  sleep 0.25
done
WITNESS_PGID=""
[ -n "$WITNESS_PID" ] && WITNESS_PGID="$(pgid_of "$WITNESS_PID")"
assert_true "AC-fallback-witness (probe): the exec'd hang subject is a process-group leader (pgid == pid) — positive evidence the sleep+kill fallback ran, not the bound tool" \
  "[ -n \"$WITNESS_PID\" ] && [ -n \"$WITNESS_PGID\" ] && [ \"$WITNESS_PGID\" = \"$WITNESS_PID\" ]"
[ -n "$WITNESS_PID" ] && kill -TERM -"$WITNESS_PID" 2>/dev/null
wait "$WITNESS_BG_PID" 2>/dev/null
kill "$WITNESS_WPID" 2>/dev/null
wait "$WITNESS_WPID" 2>/dev/null

# =============================================================================
echo ""
echo "=== AC-child-reaped (RED discriminator) ==="
run_probe 11 forkhang 85 240 1
# Fire oracle (issue #119). The child-absence assertion below is
# absence-shaped: a subject that never hung, and a watchdog that never fired,
# satisfy it too. At the unreduced bound that weakness was masked by the size
# of the hang literal; at a reduced bound it is not. The product's own fired
# contract is read instead — check-review-backend.sh exits 3 on a fired probe
# bound (PROBE_TIMED_OUT) — so the leg discriminates "the watchdog fired and
# reaped the child" from "there was never anything to reap".
assert_true "AC-child-reaped (fire oracle): the forking subject was actually terminated by its own bound (probe exit 3), not left to exit on its own" \
  "[ $PROBE_RC -eq 3 ]"
sleep 0.8
assert_false "AC-child-reaped: no surviving child ('sleep 240') of the hung, forking subject after the fire + settle" \
  "[ -n \"\$(find_pid_by_cmd 'sleep 240$')\" ]"
find_pid_by_cmd 'sleep 240$' | xargs -I{} kill -9 {} 2>/dev/null || true

# =============================================================================
echo ""
echo "=== AC-marker-cleanup (fence: passes at HEAD; two mktemp-convention sites) ==="
LEG_TMPDIR1="$(mktemp -d)"; LEG_OUT1="$(mktemp)"; LEG_ERR1="$(mktemp)"
TMPDIR="$LEG_TMPDIR1" harness_run 61 -- env PATH="$(compose_path "$FAKEBIN")" FAKE_BACKEND_AUTH=hang FAKE_HANG_SECS=55 PROBE_TIMEOUT_SECS=8 \
  "$CHECK_SCRIPT" --backend claude --probe </dev/null >"$LEG_OUT1" 2>"$LEG_ERR1"
MARKER_FIRED_RC=$?
# Fire oracle (issue #119). harness_run returns the wrapped command's own exit
# status, and this leg discarded it: an empty TMPDIR is equally true of a
# subject that exited at once, so the leg's name ("fired branch") was carried
# by the hang literal rather than by any assertion. 3 is
# check-review-backend.sh's own fired-bound status, and it is distinct from the
# 137 harness_run returns when ITS outer cap fires — so an outer-cap kill,
# which would also leave TMPDIR empty, reds this arm instead of passing.
assert_true "AC-marker-cleanup (check-review-backend.sh, fired branch — fire oracle): the leg really took the fired branch (probe exit 3, not an early exit and not a harness outer-cap kill)" \
  "[ $MARKER_FIRED_RC -eq 3 ]"
assert_true "AC-marker-cleanup (check-review-backend.sh, fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$LEG_TMPDIR1\" 2>/dev/null)\" ]"
assert_no_resolution_failure "AC-toolchain-sufficient (marker-cleanup fired leg): captured streams carry no command-resolution failure" \
  "$(cat "$LEG_OUT1" "$LEG_ERR1" 2>/dev/null)"
rm -rf "$LEG_TMPDIR1"; rm -f "$LEG_OUT1" "$LEG_ERR1"

LEG_TMPDIR2="$(mktemp -d)"; LEG_OUT2="$(mktemp)"; LEG_ERR2="$(mktemp)"
TMPDIR="$LEG_TMPDIR2" harness_run 63 -- env PATH="$(compose_path "$FAKEBIN")" FAKE_BACKEND_AUTH=ok PROBE_TIMEOUT_SECS=43 \
  "$CHECK_SCRIPT" --backend claude --probe </dev/null >"$LEG_OUT2" 2>"$LEG_ERR2"
assert_true "AC-marker-cleanup (check-review-backend.sh, not-fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$LEG_TMPDIR2\" 2>/dev/null)\" ]"
assert_no_resolution_failure "AC-toolchain-sufficient (marker-cleanup not-fired leg): captured streams carry no command-resolution failure" \
  "$(cat "$LEG_OUT2" "$LEG_ERR2" 2>/dev/null)"
rm -rf "$LEG_TMPDIR2"; rm -f "$LEG_OUT2" "$LEG_ERR2"

# =============================================================================
echo ""
echo "=== AC-no-job-notice (fence: passes at HEAD) ==="
run_probe 13 hang 91 "" 1
# Fire oracle (issue #119). "stderr carries no Terminated|Killed|Stopped line"
# is a fence: it is satisfied by a subject that was never killed at all. The
# fence stays as the fence it is, and the fired reading is added beside it, so
# the leg cannot go green by never firing.
assert_true "AC-no-job-notice (hang leg — fire oracle): the hung subject was terminated by its own bound (probe exit 3), so the silent-stderr fence is over a real kill" \
  "[ $PROBE_RC -eq 3 ]"
assert_true "AC-no-job-notice (hang leg): captured stderr carries no job-control termination line" \
  "! printf '%s' \"\$PROBE_STDERR\" | grep -qE 'Terminated|Killed|Stopped'"
run_probe 73 ok 0 "" 1
assert_true "AC-no-job-notice (early-exit leg): captured stderr carries no job-control termination line" \
  "! printf '%s' \"\$PROBE_STDERR\" | grep -qE 'Terminated|Killed|Stopped'"

# =============================================================================
echo ""
echo "=== AC-marker-cleanup second site: confirm-ci-green.sh ==="
GREEN_BODY='{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[{"__typename":"CheckRun","name":"x","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]}'

CONFIRM_TMPDIR1="$(mktemp -d)"; CONFIRM_OUT1="$(mktemp)"; CONFIRM_ERR1="$(mktemp)"
TMPDIR="$CONFIRM_TMPDIR1" harness_run 110 -- env PATH="$(compose_path "$MOCK_GH_DIR")" \
  GH_MOCK_PRECHECK_BODY="$GREEN_BODY" GH_MOCK_POLL_BODY="$GREEN_BODY" GH_MOCK_PRECHECK_SLEEP=90 \
  CI_POLL_TIMEOUT_SECS=17 CI_POLL_INTERVAL_SECS=17 "$CONFIRM_SCRIPT" --pr 1 </dev/null >"$CONFIRM_OUT1" 2>"$CONFIRM_ERR1"
CONFIRM_FIRED_RC=$?
# Fire oracle (issue #119), confirm-ci-green.sh's own contract: exit 14 when
# the poll deadline is reached without a confirmed mergeable state. The mock's
# precheck sleep outlasts CI_POLL_TIMEOUT_SECS, so 14 is the fired
# classification for this leg — and, as on the probe side, it is distinct from
# harness_run's 137 outer-cap kill, which would leave the same empty TMPDIR.
assert_true "AC-marker-cleanup (confirm-ci-green.sh, fired branch — fire oracle): the leg really reached the poll deadline (confirm exit 14, not a confirmed-green early return and not a harness outer-cap kill)" \
  "[ $CONFIRM_FIRED_RC -eq 14 ]"
assert_true "AC-marker-cleanup (confirm-ci-green.sh, fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$CONFIRM_TMPDIR1\" 2>/dev/null)\" ]"
assert_no_resolution_failure "AC-toolchain-sufficient (confirm marker-cleanup fired leg): captured streams carry no command-resolution failure" \
  "$(cat "$CONFIRM_OUT1" "$CONFIRM_ERR1" 2>/dev/null)"
rm -rf "$CONFIRM_TMPDIR1"; rm -f "$CONFIRM_OUT1" "$CONFIRM_ERR1"

CONFIRM_TMPDIR2="$(mktemp -d)"; CONFIRM_OUT2="$(mktemp)"; CONFIRM_ERR2="$(mktemp)"
TMPDIR="$CONFIRM_TMPDIR2" harness_run 25 -- env PATH="$(compose_path "$MOCK_GH_DIR")" \
  GH_MOCK_PRECHECK_BODY="$GREEN_BODY" GH_MOCK_POLL_BODY="$GREEN_BODY" \
  CI_POLL_TIMEOUT_SECS=9 CI_POLL_INTERVAL_SECS=9 "$CONFIRM_SCRIPT" --pr 1 </dev/null >"$CONFIRM_OUT2" 2>"$CONFIRM_ERR2"
assert_true "AC-marker-cleanup (confirm-ci-green.sh, not-fired branch): no leftover mktemp marker in TMPDIR" \
  "[ -z \"\$(ls -A \"$CONFIRM_TMPDIR2\" 2>/dev/null)\" ]"
assert_no_resolution_failure "AC-toolchain-sufficient (confirm marker-cleanup not-fired leg): captured streams carry no command-resolution failure" \
  "$(cat "$CONFIRM_OUT2" "$CONFIRM_ERR2" 2>/dev/null)"
rm -rf "$CONFIRM_TMPDIR2"; rm -f "$CONFIRM_OUT2" "$CONFIRM_ERR2"

# =============================================================================
echo ""
echo "=== AC-fallback-witness (confirm): mock gh subject is its own process-group leader ==="
# Kept as a NEW leg rather than folded into the marker-cleanup legs above
# (ledger O8 (2): those stay synchronous, no background-and-poll rewrite).
# Another new backgrounded-sleep site — same file-scoped exemption noted at
# the top of this file (ledger O8 (3)) and at the probe witness leg above.
# GH_MOCK_PRECHECK_SLEEP (99) is kept above the precheck's own gh_bounded
# sub-bound (clamp_to_interval(CI_POLL_TIMEOUT_SECS)=88 here), so the mock is
# still hung when the poll loop below locates it (verification design §5).
CONFIRM_WITNESS_TMPDIR="$(mktemp -d)"
TMPDIR="$CONFIRM_WITNESS_TMPDIR" env PATH="$(compose_path "$MOCK_GH_DIR")" \
  GH_MOCK_PRECHECK_BODY="$GREEN_BODY" GH_MOCK_POLL_BODY="$GREEN_BODY" GH_MOCK_PRECHECK_SLEEP=99 \
  CI_POLL_TIMEOUT_SECS=88 CI_POLL_INTERVAL_SECS=88 "$CONFIRM_SCRIPT" --pr 1 </dev/null >/dev/null 2>&1 &
CONFIRM_WITNESS_PID=$!
( sleep 115; kill -9 "$CONFIRM_WITNESS_PID" 2>/dev/null ) &
CONFIRM_WITNESS_WPID=$!
CONFIRM_MOCK_PID=""
for _ in $(seq 1 40); do
  # End-anchored on the precheck call's own argv suffix, never on its inner
  # `sleep` child — the mock survives its own hang as the group leader
  # (verification design §0, feature design §2 "Direct branch witness").
  CONFIRM_MOCK_PID="$(find_pid_by_cmd 'mergeable,mergeStateStatus$')"
  [ -n "$CONFIRM_MOCK_PID" ] && break
  sleep 0.25
done
CONFIRM_MOCK_PGID=""
[ -n "$CONFIRM_MOCK_PID" ] && CONFIRM_MOCK_PGID="$(pgid_of "$CONFIRM_MOCK_PID")"
assert_true "AC-fallback-witness (confirm): the surviving mock gh precheck call is a process-group leader (pgid == pid), located by its end-anchored --json mergeable,mergeStateStatus argv, not its inner sleep child" \
  "[ -n \"$CONFIRM_MOCK_PID\" ] && [ -n \"$CONFIRM_MOCK_PGID\" ] && [ \"$CONFIRM_MOCK_PGID\" = \"$CONFIRM_MOCK_PID\" ]"
[ -n "$CONFIRM_MOCK_PID" ] && kill -TERM -"$CONFIRM_MOCK_PID" 2>/dev/null
wait "$CONFIRM_WITNESS_PID" 2>/dev/null
kill "$CONFIRM_WITNESS_WPID" 2>/dev/null
wait "$CONFIRM_WITNESS_WPID" 2>/dev/null
rm -rf "$CONFIRM_WITNESS_TMPDIR"

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
rm -rf "$FAKEBIN" "$NEITHER_TIMEOUT_TAIL" 2>/dev/null
[[ $FAIL -gt 0 ]] && exit 1
exit 0
