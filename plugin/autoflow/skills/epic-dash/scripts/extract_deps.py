#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""epic-dash Step 3: 구조화된 deps 필드 파싱 + 슬라이스ID 해석 → deps.json
각 이슈 body의 `선행 의존(deps)` 필드(hard/mockable)와 title의 슬라이스ID를 결합한다.
hard = 차단 의존(confidence 1.0, in-degree 카운트), mockable = 목킹 가능 소프트 의존(병렬 가능, 순서 힌트)."""
import json, re, sys
from datetime import datetime, timezone

A = json.load(open('issues_open.json'))
C = json.load(open('issues_closed.json'))

_BODY_SLICE = re.compile(r'분해 (?:슬라이스|단위)\s*`#([0-9A-Za-z-]+)`')
_TITLE_SLICE = re.compile(r'\[[^\]]*·?\s*#([0-9A-Za-z-]+)\]')

def slice_id_of(title, body):
    # 1순위: body의 'epic 분해 슬라이스 `#80-S0`' / '분해 단위 `#80-S0`'
    m = _BODY_SLICE.search(body or '')
    if m: return m.group(1)
    # 2순위: title의 '[feat · #79-S5]' 또는 '[#79-S5]'
    m = _TITLE_SLICE.search(title or '')
    if m: return m.group(1)
    return None

# 1) 슬라이스ID/이슈번호 → 번호, 상태 맵 구축 (open+closed 전체)
slice_map = {}     # "80-S0" -> issue number
num_state = {}     # number -> "open"/"closed"
num_title = {}
num_labels = {}
num_assignees = {}
for it in A:
    n = it['number']; num_state[n] = 'open'; num_title[n] = it['title']
    num_labels[n] = [l['name'] for l in it.get('labels', [])]
    num_assignees[n] = [a['login'] for a in (it.get('assignees') or [])]
    sid = slice_id_of(it['title'], it.get('body'))
    if sid: slice_map[sid] = n
for it in C:
    n = it['number']; num_state[n] = 'closed'; num_title[n] = it['title']
    num_labels[n] = [l['name'] for l in it.get('labels', [])]
    sid = slice_id_of(it['title'], it.get('body'))
    if sid and sid not in slice_map: slice_map[sid] = n

def resolve(token):
    """deps 토큰(예 '#80-S0', '#71', '80-S0', '114') → 이슈번호 또는 None(미해석)."""
    t = token.strip().lstrip('#').strip('`').strip()
    if t in slice_map: return slice_map[t]
    if re.fullmatch(r'\d+', t):
        n = int(t)
        if n in num_state: return n
        return n  # 알려지지 않은 직접 번호도 일단 반환
    return None

# 2) 각 오픈 이슈의 deps 필드 파싱
edges = []
unresolved = []
dep_line_re = re.compile(r'선행 의존[^:]*:\s*(.*)')
token_re = re.compile(r'`?#?([0-9A-Za-z-]+)`?\s*·\s*(hard|mockable)')

# 영문 `depends_on:` 형식 폴백 (epic-567 식 자동분해 이슈).
#   예: `- depends_on: **#570 (S1)**·hard(capability+audit), **#571 (S2)**·soft(...)`
# `#N` 뒤에 `(Sx)`/`**` 가 끼어든 뒤 `·kind` 가 오는 형태를 허용한다. `·참조`(kind 없음)는
# 매칭되지 않아 자동 제외된다(차단/소프트 의존이 아니라 단순 참조이므로). soft → mockable 로 정규화.
depends_line_re = re.compile(r'depends_on\s*:?\s*(.*)', re.I)
_DEPENDS_TOKEN = re.compile(
    r'#([0-9A-Za-z-]+)(?:\s*\([^)]*\))?\s*\*{0,2}\s*·\s*(hard|mockable|soft)')

# 섹션-헤딩 형식 폴백: 인라인 `선행 의존: #N·hard` 가 없을 때 `## 선행 의존\n- #N (설명)` 블록을 파싱.
# 불릿 선두 `#N` 만 의존 대상으로 본다(괄호 주석 속 다른 #N 오인 방지). 마일스톤 운영 이슈가 이 형식을 쓴다.
_SEC_HEAD = re.compile(r'^#{1,6}\s*선행 의존\s*$')
_BULLET_REF = re.compile(r'^\s*[-*]\s*\**\s*#([0-9A-Za-z-]+)')

def section_tokens(body):
    """`## 선행 의존` 섹션의 불릿에서 (토큰, kind) 목록 추출. 없음/독립 불릿은 제외, 기본 kind=hard."""
    lines = body.splitlines()
    toks = []
    for i, ln in enumerate(lines):
        if not _SEC_HEAD.match(ln.strip()):
            continue
        for lj in lines[i + 1:]:
            s = lj.strip()
            if re.match(r'^#{1,6}\s', s):     # 다음 헤딩 → 섹션 종료
                break
            if not s:
                continue
            if s[0] not in '-*':              # 불릿이 아니면 무시
                continue
            bare = s.lstrip('-*').strip()
            if bare.startswith('없음') or '독립' in bare:
                continue
            m = _BULLET_REF.match(lj)
            if m:
                kind = 'mockable' if ('mockable' in s or '목킹' in s) else 'hard'
                toks.append((m.group(1), kind))
        break
    return toks

def epic_of(n):
    for lb in num_labels.get(n, []):
        m = re.fullmatch(r'epic-(\d+)', lb)
        if m: return int(m.group(1))
    return None

for it in A:
    n = it['number']
    body = it.get('body') or ''
    dep_field = None
    depends_field = None
    for line in body.splitlines():
        if dep_field is None and '선행 의존' in line:
            m = dep_line_re.search(line)
            if m: dep_field = m.group(1).strip()
        if depends_field is None and 'depends_on' in line.lower():
            m = depends_line_re.search(line)
            if m: depends_field = m.group(1).strip()
    tokens = []
    if dep_field and not (dep_field.startswith('없음') or '독립' in dep_field):
        tokens = token_re.findall(dep_field)
    if not tokens and depends_field and not (
            depends_field.lower().startswith('none') or '없음' in depends_field or '독립' in depends_field):
        # soft → mockable 정규화 (소프트 의존 = 목킹 가능, 병렬 착수)
        tokens = [(t, 'mockable' if k == 'soft' else k)
                  for t, k in _DEPENDS_TOKEN.findall(depends_field)]
    if not tokens:                       # 인라인 형식이 없으면 섹션-헤딩 형식 폴백
        tokens = section_tokens(body)
    if not tokens:
        continue
    # 토큰 추출: `#80-S0`·hard, `#74`·mockable (인라인) 또는 `- #N` (섹션)
    for tok, kind in tokens:
        to_num = resolve(tok)
        if to_num is None:
            unresolved.append((n, tok, kind))
            continue
        if to_num == n:
            continue
        # 에픽 트래커를 향한 hard 선행은 그 에픽의 S0 셸 슬라이스로 해석.
        # (트래커는 작업노드가 아니라 위상정렬/그래프에서 누락됨. 예: #300의 '#62·hard' → #62-S0=#281)
        if kind == 'hard' and 'epic' in num_labels.get(to_num, []):
            s0 = slice_map.get(f"{to_num}-S0")
            if s0 and s0 != n:
                to_num = s0
        hard = (kind == 'hard')
        # 슬라이스ID였는지 vs 직접 epic/이슈 참조인지
        is_slice = (tok.strip('`#') in slice_map)
        edges.append({
            'from': n,
            'to': to_num,
            'confidence': 1.0 if hard else 0.6,
            'type': 'hard_dep' if hard else 'mockable_dep',
            'kind': kind,
            'to_state': num_state.get(to_num, 'unknown'),
            'reason': ''  # 아래서 채움
        })

# 3) reason 생성 (구조 기반, 정확)
for e in edges:
    to_t = num_title.get(e['to'], f"#{e['to']}")
    short = re.sub(r'^\[[^\]]*\]\s*', '', to_t)[:36]
    if e['kind'] == 'hard':
        e['reason'] = f"#{e['to']}({short}) 완료 필요 — hard 선행(차단)"
    else:
        e['reason'] = f"#{e['to']}({short}) 인터페이스에 의존하나 mockable(목킹 가능, 병렬 착수 가능)"

try:
    _repo = json.load(open('meta.json')).get('repo', '')
except Exception:
    _repo = ''
out = {
    'analyzed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'repo': _repo,
    'edges': edges,
    'issue_states': {str(n): s for n, s in num_state.items() if s == 'open'},
    'slice_map': slice_map,
}
# deps_parsed.json = 파이프라인 입력, deps.json = 스킬 스펙 산출물 이름(동일 내용)
json.dump(out, open('deps_parsed.json', 'w'), ensure_ascii=False, indent=2)
json.dump(out, open('deps.json', 'w'), ensure_ascii=False, indent=2)

print(f"엣지 총 {len(edges)}개 (hard {sum(1 for e in edges if e['kind']=='hard')} / mockable {sum(1 for e in edges if e['kind']=='mockable')})")
print(f"슬라이스 매핑 {len(slice_map)}개")
print(f"미해석 토큰 {len(unresolved)}개:", unresolved[:20])
# 미해석 토큰의 고유 집합
uniq = sorted(set(t for _,t,_ in unresolved))
print("미해석 고유 토큰:", uniq)
