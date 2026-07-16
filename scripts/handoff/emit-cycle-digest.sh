#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/emit-cycle-digest.sh
#
# HANDOFF step 6.7 — cycle digest emission (issue #953).
# Serializes ONE canonical per-cycle digest record (feature design §4) from the
# terminal-cycle evidence and APPENDS it (append-only, never truncates) to the
# git-tracked file docs/cycle-digest.jsonl. Invoked by the step-6.7
# autoflow-analyzer subagent so schema/append behaviour is unit-testable without
# a live HANDOFF (tests/test-issue-953-cycle-digest.sh).
#
# The digest is a WRITE-ONLY-FORWARD data plane: this script reads the state
# file, ledger, and review-findings and writes the digest; nothing ever reads
# the digest back into a gate evaluation (feature design §5 [DENY]).
#
# Usage:
#   scripts/handoff/emit-cycle-digest.sh <issue-json> <ledger-md> <review-findings-md>
#     <issue-json>          .autoflow/issue-{N}.json  (terminal-cycle phases)
#     <ledger-md>           .autoflow/issue-{N}-ledger.md
#     <review-findings-md>  .autoflow/issue-{N}-review-findings.md  (optional)
#
# Precedent: scripts/handoff/create-host-pr.sh, scripts/review/codex-review-pr.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Append target — the durable, git-tracked digest file (feature design F2).
DIGEST="$REPO_ROOT/docs/cycle-digest.jsonl"

ISSUE_JSON="${1:-}"
LEDGER_MD="${2:-}"
FINDINGS_MD="${3:-}"

if [ -z "$ISSUE_JSON" ] || [ ! -f "$ISSUE_JSON" ]; then
  echo "emit-cycle-digest: missing or unreadable issue state file: $ISSUE_JSON" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Ledger-derived cross-cycle signal (survives review-response phases reset).
# Prose-parsed with tolerant defaults — an absent signal degrades to its
# neutral value rather than aborting the terminal write-point.
# ---------------------------------------------------------------------------
ROUNDS=0
ESCALATE=false
LOOP_CLASS=""
AUTOFIX=0

if [ -n "$LEDGER_MD" ] && [ -f "$LEDGER_MD" ]; then
  _r="$(grep -oiE 'rounds:?[[:space:]]*[0-9]+' "$LEDGER_MD" | grep -oE '[0-9]+' | tail -1 || true)"
  [ -n "$_r" ] && ROUNDS="$_r"
  if grep -qiE 'escalate:?[[:space:]]*true' "$LEDGER_MD"; then ESCALATE=true; fi
  _lc="$(grep -oiE 'loop.?check.?class:?[[:space:]]*[A-Za-z0-9_-]+' "$LEDGER_MD" \
          | sed -E 's/.*[:[:space:]]([A-Za-z0-9_-]+)$/\1/' | tail -1 || true)"
  case "$(printf '%s' "$_lc" | tr '[:upper:]' '[:lower:]')" in
    ""|none|null|n/a) LOOP_CLASS="" ;;
    *) LOOP_CLASS="$_lc" ;;
  esac
  AUTOFIX="$(grep -coF 'review-autofix' "$LEDGER_MD" || true)"
  [ -n "$AUTOFIX" ] || AUTOFIX=0
fi

# ---------------------------------------------------------------------------
# Review-findings-derived signal (Codex outcome). Absent file → clean default.
# ---------------------------------------------------------------------------
MAX_SEV="None"
ESCAPED='[]'

if [ -n "$FINDINGS_MD" ] && [ -f "$FINDINGS_MD" ]; then
  _sev="$(grep -oiE 'max_severity:?[[:space:]]*(None|Low|Medium|High|Critical)' "$FINDINGS_MD" \
           | grep -oiE '(None|Low|Medium|High|Critical)' | tail -1 || true)"
  if [ -n "$_sev" ]; then
    case "$(printf '%s' "$_sev" | tr '[:upper:]' '[:lower:]')" in
      none) MAX_SEV="None" ;; low) MAX_SEV="Low" ;; medium) MAX_SEV="Medium" ;;
      high) MAX_SEV="High" ;; critical) MAX_SEV="Critical" ;;
    esac
  fi

  # Escaped-defect items: each finding is a `- severity: <Sev>` list entry
  # followed by indented `key: value` lines (the same tolerant line grammar as
  # max_severity above; fields mirror the step-6.5 review-triage classification
  # of the Codex comment — .codex/review.md finding fields). Each block yields
  # one canonical item {class, nominal_rubric_item, surface, codex_anchor};
  # a field absent from a block degrades to "" (tolerant default). A findings
  # file with no `- severity:` entries leaves escaped_defects at [] (clean or
  # summary-only input).
  _items="$(awk '
    function flush() {
      if (inblock) {
        printf "%s\x1f%s\x1f%s\x1f%s\n", f["class"], f["nominal_rubric_item"], f["surface"], f["codex_anchor"]
        delete f
      }
      inblock = 0
    }
    /^[[:space:]]*-[[:space:]]*severity[[:space:]]*:/ { flush(); inblock=1; next }
    inblock && /^[[:space:]]+(class|nominal_rubric_item|surface|codex_anchor)[[:space:]]*:/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      k=line; sub(/[[:space:]]*:.*$/, "", k)
      v=line; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v)
      f[k]=v; next
    }
    inblock && /^[^[:space:]-]/ { flush() }
    END { flush() }
  ' "$FINDINGS_MD")"

  if [ -n "$_items" ]; then
    ESCAPED="$(printf '%s\n' "$_items" | jq -R -c -s '
      split("\n") | map(select(length > 0) | split("\u001f")
        | { class: (.[0] // ""), nominal_rubric_item: (.[1] // ""),
            surface: (.[2] // ""), codex_anchor: (.[3] // "") })
    ')"
  fi
fi

# ---------------------------------------------------------------------------
# Build the canonical §4 record. Per-gate objects take the pass-shape when the
# state file carries item scores, else the verdict-shape (gate_hypothesis_cause
# is verdict-only for feat issues). avg/items/below7 derive from the SAME raw
# phases.<gate>.scores object the gate hook averages — never a placeholder.
# ---------------------------------------------------------------------------
LINE="$(jq -c -n \
  --slurpfile issue "$ISSUE_JSON" \
  --argjson rounds "$ROUNDS" \
  --argjson escalate "$ESCALATE" \
  --arg loopclass "$LOOP_CLASS" \
  --argjson autofix "$AUTOFIX" \
  --arg maxsev "$MAX_SEV" \
  --argjson escaped "$ESCAPED" '
  ($issue[0]) as $s
  # Normalize a single score value to its number, matching the gate hook
  # accepted shapes (.claude/hooks/check-autoflow-gate.sh is_score): a bare
  # number OR an object {score: number}. Without this, a bare-number score
  # crashes .value.score (jq cannot index a number with "score") under
  # set -euo pipefail before the append (issue #953 RR cycle 2).
  | def snorm: if type == "number" then . else .score end;
  def gate($k):
      ($s.phases[$k] // {}) as $g
      | if (($g.scores // {}) | length) > 0
        then
          ($g.scores | to_entries) as $e
          | ($e | map(.value | snorm)) as $vals
          | ($e | map(select((.value | snorm) < 7) | .key)) as $below
          | { pass: ($below | length == 0),
              avg: (($vals | add) / ($vals | length)),
              items: ($e | map({key: .key, value: (.value | snorm)}) | from_entries),
              below7: $below }
        elif (($g.verdict // "") | length) > 0
        then { verdict: $g.verdict }
        else { verdict: "not-evaluated" }
        end;
  {
    issue: $s.issue,
    terminal_cycle: ($s.cycle // 1),
    date: $s.date,
    mode: ($s.mode // "new-issue"),
    gates: {
      gate_hypothesis_structure: gate("gate_hypothesis_structure"),
      gate_hypothesis_cause:     gate("gate_hypothesis_cause"),
      gate_plan:                 gate("gate_plan"),
      audit:                     gate("audit"),
      gate_quality:              gate("gate_quality")
    },
    # Per-gate regression counts are NOT derived (constant 0): the ledger has
    # no structured grammar to count them from — disclosed in the step-6.7
    # schema text (autoflow-guide.md); only review_autofix_cycles is derived.
    regressions: {
      gate_plan: 0, verify: 0, audit: 0, gate_quality: 0,
      review_autofix_cycles: $autofix
    },
    architect: { rounds: $rounds, escalate: $escalate },
    loop_check_class: (if ($loopclass | length) > 0 then $loopclass else null end),
    review_max_severity: $maxsev,
    escaped_defects: $escaped
  }
')"

# Append-only write (never a truncating redirect).
mkdir -p "$(dirname "$DIGEST")"
printf '%s\n' "$LINE" >> "$DIGEST"

ANCHOR_LINE="$(wc -l < "$DIGEST" | tr -d ' ')"
echo "docs/cycle-digest.jsonl:${ANCHOR_LINE}"
