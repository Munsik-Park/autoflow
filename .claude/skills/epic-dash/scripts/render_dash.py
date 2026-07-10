#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""epic-dash Step 5/6: 프로젝트 현황 대시보드 HTML 생성.
전폭 Wave-밴드 SVG + 상태 배지 + HTML 미니 범례 + 착수 추천.
입력: issues_open/closed.json, deps_parsed.json, epics.json, execution-order.json"""
import json, re, html, sys

BASE = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = sys.argv[2] if len(sys.argv) > 2 else '../epic_status.html'

A  = json.load(open(f'{BASE}/issues_open.json'))
C  = json.load(open(f'{BASE}/issues_closed.json'))
dp = json.load(open(f'{BASE}/deps_parsed.json'))
EP = json.load(open(f'{BASE}/epics.json'))
EO = json.load(open(f'{BASE}/execution-order.json'))
meta = json.load(open(f'{BASE}/meta.json'))
try:
    PR = json.load(open(f'{BASE}/prs_open.json'))
except Exception:
    PR = []

epics = {int(k): v for k, v in EP['epics'].items()}
issue_epic = {int(k): v for k, v in EP['issue_epic'].items()}
trackers = set(EP['trackers'])

num_title, num_state, num_labels = {}, {}, {}
for it in A:
    num_title[it['number']] = it['title']; num_state[it['number']] = 'open'
    num_labels[it['number']] = [l['name'] for l in it.get('labels', [])]
for it in C:
    num_title[it['number']] = it['title']; num_state[it['number']] = 'closed'
    num_labels[it['number']] = [l['name'] for l in it.get('labels', [])]

# 오픈 PR → 이슈 연결: 담당자/연결 PR 있으면 '진행 중', draft·blocked-by-subrepo 면 '외부 대기'(HANDOFF)
pr_status = {}   # issue number -> 'inprogress' | 'review'
_close_re = re.compile(r'(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)', re.I)
for pr in PR:
    refs = set(int(m) for m in _close_re.findall(pr.get('body') or ''))
    m = re.search(r'issue[-_]?(\d+)', pr.get('headRefName', '') or '')
    if m:
        refs.add(int(m.group(1)))
    pr_labels = [l['name'] for l in pr.get('labels', [])]
    blocked = pr.get('isDraft') or ('blocked-by-subrepo' in pr_labels)
    for n in refs:
        st = 'review' if blocked else 'inprogress'
        if pr_status.get(n) != 'review':   # 외부 대기 우선
            pr_status[n] = st
# assignee 기반 진행 중 (PR 미연결 이슈)
for it in A:
    if it['number'] not in pr_status and it.get('assignees'):
        pr_status[it['number']] = 'inprogress'

wave_of = {}
for wv in EO['waves']:
    for i in wv['issues']:
        wave_of[i] = wv['wave']
impact_d = {int(k): v for k, v in EO['impact_direct'].items()}
impact_t = {int(k): v for k, v in EO['impact_transitive'].items()}
deferred_set = set(EO.get('deferred', []))               # priority:low 동결 슬라이스
issue_tier = {int(k): v for k, v in EO.get('issue_tier', {}).items()}
TIER_RANK = {'P0': 0, 'P1': 1, 'none': 2, 'deferred': 3}
TIER_LABEL = {'P0': '🔥 P0 — 즉시 우선', 'P1': '🟡 P1 — 다음 우선', 'none': '· 우선순위 미지정'}
TIER_BADGE = {'P0': '🔥 P0', 'P1': '🟡 P1', 'none': '', 'deferred': '❄️ 동결'}

intra_edges = {}   # epic -> list of (from, to, kind)
cross_mock  = {}   # issue -> set(target)  (병렬 가능)
cross_hard  = {}   # issue -> set(target)  (cross-epic 차단 — 다른 에픽 선행)
for e in dp['edges']:
    f, t = e['from'], e['to']
    ef, et = issue_epic.get(f), issue_epic.get(t)
    if ef is not None and ef == et:
        intra_edges.setdefault(ef, []).append((f, t, e['kind']))
        continue
    if num_state.get(t) == 'closed':
        continue  # 선행이 이미 완료(closed) → 차단 아님. cross-그룹 노트에서 제외(Wave 로직과 일관).
    if e['kind'] == 'mockable':
        cross_mock.setdefault(f, set()).add(t)
    else:   # cross-epic hard — 다른 에픽 슬라이스가 먼저 끝나야 착수 가능
        cross_hard.setdefault(f, set()).add(t)

def status_of(n):
    if num_state.get(n) == 'closed':
        return 'done'
    if n in deferred_set:        # priority:low → 동결 (Wave/추천에서 제외)
        return 'deferred'
    if n in pr_status:           # 연결 PR/담당자 → 진행 중 또는 외부 대기(HANDOFF)
        return pr_status[n]
    if wave_of.get(n, 1) == 1:
        return 'ready'
    return 'todo'

STATUS_TXT = {'done': '✅ 완료', 'inprogress': '▶ 진행 중', 'review': '🔶 외부 대기',
              'ready': '⚡ 즉시 착수', 'todo': '⏳ 대기', 'deferred': '❄️ 동결'}

def short(n, m=40):
    t = re.sub(r'^\[[^\]]*\]\s*', '', num_title.get(n, f'#{n}')).strip()
    return html.escape(t[:m-1] + '…' if len(t) > m else t)

def vshort(n, m=22):
    t = re.sub(r'^\[[^\]]*\]\s*', '', num_title.get(n, f'#{n}'))
    t = re.split(r'[—\-–(]', t)[0].strip()
    return html.escape(t[:m-1] + '…' if len(t) > m else t)

CLR = {
    'done':       ('#1a4429', '#238636', '#3fb950'),
    'inprogress': ('#2d1b4e', '#8957e5', '#bc8cff'),
    'review':     ('#2d1f00', '#9e6a03', '#d29922'),
    'ready':      ('#0d2a4a', '#1f6feb', '#58a6ff'),
    'todo':       ('#21262d', '#484f58', '#7d8590'),
    'deferred':   ('#1c2128', '#373e47', '#768390'),
}

active = [E for E in epics if not epics[E]['complete']]
complete = [E for E in epics if epics[E]['complete']]
total_sub = sum(epics[E]['total'] for E in epics)
done_sub  = sum(epics[E]['done'] for E in epics)
open_work = [n for n in num_state if num_state[n] == 'open' and n not in trackers]
ready_n = [n for n in open_work if status_of(n) == 'ready']
inprog_n = [n for n in open_work if status_of(n) == 'inprogress']
review_n = [n for n in open_work if status_of(n) == 'review']
todo_n = [n for n in open_work if status_of(n) == 'todo']
deferred_n = [n for n in open_work if status_of(n) == 'deferred']
wave1 = EO['waves'][0]['issues'] if EO['waves'] else []
analyzed = dp.get('analyzed_at', meta.get('fetched_at', ''))
hardN = sum(1 for e in dp['edges'] if e['kind'] == 'hard')
mockN = sum(1 for e in dp['edges'] if e['kind'] == 'mockable')
# 활성(P0/P1/미지정) vs 동결(deferred) Epic 분리. 활성은 티어 → 오픈 수 순.
def etier(E):
    return epics[E].get('tier', 'none')
deferred_epics = sorted([E for E in active if etier(E) == 'deferred'], key=lambda E: -len(epics[E]['open']))
active_live = [E for E in active if etier(E) != 'deferred']
active_sorted = sorted(active_live, key=lambda E: (TIER_RANK.get(etier(E), 2), -len(epics[E]['open'])))

P = []
def w(s): P.append(s)

w(f'''<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Epic 현황 · {html.escape(meta["repo"])}</title>
<style>
:root{{--bg:#0d1117;--card:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#7d8590}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;line-height:1.5}}
.wrap{{max-width:1180px;margin:0 auto;padding:24px 20px 80px}}
header h1{{font-size:22px;margin:0 0 4px}}
header .sub{{color:var(--muted);font-size:13px}}
h2{{font-size:17px;margin:34px 0 14px;padding-bottom:8px;border-bottom:1px solid var(--border)}}
.overall{{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:18px 20px;margin-top:18px}}
.overall .big{{font-size:28px;font-weight:700}}
.obar{{height:14px;background:#21262d;border-radius:7px;overflow:hidden;margin:12px 0 6px}}
.obar>div{{height:100%;background:linear-gradient(90deg,#238636,#2ea043)}}
.ostat{{display:flex;gap:22px;flex-wrap:wrap;font-size:13px;color:var(--muted);margin-top:10px}}
.ostat b{{color:var(--text)}}
.legend{{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;margin:14px 0;color:var(--muted)}}
.legend span{{display:flex;align-items:center;gap:6px}}
.dot{{width:11px;height:11px;border-radius:3px;border:2px solid currentColor;display:inline-block}}
.cards{{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px}}
.epic-card{{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:16px;display:flex;flex-direction:column}}
.epic-card.done{{border-color:#238636}}
.epic-header{{display:flex;align-items:center;gap:8px;margin-bottom:10px}}
.epic-icon{{font-size:17px}}
.epic-title{{font-weight:700;font-size:14px;flex:1}}
.epic-badge{{font-size:11px;padding:3px 8px;border-radius:10px;background:#21262d;color:var(--muted);white-space:nowrap}}
.epic-card.done .epic-badge{{background:#1a4429;color:#3fb950}}
.divider{{margin:10px 0 4px;font-size:11px;color:var(--muted);font-weight:600}}
.issue-row{{display:flex;align-items:center;gap:8px;padding:3px 0;font-size:12.5px}}
.status-dot{{width:9px;height:9px;border-radius:50%;flex-shrink:0}}
.status-dot.done{{background:#3fb950}}.status-dot.ready{{background:#58a6ff}}.status-dot.todo{{background:#7d8590}}
.status-dot.inprogress{{background:#bc8cff}}.status-dot.review{{background:#d29922}}.status-dot.deferred{{background:#768390}}
.issue-num{{color:var(--muted);font-variant-numeric:tabular-nums;flex-shrink:0;font-size:11.5px}}
.issue-name{{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.tag{{font-size:10px;padding:1px 6px;border-radius:8px;flex-shrink:0;white-space:nowrap}}
.tag.done{{background:#1a4429;color:#3fb950}}.tag.ready{{background:#0d2a4a;color:#58a6ff}}.tag.todo{{background:#21262d;color:#7d8590}}
.tag.inprogress{{background:#2d1b4e;color:#bc8cff}}.tag.review{{background:#2d1f00;color:#d29922}}
.tag.imp{{background:#3a1d00;color:#f0883e}}.tag.deferred{{background:#1c2128;color:#768390}}
.tier-head{{font-size:14px;font-weight:700;margin:24px 0 12px;display:flex;align-items:center;gap:8px}}
.tier-head.p0{{color:#f0883e}}.tier-head.p1{{color:#d29922}}.tier-head.none{{color:var(--muted)}}
.tier-head .tdesc{{font-size:12px;font-weight:400;color:var(--muted)}}
.epic-badge.tier-p0{{background:#3a1d00;color:#f0883e}}.epic-badge.tier-p1{{background:#2d1f00;color:#d29922}}
.epic-card.deferred{{opacity:0.6;border-style:dashed}}
.defer-note{{font-size:12px;color:var(--muted);margin:6px 0 14px}}
.progress-bar-wrap{{display:flex;align-items:center;gap:8px;margin-top:auto;padding-top:12px}}
.progress-bar{{flex:1;height:8px;background:#21262d;border-radius:4px;overflow:hidden}}
.progress-fill{{height:100%;background:#238636}}
.progress-label{{font-size:11px;color:var(--muted);white-space:nowrap}}
details.donecard>summary{{cursor:pointer;list-style:none}}
details.donecard>summary::-webkit-details-marker{{display:none}}
.chips{{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px}}
.chip{{font-size:10.5px;padding:2px 6px;border-radius:8px;background:#1a4429;color:#3fb950;border:1px solid #238636}}
.graph-wrap{{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:14px 16px;margin-bottom:18px;overflow-x:auto}}
.graph-wrap h3{{font-size:14px;margin:0 0 4px}}
.graph-wrap .gsub{{font-size:11.5px;color:var(--muted);margin-bottom:10px}}
.graph-legend-strip{{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:14px;padding:8px 12px;background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:6px;font-size:12px}}
.gls-item{{display:flex;align-items:center;gap:6px;white-space:nowrap}}
.gls-dot{{display:inline-block;width:10px;height:10px;border-radius:2px;border:2px solid currentColor;flex-shrink:0}}
.rec{{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:6px 0}}
.rec-row{{padding:12px 18px;border-bottom:1px solid var(--border)}}
.rec-row:last-child{{border-bottom:none}}
.rec-head{{display:flex;align-items:center;gap:10px;flex-wrap:wrap}}
.rec-num{{font-weight:700;color:#58a6ff;font-size:14px}}
.rec-title{{font-size:13.5px}}
.rec-pill{{font-size:10.5px;padding:2px 8px;border-radius:9px;background:#0d2a4a;color:#58a6ff}}
.rec-pill.hot{{background:#3a1d00;color:#f0883e}}
.rec-pill.epic{{background:#21262d;color:var(--muted)}}
.rec-why{{font-size:12px;color:var(--muted);margin-top:6px;display:flex;flex-direction:column;gap:2px}}
.rec-why b{{color:#3fb950;font-weight:600}}
footer{{margin-top:40px;padding-top:16px;border-top:1px solid var(--border);color:var(--muted);font-size:12px}}
code{{background:#21262d;padding:1px 5px;border-radius:4px;font-size:11.5px}}
</style></head><body><div class="wrap">''')

w(f'''<header><h1>📊 Epic 진행 현황 — {html.escape(meta["repo"])}</h1>
<div class="sub">분석 시각 {html.escape(analyzed[:19].replace("T"," "))} UTC · 오픈 이슈 {meta["open_issues"]} · 완료 이슈 {meta["closed_issues"]} · 의존성 엣지 {len(dp["edges"])}개 (hard {hardN}/mockable {mockN})</div></header>''')

pct = round(done_sub / total_sub * 100) if total_sub else 0
w(f'''<div class="overall">
<div class="big">{pct}% <span style="font-size:14px;color:var(--muted);font-weight:400">서브이슈 완료 ({done_sub}/{total_sub})</span></div>
<div class="obar"><div style="width:{pct}%"></div></div>
<div class="ostat">
<span>Epic <b>{len(epics)}</b>개 (완료 <b style="color:#3fb950">{len(complete)}</b> · 진행 중 <b style="color:#bc8cff">{len(active)}</b>)</span>
<span>즉시 착수 가능 <b style="color:#58a6ff">{len(ready_n)}</b>개</span>
<span>진행 중 <b style="color:#bc8cff">{len(inprog_n)}</b>개 · 외부 대기 <b style="color:#d29922">{len(review_n)}</b>개</span>
<span>대기 <b>{len(todo_n)}</b>개</span>
<span>❄️ 동결 <b style="color:#768390">{len(deferred_n)}</b>개</span>
<span>실행 단계(Wave) <b>{len(EO["waves"])}</b>단계</span>
</div></div>''')

w('''<div class="legend">
<span style="color:#3fb950"><i class="dot"></i>완료 (Closed)</span>
<span style="color:#bc8cff"><i class="dot"></i>진행 중 (In Progress — 담당자/PR)</span>
<span style="color:#58a6ff"><i class="dot"></i>즉시 착수 가능 (Ready)</span>
<span style="color:#d29922"><i class="dot"></i>외부 대기 (HANDOFF — 서브레포/리뷰)</span>
<span style="color:#7d8590"><i class="dot"></i>대기 (Blocked — 선행 미완료)</span>
<span style="color:#f0883e"><i class="dot"></i>영향도 높음 (다수 unblock)</span>
<span style="color:#768390"><i class="dot"></i>❄️ 동결 (Deferred — priority:low, PoC v2 범위 밖)</span>
</div>''')

# 완료 Epic
w('<h2>✅ 완료된 Epic</h2><div class="cards">')
for E in sorted(complete):
    d = epics[E]
    chips = ''.join(f'<span class="chip">#{n}</span>' for n in sorted(d['closed']))
    w(f'''<div class="epic-card done"><details class="donecard"><summary>
<div class="epic-header"><span class="epic-icon">✅</span>
<span class="epic-title">{html.escape(d["label"])}</span>
<span class="epic-badge">{d["done"]}/{d["total"]} 완료</span></div>
<div class="progress-bar-wrap"><div class="progress-bar"><div class="progress-fill" style="width:100%"></div></div>
<span class="progress-label">100%</span></div></summary>
<div class="chips">{chips}</div></details></div>''')
w('</div>')

# 진행 중 Epic — 우선순위 티어별 + 동결 분리
TIER_DESC = {'P0': 'PoC v2 라우팅 본체 · 즉시 착수', 'P1': '관리 UX 마감 · P0 직후',
             'none': '우선순위 라벨 없음'}
def emit_epic_card(E, deferred_card=False):
    d = epics[E]
    grp = {'done': [], 'inprogress': [], 'review': [], 'ready': [], 'todo': [], 'deferred': []}
    for n in d['open'] + d['closed']:
        grp[status_of(n)].append(n)
    pctE = round(d['done'] / d['total'] * 100) if d['total'] else 0
    rows = []
    def emit(key, label):
        if not grp[key]:
            return
        rows.append(f'<div class="divider">{label}</div>')
        for n in sorted(grp[key], key=lambda x: (wave_of.get(x, 99), x)):
            st = status_of(n); imp = impact_d.get(n, 0)
            tag = (f'<span class="tag imp">★{imp} unblock</span>' if st == 'ready' and imp >= 3
                   else f'<span class="tag {st}">{STATUS_TXT[st]}</span>')
            rows.append(f'<div class="issue-row"><span class="status-dot {st}"></span>'
                        f'<span class="issue-num">#{n}</span><span class="issue-name">{short(n,44)}</span>{tag}</div>')
    emit('done', f'✅ 완료 ({len(grp["done"])})')
    emit('inprogress', f'▶ 진행 중 ({len(grp["inprogress"])})')
    emit('review', f'🔶 외부 대기 — HANDOFF ({len(grp["review"])})')
    emit('ready', f'⚡ 즉시 착수 가능 ({len(grp["ready"])})')
    emit('todo', f'⏳ 대기 — 선행 완료 후 ({len(grp["todo"])})')
    emit('deferred', f'❄️ 동결 ({len(grp["deferred"])})')
    t = etier(E)
    tbadge = (f'<span class="epic-badge tier-{t.lower()}">{TIER_BADGE[t]}</span>'
              if t in ('P0', 'P1') else '')
    icon = ('❄️' if deferred_card else
            ('🔥' if any(impact_d.get(n, 0) >= 5 for n in grp['ready']) else '🔧'))
    cls = 'epic-card deferred' if deferred_card else 'epic-card'
    w(f'''<div class="{cls}"><div class="epic-header"><span class="epic-icon">{icon}</span>
<span class="epic-title">{html.escape(d["label"])}</span>
{tbadge}<span class="epic-badge">{d["done"]}/{d["total"]} 완료</span></div>
<div class="issue-list">{''.join(rows)}</div>
<div class="progress-bar-wrap"><div class="progress-bar"><div class="progress-fill" style="width:{pctE}%"></div></div>
<span class="progress-label">{pctE}%</span></div></div>''')

w('<h2>🔧 진행 중인 Epic — 우선순위별</h2>')
for tier in ['P0', 'P1', 'none']:
    group = [E for E in active_sorted if etier(E) == tier]
    if not group:
        continue
    w(f'<div class="tier-head {tier.lower()}">{TIER_LABEL[tier]} '
      f'<span class="tdesc">{TIER_DESC[tier]} · {len(group)} epic</span></div>')
    w('<div class="cards">')
    for E in group:
        emit_epic_card(E)
    w('</div>')

# 동결(Deferred) Epic — priority:low, PoC v2 범위 밖
if deferred_epics:
    defcnt = sum(len(epics[E]['open']) for E in deferred_epics)
    w('<h2>❄️ 동결 (Deferred) — PoC v2 범위 밖</h2>')
    w(f'<div class="defer-note">priority:low 로 동결된 {len(deferred_epics)} epic · 오픈 {defcnt}개. '
      f'Wave 계산·착수 추천에서 제외됨(백로그 보존). PoC v2(LLM 라우팅) 완료 후 재검토.</div>')
    w('<div class="cards">')
    for E in deferred_epics:
        emit_epic_card(E, deferred_card=True)
    w('</div>')

# Epic 미소속 (standalone) 이슈
_ST_RANK = {'inprogress': 0, 'review': 1, 'ready': 2, 'todo': 3, 'deferred': 4, 'done': 5}
unepiced = sorted((n for n in num_state if num_state[n] == 'open' and n not in trackers and n not in issue_epic),
                  key=lambda n: (_ST_RANK.get(status_of(n), 9), n))
if unepiced:
    w('<h2>📌 Epic 미소속 — 독립 이슈</h2>')
    w('<div class="cards"><div class="epic-card"><div class="issue-list">')
    for n in unepiced:
        st = status_of(n)
        labs = ' '.join(f'<span class="tag todo">{html.escape(l)}</span>' for l in num_labels.get(n, []) if l not in ('claude',))
        w(f'<div class="issue-row"><span class="status-dot {st}"></span>'
          f'<span class="issue-num">#{n}</span><span class="issue-name">{short(n,50)}</span>'
          f'<span class="tag {st}">{STATUS_TXT[st]}</span>{labs}</div>')
    w('</div></div></div>')

# 의존성 그래프
w('<h2>🔗 의존성 그래프 — 무엇이 무엇을 막는가</h2>')
w('''<div class="graph-legend-strip">
<span class="gls-item" style="color:#3fb950"><span class="gls-dot" style="background:rgba(26,68,41,0.6)"></span>✅ 완료 (Closed)</span>
<span class="gls-item" style="color:#bc8cff"><span class="gls-dot" style="background:rgba(45,27,78,0.8)"></span>▶ 진행 중 (In Progress) — 담당자/PR 있음</span>
<span class="gls-item" style="color:#58a6ff"><span class="gls-dot" style="background:rgba(13,42,74,0.8)"></span>⚡ 즉시 착수 가능 (Ready) — 미배정·선행 완료</span>
<span class="gls-item" style="color:#d29922"><span class="gls-dot" style="background:rgba(45,31,0,0.8)"></span>🔶 외부 대기 (HANDOFF) — 서브레포/리뷰</span>
<span class="gls-item" style="color:#7d8590"><span class="gls-dot" style="background:rgba(33,38,45,0.8)"></span>⏳ 대기 (Blocked) — 선행 미완료</span>
</div>''')
w('<div style="font-size:12px;color:var(--muted);margin-bottom:12px">화살표: 선행(위) → 후행(아래). 실선 = hard(차단), 점선(주황) = mockable(목킹 가능·병렬). 각 Epic은 자체 셸(S0)에서 시작하는 독립 의존 체인.</div>')

def epic_svg(E):
    d = epics[E]
    open_nodes = d['open']; closed_nodes = d['closed']
    waves_here = {}
    deferred_here = []
    for n in open_nodes:
        if status_of(n) == 'deferred':   # 동결은 Wave 제외 → Wave 1 밴드 오배치 방지, 하단 별도 밴드
            deferred_here.append(n)
        else:
            waves_here.setdefault(wave_of.get(n, 1), []).append(n)
    W = 960; MX = 16; gap = 12
    bands = []
    if closed_nodes:
        bands.append(('done', sorted(closed_nodes)))
    for wv in sorted(waves_here):
        bands.append((wv, sorted(waves_here[wv])))
    if deferred_here:
        bands.append(('deferred', sorted(deferred_here)))
    BAND_LABEL = 22; BOX_H = 46; ROW_PAD = 18
    pos = {}; y = 6; layout = []
    for kind, nodes in bands:
        ny = y + BAND_LABEL; n = len(nodes)
        bw = max(96, (W - 2*MX - gap*(n-1)) / n)
        for i, node in enumerate(nodes):
            pos[node] = (MX + i*(bw+gap), ny, bw)
        layout.append((kind, nodes, y, ny)); y = ny + BOX_H + ROW_PAD
    H = y + 6
    s = [f'<svg viewBox="0 0 {W} {int(H)}" style="width:100%;display:block" xmlns="http://www.w3.org/2000/svg">',
         '<defs><marker id="ah" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#6e7681"/></marker>'
         '<marker id="ahm" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#9e6a03"/></marker></defs>']
    for idx, (kind, nodes, by, ny) in enumerate(layout):
        if kind == 'done':
            lbl = f'✅ 완료 (기반) — {len(nodes)}개'
        elif kind == 'deferred':
            lbl = f'❄️ 동결 (Deferred) — priority:low · Wave 제외 — {len(nodes)}개'
        elif any(status_of(nd) == 'ready' for nd in nodes):
            # 밴드 라벨은 위치가 아니라 실제 노드 상태 기준 — cross-epic 차단으로 첫 밴드가
            # Wave 1이 아닐 수도 있으므로(예: epic-66은 #300이 #281 대기로 Wave 2부터 시작).
            lbl = f'⚡ Wave {kind} — 즉시 착수 가능 (Ready)'
        else:
            lbl = f'Wave {kind} — 선행 완료 후 (Blocked)'
        s.append(f'<text x="{MX}" y="{by+14}" fill="#7d8590" font-size="11" font-weight="600">{html.escape(lbl)}</text>')
    for k, (f, t, kind) in enumerate(sorted(intra_edges.get(E, []))):
        if f not in pos or t not in pos:
            continue
        fx, fy, fw = pos[f]; tx, ty, tw = pos[t]
        sx = tx + tw/2; sy = ty + BOX_H; ex = fx + fw/2; ey = fy
        if ey <= sy:
            continue
        midy = sy + (ey - sy)*0.5 + ((k % 5) - 2)*3
        col = '#9e6a03' if kind == 'mockable' else '#484f58'
        dash = 'stroke-dasharray="4,3"' if kind == 'mockable' else ''
        mk = 'url(#ahm)' if kind == 'mockable' else 'url(#ah)'
        s.append(f'<path d="M{sx:.0f},{sy:.0f} L{sx:.0f},{midy:.0f} L{ex:.0f},{midy:.0f} L{ex:.0f},{ey:.0f}" '
                 f'fill="none" stroke="{col}" stroke-width="1.3" {dash} marker-end="{mk}" opacity="0.85"/>')
    for kind, nodes, by, ny in layout:
        for node in nodes:
            x, yy, bw = pos[node]
            st = 'done' if kind == 'done' else status_of(node)
            fill, stroke, txt = CLR[st]
            imp = impact_d.get(node, 0); hot = (st == 'ready' and imp >= 5)
            sw = 2.5 if hot else (2 if st == 'ready' else 1.5)
            sc = '#f85149' if hot else stroke
            s.append(f'<g transform="translate({x:.0f},{yy:.0f})">')
            s.append(f'<rect width="{bw:.0f}" height="{BOX_H}" rx="6" fill="{fill}" stroke="{sc}" stroke-width="{sw}"/>')
            star = ' ★' if hot else ''
            s.append(f'<text x="{bw/2:.0f}" y="14" text-anchor="middle" fill="{txt}" font-size="11.5" font-weight="700">#{node}{star}</text>')
            s.append(f'<text x="{bw/2:.0f}" y="27" text-anchor="middle" fill="{txt}" font-size="9">{vshort(node, max(10, int(bw/7)))}</text>')
            if st != 'done':
                bw2 = min(bw - 10, 92); bx = (bw - bw2)/2
                bf = {'ready': '#1f6feb', 'todo': '#484f58',
                      'inprogress': '#8957e5', 'review': '#9e6a03',
                      'deferred': '#373e47'}[st]
                bt = f'★{imp} unblock' if hot else STATUS_TXT[st]
                s.append(f'<rect x="{bx:.0f}" y="31" width="{bw2:.0f}" height="11" rx="3" fill="{bf}" opacity="0.35"/>')
                s.append(f'<text x="{bw/2:.0f}" y="39.5" text-anchor="middle" fill="{txt}" font-size="8.5" font-weight="600">{bt}</text>')
            s.append('</g>')
    s.append('</svg>')
    return '\n'.join(s)

def ename_of(t):
    e = issue_epic.get(t)
    return epics[e]['label'] if e in epics else (epics[t]['label'] if t in epics else f'#{t}')

for E in active_sorted:
    d = epics[E]
    cm = sorted({issue_epic.get(t, t) for n in d['open'] for t in cross_mock.get(n, set())})
    cm = [c for c in cm if c != E]
    note = ''
    if cm:
        names = ', '.join(f'#{c}' + (f'({epics[c]["name"]})' if c in epics else '') for c in cm)
        note = f' · 🔗 cross-epic mockable(병렬 가능): {html.escape(names)}'
    # cross-epic HARD: 다른 에픽 슬라이스가 끝나야 착수 가능 (차단). 구체 쌍을 명시.
    chard = sorted((n, t) for n in d['open'] for t in cross_hard.get(n, set()))
    hard_note = ''
    if chard:
        pairs = ', '.join(f'#{n} ⟵ #{t} ({html.escape(ename_of(t))})' for n, t in chard)
        hard_note = (f'<div style="font-size:11.5px;color:#d29922;margin-top:6px;'
                     f'padding:5px 8px;background:rgba(45,31,0,0.5);border:1px solid #9e6a03;border-radius:5px">'
                     f'⛔ cross-epic 선행(차단): {pairs} — 다른 에픽의 선행 슬라이스 완료 후 착수</div>')
    nready = sum(1 for n in d['open'] if status_of(n) == 'ready')
    depth = max([wave_of.get(n, 1) for n in d['open']], default=1)
    w(f'''<div class="graph-wrap"><h3>{html.escape(d["label"])}</h3>
<div class="gsub">{len(d["open"])}개 오픈 · 즉시 착수 {nready}개 · 최대 {depth}단계 깊이{note}</div>
{hard_note}
{epic_svg(E)}</div>''')

# 착수 추천
w('<h2>🚀 지금 착수 가능 — 우선순위 추천 (근거 포함)</h2>')
w('<div style="font-size:12px;color:var(--muted);margin-bottom:12px">※ 제안일 뿐 자동 착수가 아닙니다. 근거를 보고 사람이 판단해 시작하세요. 우선순위 티어(P0→P1) → 영향도(unblock 수) → 깊이 순. ❄️ 동결(priority:low)은 제외.</div>')
rec = sorted([n for n in wave1 if status_of(n) == 'ready'],
             key=lambda n: (TIER_RANK.get(issue_tier.get(n, 'none'), 2),
                            -impact_d.get(n, 0), -impact_t.get(n, 0), n))
w('<div class="rec">')
for n in rec[:10]:
    E = issue_epic.get(n); elabel = epics[E]['label'] if E in epics else '📌 독립 이슈'
    idr = impact_d.get(n, 0); itr = impact_t.get(n, 0)
    parallel = [m for m in epics[E]['open'] if m != n and status_of(m) == 'ready'] if E in epics else []
    hot = idr >= 5
    pills = []
    if 'priority:high' in num_labels.get(n, []):
        pills.append('<span class="rec-pill hot">priority:high</span>')
    if hot:
        pills.append('<span class="rec-pill hot">★ 핵심 경로</span>')
    pills.append(f'<span class="rec-pill epic">{html.escape(elabel)}</span>')
    why = ['<span><b>왜 지금:</b> 선행 hard 의존 없음 (Wave 1, 즉시 착수)</span>']
    why.append(f'<span><b>영향도:</b> 직접 {idr}개 · 전이 {itr}개 후속 unblock</span>' if idr > 0
               else '<span><b>영향도:</b> 독립 슬라이스 (후속 차단 없음)</span>')
    if parallel:
        why.append(f'<span><b>병렬:</b> 같은 그룹의 {", ".join(f"#{m}" for m in parallel[:5])} 와 동시 진행 가능</span>')
    w(f'''<div class="rec-row"><div class="rec-head">
<span class="rec-num">#{n}</span><span class="rec-title">{short(n,56)}</span>{''.join(pills)}</div>
<div class="rec-why">{''.join(why)}</div></div>''')
w('</div>')

w(f'''<footer>
생성: epic-dash 스킬 · 데이터 소스 {html.escape(meta.get("source","gh-cli"))} · 분석 {html.escape(analyzed[:19].replace("T"," "))} UTC<br>
의존성: 각 이슈 본문의 <code>선행 의존(deps)</code> 필드(hard=차단 / mockable=목킹 가능·병렬)를 파싱, 슬라이스ID를 이슈번호로 해석해 위상정렬. hard {hardN}개를 차단 기준, mockable {mockN}개는 병렬 순서 힌트로 사용.<br>
순환 의존성: {'⚠️ 감지됨' if EO.get("cycle_detected") else '없음 ✅'} · 위상정렬 {len(EO["waves"])}단계
</footer></div></body></html>''')

open(OUT, 'w').write('\n'.join(P))
print(f"HTML 생성 완료 → {OUT}")
print(f"  완료 epic {len(complete)} / 진행 중 {len(active)} / 작업노드 {len(open_work)} / ready {len(ready_n)} / wave {len(EO['waves'])}")
