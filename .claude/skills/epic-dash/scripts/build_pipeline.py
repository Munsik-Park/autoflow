#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""epic-dash Step 2+4: Epic 구조(epics.json) + 위상정렬 Wave(execution-order.json).
hard 엣지만 in-degree(차단)로 사용. mockable은 병렬 가능 → 순서 힌트(블록 아님)."""
import json, re
from collections import defaultdict, deque

A = json.load(open('issues_open.json'))
C = json.load(open('issues_closed.json'))
dp = json.load(open('deps_parsed.json'))
edges = dp['edges']
slice_map = dp['slice_map']

num_state, num_title, num_labels, num_assignees, num_body = {}, {}, {}, {}, {}
for it in A:
    n = it['number']; num_state[n]='open'; num_title[n]=it['title']
    num_labels[n]=[l['name'] for l in it.get('labels',[])]
    num_assignees[n]=[a['login'] for a in (it.get('assignees') or [])]
    num_body[n]=it.get('body') or ''
for it in C:
    n=it['number']; num_state[n]='closed'; num_title[n]=it['title']
    num_labels[n]=[l['name'] for l in it.get('labels',[])]

# 상위 epic 트래커 = label 'epic' 이 있고 'epic-N' 자식 라벨은 없는 이슈(open+closed).
# (epic + epic-N 둘 다인 이슈는 상위 트래커가 아니라 부모 epic의 슬라이스/미니트래커 — 예 #99,#103)
TRACKERS = {n for n, labs in num_labels.items()
            if 'epic' in labs and not any(re.fullmatch(r'epic-\d+', l) for l in labs)}

# 표시용 한글 이름(선택 override). 없으면 트래커 이슈 제목에서 도출 → 새 epic 자동 대응.
EPIC_NAMES = {
 62:"멀티 모델 채팅", 64:"문서함/파일 관리", 65:"이미지 생성 갤러리", 66:"동영상 생성",
 67:"다국어 문서 번역", 68:"AI 문서 자동 생성", 69:"유튜브 영상 요약", 70:"MonoRouter API키 통합",
 71:"크레딧/요금제 시스템", 72:"Enterprise 멤버 관리", 73:"Enterprise 대시보드", 74:"Enterprise 보안 마스킹",
 75:"기관 브랜딩/공지", 76:"사용자 설정", 77:"음원 생성", 79:"그룹 채팅", 80:"채팅 입력창 퀵 액션",
 63:"AI 비서/문서 Q&A",
}
def epic_name(E):
    if E in EPIC_NAMES:
        return EPIC_NAMES[E]
    t = re.sub(r'^\[[^\]]*\]\s*', '', num_title.get(E, f'#{E}'))
    return re.split(r'[—\-–(]', t)[0].strip()[:24] or f'#{E}'

# native 서브이슈는 sub_issues.json 에서 읽음 (하드코딩 금지 → 데이터 변경 자동 반영)
try:
    native = {x['parent']: x['children'] for x in json.load(open('sub_issues.json'))}
except Exception:
    native = {}

# epic 멤버 수집 (label epic-N + native sub-issue) — 트래커 자신 제외
epics = {}
for E in sorted(TRACKERS):
    name = epic_name(E)
    members = set()
    for n, labs in num_labels.items():
        if f"epic-{E}" in labs and n != E:
            members.add(n)
    for c in native.get(E, []):
        members.add(c)
    members.discard(E)
    open_m = sorted([m for m in members if num_state.get(m)=='open'])
    closed_m = sorted([m for m in members if num_state.get(m)=='closed'])
    epics[E] = {
        'tracker': E, 'name': name, 'label': f"epic-{E} · {name}",
        'open': open_m, 'closed': closed_m,
        'total': len(members), 'done': len(closed_m),
        'complete': len(open_m)==0 and len(members)>0,
        'source': 'native+label' if E in native else 'label',
        'group': 'epic',
    }

# epic 멤버십 역참조 (이슈 → epic)
issue_epic = {}
for E, d in epics.items():
    for m in d['open']+d['closed']:
        issue_epic[m] = E

# ---- 우선순위 티어 (priority:* 라벨) ----
# P0=priority:high, P1=priority:medium, deferred(동결)=priority:low. 라벨 없으면 none.
def tier_of(n):
    labs = num_labels.get(n, [])
    if 'priority:high' in labs:   return 'P0'
    if 'priority:medium' in labs: return 'P1'
    if 'priority:low' in labs:    return 'deferred'
    return 'none'
issue_tier = {n: tier_of(n) for n in num_state if num_state[n]=='open'}
# 동결(priority:low) 오픈 슬라이스 → Wave 위상정렬·추천에서 제외(별도 Deferred 밴드로 렌더).
deferred = sorted(n for n in num_state
                  if num_state[n]=='open' and n not in TRACKERS and issue_tier.get(n)=='deferred')
deferred_set = set(deferred)
# epic 티어: 열린 멤버에 P0 있으면 P0, 없고 P1 있으면 P1, 전부 deferred면 deferred, 그 외 none.
def group_tier(open_members):
    ot = {issue_tier.get(m, 'none') for m in open_members}
    if 'P0' in ot:                  return 'P0'
    if 'P1' in ot:                  return 'P1'
    if ot and ot <= {'deferred'}:   return 'deferred'
    return 'none'
for E, d in epics.items():
    d['tier'] = group_tier(d['open'])

# ---- 마일스톤 유사-epic 그룹 (라벨 epic 미소속 이슈를 마일스톤으로 묶음) ----
# 스킬 Step 2: "라벨 epic이 없는 이슈는 마일스톤으로 묶는다". 합성 키는 음수(-번호)로
# render의 int(k) 캐스팅과 충돌 없이 epic 번호 공간과 분리한다. epic 멤버(예 #284→epic-62)는
# epic 카드에 남기고, cross-그룹 hard 의존은 render에서 cross-epic 차단 노트로 표시된다.
try:
    _ms_meta = {m['number']: m for m in json.load(open('milestones.json'))}
except Exception:
    _ms_meta = {}
ms_issue = {}   # 이슈 → 마일스톤 번호 (open+closed)
for it in A + C:
    m = it.get('milestone')
    if m and 'number' in m:
        ms_issue[it['number']] = m['number']
for mnum in sorted(set(ms_issue.values())):
    members = [n for n, mm in ms_issue.items()
               if mm == mnum and n not in issue_epic and n not in TRACKERS]
    open_m = sorted(n for n in members if num_state.get(n) == 'open')
    closed_m = sorted(n for n in members if num_state.get(n) == 'closed')
    if not members:         # 비-epic 멤버가 전혀 없는 마일스톤은 그룹 생략(작업이 epic 진행률에 이미 반영됨)
        continue
    title = _ms_meta.get(mnum, {}).get('title', f'마일스톤 #{mnum}')
    key = -mnum
    epics[key] = {
        'tracker': None, 'name': title, 'label': f'🎯 {title}',
        'open': open_m, 'closed': closed_m,
        'total': len(members), 'done': len(closed_m),
        # 열린 비-epic 작업이 없으면 완료 그룹 → render 가 ✅ 완료 섹션에 유지(완료 제거 금지).
        'complete': len(open_m) == 0, 'source': 'milestone', 'group': 'milestone',
        'milestone': mnum, 'tier': group_tier(open_m),
    }
    for n in open_m + closed_m:
        issue_epic[n] = key

# ---- 위상정렬: hard 엣지(차단) 기반, open 작업 슬라이스만 (동결 제외) ----
work_nodes = [n for n in num_state if num_state[n]=='open' and n not in TRACKERS and n not in deferred_set]
hard_to_open = defaultdict(set)   # from -> {to(open)}
out_hard = defaultdict(set)       # to -> {from} (이 이슈를 풀면 unblock되는 후속)
for e in edges:
    if e['kind']=='hard' and num_state.get(e['to'])=='open' and e['from'] in num_state:
        if e['to'] in work_nodes and e['from'] in work_nodes:
            hard_to_open[e['from']].add(e['to'])
            out_hard[e['to']].add(e['from'])

indeg = {n: len(hard_to_open.get(n,())) for n in work_nodes}

# Kahn
waves = []
remaining = set(work_nodes)
level = {n:0 for n in work_nodes}
q = deque(sorted([n for n in work_nodes if indeg[n]==0]))
processed = set()
cur_indeg = dict(indeg)
# 레벨 계산: 위상순 + 레벨 = max(dep 레벨)+1
order = []
dq = deque(sorted([n for n in work_nodes if cur_indeg[n]==0]))
while dq:
    n = dq.popleft(); order.append(n)
    for succ in sorted(out_hard.get(n,())):
        level[succ] = max(level[succ], level[n]+1)
        cur_indeg[succ]-=1
        if cur_indeg[succ]==0:
            dq.append(succ)
cycle = len(order)!=len(work_nodes)
maxlev = max(level.values()) if level else 0
for lv in range(maxlev+1):
    issues = sorted([n for n in work_nodes if level[n]==lv])
    if issues:
        waves.append({'wave':lv+1, 'issues':issues, 'parallel':True})

# 영향도(out-degree, hard 기준): 이 이슈 완료 시 직접 unblock되는 후속 수
impact = {n: len(out_hard.get(n,())) for n in work_nodes}
# 전이 영향도(이 이슈가 풀려야 가능한 모든 후행)
def reachable(n):
    seen=set(); st=[n]
    while st:
        x=st.pop()
        for s in out_hard.get(x,()):
            if s not in seen: seen.add(s); st.append(s)
    return seen
trans_impact = {n: len(reachable(n)) for n in work_nodes}

out = {
    'waves': waves,
    'cycle_detected': cycle,
    'wave1': waves[0]['issues'] if waves else [],
    'impact_direct': impact,
    'impact_transitive': trans_impact,
    'deferred': deferred,
    'issue_tier': {str(n): t for n, t in issue_tier.items()},
}
json.dump(out, open('execution-order.json','w'), ensure_ascii=False, indent=2)
json.dump({'epics':epics, 'issue_epic':issue_epic, 'milestones':{}, 'trackers':sorted(TRACKERS)},
          open('epics.json','w'), ensure_ascii=False, indent=2)

print("=== Epic/그룹 완료 현황 ===")
for E in sorted(epics):
    d=epics[E]; mark='✅완료' if d['complete'] else f"🔧{d['done']}/{d['total']}"
    tag = f"epic-{E}" if d.get('group') != 'milestone' else f"🎯ms-{-E}"
    print(f"  {tag:9s} {d['name']:18s} {mark}  open={len(d['open'])}")
print(f"\n작업 노드(open 슬라이스): {len(work_nodes)}  (동결 제외 {len(deferred)}개)")
_tier_cnt = {t: sum(1 for v in issue_tier.values() if v == t) for t in ('P0', 'P1', 'deferred', 'none')}
print(f"티어: P0 {_tier_cnt['P0']} · P1 {_tier_cnt['P1']} · 동결 {_tier_cnt['deferred']} · 미지정 {_tier_cnt['none']}")
print(f"Wave 수: {len(waves)}  cycle={cycle}")
for w in waves:
    print(f"  Wave {w['wave']}: {len(w['issues'])}개  {w['issues'][:12]}{'...' if len(w['issues'])>12 else ''}")
print("\n=== 영향도 상위(직접 unblock 수) ===")
for n,_ in sorted(impact.items(), key=lambda x:-x[1])[:12]:
    if impact[n]>0:
        print(f"  #{n} 직접{impact[n]} 전이{trans_impact[n]}  E{issue_epic.get(n,'?')}  {re.sub(r'^\[[^]]*\]','',num_title[n])[:46]}")
