#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""AutoFlow cycle cost / outcome collector (issue #268).

A record tool, machine-local: it reads what Claude Code already left on disk and
keeps the aggregate, because the transcripts expire and the archive does not
hold them. It changes no rule, gate, hook or bundle, is no gate input, and is
not shipped to a target (same disposition as scripts/architect/deliberation-metrics.py).

Two steps, run together by default:

  collect  ~/.claude/projects/*/<session>.jsonl
           + <session>/subagents/*.jsonl + <session>/subagents/workflows/*/*.jsonl
           -> $ROOT/sessions/<session-id>.json, written once per session and left
           alone afterwards. A session whose last record is younger than
           --settle-hours is not finalized yet and is skipped. The one case a
           session file is written again is a source that GREW after collection
           (a resumed session): the new aggregate is a superset of the old one.
           A source that shrank or vanished never touches the record.

  derive   $ROOT/sessions/*.json + $ROOT/labels.tsv + the .autoflow archive
           -> $ROOT/issues.tsv and $ROOT/issues.json, REGENERATED on every run,
           so a fix to the attribution logic recomputes every past issue.

$ROOT is ${AUTOFLOW_ARCHIVE_ROOT:-$HOME/.autoflow}/_metrics.

What a session record holds is aggregate only — per agent: role (`agentType`),
model, the spawn's short `description` label, phase-key, call count, cache
read / write / output, peak context, start / end, per-wake figures; for the
orchestrator: one row per API call (timestamp, context, cache read / write,
output, re-write flag); the `.autoflow/issue-{N}` reference runs; operator
prompt timestamps. No transcript text, tool output or prompt body is stored.

Phase-key recovery. Every spawn is preceded (a `[MUST]`) by a
`spawn-policy.sh model <phase-key>` readout, so the key is recovered from the
orchestrator's Bash calls: literal keys and the word list of a `for k in ...`
loop around the readout. Readouts are often batched, so the candidates are
narrowed by the policy's own `agent_type` for the spawn's `subagent_type`. The
spawn's description label decides among them (`readout+description`; plain
`description` when the named key was never read out in the session); a label
that names no key falls to the one unspent readout of that role (`readout`),
then to a role the policy maps to a single key (`agent-type`). Workflow
sub-agents take `<workflow>/<site>` (`workflow-site`). Each agent records the
method that decided it, or null, and the run prints the recovery rate.

Usage:
  cycle-metrics.py [--projects-root DIR]... [--root DIR] [--archive-root DIR]
                   [--settle-hours H] [--now ISO] [--session ID]...
                   [--policy FILE] [--no-collect] [--no-derive] [--gh]

Only the standard library is used.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True   # no __pycache__ in the checkout: PREFLIGHT wants a clean tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from transcript_stats import (  # noqa: E402
    context_of, dedup_calls, is_rewrite, is_wake, load, parse_ts, tool_use_blocks, wake_indices,
)

SCHEMA = 1
PK_RE = re.compile(r'spawn-policy\.sh["\']?\s+(?:model|effort)\s+([A-Za-z0-9][A-Za-z0-9_-]*)')
PK_LOOP_RE = re.compile(r'\bfor\s+\w+\s+in\s+([^;\n]+?)\s*;\s*do\b')
ISSUE_RE = re.compile(r'\.autoflow/issue-(\d+)(?=[-./\s"\'`)\\]|$)')   # not a truncated preview (`issue-5…`)
WF_ISSUE_RE = re.compile(r'''["']?issue["']?\s*[:=]\s*["']?#?(\d+)''')
SWITCH_REFS = 3       # consecutive references that move the session to another issue
TAIL_S = 1800         # a segment reaches this far past its last reference, no further
DESC_MAX = 80
USAGE_KEYS = ('input', 'cache_creation', 'cache_read', 'output')


# --------------------------------------------------------------------------- collect

def load_policy(path):
    """{phase-key: agent_type} and {workflow: {site: model}} from the spawn policy, or empty."""
    try:
        with open(path, encoding='utf-8') as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}, {}
    phases = cfg.get('phases') or {}
    keys = {k: (v or {}).get('agent_type') for k, v in phases.items()} if isinstance(phases, dict) else {}
    return keys, cfg.get('workflow_sites') or {}


def role_of(agent_type):
    return (agent_type or '').split(':')[-1]


def tokens(s):
    return set(re.findall(r'[a-z0-9]+', (s or '').lower()))


def readout_keys(block):
    """Phase keys one orchestrator Bash call read out."""
    if isinstance(block.get('phase_keys'), list):
        return list(block['phase_keys'])
    cmd = (block.get('input') or {}).get('command') or ''
    if 'spawn-policy' not in cmd:
        return []
    keys = PK_RE.findall(cmd)
    for words in PK_LOOP_RE.findall(cmd):
        keys.extend(w for w in words.split() if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', w))
    out = []
    for k in keys:
        if k not in out:
            out.append(k)
    return out


def issue_refs(block):
    if isinstance(block.get('issues'), list):
        return sorted({int(n) for n in block['issues']})
    inp = block.get('input')
    if not inp:
        return []
    blob = json.dumps(inp, ensure_ascii=False)
    found = set(ISSUE_RE.findall(blob))
    if block.get('name') in ('Workflow', 'Skill'):
        found |= set(WF_ISSUE_RE.findall(blob.replace('\\"', '"')))
    return sorted(int(n) for n in found)


def best_by_description(cands, desc):
    dt_ = tokens(desc)
    scored = []
    for k in cands:
        kt = tokens(k)
        if kt:
            scored.append((len(kt & dt_) / len(kt), k))
    if not scored:
        return None
    top = max(s for s, _ in scored)
    if top <= 0:
        return None
    winners = [k for s, k in scored if s == top]
    return winners[0] if len(winners) == 1 else None


def recover_phase_key(role, desc, pending, pool, policy_keys):
    """(phase_key, method) for one orchestrator spawn. `pending` is consumed by a plain `readout`."""
    def of_role(keys):
        if not policy_keys:
            return list(keys)
        return [k for k in keys if policy_keys.get(k) == role]

    vocab = of_role(policy_keys) if policy_keys else list(pool)
    named = best_by_description(vocab, desc)
    if named:
        return named, 'readout+description' if named in pool else 'description'
    # The label names no key: only a readout not yet spent on an earlier spawn decides.
    fresh = of_role(pending)
    if len(fresh) == 1:
        pending.remove(fresh[0])
        return fresh[0], 'readout'
    if len(vocab) == 1:
        return vocab[0], 'agent-type'
    return None, None


def is_operator_prompt(rec):
    if not is_wake(rec) or rec.get('isMeta') or rec.get('isSidechain'):
        return None
    origin = rec.get('origin')
    if isinstance(origin, dict):
        return origin.get('kind') == 'human'
    if rec.get('promptSource'):
        return rec['promptSource'] == 'typed'
    if isinstance(rec.get('user'), dict):
        return None          # a stripped record keeps no origin: not derivable
    content = (rec.get('message') or {}).get('content')
    text = content if isinstance(content, str) else ''.join(
        p.get('text', '') for p in content or [] if isinstance(p, dict))
    return bool(text) and not text.lstrip().startswith('<')


def sum_usage(calls):
    tot = dict.fromkeys(USAGE_KEYS, 0)
    for c in calls:
        for k in USAGE_KEYS:
            tot[k] += c[k]
    return tot


def span(recs):
    ts = [r.get('timestamp') for r in recs if r.get('timestamp')]
    return (min(ts), max(ts)) if ts else (None, None)


def agent_record(path, meta):
    recs = load(path)
    assistant = [r for r in recs if r.get('type') == 'assistant']
    calls = dedup_calls(assistant)
    start, end = span(recs)
    wakes = []
    idx = wake_indices(recs)
    for j, lo in enumerate(idx):
        hi = idx[j + 1] if j + 1 < len(idx) else len(recs)
        wc = dedup_calls([r for r in recs[lo:hi] if r.get('type') == 'assistant'])
        ws, we = span(recs[lo:hi])
        wakes.append({
            'start': ws, 'end': we, 'calls': len(wc),
            'first_in': context_of(wc[0]) if wc else 0,
            'first_cache_creation': wc[0]['cache_creation'] if wc else 0,
            'rewrite': bool(wc) and j > 0 and is_rewrite(wc[0]),
            'usage': sum_usage(wc),
        })
    tools = {}
    seen = set()
    for r in assistant:
        for b in tool_use_blocks(r):
            if b.get('id') in seen:
                continue
            seen.add(b.get('id'))
            tools[b.get('name') or '?'] = tools.get(b.get('name') or '?', 0) + 1
    models = {}
    for c in calls:
        if c['model']:
            models[c['model']] = models.get(c['model'], 0) + 1
    return {
        'id': os.path.basename(path)[len('agent-'):-len('.jsonl')],
        'role': role_of(meta.get('agentType')),
        'agent_type': meta.get('agentType'),
        'model': meta.get('model'),
        'api_models': models,
        'description': (meta.get('description') or '')[:DESC_MAX],
        'tool_use_id': meta.get('toolUseId'),
        'parent': meta.get('parentAgentId'),
        'depth': meta.get('spawnDepth'),
        'workflow_phase': meta.get('workflowPhase'),
        'phase_key': None, 'phase_key_method': None,
        'start': start, 'end': end,
        'calls': len(calls),
        'requests': len({r.get('requestId') for r in assistant if r.get('requestId')}),
        'usage': sum_usage(calls),
        'first_in': context_of(calls[0]) if calls else 0,
        'max_context': max((context_of(c) for c in calls), default=0),
        'rewrites': sum(1 for i, c in enumerate(calls) if i > 0 and is_rewrite(c)),
        'wakes': wakes,
        'tools': tools,
    }


def read_meta(jsonl):
    try:
        with open(jsonl[:-len('.jsonl')] + '.meta.json', encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def session_files(main):
    base = main[:-len('.jsonl')]
    direct = sorted(glob.glob(os.path.join(base, 'subagents', 'agent-*.jsonl')))
    wf = sorted(glob.glob(os.path.join(base, 'subagents', 'workflows', '*', 'agent-*.jsonl')))
    return direct, wf


def source_bytes(main):
    direct, wf = session_files(main)
    total = 0
    for p in [main] + direct + wf:
        try:
            total += os.path.getsize(p)
        except OSError:
            pass
    return total, 1 + len(direct) + len(wf)


def collect_session(main, policy_keys):
    recs = load(main)
    sid = os.path.basename(main)[:-len('.jsonl')]
    assistant = [r for r in recs if r.get('type') == 'assistant']
    calls = dedup_calls(assistant)
    start, end = span(recs)

    def distinct(field):
        seen = []
        for r in recs:
            v = r.get(field)
            if isinstance(v, str) and v and v not in seen:
                seen.append(v)
        return seen

    # One pass over the orchestrator's tool calls, in order: readouts, spawns, issue references.
    pending, pool = [], []
    spawn_keys = {}                     # tool_use id -> (phase_key, method)
    refs = []                           # [issue, first_ts, last_ts, count] runs
    state_writes = []
    tools = {}
    seen = set()
    for r in assistant:
        for b in tool_use_blocks(r):
            if b.get('id') in seen:
                continue
            seen.add(b.get('id'))
            name = b.get('name') or '?'
            tools[name] = tools.get(name, 0) + 1
            inp = b.get('input') or {}
            if name == 'Bash':
                keys = readout_keys(b)
                if keys:
                    pending = keys
                    pool = keys + [k for k in pool if k not in keys]
            elif name in ('Agent', 'Task'):
                role = role_of(inp.get('subagent_type') or b.get('subagent_type'))
                desc = inp.get('description') or b.get('description') or ''
                spawn_keys[b.get('id')] = recover_phase_key(role, desc, pending, pool, policy_keys)
            for n in issue_refs(b):
                ts = r.get('timestamp')
                if refs and refs[-1][0] == n:
                    refs[-1][2] = ts
                    refs[-1][3] += 1
                else:
                    refs.append([n, ts, ts, 1])
                fp = inp.get('file_path') or ''
                if name == 'Write' and re.search(r'\.autoflow/issue-%d\.json$' % n, fp):
                    state_writes.append([ts, n])

    prompts = []
    derivable = False
    for r in recs:
        if r.get('type') != 'user':
            continue
        v = is_operator_prompt(r)
        if v is not None:
            derivable = True
        if v:
            prompts.append(r.get('timestamp'))

    workflows = {}
    for p in sorted(glob.glob(os.path.join(main[:-len('.jsonl')], 'workflows', 'wf_*.json'))):
        try:
            with open(p, encoding='utf-8') as f:
                w = json.load(f)
        except (OSError, ValueError):
            continue
        workflows[w.get('runId') or os.path.basename(p)[:-5]] = {
            'name': w.get('workflowName'), 'start': w.get('timestamp'),
            'duration_ms': w.get('durationMs'), 'status': w.get('status'),
        }

    direct, wf = session_files(main)
    agents = []
    for p in direct:
        a = agent_record(p, read_meta(p))
        a['workflow'] = None
        if a['tool_use_id'] in spawn_keys:
            a['phase_key'], a['phase_key_method'] = spawn_keys[a['tool_use_id']]
        agents.append(a)
    for p in wf:
        a = agent_record(p, read_meta(p))
        run = os.path.basename(os.path.dirname(p))
        a['workflow'] = run
        wname = (workflows.get(run) or {}).get('name')
        if wname and a['description']:
            a['phase_key'], a['phase_key_method'] = '%s/%s' % (wname, a['description']), 'workflow-site'
        agents.append(a)
    agents.sort(key=lambda a: a['start'] or '')

    # The policy governs AutoFlow roles only: a research type (Explore, general-purpose) has no key to recover.
    top = [a for a in agents if not a['workflow'] and not a['parent'] and a['role'].startswith('autoflow-')]
    by_method = {}
    for a in top:
        m = a['phase_key_method'] or 'none'
        by_method[m] = by_method.get(m, 0) + 1

    nbytes, nfiles = source_bytes(main)
    models = {}
    for c in calls:
        if c['model']:
            models[c['model']] = models.get(c['model'], 0) + 1
    return {
        'schema': SCHEMA,
        'session': sid,
        'project_dir': os.path.basename(os.path.dirname(main)),
        'cwd': distinct('cwd'),
        'git_branches': distinct('gitBranch'),
        'versions': distinct('version'),
        'source': {
            'bytes': nbytes, 'files': nfiles, 'records': len(recs),
            'form': 'stripped' if any('user' in r and isinstance(r.get('user'), dict) for r in recs[:200]) else 'raw',
        },
        'start': start, 'end': end,
        'operator': {'prompts': prompts if derivable else None},
        'orchestrator': {
            'models': models,
            'usage': sum_usage(calls),
            'first_in': context_of(calls[0]) if calls else 0,
            'max_context': max((context_of(c) for c in calls), default=0),
            'rewrites': sum(1 for i, c in enumerate(calls) if i > 0 and is_rewrite(c)),
            'tools': tools,
            'call_columns': ['ts', 'context', 'cache_read', 'cache_creation', 'output', 'input', 'rewrite'],
            'calls': [[c['ts'], context_of(c), c['cache_read'], c['cache_creation'], c['output'], c['input'],
                       int(i > 0 and is_rewrite(c))] for i, c in enumerate(calls)],
        },
        'agents': agents,
        'workflows': workflows,
        'issue_refs': refs,
        'state_writes': state_writes,
        'pr_links': [{'ts': r.get('timestamp'), 'repo': r.get('prRepository'), 'number': r.get('prNumber')}
                     for r in recs if r.get('type') == 'pr-link' and r.get('prNumber')],
        'phase_key_recovery': {'spawns': len(top), 'by_method': by_method},
    }


def write_json(path, obj):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    os.replace(tmp, path)


def collect(args, now):
    out_dir = os.path.join(args.root, 'sessions')
    os.makedirs(out_dir, exist_ok=True)
    policy_keys, _ = load_policy(args.policy)
    counts = {'written': 0, 'updated': 0, 'kept': 0, 'unsettled': 0, 'empty': 0}
    seen = set()
    for root in args.projects_root:
        for main in sorted(glob.glob(os.path.join(root, '*', '*.jsonl'))):
            sid = os.path.basename(main)[:-len('.jsonl')]
            if sid in seen or (args.session and sid not in args.session):
                continue
            seen.add(sid)
            dest = os.path.join(out_dir, sid + '.json')
            nbytes, _ = source_bytes(main)
            prior = None
            if os.path.exists(dest):
                try:
                    with open(dest, encoding='utf-8') as f:
                        prior = json.load(f)
                except (OSError, ValueError):
                    prior = None
                if prior and nbytes <= (prior.get('source') or {}).get('bytes', 0):
                    counts['kept'] += 1
                    continue
            rec = collect_session(main, policy_keys)
            last = parse_ts(rec['end'])
            for a in rec['agents']:
                t = parse_ts(a['end'])
                if t and (last is None or t > last):
                    last = t
            if last is None:
                counts['empty'] += 1
                continue
            if (now - last).total_seconds() < args.settle_hours * 3600:
                counts['unsettled'] += 1
                continue
            rec['collected_at'] = now.isoformat()
            write_json(dest, rec)
            counts['updated' if prior else 'written'] += 1
    return counts


# --------------------------------------------------------------------------- derive

def repo_of(sess):
    cwds = sess.get('cwd') or []
    return os.path.basename(cwds[0].rstrip('/')) if cwds else sess.get('project_dir') or '?'


def segments_of(sess):
    """Issue segments of one session: [{'issue', 'start', 'end', 'refs'}], non-overlapping, in order."""
    segs = []
    cur = None
    pend = None
    for issue, first, last, count in sess.get('issue_refs') or []:
        if cur and issue == cur['issue']:
            cur['last'] = last
            cur['refs'] += count
            pend = None
            continue
        if pend and pend['issue'] == issue:
            pend['last'] = last
            pend['refs'] += count
        else:
            pend = {'issue': issue, 'start': first, 'last': last, 'refs': count}
        if pend['refs'] >= SWITCH_REFS:
            if cur:
                segs.append(cur)
            cur = pend
            pend = None
    if cur:
        segs.append(cur)
    end_of_session = norm_ts(sess.get('end'))
    spans = [(norm_ts(a.get('start')), norm_ts(a.get('end'))) for a in sess.get('agents') or []]
    for _, a_end in spans:
        if a_end and (not end_of_session or a_end > end_of_session):
            end_of_session = a_end
    for s in segs:
        s['start'], s['last'] = norm_ts(s['start']), norm_ts(s['last'])
    # A segment opens at the operator prompt that started it, not at the first reference that prompt led to.
    prompts = sorted(norm_ts(p) for p in (sess.get('operator') or {}).get('prompts') or [])
    for i, s in enumerate(segs):
        floor = segs[i - 1]['last'] if i else ''
        before = [p for p in prompts if floor < p < s['start']]
        if before:
            s['start'] = before[-1]
    for i, s in enumerate(segs):
        limit = segs[i + 1]['start'] if i + 1 < len(segs) else end_of_session
        tail = parse_ts(s['last'])
        cap = norm_ts((tail + dt.timedelta(seconds=TAIL_S)).isoformat()) if tail else None
        s['end'] = min(x for x in (limit, cap) if x) if (limit or cap) else s['last']
        # an agent spawned inside the segment may outlive its last reference
        for a_start, a_end in spans:
            if a_start and a_end and s['start'] <= a_start < s['end'] < a_end:
                s['end'] = min(a_end, limit) if limit else a_end
    return segs


def norm_ts(s):
    t = parse_ts(s)
    return t.astimezone(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z' if t else s


def read_labels(path):
    rows = {}
    try:
        with open(path, encoding='utf-8') as f:
            lines = [ln.rstrip('\n') for ln in f if ln.strip() and not ln.startswith('#')]
    except OSError:
        return rows
    for ln in lines:
        c = ln.split('\t')
        if c[0] in ('session-id', 'session_id'):
            continue
        c += [''] * (5 - len(c))
        rows[c[0]] = {'arm': c[1], 'issue': c[2].lstrip('#'), 'operator_minutes': c[3], 'note': c[4]}
    return rows


def find_artifacts(archive_root, repo, issue, cwds):
    """The directory holding issue-{N}.json: the archive copy, else a live .autoflow."""
    hits = []
    for pat in ('*__%s' % repo, repo):
        hits += glob.glob(os.path.join(archive_root, pat, 'issue-%s-*' % issue, 'issue-%s.json' % issue))
    if hits:
        return os.path.dirname(sorted(hits)[-1]), 'archive'
    for cwd in cwds:
        p = os.path.join(cwd, '.autoflow', 'issue-%s.json' % issue)
        if os.path.exists(p):
            return os.path.dirname(p), 'live'
    return None, None


def score_avg(scores):
    vals = []
    for v in (scores or {}).values():
        v = v.get('score') if isinstance(v, dict) else v
        if isinstance(v, (int, float)):
            vals.append(v)
    return round(sum(vals) / len(vals), 2) if vals else None


def outcome(adir, issue):
    o = {}
    if not adir:
        return o
    try:
        with open(os.path.join(adir, 'issue-%s.json' % issue), encoding='utf-8') as f:
            st = json.load(f)
    except (OSError, ValueError):
        st = {}
    o['cycle'] = st.get('cycle')
    o['state_phase'] = st.get('phase')
    o['mode'] = st.get('mode')
    for gate in ('gate_hypothesis_structure', 'gate_hypothesis_cause', 'gate_plan', 'audit', 'gate_quality'):
        o[gate] = score_avg(((st.get('phases') or {}).get(gate) or {}).get('scores'))

    def count(pattern):
        rx = re.compile(pattern)
        return sum(1 for n in os.listdir(adir) if rx.fullmatch(n))

    pre = r'issue-%s-(?:c\d+-)?' % issue
    o['gate_plan_evals'] = count(pre + r'gate-plan(?:-\d+)?\.md')
    o['audit_evals'] = count(pre + r'audit(?:-\d+)?\.md')
    o['gate_quality_evals'] = count(pre + r'gate-quality(?:-\d+)?\.md')
    o['reviewer_rounds'] = count(pre + r'review-comment-.*\.md')
    turns = briefs = 0
    for p in glob.glob(os.path.join(adir, 'issue-%s-*architect-transcript.md' % issue)):
        with open(p, encoding='utf-8') as f:
            for ln in f:
                turns += ln.startswith('### Turn ')
                briefs += ln.startswith('### Brief')
    o['architect_turns'] = turns
    o['architect_rounds'] = (briefs + 1) if turns else 0
    heads = []
    for p in glob.glob(os.path.join(adir, 'issue-%s-*ledger.md' % issue)) + \
            glob.glob(os.path.join(adir, 'issue-%s-ledger.md' % issue)):
        with open(p, encoding='utf-8') as f:
            heads += [ln.strip() for ln in f if ln.startswith('## ')]
    heads = list(dict.fromkeys(heads))
    o['ledger_entries'] = len(heads)
    o['review_autofix'] = sum(1 for h in heads if h.endswith('[review-autofix]'))
    o['ac_decisions'] = sum(1 for h in heads if h.endswith('[ac-decision]'))
    # A CI round is judged by the `exit=<n>` line confirm-ci-green.sh's caller left in the log, never by
    # its position: a later log is often a green re-confirmation. 12 is the red build; any other
    # non-zero exit (not mergeable, no check published, no verdict) is a round that did not fail the
    # build; a log with no exit line is undetermined and counted as nothing else.
    o['ci_rounds'] = o['ci_fail_rounds'] = o['ci_other_rounds'] = o['ci_undetermined'] = 0
    for p in glob.glob(os.path.join(adir, 'issue-%s-local' % issue, 'handoff-ci-*.log')):
        with open(p, encoding='utf-8', errors='replace') as f:
            exits = re.findall(r'^exit=(\d+)\s*$', f.read(), re.M)
        if not exits:
            o['ci_undetermined'] += 1
            continue
        o['ci_rounds'] += 1
        code = int(exits[-1])
        o['ci_fail_rounds'] += code == 12
        o['ci_other_rounds'] += code not in (0, 12)
    markers = []
    for p in glob.glob(os.path.join(adir, 'issue-%s-phases.jsonl' % issue)):
        with open(p, encoding='utf-8') as f:
            for ln in f:
                try:
                    markers.append(json.loads(ln))
                except ValueError:
                    pass
    o['phase_markers'] = [[m.get('ts'), m.get('phase'), m.get('event')] for m in markers if m.get('ts')]
    return o


def marker_phase(markers, ts):
    cur = None
    for mts, phase, event in sorted(markers):
        if norm_ts(mts) > ts:
            break
        cur = phase if event == 'enter' else None
    return cur


def gh_pr_state(repo, number):
    try:
        r = subprocess.run(['gh', 'pr', 'view', str(number), '-R', repo, '--json', 'state', '-q', '.state'],
                           capture_output=True, text=True, timeout=30)
        return r.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def derive(args):
    labels = read_labels(os.path.join(args.root, 'labels.tsv'))
    issues = {}
    unattributed = []
    for path in sorted(glob.glob(os.path.join(args.root, 'sessions', '*.json'))):
        try:
            with open(path, encoding='utf-8') as f:
                sess = json.load(f)
        except (OSError, ValueError):
            continue
        repo = repo_of(sess)
        label = labels.get(sess['session'])
        segs = segments_of(sess)
        if not segs and label and label['issue']:
            segs = [{'issue': int(label['issue']), 'start': norm_ts(sess['start']), 'end': '9999', 'refs': 0}]
        calls = sess['orchestrator']['calls']
        prompts = sess['operator']['prompts']
        taken_calls = taken_agents = 0
        for s in segs:
            # Two arms of one issue are two rows: the comparison is the point of the label.
            arm = (label or {}).get('arm') or ('A' if s['refs'] else '')
            key = '%s#%s' % (repo, s['issue']) + ('' if arm in ('', 'A') else '@' + arm)
            it = issues.setdefault(key, {
                'key': key, 'repo': repo, 'issue': s['issue'], 'arm': arm, 'operator_minutes': '', 'note': '',
                'sessions': [], 'segments': [], 'cwd': [], 'orch_calls': [], 'agents': [], 'pr_links': [],
                'operator_prompts': 0, 'operator_prompts_known': True,
            })
            inside = lambda ts: ts is not None and s['start'] <= norm_ts(ts) < s['end']  # noqa: E731
            if sess['session'] not in it['sessions']:
                it['sessions'].append(sess['session'])
            it['cwd'] = list(dict.fromkeys(it['cwd'] + (sess.get('cwd') or [])))
            if label:
                it['operator_minutes'] = label['operator_minutes'] or it['operator_minutes']
                it['note'] = label['note'] or it['note']
            seg_calls = [c for c in calls if inside(c[0])]
            seg_agents = [a for a in sess['agents'] if inside(a.get('start'))]
            taken_calls += len(seg_calls)
            taken_agents += len(seg_agents)
            it['segments'].append({'session': sess['session'], 'start': s['start'],
                                   'end': s['end'] if s['end'] != '9999' else norm_ts(sess['end']),
                                   'refs': s['refs']})
            it['orch_calls'] += [[norm_ts(c[0])] + c[1:] for c in seg_calls]
            it['agents'] += [dict(a, session=sess['session']) for a in seg_agents]
            it['pr_links'] += [p for p in sess.get('pr_links') or [] if inside(p.get('ts'))]
            if prompts is None:
                it['operator_prompts_known'] = False
            else:
                it['operator_prompts'] += sum(1 for p in prompts if inside(p))
        rest = len(calls) - taken_calls
        if rest or len(sess['agents']) - taken_agents:
            unattributed.append({'session': sess['session'], 'repo': repo, 'orch_calls': rest,
                                 'agents': len(sess['agents']) - taken_agents})

    rows = []
    for key in sorted(issues, key=lambda k: (issues[k]['repo'], issues[k]['issue'])):
        it = issues[key]
        adir, where = find_artifacts(args.archive_root, it['repo'], it['issue'], it['cwd'])
        it['outcome'] = outcome(adir, it['issue'])
        it['outcome']['artifacts'] = where
        for a in it['agents']:
            a['phase_marker'] = marker_phase(it['outcome'].get('phase_markers') or [], norm_ts(a['start'])) \
                if it['outcome'].get('phase_markers') else None
        prs = {}
        for p in it['pr_links']:
            prs['%s#%s' % (p['repo'], p['number'])] = p
        it['prs'] = sorted(prs)
        it['pr_states'] = {k: gh_pr_state(p['repo'], p['number']) for k, p in prs.items()} if args.gh else {}
        del it['pr_links']

        orch = dict.fromkeys(USAGE_KEYS, 0)
        for c in it['orch_calls']:
            orch['cache_read'] += c[2]
            orch['cache_creation'] += c[3]
            orch['output'] += c[4]
            orch['input'] += c[5]
        ag = dict.fromkeys(USAGE_KEYS, 0)
        gate = 0
        for a in it['agents']:
            for k in USAGE_KEYS:
                ag[k] += a['usage'][k]
            if a['role'] == 'autoflow-evaluator':
                gate += sum(a['usage'].values())
        total = sum(orch.values()) + sum(ag.values())
        wall = sum((parse_ts(s['end']) - parse_ts(s['start'])).total_seconds() for s in it['segments']
                   if parse_ts(s['end']) and parse_ts(s['start']))
        top = [a for a in it['agents'] if not a['workflow'] and not a['parent'] and a['role'].startswith('autoflow-')]
        it['totals'] = {
            'orchestrator': orch, 'agents': ag, 'tokens': total,
            'orch_share': round(sum(orch.values()) / total, 4) if total else None,
            'gate_share': round(gate / total, 4) if total else None,
            'wall_h': round(wall / 3600, 2),
            'max_orch_context': max((c[1] for c in it['orch_calls']), default=0),
            'rewrites': sum(c[6] for c in it['orch_calls']) + sum(a['rewrites'] for a in it['agents']),
            'spawns': len(top),
            'phase_keys_recovered': sum(1 for a in top if a['phase_key']),
        }
        o, t = it['outcome'], it['totals']
        rows.append([
            it['repo'], it['issue'], it['arm'], len(it['sessions']),
            min(s['start'] for s in it['segments']), max(s['end'] for s in it['segments']), t['wall_h'],
            it['operator_prompts'] if it['operator_prompts_known'] else '', it['operator_minutes'],
            len(it['orch_calls']), orch['cache_read'], orch['cache_creation'], orch['output'],
            len(it['agents']), ag['cache_read'], ag['cache_creation'], ag['output'],
            t['tokens'], t['orch_share'], t['gate_share'], t['max_orch_context'], t['rewrites'],
            t['spawns'], t['phase_keys_recovered'],
            o.get('cycle'), o.get('state_phase'), o.get('gate_hypothesis_structure'), o.get('gate_hypothesis_cause'),
            o.get('gate_plan'), o.get('audit'), o.get('gate_quality'),
            o.get('architect_turns'), o.get('architect_rounds'), o.get('gate_plan_evals'), o.get('audit_evals'),
            o.get('gate_quality_evals'), o.get('review_autofix'), o.get('reviewer_rounds'),
            o.get('ci_rounds'), o.get('ci_fail_rounds'), o.get('ci_other_rounds'), o.get('ci_undetermined'),
            ' '.join(it['prs']), ' '.join('%s=%s' % kv for kv in sorted(it['pr_states'].items()) if kv[1]),
            it['note'],
        ])
    header = [
        'repo', 'issue', 'arm', 'sessions', 'start', 'end', 'wall_h', 'operator_prompts', 'operator_minutes',
        'orch_calls', 'orch_cache_read', 'orch_cache_creation', 'orch_output',
        'agents', 'agent_cache_read', 'agent_cache_creation', 'agent_output',
        'tokens', 'orch_share', 'gate_share', 'max_orch_context', 'rewrites', 'spawns', 'phase_keys_recovered',
        'cycle', 'state_phase', 'gate_hypothesis_structure', 'gate_hypothesis_cause', 'gate_plan', 'audit',
        'gate_quality', 'architect_turns', 'architect_rounds', 'gate_plan_evals', 'audit_evals',
        'gate_quality_evals', 'review_autofix', 'reviewer_rounds', 'ci_rounds', 'ci_fail_rounds', 'ci_other_rounds', 'ci_undetermined',
        'prs', 'pr_states', 'note',
    ]
    tmp = os.path.join(args.root, 'issues.tsv.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write('\t'.join(header) + '\n')
        for r in rows:
            f.write('\t'.join('' if v is None else str(v).replace('\t', ' ') for v in r) + '\n')
    os.replace(tmp, os.path.join(args.root, 'issues.tsv'))
    write_json(os.path.join(args.root, 'issues.json'),
               {'schema': SCHEMA, 'issues': [issues[k] for k in sorted(issues)], 'unattributed': unattributed})
    return len(rows), unattributed


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    archive = os.environ.get('AUTOFLOW_ARCHIVE_ROOT') or os.path.join(os.path.expanduser('~'), '.autoflow')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--projects-root', action='append',
                    help='transcript root (repeatable; first hit of a session id wins). '
                         'Default: ~/.claude/projects')
    ap.add_argument('--archive-root', default=archive, help='the .autoflow archive root (outcome join)')
    ap.add_argument('--root', help='metrics store. Default: <archive-root>/_metrics')
    ap.add_argument('--settle-hours', type=float, default=12.0,
                    help='a session whose last record is younger than this is not finalized')
    ap.add_argument('--now', help='clock override (ISO 8601), for tests')
    ap.add_argument('--session', action='append', help='collect only this session id (repeatable)')
    ap.add_argument('--policy', default=os.path.join(here, '..', '..', '.claude', 'autoflow', 'spawn-policy.json'))
    ap.add_argument('--no-collect', action='store_true')
    ap.add_argument('--no-derive', action='store_true')
    ap.add_argument('--gh', action='store_true', help='query each linked PR\'s state with the gh CLI (network)')
    args = ap.parse_args(argv)
    args.projects_root = args.projects_root or [os.path.join(os.path.expanduser('~'), '.claude', 'projects')]
    args.root = args.root or os.path.join(args.archive_root, '_metrics')
    now = parse_ts(args.now) if args.now else dt.datetime.now(dt.timezone.utc)
    if now is None:
        ap.error('--now is not ISO 8601')
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    os.makedirs(args.root, exist_ok=True)

    if not args.no_collect:
        c = collect(args, now)
        print('collect: written %(written)d, updated %(updated)d, kept %(kept)d, '
              'unsettled %(unsettled)d, empty %(empty)d' % c)
        spawns = recovered = 0
        methods = {}
        for p in glob.glob(os.path.join(args.root, 'sessions', '*.json')):
            with open(p, encoding='utf-8') as f:
                r = json.load(f).get('phase_key_recovery') or {}
            spawns += r.get('spawns', 0)
            for m, n in (r.get('by_method') or {}).items():
                methods[m] = methods.get(m, 0) + n
                recovered += n if m != 'none' else 0
        if spawns:
            print('phase-key recovery: %d / %d orchestrator spawns (%.1f%%) — %s' % (
                recovered, spawns, 100.0 * recovered / spawns,
                ', '.join('%s %d' % kv for kv in sorted(methods.items()))))
    if not args.no_derive:
        n, un = derive(args)
        print('derive: %d issue rows -> %s' % (n, os.path.join(args.root, 'issues.tsv')))
        if un:
            print('unattributed: %d sessions hold calls or agents outside every issue segment' % len(un))
    return 0


if __name__ == '__main__':
    sys.exit(main())
