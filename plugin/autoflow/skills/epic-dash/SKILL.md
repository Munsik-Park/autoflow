---
name: epic-dash
description: GitHub 이슈를 수집해 의존성을 분석하고 HTML 대시보드를 생성한다. 라벨·마일스톤·태스크리스트·서브이슈·서브레포 참조 등 명시적 신호와 이슈 본문/코멘트 맥락을 함께 분석해 Wave(착수 순서)를 계산하고, 어떤 이슈를 먼저 시작할지 추천한다. "이슈 의존성 분석", "에픽 대시보드", "이슈 현황 HTML", "다음에 뭘 작업할지", "epic-dash", "이슈 정리해서 보여줘" 등의 요청에 사용. gh CLI / GitHub MCP / git remote 중 가능한 경로로 데이터를 가져온다.
---

# epic-dash

GitHub 이슈를 수집하고 LLM으로 의존성을 분석해서 HTML 대시보드를 생성하는 Claude Code 스킬.
레포 내 `.autoflow/issue-analysis/` 에 분석 결과를 저장하고 `epic_status.html` 을 생성/갱신한다.

데이터 수집은 **접근 수단을 강제하지 않는다.** Claude가 사용 가능한 경로를 탐색해서
(gh CLI → GitHub MCP → git remote 순) 되는 것으로 가져온다. 셋 다 없을 때만 사용자에게 안내한다.

의존성 신호는 **명시적 표시(라벨·마일스톤·태스크리스트·서브이슈·서브레포 참조)** 와
**이슈 맥락(body·코멘트 LLM 분석)** 을 함께 사용한다.

## 사용법

```
/epic-dash                           # 현재 레포, 기본 경로
/epic-dash --output docs/dash.html   # 출력 경로 지정
/epic-dash --incremental             # 변경된 이슈만 재분석 (빠름)
/epic-dash --repo owner/repo         # 현재 디렉터리가 레포가 아닐 때
```

---

## Step 0: 접근 경로 탐색 → 선택 → 폴백

접근 수단을 강제하지 않는다. Claude가 아래 순서로 **사용 가능한 경로를 탐색**해서 되는 것을 고른다.

```bash
# 1) gh CLI 경로 (가장 단순) — 설치 + 인증 동시 확인
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && echo "GH_OK"

# 2) 레포 식별 (--repo 미지정 시): gh → git remote 순
# ⚠️ gh repo view 는 --repo 플래그를 지원하지 않는다. 위치 인수 또는 현재 디렉터리를 사용한다.
gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null \
  || git remote get-url origin 2>/dev/null \
     | sed -E 's#(git@|https://)github.com[:/]##; s#\.git$##'
```

> **주의:** `gh repo view --repo owner/repo` 는 오류가 난다(`unknown flag: --repo`).
> `--repo` 플래그는 `gh issue list`, `gh pr list`, `gh api` 등에서는 지원되지만
> `gh repo view` 에서는 지원되지 않는다. 레포를 명시할 때는 `gh repo view owner/repo`
> (위치 인수) 또는 `EXPLICIT_REPO` 변수에 직접 저장해 후속 명령에 `--repo "$EXPLICIT_REPO"` 로 전달한다.
> `scripts/fetch.sh` 는 이 방식으로 구현되어 있다.

**선택 규칙:**

| 조건 | 사용 경로 |
|------|-----------|
| `GH_OK` 출력됨 | `scripts/fetch.sh` 실행 (gh CLI 경로) |
| gh 없음/미인증 + GitHub MCP 도구 사용 가능 | MCP 도구로 수집 (Step 1의 MCP 매핑 참고) |
| gh 없음 + git remote만 존재 | remote에서 owner/repo만 추출 후 → MCP 경로 시도 |
| 위 어느 것도 불가 | **그제서야** 사용자에게 `gh auth login` 또는 GitHub MCP 설정 안내 |

> `scripts/fetch.sh` 는 gh가 없거나 미인증이면 **종료 코드 3** 을 반환한다(중단이 아님).
> 코드 3을 받으면 Claude는 MCP 경로로 폴백한다. 가능한 데이터만으로도 분석을 진행한다.

출력 디렉터리 생성:
```bash
mkdir -p .autoflow/issue-analysis
```

---

## Step 1: 이슈 & PR 데이터 수집

### gh CLI 경로 (권장, 자동)
`scripts/fetch.sh` 한 번으로 아래를 모두 수집한다.

```bash
./scripts/fetch.sh [--repo owner/repo] [--incremental]
```

수집 산출물(`.autoflow/issue-analysis/`):

| 파일 | 내용 |
|------|------|
| `issues_open.json` | 오픈 이슈 — number,title,body,labels,assignees,**milestone**,createdAt,updatedAt |
| `issues_closed.json` | 완료 이슈 — number,title,labels,**milestone**,closedAt,stateReason |
| `prs_open.json` | 오픈 PR — number,title,body,labels,isDraft,headRefName,baseRefName |
| `milestones.json` | 마일스톤 — number,title,state,due_on,open/closed_issues |
| `sub_issues.json` | GitHub 네이티브 서브이슈 `{parent, children:[..]}` (best-effort) |
| `issue_comments.json` | 의존성 키워드 후보 이슈의 코멘트 |
| `meta.json` | 레포·수집 시각·카운트 |

### GitHub MCP 경로 (gh 폴백)
gh가 없을 때 동일 데이터를 MCP 도구로 수집한다. 대응 매핑:

| gh / 데이터 | GitHub MCP 도구 |
|-------------|-----------------|
| 오픈/완료 이슈 목록 | `list_issues` (state별 호출, milestone 필드 포함) |
| 이슈 본문·라벨·마일스톤 | `get_issue` |
| 코멘트 | `get_issue` (코멘트 포함) / 이슈 코멘트 조회 |
| 오픈 PR | `list_pull_requests` |
| 서브이슈 / 마일스톤 | MCP가 미지원이면 생략하고 body의 태스크리스트 파싱으로 대체 |

수집 결과는 gh 경로와 **동일한 JSON 스키마**로 `.autoflow/issue-analysis/` 에 저장해
이후 단계가 경로와 무관하게 동작하도록 한다. `meta.json` 의 `source` 에 `mcp` 를 기록한다.

### `--incremental` 모드일 때
`.autoflow/issue-analysis/last-updated.txt` 의 타임스탬프를 읽어서
`updatedAt` 이 그 이후인 이슈만 재분석한다. 나머지는 기존 `deps.json` 값 유지.

---

## Step 2: Epic 구조 파악 (라벨 + 마일스톤 + 서브이슈)

> **결정적 파이프라인 (Step 2~6).** 이 레포의 자동 분해 이슈는 본문에 구조화된 `선행 의존(deps)` 필드를
> 선언하므로, Step 2~6은 체크인된 결정적 스크립트로 재현 가능하게 구현되어 있다. fetch 후:
> ```bash
> # 스크립트 위치를 설치 채널에 무관하게 해석한다.
> #  - 플러그인 채널: 로더가 ${CLAUDE_PLUGIN_ROOT} 를 skill content 안에서 실제 경로로 인라인 치환 →
> #    첫 후보가 실재 디렉터리로 히트.
> #  - 프로젝트(.claude) 채널: ${CLAUDE_PLUGIN_ROOT} 는 치환되지 않아(플러그인 아님) 빈/부재 →
> #    -d 실패로 다음 후보($PWD/.claude/...)로 폴백. (cd 이전이라 $PWD = 레포 루트)
> for S in \
>   "${CLAUDE_PLUGIN_ROOT}/skills/epic-dash/scripts" \
>   "$PWD/.claude/skills/epic-dash/scripts"; do
>   [ -d "$S" ] && break
> done
> cd .autoflow/issue-analysis
> python3 "$S/extract_deps.py"                 # Step 3: 본문 deps 필드 → deps.json/deps_parsed.json
> python3 "$S/build_pipeline.py"               # Step 2+4: epics.json + execution-order.json
> python3 "$S/render_dash.py" . ../epic_status.html   # Step 5+6: HTML
> ```
> 스크립트는 CWD=`.autoflow/issue-analysis` 기준으로 동작한다. 아래 산문은 각 스크립트가 *무엇을* 계산하는지의
> 사양이며, **`선행 의존(deps)` 관례가 없는 레포에서는 Step 3의 LLM 추론으로 대체**한다(스크립트는 그 경우 엣지가 비므로 폴백 필요).

다음 세 가지 명시적 신호를 결합해 그룹 구조를 만든다.

**(a) 레이블 패턴** — `issues_open.json`

| 패턴 | 의미 |
|------|------|
| `epic` | 이 이슈 자체가 Epic tracker (부모) |
| `epic-N` | 이슈 #N epic의 서브이슈 |
| `epic-N + epic` | mini-epic tracker (중간 계층) |
| `blocked-by-subrepo` | PR이 서브리포 머지 대기 (HANDOFF 상태) |
| `priority:high` | 긴급, 즉시 처리 권장 |
| `bug` | 버그 수정 |
| `claude` | AutoFlow 자동화 대상 |

**(b) 마일스톤** — `milestones.json` + 이슈의 `milestone` 필드
- 마일스톤은 **릴리스/단계 단위 그룹**으로 사용한다. 라벨 epic이 없는 이슈는 마일스톤으로 묶는다.
- 같은 마일스톤 + `due_on` 순서는 **약한 순서 신호**(soft ordering)로 Step 3에 넘긴다.

**(c) 네이티브 서브이슈** — `sub_issues.json`
- `{parent, children}` 는 라벨 epic보다 **강한 부모-자식 관계**다. 라벨 epic과 충돌하면 서브이슈를 우선한다.

Epic 그룹 맵 생성 (`.autoflow/issue-analysis/epics.json`):
```json
{
  "epics": {
    "72": { "tracker": 72, "sub_issues": [210, 211, 212], "source": "label+sub_issue" },
    "73": { "tracker": 73, "sub_issues": [225, 226, 228], "source": "label" }
  },
  "milestones": {
    "v1.0": { "number": 3, "issues": [62, 70], "due_on": "2026-06-30" }
  },
  "unepiced": [65, 66, 76, 77]
}
```

---

## Step 3: 의존성 추출 — LLM 추론이 핵심 (★)

**이 단계의 본질은 LLM이 이슈를 읽고 "무엇이 무엇을 선행해야 하는가"를 추론하는 것이다.**
라벨·태스크리스트 같은 명시적 신호는 **출발점일 뿐**, 그것만으로 끝내면 안 된다(그러면 LLM이
필요 없다 — 라벨 그루핑에 불과해진다). 반드시 각 이슈의 `body` 와 `comments` 를 읽고
**내용 기반으로 선후관계를 추론**한다.

명시적 의존 표시가 전혀 없어도, 다음 같은 **논리적 선행관계를 LLM이 추론해서 엣지로 만든다:**
- 공통 스키마/DB/타입을 정의하는 이슈 → 그걸 쓰는 이슈보다 선행
- API 계약/인터페이스 → 그 API를 소비하는 프론트/연동 이슈보다 선행
- 인증·권한·기반 인프라 → 그 위에 얹히는 기능 이슈보다 선행
- 같은 화면/도메인을 만지는 이슈 간 자연스러운 순서

**모든 엣지에는 `reason`(왜 이 의존이 성립하는지)을 반드시 단다.** reason 없는 엣지는 만들지 않는다.
엣지가 0개로 나오면 분석을 덜 한 것이다 — 이슈 내용을 다시 읽고 논리적 선행관계를 찾는다.

아래 A(명시적)·B(맥락 추론) 신호를 **합쳐** 엣지 집합을 만든다. 핵심 가치는 B에 있다.

### A. 명시적 신호 (deterministic — 가능한 한 코드로 파싱)

**A-1. 네이티브 서브이슈** (`sub_issues.json`, confidence 1.0, `type:"sub_issue"`)
- `{parent, children}` → 각 child 가 parent의 구성요소. parent 완료는 children 완료에 의존.
- 엣지: parent `from` → 각 child `to` (parent는 children이 끝나야 닫힘).

**A-2. 태스크리스트** (`body` 파싱, confidence 1.0, `type:"tasklist"`)
- 마크다운 체크박스 + 이슈 참조: `- [ ] #N`, `- [x] #N`
- 정규식: `^\s*[-*]\s+\[[ xX]\]\s+.*#(\d+)` (같은 레포) / `#(\d+)` 토큰 추출
- 부모 이슈 `from` → 체크박스의 각 #N `to`. `[x]`는 이미 완료로 표시.

**A-3. 키워드 참조** (`body`+`comments`, confidence 1.0, `type:"keyword"`)
- `Blocks #N`, `Closes #N`, `Fixes #N`, `Resolves #N`
- `Blocked by #N`, `Part of #N`, `Depends on #N`

**A-4. 서브레포 / cross-repo 참조** (confidence 1.0, `type:"cross_repo"`, `external:true`)
- 정규식: `([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#(\d+)` → 다른 레포 이슈 참조
- `blocked-by-subrepo` 라벨이 있는 이슈/PR → 외부 서브레포 머지 대기(HANDOFF)
- 엣지의 `to` 를 `"owner/repo#N"` 문자열로 기록하고 `external:true`. 위상 정렬에서는
  외부 노드를 "미완료 차단자"로 취급(레포 밖이라 상태 불명 → 기본 blocked).

**A-5. 구조화 `선행 의존(deps)` 필드** (`body` 파싱, `type:"hard_dep"`/`"mockable_dep"`, `kind:"hard"`/`"mockable"`)
- 이 레포의 자동 분해 이슈는 본문에 `- **선행 의존(deps)**: \`#67-S2b\`·hard, \`#64\`·mockable` 형태로 의존을
  **명시 선언**한다. 이는 LLM 추론이 아니라 팀의 분해 분석이 만든 **권위적 선언**이므로 deterministic 추출한다(추론으로 덮어쓰지 않는다).
- `hard` = 차단(in-degree 카운트, confidence 1.0), `mockable` = 목킹 가능 소프트 의존(병렬 착수 가능 → in-degree 비카운트, 순서 힌트, confidence 0.6).
- 슬라이스ID(`#67-S2b`)는 `slice_map` 으로 이슈번호(#312)로 해석한다.
- **[MUST] 에픽 트래커를 향한 `hard` 선행은 그 에픽의 `S0` 셸 슬라이스로 해석한다.** 예: `#62·hard` → `#62-S0`=#281.
  트래커(#62)는 작업노드가 아니라 위상정렬·그래프에서 누락되어 의존이 통째로 사라지므로, 반드시 구체 `S0` 슬라이스로 치환해야
  후행 이슈(#300)가 #281 완료 전까지 "대기"로 올바르게 표시된다. `mockable` 의 트래커 참조(#64·#71 등 인터페이스)는 그대로 둔다(병렬 노트 표시용).
- 구현: `scripts/extract_deps.py`. (B-1 의 `선행 의존: #N` 비구조 패턴보다 우선 — 본 필드는 명시적 A 신호다.)

### B. 맥락 신호 (LLM — body·comments 해석)

**B-1. 한국어 패턴** (confidence 0.9, `type:"context"`)
- `#N 완료 후`, `#N 머지 후`, `#N 기반`, `S0 완료 후`, `Wave 1 완료 후`, `파동 1`
- `선행 의존: #N`, `의존: #N`

**B-2. 슬라이스 계층** (confidence 0.8, `type:"context"`)
- 같은 epic 내 S0→S1f, S0b→S5a 같은 번호 참조
- "모든 frontend 슬라이스가 S0에 hard depends_on" 류의 서술

**B-3. 암시적** (confidence 0.7, `type:"context"`)
- `requires`, `prerequisite`, `전제`, `선행`, 공통 스키마/인터페이스 선행 정의 관계

**B-4. 마일스톤 순서** (confidence 0.5, `type:"milestone_order"`, soft)
- 같은 트랙에서 `due_on` 이 빠른 마일스톤의 이슈가 선행. **약한 신호**라 위상 정렬에서
  하드 엣지로 쓰지 않고 동순위(tie) 정렬 힌트로만 사용한다.

confidence 0.6 미만(B-4 포함)은 **순서 힌트로만** 쓰고 하드 의존 엣지로 저장하지 않는다.
명시적(A)과 맥락(B)이 같은 쌍을 가리키면 **높은 confidence + `type` 병합**으로 1개 엣지만 남긴다.

결과를 `.autoflow/issue-analysis/deps.json` 으로 저장:

```json
{
  "analyzed_at": "2026-05-31T12:00:00Z",
  "repo": "owner/repo",
  "edges": [
    { "from": 72, "to": 210, "confidence": 1.0, "type": "sub_issue",  "reason": "네이티브 서브이슈" },
    { "from": 68, "to": 63,  "confidence": 1.0, "type": "tasklist",   "reason": "체크박스 - [ ] #63" },
    { "from": 227,"to": 225, "confidence": 1.0, "type": "keyword",    "reason": "Depends on #225" },
    { "from": 89, "to": "example-org/infra#12", "confidence": 1.0,
      "type": "cross_repo", "external": true, "reason": "blocked-by-subrepo" }
  ],
  "issue_states": { "225": "open", "226": "open" }
}
```

**엣지 방향:** `from` 이슈가 `to` 이슈에 의존한다. 즉 `to` 가 먼저 완료되어야 `from` 을 시작할 수 있다.
`external:true` 인 `to` 는 레포 밖 노드로, 기본적으로 미완료(차단)로 간주한다.

---

## Step 4: 위상 정렬 (Wave = 의존 계층)

Wave는 단순 묶음이 아니라 **의존 계층**이다. 같은 Wave 안의 이슈는 서로 의존이 없어
**독립적·병렬로 실행 가능**하고, 다음 Wave는 이전 Wave가 끝나야 시작된다. 이 계층 구분이
"지금 동시에 착수 가능한 것"과 "아직 막힌 것"을 가른다.

`deps.json` 의 엣지를 기반으로 Kahn's algorithm으로 위상 정렬한다.

> **점검:** 모든 이슈가 Wave 1 한 줄에 평탄하게 들어가고 엣지가 0개면, 이는 정상이 아니라
> **Step 3에서 의존성 추론을 안 한 신호**다. 계층이 전혀 없다는 건 곧 의존성 분석이 비었다는 뜻이므로,
> Step 3로 돌아가 이슈 내용을 다시 읽고 선행관계를 추론한다.

1. 각 오픈 이슈의 in-degree 계산. 단:
   - 이미 `closed` 인 `to` 엣지는 충족된 것으로 보고 카운트하지 않는다.
   - `external:true` 인 `to`(서브레포)는 상태 불명 → **미충족(차단)** 으로 카운트한다.
     해당 이슈는 HANDOFF로 표시하고 Wave에 넣지 않는다.
   - `confidence < 0.6` / `type:"milestone_order"` 엣지는 in-degree에 넣지 않는다(순서 힌트 전용).
   - **`hard` 엣지는 같은 epic이든 다른 epic이든 모두 in-degree에 포함한다**(cross-epic 차단 포함). 단
     트래커 대상 `hard` 는 Step 3 A-5에 따라 `S0` 슬라이스로 치환된 뒤라야 카운트된다(트래커는 작업노드가 아니므로 치환 전이면 누락). 구현: `scripts/build_pipeline.py`.
2. in-degree = 0 인 이슈 → Wave 1 (즉시 착수 가능)
3. Wave 1 제거 후 in-degree = 0 이 된 이슈 → Wave 2
4. 반복
5. 동일 Wave 내 정렬은 `milestone_order`(due_on) 힌트 → `priority:high` 순으로 tie-break.

### 우선순위 티어 & 동결(Deferred) — `priority:*` 라벨 반영

Wave는 "무엇이 풀렸나(의존)"를 답하지만, "무엇을 먼저 하나(우선순위)"는 `priority:*`
라벨로 결정한다. `build_pipeline.py` 가 각 오픈 슬라이스에 티어를 매긴다:
`priority:high`→**P0**, `priority:medium`→**P1**, `priority:low`→**동결(deferred)**, 무라벨→`none`.

- **[중요] 동결(`priority:low`) 슬라이스는 `work_nodes`에서 제외**되어 Wave 위상정렬과
  착수 추천에 들어가지 않는다(백로그로 보존, 별도 ❄️ Deferred 밴드로 렌더). 라벨만으로
  동결이 Wave 1에 "즉시 착수"로 잘못 노출되던 문제를 차단한다.
- `execution-order.json` 에 `deferred`(동결 이슈 번호 목록)와 `issue_tier`(이슈→티어 맵)를
  추가 기록한다. `epics.json` 의 각 epic에 `tier`(열린 멤버 기준 P0/P1/deferred/none)를 기록한다.
- 렌더(Step 5)는 진행 중 Epic을 **티어 헤더(🔥 P0 → 🟡 P1 → 미지정)** 로 묶고, 동결 epic은
  **❄️ 동결 섹션**으로 분리(회색·점선)한다. 착수 추천은 **티어(P0→P1) → 영향도 → 깊이** 순.

순환 의존성 감지 시: `cycle_detected: true` 기록 + 사용자에게 경고.

결과를 `.autoflow/issue-analysis/execution-order.json` 으로 저장:

```json
{
  "waves": [
    {
      "wave": 1,
      "issues": [210, 211, 212, 213, 225, 226, 228, 230, 233],
      "parallel": true
    },
    {
      "wave": 2,
      "issues": [216, 227, 229, 231, 232, 234],
      "parallel": true
    }
  ],
  "cycle_detected": false
}
```

---

## Step 5: HTML 대시보드 생성

### 설계 원칙 (그리기 전 반드시 준수)

이 화면은 **"다음 작업 추천 시스템"이 아니라 프로젝트 현황 대시보드**다. 목적은 전체 이슈
현황과 진행 상태를 한눈에 파악하게 하는 것. 개별 추천보다 **전체 맥락을 우선** 제공하고,
사용자가 현재 상태를 이해한 뒤 스스로 무엇을 할지 판단하게 한다.

1. **정보 우선순위** — 전체 현황 > 개별 이슈 추천. 추천이 화면을 지배하지 않게 한다.
2. **"다음 작업" 영역은 보조 기능** — 의사결정을 대신하지 않는다. 현재 상태를 근거로
   *즉시 착수 가능 / 의존성 해소됨 / 영향도 높음(다수 unblock) / 병렬 가능* 이슈를 빨리 발견하게만 돕는다.
3. **선택적 시각 강조** — 모든 이슈를 같은 강도로 그리지 않는다. 다음만 강조한다:
   즉시 시작 가능, 다수 후속작업 unblock, 핵심 경로 위치, 병목 해소 효과 큼.
   단 강조가 **전체 현황 파악을 방해하지 않는 수준**으로만.
4. **Epic 카드 = 기본 단위** — 카드만 보고도 진행률·활성 작업·대기·완료·병목·예상 흐름을 이해할 수 있어야 한다.
5. **의존성 그래프는 단순하게** — 목적은 "무엇이 무엇을 막는가"를 보여주는 것. 복잡한 DAG 자체를
   과시하지 않는다. **진행 중 Epic 중심**으로 단순화한다.
6. **10초 테스트** — 화면을 연 사용자가 10초 안에 다음 다섯 질문에 답할 수 있는 구조를 유지한다:
   ① 프로젝트는 어느 정도 진행됐나 ② 진행 중 Epic은 무엇인가 ③ 병목은 어디인가
   ④ 지금 바로 시작 가능한 작업은 무엇인가 ⑤ 가장 영향이 큰 작업은 무엇인가

아래 구조로 HTML 파일을 생성한다. 기존 파일이 있으면 덮어쓴다.

### 전체 레이아웃

```
<header>  레포명 · 갱신 일시
<overall> 전체 Epic 진행률 바
<legend>  색상 범례
<section> ✅ 완료된 Epic  (항상 표시 — 제거 금지, 접힘 가능)
<section> 🔧 진행 중인 Epic (Wave 구조)
<section> 🔗 의존성 그래프 (SVG)
<section> 🚀 개발자 배분 권장
<footer>  갱신 요약
```

### 색상 코딩 (CSS variables)

```css
background:  #0d1117
card:        #161b22
border:      #30363d

진행 중:     stroke #8957e5, fill #2d1b4e, text #bc8cff   /* 담당자/PR 있음 — 누가 작업 중 */
즉시 시작:   stroke #1f6feb, fill #0d2a4a, text #58a6ff   /* 미배정 + 의존 해소 — 아무도 안 함 */
대기 중:     stroke #30363d, fill #21262d, text #7d8590   /* 선행 미완료로 막힘 */
완료:        stroke #238636, fill #1a4429, text #3fb950
긴급/버그:   stroke #f85149, fill #2d0000, text #ff7b72
리뷰 대기:   stroke #bd561d, fill #2d1f00, text #f0883e
외부 대기:   stroke #9e6a03, fill #2d1f00, text #d29922   /* 서브레포 HANDOFF */
```

**색으로 4상태를 반드시 구분한다:** 완료(초록) · **진행 중=담당자/PR 있음(보라)** ·
**즉시 시작=미배정인데 막힌 게 없음(파랑)** · 대기=선행에 막힘(회색).
"진행 중"과 "즉시 시작(아무도 안 함)"이 같은 색이면 안 된다.

### Epic 카드 구조 (진행 중)

**진행 중 Epic 카드는 그 Epic에 속한 모든 이슈를 한 카드 안에 나열한다.** 완료된 이슈를
별도 섹션으로 빼내지 말고, 같은 카드 안에서 **색만 다르게(`done` 초록)** 표시한다. 그래야
"이 Epic이 어디까지 됐는지"가 카드 하나로 보인다. 권장 그룹 순서:

1. ✅ 완료 (`done`, 접힘 가능하나 카드 안에 유지)
2. 🟣 진행 중 (`inprogress`)
3. ⚡ 즉시 시작 가능 (`ready`)
4. ⏳ 대기 / 외부 대기 (`todo` / `split`)

각 issue-row 의 `status-dot` 와 `tag` 색으로 4상태를 구분한다(완료/진행 중/즉시 시작/대기).

```html
<div class="epic-card">
  <div class="epic-header">
    <span class="epic-icon">{아이콘}</span>
    <span class="epic-title">epic-N · {제목}</span>
    <span class="epic-badge open-badge">{완료수}/{전체} 완료</span>
  </div>
  <div class="issue-list">
    <!-- Wave별 divider와 issue-row 반복 -->
    <div class="divider"><span class="divider-label">⚡ Wave 1 — 즉시 시작</span></div>
    <div class="issue-row">
      <span class="status-dot {상태클래스}"></span>
      <span class="issue-num">#{번호}</span>
      <span class="issue-name">{제목}</span>
      <span class="tag {상태클래스}">{상태텍스트}</span>
    </div>
  </div>
  <div class="progress-bar-wrap">
    <div class="progress-bar"><div class="progress-fill" style="width:{%}%"></div></div>
    <span class="progress-label">{완료}/{전체} 완료</span>
  </div>
</div>
```

### 의존성 그래프 SVG — 전폭 Wave-밴드 레이아웃 (★ 이 형식 고정)

목적은 **"무엇이 무엇을 막는가"** 를 한눈에 보는 것. 아래 레이아웃을 그대로 따른다.
(좁은 노드-링크형으로 그리지 말 것 — 박스가 작아지고 화살표가 대각으로 교차해 가독성이 떨어진다.)

**[MUST] SVG 앞에 HTML 미니 범례 스트립을 반드시 배치한다 (★ 핵심 가독성 요소)**

그래프 `<div class="graph-wrap">` 안, SVG 바로 위에 다음 범례 HTML을 삽입한다.
색상만으로는 "진행 중"과 "즉시 착수 가능"을 구별하기 어렵기 때문에 **스크롤 없이 그래프 옆에서
읽을 수 있는 위치**에 두는 것이 핵심이다. 하단 SVG 범례만으로는 부족하다.

```html
<div class="graph-legend-strip">
  <span class="gls-item" style="color:#3fb950">
    <span class="gls-dot" style="background:rgba(26,68,41,0.6)"></span>
    ✅ 완료 (Closed)
  </span>
  <span class="gls-item" style="color:#bc8cff">
    <span class="gls-dot" style="background:rgba(45,27,78,0.8)"></span>
    ▶ 진행 중 (In Progress) — 담당자/PR 있음
  </span>
  <span class="gls-item" style="color:#58a6ff">
    <span class="gls-dot" style="background:rgba(13,42,74,0.8)"></span>
    ⚡ 즉시 착수 가능 (Ready) — 미배정이지만 선행 완료
  </span>
  <span class="gls-item" style="color:#7d8590">
    <span class="gls-dot" style="background:rgba(33,38,45,0.8)"></span>
    ⏳ 대기 (Blocked) — 선행 이슈 미완료
  </span>
</div>
```

CSS:
```css
.graph-legend-strip {
  display: flex; gap: 16px; flex-wrap: wrap;
  margin-bottom: 14px; padding: 8px 12px;
  background: rgba(255,255,255,0.03);
  border: 1px solid var(--border); border-radius: 6px; font-size: 12px;
}
.gls-item { display: flex; align-items: center; gap: 6px; white-space: nowrap; }
.gls-dot  { display: inline-block; width: 10px; height: 10px; border-radius: 2px;
             border: 2px solid currentColor; flex-shrink: 0; }
```

**캔버스**
- Epic당 SVG 1개. `<svg viewBox="0 0 960 {높이}" style="width:100%;display:block">` —
  **`width:100%` 로 화면 폭을 꽉 채운다.** 컨테이너는 `overflow-x:auto`.
- `{높이}` = Σ(각 Wave 밴드 높이). 밴드 = 라벨 띠(22~26px) + 노드 행(72~80px) + 여백.

**Wave = 가로 밴드 (세로로 쌓음)**
- 위에서부터 완료(기반) → Wave 1 → Wave 2 → … 순으로 **전폭 라벨 띠**를 그리고,
  그 아래 그 Wave의 노드들을 **가로로 균등 분배**해 폭을 채운다.
- 한 Wave의 노드 폭 = `(960 - 좌우여백 - 노드간격×(n-1)) / n`. n개를 가로로 꽉 차게 배치.
  (예: Wave 1에 6개 → 각 ~150px, 5개 → 각 ~176~196px)
- **Wave 1 라벨 띠**: Wave 1에 진행 중(보라)과 즉시 착수(파랑) 두 상태가 섞여 있으면
  `Wave 1 — ▶ 보라: 진행 중 · ⚡ 파랑: 즉시 착수 가능` 처럼 **두 상태를 명시**한다.
  Wave 2 이상은 `Wave 2 — #N 완료 후` 처럼 **무엇이 끝나야 풀리는지**를 적는다.
- **[MUST] 밴드 라벨은 위치가 아니라 그 밴드 노드들의 실제 상태 기준으로 정한다.** "첫 오픈 밴드 = 즉시 착수"로
  단정하지 않는다 — cross-epic `hard` 차단(Step 3 A-5)으로 에픽의 최하위 밴드가 Wave 1이 아닐 수 있다(예: epic-66은
  #300이 #281 대기라 Wave 2부터 시작, "즉시 착수" 밴드 없음). 밴드에 `ready` 노드가 하나라도 있으면 "즉시 착수 가능 (Ready)",
  아니면 "선행 완료 후 (Blocked)"로 적는다.

**노드 박스 — 상태 배지 텍스트 필수 (★ 색상만으로는 구분 불가)**

박스 높이 **46px**, 텍스트 3줄 + 하단 상태 배지로 구성한다. 색상은 힌트일 뿐 —
박스 안에 반드시 상태 텍스트를 표시해야 색맹·인쇄·저조도에서도 구별된다.

```svg
<!-- 진행 중 노드 예시 (height=46) -->
<g transform="translate(x,y)">
  <rect width="W" height="46" fill="#2d1b4e" stroke="#8957e5" stroke-width="1.5" rx="6"/>
  <text x="cx" y="13" text-anchor="middle" fill="#bc8cff" font-size="12" font-weight="700">#N</text>
  <text x="cx" y="25" text-anchor="middle" fill="#bc8cff" font-size="10">짧은 제목</text>
  <!-- 상태 배지: 채운 rect + 텍스트 -->
  <rect x="pad" y="30" width="bw" height="11" rx="3" fill="#8957e5" opacity="0.35"/>
  <text x="cx" y="39" text-anchor="middle" fill="#bc8cff" font-size="9" font-weight="600">▶ 진행 중</text>
</g>

<!-- 즉시 착수 노드 예시 (height=46) -->
<g transform="translate(x,y)">
  <rect width="W" height="46" fill="#0d2a4a" stroke="#1f6feb" stroke-width="2" rx="6"/>
  <text x="cx" y="13" text-anchor="middle" fill="#58a6ff" font-size="12" font-weight="700">#N</text>
  <text x="cx" y="25" text-anchor="middle" fill="#58a6ff" font-size="10">짧은 제목</text>
  <rect x="pad" y="30" width="bw" height="11" rx="3" fill="#1f6feb" opacity="0.35"/>
  <text x="cx" y="39" text-anchor="middle" fill="#58a6ff" font-size="9" font-weight="600">⚡ 즉시 착수 가능</text>
</g>

<!-- 대기 노드 예시 (height=46) -->
<g transform="translate(x,y)">
  <rect width="W" height="46" fill="#21262d" stroke="#30363d" stroke-width="1.5" rx="6"/>
  <text x="cx" y="13" text-anchor="middle" fill="#7d8590" font-size="12" font-weight="700">#N</text>
  <text x="cx" y="25" text-anchor="middle" fill="#7d8590" font-size="10">짧은 제목</text>
  <rect x="pad" y="30" width="bw" height="11" rx="3" fill="#484f58" opacity="0.35"/>
  <text x="cx" y="39" text-anchor="middle" fill="#7d8590" font-size="9" font-weight="600">⏳ 대기</text>
</g>
```

상태 배지 텍스트 규칙:
- `▶ 진행 중` — `inprogress` (보라, status:in-progress 라벨 또는 담당자 있음)
- `⚡ 즉시 착수 가능` — `ready` (파랑, 미배정 + in-degree 0)
- `⏳ 대기` — `todo` (회색, in-degree > 0)
- 완료 박스(`done`)는 배지 생략(색으로 충분)

색상 스펙 (박스 형태는 상태와 무관하게 동일, 색만 다름):

| 상태 | fill | stroke | text |
|------|------|--------|------|
| 완료 | `#1a4429` | `#238636` | `#3fb950` |
| 진행 중 | `#2d1b4e` | `#8957e5` | `#bc8cff` |
| 즉시 착수 | `#0d2a4a` | `#1f6feb` | `#58a6ff` |
| 대기 | `#21262d` | `#484f58` | `#7d8590` |
| 최우선/blocker | `#2d0000` | `#f85149` stroke-width 2.5 | `#ff7b72` + `★` |

- **완료된 기반 이슈는 맨 위 "✅ 완료 (기반)" 밴드에 초록 박스로 유지한다 — 제거·칩화 금지.**
- `최우선/blocker` 노드는 빨간 테두리 두께 2.5 + `★` 기호로 추가 강조.

**박스 높이와 화살표 좌표**: 배지 있는 박스(height=46px)에서 화살표가 박스 하단에서 출발하면
y = `transform_y + 46`. 완료 박스는 배지 없이 34px 유지 가능.

**화살표 (선행 → 후행, 깔끔하게)**
- `deps.json` 의 **같은 Epic** 엣지를 **전부** SVG 화살표로 그린다. 방향은 **선행(위 Wave) → 후행(아래 Wave)**.
  즉 `to`(먼저 끝날 이슈, 위) 에서 `from`(그에 의존, 아래) 으로 화살촉이 향한다.
- **cross-epic 엣지(다른 에픽 선행)** 는 그 에픽 그래프 안에 선행 노드가 없어 화살표로 못 그린다. 대신 그래프 상단에 노트로 표시한다:
  - **cross-epic `hard`(차단)**: `⛔ cross-epic 선행(차단): #300 ⟵ #281 (epic-62 …)` — 주황 박스. 후행 노드는 그 선행이 미완료면 **대기(회색)** 로 칠한다(in-degree에 반영됨, Step 4).
  - **cross-epic `mockable`(병렬 가능)**: `🔗 cross-epic mockable(병렬 가능): #64(…), #71(…)` — 차단 아님(병렬 착수 OK), 인터페이스 의존 정보로만.
- `<marker>` 로 화살촉 정의 후 `marker-end` 적용. 대각 직선으로 가로지르지 말고
  **세로로 내린 뒤 가로 연결선 → 다시 세로로 꽂는** 직교(맨해튼) 경로로 교차를 최소화한다.
- 스타일 `stroke="#484f58" stroke-width="1.5" stroke-dasharray="4,2"`. blocker발 엣지는 빨강 marker.
- 다수 후속작업을 푸는(out-degree 높은) 기반 이슈는 빨간 테두리로 강조.
- cross-repo(`external:true`)는 점선 + "↗ owner/repo#N" 외부 노드로 표시.

**범례** — SVG 하단에도 한 줄 추가: 즉시 시작(파랑)·진행 중(보라)·대기(회색)·완료(초록)·최우선(빨강)·의존 화살표.
단, **HTML 미니 범례 스트립(SVG 상단)**이 메인이고 SVG 내 범례는 보조다.

**검증** — 그린 뒤 확인: ① 그래프가 컨테이너 폭을 꽉 채우는가(좌측 쏠림·우측 공백 금지)
② `deps.json` 의 같은 Epic 엣지 수만큼 화살표가 실제로 그려졌는가(박스만 있고 화살표 0개면 오류)
③ 완료 이슈가 초록 박스로 남아 있는가.
④ **Wave 1 박스 안에 `▶ 진행 중` 또는 `⚡ 즉시 착수 가능` 배지 텍스트가 있는가** — 색만 있고 텍스트 없으면 불완전.
⑤ **cross-epic `hard` 의존이 있으면 `⛔ cross-epic 선행(차단)` 노트가 떠 있고, 후행 노드가 대기(회색)인가** — 트래커 대상 의존이
   조용히 사라져 후행이 "즉시 착수"로 오표시되지 않는지 확인(트래커→`S0` 치환 누락의 회귀 신호).

### 이슈 상태 판별 로직

위에서부터 먼저 맞는 조건을 적용한다(우선순위 순서).

| 조건 | 상태 | CSS 클래스 |
|------|------|-----------|
| `state = closed` | 완료 | `done` |
| `state = open` + `external:true` 의존(서브레포 미완료) | 외부 대기 (HANDOFF) | `split` |
| `state = open` + PR 존재 + `isDraft = true` | 리뷰 대기 | `review` |
| `state = open` + `blocked-by-subrepo` 라벨 | 리뷰 대기 | `review` |
| `state = open` + **assignee 있음 또는 연결된 open PR/브랜치 존재** | **진행 중** | `inprogress` |
| `state = open` + in-degree = 0 (미배정, 막힘 없음) | 즉시 시작 가능 | `ready` |
| `state = open` + in-degree > 0 | 대기 | `todo` |

**진행 중(`inprogress`) 판별 근거:** 이슈에 `assignees` 가 있거나, `prs_open.json` 에서
이 이슈를 닫는/참조하는 PR(`Closes #N`, 브랜치명에 이슈번호 등)이 있으면 "누군가 작업 중"으로 본다.
이것이 **즉시 시작(ready, 아무도 안 함)** 과의 핵심 차이다.

### 완료된 Epic 판별 및 표시 (★ 제거 금지)

모든 서브이슈(epic-N 라벨/서브이슈)가 `closed` 이면 그 Epic을 **완료**로 판정한다.

**완료된 Epic은 절대 대시보드에서 제거하지 않는다.** 전체 진행을 확인할 수 있어야 하므로
"✅ 완료된 Epic" 섹션에 **항상 표시**한다. 진행 중 Epic과 시각적으로만 구분(완료 색/체크)하고
숨기거나 누락시키지 않는다. 다음을 반드시 포함한다:

- Epic 제목 + ✅ 표시, 완료 색상(`stroke #238636, fill #1a4429`)
- **진행률 바 100%** 와 `{완료수}/{전체} 완료` 카운트 (완료도 진행률이 보여야 함)
- 서브이슈 번호 chips (closed 표시) — 어떤 이슈로 구성됐는지 추적 가능하게
- 카드는 기본 collapsed(접힘) 가능하나, **클릭하면 펼쳐 서브이슈를 볼 수 있게** 한다.
  접더라도 카드 자체와 진행률·카운트는 화면에 남는다.

`<overall>` 전체 진행률 바에도 완료 Epic을 포함해 분모로 계산한다(완료/전체).
**완료 Epic을 빼고 그리면 안 된다** — "다 끝난 것까지 보여서 전체 진행을 확인"하는 것이 목적이다.

---

## Step 6: 착수 순서 추천 + 근거 (LLM 핵심 산출물)

**이 영역이 LLM 분석을 정당화하는 산출물이다.** 의존성 분석을 했다면 "이 순서로 하면 좋다"는
**추천과 그 근거**가 반드시 나와야 한다. 근거 없는 그림은 라벨 그루핑과 다를 바 없다.

각 추천 이슈마다 다음을 함께 제시한다:
- **왜 지금 착수 가능한가** — 선행 의존이 모두 해소됨(또는 처음부터 없음)
- **왜 중요한가(영향도)** — 이 이슈가 해소하면 풀리는 후속 작업 수(out-degree), 핵심 경로 여부
- **병렬 가능 여부** — 같은 Wave의 어떤 이슈와 동시에 진행 가능한지

추천 우선순위: `priority:high` → out-degree(많이 unblock) → 핵심 경로 → 병목 해소 효과 순.
같은 Epic 이슈를 한 개발자에게 묶는 것을 우선한다.

이 추천은 **제안일 뿐 자동 착수가 아니다.** 사람이 근거를 보고 판단해 시작하도록 돕는 것이 목적이다.
(설계 원칙 2 — "다음 작업" 영역은 의사결정을 대신하지 않는다.)

예시 출력:
```
⚡ 지금 착수 가능 (근거 포함)
  #225 (S0 탭 셸)  — 선행 없음 / #227·#229·#231 3개를 unblock(핵심 경로) / #226과 병렬 가능
  #210 (스키마)    — 선행 없음 / #212·#213을 unblock / priority:high
```

---

## Step 7: 파일 저장 및 완료

```bash
# 타임스탬프 갱신
date -u +"%Y-%m-%dT%H:%M:%SZ" > .autoflow/issue-analysis/last-updated.txt
```

사용자에게 출력:
```
✅ epic-dash 분석 완료
   이슈: {N}개 분석 · 의존성 엣지: {M}개

⚡ 즉시 착수 가능 (Wave 1):
   #{번호} {슬라이스} · {제목} ({epic 이름})
   ...

📊 대시보드: .autoflow/epic_status.html
📁 분석 데이터: .autoflow/issue-analysis/
```

---

## 주의사항

- **접근은 강제하지 않는다.** gh 미설치/미인증이면 중단하지 말고 MCP → git remote 순으로 폴백,
  셋 다 안 될 때만 사용자에게 안내한다. (`fetch.sh` 종료 코드 3 = "폴백하라")
- issues 300개 초과 레포는 `--limit`(또는 MCP 페이지네이션)을 늘리도록 안내
- `deps.json` 의 `analyzed_at` 을 헤더에 표시해서 오래된 분석임을 알 수 있게 한다
- 의존성 분석은 추론이므로 confidence·`type`·reason 을 반드시 HTML 툴팁/주석에 포함한다
  (명시적 신호 type=sub_issue/tasklist/keyword/cross_repo 는 confidence 1.0, 맥락 type=context 는 0.7~0.9)
- 서브이슈/마일스톤 엔드포인트는 레포·플랜에 따라 없을 수 있다 → best-effort, 없으면 태스크리스트
  파싱으로 대체하고 분석을 계속한다
- 최종 산출물은 **AI 추천 + 사람 확인** 용이다. Wave 1 추천은 제안일 뿐 자동 착수가 아님을 명시한다
