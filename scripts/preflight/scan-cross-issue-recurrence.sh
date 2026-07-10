#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/preflight/scan-cross-issue-recurrence.sh
#
# PREFLIGHT step 1.5 — cross-issue complaint-class recurrence scan (issue #954).
# Deterministic, read-only tally over the durable, git-tracked corpus
# docs/cycle-digest.jsonl (#953). Counts, per normalized class token, the number
# of DISTINCT `issue` values it appears in within the last M records; a class
# recurring across >= K distinct issues is a breach and is emitted as a candidate
# finding for HUMAN promotion (Decision 4 — the scan never auto-modifies any
# rubric/criteria and never feeds a gate/evaluator).
#
# The corpus is EXCLUSIVELY docs/cycle-digest.jsonl. The scan does NOT read the
# gitignored .autoflow/ scratch as a corpus — .autoflow/* is per-issue, deleted
# at PREFLIGHT prior-cycle resolution, and cannot be a cumulative cross-issue
# store (feature design §2). This script is READ-ONLY w.r.t. every git-tracked
# file: both outputs go to stdout only; it writes nothing to disk.
#
# Class axes (both drawn from the existing #953 record, no schema change):
#   loop_check_class            (top-level string|null)  — axis "loop_check"
#   escaped_defects[].class     (array of objects)       — axis "escaped_defect"
# The two axes share one token namespace and are counted together (a complaint
# class and an escaped-defect class that normalize to the same token denote the
# same underlying rubric/rule deficiency); provenance keeps the axis.
#
# Usage:
#   scripts/preflight/scan-cross-issue-recurrence.sh [<digest-jsonl>] [<M>] [<K>] [--format=json|backlog]
#     <digest-jsonl>   path to the digest corpus   (default: docs/cycle-digest.jsonl)
#     <M>              recent-cycle window          (default: 20)
#     <K>              distinct-issue threshold     (default: 3)
#     --format=json    (default) the machine tally — a JSON array, one object per breached class
#     --format=backlog the rendered backlog `###` candidate block(s), one per breached class;
#                      empty output (nothing printed, exit 0) when no class breaches
#
# Scan date embedded in --format=backlog defaults to today; override with the
# env var XISSUE_SCAN_DATE (for byte-level golden-file assertion).
#
# Precedent: scripts/handoff/emit-cycle-digest.sh (pure, jq-based, unit-testable).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- argument parsing: positional digest/M/K in order, --format=* anywhere ----
FORMAT="json"
POS=()
for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    *)          POS+=("$arg") ;;
  esac
done

DIGEST="${POS[0]:-$REPO_ROOT/docs/cycle-digest.jsonl}"
M="${POS[1]:-20}"
K="${POS[2]:-3}"

case "$FORMAT" in
  json|backlog) ;;
  *) echo "scan-cross-issue-recurrence: unknown --format=$FORMAT" >&2; exit 2 ;;
esac
case "$M" in *[!0-9]*|'') echo "scan-cross-issue-recurrence: bad M=$M" >&2; exit 2 ;; esac
case "$K" in *[!0-9]*|'') echo "scan-cross-issue-recurrence: bad K=$K" >&2; exit 2 ;; esac

SCAN_DATE="${XISSUE_SCAN_DATE:-$(date +%F)}"

# --- tolerant absent/empty corpus (normal early-adoption state) ---------------
if [ ! -s "$DIGEST" ]; then
  [ "$FORMAT" = "json" ] && printf '[]\n'
  exit 0
fi

# --- tally: last M records -> class->witnesses -> distinct-issue threshold -----
TALLY="$(tail -n "$M" "$DIGEST" | jq -s --argjson K "$K" --argjson M "$M" '
  def norm: ascii_downcase | gsub("^\\s+|\\s+$"; "");
  [ .[] as $r
    | ( [ ($r.loop_check_class // empty)
          | select(type == "string")
          | { class: norm, axis: "loop_check", surface: "", codex_anchor: "", issue: $r.issue } ]
      + [ ($r.escaped_defects // [])[]
          | { class: ((.class // "") | norm), axis: "escaped_defect",
              surface: (.surface // ""), codex_anchor: (.codex_anchor // ""), issue: $r.issue } ] )[]
    | select(.class != "")
  ]
  | group_by(.class)
  | map({
      class: .[0].class,
      distinct_issues: (map(.issue) | unique),
      witnesses: map({ issue: .issue, axis: .axis, surface: .surface, codex_anchor: .codex_anchor })
    })
  | map(. + { count: (.distinct_issues | length), window: $M, threshold: $K })
  | map(select(.count >= $K))
  | sort_by(.class)
')"

if [ "$FORMAT" = "json" ]; then
  printf '%s\n' "$TALLY"
  exit 0
fi

# --- backlog render (§7 template). Digest-sourced tokens (class/surface/anchor)
# --- are sanitized against markdown-structure injection: backticks and CR/LF
# --- are stripped so a token cannot break out of its code span or block. -------
printf '%s' "$TALLY" | jq -r --arg DATE "$SCAN_DATE" --argjson M "$M" --argjson K "$K" '
  def san: gsub("[`\r\n]"; "");
  .[]
  | (.class | san) as $c
  | (.distinct_issues | map(san) | join(", ")) as $issues
  | "### `xissue-scan-\($c)-\($DATE)` — 클래스 `\($c)` 재발 (교차-이슈 누적 스캔, \(.count)개 이슈)\n"
  + "\n"
  + "- **분류**: (candidate) · cross-issue-recurrence\n"
  + "- **문제**: complaint/escaped-defect 클래스 `\($c)`가 최근 M(=\($M)) 사이클 digest 창에서 서로 다른 이슈 \(.count)(≥K=\($K))건 — \($issues) — 에 걸쳐 재발.\n"
  + "- **영향**: 단일 이슈 loop-check 범위 밖의 구조 신호 — rubric/rule 수준 체계 결함 후보.\n"
  + "- **권고**: (인간 검토·승격 대기) 해당 rubric 항목/rule을 점검. 자동 수정 없음(Decision 4).\n"
  + "- **검증**: 기계 방출(factual tally) · 인간 승격 대기 — 평가 기준 미변경.\n"
  + "- **근거 anchor**:\n"
  + "  - `docs/cycle-digest.jsonl` 내 witness 레코드 (axis 표기)\n"
  + ( [ .witnesses[]
        | "  - \(.issue | san) (axis: \(.axis))"
          + (if (.surface | san) != "" then " — surface `\(.surface | san)`" else "" end)
          + (if (.codex_anchor | san) != "" then " / anchor \(.codex_anchor | san)" else "" end)
      ] | join("\n") ) + "\n"
  + "- **재발 상태**: \(.count) distinct issues / window M=\($M) / threshold K=\($K) (스캔 일자 \($DATE))\n"
'
exit 0
