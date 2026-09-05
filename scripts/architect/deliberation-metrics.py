#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""ARCHITECT deliberation — cost aggregation over agent transcripts (issue #179).

The effect record of ADR-0023 D4 compares two ARCHITECT arms — the per-turn
respawn script (arm 0) and the orchestrator-relayed persistent participants
(arm A2) — on the same input. The review that measured the baseline
(docs/design-reviews/issue-177-deliberation-participant-lifetime.md, §1.3)
computed its numbers with scratch scripts that were not committed; this script
is that method, committed so the metric re-derives:

  * one API call = one distinct `requestId` among a transcript's `assistant`
    records (streamed records of one request share the id);
  * a turn's `first_in` = input + cache_read + cache_creation tokens of its
    first assistant record (the prompt the turn opened with);
  * tool calls = `tool_use` blocks by `name`, de-duplicated by block id;
  * wall = last record timestamp minus first;
  * tokens = cache_creation / cache_read / output summed over `message.usage`,
    de-duplicated by `message.id` keeping the record with the largest
    output_tokens (ADR-0017 > Notes > C8 method);
  * a persistent participant's transcript is split into wakes at each user
    record that is a message rather than a tool result, and every per-turn
    figure above is then computed per wake.

Usage:
  deliberation-metrics.py [--label <arm>] [--transcript <relay.md>]
                          [--session <session.jsonl> --from <iso> --to <iso>]
                          [--markdown] <agent.jsonl | dir> ...

Positional arguments are agent transcripts or directories holding
`agent-*.jsonl`. `--transcript` adds per-turn message lengths from a relay
transcript file (arm A2; arm 0 reads them from each turn's StructuredOutput).
`--session` with a window adds the orchestrator's own calls and usage inside
that window (the relay turns, counted separately as the review §6 asks).
Output is JSON on stdout, or a Markdown record with `--markdown`.
Only the standard library is used.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import sys

PATH_RE = re.compile(r'(?<!\w)((?:\.autoflow|\.claude|docs|scripts|tests|test|setup|plugin)/[\w./-]+\.[a-z]+)')


def parse_ts(s):
    if not s:
        return None
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    try:
        return dt.datetime.fromisoformat(s)
    except ValueError:
        return None


def load(path):
    recs = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                recs.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return recs


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return ''.join(p.get('text', '') for p in content if isinstance(p, dict) and p.get('type') == 'text')
    return ''


def is_wake(rec):
    """A user record that is a message to the agent (spawn prompt or a wake), not a tool result."""
    if rec.get('type') != 'user':
        return False
    content = (rec.get('message') or {}).get('content')
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(isinstance(p, dict) and p.get('type') == 'tool_result' for p in content)
    return False


def kind_of(prompt):
    p = prompt or ''
    if 'transcription channel' in p:
        return 'policy-load'
    if 'You are the scribe' in p:
        return 'scribe'
    if p.startswith('Append (do NOT rewrite') or 'Append (do NOT rewrite or delete)' in p:
        return 'ledger'
    if 'transcribed below' in p:
        return 'dev-report' if 'Developer AI' in p[:80] else 'test-report'
    if 'ARCHITECT relay' in p or 'relay participant' in p:
        return 'participant-dev' if 'Developer AI' in p[:200] else 'participant-test'
    if 'You are the Developer AI in an AutoFlow ARCHITECT deliberation' in p:
        return 'dev-turn'
    if 'You are the Test AI in an AutoFlow ARCHITECT deliberation' in p:
        return 'test-turn'
    return 'other'


def usage_totals(assistant_recs):
    """Sum usage de-duplicated by message.id, keeping the record with the largest output_tokens."""
    best = {}
    for r in assistant_recs:
        m = r.get('message') or {}
        u = m.get('usage')
        if not u:
            continue
        mid = m.get('id') or r.get('requestId') or id(r)
        if mid not in best or (u.get('output_tokens') or 0) > (best[mid].get('output_tokens') or 0):
            best[mid] = u
    tot = {'input': 0, 'cache_creation': 0, 'cache_read': 0, 'output': 0}
    for u in best.values():
        tot['input'] += u.get('input_tokens') or 0
        tot['cache_creation'] += u.get('cache_creation_input_tokens') or 0
        tot['cache_read'] += u.get('cache_read_input_tokens') or 0
        tot['output'] += u.get('output_tokens') or 0
    return tot


def first_in(assistant_recs):
    for r in assistant_recs:
        u = (r.get('message') or {}).get('usage')
        if u:
            return (u.get('input_tokens') or 0) + (u.get('cache_read_input_tokens') or 0) + (u.get('cache_creation_input_tokens') or 0)
    return 0


def first_cache_creation(assistant_recs):
    for r in assistant_recs:
        u = (r.get('message') or {}).get('usage')
        if u:
            return u.get('cache_creation_input_tokens') or 0
    return 0


def tool_uses(assistant_recs):
    seen = set()
    counts = {}
    paths = set()
    message_len = None
    for r in assistant_recs:
        for c in (r.get('message') or {}).get('content') or []:
            if not isinstance(c, dict) or c.get('type') != 'tool_use':
                continue
            cid = c.get('id')
            if cid in seen:
                continue
            seen.add(cid)
            name = c.get('name') or '?'
            counts[name] = counts.get(name, 0) + 1
            inp = c.get('input') or {}
            if name == 'Bash':
                for m in PATH_RE.findall(inp.get('command') or ''):
                    paths.add(m)
            elif name in ('Read', 'Grep', 'Glob'):
                fp = inp.get('file_path') or inp.get('path')
                if fp:
                    paths.add(re.sub(r'^.*?/(?=(\.autoflow|\.claude|docs|scripts|tests|test|setup|plugin)/)', '', fp))
            if name == 'StructuredOutput' and isinstance(inp.get('message'), str):
                message_len = len(inp['message'])
    return counts, paths, message_len


def tool_seconds(recs):
    """Tool execution time: the span from each tool_use record to the next user record (§1.3)."""
    total = 0.0
    longest = 0.0
    pending = None
    for r in recs:
        if r.get('type') == 'assistant' and any(isinstance(c, dict) and c.get('type') == 'tool_use' for c in (r.get('message') or {}).get('content') or []):
            pending = parse_ts(r.get('timestamp'))
        elif r.get('type') == 'user' and pending is not None:
            t = parse_ts(r.get('timestamp'))
            if t:
                span = (t - pending).total_seconds()
                total += span
                longest = max(longest, span)
            pending = None
    return round(total, 1), round(longest, 1)


def segment_stats(recs):
    """Stats for one contiguous slice of records (a whole one-shot agent, or one wake)."""
    a = [r for r in recs if r.get('type') == 'assistant']
    ts = [parse_ts(r.get('timestamp')) for r in recs]
    ts = [t for t in ts if t]
    calls = len({r.get('requestId') for r in a if r.get('requestId')})
    counts, paths, message_len = tool_uses(a)
    tool_s, longest_tool_s = tool_seconds(recs)
    return {
        'tool_s': tool_s,
        'longest_tool_s': longest_tool_s,
        'calls': calls,
        'tools': counts,
        'bash': counts.get('Bash', 0),
        'paths': sorted(paths),
        'first_in': first_in(a),
        'first_cache_creation': first_cache_creation(a),
        'usage': usage_totals(a),
        'wall_s': round((max(ts) - min(ts)).total_seconds(), 1) if len(ts) >= 2 else 0.0,
        'start': min(ts).isoformat() if ts else None,
        'end': max(ts).isoformat() if ts else None,
        'message_len': message_len,
    }


def analyze_agent(path):
    recs = load(path)
    wakes = [i for i, r in enumerate(recs) if is_wake(r)]
    prompt = text_of((recs[wakes[0]].get('message') or {}).get('content')) if wakes else ''
    kind = kind_of(prompt)
    whole = segment_stats(recs)
    segments = []
    for j, start in enumerate(wakes):
        end = wakes[j + 1] if j + 1 < len(wakes) else len(recs)
        seg = segment_stats(recs[start:end])
        seg['wake'] = j + 1
        seg['wake_text'] = text_of((recs[start].get('message') or {}).get('content'))[:120]
        segments.append(seg)
    return {
        'agent': os.path.basename(path).replace('.jsonl', ''),
        'kind': kind,
        'wakes': len(wakes),
        'whole': whole,
        'segments': segments,
    }


def transcript_turn_lengths(path):
    lengths = {}
    cur = None
    buf = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^### Turn (\d+) ', line)
            if m or line.startswith('## ') or line.startswith('### '):
                if cur is not None:
                    lengths[cur] = len(''.join(buf).strip())
                cur = int(m.group(1)) if m else None
                buf = []
                continue
            if cur is not None:
                buf.append(line)
    if cur is not None:
        lengths[cur] = len(''.join(buf).strip())
    return lengths


def session_window(path, t_from, t_to):
    recs = load(path)
    lo, hi = parse_ts(t_from), parse_ts(t_to)
    inside = [r for r in recs if r.get('type') == 'assistant' and (ts := parse_ts(r.get('timestamp'))) and lo <= ts <= hi]
    counts, _, _ = tool_uses(inside)
    return {
        'calls': len({r.get('requestId') for r in inside if r.get('requestId')}),
        'usage': usage_totals(inside),
        'tools': counts,
        'wakes': counts.get('SendMessage', 0) + counts.get('Agent', 0),
    }


def build(args):
    files = []
    for p in args.inputs:
        if os.path.isdir(p):
            files.extend(sorted(glob.glob(os.path.join(p, 'agent-*.jsonl'))))
        else:
            files.append(p)
    agents = [analyze_agent(f) for f in files]
    agents.sort(key=lambda a: a['whole']['start'] or '')

    # Turn rows, in chronological order across agents: one-shot turn agents contribute one row
    # each; a persistent participant contributes one row per wake.
    rows = []
    for a in agents:
        if a['kind'] in ('dev-turn', 'test-turn'):
            s = a['whole']
            rows.append({'side': 'dev' if a['kind'] == 'dev-turn' else 'test', 'agent': a['agent'], **s})
        elif a['kind'] in ('participant-dev', 'participant-test'):
            for s in a['segments']:
                rows.append({'side': 'dev' if a['kind'] == 'participant-dev' else 'test', 'agent': a['agent'], **s})
    rows.sort(key=lambda r: r['start'] or '')
    for i, r in enumerate(rows, 1):
        r['turn'] = i
    if args.transcript:
        lengths = transcript_turn_lengths(args.transcript)
        for r in rows:
            if r['turn'] in lengths:
                r['message_len'] = lengths[r['turn']]

    discuss_kinds = {'dev-turn', 'test-turn', 'participant-dev', 'participant-test'}
    record_kinds = {'dev-report', 'test-report', 'scribe', 'ledger'}

    def group(kinds):
        sel = [a for a in agents if a['kind'] in kinds]
        starts = [a['whole']['start'] for a in sel if a['whole']['start']]
        ends = [a['whole']['end'] for a in sel if a['whole']['end']]
        u = {'input': 0, 'cache_creation': 0, 'cache_read': 0, 'output': 0}
        for a in sel:
            for k in u:
                u[k] += a['whole']['usage'][k]
        return {
            'agents': len(sel),
            'calls': sum(a['whole']['calls'] for a in sel),
            'bash': sum(a['whole']['bash'] for a in sel),
            'tool_s': round(sum(a['whole']['tool_s'] for a in sel), 1),
            'wall_s': round((max(parse_ts(e) for e in ends) - min(parse_ts(s) for s in starts)).total_seconds(), 1) if starts and ends else 0.0,
            'usage': u,
        }

    path_counts = {}
    for a in agents:
        for p in a['whole']['paths']:
            path_counts[p] = path_counts.get(p, 0) + 1
    repeated = sorted(path_counts.items(), key=lambda kv: (-kv[1], kv[0]))

    out = {
        'label': args.label,
        'agents': agents,
        'turns': rows,
        'totals': {
            'all': group(discuss_kinds | record_kinds | {'policy-load', 'other'}),
            'discuss': group(discuss_kinds),
            'record': group(record_kinds),
        },
        'repeated_reads': [{'path': p, 'agents': n} for p, n in repeated if n >= args.min_readers],
    }
    if args.session:
        out['orchestrator'] = session_window(args.session, args.t_from, args.t_to)
    return out


def markdown(out):
    L = []
    lab = out['label'] or 'run'
    t = out['totals']
    L.append(f"### {lab} — run totals\n")
    L.append('| Item | Value |\n|---|---|')
    L.append(f"| Agents / discussion turns | {t['all']['agents']} / {len(out['turns'])} |")
    L.append(f"| API calls (distinct requestId) | {t['all']['calls']} — discussion {t['discuss']['calls']}, record {t['record']['calls']} |")
    L.append(f"| Bash tool calls | {t['all']['bash']} — discussion {t['discuss']['bash']} |")
    L.append(f"| Wall clock in-agent (s) | discussion {t['discuss']['wall_s']}, record {t['record']['wall_s']}, all {t['all']['wall_s']} |")
    L.append(f"| Tool execution (s, tool_use → next user record) | discussion {t['discuss']['tool_s']}, record {t['record']['tool_s']} — the rest of the wall is model generation |")
    u = t['all']['usage']
    L.append(f"| Tokens (dedup by message.id) | cache_creation {u['cache_creation']:,} · cache_read {u['cache_read']:,} · output {u['output']:,} · input {u['input']:,} |")
    if 'orchestrator' in out:
        o = out['orchestrator']
        ou = o['usage']
        L.append(f"| Orchestrator relay (session window) | {o['calls']} calls, {o['wakes']} wake/spawn tool uses; cache_creation {ou['cache_creation']:,} · cache_read {ou['cache_read']:,} · output {ou['output']:,} |")
    L.append('')
    L.append(f"### {lab} — per turn\n")
    L.append('| turn | side | calls | Bash | wall (s) | tool (s) | first_in | cache_w (first call) | msg |\n|---|---|---|---|---|---|---|---|---|')
    for r in out['turns']:
        L.append(f"| {r['turn']} | {r['side']} | {r['calls']} | {r['bash']} | {r['wall_s']} | {r['tool_s']} | {r['first_in']:,} | {r['first_cache_creation']:,} | {r['message_len'] if r['message_len'] is not None else '—'} |")
    L.append('')
    if out['repeated_reads']:
        L.append(f"### {lab} — paths read by ≥ {min(x['agents'] for x in out['repeated_reads'])} agents\n")
        for x in out['repeated_reads']:
            L.append(f"- `{x['path']}` ({x['agents']})")
        L.append('')
    return '\n'.join(L)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('inputs', nargs='+', help='agent transcript files or directories of agent-*.jsonl')
    ap.add_argument('--label', default='')
    ap.add_argument('--transcript', help='relay transcript (.md) for per-turn message lengths')
    ap.add_argument('--session', help='orchestrator session transcript (.jsonl)')
    ap.add_argument('--from', dest='t_from', help='window start (ISO 8601) for --session')
    ap.add_argument('--to', dest='t_to', help='window end (ISO 8601) for --session')
    ap.add_argument('--min-readers', type=int, default=2, help='report paths read by at least this many agents')
    ap.add_argument('--markdown', action='store_true')
    args = ap.parse_args(argv)
    if args.session and not (args.t_from and args.t_to):
        ap.error('--session requires --from and --to')
    out = build(args)
    if args.markdown:
        print(markdown(out))
    else:
        json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
