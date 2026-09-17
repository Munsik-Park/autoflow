#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""AutoFlow cycle metrics — static HTML view (issue #268).

Reads $ROOT/issues.json (written by cycle-metrics.py) and writes ONE
self-contained HTML file: inline CSS, inline JS, inline data, no external
resource of any kind, so it opens without a network. Only aggregate values go
in — the same fields the session records hold, minus the working-directory
paths.

  Across issues  sortable table · cost against outcome (scatter, colour = arm)
                 · orchestrator / gate share over time
  One issue      result line · spawn timeline (role lane x time, colour = model,
                 re-written wakes ticked) · orchestrator context curve (gate
                 spawns and cold re-writes marked) · cost by phase, the base
                 context share (calls x first_in, per segment and per wake, then
                 summed) apart from the accumulated one

Idle stretches longer than 30 minutes are folded on the time axis, so a cycle
that waited a week on a reviewer still shows its working hours.

Usage:
  render-metrics.py [--root DIR] [--out FILE]

Only the standard library is used.
"""
import argparse
import json
import os
import sys

AGENT_FIELDS = ('id', 'role', 'model', 'description', 'phase_key', 'phase_key_method', 'phase_marker',
                'workflow', 'parent', 'start', 'end', 'calls', 'usage', 'first_in', 'max_context', 'rewrites')
ISSUE_FIELDS = ('key', 'repo', 'issue', 'arm', 'operator_minutes', 'note', 'operator_prompts',
                'operator_prompts_known', 'segments', 'prs', 'pr_states', 'outcome', 'totals')


def slim(issue):
    out = {k: issue.get(k) for k in ISSUE_FIELDS}
    out['sessions'] = len(issue.get('sessions') or [])
    out['segments'] = [[s['start'], s['end']] for s in issue.get('segments') or []]
    out['outcome'] = {k: v for k, v in (issue.get('outcome') or {}).items() if k != 'phase_markers'}
    out['orch'] = [[c[0], c[1], c[6]] for c in issue.get('orch_calls') or []]
    agents = []
    for a in issue.get('agents') or []:
        s = {k: a.get(k) for k in AGENT_FIELDS}
        s['wakes'] = [[w['start'], w['end'], w['calls'], w['first_in'], int(w['rewrite'])] for w in a.get('wakes') or []]
        agents.append(s)
    out['agents'] = agents
    return out


PAGE = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AutoFlow cycle metrics</title>
<style>
:root{color-scheme:light;--page:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--muted:#898781;
--grid:#e1e0d9;--axis:#c3c2b7;--ring:rgba(11,11,11,.10);--s1:#2a78d6;--s2:#eb6834;--s3:#1baf7a;--s4:#eda100;
--s1l:#9ec5f4;--crit:#d03b3b}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){color-scheme:dark;--page:#0d0d0d;--surface:#1a1a19;
--ink:#fff;--ink2:#c3c2b7;--muted:#898781;--grid:#2c2c2a;--axis:#383835;--ring:rgba(255,255,255,.10);
--s1:#3987e5;--s2:#d95926;--s3:#199e70;--s4:#c98500;--s1l:#9ec5f4;--crit:#d03b3b}}
*{box-sizing:border-box}
body{margin:0;background:var(--page);color:var(--ink);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1180px;margin:0 auto;padding:20px 16px 60px}
h1{font-size:20px;margin:0 0 2px}h2{font-size:15px;margin:0 0 8px}
.sub{color:var(--ink2);margin:0 0 16px}
.card{background:var(--surface);border:1px solid var(--ring);border-radius:8px;padding:14px;margin:0 0 14px;overflow:hidden}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:820px){.grid2{grid-template-columns:1fr}}
.scroll{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:13px}
th,td{padding:5px 8px;text-align:right;border-bottom:1px solid var(--grid);white-space:nowrap}
th:first-child,td:first-child{text-align:left}
th{color:var(--ink2);font-weight:600;cursor:pointer;user-select:none;position:sticky;top:0;background:var(--surface)}
tbody tr{cursor:pointer}tbody tr:hover{background:var(--page)}tbody tr.sel{outline:2px solid var(--s1);outline-offset:-2px}
.tiles{display:flex;flex-wrap:wrap;gap:8px 22px;margin:0 0 4px}
.tile b{display:block;font-size:20px;font-weight:600}.tile span{color:var(--ink2);font-size:12px}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;color:var(--ink2);font-size:12px;margin:0 0 6px}
.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:5px;vertical-align:-1px}
.note{color:var(--muted);font-size:12px;margin:6px 0 0}
svg{display:block;width:100%;height:auto}svg text{fill:var(--muted);font-size:11px}
svg .lab{fill:var(--ink2)}
select{font:inherit;color:inherit;background:var(--surface);border:1px solid var(--axis);border-radius:6px;padding:2px 6px}
#tip{position:fixed;pointer-events:none;background:var(--surface);color:var(--ink);border:1px solid var(--ring);
border-radius:6px;padding:6px 8px;font-size:12px;box-shadow:0 4px 14px rgba(0,0,0,.18);display:none;max-width:340px;z-index:9}
#tip b{font-weight:600}#tip div{color:var(--ink2)}
</style></head><body><main>
<h1>AutoFlow cycle metrics</h1>
<p class="sub" id="sub"></p>
<div class="card"><h2>Issues</h2><div class="scroll" style="max-height:420px"><table id="tbl"></table></div>
<p class="note">Click a row for the issue view below. Click a header to sort. Tokens = input + cache read + cache write + output, orchestrator and agents together.</p></div>
<div class="grid2">
<div class="card"><h2>Cost against outcome</h2>
<div class="legend" id="scLegend"></div>
<label class="note">y: <select id="ySel"></select></label><div id="scatter"></div></div>
<div class="card"><h2>Orchestrator and gate share of tokens, by issue start</h2>
<div class="legend"><span><i style="background:var(--s1)"></i>orchestrator</span><span><i style="background:var(--s2)"></i>gates (Evaluation AI)</span></div>
<div id="trend"></div></div></div>
<div class="card"><h2 id="iTitle"></h2><div class="tiles" id="tiles"></div><p class="note" id="iNote"></p></div>
<div class="card"><h2>Spawn timeline</h2><div class="legend" id="tlLegend"></div><div id="timeline"></div>
<p class="note">One lane per role; a bar is one agent, or one wake of a resumed agent. A red tick marks a wake whose whole prefix was re-written (cache write &ge; 0.9 of the cached prefix). Idle stretches over 30 minutes are folded (dashed rule).</p></div>
<div class="card"><h2>Orchestrator context per call</h2><div id="ctx"></div>
<p class="note">Vertical rules: a gate evaluation was spawned. Red dots: the orchestrator's own prefix was re-written.</p></div>
<div class="card"><h2>Input tokens by phase</h2>
<div class="legend"><span><i style="background:var(--s1)"></i>base context (calls &times; first_in)</span><span><i style="background:var(--s1l)"></i>accumulated beyond it</span></div>
<div id="cost"></div><div class="scroll"><table id="costTbl"></table></div></div>
</main><div id="tip"></div>
<script id="data" type="application/json">__DATA__</script>
<script>
"use strict";
const D=JSON.parse(document.getElementById('data').textContent),I=D.issues;
const $=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const fmt=n=>n==null||n===''?'–':n>=1e9?(n/1e9).toFixed(2)+'B':n>=1e6?(n/1e6).toFixed(1)+'M':n>=1e3?(n/1e3).toFixed(0)+'K':String(n);
const pct=v=>v==null?'–':(v*100).toFixed(1)+'%';
const T=s=>Date.parse(s);
const inTok=u=>u.input+u.cache_read+u.cache_creation;
function el(tag,attrs,parent,text){const e=document.createElementNS(NS,tag);for(const k in attrs)e.setAttribute(k,attrs[k]);
 if(text!=null)e.textContent=text;if(parent)parent.appendChild(e);return e}
function svg(host,w,h){host.innerHTML='';return el('svg',{viewBox:`0 0 ${w} ${h}`,role:'img'},host)}
const tip=$('tip');
function hover(node,html){node.addEventListener('mousemove',e=>{tip.innerHTML=html;tip.style.display='block';
 const x=Math.min(e.clientX+14,innerWidth-tip.offsetWidth-8),y=Math.min(e.clientY+14,innerHeight-tip.offsetHeight-8);
 tip.style.left=x+'px';tip.style.top=y+'px'});node.addEventListener('mouseleave',()=>tip.style.display='none')}
const MODEL_SLOT={opus:'--s1',sonnet:'--s2',haiku:'--s3'};
const modelColor=m=>`var(${MODEL_SLOT[m]||'--s4'})`;
const ARM_SLOT={A:'--s1',B:'--s2'};
const armColor=a=>`var(${ARM_SLOT[a]||'--s3'})`;
function ticks(lo,hi,n){const span=hi-lo||1,step=Math.pow(10,Math.floor(Math.log10(span/n)));
 const m=[1,2,5,10].find(k=>span/(step*k)<=n)||10,s=step*m,out=[];for(let v=Math.ceil(lo/s)*s;v<=hi+1e-9;v+=s)out.push(v);return out}

$('sub').textContent=`${I.length} issues · generated ${D.generated} · machine-local aggregate, no transcript text`;

// ---- table
const COLS=[['key','issue'],['arm','arm'],['wall_h','wall h',i=>i.totals.wall_h],['tokens','tokens',i=>i.totals.tokens,fmt],
 ['orch','orch share',i=>i.totals.orch_share,pct],['gate','gate share',i=>i.totals.gate_share,pct],
 ['ctx','peak orch ctx',i=>i.totals.max_orch_context,fmt],['rw','re-writes',i=>i.totals.rewrites],
 ['sp','spawns',i=>i.totals.spawns],['op','operator prompts',i=>i.operator_prompts_known?i.operator_prompts:null],
 ['cycle','cycle',i=>i.outcome.cycle],['gp','GATE:PLAN',i=>i.outcome.gate_plan],['gq','GATE:QUALITY',i=>i.outcome.gate_quality],
 ['ar','ARCHITECT rounds',i=>i.outcome.architect_rounds],['af','review-autofix',i=>i.outcome.review_autofix],
 ['rr','reviewer rounds',i=>i.outcome.reviewer_rounds],['ci','CI fail rounds',i=>i.outcome.ci_fail_rounds],
 ['pr','PR',i=>Object.values(i.pr_states||{}).filter(Boolean).join(' ')||null]];
let sortCol='key',sortDir=1,current=null;
const val=(i,c)=>c[2]?c[2](i):i[c[0]];
function drawTable(){const c=COLS.find(c=>c[0]===sortCol);
 const rows=[...I].sort((a,b)=>{const x=val(a,c),y=val(b,c);if(x==null)return 1;if(y==null)return -1;return(x>y?1:x<y?-1:0)*sortDir});
 $('tbl').innerHTML='<thead><tr>'+COLS.map(c=>`<th data-c="${c[0]}">${esc(c[1])}${c[0]===sortCol?(sortDir>0?' ▲':' ▼'):''}</th>`).join('')+
 '</tr></thead><tbody>'+rows.map(i=>`<tr data-k="${esc(i.key)}" class="${i.key===current?'sel':''}">`+COLS.map(c=>{const v=val(i,c);
 return `<td>${esc(v==null||v===''?'–':c[3]?c[3](v):v)}</td>`}).join('')+'</tr>').join('')+'</tbody>'}
$('tbl').addEventListener('click',e=>{const th=e.target.closest('th'),tr=e.target.closest('tbody tr');
 if(th){const k=th.dataset.c;sortDir=k===sortCol?-sortDir:1;sortCol=k;drawTable()}else if(tr)show(tr.dataset.k)});

// ---- scatter
const YS=[['gate_quality','GATE:QUALITY average'],['gate_plan','GATE:PLAN average'],['review_autofix','review-autofix attempts'],
 ['reviewer_rounds','reviewer rounds'],['ci_fail_rounds','CI fail rounds'],['cycle','cycles'],['architect_rounds','ARCHITECT rounds']];
$('ySel').innerHTML=YS.map(y=>`<option value="${y[0]}">${y[1]}</option>`).join('');
$('ySel').addEventListener('change',drawScatter);
function drawScatter(){const yk=$('ySel').value,pts=I.filter(i=>i.outcome[yk]!=null&&i.totals.tokens>0);
 const W=540,H=300,L=44,R=12,Tp=10,B=34,s=svg($('scatter'),W,H);
 const arms=[...new Set(I.map(i=>i.arm||'–'))].sort();
 $('scLegend').innerHTML=arms.map(a=>`<span><i style="background:${armColor(a)};border-radius:50%"></i>arm ${esc(a)}</span>`).join('');
 if(!pts.length){el('text',{x:W/2,y:H/2,'text-anchor':'middle'},s,'no issue carries this outcome yet');return}
 const xs=pts.map(i=>i.totals.tokens/1e6),ys=pts.map(i=>i.outcome[yk]);
 const x1=Math.max(...xs)*1.05,y0=Math.min(0,...ys),y1=Math.max(...ys)*1.08||1;
 const X=v=>L+(v/x1)*(W-L-R),Y=v=>H-B-((v-y0)/(y1-y0))*(H-B-Tp);
 for(const t of ticks(y0,y1,5)){el('line',{x1:L,x2:W-R,y1:Y(t),y2:Y(t),stroke:'var(--grid)'},s);el('text',{x:L-6,y:Y(t)+4,'text-anchor':'end'},s,+t.toFixed(2))}
 for(const t of ticks(0,x1,6))el('text',{x:X(t),y:H-B+16,'text-anchor':'middle'},s,t+'M');
 el('line',{x1:L,x2:W-R,y1:H-B,y2:H-B,stroke:'var(--axis)'},s);el('text',{x:W-R,y:H-4,'text-anchor':'end'},s,'tokens');
 for(const i of pts){const c=el('circle',{cx:X(i.totals.tokens/1e6),cy:Y(i.outcome[yk]),r:5,fill:armColor(i.arm||'–'),stroke:'var(--surface)','stroke-width':2,style:'cursor:pointer'},s);
  hover(c,`<b>${esc(i.key)}</b><div>${fmt(i.totals.tokens)} tokens · ${esc(yk)} ${esc(i.outcome[yk])} · arm ${esc(i.arm||'–')}</div>`);c.addEventListener('click',()=>show(i.key))}}

// ---- trend
function drawTrend(){const pts=I.filter(i=>i.totals.tokens>0&&i.segments.length).map(i=>({i,t:T(i.segments[0][0])})).sort((a,b)=>a.t-b.t);
 const W=540,H=300,L=44,R=12,Tp=10,B=34,s=svg($('trend'),W,H);if(!pts.length)return;
 const X=k=>L+(pts.length<2?.5:k/(pts.length-1))*(W-L-R),Y=v=>H-B-v*(H-B-Tp);
 for(const t of[0,.25,.5,.75,1]){el('line',{x1:L,x2:W-R,y1:Y(t),y2:Y(t),stroke:'var(--grid)'},s);el('text',{x:L-6,y:Y(t)+4,'text-anchor':'end'},s,t*100+'%')}
 el('line',{x1:L,x2:W-R,y1:H-B,y2:H-B,stroke:'var(--axis)'},s);
 const first=new Date(pts[0].t).toISOString().slice(0,10),last=new Date(pts[pts.length-1].t).toISOString().slice(0,10);
 el('text',{x:L,y:H-B+16},s,first);el('text',{x:W-R,y:H-B+16,'text-anchor':'end'},s,last);
 for(const[k,col]of[['orch_share','var(--s1)'],['gate_share','var(--s2)']]){
  el('polyline',{points:pts.map((p,n)=>X(n)+','+Y(p.i.totals[k]||0)).join(' '),fill:'none',stroke:col,'stroke-width':2,'stroke-linejoin':'round'},s);
  pts.forEach((p,n)=>{const c=el('circle',{cx:X(n),cy:Y(p.i.totals[k]||0),r:4,fill:col,stroke:'var(--surface)','stroke-width':2,style:'cursor:pointer'},s);
   hover(c,`<b>${esc(p.i.key)}</b><div>orchestrator ${pct(p.i.totals.orch_share)} · gates ${pct(p.i.totals.gate_share)}</div>`);c.addEventListener('click',()=>show(p.i.key))})}}

// ---- folded time axis
function axis(iss,L,W){const iv=[];for(const a of iss.agents)if(a.start&&a.end)iv.push([T(a.start),T(a.end)]);
 for(const c of iss.orch)iv.push([T(c[0]),T(c[0])]);iv.sort((a,b)=>a[0]-b[0]);
 const blocks=[];for(const[a,b]of iv){const l=blocks[blocks.length-1];if(l&&a-l[1]<=18e5)l[1]=Math.max(l[1],b);else blocks.push([a,b])}
 const GAP=14,active=blocks.reduce((s,b)=>s+Math.max(b[1]-b[0],6e4),0),room=W-L-GAP*(blocks.length-1);
 let x=L;const map=blocks.map(b=>{const w=Math.max(b[1]-b[0],6e4)/active*room,o={t0:b[0],t1:b[1],x0:x,x1:x+w};x+=w+GAP;return o});
 const X=t=>{for(const m of map){if(t<=m.t1)return t<=m.t0?m.x0:m.x0+(t-m.t0)/Math.max(m.t1-m.t0,1)*(m.x1-m.x0)}return map.length?map[map.length-1].x1:L};
 return{X,map}}
function drawAxis(s,ax,y0,y1){ax.map.forEach((m,n)=>{if(n)el('line',{x1:m.x0-7,x2:m.x0-7,y1:y0,y2:y1,stroke:'var(--axis)','stroke-dasharray':'3 3'},s);
 if(m.x1-m.x0>70)el('text',{x:m.x0,y:y1+14},s,new Date(m.t0).toISOString().slice(5,16).replace('T',' '))})}

// ---- issue view
function show(key){const iss=I.find(i=>i.key===key);if(!iss)return;current=key;drawTable();const o=iss.outcome,t=iss.totals;
 $('iTitle').textContent=`${iss.key}${iss.arm?' · arm '+iss.arm:''}`;
 const tiles=[['tokens',fmt(t.tokens)],['orchestrator',pct(t.orch_share)],['gates',pct(t.gate_share)],['wall',t.wall_h+' h'],
  ['peak orch context',fmt(t.max_orch_context)],['re-writes',t.rewrites],['spawns',t.spawns],['phase keys',`${t.phase_keys_recovered}/${t.spawns}`],
  ['cycle',o.cycle],['GATE:PLAN',o.gate_plan],['AUDIT',o.audit],['GATE:QUALITY',o.gate_quality],['ARCHITECT rounds',o.architect_rounds],
  ['review-autofix',o.review_autofix],['reviewer rounds',o.reviewer_rounds],['CI fail rounds',o.ci_fail_rounds],['CI logs undetermined',o.ci_undetermined||null],
  ['operator prompts',iss.operator_prompts_known?iss.operator_prompts:null],['operator min',iss.operator_minutes||null]];
 $('tiles').innerHTML=tiles.map(([l,v])=>`<div class="tile"><b>${esc(v==null?'–':v)}</b><span>${esc(l)}</span></div>`).join('');
 $('iNote').textContent=[iss.sessions+' session(s)',o.artifacts?'outcome from '+o.artifacts+' .autoflow':'no .autoflow artifacts found',
  o.state_phase,(iss.prs||[]).map(p=>p+(iss.pr_states[p]?' '+iss.pr_states[p]:'')).join(', '),iss.note].filter(Boolean).join(' · ');
 drawTimeline(iss);drawCtx(iss);drawCost(iss)}

function drawTimeline(iss){const roles=[...new Set(iss.agents.map(a=>a.workflow?'workflow':a.role||'?'))];
 const W=1140,L=150,RH=24,H=roles.length*RH+30,s=svg($('timeline'),W,Math.max(H,60)),ax=axis(iss,L,W-10);
 const models=[...new Set(iss.agents.map(a=>a.model||'?'))];
 $('tlLegend').innerHTML=models.map(m=>`<span><i style="background:${modelColor(m)}"></i>${esc(m)}</span>`).join('');
 roles.forEach((r,n)=>{el('text',{x:L-8,y:n*RH+17,'text-anchor':'end',class:'lab'},s,r.replace('autoflow-',''));
  el('line',{x1:L,x2:W-10,y1:n*RH+RH,y2:n*RH+RH,stroke:'var(--grid)'},s)});
 drawAxis(s,ax,0,roles.length*RH);
 for(const a of iss.agents){const n=roles.indexOf(a.workflow?'workflow':a.role||'?'),ws=a.wakes.length?a.wakes:[[a.start,a.end,a.calls,a.first_in,0]];
  ws.forEach((w,k)=>{if(!w[0])return;const x0=ax.X(T(w[0])),x1=Math.max(ax.X(T(w[1])),x0+3);
   const r=el('rect',{x:x0,y:n*RH+5,width:x1-x0,height:RH-10,rx:3,fill:modelColor(a.model),stroke:'var(--surface)','stroke-width':1},s);
   if(w[4])el('rect',{x:x0-1,y:n*RH+2,width:2,height:RH-4,fill:'var(--crit)'},s);
   hover(r,`<b>${esc(a.description||a.role)}</b><div>${esc(a.phase_key||a.phase_marker||'phase key not recovered')}${a.phase_key_method?' ('+esc(a.phase_key_method)+')':''} · ${esc(a.model||'?')}</div>`+
    `<div>${ws.length>1?'wake '+(k+1)+'/'+ws.length+' · ':''}${w[2]} calls · opened at ${fmt(w[3])}${w[4]?' · prefix re-written':''}</div>`+
    `<div>agent: ${fmt(inTok(a.usage))} in · ${fmt(a.usage.output)} out · peak ${fmt(a.max_context)}</div>`)})}}

function drawCtx(iss){const W=1140,L=60,H=240,B=26,Tp=10,s=svg($('ctx'),W,H),ax=axis(iss,L,W-10),pts=iss.orch;
 if(!pts.length){el('text',{x:W/2,y:H/2,'text-anchor':'middle'},s,'no orchestrator call in this issue\'s segments');return}
 const y1=Math.max(...pts.map(p=>p[1]))*1.06,Y=v=>H-B-(v/y1)*(H-B-Tp);
 for(const t of ticks(0,y1,5)){el('line',{x1:L,x2:W-10,y1:Y(t),y2:Y(t),stroke:'var(--grid)'},s);el('text',{x:L-6,y:Y(t)+4,'text-anchor':'end'},s,fmt(t))}
 drawAxis(s,ax,Tp,H-B);
 for(const a of iss.agents)if(a.role==='autoflow-evaluator'&&a.start){const x=ax.X(T(a.start));
  const ln=el('line',{x1:x,x2:x,y1:Tp,y2:H-B,stroke:'var(--axis)','stroke-width':6,'stroke-opacity':.01},s);
  el('line',{x1:x,x2:x,y1:Tp,y2:H-B,stroke:'var(--s2)','stroke-width':1},s);hover(ln,`<b>${esc(a.description||'gate')}</b><div>${esc(a.phase_key||'')}</div>`)}
 el('polyline',{points:pts.map(p=>ax.X(T(p[0]))+','+Y(p[1])).join(' '),fill:'none',stroke:'var(--s1)','stroke-width':2,'stroke-linejoin':'round'},s);
 for(const p of pts)if(p[2]){const c=el('circle',{cx:ax.X(T(p[0])),cy:Y(p[1]),r:4,fill:'var(--crit)',stroke:'var(--surface)','stroke-width':2},s);
  hover(c,`<b>prefix re-written</b><div>${esc(p[0].slice(0,16).replace('T',' '))} · context ${fmt(p[1])}</div>`)}
 const hit=el('rect',{x:L,y:Tp,width:W-10-L,height:H-B-Tp,fill:'transparent'},s),cross=el('line',{y1:Tp,y2:H-B,stroke:'var(--axis)',visibility:'hidden'},s);
 s.insertBefore(hit,s.firstChild);
 hit.addEventListener('mousemove',e=>{const r=s.getBoundingClientRect(),x=(e.clientX-r.left)/r.width*W;let best=pts[0],bd=1e9;
  for(const p of pts){const d=Math.abs(ax.X(T(p[0]))-x);if(d<bd){bd=d;best=p}}
  cross.setAttribute('x1',ax.X(T(best[0])));cross.setAttribute('x2',ax.X(T(best[0])));cross.setAttribute('visibility','visible');
  tip.innerHTML=`<b>${fmt(best[1])} context</b><div>${esc(best[0].slice(0,16).replace('T',' '))}</div>`;tip.style.display='block';
  tip.style.left=Math.min(e.clientX+14,innerWidth-180)+'px';tip.style.top=(e.clientY+14)+'px'});
 hit.addEventListener('mouseleave',()=>{tip.style.display='none';cross.setAttribute('visibility','hidden')})}

function drawCost(iss){const g={};
 const add=(k,base,total,out,calls)=>{const r=g[k]||(g[k]={k,base:0,total:0,out:0,calls:0,n:0});r.base+=Math.min(base,total);r.total+=total;r.out+=out;r.calls+=calls;r.n++};
 const oc=iss.orch.length,ot=iss.totals.orchestrator;add('orchestrator',iss.totals.orch_base,inTok(ot),ot.output,oc);
 for(const a of iss.agents){const ws=a.wakes.length?a.wakes:[[0,0,a.calls,a.first_in,0]];
  add(a.phase_key||a.phase_marker||(a.role||'?').replace('autoflow-','')+' (no key)',ws.reduce((s,w)=>s+w[2]*w[3],0),inTok(a.usage),a.usage.output,a.calls)}
 const rows=Object.values(g).sort((a,b)=>b.total-a.total),W=1140,L=230,RH=22,H=rows.length*RH+24,s=svg($('cost'),W,H);
 const x1=Math.max(...rows.map(r=>r.total))||1,X=v=>v/x1*(W-L-70);
 rows.forEach((r,n)=>{el('text',{x:L-8,y:n*RH+15,'text-anchor':'end',class:'lab'},s,r.k);
  const b=el('rect',{x:L,y:n*RH+4,width:Math.max(X(r.base),1),height:RH-8,fill:'var(--s1)'},s);
  const c=el('rect',{x:L+X(r.base)+2,y:n*RH+4,width:Math.max(X(r.total-r.base)-2,0),height:RH-8,rx:3,fill:'var(--s1l)'},s);
  el('text',{x:L+X(r.total)+6,y:n*RH+15,class:'lab'},s,fmt(r.total));
  const h=`<b>${esc(r.k)}</b><div>${r.n>1?r.n+' agents · ':''}${r.calls} calls</div><div>base ${fmt(r.base)} (${pct(r.total?r.base/r.total:0)}) · accumulated ${fmt(r.total-r.base)} · output ${fmt(r.out)}</div>`;hover(b,h);hover(c,h)});
 for(const t of ticks(0,x1,6))el('text',{x:L+X(t),y:H-4,'text-anchor':'middle'},s,fmt(t));
 $('costTbl').innerHTML='<thead><tr><th>phase</th><th>agents</th><th>calls</th><th>input tokens</th><th>base</th><th>accumulated</th><th>output</th></tr></thead><tbody>'+
  rows.map(r=>`<tr><td>${esc(r.k)}</td><td>${r.k==='orchestrator'?'–':r.n}</td><td>${r.calls}</td><td>${fmt(r.total)}</td><td>${fmt(r.base)}</td><td>${fmt(r.total-r.base)}</td><td>${fmt(r.out)}</td></tr>`).join('')+'</tbody>'}

drawTable();drawScatter();drawTrend();
if(I.length)show([...I].sort((a,b)=>b.totals.tokens-a.totals.tokens)[0].key);
</script></body></html>
'''


def main(argv=None):
    archive = os.environ.get('AUTOFLOW_ARCHIVE_ROOT') or os.path.join(os.path.expanduser('~'), '.autoflow')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=os.path.join(archive, '_metrics'))
    ap.add_argument('--out', help='Default: <root>/cycle-metrics.html')
    args = ap.parse_args(argv)
    src = os.path.join(args.root, 'issues.json')
    try:
        with open(src, encoding='utf-8') as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        print('render-metrics: cannot read %s (%s) — run cycle-metrics.py first' % (src, e), file=sys.stderr)
        return 1
    import datetime as dt
    payload = {
        'generated': dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d %H:%MZ'),
        'issues': [slim(i) for i in data.get('issues') or []],
    }
    blob = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    out = args.out or os.path.join(args.root, 'cycle-metrics.html')
    with open(out, 'w', encoding='utf-8') as f:
        f.write(PAGE.replace('__DATA__', blob))
    print('render: %d issues -> %s' % (len(payload['issues']), out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
