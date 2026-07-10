#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# epic-dash fetch script (gh CLI 경로)
# gh CLI로 이슈/PR/마일스톤/서브이슈/코멘트를 수집해서 .autoflow/issue-analysis/ 에 저장한다.
#
# 사용법: ./scripts/fetch.sh [--repo owner/repo] [--incremental]
#
# 의존: gh CLI(인증 완료), jq
#
# 종료 코드:
#   0  수집 성공
#   3  gh CLI 미설치/미인증 → 호출자(Claude)가 MCP 등 대체 경로로 폴백할 것
#   1  그 외 오류
#
# ※ 이 스크립트는 "gh가 있을 때 쓰는 한 가지 옵션"이다. gh가 없으면 강제로 중단시키지
#   않고 코드 3으로 신호만 보낸다. SKILL.md Step 0의 탐색→선택→폴백 흐름이 이를 처리한다.

set -uo pipefail   # -e 제거: 일부 수집(서브이슈/코멘트)이 실패해도 가능한 데이터로 계속 진행

# ── 인자 파싱 ──────────────────────────────────────────────────────────────
EXPLICIT_REPO=""
REPO_FLAG=""
INCREMENTAL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)    EXPLICIT_REPO="$2"; REPO_FLAG="--repo $2"; shift 2 ;;
    --incremental) INCREMENTAL=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── 사전 조건(비강제) ──────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "ℹ️ gh CLI 미설치 — gh 경로 사용 불가. 대체 경로(GitHub MCP)로 폴백하세요." >&2
  exit 3
fi
if ! gh auth status &>/dev/null; then
  echo "ℹ️ gh 미인증 — 'gh auth login' 또는 대체 경로(GitHub MCP)로 폴백하세요." >&2
  exit 3
fi
if ! command -v jq &>/dev/null; then
  echo "❌ jq 미설치 — 'brew install jq' 등으로 설치하세요." >&2
  exit 1
fi

# gh repo view는 --repo 플래그를 지원하지 않으므로 위치 인수 또는 현재 디렉터리 사용
if [[ -n "$EXPLICIT_REPO" ]]; then
  REPO="$EXPLICIT_REPO"
else
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
fi
if [[ -z "$REPO" ]]; then
  echo "ℹ️ 현재 디렉터리가 레포가 아닙니다. --repo owner/repo 를 지정하거나 git remote를 설정하세요." >&2
  exit 3
fi

echo "📦 레포: $REPO"

# ── 출력 디렉터리 ──────────────────────────────────────────────────────────
OUT=".autoflow/issue-analysis"
mkdir -p "$OUT"

# ── 오픈 이슈 수집 (milestone 포함) ────────────────────────────────────────
echo "📥 오픈 이슈 수집 중..."
gh issue list $REPO_FLAG \
  --state open \
  --limit 300 \
  --json number,title,body,labels,assignees,milestone,createdAt,updatedAt \
  > "$OUT/issues_open.json"

OPEN_COUNT=$(jq length "$OUT/issues_open.json")
echo "   → ${OPEN_COUNT}개 오픈 이슈"

# ── 완료 이슈 (milestone 포함) ─────────────────────────────────────────────
# [MUST] limit 은 누적 완료 이슈 전체를 덮을 만큼 충분히 크게 둔다. 너무 작으면 오래된 완료
# 이슈가 윈도 밖으로 잘려 그 멤버를 가진 완료 Epic 이 0/0 으로 표시·누락된다(완료 Epic 제거 금지 위반).
# 레포 누적 완료가 이 값에 근접하면 더 키운다(현재 Munsik-Park/autoflow ≈ 213개).
echo "📥 완료 이슈 수집 중..."
gh issue list $REPO_FLAG \
  --state closed \
  --limit 500 \
  --json number,title,labels,milestone,closedAt,stateReason \
  > "$OUT/issues_closed.json"

CLOSED_COUNT=$(jq length "$OUT/issues_closed.json")
echo "   → ${CLOSED_COUNT}개 완료 이슈"

# ── 오픈 PR ────────────────────────────────────────────────────────────────
echo "📥 오픈 PR 수집 중..."
gh pr list $REPO_FLAG \
  --state open \
  --json number,title,body,labels,isDraft,headRefName,baseRefName \
  > "$OUT/prs_open.json"

PR_COUNT=$(jq length "$OUT/prs_open.json")
echo "   → ${PR_COUNT}개 오픈 PR"

# ── 마일스톤 목록 ──────────────────────────────────────────────────────────
echo "📥 마일스톤 수집 중..."
gh api "repos/$REPO/milestones?state=all&per_page=100" \
  --jq '[.[] | {number, title, state, due_on, open_issues, closed_issues}]' \
  > "$OUT/milestones.json" 2>/dev/null || echo "[]" > "$OUT/milestones.json"
MS_COUNT=$(jq length "$OUT/milestones.json" 2>/dev/null || echo 0)
echo "   → ${MS_COUNT}개 마일스톤"

# ── 변경 이슈 집합 결정 (증분) ─────────────────────────────────────────────
# 직전 실행 타임스탬프를 (덮어쓰기 전에) 읽어 둔다. 벌크 이슈/PR fetch 는 항상 전체이고,
# 비싼 것은 이슈별 루프(서브이슈/코멘트)이므로 증분은 그 두 루프만 변경 이슈로 좁힌다.
PREV_TS=""
[[ -f "$OUT/last-updated.txt" ]] && PREV_TS=$(cat "$OUT/last-updated.txt" 2>/dev/null || true)
ISSUE_NUMS=$(jq -r '.[].number' "$OUT/issues_open.json")
if [[ "$INCREMENTAL" == true && -n "$PREV_TS" && -s "$OUT/sub_issues.json" ]]; then
  LOOP_NUMS=$(jq -r --arg ts "$PREV_TS" '.[] | select((.updatedAt // "") > $ts) | .number' "$OUT/issues_open.json")
  INCR_ACTIVE=true
  echo "🔄 증분: $PREV_TS 이후 변경 이슈 $(echo -n "$LOOP_NUMS" | grep -c . || true)건만 서브이슈/코멘트 재조회 (나머지는 직전 결과 재사용)"
else
  LOOP_NUMS="$ISSUE_NUMS"
  INCR_ACTIVE=false
fi
export REPO REPO_FLAG

# ── 서브이슈(GitHub 네이티브) 수집 (병렬, best-effort) ──────────────────────
# sub_issues 는 이슈별 엔드포인트뿐(벌크 없음)이라 변경 대상만 -P 10 병렬 조회한다.
echo "📥 서브이슈(네이티브) 수집 중 (병렬, best-effort)..."
SUB_FILE="$OUT/sub_issues.json"
_fetch_sub() {
  local subs
  subs=$(gh api "repos/$REPO/issues/$1/sub_issues" --jq '[.[].number]' 2>/dev/null || echo "")
  [[ -n "$subs" && "$subs" != "[]" ]] && jq -nc --argjson parent "$1" --argjson children "$subs" '{parent:$parent,children:$children}'
}
export -f _fetch_sub
# pipefail 하에서 xargs 가 일부 비-0 종료(서브이슈 없는 이슈)해도 jq 출력이 권위를 갖도록 분리.
set +o pipefail
NEW_SUBS=$(echo "$LOOP_NUMS" | grep . | xargs -P 10 -I{} bash -c '_fetch_sub "$@"' _ {} | jq -s '.' 2>/dev/null)
set -o pipefail
echo "$NEW_SUBS" | jq -e . >/dev/null 2>&1 || NEW_SUBS="[]"
if [[ "$INCR_ACTIVE" == true ]]; then
  # 직전 결과 중 (여전히 열려있고 && 이번에 재조회하지 않은) 부모만 보존 + 신규 변경분
  OPEN_ARR=$(echo "$ISSUE_NUMS" | grep . | jq -R 'tonumber' | jq -s . 2>/dev/null || echo '[]')
  LOOP_ARR=$(echo "$LOOP_NUMS" | grep . | jq -R 'tonumber' | jq -s . 2>/dev/null || echo '[]')
  jq -n --argjson prev "$(cat "$SUB_FILE" 2>/dev/null || echo '[]')" --argjson new "$NEW_SUBS" \
        --argjson open "$OPEN_ARR" --argjson loop "$LOOP_ARR" \
     '($prev | map(select((.parent as $p | $open|index($p)) and ((.parent as $p | $loop|index($p))|not)))) + $new' \
     > "$SUB_FILE.tmp" && mv "$SUB_FILE.tmp" "$SUB_FILE"
else
  echo "$NEW_SUBS" > "$SUB_FILE"
fi
SUB_COUNT=$(jq length "$SUB_FILE" 2>/dev/null || echo 0)
echo "   → ${SUB_COUNT}개 이슈에 서브이슈 존재"

# ── 이슈별 코멘트 수집 (병렬, 본문에 의존 키워드 없는 이슈만) ───────────────
# 후보 선별은 단일 jq 패스(이슈마다 전체 파일 재파싱 제거), API 조회는 -P 10 병렬.
echo "📥 이슈 코멘트 수집 중 (의존성 키워드 탐지용, 병렬)..."
COMMENT_FILE="$OUT/issue_comments.json"
[[ -f "$COMMENT_FILE" ]] || echo "[]" > "$COMMENT_FILE"
CAND_NUMS=$(jq -r '.[] | select(((.body // "") | test("blocks|part of|depends on|완료 후|머지 후|의존|#[0-9]+|/[A-Za-z0-9_.-]+#[0-9]+";"i"))|not) | .number' "$OUT/issues_open.json")
if [[ "$INCR_ACTIVE" == true ]]; then
  CAND_NUMS=$(comm -12 <(echo "$CAND_NUMS" | sort -n) <(echo "$LOOP_NUMS" | sort -n))
fi
_fetch_comments() {
  gh issue view $REPO_FLAG "$1" --json comments -q '.comments[] | {issueNumber: '"$1"', body: .body}' 2>/dev/null || true
}
export -f _fetch_comments
set +o pipefail
NEW_COMMENTS=$(echo "$CAND_NUMS" | grep . | xargs -P 10 -I{} bash -c '_fetch_comments "$@"' _ {} | jq -s '.' 2>/dev/null)
set -o pipefail
echo "$NEW_COMMENTS" | jq -e . >/dev/null 2>&1 || NEW_COMMENTS="[]"
if [[ "$INCR_ACTIVE" == true ]]; then
  LOOP_ARR=$(echo "$LOOP_NUMS" | grep . | jq -R 'tonumber' | jq -s . 2>/dev/null || echo '[]')
  jq -n --argjson prev "$(cat "$COMMENT_FILE" 2>/dev/null || echo '[]')" --argjson new "$NEW_COMMENTS" --argjson loop "$LOOP_ARR" \
     '[ $prev[]? | select((.issueNumber as $i | $loop|index($i))|not) ] + $new' \
     > "$COMMENT_FILE.tmp" && mv "$COMMENT_FILE.tmp" "$COMMENT_FILE"
else
  echo "$NEW_COMMENTS" > "$COMMENT_FILE"
fi
CMT_COUNT=$(jq length "$COMMENT_FILE" 2>/dev/null || echo 0)
echo "   → 코멘트 ${CMT_COUNT}건 수집"

# ── 타임스탬프 저장 ────────────────────────────────────────────────────────
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$OUT/last-updated.txt"

# ── 메타 정보 저장 ─────────────────────────────────────────────────────────
cat > "$OUT/meta.json" <<EOF
{
  "repo": "$REPO",
  "source": "gh-cli",
  "fetched_at": "$(cat "$OUT/last-updated.txt")",
  "open_issues": $OPEN_COUNT,
  "closed_issues": $CLOSED_COUNT,
  "open_prs": $PR_COUNT,
  "milestones": $MS_COUNT,
  "issues_with_sub": $SUB_COUNT,
  "incremental": $INCREMENTAL
}
EOF

echo ""
echo "✅ 수집 완료 → $OUT/"
echo "   파일: issues_open / issues_closed / prs_open / milestones / sub_issues / issue_comments / meta"
echo "   다음 단계: Claude가 deps.json 생성 후 HTML 빌드"
