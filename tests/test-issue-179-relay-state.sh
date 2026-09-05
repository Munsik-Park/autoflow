#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/architect/relay-state.sh scripts/architect/isolation-check.sh scripts/architect/deliberation-metrics.py tests/fixtures/issue-179/**
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #179 — ARCHITECT relay: transcript state, isolation check, metrics
# =============================================================================
# The ARCHITECT deliberation is relayed by the orchestrator between two
# persistent participants (ADR-0023 D2). Three scripts carry the mechanical
# half of that procedure, and this suite fixes each of them hermetically over
# fixtures under tests/fixtures/issue-179/ — no agent, no session, no network:
#
#   1. scripts/architect/relay-state.sh — `init` writes the header and refuses
#      to overwrite; `brief` appends a Brief block; `state` prints the decidable
#      state only (turns, last side, ended, reports, next) and fails closed on
#      a malformed transcript (non-consecutive turn, wrong side, missing
#      marker, report before the end). The end condition is the issue #166
#      rule unchanged: two consecutive turns marked `further: none`; a Brief
#      block re-opens an ended discussion.
#   2. scripts/architect/isolation-check.sh — the first N characters of every
#      turn body are searched in a session log, JSON-escaped as the log stores
#      text; a hit is a leak (exit 1), none is clean (exit 0).
#   3. scripts/architect/deliberation-metrics.py — distinct-requestId call
#      counts, tool counts, usage de-duplicated by message.id, first_in, and
#      per-wake segmentation of a persistent participant's transcript.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE="$PROJECT_ROOT/scripts/architect/relay-state.sh"
ISO="$PROJECT_ROOT/scripts/architect/isolation-check.sh"
METRICS="$PROJECT_ROOT/scripts/architect/deliberation-metrics.py"
FX="$PROJECT_ROOT/tests/fixtures/issue-179"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# state <fixture> -> stdout captured in OUT, exit in RC
run_state() { OUT="$(bash "$STATE" state "$1" 2>"$SCRATCH/err")"; RC=$?; ERR="$(cat "$SCRATCH/err")"; }
kv() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p"; }

echo "== relay-state: state over well-formed transcripts =="

run_state "$FX/transcript-ended.md"
if [ "$RC" = "0" ] && [ "$(kv turns)" = "4" ] && [ "$(kv last)" = "test" ] && [ "$(kv ended)" = "true" ] && [ "$(kv reports)" = "-" ] && [ "$(kv reports_missing)" = "dev,test" ] && [ "$(kv next)" = "report" ]; then
  pass "ended: four turns, the last two 'further: none' -> ended=true, next=report, both reports missing"
else
  failc "ended: rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi
# The marker lives on the heading: a body that says "further: none" is not a marker.
if [ "$(kv ended)" = "true" ] && ! printf '%s' "$OUT" | grep -q 'body'; then
  pass "ended: the body phrase 'further: none' in turn 2 did not shift the state (the heading is the marker)"
fi

run_state "$FX/transcript-open.md"
if [ "$RC" = "0" ] && [ "$(kv turns)" = "3" ] && [ "$(kv ended)" = "false" ] && [ "$(kv next)" = "test" ] && [ "$(kv reports_missing)" = "-" ]; then
  pass "open: none/yes/none is not a consecutive pair -> ended=false, next=test (turn 4 is the Test AI's)"
else
  failc "open: rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi

run_state "$FX/transcript-brief-reopens.md"
if [ "$RC" = "0" ] && [ "$(kv turns)" = "3" ] && [ "$(kv ended)" = "false" ] && [ "$(kv next)" = "test" ]; then
  pass "brief: a Brief block after an ended pair re-opens the discussion; the pair is counted from the brief on"
else
  failc "brief: rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi

run_state "$FX/transcript-reports.md"
if [ "$RC" = "0" ] && [ "$(kv ended)" = "true" ] && [ "$(kv reports)" = "test" ] && [ "$(kv reports_missing)" = "dev" ] && [ "$(kv next)" = "record" ]; then
  pass "reports: one report present -> next=record, reports_missing names the other side"
else
  failc "reports: rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi

run_state "$FX/transcript-both-reports.md"
if [ "$RC" = "0" ] && [ "$(kv reports)" = "dev,test" ] && [ "$(kv reports_missing)" = "-" ] && [ "$(kv next)" = "record" ]; then
  pass "reports: both present -> next=record, nothing missing"
else
  failc "reports (both): rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi

echo "== relay-state: state fails closed on a malformed transcript =="

run_state "$FX/transcript-bad-number.md"
if [ "$RC" = "1" ] && printf '%s' "$ERR" | grep -q 'turn 3 follows turn 1'; then
  pass "malformed: a non-consecutive turn number is rejected (exit 1, cause names the turns)"
else
  failc "malformed number: rc=$RC err=[$ERR]"
fi
run_state "$FX/transcript-bad-side.md"
if [ "$RC" = "1" ] && printf '%s' "$ERR" | grep -q 'belongs to the Developer AI'; then
  pass "malformed: turn 1 by the Test AI is rejected (the Developer AI opens; sides alternate)"
else
  failc "malformed side: rc=$RC err=[$ERR]"
fi
run_state "$FX/transcript-bad-marker.md"
if [ "$RC" = "1" ] && printf '%s' "$ERR" | grep -q 'malformed turn heading'; then
  pass "malformed: a turn heading without the [further: …] marker is rejected"
else
  failc "malformed marker: rc=$RC err=[$ERR]"
fi
run_state "$FX/transcript-early-report.md"
if [ "$RC" = "1" ] && printf '%s' "$ERR" | grep -q 'before the discussion has ended'; then
  pass "malformed: a report section before the end condition is rejected"
else
  failc "early report: rc=$RC err=[$ERR]"
fi
run_state "$SCRATCH/absent.md"
if [ "$RC" = "2" ]; then
  pass "usage: a missing transcript is a usage error (exit 2), distinct from malformed (exit 1)"
else
  failc "usage: rc=$RC for a missing file"
fi
bash "$STATE" >/dev/null 2>&1; RC=$?
if [ "$RC" = "2" ]; then pass "usage: no arguments -> exit 2"; else failc "usage: no arguments -> rc=$RC"; fi

echo "== relay-state: init and brief =="

T="$SCRATCH/t.md"
if bash "$STATE" init "$T" 179 2>/dev/null && grep -q '^# ARCHITECT transcript — issue #179$' "$T" && grep -q '^## Topic$' "$T" && grep -q 'Issue #179\. Inputs: \.autoflow/issue-179-phase-a\.md' "$T" && grep -q '"operator decision" is settled' "$T" && grep -q '^## Transcript$' "$T" && ! grep -q 'From the orchestrator' "$T"; then
  pass "init: writes the header with the topic stated once, naming the issue's inputs and the settled authorities, no brief line"
else
  failc "init: header not as expected: $(head -5 "$T" 2>/dev/null | tr '\n' '|')"
fi
run_state "$T"
if [ "$RC" = "0" ] && [ "$(kv turns)" = "0" ] && [ "$(kv next)" = "dev" ] && [ "$(kv last)" = "-" ]; then
  pass "init: a fresh transcript has zero turns and the Developer AI opens (next=dev)"
else
  failc "init state: rc=$RC out=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
fi
bash "$STATE" init "$T" 179 >/dev/null 2>&1; RC=$?
if [ "$RC" = "1" ] && grep -q '^## Transcript$' "$T"; then
  pass "init: refuses to overwrite an existing transcript (append-only; exit 1, file untouched)"
else
  failc "init overwrite: rc=$RC"
fi
T2="$SCRATCH/t2.md"
if bash "$STATE" init "$T2" 179 "discuss only the oracle" 2>/dev/null && grep -q '^From the orchestrator: discuss only the oracle$' "$T2"; then
  pass "init: an initial brief is carried into the Topic under the 'From the orchestrator:' line"
else
  failc "init brief: $(grep -n 'orchestrator' "$T2" 2>/dev/null)"
fi
bash "$STATE" init "$SCRATCH/t3.md" abc >/dev/null 2>&1; RC=$?
if [ "$RC" = "2" ] && [ ! -e "$SCRATCH/t3.md" ]; then pass "init: a non-numeric issue is a usage error and writes nothing"; else failc "init non-numeric: rc=$RC"; fi
printf '\n### Turn 1 — Developer AI [further: none]\nopen\n\n### Turn 2 — Test AI [further: none]\nclose\n' >> "$T"
run_state "$T"; before_next="$(kv next)"
if bash "$STATE" brief "$T" "one more question" 2>/dev/null && grep -q '^### Brief$' "$T" && grep -q '^one more question$' "$T"; then
  run_state "$T"
  if [ "$before_next" = "report" ] && [ "$(kv ended)" = "false" ] && [ "$(kv next)" = "dev" ]; then
    pass "brief: appended after an ended pair, the state re-opens (ended=false) and the next side follows the alternation"
  else
    failc "brief state: before=$before_next after=[$(printf '%s' "$OUT" | tr '\n' ' ')]"
  fi
else
  failc "brief: append failed or block not found"
fi
bash "$STATE" brief "$SCRATCH/no-header.md" "x" >/dev/null 2>&1; RC=$?
if [ "$RC" = "2" ]; then pass "brief: a missing transcript is a usage error (exit 2)"; else failc "brief missing: rc=$RC"; fi
printf 'no header\n' > "$SCRATCH/nh.md"; bash "$STATE" brief "$SCRATCH/nh.md" "x" >/dev/null 2>&1; RC=$?
if [ "$RC" = "1" ]; then pass "brief: a file without the Transcript header is refused (exit 1)"; else failc "brief no-header: rc=$RC"; fi

echo "== isolation-check =="

if command -v jq >/dev/null 2>&1; then
  out="$(bash "$ISO" "$FX/transcript-ended.md" "$FX/session-clean.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "0" ] && [ "$(printf '%s\n' "$out" | grep -c ': clean$')" = "4" ] && printf '%s' "$out" | grep -q '4 turn(s) checked, 0 leak(s)'; then
    pass "isolation: a session log holding only the one-line notifications and the state output is clean for all four turns (exit 0)"
  else
    failc "isolation clean: rc=$RC out=[$(printf '%s' "$out" | tr '\n' '|')]"
  fi
  out="$(bash "$ISO" "$FX/transcript-ended.md" "$FX/session-leak.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "1" ] && printf '%s' "$out" | grep -q '^turn 3: LEAK' && [ "$(printf '%s\n' "$out" | grep -c 'LEAK')" = "1" ]; then
    pass "isolation: a turn body that reached the session log (JSON-escaped, inside a tool_result) is reported as a leak on exactly that turn (exit 1)"
  else
    failc "isolation leak: rc=$RC out=[$(printf '%s' "$out" | tr '\n' '|')]"
  fi
  out="$(bash "$ISO" "$FX/transcript-ended.md" "$FX/session-leak.jsonl" --chars 5 2>&1)"; RC=$?
  if [ "$RC" = "1" ] && printf '%s' "$out" | grep -q 'first 5 character(s)'; then
    pass "isolation: --chars sets the needle length and is reported in the summary"
  else
    failc "isolation --chars: rc=$RC out=[$(printf '%s' "$out" | tail -1)]"
  fi
  bash "$ISO" "$FX/transcript-ended.md" >/dev/null 2>&1; RC=$?
  if [ "$RC" = "2" ]; then pass "isolation: missing session argument -> usage (exit 2)"; else failc "isolation usage: rc=$RC"; fi
else
  failc "isolation: jq is required by the script and is not installed"
fi

echo "== deliberation-metrics =="

if command -v python3 >/dev/null 2>&1; then
  J="$(python3 "$METRICS" --label t "$FX/agent-one-shot.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "0" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].kind')" = "dev-turn" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.calls')" = "2" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.bash')" = "1" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.first_in')" = "1210" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.usage.output')" = "100" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.usage.cache_creation')" = "1050" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.message_len')" = "12" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.wall_s == 10')" = "true" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.tool_s == 1')" = "true" ]; then
    pass "metrics: one-shot turn — 2 distinct requestIds over 3 assistant records, usage de-duplicated by message.id keeping the larger output (40 not 3), first_in = first record's input+cache, StructuredOutput message length, wall from first to last record, tool time = tool_use → next user record (1 s)"
  else
    failc "metrics one-shot: rc=$RC $(printf '%s' "$J" | jq -c '.agents[0] | {kind, calls: .whole.calls, bash: .whole.bash, first_in: .whole.first_in, usage: .whole.usage, message_len: .whole.message_len, wall_s: .whole.wall_s}' 2>/dev/null || printf '%s' "$J" | head -3)"
  fi
  if [ "$(printf '%s' "$J" | jq -r '.agents[0].whole.paths | join(" ")')" = ".autoflow/issue-179-ledger.md docs/autoflow-guide.md" ]; then
    pass "metrics: repo-relative paths named in Bash commands are collected per agent"
  else
    failc "metrics paths: $(printf '%s' "$J" | jq -c '.agents[0].whole.paths')"
  fi
  J="$(python3 "$METRICS" --label t --transcript "$FX/transcript-ended.md" "$FX/agent-participant.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "0" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].kind')" = "participant-dev" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].wakes')" = "2" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].segments | length')" = "2" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].segments[0].calls')" = "2" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].segments[1].calls')" = "1" ] \
     && [ "$(printf '%s' "$J" | jq -r '.agents[0].segments[1].first_cache_creation')" = "40" ] \
     && [ "$(printf '%s' "$J" | jq -r '.turns | length')" = "2" ] \
     && [ "$(printf '%s' "$J" | jq -r '.turns[0].message_len')" != "null" ]; then
    pass "metrics: a persistent participant is split into wakes at each coordinator message (2 wakes: 2 + 1 calls), the second wake's first-call cache_creation is its re-write, and --transcript supplies per-turn message lengths"
  else
    failc "metrics participant: rc=$RC $(printf '%s' "$J" | jq -c '.agents[0] | {kind, wakes, segs: [.segments[] | {calls, first_cache_creation}]}, .turns' 2>/dev/null || printf '%s' "$J" | head -3)"
  fi
  M="$(python3 "$METRICS" --label arm --markdown "$FX/agent-one-shot.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "0" ] && printf '%s' "$M" | grep -q '^### arm — run totals' && printf '%s' "$M" | grep -q '^| 1 | dev | 2 | 1 | 10.0 | 1.0 |'; then
    pass "metrics: --markdown renders the run-totals and per-turn tables"
  else
    failc "metrics markdown: rc=$RC $(printf '%s' "$M" | head -12 | tr '\n' '|')"
  fi
  python3 "$METRICS" --session "$FX/session-clean.jsonl" "$FX/agent-one-shot.jsonl" >/dev/null 2>&1; RC=$?
  if [ "$RC" != "0" ]; then pass "metrics: --session without --from/--to is refused"; else failc "metrics: --session without a window was accepted"; fi
  J="$(python3 "$METRICS" --session "$FX/session-clean.jsonl" --from 2026-09-05T09:00:00Z --to 2026-09-05T12:00:00Z "$FX/agent-one-shot.jsonl" 2>&1)"; RC=$?
  if [ "$RC" = "0" ] && [ "$(printf '%s' "$J" | jq -r '.orchestrator.calls')" = "1" ] && [ "$(printf '%s' "$J" | jq -r '.orchestrator.usage.cache_creation')" = "100" ]; then
    pass "metrics: --session with a window counts the orchestrator's own calls and usage inside it"
  else
    failc "metrics session: rc=$RC $(printf '%s' "$J" | jq -c '.orchestrator' 2>/dev/null)"
  fi
else
  failc "metrics: python3 is required and is not installed"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
