#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-watchdog-detachment.sh — standing lint: every sleep+kill watchdog
# fallback (bounded-execution helper's no-GNU-timeout branch) is detached
# from its caller's stdout/stderr and signals only its subject's own process
# group. Issue #100.
# =============================================================================
# .autoflow/issue-100-feature-design.md §2 (canonical fallback shape) and §4
# > *copy lineage* (two-tier recognition predicate, adopted at ledger F2/F4).
# .autoflow/issue-100-verification-design.md AC-site-closure.
#
# RECOGNITION — a candidate is any line opening a backgrounded subshell whose
# first statement is `sleep` on a bound (a shell variable or a literal
# integer): `( sleep "$bound" ...` / `( sleep 5 ...`. This is the same
# discovery shape the feature design's own §0 fact-finding grep used
# (`grep -rn 'sleep .\{0,2\}.bound'`), generalised to a literal bound so the
# one inline exemption site is also discovered rather than silently missed.
#
# Each candidate is held to one of two tiers:
#   - CANONICAL tier — every site except the named exemption(s) below. Must
#     satisfy every check in `check_canonical_block` (own redirection, group
#     job control, marker-before-kill ordering, group-scoped kill and reap,
#     marker cleanup) in the STATEMENT ORDER the checklist states — this is
#     what makes the marker-write-precedes-kill guarantee a text property
#     rather than a per-site behavioural claim (ledger F4). Normalised only
#     for local variable names, the marker path, and insignificant
#     whitespace/comments — nothing else.
#   - ENUMERATED-EXEMPTION tier — sites named in EXEMPT_SITES below, with
#     their reason recorded beside them (ledger F2). Held only to the two
#     properties the feature design's §4 *Fallback shape* bullet still
#     applies to them: own-group redirection and a group-scoped (dash-prefixed
#     pgid) kill/reap. Not held to block-shape conformance.
#
# A loose "carries a redirection somewhere" predicate is rejected for the
# canonical tier (feature design §4): it would leave the byte-identical
# `run_bounded` copies with neither a behavioural oracle nor a text guarantee.
#
# Usage:
#   bash scripts/test/check-watchdog-detachment.sh [--self-test] [--root <dir>]
#
# Self-test first, then the real-tree result — the
# scripts/test/check-suite-ci-coverage.sh:31-38 precedent. Against the live
# tree (once fixed) an exit 0 is unfalsifiable; the self-test's planted
# violations (one per tier, including a statement-order regression) are what
# keep it from being vacuous.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODE="default"
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --root)      ROOT="${2:-}"; shift ;;
    *)           echo "check-watchdog-detachment: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# Enumerated-exemption tier (feature design §4, ledger F2). Each entry: path
# then its reason, recorded here so the exclusion survives a rename rather
# than reading as a silent non-match.
EXEMPT_SITES_LIST="tests/test-issue-952-wizard-removal.sh"
is_exempt() {
  case "$1" in
    tests/test-issue-952-wizard-removal.sh)
      # Literal bound, bare unguarded kill, no marker (feature design §4,
      # ledger F2) — cannot satisfy the exact-block predicate.
      return 0 ;;
  esac
  return 1
}

# candidate_lines <root> — "<repo-relative-path>:<line>" for every
# backgrounded sleep-watchdog subshell opener under tests/** and scripts/**.
candidate_lines() {
  local root="$1"
  { grep -rnE '\( *sleep +("?\$[A-Za-z_][A-Za-z0-9_]*"?|[0-9]+)' \
      "$root/tests" "$root/scripts" 2>/dev/null || true; } \
    | grep -E '^[^:]+:[0-9]+:.*\( *sleep' \
    | sed -E "s#^$root/##" \
    | cut -d: -f1,2 \
    | grep -vF 'scripts/test/check-watchdog-detachment.sh:'
}

# block_text <file> <start-line> -> up to 40 lines from start, the working
# window every check below scans within.
block_text() {
  local file="$1" start="$2"
  sed -n "${start},$((start + 40))p" "$file"
}

# line_of <block-text> <regex> -> first 1-based line number within the block
# matching regex, or empty.
line_of() {
  printf '%s\n' "$1" | grep -nE "$2" | head -1 | cut -d: -f1
}

# var_of <block-text> <regex-with-one-capture> -> the captured variable name.
var_of() {
  printf '%s\n' "$1" | grep -oE "$2" | head -1 | sed -E "s/$2/\\1/"
}

# check_canonical_block <block-text> -> prints violation reason(s) to stdout;
# empty output means conformant. Statement order is enforced by requiring
# each anchor's line number to strictly increase.
check_canonical_block() {
  local block="$1" rc=0
  local pidvar wdvar markervar
  pidvar="$(var_of "$block" 'kill -0 "\$([A-Za-z_][A-Za-z0-9_]*)"')"
  if [ -z "$pidvar" ]; then
    echo "no kill -0 \"\$pid\" liveness guard found"
    return 1
  fi
  local l_open l_live l_mark l_kill l_close l_setpm l_wait l_check
  l_open="$(line_of "$block" '\( *sleep')"
  l_live="$(line_of "$block" "kill -0 \"\\\$${pidvar}\"")"
  l_mark="$(line_of "$block" 'echo .* *> *"?\$')"
  l_kill="$(line_of "$block" "kill -TERM -\"\\\$${pidvar}\"")"
  l_close="$(line_of "$block" '\) *>/dev/null 2>&1 *&')"
  l_setpm="$(line_of "$block" 'set \+m')"
  l_wait="$(line_of "$block" "wait \"\\\$${pidvar}\"")"
  l_check="$(line_of "$block" '\[ *-s *"?\$')"

  [ -n "$l_open" ]  || { echo "watchdog subshell opener not found"; rc=1; }
  [ -n "$l_live" ]  || { echo "no kill -0 liveness guard on the same pid var"; rc=1; }
  [ -n "$l_mark" ]  || { echo "no marker write inside the fired branch"; rc=1; }
  [ -n "$l_kill" ]  || { echo "no group-scoped kill -TERM -\"\$pid\" of the subject"; rc=1; }
  [ -n "$l_close" ] || { echo "watchdog subshell is not redirected to /dev/null (pipe-hold)"; rc=1; }
  [ -n "$l_setpm" ] || { echo "no set +m before the wait (job-control notice risk)"; rc=1; }
  [ -n "$l_wait" ]  || { echo "no wait \"\$pid\" on the same pid var"; rc=1; }
  [ -n "$l_check" ] || { echo "no marker existence check after wait"; rc=1; }
  [ "$rc" -eq 1 ] && return 1

  # Statement order: open < live < mark < kill < close < set+m < wait < check
  local prev=0 n
  for n in "$l_open" "$l_live" "$l_mark" "$l_kill" "$l_close" "$l_setpm" "$l_wait" "$l_check"; do
    if [ "$n" -le "$prev" ]; then
      echo "statement order violated (marker-before-kill / redirection / set+m ordering broken)"
      return 1
    fi
    prev="$n"
  done

  # Reap branch: after the marker check, a group-scoped kill of the watchdog,
  # a wait on it, then a marker rm -f — all after l_check.
  local tail
  tail="$(printf '%s\n' "$block" | sed -n "$((l_check + 1)),\$p")"
  wdvar="$(var_of "$tail" 'kill -TERM -"\$([A-Za-z_][A-Za-z0-9_]*)"')"
  if [ -z "$wdvar" ] || [ "$wdvar" = "$pidvar" ]; then
    echo "no group-scoped reap of a distinct watchdog pid var in the not-fired branch"
    return 1
  fi
  if ! printf '%s\n' "$tail" | grep -qE "wait \"\\\$${wdvar}\""; then
    echo "watchdog pid is not waited on after the reap"
    return 1
  fi
  markervar="$(var_of "$block" 'rm -f "\$([A-Za-z_][A-Za-z0-9_]*)"')"
  if [ -z "$markervar" ]; then
    echo "no marker cleanup (rm -f) after the watchdog wait"
    return 1
  fi
  return 0
}

# check_exempt_block <block-text> -> the two-property predicate the
# enumerated-exemption tier is still held to: own-group redirection is a
# looser requirement here (the site is allowed to write its own stdout, only
# the watchdog's own kill/reap must be group-scoped); require a group-scoped
# (dash-prefixed) kill somewhere in the block.
check_exempt_block() {
  local block="$1"
  if ! printf '%s\n' "$block" | grep -qE 'kill -TERM? -"?\$[A-Za-z_][A-Za-z0-9_]*"?|kill -"?\$[A-Za-z_][A-Za-z0-9_]*"?'; then
    echo "exempt site's watchdog kill is not group-scoped (missing leading '-' before the pgid)"
    return 1
  fi
  return 0
}

# scan <root> -> prints one "<path>:<line>: <reason>" per violation; empty
# output means every candidate conforms to its tier.
scan() {
  local root="$1" line file num block reason
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file="${line%:*}"
    num="${line##*:}"
    block="$(block_text "$root/$file" "$num")"
    if is_exempt "$file"; then
      reason="$(check_exempt_block "$block")"
    else
      reason="$(check_canonical_block "$block")"
    fi
    [ -n "$reason" ] && printf '%s:%s: %s\n' "$file" "$num" "$reason"
  done < <(candidate_lines "$root")
}

# ---------------------------------------------------------------------------
# Self-test — one planted violation per tier, plus a positive (conforming)
# fixture for each tier, and a dedicated statement-order regression fixture
# (marker write slid after the kill inside an otherwise-conforming block).
# ---------------------------------------------------------------------------
self_test() {
  local dir rc=0
  dir="$(mktemp -d)"
  mkdir -p "$dir/tests" "$dir/scripts"

  # Conforming canonical-tier fixture.
  cat > "$dir/tests/fixture-conforming.sh" <<'EOF'
run_bounded() {
  set -m
  ( "$@" ) >"$logfile" 2>&1 &
  pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      echo killed > "$marker"
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  watchdog_pid=$!
  set +m
  wait "$pid" 2>/dev/null
  RB_EXIT=$?
  if [ -s "$marker" ]; then
    RB_KILLED=1
  else
    kill -TERM -"$watchdog_pid" 2>/dev/null || kill "$watchdog_pid" 2>/dev/null
  fi
  wait "$watchdog_pid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
}
EOF

  # Statement-order regression: marker write slides AFTER the kill.
  cat > "$dir/tests/fixture-order-regression.sh" <<'EOF'
run_bounded() {
  set -m
  ( "$@" ) >"$logfile" 2>&1 &
  pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
      echo killed > "$marker"
    fi
  ) >/dev/null 2>&1 &
  watchdog_pid=$!
  set +m
  wait "$pid" 2>/dev/null
  RB_EXIT=$?
  if [ -s "$marker" ]; then
    RB_KILLED=1
  else
    kill -TERM -"$watchdog_pid" 2>/dev/null || kill "$watchdog_pid" 2>/dev/null
  fi
  wait "$watchdog_pid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
}
EOF

  # Pipe-hold regression: no redirection on the watchdog subshell.
  cat > "$dir/tests/fixture-pipe-hold.sh" <<'EOF'
run_bounded() {
  set -m
  ( "$@" ) >"$logfile" 2>&1 &
  pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      echo killed > "$marker"
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    fi
  ) &
  watchdog_pid=$!
  set +m
  wait "$pid" 2>/dev/null
  RB_EXIT=$?
  if [ -s "$marker" ]; then
    RB_KILLED=1
  else
    kill -TERM -"$watchdog_pid" 2>/dev/null || kill "$watchdog_pid" 2>/dev/null
  fi
  wait "$watchdog_pid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
}
EOF

  # Enumerated-exemption tier: conforming (group-scoped kill only).
  mkdir -p "$dir/tests"
  cat > "$dir/tests/test-issue-952-wizard-removal.sh" <<'EOF'
( sleep 5; kill -"$NOARG_PID" 2>/dev/null ) &
NOARG_WPID=$!
EOF

  local out expect
  out="$(scan "$dir")"

  # Conforming fixture must report nothing.
  if printf '%s\n' "$out" | grep -q 'fixture-conforming.sh'; then
    echo "check-watchdog-detachment: --self-test FAIL — conforming canonical fixture reported a violation"
    rc=1
  fi

  # Order-regression fixture must be caught, on the ordering reason.
  if ! printf '%s\n' "$out" | grep -q 'fixture-order-regression.sh.*statement order'; then
    echo "check-watchdog-detachment: --self-test FAIL — statement-order regression not detected"
    rc=1
  fi

  # Pipe-hold fixture must be caught.
  if ! printf '%s\n' "$out" | grep -q 'fixture-pipe-hold.sh'; then
    echo "check-watchdog-detachment: --self-test FAIL — missing-redirection regression not detected"
    rc=1
  fi

  # The exemption-tier fixture (group-scoped kill present) must NOT be
  # reported: it is held to the two-property predicate, not block shape.
  if printf '%s\n' "$out" | grep -q 'test-issue-952-wizard-removal.sh'; then
    echo "check-watchdog-detachment: --self-test FAIL — enumerated-exemption fixture (group-scoped) was reported"
    rc=1
  fi

  # Negative control on the exemption predicate itself: a NON-group-scoped
  # kill in an exempt-tier site must still be caught.
  rm -f "$dir/tests/test-issue-952-wizard-removal.sh"
  cat > "$dir/tests/test-issue-952-wizard-removal.sh" <<'EOF'
( sleep 5; kill "$NOARG_PID" 2>/dev/null ) &
NOARG_WPID=$!
EOF
  out2="$(scan "$dir")"
  if ! printf '%s\n' "$out2" | grep -q 'test-issue-952-wizard-removal.sh.*group-scoped'; then
    echo "check-watchdog-detachment: --self-test FAIL — non-group-scoped kill at the exempt site was not caught"
    rc=1
  fi

  [ "$rc" -eq 0 ] && echo "check-watchdog-detachment: --self-test OK (conforming/order-regression/pipe-hold/exemption fixtures all classified correctly)"

  rm -rf "$dir"
  return $rc
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if ! self_test; then
  echo "check-watchdog-detachment: detector self-test failed — real-tree result not reported"
  exit 1
fi

VIOLATIONS="$(scan "$ROOT")"
if [ -z "$VIOLATIONS" ]; then
  echo "check-watchdog-detachment: OK — every sleep-watchdog fallback site is detached and group-scoped"
  exit 0
fi

echo "check-watchdog-detachment: watchdog site(s) failing detachment/group-scope conformance:"
printf '%s\n' "$VIOLATIONS" | sed 's/^/  /'
exit 1
